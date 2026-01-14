//
// BlockAction.swift
// InkOS
//
// Actions that blocks can trigger in response to user interaction.
// Actions are behaviors (navigate, submit, invoke AI) separate from
// blocks which are renderable content.
//

import Foundation

// MARK: - BlockActionType

// Types of actions blocks can trigger.
enum BlockActionType: String, Sendable, Codable, Equatable {
  // Navigate to another block, section, or lesson.
  case navigate

  // Trigger AI processing or conversation.
  case invokeAI

  // Submit user input for evaluation.
  case submit

  // Pin block to main layer (Layer 0).
  case pin

  // Start a timer block.
  case startTimer

  // Stop a timer block.
  case stopTimer

  // Update a progress indicator.
  case updateProgress

  // Check an answer for correctness.
  case checkAnswer

  // Shuffle quiz or card deck options.
  case shuffle

  // Play audio content.
  case playAudio

  // Pause audio content.
  case pauseAudio

  // Play video content.
  case playVideo

  // Pause video content.
  case pauseVideo

  // Copy content to clipboard.
  case copyToClipboard

  // Expand a collapsed block.
  case expand

  // Collapse an expanded block.
  case collapse

  // Custom action with handler.
  case custom
}

// MARK: - ActionPayload

// Payload data for actions.
// Different action types may require different payload types.
enum ActionPayload: Sendable, Equatable {
  // Simple text payload.
  case text(String)

  // Numeric payload.
  case number(Double)

  // Boolean payload.
  case boolean(Bool)

  // Reference to another block.
  case blockReference(BlockID)

  // Dictionary of parameter values.
  case parameters([String: ParameterValue])

  // Navigation destination.
  case destination(NavigationDestination)
}

// MARK: - ActionPayload Codable

extension ActionPayload: Codable {
  private enum TypeKey: String, CodingKey {
    case type
    case value
  }

  private enum PayloadType: String, Codable {
    case text
    case number
    case boolean
    case blockReference
    case parameters
    case destination
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(PayloadType.self, forKey: .type)

    switch type {
    case .text:
      let value = try container.decode(String.self, forKey: .value)
      self = .text(value)
    case .number:
      let value = try container.decode(Double.self, forKey: .value)
      self = .number(value)
    case .boolean:
      let value = try container.decode(Bool.self, forKey: .value)
      self = .boolean(value)
    case .blockReference:
      let value = try container.decode(BlockID.self, forKey: .value)
      self = .blockReference(value)
    case .parameters:
      let value = try container.decode([String: ParameterValue].self, forKey: .value)
      self = .parameters(value)
    case .destination:
      let value = try container.decode(NavigationDestination.self, forKey: .value)
      self = .destination(value)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)

    switch self {
    case .text(let value):
      try container.encode(PayloadType.text, forKey: .type)
      try container.encode(value, forKey: .value)
    case .number(let value):
      try container.encode(PayloadType.number, forKey: .type)
      try container.encode(value, forKey: .value)
    case .boolean(let value):
      try container.encode(PayloadType.boolean, forKey: .type)
      try container.encode(value, forKey: .value)
    case .blockReference(let value):
      try container.encode(PayloadType.blockReference, forKey: .type)
      try container.encode(value, forKey: .value)
    case .parameters(let value):
      try container.encode(PayloadType.parameters, forKey: .type)
      try container.encode(value, forKey: .value)
    case .destination(let value):
      try container.encode(PayloadType.destination, forKey: .type)
      try container.encode(value, forKey: .value)
    }
  }
}

// MARK: - NavigationDestination

// Destination for navigation actions.
enum NavigationDestination: Sendable, Codable, Equatable {
  // Navigate to a specific block by ID.
  case block(BlockID)

  // Navigate to the next section.
  case nextSection

  // Navigate to the previous section.
  case previousSection

  // Navigate to a specific lesson.
  case lesson(String)

  // Navigate to a branch conversation.
  case branch(String)

  // Navigate back to main layer.
  case mainLayer

  // Navigate to external URL.
  case url(String)

  private enum TypeKey: String, CodingKey {
    case type
    case value
  }

  private enum DestinationType: String, Codable {
    case block
    case nextSection
    case previousSection
    case lesson
    case branch
    case mainLayer
    case url
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(DestinationType.self, forKey: .type)

    switch type {
    case .block:
      let value = try container.decode(BlockID.self, forKey: .value)
      self = .block(value)
    case .nextSection:
      self = .nextSection
    case .previousSection:
      self = .previousSection
    case .lesson:
      let value = try container.decode(String.self, forKey: .value)
      self = .lesson(value)
    case .branch:
      let value = try container.decode(String.self, forKey: .value)
      self = .branch(value)
    case .mainLayer:
      self = .mainLayer
    case .url:
      let value = try container.decode(String.self, forKey: .value)
      self = .url(value)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)

    switch self {
    case .block(let value):
      try container.encode(DestinationType.block, forKey: .type)
      try container.encode(value, forKey: .value)
    case .nextSection:
      try container.encode(DestinationType.nextSection, forKey: .type)
    case .previousSection:
      try container.encode(DestinationType.previousSection, forKey: .type)
    case .lesson(let value):
      try container.encode(DestinationType.lesson, forKey: .type)
      try container.encode(value, forKey: .value)
    case .branch(let value):
      try container.encode(DestinationType.branch, forKey: .type)
      try container.encode(value, forKey: .value)
    case .mainLayer:
      try container.encode(DestinationType.mainLayer, forKey: .type)
    case .url(let value):
      try container.encode(DestinationType.url, forKey: .type)
      try container.encode(value, forKey: .value)
    }
  }
}

