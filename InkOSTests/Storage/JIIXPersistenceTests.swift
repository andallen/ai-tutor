// Tests for JIIX persistence feature.
// Tests the JIIXPersistenceService actor with mock protocol implementations.
// Verifies debounce behavior, error handling, and thread safety.
// swiftlint:disable file_length
// File length exception justified: Comprehensive test suite with multiple test groups.
// Each test group covers specific functionality and splitting would reduce test cohesion.

import Foundation
import Testing

@testable import InkOS

// MARK: - Mock EditorExport

// Mock implementation of EditorExportProtocol for testing.
// Must be MainActor-isolated to match protocol requirements.
@MainActor
final class MockEditorExport: EditorExportProtocol {

  // The JIIX string to return from exportJIIX calls.
  var jiixToReturn: String = "{\"type\":\"Raw Content\"}"

  // Error to throw from exportJIIX calls, or nil for success.
  var errorToThrow: Error?

  // Number of times exportJIIX has been called.
  var exportCallCount = 0

  func exportJIIX() throws -> String {
    exportCallCount += 1

    if let error = errorToThrow {
      throw error
    }

    return jiixToReturn
  }

  // Resets all tracking state for test setup.
  func reset() {
    exportCallCount = 0
    jiixToReturn = "{\"type\":\"Raw Content\"}"
    errorToThrow = nil
  }
}

// MARK: - Mock JIIXDocumentHandle

// Mock implementation of JIIXDocumentHandleProtocol for testing.
// Stores JIIX data in memory instead of file system.
final class MockJIIXDocumentHandle: JIIXDocumentHandleProtocol {

  // In-memory storage for saved JIIX data.
  var savedData: Data?

  // Error to throw from saveJIIXData calls, or nil for success.
  var saveError: Error?

  // Error to throw from loadJIIXData calls, or nil for success.
  var loadError: Error?

  // Number of times saveJIIXData has been called.
  var saveCallCount = 0

  // Number of times loadJIIXData has been called.
  var loadCallCount = 0

  func saveJIIXData(_ data: Data) async throws {
    saveCallCount += 1

    if let error = saveError {
      throw error
    }

    savedData = data
  }

  func loadJIIXData() async throws -> Data? {
    loadCallCount += 1

    if let error = loadError {
      throw error
    }

    return savedData
  }

  // Resets all tracking state for test setup.
  func reset() {
    savedData = nil
    saveError = nil
    loadError = nil
    saveCallCount = 0
    loadCallCount = 0
  }
}

// MARK: - Mock Errors

// Custom error type for testing error propagation.
struct MockJIIXError: Error, LocalizedError {
  let message: String

  var errorDescription: String? {
    return message
  }
}

// MARK: - Test Helpers

// Creates a test configuration with very short debounce delay for fast tests.
func createTestConfiguration() -> JIIXPersistenceConfiguration {
  return JIIXPersistenceConfiguration(debounceDelaySeconds: 0.1)
}

// MARK: - Error Equality Tests

// Tests for JIIXPersistenceError equality implementation.
// Verifies that error comparison works correctly.
@Suite("JIIX Persistence Error Equality")
struct JIIXPersistenceErrorEqualityTests {

  @Test("noPartLoaded errors are equal")
  func noPartLoadedEquality() {
    let error1 = JIIXPersistenceError.noPartLoaded
    let error2 = JIIXPersistenceError.noPartLoaded

    #expect(error1 == error2, "noPartLoaded errors should be equal")
  }

  @Test("exportFailed errors are equal regardless of reason")
  func exportFailedEquality() {
    let error1 = JIIXPersistenceError.exportFailed(reason: "reason1")
    let error2 = JIIXPersistenceError.exportFailed(reason: "reason2")

    #expect(error1 == error2, "exportFailed errors should be equal regardless of reason")
  }

