import Foundation

// A DocumentHandle represents an open Notebook and provides safe operations
// for working with the MyScript iink package without exposing file paths.
// The editor never sees file paths; it only uses the handle.
// Being an actor ensures only one operation happens at a time.
actor DocumentHandle {
  // The unique identifier of the Notebook this handle represents.
  let notebookID: String

  // The initial Manifest loaded when the Notebook was opened.
  // This is provided so the editor can build the Notebook Model immediately.
  let initialManifest: Manifest

  // The URL of the Bundle folder. Private to hide file paths from the editor.
  private let bundleURL: URL

  // The file path to the MyScript iink package for this notebook.
  let packagePath: String

  // Reference to the opened MyScript package.
  // This must be accessed on the main actor since IINKContentPackage is not thread-safe.
  private var package: IINKContentPackage?

  // The name of the Manifest file inside the Bundle.
  private static let manifestFileName = "manifest.json"

  // Creates a new DocumentHandle for the given Bundle.
  // Opens the MyScript package at the specified path.
  // This initializer is internal so only the BundleManager can create handles.
  init(notebookID: String, bundleURL: URL, manifest: Manifest, packagePath: String) async {
    self.notebookID = notebookID
    self.bundleURL = bundleURL
    self.initialManifest = manifest
    self.packagePath = packagePath

    // Open the package on the main actor since the engine is @MainActor.
    self.package = await MainActor.run {
      guard let engine = EngineProvider.shared.engine else {
        return nil
      }
      do {
        let openedPackage = try engine.openPackage(packagePath)
        return openedPackage
      } catch {
        return nil
      }
    }
  }

  // MARK: - Manifest API

  // Loads the current Manifest from disk.
  // Use this to get the latest state of the Notebook metadata.
  func loadManifest() throws -> Manifest {
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    let data = try Data(contentsOf: manifestURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Manifest.self, from: data)
  }

  // MARK: - Package API

  // Returns the MyScript package if it was successfully opened.
  // The package must be accessed on the main actor.
  func getPackage() async -> IINKContentPackage? {
    // Capture the package reference before entering MainActor context.
    let capturedPackage = self.package
    return await MainActor.run {
      return capturedPackage
    }
  }

  // Returns the number of parts (pages) in the package.
  func getPartCount() async -> Int {
    // Capture the package reference before entering MainActor context.
    guard let capturedPackage = self.package else { return 0 }
    return await MainActor.run {
      return capturedPackage.partCount()
    }
  }

  // Retrieves a specific part (page) from the package by index.
  // Returns nil if the index is out of bounds or the package is not available.
  func getPart(at index: Int) async -> IINKContentPart? {
    // Capture the package reference before entering MainActor context.
    guard let capturedPackage = self.package else { return nil }
    guard index >= 0 else { return nil }
    return await MainActor.run {
      guard index < capturedPackage.partCount() else { return nil }
      do {
        return try capturedPackage.part(at: index)
      } catch {
        return nil
      }
    }
  }

  // Saves the package to disk as a compressed zip archive.
  // This is a slow operation due to compression, but creates a self-contained file.
  // Use this when closing the notebook or when the app backgrounds.
  func savePackage() async throws {
    // Capture the package reference before entering MainActor context.
    guard let capturedPackage = self.package else {
      throw DocumentHandleError.packageNotAvailable
    }
    let capturedPath = self.packagePath
    try await MainActor.run {
      try capturedPackage.save()
    }
  }

  // Saves the package content from memory to the temporary folder.
  // This is much faster than save() and is suitable for frequent auto-saves.
  // MyScript can recover this data if the app is force-quit.
  func savePackageToTemp() async throws {
    // Capture the package reference before entering MainActor context.
    guard let capturedPackage = self.package else {
      throw DocumentHandleError.packageNotAvailable
    }
    try await MainActor.run {
      try capturedPackage.saveToTemp()
    }
  }

  // MARK: - Cleanup

  // Closes the package and releases resources.
  // Call this when the notebook is closed.
  func close() async {
    // Save the package before closing.
    do {
      try await savePackage()
    } catch {
      // Save failed, continue with close.
    }

    // Release the package reference.
    // We can set it directly since we're already in the actor context.
    self.package = nil
  }
}

// Errors that can occur when working with DocumentHandles.
enum DocumentHandleError: LocalizedError {
  case packageNotAvailable

  var errorDescription: String? {
    switch self {
    case .packageNotAvailable:
      return "MyScript package is not available. The package may not have been opened successfully."
    }
  }
}
