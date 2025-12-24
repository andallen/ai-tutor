import Foundation

// Represents one opened notebook.
// Keeps the manifest and the iink package tied to the notebook folder.
// Uses an actor so notebook operations do not run at the same time.
actor DocumentHandle {
  // Stores the notebook identifier.
  let notebookID: String

  // Stores the manifest loaded at open time.
  let initialManifest: Manifest

  // Stores the notebook folder URL.
  private let bundleURL: URL

  // Stores the file path to the iink package.
  let packagePath: String

  // Stores the opened package for the lifetime of the handle.
  // Uses MainActor access because the SDK objects are not thread-safe.
  private var package: IINKContentPackage?

  // Stores the manifest file name inside the notebook folder.
  private static let manifestFileName = "manifest.json"

  // Creates a handle and opens the iink package.
  // Opens on the main actor because the engine is used on the main actor in this project.
  init(notebookID: String, bundleURL: URL, manifest: Manifest, packagePath: String) async {
    self.notebookID = notebookID
    self.bundleURL = bundleURL
    self.initialManifest = manifest
    self.packagePath = packagePath

    self.package = await MainActor.run {
      guard let engine = EngineProvider.shared.engine else {
        appLog("❌ DocumentHandle.init engine unavailable notebookID=\(notebookID)")
        return nil
      }
      do {
        // Open or create the package if it is missing.
        // Matches the SDK guidance to use openPackage(openOption:) for create-or-open behavior.
        let openedPackage = try engine.openPackage(packagePath, openOption: .create)
        return openedPackage
      } catch {
        appLog("❌ DocumentHandle.init failed open package notebookID=\(notebookID) error=\(error)")
        return nil
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
  func close() async {
    do {
      try await savePackage()
    } catch {
      appLog("⚠️ DocumentHandle.close save failed notebookID=\(notebookID) error=\(error)")
      // Ignore save errors during close.
    }

    self.package = nil
  }
}

// Represents errors for package access.
enum DocumentHandleError: LocalizedError {
  case packageNotAvailable

  var errorDescription: String? {
    switch self {
    case .packageNotAvailable:
      return "MyScript package is not available."
    }
  }
}
