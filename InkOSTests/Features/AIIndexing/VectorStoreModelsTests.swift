// VectorStoreModelsTests.swift
// Tests for VectorStore data models.

import Foundation
import Testing

@testable import InkOS

// MARK: - IndexedChunk Tests

@Suite("IndexedChunk Tests")
struct IndexedChunkTests {

  // Helper to create a test chunk.
  private func createTestChunk(
    id: String = "chunk-1",
    documentID: String = "doc-1",
    chunkIndex: Int = 0,
    text: String = "Test text",
    embedding: [Double]? = nil
  ) -> IndexedChunk {
    return IndexedChunk(
      id: id,
      documentID: documentID,
      documentType: .notebook,
      chunkIndex: chunkIndex,
      text: text,
      embedding: embedding ?? Array(repeating: 0.1, count: 768),
      tokenCount: 5,
      displayName: "Test Document",
      modifiedAt: Date(),
      indexedAt: Date(),
      pageNumber: nil,
      blockTypes: [.text]
    )
  }

  @Test("indexed chunk is identifiable")
  func isIdentifiable() {
    let chunk = createTestChunk(id: "unique-chunk-id")
    #expect(chunk.id == "unique-chunk-id")
  }

  @Test("indexed chunk is equatable")
  func isEquatable() {
    let date = Date()
    let embedding = Array(repeating: 0.5, count: 768)

    let chunk1 = IndexedChunk(
      id: "id-1",
      documentID: "doc-1",
      documentType: .notebook,
      chunkIndex: 0,
      text: "Test",
      embedding: embedding,
      tokenCount: 1,
      displayName: "Test",
      modifiedAt: date,
      indexedAt: date,
      pageNumber: nil,
      blockTypes: [.text]
    )

    let chunk2 = IndexedChunk(
      id: "id-1",
      documentID: "doc-1",
      documentType: .notebook,
      chunkIndex: 0,
      text: "Test",
      embedding: embedding,
      tokenCount: 1,
      displayName: "Test",
      modifiedAt: date,
      indexedAt: date,
      pageNumber: nil,
      blockTypes: [.text]
    )

    #expect(chunk1 == chunk2)
  }

  @Test("indexed chunk stores 768-dimensional embedding")
  func stores768DimEmbedding() {
    let embedding = (0..<768).map { Double($0) / 768.0 }
    let chunk = createTestChunk(embedding: embedding)

    #expect(chunk.embedding.count == 768)
    #expect(chunk.embedding[0] == 0.0)
    #expect(chunk.embedding[767] == 767.0 / 768.0)
  }

  @Test("indexed chunk preserves document metadata")
  func preservesDocumentMetadata() {
    let modifiedDate = Date()
    let indexedDate = Date()

    let chunk = IndexedChunk(
      id: "chunk-id",
      documentID: "notebook-123",
      documentType: .pdf,
      chunkIndex: 5,
      text: "Content",
      embedding: Array(repeating: 0.0, count: 768),
      tokenCount: 100,
      displayName: "My PDF",
      modifiedAt: modifiedDate,
      indexedAt: indexedDate,
      pageNumber: 3,
      blockTypes: [.text, .math]
    )

    #expect(chunk.documentID == "notebook-123")
    #expect(chunk.documentType == .pdf)
    #expect(chunk.chunkIndex == 5)
    #expect(chunk.displayName == "My PDF")
    #expect(chunk.pageNumber == 3)
    #expect(chunk.blockTypes.contains(.text))
    #expect(chunk.blockTypes.contains(.math))
  }

  @Test("indexed chunk is sendable")
  func isSendable() async {
    let chunk = createTestChunk()

    let passedChunk = await Task.detached {
      return chunk
    }.value

    #expect(passedChunk.id == chunk.id)
  }
}

// MARK: - EmbeddingTaskType Tests

@Suite("EmbeddingTaskType Tests")
struct EmbeddingTaskTypeTests {

  @Test("retrieval document has correct raw value")
  func retrievalDocumentRawValue() {
    #expect(EmbeddingTaskType.retrievalDocument.rawValue == "RETRIEVAL_DOCUMENT")
  }

