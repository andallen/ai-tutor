//
// InputContent.swift
// InkOS
//
// User input collection (text, handwriting, multiple choice, quizzes, etc.).
// Rendered natively using SwiftUI.
//

import Foundation

// MARK: - InputContent

// User input collection.
struct InputContent: Sendable, Codable, Equatable {
  // Type of input to collect.
  let inputType: InputType

  // Type-specific configuration.
  let config: InputConfig

  // Question or instruction text.
  let prompt: String?

  // LaTeX to render in the prompt (optional).
  let promptLatex: String?

  // Whether input is required.
  let required: Bool

  // Submit button label.
  let submitLabel: String

  // The user's submitted response (populated after submission).
  var submittedValue: AnyCodable?

  // Feedback shown after submission.
  var feedback: InputFeedback?

  private enum CodingKeys: String, CodingKey {
    case inputType = "input_type"
    case prompt
    case promptLatex = "prompt_latex"
    case required
    case submitLabel = "submit_label"
    case submittedValue = "submitted_value"
    case feedback
    // Config keys.
    case textConfig = "text_config"
    case handwritingConfig = "handwriting_config"
    case choiceConfig = "choice_config"
    case multiSelectConfig = "multi_select_config"
    case buttonConfig = "button_config"
    case sliderConfig = "slider_config"
    case numericConfig = "numeric_config"
  }

