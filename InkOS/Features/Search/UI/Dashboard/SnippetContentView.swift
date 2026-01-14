import SwiftUI

// View for rendering search result snippets with mixed text, markdown, and LaTeX content.
// Parses snippet text and renders:
// - LaTeX expressions (between $ or $$) converted to Unicode (x² instead of x^2)
// - Markdown formatting (bold, italic, code) stripped but content preserved
// - Match highlighting (between [MATCH] and [/MATCH]) with emphasis
struct SnippetContentView: View {
  // The raw snippet text to render.
  let snippet: String
  // Font size for text content.
  var fontSize: CGFloat = 13
  // Color for regular text.
  var textColor: Color = .secondary
  // Color for highlighted match text.
  var highlightColor: Color = .primary

  var body: some View {
    Text(formattedSnippet())
  }

  // Parses and formats the snippet into an AttributedString.
  private func formattedSnippet() -> AttributedString {
    let segments = SnippetParser.parse(snippet)
    return SnippetRenderer.render(
      segments: segments,
      fontSize: fontSize,
      textColor: textColor,
      highlightColor: highlightColor
    )
  }
}

// MARK: - Segment Types

// Represents a segment of parsed snippet content.
enum SnippetSegment {
  // Plain text segment.
  case text(content: String, isHighlighted: Bool)
  // LaTeX math segment (converted to Unicode).
  case math(unicode: String, isHighlighted: Bool)
}

// MARK: - Snippet Parser

// Parses raw snippet text into typed segments.
enum SnippetParser {

  // Parses snippet into segments, handling match markers and LaTeX delimiters.
  static func parse(_ snippet: String) -> [SnippetSegment] {
    var segments: [SnippetSegment] = []
    var remaining = snippet[...]
    var currentHighlight = false

    while !remaining.isEmpty {
      // When inside a highlighted region, look for end marker first.
      // This prevents finding a later start marker before the current end marker.
      if currentHighlight {
        if let matchEnd = remaining.range(of: SearchIndexConstants.matchEndMarker) {
          // Add text before marker as highlighted.
          let beforeText = String(remaining[..<matchEnd.lowerBound])
          if !beforeText.isEmpty {
            segments.append(contentsOf: parseInlineContent(beforeText, isHighlighted: true))
          }
          remaining = remaining[matchEnd.upperBound...]
          currentHighlight = false
          continue
        }
        // No end marker found - treat rest as highlighted.
        let remainingText = String(remaining)
        segments.append(contentsOf: parseInlineContent(remainingText, isHighlighted: true))
        break
      }

      // When outside highlighted region, look for start marker.
      if let matchStart = remaining.range(of: SearchIndexConstants.matchStartMarker) {
        // Add text before marker as non-highlighted.
        let beforeText = String(remaining[..<matchStart.lowerBound])
        if !beforeText.isEmpty {
          segments.append(contentsOf: parseInlineContent(beforeText, isHighlighted: false))
        }
        remaining = remaining[matchStart.upperBound...]
        currentHighlight = true
        continue
      }

      // No more markers, add remaining content.
      let remainingText = String(remaining)
      segments.append(contentsOf: parseInlineContent(remainingText, isHighlighted: false))
      break
    }

    return segments
  }

  // Parses inline content for LaTeX math expressions.
  private static func parseInlineContent(_ text: String, isHighlighted: Bool) -> [SnippetSegment] {
    var segments: [SnippetSegment] = []
    var remaining = text[...]

    while !remaining.isEmpty {
      // Check for display math ($$...$$) first.
      if let displayStart = remaining.range(of: "$$") {
        // Add text before math.
        let beforeText = String(remaining[..<displayStart.lowerBound])
        if !beforeText.isEmpty {
          segments.append(.text(content: stripMarkdown(beforeText), isHighlighted: isHighlighted))
        }
        remaining = remaining[displayStart.upperBound...]

        // Find closing $$.
        if let displayEnd = remaining.range(of: "$$") {
          let latex = String(remaining[..<displayEnd.lowerBound])
          let unicode = LaTeXConverter.toUnicode(latex)
          segments.append(.math(unicode: unicode, isHighlighted: isHighlighted))
          remaining = remaining[displayEnd.upperBound...]
        } else {
          // No closing marker, treat as text.
          segments.append(.text(content: "$$" + String(remaining), isHighlighted: isHighlighted))
          break
        }
        continue
      }

      // Check for inline math ($...$).
      if let inlineStart = remaining.range(of: "$") {
        // Add text before math.
        let beforeText = String(remaining[..<inlineStart.lowerBound])
        if !beforeText.isEmpty {
          segments.append(.text(content: stripMarkdown(beforeText), isHighlighted: isHighlighted))
        }
        remaining = remaining[inlineStart.upperBound...]

        // Find closing $.
        if let inlineEnd = remaining.range(of: "$") {
          let latex = String(remaining[..<inlineEnd.lowerBound])
          let unicode = LaTeXConverter.toUnicode(latex)
          segments.append(.math(unicode: unicode, isHighlighted: isHighlighted))
          remaining = remaining[inlineEnd.upperBound...]
        } else {
          // No closing marker, treat as text.
          segments.append(.text(content: "$" + String(remaining), isHighlighted: isHighlighted))
          break
        }
        continue
      }

      // No math markers, add remaining as text.
      segments.append(.text(content: stripMarkdown(String(remaining)), isHighlighted: isHighlighted))
      break
    }

    return segments
  }