// MARK: - ActionCondition

// Conditions for action enablement.
enum ActionCondition: Sendable, Equatable {
  // Action is always enabled.
  case always

  // Action is never enabled.
  case never

  // Action is enabled when block is in specific state.
  case stateEquals(BlockState)

  // Action is enabled when parameter equals value.
  case parameterEquals(ParameterID, ParameterValue)

  // Action is enabled when input is not empty.
  case inputNotEmpty

  // Action is enabled when all steps are completed.
  case allStepsCompleted

  // All conditions must be true.
  case and([ActionCondition])

  // Any condition must be true.
  case or([ActionCondition])
}

// MARK: - ActionCondition Codable

extension ActionCondition: Codable {
  private enum TypeKey: String, CodingKey {
    case type
    case state
    case parameterId
    case parameterValue
    case conditions
  }

  private enum ConditionType: String, Codable {
    case always
    case never
    case stateEquals
    case parameterEquals
    case inputNotEmpty
    case allStepsCompleted
    case and
    case or
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(ConditionType.self, forKey: .type)

    switch type {
    case .always:
      self = .always
    case .never:
      self = .never
    case .stateEquals:
      let state = try container.decode(BlockState.self, forKey: .state)
      self = .stateEquals(state)
    case .parameterEquals:
      let paramId = try container.decode(ParameterID.self, forKey: .parameterId)
      let paramValue = try container.decode(ParameterValue.self, forKey: .parameterValue)
      self = .parameterEquals(paramId, paramValue)
    case .inputNotEmpty:
      self = .inputNotEmpty
    case .allStepsCompleted:
      self = .allStepsCompleted
    case .and:
      let conditions = try container.decode([ActionCondition].self, forKey: .conditions)
      self = .and(conditions)
    case .or:
      let conditions = try container.decode([ActionCondition].self, forKey: .conditions)
      self = .or(conditions)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)

    switch self {
    case .always:
      try container.encode(ConditionType.always, forKey: .type)
    case .never:
      try container.encode(ConditionType.never, forKey: .type)
    case .stateEquals(let state):
      try container.encode(ConditionType.stateEquals, forKey: .type)
      try container.encode(state, forKey: .state)
    case .parameterEquals(let paramId, let paramValue):
      try container.encode(ConditionType.parameterEquals, forKey: .type)
      try container.encode(paramId, forKey: .parameterId)
      try container.encode(paramValue, forKey: .parameterValue)
    case .inputNotEmpty:
      try container.encode(ConditionType.inputNotEmpty, forKey: .type)
    case .allStepsCompleted:
      try container.encode(ConditionType.allStepsCompleted, forKey: .type)
    case .and(let conditions):
      try container.encode(ConditionType.and, forKey: .type)
      try container.encode(conditions, forKey: .conditions)
    case .or(let conditions):
      try container.encode(ConditionType.or, forKey: .type)
      try container.encode(conditions, forKey: .conditions)
    }
  }
}

// MARK: - BlockAction

// An action that a block can trigger.
struct BlockAction: Sendable, Equatable, Identifiable {
  let id: String

  // Type of action.
  let type: BlockActionType

  // Action label for UI buttons.
  let label: String?

  // Target block ID (for navigate, updateProgress, etc.).
  let targetBlockID: BlockID?

  // Payload data for the action.
  let payload: ActionPayload?

  // Conditions for when this action is enabled.
  let enabledCondition: ActionCondition?

  private enum CodingKeys: String, CodingKey {
    case id
    case type
    case label
    case targetBlockID
    case payload
    case enabledCondition
  }

  init(
    id: String = UUID().uuidString,
    type: BlockActionType,
    label: String? = nil,
    targetBlockID: BlockID? = nil,
    payload: ActionPayload? = nil,
    enabledCondition: ActionCondition? = nil
  ) {
    self.id = id
    self.type = type
    self.label = label
    self.targetBlockID = targetBlockID
    self.payload = payload
    self.enabledCondition = enabledCondition
  }
}

// MARK: - BlockAction Codable

extension BlockAction: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.type = try container.decode(BlockActionType.self, forKey: .type)
    self.label = try container.decodeIfPresent(String.self, forKey: .label)
    self.targetBlockID = try container.decodeIfPresent(BlockID.self, forKey: .targetBlockID)
    self.payload = try container.decodeIfPresent(ActionPayload.self, forKey: .payload)
    self.enabledCondition = try container.decodeIfPresent(ActionCondition.self, forKey: .enabledCondition)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(label, forKey: .label)
    try container.encodeIfPresent(targetBlockID, forKey: .targetBlockID)
    try container.encodeIfPresent(payload, forKey: .payload)
    try container.encodeIfPresent(enabledCondition, forKey: .enabledCondition)
  }
}

// MARK: - BlockAction Factory Methods

extension BlockAction {
  // Creates a navigate action.
  static func navigate(
    to destination: NavigationDestination,
    label: String? = nil
  ) -> BlockAction {
    BlockAction(
      type: .navigate,
      label: label,
      payload: .destination(destination)
    )
  }

  // Creates a submit action.
  static func submit(label: String = "Submit") -> BlockAction {
    BlockAction(type: .submit, label: label)
  }

  // Creates a check answer action.
  static func checkAnswer(label: String = "Check") -> BlockAction {
    BlockAction(type: .checkAnswer, label: label)
  }

  // Creates an invoke AI action.
  static func invokeAI(prompt: String? = nil) -> BlockAction {
    BlockAction(
      type: .invokeAI,
      payload: prompt.map { .text($0) }
    )
  }
}
