//
// NotebookValidation.swift
// InkOS
//
// Validation logic and error types for notebooks.
// Ensures notebooks are well-formed before rendering or persistence.
//

import Foundation

// MARK: - NotebookError

// Errors that can occur during notebook operations.
enum NotebookError: Error, LocalizedError, Equatable, Sendable {
  // Schema version is not supported.
  case invalidSchemaVersion(found: Int, supported: Set<Int>)

  // Topic string is empty.
  case emptyTopic

  // Notebook references itself as parent.
  case selfReferencingParent

  var errorDescription: String? {
    switch self {
    case .invalidSchemaVersion(let found, let supported):
      return "Notebook schema version \(found) is not supported. Supported: \(supported)"
    case .emptyTopic:
      return "Notebook topic cannot be empty"
    case .selfReferencingParent:
      return "Notebook cannot reference itself as parent"
    }
  }
}

// MARK: - NotebookValidator Protocol

// Protocol for notebook validation.
protocol NotebookValidator: Sendable {
  func validate(_ notebook: Notebook) throws
}

// MARK: - DefaultNotebookValidator

// Default implementation of notebook validation.
struct DefaultNotebookValidator: NotebookValidator {

  func validate(_ notebook: Notebook) throws {
    // Validate schema version.
    guard NotebookSchemaVersion.supported.contains(notebook.metadata.schemaVersion) else {
      throw NotebookError.invalidSchemaVersion(
        found: notebook.metadata.schemaVersion,
        supported: NotebookSchemaVersion.supported
      )
    }

    // Validate topic is not empty.
    guard !notebook.topic.isEmpty else {
      throw NotebookError.emptyTopic
    }

    // Validate notebook doesn't reference itself as parent.
    if let parentId = notebook.parentId {
      guard parentId != notebook.id else {
        throw NotebookError.selfReferencingParent
      }
    }
  }
}

// MARK: - Notebook Validation Extension

extension Notebook {
  // Validates this notebook using the default validator.
  func validate() throws {
    let validator = DefaultNotebookValidator()
    try validator.validate(self)
  }

  // Returns whether this notebook is valid.
  var isValid: Bool {
    do {
      try validate()
      return true
    } catch {
      return false
    }
  }
}