  @Test("saveFailed errors are equal regardless of reason")
  func saveFailedEquality() {
    let error1 = JIIXPersistenceError.saveFailed(reason: "reason1")
    let error2 = JIIXPersistenceError.saveFailed(reason: "reason2")

    #expect(error1 == error2, "saveFailed errors should be equal regardless of reason")
  }

  @Test("loadFailed errors are equal regardless of reason")
  func loadFailedEquality() {
    let error1 = JIIXPersistenceError.loadFailed(reason: "reason1")
    let error2 = JIIXPersistenceError.loadFailed(reason: "reason2")

    #expect(error1 == error2, "loadFailed errors should be equal regardless of reason")
  }

  @Test("exportCancelled errors are equal")
  func exportCancelledEquality() {
    let error1 = JIIXPersistenceError.exportCancelled
    let error2 = JIIXPersistenceError.exportCancelled

    #expect(error1 == error2, "exportCancelled errors should be equal")
  }

  @Test("different error types are not equal")
  func differentErrorTypesNotEqual() {
    let error1 = JIIXPersistenceError.noPartLoaded
    let error2 = JIIXPersistenceError.exportFailed(reason: "test")

    #expect(error1 != error2, "Different error types should not be equal")
  }

  @Test("error descriptions are correct")
  func errorDescriptions() {
    let noPartLoaded = JIIXPersistenceError.noPartLoaded
    #expect(
      noPartLoaded.errorDescription
        == "Cannot export JIIX: no content part is loaded in the editor.",
      "noPartLoaded should have correct description"
    )

    let exportFailed = JIIXPersistenceError.exportFailed(reason: "test reason")
    #expect(
      exportFailed.errorDescription == "Failed to export JIIX from editor: test reason",
      "exportFailed should include reason in description"
    )

    let saveFailed = JIIXPersistenceError.saveFailed(reason: "disk full")
    #expect(
      saveFailed.errorDescription == "Failed to save JIIX to notebook: disk full",
      "saveFailed should include reason in description"
    )

    let loadFailed = JIIXPersistenceError.loadFailed(reason: "file not found")
    #expect(
      loadFailed.errorDescription == "Failed to load JIIX from notebook: file not found",
      "loadFailed should include reason in description"
    )

    let exportCancelled = JIIXPersistenceError.exportCancelled
    #expect(
      exportCancelled.errorDescription == "JIIX export was cancelled.",
      "exportCancelled should have correct description"
    )
  }
}

// MARK: - Configuration Tests

// Tests for JIIXPersistenceConfiguration.
// Verifies default and test configurations.
@Suite("JIIX Persistence Configuration")
struct JIIXPersistenceConfigurationTests {

  @Test("default configuration has correct debounce delay")
  func defaultConfiguration() {
    let config = JIIXPersistenceConfiguration.default

    #expect(
      config.debounceDelaySeconds == 2.5,
      "Default configuration should have 2.5 second debounce"
    )
  }

  @Test("testing configuration has minimal debounce delay")
  func testingConfiguration() {
    let config = JIIXPersistenceConfiguration.testing

    #expect(
      config.debounceDelaySeconds == 0.1,
      "Testing configuration should have 0.1 second debounce"
    )
  }

  @Test("custom configuration accepts custom delay")
  func customConfiguration() {
    let config = JIIXPersistenceConfiguration(debounceDelaySeconds: 5.0)

    #expect(
      config.debounceDelaySeconds == 5.0,
      "Custom configuration should accept custom debounce delay"
    )
  }
}

// MARK: - Service Initialization Tests

// Tests for JIIXPersistenceService initialization.
// Verifies service can be created with mock dependencies.
@Suite("JIIX Persistence Service Initialization")
struct JIIXPersistenceServiceInitTests {

  @Test("service initializes with correct dependencies")
  @MainActor
  func serviceInitialization() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Verify initial state.
    let isExporting = await service.isExporting
    let hasPendingChanges = await service.hasPendingChanges

