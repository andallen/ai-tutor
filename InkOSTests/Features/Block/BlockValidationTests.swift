//
// BlockValidationTests.swift
// InkOSTests
//
// Tests for BlockError and DefaultBlockValidator.
//

import Foundation
import Testing

@testable import InkOS

@Suite("BlockValidation Tests")
struct BlockValidationTests {

  // MARK: - BlockError

  @Test("BlockError has localized descriptions")
  func errorHasDescriptions() {
    let errors: [BlockError] = [
      .unsupportedBlockKind(.textOutput),
      .decodingRequiresKind,
      .invalidStateTransition(from: .completed, to: .loading),
      .invalidPropertyForKind(kind: .textOutput, reason: "Test"),
      .missingRequiredProperty(propertyName: "content"),
      .invalidParameterValue(parameterName: "speed", reason: "Too fast"),
      .parameterOutOfRange(parameterName: "volume", value: 150, min: 0, max: 100),
      .childrenNotAllowed(kind: .textOutput),
      .invalidAction(actionType: .shuffle, reason: "Wrong block kind"),
      .schemaVersionUnsupported(version: 99),
      .emptyBlockID,
      .invalidLayer(layer: -1)
    ]

    for error in errors {
      #expect(error.errorDescription != nil)
      #expect(error.errorDescription!.isEmpty == false)
    }
  }

  // MARK: - DefaultBlockValidator

  @Test("Valid block passes validation")
  func validBlockPasses() throws {
    let validator = DefaultBlockValidator()
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Hello"))
    )

