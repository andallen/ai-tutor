//
// DashboardItem.swift
// InkOS
//
// Unified type for displaying notebooks and folders in the Dashboard grid.
// Allows the grid to display both item types with proper sorting.
//

import Foundation

// Represents a notebook, folder, PDF document, or lesson for display in the Dashboard grid.
// The Dashboard grid uses this type to render a mixed list of items.
enum DashboardItem: Identifiable {
  case notebook(NotebookMetadata)
  case folder(FolderMetadata)
  case pdfDocument(PDFDocumentMetadata)
  case lesson(LessonMetadata)

  // Unique identifier combining type prefix with item ID.
  // Ensures no collision between notebook, folder, PDF document, and lesson with same UUID.
  var id: String {
    switch self {
    case .notebook(let metadata):
      return "notebook-\(metadata.id)"
    case .folder(let metadata):
      return "folder-\(metadata.id)"
    case .pdfDocument(let metadata):
      return "pdf-\(metadata.id)"
    case .lesson(let metadata):
      return "lesson-\(metadata.id)"
    }
  }

  // Display name shown to the user.
  var displayName: String {
    switch self {
    case .notebook(let metadata):
      return metadata.displayName
    case .folder(let metadata):
      return metadata.displayName
    case .pdfDocument(let metadata):
      return metadata.displayName
    case .lesson(let metadata):
      return metadata.displayName
    }
  }

  // Date used for sorting items.
  // Returns lastAccessedAt for notebooks and lessons, modifiedAt for folders and PDF documents.
  var sortDate: Date? {
    switch self {
    case .notebook(let metadata):
      return metadata.lastAccessedAt
    case .folder(let metadata):
      return metadata.modifiedAt
    case .pdfDocument(let metadata):
      return metadata.modifiedAt
    case .lesson(let metadata):
      return metadata.lastAccessedAt
    }
  }

  // Returns true if this item is a folder.
  var isFolder: Bool {
    if case .folder = self {
      return true
    }
    return false
  }

  // Returns true if this item is a notebook.
  var isNotebook: Bool {
    if case .notebook = self {
      return true
    }
    return false
  }

  // Returns true if this item is a PDF document.
  var isPDFDocument: Bool {
    if case .pdfDocument = self {
      return true
    }
    return false
  }

  // Returns the notebook metadata if this is a notebook, nil otherwise.
  var notebookMetadata: NotebookMetadata? {
    if case .notebook(let metadata) = self {
      return metadata
    }
    return nil
  }

  // Returns the folder metadata if this is a folder, nil otherwise.
  var folderMetadata: FolderMetadata? {
    if case .folder(let metadata) = self {
      return metadata
    }
    return nil
  }

  // Returns the PDF document metadata if this is a PDF document, nil otherwise.
  var pdfDocumentMetadata: PDFDocumentMetadata? {
    if case .pdfDocument(let metadata) = self {
      return metadata
    }
    return nil
  }

  // Returns true if this item is a lesson.
  var isLesson: Bool {
    if case .lesson = self {
      return true
    }
    return false
  }

  // Returns the lesson metadata if this is a lesson, nil otherwise.
  var lessonMetadata: LessonMetadata? {
    if case .lesson(let metadata) = self {
      return metadata
    }
    return nil
  }
}
