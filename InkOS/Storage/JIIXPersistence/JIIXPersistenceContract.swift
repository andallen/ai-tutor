// Contract.swift
// Defines the API contract for JIIX (JSON Interactive Ink eXchange) persistence.
// JIIX format enables full-text search, cloud sync, and LLM consumption of canvas content.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation

// MARK: - API Contract

// MARK: EditorExportProtocol

// Protocol abstracting JIIX export from IINKEditor for testability.
// Must be called on MainActor because the MyScript SDK is not thread-safe.
// The real IINKEditor will conform to this protocol via extension.
@MainActor
protocol EditorExportProtocol: AnyObject {
  // Exports the entire active part as a JIIX string.
  // Returns the JIIX JSON string representing the current editor content.
  // Throws if no part is loaded or export fails.
  func exportJIIX() throws -> String
}

/*
 ACCEPTANCE CRITERIA: EditorExportProtocol

 SCENARIO: Export JIIX from editor with content
 GIVEN: An editor with a part containing ink strokes
 WHEN: exportJIIX() is called
 THEN: Returns a valid JIIX JSON string
  AND: The string is non-empty
  AND: The string can be parsed as JSON

 SCENARIO: Export JIIX from empty canvas
 GIVEN: An editor with a part containing no content
 WHEN: exportJIIX() is called
 THEN: Returns a minimal valid JIIX JSON string
  AND: The string represents an empty document structure

 SCENARIO: Export JIIX with no part loaded
 GIVEN: An editor with no active part
 WHEN: exportJIIX() is called
 THEN: Throws JIIXPersistenceError.noPartLoaded
*/

// MARK: JIIXPersistenceService

// The JIIXPersistenceService actor is implemented in JIIXPersistenceService.swift.
// See the acceptance criteria comments below for the expected behavior.

/*
 ACCEPTANCE CRITERIA: JIIXPersistenceService.contentDidChange()

 SCENARIO: Single content change triggers debounced export
 GIVEN: A persistence service with 2.5 second debounce
 WHEN: contentDidChange() is called once
  AND: 2.5 seconds elapse without further changes
 THEN: JIIX is exported from editor
  AND: JIIX is saved to document bundle
  AND: hasPendingChanges becomes false

 SCENARIO: Rapid content changes reset debounce timer
 GIVEN: A persistence service with 2.5 second debounce
 WHEN: contentDidChange() is called
  AND: After 1 second, contentDidChange() is called again
  AND: After 1 second, contentDidChange() is called again
  AND: 2.5 seconds elapse without further changes
 THEN: Only one export operation occurs
  AND: The export happens 2.5 seconds after the last contentDidChange() call

 SCENARIO: contentDidChange during export in progress
 GIVEN: A persistence service currently performing an export
 WHEN: contentDidChange() is called
 THEN: hasPendingChanges becomes true
  AND: A new debounce timer is scheduled for after the current export completes
*/

/*
 ACCEPTANCE CRITERIA: JIIXPersistenceService.saveNow()

 SCENARIO: Immediate save with pending changes
 GIVEN: A persistence service with pending changes
 WHEN: saveNow() is called
 THEN: JIIX is exported from editor immediately
  AND: JIIX is saved to document bundle
  AND: hasPendingChanges becomes false
  AND: Any pending debounce timer is cancelled

 SCENARIO: Immediate save with no pending changes
 GIVEN: A persistence service with no pending changes
  AND: JIIX was previously exported
 WHEN: saveNow() is called
 THEN: No export is performed
  AND: The cached JIIX is saved to document bundle

 SCENARIO: saveNow fails due to export error
 GIVEN: A persistence service with pending changes
  AND: The editor export will fail
 WHEN: saveNow() is called
 THEN: Throws JIIXPersistenceError.exportFailed
  AND: hasPendingChanges remains true
  AND: No file is written

 SCENARIO: saveNow fails due to file write error
 GIVEN: A persistence service with pending changes
  AND: The file system write will fail
 WHEN: saveNow() is called
 THEN: Throws JIIXPersistenceError.saveFailed
  AND: hasPendingChanges remains true
*/

