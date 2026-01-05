// IndexingModels.swift
// Data models for the indexing pipeline.

import Foundation

// MARK: - Indexing Request Models

// Represents a request to index a notebook document.
struct NotebookIndexRequest: Sendable, Equatable {
  // Unique identifier for the notebook.
  let notebookID: String

  // Display name of the notebook.
  let displayName: String

  // Timestamp when the notebook was last modified.
  let modifiedAt: Date
}

// Represents a request to index a PDF document.
struct PDFIndexRequest: Sendable, Equatable {
  // Unique identifier for the PDF document.
  let documentID: String

  // Display name of the PDF document.
  let displayName: String

  // Timestamp when the PDF was last modified.
  let modifiedAt: Date
}

// Unified index request that can be either a notebook or PDF.
enum IndexRequest: Sendable, Equatable {
  case notebook(NotebookIndexRequest)
  case pdf(PDFIndexRequest)

  // The document identifier for this request.
  var documentID: String {
    switch self {
    case .notebook(let request): return request.notebookID
    case .pdf(let request): return request.documentID
    }
  }

  // The display name for this request.
  var displayName: String {
    switch self {
    case .notebook(let request): return request.displayName
    case .pdf(let request): return request.displayName
    }
  }

  // The modification timestamp for this request.
  var modifiedAt: Date {
    switch self {
    case .notebook(let request): return request.modifiedAt
    case .pdf(let request): return request.modifiedAt
    }
  }

  // The document type for this request.
  var documentType: DocumentType {
    switch self {
    case .notebook: return .notebook
    case .pdf: return .pdf
    }
  }
}

// MARK: - Indexing Result Models

// Result of indexing a single document.
struct IndexingResult: Sendable {
  // The document identifier.
  let documentID: String

  // Whether indexing was successful.
  let success: Bool

  // Number of chunks indexed.
  let chunksIndexed: Int

  // Error message if indexing failed.
  let errorMessage: String?

  // Time taken to index in seconds.
  let duration: TimeInterval

  // Creates a successful indexing result.
  static func success(documentID: String, chunksIndexed: Int, duration: TimeInterval) -> IndexingResult {
    return IndexingResult(
      documentID: documentID,
      success: true,
      chunksIndexed: chunksIndexed,
      errorMessage: nil,
      duration: duration
    )
  }

  // Creates a failed indexing result.
  static func failure(documentID: String, error: String, duration: TimeInterval) -> IndexingResult {
    return IndexingResult(
      documentID: documentID,
      success: false,
      chunksIndexed: 0,
      errorMessage: error,
      duration: duration
    )
  }
}

// Summary of a batch indexing operation.
struct BatchIndexingResult: Sendable {
  // Total number of documents processed.
  let totalDocuments: Int

  // Number of documents successfully indexed.
  let successCount: Int

  // Number of documents that failed to index.
  let failureCount: Int

  // Total chunks indexed across all documents.
  let totalChunksIndexed: Int

  // Individual results for each document.
  let results: [IndexingResult]

  // Total time taken in seconds.
  let duration: TimeInterval
}

// MARK: - Indexing Progress Models

// Progress update during indexing.
struct IndexingProgress: Sendable {
  // The document being indexed.
  let documentID: String

  // Current state of indexing.
  let state: IndexingState

  // Progress percentage (0.0 to 1.0).
  let progress: Double

  // Human-readable status message.
  let message: String
}

// Callback type for progress updates.
typealias IndexingProgressCallback = @Sendable (IndexingProgress) -> Void

// MARK: - Indexing Errors

// Errors specific to the indexing pipeline.
enum IndexingError: LocalizedError, Equatable {
  case documentNotFound(documentID: String)
  case extractionFailed(documentID: String, reason: String)
  case chunkingFailed(documentID: String, reason: String)
  case embeddingFailed(documentID: String, reason: String)
  case storageFailed(documentID: String, reason: String)
  case queueFull(maxSize: Int)
  case indexingCancelled(documentID: String)
  case invalidConfiguration(reason: String)

  var errorDescription: String? {
    switch self {
    case .documentNotFound(let documentID):
      return "Document not found: \(documentID)"
    case .extractionFailed(let documentID, let reason):
      return "Failed to extract content from \(documentID): \(reason)"
    case .chunkingFailed(let documentID, let reason):
      return "Failed to chunk content from \(documentID): \(reason)"
    case .embeddingFailed(let documentID, let reason):
      return "Failed to generate embeddings for \(documentID): \(reason)"
    case .storageFailed(let documentID, let reason):
      return "Failed to store embeddings for \(documentID): \(reason)"
    case .queueFull(let maxSize):
      return "Indexing queue is full (max \(maxSize) items)"
    case .indexingCancelled(let documentID):
      return "Indexing was cancelled for \(documentID)"
    case .invalidConfiguration(let reason):
      return "Invalid indexing configuration: \(reason)"
    }
  }
}

// MARK: - Indexing Configuration

// Configuration for the indexing pipeline.
struct IndexingConfiguration: Sendable {
  // Delay in seconds before processing queued items.
  let debounceDelay: TimeInterval

  // Maximum number of items in the indexing queue.
  let maxQueueSize: Int

  // Whether to enable automatic indexing on content changes.
  let automaticIndexingEnabled: Bool

  // Maximum concurrent indexing operations.
  let maxConcurrentOperations: Int

  // Default configuration for production use.
  static let `default` = IndexingConfiguration(
    debounceDelay: 5.0,
    maxQueueSize: 100,
    automaticIndexingEnabled: true,
    maxConcurrentOperations: 3
  )

  // Configuration for testing with faster processing.
  static let testing = IndexingConfiguration(
    debounceDelay: 0.1,
    maxQueueSize: 10,
    automaticIndexingEnabled: true,
    maxConcurrentOperations: 1
  )
}

// MARK: - Queue Item Models

// Represents an item in the indexing queue.
struct QueuedIndexRequest: Sendable, Equatable {
  // Unique identifier for this queue item.
  let id: String

  // The actual index request.
  let request: IndexRequest

  // Timestamp when this item was queued.
  let queuedAt: Date

  // Creates a new queued request with a unique ID.
  init(request: IndexRequest) {
    self.id = UUID().uuidString
    self.request = request
    self.queuedAt = Date()
  }
}

// MARK: - Notification Keys

// Keys used in notification userInfo dictionaries.
enum IndexingNotificationKey {
  // The document ID that was indexed or failed.
  static let documentID = "documentID"

  // The indexing result for completed operations.
  static let result = "result"

  // The error for failed operations.
  static let error = "error"

  // The progress update for in-progress operations.
  static let progress = "progress"
}
