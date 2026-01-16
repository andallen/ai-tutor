//
// TextContent.swift
// InkOS
//
// Rich text content with LaTeX, code, and kinetic typography.
// Rendered natively using SwiftUI + iosMath.
//

import Foundation

// MARK: - TextContent

// Rich text with LaTeX, code, and kinetic typography.
struct TextContent: Sendable, Codable, Equatable {
  // Ordered list of text segments to render sequentially.
  let segments: [TextSegment]

  // Text alignment.
  let alignment: TextAlignment

  // Vertical spacing between segments.
  let spacing: TextSpacing

  private enum CodingKeys: String, CodingKey {
    case segments
    case alignment
    case spacing
  }

  init(
    segments: [TextSegment],
    alignment: TextAlignment = .leading,
    spacing: TextSpacing = .normal
  ) {
    self.segments = segments
    self.alignment = alignment
    self.spacing = spacing
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.segments = try container.decode([TextSegment].self, forKey: .segments)
    self.alignment = try container.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? .leading
    self.spacing = try container.decodeIfPresent(TextSpacing.self, forKey: .spacing) ?? .normal
  }

  // Convenience initializer for simple plain text.
  static func plain(_ text: String, style: TextStyle? = nil) -> TextContent {
    TextContent(segments: [.plain(text: text, style: style)])
  }

  // Convenience initializer for LaTeX equation.
  static func latex(_ latex: String, displayMode: Bool = false) -> TextContent {
    TextContent(segments: [.latex(latex: latex, displayMode: displayMode)])
  }

  // Convenience initializer for code block.
  static func code(_ code: String, language: String = "plaintext") -> TextContent {
    TextContent(segments: [.code(code: code, language: language)])
  }

  // Calculates the streaming animation duration in milliseconds.
  // Matches the timing logic in StreamingTextView.
  var streamingDurationMs: Int {
    let charactersPerSecond: Double = 60
    let fadeCharacters = 3
    let fadeDuration = Double(fadeCharacters) / charactersPerSecond

    var duration: Double = 0
    for segment in segments {
      switch segment {
      case .plain(let text, _):
        duration += Double(text.count) / charactersPerSecond
      case .pause(let durationMs):
        duration += Double(durationMs) / 1000.0
      case .kinetic(_, _, let durationMs, let delayMs, _):
        duration += Double(durationMs + delayMs) / 1000.0
      case .latex, .code:
        // Non-streaming segments appear instantly.
        break
      }
    }
    return Int((duration + fadeDuration) * 1000)
  }
}

// MARK: - TextAlignment

// Text alignment options.
enum TextAlignment: String, Sendable, Codable, Equatable {
  case leading
  case center
  case trailing
}

// MARK: - TextSpacing

// Vertical spacing between segments.
enum TextSpacing: String, Sendable, Codable, Equatable {
  case compact
  case normal
  case relaxed
}

// MARK: - TextSegment

// A segment of text content.
enum TextSegment: Sendable, Equatable {
  case plain(text: String, style: TextStyle? = nil)
  case latex(latex: String, displayMode: Bool = false, color: String? = nil)
  case code(code: String, language: String = "plaintext", showLineNumbers: Bool = false, highlightLines: [Int]? = nil)
  case kinetic(text: String, animation: KineticAnimation = .typewriter, durationMs: Int = 500, delayMs: Int = 0, style: TextStyle? = nil)
  // Human-like pause in the text flow. Default 400ms is a natural breath pause.
  case pause(durationMs: Int = 400)
}

// MARK: - TextSegment Codable

extension TextSegment: Codable {
  private enum TypeKey: String, CodingKey {
    case type
    case text
    case style
    case latex
    case displayMode = "display_mode"
    case color
    case code
    case language
    case showLineNumbers = "show_line_numbers"
    case highlightLines = "highlight_lines"
    case animation
    case durationMs = "duration_ms"
    case delayMs = "delay_ms"
  }

  private enum SegmentType: String, Codable {
    case plain
    case latex
    case code
    case kinetic
    case pause
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(SegmentType.self, forKey: .type)

