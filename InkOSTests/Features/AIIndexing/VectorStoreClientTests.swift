// VectorStoreClientTests.swift
// Tests for VectorStoreClient Firestore operations.

// swiftlint:disable force_unwrapping file_length function_body_length
// Force unwraps are acceptable in test code for creating test data.
// Comprehensive test coverage naturally results in longer test files and test functions.

import Foundation
import Testing

@testable import InkOS

// MARK: - Mock URL Protocol for VectorStoreClient Tests

// Custom URLProtocol to intercept and mock network requests for VectorStoreClient.
// Separate from EmbeddingServiceTests to avoid shared state conflicts in parallel testing.
final class VectorStoreMockURLProtocol: URLProtocol {
  // Handler to process requests and return mock responses.
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override static func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override static func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let handler = VectorStoreMockURLProtocol.requestHandler else {
      client?.urlProtocol(
        self, didFailWithError: NSError(domain: "VectorStoreMockURLProtocol", code: -1))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

// MARK: - VectorStoreClient Tests

// Using .serialized to prevent race conditions with the shared VectorStoreMockURLProtocol.requestHandler.
@Suite("VectorStoreClient Tests", .serialized)
struct VectorStoreClientTests {

  // Creates a test chunk for use in tests.
  private func createTestChunk(
    id: String = "test-chunk-1",
    documentID: String = "doc-1",
    chunkIndex: Int = 0,
    text: String = "Test content"
  ) -> IndexedChunk {
    return IndexedChunk(
      id: id,
      documentID: documentID,
      documentType: .notebook,
      chunkIndex: chunkIndex,
      text: text,
      embedding: Array(repeating: 0.1, count: 768),
      tokenCount: 5,
      displayName: "Test Document",
      modifiedAt: Date(),
      indexedAt: Date(),
      pageNumber: nil,
      blockTypes: [.text]
    )
  }

  // Creates a URLSession configured with mock protocol.
  private func createMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [VectorStoreMockURLProtocol.self]
    return URLSession(configuration: config)
  }

  @Suite("Upsert Operations")
  struct UpsertOperationsTests {

    private func createTestChunk(id: String = "chunk-1") -> IndexedChunk {
      return IndexedChunk(
        id: id,
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
    }

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [VectorStoreMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    @Test("upserts single chunk successfully")
    func upsertsSingleChunk() async throws {
      let session = createMockSession()

      VectorStoreMockURLProtocol.requestHandler = { request in
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path.contains("document_chunks/chunk-1") == true)

        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data("{}".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      let chunk = createTestChunk()
      let result = try await client.upsertChunks([chunk])

      #expect(result.successCount == 1)
      #expect(result.failureCount == 0)
    }

    @Test("upserts multiple chunks")
    func upsertsMultipleChunks() async throws {
      let session = createMockSession()

      VectorStoreMockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data("{}".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      let chunks = (0..<5).map { createTestChunk(id: "chunk-\($0)") }
      let result = try await client.upsertChunks(chunks)

      #expect(result.successCount == 5)
      #expect(result.failureCount == 0)
    }

    @Test("returns empty result for empty input")
    func emptyInputReturnsEmptyResult() async throws {
      let session = createMockSession()

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      let result = try await client.upsertChunks([])

      #expect(result.successCount == 0)
      #expect(result.failureCount == 0)
    }

    @Test("records failures for failed upserts")
    func recordsFailures() async throws {
      let session = createMockSession()
      var requestCount = 0

      VectorStoreMockURLProtocol.requestHandler = { request in
        requestCount += 1
        // Fail every other request.
        let statusCode = requestCount % 2 == 0 ? 500 : 200

        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: statusCode,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data("{}".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      let chunks = (0..<4).map { createTestChunk(id: "chunk-\($0)") }
      let result = try await client.upsertChunks(chunks)

      #expect(result.successCount == 2)
      #expect(result.failureCount == 2)
    }
  }

  @Suite("Delete Operations")
  struct DeleteOperationsTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [VectorStoreMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    @Test("deletes single chunk")
    func deletesSingleChunk() async throws {
      let session = createMockSession()

      VectorStoreMockURLProtocol.requestHandler = { request in
        #expect(request.httpMethod == "DELETE")

        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data("{}".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      try await client.deleteChunk(chunkID: "chunk-to-delete")
      // No error thrown means success.
    }

    @Test("handles 404 as success for delete")
    func handles404AsSuccess() async throws {
      let session = createMockSession()

      VectorStoreMockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 404,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data("{}".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      // Should not throw for 404.
      try await client.deleteChunk(chunkID: "nonexistent-chunk")
    }

    @Test("throws error on delete failure")
    func throwsOnDeleteFailure() async {
      let session = createMockSession()

      VectorStoreMockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 500,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data("Server error".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      await #expect(throws: VectorStoreError.self) {
        try await client.deleteChunk(chunkID: "chunk-id")
      }
    }
  }

  @Suite("Query Operations")
  struct QueryOperationsTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [VectorStoreMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    @Test("returns nil for nonexistent chunk")
    func returnsNilForNonexistent() async throws {
      let session = createMockSession()

      VectorStoreMockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 404,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data("{}".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      let chunk = try await client.getChunk(chunkID: "nonexistent")
      #expect(chunk == nil)
    }

    @Test("returns empty array for document with no chunks")
    func returnsEmptyForNoChunks() async throws {
      let session = createMockSession()

      VectorStoreMockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        // Empty query result.
        return (response, Data("[]".utf8))
      }

      let client = VectorStoreClient(
        projectID: "test-project",
        apiKey: "test-key",
        urlSession: session
      )

      let chunks = try await client.getChunksForDocument(documentID: "empty-doc")
      #expect(chunks.isEmpty)
    }
  }
}

// MARK: - MockVectorStoreClient Tests

@Suite("MockVectorStoreClient Tests")
struct MockVectorStoreClientTests {

  private func createTestChunk(
    id: String = "chunk-1",
    documentID: String = "doc-1"
  ) -> IndexedChunk {
    return IndexedChunk(
      id: id,
      documentID: documentID,
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
  }

  @Test("upserts and retrieves chunks")
  func upsertsAndRetrieves() async throws {
    let client = MockVectorStoreClient()
    let chunk = createTestChunk()

    _ = try await client.upsertChunks([chunk])
    let retrieved = try await client.getChunk(chunkID: "chunk-1")

    #expect(retrieved != nil)
    #expect(retrieved?.id == "chunk-1")
  }

  @Test("deletes chunks by document ID")
  func deletesByDocumentID() async throws {
    let client = MockVectorStoreClient()

    // Add chunks for different documents.
    client.addChunk(createTestChunk(id: "chunk-1", documentID: "doc-1"))
    client.addChunk(createTestChunk(id: "chunk-2", documentID: "doc-1"))
    client.addChunk(createTestChunk(id: "chunk-3", documentID: "doc-2"))

    let result = try await client.deleteChunksForDocument(documentID: "doc-1")

    #expect(result.deletedCount == 2)
    #expect(result.success == true)

    let remainingForDoc1 = try await client.getChunksForDocument(documentID: "doc-1")
    let remainingForDoc2 = try await client.getChunksForDocument(documentID: "doc-2")

    #expect(remainingForDoc1.isEmpty)
    #expect(remainingForDoc2.count == 1)
  }

  @Test("searches with document filter")
  func searchesWithFilter() async throws {
    let client = MockVectorStoreClient()

    client.addChunk(createTestChunk(id: "chunk-1", documentID: "doc-1"))
    client.addChunk(createTestChunk(id: "chunk-2", documentID: "doc-2"))
    client.addChunk(createTestChunk(id: "chunk-3", documentID: "doc-3"))

    let queryEmbedding = Array(repeating: 0.0, count: 768)
    let results = try await client.searchSimilar(
      queryEmbedding: queryEmbedding,
      limit: 10,
      documentIDFilter: ["doc-1", "doc-2"]
    )

    #expect(results.count == 2)
    #expect(results.allSatisfy { ["doc-1", "doc-2"].contains($0.chunk.documentID) })
  }

  @Test("respects search limit")
  func respectsSearchLimit() async throws {
    let client = MockVectorStoreClient()

    // Add 10 chunks.
    for i in 0..<10 {
      client.addChunk(createTestChunk(id: "chunk-\(i)", documentID: "doc-1"))
    }

    let queryEmbedding = Array(repeating: 0.0, count: 768)
    let results = try await client.searchSimilar(
      queryEmbedding: queryEmbedding,
      limit: 3,
      documentIDFilter: nil
    )

    #expect(results.count == 3)
  }

  @Test("records upserted chunks")
  func recordsUpsertedChunks() async throws {
    let client = MockVectorStoreClient()
    let chunks = [
      createTestChunk(id: "chunk-1"),
      createTestChunk(id: "chunk-2")
    ]

    _ = try await client.upsertChunks(chunks)

    #expect(client.upsertedChunks.count == 2)
  }

  @Test("records deleted chunk IDs")
  func recordsDeletedChunkIDs() async throws {
    let client = MockVectorStoreClient()
    client.addChunk(createTestChunk(id: "chunk-1"))

    try await client.deleteChunk(chunkID: "chunk-1")

    #expect(client.deletedChunkIDs.contains("chunk-1"))
  }

  @Test("records search queries")
  func recordsSearchQueries() async throws {
    let client = MockVectorStoreClient()
    let queryEmbedding = Array(repeating: 0.5, count: 768)

    _ = try await client.searchSimilar(
      queryEmbedding: queryEmbedding,
      limit: 5,
      documentIDFilter: nil
    )

    #expect(client.searchQueries.count == 1)
    #expect(client.searchQueries[0].limit == 5)
  }

  @Test("throws configured error")
  func throwsConfiguredError() async {
    let client = MockVectorStoreClient()
    client.errorToThrow = VectorStoreError.firestoreWriteFailed(reason: "Test")

    await #expect(throws: VectorStoreError.self) {
      _ = try await client.upsertChunks([createTestChunk()])
    }
  }

  @Test("reset clears all state")
  func resetClearsState() async throws {
    let client = MockVectorStoreClient()

    client.addChunk(createTestChunk())
    _ = try await client.upsertChunks([createTestChunk(id: "chunk-2")])
    try await client.deleteChunk(chunkID: "chunk-1")

    client.reset()

    #expect(client.upsertedChunks.isEmpty)
    #expect(client.deletedChunkIDs.isEmpty)
    #expect(client.searchQueries.isEmpty)

    let chunks = try await client.getChunksForDocument(documentID: "doc-1")
    #expect(chunks.isEmpty)
  }

  @Test("gets chunks for document sorted by index")
  func getsChunksSortedByIndex() async throws {
    let client = MockVectorStoreClient()

    // Add chunks out of order.
    client.addChunk(
      IndexedChunk(
        id: "chunk-2",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 2,
        text: "Third",
        embedding: Array(repeating: 0.1, count: 768),
        tokenCount: 5,
        displayName: "Test",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      ))
    client.addChunk(
      IndexedChunk(
        id: "chunk-0",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "First",
        embedding: Array(repeating: 0.1, count: 768),
        tokenCount: 5,
        displayName: "Test",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      ))
    client.addChunk(
      IndexedChunk(
        id: "chunk-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 1,
        text: "Second",
        embedding: Array(repeating: 0.1, count: 768),
        tokenCount: 5,
        displayName: "Test",
        modifiedAt: Date(),
        indexedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      ))

    let chunks = try await client.getChunksForDocument(documentID: "doc-1")

    #expect(chunks.count == 3)
    #expect(chunks[0].chunkIndex == 0)
    #expect(chunks[1].chunkIndex == 1)
    #expect(chunks[2].chunkIndex == 2)
  }
}
