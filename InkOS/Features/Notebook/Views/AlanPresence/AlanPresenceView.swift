//
// AlanPresenceView.swift
// InkOS
//
// SwiftUI wrapper for the metaball presence indicator.
// Handles animated transitions between states by interpolating shader parameters.
// Uses TimelineView for continuous animation updates.
// Manual interpolation is required because SwiftUI's withAnimation doesn't
// interpolate raw Float values passed to Metal shaders.
//

import SwiftUI

// MARK: - AlanPresenceView

// Displays Alan's presence as an animated metaball.
// Seamlessly transitions between idle, thinking, and outputting states.
struct AlanPresenceView: View {
  let state: AlanPresenceState

  // Animation start time for continuous time-based animation.
  @State private var startTime = Date()

  // Transition tracking for smooth interpolation.
  @State private var transitionStartTime = Date()
  @State private var previousState: AlanPresenceState = .idle

  // Duration of state transitions.
  private let transitionDuration: TimeInterval = 0.5

  var body: some View {
    TimelineView(.animation) { timeline in
      let elapsed = Float(timeline.date.timeIntervalSince(startTime))

      // Calculate transition progress (0 to 1).
      let transitionElapsed = timeline.date.timeIntervalSince(transitionStartTime)
      let rawProgress = min(1.0, transitionElapsed / transitionDuration)
      let smoothProgress = Float(easeInOut(rawProgress))

      // Interpolate between previous and current state parameters.
      let speed = lerp(previousState.speedMultiplier, state.speedMultiplier, smoothProgress)
      let range = lerp(previousState.movementRange, state.movementRange, smoothProgress)
      let breath = lerp(previousState.breathAmplitude, state.breathAmplitude, smoothProgress)
      let verts = lerp(previousState.vertexCount, state.vertexCount, smoothProgress)

      MetaballMetalView(
        time: elapsed,
        speedMultiplier: speed,
        movementRange: range,
        breathAmplitude: breath,
        vertexCount: verts
      )
    }
    .frame(width: 100, height: 100)
    .onAppear {
      // Initialize to current state with no transition.
      previousState = state
      transitionStartTime = Date.distantPast
    }
    .onChange(of: state) { oldState, _ in
      // Start transition from old state to new state.
      previousState = oldState
      transitionStartTime = Date()
    }
  }

  // Linear interpolation between two values.
  private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * t
  }

  // Ease-in-out curve for smooth acceleration and deceleration.
  private func easeInOut(_ t: TimeInterval) -> TimeInterval {
    t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 40) {
    AlanPresenceView(state: .idle)
    AlanPresenceView(state: .thinking)
    AlanPresenceView(state: .outputting)
  }
  .padding()
  .background(Color.white)
}