/*
 ACCEPTANCE CRITERIA: JIIXPersistenceService.getJIIX()

 SCENARIO: Get JIIX with pending changes
 GIVEN: A persistence service with pending changes
 WHEN: getJIIX() is called
 THEN: A fresh export is performed
  AND: Returns the newly exported JIIX string
  AND: Does not save to file
  AND: hasPendingChanges remains true

 SCENARIO: Get JIIX with no pending changes
 GIVEN: A persistence service with no pending changes
  AND: JIIX was previously exported and cached
 WHEN: getJIIX() is called
 THEN: Returns the cached JIIX string
  AND: No export is performed

 SCENARIO: Get JIIX fails due to export error
 GIVEN: A persistence service with pending changes
  AND: The editor export will fail
 WHEN: getJIIX() is called
 THEN: Throws JIIXPersistenceError.exportFailed
*/

/*
 ACCEPTANCE CRITERIA: JIIXPersistenceService.cancelPendingSave()

 SCENARIO: Cancel pending save with timer active
 GIVEN: A persistence service with an active debounce timer
 WHEN: cancelPendingSave() is called
 THEN: The debounce timer is cancelled
  AND: No export occurs
  AND: hasPendingChanges remains true

 SCENARIO: Cancel pending save with no timer active
 GIVEN: A persistence service with no active debounce timer
 WHEN: cancelPendingSave() is called
 THEN: No error occurs
  AND: State is unchanged
*/

/*
 ACCEPTANCE CRITERIA: JIIXPersistenceService.handleAppBackground()

 SCENARIO: App backgrounds with pending changes
 GIVEN: A persistence service with pending changes
 WHEN: handleAppBackground() is called
 THEN: JIIX is exported immediately
  AND: JIIX is saved to document bundle
  AND: The method completes without throwing

 SCENARIO: App backgrounds during export in progress
 GIVEN: A persistence service currently performing an export
 WHEN: handleAppBackground() is called
 THEN: Waits for current export to complete
  AND: Saves the exported JIIX to document bundle

 SCENARIO: App backgrounds with export failure
 GIVEN: A persistence service with pending changes
  AND: The editor export will fail
 WHEN: handleAppBackground() is called
 THEN: The error is logged
  AND: The method completes without throwing
*/

// MARK: JIIXDocumentHandleProtocol

// Protocol extending DocumentHandleProtocol with JIIX-specific file operations.
// Implemented by DocumentHandle to save and load JIIX files within notebook bundles.
protocol JIIXDocumentHandleProtocol: AnyObject, Sendable {
  // Saves JIIX data to the content.jiix file in the notebook bundle.
  // The data should be UTF-8 encoded JIIX JSON.
  // Uses atomic write to prevent corruption.
  func saveJIIXData(_ data: Data) async throws

  // Loads JIIX data from the content.jiix file in the notebook bundle.
  // Returns nil if the file does not exist (not an error condition).
  // Throws if the file exists but cannot be read.
  func loadJIIXData() async throws -> Data?
}

/*
 ACCEPTANCE CRITERIA: JIIXDocumentHandleProtocol.saveJIIXData()

 SCENARIO: Save JIIX to new file
 GIVEN: A notebook bundle without content.jiix
 WHEN: saveJIIXData() is called with valid JIIX data
 THEN: content.jiix is created in the bundle
  AND: The file contains the exact data provided
  AND: The file is written atomically

 SCENARIO: Save JIIX overwrites existing file
 GIVEN: A notebook bundle with existing content.jiix
 WHEN: saveJIIXData() is called with new JIIX data
 THEN: content.jiix is overwritten with new data
  AND: The old content is completely replaced

 SCENARIO: Save JIIX with empty data
 GIVEN: A notebook bundle
 WHEN: saveJIIXData() is called with empty Data
 THEN: content.jiix is created with zero bytes
  AND: No error is thrown

 SCENARIO: Save JIIX fails due to disk full
 GIVEN: A notebook bundle on a full disk
 WHEN: saveJIIXData() is called
 THEN: Throws JIIXPersistenceError.saveFailed
  AND: The original file (if any) is unchanged

 SCENARIO: Save JIIX fails due to permissions
 GIVEN: A notebook bundle without write permission
 WHEN: saveJIIXData() is called
 THEN: Throws JIIXPersistenceError.saveFailed
*/