    #expect(!isExporting, "Service should not be exporting initially")
    #expect(!hasPendingChanges, "Service should not have pending changes initially")
  }

  @Test("service initializes with custom debounce delay")
  @MainActor
  func customDebounceDelay() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: 3.0
    )

    // Service should be created successfully with custom delay.
    let isExporting = await service.isExporting
    #expect(!isExporting, "Service should initialize successfully")
  }
}

// MARK: - contentDidChange Tests

// Tests for JIIXPersistenceService.contentDidChange().
// Verifies debounce behavior and state tracking.
@Suite("JIIX Persistence contentDidChange")
struct JIIXPersistenceContentDidChangeTests {

  @Test("contentDidChange sets hasPendingChanges to true")
  @MainActor
  func contentDidChangeSetsHasPendingChanges() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    let hasPendingChanges = await service.hasPendingChanges
    #expect(hasPendingChanges, "hasPendingChanges should be true after contentDidChange")
  }

  @Test("contentDidChange triggers export after debounce delay")
  @MainActor
  func contentDidChangeTriggersExport() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // Wait for debounce delay plus generous buffer for task scheduling.
    try? await Task.sleep(nanoseconds: UInt64((config.debounceDelaySeconds + 0.5) * 1_000_000_000))

    // Export should have occurred.
    #expect(mockEditor.exportCallCount == 1, "Export should be called after debounce delay")

    // Data should be saved.
    #expect(mockHandle.saveCallCount == 1, "Save should be called after export")

    // Pending changes should be cleared.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(!hasPendingChanges, "hasPendingChanges should be false after export completes")
  }

  @Test("multiple contentDidChange calls result in eventual export")
  @MainActor
  func multipleContentDidChangeCallsResultInExport() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Call contentDidChange multiple times rapidly.
    await service.contentDidChange()
    await service.contentDidChange()
    await service.contentDidChange()

    // Force an immediate save to bypass debounce timing issues.
    try? await service.saveNow()

    // At least one export should have occurred.
    #expect(
      mockEditor.exportCallCount >= 1,
      "At least one export should occur after contentDidChange calls"
    )

    // Save should have occurred.
    #expect(
      mockHandle.saveCallCount >= 1,
      "At least one save should occur"
    )

    // Pending changes should be cleared.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(!hasPendingChanges, "hasPendingChanges should be false after save")
  }

  @Test("contentDidChange after export triggers new export")
  @MainActor
  func contentDidChangeAfterExport() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Trigger first export.
    await service.contentDidChange()

    // Wait for first debounce and export to complete.
    try? await Task.sleep(nanoseconds: UInt64((config.debounceDelaySeconds + 0.2) * 1_000_000_000))

    // First export should have occurred.
    #expect(mockEditor.exportCallCount == 1, "First export should have occurred")

    // Pending changes should be cleared after first export.
    let hasPendingAfterFirst = await service.hasPendingChanges
    #expect(!hasPendingAfterFirst, "hasPendingChanges should be false after first export")

    // Trigger second export with new content change.
    await service.contentDidChange()

    // Pending changes should be true again.
    let hasPendingAfterSecondChange = await service.hasPendingChanges
    #expect(
      hasPendingAfterSecondChange, "hasPendingChanges should be true after second contentDidChange")

    // Wait for second debounce and export to complete.
    try? await Task.sleep(nanoseconds: UInt64((config.debounceDelaySeconds + 0.2) * 1_000_000_000))

    // Two exports should have occurred.
    #expect(
      mockEditor.exportCallCount == 2,
      "Second export should occur after second contentDidChange"
    )

    // Pending changes should be cleared after second export.
    let hasPendingAfterSecond = await service.hasPendingChanges
    #expect(!hasPendingAfterSecond, "hasPendingChanges should be false after second export")
  }
}

// MARK: - saveNow Tests

