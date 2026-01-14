//
// BlockValidation.swift
// InkOS
//
// Validation logic and error types for blocks.
// Ensures blocks are well-formed before rendering or persistence.
//

import Foundation

// MARK: - BlockError

// Errors that can occur during block operations.
enum BlockError: Error, LocalizedError, Equatable, Sendable {
  // Block kind is not supported.
  case unsupportedBlockKind(BlockKind)

  // Decoding BlockProperties requires knowing the block kind first.
  case decodingRequiresKind

  // Invalid state transition attempted.
  case invalidStateTransition(from: BlockState, to: BlockState)

  // Properties don't match the block kind.
  case invalidPropertyForKind(kind: BlockKind, reason: String)

  // Required property is missing.
  case missingRequiredProperty(propertyName: String)

  // Parameter value is invalid.
  case invalidParameterValue(parameterName: String, reason: String)

  // Parameter value is outside allowed range.
  case parameterOutOfRange(parameterName: String, value: Double, min: Double, max: Double)

  // Block kind does not allow children.
  case childrenNotAllowed(kind: BlockKind)

  // Action is invalid for this block kind.
  case invalidAction(actionType: BlockActionType, reason: String)

  // Schema version is not supported.
  case schemaVersionUnsupported(version: Int)

  // Block ID is empty.
  case emptyBlockID

  // Layer value is invalid.
  case invalidLayer(layer: Int)

  var errorDescription: String? {
    switch self {
    case .unsupportedBlockKind(let kind):
      return "Unsupported block kind: \(kind.rawValue)"
    case .decodingRequiresKind:
      return "BlockProperties decoding requires the block kind to be known"
    case .invalidStateTransition(let from, let to):
      return "Invalid state transition from \(from.rawValue) to \(to.rawValue)"
    case .invalidPropertyForKind(let kind, let reason):
      return "Invalid property for \(kind.rawValue): \(reason)"
    case .missingRequiredProperty(let name):
      return "Missing required property: \(name)"
    case .invalidParameterValue(let name, let reason):
      return "Invalid value for parameter '\(name)': \(reason)"
    case .parameterOutOfRange(let name, let value, let min, let max):
      return "Parameter '\(name)' value \(value) is out of range [\(min), \(max)]"
    case .childrenNotAllowed(let kind):
      return "Block kind \(kind.rawValue) does not allow children"
    case .invalidAction(let actionType, let reason):
      return "Invalid action \(actionType.rawValue): \(reason)"
    case .schemaVersionUnsupported(let version):
      return "Block schema version \(version) is not supported"
    case .emptyBlockID:
      return "Block ID cannot be empty"
    case .invalidLayer(let layer):
      return "Layer value \(layer) is invalid (must be >= 0)"
    }
  }
}

// MARK: - BlockValidator Protocol

// Protocol for block validation.
protocol BlockValidator {
  func validate(_ block: Block) throws
}

// MARK: - DefaultBlockValidator

// Default implementation of block validation.
struct DefaultBlockValidator: BlockValidator, Sendable {

  func validate(_ block: Block) throws {
    // Validate block ID is not empty.
    guard !block.id.rawValue.isEmpty else {
      throw BlockError.emptyBlockID
    }

    // Validate schema version.
    guard BlockSchemaVersion.supported.contains(block.metadata.schemaVersion) else {
      throw BlockError.schemaVersionUnsupported(version: block.metadata.schemaVersion)
    }

    // Validate layer is non-negative.
    guard block.layer >= 0 else {
      throw BlockError.invalidLayer(layer: block.layer)
    }

    // Validate properties match kind.
    try validatePropertiesMatchKind(block)

    // Validate parameters.
    if let parameters = block.parameters {
      for param in parameters {
        try validateParameter(param)
      }
    }

    // Validate children if present.
    if let children = block.children {
      guard block.kind.allowsChildren else {
        throw BlockError.childrenNotAllowed(kind: block.kind)
      }
      for child in children {
        try validate(child)
      }
    }

    // Validate actions.
    if let actions = block.actions {
      for action in actions {
        try validateAction(action, for: block.kind)
      }
    }
  }

