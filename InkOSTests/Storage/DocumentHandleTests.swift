//
// Tests for DocumentHandle actor.
// Tests the real DocumentHandle with mock SDK dependencies.
//

import Testing
import Foundation
import CoreGraphics
@testable import InkOS

// MARK: - Mock Types

// Mock content part conforming to ContentPartProtocol.
// Named MockDocumentHandlePart to avoid conflict with other test files.
final class MockDocumentHandlePart: ContentPartProtocol {
  let type: String
  let identifier: String

  init(type: String) {
    self.type = type
    self.identifier = UUID().uuidString
  }
}

// Mock content package conforming to ContentPackageProtocol.
// Named MockDocumentHandlePackage to avoid conflict with other test files.
@MainActor
final class MockDocumentHandlePackage: ContentPackageProtocol {
  var parts: [MockDocumentHandlePart] = []
  var saveCallCount = 0
  var saveToTempCallCount = 0
  var shouldThrowOnSave = false
  var shouldThrowOnSaveToTemp = false
  var shouldThrowOnCreatePart = false
  var shouldThrowOnGetPart = false

  func getPartCount() -> Int {
    return parts.count
  }

  func getPart(at index: Int) throws -> any ContentPartProtocol {
    if shouldThrowOnGetPart {
      throw MockError.partAccessFailed
    }
    guard index >= 0 && index < parts.count else {
      throw MockError.indexOutOfBounds
    }
    return parts[index]
  }

  func createNewPart(with type: String) throws -> any ContentPartProtocol {
    if shouldThrowOnCreatePart {
      throw MockError.partCreationFailed
    }
    let part = MockDocumentHandlePart(type: type)
    parts.append(part)
    return part
  }

  func createNewPart(with type: String, fixedSize: CGSize) throws -> any ContentPartProtocol {
    if shouldThrowOnCreatePart {
      throw MockError.partCreationFailed
    }
    let part = MockDocumentHandlePart(type: type)
    parts.append(part)
    return part
  }

  func savePackage() throws {
    if shouldThrowOnSave {
      throw MockError.packageSaveFailed
    }
    saveCallCount += 1
  }

  func savePackageToTemp() throws {
    if shouldThrowOnSaveToTemp {
      throw MockError.packageSaveFailed
    }
    saveToTempCallCount += 1
  }
}

// Mock engine conforming to EngineProtocol.
// Named MockDocumentHandleEngine to avoid conflict with other test files.
@MainActor
final class MockDocumentHandleEngine: EngineProtocol {
  var openCallCount = 0
  var createCallCount = 0
  var lastOpenedPath: String?
  var lastCreatedPath: String?
  var lastOpenOption: IINKPackageOpenOption?
  var shouldThrowOnOpen = false
  var shouldThrowOnCreate = false
  var mockPackage: MockDocumentHandlePackage?

  func openContentPackage(_ path: String, openOption: IINKPackageOpenOption) throws -> any ContentPackageProtocol {
    openCallCount += 1
    lastOpenedPath = path
    lastOpenOption = openOption

    if shouldThrowOnOpen {
      throw MockError.packageOpenFailed
    }

    let package = mockPackage ?? MockDocumentHandlePackage()
    mockPackage = package
    return package
  }

  func createContentPackage(_ path: String) throws -> any ContentPackageProtocol {
    createCallCount += 1
    lastCreatedPath = path

    if shouldThrowOnCreate {
      throw MockError.packageCreationFailed
    }

    let package = mockPackage ?? MockDocumentHandlePackage()
    mockPackage = package
    return package
  }
}

// Mock engine provider conforming to EngineProviderProtocol.
// Named MockDocumentHandleEngineProvider to avoid conflict with MockEngineProvider in EditorViewModelTests.
@MainActor
final class MockDocumentHandleEngineProvider: EngineProviderProtocol {
  var engineInstance: (any EngineProtocol)?

