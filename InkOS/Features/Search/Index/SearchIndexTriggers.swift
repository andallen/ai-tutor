// SearchIndexTriggers.swift
// Observes notifications to trigger search index updates.

import Foundation

// MARK: - SearchIndexTriggers

// Observes content change notifications and triggers index updates.
// Uses debouncing to coalesce rapid changes.
final class SearchIndexTriggers: SearchIndexTriggersProtocol {
  // The search index to update.
  private let searchIndex: any SearchIndexProtocol

  // Callback to perform actual indexing (injected for flexibility).
  private let indexHandler: ((String, DocumentType) async -> Void)?

  // Notification observers.
  private var notebookObserver: NSObjectProtocol?
  private var pdfObserver: NSObjectProtocol?
  private var lessonObserver: NSObjectProtocol?
  private var folderCreatedObserver: NSObjectProtocol?
  private var folderRenamedObserver: NSObjectProtocol?

  // Debounce timers per document ID.
  private var debounceTimers: [String: Task<Void, Never>] = [:]

  // Whether currently observing.
  private(set) var isObserving = false

  // Creates triggers with dependencies.
  init(
    searchIndex: any SearchIndexProtocol,
    indexHandler: ((String, DocumentType) async -> Void)? = nil
  ) {
    self.searchIndex = searchIndex
    self.indexHandler = indexHandler
  }

  deinit {
    stopObserving()
  }

  // MARK: - SearchIndexTriggersProtocol

  func startObserving() {
    guard !isObserving else { return }

    // Observe notebook content saved.
    notebookObserver = NotificationCenter.default.addObserver(
      forName: .notebookContentSaved,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleNotebookContentSaved(notification)
    }

    // Observe PDF document imported.
    pdfObserver = NotificationCenter.default.addObserver(
      forName: .pdfDocumentImported,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handlePDFDocumentImported(notification)
    }

    // Observe lesson content saved.
    lessonObserver = NotificationCenter.default.addObserver(
      forName: .lessonContentSaved,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleLessonContentSaved(notification)
    }

    // Observe folder created.
    folderCreatedObserver = NotificationCenter.default.addObserver(
      forName: .folderCreated,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleFolderChanged(notification)
    }

    // Observe folder renamed.
    folderRenamedObserver = NotificationCenter.default.addObserver(
      forName: .folderRenamed,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleFolderChanged(notification)
    }

    isObserving = true
  }

  func stopObserving() {
    if let observer = notebookObserver {
      NotificationCenter.default.removeObserver(observer)
      notebookObserver = nil
    }

    if let observer = pdfObserver {
      NotificationCenter.default.removeObserver(observer)
      pdfObserver = nil
    }

    if let observer = lessonObserver {
      NotificationCenter.default.removeObserver(observer)
      lessonObserver = nil
    }

    if let observer = folderCreatedObserver {
      NotificationCenter.default.removeObserver(observer)
      folderCreatedObserver = nil
    }

    if let observer = folderRenamedObserver {
      NotificationCenter.default.removeObserver(observer)
      folderRenamedObserver = nil
    }

    // Cancel any pending debounce timers.
    for (_, task) in debounceTimers {
      task.cancel()
    }
    debounceTimers.removeAll()

    isObserving = false
  }

  // MARK: - Notification Handlers

  private func handleNotebookContentSaved(_ notification: Notification) {
    guard let documentID = notification.userInfo?["documentID"] as? String else {
      return
    }

    // Debounce rapid saves.
    debounceIndexing(documentID: documentID) { [weak self] in
      await self?.indexHandler?(documentID, .notebook)
    }
  }

  private func handlePDFDocumentImported(_ notification: Notification) {
    guard let documentID = notification.userInfo?["documentID"] as? String else {
      return
    }

    // Index immediately for imports (no debounce needed).
    Task {
      await indexHandler?(documentID, .pdf)
    }
  }

  private func handleLessonContentSaved(_ notification: Notification) {
    guard let documentID = notification.userInfo?["documentID"] as? String else {
      return
    }

    // Debounce rapid saves.
    debounceIndexing(documentID: documentID) { [weak self] in
      await self?.indexHandler?(documentID, .lesson)
    }
  }

  private func handleFolderChanged(_ notification: Notification) {
    guard let folderID = notification.userInfo?["folderID"] as? String else {
      return
    }

    // Index folder immediately (folder changes are infrequent).
    Task {
      await indexHandler?(folderID, .folder)
    }
  }

  // MARK: - Debouncing

  private func debounceIndexing(documentID: String, action: @escaping () async -> Void) {
    // Cancel existing timer for this document.
    debounceTimers[documentID]?.cancel()

    // Create new debounced task.
    let task = Task {
      try? await Task.sleep(
        nanoseconds: UInt64(SearchIndexConstants.indexingDebounceInterval * 1_000_000_000))

      // Check if cancelled.
      guard !Task.isCancelled else { return }

      await action()

      // Clean up timer reference.
      debounceTimers.removeValue(forKey: documentID)
    }

    debounceTimers[documentID] = task
  }
}
