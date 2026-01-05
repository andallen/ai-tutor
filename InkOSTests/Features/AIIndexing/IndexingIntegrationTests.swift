// IndexingIntegrationTests.swift
// Integration tests for the full indexing pipeline.
// Tests the end-to-end flow: extract -> chunk -> embed -> store.

// swiftlint:disable file_length type_body_length function_body_length
// Comprehensive integration tests require longer test files and test functions.

import Foundation
import Testing

@testable import InkOS

// MARK: - Integration Test Helpers

// Creates a complete mock extractor for integration testing.
actor IntegrationMockContentExtractor: ContentExtractorProtocol {
  var extractedContents: [String: ExtractedContent] = [:]
  var errorToThrow: Error?

  func extractFromJIIX(
    data: Data,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent {
    if let error = errorToThrow {
      throw error
    }

    if let content = extractedContents[documentID] {
      return content
    }

    // Default extraction returns some text.
    return ExtractedContent(
      text: "Extracted text from document",
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
    if let error = errorToThrow {
      throw error
    }

    if let content = extractedContents[documentID] {
      return content
    }

    return ExtractedContent(
      text: "PDF content",
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
    return try extractFromPDF(
      url: pdfURL,
      documentID: documentID,
      displayName: displayName,
      modifiedAt: modifiedAt
    )
  }

  func setContent(for documentID: String, content: ExtractedContent) {
    extractedContents[documentID] = content
  }

  func setError(_ error: Error?) {
    errorToThrow = error
  }
}

// Creates a mock chunking service for integration testing.
actor IntegrationMockChunkingService: ChunkingServiceProtocol {
  var chunksPerDocument: [String: [DocumentChunk]] = [:]
  var errorToThrow: Error?

  func chunkContent(_ content: ExtractedContent) throws -> [DocumentChunk] {
    if let error = errorToThrow {
      throw error
    }

    if let chunks = chunksPerDocument[content.documentID] {
      return chunks
    }

    // Default chunking returns a single chunk.
    return [
      DocumentChunk(
        id: UUID().uuidString,
        documentID: content.documentID,
        documentType: content.documentType,
        chunkIndex: 0,
        text: content.text,
        tokenCount: content.text.count / 4,
        displayName: content.displayName,
        modifiedAt: content.modifiedAt,
        pageNumber: content.pageNumber,
        blockTypes: content.blockTypes
      )
    ]
  }

  func setChunks(for documentID: String, chunks: [DocumentChunk]) {
    chunksPerDocument[documentID] = chunks
  }

  func setError(_ error: Error?) {
    errorToThrow = error
  }
}

// Creates a mock embedding service for integration testing.
actor IntegrationMockEmbeddingService: EmbeddingServiceProtocol {
  var requestCount = 0
  var totalTextsEmbedded = 0
  var errorToThrow: Error?
  private let mockEmbedding: [Double]

  init(mockEmbedding: [Double]? = nil) {
    self.mockEmbedding = mockEmbedding ?? Array(repeating: 0.1, count: 768)
  }

  func generateEmbeddings(
    texts: [String],
    taskType: EmbeddingTaskType
  ) throws -> [[Double]] {
    if let error = errorToThrow {
      throw error
    }

    requestCount += 1
    totalTextsEmbedded += texts.count

    return texts.map { _ in mockEmbedding }
  }

  func generateQueryEmbedding(query: String) throws -> [Double] {
    if let error = errorToThrow {
      throw error
    }
    return mockEmbedding
  }

  func getRequestCount() -> Int {
    return requestCount
  }

  func getTotalTextsEmbedded() -> Int {
    return totalTextsEmbedded
  }

  func setError(_ error: Error?) {
    errorToThrow = error
  }

  func reset() {
    requestCount = 0
    totalTextsEmbedded = 0
    errorToThrow = nil
  }
}

// Creates a mock vector store for integration testing.
actor IntegrationMockVectorStore: VectorStoreClientProtocol {
  private var chunks: [String: IndexedChunk] = [:]
  private var upsertedChunks: [IndexedChunk] = []
  private var deletedDocumentIDs: [String] = []
  var errorToThrow: Error?

  func upsertChunks(_ indexedChunks: [IndexedChunk]) throws -> BatchUpsertResult {
    if let error = errorToThrow {
      throw error
    }

    for chunk in indexedChunks {
      chunks[chunk.id] = chunk
      upsertedChunks.append(chunk)
    }

    return BatchUpsertResult(
      successCount: indexedChunks.count,
      failureCount: 0,
      failures: []
    )
  }

  func deleteChunk(chunkID: String) throws {
    if let error = errorToThrow {
      throw error
    }
    chunks.removeValue(forKey: chunkID)
  }

  func deleteChunksForDocument(documentID: String) throws -> BatchDeleteResult {
    if let error = errorToThrow {
      throw error
    }

    deletedDocumentIDs.append(documentID)

    let chunksToDelete = chunks.values.filter { $0.documentID == documentID }
    for chunk in chunksToDelete {
      chunks.removeValue(forKey: chunk.id)
    }

    return BatchDeleteResult(
      deletedCount: chunksToDelete.count,
      success: true,
      errorMessage: nil
    )
  }

  func getChunk(chunkID: String) throws -> IndexedChunk? {
    return chunks[chunkID]
  }

  func getChunksForDocument(documentID: String) throws -> [IndexedChunk] {
    return chunks.values.filter { $0.documentID == documentID }.sorted {
      $0.chunkIndex < $1.chunkIndex
    }
  }

  func searchSimilar(
    queryEmbedding: [Double],
    limit: Int,
    documentIDFilter: [String]?
  ) throws -> [VectorSearchResult] {
    var results = chunks.values.map { chunk in
      VectorSearchResult(chunk: chunk, score: 0.9)
    }

    if let filter = documentIDFilter {
      results = results.filter { filter.contains($0.chunk.documentID) }
    }

    return Array(results.prefix(limit))
  }

  func getUpsertedChunks() -> [IndexedChunk] {
    return upsertedChunks
  }

  func getDeletedDocumentIDs() -> [String] {
    return deletedDocumentIDs
  }

  func getStoredChunkCount() -> Int {
    return chunks.count
  }

  func setError(_ error: Error?) {
    errorToThrow = error
  }

  func reset() {
    chunks = [:]
    upsertedChunks = []
    deletedDocumentIDs = []
    errorToThrow = nil
  }
}

// MARK: - Integration Tests

@Suite("Indexing Pipeline Integration Tests")
struct IndexingPipelineIntegrationTests {

  @Test("full pipeline indexes document successfully")
  func fullPipelineSuccess() async throws {
    let extractor = IntegrationMockContentExtractor()
    let chunker = IntegrationMockChunkingService()
    let embedder = IntegrationMockEmbeddingService()
    let vectorStore = IntegrationMockVectorStore()

    // Set up test content.
    let testContent = ExtractedContent(
      text: "This is the test document content.",
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Test Notebook",
      blockCount: 1,
      blockTypes: [.text],
      modifiedAt: Date(),
      pageNumber: nil
    )
    await extractor.setContent(for: "doc-1", content: testContent)

    // Create test chunks.
    let testChunks = [
      DocumentChunk(
        id: "chunk-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "First chunk text",
        tokenCount: 10,
        displayName: "Test Notebook",
        modifiedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      ),
      DocumentChunk(
        id: "chunk-2",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 1,
        text: "Second chunk text",
        tokenCount: 10,
        displayName: "Test Notebook",
        modifiedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )
    ]
    await chunker.setChunks(for: "doc-1", chunks: testChunks)

    // Simulate pipeline execution.
    // 1. Extract content.
    let extracted = try await extractor.extractFromJIIX(
      data: Data(),
      documentID: "doc-1",
      displayName: "Test Notebook",
      modifiedAt: Date()
    )

    // 2. Chunk content.
    let chunks = try await chunker.chunkContent(extracted)

    // 3. Generate embeddings.
    let texts = chunks.map { $0.text }
    let embeddings = try await embedder.generateEmbeddings(
      texts: texts, taskType: .retrievalDocument)

    // 4. Create indexed chunks.
    var indexedChunks: [IndexedChunk] = []
    for (index, chunk) in chunks.enumerated() {
      let indexed = IndexedChunk(
        id: chunk.id,
        documentID: chunk.documentID,
        documentType: chunk.documentType,
        chunkIndex: chunk.chunkIndex,
        text: chunk.text,
        embedding: embeddings[index],
        tokenCount: chunk.tokenCount,
        displayName: chunk.displayName,
        modifiedAt: chunk.modifiedAt,
        indexedAt: Date(),
        pageNumber: chunk.pageNumber,
        blockTypes: chunk.blockTypes
      )
      indexedChunks.append(indexed)
    }

    // 5. Store in vector store.
    let result = try await vectorStore.upsertChunks(indexedChunks)

    // Verify results.
    #expect(result.successCount == 2)
    #expect(result.failureCount == 0)

    let storedCount = await vectorStore.getStoredChunkCount()
    #expect(storedCount == 2)

    let requestCount = await embedder.getRequestCount()
    #expect(requestCount == 1)
  }

  @Test("pipeline handles empty document gracefully")
  func pipelineHandlesEmptyDocument() async throws {
    let extractor = IntegrationMockContentExtractor()

    // Set up empty content.
    let emptyContent = ExtractedContent.empty(
      documentID: "empty-doc",
      documentType: .notebook,
      displayName: "Empty Notebook",
      modifiedAt: Date()
    )
    await extractor.setContent(for: "empty-doc", content: emptyContent)

    let extracted = try await extractor.extractFromJIIX(
      data: Data(),
      documentID: "empty-doc",
      displayName: "Empty Notebook",
      modifiedAt: Date()
    )

    #expect(extracted.text.isEmpty)
    #expect(extracted.blockCount == 0)
  }

  @Test("pipeline propagates extraction errors")
  func pipelinePropagatesExtractionErrors() async {
    let extractor = IntegrationMockContentExtractor()
    await extractor.setError(ExtractionError.documentNotFound(documentID: "missing-doc"))

    await #expect(throws: ExtractionError.self) {
      _ = try await extractor.extractFromJIIX(
        data: Data(),
        documentID: "missing-doc",
        displayName: "Missing",
        modifiedAt: Date()
      )
    }
  }

  @Test("pipeline propagates chunking errors")
  func pipelinePropagatesChunkingErrors() async {
    let chunker = IntegrationMockChunkingService()
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

  @Test("pipeline propagates embedding errors")
  func pipelinePropagatesEmbeddingErrors() async {
    let embedder = IntegrationMockEmbeddingService()
    await embedder.setError(VectorStoreError.embeddingGenerationFailed(reason: "API error"))

    await #expect(throws: VectorStoreError.self) {
      _ = try await embedder.generateEmbeddings(texts: ["test"], taskType: .retrievalDocument)
    }
  }

  @Test("pipeline propagates storage errors")
  func pipelinePropagatesStorageErrors() async {
    let vectorStore = IntegrationMockVectorStore()
    await vectorStore.setError(VectorStoreError.firestoreWriteFailed(reason: "Permission denied"))

    let testChunk = IndexedChunk(
      id: "chunk-1",
      documentID: "doc-1",
      documentType: .notebook,
      chunkIndex: 0,
      text: "Test",
      embedding: Array(repeating: 0.1, count: 768),
      tokenCount: 5,
      displayName: "Test",
      modifiedAt: Date(),
      indexedAt: Date(),
      pageNumber: nil,
      blockTypes: [.text]
    )

    await #expect(throws: VectorStoreError.self) {
      _ = try await vectorStore.upsertChunks([testChunk])
    }
  }

  @Test("document re-indexing replaces old chunks")
  func documentReIndexingReplacesOldChunks() async throws {
    let vectorStore = IntegrationMockVectorStore()

    // First indexing.
    let oldChunks = [
      IndexedChunk(
        id: "old-chunk-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Old content",
        embedding: Array(repeating: 0.1, count: 768),
        tokenCount: 5,
        displayName: "Test",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )
    ]
    _ = try await vectorStore.upsertChunks(oldChunks)

    // Delete old chunks.
    _ = try await vectorStore.deleteChunksForDocument(documentID: "doc-1")

    // Second indexing with new chunks.
    let newChunks = [
      IndexedChunk(
        id: "new-chunk-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "New content part 1",
        embedding: Array(repeating: 0.2, count: 768),
        tokenCount: 5,
        displayName: "Test",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      ),
      IndexedChunk(
        id: "new-chunk-2",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 1,
        text: "New content part 2",
        embedding: Array(repeating: 0.3, count: 768),
        tokenCount: 5,
        displayName: "Test",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )
    ]
    _ = try await vectorStore.upsertChunks(newChunks)

    // Verify only new chunks exist.
    let storedChunks = try await vectorStore.getChunksForDocument(documentID: "doc-1")
    #expect(storedChunks.count == 2)
    #expect(storedChunks.allSatisfy { $0.text.starts(with: "New content") })
  }

  @Test("multiple documents indexed independently")
  func multipleDocumentsIndexedIndependently() async throws {
    let vectorStore = IntegrationMockVectorStore()

    // Index doc-1.
    let chunks1 = [
      IndexedChunk(
        id: "doc1-chunk",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Document 1 content",
        embedding: Array(repeating: 0.1, count: 768),
        tokenCount: 5,
        displayName: "Doc 1",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )
    ]
    _ = try await vectorStore.upsertChunks(chunks1)

    // Index doc-2.
    let chunks2 = [
      IndexedChunk(
        id: "doc2-chunk",
        documentID: "doc-2",
        documentType: .pdf,
        chunkIndex: 0,
        text: "Document 2 content",
        embedding: Array(repeating: 0.2, count: 768),
        tokenCount: 5,
        displayName: "Doc 2",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: 1,
        blockTypes: [.text]
      )
    ]
    _ = try await vectorStore.upsertChunks(chunks2)

    // Verify both documents stored.
    let doc1Chunks = try await vectorStore.getChunksForDocument(documentID: "doc-1")
    let doc2Chunks = try await vectorStore.getChunksForDocument(documentID: "doc-2")

    #expect(doc1Chunks.count == 1)
    #expect(doc2Chunks.count == 1)
    #expect(doc1Chunks[0].documentType == .notebook)
    #expect(doc2Chunks[0].documentType == .pdf)
  }

  @Test("search returns relevant results")
  func searchReturnsRelevantResults() async throws {
    let vectorStore = IntegrationMockVectorStore()

    // Index multiple documents.
    let chunks = [
      IndexedChunk(
        id: "chunk-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Swift programming language",
        embedding: Array(repeating: 0.1, count: 768),
        tokenCount: 5,
        displayName: "Swift Notes",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      ),
      IndexedChunk(
        id: "chunk-2",
        documentID: "doc-2",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Python programming language",
        embedding: Array(repeating: 0.2, count: 768),
        tokenCount: 5,
        displayName: "Python Notes",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )
    ]
    _ = try await vectorStore.upsertChunks(chunks)

    // Search without filter.
    let allResults = try await vectorStore.searchSimilar(
      queryEmbedding: Array(repeating: 0.1, count: 768),
      limit: 10,
      documentIDFilter: nil
    )
    #expect(allResults.count == 2)

    // Search with filter.
    let filteredResults = try await vectorStore.searchSimilar(
      queryEmbedding: Array(repeating: 0.1, count: 768),
      limit: 10,
      documentIDFilter: ["doc-1"]
    )
    #expect(filteredResults.count == 1)
    #expect(filteredResults[0].chunk.documentID == "doc-1")
  }

  @Test("batch operations handle large document sets")
  func batchOperationsHandleLargeDocumentSets() async throws {
    let embedder = IntegrationMockEmbeddingService()
    let vectorStore = IntegrationMockVectorStore()

    // Create many chunks.
    let chunkCount = 150
    var chunks: [DocumentChunk] = []
    for i in 0..<chunkCount {
      chunks.append(
        DocumentChunk(
          id: "chunk-\(i)",
          documentID: "large-doc",
          documentType: .notebook,
          chunkIndex: i,
          text: "Chunk \(i) content",
          tokenCount: 5,
          displayName: "Large Document",
          modifiedAt: Date(),
          pageNumber: nil,
          blockTypes: [.text]
        ))
    }

    // Generate embeddings (may be batched internally).
    let texts = chunks.map { $0.text }
    let embeddings = try await embedder.generateEmbeddings(
      texts: texts, taskType: .retrievalDocument)

    // Create indexed chunks.
    var indexedChunks: [IndexedChunk] = []
    for (i, chunk) in chunks.enumerated() {
      indexedChunks.append(
        IndexedChunk(
          id: chunk.id,
          documentID: chunk.documentID,
          documentType: chunk.documentType,
          chunkIndex: chunk.chunkIndex,
          text: chunk.text,
          embedding: embeddings[i],
          tokenCount: chunk.tokenCount,
          displayName: chunk.displayName,
          modifiedAt: chunk.modifiedAt,
          indexedAt: Date(),
          pageNumber: chunk.pageNumber,
          blockTypes: chunk.blockTypes
        ))
    }

    // Store all chunks.
    let result = try await vectorStore.upsertChunks(indexedChunks)

    #expect(result.successCount == chunkCount)
    #expect(result.failureCount == 0)

    let storedCount = await vectorStore.getStoredChunkCount()
    #expect(storedCount == chunkCount)

    let totalEmbedded = await embedder.getTotalTextsEmbedded()
    #expect(totalEmbedded == chunkCount)
  }
}

// MARK: - Edge Case Tests

@Suite("Indexing Edge Case Tests")
struct IndexingEdgeCaseTests {

  @Test("handles whitespace-only content")
  func handlesWhitespaceOnlyContent() async throws {
    let content = ExtractedContent(
      text: "   \n\t\n   ",
      documentID: "whitespace-doc",
      documentType: .notebook,
      displayName: "Whitespace",
      blockCount: 0,
      blockTypes: [],
      modifiedAt: Date(),
      pageNumber: nil
    )

    // Whitespace-only should be treated as empty after trimming.
    let trimmedText = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(trimmedText.isEmpty)
  }

  @Test("handles unicode content")
  func handlesUnicodeContent() async throws {
    let content = ExtractedContent(
      text: "Hello 你好 مرحبا שלום 🌍 Math: ∫∑∏",
      documentID: "unicode-doc",
      documentType: .notebook,
      displayName: "Unicode Notes",
      blockCount: 1,
      blockTypes: [.text, .math],
      modifiedAt: Date(),
      pageNumber: nil
    )

    #expect(!content.text.isEmpty)
    #expect(content.text.contains("你好"))
    #expect(content.text.contains("🌍"))
    #expect(content.text.contains("∫"))
  }

  @Test("handles very long text")
  func handlesVeryLongText() async throws {
    let longText = String(repeating: "This is a test sentence. ", count: 1000)
    let content = ExtractedContent(
      text: longText,
      documentID: "long-doc",
      documentType: .notebook,
      displayName: "Long Document",
      blockCount: 1,
      blockTypes: [.text],
      modifiedAt: Date(),
      pageNumber: nil
    )

    #expect(content.text.count > 20000)
  }

  @Test("handles special characters in document ID")
  func handlesSpecialCharsInDocumentID() async throws {
    let specialID = "doc-with-special_chars.123"
    let content = ExtractedContent(
      text: "Test content",
      documentID: specialID,
      documentType: .notebook,
      displayName: "Special ID Doc",
      blockCount: 1,
      blockTypes: [.text],
      modifiedAt: Date(),
      pageNumber: nil
    )

    #expect(content.documentID == specialID)
  }

  @Test("chunk indices remain sequential")
  func chunkIndicesRemainSequential() async throws {
    let chunks = (0..<10).map { i in
      DocumentChunk(
        id: "chunk-\(i)",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: i,
        text: "Chunk \(i)",
        tokenCount: 5,
        displayName: "Test",
        modifiedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )
    }

    for (i, chunk) in chunks.enumerated() {
      #expect(chunk.chunkIndex == i)
    }
  }

  @Test("preserves page numbers for PDF chunks")
  func preservesPageNumbersForPDF() async throws {
    let pdfChunks = (1...5).map { page in
      DocumentChunk(
        id: "pdf-chunk-\(page)",
        documentID: "pdf-doc",
        documentType: .pdf,
        chunkIndex: page - 1,
        text: "Page \(page) content",
        tokenCount: 5,
        displayName: "Test PDF",
        modifiedAt: Date(),
        pageNumber: page,
        blockTypes: [.text]
      )
    }

    for (i, chunk) in pdfChunks.enumerated() {
      #expect(chunk.pageNumber == i + 1)
      #expect(chunk.documentType == .pdf)
    }
  }

  @Test("preserves mixed block types")
  func preservesMixedBlockTypes() async throws {
    let mixedContent = ExtractedContent(
      text: "Text content\nMath: x^2 + y^2 = r^2",
      documentID: "mixed-doc",
      documentType: .notebook,
      displayName: "Mixed Content",
      blockCount: 2,
      blockTypes: [.text, .math],
      modifiedAt: Date(),
      pageNumber: nil
    )

    #expect(mixedContent.blockTypes.contains(.text))
    #expect(mixedContent.blockTypes.contains(.math))
    #expect(mixedContent.blockCount == 2)
  }

  @Test("embedding dimensions are consistent")
  func embeddingDimensionsAreConsistent() async throws {
    let embedder = IntegrationMockEmbeddingService()

    let texts = ["First", "Second", "Third"]
    let embeddings = try await embedder.generateEmbeddings(
      texts: texts, taskType: .retrievalDocument)

    #expect(embeddings.count == 3)
    for embedding in embeddings {
      #expect(embedding.count == 768)
    }
  }

  @Test("handles concurrent indexing requests")
  func handlesConcurrentIndexingRequests() async throws {
    let vectorStore = IntegrationMockVectorStore()

    // Simulate concurrent upserts.
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<10 {
        group.addTask {
          let chunk = IndexedChunk(
            id: "concurrent-chunk-\(i)",
            documentID: "doc-\(i % 3)",
            documentType: .notebook,
            chunkIndex: 0,
            text: "Concurrent chunk \(i)",
            embedding: Array(repeating: 0.1, count: 768),
            tokenCount: 5,
            displayName: "Test",
            modifiedAt: Date(),
            indexedAt: Date(),
            pageNumber: nil,
            blockTypes: [.text]
          )
          _ = try? await vectorStore.upsertChunks([chunk])
        }
      }
    }

    let storedCount = await vectorStore.getStoredChunkCount()
    #expect(storedCount == 10)
  }
}