  @Test("retrieval query has correct raw value")
  func retrievalQueryRawValue() {
    #expect(EmbeddingTaskType.retrievalQuery.rawValue == "RETRIEVAL_QUERY")
  }

  @Test("semantic similarity has correct raw value")
  func semanticSimilarityRawValue() {
    #expect(EmbeddingTaskType.semanticSimilarity.rawValue == "SEMANTIC_SIMILARITY")
  }

  @Test("classification has correct raw value")
  func classificationRawValue() {
    #expect(EmbeddingTaskType.classification.rawValue == "CLASSIFICATION")
  }

  @Test("clustering has correct raw value")
  func clusteringRawValue() {
    #expect(EmbeddingTaskType.clustering.rawValue == "CLUSTERING")
  }

  @Test("is codable")
  func isCodable() throws {
    let original = EmbeddingTaskType.retrievalDocument
    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(EmbeddingTaskType.self, from: data)

    #expect(decoded == original)
  }
}

// MARK: - VectorSearchRequest Tests

@Suite("VectorSearchRequest Tests")
struct VectorSearchRequestTests {

  @Test("creates request with default values")
  func defaultValues() {
    let request = VectorSearchRequest(queryText: "test query")

    #expect(request.queryText == "test query")
    #expect(request.limit == 10)
    #expect(request.documentIDFilter == nil)
    #expect(request.minimumScore == nil)
  }

  @Test("creates request with custom values")
  func customValues() {
    let request = VectorSearchRequest(
      queryText: "search text",
      limit: 5,
      documentIDFilter: ["doc-1", "doc-2"],
      minimumScore: 0.8
    )

    #expect(request.limit == 5)
    #expect(request.documentIDFilter?.count == 2)
    #expect(request.minimumScore == 0.8)
  }
}

// MARK: - VectorSearchResult Tests

@Suite("VectorSearchResult Tests")
struct VectorSearchResultTests {

  @Test("result is identifiable via chunk id")
  func isIdentifiable() {
    let chunk = IndexedChunk(
      id: "result-chunk-id",
      documentID: "doc-1",
      documentType: .notebook,
      chunkIndex: 0,
      text: "Test",
      embedding: Array(repeating: 0.0, count: 768),
      tokenCount: 1,
      displayName: "Test",
      modifiedAt: Date(),
      indexedAt: Date(),
      pageNumber: nil,
      blockTypes: [.text]
    )

    let result = VectorSearchResult(chunk: chunk, score: 0.95)

    #expect(result.id == "result-chunk-id")
  }

  @Test("result includes similarity score")
  func includesScore() {
    let chunk = IndexedChunk(
      id: "id",
      documentID: "doc",
      documentType: .notebook,
      chunkIndex: 0,
      text: "Test",
      embedding: Array(repeating: 0.0, count: 768),
      tokenCount: 1,
      displayName: "Test",
      modifiedAt: Date(),
      indexedAt: Date(),
      pageNumber: nil,
      blockTypes: [.text]
    )

    let result = VectorSearchResult(chunk: chunk, score: 0.87)

    #expect(result.score == 0.87)
  }
}

// MARK: - VectorStoreError Tests

@Suite("VectorStoreError Tests")
struct VectorStoreErrorTests {

  @Test("embedding generation failed has correct description")
  func embeddingGenerationFailedDescription() {
    let error = VectorStoreError.embeddingGenerationFailed(reason: "API timeout")
    #expect(error.errorDescription?.contains("API timeout") == true)
  }

  @Test("firestore write failed has correct description")
  func firestoreWriteFailedDescription() {
    let error = VectorStoreError.firestoreWriteFailed(reason: "Permission denied")
    #expect(error.errorDescription?.contains("Permission denied") == true)
  }

  @Test("invalid embedding dimensions has correct description")
  func invalidEmbeddingDimensionsDescription() {
    let error = VectorStoreError.invalidEmbeddingDimensions(expected: 768, received: 512)
    #expect(error.errorDescription?.contains("768") == true)
    #expect(error.errorDescription?.contains("512") == true)
  }

