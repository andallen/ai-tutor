//
// BlockParameter.swift
// InkOS
//
// Parameter system for user-configurable block values.
// Parameters enable interactive blocks with sliders, toggles, and dropdowns
// that can be bound to other blocks for reactive updates.
//

import Foundation

// MARK: - ParameterID

// Type-safe identifier for parameters.
struct ParameterID: Hashable, Sendable, Codable, Equatable, CustomStringConvertible {
  let rawValue: String

  init() {
    self.rawValue = UUID().uuidString
  }

  init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  var description: String { rawValue }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

// MARK: - ParameterType

// Types of parameter controls.
enum ParameterType: String, Sendable, Codable, Equatable {
  // Numeric slider control.
  case slider

  // Boolean toggle switch.
  case toggle

  // Single-select dropdown menu.
  case dropdown

  // Text input field.
  case textField

  // Numeric stepper with +/- buttons.
  case stepper

  // Color picker.
  case colorPicker
}

// MARK: - ParameterValue

// Type-safe parameter values.
// Preserves type information when passing values between blocks.
enum ParameterValue: Sendable, Equatable {
  case string(String)
  case number(Double)
  case boolean(Bool)
  case integer(Int)

  // Convenience accessors.

  var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  var numberValue: Double? {
    if case .number(let value) = self { return value }
    if case .integer(let value) = self { return Double(value) }
    return nil
  }

  var booleanValue: Bool? {
    if case .boolean(let value) = self { return value }
    return nil
  }

  var integerValue: Int? {
    if case .integer(let value) = self { return value }
    if case .number(let value) = self { return Int(value) }
    return nil
  }
}

// MARK: - ParameterValue Codable

extension ParameterValue: Codable {
  private enum TypeKey: String, CodingKey {
    case type
    case value
  }

  private enum ValueType: String, Codable {
    case string
    case number
    case boolean
    case integer
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(ValueType.self, forKey: .type)

    switch type {
    case .string:
      let value = try container.decode(String.self, forKey: .value)
      self = .string(value)
    case .number:
      let value = try container.decode(Double.self, forKey: .value)
      self = .number(value)
    case .boolean:
      let value = try container.decode(Bool.self, forKey: .value)
      self = .boolean(value)
    case .integer:
      let value = try container.decode(Int.self, forKey: .value)
      self = .integer(value)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)

    switch self {
    case .string(let value):
      try container.encode(ValueType.string, forKey: .type)
      try container.encode(value, forKey: .value)
    case .number(let value):
      try container.encode(ValueType.number, forKey: .type)
      try container.encode(value, forKey: .value)
    case .boolean(let value):
      try container.encode(ValueType.boolean, forKey: .type)
      try container.encode(value, forKey: .value)
    case .integer(let value):
      try container.encode(ValueType.integer, forKey: .type)
      try container.encode(value, forKey: .value)
    }
  }
}

// MARK: - BlockParameterRange

// Range constraints for numeric parameters.
// Named BlockParameterRange to avoid conflict with GraphSpecificationContract.ParameterRange.
struct BlockParameterRange: Sendable, Codable, Equatable {
  // Minimum value.
  let min: Double

  // Maximum value.
  let max: Double

  // Step increment (nil for continuous).
  let step: Double?

  private enum CodingKeys: String, CodingKey {
    case min
    case max
    case step
  }

  init(min: Double, max: Double, step: Double? = nil) {
    self.min = min
    self.max = max
    self.step = step
  }

  // Checks if a value is within range.
  func contains(_ value: Double) -> Bool {
    return value >= min && value <= max
  }

  // Clamps a value to the range.
  func clamp(_ value: Double) -> Double {
    return Swift.min(max, Swift.max(min, value))
  }
}

// MARK: - ParameterOption

// Option for dropdown parameters.
struct ParameterOption: Sendable, Codable, Equatable, Identifiable {
  let id: String
  let label: String
  let value: ParameterValue

  private enum CodingKeys: String, CodingKey {
    case id
    case label
    case value
  }

