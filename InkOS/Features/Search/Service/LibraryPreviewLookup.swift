import Foundation

// Implements PreviewLookupProtocol using NotebookLibrary to resolve document IDs to preview images.
// Used by SearchService to enrich search results with preview thumbnails.
// The preview data comes from the same source as dashboard cards, ensuring visual consistency.
actor LibraryPreviewLookup: PreviewLookupProtocol {
  // The NotebookLibrary instance to query for preview data.
  private let library: NotebookLibrary

  // Creates a lookup backed by the given NotebookLibrary.
  init(library: NotebookLibrary) {
    self.library = library
  }

  // Resolves a document ID to its preview image data.
  // Returns the same preview data used in dashboard cards.
  // Returns nil if the document is not found or has no preview.
  func getPreviewImageData(documentID: String, documentType: DocumentType) async -> Data? {
    // Access main actor isolated properties on the main actor.
    return await MainActor.run {
      switch documentType {
      case .notebook:
        // Find notebook in library and return its preview data.
        return library.notebooks.first(where: { $0.id == documentID })?.previewImageData
      case .pdf:
        // Find PDF document in library and return its preview data.
        return library.pdfDocuments.first(where: { $0.id == documentID })?.previewImageData
      case .lesson:
        // Find lesson in library and return its preview data.
        return library.lessons.first(where: { $0.id == documentID })?.previewImage
      case .folder:
        // Folders don't have preview images.
        return nil
      }
    }
  }
}
