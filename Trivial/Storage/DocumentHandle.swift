import Foundation

// Data required to save an ink item. Passed by the editor when saving.
// Sendable so it can be passed across actor boundaries.
struct InkItemSaveRequest: Sendable {
  // Unique identifier for this Ink Item.
  let id: String

  // The rectangular region this Ink Item occupies on the canvas.
  let rectangle: InkRectangle

  // The raw ink data to save (e.g., serialized PKDrawing).
  let payload: Data

  init(id: String, rectangle: InkRectangle, payload: Data) {
    self.id = id
    self.rectangle = rectangle
    self.payload = payload
  }
}

// Result of loading an ink item's payload.
// Sendable so it can be passed across actor boundaries.
struct LoadedInkPayload: Sendable {
  // The Ink Item's identifier.
  let id: String

  // The raw ink data loaded from disk.
  let payload: Data

  init(id: String, payload: Data) {
    self.id = id
    self.payload = payload
  }
}

// A DocumentHandle represents an open Notebook and provides safe operations
// for the editor to load and save data without exposing file paths.
// The editor never sees file paths; it only uses the handle.
// Being an actor ensures only one save operation happens at a time.
actor DocumentHandle {
  // The unique identifier of the Notebook this handle represents.
  let notebookID: String

  // The initial Manifest loaded when the Notebook was opened.
  // This is provided so the editor can build the Notebook Model immediately.
  let initialManifest: Manifest

  // The URL of the Bundle folder. Private to hide file paths from the editor.
  private let bundleURL: URL

  // The name of the Manifest file inside the Bundle.
  private static let manifestFileName = "manifest.json"

  // The name of the folder where ink payload files are stored.
  private static let inkFolderName = "ink"

  // Creates a new DocumentHandle for the given Bundle.
  // This initializer is internal so only the BundleManager can create handles.
  init(notebookID: String, bundleURL: URL, manifest: Manifest) {
    self.notebookID = notebookID
    self.bundleURL = bundleURL
    self.initialManifest = manifest
  }

  // MARK: - Load API

  // Loads the current Manifest from disk.
  // Use this to get the latest state of the Notebook.
  func loadManifest() throws -> Manifest {
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(Manifest.self, from: data)
  }

  // Loads ink payloads for the specified item IDs.
  // Returns an array of loaded payloads. Items that cannot be loaded are skipped.
  // This allows the viewport controller to request only visible items.
  func loadInkPayloads(for itemIDs: [String]) -> [LoadedInkPayload] {
    let inkFolderURL = bundleURL.appendingPathComponent(Self.inkFolderName, isDirectory: true)
    var results: [LoadedInkPayload] = []

    for id in itemIDs {
      let inkFileURL = inkFolderURL.appendingPathComponent("\(id).ink")
      do {
        let data = try Data(contentsOf: inkFileURL)
        results.append(LoadedInkPayload(id: id, payload: data))
      } catch {
        // Skip items that cannot be loaded. The caller can handle missing items.
        continue
      }
    }

    return results
  }

  // MARK: - Save API

  // Saves ink items and updates the manifest atomically.
  // Writes payload files first, then updates the manifest.
  // This ensures the manifest never references missing payload files.
  // The actor isolation guarantees only one save runs at a time.
  func saveInkItems(_ requests: [InkItemSaveRequest]) throws {
    guard !requests.isEmpty else { return }

    let fileManager = FileManager.default
    let inkFolderURL = bundleURL.appendingPathComponent(Self.inkFolderName, isDirectory: true)

    // Create the ink folder if it does not exist.
    if !fileManager.fileExists(atPath: inkFolderURL.path) {
      try fileManager.createDirectory(at: inkFolderURL, withIntermediateDirectories: true)
    }

    // Step 1: Write all payload files first.
    var savedItems: [InkItem] = []
    for request in requests {
      let inkFileName = "\(request.id).ink"
      let inkFileURL = inkFolderURL.appendingPathComponent(inkFileName)
      let tempURL = inkFolderURL.appendingPathComponent(".\(request.id).ink.tmp")

      // Write to temp file first.
      try request.payload.write(to: tempURL, options: [.atomic])

      // Replace target file with temp file.
      if fileManager.fileExists(atPath: inkFileURL.path) {
        try fileManager.removeItem(at: inkFileURL)
      }
      try fileManager.moveItem(at: tempURL, to: inkFileURL)

      // Build the InkItem for the manifest.
      let payloadPath = "\(Self.inkFolderName)/\(inkFileName)"
      let inkItem = InkItem(id: request.id, rectangle: request.rectangle, payloadPath: payloadPath)
      savedItems.append(inkItem)
    }

    // Step 2: Read the current manifest, update it, and write it back.
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    let manifestData = try Data(contentsOf: manifestURL)
    var manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)

    // Update the manifest's inkItems array.
    // For each saved item, replace existing item with same ID or append new.
    for savedItem in savedItems {
      if let index = manifest.inkItems.firstIndex(where: { $0.id == savedItem.id }) {
        manifest.inkItems[index] = savedItem
      } else {
        manifest.inkItems.append(savedItem)
      }
    }

    // Write manifest atomically.
    try writeManifest(manifest)
  }

  // Deletes ink items from disk and updates the manifest.
  // Removes from manifest first, then deletes the payload files.
  func deleteInkItems(_ itemIDs: [String]) throws {
    guard !itemIDs.isEmpty else { return }

    let fileManager = FileManager.default
    let inkFolderURL = bundleURL.appendingPathComponent(Self.inkFolderName, isDirectory: true)
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)

    // Step 1: Update manifest to remove the items.
    let manifestData = try Data(contentsOf: manifestURL)
    var manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)

    let idsToRemove = Set(itemIDs)
    manifest.inkItems.removeAll { idsToRemove.contains($0.id) }

    try writeManifest(manifest)

    // Step 2: Delete the payload files.
    for id in itemIDs {
      let inkFileURL = inkFolderURL.appendingPathComponent("\(id).ink")
      if fileManager.fileExists(atPath: inkFileURL.path) {
        try fileManager.removeItem(at: inkFileURL)
      }
    }
  }

  // MARK: - Private Helpers

  // Writes the manifest to disk using atomic write.
  private func writeManifest(_ manifest: Manifest) throws {
    let manifestURL = bundleURL.appendingPathComponent(Self.manifestFileName)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)

    // Write to a temporary file first for safe atomic write.
    let tempURL = bundleURL.appendingPathComponent(".\(Self.manifestFileName).tmp")
    try data.write(to: tempURL, options: [.atomic])

    // Replace the target file with the temporary file.
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: manifestURL.path) {
      try fileManager.removeItem(at: manifestURL)
    }
    try fileManager.moveItem(at: tempURL, to: manifestURL)
  }
}
