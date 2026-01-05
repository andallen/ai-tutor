// IndexingCoordinatorTests.swift
// Tests for IndexingCoordinator functionality.

// swiftlint:disable file_length
// Comprehensive test coverage naturally results in longer test files.

import Foundation
import Testing

@testable import InkOS

// MARK: - MockContentExtractor

// Mock content extractor for testing.
actor MockContentExtractorForCoordinator: ContentExtractorProtocol {
  var mockContent: ExtractedContent?
  var errorToThrow: Error?
  private(set) var extractFromJIIXCalls: [Data] = []
  private(set) var extractFromPDFCalls: [URL] = []

  func extractFromJIIX(
    data: Data,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent {
    extractFromJIIXCalls.append(data)

    if let error = errorToThrow {
      throw error
    }

    return mockContent
      ?? ExtractedContent(
        text: "Mock extracted text",
        documentID: documentID,
        documentType: .notebook,
        displayName: displayName,
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: modifiedAt,
        pageNumber: nil
      )
  }

  func extractFromPDF(
    url: URL,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent {
    extractFromPDFCalls.append(url)

    if let error = errorToThrow {
      throw error
    }

    return mockContent
      ?? ExtractedContent(
        text: "Mock PDF text",
        documentID: documentID,
        documentType: .pdf,
        displayName: displayName,
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: modifiedAt,
        pageNumber: nil
      )
  }

  func extractFromPDFWithAnnotations(
    pdfURL: URL,
    annotationsData: Data?,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent {
    extractFromPDFCalls.append(pdfURL)

    if let error = errorToThrow {
      throw error
    }

    return mockContent
      ?? ExtractedContent(
        text: "Mock PDF with annotations",
        documentID: documentID,
        documentType: .pdf,
        displayName: displayName,
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: modifiedAt,
        pageNumber: nil
      )
  }

  func reset() {
    mockContent = nil
    errorToThrow = nil
    extractFromJIIXCalls = []
    extractFromPDFCalls = []
  }
}

// MARK: - MockChunkingService

// Mock chunking service for testing.
actor MockChunkingServiceForCoordinator: ChunkingServiceProtocol {
  var mockChunks: [DocumentChunk]?
  var errorToThrow: Error?
  private(set) var chunkContentCalls: [ExtractedContent] = []

  func chunkContent(_ content: ExtractedContent) throws -> [DocumentChunk] {
    chunkContentCalls.append(content)

    if let error = errorToThrow {
      throw error
    }

    return mockChunks ?? [
      DocumentChunk(
        id: UUID().uuidString,
        documentID: content.documentID,
        documentType: content.documentType,
        chunkIndex: 0,
        text: content.text,
        tokenCount: 50,
        displayName: content.displayName,
        modifiedAt: content.modifiedAt,
        pageNumber: nil,
        blockTypes: content.blockTypes
      )
    ]
  }

  func reset() {
    mockChunks = nil
    errorToThrow = nil
    chunkContentCalls = []
  }
}

// MARK: - MockIndexingCoordinator Tests

@Suite("MockIndexingCoordinator Tests")
struct MockIndexingCoordinatorTests {

  @Test("records indexed requests")
  func recordsIndexedRequests() async throws {
    let coordinator = MockIndexingCoordinator()

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    _ = try await coordinator.indexDocument(request)

    let count = await coordinator.getIndexedRequestsCount()
    let firstRequest = await coordinator.getIndexedRequest(at: 0)
    #expect(count == 1)
    #expect(firstRequest == request)
  }

  @Test("records removed document IDs")
  func recordsRemovedDocumentIDs() async throws {
    let coordinator = MockIndexingCoordinator()

    try await coordinator.removeDocument(documentID: "doc-1")

    let count = await coordinator.getRemovedDocumentIDsCount()
    let firstID = await coordinator.getRemovedDocumentID(at: 0)
    #expect(count == 1)
    #expect(firstID == "doc-1")
  }

  @Test("records scheduled requests")
  func recordsScheduledRequests() async throws {
    let coordinator = MockIndexingCoordinator()

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    try await coordinator.scheduleIndexing(request)

    let count = await coordinator.getScheduledRequestsCount()
    let firstRequest = await coordinator.getScheduledRequest(at: 0)
    #expect(count == 1)
    #expect(firstRequest == request)
  }

  @Test("records cancelAll called")
  func recordsCancelAllCalled() async {
    let coordinator = MockIndexingCoordinator()

    await coordinator.cancelAll()

    let called = await coordinator.getCancelAllCalled()
    #expect(called == true)
  }

  @Test("records indexAllNotebooks called")
  func recordsIndexAllNotebooksCalled() async throws {
    let coordinator = MockIndexingCoordinator()

    _ = try await coordinator.indexAllNotebooks()

    let called = await coordinator.getIndexAllNotebooksCalled()
    #expect(called == true)
  }

  @Test("throws configured error")
  func throwsConfiguredError() async {
    let coordinator = MockIndexingCoordinator()
    await coordinator.setErrorToThrow(IndexingError.documentNotFound(documentID: "doc-1"))

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    await #expect(throws: IndexingError.self) {
      _ = try await coordinator.indexDocument(request)
    }
  }

  @Test("returns mock result")
  func returnsMockResult() async throws {
    let coordinator = MockIndexingCoordinator()
    let mockResult = IndexingResult.success(documentID: "doc-1", chunksIndexed: 10, duration: 5.0)
    await coordinator.setMockResult(mockResult)

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    let result = try await coordinator.indexDocument(request)

    #expect(result.chunksIndexed == 10)
    #expect(result.duration == 5.0)
  }

  @Test("returns mock batch result")
  func returnsMockBatchResult() async throws {
    let coordinator = MockIndexingCoordinator()
    let mockBatch = BatchIndexingResult(
      totalDocuments: 5,
      successCount: 4,
      failureCount: 1,
      totalChunksIndexed: 20,
      results: [],
      duration: 10.0
    )
    await coordinator.setMockBatchResult(mockBatch)

    let result = try await coordinator.indexAllNotebooks()

    #expect(result.totalDocuments == 5)
    #expect(result.successCount == 4)
    #expect(result.totalChunksIndexed == 20)
  }

  @Test("reset clears state")
  func resetClearsState() async throws {
    let coordinator = MockIndexingCoordinator()

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    _ = try await coordinator.indexDocument(request)
    try await coordinator.removeDocument(documentID: "doc-1")
    await coordinator.cancelAll()

    await coordinator.reset()

    let indexedEmpty = await coordinator.isIndexedRequestsEmpty()
    let removedEmpty = await coordinator.isRemovedDocumentIDsEmpty()
    let cancelCalled = await coordinator.getCancelAllCalled()
    #expect(indexedEmpty)
    #expect(removedEmpty)
    #expect(cancelCalled == false)
  }
}

// MARK: - IndexingResult Factory Tests

@Suite("IndexingResult Factory Tests")
struct IndexingResultFactoryTests {

  @Test("success factory creates correct result")
  func successFactory() {
    let result = IndexingResult.success(
      documentID: "doc-1",
      chunksIndexed: 5,
      duration: 2.5
    )

    #expect(result.success == true)
    #expect(result.documentID == "doc-1")
    #expect(result.chunksIndexed == 5)
    #expect(result.duration == 2.5)
    #expect(result.errorMessage == nil)
  }

  @Test("failure factory creates correct result")
  func failureFactory() {
    let result = IndexingResult.failure(
      documentID: "doc-2",
      error: "Test error",
      duration: 1.0
    )

    #expect(result.success == false)
    #expect(result.documentID == "doc-2")
    #expect(result.chunksIndexed == 0)
    #expect(result.duration == 1.0)
    #expect(result.errorMessage == "Test error")
  }
}

// MARK: - Notification Key Tests

@Suite("IndexingNotificationKey Tests")
struct IndexingNotificationKeyTests {

  @Test("notification keys have expected values")
  func keyValues() {
    #expect(IndexingNotificationKey.documentID == "documentID")
    #expect(IndexingNotificationKey.result == "result")
    #expect(IndexingNotificationKey.error == "error")
    #expect(IndexingNotificationKey.progress == "progress")
  }
}

// MARK: - Error Handling Tests

@Suite("IndexingCoordinator Error Handling Tests")
struct IndexingCoordinatorErrorHandlingTests {

  @Test("throws documentNotFound error for removeDocument")
  func throwsDocumentNotFoundOnRemove() async {
    let coordinator = MockIndexingCoordinator()
    await coordinator.setErrorToThrow(IndexingError.documentNotFound(documentID: "missing-doc"))

    await #expect(throws: IndexingError.self) {
      try await coordinator.removeDocument(documentID: "missing-doc")
    }
  }

  @Test("throws error on scheduleIndexing")
  func throwsErrorOnSchedule() async {
    let coordinator = MockIndexingCoordinator()
    await coordinator.setErrorToThrow(IndexingError.queueFull(maxSize: 100))

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    await #expect(throws: IndexingError.self) {
      try await coordinator.scheduleIndexing(request)
    }
  }

  @Test("throws error on indexAllNotebooks")
  func throwsErrorOnIndexAll() async {
    let coordinator = MockIndexingCoordinator()
    await coordinator.setErrorToThrow(
      IndexingError.extractionFailed(documentID: "doc-1", reason: "Test"))

    await #expect(throws: IndexingError.self) {
      _ = try await coordinator.indexAllNotebooks()
    }
  }

  @Test("handles multiple sequential indexing requests")
  func handlesMultipleSequentialRequests() async throws {
    let coordinator = MockIndexingCoordinator()

    let requests = (0..<5).map { i in
      IndexRequest.notebook(
        NotebookIndexRequest(
          notebookID: "doc-\(i)",
          displayName: "Doc \(i)",
          modifiedAt: Date()
        ))
    }

    for request in requests {
      _ = try await coordinator.indexDocument(request)
    }

    let count = await coordinator.getIndexedRequestsCount()
    #expect(count == 5)
  }

  @Test("handles multiple remove operations")
  func handlesMultipleRemoveOperations() async throws {
    let coordinator = MockIndexingCoordinator()

    for i in 0..<3 {
      try await coordinator.removeDocument(documentID: "doc-\(i)")
    }

    let count = await coordinator.getRemovedDocumentIDsCount()
    #expect(count == 3)
  }

  @Test("indexNotebook delegates to indexDocument")
  func indexNotebookDelegates() async throws {
    let coordinator = MockIndexingCoordinator()

    _ = try await coordinator.indexNotebook(notebookID: "notebook-123")

    let count = await coordinator.getIndexedRequestsCount()
    #expect(count == 1)

    let request = await coordinator.getIndexedRequest(at: 0)
    #expect(request?.documentID == "notebook-123")
  }

  @Test("PDF request has correct document type")
  func pdfRequestHasCorrectType() async throws {
    let coordinator = MockIndexingCoordinator()

    let request = IndexRequest.pdf(
      PDFIndexRequest(
        documentID: "pdf-1",
        displayName: "Test PDF",
        modifiedAt: Date()
      ))

    _ = try await coordinator.indexDocument(request)

    let indexed = await coordinator.getIndexedRequest(at: 0)
    #expect(indexed?.documentType == .pdf)
  }

  @Test("failure result has zero chunks indexed")
  func failureResultHasZeroChunks() {
    let result = IndexingResult.failure(
      documentID: "failed-doc",
      error: "Network error",
      duration: 0.5
    )

    #expect(result.chunksIndexed == 0)
    #expect(result.success == false)
    #expect(result.errorMessage == "Network error")
  }

  @Test("batch result tracks all documents")
  func batchResultTracksAllDocuments() async throws {
    let coordinator = MockIndexingCoordinator()

    let mockBatch = BatchIndexingResult(
      totalDocuments: 10,
      successCount: 8,
      failureCount: 2,
      totalChunksIndexed: 40,
      results: [],
      duration: 30.0
    )
    await coordinator.setMockBatchResult(mockBatch)

    let result = try await coordinator.indexAllNotebooks()

    #expect(result.totalDocuments == 10)
    #expect(result.successCount + result.failureCount == result.totalDocuments)
  }
}

