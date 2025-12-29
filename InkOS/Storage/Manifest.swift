import Foundation

// Version constants for the Manifest format.
enum ManifestVersion: Sendable {
  static let current = 1
  static let supported: Set<Int> = [1]
}

// Represents saved viewport configuration for a notebook.
// Stores scroll position and zoom level in MyScript's coordinate system.
// Coordinates are in millimeters (document space), not pixels.
struct ViewportState: Codable, Equatable, Sendable {
  // Horizontal offset in millimeters from the document origin.
  let offsetX: Float

  // Vertical offset in millimeters from the document origin.
  let offsetY: Float

  // Zoom scale factor where 1.0 equals 100 percent zoom.
  let scale: Float

  // Creates a default viewport state centered at the origin with 100 percent zoom.
  static let `default` = ViewportState(offsetX: 0, offsetY: 0, scale: 1.0)

  // Validates that viewport values are within reasonable bounds.
  // Prevents crashes from corrupted or invalid manifest data.
  func isValid() -> Bool {
    // Scale must be positive and within reasonable zoom range.
    guard scale > 0.1 && scale < 10.0 else { return false }

    // Offsets must be finite numbers (not NaN or infinity).
    guard offsetX.isFinite && offsetY.isFinite else { return false }

    return true
  }
}

// The Manifest is a JSON file inside the Bundle that describes the Notebook metadata.
// It no longer tracks individual ink items, as ink is stored in the MyScript .iink package.
// It contains only app-level metadata like title and timestamps.
// @unchecked Sendable bypasses strict checking that conflicts with actor isolation inference.
struct Manifest: Codable, @unchecked Sendable {
  // Unique identifier for this Notebook.
  let notebookID: String

  // Display name shown to the user.
  var displayName: String

  // Format version for backward compatibility.
  let version: Int

  // Timestamp when the notebook was created.
  let createdAt: Date

  // Timestamp when the notebook was last modified.
  var modifiedAt: Date

  // Timestamp when the notebook was last accessed.
  var lastAccessedAt: Date?

  // Optional viewport state preserving scroll position and zoom level.
  // Nil means use default positioning when opening the notebook.
  var viewportState: ViewportState?

  // Creates a new Manifest with the given notebook ID and display name.
  // Sets version and records creation timestamp.
  init(notebookID: String, displayName: String) {
    self.notebookID = notebookID
    self.displayName = displayName
    self.version = ManifestVersion.current
    let now = Date()
    self.createdAt = now
    self.modifiedAt = now
    self.lastAccessedAt = now
    self.viewportState = nil
  }
}

// Explicit Codable conformance methods.
extension Manifest {
  private enum CodingKeys: String, CodingKey {
    case notebookID
    case displayName
    case version
    case createdAt
    case modifiedAt
    case lastAccessedAt
    case viewportState
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.notebookID = try container.decode(String.self, forKey: .notebookID)
    self.displayName = try container.decode(String.self, forKey: .displayName)
    self.version = try container.decode(Int.self, forKey: .version)
    self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    self.modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    self.lastAccessedAt = try container.decodeIfPresent(Date.self, forKey: .lastAccessedAt)
    self.viewportState = try container.decodeIfPresent(ViewportState.self, forKey: .viewportState)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(notebookID, forKey: .notebookID)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(version, forKey: .version)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(modifiedAt, forKey: .modifiedAt)
    try container.encodeIfPresent(lastAccessedAt, forKey: .lastAccessedAt)
    try container.encodeIfPresent(viewportState, forKey: .viewportState)
  }
}
