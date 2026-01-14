//
// BlockParameterTests.swift
// InkOSTests
//
// Tests for Parameter system including ParameterValue, BlockParameterRange, and factory methods.
//

import Foundation
import Testing

@testable import InkOS

@Suite("BlockParameter Tests")
struct BlockParameterTests {

  // MARK: - ParameterID

  @Test("ParameterID generates unique IDs")
  func parameterIDUnique() {
    let id1 = ParameterID()
    let id2 = ParameterID()

    #expect(id1 != id2)
    #expect(id1.rawValue.isEmpty == false)
  }

  @Test("ParameterID can be created from string")
  func parameterIDFromString() {
    let id = ParameterID("param-123")

    #expect(id.rawValue == "param-123")
    #expect(id.description == "param-123")
  }

  // MARK: - ParameterValue

  @Test("ParameterValue preserves string type")
  func parameterValueString() {
    let value = ParameterValue.string("hello")

    #expect(value.stringValue == "hello")
    #expect(value.numberValue == nil)
    #expect(value.booleanValue == nil)
    #expect(value.integerValue == nil)
  }

  @Test("ParameterValue preserves number type")
  func parameterValueNumber() {
    let value = ParameterValue.number(42.5)

    #expect(value.numberValue == 42.5)
    #expect(value.integerValue == 42)
    #expect(value.stringValue == nil)
  }

  @Test("ParameterValue preserves boolean type")
  func parameterValueBoolean() {
    let value = ParameterValue.boolean(true)

    #expect(value.booleanValue == true)
    #expect(value.stringValue == nil)
  }

  @Test("ParameterValue preserves integer type")
  func parameterValueInteger() {
    let value = ParameterValue.integer(100)

    #expect(value.integerValue == 100)
    #expect(value.numberValue == 100.0)
    #expect(value.booleanValue == nil)
  }

