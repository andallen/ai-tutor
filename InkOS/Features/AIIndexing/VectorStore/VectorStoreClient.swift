// VectorStoreClient.swift
// Client for storing and querying document chunks in Firestore.

import Foundation

// MARK: - Vector Store Protocol

// Protocol for vector store operations.
// Enables dependency injection and testing with mock implementations.
protocol VectorStoreClientProtocol: Sendable {
  // Upserts chunks with embeddings to the vector store.
  func upsertChunks(_ chunks: [IndexedChunk]) async throws -> BatchUpsertResult

  // Deletes all chunks for a specific document.
  func deleteChunksForDocument(documentID: String) async throws -> BatchDeleteResult

  // Deletes a specific chunk by ID.
  func deleteChunk(chunkID: String) async throws

  // Retrieves all chunks for a specific document.
  func getChunksForDocument(documentID: String) async throws -> [IndexedChunk]

  // Retrieves a specific chunk by ID.
  func getChunk(chunkID: String) async throws -> IndexedChunk?

  // Performs vector similarity search.
  func searchSimilar(
    queryEmbedding: [Double],
    limit: Int,
    documentIDFilter: [String]?
  ) async throws -> [VectorSearchResult]
}

// MARK: - Vector Store Client Actor

// Actor that manages Firestore operations for document chunks.
// Uses Firestore REST API for vector storage and search.
actor VectorStoreClient: VectorStoreClientProtocol {

  // HTTP client for Firestore REST API.
  private let urlSession: URLSession

  // Firebase project ID.
  private let projectID: String

  // Firestore database ID (default is "(default)").
  private let databaseID: String

  // API key for Firestore access.
  private let apiKey: String

  // Base URL for Firestore REST API.
  private let baseURL: URL

  // JSON encoder configured for Firestore format.
  private let encoder: JSONEncoder

  // JSON decoder configured for Firestore format.
  private let decoder: JSONDecoder

  // Creates a vector store client with the specified configuration.
  init(
    projectID: String,
    apiKey: String,
    databaseID: String = "(default)",
    urlSession: URLSession = .shared
  ) {
    self.projectID = projectID
    self.apiKey = apiKey
    self.databaseID = databaseID
    self.urlSession = urlSession

    // Construct the base URL for Firestore REST API.
    let baseURLString = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/\(databaseID)/documents"
    self.baseURL = URL(string: baseURLString)!

    // Configure encoder for ISO8601 dates.
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601

    // Configure decoder for ISO8601 dates.
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  // MARK: - Upsert Operations

  // Upserts chunks with embeddings to Firestore.
  // Uses batched writes for efficiency.
  func upsertChunks(_ chunks: [IndexedChunk]) async throws -> BatchUpsertResult {
    var successCount = 0
    var failures: [(chunkID: String, error: String)] = []

    // Process chunks individually for now.
    // Firestore batch writes require transactions which are complex via REST.
    for chunk in chunks {
      do {
        try await upsertSingleChunk(chunk)
        successCount += 1
      } catch {
        failures.append((chunkID: chunk.id, error: error.localizedDescription))
      }
    }

    return BatchUpsertResult(
      successCount: successCount,
      failureCount: failures.count,
      failures: failures
    )
  }

  // Upserts a single chunk to Firestore.
  private func upsertSingleChunk(_ chunk: IndexedChunk) async throws {
    // Build the document path.
    let documentPath = "\(VectorStoreConstants.chunksCollection)/\(chunk.id)"
    var urlComponents = URLComponents(url: baseURL.appendingPathComponent(documentPath), resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

    guard let url = urlComponents.url else {
      throw VectorStoreError.firestoreWriteFailed(reason: "Invalid URL")
    }

    // Convert chunk to Firestore document format.
    let firestoreDoc = chunkToFirestoreDocument(chunk)
    let jsonData = try JSONSerialization.data(withJSONObject: ["fields": firestoreDoc])

    // Create PATCH request (upsert behavior).
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw VectorStoreError.firestoreWriteFailed(reason: "Invalid response type")
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw VectorStoreError.firestoreWriteFailed(
        reason: "HTTP \(httpResponse.statusCode): \(errorMsg)"
      )
    }
  }

  // MARK: - Delete Operations

  // Deletes all chunks for a document.
  func deleteChunksForDocument(documentID: String) async throws -> BatchDeleteResult {
    // First, query for all chunks with this document ID.
    let chunks = try await getChunksForDocument(documentID: documentID)

    if chunks.isEmpty {
      return BatchDeleteResult(deletedCount: 0, success: true, errorMessage: nil)
    }

    var deletedCount = 0
    var errors: [String] = []

    for chunk in chunks {
      do {
        try await deleteChunk(chunkID: chunk.id)
        deletedCount += 1
      } catch {
        errors.append("Failed to delete \(chunk.id): \(error.localizedDescription)")
      }
    }

    return BatchDeleteResult(
      deletedCount: deletedCount,
      success: errors.isEmpty,
      errorMessage: errors.isEmpty ? nil : errors.joined(separator: "; ")
    )
  }

  // Deletes a single chunk by ID.
  func deleteChunk(chunkID: String) async throws {
    let documentPath = "\(VectorStoreConstants.chunksCollection)/\(chunkID)"
    var urlComponents = URLComponents(url: baseURL.appendingPathComponent(documentPath), resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

    guard let url = urlComponents.url else {
      throw VectorStoreError.firestoreDeleteFailed(reason: "Invalid URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw VectorStoreError.firestoreDeleteFailed(reason: "Invalid response type")
    }

    // 404 is acceptable (document already deleted).
    guard httpResponse.statusCode == 200 || httpResponse.statusCode == 404 else {
      let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw VectorStoreError.firestoreDeleteFailed(
        reason: "HTTP \(httpResponse.statusCode): \(errorMsg)"
      )
    }
  }

  // MARK: - Query Operations

  // Retrieves all chunks for a document.
  func getChunksForDocument(documentID: String) async throws -> [IndexedChunk] {
    // Build structured query.
    let query: [String: Any] = [
      "structuredQuery": [
        "from": [["collectionId": VectorStoreConstants.chunksCollection]],
        "where": [
          "fieldFilter": [
            "field": ["fieldPath": "documentID"],
            "op": "EQUAL",
            "value": ["stringValue": documentID]
          ]
        ],
        "orderBy": [
          ["field": ["fieldPath": "chunkIndex"], "direction": "ASCENDING"]
        ]
      ]
    ]

    let runQueryURL = baseURL
      .deletingLastPathComponent()
      .appendingPathComponent("documents:runQuery")
    var urlComponents = URLComponents(url: runQueryURL, resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

    guard let url = urlComponents.url else {
      throw VectorStoreError.firestoreReadFailed(reason: "Invalid URL")
    }

    let jsonData = try JSONSerialization.data(withJSONObject: query)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw VectorStoreError.firestoreReadFailed(reason: "Invalid response type")
    }

    guard httpResponse.statusCode == 200 else {
      let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw VectorStoreError.firestoreReadFailed(
        reason: "HTTP \(httpResponse.statusCode): \(errorMsg)"
      )
    }

    return try parseQueryResponse(data: data)
  }

  // Retrieves a single chunk by ID.
  func getChunk(chunkID: String) async throws -> IndexedChunk? {
    let documentPath = "\(VectorStoreConstants.chunksCollection)/\(chunkID)"
    var urlComponents = URLComponents(url: baseURL.appendingPathComponent(documentPath), resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

    guard let url = urlComponents.url else {
      throw VectorStoreError.firestoreReadFailed(reason: "Invalid URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw VectorStoreError.firestoreReadFailed(reason: "Invalid response type")
    }

    // 404 means chunk doesn't exist.
    if httpResponse.statusCode == 404 {
      return nil
    }

    guard httpResponse.statusCode == 200 else {
      let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw VectorStoreError.firestoreReadFailed(
        reason: "HTTP \(httpResponse.statusCode): \(errorMsg)"
      )
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let fields = json["fields"] as? [String: Any] else {
      throw VectorStoreError.firestoreReadFailed(reason: "Invalid document format")
    }

    return try firestoreDocumentToChunk(fields, chunkID: chunkID)
  }

  // MARK: - Vector Search

  // Performs vector similarity search using Firestore vector search.
  // Note: This requires a vector index to be configured in Firestore.
  func searchSimilar(
    queryEmbedding: [Double],
    limit: Int = VectorStoreConstants.defaultSearchLimit,
    documentIDFilter: [String]? = nil
  ) async throws -> [VectorSearchResult] {
    // Build the vector search query.
    // Firestore vector search uses findNearest in structured queries.
    var query: [String: Any] = [
      "structuredQuery": [
        "from": [["collectionId": VectorStoreConstants.chunksCollection]],
        "findNearest": [
          "vectorField": ["fieldPath": "embedding"],
          "queryVector": ["doubleValue": queryEmbedding],
          "limit": limit,
          "distanceMeasure": "COSINE"
        ]
      ]
    ]

    // Add document ID filter if specified.
    if let filterIDs = documentIDFilter, !filterIDs.isEmpty {
      let structuredQuery = query["structuredQuery"] as! [String: Any]
      var updatedQuery = structuredQuery
      updatedQuery["where"] = [
        "fieldFilter": [
          "field": ["fieldPath": "documentID"],
          "op": "IN",
          "value": ["arrayValue": ["values": filterIDs.map { ["stringValue": $0] }]]
        ]
      ]
      query["structuredQuery"] = updatedQuery
    }

    let runQueryURL = baseURL
      .deletingLastPathComponent()
      .appendingPathComponent("documents:runQuery")
    var urlComponents = URLComponents(url: runQueryURL, resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

    guard let url = urlComponents.url else {
      throw VectorStoreError.vectorSearchFailed(reason: "Invalid URL")
    }

    let jsonData = try JSONSerialization.data(withJSONObject: query)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw VectorStoreError.vectorSearchFailed(reason: "Invalid response type")
    }

    guard httpResponse.statusCode == 200 else {
      let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw VectorStoreError.vectorSearchFailed(
        reason: "HTTP \(httpResponse.statusCode): \(errorMsg)"
      )
    }

    return try parseVectorSearchResponse(data: data)
  }

  // MARK: - Firestore Document Conversion

  // Converts an IndexedChunk to Firestore document format.
  private func chunkToFirestoreDocument(_ chunk: IndexedChunk) -> [String: Any] {
    // ISO8601 date formatter.
    let dateFormatter = ISO8601DateFormatter()

    var fields: [String: Any] = [
      "chunkID": ["stringValue": chunk.id],
      "documentID": ["stringValue": chunk.documentID],
      "documentType": ["stringValue": chunk.documentType.rawValue],
      "chunkIndex": ["integerValue": String(chunk.chunkIndex)],
      "text": ["stringValue": chunk.text],
      "embedding": [
        "arrayValue": [
          "values": chunk.embedding.map { ["doubleValue": $0] }
        ]
      ],
      "tokenCount": ["integerValue": String(chunk.tokenCount)],
      "displayName": ["stringValue": chunk.displayName],
      "modifiedAt": ["timestampValue": dateFormatter.string(from: chunk.modifiedAt)],
      "lastIndexedAt": ["timestampValue": dateFormatter.string(from: chunk.indexedAt)],
      "blockTypes": [
        "arrayValue": [
          "values": chunk.blockTypes.map { ["stringValue": $0.rawValue] }
        ]
      ]
    ]

    // Add page number if present.
    if let pageNumber = chunk.pageNumber {
      fields["pageNumber"] = ["integerValue": String(pageNumber)]
    }

    return fields
  }

  // Parses a Firestore document to an IndexedChunk.
  private func firestoreDocumentToChunk(
    _ fields: [String: Any],
    chunkID: String
  ) throws -> IndexedChunk {
    // Extract required fields.
    guard let documentIDValue = fields["documentID"] as? [String: Any],
          let documentID = documentIDValue["stringValue"] as? String else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing documentID")
    }

    guard let documentTypeValue = fields["documentType"] as? [String: Any],
          let documentTypeStr = documentTypeValue["stringValue"] as? String,
          let documentType = DocumentType(rawValue: documentTypeStr) else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing or invalid documentType")
    }

    guard let chunkIndexValue = fields["chunkIndex"] as? [String: Any],
          let chunkIndexStr = chunkIndexValue["integerValue"] as? String,
          let chunkIndex = Int(chunkIndexStr) else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing chunkIndex")
    }

    guard let textValue = fields["text"] as? [String: Any],
          let text = textValue["stringValue"] as? String else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing text")
    }

    guard let embeddingValue = fields["embedding"] as? [String: Any],
          let arrayValue = embeddingValue["arrayValue"] as? [String: Any],
          let values = arrayValue["values"] as? [[String: Any]] else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing embedding")
    }

    let embedding = values.compactMap { value -> Double? in
      if let doubleValue = value["doubleValue"] as? Double {
        return doubleValue
      }
      if let doubleStr = value["doubleValue"] as? String, let d = Double(doubleStr) {
        return d
      }
      return nil
    }

    guard let tokenCountValue = fields["tokenCount"] as? [String: Any],
          let tokenCountStr = tokenCountValue["integerValue"] as? String,
          let tokenCount = Int(tokenCountStr) else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing tokenCount")
    }

    guard let displayNameValue = fields["displayName"] as? [String: Any],
          let displayName = displayNameValue["stringValue"] as? String else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing displayName")
    }

    // Parse dates.
    let dateFormatter = ISO8601DateFormatter()

    guard let modifiedAtValue = fields["modifiedAt"] as? [String: Any],
          let modifiedAtStr = modifiedAtValue["timestampValue"] as? String,
          let modifiedAt = dateFormatter.date(from: modifiedAtStr) else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing modifiedAt")
    }

    guard let indexedAtValue = fields["lastIndexedAt"] as? [String: Any],
          let indexedAtStr = indexedAtValue["timestampValue"] as? String,
          let indexedAt = dateFormatter.date(from: indexedAtStr) else {
      throw VectorStoreError.firestoreReadFailed(reason: "Missing lastIndexedAt")
    }

    // Parse optional page number.
    var pageNumber: Int?
    if let pageNumValue = fields["pageNumber"] as? [String: Any],
       let pageNumStr = pageNumValue["integerValue"] as? String {
      pageNumber = Int(pageNumStr)
    }

    // Parse block types.
    var blockTypes: Set<ContentBlockType> = []
    if let blockTypesValue = fields["blockTypes"] as? [String: Any],
       let blockTypesArray = blockTypesValue["arrayValue"] as? [String: Any],
       let blockTypeValues = blockTypesArray["values"] as? [[String: Any]] {
      for value in blockTypeValues {
        if let typeStr = value["stringValue"] as? String,
           let blockType = ContentBlockType(rawValue: typeStr) {
          blockTypes.insert(blockType)
        }
      }
    }

    return IndexedChunk(
      id: chunkID,
      documentID: documentID,
      documentType: documentType,
      chunkIndex: chunkIndex,
      text: text,
      embedding: embedding,
      tokenCount: tokenCount,
      displayName: displayName,
      modifiedAt: modifiedAt,
      indexedAt: indexedAt,
      pageNumber: pageNumber,
      blockTypes: blockTypes
    )
  }

  // Parses query response into IndexedChunks.
  private func parseQueryResponse(data: Data) throws -> [IndexedChunk] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      // Empty result set.
      return []
    }

    var chunks: [IndexedChunk] = []

    for item in json {
      // Each item has a "document" key with the actual document.
      guard let document = item["document"] as? [String: Any],
            let fields = document["fields"] as? [String: Any],
            let name = document["name"] as? String else {
        continue
      }

      // Extract chunk ID from document path.
      let chunkID = name.components(separatedBy: "/").last ?? ""

      if let chunk = try? firestoreDocumentToChunk(fields, chunkID: chunkID) {
        chunks.append(chunk)
      }
    }

    return chunks
  }

  // Parses vector search response into results with scores.
  private func parseVectorSearchResponse(data: Data) throws -> [VectorSearchResult] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }

    var results: [VectorSearchResult] = []

    for item in json {
      guard let document = item["document"] as? [String: Any],
            let fields = document["fields"] as? [String: Any],
            let name = document["name"] as? String else {
        continue
      }

      let chunkID = name.components(separatedBy: "/").last ?? ""

      // Vector search response includes distance/score.
      // Cosine distance: 0 = identical, 2 = opposite. Convert to similarity score.
      var score = 1.0
      if let distance = item["distance"] as? Double {
        // Convert cosine distance to similarity: 1 - (distance / 2)
        score = 1.0 - (distance / 2.0)
      }

      if let chunk = try? firestoreDocumentToChunk(fields, chunkID: chunkID) {
        results.append(VectorSearchResult(chunk: chunk, score: score))
      }
    }

    return results
  }
}

