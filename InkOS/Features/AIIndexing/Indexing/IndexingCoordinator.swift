// IndexingCoordinator.swift
// Orchestrates the document indexing pipeline.

import Foundation

// MARK: - Indexing Coordinator Protocol

// Protocol for the indexing coordinator to support dependency injection.
protocol IndexingCoordinatorProtocol: Actor {
  // Indexes a single document.
  func indexDocument(_ request: IndexRequest) async throws -> IndexingResult

  // Indexes a notebook by ID.
  func indexNotebook(notebookID: String) async throws -> IndexingResult

  // Removes all indexed content for a document.
  func removeDocument(documentID: String) async throws

  // Indexes all notebooks.
  func indexAllNotebooks() async throws -> BatchIndexingResult

  // Schedules a document for indexing via the queue.
  func scheduleIndexing(_ request: IndexRequest) async throws

  // Cancels all pending and in-progress indexing.
  func cancelAll() async
}

// MARK: - Indexing Coordinator Actor

// Actor that orchestrates the full indexing pipeline:
// Extract content -> Chunk text -> Generate embeddings -> Store in vector DB.
// Listens for document change notifications and schedules indexing.
actor IndexingCoordinator: IndexingCoordinatorProtocol {

  // Content extractor for JIIX and PDF parsing.
  private let contentExtractor: any ContentExtractorProtocol

  // Chunking service for splitting text.
  private let chunkingService: any ChunkingServiceProtocol

  // Embedding service for generating vectors.
  private let embeddingService: any EmbeddingServiceProtocol

  // Vector store client for persistence.
  private let vectorStoreClient: any VectorStoreClientProtocol

  // Bundle manager for accessing documents.
  private let bundleManager: BundleManager

  // Indexing queue for debounced background processing.
  private let indexingQueue: IndexingQueue

  // Configuration for indexing behavior.
  private let configuration: IndexingConfiguration

  // Creates an indexing coordinator with dependencies.
  init(
    contentExtractor: any ContentExtractorProtocol,
    chunkingService: any ChunkingServiceProtocol,
    embeddingService: any EmbeddingServiceProtocol,
    vectorStoreClient: any VectorStoreClientProtocol,
    bundleManager: BundleManager,
    configuration: IndexingConfiguration = .default
  ) {
    self.contentExtractor = contentExtractor
    self.chunkingService = chunkingService
    self.embeddingService = embeddingService
    self.vectorStoreClient = vectorStoreClient
    self.bundleManager = bundleManager
    self.configuration = configuration

    // Create the indexing queue.
    self.indexingQueue = IndexingQueue(configuration: configuration)
  }

  // Sets up the coordinator by registering for notifications.
  // Call this after initialization to start listening for document changes.
  func setup() async {
    // Set up queue callback to process requests.
    await indexingQueue.setProcessCallback { [weak self] requests in
      guard let self = self else { return }
      await self.processQueuedRequests(requests)
    }

    // Register for notifications.
    // Notifications are observed on the main queue and forwarded to this actor.
    await registerNotificationObservers()
  }

  // Tears down the coordinator by canceling pending operations.
  func teardown() async {
    await indexingQueue.cancelAll()
  }

  // MARK: - Notification Handling

  // Registers observers for document change notifications.
  @MainActor
  private func registerNotificationObservers() {
    let coordinator = self

    // Listen for notebook content changes.
    NotificationCenter.default.addObserver(
      forName: .notebookContentSaved,
      object: nil,
      queue: .main
    ) { notification in
      Task {
        await coordinator.handleNotebookContentChanged(notification)
      }
    }

    // Listen for PDF import completions.
    NotificationCenter.default.addObserver(
      forName: .pdfDocumentImported,
      object: nil,
      queue: .main
    ) { notification in
      Task {
        await coordinator.handlePDFImported(notification)
      }
    }
  }

  // Handles notebook content changed notification.
  private func handleNotebookContentChanged(_ notification: Notification) async {
    guard configuration.automaticIndexingEnabled else { return }

    guard let userInfo = notification.userInfo,
          let notebookID = userInfo[IndexingNotificationKey.documentID] as? String else {
      return
    }

    // Get notebook metadata by opening the handle.
    do {
      let handle = try await bundleManager.openNotebook(id: notebookID)
      let manifest = handle.initialManifest

      // Close handle after getting metadata.
      await handle.close(saveBeforeClose: false)

      let request = IndexRequest.notebook(NotebookIndexRequest(
        notebookID: notebookID,
        displayName: manifest.displayName,
        modifiedAt: manifest.modifiedAt
      ))

      try await scheduleIndexing(request)
    } catch {
      // Log error but don't propagate - this is background indexing.
      print("Failed to schedule indexing for notebook \(notebookID): \(error)")
    }
  }

  // Handles PDF imported notification.
  private func handlePDFImported(_ notification: Notification) async {
    guard configuration.automaticIndexingEnabled else { return }

    guard let userInfo = notification.userInfo,
          let documentID = userInfo[IndexingNotificationKey.documentID] as? String,
          let displayName = userInfo["displayName"] as? String else {
      return
    }

    let modifiedAt = userInfo["modifiedAt"] as? Date ?? Date()

    let request = IndexRequest.pdf(PDFIndexRequest(
      documentID: documentID,
      displayName: displayName,
      modifiedAt: modifiedAt
    ))

    do {
      try await scheduleIndexing(request)
    } catch {
      print("Failed to schedule indexing for PDF \(documentID): \(error)")
    }
  }

  // MARK: - Queue Processing

  // Schedules a document for indexing via the debounced queue.
  func scheduleIndexing(_ request: IndexRequest) async throws {
    try await indexingQueue.enqueue(request)
  }

  // Processes queued index requests.
  private func processQueuedRequests(_ requests: [IndexRequest]) async {
    for request in requests {
      do {
        let result = try await indexDocument(request)

        // Post success notification.
        await MainActor.run {
          NotificationCenter.default.post(
            name: .documentIndexingCompleted,
            object: nil,
            userInfo: [
              IndexingNotificationKey.documentID: request.documentID,
              IndexingNotificationKey.result: result
            ]
          )
        }
      } catch {
        // Post failure notification.
        await MainActor.run {
          NotificationCenter.default.post(
            name: .documentIndexingFailed,
            object: nil,
            userInfo: [
              IndexingNotificationKey.documentID: request.documentID,
              IndexingNotificationKey.error: error.localizedDescription
            ]
          )
        }
      }
    }
  }

  // MARK: - Direct Indexing

  // Indexes a single document through the full pipeline.
  func indexDocument(_ request: IndexRequest) async throws -> IndexingResult {
    let startTime = Date()
    let documentID = request.documentID

    do {
      // Step 1: Extract content.
      let extractedContent = try await extractContent(for: request)

      // If no content, nothing to index.
      guard !extractedContent.text.isEmpty else {
        // Delete any existing chunks for this document.
        _ = try await vectorStoreClient.deleteChunksForDocument(documentID: documentID)
        return IndexingResult.success(
          documentID: documentID,
          chunksIndexed: 0,
          duration: Date().timeIntervalSince(startTime)
        )
      }

      // Step 2: Chunk the content.
      let chunks = try await chunkingService.chunkContent(extractedContent)

      // Step 3: Generate embeddings.
      let texts = chunks.map { $0.text }
      let embeddings = try await embeddingService.generateEmbeddings(
        texts: texts,
        taskType: .retrievalDocument
      )

      // Step 4: Create indexed chunks with embeddings.
      let indexedChunks = createIndexedChunks(
        chunks: chunks,
        embeddings: embeddings,
        modifiedAt: request.modifiedAt
      )

      // Step 5: Delete existing chunks for this document.
      _ = try await vectorStoreClient.deleteChunksForDocument(documentID: documentID)

      // Step 6: Store new chunks.
      let upsertResult = try await vectorStoreClient.upsertChunks(indexedChunks)

      // Return result.
      let duration = Date().timeIntervalSince(startTime)

      if upsertResult.failureCount > 0 {
        return IndexingResult(
          documentID: documentID,
          success: true,
          chunksIndexed: upsertResult.successCount,
          errorMessage: "Partial failure: \(upsertResult.failureCount) chunks failed",
          duration: duration
        )
      }

      return IndexingResult.success(
        documentID: documentID,
        chunksIndexed: upsertResult.successCount,
        duration: duration
      )

    } catch {
      let duration = Date().timeIntervalSince(startTime)
      return IndexingResult.failure(
        documentID: documentID,
        error: error.localizedDescription,
        duration: duration
      )
    }
  }

  // Indexes a notebook by ID.
  func indexNotebook(notebookID: String) async throws -> IndexingResult {
    // Open handle to get metadata.
    let handle = try await bundleManager.openNotebook(id: notebookID)
    let manifest = handle.initialManifest

    let request = IndexRequest.notebook(NotebookIndexRequest(
      notebookID: notebookID,
      displayName: manifest.displayName,
      modifiedAt: manifest.modifiedAt
    ))

    return try await indexDocument(request)
  }

  // Removes all indexed content for a document.
  func removeDocument(documentID: String) async throws {
    _ = try await vectorStoreClient.deleteChunksForDocument(documentID: documentID)
  }

  // Indexes all notebooks in the library.
  func indexAllNotebooks() async throws -> BatchIndexingResult {
    let startTime = Date()
    var results: [IndexingResult] = []
    var successCount = 0
    var failureCount = 0
    var totalChunks = 0

    // Get all notebooks using listBundles.
    let notebooks = try await bundleManager.listBundles()

    for notebook in notebooks {
      do {
        let result = try await indexNotebook(notebookID: notebook.id)
        results.append(result)

        if result.success {
          successCount += 1
          totalChunks += result.chunksIndexed
        } else {
          failureCount += 1
        }
      } catch {
        failureCount += 1
        results.append(IndexingResult.failure(
          documentID: notebook.id,
          error: error.localizedDescription,
          duration: 0
        ))
      }
    }

    let duration = Date().timeIntervalSince(startTime)

    return BatchIndexingResult(
      totalDocuments: notebooks.count,
      successCount: successCount,
      failureCount: failureCount,
      totalChunksIndexed: totalChunks,
      results: results,
      duration: duration
    )
  }

  // Cancels all pending and in-progress indexing.
  func cancelAll() async {
    await indexingQueue.cancelAll()
  }

  // MARK: - Private Helpers

  // Extracts content based on document type.
  private func extractContent(for request: IndexRequest) async throws -> ExtractedContent {
    switch request {
    case .notebook(let notebookRequest):
      return try await extractNotebookContent(notebookRequest)
    case .pdf(let pdfRequest):
      return try await extractPDFContent(pdfRequest)
    }
  }

  // Extracts content from a notebook.
  private func extractNotebookContent(_ request: NotebookIndexRequest) async throws -> ExtractedContent {
    // Open the document handle.
    let handle = try await bundleManager.openNotebook(id: request.notebookID)

    // Load JIIX data.
    guard let jiixData = try await handle.loadJIIXData() else {
      // Close handle and return empty content.
      await handle.close(saveBeforeClose: false)
      return ExtractedContent.empty(
        documentID: request.notebookID,
        documentType: .notebook,
        displayName: request.displayName,
        modifiedAt: request.modifiedAt
      )
    }

    // Close handle after loading data.
    await handle.close(saveBeforeClose: false)

    // Extract content from JIIX.
    return try await contentExtractor.extractFromJIIX(
      data: jiixData,
      documentID: request.notebookID,
      displayName: request.displayName,
      modifiedAt: request.modifiedAt
    )
  }

  // Extracts content from a PDF.
  private func extractPDFContent(_ request: PDFIndexRequest) async throws -> ExtractedContent {
    // Get the PDF URL from storage.
    let documentURL = try await PDFNoteStorage.documentDirectory(
      for: UUID(uuidString: request.documentID) ?? UUID()
    )
    let pdfURL = documentURL.appendingPathComponent(ImportCoordinator.pdfFileName)

    // Check if PDF exists.
    guard FileManager.default.fileExists(atPath: pdfURL.path) else {
      throw IndexingError.documentNotFound(documentID: request.documentID)
    }

    // Try to load annotations JIIX.
    // Note: For now we just extract PDF text without annotations.
    // Full annotation extraction would require opening the MyScript package.
    let annotationsData: Data? = nil

    // Extract content from PDF with optional annotations.
    return try await contentExtractor.extractFromPDFWithAnnotations(
      pdfURL: pdfURL,
      annotationsData: annotationsData,
      documentID: request.documentID,
      displayName: request.displayName,
      modifiedAt: request.modifiedAt
    )
  }

  // Creates indexed chunks by combining chunks with embeddings.
  private func createIndexedChunks(
    chunks: [DocumentChunk],
    embeddings: [[Double]],
    modifiedAt: Date
  ) -> [IndexedChunk] {
    let now = Date()
    var indexedChunks: [IndexedChunk] = []

    for (index, chunk) in chunks.enumerated() {
      guard index < embeddings.count else { break }

      let indexedChunk = IndexedChunk(
        id: chunk.id,
        documentID: chunk.documentID,
        documentType: chunk.documentType,
        chunkIndex: chunk.chunkIndex,
        text: chunk.text,
        embedding: embeddings[index],
        tokenCount: chunk.tokenCount,
        displayName: chunk.displayName,
        modifiedAt: modifiedAt,
        indexedAt: now,
        pageNumber: chunk.pageNumber,
        blockTypes: chunk.blockTypes
      )
      indexedChunks.append(indexedChunk)
    }

    return indexedChunks
  }
}