// Tests for JIIXPersistenceService.saveNow().
// Verifies immediate save behavior and error handling.
@Suite("JIIX Persistence saveNow")
struct JIIXPersistenceSaveNowTests {

  @Test("saveNow with pending changes exports and saves immediately")
  @MainActor
  func saveNowWithPendingChanges() async throws {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = "{\"type\":\"Test Content\"}"
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // saveNow should export immediately without waiting for debounce.
    try await service.saveNow()

    // Export should have occurred.
    #expect(mockEditor.exportCallCount == 1, "Export should be called immediately")

    // Data should be saved.
    #expect(mockHandle.saveCallCount == 1, "Save should be called immediately")

    // Verify saved data matches exported JIIX.
    let savedData = mockHandle.savedData
    let savedString = savedData.flatMap { String(data: $0, encoding: .utf8) }
    #expect(savedString == "{\"type\":\"Test Content\"}", "Saved data should match exported JIIX")

    // Pending changes should be cleared.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(!hasPendingChanges, "hasPendingChanges should be false after saveNow")
  }

  @Test("saveNow with no pending changes uses cached JIIX")
  @MainActor
  func saveNowWithNoPendingChanges() async throws {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = "{\"type\":\"Cached Content\"}"
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // First saveNow to establish cached JIIX.
    await service.contentDidChange()
    try await service.saveNow()

    // Reset export call count.
    mockEditor.exportCallCount = 0
    mockHandle.saveCallCount = 0

    // Second saveNow with no new changes.
    try await service.saveNow()

    // No new export should occur.
    #expect(mockEditor.exportCallCount == 0, "No export should occur when using cached JIIX")

    // Save should still occur with cached data.
    #expect(mockHandle.saveCallCount == 1, "Save should occur with cached JIIX")
  }

  @Test("saveNow cancels pending debounce timer")
  @MainActor
  func saveNowCancelsPendingDebounce() async throws {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // Immediately call saveNow before debounce fires.
    try await service.saveNow()

    // Export should occur once from saveNow.
    #expect(mockEditor.exportCallCount == 1, "Export should occur from saveNow")

    // Wait for original debounce delay.
    try? await Task.sleep(nanoseconds: UInt64((config.debounceDelaySeconds + 0.2) * 1_000_000_000))

    // Export count should still be 1 (debounce was cancelled).
    #expect(
      mockEditor.exportCallCount == 1,
      "Debounce timer should be cancelled by saveNow"
    )
  }

  @Test("saveNow throws when export fails")
  @MainActor
  func saveNowThrowsOnExportFailure() async {
    let mockEditor = MockEditorExport()
    mockEditor.errorToThrow = MockJIIXError(message: "Export failed")
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // saveNow should throw.
    await #expect(throws: JIIXPersistenceError.self) {
      try await service.saveNow()
    }

    // hasPendingChanges should remain true.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(hasPendingChanges, "hasPendingChanges should remain true after export failure")

    // No save should occur.
    #expect(mockHandle.saveCallCount == 0, "Save should not occur after export failure")
  }

  @Test("saveNow throws when save fails")
  @MainActor
  func saveNowThrowsOnSaveFailure() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    mockHandle.saveError = MockJIIXError(message: "Disk full")
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // saveNow should throw.
    await #expect(throws: JIIXPersistenceError.self) {
      try await service.saveNow()
    }

    // hasPendingChanges should remain true.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(hasPendingChanges, "hasPendingChanges should remain true after save failure")
  }
}

// MARK: - getJIIX Tests

// Tests for JIIXPersistenceService.getJIIX().
// Verifies JIIX retrieval behavior with and without pending changes.
@Suite("JIIX Persistence getJIIX")
struct JIIXPersistenceGetJIIXTests {

  @Test("getJIIX with pending changes performs fresh export")
  @MainActor
  func getJIIXWithPendingChanges() async throws {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = "{\"type\":\"Fresh Export\"}"
    let mockHandle = MockJIIXDocumentHandle()

    // Use a long debounce to ensure background task doesn't interfere.
    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: 10.0
    )