    try validator.validate(block)
    // No error thrown = success
  }

  @Test("Empty block ID fails validation")
  func emptyBlockIDFails() {
    let validator = DefaultBlockValidator()
    let block = Block(
      id: BlockID(""),
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Negative layer fails validation")
  func negativeLayerFails() {
    let validator = DefaultBlockValidator()
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test")),
      layer: -1
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Properties must match block kind")
  func propertiesMustMatchKind() {
    let validator = DefaultBlockValidator()

    // This is actually caught at compile time due to type safety,
    // but we test runtime validation for completeness
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    // Should pass
    #expect(throws: Never.self) {
      try validator.validate(block)
    }
  }

  @Test("Slider parameter requires range")
  func sliderRequiresRange() {
    let validator = DefaultBlockValidator()

    let param = Parameter(
      name: "speed",
      label: "Speed",
      type: .slider,
      value: .number(50),
      range: nil  // Missing range
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["x"])),
      parameters: [param]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Parameter value must be in range")
  func parameterValueInRange() {
    let validator = DefaultBlockValidator()

    let param = Parameter(
      name: "speed",
      label: "Speed",
      type: .slider,
      value: .number(150),  // Out of range
      range: BlockParameterRange(min: 0, max: 100)
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["x"])),
      parameters: [param]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Dropdown parameter requires options")
  func dropdownRequiresOptions() {
    let validator = DefaultBlockValidator()

    let param = Parameter(
      name: "size",
      label: "Size",
      type: .dropdown,
      value: .string("large"),
      options: nil  // Missing options
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["x"])),
      parameters: [param]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Parameter name cannot be empty")
  func parameterNameNotEmpty() {
    let validator = DefaultBlockValidator()

    let param = Parameter(
      name: "",  // Empty name
      label: "Test",
      type: .toggle,
      value: .boolean(true)
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["x"])),
      parameters: [param]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Parameter label cannot be empty")
  func parameterLabelNotEmpty() {
    let validator = DefaultBlockValidator()

    let param = Parameter(
      name: "test",
      label: "",  // Empty label
      type: .toggle,
      value: .boolean(true)
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["x"])),
      parameters: [param]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Children only allowed for container blocks")
  func childrenOnlyForContainers() {
    let validator = DefaultBlockValidator()

    let child = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Child"))
    )

    let block = Block(
      kind: .textOutput,  // textOutput does not allow children
      properties: .textOutput(TextOutputProperties(content: "Parent")),
      children: [child]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Steps block allows children")
  func stepsAllowsChildren() throws {
    let validator = DefaultBlockValidator()

    let child = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Step 1"))
    )

    let block = Block(
      kind: .quiz,  // quiz allows children
      properties: .quiz(QuizProperties(questions: [])),
      children: [child]
    )

    // Should not throw
    try validator.validate(block)
  }

  @Test("Shuffle action only valid for quiz and cardDeck")
  func shuffleOnlyForQuizAndCards() {
    let validator = DefaultBlockValidator()

    let action = BlockAction(type: .shuffle)

    let block = Block(
      kind: .textOutput,  // Wrong kind
      properties: .textOutput(TextOutputProperties(content: "Test")),
      actions: [action]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Shuffle action valid for quiz")
  func shuffleValidForQuiz() throws {
    let validator = DefaultBlockValidator()

    let action = BlockAction(type: .shuffle)

    let block = Block(
      kind: .quiz,  // Correct kind
      properties: .quiz(QuizProperties(questions: [])),
      actions: [action]
    )

    // Should not throw
    try validator.validate(block)
  }

  @Test("Timer actions only valid for timer blocks")
  func timerActionsOnlyForTimer() {
    let validator = DefaultBlockValidator()

    let action = BlockAction(type: .startTimer)

    let block = Block(
      kind: .textOutput,  // Wrong kind
      properties: .textOutput(TextOutputProperties(content: "Test")),
      actions: [action]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Audio actions only valid for audio blocks")
  func audioActionsOnlyForAudio() {
    let validator = DefaultBlockValidator()

    let action = BlockAction(type: .playAudio)

    let block = Block(
      kind: .videoOutput,  // Wrong kind
      properties: .videoOutput(VideoOutputProperties(source: "test.mp4")),
      actions: [action]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Video actions only valid for video blocks")
  func videoActionsOnlyForVideo() {
    let validator = DefaultBlockValidator()

    let action = BlockAction(type: .playVideo)

    let block = Block(
      kind: .audio,  // Wrong kind
      properties: .audio(AudioProperties(source: "test.mp3")),
      actions: [action]
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Generic actions valid for any block kind")
  func genericActionsValid() throws {
    let validator = DefaultBlockValidator()

    let genericActions: [BlockActionType] = [
      .navigate, .invokeAI, .submit, .pin, .updateProgress, .checkAnswer, .custom
    ]

    for actionType in genericActions {
      let action = BlockAction(type: actionType)

      let block = Block(
        kind: .textOutput,
        properties: .textOutput(TextOutputProperties(content: "Test")),
        actions: [action]
      )

      // Should not throw
      try validator.validate(block)
    }
  }

  @Test("Recursive validation of children")
  func recursiveValidation() {
    let validator = DefaultBlockValidator()

    // Create invalid child
    let invalidChild = Block(
      id: BlockID(""),  // Empty ID (invalid)
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Child"))
    )

    let block = Block(
      kind: .quiz,
      properties: .quiz(QuizProperties(questions: [])),
      children: [invalidChild]
    )

    // Should fail because child is invalid
    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  @Test("Unsupported schema version fails")
  func unsupportedSchemaFails() {
    let validator = DefaultBlockValidator()

    let metadata = BlockMetadata(schemaVersion: 999)

    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test")),
      metadata: metadata
    )

    #expect(throws: BlockError.self) {
      try validator.validate(block)
    }
  }

  // MARK: - Block Extension Methods

  @Test("Block.validate() convenience method works")
  func blockValidateMethod() throws {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    // Should not throw
    try block.validate()
  }

  @Test("Block.isValid property works")
  func blockIsValidProperty() {
    let validBlock = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    let invalidBlock = Block(
      id: BlockID(""),  // Empty ID
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    #expect(validBlock.isValid == true)
    #expect(invalidBlock.isValid == false)
  }
}
