//
// BlockKind.swift
// InkOS
//
// Defines the types of blocks available in the Alan content system.
// Each kind determines rendering behavior and valid properties.
//

import Foundation

// MARK: - BlockTrait

// Categorization tags for block capabilities.
// A block can have multiple traits indicating its behavior.
struct BlockTrait: OptionSet, Sendable, Codable, Equatable {
  let rawValue: Int

  // Produces visible output (text, graphics, etc.).
  static let output = BlockTrait(rawValue: 1 << 0)

  // Accepts user input (text, handwriting, choices).
  static let input = BlockTrait(rawValue: 1 << 1)

  // Displays visual content (images, diagrams, graphs).
  static let visual = BlockTrait(rawValue: 1 << 2)

  // System/infrastructure block (timers, progress tracking).
  static let system = BlockTrait(rawValue: 1 << 3)

  // Common combinations.
  static let interactive: BlockTrait = [.output, .input]
  static let outputVisual: BlockTrait = [.output, .visual]
}

// MARK: - BlockKind

// Defines the type of a block, determining its rendering and behavior.
// Each kind maps to specific typed properties in BlockProperties.
enum BlockKind: String, Sendable, Codable, Equatable, CaseIterable {
  // MARK: Phase 1 - Core Content

  // Rich text with markdown and LaTeX support.
  case textOutput

  // Keyboard text input field.
  case textInput

  // Handwriting input canvas with recognition.
  case handwritingInput

  // MARK: Phase 2 - Visual

  // Mathematical graph/plot with interactive parameters.
  case plot

  // Data table with optional editing and formulas.
  case table

  // Flowchart, diagram, or concept map.
  case diagramOutput

  // MARK: Phase 3 - Interactive

  // Flashcard deck with spaced repetition.
  case cardDeck

  // Multi-question quiz with various question types.
  case quiz

  // MARK: Phase 4 - Advanced

  // Interactive geometry construction.
  case geometry

  // Executable code cell with output.
  case codeCell

  // MARK: Utility Blocks

  // Static code display with syntax highlighting.
  case codeOutput

  // Highlighted callout box (info, warning, etc.).
  case calloutOutput

  // Static image display.
  case imageOutput

  // Clickable action button.
  case buttonInput

  // Countdown or stopwatch timer.
  case timerOutput

  // Progress indicator bar.
  case progressOutput

  // Audio playback control.
  case audio

  // Video playback control.
  case videoOutput

  // MARK: - Computed Properties

  // Traits for this block kind.
  var traits: BlockTrait {
    switch self {
    case .textOutput:
      return .output
    case .textInput:
      return .input
    case .handwritingInput:
      return .input
    case .plot:
      return [.output, .input, .visual]
    case .table:
      return [.output, .input, .visual]
    case .diagramOutput:
      return [.output, .visual]
    case .cardDeck:
      return [.output, .input, .visual]
    case .quiz:
      return [.output, .input, .visual]
    case .geometry:
      return [.output, .input, .visual]
    case .codeCell:
      return [.output, .input]
    case .codeOutput:
      return .output
    case .calloutOutput:
      return [.output, .visual]
    case .imageOutput:
      return [.output, .visual]
    case .buttonInput:
      return [.input, .visual, .system]
    case .timerOutput:
      return [.output, .visual, .system]
    case .progressOutput:
      return [.output, .visual, .system]
    case .audio:
      return [.output, .input]
    case .videoOutput:
      return [.output, .visual]
    }
  }

  // Whether this kind accepts user input.
  var acceptsInput: Bool {
    traits.contains(.input)
  }

  // Whether this kind produces visual output.
  var isVisual: Bool {
    traits.contains(.visual)
  }

  // Whether this kind is a system/infrastructure block.
  var isSystem: Bool {
    traits.contains(.system)
  }

  // Whether this kind can contain child blocks.
  var allowsChildren: Bool {
    switch self {
    case .cardDeck, .quiz:
      return true
    default:
      return false
    }
  }
}
