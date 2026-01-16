//
// NotebookDesignTokens.swift
// InkOS
//
// Design tokens for the notebook renderer.
// Single source of truth for typography, spacing, and layout values.
// See Docs/NotebookDesignSystem.md for rationale and usage guidelines.
//
// Key concepts:
// - Typography scale: display → title → headline → body → caption
// - Spacing scale: xs → sm → md → lg → xl → xxl (based on 8pt grid)
// - Block roles: display, section, content, interactive (determines trailing space)
// - Segment rendering: plain segments flow inline; kinetic/latex/code are block-level
//

import SwiftUI

// MARK: - NotebookPalette

// Color palette for the notebook.
// Refined neutral tones that feel clean without being cold.
enum NotebookPalette {
  // Background: soft off-white, neutral with slight warmth.
  static let paper = Color(red: 0.97, green: 0.97, blue: 0.96)

  // Primary text: soft charcoal, not pure black.
  static let ink = Color(red: 0.12, green: 0.11, blue: 0.10)

  // Secondary text: for captions, hints.
  static let inkSubtle = Color(red: 0.35, green: 0.33, blue: 0.31)

  // Faint text: for placeholders, disabled states.
  static let inkFaint = Color(red: 0.55, green: 0.53, blue: 0.50)
}

// MARK: - NotebookTypography

// Single-scale typography system.
// Walk down the scale: Display → Title → Headline → Body → Caption.
// Only Display uses SF Pro Rounded. Everything else uses Nunito.
//
// Level 1: Display   28pt  SF Pro Rounded Bold
// Level 2: Title     22pt  Nunito Bold
// Level 3: Headline  19pt  Nunito Semibold
// Level 4: Body      17pt  Nunito Regular
// Level 5: Caption   13pt  Nunito Regular
//
enum NotebookTypography {

  // MARK: - Font Configuration

  // Nunito variable font name.
  static let nunitoFontName = "Nunito"

  // Tighter tracking for Nunito.
  static let nunitoTracking: CGFloat = -0.3

  // MARK: - The Scale

  // Level 1: Display - Big dramatic reveals. SF Pro Rounded for maximum impact.
  static let display = Font.system(size: 28, weight: .bold, design: .rounded)

  // Level 2: Title - Section openers.
  static var title: Font {
    nunitoFont(size: 22, weight: .bold)
  }

  // Level 3: Headline - Subsection markers.
  static var headline: Font {
    nunitoFont(size: 19, weight: .semibold)
  }

  // Level 4: Body - The bulk of reading.
  static var body: Font {
    nunitoFont(size: 17, weight: .regular)
  }

  // Level 5: Caption - Secondary information.
  static var caption: Font {
    nunitoFont(size: 13, weight: .regular)
  }

  // MARK: - Nunito Font Helper

  static func nunitoFont(size: CGFloat, weight: Font.Weight) -> Font {
    if let uiFont = UIFont(name: nunitoFontName, size: size) {
      let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: uiFontWeight(from: weight)]
      let descriptor = uiFont.fontDescriptor.addingAttributes([.traits: traits])
      return Font(UIFont(descriptor: descriptor, size: size))
    }
    return Font.system(size: size, weight: weight, design: .rounded)
  }

  private static func uiFontWeight(from weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .ultraLight: return .ultraLight
    case .thin: return .thin
    case .light: return .light
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    case .black: return .black
    default: return .regular
    }
  }

  // MARK: - UIFont Versions (for iosMath and UIKit)

  static func nunitoUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
    if let font = UIFont(name: nunitoFontName, size: size) {
      let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: weight]
      let descriptor = font.fontDescriptor.addingAttributes([.traits: traits])
      return UIFont(descriptor: descriptor, size: size)
    }
    return UIFont.systemFont(ofSize: size, weight: weight)
  }

  static var bodyUIFont: UIFont {
    nunitoUIFont(size: 17, weight: .regular)
  }
}

// MARK: - NotebookSpacing

