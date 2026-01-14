//
// NotebookValidationTests.swift
// InkOSTests
//
// Tests for NotebookError and DefaultNotebookValidator.
//

import Foundation
import Testing

@testable import InkOS

@Suite("NotebookValidation Tests")
struct NotebookValidationTests {

  // MARK: - NotebookError

  @Test("NotebookError has localized descriptions")
  func errorHasDescriptions() {
    let errors: [NotebookError] = [
      .invalidSchemaVersion(found: 99, supported: [1]),
      .emptyTopic,
      .selfReferencingParent
    ]

    for error in errors {
      #expect(error.errorDescription != nil)
      #expect(error.errorDescription!.isEmpty == false)
    }
  }

  @Test("NotebookError cases are equatable")
  func errorCasesEquatable() {
    #expect(NotebookError.emptyTopic == NotebookError.emptyTopic)
    #expect(NotebookError.selfReferencingParent == NotebookError.selfReferencingParent)
    #expect(
      NotebookError.invalidSchemaVersion(found: 1, supported: [1])
        == NotebookError.invalidSchemaVersion(found: 1, supported: [1])
    )
  }

  // MARK: - DefaultNotebookValidator

  @Test("Valid notebook passes validation")
  func validNotebookPasses() throws {
    let validator = DefaultNotebookValidator()
    let notebook = Notebook(topic: "Algebra")

    try validator.validate(notebook)
    // No error thrown = success
  }

  @Test("Empty topic fails validation")
  func emptyTopicFails() {
    let validator = DefaultNotebookValidator()
    let notebook = Notebook(topic: "")

    #expect(throws: NotebookError.self) {
      try validator.validate(notebook)
    }
  }

  @Test("Empty topic throws correct error")
  func emptyTopicThrowsCorrectError() throws {
    let validator = DefaultNotebookValidator()
    let notebook = Notebook(topic: "")

    do {
      try validator.validate(notebook)
      Issue.record("Expected error to be thrown")
    } catch let error as NotebookError {
      #expect(error == .emptyTopic)
    }
  }

  @Test("Self-referencing parent fails validation")
  func selfReferencingParentFails() {
    let validator = DefaultNotebookValidator()
    let id = NotebookID()
    let notebook = Notebook(id: id, topic: "Test", parentId: id)

    #expect(throws: NotebookError.self) {
      try validator.validate(notebook)
    }
  }

  @Test("Self-referencing parent throws correct error")
  func selfReferencingParentThrowsCorrectError() throws {
    let validator = DefaultNotebookValidator()
    let id = NotebookID()
    let notebook = Notebook(id: id, topic: "Test", parentId: id)

    do {
      try validator.validate(notebook)
      Issue.record("Expected error to be thrown")
    } catch let error as NotebookError {
      #expect(error == .selfReferencingParent)
    }
  }

  @Test("Unsupported schema version fails validation")
  func unsupportedSchemaVersionFails() {
    let validator = DefaultNotebookValidator()
    let metadata = NotebookMeta(schemaVersion: 999)
    let notebook = Notebook(topic: "Test", metadata: metadata)

    #expect(throws: NotebookError.self) {
      try validator.validate(notebook)
    }
  }

  @Test("Unsupported schema version throws correct error")
  func unsupportedSchemaVersionThrowsCorrectError() throws {
    let validator = DefaultNotebookValidator()
    let metadata = NotebookMeta(schemaVersion: 999)
    let notebook = Notebook(topic: "Test", metadata: metadata)

    do {
      try validator.validate(notebook)
      Issue.record("Expected error to be thrown")
    } catch let error as NotebookError {
      if case .invalidSchemaVersion(let found, _) = error {
        #expect(found == 999)
      } else {
        Issue.record("Wrong error type: \(error)")
      }
    }
  }

  @Test("Notebook with valid parent ID passes validation")
  func validParentIdPasses() throws {
    let validator = DefaultNotebookValidator()
    let parentId = NotebookID()
    let notebook = Notebook(topic: "Child Topic", parentId: parentId)

    // Should not throw since parentId is different from notebook's own id
    try validator.validate(notebook)
  }

  @Test("Notebook with blocks passes validation")
  func notebookWithBlocksPasses() throws {
    let validator = DefaultNotebookValidator()
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Hello"))
    )
    let notebook = Notebook(topic: "Test", blocks: [block])

    try validator.validate(notebook)
  }

  // MARK: - Notebook Extension Methods

  @Test("Notebook.validate() convenience method works")
  func notebookValidateMethod() throws {
    let notebook = Notebook(topic: "Test")

    // Should not throw
    try notebook.validate()
  }

  @Test("Notebook.isValid property returns true for valid notebook")
  func notebookIsValidTrue() {
    let notebook = Notebook(topic: "Test")

    #expect(notebook.isValid == true)
  }

  @Test("Notebook.isValid property returns false for invalid notebook")
  func notebookIsValidFalse() {
    let notebook = Notebook(topic: "")

    #expect(notebook.isValid == false)
  }

  @Test("Notebook.isValid returns false for self-referencing parent")
  func notebookIsValidFalseForSelfReference() {
    let id = NotebookID()
    let notebook = Notebook(id: id, topic: "Test", parentId: id)

    #expect(notebook.isValid == false)
  }
}