  // Accepts an optional engine. If nil, creates a default MockDocumentHandleEngine.
  init(engine: MockDocumentHandleEngine? = nil) {
    self.engineInstance = engine ?? MockDocumentHandleEngine()
  }

  // Convenience initializer to explicitly set no engine (for testing nil engine case).
  init(noEngine: Bool) {
    self.engineInstance = nil
  }
}

// Mock errors for testing error handling.
enum MockError: Error, LocalizedError {
  case engineUnavailable
  case packageOpenFailed
  case packageCreationFailed
  case packageSaveFailed
  case partCreationFailed
  case partAccessFailed
  case indexOutOfBounds

  var errorDescription: String? {
    switch self {
    case .engineUnavailable:
      return "Mock engine is not available."
    case .packageOpenFailed:
      return "Mock package open failed."
    case .packageCreationFailed:
      return "Mock package creation failed."
    case .packageSaveFailed:
      return "Mock package save failed."
    case .partCreationFailed:
      return "Mock part creation failed."
    case .partAccessFailed:
      return "Mock part access failed."
    case .indexOutOfBounds:
      return "Mock index out of bounds."
    }
  }
}

// MARK: - Test Helpers

// Creates a test manifest with the given notebook ID and display name.
// Uses the Manifest(notebookID:displayName:) initializer which sets default timestamps.
func createTestManifest(notebookID: String, displayName: String) -> Manifest {
  return Manifest(notebookID: notebookID, displayName: displayName)
}

// MARK: - Test Suite