// MARK: - Mock Vector Store Client

// Mock implementation for testing without Firestore.
final class MockVectorStoreClient: VectorStoreClientProtocol, @unchecked Sendable {

  // In-memory storage for chunks.
  private var chunks: [String: IndexedChunk] = [:]

  // Error to throw if set.
  var errorToThrow: Error?

  // Records upserted chunks.
  private(set) var upsertedChunks: [IndexedChunk] = []

  // Records deleted chunk IDs.
  private(set) var deletedChunkIDs: [String] = []

  // Records search queries.
  private(set) var searchQueries: [(embedding: [Double], limit: Int)] = []

  func upsertChunks(_ chunks: [IndexedChunk]) async throws -> BatchUpsertResult {
    if let error = errorToThrow {
      throw error
    }

    for chunk in chunks {
      self.chunks[chunk.id] = chunk
    }
    upsertedChunks.append(contentsOf: chunks)

    return BatchUpsertResult(
      successCount: chunks.count,
      failureCount: 0,
      failures: []
    )
  }

  func deleteChunksForDocument(documentID: String) async throws -> BatchDeleteResult {
    if let error = errorToThrow {
      throw error
    }

    let toDelete = chunks.values.filter { $0.documentID == documentID }
    for chunk in toDelete {
      chunks.removeValue(forKey: chunk.id)
      deletedChunkIDs.append(chunk.id)
    }

    return BatchDeleteResult(
      deletedCount: toDelete.count,
      success: true,
      errorMessage: nil
    )
  }

