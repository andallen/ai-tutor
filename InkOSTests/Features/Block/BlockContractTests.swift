//
// BlockContractTests.swift
// InkOSTests
//
// Tests for Block core contract types: Block, BlockID, BlockMetadata, BlockSource.
//

import Foundation
import Testing

@testable import InkOS

@Suite("Block Contract Tests")
struct BlockContractTests {

  @Test("Block creates with default values")
  func blockCreatesWithDefaults() {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Hello"))
    )

    #expect(block.state == .idle)
    #expect(block.layer == 0)
    #expect(block.source == .generated)
    #expect(block.parameters == nil)
    #expect(block.children == nil)
    #expect(block.actions == nil)
  }

  @Test("Block is identifiable with unique IDs")
  func blockIsIdentifiable() {
    let block1 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test 1"))
    )
    let block2 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test 2"))
    )

    #expect(block1.id.rawValue.isEmpty == false)
    #expect(block2.id.rawValue.isEmpty == false)
    #expect(block1.id != block2.id)
  }

  @Test("Blocks with same ID are equal")
  func blocksWithSameIDEqual() {
    let id = BlockID()
    let block1 = Block(
      id: id,
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )
    let block2 = Block(
      id: id,
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    #expect(block1 == block2)
  }

  @Test("BlockID encodes and decodes correctly")
  func blockIDCodable() throws {
    let id = BlockID()

    let encoder = JSONEncoder()
    let data = try encoder.encode(id)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(BlockID.self, from: data)

    #expect(decoded == id)
    #expect(decoded.rawValue == id.rawValue)
  }

  @Test("BlockID can be created from string")
  func blockIDFromString() {
    let idString = "test-id-123"
    let id = BlockID(idString)

    #expect(id.rawValue == idString)
    #expect(id.description == idString)
  }

  @Test("BlockMetadata has creation and modification dates")
  func blockMetadataHasDates() {
    let metadata = BlockMetadata()

    #expect(metadata.createdAt <= Date())
    #expect(metadata.modifiedAt <= Date())
    #expect(metadata.schemaVersion == BlockSchemaVersion.current)
  }

  @Test("BlockMetadata supports creator identification")
  func blockMetadataSupportsCreator() {
    let metadata = BlockMetadata(createdBy: "AI-Model-GPT4")

    #expect(metadata.createdBy == "AI-Model-GPT4")
  }

  @Test("BlockSource has all expected cases")
  func blockSourceCases() {
    let sources: [BlockSource] = [
      .generated,
      .userInput,
      .pinned,
      .imported,
      .template
    ]

    for source in sources {
      let block = Block(
        kind: .textOutput,
        properties: .textOutput(TextOutputProperties(content: "Test")),
        source: source
      )
      #expect(block.source == source)
    }
  }

  @Test("BlockSchemaVersion validates supported versions")
  func blockSchemaVersionValidation() {
    #expect(BlockSchemaVersion.current == 1)
    #expect(BlockSchemaVersion.supported.contains(1))
  }

  @Test("Block supports layer depth")
  func blockSupportsLayerDepth() {
    let layer0 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Main layer")),
      layer: 0
    )
    let layer1 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Branch layer")),
      layer: 1
    )

    #expect(layer0.layer == 0)
    #expect(layer1.layer == 1)
  }

  @Test("Block supports optional parameters")
  func blockSupportsParameters() {
    let param = Parameter(
      name: "speed",
      label: "Speed",
      type: .slider,
      value: .number(50),
      range: BlockParameterRange(min: 0, max: 100)
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["x^2"])),
      parameters: [param]
    )

    #expect(block.parameters?.count == 1)
    #expect(block.parameters?.first?.name == "speed")
  }

  @Test("Block supports child blocks")
  func blockSupportsChildren() {
    let child1 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Step 1"))
    )
    let child2 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Step 2"))
    )

    let parent = Block(
      kind: .quiz,
      properties: .quiz(QuizProperties(questions: [])),
      children: [child1, child2]
    )

    #expect(parent.children?.count == 2)
  }

  @Test("Block supports actions")
  func blockSupportsActions() {
    let action = BlockAction.submit()

    let block = Block(
      kind: .textInput,
      properties: .textInput(TextInputProperties()),
      actions: [action]
    )

    #expect(block.actions?.count == 1)
    #expect(block.actions?.first?.type == .submit)
  }
}
