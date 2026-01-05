// EmbeddingService.swift
// Service for generating text embeddings via Firebase Cloud Function.

import Foundation

// MARK: - Embedding Service Protocol

// Protocol for embedding generation services.
// Enables dependency injection and testing with mock implementations.
protocol EmbeddingServiceProtocol: Sendable {
  // Generates embeddings for an array of text chunks.
  // Returns 768-dimensional vectors for each text.
  func generateEmbeddings(
    texts: [String],
    taskType: EmbeddingTaskType
  ) async throws -> [[Double]]

  // Generates embedding for a single query text.
  // Uses RETRIEVAL_QUERY task type optimized for search.
  func generateQueryEmbedding(query: String) async throws -> [Double]
}

// MARK: - Embedding Service Actor

// Actor that handles embedding generation via Firebase Cloud Function.
// Uses text-embedding-005 model (768 dimensions).
actor EmbeddingService: EmbeddingServiceProtocol {

  // HTTP client for calling the Cloud Function.
  private let urlSession: URLSession

  // Base URL for Firebase Cloud Functions.
  private let functionsBaseURL: URL

  // Project ID for Firebase.
  private let projectID: String

  // Region where functions are deployed.
  private let region: String

  // Creates an embedding service with the specified configuration.
  init(
    projectID: String,
    region: String = "us-central1",
    urlSession: URLSession = .shared
  ) {
    self.projectID = projectID
    self.region = region
    self.urlSession = urlSession

    // Construct the base URL for callable functions.
    // Format: https://{region}-{project}.cloudfunctions.net
    let baseURLString = "https://\(region)-\(projectID).cloudfunctions.net"
    self.functionsBaseURL = URL(string: baseURLString)!
  }

  // Generates embeddings for multiple text chunks.
  // Batches texts in groups of 100 (max per request).
  func generateEmbeddings(
    texts: [String],
    taskType: EmbeddingTaskType = .retrievalDocument
  ) async throws -> [[Double]] {
    guard !texts.isEmpty else {
      return []
    }

    // Process in batches of max 100 texts.
    var allEmbeddings: [[Double]] = []
    let batchSize = VectorStoreConstants.maxTextsPerRequest

    for batchStart in stride(from: 0, to: texts.count, by: batchSize) {
      let batchEnd = min(batchStart + batchSize, texts.count)
      let batch = Array(texts[batchStart..<batchEnd])

      let embeddings = try await callEmbeddingFunction(
        texts: batch,
        taskType: taskType
      )
      allEmbeddings.append(contentsOf: embeddings)
    }

    return allEmbeddings
  }

  // Generates embedding for a single search query.
  // Uses RETRIEVAL_QUERY task type for optimal search performance.
  func generateQueryEmbedding(query: String) async throws -> [Double] {
    let embeddings = try await generateEmbeddings(
      texts: [query],
      taskType: .retrievalQuery
    )

    guard let embedding = embeddings.first else {
      throw VectorStoreError.embeddingGenerationFailed(
        reason: "No embedding returned for query"
      )
    }

    return embedding
  }

  // MARK: - Private Methods

  // Calls the Firebase Cloud Function to generate embeddings.
  private func callEmbeddingFunction(
    texts: [String],
    taskType: EmbeddingTaskType
  ) async throws -> [[Double]] {
    // Build the request URL for the callable function.
    let functionURL = functionsBaseURL.appendingPathComponent("generateEmbeddings")

    // Create the request body in Firebase callable format.
    let requestBody: [String: Any] = [
      "data": [
        "texts": texts,
        "taskType": taskType.rawValue
      ]
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

    // Build the HTTP request.
    var request = URLRequest(url: functionURL)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Execute the request.
    let (data, response) = try await urlSession.data(for: request)

    // Check for HTTP errors.
    guard let httpResponse = response as? HTTPURLResponse else {
      throw VectorStoreError.networkError(reason: "Invalid response type")
    }

    guard httpResponse.statusCode == 200 else {
      let errorMessage = parseErrorResponse(data: data)
      throw mapHTTPError(statusCode: httpResponse.statusCode, message: errorMessage)
    }

    // Parse the response.
    return try parseEmbeddingResponse(data: data)
  }

  // Parses the embedding response from the Cloud Function.
  // The response is wrapped in Firebase callable format: { "result": { "embeddings": [...] } }
  private func parseEmbeddingResponse(data: Data) throws -> [[Double]] {
    // Decode the Firebase callable response wrapper.
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let result = json["result"] as? [String: Any],
          let embeddings = result["embeddings"] as? [[Double]] else {
      throw VectorStoreError.embeddingGenerationFailed(
        reason: "Invalid response format from embedding function"
      )
    }

    // Validate embedding dimensions.
    for embedding in embeddings {
      if embedding.count != VectorStoreConstants.embeddingDimensions {
        throw VectorStoreError.invalidEmbeddingDimensions(
          expected: VectorStoreConstants.embeddingDimensions,
          received: embedding.count
        )
      }
    }

    return embeddings
  }

  // Parses error details from the response body.
  private func parseErrorResponse(data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let error = json["error"] as? [String: Any] {
      if let message = error["message"] as? String {
        return message
      }
      if let details = error["details"] as? String {
        return details
      }
    }
    return String(data: data, encoding: .utf8) ?? "Unknown error"
  }

  // Maps HTTP status codes to appropriate errors.
  private func mapHTTPError(statusCode: Int, message: String) -> VectorStoreError {
    switch statusCode {
    case 400:
      return .embeddingGenerationFailed(reason: "Invalid request: \(message)")
    case 401, 403:
      return .authenticationFailed
    case 429:
      return .rateLimitExceeded
    case 500..<600:
      return .embeddingGenerationFailed(reason: "Server error: \(message)")
    default:
      return .networkError(reason: "HTTP \(statusCode): \(message)")
    }
  }
}

// MARK: - Mock Embedding Service

// Mock implementation for testing without network calls.
final class MockEmbeddingService: EmbeddingServiceProtocol, @unchecked Sendable {

  // Fixed embedding to return for testing.
  var mockEmbedding: [Double]

  // Error to throw if set.
  var errorToThrow: Error?

  // Records texts that were requested.
  private(set) var requestedTexts: [[String]] = []

  // Records task types that were requested.
  private(set) var requestedTaskTypes: [EmbeddingTaskType] = []

  init(
    mockEmbedding: [Double]? = nil
  ) {
    // Default to a 768-dimensional zero vector.
    self.mockEmbedding = mockEmbedding ?? Array(repeating: 0.0, count: 768)
  }

  func generateEmbeddings(
    texts: [String],
    taskType: EmbeddingTaskType
  ) async throws -> [[Double]] {
    requestedTexts.append(texts)
    requestedTaskTypes.append(taskType)

    if let error = errorToThrow {
      throw error
    }

    return texts.map { _ in mockEmbedding }
  }

  func generateQueryEmbedding(query: String) async throws -> [Double] {
    let embeddings = try await generateEmbeddings(
      texts: [query],
      taskType: .retrievalQuery
    )
    return embeddings[0]
  }

  // Resets recorded state for testing.
  func reset() {
    requestedTexts = []
    requestedTaskTypes = []
    errorToThrow = nil
  }
}
