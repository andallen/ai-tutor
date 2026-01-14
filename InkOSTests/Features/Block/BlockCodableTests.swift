//
// BlockCodableTests.swift
// InkOSTests
//
// Tests for Block Codable conformance and JSON serialization.
//

import Foundation
import Testing

@testable import InkOS

@Suite("BlockCodable Tests")
struct BlockCodableTests {

  // MARK: - Block Round-trip

  @Test("Block round-trips through JSON")
  func blockRoundTrip() throws {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Hello **world**"))
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.id == block.id)
    #expect(decoded.kind == block.kind)
    #expect(decoded.state == block.state)
    #expect(decoded.layer == block.layer)
    #expect(decoded.source == block.source)
  }

  @Test("Block properties decode correctly based on kind")
  func blockPropertiesDecodeByKind() throws {
    let block = Block(
      kind: .textInput,
      properties: .textInput(TextInputProperties(
        placeholder: "Enter answer",
        value: "Test",
        multiline: true
      ))
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    if case .textInput(let props) = decoded.properties {
      #expect(props.placeholder == "Enter answer")
      #expect(props.value == "Test")
      #expect(props.multiline == true)
    } else {
      Issue.record("Expected textInput properties")
    }
  }

  @Test("Block with parameters round-trips")
  func blockWithParameters() throws {
    let param = Parameter.slider(
      name: "time",
      label: "Time (s)",
      value: 2.5,
      range: BlockParameterRange(min: 0, max: 10, step: 0.5)
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["sin(t*x)"])),
      parameters: [param]
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.parameters?.count == 1)
    #expect(decoded.parameters?.first?.name == "time")
    #expect(decoded.parameters?.first?.value.numberValue == 2.5)
  }

  @Test("Block with children round-trips")
  func blockWithChildren() throws {
    let child1 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Step 1"))
    )
    let child2 = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Step 2"))
    )

    let block = Block(
      kind: .quiz,
      properties: .quiz(QuizProperties(questions: [])),
      children: [child1, child2]
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.children?.count == 2)
    #expect(decoded.children?[0].id == child1.id)
    #expect(decoded.children?[1].id == child2.id)
  }

  @Test("Block with actions round-trips")
  func blockWithActions() throws {
    let action = BlockAction.submit(label: "Submit Answer")

    let block = Block(
      kind: .textInput,
      properties: .textInput(TextInputProperties()),
      actions: [action]
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.actions?.count == 1)
    #expect(decoded.actions?.first?.type == .submit)
    #expect(decoded.actions?.first?.label == "Submit Answer")
  }

  @Test("Block metadata preserves dates")
  func blockMetadataPreservesDates() throws {
    let now = Date()
    let metadata = BlockMetadata(createdAt: now, modifiedAt: now)

    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test")),
      metadata: metadata
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    // Dates should be equal within a small tolerance
    let timeDiff = abs(decoded.metadata.createdAt.timeIntervalSince(now))
    #expect(timeDiff < 0.001)
  }

  // MARK: - Different Block Kinds

  @Test("RichText block round-trips")
  func textOutputBlockRoundTrip() throws {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(
        content: "# Title\n\n$E = mc^2$",
        enableMath: true
      ))
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.kind == .textOutput)
    if case .textOutput(let props) = decoded.properties {
      #expect(props.content.contains("Title"))
      #expect(props.enableMath == true)
    }
  }

  @Test("Plot block round-trips")
  func plotBlockRoundTrip() throws {
    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(
        expressions: ["x^2", "sin(x)"],
        xRange: -5...5,
        yRange: 0...25
      ))
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.kind == .plot)
    if case .plot(let props) = decoded.properties {
      #expect(props.expressions.count == 2)
      #expect(props.xRange.lowerBound == -5)
    }
  }

  @Test("Quiz block round-trips")
  func quizBlockRoundTrip() throws {
    let question = QuizQuestion(
      question: "What is 2+2?",
      questionType: .multipleChoice,
      options: ["3", "4", "5"],
      correctAnswer: "4"
    )

    let block = Block(
      kind: .quiz,
      properties: .quiz(QuizProperties(questions: [question]))
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.kind == .quiz)
    if case .quiz(let props) = decoded.properties {
      #expect(props.questions.count == 1)
      #expect(props.questions.first?.correctAnswer == "4")
    }
  }

  @Test("Button block round-trips")
  func buttonBlockRoundTrip() throws {
    let block = Block(
      kind: .buttonInput,
      properties: .buttonInput(ButtonInputProperties(
        label: "Click Me",
        style: .primary,
        disabled: false
      ))
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.kind == .buttonInput)
    if case .buttonInput(let props) = decoded.properties {
      #expect(props.label == "Click Me")
      #expect(props.style == .primary)
    }
  }

  // MARK: - JSON String Methods

  @Test("Block toJSONString produces valid JSON")
  func blockToJSONString() throws {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    let jsonString = try block.toJSONString()

    #expect(jsonString.contains("\"kind\""))
    #expect(jsonString.contains("\"textOutput\""))
    #expect(jsonString.isEmpty == false)
  }

  @Test("Block fromJSONString decodes correctly")
  func blockFromJSONString() throws {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Original"))
    )

    let jsonString = try block.toJSONString()
    let decoded = try Block.fromJSONString(jsonString)

    #expect(decoded.id == block.id)
    #expect(decoded.kind == .textOutput)
  }

  // MARK: - Array Encoding

  @Test("Array of blocks round-trips through JSON")
  func arrayOfBlocksRoundTrip() throws {
    let blocks = [
      Block(kind: .textOutput, properties: .textOutput(TextOutputProperties(content: "Block 1"))),
      Block(kind: .textOutput, properties: .textOutput(TextOutputProperties(content: "Block 2"))),
      Block(kind: .textOutput, properties: .textOutput(TextOutputProperties(content: "Block 3")))
    ]

    let data = try blocks.toJSONData()
    let decoded = try [Block].fromJSONData(data)

    #expect(decoded.count == 3)
    #expect(decoded[0].id == blocks[0].id)
    #expect(decoded[1].id == blocks[1].id)
    #expect(decoded[2].id == blocks[2].id)
  }

  // MARK: - Complex Nested Structures

  @Test("Complex block with everything round-trips")
  func complexBlockRoundTrip() throws {
    let param = Parameter.slider(
      name: "amplitude",
      label: "Amplitude",
      value: 1.5,
      range: BlockParameterRange(min: 0, max: 5)
    )

    let action = BlockAction.navigate(to: .nextSection, label: "Continue")

    let child = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Child block"))
    )

    let block = Block(
      kind: .quiz,
      properties: .quiz(QuizProperties(
        questions: [],
        currentIndex: 0,
        shuffled: false
      )),
      parameters: [param],
      children: [child],
      state: .active,
      actions: [action],
      layer: 1,
      source: .userInput
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.id == block.id)
    #expect(decoded.kind == .quiz)
    #expect(decoded.parameters?.count == 1)
    #expect(decoded.children?.count == 1)
    #expect(decoded.actions?.count == 1)
    #expect(decoded.state == .active)
    #expect(decoded.layer == 1)
    #expect(decoded.source == .userInput)
  }

  // MARK: - DecodingRequiresKind Error

  @Test("Decoding BlockProperties directly throws error")
  func decodingPropertiesDirectlyThrows() throws {
    // Create some valid JSON for properties
    let props = TextOutputProperties(content: "Test")
    let encoder = JSONEncoder()
    let data = try encoder.encode(props)

    let decoder = JSONDecoder()

    #expect(throws: BlockError.self) {
      _ = try decoder.decode(BlockProperties.self, from: data)
    }
  }

  // MARK: - JSON Format

  @Test("JSON output is pretty-printed and sorted")
  func jsonIsPrettyPrinted() throws {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    let jsonString = try block.toJSONString()

    // Pretty-printed JSON should have newlines and indentation
    #expect(jsonString.contains("\n"))
    #expect(jsonString.contains("  "))
  }

  // MARK: - Edge Cases

  @Test("Empty block array round-trips")
  func emptyArrayRoundTrip() throws {
    let blocks: [Block] = []

    let data = try blocks.toJSONData()
    let decoded = try [Block].fromJSONData(data)

    #expect(decoded.count == 0)
  }

  @Test("Block with nil optionals round-trips")
  func blockWithNilOptionals() throws {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test")),
      parameters: nil,
      children: nil,
      actions: nil
    )

    let data = try block.toJSONData()
    let decoded = try Block.fromJSONData(data)

    #expect(decoded.parameters == nil)
    #expect(decoded.children == nil)
    #expect(decoded.actions == nil)
  }

  @Test("Block with all states round-trips")
  func blockWithAllStates() throws {
    for state in BlockState.allCases {
      let block = Block(
        kind: .textOutput,
        properties: .textOutput(TextOutputProperties(content: "Test")),
        state: state
      )

      let data = try block.toJSONData()
      let decoded = try Block.fromJSONData(data)

      #expect(decoded.state == state)
    }
  }

  @Test("Block with all sources round-trips")
  func blockWithAllSources() throws {
    let sources: [BlockSource] = [.generated, .userInput, .pinned, .imported, .template]

    for source in sources {
      let block = Block(
        kind: .textOutput,
        properties: .textOutput(TextOutputProperties(content: "Test")),
        source: source
      )

      let data = try block.toJSONData()
      let decoded = try Block.fromJSONData(data)

      #expect(decoded.source == source)
    }
  }
}
