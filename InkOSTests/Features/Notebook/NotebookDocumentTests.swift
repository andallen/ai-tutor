//
// NotebookDocumentTests.swift
// InkOSTests
//
// Tests for the NotebookDocument schema.
//

import XCTest

@testable import InkOS

final class NotebookDocumentTests: XCTestCase {

  // MARK: - NotebookDocumentID Tests

  func testNotebookDocumentIDGeneratesUniqueIDs() {
    let id1 = NotebookDocumentID()
    let id2 = NotebookDocumentID()
    XCTAssertNotEqual(id1, id2)
  }

  func testNotebookDocumentIDInitWithString() {
    let id = NotebookDocumentID("test-notebook-id")
    XCTAssertEqual(id.rawValue, "test-notebook-id")
    XCTAssertEqual(id.description, "test-notebook-id")
  }

  func testNotebookDocumentIDCodable() throws {
    let original = NotebookDocumentID("test-id")
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NotebookDocumentID.self, from: data)

    XCTAssertEqual(original, decoded)
  }

  // MARK: - NotebookDocument Creation Tests

  func testNotebookDocumentDefaultInit() {
    let doc = NotebookDocument()

    XCTAssertEqual(doc.version, 1)
    XCTAssertNil(doc.sessionId)
    XCTAssertNil(doc.title)
    XCTAssertTrue(doc.blocks.isEmpty)
  }

  func testNotebookDocumentWithBlocks() {
    let blocks = [
      Block.text(content: TextContent.plain("Hello")),
      Block.text(content: TextContent.plain("World")),
    ]
    let doc = NotebookDocument(title: "Test Notebook", blocks: blocks)

    XCTAssertEqual(doc.title, "Test Notebook")
    XCTAssertEqual(doc.blocks.count, 2)
  }

  // MARK: - NotebookDocument Mutation Tests

  func testIncrementVersion() {
    var doc = NotebookDocument()
    let initialVersion = doc.version
    let initialUpdatedAt = doc.updatedAt

    // Small delay to ensure timestamp changes.
    Thread.sleep(forTimeInterval: 0.01)
    doc.incrementVersion()

    XCTAssertEqual(doc.version, initialVersion + 1)
    XCTAssertGreaterThan(doc.updatedAt, initialUpdatedAt)
  }

  func testAppendBlock() {
    var doc = NotebookDocument()
    let block = Block.text(content: TextContent.plain("New block"))

    doc.appendBlock(block)

    XCTAssertEqual(doc.blocks.count, 1)
    XCTAssertEqual(doc.blocks[0].id, block.id)
    XCTAssertEqual(doc.version, 2)
  }

  func testInsertBlockAtIndex() {
    var doc = NotebookDocument(blocks: [
      Block.text(content: TextContent.plain("First")),
      Block.text(content: TextContent.plain("Third")),
    ])

    let middleBlock = Block.text(content: TextContent.plain("Second"))
    doc.insertBlock(middleBlock, at: 1)

    XCTAssertEqual(doc.blocks.count, 3)
    XCTAssertEqual(doc.blocks[1].id, middleBlock.id)
  }

  func testRemoveBlockAtIndex() {
    let block1 = Block.text(content: TextContent.plain("First"))
    let block2 = Block.text(content: TextContent.plain("Second"))
    var doc = NotebookDocument(blocks: [block1, block2])

    let removed = doc.removeBlock(at: 0)

    XCTAssertEqual(doc.blocks.count, 1)
    XCTAssertEqual(removed.id, block1.id)
    XCTAssertEqual(doc.blocks[0].id, block2.id)
  }

  func testUpdateBlockAtIndex() {
    let originalBlock = Block.text(content: TextContent.plain("Original"))
    var doc = NotebookDocument(blocks: [originalBlock])

    let updatedBlock = Block.text(id: originalBlock.id, content: TextContent.plain("Updated"))
    doc.updateBlock(at: 0, with: updatedBlock)

    XCTAssertEqual(doc.blocks[0].content.textContent?.segments.count, 1)
  }

  // MARK: - Block Lookup Tests

  func testBlockWithId() {
    let block1 = Block.text(content: TextContent.plain("First"))
    let block2 = Block.text(content: TextContent.plain("Second"))
    let doc = NotebookDocument(blocks: [block1, block2])

    let found = doc.block(withId: block2.id)
    XCTAssertNotNil(found)
    XCTAssertEqual(found?.id, block2.id)

    let notFound = doc.block(withId: BlockID("nonexistent"))
    XCTAssertNil(notFound)
  }

  func testIndexOfBlockWithId() {
    let block1 = Block.text(content: TextContent.plain("First"))
    let block2 = Block.text(content: TextContent.plain("Second"))
    let doc = NotebookDocument(blocks: [block1, block2])

    let index = doc.indexOfBlock(withId: block2.id)
    XCTAssertEqual(index, 1)

    let notFoundIndex = doc.indexOfBlock(withId: BlockID("nonexistent"))
    XCTAssertNil(notFoundIndex)
  }

  // MARK: - Codable Tests

  func testNotebookDocumentCodable() throws {
    let blocks = [
      Block.text(content: TextContent.plain("Test content")),
      Block.image(content: ImageContent.url("https://example.com/img.png")),
    ]
    let doc = NotebookDocument(
      sessionId: "session-123",
      title: "Math Lesson",
      blocks: blocks
    )

    let data = try doc.toJSONData()
    let decoded = try NotebookDocument.fromJSONData(data)

    XCTAssertEqual(doc.id, decoded.id)
    XCTAssertEqual(doc.version, decoded.version)
    XCTAssertEqual(doc.sessionId, decoded.sessionId)
    XCTAssertEqual(doc.title, decoded.title)
    XCTAssertEqual(doc.blocks.count, decoded.blocks.count)

    for (original, decodedBlock) in zip(doc.blocks, decoded.blocks) {
      XCTAssertEqual(original.id, decodedBlock.id)
      XCTAssertEqual(original.type, decodedBlock.type)
    }
  }

  func testNotebookDocumentJSONString() throws {
    let doc = NotebookDocument(title: "Test")

    let jsonString = try doc.toJSONString()
    XCTAssertTrue(jsonString.contains("\"title\" : \"Test\""))

    let decoded = try NotebookDocument.fromJSONString(jsonString)
    XCTAssertEqual(doc.id, decoded.id)
    XCTAssertEqual(doc.title, decoded.title)
  }

  func testNotebookDocumentDateEncoding() throws {
    let doc = NotebookDocument()

    let data = try doc.toJSONData()
    let jsonString = String(data: data, encoding: .utf8)!

    // Check that dates are encoded in ISO8601 format.
    XCTAssertTrue(jsonString.contains("created_at"))
    XCTAssertTrue(jsonString.contains("updated_at"))
  }

  // MARK: - Complex Document Tests

  func testComplexNotebookDocument() throws {
    let blocks: [Block] = [
      Block.text(content: TextContent(segments: [
        .plain(text: "Welcome to the lesson!"),
        .latex(latex: "E = mc^2", displayMode: true),
      ])),
      Block.image(content: ImageContent(
        source: .library(libraryId: "physics_energy_001"),
        caption: "Energy-mass equivalence"
      )),
      Block.input(content: InputContent.multipleChoice(
        prompt: "What does E represent?",
        options: [
          ChoiceOption(id: "a", text: "Energy", correct: true),
          ChoiceOption(id: "b", text: "Electron"),
          ChoiceOption(id: "c", text: "Earth"),
        ]
      )),
    ]

    let doc = NotebookDocument(
      sessionId: "physics-101",
      title: "Energy and Mass",
      blocks: blocks
    )

    let data = try doc.toJSONData()
    let decoded = try NotebookDocument.fromJSONData(data)

    XCTAssertEqual(decoded.blocks.count, 3)
    XCTAssertEqual(decoded.blocks[0].type, .text)
    XCTAssertEqual(decoded.blocks[1].type, .image)
    XCTAssertEqual(decoded.blocks[2].type, .input)
  }
}