/*
 ACCEPTANCE CRITERIA: JIIXDocumentHandleProtocol.loadJIIXData()

 SCENARIO: Load JIIX from existing file
 GIVEN: A notebook bundle with content.jiix containing valid data
 WHEN: loadJIIXData() is called
 THEN: Returns the file contents as Data
  AND: The data matches what was previously saved

 SCENARIO: Load JIIX when file does not exist
 GIVEN: A notebook bundle without content.jiix
 WHEN: loadJIIXData() is called
 THEN: Returns nil
  AND: No error is thrown

 SCENARIO: Load JIIX from empty file
 GIVEN: A notebook bundle with empty content.jiix
 WHEN: loadJIIXData() is called
 THEN: Returns empty Data
  AND: No error is thrown

 SCENARIO: Load JIIX fails due to read permissions
 GIVEN: A notebook bundle with content.jiix without read permission
 WHEN: loadJIIXData() is called
 THEN: Throws JIIXPersistenceError.loadFailed
*/

// MARK: - Error Definitions

// Errors for JIIX persistence operations.
// Provides clear error messages for debugging and user feedback.
enum JIIXPersistenceError: Error, LocalizedError, Equatable {
  // No part is loaded in the editor, cannot export.
  case noPartLoaded

  // JIIX export from the editor failed.
  // Includes the underlying error description for debugging.
  case exportFailed(reason: String)

  // Failed to save JIIX data to the file system.
  case saveFailed(reason: String)

  // Failed to load JIIX data from the file system.
  case loadFailed(reason: String)

  // Export was cancelled due to notebook closing.
  case exportCancelled

  var errorDescription: String? {
    switch self {
    case .noPartLoaded:
      return "Cannot export JIIX: no content part is loaded in the editor."
    case .exportFailed(let reason):
      return "Failed to export JIIX from editor: \(reason)"
    case .saveFailed(let reason):
      return "Failed to save JIIX to notebook: \(reason)"
    case .loadFailed(let reason):
      return "Failed to load JIIX from notebook: \(reason)"
    case .exportCancelled:
      return "JIIX export was cancelled."
    }
  }

  // Equatable conformance for testing.
  // Only compares case type, not associated values.
  static func == (lhs: JIIXPersistenceError, rhs: JIIXPersistenceError) -> Bool {
    switch (lhs, rhs) {
    case (.noPartLoaded, .noPartLoaded):
      return true
    case (.exportFailed, .exportFailed):
      return true
    case (.saveFailed, .saveFailed):
      return true
    case (.loadFailed, .loadFailed):
      return true
    case (.exportCancelled, .exportCancelled):
      return true
    default:
      return false
    }
  }
}

// MARK: - Supporting Types

// Configuration for the JIIX persistence service.
// Allows customization of debounce timing for different use cases.
struct JIIXPersistenceConfiguration: Sendable {
  // Delay in seconds before exporting after content changes.
  // Recommended range: 2.0 to 3.0 seconds.
  let debounceDelaySeconds: Double

  // Default configuration with 2.5 second debounce.
  static let `default` = JIIXPersistenceConfiguration(debounceDelaySeconds: 2.5)

