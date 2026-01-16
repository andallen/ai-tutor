//
// NotebookViewModel.swift
// InkOS
//
// State management for the notebook renderer.
// Tracks animation state for each block and Alan's presence state.
// User controls pacing by tapping to advance to the next block.
// Alan's presence indicator reflects current activity (idle/thinking/outputting).
//

import SwiftUI

// MARK: - BlockAnimationState

// Animation state for a single block.
enum BlockAnimationState: Equatable, Sendable {
  // Block is waiting to animate (not yet visible).
  case waiting
  // Block is currently animating in.
  case animating
  // Block animation has completed.
  case complete
}

// MARK: - NotebookViewModel

// Observable state for the notebook canvas renderer.
// User taps to advance through blocks at their own pace.
@MainActor @Observable
final class NotebookViewModel {
  // The notebook document being rendered.
  var document: NotebookDocument

  // Animation state for each block, keyed by block ID.
  var animationState: [BlockID: BlockAnimationState] = [:]

  // Alan's current presence state for the metaball indicator.
  var alanState: AlanPresenceState = .idle

  // The block ID the metaball should be positioned next to.
  // Set immediately on tap so metaball moves before block is revealed.
  var metaballTargetBlockId: BlockID?

  // Queue of block IDs waiting to be revealed.
  private var animationQueue: [BlockID] = []

  // Task for thinking delay, cancellable if user taps again.
  private var thinkingTask: Task<Void, Never>?

  // Duration for metaball position movement animation (in milliseconds).
  // Must match the animation duration in NotebookCanvasView (~150ms spring response).
  static let positionMovementDuration: Int = 150

  init(document: NotebookDocument) {
    self.document = document
    // Initialize all blocks as waiting.
    for block in document.blocks {
      animationState[block.id] = .waiting
    }
    // Build the queue of blocks to reveal.
    animationQueue = document.blocks.map { $0.id }
  }

  // Whether there are more blocks to reveal.
  var hasMoreBlocks: Bool {
    !animationQueue.isEmpty
  }

  // Whether any block is currently animating or has been revealed.
  // Used to determine if metaball should move from initial position.
  var hasAnimatingBlock: Bool {
    animationState.values.contains { $0 == .animating || $0 == .complete }
  }

  // Prepares the first block for reveal on user tap.
  // Sets metaball position but doesn't reveal content - user must tap.
  func prepareFirstBlock() {
    guard let firstId = animationQueue.first else { return }
    metaballTargetBlockId = firstId
    alanState = .idle
  }

  // Advances to the next block when user taps.
  // Sequence: metaball moves immediately → thinking during movement → reveal block → outputting.
  func advanceToNextBlock() {
    // Cancel any pending thinking task.
    thinkingTask?.cancel()

    // Mark any currently animating block as complete.
    for (blockId, state) in animationState where state == .animating {
      animationState[blockId] = .complete
    }

    // Check if there are more blocks.
    guard let nextId = animationQueue.first else {
      alanState = .idle
      return
    }

    // Phase 1: Immediately move metaball to next block position.
    metaballTargetBlockId = nextId

    // Enter thinking state (plays during movement).
    alanState = .thinking

    // Get the block to calculate its animation duration.
    let block = document.blocks.first { $0.id == nextId }
    let animationDuration = block?.content.animationDurationMs ?? 300

    thinkingTask = Task {
      // Phase 2: Wait for movement animation to complete.
      try? await Task.sleep(for: .milliseconds(Self.positionMovementDuration))
      guard !Task.isCancelled else { return }

      // Phase 3: Transition to outputting state after movement settles.
      alanState = .outputting

      // Phase 4: Brief pause, then reveal block.
      let revealDelay = Int.random(in: 200...400)
      try? await Task.sleep(for: .milliseconds(revealDelay))
      guard !Task.isCancelled else { return }

      animationQueue.removeFirst()
      animationState[nextId] = .animating

      // Phase 5: Return to idle after content animation completes.
      // Wait for the actual animation duration of this block.
      try? await Task.sleep(for: .milliseconds(animationDuration))
      guard !Task.isCancelled else { return }
      alanState = .idle
    }
  }

  // Immediately reveals all remaining blocks.
  func completeAllAnimations() {
    thinkingTask?.cancel()
    animationQueue.removeAll()
    for blockId in animationState.keys {
      animationState[blockId] = .complete
    }
    alanState = .idle
  }

  // Resets all animations to waiting state.
  func resetAnimations() {
    thinkingTask?.cancel()
    animationQueue = document.blocks.map { $0.id }
    for block in document.blocks {
      animationState[block.id] = .waiting
    }
    alanState = .idle
  }
}
