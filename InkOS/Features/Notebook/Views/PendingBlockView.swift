//
// PendingBlockView.swift
// InkOS
//
// Minimal loading indicator for blocks that are still being generated.
// Subtle pulsing dot - understated, not distracting.
//

import SwiftUI

// MARK: - PendingBlockView

// Loading indicator for pending blocks.
struct PendingBlockView: View {
  @State private var isPulsing = false

  var body: some View {
    HStack {
      Circle()
        .fill(Color.black.opacity(0.2))
        .frame(width: 8, height: 8)
        .scaleEffect(isPulsing ? 1.2 : 0.8)
        .animation(
          .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
          value: isPulsing
        )
      Spacer()
    }
    .padding(.vertical, 24)
    .onAppear {
      isPulsing = true
    }
  }
}

// MARK: - Preview

#Preview {
  PendingBlockView()
    .padding()
}
