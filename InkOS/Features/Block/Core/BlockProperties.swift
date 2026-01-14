//
// BlockProperties.swift
// InkOS
//
// Type-safe property structs for each BlockKind.
// Uses enum with associated values for compile-time type safety.
//

import CoreGraphics
import Foundation

// MARK: - BlockProperties

// Type-safe wrapper for block-specific properties.
// Each case wraps a struct with properties specific to that block kind.
enum BlockProperties: Sendable, Equatable {
  // Phase 1 - Core Content
  case textOutput(TextOutputProperties)
  case textInput(TextInputProperties)
  case handwritingInput(HandwritingInputProperties)

  // Phase 2 - Visual
  case plot(PlotProperties)
  case table(TableProperties)
  case diagramOutput(DiagramOutputProperties)

  // Phase 3 - Interactive
  case cardDeck(CardDeckProperties)
  case quiz(QuizProperties)

  // Phase 4 - Advanced
  case geometry(GeometryProperties)
  case codeCell(CodeCellProperties)

  // Utility blocks
  case codeOutput(CodeOutputProperties)
  case calloutOutput(CalloutOutputProperties)
  case imageOutput(ImageOutputProperties)
  case buttonInput(ButtonInputProperties)
  case timerOutput(TimerOutputProperties)
  case progressOutput(ProgressOutputProperties)
  case audio(AudioProperties)
  case videoOutput(VideoOutputProperties)
}

// MARK: - Shared Types

// Text styling options for rich text blocks.
struct TextStyle: Sendable, Codable, Equatable {
  let fontSize: CGFloat?
  let fontWeight: FontWeight?
  let textColor: String?
  let alignment: TextAlignment?

  init(
    fontSize: CGFloat? = nil,
    fontWeight: FontWeight? = nil,
    textColor: String? = nil,
    alignment: TextAlignment? = nil
  ) {
    self.fontSize = fontSize
    self.fontWeight = fontWeight
    self.textColor = textColor
    self.alignment = alignment
  }
}

// Font weight options.
enum FontWeight: String, Sendable, Codable, Equatable {
  case regular
  case medium
  case semibold
  case bold
}

// Text alignment options.
enum TextAlignment: String, Sendable, Codable, Equatable {
  case leading
  case center
  case trailing
}

// Keyboard type hints for text input.
enum KeyboardTypeHint: String, Sendable, Codable, Equatable {
  case `default`
  case numeric
  case email
  case url
  case decimalPad
}

// MARK: - Phase 1 Property Structs

// Properties for rich text display blocks.
// Supports markdown and inline/display LaTeX.
struct TextOutputProperties: Sendable, Codable, Equatable {
  // Markdown content string with optional LaTeX.
  let content: String

  // Optional text style override.
  let style: TextStyle?

  // Whether to enable math rendering.
  let enableMath: Bool

  private enum CodingKeys: String, CodingKey {
    case content
    case style
    case enableMath
  }

  init(content: String, style: TextStyle? = nil, enableMath: Bool = true) {
    self.content = content
    self.style = style
    self.enableMath = enableMath
  }
}

// Properties for text input blocks.
struct TextInputProperties: Sendable, Codable, Equatable {
  // Placeholder text when empty.
  let placeholder: String?

  // Current text value.
  var value: String

  // Maximum character limit.
  let maxLength: Int?

  // Whether input is multiline.
  let multiline: Bool

  // Keyboard type hint.
  let keyboardType: KeyboardTypeHint

  private enum CodingKeys: String, CodingKey {
    case placeholder
    case value
    case maxLength
    case multiline
    case keyboardType
  }

  init(
    placeholder: String? = nil,
    value: String = "",
    maxLength: Int? = nil,
    multiline: Bool = false,
    keyboardType: KeyboardTypeHint = .default
  ) {
    self.placeholder = placeholder
    self.value = value
    self.maxLength = maxLength
    self.multiline = multiline
    self.keyboardType = keyboardType
  }
}