// MARK: - Mock Content Extractor Tests

@Suite("MockContentExtractor Tests")
struct MockContentExtractorTests {

  @Test("returns mock content when set")
  func returnsMockContent() async throws {
    let extractor = MockContentExtractorForCoordinator()

    let mockContent = ExtractedContent(
      text: "Custom mock text",
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Mock Doc",
      blockCount: 3,
      blockTypes: [.text, .math],
      modifiedAt: Date(),
      pageNumber: nil
    )
    await extractor.setMockContent(mockContent)

    let result = try await extractor.extractFromJIIX(
      data: Data(),
      documentID: "doc-1",
      displayName: "Test",
      modifiedAt: Date()
    )

    #expect(result.text == "Custom mock text")
    #expect(result.blockCount == 3)
  }

  @Test("throws configured error")
  func throwsConfiguredError() async {
    let extractor = MockContentExtractorForCoordinator()
    await extractor.setError(ExtractionError.jiixParsingFailed(reason: "Invalid JSON"))

    await #expect(throws: ExtractionError.self) {
      _ = try await extractor.extractFromJIIX(
        data: Data(),
        documentID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      )
    }
  }

  @Test("records extraction calls")
  func recordsExtractionCalls() async throws {
    let extractor = MockContentExtractorForCoordinator()

    let testData = Data("test".utf8)
    _ = try await extractor.extractFromJIIX(
      data: testData,
      documentID: "doc-1",
      displayName: "Test",
      modifiedAt: Date()
    )

    let calls = await extractor.getExtractFromJIIXCallsCount()
    #expect(calls == 1)
  }

  @Test("reset clears all state")
  func resetClearsState() async throws {
    let extractor = MockContentExtractorForCoordinator()

    // Set up some state.
    await extractor.setError(ExtractionError.documentNotFound(documentID: "doc-1"))
    _ = try? await extractor.extractFromJIIX(
      data: Data(),
      documentID: "doc-1",
      displayName: "Test",
      modifiedAt: Date()
    )

    await extractor.reset()

    // Should not throw after reset.
    let result = try await extractor.extractFromJIIX(
      data: Data(),
      documentID: "doc-1",
      displayName: "Test",
      modifiedAt: Date()
    )
    #expect(!result.text.isEmpty)
  }
}

