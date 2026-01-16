//
// TypewriterAnimationView.swift
// InkOS
//
// Character-by-character text reveal animation.
// Uses AttributedString with per-character opacity for proper multi-line support.
//

import SwiftUI

// MARK: - TypewriterAnimationView

// Reveals text character by character using per-character opacity.
// Works correctly with multi-line text since layout is handled by the text engine.
struct TypewriterAnimationView: View {
  let text: String
  let progress: Double
  let style: TextStyle?

  // Number of characters to use for soft fade edge.
  private let fadeCharacters = 3

  var body: some View {
    Text(attributedText)
      .font(font)
      .fontWeight(fontWeight)
      .italic(style?.italic ?? false)
      .underline(style?.underline ?? false)
      .strikethrough(style?.strikethrough ?? false)
  }

  // Builds AttributedString with per-character opacity based on progress.
  private var attributedText: AttributedString {
    var attributed = AttributedString(text)
    let characters = Array(text)
    let totalCharacters = characters.count

    guard totalCharacters > 0 else { return attributed }

    // Calculate reveal position with fractional precision.
    let revealPosition = progress * Double(totalCharacters + fadeCharacters)

    // Apply opacity to each character.
    var currentIndex = attributed.startIndex
    for i in 0..<totalCharacters {
      let nextIndex = attributed.index(afterCharacter: currentIndex)
      let range = currentIndex..<nextIndex

      // Calculate opacity for this character.
      let characterPosition = Double(i)
      let opacity: Double

      if characterPosition < revealPosition - Double(fadeCharacters) {
        // Fully revealed.
        opacity = 1.0
      } else if characterPosition < revealPosition {
        // In the fade zone.
        opacity = (revealPosition - characterPosition) / Double(fadeCharacters)
      } else {
        // Not yet revealed.
        opacity = 0.0
      }

      // Apply foreground color with opacity.
      attributed[range].foregroundColor = foregroundColor.opacity(opacity)

      currentIndex = nextIndex
    }

    return attributed
  }

  // Maps TextSize to SwiftUI Font from the typography scale.
  private var font: Font {
    guard let size = style?.size else { return NotebookTypography.body }
    switch size {
    case .caption: return NotebookTypography.caption
    case .body: return NotebookTypography.body
    case .headline: return NotebookTypography.headline
    case .title: return NotebookTypography.title
    case .largeTitle: return NotebookTypography.display
    }
  }

  private var fontWeight: Font.Weight? {
    guard let weight = style?.weight else { return nil }
    switch weight {
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    }
  }

  // Maps hex color string to SwiftUI Color, defaulting to notebook ink.
  private var foregroundColor: Color {
    guard let hexColor = style?.color else { return NotebookPalette.ink }
    return Color(hex: hexColor) ?? NotebookPalette.ink
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 20) {
    TypewriterAnimationView(text: "Hello, World!", progress: 0.0, style: nil)
    TypewriterAnimationView(text: "Hello, World!", progress: 0.5, style: nil)
    TypewriterAnimationView(text: "Hello, World!", progress: 1.0, style: nil)
  }
  .padding()
}
