//
// GraphicsBlockView.swift
// InkOS
//
// Placeholder for graphics block rendering.
// Will be implemented in a future phase with WebView for Chart.js, p5.js, etc.
//

import SwiftUI

// MARK: - GraphicsBlockView

// Placeholder for graphics blocks.
struct GraphicsBlockView: View {
  let content: GraphicsContent

  var body: some View {
    VStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.1))
        .frame(height: 250)
        .overlay {
          VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("Graphics (\(content.engine.rawValue))")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

      if let caption = content.caption {
        Text(caption)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 16)
  }
}