  init(
    inputType: InputType,
    config: InputConfig,
    prompt: String? = nil,
    promptLatex: String? = nil,
    required: Bool = false,
    submitLabel: String = "Submit",
    submittedValue: AnyCodable? = nil,
    feedback: InputFeedback? = nil
  ) {
    self.inputType = inputType
    self.config = config
    self.prompt = prompt
    self.promptLatex = promptLatex
    self.required = required
    self.submitLabel = submitLabel
    self.submittedValue = submittedValue
    self.feedback = feedback
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.inputType = try container.decode(InputType.self, forKey: .inputType)
    self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
    self.promptLatex = try container.decodeIfPresent(String.self, forKey: .promptLatex)
    self.required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
    self.submitLabel = try container.decodeIfPresent(String.self, forKey: .submitLabel) ?? "Submit"
    self.submittedValue = try container.decodeIfPresent(AnyCodable.self, forKey: .submittedValue)
    self.feedback = try container.decodeIfPresent(InputFeedback.self, forKey: .feedback)

    // Decode config based on input type.
    switch inputType {
    case .text:
      let config = try container.decodeIfPresent(TextInputConfig.self, forKey: .textConfig) ?? TextInputConfig()
      self.config = .text(config)
    case .handwriting:
      let config = try container.decodeIfPresent(HandwritingConfig.self, forKey: .handwritingConfig)
        ?? HandwritingConfig()
      self.config = .handwriting(config)
    case .multipleChoice:
      let config = try container.decode(ChoiceConfig.self, forKey: .choiceConfig)
      self.config = .multipleChoice(config)
    case .multiSelect:
      let config = try container.decode(MultiSelectConfig.self, forKey: .multiSelectConfig)
      self.config = .multiSelect(config)
    case .button:
      let config = try container.decode(ButtonConfig.self, forKey: .buttonConfig)
      self.config = .button(config)
    case .slider:
      let config = try container.decode(SliderConfig.self, forKey: .sliderConfig)
      self.config = .slider(config)
    case .numeric:
      let config = try container.decodeIfPresent(NumericConfig.self, forKey: .numericConfig) ?? NumericConfig()
      self.config = .numeric(config)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(inputType, forKey: .inputType)
    try container.encodeIfPresent(prompt, forKey: .prompt)
    try container.encodeIfPresent(promptLatex, forKey: .promptLatex)
    if required { try container.encode(required, forKey: .required) }
    if submitLabel != "Submit" { try container.encode(submitLabel, forKey: .submitLabel) }
    try container.encodeIfPresent(submittedValue, forKey: .submittedValue)
    try container.encodeIfPresent(feedback, forKey: .feedback)

    // Encode config based on input type.
    switch config {
    case .text(let config):
      try container.encode(config, forKey: .textConfig)
    case .handwriting(let config):
      try container.encode(config, forKey: .handwritingConfig)
    case .multipleChoice(let config):
      try container.encode(config, forKey: .choiceConfig)
    case .multiSelect(let config):
      try container.encode(config, forKey: .multiSelectConfig)
    case .button(let config):
      try container.encode(config, forKey: .buttonConfig)
    case .slider(let config):
      try container.encode(config, forKey: .sliderConfig)
    case .numeric(let config):
      try container.encode(config, forKey: .numericConfig)
    }
  }

  // Convenience initializers.

  static func text(
    prompt: String? = nil,
    placeholder: String? = nil,
    multiline: Bool = false
  ) -> InputContent {
    InputContent(
      inputType: .text,
      config: .text(TextInputConfig(placeholder: placeholder, multiline: multiline)),
      prompt: prompt
    )
  }

  static func handwriting(
    prompt: String? = nil,
    recognitionType: HandwritingRecognitionType = .math,
    canvasHeight: Double = 150
  ) -> InputContent {
    InputContent(
      inputType: .handwriting,
      config: .handwriting(HandwritingConfig(recognitionType: recognitionType, canvasHeight: canvasHeight)),
      prompt: prompt
    )
  }

  static func multipleChoice(
    prompt: String? = nil,
    options: [ChoiceOption],
    layout: ChoiceLayout = .vertical
  ) -> InputContent {
    InputContent(
      inputType: .multipleChoice,
      config: .multipleChoice(ChoiceConfig(options: options, layout: layout)),
      prompt: prompt
    )
  }

  static func slider(
    prompt: String? = nil,
    min: Double,
    max: Double,
    step: Double = 1,
    defaultValue: Double? = nil
  ) -> InputContent {
    InputContent(
      inputType: .slider,
      config: .slider(SliderConfig(min: min, max: max, step: step, defaultValue: defaultValue)),
      prompt: prompt
    )
  }

  static func numeric(
    prompt: String? = nil,
    unit: String? = nil,
    expectedValue: Double? = nil,
    tolerance: Double? = nil
  ) -> InputContent {
    let validation =
      expectedValue != nil
      ? NumericValidation(expected: expectedValue, tolerance: tolerance) : nil
    return InputContent(
      inputType: .numeric,
      config: .numeric(NumericConfig(unit: unit, validation: validation)),
      prompt: prompt
    )
  }
}

// MARK: - InputType

// Input types.
enum InputType: String, Sendable, Codable, Equatable {
  case text
  case handwriting
  case multipleChoice = "multiple_choice"
  case multiSelect = "multi_select"
  case button
  case slider
  case numeric
}

// MARK: - InputConfig

// Type-specific configuration.
enum InputConfig: Sendable, Equatable {
  case text(TextInputConfig)
  case handwriting(HandwritingConfig)
  case multipleChoice(ChoiceConfig)
  case multiSelect(MultiSelectConfig)
  case button(ButtonConfig)
  case slider(SliderConfig)
  case numeric(NumericConfig)
}

// MARK: - InputFeedback

// Feedback shown after submission.
struct InputFeedback: Sendable, Codable, Equatable {
  let correct: Bool?
  let message: String?
  let explanation: String?

  init(correct: Bool? = nil, message: String? = nil, explanation: String? = nil) {
    self.correct = correct
    self.message = message
    self.explanation = explanation
  }
}

// MARK: - TextInputConfig

// Configuration for text input.
struct TextInputConfig: Sendable, Codable, Equatable {
  let placeholder: String?
  let multiline: Bool
  let maxLength: Int?
  let keyboardType: InputKeyboardType
  let validation: TextInputValidation?

  private enum CodingKeys: String, CodingKey {
    case placeholder
    case multiline
    case maxLength = "max_length"
    case keyboardType = "keyboard_type"
    case validation
  }