  // Strips markdown formatting from text, preserving the content.
  private static func stripMarkdown(_ text: String) -> String {
    var result = text

    // Strip bold (**text** or __text__).
    result = result.replacingOccurrences(
      of: #"\*\*(.+?)\*\*"#,
      with: "$1",
      options: .regularExpression
    )
    result = result.replacingOccurrences(
      of: #"__(.+?)__"#,
      with: "$1",
      options: .regularExpression
    )

    // Strip italic (*text* or _text_).
    result = result.replacingOccurrences(
      of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#,
      with: "$1",
      options: .regularExpression
    )
    result = result.replacingOccurrences(
      of: #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#,
      with: "$1",
      options: .regularExpression
    )

    // Strip inline code (`code`).
    result = result.replacingOccurrences(
      of: #"`(.+?)`"#,
      with: "$1",
      options: .regularExpression
    )

    // Strip header markers (# ## ### etc.) anywhere in text.
    // Matches 1-6 # characters followed by space(s) at start or after newline.
    result = result.replacingOccurrences(
      of: #"(?:^|\n)#{1,6}\s+"#,
      with: " ",
      options: .regularExpression
    )

    // Also strip standalone header markers that appear mid-text without newline.
    // This handles cases where snippet extraction splits lines.
    result = result.replacingOccurrences(
      of: #"\s#{1,6}\s+"#,
      with: " ",
      options: .regularExpression
    )

    // Clean up extra whitespace.
    result = result.replacingOccurrences(
      of: #"\s{2,}"#,
      with: " ",
      options: .regularExpression
    )
    result = result.trimmingCharacters(in: .whitespaces)

    return result
  }
}

// MARK: - LaTeX to Unicode Converter

// Converts LaTeX math notation to Unicode text.
enum LaTeXConverter {

  // Converts a LaTeX string to Unicode.
  static func toUnicode(_ latex: String) -> String {
    var result = latex

    // Convert Greek letters.
    for (command, unicode) in greekLetters {
      result = result.replacingOccurrences(of: command, with: unicode)
    }

    // Convert common symbols.
    for (command, unicode) in symbols {
      result = result.replacingOccurrences(of: command, with: unicode)
    }

    // Convert superscripts (x^2, x^{10}).
    result = convertSuperscripts(result)

    // Convert subscripts (x_1, x_{10}).
    result = convertSubscripts(result)

    // Convert fractions.
    result = convertFractions(result)

    // Clean up remaining LaTeX artifacts.
    result = result.replacingOccurrences(of: "\\", with: "")
    result = result.replacingOccurrences(of: "{", with: "")
    result = result.replacingOccurrences(of: "}", with: "")

    return result
  }

  // Converts superscript notation to Unicode superscript characters.
  private static func convertSuperscripts(_ text: String) -> String {
    var result = text

    // Match ^{...} or ^single_char.
    let bracedPattern = #"\^{([^}]+)}"#
    let singlePattern = #"\^([0-9a-zA-Z])"#

    // Convert braced superscripts.
    if let regex = try? NSRegularExpression(pattern: bracedPattern) {
      let range = NSRange(result.startIndex..., in: result)
      let matches = regex.matches(in: result, range: range).reversed()
      for match in matches {
        if let contentRange = Range(match.range(at: 1), in: result) {
          let content = String(result[contentRange])
          let superscript = toSuperscript(content)
          if let fullRange = Range(match.range, in: result) {
            result.replaceSubrange(fullRange, with: superscript)
          }
        }
      }
    }

    // Convert single character superscripts.
    if let regex = try? NSRegularExpression(pattern: singlePattern) {
      let range = NSRange(result.startIndex..., in: result)
      let matches = regex.matches(in: result, range: range).reversed()
      for match in matches {
        if let contentRange = Range(match.range(at: 1), in: result) {
          let content = String(result[contentRange])
          let superscript = toSuperscript(content)
          if let fullRange = Range(match.range, in: result) {
            result.replaceSubrange(fullRange, with: superscript)
          }
        }
      }
    }

    return result
  }

