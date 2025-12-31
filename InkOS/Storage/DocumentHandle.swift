import Foundation

// Represents one opened notebook.
// Keeps the manifest and the iink package tied to the notebook folder.
// Uses an actor so notebook operations do not run at the same time.
actor DocumentHandle {
  // Stores the notebook identifier.
  let notebookID: String

  // Stores the manifest loaded at open time.
  let initialManifest: Manifest

  // Tracks the current manifest state including any updates.
  private var currentManifest: Manifest

  // Stores the notebook folder URL.
  private let bundleURL: URL

  // Stores the file path to the iink package.
  let packagePath: String

  // Stores the opened package for the lifetime of the handle.
  // Uses protocol type to allow dependency injection for testing.
  // Uses MainActor access because the SDK objects are not thread-safe.
  private var package: (any ContentPackageProtocol)?

  // Stores the manifest file name inside the notebook folder.
  private static let manifestFileName = "manifest.json"
  // Stores the preview image file name inside the notebook folder.
  private static let previewImageFileName = "preview.png"
  // Stores the JIIX file name inside the notebook folder.
  private static let jiixFileName = "content.jiix"

  // Creates a handle and opens the iink package.
  // Opens on the main actor because the engine is used on the main actor in this project.
  // Accepts an optional engineProvider dependency; defaults to the shared singleton for production use.
  // Pass nil to use the default EngineProvider.sharedInstance.
  // This avoids MainActor isolation issues with default parameter.
  init(
    notebookID: String,
    bundleURL: URL,
    manifest: Manifest,
    packagePath: String,
    openOption: IINKPackageOpenOption,
    engineProvider: (any EngineProviderProtocol)? = nil
  ) async throws {
    self.notebookID = notebookID
    self.bundleURL = bundleURL
    self.initialManifest = manifest
    self.currentManifest = manifest
    self.packagePath = packagePath

    self.package = try await MainActor.run {
      // Use provided engine provider or fall back to the shared singleton.
      let provider = engineProvider ?? EngineProvider.sharedInstance
      guard let engine = provider.engineInstance else {
        throw DocumentHandleError.engineUnavailable
      }
      do {
        let openedPackage = try engine.openContentPackage(packagePath, openOption: openOption)
        return openedPackage
      } catch {
        throw DocumentHandleError.packageOpenFailed(underlyingError: error)
      }
    }
  }

  // Loads the current manifest from disk.
  func loadManifest() throws -> Manifest {
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    let data = try Data(contentsOf: manifestURL)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let manifest = try decoder.decode(Manifest.self, from: data)
    return manifest
  }

  // Returns the package if it was opened successfully.
  func getPackage() async -> (any ContentPackageProtocol)? {
    let capturedPackage = self.package
    return await MainActor.run {
      capturedPackage
    }
  }

  // Returns the number of parts in the package.
  func getPartCount() async -> Int {
    guard let capturedPackage = self.package else { return 0 }
    let count = await MainActor.run {
      capturedPackage.getPartCount()
    }
    return count
  }

  // Returns a part by index.
  func getPart(at index: Int) async -> (any ContentPartProtocol)? {
    guard let capturedPackage = self.package else { return nil }
    guard index >= 0 else { return nil }

    return await MainActor.run {
      guard index < capturedPackage.getPartCount() else { return nil }
      do {
        let part = try capturedPackage.getPart(at: index)
        return part
      } catch {
        return nil
      }
    }
  }

  // Ensures there is at least one part and returns the first part.
  func ensureInitialPart(type: String) async throws -> any ContentPartProtocol {
    guard let capturedPackage = self.package else {
      throw DocumentHandleError.packageNotAvailable
    }
    return try await MainActor.run {
      if capturedPackage.getPartCount() == 0 {
        do {
          let part = try capturedPackage.createNewPart(with: type)
          return part
        } catch {
          throw DocumentHandleError.partCreationFailed(underlyingError: error)
        }
      }
      do {
        let part = try capturedPackage.getPart(at: 0)
        return part
      } catch {
        throw DocumentHandleError.partLoadFailed(underlyingError: error)
      }
    }
  }

  // Saves the package into the compressed archive.
  func savePackage() async throws {
    guard let capturedPackage = self.package else {
      throw DocumentHandleError.packageNotAvailable
    }
    try await MainActor.run {
      try capturedPackage.savePackage()
    }
  }

  // Saves current in-memory changes to the temp folder.
  func savePackageToTemp() async throws {
    guard let capturedPackage = self.package else {
      throw DocumentHandleError.packageNotAvailable
    }
    try await MainActor.run {
      try capturedPackage.savePackageToTemp()
    }
  }

  // Saves and releases the package reference.
  func close(saveBeforeClose: Bool = true) async {
    if saveBeforeClose {
      do {
        try await savePackage()
      } catch {
        // Ignore save errors during close.
      }
    }
    self.package = nil
  }

  // Saves a preview image for the notebook.
  func savePreviewImageData(_ data: Data) throws {
    let previewURL = bundleURL.appendingPathComponent(Self.previewImageFileName)
    do {
      try data.write(to: previewURL, options: [.atomic])
    } catch {
      throw DocumentHandleError.previewSaveFailed(underlyingError: error)
    }
  }

  // Exposes the current manifest state.
  var manifest: Manifest {
    currentManifest
  }

  // Updates the viewport state in the manifest and persists it to disk.
  // This allows incremental updates without a full package save.
  // Errors are logged but not thrown as viewport persistence is a convenience feature.
  func updateViewportState(_ state: ViewportState) async {
    // Update the in-memory manifest.
    currentManifest.viewportState = state
    currentManifest.modifiedAt = Date()

    // Persist to disk.
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(currentManifest)
      try data.write(to: manifestURL, options: [.atomic])
    } catch {
      // Non-fatal error - viewport state is a convenience feature.
      // Document content is still safe.
    }
  }

  // Saves JIIX data to the content.jiix file in the notebook bundle.
  // Uses atomic write to prevent corruption if interrupted.
  func saveJIIXData(_ data: Data) async throws {
    let jiixURL = bundleURL.appendingPathComponent(Self.jiixFileName)
    do {
      try data.write(to: jiixURL, options: [.atomic])
    } catch {
      throw JIIXPersistenceError.saveFailed(reason: error.localizedDescription)
    }
  }

  // Loads JIIX data from the content.jiix file in the notebook bundle.
  // Returns nil if the file does not exist.
  func loadJIIXData() async throws -> Data? {
    let jiixURL = bundleURL.appendingPathComponent(Self.jiixFileName)
    let fileManager = FileManager.default

    // Return nil if file does not exist.
    guard fileManager.fileExists(atPath: jiixURL.path) else {
      return nil
    }

    do {
      return try Data(contentsOf: jiixURL)
    } catch {
      throw JIIXPersistenceError.loadFailed(reason: error.localizedDescription)
    }
  }
}

// DocumentHandle conforms to JIIXDocumentHandleProtocol for JIIX persistence.
extension DocumentHandle: JIIXDocumentHandleProtocol {}

// Represents errors for package access.
enum DocumentHandleError: LocalizedError {
  case engineUnavailable
  case packageOpenFailed(underlyingError: Error)
  case packageNotAvailable
  case partCreationFailed(underlyingError: Error)
  case partLoadFailed(underlyingError: Error)
  case previewSaveFailed(underlyingError: Error)

  var errorDescription: String? {
    switch self {
    case .engineUnavailable:
      return "MyScript engine is not available."
    case .packageOpenFailed(let underlyingError):
      return "Failed to open MyScript package: \(underlyingError.localizedDescription)"
    case .packageNotAvailable:
      return "MyScript package is not available."
    case .partCreationFailed(let underlyingError):
      return "Failed to create a content part: \(underlyingError.localizedDescription)"
    case .partLoadFailed(let underlyingError):
      return "Failed to load a content part: \(underlyingError.localizedDescription)"
    case .previewSaveFailed(let underlyingError):
      return "Failed to save notebook preview: \(underlyingError.localizedDescription)"
    }
  }
}
