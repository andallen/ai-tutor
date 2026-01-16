//
// CodeBlockView.swift
// InkOS
//
// Renders code blocks with monospace font and optional line numbers.
// Basic syntax highlighting could be added in future.
//

import SwiftUI

// MARK: - CodeBlockView

// Renders code with monospace styling.
struct CodeBlockView: View {
  let code: String
  let language: String
  let showLineNumbers: Bool
  let highlightLines: [Int]?

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if showLineNumbers {
        lineNumbersColumn
      }
      codeColumn
    }
    .font(.system(.body, design: .monospaced))
    .padding(16)
    .background(Color.black.opacity(0.03))
    .cornerRadius(8)
  }

  private var lines: [String] {
    code.components(separatedBy: "\n")
  }

  private var lineNumbersColumn: some View {
    VStack(alignment: .trailing, spacing: 0) {
      ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
        Text("\(index + 1)")
          .foregroundColor(.secondary.opacity(0.5))
          .frame(height: lineHeight)
      }
    }
  }

  private var codeColumn: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
        Text(line.isEmpty ? " " : line)
          .frame(height: lineHeight, alignment: .leading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(isHighlighted(index + 1) ? Color.yellow.opacity(0.2) : Color.clear)
      }
    }
  }

  private var lineHeight: CGFloat { 20 }

  private func isHighlighted(_ lineNumber: Int) -> Bool {
    highlightLines?.contains(lineNumber) ?? false
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 24) {
    CodeBlockView(
      code: "func hello() {\n    print(\"Hello, world!\")\n}",
      language: "swift",
      showLineNumbers: true,
      highlightLines: [2]
    )

    CodeBlockView(
      code: "let x = 42\nlet y = x * 2",
      language: "swift",
      showLineNumbers: false,
      highlightLines: nil
    )
  }
  .padding()
}
