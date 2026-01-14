//
// NotebookCodableTests.swift
// InkOSTests
//
// Tests for Notebook Codable conformance and JSON serialization.
//

import Foundation
import Testing

@testable import InkOS

@Suite("NotebookCodable Tests")
struct NotebookCodableTests {

  // MARK: - Notebook Round-trip

  @Test("Notebook round-trips through JSON")
  func notebookRoundTrip() throws {
    let notebook = Notebook(topic: "Algebra Basics")

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.id == notebook.id)
    #expect(decoded.topic == notebook.topic)
    #expect(decoded.parentId == notebook.parentId)
    #expect(decoded.isBranch == notebook.isBranch)
  }

  @Test("Notebook with blocks round-trips")
  func notebookWithBlocksRoundTrip() throws {
    let block1 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Hello"))
    )
    let block2 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "World"))
    )

    let notebook = Notebook(topic: "Test", blocks: [block1, block2])

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.blocks.count == 2)
    #expect(decoded.blocks[0].id == block1.id)
    #expect(decoded.blocks[1].id == block2.id)
  }

  @Test("Notebook with parent ID round-trips")
  func notebookWithParentIdRoundTrip() throws {
    let parentId = NotebookID("parent-123")
    let notebook = Notebook(topic: "Child Topic", parentId: parentId)

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.parentId == parentId)
    #expect(decoded.isBranch == true)
  }

  @Test("Standalone notebook round-trips")
  func standaloneNotebookRoundTrip() throws {
    let notebook = Notebook(topic: "Standalone", parentId: nil)

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.parentId == nil)
    #expect(decoded.isBranch == false)
  }

  @Test("Notebook metadata preserves dates")
  func notebookMetadataPreservesDates() throws {
    let now = Date()
    let metadata = NotebookMeta(createdAt: now, modifiedAt: now)

    let notebook = Notebook(topic: "Test", metadata: metadata)

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    // Dates should be equal within a small tolerance (ISO8601 has second precision)
    let timeDiff = abs(decoded.metadata.createdAt.timeIntervalSince(now))
    #expect(timeDiff < 1.0)
  }

  @Test("Notebook schema version persists")
  func notebookSchemaVersionPersists() throws {
    let metadata = NotebookMeta(schemaVersion: 1)
    let notebook = Notebook(topic: "Test", metadata: metadata)

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.metadata.schemaVersion == 1)
  }

  // MARK: - JSON String Methods

  @Test("Notebook toJSONString produces valid JSON")
  func notebookToJSONString() throws {
    let notebook = Notebook(topic: "Test Topic")

    let jsonString = try notebook.toJSONString()

    #expect(jsonString.contains("\"topic\""))
    #expect(jsonString.contains("\"Test Topic\""))
    #expect(jsonString.isEmpty == false)
  }

  @Test("Notebook fromJSONString decodes correctly")
  func notebookFromJSONString() throws {
    let notebook = Notebook(topic: "Original Topic")

    let jsonString = try notebook.toJSONString()
    let decoded = try Notebook.fromJSONString(jsonString)

    #expect(decoded.id == notebook.id)
    #expect(decoded.topic == "Original Topic")
  }

  // MARK: - Array Encoding

  @Test("Array of notebooks round-trips through JSON")
  func arrayOfNotebooksRoundTrip() throws {
    let notebooks = [
      Notebook(topic: "Topic 1"),
      Notebook(topic: "Topic 2"),
      Notebook(topic: "Topic 3")
    ]

    let data = try notebooks.toJSONData()
    let decoded = try [Notebook].fromJSONData(data)

    #expect(decoded.count == 3)
    #expect(decoded[0].id == notebooks[0].id)
    #expect(decoded[1].id == notebooks[1].id)
    #expect(decoded[2].id == notebooks[2].id)
  }

  @Test("Empty notebook array round-trips")
  func emptyArrayRoundTrip() throws {
    let notebooks: [Notebook] = []

    let data = try notebooks.toJSONData()
    let decoded = try [Notebook].fromJSONData(data)

    #expect(decoded.count == 0)
  }

  // MARK: - JSON Format

  @Test("JSON output is pretty-printed and sorted")
  func jsonIsPrettyPrinted() throws {
    let notebook = Notebook(topic: "Test")

    let jsonString = try notebook.toJSONString()

    // Pretty-printed JSON should have newlines and indentation
    #expect(jsonString.contains("\n"))
    #expect(jsonString.contains("  "))
  }

  // MARK: - NotebookID Encoding

  @Test("NotebookID encodes as plain string")
  func notebookIdEncodesAsString() throws {
    let id = NotebookID("test-id-abc")

    let encoder = JSONEncoder()
    let data = try encoder.encode(id)
    let jsonString = String(data: data, encoding: .utf8)

    #expect(jsonString == "\"test-id-abc\"")
  }

  @Test("NotebookID decodes from plain string")
  func notebookIdDecodesFromString() throws {
    let jsonData = "\"test-id-xyz\"".data(using: .utf8)!

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(NotebookID.self, from: jsonData)

    #expect(decoded.rawValue == "test-id-xyz")
  }

  // MARK: - Edge Cases

  @Test("Notebook with empty blocks array round-trips")
  func notebookWithEmptyBlocksRoundTrip() throws {
    let notebook = Notebook(topic: "Empty", blocks: [])

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.blocks.isEmpty)
  }

  @Test("Notebook with various block types round-trips")
  func notebookWithVariousBlockTypes() throws {
    let blocks: [Block] = [
      Block(kind: .textOutput, properties: .textOutput(TextOutputProperties(content: "Text"))),
      Block(kind: .textInput, properties: .textInput(TextInputProperties())),
      Block(kind: .handwritingInput, properties: .handwritingInput(HandwritingInputProperties()))
    ]

    let notebook = Notebook(topic: "Mixed Blocks", blocks: blocks)

    let data = try notebook.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.blocks.count == 3)
    #expect(decoded.blocks[0].kind == .textOutput)
    #expect(decoded.blocks[1].kind == .textInput)
    #expect(decoded.blocks[2].kind == .handwritingInput)
  }

  @Test("Branch notebook round-trips with correct parent relationship")
  func branchNotebookRoundTrip() throws {
    let parent = Notebook(topic: "Parent Topic")
    let branch = Notebook(topic: "Branch Topic", parentId: parent.id)

    let data = try branch.toJSONData()
    let decoded = try Notebook.fromJSONData(data)

    #expect(decoded.parentId == parent.id)
    #expect(decoded.isBranch == true)
  }

  @Test("Multiple notebooks with parent relationships round-trip")
  func multipleNotebooksWithRelationships() throws {
    let parent = Notebook(topic: "Parent")
    let branch1 = Notebook(topic: "Branch 1", parentId: parent.id)
    let branch2 = Notebook(topic: "Branch 2", parentId: parent.id)

    let notebooks = [parent, branch1, branch2]

    let data = try notebooks.toJSONData()
    let decoded = try [Notebook].fromJSONData(data)

    #expect(decoded.count == 3)
    #expect(decoded[0].isBranch == false)
    #expect(decoded[1].isBranch == true)
    #expect(decoded[2].isBranch == true)
    #expect(decoded[1].parentId == decoded[0].id)
    #expect(decoded[2].parentId == decoded[0].id)
  }
}
