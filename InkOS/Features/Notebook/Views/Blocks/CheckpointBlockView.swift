//
// CheckpointBlockView.swift
// InkOS
//
// Visual marker in the notebook flow.
// Displays prompt text as a styled divider. User pacing is controlled
// by tap-to-advance on the canvas, not by buttons within checkpoints.
//

import SwiftUI

// MARK: - CheckpointBlockView

// Displays checkpoint prompt as styled text.
// No button - user advances by tapping the canvas.
struct CheckpointBlockView: View {
  let content: CheckpointContent

  var body: some View {
    Text(content.prompt)
      .font(.title2)
      .fontWeight(.medium)
      .foregroundColor(.primary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 48)
  }
}

// MARK: - Preview

#Preview {
  CheckpointBlockView(content: CheckpointContent(prompt: "Ready?"))
}
