// ContentSectionCell.swift
// UICollectionViewCell displaying markdown content sections.

import UIKit

// Cell displaying markdown text content in a lesson.
// Renders basic markdown (headers, bullets, paragraphs).
final class ContentSectionCell: UICollectionViewCell {

  static let reuseIdentifier = "ContentSectionCell"

  // MARK: - UI Elements

  private let contentLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setupViews() {
    contentView.addSubview(contentLabel)

    NSLayoutConstraint.activate([
      contentLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      contentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      contentLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
    ])
  }

  // MARK: - Configuration

  func configure(with section: ContentSection) {
    contentLabel.attributedText = renderMarkdown(section.content)
  }

  // MARK: - Markdown Rendering

  // Renders basic markdown to attributed string.
  private func renderMarkdown(_ text: String) -> NSAttributedString {
    let result = NSMutableAttributedString()

    // Base paragraph style.
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 4
    paragraphStyle.paragraphSpacing = 12

    // Text color.
    let textColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
    let subtleColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)

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
        attributes[.font] = UIFont.systemFont(ofSize: 16, weight: .semibold)
      } else if line.hasPrefix("## ") {
        processedLine = String(line.dropFirst(3))
        attributes[.font] = UIFont.systemFont(ofSize: 18, weight: .semibold)
      } else if line.hasPrefix("# ") {
        processedLine = String(line.dropFirst(2))
        attributes[.font] = UIFont.systemFont(ofSize: 22, weight: .bold)
      } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
        // Bullet point.
        processedLine = "•  " + String(line.dropFirst(2))
        attributes[.font] = UIFont.systemFont(ofSize: 16, weight: .regular)
      } else if let match = line.range(of: #"^\d+\. "#, options: .regularExpression) {
        // Numbered list.
        let number = line[match].dropLast(2)
        processedLine = "\(number).  " + String(line[match.upperBound...])
        attributes[.font] = UIFont.systemFont(ofSize: 16, weight: .regular)
      } else if line.hasPrefix("> ") {
        // Blockquote.
        processedLine = String(line.dropFirst(2))
        attributes[.font] = UIFont.italicSystemFont(ofSize: 16)
        attributes[.foregroundColor] = subtleColor
      } else if line.hasPrefix("```") {
        // Code block marker - skip.
        continue
      } else {
        // Regular paragraph.
        attributes[.font] = UIFont.systemFont(ofSize: 16, weight: .regular)
      }

      // Process inline bold (**text**).
      let attributedLine = processInlineFormatting(processedLine, baseAttributes: attributes)
      result.append(attributedLine)

      // Add newline between lines (except last).
      if index < lines.count - 1 {
        result.append(NSAttributedString(string: "\n", attributes: attributes))
      }
    }

    return result
  }

  // Processes inline bold and italic formatting.
  private func processInlineFormatting(
    _ text: String,
    baseAttributes: [NSAttributedString.Key: Any]
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    var remaining = text

    // Pattern for **bold** text.
    let boldPattern = #"\*\*(.+?)\*\*"#

    while let match = remaining.range(of: boldPattern, options: .regularExpression) {
      // Add text before match.
      let beforeMatch = String(remaining[..<match.lowerBound])
      if !beforeMatch.isEmpty {
        result.append(NSAttributedString(string: beforeMatch, attributes: baseAttributes))
      }

      // Extract bold text (remove ** markers).
      let matchedText = String(remaining[match])
      let boldText = String(matchedText.dropFirst(2).dropLast(2))

      // Add bold text.
      var boldAttributes = baseAttributes
      if let baseFont = baseAttributes[.font] as? UIFont {
        boldAttributes[.font] = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
      }
      result.append(NSAttributedString(string: boldText, attributes: boldAttributes))

      // Continue with remaining text.
      remaining = String(remaining[match.upperBound...])
    }

    // Add any remaining text.
    if !remaining.isEmpty {
      result.append(NSAttributedString(string: remaining, attributes: baseAttributes))
    }

    return result
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    contentLabel.attributedText = nil
  }
}
