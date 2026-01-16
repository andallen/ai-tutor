//
// CheckpointContent.swift
// InkOS
//
// Pause point in the notebook flow.
// Displays a prompt and requires user interaction to continue.
//

import Foundation

// MARK: - CheckpointContent

// Content for a checkpoint block that pauses the flow.
struct CheckpointContent: Sendable, Codable, Equatable {
  // Optional prompt text shown above the continue button.
  let prompt: String

  init(prompt: String = "Ready?") {
    self.prompt = prompt
  }
}