  // Validates that properties enum case matches block kind.
  private func validatePropertiesMatchKind(_ block: Block) throws {
    let isValid: Bool
    switch (block.kind, block.properties) {
    case (.textOutput, .textOutput):
      isValid = true
    case (.textInput, .textInput):
      isValid = true
    case (.handwritingInput, .handwritingInput):
      isValid = true
    case (.plot, .plot):
      isValid = true
    case (.table, .table):
      isValid = true
    case (.diagramOutput, .diagramOutput):
      isValid = true
    case (.cardDeck, .cardDeck):
      isValid = true
    case (.quiz, .quiz):
      isValid = true
    case (.geometry, .geometry):
      isValid = true
    case (.codeCell, .codeCell):
      isValid = true
    case (.codeOutput, .codeOutput):
      isValid = true
    case (.calloutOutput, .calloutOutput):
      isValid = true
    case (.imageOutput, .imageOutput):
      isValid = true
    case (.buttonInput, .buttonInput):
      isValid = true
    case (.timerOutput, .timerOutput):
      isValid = true
    case (.progressOutput, .progressOutput):
      isValid = true
    case (.audio, .audio):
      isValid = true
    case (.videoOutput, .videoOutput):
      isValid = true
    default:
      isValid = false
    }

    guard isValid else {
      throw BlockError.invalidPropertyForKind(
        kind: block.kind,
        reason: "Properties type does not match block kind"
      )
    }
  }

  // Validates a parameter.
  private func validateParameter(_ param: Parameter) throws {
    // Validate slider range.
    if param.type == .slider || param.type == .stepper {
      guard let range = param.range else {
        throw BlockError.invalidParameterValue(
          parameterName: param.name,
          reason: "Slider/stepper parameter requires range"
        )
      }

      if let value = param.value.numberValue {
        guard range.contains(value) else {
          throw BlockError.parameterOutOfRange(
            parameterName: param.name,
            value: value,
            min: range.min,
            max: range.max
          )
        }
      }
    }

    // Validate dropdown has options.
    if param.type == .dropdown {
      guard let options = param.options, !options.isEmpty else {
        throw BlockError.invalidParameterValue(
          parameterName: param.name,
          reason: "Dropdown parameter requires options"
        )
      }
    }

    // Validate name is not empty.
    guard !param.name.isEmpty else {
      throw BlockError.invalidParameterValue(
        parameterName: "",
        reason: "Parameter name cannot be empty"
      )
    }

    // Validate label is not empty.
    guard !param.label.isEmpty else {
      throw BlockError.invalidParameterValue(
        parameterName: param.name,
        reason: "Parameter label cannot be empty"
      )
    }
  }

  // Validates an action for a block kind.
  private func validateAction(_ action: BlockAction, for kind: BlockKind) throws {
    // Validate action is appropriate for block kind.
    switch action.type {
    case .shuffle:
      guard kind == .quiz || kind == .cardDeck else {
        throw BlockError.invalidAction(
          actionType: action.type,
          reason: "shuffle action only valid for quiz or cardDeck blocks"
        )
      }
    case .startTimer, .stopTimer:
      guard kind == .timerOutput else {
        throw BlockError.invalidAction(
          actionType: action.type,
          reason: "timer actions only valid for timer blocks"
        )
      }
    case .playAudio, .pauseAudio:
      guard kind == .audio else {
        throw BlockError.invalidAction(
          actionType: action.type,
          reason: "audio actions only valid for audio blocks"
        )
      }
    case .playVideo, .pauseVideo:
      guard kind == .videoOutput else {
        throw BlockError.invalidAction(
          actionType: action.type,
          reason: "video actions only valid for video blocks"
        )
      }
    default:
      // Other actions are generally valid for any block kind.
      break
    }
  }
}

// MARK: - Block Validation Extension

extension Block {
  // Validates this block using the default validator.
  func validate() throws {
    let validator = DefaultBlockValidator()
    try validator.validate(self)
  }

  // Returns whether this block is valid.
  var isValid: Bool {
    do {
      try validate()
      return true
    } catch {
      return false
    }
  }
}