@Suite("DocumentHandle Tests")
struct DocumentHandleTests {

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("successful initialization opens package")
    @MainActor
    func successfulInitialization() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      #expect(await handle.notebookID == "test-id")
      #expect(engine.openCallCount == 1)
    }

    @Test("initialization throws when engine is nil")
    @MainActor
    func throwsWhenEngineNil() async {
      let engineProvider = MockDocumentHandleEngineProvider(noEngine: true)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      await #expect(throws: DocumentHandleError.self) {
        _ = try await DocumentHandle(
          notebookID: "test-id",
          bundleURL: bundleURL,
          manifest: manifest,
          packagePath: "/tmp/test.iink",
          openOption: .existing,
          engineProvider: engineProvider
        )
      }
    }

    @Test("initialization throws when package open fails")
    @MainActor
    func throwsWhenPackageOpenFails() async {
      let engine = MockDocumentHandleEngine()
      engine.shouldThrowOnOpen = true
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      await #expect(throws: DocumentHandleError.self) {
        _ = try await DocumentHandle(
          notebookID: "test-id",
          bundleURL: bundleURL,
          manifest: manifest,
          packagePath: "/tmp/test.iink",
          openOption: .existing,
          engineProvider: engineProvider
        )
      }
    }

    @Test("initialization passes correct path to engine")
    @MainActor
    func passesCorrectPathToEngine() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")
      let expectedPath = "/Users/test/notebooks/content.iink"

      _ = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: expectedPath,
        openOption: .existing,
        engineProvider: engineProvider
      )

      #expect(engine.lastOpenedPath == expectedPath)
    }

    @Test("initialization passes correct open option to engine")
    @MainActor
    func passesCorrectOpenOptionToEngine() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      _ = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .create,
        engineProvider: engineProvider
      )

      #expect(engine.lastOpenOption == .create)
    }
  }

  // MARK: - Properties Tests

  @Suite("Properties")
  struct PropertiesTests {

    @Test("notebookID is set correctly")
    @MainActor
    func notebookIDSetCorrectly() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-123", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-123",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      #expect(await handle.notebookID == "test-123")
    }

    @Test("packagePath is set correctly")
    @MainActor
    func packagePathSetCorrectly() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")
      let expectedPath = "/Users/test/Documents/notebook.iink"

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: expectedPath,
        openOption: .existing,
        engineProvider: engineProvider
      )

      #expect(await handle.packagePath == expectedPath)
    }

    @Test("initialManifest is snapshot at open time")
    @MainActor
    func initialManifestIsSnapshot() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Original Name")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      let initialDisplayName = await handle.initialManifest.displayName
      #expect(initialDisplayName == "Original Name")
    }

    @Test("manifest reflects current state")
    @MainActor
    func manifestReflectsCurrentState() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      // Initially no viewport state.
      var currentState = await handle.manifest.viewportState
      #expect(currentState == nil)

      // Update viewport state.
      let newState = ViewportState(offsetX: 50, offsetY: 100, scale: 1.5)
      await handle.updateViewportState(newState)

      // Manifest should now reflect the update.
      currentState = await handle.manifest.viewportState
      #expect(currentState?.offsetX == 50)
      #expect(currentState?.offsetY == 100)
      #expect(currentState?.scale == 1.5)
    }
  }

  // MARK: - getPackage Tests

  @Suite("getPackage")
  struct GetPackageTests {

    @Test("getPackage returns opened package")
    @MainActor
    func returnsOpenedPackage() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      let package = await handle.getPackage()
      #expect(package != nil)
    }

    @Test("getPackage returns nil after close")
    @MainActor
    func returnsNilAfterClose() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: false)

      let package = await handle.getPackage()
      #expect(package == nil)
    }
  }

  // MARK: - getPartCount Tests

  @Suite("getPartCount")
  struct GetPartCountTests {

    @Test("getPartCount returns 0 for empty package")
    @MainActor
    func returnsZeroForEmpty() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      let count = await handle.getPartCount()
      #expect(count == 0)
    }

    @Test("getPartCount returns correct count after creating parts")
    @MainActor
    func returnsCorrectCountAfterCreatingParts() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      // Create a part.
      _ = try await handle.ensureInitialPart(type: "Drawing")

      let count = await handle.getPartCount()
      #expect(count == 1)
    }

    @Test("getPartCount returns 0 after close")
    @MainActor
    func returnsZeroAfterClose() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      _ = try await handle.ensureInitialPart(type: "Drawing")
      await handle.close(saveBeforeClose: false)

      let count = await handle.getPartCount()
      #expect(count == 0)
    }
  }

  // MARK: - getPart Tests

  @Suite("getPart")
  struct GetPartTests {

    @Test("getPart returns part at valid index")
    @MainActor
    func returnsPartAtValidIndex() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      _ = try await handle.ensureInitialPart(type: "Drawing")

      let part = await handle.getPart(at: 0)
      #expect(part != nil)
    }

    @Test("getPart returns nil for negative index")
    @MainActor
    func returnsNilForNegativeIndex() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      _ = try await handle.ensureInitialPart(type: "Drawing")

      let part = await handle.getPart(at: -1)
      #expect(part == nil)
    }

    @Test("getPart returns nil for index out of bounds")
    @MainActor
    func returnsNilForOutOfBounds() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      _ = try await handle.ensureInitialPart(type: "Drawing")

      let part = await handle.getPart(at: 100)
      #expect(part == nil)
    }

    @Test("getPart returns nil after close")
    @MainActor
    func returnsNilAfterClose() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      _ = try await handle.ensureInitialPart(type: "Drawing")
      await handle.close(saveBeforeClose: false)

      let part = await handle.getPart(at: 0)
      #expect(part == nil)
    }
  }

  // MARK: - ensureInitialPart Tests

  @Suite("ensureInitialPart")
  struct EnsureInitialPartTests {

    @Test("ensureInitialPart creates part when package is empty")
    @MainActor
    func createsPartWhenEmpty() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      let part = try await handle.ensureInitialPart(type: "Drawing")
      #expect(part != nil)
      #expect(await handle.getPartCount() == 1)
    }

    @Test("ensureInitialPart returns existing part when available")
    @MainActor
    func returnsExistingPart() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      // Create the first part.
      let firstPart = try await handle.ensureInitialPart(type: "Drawing")
      let firstPartMock = firstPart as? MockDocumentHandlePart

      // Call again should return the same part.
      let secondPart = try await handle.ensureInitialPart(type: "Text Document")
      let secondPartMock = secondPart as? MockDocumentHandlePart

      #expect(firstPartMock?.identifier == secondPartMock?.identifier)
      #expect(await handle.getPartCount() == 1)
    }

    @Test("ensureInitialPart throws when package is nil")
    @MainActor
    func throwsWhenPackageNil() async throws {
      let engine = MockDocumentHandleEngine()
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: false)

      await #expect(throws: DocumentHandleError.self) {
        _ = try await handle.ensureInitialPart(type: "Drawing")
      }
    }

    @Test("ensureInitialPart throws when part creation fails")
    @MainActor
    func throwsWhenPartCreationFails() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      mockPackage.shouldThrowOnCreatePart = true
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await #expect(throws: DocumentHandleError.self) {
        _ = try await handle.ensureInitialPart(type: "Drawing")
      }
    }
  }

  // MARK: - savePackage Tests

  @Suite("savePackage")
  struct SavePackageTests {

    @Test("savePackage calls save on package")
    @MainActor
    func callsSaveOnPackage() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      try await handle.savePackage()

      #expect(mockPackage.saveCallCount == 1)
    }

    @Test("savePackage throws when package is nil")
    @MainActor
    func throwsWhenPackageNil() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: false)

      await #expect(throws: DocumentHandleError.self) {
        try await handle.savePackage()
      }
    }

    @Test("savePackage can be called multiple times")
    @MainActor
    func canBeCalledMultipleTimes() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      try await handle.savePackage()
      try await handle.savePackage()
      try await handle.savePackage()

      #expect(mockPackage.saveCallCount == 3)
    }
  }

  // MARK: - savePackageToTemp Tests

  @Suite("savePackageToTemp")
  struct SavePackageToTempTests {

    @Test("savePackageToTemp calls saveToTemp on package")
    @MainActor
    func callsSaveToTempOnPackage() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      try await handle.savePackageToTemp()

      #expect(mockPackage.saveToTempCallCount == 1)
    }

    @Test("savePackageToTemp throws when package is nil")
    @MainActor
    func throwsWhenPackageNil() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: false)

      await #expect(throws: DocumentHandleError.self) {
        try await handle.savePackageToTemp()
      }
    }
  }

  // MARK: - close Tests

  @Suite("close")
  struct CloseTests {

    @Test("close with saveBeforeClose=true saves package")
    @MainActor
    func withSaveBeforeCloseTrueSavesPackage() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: true)

      #expect(mockPackage.saveCallCount == 1)
    }

    @Test("close with saveBeforeClose=false does not save")
    @MainActor
    func withSaveBeforeCloseFalseDoesNotSave() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: false)

      #expect(mockPackage.saveCallCount == 0)
    }

    @Test("close releases package reference")
    @MainActor
    func releasesPackageReference() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: false)

      let package = await handle.getPackage()
      #expect(package == nil)
    }

    @Test("close can be called multiple times safely")
    @MainActor
    func canBeCalledMultipleTimesSafely() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.close(saveBeforeClose: true)
      await handle.close(saveBeforeClose: true)
      await handle.close(saveBeforeClose: false)

      // Should not crash.
      #expect(await handle.getPackage() == nil)
    }

    @Test("close ignores save errors and still releases package")
    @MainActor
    func ignoresSaveErrorsAndReleasesPackage() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      mockPackage.shouldThrowOnSave = true
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      // Should not throw even though save fails.
      await handle.close(saveBeforeClose: true)

      // Package should still be released.
      #expect(await handle.getPackage() == nil)
    }
  }

  // MARK: - updateViewportState Tests

  @Suite("updateViewportState")
  struct UpdateViewportStateTests {

    @Test("updateViewportState updates manifest viewportState")
    @MainActor
    func updatesManifestViewportState() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      let newState = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      await handle.updateViewportState(newState)

      let savedState = await handle.manifest.viewportState
      #expect(savedState?.offsetX == 100)
      #expect(savedState?.offsetY == 200)
      #expect(savedState?.scale == 2.0)
    }

    @Test("updateViewportState updates modifiedAt timestamp")
    @MainActor
    func updatesModifiedAtTimestamp() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      let originalModifiedAt = await handle.manifest.modifiedAt

      // Small delay to ensure different timestamp.
      try await Task.sleep(nanoseconds: 10_000_000)

      let newState = ViewportState(offsetX: 50, offsetY: 75, scale: 1.5)
      await handle.updateViewportState(newState)

      let newModifiedAt = await handle.manifest.modifiedAt
      #expect(newModifiedAt > originalModifiedAt)
    }

    @Test("updateViewportState does not affect initialManifest")
    @MainActor
    func doesNotAffectInitialManifest() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      let newState = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      await handle.updateViewportState(newState)

      let initialViewport = await handle.initialManifest.viewportState
      #expect(initialViewport == nil)
    }

    @Test("updateViewportState can be called multiple times")
    @MainActor
    func canBeCalledMultipleTimes() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await handle.updateViewportState(ViewportState(offsetX: 10, offsetY: 20, scale: 1.0))
      await handle.updateViewportState(ViewportState(offsetX: 30, offsetY: 40, scale: 1.5))
      await handle.updateViewportState(ViewportState(offsetX: 50, offsetY: 60, scale: 2.0))

      let finalState = await handle.manifest.viewportState
      #expect(finalState?.offsetX == 50)
      #expect(finalState?.offsetY == 60)
      #expect(finalState?.scale == 2.0)
    }
  }

  // MARK: - Error Descriptions Tests

  @Suite("Error Descriptions")
  struct ErrorDescriptionsTests {

    @Test("engineUnavailable has correct description")
    func engineUnavailableDescription() {
      let error = DocumentHandleError.engineUnavailable
      #expect(error.errorDescription == "MyScript engine is not available.")
    }

    @Test("packageNotAvailable has correct description")
    func packageNotAvailableDescription() {
      let error = DocumentHandleError.packageNotAvailable
      #expect(error.errorDescription == "MyScript package is not available.")
    }
  }

  // MARK: - Thread Safety Tests

  @Suite("Thread Safety")
  struct ThreadSafetyTests {

    @Test("concurrent operations do not corrupt state")
    @MainActor
    func concurrentOperationsDoNotCorruptState() async throws {
      let engineProvider = MockDocumentHandleEngineProvider()
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await withTaskGroup(of: Void.self) { group in
        for i in 0..<50 {
          group.addTask {
            let state = ViewportState(
              offsetX: Float(i),
              offsetY: Float(i * 2),
              scale: 1.0 + Float(i) / 100.0
            )
            await handle.updateViewportState(state)
          }

          group.addTask {
            _ = await handle.manifest
          }

          group.addTask {
            _ = await handle.getPackage()
          }
        }
      }

      // Should complete without data race.
      let finalState = await handle.manifest.viewportState
      #expect(finalState != nil)
    }

    @Test("rapid save operations are serialized")
    @MainActor
    func rapidSaveOperationsAreSerialized() async throws {
      let engine = MockDocumentHandleEngine()
      let mockPackage = MockDocumentHandlePackage()
      engine.mockPackage = mockPackage
      let engineProvider = MockDocumentHandleEngineProvider(engine: engine)
      let manifest = createTestManifest(notebookID: "test-id", displayName: "Test")
      let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-bundle")

      let handle = try await DocumentHandle(
        notebookID: "test-id",
        bundleURL: bundleURL,
        manifest: manifest,
        packagePath: "/tmp/test.iink",
        openOption: .existing,
        engineProvider: engineProvider
      )

      await withTaskGroup(of: Void.self) { group in
        for _ in 0..<20 {
          group.addTask {
            try? await handle.savePackageToTemp()
          }
        }
      }

      #expect(mockPackage.saveToTempCallCount == 20)
    }
  }
}
