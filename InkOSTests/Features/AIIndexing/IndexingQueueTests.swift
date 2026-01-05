// IndexingQueueTests.swift
// Tests for IndexingQueue functionality.

import Foundation
import Testing

@testable import InkOS

// MARK: - IndexingQueue Tests

@Suite("IndexingQueue Tests")
struct IndexingQueueTests {

  // Creates a test request for convenience.
  private func createRequest(id: String = "test-doc") -> IndexRequest {
    return IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: id,
        displayName: "Test Notebook",
        modifiedAt: Date()
      ))
  }

  @Test("initially has zero queue size")
  func initialQueueSize() async {
    let queue = IndexingQueue(configuration: .testing)

    let size = await queue.queueSize
    #expect(size == 0)
  }

  @Test("initially is not processing")
  func initialNotProcessing() async {
    let queue = IndexingQueue(configuration: .testing)

    let isProcessing = await queue.isProcessing
    #expect(isProcessing == false)
  }

  @Test("enqueue increases queue size")
  func enqueueIncreasesSize() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,  // Long delay to prevent processing
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))

    let size = await queue.queueSize
    #expect(size == 1)
  }

  @Test("enqueue same document replaces existing")
  func enqueueSameDocumentReplaces() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    try await queue.enqueue(createRequest(id: "doc-1"))

    let size = await queue.queueSize
    #expect(size == 1)
  }

  @Test("enqueue different documents adds to queue")
  func enqueueDifferentDocumentsAdds() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    try await queue.enqueue(createRequest(id: "doc-2"))

    let size = await queue.queueSize
    #expect(size == 2)
  }

  @Test("remove decreases queue size")
  func removeDecreasesSize() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    await queue.remove(documentID: "doc-1")

    let size = await queue.queueSize
    #expect(size == 0)
  }

  @Test("remove non-existent document is no-op")
  func removeNonExistentIsNoOp() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    await queue.remove(documentID: "non-existent")

    let size = await queue.queueSize
    #expect(size == 1)
  }

  @Test("cancelAll clears queue")
  func cancelAllClearsQueue() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    try await queue.enqueue(createRequest(id: "doc-2"))
    await queue.cancelAll()

    let size = await queue.queueSize
    #expect(size == 0)
  }

  @Test("throws when queue is full")
  func throwsWhenQueueFull() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 2,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    try await queue.enqueue(createRequest(id: "doc-2"))

    await #expect(throws: IndexingError.self) {
      try await queue.enqueue(createRequest(id: "doc-3"))
    }
  }

  @Test("allows replacing when queue is full")
  func allowsReplacingWhenFull() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 2,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    try await queue.enqueue(createRequest(id: "doc-2"))

    // Should not throw since we're replacing an existing document
    try await queue.enqueue(createRequest(id: "doc-1"))

    let size = await queue.queueSize
    #expect(size == 2)
  }

  @Test("forceProcess processes all pending items")
  func forceProcessProcessesAll() async throws {
    var processedRequests: [IndexRequest] = []
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    await queue.setProcessCallback { requests in
      processedRequests = requests
    }

    try await queue.enqueue(createRequest(id: "doc-1"))
    try await queue.enqueue(createRequest(id: "doc-2"))
    await queue.forceProcess()

    #expect(processedRequests.count == 2)
    let size = await queue.queueSize
    #expect(size == 0)
  }

  @Test("getPendingDocumentIDs returns all pending")
  func getPendingDocumentIDsReturnsAll() async throws {
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 10.0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    try await queue.enqueue(createRequest(id: "doc-1"))
    try await queue.enqueue(createRequest(id: "doc-2"))

    let pending = await queue.getPendingDocumentIDs()
    #expect(pending.count == 2)
    #expect(pending.contains("doc-1"))
    #expect(pending.contains("doc-2"))
  }

  @Test("zero debounce processes immediately")
  func zeroDebounceProcessesImmediately() async throws {
    var processed = false
    let queue = IndexingQueue(
      configuration: IndexingConfiguration(
        debounceDelay: 0,
        maxQueueSize: 100,
        automaticIndexingEnabled: true,
        maxConcurrentOperations: 1
      ))

    await queue.setProcessCallback { _ in
      processed = true
    }

    try await queue.enqueue(createRequest(id: "doc-1"))

    // Give a small delay for processing
    try await Task.sleep(nanoseconds: 10_000_000)

    #expect(processed == true)
    let size = await queue.queueSize
    #expect(size == 0)
  }
}

// MARK: - MockIndexingQueue Tests

@Suite("MockIndexingQueue Tests")
struct MockIndexingQueueTests {

  @Test("records enqueued requests")
  func recordsEnqueuedRequests() async throws {
    let mockQueue = MockIndexingQueue()

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    try await mockQueue.enqueue(request)

    let count = await mockQueue.getEnqueuedRequestsCount()
    let firstRequest = await mockQueue.getEnqueuedRequest(at: 0)
    #expect(count == 1)
    #expect(firstRequest == request)
  }

  @Test("records removed document IDs")
  func recordsRemovedDocumentIDs() async {
    let mockQueue = MockIndexingQueue()

    await mockQueue.remove(documentID: "doc-1")
    await mockQueue.remove(documentID: "doc-2")

    let count = await mockQueue.getRemovedDocumentIDsCount()
    let containsDoc1 = await mockQueue.removedDocumentIDsContains("doc-1")
    let containsDoc2 = await mockQueue.removedDocumentIDsContains("doc-2")
    #expect(count == 2)
    #expect(containsDoc1)
    #expect(containsDoc2)
  }

  @Test("records cancelAll called")
  func recordsCancelAllCalled() async {
    let mockQueue = MockIndexingQueue()

    await mockQueue.cancelAll()

    let called = await mockQueue.getCancelAllCalled()
    #expect(called == true)
  }

  @Test("throws configured error")
  func throwsConfiguredError() async {
    let mockQueue = MockIndexingQueue()
    await mockQueue.setErrorToThrow(IndexingError.queueFull(maxSize: 10))

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    await #expect(throws: IndexingError.self) {
      try await mockQueue.enqueue(request)
    }
  }

  @Test("reset clears state")
  func resetClearsState() async throws {
    let mockQueue = MockIndexingQueue()

    let request = IndexRequest.notebook(
      NotebookIndexRequest(
        notebookID: "doc-1",
        displayName: "Test",
        modifiedAt: Date()
      ))

    try await mockQueue.enqueue(request)
    await mockQueue.remove(documentID: "doc-1")
    await mockQueue.cancelAll()

    await mockQueue.reset()

    let isEmpty = await mockQueue.isEnqueuedRequestsEmpty()
    let removedEmpty = await mockQueue.isRemovedDocumentIDsEmpty()
    let cancelCalled = await mockQueue.getCancelAllCalled()
    #expect(isEmpty)
    #expect(removedEmpty)
    #expect(cancelCalled == false)
  }
}