    switch type {
    case .plain:
      let text = try container.decode(String.self, forKey: .text)
      let style = try container.decodeIfPresent(TextStyle.self, forKey: .style)
      self = .plain(text: text, style: style)

    case .latex:
      let latex = try container.decode(String.self, forKey: .latex)
      let displayMode = try container.decodeIfPresent(Bool.self, forKey: .displayMode) ?? false
      let color = try container.decodeIfPresent(String.self, forKey: .color)
      self = .latex(latex: latex, displayMode: displayMode, color: color)

    case .code:
      let code = try container.decode(String.self, forKey: .code)
      let language = try container.decodeIfPresent(String.self, forKey: .language) ?? "plaintext"
      let showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? false
      let highlightLines = try container.decodeIfPresent([Int].self, forKey: .highlightLines)
      self = .code(code: code, language: language, showLineNumbers: showLineNumbers, highlightLines: highlightLines)

    case .kinetic:
      let text = try container.decode(String.self, forKey: .text)
      let animation = try container.decodeIfPresent(KineticAnimation.self, forKey: .animation) ?? .typewriter
      let durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs) ?? 500
      let delayMs = try container.decodeIfPresent(Int.self, forKey: .delayMs) ?? 0
      let style = try container.decodeIfPresent(TextStyle.self, forKey: .style)
      self = .kinetic(text: text, animation: animation, durationMs: durationMs, delayMs: delayMs, style: style)

    case .pause:
      let durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs) ?? 400
      self = .pause(durationMs: durationMs)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)

    switch self {
    case .plain(let text, let style):
      try container.encode(SegmentType.plain, forKey: .type)
      try container.encode(text, forKey: .text)
      try container.encodeIfPresent(style, forKey: .style)

    case .latex(let latex, let displayMode, let color):
      try container.encode(SegmentType.latex, forKey: .type)
      try container.encode(latex, forKey: .latex)
      if displayMode { try container.encode(displayMode, forKey: .displayMode) }
      try container.encodeIfPresent(color, forKey: .color)

    case .code(let code, let language, let showLineNumbers, let highlightLines):
      try container.encode(SegmentType.code, forKey: .type)
      try container.encode(code, forKey: .code)
      if language != "plaintext" { try container.encode(language, forKey: .language) }
      if showLineNumbers { try container.encode(showLineNumbers, forKey: .showLineNumbers) }
      try container.encodeIfPresent(highlightLines, forKey: .highlightLines)

    case .kinetic(let text, let animation, let durationMs, let delayMs, let style):
      try container.encode(SegmentType.kinetic, forKey: .type)
      try container.encode(text, forKey: .text)
      if animation != .typewriter { try container.encode(animation, forKey: .animation) }
      if durationMs != 500 { try container.encode(durationMs, forKey: .durationMs) }
      if delayMs != 0 { try container.encode(delayMs, forKey: .delayMs) }
      try container.encodeIfPresent(style, forKey: .style)

    case .pause(let durationMs):
      try container.encode(SegmentType.pause, forKey: .type)
      if durationMs != 400 { try container.encode(durationMs, forKey: .durationMs) }
    }
  }
}

// MARK: - TextStyle

// Styling options for plain and kinetic text.
struct TextStyle: Sendable, Codable, Equatable {
  let size: TextSize?
  let weight: TextWeight?
  let color: String?
  let italic: Bool
  let underline: Bool
  let strikethrough: Bool

  private enum CodingKeys: String, CodingKey {
    case size
    case weight
    case color
    case italic
    case underline
    case strikethrough
  }

  init(
    size: TextSize? = nil,
    weight: TextWeight? = nil,
    color: String? = nil,
    italic: Bool = false,
    underline: Bool = false,
    strikethrough: Bool = false
  ) {
    self.size = size
    self.weight = weight
    self.color = color
    self.italic = italic
    self.underline = underline
    self.strikethrough = strikethrough
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.size = try container.decodeIfPresent(TextSize.self, forKey: .size)
    self.weight = try container.decodeIfPresent(TextWeight.self, forKey: .weight)
    self.color = try container.decodeIfPresent(String.self, forKey: .color)
    self.italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
    self.underline = try container.decodeIfPresent(Bool.self, forKey: .underline) ?? false
    self.strikethrough = try container.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
  }
}

// MARK: - TextSize

// Text size options (maps to SwiftUI text styles).
enum TextSize: String, Sendable, Codable, Equatable {
  case caption
  case body
  case headline
  case title
  case largeTitle
}

// MARK: - TextWeight

// Font weight options.
enum TextWeight: String, Sendable, Codable, Equatable {
  case regular
  case medium
  case semibold
  case bold
  case heavy
}

// MARK: - KineticAnimation

// Kinetic typography animation types.
// All animations are finite (they complete and stop).
// Typewriter is the only animation - sequential text output maintains
// the sense of a living agent producing content in real-time.
enum KineticAnimation: String, Sendable, Codable, Equatable {
  case typewriter
}
