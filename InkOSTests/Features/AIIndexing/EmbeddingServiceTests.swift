// EmbeddingServiceTests.swift
// Tests for EmbeddingService embedding generation.

import Foundation
import Testing

@testable import InkOS

// MARK: - Mock URL Protocol for Testing

// Custom URLProtocol to intercept and mock network requests.
final class MockURLProtocol: URLProtocol {
  // Handler to process requests and return mock responses.
  // Uses nonisolated(unsafe) for concurrent access in parallel tests.
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override static func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override static func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let handler = MockURLProtocol.requestHandler else {
      client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1))
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

// MARK: - EmbeddingService Tests

// Using .serialized to prevent race conditions with the shared MockURLProtocol.requestHandler.
@Suite("EmbeddingService Tests", .serialized)
struct EmbeddingServiceTests {

  // Creates a URLSession configured with mock protocol.
  private func createMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
  }

  // Creates a mock embedding response.
  // Returns valid JSON data for the embedding response.
  private func createMockEmbeddingResponse(count: Int) -> Data {
    let embeddings = (0..<count).map { _ in
      Array(repeating: 0.1, count: 768)
    }

    let response: [String: Any] = [
      "result": [
        "embeddings": embeddings,
        "model": "text-embedding-005",
        "dimensions": 768
      ]
    ]

    // This should always succeed with the known-good structure above.
    // Using do-catch to provide a fallback in case of unexpected issues.
    do {
      return try JSONSerialization.data(withJSONObject: response)
    } catch {
      // Return minimal valid response as fallback.
      return Data("{}".utf8)
    }
  }

  // Helper to create a valid HTTP response.
  private func createResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
    // Force unwrap is acceptable here as the URL string is a compile-time constant.
    // swiftlint:disable:next force_unwrapping
    let url = request.url ?? URL(string: "https://test.example.com")!
    return HTTPURLResponse(
      url: url,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    ) ?? HTTPURLResponse()
  }

  @Test("generates embeddings for single text")
  func generatesSingleEmbedding() async throws {
    let session = createMockSession()

    MockURLProtocol.requestHandler = { request in
      let response = self.createResponse(for: request, statusCode: 200)
      return (response, self.createMockEmbeddingResponse(count: 1))
    }

    let service = EmbeddingService(
      projectID: "test-project",
      urlSession: session
    )

    let embeddings = try await service.generateEmbeddings(
      texts: ["Hello world"],
      taskType: .retrievalDocument
    )

    #expect(embeddings.count == 1)
    #expect(embeddings[0].count == 768)
  }

  @Test("generates embeddings for multiple texts")
  func generatesMultipleEmbeddings() async throws {
    let session = createMockSession()

    // Return exactly 3 embeddings for the 3 texts we're sending.
    MockURLProtocol.requestHandler = { request in
      let response = self.createResponse(for: request, statusCode: 200)
      return (response, self.createMockEmbeddingResponse(count: 3))
    }

    let service = EmbeddingService(
      projectID: "test-project",
      urlSession: session
    )

    let texts = ["First text", "Second text", "Third text"]
    let embeddings = try await service.generateEmbeddings(
      texts: texts,
      taskType: .retrievalDocument
    )

    #expect(embeddings.count == 3)
  }

  @Test("returns empty array for empty input")
  func emptyInputReturnsEmpty() async throws {
    let service = EmbeddingService(projectID: "test-project")

    let embeddings = try await service.generateEmbeddings(
      texts: [],
      taskType: .retrievalDocument
    )

    #expect(embeddings.isEmpty)
  }

  @Test("generates query embedding returns single embedding")
  func generatesQueryEmbedding() async throws {
    let session = createMockSession()

    MockURLProtocol.requestHandler = { request in
      let response = self.createResponse(for: request, statusCode: 200)
      return (response, self.createMockEmbeddingResponse(count: 1))
    }

    let service = EmbeddingService(
      projectID: "test-project",
      urlSession: session
    )

    let embedding = try await service.generateQueryEmbedding(query: "What is the capital?")

    #expect(embedding.count == 768)
  }

  @Test("throws error on HTTP 401")
  func throwsOnUnauthorized() async {
    let session = createMockSession()

    MockURLProtocol.requestHandler = { request in
      let response = self.createResponse(for: request, statusCode: 401)
      let errorData = Data(
        """
        {"error": {"message": "Unauthorized"}}
        """.utf8)
      return (response, errorData)
    }

    let service = EmbeddingService(
      projectID: "test-project",
      urlSession: session
    )

    await #expect(throws: VectorStoreError.self) {
      _ = try await service.generateEmbeddings(
        texts: ["test"],
        taskType: .retrievalDocument
      )
    }
  }

  @Test("throws error on rate limit exceeded")
  func throwsOnRateLimit() async {
    let session = createMockSession()

    MockURLProtocol.requestHandler = { request in
      let response = self.createResponse(for: request, statusCode: 429)
      let errorData = Data("Rate limit exceeded".utf8)
      return (response, errorData)
    }

    let service = EmbeddingService(
      projectID: "test-project",
      urlSession: session
    )

    await #expect(throws: VectorStoreError.self) {
      _ = try await service.generateEmbeddings(
        texts: ["test"],
        taskType: .retrievalDocument
      )
    }
  }

  @Test("validates embedding dimensions")
  func validatesEmbeddingDimensions() async {
    let session = createMockSession()

    // Return embeddings with wrong dimensions.
    MockURLProtocol.requestHandler = { request in
      let wrongSizeEmbeddings = [[0.1, 0.2, 0.3]]  // Only 3 dimensions

      let responseBody: [String: Any] = [
        "result": [
          "embeddings": wrongSizeEmbeddings,
          "model": "text-embedding-005",
          "dimensions": 3
        ]
      ]

      let data: Data
      do {
        data = try JSONSerialization.data(withJSONObject: responseBody)
      } catch {
        data = Data()
      }

      let httpResponse = self.createResponse(for: request, statusCode: 200)
      return (httpResponse, data)
    }

    let service = EmbeddingService(
      projectID: "test-project",
      urlSession: session
    )

    await #expect(throws: VectorStoreError.self) {
      _ = try await service.generateEmbeddings(
        texts: ["test"],
        taskType: .retrievalDocument
      )
    }
  }

  @Test("batches requests for more than 100 texts")
  func batchesLargeRequests() async throws {
    let session = createMockSession()
    var requestCount = 0

    // Each batch returns 100 embeddings for the first batch, 50 for the second.
    MockURLProtocol.requestHandler = { request in
      requestCount += 1
      // First batch gets 100, second batch gets 50 (150 total).
      let batchSize = requestCount == 1 ? 100 : 50
      let response = self.createResponse(for: request, statusCode: 200)
      return (response, self.createMockEmbeddingResponse(count: batchSize))
    }

    let service = EmbeddingService(
      projectID: "test-project",
      urlSession: session
    )

    // Create 150 texts (should require 2 batches).
    let texts = (0..<150).map { "Text \($0)" }
    let embeddings = try await service.generateEmbeddings(
      texts: texts,
      taskType: .retrievalDocument
    )

    #expect(embeddings.count == 150)
    #expect(requestCount == 2)
  }
}

