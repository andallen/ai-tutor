// MathContentView.swift
// View for rendering mixed text and LaTeX math content.
// Uses iosMath for proper LaTeX rendering with inline math support.

import iosMath
import UIKit

// View that renders markdown text with embedded LaTeX math.
// Supports inline math ($...$) and display math ($$...$$).
final class MathContentView: UIView {

  // Stack for display math blocks that need full-width rendering.
  private let contentStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = LessonTypography.Spacing.sm
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  // Configuration for text rendering.
  var fontSize: CGFloat = LessonTypography.Size.body {
    didSet { setNeedsLayout() }
  }

  var textColor: UIColor = LessonTypography.Color.primary {
    didSet { setNeedsLayout() }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    addSubview(contentStack)
    NSLayoutConstraint.activate([
      contentStack.topAnchor.constraint(equalTo: topAnchor),
      contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
      contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
      contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }

  // Configures the view with content containing markdown and LaTeX.
  func configure(with content: String) {
    // Clear previous content.
    contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

    // Split content into blocks (paragraphs and display math).
    let blocks = parseBlocks(content)

    for block in blocks {
      switch block {
      case let .text(text):
        let label = createTextLabel(text)
        contentStack.addArrangedSubview(label)

      case let .displayMath(latex):
        let mathView = createDisplayMathView(latex)
        contentStack.addArrangedSubview(mathView)
      }
    }
  }

  // MARK: - Parsing

  private enum ContentBlock {
    case text(String)
    case displayMath(String)
  }

  // Parses content into text blocks and display math blocks.
  private func parseBlocks(_ content: String) -> [ContentBlock] {
    var blocks: [ContentBlock] = []
    var remaining = content

    // Pattern for display math $$...$$.
    let displayPattern = #"\$\$([^$]+)\$\$"#

    while !remaining.isEmpty {
      if let match = remaining.range(of: displayPattern, options: .regularExpression) {
        // Add text before display math.
        let textBefore = String(remaining[..<match.lowerBound])
        if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          blocks.append(.text(textBefore))
        }

        // Add display math block.
        let matchedText = String(remaining[match])
        let latex = String(matchedText.dropFirst(2).dropLast(2))
        blocks.append(.displayMath(latex))

        remaining = String(remaining[match.upperBound...])
      } else {
        // No more display math, add remaining text.
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          blocks.append(.text(remaining))
        }
        break
      }
    }

    return blocks
  }

  // MARK: - View Creation

