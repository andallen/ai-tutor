import CoreGraphics
import Foundation

// Version constants for the Manifest format.
enum ManifestVersion: Sendable {
  static let current = 1
  static let supported: Set<Int> = [1]
}

// The Manifest is a JSON file inside the Bundle that describes what ink exists in the Notebook.
// It contains the Notebook's metadata and a list of Ink Items.
// @unchecked Sendable bypasses strict checking that conflicts with actor isolation inference.
struct Manifest: Codable, @unchecked Sendable {
  // Unique identifier for this Notebook.
  let notebookID: String

  // Display name shown to the user.
  var displayName: String

  // Format version for backward compatibility.
  let version: Int

  // List of Ink Items in this Notebook.
  // Empty initially, will be populated as ink is added.
  var inkItems: [InkItem]

  // Creates a new Manifest with the given notebook ID and display name.
  // Sets version and initializes an empty ink items array.
  init(notebookID: String, displayName: String) {
    self.notebookID = notebookID
    self.displayName = displayName
    self.version = ManifestVersion.current
    self.inkItems = []
  }
}

// Explicit Codable conformance methods.
extension Manifest {
  private enum CodingKeys: String, CodingKey {
    case notebookID
    case displayName
    case version
    case inkItems
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.notebookID = try container.decode(String.self, forKey: .notebookID)
    self.displayName = try container.decode(String.self, forKey: .displayName)
    self.version = try container.decode(Int.self, forKey: .version)
    self.inkItems = try container.decode([InkItem].self, forKey: .inkItems)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(notebookID, forKey: .notebookID)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(version, forKey: .version)
    try container.encode(inkItems, forKey: .inkItems)
  }
}

// A rectangle defining an Ink Item's position and size on the Notebook canvas.
// Uses Notebook coordinates (not screen coordinates).
// @unchecked Sendable bypasses strict checking that conflicts with actor isolation inference.
struct InkRectangle: Codable, Equatable, @unchecked Sendable {
  // Horizontal position of the rectangle's origin.
  let x: Double

  // Vertical position of the rectangle's origin.
  let y: Double

  // Width of the rectangle.
  let width: Double

  // Height of the rectangle.
  let height: Double

  // Creates an InkRectangle from a CGRect.
  init(from rect: CGRect) {
    self.x = Double(rect.origin.x)
    self.y = Double(rect.origin.y)
    self.width = Double(rect.size.width)
    self.height = Double(rect.size.height)
  }

  // Creates an InkRectangle with explicit values.
  init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  // Converts to CGRect for use with UIKit/CoreGraphics.
  var cgRect: CGRect {
    CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
  }
}

// An Ink Item represents one chunk of ink content in the Notebook.
// Each item has an identifier, a bounding rectangle, and a path to its payload file.
// @unchecked Sendable bypasses strict checking that conflicts with actor isolation inference.
struct InkItem: Codable, Identifiable, @unchecked Sendable {
  // Unique identifier for this Ink Item.
  let id: String

  // The rectangular region this Ink Item occupies on the canvas.
  let rectangle: InkRectangle

  // Relative path to the payload file inside the Bundle (e.g., "ink/abc123.ink").
  let payloadPath: String

  // Creates a new InkItem without requiring the main actor.
  init(id: String, rectangle: InkRectangle, payloadPath: String) {
    self.id = id
    self.rectangle = rectangle
    self.payloadPath = payloadPath
  }
}