  init(
    placeholder: String? = nil,
    multiline: Bool = false,
    maxLength: Int? = nil,
    keyboardType: InputKeyboardType = .default,
    validation: TextInputValidation? = nil
  ) {
    self.placeholder = placeholder
    self.multiline = multiline
    self.maxLength = maxLength
    self.keyboardType = keyboardType
    self.validation = validation
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
    self.multiline = try container.decodeIfPresent(Bool.self, forKey: .multiline) ?? false
    self.maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
    self.keyboardType = try container.decodeIfPresent(InputKeyboardType.self, forKey: .keyboardType) ?? .default
    self.validation = try container.decodeIfPresent(TextInputValidation.self, forKey: .validation)
  }
}

// MARK: - InputKeyboardType

enum InputKeyboardType: String, Sendable, Codable, Equatable {
  case `default`
  case email
  case number
  case url
}

// MARK: - TextInputValidation

struct TextInputValidation: Sendable, Codable, Equatable {
  // Regex pattern for validation.
  let pattern: String?

  // Expected answer for auto-grading.
  let expected: String?

  // Whether comparison is case-sensitive.
  let caseSensitive: Bool

  private enum CodingKeys: String, CodingKey {
    case pattern
    case expected
    case caseSensitive = "case_sensitive"
  }

  init(pattern: String? = nil, expected: String? = nil, caseSensitive: Bool = false) {
    self.pattern = pattern
    self.expected = expected
    self.caseSensitive = caseSensitive
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
    self.expected = try container.decodeIfPresent(String.self, forKey: .expected)
    self.caseSensitive = try container.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? false
  }
}

// MARK: - HandwritingConfig

// Configuration for handwriting input.
struct HandwritingConfig: Sendable, Codable, Equatable {
  // What to recognize from handwriting.
  let recognitionType: HandwritingRecognitionType

  // Height of drawing area in points.
  let canvasHeight: Double

  // Canvas background style.
  let background: CanvasBackground

  // Ink color.
  let inkColor: String

  // Validation for expected answer.
  let validation: HandwritingValidation?

  private enum CodingKeys: String, CodingKey {
    case recognitionType = "recognition_type"
    case canvasHeight = "canvas_height"
    case background
    case inkColor = "ink_color"
    case validation
  }

  init(
    recognitionType: HandwritingRecognitionType = .math,
    canvasHeight: Double = 150,
    background: CanvasBackground = .blank,
    inkColor: String = "#000000",
    validation: HandwritingValidation? = nil
  ) {
    self.recognitionType = recognitionType
    self.canvasHeight = canvasHeight
    self.background = background
    self.inkColor = inkColor
    self.validation = validation
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.recognitionType =
      try container.decodeIfPresent(HandwritingRecognitionType.self, forKey: .recognitionType)
      ?? .math
    self.canvasHeight = try container.decodeIfPresent(Double.self, forKey: .canvasHeight) ?? 150
    self.background = try container.decodeIfPresent(CanvasBackground.self, forKey: .background) ?? .blank
    self.inkColor = try container.decodeIfPresent(String.self, forKey: .inkColor) ?? "#000000"
    self.validation = try container.decodeIfPresent(HandwritingValidation.self, forKey: .validation)
  }
}

// MARK: - HandwritingRecognitionType

enum HandwritingRecognitionType: String, Sendable, Codable, Equatable {
  case text
  case math
  case diagram
  case raw
}

// MARK: - CanvasBackground

enum CanvasBackground: String, Sendable, Codable, Equatable {
  case blank
  case lined
  case grid
  case graph
}

// MARK: - HandwritingValidation

struct HandwritingValidation: Sendable, Codable, Equatable {
  // Expected LaTeX expression.
  let expectedLatex: String?

  // Mathematically equivalent acceptable answers.
  let equivalentForms: [String]?

  private enum CodingKeys: String, CodingKey {
    case expectedLatex = "expected_latex"
    case equivalentForms = "equivalent_forms"
  }

