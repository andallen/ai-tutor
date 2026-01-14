//
// BlockActionTests.swift
// InkOSTests
//
// Tests for BlockAction, ActionPayload, NavigationDestination, and ActionCondition.
//

import Foundation
import Testing

@testable import InkOS

@Suite("BlockAction Tests")
struct BlockActionTests {

  // MARK: - BlockActionType

  @Test("BlockActionType has all expected types")
  func actionTypeAllTypes() {
    let types: [BlockActionType] = [
      .navigate, .invokeAI, .submit, .pin,
      .startTimer, .stopTimer, .updateProgress,
      .checkAnswer, .shuffle,
      .playAudio, .pauseAudio, .playVideo, .pauseVideo,
      .copyToClipboard, .expand, .collapse, .custom
    ]

    for type in types {
      let action = BlockAction(type: type)
      #expect(action.type == type)
    }
  }

  // MARK: - BlockAction

  @Test("BlockAction has unique ID")
  func actionHasUniqueID() {
    let action1 = BlockAction(type: .submit)
    let action2 = BlockAction(type: .submit)

    #expect(action1.id != action2.id)
  }

  @Test("BlockAction supports optional label")
  func actionSupportsLabel() {
    let action = BlockAction(type: .submit, label: "Submit Answer")

    #expect(action.label == "Submit Answer")
  }

  @Test("BlockAction supports target block ID")
  func actionSupportsTarget() {
    let targetID = BlockID()
    let action = BlockAction(type: .navigate, targetBlockID: targetID)

    #expect(action.targetBlockID == targetID)
  }

  @Test("BlockAction supports payload")
  func actionSupportsPayload() {
    let action = BlockAction(
      type: .navigate,
      payload: .text("Next Section")
    )

    if case .text(let value) = action.payload {
      #expect(value == "Next Section")
    } else {
      Issue.record("Expected text payload")
    }
  }

  // MARK: - ActionPayload

  @Test("ActionPayload supports text")
  func payloadText() {
    let payload = ActionPayload.text("Hello")

    if case .text(let value) = payload {
      #expect(value == "Hello")
    } else {
      Issue.record("Expected text payload")
    }
  }

  @Test("ActionPayload supports number")
  func payloadNumber() {
    let payload = ActionPayload.number(42.5)

    if case .number(let value) = payload {
      #expect(value == 42.5)
    } else {
      Issue.record("Expected number payload")
    }
  }

  @Test("ActionPayload supports boolean")
  func payloadBoolean() {
    let payload = ActionPayload.boolean(true)

    if case .boolean(let value) = payload {
      #expect(value == true)
    } else {
      Issue.record("Expected boolean payload")
    }
  }

  @Test("ActionPayload supports block reference")
  func payloadBlockReference() {
    let blockID = BlockID()
    let payload = ActionPayload.blockReference(blockID)

    if case .blockReference(let id) = payload {
      #expect(id == blockID)
    } else {
      Issue.record("Expected blockReference payload")
    }
  }

  @Test("ActionPayload supports parameters")
  func payloadParameters() {
    let params = ["speed": ParameterValue.number(50)]
    let payload = ActionPayload.parameters(params)

    if case .parameters(let dict) = payload {
      #expect(dict["speed"] == .number(50))
    } else {
      Issue.record("Expected parameters payload")
    }
  }

  @Test("ActionPayload supports destination")
  func payloadDestination() {
    let dest = NavigationDestination.nextSection
    let payload = ActionPayload.destination(dest)

    if case .destination(let value) = payload {
      #expect(value == .nextSection)
    } else {
      Issue.record("Expected destination payload")
    }
  }

