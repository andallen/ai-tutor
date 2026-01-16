//
// PlainTextView.swift
// InkOS
//
// Renders plain text with TextStyle applied.
// Maps TextSize, TextWeight, and styling options to SwiftUI modifiers.
//

import SwiftUI

// MARK: - PlainTextView

// Renders plain text with optional styling.
struct PlainTextView: View {
  let text: String
  let style: TextStyle?

  var body: some View {
    Text(text)
      .font(font)
      .fontWeight(fontWeight)
      .foregroundColor(foregroundColor)
      .italic(style?.italic ?? false)
      .underline(style?.underline ?? false)
      .strikethrough(style?.strikethrough ?? false)
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

  // Maps TextWeight to SwiftUI Font.Weight.
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

// MARK: - Color Hex Extension

extension Color {
  // Creates a Color from a hex string (e.g., "#FF5733" or "FF5733").
  init?(hex: String) {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

    let length = hexSanitized.count
    if length == 6 {
      let red = Double((rgb & 0xFF0000) >> 16) / 255.0
      let green = Double((rgb & 0x00FF00) >> 8) / 255.0
      let blue = Double(rgb & 0x0000FF) / 255.0
      self.init(red: red, green: green, blue: blue)
    } else if length == 8 {
      let red = Double((rgb & 0xFF00_0000) >> 24) / 255.0
      let green = Double((rgb & 0x00FF_0000) >> 16) / 255.0
      let blue = Double((rgb & 0x0000_FF00) >> 8) / 255.0
      let alpha = Double(rgb & 0x0000_00FF) / 255.0
      self.init(red: red, green: green, blue: blue, opacity: alpha)
    } else {
      return nil
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    PlainTextView(text: "Default body text", style: nil)
    PlainTextView(text: "Large title", style: TextStyle(size: .largeTitle, weight: .bold))
    PlainTextView(text: "Headline", style: TextStyle(size: .headline, weight: .semibold))
    PlainTextView(text: "Caption text", style: TextStyle(size: .caption))
    PlainTextView(text: "Colored text", style: TextStyle(color: "#FF5733"))
    PlainTextView(text: "Italic underline", style: TextStyle(italic: true, underline: true))
  }
  .padding()
}
