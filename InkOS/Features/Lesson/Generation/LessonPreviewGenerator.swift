//
// LessonPreviewGenerator.swift
// InkOS
//
// Generates preview images for lessons to display on the dashboard.
// Renders lesson title and first content section as an image.
//

import UIKit

// Generates preview thumbnail images for lessons.
// Renders the lesson title and first content section as a visual preview.
struct LessonPreviewGenerator {

  // Size of the generated preview image.
  private let previewSize: CGSize

  // Padding around the content.
  private let padding: CGFloat = 16

  // Creates a preview generator with the specified preview size.
  // Default size matches the aspect ratio and resolution used for notebook previews.
  init(previewSize: CGSize = CGSize(width: 400, height: 556)) {
    self.previewSize = previewSize
  }

  // Generates a preview image for the given lesson.
  // Returns PNG data of the rendered preview.
  func generatePreview(for lesson: Lesson) -> Data? {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 2.0

    let renderer = UIGraphicsImageRenderer(size: previewSize, format: format)

    let image = renderer.image { context in
      let cgContext = context.cgContext
      let rect = CGRect(origin: .zero, size: previewSize)

      // Fill background with white.
      UIColor.white.setFill()
      cgContext.fill(rect)

      // Calculate content area with padding.
      let contentRect = rect.insetBy(dx: padding, dy: padding)

      // Draw the title.
      let titleRect = drawTitle(lesson.title, in: contentRect, context: cgContext)

      // Draw a subtle separator line.
      let separatorY = titleRect.maxY + 12
      drawSeparator(at: separatorY, in: contentRect, context: cgContext)

      // Draw the first content section.
      let contentStartY = separatorY + 16
      if let firstContentSection = findFirstContentSection(in: lesson.sections) {
        let contentArea = CGRect(
          x: contentRect.minX,
          y: contentStartY,
          width: contentRect.width,
          height: contentRect.maxY - contentStartY
        )
        drawContentPreview(firstContentSection.content, in: contentArea)
      }
    }

    return image.pngData()
  }

  // MARK: - Private Drawing Methods

  // Draws the lesson title and returns the bounding rect.
  private func drawTitle(_ title: String, in rect: CGRect, context: CGContext) -> CGRect {
    let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
    let titleColor = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1.0) // Color.ink

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
      .font: titleFont,
      .foregroundColor: titleColor,
      .paragraphStyle: paragraphStyle
    ]

    let maxTitleHeight = rect.height * 0.25
    let titleSize = CGSize(width: rect.width, height: maxTitleHeight)
    let boundingRect = (title as NSString).boundingRect(
      with: titleSize,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    )

    let titleRect = CGRect(
      x: rect.minX,
      y: rect.minY,
      width: boundingRect.width,
      height: min(boundingRect.height, maxTitleHeight)
    )

    (title as NSString).draw(in: titleRect, withAttributes: attributes)

    return titleRect
  }

  // Draws a subtle separator line.
  private func drawSeparator(at y: CGFloat, in rect: CGRect, context: CGContext) {
    let separatorColor = UIColor(red: 0.92, green: 0.92, blue: 0.93, alpha: 1.0)
    context.setStrokeColor(separatorColor.cgColor)
    context.setLineWidth(1.0)
    context.move(to: CGPoint(x: rect.minX, y: y))
    context.addLine(to: CGPoint(x: rect.maxX, y: y))
    context.strokePath()
  }

  // Draws content preview text.
  private func drawContentPreview(_ content: String, in rect: CGRect) {
    // Strip markdown formatting for cleaner preview.
    let cleanContent = stripMarkdown(content)

    let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    let contentColor = UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0) // Subtle gray

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.lineSpacing = 4

    let attributes: [NSAttributedString.Key: Any] = [
      .font: contentFont,
      .foregroundColor: contentColor,
      .paragraphStyle: paragraphStyle
    ]

    (cleanContent as NSString).draw(in: rect, withAttributes: attributes)
  }

  // Finds the first content section in the lesson.
  private func findFirstContentSection(in sections: [LessonSection]) -> ContentSection? {
    for section in sections {
      if case .content(let contentSection) = section {
        return contentSection
      }
    }
    return nil
  }

  // Strips common markdown formatting for cleaner display.
  private func stripMarkdown(_ text: String) -> String {
    var result = text

    // Remove headers (## Header).
    result = result.replacingOccurrences(
      of: "#{1,6}\\s*",
      with: "",
      options: .regularExpression
    )

    // Remove bold (**text**).
    result = result.replacingOccurrences(
      of: "\\*\\*([^*]+)\\*\\*",
      with: "$1",
      options: .regularExpression
    )

    // Remove italic (*text*).
    result = result.replacingOccurrences(
      of: "\\*([^*]+)\\*",
      with: "$1",
      options: .regularExpression
    )

    // Remove inline code (`code`).
    result = result.replacingOccurrences(
      of: "`([^`]+)`",
      with: "$1",
      options: .regularExpression
    )

    // Remove links [text](url).
    result = result.replacingOccurrences(
      of: "\\[([^\\]]+)\\]\\([^)]+\\)",
      with: "$1",
      options: .regularExpression
    )

    // Remove bullet points (- item).
    result = result.replacingOccurrences(
      of: "^\\s*[-*+]\\s+",
      with: "",
      options: .regularExpression
    )

    // Collapse multiple newlines.
    result = result.replacingOccurrences(
      of: "\n{3,}",
      with: "\n\n",
      options: .regularExpression
    )

    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