// MARK: - Mock Indexing Coordinator

// Mock implementation for testing.
actor MockIndexingCoordinator: IndexingCoordinatorProtocol {

  // Records indexed requests.
  private(set) var indexedRequests: [IndexRequest] = []

  // Records removed document IDs.
  private(set) var removedDocumentIDs: [String] = []

  // Records scheduled requests.
  private(set) var scheduledRequests: [IndexRequest] = []

  // Whether cancelAll was called.
  private(set) var cancelAllCalled: Bool = false

  // Whether indexAllNotebooks was called.
  private(set) var indexAllNotebooksCalled: Bool = false

  // Error to throw on indexing.
  var errorToThrow: Error?

  // Mock result to return.
  var mockResult: IndexingResult?

  // Mock batch result to return.
  var mockBatchResult: BatchIndexingResult?

  func indexDocument(_ request: IndexRequest) async throws -> IndexingResult {
    if let error = errorToThrow {
      throw error
    }

    indexedRequests.append(request)

    return mockResult ?? IndexingResult.success(
      documentID: request.documentID,
      chunksIndexed: 1,
      duration: 0.1
    )
  }

  func indexNotebook(notebookID: String) async throws -> IndexingResult {
    let request = IndexRequest.notebook(NotebookIndexRequest(
      notebookID: notebookID,
      displayName: "Test Notebook",
      modifiedAt: Date()
    ))
    return try await indexDocument(request)
  }

  func removeDocument(documentID: String) async throws {
    if let error = errorToThrow {
      throw error
    }
    removedDocumentIDs.append(documentID)
  }

  func indexAllNotebooks() async throws -> BatchIndexingResult {
    if let error = errorToThrow {
      throw error
    }

    indexAllNotebooksCalled = true

    return mockBatchResult ?? BatchIndexingResult(
      totalDocuments: 0,
      successCount: 0,
      failureCount: 0,
      totalChunksIndexed: 0,
      results: [],
      duration: 0.1
    )
  }

  func scheduleIndexing(_ request: IndexRequest) async throws {
    if let error = errorToThrow {
      throw error
    }
    scheduledRequests.append(request)
  }

  func cancelAll() async {
    cancelAllCalled = true
  }

  // Resets all recorded state.
  func reset() {
    indexedRequests = []
    removedDocumentIDs = []
    scheduledRequests = []
    cancelAllCalled = false
    indexAllNotebooksCalled = false
    errorToThrow = nil
    mockResult = nil
    mockBatchResult = nil
  }

  // MARK: - Test Accessors

  // Gets the count of indexed requests.
  func getIndexedRequestsCount() -> Int {
    return indexedRequests.count
  }

  // Gets an indexed request at index.
  func getIndexedRequest(at index: Int) -> IndexRequest? {
    guard index < indexedRequests.count else { return nil }
    return indexedRequests[index]
  }

  // Checks if indexed requests is empty.
  func isIndexedRequestsEmpty() -> Bool {
    return indexedRequests.isEmpty
  }

  // Gets the count of removed document IDs.
  func getRemovedDocumentIDsCount() -> Int {
    return removedDocumentIDs.count
  }

  // Gets a removed document ID at index.
  func getRemovedDocumentID(at index: Int) -> String? {
    guard index < removedDocumentIDs.count else { return nil }
    return removedDocumentIDs[index]
  }

  // Checks if removed document IDs is empty.
  func isRemovedDocumentIDsEmpty() -> Bool {
    return removedDocumentIDs.isEmpty
  }

  // Gets the count of scheduled requests.
  func getScheduledRequestsCount() -> Int {
    return scheduledRequests.count
  }

  // Gets a scheduled request at index.
  func getScheduledRequest(at index: Int) -> IndexRequest? {
    guard index < scheduledRequests.count else { return nil }
    return scheduledRequests[index]
  }

  // Checks if scheduled requests is empty.
  func isScheduledRequestsEmpty() -> Bool {
    return scheduledRequests.isEmpty
  }

  // Gets the cancelAllCalled state.
  func getCancelAllCalled() -> Bool {
    return cancelAllCalled
  }

  // Gets the indexAllNotebooksCalled state.
  func getIndexAllNotebooksCalled() -> Bool {
    return indexAllNotebooksCalled
  }

  // Sets the error to throw.
  func setErrorToThrow(_ error: Error?) {
    errorToThrow = error
  }

  // Sets the mock result.
  func setMockResult(_ result: IndexingResult?) {
    mockResult = result
  }

  // Sets the mock batch result.
  func setMockBatchResult(_ result: BatchIndexingResult?) {
    mockBatchResult = result
  }
}
