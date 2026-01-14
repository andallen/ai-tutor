//
// BlockState.swift
// InkOS
//
// Block state management with valid state transitions.
// Defines the lifecycle states a block can be in and the
// allowed transitions between them.
//

import Foundation

// MARK: - BlockState

// The current state of a block.
enum BlockState: String, Sendable, Codable, Equatable, CaseIterable {
  // Block is ready but not interacted with.
  case idle

  // Block is currently active/focused.
  case active

  // Block is processing (e.g., waiting for AI response).
  case loading

  // Block completed successfully.
  case completed

  // Block encountered an error.
  case error

  // Block is disabled/locked.
  case disabled

  // Block is hidden from view.
  case hidden

  // Block is collapsed (for steps, cards, etc.).
  case collapsed

  // Block is expanded.
  case expanded
}

// MARK: - StateTransitionTrigger

// What triggered a state transition.
enum StateTransitionTrigger: String, Sendable, Codable, Equatable {
  // User interacted with the block.
  case userInteraction

  // An action completed successfully.
  case actionCompleted

  // An action failed.
  case actionFailed

  // A timer expired.
  case timerExpired

  // External system updated the state.
  case externalUpdate

  // A parameter value changed.
  case parameterChange

  // Block received focus.
  case focus

  // Block lost focus.
  case blur
}

// MARK: - BlockStateTransition

// Represents and validates state transitions for blocks.
struct BlockStateTransition: Sendable {
  let from: BlockState
  let to: BlockState
  let trigger: StateTransitionTrigger

  // Valid state transitions.
  // Defines which state changes are allowed.
  private static let validTransitions: Set<StateTransitionPair> = [
    // From idle.
    StateTransitionPair(.idle, .active),
    StateTransitionPair(.idle, .loading),
    StateTransitionPair(.idle, .disabled),
    StateTransitionPair(.idle, .hidden),
    StateTransitionPair(.idle, .collapsed),
    StateTransitionPair(.idle, .expanded),

    // From active.
    StateTransitionPair(.active, .idle),
    StateTransitionPair(.active, .loading),
    StateTransitionPair(.active, .completed),
    StateTransitionPair(.active, .error),
    StateTransitionPair(.active, .disabled),

    // From loading.
    StateTransitionPair(.loading, .completed),
    StateTransitionPair(.loading, .error),
    StateTransitionPair(.loading, .idle),
    StateTransitionPair(.loading, .active),

    // From completed.
    StateTransitionPair(.completed, .idle),
    StateTransitionPair(.completed, .active),
    StateTransitionPair(.completed, .loading),

    // From error.
    StateTransitionPair(.error, .idle),
    StateTransitionPair(.error, .active),
    StateTransitionPair(.error, .loading),

    // From disabled.
    StateTransitionPair(.disabled, .idle),
    StateTransitionPair(.disabled, .active),

    // From hidden.
    StateTransitionPair(.hidden, .idle),
    StateTransitionPair(.hidden, .active),
    StateTransitionPair(.hidden, .collapsed),
    StateTransitionPair(.hidden, .expanded),

    // From collapsed.
    StateTransitionPair(.collapsed, .expanded),
    StateTransitionPair(.collapsed, .idle),
    StateTransitionPair(.collapsed, .hidden),

    // From expanded.
    StateTransitionPair(.expanded, .collapsed),
    StateTransitionPair(.expanded, .idle),
    StateTransitionPair(.expanded, .hidden),
  ]

  // Validates if a transition is allowed.
  static func isValid(from: BlockState, to: BlockState) -> Bool {
    // Same state is always valid (no-op).
    if from == to { return true }
    return validTransitions.contains(StateTransitionPair(from, to))
  }

  // Returns all valid next states from a given state.
  static func validNextStates(from state: BlockState) -> [BlockState] {
    validTransitions
      .filter { $0.from == state }
      .map { $0.to }
  }
}

// MARK: - StateTransitionPair

// Hashable pair for transition lookup.
private struct StateTransitionPair: Hashable {
  let from: BlockState
  let to: BlockState

  init(_ from: BlockState, _ to: BlockState) {
    self.from = from
    self.to = to
  }
}

// MARK: - BlockState Convenience

extension BlockState {
  // Whether this state indicates the block is interactable.
  var isInteractable: Bool {
    switch self {
    case .idle, .active, .expanded:
      return true
    case .loading, .completed, .error, .disabled, .hidden, .collapsed:
      return false
    }
  }

  // Whether this state indicates the block is visible.
  var isVisible: Bool {
    self != .hidden
  }

  // Whether this state indicates a terminal condition.
  var isTerminal: Bool {
    switch self {
    case .completed, .error:
      return true
    default:
      return false
    }
  }

  // Whether this state indicates the block is processing.
  var isProcessing: Bool {
    self == .loading
  }
}
