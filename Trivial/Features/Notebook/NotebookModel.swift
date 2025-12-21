import Foundation

// The Notebook Model is the in-memory representation of the Notebook metadata.
// It is built by reading the Manifest when the Notebook is opened.
// Ink content is stored in the MyScript iink package, not in this model.
struct NotebookModel {
  // Unique identifier for this Notebook.
  let notebookID: String

  // Display name shown to the user.
  var displayName: String

  // Version number of the Manifest format this Notebook uses.
  let version: Int

  // Timestamp when the notebook was created.
  let createdAt: Date

  // Timestamp when the notebook was last modified.
  var modifiedAt: Date

  // Creates a new Notebook Model from a Manifest.
  // This is how the editor builds the in-memory representation when opening a Notebook.
  init(from manifest: Manifest) {
    self.notebookID = manifest.notebookID
    self.displayName = manifest.displayName
    self.version = manifest.version
    self.createdAt = manifest.createdAt
    self.modifiedAt = manifest.modifiedAt
  }
}