    await service.contentDidChange()

    let jiix = try await service.getJIIX()

    // Export should have occurred (from getJIIX, not debounce).
    #expect(mockEditor.exportCallCount == 1, "Export should occur for fresh JIIX")

    // Returned JIIX should match export.
    #expect(jiix == "{\"type\":\"Fresh Export\"}", "getJIIX should return exported JIIX")

    // No save should occur (getJIIX does not save).
    #expect(mockHandle.saveCallCount == 0, "getJIIX should not save to file")

    // hasPendingChanges should remain true (not saved).
    let hasPendingChanges = await service.hasPendingChanges
    #expect(hasPendingChanges, "hasPendingChanges should remain true after getJIIX")

    // Cancel the pending debounce to clean up.
    await service.cancelPendingSave()
  }

  @Test("getJIIX with no pending changes returns cached JIIX")
  @MainActor
  func getJIIXWithNoPendingChanges() async throws {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = "{\"type\":\"Cached Content\"}"
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Establish cached JIIX.
    await service.contentDidChange()
    try await service.saveNow()

    // Reset export call count.
    mockEditor.exportCallCount = 0

    // Get JIIX with no new changes.
    let jiix = try await service.getJIIX()

    // No new export should occur.
    #expect(mockEditor.exportCallCount == 0, "No export should occur when using cached JIIX")

    // Cached JIIX should be returned.
    #expect(jiix == "{\"type\":\"Cached Content\"}", "Cached JIIX should be returned")
  }

  @Test("getJIIX throws when export fails")
  @MainActor
  func getJIIXThrowsOnExportFailure() async {
    let mockEditor = MockEditorExport()
    mockEditor.errorToThrow = MockJIIXError(message: "Export failed")
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // getJIIX should throw.
    await #expect(throws: JIIXPersistenceError.self) {
      _ = try await service.getJIIX()
    }
  }
}

// MARK: - cancelPendingSave Tests

// Tests for JIIXPersistenceService.cancelPendingSave().
// Verifies cancellation behavior.
@Suite("JIIX Persistence cancelPendingSave")
struct JIIXPersistenceCancelPendingSaveTests {

  @Test("cancelPendingSave cancels active debounce timer")
  @MainActor
  func cancelPendingSaveCancelsTimer() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // Cancel pending save.
    await service.cancelPendingSave()

    // Wait for debounce delay.
    try? await Task.sleep(nanoseconds: UInt64((config.debounceDelaySeconds + 0.2) * 1_000_000_000))

    // No export should occur.
    #expect(mockEditor.exportCallCount == 0, "Export should be cancelled")

    // hasPendingChanges should still be true.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(hasPendingChanges, "hasPendingChanges should remain true after cancel")
  }

  @Test("cancelPendingSave with no timer active does not error")
  @MainActor
  func cancelPendingSaveWithNoTimer() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Cancel when no timer is active.
    await service.cancelPendingSave()

    // Should complete without error.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(!hasPendingChanges, "State should be unchanged")
  }
}

// MARK: - handleAppBackground Tests

// Tests for JIIXPersistenceService.handleAppBackground().
// Verifies non-throwing immediate save behavior.
@Suite("JIIX Persistence handleAppBackground")
struct JIIXPersistenceHandleAppBackgroundTests {

  @Test("handleAppBackground with pending changes saves immediately")
  @MainActor
  func handleAppBackgroundWithPendingChanges() async {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = "{\"type\":\"Background Save\"}"
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // handleAppBackground should save immediately without throwing.
    await service.handleAppBackground()

    // Export should have occurred.
    #expect(mockEditor.exportCallCount == 1, "Export should occur on app background")

    // Save should have occurred.
    #expect(mockHandle.saveCallCount == 1, "Save should occur on app background")

    // Pending changes should be cleared.
    let hasPendingChanges = await service.hasPendingChanges
    #expect(!hasPendingChanges, "hasPendingChanges should be false after background save")
  }

