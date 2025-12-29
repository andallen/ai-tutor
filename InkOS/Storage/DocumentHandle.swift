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
  // Uses MainActor access because the SDK objects are not thread-safe.
  private var package: IINKContentPackage?

  // Stores the manifest file name inside the notebook folder.
  private static let manifestFileName = "manifest.json"
  // Stores the preview image file name inside the notebook folder.
  private static let previewImageFileName = "preview.png"

  // Creates a handle and opens the iink package.
  // Opens on the main actor because the engine is used on the main actor in this project.
  init(
    notebookID: String,
    bundleURL: URL,
    manifest: Manifest,
    packagePath: String,
    openOption: IINKPackageOpenOption
  ) async throws {
    self.notebookID = notebookID
    self.bundleURL = bundleURL
    self.initialManifest = manifest
    self.currentManifest = manifest
    self.packagePath = packagePath

    self.package = try await MainActor.run {
      guard let engine = EngineProvider.sharedInstance.engine else {
        appLog("❌ DocumentHandle.init engine unavailable notebookID=\(notebookID)")
        throw DocumentHandleError.engineUnavailable
      }
      do {
        let openedPackage = try engine.openPackage(packagePath, openOption: openOption)
        return openedPackage
      } catch {
        appLog("❌ DocumentHandle.init failed open package notebookID=\(notebookID) error=\(error)")
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
  func getPackage() async -> IINKContentPackage? {
    let capturedPackage = self.package
    return await MainActor.run {
      capturedPackage
    }
  }

  // Returns the number of parts in the package.
  func getPartCount() async -> Int {
    guard let capturedPackage = self.package else { return 0 }
    let count = await MainActor.run {
      capturedPackage.partCount()
    }
    return count
  }

  // Returns a part by index.
  func getPart(at index: Int) async -> IINKContentPart? {
    guard let capturedPackage = self.package else { return nil }
    guard index >= 0 else { return nil }

    return await MainActor.run {
      guard index < capturedPackage.partCount() else { return nil }
      do {
        let part = try capturedPackage.part(at: index)
        return part
      } catch {
        appLog(
          "❌ DocumentHandle.getPart failed notebookID=\(notebookID) index=\(index) error=\(error)")
        return nil
      }
    }
  }

  // Ensures there is at least one part and returns the first part.
  func ensureInitialPart(type: String) async throws -> IINKContentPart {
    guard let capturedPackage = self.package else {
      appLog("❌ DocumentHandle.ensureInitialPart missing package notebookID=\(notebookID)")
      throw DocumentHandleError.packageNotAvailable
    }
    return try await MainActor.run {
      if capturedPackage.partCount() == 0 {
        do {
          let part = try capturedPackage.createPart(with: type)
          return part
        } catch {
          appLog(
            "❌ DocumentHandle.ensureInitialPart create failed notebookID=\(notebookID) error=\(error)"
          )
          throw DocumentHandleError.partCreationFailed(underlyingError: error)
        }
      }
      do {
        let part = try capturedPackage.part(at: 0)
        return part
      } catch {
        appLog(
          "❌ DocumentHandle.ensureInitialPart load failed notebookID=\(notebookID) error=\(error)"
        )
        throw DocumentHandleError.partLoadFailed(underlyingError: error)
      }
    }
  }

  // Saves the package into the compressed archive.
  func savePackage() async throws {
    guard let capturedPackage = self.package else {
      appLog("❌ DocumentHandle.savePackage missing package notebookID=\(notebookID)")
      throw DocumentHandleError.packageNotAvailable
    }
    try await MainActor.run {
      try capturedPackage.save()
    }
  }

  // Saves current in-memory changes to the temp folder.
  func savePackageToTemp() async throws {
    guard let capturedPackage = self.package else {
      appLog("❌ DocumentHandle.savePackageToTemp missing package notebookID=\(notebookID)")
      throw DocumentHandleError.packageNotAvailable
    }
    try await MainActor.run {
      try capturedPackage.saveToTemp()
    }
  }

  // Saves and releases the package reference.
  func close(saveBeforeClose: Bool = true) async {
    if saveBeforeClose {
      do {
        try await savePackage()
      } catch {
        appLog("⚠️ DocumentHandle.close save failed notebookID=\(notebookID) error=\(error)")
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
      addLog(
        "🧪 DocumentHandle.savePreviewImageData saved notebookID=\(notebookID) bytes=\(data.count) path=\(previewURL.lastPathComponent)"
      )
    } catch {
      addLog(
        "🧪 DocumentHandle.savePreviewImageData failed notebookID=\(notebookID) error=\(error)"
      )
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
      addLog(
        "🧪 DocumentHandle.updateViewportState saved notebookID=\(notebookID) offset=(\(state.offsetX),\(state.offsetY)) scale=\(state.scale)"
      )
    } catch {
      appLog(
        "⚠️ DocumentHandle.updateViewportState failed notebookID=\(notebookID) error=\(error)"
      )
      // Non-fatal error - viewport state is a convenience feature.
      // Document content is still safe.
    }
  }
}

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