  // Configuration for testing with minimal debounce.
  static let testing = JIIXPersistenceConfiguration(debounceDelaySeconds: 0.1)
}

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Negative debounce delay
 GIVEN: JIIXPersistenceService initialization
 WHEN: debounceDelaySeconds is negative
 THEN: Uses absolute value of the delay
  AND: Logs a warning about invalid configuration

 EDGE CASE: Zero debounce delay
 GIVEN: JIIXPersistenceService initialization with 0 delay
 WHEN: contentDidChange() is called
 THEN: Export occurs immediately
  AND: No timer is scheduled

 EDGE CASE: Very long JIIX string
 GIVEN: A canvas with extensive content producing megabytes of JIIX
 WHEN: exportJIIX() is called
 THEN: Export completes successfully
  AND: File save handles large data correctly

 EDGE CASE: Concurrent contentDidChange calls
 GIVEN: A persistence service
 WHEN: Multiple contentDidChange() calls arrive simultaneously from different tasks
 THEN: Actor serialization ensures only one debounce timer is active
  AND: No race conditions occur

 EDGE CASE: Export called during deallocation
 GIVEN: A persistence service being deallocated
 WHEN: The debounce timer fires
 THEN: Export is cancelled gracefully
  AND: No crash occurs

 EDGE CASE: DocumentHandle closed before debounce completes
 GIVEN: A persistence service with pending debounce
 WHEN: The DocumentHandle is closed
 THEN: The debounce is cancelled via cancelPendingSave()
  AND: No attempt is made to save

 EDGE CASE: Editor becomes nil before debounce completes
 GIVEN: A persistence service with pending debounce
  AND: The editor is held weakly
 WHEN: The editor is deallocated before debounce fires
 THEN: Export logs error and completes
  AND: No crash occurs
  AND: hasPendingChanges remains true

 EDGE CASE: Unicode content in JIIX
 GIVEN: A canvas containing text with emoji, CJK, and RTL characters
 WHEN: exportJIIX() is called
 THEN: JIIX correctly encodes all Unicode
  AND: File save uses UTF-8 encoding

 EDGE CASE: Recognition ongoing during export
 GIVEN: The MyScript SDK is performing handwriting recognition
 WHEN: exportJIIX() is called
 THEN: Export may fail with recognition-in-progress error
  AND: JIIXPersistenceError.exportFailed is thrown
  AND: Caller should retry after recognition completes

 EDGE CASE: Rapid saveNow calls
 GIVEN: A persistence service
 WHEN: saveNow() is called multiple times in rapid succession
 THEN: Actor serialization ensures orderly execution
  AND: Each call waits for the previous to complete
  AND: No duplicate saves occur if no changes between calls

 EDGE CASE: getJIIX during saveNow
 GIVEN: A persistence service performing saveNow()
 WHEN: getJIIX() is called
 THEN: getJIIX waits for saveNow to complete
  AND: Returns the JIIX that was just saved

 EDGE CASE: handleAppBackground during export
 GIVEN: A persistence service performing a debounced export
 WHEN: handleAppBackground() is called
 THEN: Waits for the current export to complete
  AND: Ensures the file is saved before returning

 EDGE CASE: File system full during atomic write
 GIVEN: A notebook bundle on a nearly-full disk
 WHEN: saveJIIXData() performs atomic write
 THEN: Original file remains intact
  AND: Temporary file is cleaned up
  AND: Error is thrown with appropriate message
*/

// MARK: - Integration Points

/*
 INTEGRATION: EditorViewModel.contentChanged delegate callback
 The JIIXPersistenceService.contentDidChange() should be called from
 EditorViewModel.contentChanged(editor:blockIds:) to trigger debounced export.

 INTEGRATION: EditorViewModel.handleAppBackground
 The JIIXPersistenceService.handleAppBackground() should be called from
 EditorViewModel.handleAppBackground() to ensure JIIX is saved immediately.

 INTEGRATION: EditorViewModel.releaseEditor
 The JIIXPersistenceService should be notified when the editor is released:
 1. Call cancelPendingSave() if discarding changes
 2. Call saveNow() if preserving changes before close

 INTEGRATION: DocumentHandle file operations
 DocumentHandle should implement JIIXDocumentHandleProtocol to provide
 saveJIIXData() and loadJIIXData() operations within the notebook bundle.
 The file should be named "content.jiix" alongside "content.iink".

 INTEGRATION: IINKEditor JIIX export
 IINKEditor should conform to EditorExportProtocol via extension.
 The implementation calls export_(selection:mimeType:) with:
 - selection: nil (export entire part)
 - mimeType: IINKMimeType.JIIX
*/

// MARK: - Thread Safety Requirements

/*
 THREADING: MainActor for SDK calls
 All calls to EditorExportProtocol.exportJIIX() must occur on MainActor.
 The JIIXPersistenceService must hop to MainActor before calling the editor.

 THREADING: Actor isolation for file I/O
 JIIXDocumentHandleProtocol methods run within the DocumentHandle actor.
 File operations are serialized to prevent corruption.

 THREADING: Task cancellation
 The debounce Task must check for cancellation before performing export.
 Cancellation occurs when:
 - cancelPendingSave() is called
 - A new contentDidChange() resets the timer
 - The persistence service is deallocated
*/
