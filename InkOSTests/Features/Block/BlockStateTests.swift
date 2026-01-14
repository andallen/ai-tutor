//
// BlockStateTests.swift
// InkOSTests
//
// Tests for BlockState and state transitions.
//

import Foundation
import Testing

@testable import InkOS

@Suite("BlockState Tests")
struct BlockStateTests {

  // MARK: - BlockState

  @Test("BlockState has all expected states")
  func allStates() {
    let states: [BlockState] = [
      .idle, .active, .loading, .completed, .error,
      .disabled, .hidden, .collapsed, .expanded
    ]

    #expect(BlockState.allCases.count == 9)

    for state in states {
      #expect(BlockState.allCases.contains(state))
    }
  }

  @Test("BlockState encodes to raw string")
  func stateEncodesToRawValue() throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(BlockState.idle)
    let json = String(data: data, encoding: .utf8)

    #expect(json == "\"idle\"")
  }

  // MARK: - Valid Transitions

  @Test("Same state transition is always valid")
  func sameStateAlwaysValid() {
    for state in BlockState.allCases {
      #expect(BlockStateTransition.isValid(from: state, to: state))
    }
  }

  @Test("Idle to active is valid")
  func idleToActive() {
    #expect(BlockStateTransition.isValid(from: .idle, to: .active))
  }

  @Test("Idle to loading is valid")
  func idleToLoading() {
    #expect(BlockStateTransition.isValid(from: .idle, to: .loading))
  }

  @Test("Active to loading is valid")
  func activeToLoading() {
    #expect(BlockStateTransition.isValid(from: .active, to: .loading))
  }

  @Test("Active to completed is valid")
  func activeToCompleted() {
    #expect(BlockStateTransition.isValid(from: .active, to: .completed))
  }

  @Test("Active to error is valid")
  func activeToError() {
    #expect(BlockStateTransition.isValid(from: .active, to: .error))
  }

  @Test("Loading to completed is valid")
  func loadingToCompleted() {
    #expect(BlockStateTransition.isValid(from: .loading, to: .completed))
  }

  @Test("Loading to error is valid")
  func loadingToError() {
    #expect(BlockStateTransition.isValid(from: .loading, to: .error))
  }

  @Test("Completed to idle is valid")
  func completedToIdle() {
    #expect(BlockStateTransition.isValid(from: .completed, to: .idle))
  }

  @Test("Error to idle is valid")
  func errorToIdle() {
    #expect(BlockStateTransition.isValid(from: .error, to: .idle))
  }

  @Test("Disabled to idle is valid")
  func disabledToIdle() {
    #expect(BlockStateTransition.isValid(from: .disabled, to: .idle))
  }

  @Test("Hidden to idle is valid")
  func hiddenToIdle() {
    #expect(BlockStateTransition.isValid(from: .hidden, to: .idle))
  }

  @Test("Collapsed to expanded is valid")
  func collapsedToExpanded() {
    #expect(BlockStateTransition.isValid(from: .collapsed, to: .expanded))
  }

  @Test("Expanded to collapsed is valid")
  func expandedToCollapsed() {
    #expect(BlockStateTransition.isValid(from: .expanded, to: .collapsed))
  }

  // MARK: - Invalid Transitions

  @Test("Completed to loading is invalid")
  func completedToLoadingInvalid() {
    #expect(BlockStateTransition.isValid(from: .completed, to: .loading) == false)
  }

  @Test("Error to completed is invalid")
  func errorToCompletedInvalid() {
    #expect(BlockStateTransition.isValid(from: .error, to: .completed) == false)
  }

  @Test("Disabled to loading is invalid")
  func disabledToLoadingInvalid() {
    #expect(BlockStateTransition.isValid(from: .disabled, to: .loading) == false)
  }

  @Test("Hidden to error is invalid")
  func hiddenToErrorInvalid() {
    #expect(BlockStateTransition.isValid(from: .hidden, to: .error) == false)
  }

  // MARK: - Valid Next States

  @Test("Idle has multiple valid next states")
  func idleValidNextStates() {
    let validNext = BlockStateTransition.validNextStates(from: .idle)

    #expect(validNext.contains(.active))
    #expect(validNext.contains(.loading))
    #expect(validNext.contains(.disabled))
    #expect(validNext.contains(.hidden))
    #expect(validNext.count >= 4)
  }

  @Test("Active has multiple valid next states")
  func activeValidNextStates() {
    let validNext = BlockStateTransition.validNextStates(from: .active)

    #expect(validNext.contains(.idle))
    #expect(validNext.contains(.loading))
    #expect(validNext.contains(.completed))
    #expect(validNext.contains(.error))
  }

  @Test("Loading has valid next states")
  func loadingValidNextStates() {
    let validNext = BlockStateTransition.validNextStates(from: .loading)

    #expect(validNext.contains(.completed))
    #expect(validNext.contains(.error))
    #expect(validNext.contains(.idle))
  }

  @Test("Collapsed and expanded toggle")
  func collapsedExpandedToggle() {
    let fromCollapsed = BlockStateTransition.validNextStates(from: .collapsed)
    let fromExpanded = BlockStateTransition.validNextStates(from: .expanded)

    #expect(fromCollapsed.contains(.expanded))
    #expect(fromExpanded.contains(.collapsed))
  }

  // MARK: - Convenience Properties

  @Test("isInteractable property works")
  func isInteractable() {
    #expect(BlockState.idle.isInteractable == true)
    #expect(BlockState.active.isInteractable == true)
    #expect(BlockState.expanded.isInteractable == true)

    #expect(BlockState.loading.isInteractable == false)
    #expect(BlockState.completed.isInteractable == false)
    #expect(BlockState.error.isInteractable == false)
    #expect(BlockState.disabled.isInteractable == false)
    #expect(BlockState.hidden.isInteractable == false)
    #expect(BlockState.collapsed.isInteractable == false)
  }

  @Test("isVisible property works")
  func isVisible() {
    #expect(BlockState.idle.isVisible == true)
    #expect(BlockState.active.isVisible == true)
    #expect(BlockState.loading.isVisible == true)
    #expect(BlockState.completed.isVisible == true)
    #expect(BlockState.error.isVisible == true)
    #expect(BlockState.disabled.isVisible == true)
    #expect(BlockState.collapsed.isVisible == true)
    #expect(BlockState.expanded.isVisible == true)

    #expect(BlockState.hidden.isVisible == false)
  }

  @Test("isTerminal property works")
  func isTerminal() {
    #expect(BlockState.completed.isTerminal == true)
    #expect(BlockState.error.isTerminal == true)

    #expect(BlockState.idle.isTerminal == false)
    #expect(BlockState.active.isTerminal == false)
    #expect(BlockState.loading.isTerminal == false)
  }

  @Test("isProcessing property works")
  func isProcessing() {
    #expect(BlockState.loading.isProcessing == true)

    #expect(BlockState.idle.isProcessing == false)
    #expect(BlockState.active.isProcessing == false)
    #expect(BlockState.completed.isProcessing == false)
  }

  // MARK: - StateTransitionTrigger

  @Test("StateTransitionTrigger has all expected types")
  func triggerTypes() {
    let triggers: [StateTransitionTrigger] = [
      .userInteraction, .actionCompleted, .actionFailed,
      .timerExpired, .externalUpdate, .parameterChange,
      .focus, .blur
    ]

    for trigger in triggers {
      // Just verify they exist and are equatable
      #expect(trigger == trigger)
    }
  }

  // MARK: - Integration

  @Test("Block state can be updated")
  func blockStateUpdate() {
    var block = Block(
      kind: .textInput,
      properties: .textInput(TextInputProperties()),
      state: .idle
    )

    #expect(block.state == .idle)

    block.state = .active
    #expect(block.state == .active)

    block.state = .completed
    #expect(block.state == .completed)
  }

  @Test("Block starts in idle state by default")
  func blockDefaultState() {
    let block = Block(
      kind: .textOutput,
      properties: .textOutput(TextOutputProperties(content: "Test"))
    )

    #expect(block.state == .idle)
  }
}