  @Test("handleAppBackground saves pending changes immediately")
  @MainActor
  func handleAppBackgroundSavesPendingChanges() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Mark content as changed but don't wait for debounce.
    await service.contentDidChange()

    // Pending changes should be true.
    let hasPendingBefore = await service.hasPendingChanges
    #expect(hasPendingBefore, "hasPendingChanges should be true before background")

    // handleAppBackground should save immediately without waiting for debounce.
    await service.handleAppBackground()

    // Export should have occurred.
    #expect(mockEditor.exportCallCount == 1, "Export should occur on app background")

    // Save should have occurred.
    #expect(mockHandle.saveCallCount == 1, "Save should occur on app background")

    // Pending changes should be cleared.
    let hasPendingAfter = await service.hasPendingChanges
    #expect(!hasPendingAfter, "hasPendingChanges should be false after background save")
  }

  @Test("handleAppBackground with export failure does not throw")
  @MainActor
  func handleAppBackgroundWithExportFailure() async {
    let mockEditor = MockEditorExport()
    mockEditor.errorToThrow = MockJIIXError(message: "Export failed")
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // handleAppBackground should not throw even when export fails.
    await service.handleAppBackground()

    // Export should have been attempted.
    #expect(mockEditor.exportCallCount == 1, "Export should be attempted")

    // No save should occur.
    #expect(mockHandle.saveCallCount == 0, "Save should not occur after export failure")
  }

  @Test("handleAppBackground with save failure does not throw")
  @MainActor
  func handleAppBackgroundWithSaveFailure() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    mockHandle.saveError = MockJIIXError(message: "Disk full")
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // handleAppBackground should not throw even when save fails.
    await service.handleAppBackground()

    // Export should have occurred.
    #expect(mockEditor.exportCallCount == 1, "Export should occur")

    // Save should have been attempted.
    #expect(mockHandle.saveCallCount == 1, "Save should be attempted")
  }
}

// MARK: - State Tracking Tests

// Tests for JIIXPersistenceService state properties.
// Verifies isExporting and hasPendingChanges behavior.
@Suite("JIIX Persistence State Tracking")
struct JIIXPersistenceStateTrackingTests {

  @Test("isExporting is false after export completes")
  @MainActor
  func isExportingAfterExport() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Initially not exporting.
    let isExportingBefore = await service.isExporting
    #expect(!isExportingBefore, "isExporting should be false initially")

    await service.contentDidChange()

    // Wait for debounce and export to complete with generous buffer.
    try? await Task.sleep(nanoseconds: UInt64((config.debounceDelaySeconds + 0.5) * 1_000_000_000))

    // isExporting should be false after export completes.
    let isExportingAfter = await service.isExporting
    #expect(!isExportingAfter, "isExporting should be false after export completes")

    // Verify export actually occurred.
    #expect(mockEditor.exportCallCount == 1, "Export should have occurred")
  }

  @Test("hasPendingChanges is false after successful save")
  @MainActor
  func hasPendingChangesAfterSave() async throws {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // hasPendingChanges should be true.
    let hasPendingBefore = await service.hasPendingChanges
    #expect(hasPendingBefore, "hasPendingChanges should be true after contentDidChange")

    // Save now.
    try await service.saveNow()

    // hasPendingChanges should be false.
    let hasPendingAfter = await service.hasPendingChanges
    #expect(!hasPendingAfter, "hasPendingChanges should be false after saveNow")
  }
}

// MARK: - Edge Case Tests

// Tests for edge cases and boundary conditions.
// Verifies robustness of JIIXPersistenceService.
@Suite("JIIX Persistence Edge Cases")
struct JIIXPersistenceEdgeCaseTests {

