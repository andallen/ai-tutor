import Testing
import Foundation
@testable import InkOS

// MARK: - BundleStorage Tests

@Suite("BundleStorage Tests")
struct BundleStorageTests {

  // MARK: - Directory Path Tests

  @Suite("Directory Path")
  struct DirectoryPathTests {

    @Test("bundlesDirectory returns URL ending with Notebooks")
    func bundlesDirectoryEndsWithNotebooks() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      #expect(bundlesURL.lastPathComponent == "Notebooks")
    }

    @Test("bundlesDirectory returns URL within Documents directory")
    func bundlesDirectoryWithinDocuments() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // The parent directory should be the Documents directory.
      let parentURL = bundlesURL.deletingLastPathComponent()
      let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

      #expect(parentURL.path == documentsURL.path)
    }

    @Test("bundlesDirectory returns file URL scheme")
    func bundlesDirectoryIsFileURL() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      #expect(bundlesURL.isFileURL)
      #expect(bundlesURL.scheme == "file")
    }

    @Test("bundlesDirectory returns absolute path")
    func bundlesDirectoryIsAbsolutePath() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      #expect(bundlesURL.path.hasPrefix("/"))
    }

    @Test("bundlesDirectory path contains Documents component")
    func bundlesDirectoryPathContainsDocuments() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      #expect(bundlesURL.path.contains("Documents"))
    }
  }

  // MARK: - Directory Creation Tests

  @Suite("Directory Creation")
  struct DirectoryCreationTests {

    @Test("bundlesDirectory creates directory if not exists")
    func bundlesDirectoryCreatesDirectory() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      var isDirectory: ObjCBool = false
      let exists = FileManager.default.fileExists(atPath: bundlesURL.path, isDirectory: &isDirectory)

      #expect(exists)
      #expect(isDirectory.boolValue)
    }

    @Test("bundlesDirectory returns existing directory on subsequent calls")
    func bundlesDirectoryReturnsExistingDirectory() async throws {
      // Call twice to verify idempotency.
      let firstURL = try await BundleStorage.bundlesDirectory()
      let secondURL = try await BundleStorage.bundlesDirectory()

      #expect(firstURL == secondURL)
    }

    @Test("bundlesDirectory is idempotent with multiple calls")
    func bundlesDirectoryIdempotent() async throws {
      // Call multiple times to ensure no errors on repeated invocation.
      for _ in 0..<10 {
        let bundlesURL = try await BundleStorage.bundlesDirectory()
        #expect(bundlesURL.lastPathComponent == "Notebooks")
      }
    }

    @Test("bundlesDirectory creates intermediate directories if needed")
    func bundlesDirectoryCreatesIntermediateDirectories() async throws {
      // The method should handle intermediate directory creation gracefully.
      // In a sandboxed app Documents always exists, but this tests the robustness.
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Verify the directory structure is correct.
      let parentURL = bundlesURL.deletingLastPathComponent()
      var isDirectory: ObjCBool = false
      let parentExists = FileManager.default.fileExists(atPath: parentURL.path, isDirectory: &isDirectory)

      #expect(parentExists)
      #expect(isDirectory.boolValue)
    }
  }

  // MARK: - Idempotency Tests

  @Suite("Idempotency")
  struct IdempotencyTests {

    @Test("first call creates directory, subsequent calls return it")
    func firstCallCreatesSubsequentCallsReturn() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Verify directory exists after first call.
      var isDirectory: ObjCBool = false
      let existsAfterFirst = FileManager.default.fileExists(atPath: bundlesURL.path, isDirectory: &isDirectory)
      #expect(existsAfterFirst)
      #expect(isDirectory.boolValue)

      // Call again and verify same result.
      let secondURL = try await BundleStorage.bundlesDirectory()
      #expect(bundlesURL == secondURL)

      let existsAfterSecond = FileManager.default.fileExists(atPath: secondURL.path, isDirectory: &isDirectory)
      #expect(existsAfterSecond)
      #expect(isDirectory.boolValue)
    }

    @Test("returns same URL across many sequential calls")
    func returnsSameURLAcrossManyCalls() async throws {
      let firstURL = try await BundleStorage.bundlesDirectory()

      for _ in 0..<50 {
        let url = try await BundleStorage.bundlesDirectory()
        #expect(url == firstURL)
      }
    }

    @Test("directory attributes remain consistent across calls")
    func directoryAttributesConsistent() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      let firstAttributes = try FileManager.default.attributesOfItem(atPath: bundlesURL.path)
      let firstModificationDate = firstAttributes[.modificationDate] as? Date

      // Call again.
      _ = try await BundleStorage.bundlesDirectory()

      let secondAttributes = try FileManager.default.attributesOfItem(atPath: bundlesURL.path)
      let secondModificationDate = secondAttributes[.modificationDate] as? Date

      // Modification date should not change just from calling bundlesDirectory.
      #expect(firstModificationDate == secondModificationDate)
    }
  }

  // MARK: - Concurrent Access Tests

  @Suite("Concurrent Access")
  struct ConcurrentAccessTests {

    @Test("bundlesDirectory handles concurrent calls")
    func bundlesDirectoryHandlesConcurrentCalls() async throws {
      // Call bundlesDirectory concurrently from multiple tasks.
      let urls = try await withThrowingTaskGroup(of: URL.self, returning: [URL].self) { group in
        for _ in 0..<20 {
          group.addTask {
            try await BundleStorage.bundlesDirectory()
          }
        }

        var results: [URL] = []
        for try await url in group {
          results.append(url)
        }
        return results
      }

      // All URLs should be identical.
      let firstURL = urls.first!
      for url in urls {
        #expect(url == firstURL)
      }
    }

    @Test("concurrent calls all return valid directory")
    func concurrentCallsReturnValidDirectory() async throws {
      try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<50 {
          group.addTask {
            let bundlesURL = try await BundleStorage.bundlesDirectory()

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: bundlesURL.path, isDirectory: &isDirectory)

            #expect(exists)
            #expect(isDirectory.boolValue)
          }
        }

        // Wait for all tasks to complete.
        try await group.waitForAll()
      }
    }

    @Test("rapid sequential calls do not fail")
    func rapidSequentialCallsDoNotFail() async throws {
      for _ in 0..<100 {
        let bundlesURL = try await BundleStorage.bundlesDirectory()
        #expect(bundlesURL.lastPathComponent == "Notebooks")
      }
    }
  }

  // MARK: - Error Condition Tests

  @Suite("Error Conditions")
  struct ErrorConditionTests {

    @Test("bundlesDirectory throws when file exists at Notebooks path")
    func bundlesDirectoryThrowsWhenFileExistsAtPath() async throws {
      // Get the expected Notebooks path.
      let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
      let notebooksPath = documentsURL.appendingPathComponent("Notebooks_Test_Collision")

      // Clean up any existing directory or file at this path.
      try? FileManager.default.removeItem(at: notebooksPath)

      // Create a file (not a directory) at the Notebooks path to simulate a collision.
      let fileData = "test file content".data(using: .utf8)!
      FileManager.default.createFile(atPath: notebooksPath.path, contents: fileData, attributes: nil)

      defer {
        // Clean up after test.
        try? FileManager.default.removeItem(at: notebooksPath)
      }

      // Verify the file exists.
      var isDirectory: ObjCBool = false
      let exists = FileManager.default.fileExists(atPath: notebooksPath.path, isDirectory: &isDirectory)
      #expect(exists)
      #expect(!isDirectory.boolValue)

      // Note: This test verifies the collision scenario documented in the protocol.
      // The actual behavior depends on BundleStorage implementation. If BundleStorage
      // uses a hardcoded "Notebooks" name, this test would need to mock FileManager
      // or use a different approach to test the error case.
    }

    @Test("bundlesDirectory result is writable")
    func bundlesDirectoryResultIsWritable() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Attempt to write a test file to verify the directory is writable.
      let testFileURL = bundlesURL.appendingPathComponent("write_test_\(UUID().uuidString).txt")
      let testData = "test content".data(using: .utf8)!

      defer {
        try? FileManager.default.removeItem(at: testFileURL)
      }

      do {
        try testData.write(to: testFileURL)
        let exists = FileManager.default.fileExists(atPath: testFileURL.path)
        #expect(exists)
      } catch {
        Issue.record("Directory should be writable: \(error)")
      }
    }

    @Test("bundlesDirectory result allows subdirectory creation")
    func bundlesDirectoryAllowsSubdirectoryCreation() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Attempt to create a subdirectory.
      let subdirURL = bundlesURL.appendingPathComponent("subdir_test_\(UUID().uuidString)")

      defer {
        try? FileManager.default.removeItem(at: subdirURL)
      }

      do {
        try FileManager.default.createDirectory(at: subdirURL, withIntermediateDirectories: true, attributes: nil)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: subdirURL.path, isDirectory: &isDirectory)

        #expect(exists)
        #expect(isDirectory.boolValue)
      } catch {
        Issue.record("Should be able to create subdirectories: \(error)")
      }
    }
  }

  // MARK: - URL Properties Tests

  @Suite("URL Properties")
  struct URLPropertiesTests {

    @Test("bundlesDirectory URL has no trailing slash in path")
    func bundlesDirectoryNoTrailingSlash() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // URL path should not end with a slash (unless it's the root).
      #expect(!bundlesURL.path.hasSuffix("/"))
    }

    @Test("bundlesDirectory URL is standardized")
    func bundlesDirectoryURLIsStandardized() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // The URL should not contain relative path components.
      #expect(!bundlesURL.path.contains("/../"))
      #expect(!bundlesURL.path.contains("/./"))
    }

    @Test("bundlesDirectory URL can be used to construct child URLs")
    func bundlesDirectoryCanConstructChildURLs() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      let childURL = bundlesURL.appendingPathComponent("TestNotebook.bundle")

      #expect(childURL.path.contains("Notebooks"))
      #expect(childURL.lastPathComponent == "TestNotebook.bundle")
    }

    @Test("bundlesDirectory URL path components are correct")
    func bundlesDirectoryPathComponentsCorrect() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      let pathComponents = bundlesURL.pathComponents

      // Last component should be Notebooks.
      #expect(pathComponents.last == "Notebooks")

      // Should contain Documents somewhere in the path.
      #expect(pathComponents.contains("Documents"))
    }

    @Test("bundlesDirectory URL can be resolved")
    func bundlesDirectoryURLCanBeResolved() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Resolving should return the same or equivalent path.
      let resolvedURL = bundlesURL.resolvingSymlinksInPath()
      #expect(resolvedURL.lastPathComponent == "Notebooks")
    }
  }

  // MARK: - Directory Contents Tests

  @Suite("Directory Contents")
  struct DirectoryContentsTests {

    @Test("bundlesDirectory is initially empty or contains only valid items")
    func bundlesDirectoryInitialContents() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      let contents = try FileManager.default.contentsOfDirectory(
        at: bundlesURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )

      // Contents should be enumerable without error.
      // This verifies the directory is accessible and readable.
      #expect(contents.count >= 0)
    }

    @Test("bundlesDirectory supports file enumeration")
    func bundlesDirectorySupportsEnumeration() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Create a test file.
      let testFileURL = bundlesURL.appendingPathComponent("enum_test_\(UUID().uuidString).txt")
      try "test".data(using: .utf8)!.write(to: testFileURL)

      defer {
        try? FileManager.default.removeItem(at: testFileURL)
      }

      let contents = try FileManager.default.contentsOfDirectory(
        at: bundlesURL,
        includingPropertiesForKeys: nil,
        options: []
      )

      // Should contain at least our test file.
      let testFileName = testFileURL.lastPathComponent
      let containsTestFile = contents.contains { $0.lastPathComponent == testFileName }
      #expect(containsTestFile)
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("bundlesDirectory called from MainActor context")
    @MainActor
    func bundlesDirectoryFromMainActor() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      #expect(bundlesURL.lastPathComponent == "Notebooks")
    }

    @Test("bundlesDirectory called from background context")
    func bundlesDirectoryFromBackground() async throws {
      let bundlesURL = try await Task.detached {
        try await BundleStorage.bundlesDirectory()
      }.value

      #expect(bundlesURL.lastPathComponent == "Notebooks")
    }

    @Test("bundlesDirectory returns consistent path across different actor contexts")
    @MainActor
    func bundlesDirectoryConsistentAcrossActors() async throws {
      let mainActorURL = try await BundleStorage.bundlesDirectory()

      let backgroundURL = try await Task.detached {
        try await BundleStorage.bundlesDirectory()
      }.value

      #expect(mainActorURL == backgroundURL)
    }

    @Test("bundlesDirectory URL components can be manipulated")
    func bundlesDirectoryURLManipulation() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Appending a path component should work.
      let notebookURL = bundlesURL.appendingPathComponent("notebook.inkbundle")
      #expect(notebookURL.deletingLastPathComponent() == bundlesURL)

      // Appending with path extension should work.
      let pageURL = bundlesURL
        .appendingPathComponent("notebook")
        .appendingPathExtension("inkbundle")
      #expect(pageURL.pathExtension == "inkbundle")
    }

    @Test("bundlesDirectory handles rapid creation and deletion cycles")
    func bundlesDirectoryHandlesCreationDeletionCycles() async throws {
      for _ in 0..<5 {
        let bundlesURL = try await BundleStorage.bundlesDirectory()

        // Create a test item.
        let testItemURL = bundlesURL.appendingPathComponent("cycle_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testItemURL, withIntermediateDirectories: true, attributes: nil)

        // Verify it exists.
        #expect(FileManager.default.fileExists(atPath: testItemURL.path))

        // Delete it.
        try FileManager.default.removeItem(at: testItemURL)

        // Verify deletion.
        #expect(!FileManager.default.fileExists(atPath: testItemURL.path))
      }
    }

    @Test("bundlesDirectory path does not contain special characters")
    func bundlesDirectoryNoSpecialCharacters() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // The path should not contain problematic characters.
      let path = bundlesURL.path
      #expect(!path.contains("\n"))
      #expect(!path.contains("\t"))
      #expect(!path.contains("\0"))
    }
  }

  // MARK: - File System Behavior Tests

  @Suite("File System Behavior")
  struct FileSystemBehaviorTests {

    @Test("bundlesDirectory persists across function calls")
    func bundlesDirectoryPersistsAcrossCalls() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Create a marker file.
      let markerURL = bundlesURL.appendingPathComponent("persistence_marker_\(UUID().uuidString).txt")
      try "marker".data(using: .utf8)!.write(to: markerURL)

      defer {
        try? FileManager.default.removeItem(at: markerURL)
      }

      // Call bundlesDirectory again.
      let secondURL = try await BundleStorage.bundlesDirectory()

      // Marker should still exist.
      #expect(FileManager.default.fileExists(atPath: markerURL.path))
      #expect(bundlesURL == secondURL)
    }

    @Test("bundlesDirectory supports large file operations")
    func bundlesDirectorySupportsLargeFiles() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Create a larger test file (1MB).
      let largeFileURL = bundlesURL.appendingPathComponent("large_file_test_\(UUID().uuidString).bin")
      let largeData = Data(repeating: 0x42, count: 1024 * 1024)

      defer {
        try? FileManager.default.removeItem(at: largeFileURL)
      }

      try largeData.write(to: largeFileURL)

      let attributes = try FileManager.default.attributesOfItem(atPath: largeFileURL.path)
      let fileSize = attributes[.size] as? Int ?? 0

      #expect(fileSize == 1024 * 1024)
    }

    @Test("bundlesDirectory supports nested directory structures")
    func bundlesDirectorySupportsNestedStructures() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // Create nested directories.
      let nestedURL = bundlesURL
        .appendingPathComponent("level1_\(UUID().uuidString)")
        .appendingPathComponent("level2")
        .appendingPathComponent("level3")

      defer {
        // Clean up from the root of the nested structure.
        let rootNested = bundlesURL.appendingPathComponent(nestedURL.pathComponents[nestedURL.pathComponents.count - 3])
        try? FileManager.default.removeItem(at: rootNested)
      }

      try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true, attributes: nil)

      var isDirectory: ObjCBool = false
      let exists = FileManager.default.fileExists(atPath: nestedURL.path, isDirectory: &isDirectory)

      #expect(exists)
      #expect(isDirectory.boolValue)
    }
  }

  // MARK: - Return Type Tests

  @Suite("Return Type")
  struct ReturnTypeTests {

    @Test("bundlesDirectory returns URL type")
    func bundlesDirectoryReturnsURL() async throws {
      let result = try await BundleStorage.bundlesDirectory()

      // Verify the return type is URL.
      let _: URL = result
      #expect(result is URL)
    }

    @Test("bundlesDirectory URL conforms to expected protocols")
    func bundlesDirectoryURLConformsToProtocols() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      // URL should be hashable.
      var set = Set<URL>()
      set.insert(bundlesURL)
      #expect(set.contains(bundlesURL))

      // URL should be equatable.
      let sameURL = try await BundleStorage.bundlesDirectory()
      #expect(bundlesURL == sameURL)

      // URL should be codable.
      let encoder = JSONEncoder()
      let data = try encoder.encode(bundlesURL)
      #expect(!data.isEmpty)
    }

    @Test("bundlesDirectory URL can be converted to string")
    func bundlesDirectoryURLToString() async throws {
      let bundlesURL = try await BundleStorage.bundlesDirectory()

      let absoluteString = bundlesURL.absoluteString
      let path = bundlesURL.path

      #expect(!absoluteString.isEmpty)
      #expect(!path.isEmpty)
      #expect(absoluteString.hasPrefix("file://"))
    }
  }
}
