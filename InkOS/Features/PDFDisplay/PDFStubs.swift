// PDFStubs.swift
// Temporary stub types for PDF functionality.
// These will be replaced when the PDF viewer is rebuilt.

import PDFKit
import SwiftUI
import UIKit

// MARK: - PDFDocumentSession

// Session data for opening a PDF document in the editor.
struct PDFDocumentSession: Identifiable {
  let id: String
  let handle: PDFDocumentHandle
  let noteDocument: NoteDocument
  let pdfDocument: PDFDocument
}

// MARK: - PDFDocumentOpenResult

// Result from opening a PDF document.
struct PDFDocumentOpenResult {
  let handle: PDFDocumentHandle
  let noteDocument: NoteDocument
  let pdfDocument: PDFDocument
  let package: any ContentPackageProtocol
}

// MARK: - PDFDocumentLifecycleError

// Errors that can occur during PDF document lifecycle operations.
enum PDFDocumentLifecycleError: LocalizedError {
  case documentDirectoryNotFound(documentID: UUID)
  case manifestNotFound(documentID: UUID)
  case manifestLoadFailed(documentID: UUID, reason: String)
  case manifestDecodingFailed(documentID: UUID, reason: String)
  case pdfNotFound(documentID: UUID)
  case pdfLoadFailed(documentID: UUID, reason: String)
  case packageOpenFailed(documentID: UUID, underlyingError: String)
  case handleCreationFailed(documentID: UUID, reason: String)
  case packageNotFound(documentID: UUID)
  case engineNotAvailable(documentID: UUID)
  case packageLoadFailed(documentID: UUID, reason: String)

  var errorDescription: String? {
    switch self {
    case .documentDirectoryNotFound(let id):
      return "Document directory not found for \(id)"
    case .manifestNotFound(let id):
      return "Manifest not found for \(id)"
    case .manifestLoadFailed(let id, let reason):
      return "Failed to load manifest for \(id): \(reason)"
    case .manifestDecodingFailed(let id, let reason):
      return "Failed to decode manifest for \(id): \(reason)"
    case .pdfNotFound(let id):
      return "PDF not found for \(id)"
    case .pdfLoadFailed(let id, let reason):
      return "Failed to load PDF for \(id): \(reason)"
    case .packageOpenFailed(let id, let error):
      return "Failed to open package for \(id): \(error)"
    case .handleCreationFailed(let id, let reason):
      return "Failed to create handle for \(id): \(reason)"
    case .packageNotFound(let id):
      return "Package not found for \(id)"
    case .engineNotAvailable(let id):
      return "Engine not available for \(id)"
    case .packageLoadFailed(let id, let reason):
      return "Failed to load package for \(id): \(reason)"
    }
  }
}

// Note: PDFEditorHostView is now implemented in PDFEditorHostView.swift
