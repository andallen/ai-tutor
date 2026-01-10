// Dashboard data models.
// Contains shared types used by both SwiftUI and UIKit dashboard implementations.

import Foundation

// MARK: - PDF Dashboard Error

// Errors specific to PDF dashboard operations.
// Provides specific cases for different failure modes.
enum PDFDashboardError: LocalizedError, Equatable {
  // The PDFNotes directory could not be accessed.
  case pdfNotesDirectoryNotAccessible(underlyingError: String)

  // A specific document manifest could not be read.
  case manifestReadFailed(documentID: String, reason: String)

  // A specific document manifest could not be decoded.
  case manifestDecodeFailed(documentID: String, reason: String)

  var errorDescription: String? {
    switch self {
    case .pdfNotesDirectoryNotAccessible(let underlyingError):
      return "Could not access PDF documents directory: \(underlyingError)"
    case .manifestReadFailed(let documentID, let reason):
      return "Could not read document \(documentID): \(reason)"
    case .manifestDecodeFailed(let documentID, let reason):
      return "Could not decode document \(documentID): \(reason)"
    }
  }
}

// MARK: - PDF Document Metadata

// Lightweight struct for displaying PDF documents in the Dashboard grid.
// Contains only the information needed for listing and sorting, not editing.
// Mirrors NotebookMetadata pattern for consistency.
struct PDFDocumentMetadata: Identifiable, Sendable, Equatable {
  // Unique identifier for this PDF document.
  let id: String

  // Display name shown to the user.
  let displayName: String

  // Original filename of the imported PDF including extension.
  let sourceFileName: String

  // Timestamp when the document was created from the PDF.
  let createdAt: Date

  // Timestamp when the document was last modified.
  let modifiedAt: Date

  // Total number of pages in the PDF document.
  let pageCount: Int

  // Cached preview image data for the first page of the PDF.
  let previewImageData: Data?

  // Optional folder ID if the document is inside a folder.
  // Nil means the document is at the root level.
  let folderID: String?
}

// Utility for building PDFDocumentMetadata from NoteDocument.
enum PDFDocumentMetadataBuilder {
  // Builds PDFDocumentMetadata from a NoteDocument and optional preview data.
  static func build(
    from document: NoteDocument,
    previewImageData: Data?
  ) -> PDFDocumentMetadata {
    let pageCount = document.blocks.filter { block in
      if case .pdfPage = block { return true }
      return false
    }.count

    return PDFDocumentMetadata(
      id: document.documentID.uuidString,
      displayName: document.displayName,
      sourceFileName: document.sourceFileName,
      createdAt: document.createdAt,
      modifiedAt: document.modifiedAt,
      pageCount: pageCount,
      previewImageData: previewImageData,
      folderID: document.folderID
    )
  }
}

// MARK: - Notebook Session

// Represents an open notebook editing session.
struct NotebookSession: Identifiable {
  let id: String
  let handle: DocumentHandle
}
