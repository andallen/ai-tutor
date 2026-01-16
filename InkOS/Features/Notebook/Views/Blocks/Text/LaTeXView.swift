//
// LaTeXView.swift
// InkOS
//
// Renders LaTeX mathematical expressions using iosMath.
// Uses XITS Math font for fuller, more readable glyphs.
//

import iosMath
import SwiftUI

// MARK: - LaTeXView

// Renders LaTeX mathematical expressions.
// Uses MTMathUILabel from iosMath with XITS Math font.
struct LaTeXView: View {
  let latex: String
  let displayMode: Bool
  let color: String?

  // Font sizes that harmonize with the typography scale.
  private var fontSize: CGFloat {
    displayMode ? 26 : 22
  }

  var body: some View {
    MathLabelRepresentable(
      latex: latex,
      fontSize: fontSize,
      textColor: uiColor,
      displayMode: displayMode
    )
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: displayMode ? .infinity : nil, alignment: displayMode ? .center : .leading)
  }

  private var uiColor: UIColor {
    guard let hexColor = color else {
      return UIColor(NotebookPalette.ink)
    }
    return UIColor(Color(hex: hexColor) ?? NotebookPalette.ink)
  }
}

// MARK: - MathLabelRepresentable

// UIViewRepresentable wrapper for MTMathUILabel.
// Uses XITS Math font which has fuller strokes than Latin Modern.
struct MathLabelRepresentable: UIViewRepresentable {
  let latex: String
  let fontSize: CGFloat
  let textColor: UIColor
  let displayMode: Bool

  func makeUIView(context: Context) -> MTMathUILabel {
    let label = MTMathUILabel()
    label.backgroundColor = .clear
    label.displayErrorInline = false
    configureLabel(label)
    return label
  }

  func updateUIView(_ label: MTMathUILabel, context: Context) {
    configureLabel(label)
  }

  private func configureLabel(_ label: MTMathUILabel) {
    label.latex = latex
    label.textColor = textColor

    // Use XITS Math font - fuller strokes than default Latin Modern.
    label.font = MTFontManager().xitsFont(withSize: fontSize)

    // MTMathUILabelMode: 0 = display, 1 = text
    label.labelMode = displayMode ? MTMathUILabelMode(rawValue: 0)! : MTMathUILabelMode(rawValue: 1)!

    // MTTextAlignment: 0 = left, 1 = center, 2 = right
    label.textAlignment = displayMode ? MTTextAlignment(rawValue: 1)! : MTTextAlignment(rawValue: 0)!
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 24) {
    LaTeXView(latex: "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}", displayMode: true, color: nil)

    LaTeXView(latex: "E = mc^2", displayMode: false, color: nil)

    LaTeXView(
      latex: "\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}",
      displayMode: true,
      color: "#0066CC"
    )

    LaTeXView(latex: "a^2 + b^2 = c^2", displayMode: true, color: nil)
  }
  .padding()
  .background(NotebookPalette.paper)
}