  @Test("authentication failed has correct description")
  func authenticationFailedDescription() {
    let error = VectorStoreError.authenticationFailed
    #expect(error.errorDescription?.contains("authentication") == true)
  }

  @Test("rate limit exceeded has correct description")
  func rateLimitExceededDescription() {
    let error = VectorStoreError.rateLimitExceeded
    #expect(error.errorDescription?.contains("rate limit") == true)
  }

  @Test("errors are equatable")
  func errorsAreEquatable() {
    let error1 = VectorStoreError.authenticationFailed
    let error2 = VectorStoreError.authenticationFailed
    let error3 = VectorStoreError.rateLimitExceeded

    #expect(error1 == error2)
    #expect(error1 != error3)
  }
}

// MARK: - IndexingState Tests

@Suite("IndexingState Tests")
struct IndexingStateTests {

  @Test("all states have correct raw values")
  func rawValues() {
    #expect(IndexingState.pending.rawValue == "pending")
    #expect(IndexingState.extracting.rawValue == "extracting")
    #expect(IndexingState.chunking.rawValue == "chunking")
    #expect(IndexingState.embedding.rawValue == "embedding")
    #expect(IndexingState.storing.rawValue == "storing")
    #expect(IndexingState.completed.rawValue == "completed")
    #expect(IndexingState.failed.rawValue == "failed")
  }

  @Test("is codable")
  func isCodable() throws {
    let original = IndexingState.completed
    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(IndexingState.self, from: data)

    #expect(decoded == original)
  }
}

// MARK: - BatchUpsertResult Tests

@Suite("BatchUpsertResult Tests")
struct BatchUpsertResultTests {

  @Test("result tracks success and failure counts")
  func tracksCounts() {
    let result = BatchUpsertResult(
      successCount: 8,
      failureCount: 2,
      failures: [
        (chunkID: "chunk-1", error: "Error 1"),
        (chunkID: "chunk-2", error: "Error 2"),
      ]
    )

    #expect(result.successCount == 8)
    #expect(result.failureCount == 2)
    #expect(result.failures.count == 2)
  }

  @Test("failures include chunk ID and error message")
  func failuresIncludeDetails() {
    let result = BatchUpsertResult(
      successCount: 0,
      failureCount: 1,
      failures: [(chunkID: "failed-chunk", error: "Network timeout")]
    )

    #expect(result.failures[0].chunkID == "failed-chunk")
    #expect(result.failures[0].error == "Network timeout")
  }
}

// MARK: - BatchDeleteResult Tests

@Suite("BatchDeleteResult Tests")
struct BatchDeleteResultTests {

  @Test("successful delete result")
  func successfulDelete() {
    let result = BatchDeleteResult(
      deletedCount: 5,
      success: true,
      errorMessage: nil
    )

    #expect(result.deletedCount == 5)
    #expect(result.success == true)
    #expect(result.errorMessage == nil)
  }

  @Test("failed delete result includes error")
  func failedDelete() {
    let result = BatchDeleteResult(
      deletedCount: 2,
      success: false,
      errorMessage: "Some chunks could not be deleted"
    )

    #expect(result.success == false)
    #expect(result.errorMessage != nil)
  }
}

// MARK: - VectorStoreConstants Tests

@Suite("VectorStoreConstants Tests")
struct VectorStoreConstantsTests {

  @Test("chunks collection name is correct")
  func chunksCollectionName() {
    #expect(VectorStoreConstants.chunksCollection == "document_chunks")
  }

  @Test("embedding model is correct")
  func embeddingModel() {
    #expect(VectorStoreConstants.embeddingModel == "text-embedding-005")
  }

  @Test("embedding dimensions is 768")
  func embeddingDimensions() {
    #expect(VectorStoreConstants.embeddingDimensions == 768)
  }

  @Test("max texts per request is 100")
  func maxTextsPerRequest() {
    #expect(VectorStoreConstants.maxTextsPerRequest == 100)
  }

  @Test("max batch size is 500")
  func maxBatchSize() {
    #expect(VectorStoreConstants.maxBatchSize == 500)
  }

  @Test("default search limit is 10")
  func defaultSearchLimit() {
    #expect(VectorStoreConstants.defaultSearchLimit == 10)
  }
}