// Properties for handwriting input blocks.
struct HandwritingInputProperties: Sendable, Codable, Equatable {
  // JIIX content from handwriting recognition.
  var jiixContent: String?

  // Recognized text from handwriting.
  var recognizedText: String?

  // Canvas height in points.
  let canvasHeight: CGFloat

  // Whether to enable math recognition.
  let enableMathRecognition: Bool

  // Whether to show recognition suggestions.
  let showSuggestions: Bool

  private enum CodingKeys: String, CodingKey {
    case jiixContent
    case recognizedText
    case canvasHeight
    case enableMathRecognition
    case showSuggestions
  }

  init(
    jiixContent: String? = nil,
    recognizedText: String? = nil,
    canvasHeight: CGFloat = 200,
    enableMathRecognition: Bool = true,
    showSuggestions: Bool = true
  ) {
    self.jiixContent = jiixContent
    self.recognizedText = recognizedText
    self.canvasHeight = canvasHeight
    self.enableMathRecognition = enableMathRecognition
    self.showSuggestions = showSuggestions
  }
}

// MARK: - Phase 2 Property Structs (Placeholders)

// Properties for plot/graph blocks.
struct PlotProperties: Sendable, Codable, Equatable {
  // Mathematical expression(s) to plot.
  let expressions: [String]

  // X-axis range.
  let xRange: ClosedRange<Double>

  // Y-axis range.
  let yRange: ClosedRange<Double>

  // Whether the graph is interactive.
  let interactive: Bool

  // Whether to show grid lines.
  let showGrid: Bool

  private enum CodingKeys: String, CodingKey {
    case expressions
    case xMin
    case xMax
    case yMin
    case yMax
    case interactive
    case showGrid
  }

  init(
    expressions: [String],
    xRange: ClosedRange<Double> = -10...10,
    yRange: ClosedRange<Double> = -10...10,
    interactive: Bool = true,
    showGrid: Bool = true
  ) {
    self.expressions = expressions
    self.xRange = xRange
    self.yRange = yRange
    self.interactive = interactive
    self.showGrid = showGrid
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.expressions = try container.decode([String].self, forKey: .expressions)
    let xMin = try container.decode(Double.self, forKey: .xMin)
    let xMax = try container.decode(Double.self, forKey: .xMax)
    self.xRange = xMin...xMax
    let yMin = try container.decode(Double.self, forKey: .yMin)
    let yMax = try container.decode(Double.self, forKey: .yMax)
    self.yRange = yMin...yMax
    self.interactive = try container.decode(Bool.self, forKey: .interactive)
    self.showGrid = try container.decode(Bool.self, forKey: .showGrid)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(expressions, forKey: .expressions)
    try container.encode(xRange.lowerBound, forKey: .xMin)
    try container.encode(xRange.upperBound, forKey: .xMax)
    try container.encode(yRange.lowerBound, forKey: .yMin)
    try container.encode(yRange.upperBound, forKey: .yMax)
    try container.encode(interactive, forKey: .interactive)
    try container.encode(showGrid, forKey: .showGrid)
  }
}

// Properties for table blocks.
struct TableProperties: Sendable, Codable, Equatable {
  // Column definitions.
  let columns: [TableColumn]

  // Row data.
  let rows: [[TableCellValue]]

  // Whether headers are shown.
  let showHeaders: Bool

  // Whether the table is editable.
  let editable: Bool

  private enum CodingKeys: String, CodingKey {
    case columns
    case rows
    case showHeaders
    case editable
  }

  init(
    columns: [TableColumn],
    rows: [[TableCellValue]],
    showHeaders: Bool = true,
    editable: Bool = false
  ) {
    self.columns = columns
    self.rows = rows
    self.showHeaders = showHeaders
    self.editable = editable
  }
}

// Column definition for tables.
struct TableColumn: Sendable, Codable, Equatable, Identifiable {
  let id: String
  let header: String
  let alignment: TextAlignment

  private enum CodingKeys: String, CodingKey {
    case id
    case header
    case alignment
  }