  // Converts subscript notation to Unicode subscript characters.
  private static func convertSubscripts(_ text: String) -> String {
    var result = text

    // Match _{...} or _single_char.
    let bracedPattern = #"_\{([^}]+)\}"#
    let singlePattern = #"_([0-9a-zA-Z])"#

    // Convert braced subscripts.
    if let regex = try? NSRegularExpression(pattern: bracedPattern) {
      let range = NSRange(result.startIndex..., in: result)
      let matches = regex.matches(in: result, range: range).reversed()
      for match in matches {
        if let contentRange = Range(match.range(at: 1), in: result) {
          let content = String(result[contentRange])
          let subscriptText = toSubscript(content)
          if let fullRange = Range(match.range, in: result) {
            result.replaceSubrange(fullRange, with: subscriptText)
          }
        }
      }
    }

    // Convert single character subscripts.
    if let regex = try? NSRegularExpression(pattern: singlePattern) {
      let range = NSRange(result.startIndex..., in: result)
      let matches = regex.matches(in: result, range: range).reversed()
      for match in matches {
        if let contentRange = Range(match.range(at: 1), in: result) {
          let content = String(result[contentRange])
          let subscriptText = toSubscript(content)
          if let fullRange = Range(match.range, in: result) {
            result.replaceSubrange(fullRange, with: subscriptText)
          }
        }
      }
    }

    return result
  }

