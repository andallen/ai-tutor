// IndexingModelsTests.swift
// Tests for IndexingModels data structures.

import Foundation
import Testing

@testable import InkOS

// MARK: - IndexRequest Tests

@Suite("IndexRequest Tests")
struct IndexRequestTests {

  @Test("notebook request has correct document ID")
  func notebookDocumentID() {
    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "notebook-123",
        displayName: "Test Notebook",
        modifiedAt: Date()
      ))

    #expect(request.documentID == "notebook-123")
  }

  @Test("pdf request has correct document ID")
  func pdfDocumentID() {
    let request = IndexRequest.pdf(
      PDFIndexRequest(
        documentID: "pdf-456",
        displayName: "Test PDF",
        modifiedAt: Date()
      ))

    #expect(request.documentID == "pdf-456")
  }

  @Test("notebook request has correct document type")
  func notebookDocumentType() {
    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "id",
        displayName: "Name",
        modifiedAt: Date()
      ))

    #expect(request.documentType == .notebook)
  }

  @Test("pdf request has correct document type")
  func pdfDocumentType() {
    let request = IndexRequest.pdf(
      PDFIndexRequest(
        documentID: "id",
        displayName: "Name",
        modifiedAt: Date()
      ))

    #expect(request.documentType == .pdf)
  }

  @Test("request preserves display name")
  func preservesDisplayName() {
    let notebookRequest = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "id",
        displayName: "My Notebook",
        modifiedAt: Date()
      ))

    let pdfRequest = IndexRequest.pdf(
      PDFIndexRequest(
        documentID: "id",
        displayName: "My PDF",
        modifiedAt: Date()
      ))

    #expect(notebookRequest.displayName == "My Notebook")
    #expect(pdfRequest.displayName == "My PDF")
  }

  @Test("request preserves modified date")
  func preservesModifiedAt() {
    let date = Date()
    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "id",
        displayName: "Name",
        modifiedAt: date
      ))

    #expect(request.modifiedAt == date)
  }

  @Test("requests are equatable")
  func equatable() {
    let date = Date()
    let request1 = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "id",
        displayName: "Name",
        modifiedAt: date
      ))
    let request2 = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "id",
        displayName: "Name",
        modifiedAt: date
      ))

    #expect(request1 == request2)
  }
}

// MARK: - IndexingResult Tests

@Suite("IndexingResult Tests")
struct IndexingResultTests {

  @Test("success result has correct properties")
  func successResult() {
    let result = IndexingResult.success(
      documentID: "doc-1",
      chunksIndexed: 5,
      duration: 1.5
    )

    #expect(result.documentID == "doc-1")
    #expect(result.success == true)
    #expect(result.chunksIndexed == 5)
    #expect(result.duration == 1.5)
    #expect(result.errorMessage == nil)
  }

  @Test("failure result has correct properties")
  func failureResult() {
    let result = IndexingResult.failure(
      documentID: "doc-2",
      error: "Network error",
      duration: 0.5
    )

    #expect(result.documentID == "doc-2")
    #expect(result.success == false)
    #expect(result.chunksIndexed == 0)
    #expect(result.errorMessage == "Network error")
  }
}

// MARK: - BatchIndexingResult Tests

@Suite("BatchIndexingResult Tests")
struct BatchIndexingResultTests {

  @Test("batch result aggregates correctly")
  func aggregatesResults() {
    let results = [
      IndexingResult.success(documentID: "1", chunksIndexed: 3, duration: 1.0),
      IndexingResult.success(documentID: "2", chunksIndexed: 5, duration: 2.0),
      IndexingResult.failure(documentID: "3", error: "Error", duration: 0.5),
    ]

    let batch = BatchIndexingResult(
      totalDocuments: 3,
      successCount: 2,
      failureCount: 1,
      totalChunksIndexed: 8,
      results: results,
      duration: 3.5
    )

    #expect(batch.totalDocuments == 3)
    #expect(batch.successCount == 2)
    #expect(batch.failureCount == 1)
    #expect(batch.totalChunksIndexed == 8)
    #expect(batch.results.count == 3)
    #expect(batch.duration == 3.5)
  }
}

// MARK: - IndexingProgress Tests

@Suite("IndexingProgress Tests")
struct IndexingProgressTests {

  @Test("progress has correct properties")
  func progressProperties() {
    let progress = IndexingProgress(
      documentID: "doc-1",
      state: .embedding,
      progress: 0.75,
      message: "Generating embeddings..."
    )

    #expect(progress.documentID == "doc-1")
    #expect(progress.state == .embedding)
    #expect(progress.progress == 0.75)
    #expect(progress.message == "Generating embeddings...")
  }
}

// MARK: - IndexingError Tests

@Suite("IndexingError Tests")
struct IndexingErrorTests {

  @Test("document not found has correct description")
  func documentNotFoundDescription() {
    let error = IndexingError.documentNotFound(documentID: "missing-doc")
    #expect(error.errorDescription?.contains("missing-doc") == true)
  }

  @Test("extraction failed has correct description")
  func extractionFailedDescription() {
    let error = IndexingError.extractionFailed(documentID: "doc-1", reason: "Parse error")
    #expect(error.errorDescription?.contains("doc-1") == true)
    #expect(error.errorDescription?.contains("Parse error") == true)
  }

  @Test("queue full has correct description")
  func queueFullDescription() {
    let error = IndexingError.queueFull(maxSize: 100)
    #expect(error.errorDescription?.contains("100") == true)
  }

  @Test("errors are equatable")
  func errorsEquatable() {
    let error1 = IndexingError.documentNotFound(documentID: "doc-1")
    let error2 = IndexingError.documentNotFound(documentID: "doc-1")
    let error3 = IndexingError.queueFull(maxSize: 100)

    #expect(error1 == error2)
    #expect(error1 != error3)
  }
}

// MARK: - IndexingConfiguration Tests

@Suite("IndexingConfiguration Tests")
struct IndexingConfigurationTests {

  @Test("default configuration has expected values")
  func defaultConfiguration() {
    let config = IndexingConfiguration.default

    #expect(config.debounceDelay == 5.0)
    #expect(config.maxQueueSize == 100)
    #expect(config.automaticIndexingEnabled == true)
    #expect(config.maxConcurrentOperations == 3)
  }

  @Test("testing configuration has fast values")
  func testingConfiguration() {
    let config = IndexingConfiguration.testing

    #expect(config.debounceDelay == 0.1)
    #expect(config.maxQueueSize == 10)
    #expect(config.automaticIndexingEnabled == true)
    #expect(config.maxConcurrentOperations == 1)
  }
}

// MARK: - QueuedIndexRequest Tests

@Suite("QueuedIndexRequest Tests")
struct QueuedIndexRequestTests {

  @Test("creates with unique ID")
  func uniqueID() {
    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "notebook-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    let queued1 = QueuedIndexRequest(request: request)
    let queued2 = QueuedIndexRequest(request: request)

    #expect(queued1.id != queued2.id)
  }

  @Test("preserves original request")
  func preservesRequest() {
    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "notebook-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    let queued = QueuedIndexRequest(request: request)

    #expect(queued.request == request)
  }

  @Test("records queue time")
  func recordsQueueTime() {
    let before = Date()
    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "notebook-1",
        displayName: "Test",
        modifiedAt: Date()
      ))
    let queued = QueuedIndexRequest(request: request)
    let after = Date()

    #expect(queued.queuedAt >= before)
    #expect(queued.queuedAt <= after)
  }
}
