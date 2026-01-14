// MarkdownRenderer.swift
// Shared utility for rendering markdown text to NSAttributedString.
// Uses LessonTypography for consistent text formatting across lesson content.

import UIKit

// Renders markdown text to NSAttributedString with support for:
// - Headers (#, ##, ###)
// - Bold (**text**)
// - Italic (*text*)
// - Bullet points (- or *)
// - Numbered lists
// - Code blocks and inline code
// - Blockquotes (>)
enum MarkdownRenderer {

  // Standard text color (uses typography system).
  static let textColor = LessonTypography.Color.primary

  // Subtle text color for quotes.
  static let subtleColor = LessonTypography.Color.secondary

  // Math expression color.
  static let mathColor = LessonTypography.Color.accent

  // Renders markdown text to attributed string.
  static func render(_ text: String, fontSize: CGFloat = LessonTypography.Size.body) -> NSAttributedString {
    let result = NSMutableAttributedString()

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineHeightMultiple = LessonTypography.LineHeight.normal
    paragraphStyle.paragraphSpacing = LessonTypography.Spacing.md

    let lines = text.components(separatedBy: "\n")
    for (index, line) in lines.enumerated() {
      var processedLine = line
      var attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle
      ]

      // Detect headers.
      if line.hasPrefix("### ") {
        processedLine = String(line.dropFirst(4))
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineHeightMultiple = LessonTypography.LineHeight.tight
        headerStyle.paragraphSpacing = LessonTypography.Spacing.sm
        headerStyle.paragraphSpacingBefore = LessonTypography.Spacing.lg
        attributes[.font] = LessonTypography.font(size: fontSize + 2, weight: .semibold)
        attributes[.paragraphStyle] = headerStyle
      } else if line.hasPrefix("## ") {
        processedLine = String(line.dropFirst(3))
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineHeightMultiple = LessonTypography.LineHeight.tight
        headerStyle.paragraphSpacing = LessonTypography.Spacing.sm
        headerStyle.paragraphSpacingBefore = LessonTypography.Spacing.xl
        attributes[.font] = LessonTypography.font(size: fontSize + 4, weight: .semibold)
        attributes[.paragraphStyle] = headerStyle
      } else if line.hasPrefix("# ") {
        processedLine = String(line.dropFirst(2))
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineHeightMultiple = LessonTypography.LineHeight.tight
        headerStyle.paragraphSpacing = LessonTypography.Spacing.md
        headerStyle.paragraphSpacingBefore = LessonTypography.Spacing.xl
        attributes[.font] = LessonTypography.font(size: fontSize + 8, weight: .bold)
        attributes[.paragraphStyle] = headerStyle
      } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
        processedLine = "•  " + String(line.dropFirst(2))
        let listStyle = NSMutableParagraphStyle()
        listStyle.lineHeightMultiple = LessonTypography.LineHeight.normal
        listStyle.paragraphSpacing = LessonTypography.Spacing.xs
        listStyle.headIndent = LessonTypography.Spacing.lg
        listStyle.firstLineHeadIndent = 0
        attributes[.font] = LessonTypography.font(size: fontSize, weight: .regular)
        attributes[.paragraphStyle] = listStyle
      } else if let match = line.range(of: #"^\d+\. "#, options: .regularExpression) {
        let number = line[match].dropLast(2)
        processedLine = "\(number).  " + String(line[match.upperBound...])
        let listStyle = NSMutableParagraphStyle()
        listStyle.lineHeightMultiple = LessonTypography.LineHeight.normal
        listStyle.paragraphSpacing = LessonTypography.Spacing.xs
        listStyle.headIndent = LessonTypography.Spacing.lg
        listStyle.firstLineHeadIndent = 0
        attributes[.font] = LessonTypography.font(size: fontSize, weight: .regular)
        attributes[.paragraphStyle] = listStyle
      } else if line.hasPrefix("> ") {
        processedLine = String(line.dropFirst(2))
        let quoteStyle = NSMutableParagraphStyle()
        quoteStyle.lineHeightMultiple = LessonTypography.LineHeight.normal
        quoteStyle.paragraphSpacing = LessonTypography.Spacing.sm
        quoteStyle.firstLineHeadIndent = LessonTypography.Spacing.md
        quoteStyle.headIndent = LessonTypography.Spacing.md
        attributes[.font] = UIFont.italicSystemFont(ofSize: fontSize)
        attributes[.foregroundColor] = subtleColor
        attributes[.paragraphStyle] = quoteStyle
      } else if line.hasPrefix("```") {
        continue
      } else {
        attributes[.font] = LessonTypography.font(size: fontSize, weight: .regular)
      }

