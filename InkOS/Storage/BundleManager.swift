import Foundation

// Represents a Notebook in the list returned by the Bundle Manager.
// Contains only the metadata needed to display the Notebook in the Dashboard.
// Sendable so it can be passed across actor boundaries.
// Equatable to support onChange modifiers for UI state tracking.
struct NotebookMetadata: Identifiable, Sendable, Equatable {
  // Unique identifier for this Notebook.
  let id: String

  // Display name shown to the user.
  let displayName: String

  // Cached preview image data for the Notebook.
  let previewImageData: Data?

  // Timestamp when the notebook was last accessed.
  let lastAccessedAt: Date?
}

// The Bundle Manager is the only code allowed to perform direct file operations on Bundles.
// All file system access for Notebooks must go through the Bundle Manager.
actor BundleManager {
  // Shared singleton instance for accessing the Bundle Manager.
  static let shared = BundleManager()

  // The name of the Manifest file inside each Bundle.
  private static let manifestFileName = "manifest.json"

  // The name of the MyScript iink package file inside each Bundle.
  private static let iinkFileName = "content.iink"
  // The name of the preview image inside each Bundle.
  private static let previewImageFileName = "preview.png"

  // The name of the folder manifest file that distinguishes folders from notebooks.
  private static let folderManifestFileName = FolderConstants.folderManifestFileName

  // Lists all existing Bundles in the Notebooks directory.
  // Returns an array of NotebookMetadata for each Bundle that has a valid Manifest.
  // Skips Bundles that don't have a Manifest or have invalid Manifests.
  // swiftlint:disable function_body_length
  // Function requires comprehensive error handling and validation for file system operations
  func listBundles() async throws -> [NotebookMetadata] {
    // Get the directory where Bundles are stored.
    let bundlesDirectory = try await BundleStorage.bundlesDirectory()

    // Get the contents of the Bundles directory.
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(
      at: bundlesDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    // Filter to only directories and collect metadata from each Bundle.
    var notebooks: [NotebookMetadata] = []

    for url in contents {
      // Check if this is a directory.
      let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
      guard resourceValues.isDirectory == true else {
        continue
      }

      // Skip folders (directories containing folder.json).
      let folderManifestURL = url.appendingPathComponent(Self.folderManifestFileName)
      if fileManager.fileExists(atPath: folderManifestURL.path) {
        continue
      }

      // Try to read the Manifest from this Bundle.
      let manifestURL = url.appendingPathComponent(Self.manifestFileName)
      guard fileManager.fileExists(atPath: manifestURL.path) else {
        continue
      }

      // Read and decode the Manifest.
      do {
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(Manifest.self, from: data)
        let previewURL = url.appendingPathComponent(Self.previewImageFileName)
        let previewData: Data?
        if fileManager.fileExists(atPath: previewURL.path) {
          previewData = try? Data(contentsOf: previewURL)
        } else {
          previewData = nil
        }
        notebooks.append(
          NotebookMetadata(
            id: manifest.notebookID,
            displayName: manifest.displayName,
            previewImageData: previewData,
            lastAccessedAt: manifest.lastAccessedAt ?? manifest.modifiedAt
          ))
      } catch {
        // Skip Bundles with invalid Manifests.
        continue
      }
    }

    return notebooks
  }
  // swiftlint:enable function_body_length

  // Creates a new Bundle folder with an initial Manifest and iink package.
  // Generates a new UUID for the Notebook ID.
  // Returns the NotebookMetadata for the newly created Bundle.
  func createBundle(displayName: String) async throws -> NotebookMetadata {
    // Generate a unique identifier for this Notebook.
    let notebookID = UUID().uuidString

    // Get the directory where Bundles are stored.
    let bundlesDirectory = try await BundleStorage.bundlesDirectory()

    // Create the Bundle folder using the Notebook ID as the folder name.
    let bundleURL = bundlesDirectory.appendingPathComponent(notebookID, isDirectory: true)
    try FileManager.default.createDirectory(
      at: bundleURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    // Create the initial Manifest.
    let manifest = Manifest(notebookID: notebookID, displayName: displayName)

    // Write the Manifest to disk using atomic write.
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    try writeManifest(manifest, to: manifestURL)

    // Create the MyScript iink package.
    let iinkPath =
      bundleURL
      .appendingPathComponent(Self.iinkFileName)
      .path
      .decomposedStringWithCanonicalMapping

    // Access the engine on the main actor to create the package.
    let packageCreated = await MainActor.run {
      guard let engine = EngineProvider.sharedInstance.engine else {
        return false
      }
      do {
        // Create the package file.
        let package = try engine.createPackage(iinkPath)
        // Create an initial "Raw Content" part in the package.
        _ = try package.createPart(with: "Raw Content")
        // Save the package to persist it to disk.
        try package.save()
        return true
      } catch {
        return false
      }
    }

    guard packageCreated else {
      throw BundleError.packageCreationFailed(notebookID: notebookID)
    }
    return NotebookMetadata(
      id: notebookID,
      displayName: displayName,
      previewImageData: nil,
      lastAccessedAt: manifest.lastAccessedAt
    )
  }

  // Renames a Notebook by updating the display name in its Manifest.
  // Also updates the modifiedAt timestamp.
  // Throws if the Bundle doesn't exist or the Manifest cannot be read or written.
  func renameBundle(notebookID: String, newDisplayName: String) async throws {
    // Find the Bundle URL by searching root level and all folders.
    guard let bundleURL = try findBundleURL(notebookID: notebookID) else {
      throw BundleError.bundleNotFound(notebookID: notebookID)
    }

    let fileManager = FileManager.default

    // Read the existing Manifest.
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw BundleError.manifestNotFound(notebookID: notebookID)
    }

    let data = try Data(contentsOf: manifestURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var manifest = try decoder.decode(Manifest.self, from: data)
    manifest.displayName = newDisplayName
    manifest.modifiedAt = Date()

    // Write the updated Manifest back to disk using atomic write.
    try writeManifest(manifest, to: manifestURL)
  }

  // Deletes a Bundle folder and all its contents including the iink package.
  // Searches both root level and inside folders to find the notebook.
  // Throws if the Bundle doesn't exist or cannot be deleted.
  func deleteBundle(notebookID: String) async throws {
    // Validate the notebookID is not empty.
    guard !notebookID.isEmpty else {
      throw BundleError.bundleNotFound(notebookID: notebookID)
    }

    // Find the Bundle URL by searching root level and all folders.
    guard let bundleURL = try findBundleURL(notebookID: notebookID) else {
      throw BundleError.bundleNotFound(notebookID: notebookID)
    }

    let fileManager = FileManager.default

    // Delete the iink package using the engine if it exists.
    let iinkPath =
      bundleURL
      .appendingPathComponent(Self.iinkFileName)
      .path
      .decomposedStringWithCanonicalMapping

    if fileManager.fileExists(atPath: iinkPath) {
      // Access the engine on the main actor to delete the package.
      await MainActor.run {
        guard let engine = EngineProvider.sharedInstance.engine else {
          return
        }
        do {
          try engine.deletePackage(iinkPath)
        } catch {
          // Package deletion failed, will delete folder directly instead.
        }
      }
    }

    // Delete the entire Bundle folder.
    try fileManager.removeItem(at: bundleURL)
  }

  // Opens a Notebook and returns a DocumentHandle for safe access.
  // Validates that the Bundle exists, the Manifest can be decoded,
  // the version is supported, and required fields are present.
  // Searches both root level and inside folders to find the notebook.
  // Throws if any validation fails.
  // swiftlint:disable function_body_length
  // Function requires comprehensive validation and error handling for notebook opening
  func openNotebook(id notebookID: String) async throws -> DocumentHandle {
    let fileManager = FileManager.default

    // Find the Bundle URL by searching root level and all folders.
    guard let bundleURL = try findBundleURL(notebookID: notebookID) else {
      throw BundleError.bundleNotFound(notebookID: notebookID)
    }

    // Check if the Manifest file exists.
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw BundleError.manifestNotFound(notebookID: notebookID)
    }

    // Read the Manifest data.
    let data = try Data(contentsOf: manifestURL)

    // Decode the Manifest.
    let manifest: Manifest
    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      manifest = try decoder.decode(Manifest.self, from: data)
    } catch {
      throw BundleError.manifestDecodingFailed(notebookID: notebookID, underlyingError: error)
    }

    // Check the Manifest version is supported.
    guard ManifestVersion.supported.contains(manifest.version) else {
      throw BundleError.unsupportedManifestVersion(
        notebookID: notebookID, version: manifest.version)
    }

    // Check required fields are present and valid.
    guard !manifest.notebookID.isEmpty else {
      throw BundleError.invalidManifest(notebookID: notebookID, reason: "notebookID is empty")
    }
    guard !manifest.displayName.isEmpty else {
      throw BundleError.invalidManifest(notebookID: notebookID, reason: "displayName is empty")
    }

    // Updates the last accessed timestamp before opening.
    var handleManifest = manifest
    handleManifest.lastAccessedAt = Date()
    do {
      try writeManifest(handleManifest, to: manifestURL)
    } catch {
      // Silently fail the lastAccessedAt update but continue opening to avoid blocking access.
      handleManifest = manifest
    }

    // Construct the path to the iink package.
    let packagePath =
      bundleURL
      .appendingPathComponent(Self.iinkFileName)
      .path
      .decomposedStringWithCanonicalMapping

    // All checks passed. Create and return the DocumentHandle.
    // The DocumentHandle will open the package internally.
    let handle = try await DocumentHandle(
      notebookID: notebookID,
      bundleURL: bundleURL,
      manifest: handleManifest,
      packagePath: packagePath,
      openOption: .existing
    )
    return handle
  }

  // Returns the file path to the iink package for a given notebook ID.
  // This is a helper method for constructing package paths.
  func iinkPackagePath(forNotebookID notebookID: String) async throws -> String {
    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let bundleURL = bundlesDirectory.appendingPathComponent(notebookID, isDirectory: true)
    return
      bundleURL
      .appendingPathComponent(Self.iinkFileName)
      .path
      .decomposedStringWithCanonicalMapping
  }

  // Writes a Manifest to disk using atomic write.
  // Writes to a temporary file first, then replaces the target file.
  // This prevents corruption if the write is interrupted.
  private func writeManifest(_ manifest: Manifest, to url: URL) throws {
    // Encode the Manifest to JSON data.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(manifest)

    // Write to a temporary file in the same directory as the target.
    let tempURL = url.deletingLastPathComponent().appendingPathComponent(
      ".\(url.lastPathComponent).tmp")
    try data.write(to: tempURL, options: [.atomic])

    // Replace the target file with the temporary file.
    // This is an atomic operation on most file systems.
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      try fileManager.removeItem(at: url)
    }
    try fileManager.moveItem(at: tempURL, to: url)
  }

  // Writes a FolderManifest to disk using atomic write.
  // Writes to a temporary file first, then replaces the target file.
  private func writeFolderManifest(_ manifest: FolderManifest, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(manifest)

    let tempURL = url.deletingLastPathComponent().appendingPathComponent(
      ".\(url.lastPathComponent).tmp")
    try data.write(to: tempURL, options: [.atomic])

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      try fileManager.removeItem(at: url)
    }
    try fileManager.moveItem(at: tempURL, to: url)
  }

  // MARK: - Folder Operations

  // Lists all folders in the Notebooks directory.
  // Returns an array of FolderMetadata for each folder that has a valid folder.json.
  // Skips directories that have manifest.json (those are notebooks, not folders).
  func listFolders() async throws -> [FolderMetadata] {
    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let fileManager = FileManager.default

    let contents = try fileManager.contentsOfDirectory(
      at: bundlesDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var folders: [FolderMetadata] = []

    for url in contents {
      let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
      guard resourceValues.isDirectory == true else {
        continue
      }

      // Check for folder.json to identify folders.
      let folderManifestURL = url.appendingPathComponent(Self.folderManifestFileName)
      guard fileManager.fileExists(atPath: folderManifestURL.path) else {
        continue
      }

      // Read and decode the folder manifest.
      do {
        let data = try Data(contentsOf: folderManifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folderManifest = try decoder.decode(FolderManifest.self, from: data)

        // Collect preview images and notebook count from contained notebooks.
        let notebooksInFolder = try listBundlesInFolderInternal(folderURL: url)
        let previewImages = notebooksInFolder
          .prefix(FolderConstants.maxPreviewImages)
          .compactMap { $0.previewImageData }

        folders.append(
          FolderMetadata(
            id: folderManifest.folderID,
            displayName: folderManifest.displayName,
            previewImages: previewImages,
            notebookCount: notebooksInFolder.count,
            pdfCount: 0,
            modifiedAt: folderManifest.modifiedAt
          ))
      } catch {
        // Skip folders with invalid manifests.
        continue
      }
    }

    return folders
  }

  // Lists all notebooks contained within a specific folder.
  // Returns an array of NotebookMetadata for each notebook in the folder.
  func listBundlesInFolder(folderID: String) async throws -> [NotebookMetadata] {
    // Validate folder ID is not empty.
    guard !folderID.isEmpty else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let folderURL = bundlesDirectory.appendingPathComponent(folderID, isDirectory: true)
    let fileManager = FileManager.default

    // Check if the folder exists.
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    // Check that this is actually a folder (has folder.json).
    let folderManifestURL = folderURL.appendingPathComponent(Self.folderManifestFileName)
    guard fileManager.fileExists(atPath: folderManifestURL.path) else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    return try listBundlesInFolderInternal(folderURL: folderURL)
  }

  // Internal helper to list notebooks in a folder URL.
  private func listBundlesInFolderInternal(folderURL: URL) throws -> [NotebookMetadata] {
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(
      at: folderURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var notebooks: [NotebookMetadata] = []

    for url in contents {
      let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
      guard resourceValues.isDirectory == true else {
        continue
      }

      // Try to read the Manifest from this Bundle.
      let manifestURL = url.appendingPathComponent(Self.manifestFileName)
      guard fileManager.fileExists(atPath: manifestURL.path) else {
        continue
      }

      do {
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(Manifest.self, from: data)
        let previewURL = url.appendingPathComponent(Self.previewImageFileName)
        let previewData: Data? =
          fileManager.fileExists(atPath: previewURL.path)
          ? try? Data(contentsOf: previewURL) : nil

        notebooks.append(
          NotebookMetadata(
            id: manifest.notebookID,
            displayName: manifest.displayName,
            previewImageData: previewData,
            lastAccessedAt: manifest.lastAccessedAt ?? manifest.modifiedAt
          ))
      } catch {
        // Skip notebooks with invalid manifests.
        continue
      }
    }

    // Sort by lastAccessedAt descending (most recent first).
    // IMPORTANT: This sort order must match the display order in FolderOverlay
    // for thumbnail index consistency when dragging items out of folders.
    notebooks.sort {
      ($0.lastAccessedAt ?? .distantPast) > ($1.lastAccessedAt ?? .distantPast)
    }

    return notebooks
  }

  // Creates a new folder with the given display name.
  // Generates a UUID for the folder ID.
  // Creates folder.json with initial metadata.
  func createFolder(displayName: String) async throws -> FolderMetadata {
    let folderID = UUID().uuidString
    let bundlesDirectory = try await BundleStorage.bundlesDirectory()

    // Create the folder directory.
    let folderURL = bundlesDirectory.appendingPathComponent(folderID, isDirectory: true)
    try FileManager.default.createDirectory(
      at: folderURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    // Create and write the folder manifest.
    let folderManifest = FolderManifest(folderID: folderID, displayName: displayName)
    let folderManifestURL = folderURL.appendingPathComponent(Self.folderManifestFileName)
    try writeFolderManifest(folderManifest, to: folderManifestURL)

    return FolderMetadata(
      id: folderID,
      displayName: displayName,
      previewImages: [],
      notebookCount: 0,
      pdfCount: 0,
      modifiedAt: folderManifest.modifiedAt
    )
  }

  // Renames a folder by updating the display name in folder.json.
  // Updates the modifiedAt timestamp.
  func renameFolder(folderID: String, newDisplayName: String) async throws {
    guard !folderID.isEmpty else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let folderURL = bundlesDirectory.appendingPathComponent(folderID, isDirectory: true)
    let fileManager = FileManager.default

    // Check if the folder exists.
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    // Check that this is actually a folder.
    let folderManifestURL = folderURL.appendingPathComponent(Self.folderManifestFileName)
    guard fileManager.fileExists(atPath: folderManifestURL.path) else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    // Read and update the folder manifest.
    let data = try Data(contentsOf: folderManifestURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var folderManifest = try decoder.decode(FolderManifest.self, from: data)
    folderManifest.displayName = newDisplayName
    folderManifest.modifiedAt = Date()

    try writeFolderManifest(folderManifest, to: folderManifestURL)
  }

  // Deletes a folder and ALL notebooks contained within it.
  // This is a destructive operation that removes the folder directory recursively.
  func deleteFolder(folderID: String) async throws {
    guard !folderID.isEmpty else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let folderURL = bundlesDirectory.appendingPathComponent(folderID, isDirectory: true)
    let fileManager = FileManager.default

    // Check if the folder exists.
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    // Check that this is actually a folder.
    let folderManifestURL = folderURL.appendingPathComponent(Self.folderManifestFileName)
    guard fileManager.fileExists(atPath: folderManifestURL.path) else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    // Delete iink packages for all notebooks in the folder.
    let notebooks = try listBundlesInFolderInternal(folderURL: folderURL)
    for notebook in notebooks {
      let notebookURL = folderURL.appendingPathComponent(notebook.id, isDirectory: true)
      let iinkPath =
        notebookURL
        .appendingPathComponent(Self.iinkFileName)
        .path
        .decomposedStringWithCanonicalMapping

      if fileManager.fileExists(atPath: iinkPath) {
        await MainActor.run {
          guard let engine = EngineProvider.sharedInstance.engine else { return }
          do {
            try engine.deletePackage(iinkPath)
          } catch {
            // Package deletion failed, folder delete will clean it up.
          }
        }
      }
    }

    // Delete the entire folder directory.
    try fileManager.removeItem(at: folderURL)
  }

  // Moves a notebook from its current location (root or another folder) into the specified folder.
  // Physically moves the notebook directory.
  func moveNotebookToFolder(notebookID: String, folderID: String) async throws {
    guard !notebookID.isEmpty else {
      throw BundleError.bundleNotFound(notebookID: notebookID)
    }
    guard !folderID.isEmpty else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let fileManager = FileManager.default

    // Verify the folder exists and is actually a folder.
    let folderURL = bundlesDirectory.appendingPathComponent(folderID, isDirectory: true)
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }
    let folderManifestURL = folderURL.appendingPathComponent(Self.folderManifestFileName)
    guard fileManager.fileExists(atPath: folderManifestURL.path) else {
      throw FolderBundleError.folderNotFound(folderID: folderID)
    }

    // Find the notebook's current location.
    guard let currentNotebookURL = try findBundleURL(notebookID: notebookID) else {
      throw BundleError.bundleNotFound(notebookID: notebookID)
    }

    // Check if notebook is already in the target folder.
    let destinationURL = folderURL.appendingPathComponent(notebookID, isDirectory: true)
    if currentNotebookURL.path == destinationURL.path {
      throw FolderBundleError.notebookAlreadyInFolder(notebookID: notebookID, folderID: folderID)
    }

    // Move the notebook directory.
    try fileManager.moveItem(at: currentNotebookURL, to: destinationURL)
  }

  // Moves a notebook from a folder to the root level (Documents/Notebooks/).
  // Requires specifying which folder the notebook is in for validation.
  func moveNotebookToRoot(notebookID: String, fromFolderID: String) async throws {
    guard !notebookID.isEmpty else {
      throw BundleError.bundleNotFound(notebookID: notebookID)
    }
    guard !fromFolderID.isEmpty else {
      throw FolderBundleError.folderNotFound(folderID: fromFolderID)
    }

    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let fileManager = FileManager.default

    // Verify the folder exists and is actually a folder.
    let folderURL = bundlesDirectory.appendingPathComponent(fromFolderID, isDirectory: true)
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw FolderBundleError.folderNotFound(folderID: fromFolderID)
    }
    let folderManifestURL = folderURL.appendingPathComponent(Self.folderManifestFileName)
    guard fileManager.fileExists(atPath: folderManifestURL.path) else {
      throw FolderBundleError.folderNotFound(folderID: fromFolderID)
    }

    // Check if the notebook exists in the specified folder.
    let notebookInFolderURL = folderURL.appendingPathComponent(notebookID, isDirectory: true)
    let notebookManifestURL = notebookInFolderURL.appendingPathComponent(Self.manifestFileName)
    guard fileManager.fileExists(atPath: notebookManifestURL.path) else {
      throw FolderBundleError.notebookNotInFolder(notebookID: notebookID)
    }

    // Move the notebook to root level.
    let destinationURL = bundlesDirectory.appendingPathComponent(notebookID, isDirectory: true)
    try fileManager.moveItem(at: notebookInFolderURL, to: destinationURL)
  }

  // Finds the bundle URL for a notebook, checking both root and all folders.
  // Returns nil if the notebook is not found.
  private func findBundleURL(notebookID: String) throws -> URL? {
    let bundlesDirectory = try BundleStorage.bundlesDirectorySync()
    let fileManager = FileManager.default

    // Check root level first.
    let rootBundleURL = bundlesDirectory.appendingPathComponent(notebookID, isDirectory: true)
    let rootManifestURL = rootBundleURL.appendingPathComponent(Self.manifestFileName)
    if fileManager.fileExists(atPath: rootManifestURL.path) {
      return rootBundleURL
    }

    // Search inside folders.
    let contents = try fileManager.contentsOfDirectory(
      at: bundlesDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    for url in contents {
      let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
      guard resourceValues.isDirectory == true else { continue }

      // Check if this is a folder.
      let folderManifestURL = url.appendingPathComponent(Self.folderManifestFileName)
      guard fileManager.fileExists(atPath: folderManifestURL.path) else { continue }

      // Check for notebook inside this folder.
      let nestedBundleURL = url.appendingPathComponent(notebookID, isDirectory: true)
      let nestedManifestURL = nestedBundleURL.appendingPathComponent(Self.manifestFileName)
      if fileManager.fileExists(atPath: nestedManifestURL.path) {
        return nestedBundleURL
      }
    }

    return nil
  }
}

// Errors that can occur when working with Bundles.
enum BundleError: LocalizedError {
  case bundleNotFound(notebookID: String)
  case manifestNotFound(notebookID: String)
  case manifestDecodingFailed(notebookID: String, underlyingError: Error)
  case unsupportedManifestVersion(notebookID: String, version: Int)
  case invalidManifest(notebookID: String, reason: String)
  case packageCreationFailed(notebookID: String)

  var errorDescription: String? {
    switch self {
    case .bundleNotFound(let notebookID):
      return "Bundle not found: \(notebookID)"
    case .manifestNotFound(let notebookID):
      return "Manifest not found in Bundle: \(notebookID)"
    case .manifestDecodingFailed(let notebookID, let underlyingError):
      return
        "Failed to decode Manifest in Bundle \(notebookID): \(underlyingError.localizedDescription)"
    case .unsupportedManifestVersion(let notebookID, let version):
      return "Unsupported Manifest version \(version) in Bundle: \(notebookID)"
    case .invalidManifest(let notebookID, let reason):
      return "Invalid Manifest in Bundle \(notebookID): \(reason)"
    case .packageCreationFailed(let notebookID):
      return "Failed to create MyScript package for Bundle: \(notebookID)"
    }
  }
}
