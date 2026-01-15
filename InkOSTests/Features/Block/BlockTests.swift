//
// BlockTests.swift
// InkOSTests
//
// Tests for the Block primitive and related types.
//

import XCTest

@testable import InkOS

final class BlockTests: XCTestCase {

  // MARK: - BlockID Tests

  func testBlockIDGeneratesUniqueIDs() {
    let id1 = BlockID()
    let id2 = BlockID()
    XCTAssertNotEqual(id1, id2)
  }

  func testBlockIDInitWithString() {
    let id = BlockID("test-id")
    XCTAssertEqual(id.rawValue, "test-id")
    XCTAssertEqual(id.description, "test-id")
  }

  func testBlockIDCodable() throws {
    let original = BlockID("test-block-id")
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let data = try encoder.encode(original)
    let decoded = try decoder.decode(BlockID.self, from: data)

    XCTAssertEqual(original, decoded)
  }

  // MARK: - BlockType Tests

  func testBlockTypeAllCases() {
    let allTypes = BlockType.allCases
    XCTAssertEqual(allTypes.count, 6)
    XCTAssertTrue(allTypes.contains(.text))
    XCTAssertTrue(allTypes.contains(.image))
    XCTAssertTrue(allTypes.contains(.graphics))
    XCTAssertTrue(allTypes.contains(.table))
    XCTAssertTrue(allTypes.contains(.embed))
    XCTAssertTrue(allTypes.contains(.input))
  }

  func testBlockTypeCodable() throws {
    let types: [BlockType] = [.text, .image, .graphics, .table, .embed, .input]
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for type in types {
      let data = try encoder.encode(type)
      let decoded = try decoder.decode(BlockType.self, from: data)
      XCTAssertEqual(type, decoded)
    }
  }

  // MARK: - BlockStatus Tests

  func testBlockStatusCodable() throws {
    let statuses: [BlockStatus] = [.pending, .ready, .rendered, .hidden]
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for status in statuses {
      let data = try encoder.encode(status)
      let decoded = try decoder.decode(BlockStatus.self, from: data)
      XCTAssertEqual(status, decoded)
    }
  }

  // MARK: - Block Creation Tests

  func testBlockTextCreation() {
    let content = TextContent.plain("Hello, world!")
    let block = Block.text(content: content)

    XCTAssertEqual(block.type, .text)
    XCTAssertEqual(block.status, .ready)
    XCTAssertNotNil(block.content.textContent)
    XCTAssertEqual(block.content.textContent?.segments.count, 1)
  }

  func testBlockImageCreation() {
    let content = ImageContent.url("https://example.com/image.png", altText: "Example image")
    let block = Block.image(content: content)

    XCTAssertEqual(block.type, .image)
    XCTAssertNotNil(block.content.imageContent)
    XCTAssertEqual(block.content.imageContent?.altText, "Example image")
  }

  func testBlockInputCreation() {
    let content = InputContent.text(prompt: "Enter your name:", placeholder: "Name")
    let block = Block.input(content: content)

    XCTAssertEqual(block.type, .input)
    XCTAssertNotNil(block.content.inputContent)
    XCTAssertEqual(block.content.inputContent?.prompt, "Enter your name:")
  }

  // MARK: - Block Codable Tests

  func testBlockTextCodable() throws {
    let content = TextContent(segments: [
      .plain(text: "The quadratic formula is:"),
      .latex(latex: "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}", displayMode: true),
    ])
    let block = Block.text(content: content)

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    XCTAssertEqual(block.id, decoded.id)
    XCTAssertEqual(block.type, decoded.type)
    XCTAssertEqual(block.status, decoded.status)
    XCTAssertEqual(block.content, decoded.content)
  }

  func testBlockImageCodable() throws {
    let content = ImageContent(
      source: .library(libraryId: "openstax_bio_001"),
      altText: "Cell diagram",
      caption: "Structure of a cell",
      attribution: ImageAttribution(source: "OpenStax", license: "CC BY 4.0")
    )
    let block = Block.image(content: content)

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    XCTAssertEqual(block.type, decoded.type)
    XCTAssertEqual(block.content, decoded.content)
  }

  func testBlockTableCodable() throws {
    let content = TableContent(
      columns: [
        TableColumn(id: "name", header: "Name"),
        TableColumn(id: "value", header: "Value", dataType: .number),
      ],
      rows: [
        TableRow(cells: ["name": .string("Alpha"), "value": .number(1.0)]),
        TableRow(cells: ["name": .string("Beta"), "value": .number(2.0)]),
      ]
    )
    let block = Block.table(content: content)

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    XCTAssertEqual(block.type, decoded.type)
    XCTAssertEqual(block.content.tableContent?.columns.count, 2)
    XCTAssertEqual(block.content.tableContent?.rows.count, 2)
  }

  func testBlockInputCodable() throws {
    let content = InputContent.multipleChoice(
      prompt: "What is 2 + 2?",
      options: [
        ChoiceOption(id: "a", text: "3"),
        ChoiceOption(id: "b", text: "4", correct: true),
        ChoiceOption(id: "c", text: "5"),
      ]
    )
    let block = Block.input(content: content)

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    XCTAssertEqual(block.type, decoded.type)
    XCTAssertEqual(block.content.inputContent?.inputType, .multipleChoice)
    XCTAssertEqual(block.content.inputContent?.prompt, "What is 2 + 2?")
  }

  // MARK: - JSON String Tests

  func testBlockToJSONString() throws {
    let block = Block.text(content: TextContent.plain("Test"))

    let jsonString = try block.toJSONString()
    XCTAssertTrue(jsonString.contains("\"type\" : \"text\""))

    let decoded = try Block.fromJSONString(jsonString)
    XCTAssertEqual(block.id, decoded.id)
  }

  // MARK: - Block Array Tests

  func testBlockArrayCodable() throws {
    let blocks = [
      Block.text(content: TextContent.plain("First")),
      Block.text(content: TextContent.plain("Second")),
      Block.image(content: ImageContent.url("https://example.com/img.png")),
    ]

    let data = try blocks.toJSONData()
    let decoded = try [Block].fromJSONData(data)

    XCTAssertEqual(blocks.count, decoded.count)
    for (original, decodedBlock) in zip(blocks, decoded) {
      XCTAssertEqual(original.id, decodedBlock.id)
      XCTAssertEqual(original.type, decodedBlock.type)
    }
  }
}