  init(expectedLatex: String? = nil, equivalentForms: [String]? = nil) {
    self.expectedLatex = expectedLatex
    self.equivalentForms = equivalentForms
  }
}

// MARK: - ChoiceConfig

// Configuration for multiple choice input.
struct ChoiceConfig: Sendable, Codable, Equatable {
  let options: [ChoiceOption]
  let layout: ChoiceLayout
  let shuffle: Bool
  let showFeedbackImmediately: Bool

  private enum CodingKeys: String, CodingKey {
    case options
    case layout
    case shuffle
    case showFeedbackImmediately = "show_feedback_immediately"
  }

  init(
    options: [ChoiceOption],
    layout: ChoiceLayout = .vertical,
    shuffle: Bool = false,
    showFeedbackImmediately: Bool = true
  ) {
    self.options = options
    self.layout = layout
    self.shuffle = shuffle
    self.showFeedbackImmediately = showFeedbackImmediately
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.options = try container.decode([ChoiceOption].self, forKey: .options)
    self.layout = try container.decodeIfPresent(ChoiceLayout.self, forKey: .layout) ?? .vertical
    self.shuffle = try container.decodeIfPresent(Bool.self, forKey: .shuffle) ?? false
    self.showFeedbackImmediately = try container.decodeIfPresent(Bool.self, forKey: .showFeedbackImmediately) ?? true
  }
}

// MARK: - ChoiceOption

struct ChoiceOption: Sendable, Codable, Equatable, Identifiable {
  let id: String
  let text: String?
  let latex: String?
  let imageUrl: String?
  let correct: Bool?

  private enum CodingKeys: String, CodingKey {
    case id
    case text
    case latex
    case imageUrl = "image_url"
    case correct
  }

  init(id: String, text: String? = nil, latex: String? = nil, imageUrl: String? = nil, correct: Bool? = nil) {
    self.id = id
    self.text = text
    self.latex = latex
    self.imageUrl = imageUrl
    self.correct = correct
  }
}

// MARK: - ChoiceLayout

enum ChoiceLayout: String, Sendable, Codable, Equatable {
  case vertical
  case horizontal
  case grid
}

// MARK: - MultiSelectConfig

// Configuration for multi-select input.
struct MultiSelectConfig: Sendable, Codable, Equatable {
  let options: [ChoiceOption]
  let minSelections: Int
  let maxSelections: Int?
  let layout: ChoiceLayout
  let shuffle: Bool

  private enum CodingKeys: String, CodingKey {
    case options
    case minSelections = "min_selections"
    case maxSelections = "max_selections"
    case layout
    case shuffle
  }

  init(
    options: [ChoiceOption],
    minSelections: Int = 1,
    maxSelections: Int? = nil,
    layout: ChoiceLayout = .vertical,
    shuffle: Bool = false
  ) {
    self.options = options
    self.minSelections = minSelections
    self.maxSelections = maxSelections
    self.layout = layout
    self.shuffle = shuffle
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.options = try container.decode([ChoiceOption].self, forKey: .options)
    self.minSelections = try container.decodeIfPresent(Int.self, forKey: .minSelections) ?? 1
    self.maxSelections = try container.decodeIfPresent(Int.self, forKey: .maxSelections)
    self.layout = try container.decodeIfPresent(ChoiceLayout.self, forKey: .layout) ?? .vertical
    self.shuffle = try container.decodeIfPresent(Bool.self, forKey: .shuffle) ?? false
  }
}

// MARK: - ButtonConfig

// Configuration for button input.
struct ButtonConfig: Sendable, Codable, Equatable {
  let buttons: [InputButton]
  let layout: ChoiceLayout

  init(buttons: [InputButton], layout: ChoiceLayout = .horizontal) {
    self.buttons = buttons
    self.layout = layout
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.buttons = try container.decode([InputButton].self, forKey: .buttons)
    self.layout = try container.decodeIfPresent(ChoiceLayout.self, forKey: .layout) ?? .horizontal
  }

  private enum CodingKeys: String, CodingKey {
    case buttons
    case layout
  }
}

// MARK: - InputButton

struct InputButton: Sendable, Codable, Equatable, Identifiable {
  let id: String
  let label: String
  let style: InputButtonStyle
  let icon: String?