  func deleteChunk(chunkID: String) async throws {
    if let error = errorToThrow {
      throw error
    }

    chunks.removeValue(forKey: chunkID)
    deletedChunkIDs.append(chunkID)
  }

  func getChunksForDocument(documentID: String) async throws -> [IndexedChunk] {
    if let error = errorToThrow {
      throw error
    }

    return chunks.values
      .filter { $0.documentID == documentID }
      .sorted { $0.chunkIndex < $1.chunkIndex }
  }

  func getChunk(chunkID: String) async throws -> IndexedChunk? {
    if let error = errorToThrow {
      throw error
    }

    return chunks[chunkID]
  }

  func searchSimilar(
    queryEmbedding: [Double],
    limit: Int,
    documentIDFilter: [String]?
  ) async throws -> [VectorSearchResult] {
    if let error = errorToThrow {
      throw error
    }

    searchQueries.append((embedding: queryEmbedding, limit: limit))

    // Simple mock: return all chunks with score 1.0.
    var results = chunks.values.map { chunk in
      VectorSearchResult(chunk: chunk, score: 1.0)
    }

    if let filterIDs = documentIDFilter {
      results = results.filter { filterIDs.contains($0.chunk.documentID) }
    }

    return Array(results.prefix(limit))
  }

  // Adds a chunk directly for testing.
  func addChunk(_ chunk: IndexedChunk) {
    chunks[chunk.id] = chunk
  }

  // Resets all state for testing.
  func reset() {
    chunks = [:]
    errorToThrow = nil
    upsertedChunks = []
    deletedChunkIDs = []
    searchQueries = []
  }
}