// MARK: - MockEmbeddingService Tests

@Suite("MockEmbeddingService Tests")
struct MockEmbeddingServiceTests {

  @Test("returns mock embeddings")
  func returnsMockEmbeddings() async throws {
    let mockEmbedding = Array(repeating: 0.5, count: 768)
    let service = MockEmbeddingService(mockEmbedding: mockEmbedding)

    let embeddings = try await service.generateEmbeddings(
      texts: ["test1", "test2"],
      taskType: .retrievalDocument
    )

    #expect(embeddings.count == 2)
    #expect(embeddings[0] == mockEmbedding)
    #expect(embeddings[1] == mockEmbedding)
  }

  @Test("records requested texts")
  func recordsRequestedTexts() async throws {
    let service = MockEmbeddingService()

    _ = try await service.generateEmbeddings(
      texts: ["Hello", "World"],
      taskType: .retrievalDocument
    )

    #expect(service.requestedTexts.count == 1)
    #expect(service.requestedTexts[0] == ["Hello", "World"])
  }

  @Test("records task types")
  func recordsTaskTypes() async throws {
    let service = MockEmbeddingService()

    _ = try await service.generateEmbeddings(
      texts: ["test"],
      taskType: .semanticSimilarity
    )

    #expect(service.requestedTaskTypes.count == 1)
    #expect(service.requestedTaskTypes[0] == .semanticSimilarity)
  }

  @Test("throws configured error")
  func throwsConfiguredError() async {
    let service = MockEmbeddingService()
    service.errorToThrow = VectorStoreError.networkError(reason: "Test error")

    await #expect(throws: VectorStoreError.self) {
      _ = try await service.generateEmbeddings(
        texts: ["test"],
        taskType: .retrievalDocument
      )
    }
  }

  @Test("reset clears state")
  func resetClearsState() async throws {
    let service = MockEmbeddingService()

    _ = try await service.generateEmbeddings(
      texts: ["test"],
      taskType: .retrievalDocument
    )

    service.reset()

    #expect(service.requestedTexts.isEmpty)
    #expect(service.requestedTaskTypes.isEmpty)
    #expect(service.errorToThrow == nil)
  }
}
