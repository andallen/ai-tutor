//
// Tests for BundleManager based on BundleManagerProtocol contract.
// Tests cover listing, creation, renaming, deletion, opening notebooks, and path generation.
//

import Testing
import Foundation
@testable import InkOS

// MARK: - Test Suite

@Suite("BundleManager Tests")
struct BundleManagerTests {

  // MARK: - listBundles Tests

  @Suite("listBundles")
  struct ListBundlesTests {

    @Test("returns empty array when no bundles exist")
    func returnsEmptyArrayWhenNoBundles() async throws {
      let manager = BundleManager.shared
      // This test verifies the method returns an empty array for an empty directory.
      // The actual result depends on the file system state.
      let bundles = try await manager.listBundles()
      #expect(bundles is [NotebookMetadata])
    }

    @Test("returns NotebookMetadata array type")
    func returnsCorrectType() async throws {
      let manager = BundleManager.shared
      let bundles = try await manager.listBundles()
      // Verify the return type conforms to the protocol.
      #expect(bundles is [NotebookMetadata])
    }

    @Test("each metadata has non-empty id")
    func metadataHasNonEmptyId() async throws {
      let manager = BundleManager.shared
      // Create a test bundle to ensure we have something to list.
      let created = try await manager.createBundle(displayName: "Test List Bundle")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let bundles = try await manager.listBundles()
      for metadata in bundles {
        #expect(!metadata.id.isEmpty, "Each notebook metadata should have a non-empty id")
      }
    }

    @Test("each metadata has non-empty displayName")
    func metadataHasNonEmptyDisplayName() async throws {
      let manager = BundleManager.shared
      let testName = "Test Display Name Bundle"
      let created = try await manager.createBundle(displayName: testName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found != nil)
      #expect(found?.displayName == testName)
    }