  init(
    id: String = UUID().uuidString,
    header: String,
    alignment: TextAlignment = .leading
  ) {
    self.id = id
    self.header = header
    self.alignment = alignment
  }
}

// Cell value types for tables.
enum TableCellValue: Sendable, Codable, Equatable {
  case text(String)
  case number(Double)
  case boolean(Bool)
  case empty

  private enum TypeKey: String, CodingKey {
    case type
    case value
  }

  private enum ValueType: String, Codable {
    case text
    case number
    case boolean
    case empty
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(ValueType.self, forKey: .type)
    switch type {
    case .text:
      let value = try container.decode(String.self, forKey: .value)
      self = .text(value)
    case .number:
      let value = try container.decode(Double.self, forKey: .value)
      self = .number(value)
    case .boolean:
      let value = try container.decode(Bool.self, forKey: .value)
      self = .boolean(value)
    case .empty:
      self = .empty
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)
    switch self {
    case .text(let value):
      try container.encode(ValueType.text, forKey: .type)
      try container.encode(value, forKey: .value)
    case .number(let value):
      try container.encode(ValueType.number, forKey: .type)
      try container.encode(value, forKey: .value)
    case .boolean(let value):
      try container.encode(ValueType.boolean, forKey: .type)
      try container.encode(value, forKey: .value)
    case .empty:
      try container.encode(ValueType.empty, forKey: .type)
    }
  }
}

// Properties for diagram blocks.
struct DiagramOutputProperties: Sendable, Codable, Equatable {
  // Diagram source (Mermaid or custom format).
  let source: String

  // Diagram format type.
  let format: DiagramFormat

  private enum CodingKeys: String, CodingKey {
    case source
    case format
  }

  init(source: String, format: DiagramFormat = .mermaid) {
    self.source = source
    self.format = format
  }
}

// Supported diagram formats.
enum DiagramFormat: String, Sendable, Codable, Equatable {
  case mermaid
  case flowchart
  case sequence
  case mindmap
}

// MARK: - Phase 3 Property Structs (Placeholders)

// Properties for flashcard deck blocks.
struct CardDeckProperties: Sendable, Codable, Equatable {
  // Cards in the deck.
  let cards: [FlashCard]

  // Current card index.
  var currentIndex: Int

  // Whether to shuffle cards.
  let shuffled: Bool

  private enum CodingKeys: String, CodingKey {
    case cards
    case currentIndex
    case shuffled
  }

  init(cards: [FlashCard], currentIndex: Int = 0, shuffled: Bool = false) {
    self.cards = cards
    self.currentIndex = currentIndex
    self.shuffled = shuffled
  }
}

// A single flashcard.
struct FlashCard: Sendable, Codable, Equatable, Identifiable {
  let id: String
  let front: String
  let back: String
  let tags: [String]?

  private enum CodingKeys: String, CodingKey {
    case id
    case front
    case back
    case tags
  }

  init(id: String = UUID().uuidString, front: String, back: String, tags: [String]? = nil) {
    self.id = id
    self.front = front
    self.back = back
    self.tags = tags
  }
}

// Properties for quiz blocks.
struct QuizProperties: Sendable, Codable, Equatable {
  // Questions in the quiz.
  let questions: [QuizQuestion]

  // Current question index.
  var currentIndex: Int

  // Whether to shuffle questions.
  let shuffled: Bool

  // Whether to show correct answers after submission.
  let showAnswers: Bool

  private enum CodingKeys: String, CodingKey {
    case questions
    case currentIndex
    case shuffled
    case showAnswers
  }

  init(
    questions: [QuizQuestion],
    currentIndex: Int = 0,
    shuffled: Bool = false,
    showAnswers: Bool = true
  ) {
    self.questions = questions
    self.currentIndex = currentIndex
    self.shuffled = shuffled
    self.showAnswers = showAnswers
  }
}

