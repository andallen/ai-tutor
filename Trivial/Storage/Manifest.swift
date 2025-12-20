import CoreGraphics
import Foundation

// The Manifest is a JSON file inside the Bundle that describes what ink exists in the Notebook.
// It contains the Notebook's metadata and a list of Ink Items.
struct Manifest: Codable {
  static let currentVersion = 1
  static let supportedVersions: Set<Int> = [1]

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
    self.version = Self.currentVersion
    self.inkItems = []
  }
}

// A rectangle defining an Ink Item's position and size on the Notebook canvas.
// Uses Notebook coordinates (not screen coordinates).
struct InkRectangle: Codable, Equatable {
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
struct InkItem: Codable, Identifiable {
  // Unique identifier for this Ink Item.
  let id: String

  // The rectangular region this Ink Item occupies on the canvas.
  let rectangle: InkRectangle

  // Relative path to the payload file inside the Bundle (e.g., "ink/abc123.ink").
  let payloadPath: String
}
