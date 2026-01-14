// Implements the JIIXPersistenceService actor for debounced JIIX export and save.
// Coordinates between MainActor-bound editor export and file I/O operations.
// See JIIXPersistenceContract.swift for the full API contract and acceptance criteria.

import Foundation

// MARK: - JIIXPersistenceService Implementation

// Actor managing debounced JIIX persistence to file system.
// Uses debounce mechanism to avoid excessive exports during rapid editing.
// Posts .notebookContentSaved notification after successful saves.
actor JIIXPersistenceService {

  // The debounce delay in seconds before triggering an export after content changes.
  let debounceDelaySeconds: Double

  // The notebook ID for notification posting.
  private let notebookID: String

  // The editor used for JIIX export. Held as a reference to the protocol.
  // Access requires MainActor hop since EditorExportProtocol is MainActor-isolated.
  private let editor: any EditorExportProtocol

  // The document handle used for file I/O operations.
  private let documentHandle: any JIIXDocumentHandleProtocol

  // The most recently exported JIIX string, cached to avoid redundant exports.
  private var cachedJIIX: String?

  // Indicates whether content has changed since the last successful export and save.
  private var _hasPendingChanges: Bool = false

  // Indicates whether an export operation is currently in progress.
  private var _isExporting: Bool = false

  // The current debounce task, if any. Cancelled when a new change arrives.
  private var debounceTask: Task<Void, Never>?

  // Public accessor for isExporting state.
  var isExporting: Bool {
    return _isExporting
  }

  // Public accessor for hasPendingChanges state.
  var hasPendingChanges: Bool {
    return _hasPendingChanges
  }

  // Creates a new persistence service with the specified dependencies.
  init(
    notebookID: String,
    editor: any EditorExportProtocol,
    documentHandle: any JIIXDocumentHandleProtocol,
    debounceDelaySeconds: Double
  ) {
    self.notebookID = notebookID
    self.editor = editor
    self.documentHandle = documentHandle
    // Use absolute value to handle negative delay edge case.
    self.debounceDelaySeconds = abs(debounceDelaySeconds)
  }

  // Notifies the service that content has changed.
  // Resets the debounce timer and schedules an export after the delay.
  func contentDidChange() async {
    // Mark that there are pending changes.
    _hasPendingChanges = true

    // If an export is in progress, the pending changes flag is set and the export
    // completion handler will schedule a new debounce. No need to do anything else.
    if _isExporting {
      return
    }

    // Cancel any existing debounce timer.
    debounceTask?.cancel()
    debounceTask = nil

    // Handle zero debounce as special case - export immediately.
    if debounceDelaySeconds == 0 {
      await performDebouncedExportAndSave()
      return
    }

    // Schedule a new debounce timer using detached task to avoid actor isolation issues.
    // The task will be cancelled explicitly when contentDidChange is called again or when
    // cancelPendingSave is called, so there is no risk of a retain cycle.
    let capturedSelf = self
    debounceTask = Task.detached {
      // Wait for the debounce delay. If cancelled, the sleep throws CancellationError.
      do {
        let nanoseconds = UInt64(capturedSelf.debounceDelaySeconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
      } catch {
        // Task was cancelled - exit early.
        return
      }

      // Check if task was cancelled after sleep.
      guard !Task.isCancelled else { return }

      // Perform the export and save.
      await capturedSelf.performDebouncedExportAndSave()
    }
  }

  // Internal method to perform the debounced export and save.
  private func performDebouncedExportAndSave() async {
    // Guard against re-entrancy if already exporting.
    guard !_isExporting else {
      // If already exporting, the pending changes flag is already set.
      // A new debounce will be scheduled after the current export completes.
      return
    }

    _isExporting = true

    do {
      // Export JIIX on MainActor since editor is MainActor-isolated.
      let jiix = try await MainActor.run {
        try self.editor.exportJIIX()
      }

      // Cache the exported JIIX.
      cachedJIIX = jiix

      // Log the JIIX content for debugging.
      print("===== JIIX EXPORT =====")
      print(jiix)
      print("===== END JIIX =====")

      // Convert to data for saving.
      guard let data = jiix.data(using: .utf8) else {
        _isExporting = false
        return
      }

      // Save to file.
      try await documentHandle.saveJIIXData(data)

      // Clear pending changes flag on successful save.
      _hasPendingChanges = false

      // Post notification for indexing.
      await postContentSavedNotification()
    } catch {
      // Export or save failed; pending changes remain.
    }

    _isExporting = false

    // Check if new changes arrived during export.
    if _hasPendingChanges {
      // Handle zero debounce as special case.
      if debounceDelaySeconds == 0 {
        await performDebouncedExportAndSave()
      } else {
        // Schedule another debounce using detached task.
        let capturedSelf = self
        debounceTask = Task.detached {
          do {
            let nanoseconds = UInt64(capturedSelf.debounceDelaySeconds * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
          } catch {
            // Task was cancelled - exit early.
            return
          }

          guard !Task.isCancelled else { return }

          await capturedSelf.performDebouncedExportAndSave()
        }
      }
    }
  }

  // Immediately exports and saves JIIX, bypassing the debounce timer.
  func saveNow() async throws {
    // Cancel any pending debounce timer.
    debounceTask?.cancel()
    debounceTask = nil

    // If no pending changes and we have cached JIIX, just save the cached version.
    if !_hasPendingChanges, let cached = cachedJIIX {
      guard let data = cached.data(using: .utf8) else {
        throw JIIXPersistenceError.saveFailed(reason: "Failed to encode cached JIIX as UTF-8")
      }
      do {
        try await documentHandle.saveJIIXData(data)
      } catch {
        throw JIIXPersistenceError.saveFailed(reason: error.localizedDescription)
      }
      return
    }

    _isExporting = true

    // Export JIIX on MainActor.
    let jiix: String
    do {
      jiix = try await MainActor.run {
        try self.editor.exportJIIX()
      }
    } catch {
      _isExporting = false
      throw JIIXPersistenceError.exportFailed(reason: error.localizedDescription)
    }

    // Cache the exported JIIX.
    cachedJIIX = jiix

    // Log the JIIX content for debugging.
    print("===== JIIX EXPORT =====")
    print(jiix)
    print("===== END JIIX =====")

    // Convert to data for saving.
    guard let data = jiix.data(using: .utf8) else {
      _isExporting = false
      throw JIIXPersistenceError.saveFailed(reason: "Failed to encode JIIX as UTF-8")
    }

    // Save to file.
    do {
      try await documentHandle.saveJIIXData(data)
    } catch {
      _isExporting = false
      throw JIIXPersistenceError.saveFailed(reason: error.localizedDescription)
    }

    // Clear pending changes flag on successful save.
    _hasPendingChanges = false
    _isExporting = false

    // Post notification for indexing.
    await postContentSavedNotification()
  }

  // Posts a notification that content was saved successfully.
  // Called after successful debounced or immediate saves.
  private func postContentSavedNotification() async {
    let capturedNotebookID = notebookID
    await MainActor.run {
      NotificationCenter.default.post(
        name: .notebookContentSaved,
        object: nil,
        userInfo: ["documentID": capturedNotebookID]
      )
    }
  }

  // Returns the current JIIX content as a string.
  // If content has changed since last export, performs a fresh export.
  func getJIIX() async throws -> String {
    // If no pending changes and we have cached JIIX, return cached version.
    if !_hasPendingChanges, let cached = cachedJIIX {
      return cached
    }

    // Perform fresh export on MainActor.
    let jiix: String
    do {
      jiix = try await MainActor.run {
        try self.editor.exportJIIX()
      }
    } catch {
      throw JIIXPersistenceError.exportFailed(reason: error.localizedDescription)
    }

    // Cache the exported JIIX (but don't clear pending changes since we didn't save).
    cachedJIIX = jiix

    return jiix
  }

  // Cancels any pending debounced save.
  func cancelPendingSave() async {
    debounceTask?.cancel()
    debounceTask = nil
  }

  // Forces an immediate export and save, called when app enters background.
  // Does not throw; errors are logged but not propagated.
  func handleAppBackground() async {
    // Cancel any pending debounce timer.
    debounceTask?.cancel()
    debounceTask = nil

    // If no pending changes, nothing to do.
    guard _hasPendingChanges else { return }

    // Wait for any in-progress export to complete.
    // Since this is an actor, the isExporting check and subsequent operations are serialized.
    // However, if an export is in progress, we should wait for it.
    while _isExporting {
      // Yield to allow the export to complete.
      try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    // If pending changes were cleared by the export, we're done.
    guard _hasPendingChanges else { return }

    // Perform immediate save (errors are caught but not propagated).
    do {
      try await saveNow()
    } catch {
      // Error is not propagated from background save.
    }
  }
}
