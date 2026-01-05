//
// FolderManifest.swift
// InkOS
//
// Data models for folder support in the storage layer.
// Folders organize notebooks within Documents/Notebooks/ and are distinguished
// from notebooks by containing folder.json instead of manifest.json.
//

import Foundation

// MARK: - FolderManifestVersion

// Version constants for the FolderManifest format.
// Follows the same pattern as ManifestVersion for notebooks.
enum FolderManifestVersion: Sendable {
  static let current = 1
  static let supported: Set<Int> = [1]
}

// MARK: - FolderManifest

// The FolderManifest is a JSON file inside the folder that describes folder metadata.
// Stored as folder.json to distinguish folders from notebooks (which use manifest.json).
// Sendable for safe passage across actor boundaries.
struct FolderManifest: Codable, Sendable {
  // Unique identifier for this folder.
  let folderID: String

  // Display name shown to the user.
  var displayName: String

  // Format version for backward compatibility.
  let version: Int

  // Timestamp when the folder was created.
  let createdAt: Date

  // Timestamp when the folder was last modified.
  var modifiedAt: Date

  // Creates a new FolderManifest with the given folder ID and display name.
  // Sets version to current and records creation timestamp.
  init(folderID: String, displayName: String) {
    self.folderID = folderID
    self.displayName = displayName
    self.version = FolderManifestVersion.current
    let now = Date()
    self.createdAt = now
    self.modifiedAt = now
  }
}

// MARK: - FolderMetadata

// Represents a Folder in the list returned by the Bundle Manager.
// Contains only the metadata needed to display the Folder in the Dashboard.
// Sendable so it can be passed across actor boundaries.
struct FolderMetadata: Identifiable, Sendable {
  // Unique identifier for this Folder.
  let id: String

  // Display name shown to the user.
  let displayName: String

  // Cached preview image data from up to 4 contained items (notebooks and PDFs).
  // Empty array if folder contains no items or items have no previews.
  let previewImages: [Data]

  // Number of notebooks contained in this folder.
  let notebookCount: Int

  // Number of PDF documents contained in this folder.
  let pdfCount: Int

  // Total number of items (notebooks + PDFs) in this folder.
  var itemCount: Int {
    notebookCount + pdfCount
  }

  // Timestamp when the folder was last modified.
  let modifiedAt: Date
}

// MARK: - FolderBundleError

// Extended error cases for folder operations.
// These errors are specific to folder management and complement the existing BundleError.
enum FolderBundleError: LocalizedError, Equatable {
  case folderNotFound(folderID: String)
  case folderManifestNotFound(folderID: String)
  case folderManifestDecodingFailed(folderID: String, underlyingError: String)
  case unsupportedFolderManifestVersion(folderID: String, version: Int)
  case invalidFolderManifest(folderID: String, reason: String)
  case notebookAlreadyInFolder(notebookID: String, folderID: String)
  case notebookNotInFolder(notebookID: String)

  var errorDescription: String? {
    switch self {
    case .folderNotFound(let folderID):
      return "Folder not found: \(folderID)"
    case .folderManifestNotFound(let folderID):
      return "Folder manifest not found in: \(folderID)"
    case .folderManifestDecodingFailed(let folderID, let underlyingError):
      return "Failed to decode folder manifest in \(folderID): \(underlyingError)"
    case .unsupportedFolderManifestVersion(let folderID, let version):
      return "Unsupported folder manifest version \(version) in: \(folderID)"
    case .invalidFolderManifest(let folderID, let reason):
      return "Invalid folder manifest in \(folderID): \(reason)"
    case .notebookAlreadyInFolder(let notebookID, let folderID):
      return "Notebook \(notebookID) is already in folder \(folderID)"
    case .notebookNotInFolder(let notebookID):
      return "Notebook \(notebookID) is not in any folder"
    }
  }

  static func == (lhs: FolderBundleError, rhs: FolderBundleError) -> Bool {
    switch (lhs, rhs) {
    case (.folderNotFound(let lhsID), .folderNotFound(let rhsID)):
      return lhsID == rhsID
    case (.folderManifestNotFound(let lhsID), .folderManifestNotFound(let rhsID)):
      return lhsID == rhsID
    case (
      .folderManifestDecodingFailed(let lhsID, let lhsError),
      .folderManifestDecodingFailed(let rhsID, let rhsError)
    ):
      return lhsID == rhsID && lhsError == rhsError
    case (
      .unsupportedFolderManifestVersion(let lhsID, let lhsVersion),
      .unsupportedFolderManifestVersion(let rhsID, let rhsVersion)
    ):
      return lhsID == rhsID && lhsVersion == rhsVersion
    case (
      .invalidFolderManifest(let lhsID, let lhsReason),
      .invalidFolderManifest(let rhsID, let rhsReason)
    ):
      return lhsID == rhsID && lhsReason == rhsReason
    case (
      .notebookAlreadyInFolder(let lhsNotebookID, let lhsFolderID),
      .notebookAlreadyInFolder(let rhsNotebookID, let rhsFolderID)
    ):
      return lhsNotebookID == rhsNotebookID && lhsFolderID == rhsFolderID
    case (.notebookNotInFolder(let lhsID), .notebookNotInFolder(let rhsID)):
      return lhsID == rhsID
    default:
      return false
    }
  }
}

// MARK: - FolderConstants

// File name for folder manifests.
// Used to distinguish folders from notebooks in the file system.
enum FolderConstants {
  static let folderManifestFileName = "folder.json"
  static let maxPreviewImages = 4
}