  init(id: String, label: String, style: InputButtonStyle = .primary, icon: String? = nil) {
    self.id = id
    self.label = label
    self.style = style
    self.icon = icon
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.label = try container.decode(String.self, forKey: .label)
    self.style = try container.decodeIfPresent(InputButtonStyle.self, forKey: .style) ?? .primary
    self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case label
    case style
    case icon
  }
}

// MARK: - InputButtonStyle

enum InputButtonStyle: String, Sendable, Codable, Equatable {
  case primary
  case secondary
  case destructive
  case ghost
}

// MARK: - SliderConfig

// Configuration for slider input.
struct SliderConfig: Sendable, Codable, Equatable {
  let min: Double
  let max: Double
  let step: Double
  let defaultValue: Double?
  let showValue: Bool
  let labels: SliderLabels?
  let validation: NumericValidation?

  private enum CodingKeys: String, CodingKey {
    case min
    case max
    case step
    case defaultValue = "default_value"
    case showValue = "show_value"
    case labels
    case validation
  }

  init(
    min: Double,
    max: Double,
    step: Double = 1,
    defaultValue: Double? = nil,
    showValue: Bool = true,
    labels: SliderLabels? = nil,
    validation: NumericValidation? = nil
  ) {
    self.min = min
    self.max = max
    self.step = step
    self.defaultValue = defaultValue
    self.showValue = showValue
    self.labels = labels
    self.validation = validation
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.min = try container.decode(Double.self, forKey: .min)
    self.max = try container.decode(Double.self, forKey: .max)
    self.step = try container.decodeIfPresent(Double.self, forKey: .step) ?? 1
    self.defaultValue = try container.decodeIfPresent(Double.self, forKey: .defaultValue)
    self.showValue = try container.decodeIfPresent(Bool.self, forKey: .showValue) ?? true
    self.labels = try container.decodeIfPresent(SliderLabels.self, forKey: .labels)
    self.validation = try container.decodeIfPresent(NumericValidation.self, forKey: .validation)
  }
}

// MARK: - SliderLabels

struct SliderLabels: Sendable, Codable, Equatable {
  let minLabel: String?
  let maxLabel: String?

  private enum CodingKeys: String, CodingKey {
    case minLabel = "min_label"
    case maxLabel = "max_label"
  }

  init(minLabel: String? = nil, maxLabel: String? = nil) {
    self.minLabel = minLabel
    self.maxLabel = maxLabel
  }
}

// MARK: - NumericConfig

// Configuration for numeric input.
struct NumericConfig: Sendable, Codable, Equatable {
  let placeholder: String?
  let unit: String?
  let decimalPlaces: Int?
  let validation: NumericValidation?

  private enum CodingKeys: String, CodingKey {
    case placeholder
    case unit
    case decimalPlaces = "decimal_places"
    case validation
  }

  init(
    placeholder: String? = nil,
    unit: String? = nil,
    decimalPlaces: Int? = nil,
    validation: NumericValidation? = nil
  ) {
    self.placeholder = placeholder
    self.unit = unit
    self.decimalPlaces = decimalPlaces
    self.validation = validation
  }
}

// MARK: - NumericValidation

struct NumericValidation: Sendable, Codable, Equatable {
  // Expected value.
  let expected: Double?

  // Absolute tolerance.
  let tolerance: Double?

  // Percentage tolerance (0-100).
  let tolerancePercent: Double?

  // Minimum value.
  let min: Double?

  // Maximum value.
  let max: Double?

  private enum CodingKeys: String, CodingKey {
    case expected
    case tolerance
    case tolerancePercent = "tolerance_percent"
    case min
    case max
  }

  init(
    expected: Double? = nil,
    tolerance: Double? = nil,
    tolerancePercent: Double? = nil,
    min: Double? = nil,
    max: Double? = nil
  ) {
    self.expected = expected
    self.tolerance = tolerance
    self.tolerancePercent = tolerancePercent
    self.min = min
    self.max = max
  }
}