  @Test("ParameterValue round-trips through JSON")
  func parameterValueCodable() throws {
    let values: [ParameterValue] = [
      .string("test"),
      .number(3.14),
      .boolean(false),
      .integer(42)
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for value in values {
      let data = try encoder.encode(value)
      let decoded = try decoder.decode(ParameterValue.self, from: data)
      #expect(decoded == value)
    }
  }

  // MARK: - BlockParameterRange

  @Test("BlockParameterRange validates min and max")
  func rangeMinMax() {
    let range = BlockParameterRange(min: 0, max: 100, step: 1)

    #expect(range.min == 0)
    #expect(range.max == 100)
    #expect(range.step == 1)
  }

  @Test("BlockParameterRange contains checks value")
  func rangeContains() {
    let range = BlockParameterRange(min: 0, max: 100)

    #expect(range.contains(50) == true)
    #expect(range.contains(0) == true)
    #expect(range.contains(100) == true)
    #expect(range.contains(-1) == false)
    #expect(range.contains(101) == false)
  }

  @Test("BlockParameterRange clamps values")
  func rangeClamps() {
    let range = BlockParameterRange(min: 0, max: 100)

    #expect(range.clamp(-10) == 0)
    #expect(range.clamp(50) == 50)
    #expect(range.clamp(150) == 100)
  }

  // MARK: - ParameterOption

  @Test("ParameterOption has label and value")
  func parameterOptionLabelValue() {
    let option = ParameterOption(label: "Low", value: .integer(1))

    #expect(option.label == "Low")
    #expect(option.value == .integer(1))
  }

  // MARK: - Parameter

  @Test("Parameter has all required fields")
  func parameterRequiredFields() {
    let param = Parameter(
      name: "speed",
      label: "Speed",
      type: .slider,
      value: .number(50)
    )

    #expect(param.name == "speed")
    #expect(param.label == "Speed")
    #expect(param.type == .slider)
    #expect(param.value == .number(50))
  }

  @Test("Parameter supports optional fields")
  func parameterOptionalFields() {
    let range = BlockParameterRange(min: 0, max: 100)
    let param = Parameter(
      name: "volume",
      label: "Volume",
      type: .slider,
      value: .number(75),
      range: range,
      unit: "dB",
      description: "Audio volume level"
    )

    #expect(param.range?.min == 0)
    #expect(param.unit == "dB")
    #expect(param.description == "Audio volume level")
  }

  @Test("Parameter supports bindings to blocks")
  func parameterBindings() {
    let blockID = BlockID()
    let param = Parameter(
      name: "time",
      label: "Time",
      type: .slider,
      value: .number(0),
      bindings: [blockID]
    )

    #expect(param.bindings.count == 1)
    #expect(param.bindings.first == blockID)
  }

  @Test("Parameter round-trips through JSON")
  func parameterCodable() throws {
    let param = Parameter(
      name: "amplitude",
      label: "Amplitude",
      type: .slider,
      value: .number(1.0),
      range: BlockParameterRange(min: 0, max: 2, step: 0.1)
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(param)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Parameter.self, from: data)

    #expect(decoded.name == param.name)
    #expect(decoded.type == param.type)
    #expect(decoded.value == param.value)
  }

  // MARK: - Parameter Factory Methods

  @Test("Parameter.slider factory creates slider")
  func parameterSliderFactory() {
    let param = Parameter.slider(
      name: "speed",
      label: "Speed",
      value: 50,
      range: BlockParameterRange(min: 0, max: 100),
      unit: "km/h"
    )

    #expect(param.type == .slider)
    #expect(param.name == "speed")
    #expect(param.value.numberValue == 50)
    #expect(param.unit == "km/h")
  }

  @Test("Parameter.toggle factory creates toggle")
  func parameterToggleFactory() {
    let param = Parameter.toggle(
      name: "enabled",
      label: "Enabled",
      value: true
    )

    #expect(param.type == .toggle)
    #expect(param.name == "enabled")
    #expect(param.value.booleanValue == true)
  }

  @Test("Parameter.dropdown factory creates dropdown")
  func parameterDropdownFactory() {
    let options = [
      ParameterOption(label: "Small", value: .string("sm")),
      ParameterOption(label: "Large", value: .string("lg"))
    ]

    let param = Parameter.dropdown(
      name: "size",
      label: "Size",
      options: options,
      selectedValue: .string("sm")
    )

    #expect(param.type == .dropdown)
    #expect(param.options?.count == 2)
    #expect(param.value.stringValue == "sm")
  }

  @Test("Parameter.textField factory creates text field")
  func parameterTextFieldFactory() {
    let param = Parameter.textField(
      name: "title",
      label: "Title",
      value: "Default Title"
    )

    #expect(param.type == .textField)
    #expect(param.name == "title")
    #expect(param.value.stringValue == "Default Title")
  }

  // MARK: - ParameterType

  @Test("ParameterType has all expected types")
  func parameterTypeAllTypes() {
    let types: [ParameterType] = [
      .slider, .toggle, .dropdown, .textField, .stepper, .colorPicker
    ]

    for type in types {
      let param = Parameter(
        name: "test",
        label: "Test",
        type: type,
        value: .number(0)
      )
      #expect(param.type == type)
    }
  }

  // MARK: - Integration

  @Test("Parameter can be attached to Block")
  func parameterInBlock() {
    let param = Parameter.slider(
      name: "time",
      label: "Time (s)",
      value: 0,
      range: BlockParameterRange(min: 0, max: 10)
    )

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["sin(x + t)"])),
      parameters: [param]
    )

    #expect(block.parameters?.count == 1)
    #expect(block.parameters?.first?.name == "time")
  }

  @Test("Multiple parameters can be attached to Block")
  func multipleParametersInBlock() {
    let param1 = Parameter.slider(name: "amplitude", label: "A", value: 1, range: BlockParameterRange(min: 0, max: 2))
    let param2 = Parameter.slider(name: "frequency", label: "f", value: 1, range: BlockParameterRange(min: 0, max: 5))
    let param3 = Parameter.toggle(name: "showGrid", label: "Show Grid", value: true)

    let block = Block(
      kind: .plot,
      properties: .plot(PlotProperties(expressions: ["A*sin(f*x)"])),
      parameters: [param1, param2, param3]
    )

    #expect(block.parameters?.count == 3)
  }
}