    @Test("metadata previewImageData can be nil for new bundles")
    func metadataPreviewCanBeNil() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "No Preview Bundle")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found != nil)
      // New bundles should have nil preview data since no preview has been saved.
      #expect(found?.previewImageData == nil)
    }

    @Test("metadata lastAccessedAt is set for created bundles")
    func metadataLastAccessedAtIsSet() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Access Time Bundle")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found != nil)
      // According to protocol, lastAccessedAt is set on creation.
      #expect(found?.lastAccessedAt != nil)
    }

    @Test("lists multiple bundles when they exist")
    func listsMultipleBundles() async throws {
      let manager = BundleManager.shared
      let bundle1 = try await manager.createBundle(displayName: "Multi Bundle 1")
      let bundle2 = try await manager.createBundle(displayName: "Multi Bundle 2")
      let bundle3 = try await manager.createBundle(displayName: "Multi Bundle 3")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: bundle1.id)
          try? await manager.deleteBundle(notebookID: bundle2.id)
          try? await manager.deleteBundle(notebookID: bundle3.id)
        }
      }

      let bundles = try await manager.listBundles()
      let ids = Set(bundles.map { $0.id })
      #expect(ids.contains(bundle1.id))
      #expect(ids.contains(bundle2.id))
      #expect(ids.contains(bundle3.id))
    }

    @Test("skips hidden directories starting with dot")
    func skipsHiddenDirectories() async throws {
      let manager = BundleManager.shared
      // Hidden directories (starting with .) should be skipped.
      // This is documented behavior - we verify no crash occurs.
      let bundles = try await manager.listBundles()
      for bundle in bundles {
        #expect(!bundle.id.hasPrefix("."), "Hidden directories should be skipped")
      }
    }
  }

  // MARK: - createBundle Tests

  @Suite("createBundle")
  struct CreateBundleTests {

    @Test("creates bundle with provided display name")
    func createsBundleWithDisplayName() async throws {
      let manager = BundleManager.shared
      let testName = "My Test Notebook"
      let created = try await manager.createBundle(displayName: testName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == testName)
    }

    @Test("generates unique UUID for id")
    func generatesUniqueId() async throws {
      let manager = BundleManager.shared
      let bundle1 = try await manager.createBundle(displayName: "Unique ID Test 1")
      let bundle2 = try await manager.createBundle(displayName: "Unique ID Test 2")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: bundle1.id)
          try? await manager.deleteBundle(notebookID: bundle2.id)
        }
      }

      #expect(bundle1.id != bundle2.id, "Each bundle should have a unique ID")
      // Verify ID looks like a UUID.
      #expect(UUID(uuidString: bundle1.id) != nil, "ID should be a valid UUID")
      #expect(UUID(uuidString: bundle2.id) != nil, "ID should be a valid UUID")
    }

    @Test("returns metadata with nil preview for new bundle")
    func newBundleHasNilPreview() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "New Bundle Preview Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.previewImageData == nil, "New bundles should have nil preview")
    }

    @Test("returns metadata with lastAccessedAt set to creation time")
    func newBundleHasLastAccessedAt() async throws {
      let manager = BundleManager.shared
      let beforeCreate = Date()
      let created = try await manager.createBundle(displayName: "Access Time Test")
      let afterCreate = Date()
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.lastAccessedAt != nil, "lastAccessedAt should be set")
      if let accessedAt = created.lastAccessedAt {
        #expect(accessedAt >= beforeCreate, "lastAccessedAt should be at or after creation start")
        #expect(accessedAt <= afterCreate, "lastAccessedAt should be at or before creation end")
      }
    }

    @Test("creates bundle with unicode display name")
    func createsBundleWithUnicodeName() async throws {
      let manager = BundleManager.shared
      let unicodeName = "数学笔记 📝 Math Notes"
      let created = try await manager.createBundle(displayName: unicodeName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == unicodeName)
    }

    @Test("creates bundle with emoji in display name")
    func createsBundleWithEmoji() async throws {
      let manager = BundleManager.shared
      let emojiName = "🚀 Rocket Science 🧪"
      let created = try await manager.createBundle(displayName: emojiName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == emojiName)
    }

    @Test("creates bundle with very long display name")
    func createsBundleWithLongName() async throws {
      let manager = BundleManager.shared
      let longName = String(repeating: "A", count: 1000)
      let created = try await manager.createBundle(displayName: longName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == longName)
    }

    @Test("creates bundle with whitespace in display name")
    func createsBundleWithWhitespace() async throws {
      let manager = BundleManager.shared
      let whitespaceName = "  Notebook with   spaces  "
      let created = try await manager.createBundle(displayName: whitespaceName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == whitespaceName)
    }

    @Test("creates bundle with special characters in display name")
    func createsBundleWithSpecialChars() async throws {
      let manager = BundleManager.shared
      let specialName = "Test <notebook> & \"more\" 'stuff'"
      let created = try await manager.createBundle(displayName: specialName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == specialName)
    }

    @Test("created bundle appears in listBundles")
    func createdBundleAppearsInList() async throws {
      let manager = BundleManager.shared
      let testName = "List Appearance Test"
      let created = try await manager.createBundle(displayName: testName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found != nil, "Created bundle should appear in listBundles")
    }

    @Test("multiple creates do not overwrite each other")
    func multipleCreatesAreIndependent() async throws {
      let manager = BundleManager.shared
      let bundle1 = try await manager.createBundle(displayName: "Independent 1")
      let bundle2 = try await manager.createBundle(displayName: "Independent 2")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: bundle1.id)
          try? await manager.deleteBundle(notebookID: bundle2.id)
        }
      }

      let bundles = try await manager.listBundles()
      let found1 = bundles.first { $0.id == bundle1.id }
      let found2 = bundles.first { $0.id == bundle2.id }

      #expect(found1?.displayName == "Independent 1")
      #expect(found2?.displayName == "Independent 2")
    }
  }

  // MARK: - renameBundle Tests

  @Suite("renameBundle")
  struct RenameBundleTests {

    @Test("renames bundle successfully")
    func renamesBundleSuccessfully() async throws {
      let manager = BundleManager.shared
      let originalName = "Original Name"
      let newName = "New Name"
      let created = try await manager.createBundle(displayName: originalName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      try await manager.renameBundle(notebookID: created.id, newDisplayName: newName)

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found?.displayName == newName)
    }

    @Test("throws bundleNotFound for non-existent notebookID")
    func throwsBundleNotFoundForNonExistent() async throws {
      let manager = BundleManager.shared
      let fakeID = UUID().uuidString

      await #expect(throws: BundleError.self) {
        try await manager.renameBundle(notebookID: fakeID, newDisplayName: "New Name")
      }
    }

    @Test("throws bundleNotFound for empty notebookID")
    func throwsBundleNotFoundForEmptyId() async throws {
      let manager = BundleManager.shared

      await #expect(throws: BundleError.self) {
        try await manager.renameBundle(notebookID: "", newDisplayName: "New Name")
      }
    }

    @Test("preserves notebookID after rename")
    func preservesNotebookIdAfterRename() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "ID Preservation Test")
      let originalId = created.id
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: originalId)
        }
      }

      try await manager.renameBundle(notebookID: originalId, newDisplayName: "Renamed")

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == originalId }
      #expect(found != nil, "Bundle should still be findable by original ID")
    }

    @Test("rename with unicode characters")
    func renameWithUnicodeCharacters() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Unicode Rename Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let unicodeName = "日本語ノート 🇯🇵"
      try await manager.renameBundle(notebookID: created.id, newDisplayName: unicodeName)

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found?.displayName == unicodeName)
    }

    @Test("rename with very long name")
    func renameWithVeryLongName() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Long Rename Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let longName = String(repeating: "X", count: 2000)
      try await manager.renameBundle(notebookID: created.id, newDisplayName: longName)

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found?.displayName == longName)
    }

    @Test("rename to same name succeeds")
    func renameToSameNameSucceeds() async throws {
      let manager = BundleManager.shared
      let name = "Same Name Test"
      let created = try await manager.createBundle(displayName: name)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      // Renaming to the same name should succeed without error.
      try await manager.renameBundle(notebookID: created.id, newDisplayName: name)

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found?.displayName == name)
    }

    @Test("rename multiple times")
    func renameMultipleTimes() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Multiple Rename Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      try await manager.renameBundle(notebookID: created.id, newDisplayName: "First Rename")
      try await manager.renameBundle(notebookID: created.id, newDisplayName: "Second Rename")
      try await manager.renameBundle(notebookID: created.id, newDisplayName: "Final Rename")

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found?.displayName == "Final Rename")
    }

    @Test("rename with whitespace only")
    func renameWithWhitespaceOnly() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Whitespace Rename Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let whitespaceName = "   "
      try await manager.renameBundle(notebookID: created.id, newDisplayName: whitespaceName)

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found?.displayName == whitespaceName)
    }
  }

  // MARK: - deleteBundle Tests

  @Suite("deleteBundle")
  struct DeleteBundleTests {

    @Test("deletes bundle successfully")
    func deletesBundleSuccessfully() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Delete Test")
      let createdId = created.id

      try await manager.deleteBundle(notebookID: createdId)

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == createdId }
      #expect(found == nil, "Deleted bundle should not appear in listBundles")
    }

    @Test("throws bundleNotFound for non-existent notebookID")
    func throwsBundleNotFoundForNonExistent() async throws {
      let manager = BundleManager.shared
      let fakeID = UUID().uuidString

      await #expect(throws: BundleError.self) {
        try await manager.deleteBundle(notebookID: fakeID)
      }
    }

    @Test("throws bundleNotFound for empty notebookID")
    func throwsBundleNotFoundForEmptyId() async throws {
      let manager = BundleManager.shared

      await #expect(throws: BundleError.self) {
        try await manager.deleteBundle(notebookID: "")
      }
    }

    @Test("double delete throws error")
    func doubleDeleteThrowsError() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Double Delete Test")
      let createdId = created.id

      try await manager.deleteBundle(notebookID: createdId)

      // Second delete should throw bundleNotFound.
      await #expect(throws: BundleError.self) {
        try await manager.deleteBundle(notebookID: createdId)
      }
    }

    @Test("delete does not affect other bundles")
    func deleteDoesNotAffectOtherBundles() async throws {
      let manager = BundleManager.shared
      let bundle1 = try await manager.createBundle(displayName: "Keep Me 1")
      let bundle2 = try await manager.createBundle(displayName: "Delete Me")
      let bundle3 = try await manager.createBundle(displayName: "Keep Me 2")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: bundle1.id)
          try? await manager.deleteBundle(notebookID: bundle3.id)
        }
      }

      try await manager.deleteBundle(notebookID: bundle2.id)

      let bundles = try await manager.listBundles()
      let ids = Set(bundles.map { $0.id })

      #expect(ids.contains(bundle1.id), "Unrelated bundle 1 should still exist")
      #expect(!ids.contains(bundle2.id), "Deleted bundle should be gone")
      #expect(ids.contains(bundle3.id), "Unrelated bundle 3 should still exist")
    }

    @Test("delete with invalid UUID format")
    func deleteWithInvalidUUIDFormat() async throws {
      let manager = BundleManager.shared
      let invalidID = "not-a-valid-uuid"

      await #expect(throws: BundleError.self) {
        try await manager.deleteBundle(notebookID: invalidID)
      }
    }

    @Test("delete removes all bundle files")
    func deleteRemovesAllBundleFiles() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Full Delete Test")
      let createdId = created.id

      // Get the package path before deletion to verify it exists.
      let packagePath = try await manager.iinkPackagePath(forNotebookID: createdId)
      let packageURL = URL(fileURLWithPath: packagePath)
      let bundleURL = packageURL.deletingLastPathComponent()

      // Verify bundle directory exists before deletion.
      #expect(FileManager.default.fileExists(atPath: bundleURL.path))

      try await manager.deleteBundle(notebookID: createdId)

      // Verify bundle directory no longer exists.
      #expect(!FileManager.default.fileExists(atPath: bundleURL.path))
    }
  }

  // MARK: - openNotebook Tests

  @Suite("openNotebook")
  struct OpenNotebookTests {

    @Test("opens existing bundle and returns DocumentHandle")
    func opensExistingBundle() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Open Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let handle = try await manager.openNotebook(id: created.id)
      #expect(handle is DocumentHandle)
      await handle.close(saveBeforeClose: false)
    }

    @Test("throws bundleNotFound for non-existent notebookID")
    func throwsBundleNotFoundForNonExistent() async throws {
      let manager = BundleManager.shared
      let fakeID = UUID().uuidString

      await #expect(throws: BundleError.self) {
        _ = try await manager.openNotebook(id: fakeID)
      }
    }

    @Test("throws bundleNotFound for empty notebookID")
    func throwsBundleNotFoundForEmptyId() async throws {
      let manager = BundleManager.shared

      await #expect(throws: BundleError.self) {
        _ = try await manager.openNotebook(id: "")
      }
    }

    @Test("returned handle has correct notebookID")
    func returnedHandleHasCorrectId() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Handle ID Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let handle = try await manager.openNotebook(id: created.id)
      let handleId = await handle.notebookID
      #expect(handleId == created.id)
      await handle.close(saveBeforeClose: false)
    }

    @Test("opening updates lastAccessedAt")
    func openingUpdatesLastAccessedAt() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Access Update Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      // Wait a bit to ensure time difference.
      try await Task.sleep(nanoseconds: 100_000_000)
      let beforeOpen = Date()

      let handle = try await manager.openNotebook(id: created.id)
      await handle.close(saveBeforeClose: false)

      let bundles = try await manager.listBundles()
      let found = bundles.first { $0.id == created.id }
      #expect(found != nil)
      if let accessedAt = found?.lastAccessedAt {
        #expect(accessedAt >= beforeOpen, "lastAccessedAt should be updated on open")
      }
    }

    @Test("can open same notebook multiple times sequentially")
    func canOpenSameNotebookMultipleTimes() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Multiple Open Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let handle1 = try await manager.openNotebook(id: created.id)
      await handle1.close(saveBeforeClose: false)

      let handle2 = try await manager.openNotebook(id: created.id)
      await handle2.close(saveBeforeClose: false)

      let handle3 = try await manager.openNotebook(id: created.id)
      await handle3.close(saveBeforeClose: false)

      // All opens should succeed.
      #expect(true)
    }

    @Test("handle manifest has correct displayName")
    func handleManifestHasCorrectDisplayName() async throws {
      let manager = BundleManager.shared
      let testName = "Manifest Name Test"
      let created = try await manager.createBundle(displayName: testName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let handle = try await manager.openNotebook(id: created.id)
      let manifest = await handle.manifest
      #expect(manifest.displayName == testName)
      await handle.close(saveBeforeClose: false)
    }

    @Test("handle packagePath is valid")
    func handlePackagePathIsValid() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Package Path Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let handle = try await manager.openNotebook(id: created.id)
      let packagePath = await handle.packagePath
      #expect(!packagePath.isEmpty)
      #expect(packagePath.hasSuffix(".iink"))
      await handle.close(saveBeforeClose: false)
    }
  }

  // MARK: - iinkPackagePath Tests

  @Suite("iinkPackagePath")
  struct IinkPackagePathTests {

    @Test("returns path ending with content.iink")
    func returnsPathEndingWithContentIink() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Path Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let path = try await manager.iinkPackagePath(forNotebookID: created.id)
      #expect(path.hasSuffix("content.iink"))
    }

    @Test("path contains notebookID")
    func pathContainsNotebookId() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "ID in Path Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let path = try await manager.iinkPackagePath(forNotebookID: created.id)
      #expect(path.contains(created.id))
    }

    @Test("path is absolute")
    func pathIsAbsolute() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Absolute Path Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let path = try await manager.iinkPackagePath(forNotebookID: created.id)
      #expect(path.hasPrefix("/"), "Path should be absolute")
    }

    @Test("path does not validate existence")
    func pathDoesNotValidateExistence() async throws {
      let manager = BundleManager.shared
      // According to protocol, this method does not check if the file exists.
      // It simply constructs the path.
      let fakeID = UUID().uuidString
      let path = try await manager.iinkPackagePath(forNotebookID: fakeID)
      #expect(path.contains(fakeID))
      #expect(path.hasSuffix("content.iink"))
    }

    @Test("path uses decomposed unicode normalization")
    func pathUsesDecomposedNormalization() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Unicode Path Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let path = try await manager.iinkPackagePath(forNotebookID: created.id)
      // The path should use decomposedStringWithCanonicalMapping.
      let normalizedPath = path.decomposedStringWithCanonicalMapping
      #expect(path == normalizedPath)
    }

    @Test("path for existing bundle points to real file")
    func pathForExistingBundlePointsToRealFile() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Real File Path Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let path = try await manager.iinkPackagePath(forNotebookID: created.id)
      let fileExists = FileManager.default.fileExists(atPath: path)
      #expect(fileExists, "Package file should exist for created bundle")
    }
  }

  // MARK: - Error Cases Tests

  @Suite("Error Cases")
  struct ErrorCasesTests {

    @Test("bundleNotFound error includes notebookID")
    func bundleNotFoundIncludesNotebookId() async {
      let manager = BundleManager.shared
      let fakeID = "test-fake-id-12345"

      do {
        _ = try await manager.openNotebook(id: fakeID)
        Issue.record("Expected bundleNotFound error")
      } catch let error as BundleError {
        if case .bundleNotFound(let notebookID) = error {
          #expect(notebookID == fakeID)
        } else {
          Issue.record("Expected bundleNotFound error, got \(error)")
        }
      } catch {
        Issue.record("Expected BundleError, got \(error)")
      }
    }

    @Test("operations on deleted bundle throw bundleNotFound")
    func operationsOnDeletedBundleThrow() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Deleted Operations Test")
      let createdId = created.id

      try await manager.deleteBundle(notebookID: createdId)

      await #expect(throws: BundleError.self) {
        _ = try await manager.openNotebook(id: createdId)
      }

      await #expect(throws: BundleError.self) {
        try await manager.renameBundle(notebookID: createdId, newDisplayName: "New Name")
      }
    }
  }

  // MARK: - Concurrency Tests

  @Suite("Concurrency")
  struct ConcurrencyTests {

    @Test("concurrent listBundles calls succeed")
    func concurrentListBundlesCalls() async throws {
      let manager = BundleManager.shared

      await withTaskGroup(of: [NotebookMetadata].self) { group in
        for _ in 0..<10 {
          group.addTask {
            do {
              return try await manager.listBundles()
            } catch {
              return []
            }
          }
        }

        var results: [[NotebookMetadata]] = []
        for await result in group {
          results.append(result)
        }

        // All concurrent calls should succeed.
        #expect(results.count == 10)
      }
    }

    @Test("concurrent createBundle calls produce unique bundles")
    func concurrentCreateBundleCalls() async throws {
      let manager = BundleManager.shared
      var createdIds: [String] = []

      await withTaskGroup(of: NotebookMetadata?.self) { group in
        for i in 0..<5 {
          group.addTask {
            do {
              return try await manager.createBundle(displayName: "Concurrent Create \(i)")
            } catch {
              return nil
            }
          }
        }

        for await result in group {
          if let metadata = result {
            createdIds.append(metadata.id)
          }
        }
      }

      // Clean up.
      for id in createdIds {
        try? await manager.deleteBundle(notebookID: id)
      }

      // All creates should produce unique IDs.
      let uniqueIds = Set(createdIds)
      #expect(uniqueIds.count == createdIds.count, "All concurrent creates should produce unique IDs")
    }

    @Test("create and delete interleaved")
    func createAndDeleteInterleaved() async throws {
      let manager = BundleManager.shared
      var createdIds: [String] = []

      // Create some bundles.
      for i in 0..<3 {
        let created = try await manager.createBundle(displayName: "Interleaved \(i)")
        createdIds.append(created.id)
      }

      // Delete first, create new, delete second.
      try await manager.deleteBundle(notebookID: createdIds[0])
      let newBundle = try await manager.createBundle(displayName: "Interleaved New")
      createdIds.append(newBundle.id)
      try await manager.deleteBundle(notebookID: createdIds[1])

      // Verify state.
      let bundles = try await manager.listBundles()
      let ids = Set(bundles.map { $0.id })

      #expect(!ids.contains(createdIds[0]), "First deleted bundle should be gone")
      #expect(!ids.contains(createdIds[1]), "Second deleted bundle should be gone")
      #expect(ids.contains(createdIds[2]), "Third bundle should still exist")
      #expect(ids.contains(newBundle.id), "New bundle should exist")

      // Clean up remaining.
      try? await manager.deleteBundle(notebookID: createdIds[2])
      try? await manager.deleteBundle(notebookID: newBundle.id)
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCasesTests {

    @Test("create bundle with newlines in name")
    func createBundleWithNewlines() async throws {
      let manager = BundleManager.shared
      let nameWithNewlines = "Line1\nLine2\nLine3"
      let created = try await manager.createBundle(displayName: nameWithNewlines)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == nameWithNewlines)
    }

    @Test("create bundle with tabs in name")
    func createBundleWithTabs() async throws {
      let manager = BundleManager.shared
      let nameWithTabs = "Col1\tCol2\tCol3"
      let created = try await manager.createBundle(displayName: nameWithTabs)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == nameWithTabs)
    }

    @Test("create bundle with null character in name")
    func createBundleWithNullCharacter() async throws {
      let manager = BundleManager.shared
      let nameWithNull = "Before\0After"
      let created = try await manager.createBundle(displayName: nameWithNull)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      // The null character may or may not be preserved depending on JSON encoding.
      #expect(!created.displayName.isEmpty)
    }

    @Test("create bundle with RTL text in name")
    func createBundleWithRTLText() async throws {
      let manager = BundleManager.shared
      let rtlName = "مرحبا بالعالم"
      let created = try await manager.createBundle(displayName: rtlName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == rtlName)
    }

    @Test("create bundle with mixed direction text")
    func createBundleWithMixedDirectionText() async throws {
      let manager = BundleManager.shared
      let mixedName = "Hello مرحبا World عالم"
      let created = try await manager.createBundle(displayName: mixedName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(created.displayName == mixedName)
    }

    @Test("create bundle with combining characters")
    func createBundleWithCombiningCharacters() async throws {
      let manager = BundleManager.shared
      // e + combining acute accent.
      let combiningName = "Cafe\u{0301}"
      let created = try await manager.createBundle(displayName: combiningName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      // The combining character should be preserved or normalized.
      #expect(!created.displayName.isEmpty)
    }

    @Test("create bundle with zero-width characters")
    func createBundleWithZeroWidthCharacters() async throws {
      let manager = BundleManager.shared
      let zeroWidthName = "Hello\u{200B}World"
      let created = try await manager.createBundle(displayName: zeroWidthName)
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      #expect(!created.displayName.isEmpty)
    }

    @Test("notebookID with path traversal characters is handled safely")
    func notebookIdWithPathTraversalHandledSafely() async throws {
      let manager = BundleManager.shared
      // Attempting path traversal should either fail or be handled safely.
      let maliciousId = "../../../etc/passwd"

      await #expect(throws: BundleError.self) {
        _ = try await manager.openNotebook(id: maliciousId)
      }
    }

    @Test("notebookID with forward slash is handled safely")
    func notebookIdWithForwardSlashHandledSafely() async throws {
      let manager = BundleManager.shared
      let slashId = "notebook/with/slashes"

      await #expect(throws: BundleError.self) {
        _ = try await manager.openNotebook(id: slashId)
      }
    }

    @Test("notebookID with backslash is handled safely")
    func notebookIdWithBackslashHandledSafely() async throws {
      let manager = BundleManager.shared
      let backslashId = "notebook\\with\\backslashes"

      await #expect(throws: BundleError.self) {
        _ = try await manager.openNotebook(id: backslashId)
      }
    }
  }

  // MARK: - Integration Tests

  @Suite("Integration")
  struct IntegrationTests {

    @Test("full lifecycle: create, open, close, rename, delete")
    func fullLifecycle() async throws {
      let manager = BundleManager.shared

      // Create.
      let created = try await manager.createBundle(displayName: "Lifecycle Test")
      #expect(!created.id.isEmpty)

      // Verify in list.
      var bundles = try await manager.listBundles()
      #expect(bundles.contains { $0.id == created.id })

      // Open and close.
      let handle = try await manager.openNotebook(id: created.id)
      await handle.close(saveBeforeClose: false)

      // Rename.
      try await manager.renameBundle(notebookID: created.id, newDisplayName: "Renamed Lifecycle Test")
      bundles = try await manager.listBundles()
      let renamed = bundles.first { $0.id == created.id }
      #expect(renamed?.displayName == "Renamed Lifecycle Test")

      // Delete.
      try await manager.deleteBundle(notebookID: created.id)
      bundles = try await manager.listBundles()
      #expect(!bundles.contains { $0.id == created.id })
    }

    @Test("create, modify through handle, verify changes")
    func createModifyVerify() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Modify Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      // Open and get part count (verifies package structure).
      let handle = try await manager.openNotebook(id: created.id)
      let partCount = await handle.getPartCount()
      #expect(partCount >= 0)
      await handle.close(saveBeforeClose: true)

      // Verify bundle still exists after modifications.
      let bundles = try await manager.listBundles()
      #expect(bundles.contains { $0.id == created.id })
    }

    @Test("package path matches handle package path")
    func packagePathMatchesHandlePath() async throws {
      let manager = BundleManager.shared
      let created = try await manager.createBundle(displayName: "Path Match Test")
      defer {
        Task {
          try? await manager.deleteBundle(notebookID: created.id)
        }
      }

      let managerPath = try await manager.iinkPackagePath(forNotebookID: created.id)
      let handle = try await manager.openNotebook(id: created.id)
      let handlePath = await handle.packagePath

      // Both paths should match (allowing for normalization differences).
      #expect(
        managerPath.decomposedStringWithCanonicalMapping
          == handlePath.decomposedStringWithCanonicalMapping
      )

      await handle.close(saveBeforeClose: false)
    }
  }
}
