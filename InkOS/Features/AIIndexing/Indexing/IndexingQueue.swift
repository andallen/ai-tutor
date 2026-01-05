// IndexingQueue.swift
// Manages debounced background indexing queue.

import Foundation

// MARK: - Indexing Queue Protocol

// Protocol for the indexing queue to support dependency injection.
protocol IndexingQueueProtocol: Actor {
  // Enqueues a document for indexing with debounce.
  func enqueue(_ request: IndexRequest) async throws

  // Removes a document from the queue.
  func remove(documentID: String) async

  // Cancels all pending indexing operations.
  func cancelAll() async

  // Returns the current queue size.
  var queueSize: Int { get async }

  // Returns whether the queue is currently processing.
  var isProcessing: Bool { get async }
}

// MARK: - Indexing Queue Delegate

// Delegate protocol for handling queue events.
protocol IndexingQueueDelegate: AnyObject, Sendable {
  // Called when the queue is ready to process items after debounce.
  func indexingQueue(_ queue: IndexingQueue, shouldProcess requests: [IndexRequest]) async
}

// MARK: - Indexing Queue Actor

// Actor managing a debounced queue of documents to index.
// Coalesces multiple changes to the same document within the debounce window.
// Notifies delegate when ready to process after debounce delay.
actor IndexingQueue: IndexingQueueProtocol {

  // Configuration for queue behavior.
  private let configuration: IndexingConfiguration

  // Pending index requests keyed by document ID for deduplication.
  private var pendingRequests: [String: QueuedIndexRequest] = [:]

  // Current debounce task if any.
  private var debounceTask: Task<Void, Never>?

  // Whether processing is currently active.
  private var _isProcessing: Bool = false

  // Delegate for processing callbacks.
  private weak var delegate: (any IndexingQueueDelegate)?

  // Callback for processing (alternative to delegate pattern).
  private var processCallback: (([IndexRequest]) async -> Void)?

  // Public accessor for queue size.
  var queueSize: Int {
    return pendingRequests.count
  }

  // Public accessor for processing state.
  var isProcessing: Bool {
    return _isProcessing
  }

  // Creates an indexing queue with the specified configuration.
  init(configuration: IndexingConfiguration = .default) {
    self.configuration = configuration
  }

  // Sets the delegate for queue events.
  func setDelegate(_ delegate: any IndexingQueueDelegate) {
    self.delegate = delegate
  }

  // Sets a callback for processing (alternative to delegate).
  func setProcessCallback(_ callback: @escaping ([IndexRequest]) async -> Void) {
    self.processCallback = callback
  }

  // MARK: - Queue Operations

  // Enqueues a document for indexing.
  // If the same document is already queued, updates the request.
  // Restarts the debounce timer on each enqueue.
  func enqueue(_ request: IndexRequest) async throws {
    // Check queue size limit.
    if pendingRequests.count >= configuration.maxQueueSize
        && pendingRequests[request.documentID] == nil {
      throw IndexingError.queueFull(maxSize: configuration.maxQueueSize)
    }

    // Add or update the request.
    pendingRequests[request.documentID] = QueuedIndexRequest(request: request)

    // Restart debounce timer.
    await scheduleDebounce()
  }

  // Removes a document from the queue.
  func remove(documentID: String) async {
    pendingRequests.removeValue(forKey: documentID)
  }

  // Cancels all pending operations and clears the queue.
  func cancelAll() async {
    debounceTask?.cancel()
    debounceTask = nil
    pendingRequests.removeAll()
    _isProcessing = false
  }

  // MARK: - Debounce Logic

  // Schedules the debounce timer.
  // Cancels any existing timer and starts a new one.
  private func scheduleDebounce() async {
    // Cancel existing debounce.
    debounceTask?.cancel()

    // Handle zero debounce as immediate processing.
    if configuration.debounceDelay == 0 {
      await processQueue()
      return
    }

    // Schedule new debounce using detached task.
    let capturedSelf = self
    let delay = configuration.debounceDelay
    debounceTask = Task.detached {
      do {
        let nanoseconds = UInt64(delay * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
      } catch {
        // Task was cancelled.
        return
      }

      guard !Task.isCancelled else { return }

      await capturedSelf.processQueue()
    }
  }

  // Processes the queue by notifying delegate or calling callback.
  private func processQueue() async {
    // Nothing to process.
    guard !pendingRequests.isEmpty else { return }

    // Already processing.
    guard !_isProcessing else { return }

    _isProcessing = true

    // Collect all pending requests.
    let requests = pendingRequests.values.map { $0.request }

    // Clear pending requests since we're processing them.
    pendingRequests.removeAll()

    // Clear debounce task.
    debounceTask = nil

    // Notify delegate or call callback.
    if let callback = processCallback {
      await callback(requests)
    } else if let delegate = delegate {
      await delegate.indexingQueue(self, shouldProcess: requests)
    }

    _isProcessing = false
  }

  // MARK: - Testing Helpers

  // Forces immediate processing for testing.
  func forceProcess() async {
    debounceTask?.cancel()
    debounceTask = nil
    await processQueue()
  }

  // Returns all pending document IDs for testing.
  func getPendingDocumentIDs() -> [String] {
    return Array(pendingRequests.keys)
  }
}

// MARK: - Mock Indexing Queue

// Mock implementation for testing.
actor MockIndexingQueue: IndexingQueueProtocol {

  // Records enqueued requests.
  private(set) var enqueuedRequests: [IndexRequest] = []

  // Records removed document IDs.
  private(set) var removedDocumentIDs: [String] = []

  // Whether cancelAll was called.
  private(set) var cancelAllCalled: Bool = false

  // Error to throw on enqueue.
  var errorToThrow: Error?

  // Simulated queue size.
  var simulatedQueueSize: Int = 0

  // Simulated processing state.
  var simulatedIsProcessing: Bool = false

  var queueSize: Int {
    return simulatedQueueSize
  }

  var isProcessing: Bool {
    return simulatedIsProcessing
  }

  func enqueue(_ request: IndexRequest) async throws {
    if let error = errorToThrow {
      throw error
    }
    enqueuedRequests.append(request)
  }

  func remove(documentID: String) async {
    removedDocumentIDs.append(documentID)
  }

  func cancelAll() async {
    cancelAllCalled = true
    enqueuedRequests.removeAll()
  }

  // Resets all recorded state.
  func reset() {
    enqueuedRequests = []
    removedDocumentIDs = []
    cancelAllCalled = false
    errorToThrow = nil
    simulatedQueueSize = 0
    simulatedIsProcessing = false
  }

  // MARK: - Test Accessors

  // Gets the count of enqueued requests.
  func getEnqueuedRequestsCount() -> Int {
    return enqueuedRequests.count
  }

  // Gets an enqueued request at index.
  func getEnqueuedRequest(at index: Int) -> IndexRequest? {
    guard index < enqueuedRequests.count else { return nil }
    return enqueuedRequests[index]
  }

  // Checks if enqueued requests is empty.
  func isEnqueuedRequestsEmpty() -> Bool {
    return enqueuedRequests.isEmpty
  }

  // Gets the count of removed document IDs.
  func getRemovedDocumentIDsCount() -> Int {
    return removedDocumentIDs.count
  }

  // Checks if removed document IDs contains a value.
  func removedDocumentIDsContains(_ id: String) -> Bool {
    return removedDocumentIDs.contains(id)
  }

  // Checks if removed document IDs is empty.
  func isRemovedDocumentIDsEmpty() -> Bool {
    return removedDocumentIDs.isEmpty
  }

  // Gets the cancelAllCalled state.
  func getCancelAllCalled() -> Bool {
    return cancelAllCalled
  }

  // Sets the error to throw.
  func setErrorToThrow(_ error: Error?) {
    errorToThrow = error
  }
}
