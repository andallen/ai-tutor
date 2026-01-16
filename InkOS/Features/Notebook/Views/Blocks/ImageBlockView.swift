//
// ImageBlockView.swift
// InkOS
//
// Placeholder for image block rendering.
// Will be implemented in a future phase.
//

import SwiftUI

// MARK: - ImageBlockView

// Placeholder for image blocks.
struct ImageBlockView: View {
  let content: ImageContent

  var body: some View {
    VStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.1))
        .frame(height: 200)
        .overlay {
          VStack(spacing: 8) {
            Image(systemName: "photo")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("Image")
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
