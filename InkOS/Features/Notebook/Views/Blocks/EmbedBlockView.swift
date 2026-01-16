//
// EmbedBlockView.swift
// InkOS
//
// Placeholder for embed block rendering.
// Will be implemented in a future phase with WebView for PhET, GeoGebra, etc.
//

import SwiftUI

// MARK: - EmbedBlockView

// Placeholder for embed blocks.
struct EmbedBlockView: View {
  let content: EmbedContent

  var body: some View {
    VStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.1))
        .frame(height: 300)
        .overlay {
          VStack(spacing: 8) {
            Image(systemName: "globe")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("Embed (\(content.provider.rawValue))")
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
