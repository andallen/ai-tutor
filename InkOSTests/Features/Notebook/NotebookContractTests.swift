//
// NotebookContractTests.swift
// InkOSTests
//
// Tests for Notebook core contract types: Notebook, NotebookID, NotebookMeta.
//

import Foundation
import Testing

@testable import InkOS

@Suite("Notebook Contract Tests")
struct NotebookContractTests {

  @Test("Notebook creates with default values")
  func notebookCreatesWithDefaults() {
    let notebook = Notebook(topic: "Algebra")

    #expect(notebook.blocks.isEmpty)
    #expect(notebook.parentId == nil)
    #expect(notebook.isBranch == false)
  }

  @Test("Notebook is identifiable with unique IDs")
  func notebookIsIdentifiable() {
    let notebook1 = Notebook(topic: "Topic 1")
    let notebook2 = Notebook(topic: "Topic 2")

    #expect(notebook1.id.rawValue.isEmpty == false)
    #expect(notebook2.id.rawValue.isEmpty == false)
    #expect(notebook1.id != notebook2.id)
  }

  @Test("Notebooks with same ID are equal")
  func notebooksWithSameIDEqual() {
    let id = NotebookID()
    let notebook1 = Notebook(id: id, topic: "Test")
    let notebook2 = Notebook(id: id, topic: "Test")

    #expect(notebook1 == notebook2)
  }

  @Test("NotebookID encodes and decodes correctly")
  func notebookIDCodable() throws {
    let id = NotebookID()

    let encoder = JSONEncoder()
    let data = try encoder.encode(id)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(NotebookID.self, from: data)

    #expect(decoded == id)
    #expect(decoded.rawValue == id.rawValue)
  }

  @Test("NotebookID can be created from string")
  func notebookIDFromString() {
    let idString = "test-notebook-123"
    let id = NotebookID(idString)

    #expect(id.rawValue == idString)
    #expect(id.description == idString)
  }

  @Test("NotebookMeta has creation and modification dates")
  func notebookMetadataHasDates() {
    let metadata = NotebookMeta()

    #expect(metadata.createdAt <= Date())
    #expect(metadata.modifiedAt <= Date())
    #expect(metadata.schemaVersion == NotebookSchemaVersion.current)
  }

  @Test("NotebookSchemaVersion validates supported versions")
  func notebookSchemaVersionValidation() {
    #expect(NotebookSchemaVersion.current == 1)
    #expect(NotebookSchemaVersion.supported.contains(1))
  }

  @Test("Notebook isBranch returns false when parentId is nil")
  func notebookIsBranchFalseWhenNoParent() {
    let notebook = Notebook(topic: "Standalone", parentId: nil)

    #expect(notebook.isBranch == false)
    #expect(notebook.parentId == nil)
  }

  @Test("Notebook isBranch returns true when parentId is set")
  func notebookIsBranchTrueWhenParentSet() {
    let parentId = NotebookID()
    let notebook = Notebook(topic: "Branch", parentId: parentId)

    #expect(notebook.isBranch == true)
    #expect(notebook.parentId == parentId)
  }

  @Test("Notebook holds blocks array")
  func notebookHoldsBlocks() {
    let block1 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Hello"))
    )
    let block2 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "World"))
    )

    let notebook = Notebook(
      topic: "Test Topic",
      blocks: [block1, block2]
    )

    #expect(notebook.blocks.count == 2)
  }

  @Test("Notebook blocks can be modified")
  func notebookBlocksCanBeModified() {
    var notebook = Notebook(topic: "Test")
    #expect(notebook.blocks.isEmpty)

    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "New content"))
    )
    notebook.blocks.append(block)

    #expect(notebook.blocks.count == 1)
  }

  @Test("Notebook topic can be modified")
  func notebookTopicCanBeModified() {
    var notebook = Notebook(topic: "Original")
    #expect(notebook.topic == "Original")

    notebook.topic = "Updated"
    #expect(notebook.topic == "Updated")
  }
}
