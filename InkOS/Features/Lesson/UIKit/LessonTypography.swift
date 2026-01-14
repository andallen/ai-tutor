// LessonTypography.swift
// Centralized typography system for lesson content.
// Defines type scale, colors, spacing, and font styles for consistent visual design.

import UIKit

// Typography system for lesson presentation.
// Uses a 1.25 ratio (major third) modular scale for harmonious type relationships.
enum LessonTypography {

  // MARK: - Type Scale (1.25 ratio)

  // Base size for body text.
  static let baseSize: CGFloat = 18

  // Modular scale values.
  enum Size {
    static let overline: CGFloat = 12    // ÷1.5 - metadata, labels
    static let caption: CGFloat = 14     // ÷1.25 - captions, small text
    static let body: CGFloat = 18        // base - main content
    static let lead: CGFloat = 20        // intro paragraphs
    static let h3: CGFloat = 22          // ×1.25 - subheadings
    static let h2: CGFloat = 28          // ×1.56 - section titles
    static let h1: CGFloat = 36          // ×2 - lesson title
  }

  // MARK: - Line Heights

  // Line height multipliers for different content types.
  enum LineHeight {
    static let tight: CGFloat = 1.2      // Headers, display text
    static let normal: CGFloat = 1.5     // Body text, optimal for reading
    static let relaxed: CGFloat = 1.6    // Long-form content
  }

  // MARK: - Spacing (8pt baseline grid)

  enum Spacing {
    static let xxs: CGFloat = 4          // Micro spacing
    static let xs: CGFloat = 8           // Tight spacing
    static let sm: CGFloat = 12          // Small gaps
    static let md: CGFloat = 16          // Medium spacing
    static let lg: CGFloat = 24          // Paragraph spacing
    static let xl: CGFloat = 32          // Section spacing
    static let xxl: CGFloat = 48         // Large section gaps
  }

  // MARK: - Colors (Neutral palette - no blue or cream)

  enum Color {
    // Page background - very subtle warm off-white to reduce eye strain.
    static let background = UIColor(red: 0.992, green: 0.988, blue: 0.980, alpha: 1.0)  // #FDF9F5

    // Text colors - warm neutral grays.
    static let primary = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1.0)        // #1F1F21
    static let secondary = UIColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1.0)      // #59595E
    static let tertiary = UIColor(red: 0.55, green: 0.55, blue: 0.56, alpha: 1.0)       // #8C8C8F
    static let subtle = UIColor(red: 0.70, green: 0.70, blue: 0.71, alpha: 1.0)         // #B3B3B5

    // Accent color - neutral dark gray instead of blue.
    static let accent = UIColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)         // #333338

    // Semantic colors - muted versions.
    static let success = UIColor(red: 0.22, green: 0.52, blue: 0.35, alpha: 1.0)        // #388559
    static let warning = UIColor(red: 0.70, green: 0.50, blue: 0.20, alpha: 1.0)        // #B38033
    static let error = UIColor(red: 0.70, green: 0.25, blue: 0.25, alpha: 1.0)          // #B34040

    // Surface colors - neutral grays.
    static let cardBackground = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0) // #F8F8F8
    static let summaryBackground = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) // #F2F2F2
    static let questionBackground = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0) // #FAFAFA
    static let correctBackground = UIColor(red: 0.94, green: 0.97, blue: 0.95, alpha: 1.0) // #F0F8F2
    static let incorrectBackground = UIColor(red: 0.98, green: 0.95, blue: 0.95, alpha: 1.0) // #FAF2F2

    // Border colors - neutral.
    static let border = UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)         // #E0E0E0
    static let borderSelected = UIColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0) // #333338
  }

  // MARK: - Font Styles

  // Creates a font with the specified size and weight.
  static func font(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
    return UIFont.systemFont(ofSize: size, weight: weight)
  }

  // Creates rounded font for friendly headers.
  static func roundedFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
    let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
    if let rounded = descriptor.withDesign(.rounded) {
      return UIFont(descriptor: rounded, size: size)
    }
    return UIFont.systemFont(ofSize: size, weight: weight)
  }

  // Creates serif font for elegant body text (New York on iOS).
  static func serifFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
    let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
    if let serif = descriptor.withDesign(.serif) {
      return UIFont(descriptor: serif, size: size)
    }
    return UIFont.systemFont(ofSize: size, weight: weight)
  }

  // MARK: - Paragraph Styles

  // Creates a paragraph style for body text.
  static func bodyParagraphStyle() -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.lineHeightMultiple = LineHeight.normal
    style.paragraphSpacing = Spacing.lg
    return style
  }

  // Creates a paragraph style for headers.
  static func headerParagraphStyle() -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.lineHeightMultiple = LineHeight.tight
    style.paragraphSpacing = Spacing.sm
    return style
  }

  // Creates a paragraph style for lists with proper indentation.
  static func listParagraphStyle(indent: CGFloat = 24) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.lineHeightMultiple = LineHeight.normal
    style.paragraphSpacing = Spacing.xs
    style.headIndent = indent
    style.firstLineHeadIndent = 0
    style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
    return style
  }

  // MARK: - Preset Text Styles

  // Lesson title style.
  static func titleAttributes() -> [NSAttributedString.Key: Any] {
    return [
      .font: roundedFont(size: Size.h1, weight: .bold),
      .foregroundColor: Color.primary,
      .paragraphStyle: headerParagraphStyle()
    ]
  }

  // Subject/category overline style.
  static func overlineAttributes() -> [NSAttributedString.Key: Any] {
    let font = font(size: Size.overline, weight: .semibold)
    return [
      .font: font,
      .foregroundColor: Color.secondary,
      .kern: 1.5  // Letter spacing for all-caps
    ]
  }

  // Section heading style.
  static func headingAttributes() -> [NSAttributedString.Key: Any] {
    return [
      .font: font(size: Size.h3, weight: .semibold),
      .foregroundColor: Color.primary,
      .paragraphStyle: headerParagraphStyle()
    ]
  }

  // Body text style.
  static func bodyAttributes() -> [NSAttributedString.Key: Any] {
    return [
      .font: font(size: Size.body, weight: .regular),
      .foregroundColor: Color.primary,
      .paragraphStyle: bodyParagraphStyle()
    ]
  }

  // Lead paragraph style (slightly larger intro text).
  static func leadAttributes() -> [NSAttributedString.Key: Any] {
    return [
      .font: font(size: Size.lead, weight: .regular),
      .foregroundColor: Color.secondary,
      .paragraphStyle: bodyParagraphStyle()
    ]
  }

  // Caption/label style.
  static func captionAttributes() -> [NSAttributedString.Key: Any] {
    return [
      .font: font(size: Size.caption, weight: .medium),
      .foregroundColor: Color.tertiary
    ]
  }

  // Bold text style (preserves base attributes).
  static func boldAttributes(basedOn base: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
    var result = base
    if let font = base[.font] as? UIFont {
      result[.font] = UIFont.systemFont(ofSize: font.pointSize, weight: .semibold)
    }
    return result
  }

  // Italic text style (preserves base attributes).
  static func italicAttributes(basedOn base: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
    var result = base
    if let font = base[.font] as? UIFont {
      result[.font] = UIFont.italicSystemFont(ofSize: font.pointSize)
    }
    return result
  }

  // MARK: - Corner Radii

  enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
  }

  // MARK: - Shadows

  // Subtle card shadow.
  static func applyCardShadow(to layer: CALayer) {
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOffset = CGSize(width: 0, height: 2)
    layer.shadowRadius = 8
    layer.shadowOpacity = 0.04
  }
}