  // Creates a label for text content with inline math rendered as images.
  private func createTextLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.numberOfLines = 0
    label.attributedText = renderTextWithInlineMath(text)
    return label
  }

  // Creates a centered math view for display math.
  private func createDisplayMathView(_ latex: String) -> UIView {
    let container = UIView()
    container.backgroundColor = LessonTypography.Color.cardBackground

    let mathLabel = MTMathUILabel()
    mathLabel.latex = latex
    mathLabel.fontSize = fontSize + 2
    mathLabel.textColor = textColor
    mathLabel.textAlignment = .center
    mathLabel.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(mathLabel)
    NSLayoutConstraint.activate([
      mathLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: LessonTypography.Spacing.md),
      mathLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -LessonTypography.Spacing.md),
      mathLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      mathLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: LessonTypography.Spacing.md),
      mathLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -LessonTypography.Spacing.md)
    ])

    container.layer.cornerRadius = LessonTypography.CornerRadius.small
    container.clipsToBounds = true

    return container
  }

  // MARK: - Inline Math Rendering

  // Renders text with inline math expressions as image attachments.
  private func renderTextWithInlineMath(_ text: String) -> NSAttributedString {
    let result = NSMutableAttributedString()

    // First process markdown without math.
    let textWithoutMath = processMarkdownStructure(text)

    // Then find and replace inline math with rendered images.
    let remaining = textWithoutMath as NSString
    var currentIndex = 0

    // Pattern for inline math $...$ (not $$).
    let inlinePattern = #"(?<!\$)\$(?!\$)([^$]+)\$(?!\$)"#

    while currentIndex < remaining.length {
      let searchRange = NSRange(location: currentIndex, length: remaining.length - currentIndex)

      if let match = remaining.range(
        of: inlinePattern,
        options: .regularExpression,
        range: searchRange
      ).toOptional(), match.location != NSNotFound {

        // Add text before math.
        if match.location > currentIndex {
          let textRange = NSRange(location: currentIndex, length: match.location - currentIndex)
          let textBefore = remaining.substring(with: textRange)
          result.append(renderMarkdown(textBefore))
        }

        // Render math as image attachment.
        let matchedText = remaining.substring(with: match)
        let latex = String(matchedText.dropFirst(1).dropLast(1))
        if let attachment = createMathAttachment(latex) {
          result.append(NSAttributedString(attachment: attachment))
        } else {
          // Fallback: show styled text if rendering fails.
          let fallbackAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: fontSize),
            .foregroundColor: LessonTypography.Color.accent
          ]
          result.append(NSAttributedString(string: latex, attributes: fallbackAttrs))
        }

        currentIndex = match.location + match.length
      } else {
        // No more inline math, add remaining text.
        let textRange = NSRange(location: currentIndex, length: remaining.length - currentIndex)
        let remainingText = remaining.substring(with: textRange)
        result.append(renderMarkdown(remainingText))
        break
      }
    }

    return result
  }

  // Creates an NSTextAttachment containing the rendered math.
  private func createMathAttachment(_ latex: String) -> NSTextAttachment? {
    let mathLabel = MTMathUILabel()
    mathLabel.latex = latex
    mathLabel.fontSize = fontSize
    mathLabel.textColor = textColor

    // Size the math label.
    let size = mathLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: fontSize * 2))
    mathLabel.frame = CGRect(origin: .zero, size: size)

    // Render to image with correct orientation.
    // iosMath uses Core Graphics internally which has flipped coordinates.
    // We flip the context before rendering to correct this.
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
      let cgContext = context.cgContext
      // Flip the coordinate system.
      cgContext.translateBy(x: 0, y: size.height)
      cgContext.scaleBy(x: 1.0, y: -1.0)
      mathLabel.layer.render(in: cgContext)
    }

    let attachment = NSTextAttachment()
    attachment.image = image

    // Adjust vertical alignment to baseline.
    let yOffset = (fontSize - size.height) / 2 - fontSize * 0.1
    attachment.bounds = CGRect(x: 0, y: yOffset, width: size.width, height: size.height)

    return attachment
  }

  // Processes markdown structure (headers, bullets, etc.) preserving inline math.
  private func processMarkdownStructure(_ text: String) -> String {
    var result: [String] = []

    for line in text.components(separatedBy: "\n") {
      var processedLine = line

      // Handle headers.
      if line.hasPrefix("### ") {
        processedLine = String(line.dropFirst(4))
      } else if line.hasPrefix("## ") {
        processedLine = String(line.dropFirst(3))
      } else if line.hasPrefix("# ") {
        processedLine = String(line.dropFirst(2))
      } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
        processedLine = "•  " + String(line.dropFirst(2))
      } else if let match = line.range(of: #"^\d+\. "#, options: .regularExpression) {
        let number = line[match].dropLast(2)
        processedLine = "\(number).  " + String(line[match.upperBound...])
      } else if line.hasPrefix("> ") {
        processedLine = String(line.dropFirst(2))
      } else if line.hasPrefix("```") {
        continue
      }

      result.append(processedLine)
    }

    return result.joined(separator: "\n")
  }

  // Renders markdown text (bold, italic) to attributed string.
  private func renderMarkdown(_ text: String) -> NSAttributedString {
    return MarkdownRenderer.render(text, fontSize: fontSize)
  }

  // Clears the content.
  func clear() {
    contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
  }
}

// Helper extension for NSRange to Optional conversion.
private extension NSRange {
  func toOptional() -> NSRange? {
    return location != NSNotFound ? self : nil
  }
}
