//
// InputBlockView.swift
// InkOS
//
// Placeholder for input block rendering.
// Will be implemented in a future phase with form controls and MyScript handwriting.
//

import SwiftUI

// MARK: - InputBlockView

// Placeholder for input blocks.
struct InputBlockView: View {
  let content: InputContent

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let prompt = content.prompt {
        Text(prompt)
          .font(.body)
      }

      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.1))
        .frame(height: 100)
        .overlay {
          VStack(spacing: 8) {
            Image(systemName: inputIcon)
              .font(.title)
              .foregroundColor(.secondary)
            Text("Input (\(content.inputType.rawValue))")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

      Button(content.submitLabel) {
        // Placeholder action.
      }
      .buttonStyle(.borderedProminent)
      .disabled(true)
    }
    .padding(.vertical, 16)
  }

  private var inputIcon: String {
    switch content.inputType {
    case .text: return "text.cursor"
    case .handwriting: return "pencil.tip"
    case .multipleChoice: return "list.bullet"
    case .multiSelect: return "checkmark.square"
    case .button: return "hand.tap"
    case .slider: return "slider.horizontal.3"
    case .numeric: return "number"
    }
  }
}
