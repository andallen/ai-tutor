// VectorStoreModels.swift
// Data models for vector storage operations with Firestore.

import Foundation

// MARK: - Vector Embedding Models

// Represents a document chunk with its embedding vector stored in Firestore.
// Each indexed chunk is stored as a separate document in the chunks collection.
struct IndexedChunk: Sendable, Codable, Identifiable, Equatable {
  // Unique identifier for this chunk (UUID).
  let id: String

  // The source document identifier.
  let documentID: String

  // Type of document (notebook or pdf).
  let documentType: DocumentType

  // Sequential index of this chunk within the document.
  let chunkIndex: Int

  // The text content of this chunk.
  let text: String

  // The embedding vector (768 dimensions for text-embedding-005).
  let embedding: [Double]

  // Approximate token count for this chunk.
  let tokenCount: Int

  // Display name of the source document.
  let displayName: String

  // Timestamp when the document was last modified.
  let modifiedAt: Date

  // Timestamp when this chunk was indexed.
  let indexedAt: Date

  // Page number for PDF documents (nil for notebooks).
  let pageNumber: Int?

  // Types of content blocks present in this chunk.
  let blockTypes: Set<ContentBlockType>

  // Firestore field names for encoding/decoding.
  private enum CodingKeys: String, CodingKey {
    case id = "chunkID"
    case documentID
    case documentType
    case chunkIndex
    case text
    case embedding
    case tokenCount
    case displayName
    case modifiedAt
    case indexedAt = "lastIndexedAt"
    case pageNumber
    case blockTypes
  }
}

// MARK: - Embedding Request/Response Models

// Request to generate embeddings for text chunks.
// Sent to the Firebase Cloud Function.
struct EmbeddingRequest: Sendable, Codable {
  // Array of text strings to embed (max 100).
  let texts: [String]

  // Task type for optimized embeddings.
  let taskType: EmbeddingTaskType

  init(texts: [String], taskType: EmbeddingTaskType = .retrievalDocument) {
    self.texts = texts
    self.taskType = taskType
  }
}

// Response from the embedding Cloud Function.
struct EmbeddingResponse: Sendable, Codable {
  // Array of embedding vectors (768 dimensions each).
  let embeddings: [[Double]]

  // The model used for embedding generation.
  let model: String

  // Number of dimensions in each embedding.
  let dimensions: Int
}

// Task types for embedding generation.
// Different task types optimize embeddings for specific use cases.
enum EmbeddingTaskType: String, Sendable, Codable {
  // For indexing documents (chunked content).
  case retrievalDocument = "RETRIEVAL_DOCUMENT"

  // For search queries (user questions).
  case retrievalQuery = "RETRIEVAL_QUERY"

  // For comparing text similarity.
  case semanticSimilarity = "SEMANTIC_SIMILARITY"

  // For text classification tasks.
  case classification = "CLASSIFICATION"

  // For clustering texts.
  case clustering = "CLUSTERING"
}

// MARK: - Vector Search Models

// Request for vector similarity search.
struct VectorSearchRequest: Sendable {
  // The query text to search for.
  let queryText: String

  // Maximum number of results to return.
  let limit: Int

  // Optional filter by document IDs.
  let documentIDFilter: [String]?

  // Minimum similarity score threshold (0.0 to 1.0).
  let minimumScore: Double?

  init(
    queryText: String,
    limit: Int = 10,
    documentIDFilter: [String]? = nil,
    minimumScore: Double? = nil
  ) {
    self.queryText = queryText
    self.limit = limit
    self.documentIDFilter = documentIDFilter
    self.minimumScore = minimumScore
  }
}

// Result of a vector similarity search.
struct VectorSearchResult: Sendable, Identifiable {
  // The matched chunk.
  let chunk: IndexedChunk

  // Similarity score (0.0 to 1.0, higher is more similar).
  let score: Double

  var id: String { chunk.id }
}

// MARK: - Vector Store Errors

// Errors that can occur during vector storage operations.
enum VectorStoreError: LocalizedError, Equatable {
  case embeddingGenerationFailed(reason: String)
  case firestoreWriteFailed(reason: String)
  case firestoreReadFailed(reason: String)
  case firestoreDeleteFailed(reason: String)
  case vectorSearchFailed(reason: String)
  case invalidEmbeddingDimensions(expected: Int, received: Int)
  case chunkNotFound(chunkID: String)
  case documentChunksNotFound(documentID: String)
  case networkError(reason: String)
  case authenticationFailed
  case rateLimitExceeded
  case firebaseNotConfigured

  var errorDescription: String? {
    switch self {
    case .embeddingGenerationFailed(let reason):
      return "Failed to generate embeddings: \(reason)"
    case .firestoreWriteFailed(let reason):
      return "Failed to write to Firestore: \(reason)"
    case .firestoreReadFailed(let reason):
      return "Failed to read from Firestore: \(reason)"
    case .firestoreDeleteFailed(let reason):
      return "Failed to delete from Firestore: \(reason)"
    case .vectorSearchFailed(let reason):
      return "Vector search failed: \(reason)"
    case .invalidEmbeddingDimensions(let expected, let received):
      return "Invalid embedding dimensions: expected \(expected), received \(received)"
    case .chunkNotFound(let chunkID):
      return "Chunk not found: \(chunkID)"
    case .documentChunksNotFound(let documentID):
      return "No chunks found for document: \(documentID)"
    case .networkError(let reason):
      return "Network error: \(reason)"
    case .authenticationFailed:
      return "Firebase authentication failed"
    case .rateLimitExceeded:
      return "Embedding API rate limit exceeded"
    case .firebaseNotConfigured:
      return "Firebase is not properly configured"
    }
  }
}

// MARK: - Indexing Status Models

// Status of indexing for a single document.
struct DocumentIndexingStatus: Sendable, Equatable {
  // The document identifier.
  let documentID: String

  // Current indexing state.
  let state: IndexingState

  // Number of chunks indexed.
  let chunksIndexed: Int

  // Total number of chunks for the document.
  let totalChunks: Int

  // Timestamp of last indexing attempt.
  let lastIndexedAt: Date?

  // Error message if indexing failed.
  let errorMessage: String?
}

// Possible states during indexing.
enum IndexingState: String, Sendable, Codable {
  case pending
  case extracting
  case chunking
  case embedding
  case storing
  case completed
  case failed
}

// MARK: - Batch Operation Models

// Result of a batch upsert operation.
struct BatchUpsertResult: Sendable {
  // Number of chunks successfully upserted.
  let successCount: Int

  // Number of chunks that failed.
  let failureCount: Int

  // IDs of failed chunks with error messages.
  let failures: [(chunkID: String, error: String)]
}

// Result of a batch delete operation.
struct BatchDeleteResult: Sendable {
  // Number of chunks successfully deleted.
  let deletedCount: Int

  // Whether the operation completed successfully.
  let success: Bool

  // Error message if any failures occurred.
  let errorMessage: String?
}

// MARK: - Constants

// Constants for vector store configuration.
enum VectorStoreConstants {
  // Name of the Firestore collection for document chunks.
  static let chunksCollection = "document_chunks"

  // Embedding model used (text-embedding-005).
  static let embeddingModel = "text-embedding-005"

  // Number of dimensions in embeddings.
  static let embeddingDimensions = 768

  // Maximum texts per embedding request.
  static let maxTextsPerRequest = 100

  // Maximum batch size for Firestore writes.
  static let maxBatchSize = 500

  // Default number of search results.
  static let defaultSearchLimit = 10
}