// MARK: - Mock Chunking Service Tests

@Suite("MockChunkingService Tests")
struct MockChunkingServiceTests {

  @Test("returns mock chunks when set")
  func returnsMockChunks() async throws {
    let chunker = MockChunkingServiceForCoordinator()

    let mockChunks = [
      DocumentChunk(
        id: "chunk-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "First chunk",
        tokenCount: 10,
        displayName: "Test",
        modifiedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      ),
      DocumentChunk(
        id: "chunk-2",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 1,
        text: "Second chunk",
        tokenCount: 10,
        displayName: "Test",
        modifiedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )
    ]
    await chunker.setMockChunks(mockChunks)

    let content = ExtractedContent(
      text: "Test content",
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Test",
      blockCount: 1,
      blockTypes: [.text],
      modifiedAt: Date(),
      pageNumber: nil
    )

    let result = try await chunker.chunkContent(content)

    #expect(result.count == 2)
    #expect(result[0].text == "First chunk")
    #expect(result[1].text == "Second chunk")
  }

  @Test("throws configured error")
  func throwsConfiguredError() async {
    let chunker = MockChunkingServiceForCoordinator()
    await chunker.setError(ChunkingError.emptyInput)

    let content = ExtractedContent(
      text: "",
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Test",
      blockCount: 0,
      blockTypes: [],
      modifiedAt: Date(),
      pageNumber: nil
    )

    await #expect(throws: ChunkingError.self) {
      _ = try await chunker.chunkContent(content)
    }
  }

  @Test("records chunk calls")
  func recordsChunkCalls() async throws {
    let chunker = MockChunkingServiceForCoordinator()

    let content = ExtractedContent(
      text: "Test content",
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Test",
      blockCount: 1,
      blockTypes: [.text],
      modifiedAt: Date(),
      pageNumber: nil
    )

    _ = try await chunker.chunkContent(content)

    let calls = await chunker.getChunkContentCallsCount()
    #expect(calls == 1)
  }
}

// MARK: - Mock Accessor Extensions

extension MockContentExtractorForCoordinator {
  func setMockContent(_ content: ExtractedContent?) {
    mockContent = content
  }

  func setError(_ error: Error?) {
    errorToThrow = error
  }

  func getExtractFromJIIXCallsCount() -> Int {
    return extractFromJIIXCalls.count
  }

  func getExtractFromPDFCallsCount() -> Int {
    return extractFromPDFCalls.count
  }
}

extension MockChunkingServiceForCoordinator {
  func setMockChunks(_ chunks: [DocumentChunk]?) {
    mockChunks = chunks
  }

  func setError(_ error: Error?) {
    errorToThrow = error
  }

  func getChunkContentCallsCount() -> Int {
    return chunkContentCalls.count
  }
}