  init(id: String = UUID().uuidString, label: String, value: ParameterValue) {
    self.id = id
    self.label = label
    self.value = value
  }
}

// MARK: - Parameter

// A user-configurable parameter attached to a block.
// Parameters can be bound to other blocks to create reactive relationships.
struct Parameter: Identifiable, Sendable, Equatable {
  // Unique identifier.
  let id: ParameterID

  // Internal name for programmatic access (e.g., "amplitude").
  let name: String

  // Display label for UI (e.g., "Amplitude").
  let label: String

  // Type of parameter control.
  let type: ParameterType

  // Current value.
  var value: ParameterValue

  // Range constraints for sliders/steppers.
  let range: BlockParameterRange?

  // Options for dropdown parameters.
  let options: [ParameterOption]?

  // Block IDs that react to changes in this parameter.
  let bindings: [BlockID]

  // Optional unit label (e.g., "Hz", "ms").
  let unit: String?

  // Optional description for tooltips.
  let description: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case label
    case type
    case value
    case range
    case options
    case bindings
    case unit
    case description
  }

  init(
    id: ParameterID = ParameterID(),
    name: String,
    label: String,
    type: ParameterType,
    value: ParameterValue,
    range: BlockParameterRange? = nil,
    options: [ParameterOption]? = nil,
    bindings: [BlockID] = [],
    unit: String? = nil,
    description: String? = nil
  ) {
    self.id = id
    self.name = name
    self.label = label
    self.type = type
    self.value = value
    self.range = range
    self.options = options
    self.bindings = bindings
    self.unit = unit
    self.description = description
  }
}

// MARK: - Parameter Codable

extension Parameter: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(ParameterID.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.label = try container.decode(String.self, forKey: .label)
    self.type = try container.decode(ParameterType.self, forKey: .type)
    self.value = try container.decode(ParameterValue.self, forKey: .value)
    self.range = try container.decodeIfPresent(BlockParameterRange.self, forKey: .range)
    self.options = try container.decodeIfPresent([ParameterOption].self, forKey: .options)
    self.bindings = try container.decode([BlockID].self, forKey: .bindings)
    self.unit = try container.decodeIfPresent(String.self, forKey: .unit)
    self.description = try container.decodeIfPresent(String.self, forKey: .description)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(label, forKey: .label)
    try container.encode(type, forKey: .type)
    try container.encode(value, forKey: .value)
    try container.encodeIfPresent(range, forKey: .range)
    try container.encodeIfPresent(options, forKey: .options)
    try container.encode(bindings, forKey: .bindings)
    try container.encodeIfPresent(unit, forKey: .unit)
    try container.encodeIfPresent(description, forKey: .description)
  }
}

// MARK: - Parameter Factory Methods

extension Parameter {
  // Creates a slider parameter.
  static func slider(
    name: String,
    label: String,
    value: Double,
    range: BlockParameterRange,
    unit: String? = nil,
    bindings: [BlockID] = []
  ) -> Parameter {
    Parameter(
      name: name,
      label: label,
      type: .slider,
      value: .number(value),
      range: range,
      bindings: bindings,
      unit: unit
    )
  }

  // Creates a toggle parameter.
  static func toggle(
    name: String,
    label: String,
    value: Bool,
    bindings: [BlockID] = []
  ) -> Parameter {
    Parameter(
      name: name,
      label: label,
      type: .toggle,
      value: .boolean(value),
      bindings: bindings
    )
  }

  // Creates a dropdown parameter.
  static func dropdown(
    name: String,
    label: String,
    options: [ParameterOption],
    selectedValue: ParameterValue,
    bindings: [BlockID] = []
  ) -> Parameter {
    Parameter(
      name: name,
      label: label,
      type: .dropdown,
      value: selectedValue,
      options: options,
      bindings: bindings
    )
  }

  // Creates a text field parameter.
  static func textField(
    name: String,
    label: String,
    value: String,
    bindings: [BlockID] = []
  ) -> Parameter {
    Parameter(
      name: name,
      label: label,
      type: .textField,
      value: .string(value),
      bindings: bindings
    )
  }
}