  // Converts simple fractions to Unicode.
  private static func convertFractions(_ text: String) -> String {
    var result = text

    // Common fractions.
    let fractions: [(String, String)] = [
      (#"\frac{1}{2}"#, "½"),
      (#"\frac{1}{3}"#, "⅓"),
      (#"\frac{2}{3}"#, "⅔"),
      (#"\frac{1}{4}"#, "¼"),
      (#"\frac{3}{4}"#, "¾"),
      (#"\frac{1}{5}"#, "⅕"),
      (#"\frac{2}{5}"#, "⅖"),
      (#"\frac{3}{5}"#, "⅗"),
      (#"\frac{4}{5}"#, "⅘"),
      (#"\frac{1}{6}"#, "⅙"),
      (#"\frac{5}{6}"#, "⅚"),
      (#"\frac{1}{8}"#, "⅛"),
      (#"\frac{3}{8}"#, "⅜"),
      (#"\frac{5}{8}"#, "⅝"),
      (#"\frac{7}{8}"#, "⅞"),
    ]

    for (latex, unicode) in fractions {
      result = result.replacingOccurrences(of: latex, with: unicode)
    }

    // Generic fractions: \frac{a}{b} -> a/b.
    let fracPattern = #"\\frac\{([^}]+)\}\{([^}]+)\}"#
    if let regex = try? NSRegularExpression(pattern: fracPattern) {
      let range = NSRange(result.startIndex..., in: result)
      let matches = regex.matches(in: result, range: range).reversed()
      for match in matches {
        if let numRange = Range(match.range(at: 1), in: result),
          let denRange = Range(match.range(at: 2), in: result)
        {
          let num = String(result[numRange])
          let den = String(result[denRange])
          if let fullRange = Range(match.range, in: result) {
            result.replaceSubrange(fullRange, with: "\(num)/\(den)")
          }
        }
      }
    }

    return result
  }

  // Converts a string to superscript Unicode characters.
  private static func toSuperscript(_ text: String) -> String {
    text.map { superscriptMap[String($0)] ?? String($0) }.joined()
  }

  // Converts a string to subscript Unicode characters.
  private static func toSubscript(_ text: String) -> String {
    text.map { subscriptMap[String($0)] ?? String($0) }.joined()
  }

  // Unicode superscript characters.
  private static let superscriptMap: [String: String] = [
    "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
    "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
    "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
    "n": "ⁿ", "i": "ⁱ", "a": "ᵃ", "b": "ᵇ", "c": "ᶜ",
    "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ",
    "j": "ʲ", "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "o": "ᵒ",
    "p": "ᵖ", "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ",
    "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
  ]

  // Unicode subscript characters.
  private static let subscriptMap: [String: String] = [
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
    "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
    "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
    "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
    "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
    "v": "ᵥ", "x": "ₓ",
  ]

  // Greek letter mappings.
  private static let greekLetters: [(String, String)] = [
    ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
    ("\\epsilon", "ε"), ("\\zeta", "ζ"), ("\\eta", "η"), ("\\theta", "θ"),
    ("\\iota", "ι"), ("\\kappa", "κ"), ("\\lambda", "λ"), ("\\mu", "μ"),
    ("\\nu", "ν"), ("\\xi", "ξ"), ("\\pi", "π"), ("\\rho", "ρ"),
    ("\\sigma", "σ"), ("\\tau", "τ"), ("\\upsilon", "υ"), ("\\phi", "φ"),
    ("\\chi", "χ"), ("\\psi", "ψ"), ("\\omega", "ω"),
    ("\\Alpha", "Α"), ("\\Beta", "Β"), ("\\Gamma", "Γ"), ("\\Delta", "Δ"),
    ("\\Epsilon", "Ε"), ("\\Zeta", "Ζ"), ("\\Eta", "Η"), ("\\Theta", "Θ"),
    ("\\Iota", "Ι"), ("\\Kappa", "Κ"), ("\\Lambda", "Λ"), ("\\Mu", "Μ"),
    ("\\Nu", "Ν"), ("\\Xi", "Ξ"), ("\\Pi", "Π"), ("\\Rho", "Ρ"),
    ("\\Sigma", "Σ"), ("\\Tau", "Τ"), ("\\Upsilon", "Υ"), ("\\Phi", "Φ"),
    ("\\Chi", "Χ"), ("\\Psi", "Ψ"), ("\\Omega", "Ω"),
  ]

  // Common LaTeX symbols.
  private static let symbols: [(String, String)] = [
    ("\\times", "×"), ("\\div", "÷"), ("\\pm", "±"), ("\\mp", "∓"),
    ("\\cdot", "·"), ("\\ast", "∗"), ("\\star", "☆"),
    ("\\infty", "∞"), ("\\sqrt", "√"), ("\\sum", "Σ"), ("\\prod", "∏"),
    ("\\int", "∫"), ("\\partial", "∂"), ("\\nabla", "∇"),
    ("\\leq", "≤"), ("\\geq", "≥"), ("\\neq", "≠"), ("\\approx", "≈"),
    ("\\equiv", "≡"), ("\\sim", "∼"), ("\\propto", "∝"),
    ("\\subset", "⊂"), ("\\supset", "⊃"), ("\\subseteq", "⊆"), ("\\supseteq", "⊇"),
    ("\\in", "∈"), ("\\notin", "∉"), ("\\cap", "∩"), ("\\cup", "∪"),
    ("\\emptyset", "∅"), ("\\forall", "∀"), ("\\exists", "∃"),
    ("\\rightarrow", "→"), ("\\leftarrow", "←"), ("\\leftrightarrow", "↔"),
    ("\\Rightarrow", "⇒"), ("\\Leftarrow", "⇐"), ("\\Leftrightarrow", "⇔"),
    ("\\to", "→"), ("\\gets", "←"),
    ("\\ldots", "…"), ("\\cdots", "⋯"), ("\\vdots", "⋮"), ("\\ddots", "⋱"),
    ("\\degree", "°"), ("\\circ", "°"),
  ]
}

// MARK: - Snippet Renderer

// Renders parsed segments into an AttributedString.
enum SnippetRenderer {

  // Renders segments into a single AttributedString.
  static func render(
    segments: [SnippetSegment],
    fontSize: CGFloat,
    textColor: Color,
    highlightColor: Color
  ) -> AttributedString {
    var result = AttributedString()

    for segment in segments {
      switch segment {
      case .text(let content, let isHighlighted):
        var attributed = AttributedString(content)
        if isHighlighted {
          attributed.font = .system(size: fontSize, weight: .semibold)
          attributed.foregroundColor = highlightColor
        } else {
          attributed.font = .system(size: fontSize)
          attributed.foregroundColor = textColor
        }
        result.append(attributed)

      case .math(let unicode, let isHighlighted):
        var attributed = AttributedString(unicode)
        if isHighlighted {
          attributed.font = .system(size: fontSize, weight: .semibold)
          attributed.foregroundColor = highlightColor
        } else {
          attributed.font = .system(size: fontSize)
          attributed.foregroundColor = textColor
        }
        result.append(attributed)
      }
    }

    return result
  }
}