  @Test("ActionPayload round-trips through JSON")
  func payloadCodable() throws {
    let payloads: [ActionPayload] = [
      .text("test"),
      .number(3.14),
      .boolean(false),
      .blockReference(BlockID("test-id")),
      .destination(.nextSection)
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for payload in payloads {
      let data = try encoder.encode(payload)
      let decoded = try decoder.decode(ActionPayload.self, from: data)
      #expect(decoded == payload)
    }
  }

  // MARK: - NavigationDestination

  @Test("NavigationDestination supports block")
  func destinationBlock() {
    let blockID = BlockID()
    let dest = NavigationDestination.block(blockID)

    if case .block(let id) = dest {
      #expect(id == blockID)
    } else {
      Issue.record("Expected block destination")
    }
  }

  @Test("NavigationDestination supports section navigation")
  func destinationSections() {
    let next = NavigationDestination.nextSection
    let prev = NavigationDestination.previousSection

    #expect(next == .nextSection)
    #expect(prev == .previousSection)
  }

  @Test("NavigationDestination supports lesson")
  func destinationLesson() {
    let dest = NavigationDestination.lesson("lesson-123")

    if case .lesson(let id) = dest {
      #expect(id == "lesson-123")
    } else {
      Issue.record("Expected lesson destination")
    }
  }

  @Test("NavigationDestination supports branch")
  func destinationBranch() {
    let dest = NavigationDestination.branch("branch-456")

    if case .branch(let id) = dest {
      #expect(id == "branch-456")
    } else {
      Issue.record("Expected branch destination")
    }
  }

  @Test("NavigationDestination supports main layer")
  func destinationMainLayer() {
    let dest = NavigationDestination.mainLayer

    #expect(dest == .mainLayer)
  }

  @Test("NavigationDestination supports URL")
  func destinationURL() {
    let dest = NavigationDestination.url("https://example.com")

    if case .url(let urlString) = dest {
      #expect(urlString == "https://example.com")
    } else {
      Issue.record("Expected url destination")
    }
  }

  @Test("NavigationDestination round-trips through JSON")
  func destinationCodable() throws {
    let destinations: [NavigationDestination] = [
      .block(BlockID("test")),
      .nextSection,
      .previousSection,
      .lesson("lesson-1"),
      .branch("branch-1"),
      .mainLayer,
      .url("https://test.com")
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for dest in destinations {
      let data = try encoder.encode(dest)
      let decoded = try decoder.decode(NavigationDestination.self, from: data)
      #expect(decoded == dest)
    }
  }

  // MARK: - ActionCondition

  @Test("ActionCondition supports always and never")
  func conditionAlwaysNever() {
    let always = ActionCondition.always
    let never = ActionCondition.never

    #expect(always == .always)
    #expect(never == .never)
  }

  @Test("ActionCondition supports state equals")
  func conditionStateEquals() {
    let condition = ActionCondition.stateEquals(.active)

    if case .stateEquals(let state) = condition {
      #expect(state == .active)
    } else {
      Issue.record("Expected stateEquals condition")
    }
  }

  @Test("ActionCondition supports parameter equals")
  func conditionParameterEquals() {
    let paramID = ParameterID()
    let condition = ActionCondition.parameterEquals(paramID, .number(50))

    if case .parameterEquals(let id, let value) = condition {
      #expect(id == paramID)
      #expect(value == .number(50))
    } else {
      Issue.record("Expected parameterEquals condition")
    }
  }

  @Test("ActionCondition supports simple conditions")
  func conditionSimple() {
    let conditions: [ActionCondition] = [
      .inputNotEmpty,
      .allStepsCompleted
    ]

    for condition in conditions {
      // Just verify they exist and are equatable
      #expect(condition == condition)
    }
  }

  @Test("ActionCondition supports and combinator")
  func conditionAnd() {
    let condition = ActionCondition.and([
      .stateEquals(.active),
      .inputNotEmpty
    ])

    if case .and(let conditions) = condition {
      #expect(conditions.count == 2)
    } else {
      Issue.record("Expected and condition")
    }
  }

  @Test("ActionCondition supports or combinator")
  func conditionOr() {
    let condition = ActionCondition.or([
      .stateEquals(.completed),
      .allStepsCompleted
    ])

    if case .or(let conditions) = condition {
      #expect(conditions.count == 2)
    } else {
      Issue.record("Expected or condition")
    }
  }

  @Test("ActionCondition round-trips through JSON")
  func conditionCodable() throws {
    let conditions: [ActionCondition] = [
      .always,
      .never,
      .stateEquals(.active),
      .inputNotEmpty,
      .allStepsCompleted
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for condition in conditions {
      let data = try encoder.encode(condition)
      let decoded = try decoder.decode(ActionCondition.self, from: data)
      #expect(decoded == condition)
    }
  }

  // MARK: - Factory Methods

  @Test("BlockAction.navigate factory creates navigate action")
  func factoryNavigate() {
    let action = BlockAction.navigate(to: .nextSection, label: "Continue")

    #expect(action.type == .navigate)
    #expect(action.label == "Continue")

    if case .destination(let dest) = action.payload {
      #expect(dest == .nextSection)
    } else {
      Issue.record("Expected destination payload")
    }
  }

  @Test("BlockAction.submit factory creates submit action")
  func factorySubmit() {
    let action = BlockAction.submit(label: "Submit Answer")

    #expect(action.type == .submit)
    #expect(action.label == "Submit Answer")
  }

  @Test("BlockAction.checkAnswer factory creates check action")
  func factoryCheckAnswer() {
    let action = BlockAction.checkAnswer(label: "Check My Work")

    #expect(action.type == .checkAnswer)
    #expect(action.label == "Check My Work")
  }

  @Test("BlockAction.invokeAI factory creates AI action")
  func factoryInvokeAI() {
    let action = BlockAction.invokeAI(prompt: "Explain this concept")

    #expect(action.type == .invokeAI)

    if case .text(let prompt) = action.payload {
      #expect(prompt == "Explain this concept")
    } else {
      Issue.record("Expected text payload")
    }
  }

  // MARK: - Integration

  @Test("Action can be attached to Block")
  func actionInBlock() {
    let action = BlockAction.submit()

    let block = Block(
      kind: .textInput,
      properties: .textInput(TextInputProperties()),
      actions: [action]
    )

    #expect(block.actions?.count == 1)
    #expect(block.actions?.first?.type == .submit)
  }

  @Test("Multiple actions can be attached to Block")
  func multipleActionsInBlock() {
    let actions = [
      BlockAction.submit(label: "Submit"),
      BlockAction.checkAnswer(label: "Check"),
      BlockAction.invokeAI()
    ]

    let block = Block(
      kind: .quiz,
      properties: .quiz(QuizProperties(questions: [])),
      actions: actions
    )

    #expect(block.actions?.count == 3)
  }

  @Test("Action with condition")
  func actionWithCondition() {
    let action = BlockAction(
      type: .submit,
      label: "Submit",
      enabledCondition: .inputNotEmpty
    )

    #expect(action.enabledCondition == .inputNotEmpty)
  }
}