// A single quiz question.
struct QuizQuestion: Sendable, Codable, Equatable, Identifiable {
  let id: String
  let question: String
  let questionType: QuizQuestionType
  let options: [String]?
  let correctAnswer: String
  let explanation: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case question
    case questionType
    case options
    case correctAnswer
    case explanation
  }

  init(
    id: String = UUID().uuidString,
    question: String,
    questionType: QuizQuestionType,
    options: [String]? = nil,
    correctAnswer: String,
    explanation: String? = nil
  ) {
    self.id = id
    self.question = question
    self.questionType = questionType
    self.options = options
    self.correctAnswer = correctAnswer
    self.explanation = explanation
  }
}

// Types of quiz questions for Block system.
// Named QuizQuestionType to avoid conflict with LessonModel.QuestionType.
enum QuizQuestionType: String, Sendable, Codable, Equatable {
  case multipleChoice
  case shortAnswer
  case trueFalse
  case fillInBlank
}

// MARK: - Phase 4 Property Structs (Placeholders)

// Properties for geometry blocks.
struct GeometryProperties: Sendable, Codable, Equatable {
  // Geometry elements (points, lines, etc.).
  let elements: [GeometryElement]

  // Whether elements are draggable.
  let interactive: Bool

  // Whether to show labels.
  let showLabels: Bool

  // Whether to show measurements.
  let showMeasurements: Bool

  private enum CodingKeys: String, CodingKey {
    case elements
    case interactive
    case showLabels
    case showMeasurements
  }

  init(
    elements: [GeometryElement],
    interactive: Bool = true,
    showLabels: Bool = true,
    showMeasurements: Bool = false
  ) {
    self.elements = elements
    self.interactive = interactive
    self.showLabels = showLabels
    self.showMeasurements = showMeasurements
  }
}

// A geometry element (point, line, circle, etc.).
struct GeometryElement: Sendable, Codable, Equatable, Identifiable {
  let id: String
  let elementType: GeometryElementType
  let label: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case elementType
    case label
  }

  init(id: String = UUID().uuidString, elementType: GeometryElementType, label: String? = nil) {
    self.id = id
    self.elementType = elementType
    self.label = label
  }
}

// Types of geometry elements.
enum GeometryElementType: String, Sendable, Codable, Equatable {
  case point
  case line
  case segment
  case ray
  case circle
  case polygon
  case angle
}

// Properties for executable code cell blocks.
struct CodeCellProperties: Sendable, Codable, Equatable {
  // Source code.
  var source: String

  // Programming language.
  let language: String

  // Output from execution.
  var output: String?

  // Whether execution resulted in error.
  var hasError: Bool

  private enum CodingKeys: String, CodingKey {
    case source
    case language
    case output
    case hasError
  }

  init(source: String, language: String = "python", output: String? = nil, hasError: Bool = false) {
    self.source = source
    self.language = language
    self.output = output
    self.hasError = hasError
  }
}

// MARK: - Utility Property Structs

// Properties for static code display blocks.
struct CodeOutputProperties: Sendable, Codable, Equatable {
  // Source code to display.
  let source: String

  // Programming language for syntax highlighting.
  let language: String

  // Whether to show line numbers.
  let showLineNumbers: Bool

  // Lines to highlight.
  let highlightedLines: [Int]?

  private enum CodingKeys: String, CodingKey {
    case source
    case language
    case showLineNumbers
    case highlightedLines
  }

  init(
    source: String,
    language: String = "swift",
    showLineNumbers: Bool = true,
    highlightedLines: [Int]? = nil
  ) {
    self.source = source
    self.language = language
    self.showLineNumbers = showLineNumbers
    self.highlightedLines = highlightedLines
  }
}

// Properties for callout blocks.
struct CalloutOutputProperties: Sendable, Codable, Equatable {
  // Callout style type.
  let calloutType: CalloutType

  // Title text.
  let title: String?

  // Content text.
  let content: String

  private enum CodingKeys: String, CodingKey {
    case calloutType
    case title
    case content
  }

  init(calloutType: CalloutType, title: String? = nil, content: String) {
    self.calloutType = calloutType
    self.title = title
    self.content = content
  }
}

