//
// KineticTextView.swift
// InkOS
//
// Kinetic typography animation engine.
// Sequential text output (typewriter) maintains the sense of a living
// agent producing content in real-time.
//

import SwiftUI

// MARK: - KineticTextView

// Animates text with typewriter effect.
struct KineticTextView: View {
  let text: String
  let animation: KineticAnimation
  let durationMs: Int
  let delayMs: Int
  let style: TextStyle?
  let shouldAnimate: Bool
  let sequenceIndex: Int

  @State private var hasStarted = false
  @State private var progress: Double = 0

  var body: some View {
    TypewriterAnimationView(text: text, progress: progress, style: style)
      .onAppear {
        if shouldAnimate {
          runAnimation()
        }
      }
      .onChange(of: shouldAnimate) { _, newValue in
        if newValue {
          runAnimation()
        }
      }
  }

  // Runs the animation from start to finish.
  private func runAnimation() {
    // Reset state for replay.
    hasStarted = false
    progress = 0

    Task { @MainActor in
      // Wait for delay.
      if delayMs > 0 {
        try? await Task.sleep(for: .milliseconds(delayMs))
      }

      hasStarted = true

      // Animate progress from 0 to 1.
      let steps = 60
      let stepDuration = Double(durationMs) / Double(steps)

      for step in 1...steps {
        try? await Task.sleep(for: .milliseconds(Int(stepDuration)))
        progress = Double(step) / Double(steps)
      }
    }
  }
}