      let attributedLine = processInlineFormatting(processedLine, baseAttributes: attributes)
      result.append(attributedLine)

      if index < lines.count - 1 {
        result.append(NSAttributedString(string: "\n", attributes: attributes))
      }
    }

    return result
  }

  // Processes inline formatting: bold, italic.
  private static func processInlineFormatting(
    _ text: String,
    baseAttributes: [NSAttributedString.Key: Any]
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    var remaining = text

    while !remaining.isEmpty {
      // Pattern for **bold** text (with closing **).
      if let match = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
        let beforeMatch = String(remaining[..<match.lowerBound])
        if !beforeMatch.isEmpty {
          result.append(processItalic(beforeMatch, baseAttributes: baseAttributes))
        }

        let matchedText = String(remaining[match])
        let boldText = String(matchedText.dropFirst(2).dropLast(2))

        var boldAttributes = baseAttributes
        if let baseFont = baseAttributes[.font] as? UIFont {
          boldAttributes[.font] = LessonTypography.font(size: baseFont.pointSize, weight: .semibold)
        }
        result.append(NSAttributedString(string: boldText, attributes: boldAttributes))
        remaining = String(remaining[match.upperBound...])
        continue
      }

      // Pattern for **text:** without closing ** (common AI output format).
      if let match = remaining.range(of: #"\*\*([^*]+?):\*?\*?\s"#, options: .regularExpression) {
        let beforeMatch = String(remaining[..<match.lowerBound])
        if !beforeMatch.isEmpty {
          result.append(processItalic(beforeMatch, baseAttributes: baseAttributes))
        }

        let matchedText = String(remaining[match])
        var boldText = matchedText.trimmingCharacters(in: .whitespaces)
        if boldText.hasPrefix("**") {
          boldText = String(boldText.dropFirst(2))
        }
        if let colonIndex = boldText.firstIndex(of: ":") {
          boldText = String(boldText[...colonIndex])
        }
        boldText = boldText.replacingOccurrences(of: "**", with: "")

        var boldAttributes = baseAttributes
        if let baseFont = baseAttributes[.font] as? UIFont {
          boldAttributes[.font] = LessonTypography.font(size: baseFont.pointSize, weight: .semibold)
        }
        result.append(NSAttributedString(string: boldText + " ", attributes: boldAttributes))
        remaining = String(remaining[match.upperBound...])
        continue
      }

      result.append(processItalic(remaining, baseAttributes: baseAttributes))
      break
    }

    return result
  }

  // Processes italic (*text*).
  private static func processItalic(
    _ text: String,
    baseAttributes: [NSAttributedString.Key: Any]
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    var remaining = text

    while let match = remaining.range(of: #"(?<!\*)\*([^*]+)\*(?!\*)"#, options: .regularExpression) {
      let beforeMatch = String(remaining[..<match.lowerBound])
      if !beforeMatch.isEmpty {
        result.append(NSAttributedString(string: beforeMatch, attributes: baseAttributes))
      }

      let matchedText = String(remaining[match])
      let italicText = String(matchedText.dropFirst(1).dropLast(1))

      var italicAttributes = baseAttributes
      if let baseFont = baseAttributes[.font] as? UIFont {
        italicAttributes[.font] = UIFont.italicSystemFont(ofSize: baseFont.pointSize)
      }
      result.append(NSAttributedString(string: italicText, attributes: italicAttributes))
      remaining = String(remaining[match.upperBound...])
    }

    if !remaining.isEmpty {
      result.append(NSAttributedString(string: remaining, attributes: baseAttributes))
    }

    return result
  }
}