// Callout style types.
enum CalloutType: String, Sendable, Codable, Equatable {
  case info
  case warning
  case error
  case success
  case note
  case tip
}

// Properties for image blocks.
struct ImageOutputProperties: Sendable, Codable, Equatable {
  // Image source (URL or asset name).
  let source: String

  // Alt text for accessibility.
  let altText: String?

  // Optional caption.
  let caption: String?

  private enum CodingKeys: String, CodingKey {
    case source
    case altText
    case caption
  }

  init(source: String, altText: String? = nil, caption: String? = nil) {
    self.source = source
    self.altText = altText
    self.caption = caption
  }
}

// Properties for button blocks.
struct ButtonInputProperties: Sendable, Codable, Equatable {
  // Button label text.
  let label: String

  // Button style.
  let style: BlockButtonStyle

  // Whether button is disabled.
  let disabled: Bool

  private enum CodingKeys: String, CodingKey {
    case label
    case style
    case disabled
  }

  init(label: String, style: BlockButtonStyle = .primary, disabled: Bool = false) {
    self.label = label
    self.style = style
    self.disabled = disabled
  }
}

// Button style types for Block system.
// Named BlockButtonStyle to avoid conflict with SwiftUI.ButtonStyle protocol.
enum BlockButtonStyle: String, Sendable, Codable, Equatable {
  case primary
  case secondary
  case tertiary
  case destructive
}

// Properties for timer blocks.
struct TimerOutputProperties: Sendable, Codable, Equatable {
  // Duration in seconds.
  let duration: TimeInterval

  // Current elapsed time.
  var elapsed: TimeInterval

  // Whether timer is running.
  var isRunning: Bool

  // Whether to count down or up.
  let countdown: Bool

  private enum CodingKeys: String, CodingKey {
    case duration
    case elapsed
    case isRunning
    case countdown
  }

  init(duration: TimeInterval, elapsed: TimeInterval = 0, isRunning: Bool = false, countdown: Bool = true) {
    self.duration = duration
    self.elapsed = elapsed
    self.isRunning = isRunning
    self.countdown = countdown
  }
}

// Properties for progress blocks.
struct ProgressOutputProperties: Sendable, Codable, Equatable {
  // Total steps or units.
  let total: Int

  // Current progress.
  var current: Int

  // Whether to show percentage.
  let showPercentage: Bool

  // Whether to show step count.
  let showCount: Bool

  private enum CodingKeys: String, CodingKey {
    case total
    case current
    case showPercentage
    case showCount
  }

  init(total: Int, current: Int = 0, showPercentage: Bool = true, showCount: Bool = false) {
    self.total = total
    self.current = current
    self.showPercentage = showPercentage
    self.showCount = showCount
  }
}

// Properties for audio blocks.
struct AudioProperties: Sendable, Codable, Equatable {
  // Audio source URL.
  let source: String

  // Title/name of audio.
  let title: String?

  // Whether to auto-play.
  let autoPlay: Bool

  // Whether to loop.
  let loop: Bool

  private enum CodingKeys: String, CodingKey {
    case source
    case title
    case autoPlay
    case loop
  }

  init(source: String, title: String? = nil, autoPlay: Bool = false, loop: Bool = false) {
    self.source = source
    self.title = title
    self.autoPlay = autoPlay
    self.loop = loop
  }
}

// Properties for video blocks.
struct VideoOutputProperties: Sendable, Codable, Equatable {
  // Video source URL.
  let source: String

  // Title/name of video.
  let title: String?

  // Whether to auto-play.
  let autoPlay: Bool

  // Whether to show controls.
  let showControls: Bool

  private enum CodingKeys: String, CodingKey {
    case source
    case title
    case autoPlay
    case showControls
  }

  init(source: String, title: String? = nil, autoPlay: Bool = false, showControls: Bool = true) {
    self.source = source
    self.title = title
    self.autoPlay = autoPlay
    self.showControls = showControls
  }
}
