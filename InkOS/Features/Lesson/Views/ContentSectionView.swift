//
// ContentSectionView.swift
// InkOS
//
// Renders markdown content sections in lessons.
// Provides basic markdown formatting for educational content.
//

import SwiftUI

// Renders a content section with markdown formatting.
struct ContentSectionView: View {
  let section: ContentSection
  @ObservedObject var viewModel: LessonViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Parse and render markdown content.
      MarkdownTextView(text: section.content)
    }
  }
}

// MARK: - Markdown Text View

// Renders markdown text with basic formatting support.
// Handles headings, bullet lists, bold, italic, and code.
struct MarkdownTextView: View {
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(parseLines().enumerated()), id: \.offset) { _, line in
        renderLine(line)
      }
    }
  }

  // Parses text into lines for rendering.
  private func parseLines() -> [MarkdownLine] {
    let lines = text.components(separatedBy: "\n")
    var result: [MarkdownLine] = []
    var inCodeBlock = false
    var codeBlockContent: [String] = []

    for line in lines {
      // Handle code blocks.
      if line.hasPrefix("```") {
        if inCodeBlock {
          // End code block.
          result.append(.codeBlock(codeBlockContent.joined(separator: "\n")))
          codeBlockContent = []
          inCodeBlock = false
        } else {
          // Start code block.
          inCodeBlock = true
        }
        continue
      }

      if inCodeBlock {
        codeBlockContent.append(line)
        continue
      }

      // Skip empty lines.
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        continue
      }

      // Parse line type.
      if trimmed.hasPrefix("### ") {
        result.append(.h3(String(trimmed.dropFirst(4))))
      } else if trimmed.hasPrefix("## ") {
        result.append(.h2(String(trimmed.dropFirst(3))))
      } else if trimmed.hasPrefix("# ") {
        result.append(.h1(String(trimmed.dropFirst(2))))
      } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
        result.append(.bullet(String(trimmed.dropFirst(2))))
      } else if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
        result.append(.numbered(String(trimmed[match.upperBound...])))
      } else {
        result.append(.paragraph(trimmed))
      }
    }

    return result
  }

  // Renders a single line based on its type.
  // Uses semantic text styles for Dynamic Type support.
  @ViewBuilder
  private func renderLine(_ line: MarkdownLine) -> some View {
    switch line {
    case .h1(let text):
      formattedText(text)
        .font(.title2.bold())
        .foregroundStyle(Color.ink)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)

    case .h2(let text):
      formattedText(text)
        .font(.title3.bold())
        .foregroundStyle(Color.ink)
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)

    case .h3(let text):
      formattedText(text)
        .font(.headline)
        .foregroundStyle(Color.ink)
        .accessibilityAddTraits(.isHeader)

    case .paragraph(let text):
      formattedText(text)
        .font(.body)
        .foregroundStyle(Color.ink)
        .lineSpacing(4)

    case .bullet(let text):
      HStack(alignment: .top, spacing: 12) {
        Text("•")
          .font(.body)
          .foregroundStyle(Color.inkSubtle)
          .accessibilityHidden(true)

        formattedText(text)
          .font(.body)
          .foregroundStyle(Color.ink)
          .lineSpacing(4)
      }
      .padding(.leading, 8)
      .accessibilityElement(children: .combine)

    case .numbered(let text):
      formattedText(text)
        .font(.body)
        .foregroundStyle(Color.ink)
        .lineSpacing(4)
        .padding(.leading, 8)

    case .codeBlock(let code):
      Text(code)
        .font(.footnote.monospaced())
        .foregroundStyle(Color.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rule)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Code: \(code)")
    }
  }

  // Renders text with inline formatting (bold, italic, code).
  @ViewBuilder
  private func formattedText(_ text: String) -> Text {
    parseInlineFormatting(text)
  }

  // Parses inline markdown formatting.
  private func parseInlineFormatting(_ text: String) -> Text {
    var result = Text("")
    var remaining = text

    while !remaining.isEmpty {
      // Check for bold (**text** or __text__).
      if let boldMatch = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
        let before = String(remaining[..<boldMatch.lowerBound])
        let boldContent = String(remaining[boldMatch])
          .dropFirst(2)
          .dropLast(2)

        result = result + Text(before) + Text(String(boldContent)).bold()
        remaining = String(remaining[boldMatch.upperBound...])
        continue
      }

      // Check for italic (*text* or _text_).
      if let italicMatch = remaining.range(of: #"\*(.+?)\*"#, options: .regularExpression) {
        let before = String(remaining[..<italicMatch.lowerBound])
        let italicContent = String(remaining[italicMatch])
          .dropFirst(1)
          .dropLast(1)

        result = result + Text(before) + Text(String(italicContent)).italic()
        remaining = String(remaining[italicMatch.upperBound...])
        continue
      }

      // Check for inline code (`code`).
      if let codeMatch = remaining.range(of: #"`(.+?)`"#, options: .regularExpression) {
        let before = String(remaining[..<codeMatch.lowerBound])
        let codeContent = String(remaining[codeMatch])
          .dropFirst(1)
          .dropLast(1)

        result = result + Text(before)
          + Text(String(codeContent))
          .font(.callout.monospaced())
          .foregroundColor(Color.lessonAccent)
        remaining = String(remaining[codeMatch.upperBound...])
        continue
      }

      // No more formatting found, add remaining text.
      result = result + Text(remaining)
      break
    }

    return result
  }
}

// Types of markdown lines.
private enum MarkdownLine {
  case h1(String)
  case h2(String)
  case h3(String)
  case paragraph(String)
  case bullet(String)
  case numbered(String)
  case codeBlock(String)
}

// MARK: - Preview

#Preview {
  let sampleContent = ContentSection(
    content: """
      ## Introduction

      Photosynthesis is the process by which plants convert sunlight into **chemical energy**.

      This process is *essential* for life on Earth.

      - Occurs in chloroplasts
      - Requires sunlight, water, and CO₂
      - Produces glucose and oxygen

      ### Key Concepts

      The equation for photosynthesis is: `6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂`
      """
  )

  return ScrollView {
    ContentSectionView(section: sampleContent, viewModel: LessonViewModel())
      .padding(24)
  }
  .background(Color.white)
}
