import Foundation

// The Notebook Model is the in-memory representation of what is inside the Notebook.
// It is built by reading the Manifest when the Notebook is opened.
// It contains a list of ink "chunks" that exist and the basic information needed to render them.
struct NotebookModel {
  // Unique identifier for this Notebook.
  let notebookID: String

  // Display name shown to the user.
  var displayName: String

  // Version number of the Manifest format this Notebook uses.
  let version: Int

  // List of Ink Items in this Notebook.
  // Each Ink Item represents one chunk of ink content.
  // Empty initially, will be populated as ink is added.
  var inkItems: [InkItem]

  // Creates a new Notebook Model from a Manifest.
  // This is how the editor builds the in-memory representation when opening a Notebook.
  init(from manifest: Manifest) {
    self.notebookID = manifest.notebookID
    self.displayName = manifest.displayName
    self.version = manifest.version
    self.inkItems = manifest.inkItems
  }

  // Returns the ID of the first (and currently only) ink item, if one exists.
  // For the single-item milestone, the entire drawing is stored as one ink item.
  var primaryInkItemID: String? {
    inkItems.first?.id
  }

  // Returns true if this Notebook has any ink content.
  var hasInkContent: Bool {
    !inkItems.isEmpty
  }
}