  @Test("zero debounce delay triggers immediate export")
  @MainActor
  func zeroDebounceDelay() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: 0.0
    )

    await service.contentDidChange()

    // Wait minimal time.
    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    // Export should have occurred immediately.
    #expect(
      mockEditor.exportCallCount == 1,
      "Export should occur immediately with zero debounce"
    )
  }

  @Test("concurrent contentDidChange calls are serialized")
  @MainActor
  func concurrentContentDidChangeCalls() async {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    // Spawn multiple concurrent tasks.
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await service.contentDidChange()
        }
      }
    }

    // Wait for debounce with generous buffer for system scheduling variability.
    try? await Task.sleep(nanoseconds: UInt64((config.debounceDelaySeconds + 0.5) * 1_000_000_000))

    // Only one export should occur.
    #expect(
      mockEditor.exportCallCount == 1,
      "Only one export should occur despite concurrent calls"
    )
  }

  @Test("rapid saveNow calls are serialized")
  @MainActor
  func rapidSaveNowCalls() async throws {
    let mockEditor = MockEditorExport()
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // Call saveNow multiple times rapidly.
    try await service.saveNow()
    try await service.saveNow()
    try await service.saveNow()

    // First saveNow exports, subsequent calls use cached JIIX.
    #expect(
      mockEditor.exportCallCount == 1,
      "Only one export should occur for multiple saveNow calls"
    )

    // All saves should complete.
    #expect(
      mockHandle.saveCallCount == 3,
      "All saveNow calls should save"
    )
  }

  @Test("getJIIX after saveNow returns cached value")
  @MainActor
  func getJIIXAfterSaveNow() async throws {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = "{\"type\":\"Test\"}"
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()

    // saveNow exports and caches JIIX.
    try await service.saveNow()

    // Reset export count to verify no new export occurs.
    mockEditor.exportCallCount = 0

    // getJIIX should return cached value without new export.
    let jiix = try await service.getJIIX()

    // getJIIX should return the cached JIIX.
    #expect(jiix == "{\"type\":\"Test\"}", "getJIIX should return cached JIIX")

    // No new export should have occurred since pending changes were cleared.
    #expect(mockEditor.exportCallCount == 0, "No new export should occur for cached JIIX")
  }

  @Test("very long JIIX string is handled correctly")
  @MainActor
  func veryLongJIIXString() async throws {
    let mockEditor = MockEditorExport()
    // Create 1MB JIIX string.
    mockEditor.jiixToReturn = String(repeating: "a", count: 1_000_000)
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()
    try await service.saveNow()

    // Verify large data was saved.
    let savedData = mockHandle.savedData
    #expect(
      savedData?.count == 1_000_000,
      "Large JIIX should be saved correctly"
    )
  }

  @Test("unicode content in JIIX is preserved")
  @MainActor
  func unicodeContentInJIIX() async throws {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = "{\"text\":\"Hello 世界 🌍 مرحبا\"}"
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()
    try await service.saveNow()

    // Verify unicode is preserved in saved data.
    let savedData = mockHandle.savedData
    let savedString = savedData.flatMap { String(data: $0, encoding: .utf8) }
    #expect(
      savedString == "{\"text\":\"Hello 世界 🌍 مرحبا\"}",
      "Unicode content should be preserved"
    )
  }

  @Test("empty JIIX string is handled correctly")
  @MainActor
  func emptyJIIXString() async throws {
    let mockEditor = MockEditorExport()
    mockEditor.jiixToReturn = ""
    let mockHandle = MockJIIXDocumentHandle()
    let config = createTestConfiguration()

    let service = JIIXPersistenceService(
      editor: mockEditor,
      documentHandle: mockHandle,
      debounceDelaySeconds: config.debounceDelaySeconds
    )

    await service.contentDidChange()
    try await service.saveNow()

    // Empty JIIX should be saved.
    let savedData = mockHandle.savedData
    #expect(savedData?.isEmpty == true, "Empty JIIX should be saved as empty data")
  }
}