// Spacing scale for vertical rhythm.
// Generous proportions create gravitas and breathing room.
// Based on 8pt grid with purposeful jumps.
enum NotebookSpacing {
  // Base unit. All spacing derives from this.
  static let unit: CGFloat = 8

  // Spacing values - generous for a refined, unhurried feel.
  static let xs: CGFloat = 12   // Tight: related inline elements.
  static let sm: CGFloat = 20   // Compact: lines within a paragraph.
  static let md: CGFloat = 32   // Standard: between body blocks.
  static let lg: CGFloat = 48   // Generous: after headlines, before sections.
  static let xl: CGFloat = 72   // Dramatic: after display text, major reveals.
  static let xxl: CGFloat = 96  // Pause: checkpoints, section breaks.
}

// MARK: - BlockSpacing

// Spacing rules based on block role.
// The role determines how much breathing room follows the block.
enum BlockRole {
  // Display: Big dramatic reveals. Needs significant pause after.
  case display
  // Section: Headlines and section openers. Needs moderate pause.
  case section
  // Content: Body text, math, explanations. Standard rhythm.
  case content
  // Interactive: Checkpoints, inputs. Has its own internal padding.
  case interactive
}

// Spacing before and after each block role.
// Headings get more space BEFORE (separating from previous content)
// and less space AFTER (connecting to the content they introduce).
enum BlockSpacing {
  // Space before a block based on its role.
  // Headings need breathing room above to separate from previous content.
  static func before(_ role: BlockRole) -> CGFloat {
    switch role {
    case .display:
      return NotebookSpacing.xl
    case .section:
      return NotebookSpacing.lg
    case .content:
      return 0
    case .interactive:
      return NotebookSpacing.md
    }
  }

  // Space after a block based on its role.
  // Headings get small space to stay connected to following content.
  static func after(_ role: BlockRole) -> CGFloat {
    switch role {
    case .display:
      return NotebookSpacing.sm
    case .section:
      return NotebookSpacing.sm
    case .content:
      return NotebookSpacing.md
    case .interactive:
      return NotebookSpacing.md
    }
  }
}

// MARK: - TextStyle to BlockRole Mapping

extension TextStyle {
  // Determines the block role based on text styling.
  // Used to calculate appropriate trailing spacing.
  var blockRole: BlockRole {
    switch size {
    case .largeTitle:
      return .display
    case .title:
      return .section
    case .headline:
      return .section
    case .body, .caption:
      return .content
    case .none:
      return .content
    }
  }
}

// MARK: - TextContent to BlockRole Mapping

extension TextContent {
  // Determines the dominant block role for spacing purposes.
  // Looks at all segments and returns the highest-priority role.
  // Priority: display > section > content.
  var dominantRole: BlockRole {
    var highestRole: BlockRole = .content

    for segment in segments {
      let segmentRole: BlockRole
      switch segment {
      case .plain(_, let style):
        segmentRole = style?.blockRole ?? .content
      case .kinetic(_, _, _, _, let style):
        segmentRole = style?.blockRole ?? .content
      case .latex(_, let displayMode, _):
        // Display-mode LaTeX is section-level (centered equations).
        segmentRole = displayMode ? .section : .content
      case .code, .pause:
        segmentRole = .content
      }

      // Upgrade if this segment has higher priority.
      if segmentRole == .display {
        return .display  // Can't go higher.
      } else if segmentRole == .section && highestRole == .content {
        highestRole = .section
      }
    }

    return highestRole
  }
}

// MARK: - NotebookLayout

// Layout constants for the canvas.
enum NotebookLayout {
  // Horizontal padding from screen edge.
  // Wider on iPad (regular), narrower on compact.
  static let horizontalPaddingRegular: CGFloat = 120
  static let horizontalPaddingCompact: CGFloat = 60

  // Top padding before first block.
  static let topPadding: CGFloat = 100

  // Bottom padding after last block.
  static let bottomPadding: CGFloat = 80

  // Maximum content width for readability.
  // Text lines shouldn't exceed ~70 characters.
  static let maxContentWidth: CGFloat = 680
}
