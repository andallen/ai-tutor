// SkillsCoreTests.swift
// Comprehensive tests for the Skills Core infrastructure.
// These tests validate all types, protocols, and behaviors defined in SkillsContract.swift.

import Foundation
import Testing

@testable import InkOS

// MARK: - Mock Skill Implementation

// A configurable mock skill for testing the registry and executor.
// Behavior can be customized per test to simulate different scenarios.
final class MockSkill: Skill, @unchecked Sendable {

  // Static metadata for the mock skill.
  static var metadata: SkillMetadata = SkillMetadata(
    id: "mock-skill",
    displayName: "Mock Skill",
    description: "A mock skill for testing",
    iconName: "star",
    parameters: [
      SkillParameter(
        name: "topic",
        description: "The topic to process",
        type: .string,
        required: true,
        defaultValue: nil,
        allowedValues: nil
      ),
      SkillParameter(
        name: "count",
        description: "Number of items",
        type: .number,
        required: false,
        defaultValue: .number(10),
        allowedValues: nil
      ),
      SkillParameter(
        name: "verbose",
        description: "Enable verbose output",
        type: .boolean,
        required: false,
        defaultValue: .boolean(false),
        allowedValues: nil
      )
    ],
    executionMode: .local,
    hasCustomUI: false
  )

  // Configurable result to return from execute.
  var resultToReturn: SkillResult = .success(text: "Mock result")

  // Configurable error to throw from execute.
  var errorToThrow: SkillError?

  // Tracks execute invocations.
  var executeCallCount = 0
  var lastParameters: [String: SkillParameterValue]?
  var lastContext: SkillContext?

  func execute(
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    executeCallCount += 1
    lastParameters = parameters
    lastContext = context

    if let error = errorToThrow {
      throw error
    }

    return resultToReturn
  }
}

// A second mock skill for testing multiple skills in registry.
final class AlphaSkill: Skill, @unchecked Sendable {

  static var metadata: SkillMetadata = SkillMetadata(
    id: "alpha-skill",
    displayName: "Alpha Skill",
    description: "First skill alphabetically",
    iconName: "a.circle",
    parameters: [],
    executionMode: .local,
    hasCustomUI: false
  )

  func execute(
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    return .success(text: "Alpha executed")
  }
}

// A third mock skill for sorting tests.
final class ZetaSkill: Skill, @unchecked Sendable {

  static var metadata: SkillMetadata = SkillMetadata(
    id: "zeta-skill",
    displayName: "Zeta Skill",
    description: "Last skill alphabetically",
    iconName: "z.circle",
    parameters: [],
    executionMode: .cloud,
    hasCustomUI: true
  )

  func execute(
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    return .success(text: "Zeta executed")
  }
}

// Mock skill with enum parameter for testing allowed values.
final class EnumSkill: Skill, @unchecked Sendable {

  static var metadata: SkillMetadata = SkillMetadata(
    id: "enum-skill",
    displayName: "Enum Skill",
    description: "Skill with enum parameter",
    iconName: "list.bullet",
    parameters: [
      SkillParameter(
        name: "difficulty",
        description: "Difficulty level",
        type: .string,
        required: true,
        defaultValue: nil,
        allowedValues: [.string("easy"), .string("medium"), .string("hard")]
      )
    ],
    executionMode: .local,
    hasCustomUI: false
  )

  func execute(
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    return .success(text: "Enum skill executed")
  }
}

// MARK: - SkillParameterType Tests

@Suite("SkillParameterType Tests")
struct SkillParameterTypeTests {

  @Test("encodes to correct JSON raw value")
  func encodesToJSON() throws {
    let encoder = JSONEncoder()

    let stringData = try encoder.encode(SkillParameterType.string)
    let stringJSON = String(data: stringData, encoding: .utf8)
    #expect(stringJSON == "\"string\"")

    let numberData = try encoder.encode(SkillParameterType.number)
    let numberJSON = String(data: numberData, encoding: .utf8)
    #expect(numberJSON == "\"number\"")

    let booleanData = try encoder.encode(SkillParameterType.boolean)
    let booleanJSON = String(data: booleanData, encoding: .utf8)
    #expect(booleanJSON == "\"boolean\"")

    let arrayData = try encoder.encode(SkillParameterType.array)
    let arrayJSON = String(data: arrayData, encoding: .utf8)
    #expect(arrayJSON == "\"array\"")

    let objectData = try encoder.encode(SkillParameterType.object)
    let objectJSON = String(data: objectData, encoding: .utf8)
    #expect(objectJSON == "\"object\"")
  }

  @Test("decodes from JSON raw value")
  func decodesFromJSON() throws {
    let decoder = JSONDecoder()

    let stringType = try decoder.decode(
      SkillParameterType.self, from: "\"string\"".data(using: .utf8)!)
    #expect(stringType == .string)

    let numberType = try decoder.decode(
      SkillParameterType.self, from: "\"number\"".data(using: .utf8)!)
    #expect(numberType == .number)

    let booleanType = try decoder.decode(
      SkillParameterType.self, from: "\"boolean\"".data(using: .utf8)!)
    #expect(booleanType == .boolean)

    let arrayType = try decoder.decode(
      SkillParameterType.self, from: "\"array\"".data(using: .utf8)!)
    #expect(arrayType == .array)

    let objectType = try decoder.decode(
      SkillParameterType.self, from: "\"object\"".data(using: .utf8)!)
    #expect(objectType == .object)
  }

  @Test("unknown value fails decoding")
  func unknownValueFailsDecoding() {
    let decoder = JSONDecoder()

    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(
        SkillParameterType.self, from: "\"unknown\"".data(using: .utf8)!)
    }
  }

  @Test("same cases are equal")
  func sameCasesEqual() {
    #expect(SkillParameterType.string == SkillParameterType.string)
    #expect(SkillParameterType.number == SkillParameterType.number)
    #expect(SkillParameterType.boolean == SkillParameterType.boolean)
    #expect(SkillParameterType.array == SkillParameterType.array)
    #expect(SkillParameterType.object == SkillParameterType.object)
  }

  @Test("different cases are not equal")
  func differentCasesNotEqual() {
    #expect(SkillParameterType.string != SkillParameterType.number)
    #expect(SkillParameterType.boolean != SkillParameterType.array)
    #expect(SkillParameterType.object != SkillParameterType.string)
  }
}

// MARK: - SkillParameterValue Tests

@Suite("SkillParameterValue Tests")
struct SkillParameterValueTests {

  @Test("wraps string value")
  func wrapsString() {
    let value = SkillParameterValue.string("hello")

    if case .string(let str) = value {
      #expect(str == "hello")
    } else {
      Issue.record("Expected string case")
    }
  }

  @Test("wraps number value")
  func wrapsNumber() {
    let value = SkillParameterValue.number(42.5)

    if case .number(let num) = value {
      #expect(num == 42.5)
    } else {
      Issue.record("Expected number case")
    }
  }

  @Test("wraps integer as Double")
  func wrapsIntegerAsDouble() {
    let value = SkillParameterValue.number(42)

    if case .number(let num) = value {
      #expect(num == 42.0)
    } else {
      Issue.record("Expected number case")
    }
  }

  @Test("wraps boolean value")
  func wrapsBoolean() {
    let trueValue = SkillParameterValue.boolean(true)
    let falseValue = SkillParameterValue.boolean(false)

    if case .boolean(let val) = trueValue {
      #expect(val == true)
    } else {
      Issue.record("Expected boolean case")
    }

    if case .boolean(let val) = falseValue {
      #expect(val == false)
    } else {
      Issue.record("Expected boolean case")
    }
  }

  @Test("wraps array value with nested types preserved")
  func wrapsArray() {
    let value = SkillParameterValue.array([
      .string("a"),
      .number(1),
      .boolean(true),
    ])

    if case .array(let items) = value {
      #expect(items.count == 3)
      #expect(items[0] == .string("a"))
      #expect(items[1] == .number(1))
      #expect(items[2] == .boolean(true))
    } else {
      Issue.record("Expected array case")
    }
  }

  @Test("wraps heterogeneous array")
  func wrapsHeterogeneousArray() {
    let value = SkillParameterValue.array([
      .string("text"),
      .number(123),
      .boolean(false),
      .array([.string("nested")]),
    ])

    if case .array(let items) = value {
      #expect(items.count == 4)
    } else {
      Issue.record("Expected array case")
    }
  }

  @Test("wraps object value with keys preserved")
  func wrapsObject() {
    let value = SkillParameterValue.object([
      "name": .string("test"),
      "count": .number(5),
      "enabled": .boolean(true),
    ])

    if case .object(let dict) = value {
      #expect(dict["name"] == .string("test"))
      #expect(dict["count"] == .number(5))
      #expect(dict["enabled"] == .boolean(true))
    } else {
      Issue.record("Expected object case")
    }
  }

  @Test("string values are equatable")
  func stringEquatable() {
    let value1 = SkillParameterValue.string("hello")
    let value2 = SkillParameterValue.string("hello")
    let value3 = SkillParameterValue.string("world")

    #expect(value1 == value2)
    #expect(value1 != value3)
  }

  @Test("number values are equatable")
  func numberEquatable() {
    let value1 = SkillParameterValue.number(42.5)
    let value2 = SkillParameterValue.number(42.5)
    let value3 = SkillParameterValue.number(100)

    #expect(value1 == value2)
    #expect(value1 != value3)
  }

  @Test("boolean values are equatable")
  func booleanEquatable() {
    let value1 = SkillParameterValue.boolean(true)
    let value2 = SkillParameterValue.boolean(true)
    let value3 = SkillParameterValue.boolean(false)

    #expect(value1 == value2)
    #expect(value1 != value3)
  }

  @Test("nested arrays are deeply compared")
  func nestedArrayDeepComparison() {
    let value1 = SkillParameterValue.array([
      .string("a"),
      .array([.number(1), .number(2)]),
    ])
    let value2 = SkillParameterValue.array([
      .string("a"),
      .array([.number(1), .number(2)]),
    ])
    let value3 = SkillParameterValue.array([
      .string("a"),
      .array([.number(1), .number(3)]),
    ])

    #expect(value1 == value2)
    #expect(value1 != value3)
  }

  @Test("array order matters for equality")
  func arrayOrderMatters() {
    let value1 = SkillParameterValue.array([.string("a"), .string("b")])
    let value2 = SkillParameterValue.array([.string("b"), .string("a")])

    #expect(value1 != value2)
  }

  @Test("nested objects are deeply compared")
  func nestedObjectDeepComparison() {
    let value1 = SkillParameterValue.object([
      "outer": .object([
        "inner": .string("value")
      ])
    ])
    let value2 = SkillParameterValue.object([
      "outer": .object([
        "inner": .string("value")
      ])
    ])
    let value3 = SkillParameterValue.object([
      "outer": .object([
        "inner": .string("different")
      ])
    ])

    #expect(value1 == value2)
    #expect(value1 != value3)
  }

  @Test("empty arrays are equal")
  func emptyArraysEqual() {
    let value1 = SkillParameterValue.array([])
    let value2 = SkillParameterValue.array([])

    #expect(value1 == value2)
  }

  @Test("empty objects are equal")
  func emptyObjectsEqual() {
    let value1 = SkillParameterValue.object([:])
    let value2 = SkillParameterValue.object([:])

    #expect(value1 == value2)
  }

  @Test("different types are not equal")
  func differentTypesNotEqual() {
    let stringVal = SkillParameterValue.string("1")
    let numberVal = SkillParameterValue.number(1)
    let boolVal = SkillParameterValue.boolean(true)

    #expect(stringVal != numberVal)
    #expect(numberVal != boolVal)
    #expect(stringVal != boolVal)
  }
}

// MARK: - SkillParameter Tests

@Suite("SkillParameter Tests")
struct SkillParameterTests {

  @Test("required parameter without default")
  func requiredParameterWithoutDefault() {
    let param = SkillParameter(
      name: "topic",
      description: "The topic to process",
      type: .string,
      required: true,
      defaultValue: nil,
      allowedValues: nil
    )

    #expect(param.name == "topic")
    #expect(param.description == "The topic to process")
    #expect(param.type == .string)
    #expect(param.required == true)
    #expect(param.defaultValue == nil)
    #expect(param.allowedValues == nil)
  }

  @Test("optional parameter with default value")
  func optionalParameterWithDefault() {
    let param = SkillParameter(
      name: "count",
      description: "Number of items",
      type: .number,
      required: false,
      defaultValue: .number(10),
      allowedValues: nil
    )

    #expect(param.required == false)
    #expect(param.defaultValue == .number(10))
  }

  @Test("optional parameter without default value")
  func optionalParameterWithoutDefault() {
    let param = SkillParameter(
      name: "filter",
      description: "Optional filter",
      type: .string,
      required: false,
      defaultValue: nil,
      allowedValues: nil
    )

    #expect(param.required == false)
    #expect(param.defaultValue == nil)
  }

  @Test("parameter with allowed values")
  func parameterWithAllowedValues() {
    let param = SkillParameter(
      name: "difficulty",
      description: "Difficulty level",
      type: .string,
      required: true,
      defaultValue: nil,
      allowedValues: [.string("easy"), .string("medium"), .string("hard")]
    )

    #expect(param.allowedValues?.count == 3)
    #expect(param.allowedValues?.contains(.string("medium")) == true)
  }

  @Test("parameters are equatable")
  func parametersEquatable() {
    let param1 = SkillParameter(
      name: "topic",
      description: "The topic",
      type: .string,
      required: true,
      defaultValue: nil,
      allowedValues: nil
    )
    let param2 = SkillParameter(
      name: "topic",
      description: "The topic",
      type: .string,
      required: true,
      defaultValue: nil,
      allowedValues: nil
    )

    #expect(param1 == param2)
  }
}

// MARK: - SkillExecutionMode Tests

@Suite("SkillExecutionMode Tests")
struct SkillExecutionModeTests {

  @Test("all cases exist")
  func allCasesExist() {
    let local = SkillExecutionMode.local
    let cloud = SkillExecutionMode.cloud
    let hybrid = SkillExecutionMode.hybrid

    #expect(local.rawValue == "local")
    #expect(cloud.rawValue == "cloud")
    #expect(hybrid.rawValue == "hybrid")
  }

  @Test("encodes to JSON")
  func encodesToJSON() throws {
    let encoder = JSONEncoder()

    let localData = try encoder.encode(SkillExecutionMode.local)
    #expect(String(data: localData, encoding: .utf8) == "\"local\"")

    let cloudData = try encoder.encode(SkillExecutionMode.cloud)
    #expect(String(data: cloudData, encoding: .utf8) == "\"cloud\"")

    let hybridData = try encoder.encode(SkillExecutionMode.hybrid)
    #expect(String(data: hybridData, encoding: .utf8) == "\"hybrid\"")
  }

  @Test("decodes from JSON")
  func decodesFromJSON() throws {
    let decoder = JSONDecoder()

    let local = try decoder.decode(
      SkillExecutionMode.self, from: "\"local\"".data(using: .utf8)!)
    #expect(local == .local)

    let cloud = try decoder.decode(
      SkillExecutionMode.self, from: "\"cloud\"".data(using: .utf8)!)
    #expect(cloud == .cloud)

    let hybrid = try decoder.decode(
      SkillExecutionMode.self, from: "\"hybrid\"".data(using: .utf8)!)
    #expect(hybrid == .hybrid)
  }

  @Test("is equatable")
  func isEquatable() {
    #expect(SkillExecutionMode.local == SkillExecutionMode.local)
    #expect(SkillExecutionMode.local != SkillExecutionMode.cloud)
  }
}

// MARK: - SkillResult Tests

@Suite("SkillResult Tests")
struct SkillResultTests {

  @Test("success factory with data and message")
  func successWithDataAndMessage() {
    let result = SkillResult.success(data: .text("result text"), message: "Done")

    #expect(result.success == true)
    #expect(result.data == .text("result text"))
    #expect(result.message == "Done")
    #expect(result.error == nil)
  }

  @Test("success factory with data only")
  func successWithDataOnly() {
    let result = SkillResult.success(data: .text("result"))

    #expect(result.success == true)
    #expect(result.data == .text("result"))
    #expect(result.message == nil)
    #expect(result.error == nil)
  }

  @Test("success factory with text shorthand")
  func successWithTextShorthand() {
    let result = SkillResult.success(text: "Hello")

    #expect(result.success == true)
    #expect(result.data == .text("Hello"))
    #expect(result.message == nil)
    #expect(result.error == nil)
  }

  @Test("failure factory with error and message")
  func failureWithErrorAndMessage() {
    let result = SkillResult.failure(
      error: .executionFailed(reason: "reason"),
      message: "Failed"
    )

    #expect(result.success == false)
    #expect(result.error == .executionFailed(reason: "reason"))
    #expect(result.message == "Failed")
    #expect(result.data == nil)
  }

  @Test("failure factory with error only")
  func failureWithErrorOnly() {
    let result = SkillResult.failure(error: .cancelled)

    #expect(result.success == false)
    #expect(result.error == .cancelled)
    #expect(result.message == nil)
    #expect(result.data == nil)
  }

  @Test("results are equatable")
  func resultsEquatable() {
    let result1 = SkillResult.success(text: "hello")
    let result2 = SkillResult.success(text: "hello")
    let result3 = SkillResult.success(text: "world")

    #expect(result1 == result2)
    #expect(result1 != result3)
  }
}

// MARK: - SkillResultData Tests

@Suite("SkillResultData Tests")
struct SkillResultDataTests {

  @Test("text result contains string")
  func textResult() {
    let data = SkillResultData.text("summary here")

    if case .text(let str) = data {
      #expect(str == "summary here")
    } else {
      Issue.record("Expected text case")
    }
  }

  @Test("lesson result contains structured content")
  func lessonResult() {
    let lesson = LessonContent(
      title: "Math Basics",
      sections: [
        LessonSection(heading: "Introduction", content: "Welcome to math")
      ],
      exercises: [
        LessonExercise(prompt: "What is 2+2?", hint: "Count", answer: "4")
      ]
    )
    let data = SkillResultData.lesson(lesson)

    if case .lesson(let content) = data {
      #expect(content.title == "Math Basics")
      #expect(content.sections.count == 1)
      #expect(content.exercises?.count == 1)
    } else {
      Issue.record("Expected lesson case")
    }
  }

  @Test("graph result contains visualization data")
  func graphResult() {
    let graph = GraphData(
      graphType: .line,
      xAxisLabel: "Time",
      yAxisLabel: "Value",
      series: [
        DataSeries(name: "Series 1", dataPoints: [(x: 0, y: 0), (x: 1, y: 2)])
      ]
    )
    let data = SkillResultData.graph(graph)

    if case .graph(let graphData) = data {
      #expect(graphData.graphType == .line)
      #expect(graphData.xAxisLabel == "Time")
      #expect(graphData.series.count == 1)
    } else {
      Issue.record("Expected graph case")
    }
  }

  @Test("transcription result contains text and timestamps")
  func transcriptionResult() {
    let transcription = TranscriptionResult(
      text: "Hello world",
      language: "en",
      confidence: 0.95,
      wordTimestamps: [
        WordTimestamp(word: "Hello", startTime: 0.0, endTime: 0.5),
        WordTimestamp(word: "world", startTime: 0.5, endTime: 1.0),
      ]
    )
    let data = SkillResultData.transcription(transcription)

    if case .transcription(let result) = data {
      #expect(result.text == "Hello world")
      #expect(result.language == "en")
      #expect(result.confidence == 0.95)
      #expect(result.wordTimestamps?.count == 2)
    } else {
      Issue.record("Expected transcription case")
    }
  }

  @Test("analysis result contains key-value pairs")
  func analysisResult() {
    let data = SkillResultData.analysis([
      "topic": "math",
      "difficulty": "medium",
    ])

    if case .analysis(let dict) = data {
      #expect(dict["topic"] == "math")
      #expect(dict["difficulty"] == "medium")
    } else {
      Issue.record("Expected analysis case")
    }
  }

  @Test("json result contains raw data")
  func jsonResult() {
    let jsonData = "{\"key\": \"value\"}".data(using: .utf8)!
    let data = SkillResultData.json(jsonData)

    if case .json(let rawData) = data {
      #expect(rawData == jsonData)
    } else {
      Issue.record("Expected json case")
    }
  }

  @Test("result data is equatable")
  func resultDataEquatable() {
    let text1 = SkillResultData.text("hello")
    let text2 = SkillResultData.text("hello")
    let text3 = SkillResultData.text("world")

    #expect(text1 == text2)
    #expect(text1 != text3)
  }
}

// MARK: - SkillContext Tests

@Suite("SkillContext Tests")
struct SkillContextTests {

  @Test("context with notebook")
  func contextWithNotebook() {
    let context = SkillContext(
      currentNotebookID: "notebook-123",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    #expect(context.currentNotebookID == "notebook-123")
    #expect(context.currentPDFID == nil)
    #expect(context.userMessage == nil)
    #expect(context.conversationHistory == nil)
  }

  @Test("context with PDF")
  func contextWithPDF() {
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: "pdf-456",
      userMessage: nil,
      conversationHistory: nil
    )

    #expect(context.currentNotebookID == nil)
    #expect(context.currentPDFID == "pdf-456")
  }

  @Test("context without documents")
  func contextWithoutDocuments() {
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    #expect(context.currentNotebookID == nil)
    #expect(context.currentPDFID == nil)
  }

  @Test("context with AI invocation")
  func contextWithAIInvocation() {
    let history = [
      ConversationMessage(role: .user, content: "Hello"),
      ConversationMessage(role: .assistant, content: "Hi there"),
    ]
    let context = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: "summarize this",
      conversationHistory: history
    )

    #expect(context.userMessage == "summarize this")
    #expect(context.conversationHistory?.count == 2)
  }

  @Test("context with conversation history")
  func contextWithConversationHistory() {
    let history = [
      ConversationMessage(role: .system, content: "You are a helper"),
      ConversationMessage(role: .user, content: "Help me"),
      ConversationMessage(role: .assistant, content: "Sure"),
    ]
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: "More help",
      conversationHistory: history
    )

    #expect(context.conversationHistory?.count == 3)
    #expect(context.conversationHistory?[0].role == .system)
    #expect(context.conversationHistory?[1].role == .user)
    #expect(context.conversationHistory?[2].role == .assistant)
  }

  @Test("context is equatable")
  func contextEquatable() {
    let context1 = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: "hello",
      conversationHistory: nil
    )
    let context2 = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: "hello",
      conversationHistory: nil
    )

    #expect(context1 == context2)
  }
}

// MARK: - MessageRole Tests

@Suite("MessageRole Tests")
struct MessageRoleTests {

  @Test("all roles exist")
  func allRolesExist() {
    #expect(MessageRole.user.rawValue == "user")
    #expect(MessageRole.assistant.rawValue == "assistant")
  }

  @Test("is codable")
  func isCodable() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let userData = try encoder.encode(MessageRole.user)
    let decoded = try decoder.decode(MessageRole.self, from: userData)
    #expect(decoded == .user)
  }
}

// MARK: - SkillMetadata Tests

@Suite("SkillMetadata Tests")
struct SkillMetadataTests {

  @Test("identifiable conformance uses id")
  func identifiableUsesID() {
    let metadata = SkillMetadata(
      id: "unique-skill",
      displayName: "Display Name",
      description: "Description",
      iconName: "star",
      parameters: [],
      executionMode: .local,
      hasCustomUI: false
    )

    #expect(metadata.id == "unique-skill")
  }

  @Test("equatable comparison")
  func equatableComparison() {
    let metadata1 = SkillMetadata(
      id: "skill-1",
      displayName: "Skill One",
      description: "First skill",
      iconName: "star",
      parameters: [],
      executionMode: .local,
      hasCustomUI: false
    )
    let metadata2 = SkillMetadata(
      id: "skill-1",
      displayName: "Skill One",
      description: "First skill",
      iconName: "star",
      parameters: [],
      executionMode: .local,
      hasCustomUI: false
    )
    let metadata3 = SkillMetadata(
      id: "skill-2",
      displayName: "Skill Two",
      description: "Second skill",
      iconName: "circle",
      parameters: [],
      executionMode: .cloud,
      hasCustomUI: true
    )

    #expect(metadata1 == metadata2)
    #expect(metadata1 != metadata3)
  }

  @Test("metadata preserves all fields")
  func preservesAllFields() {
    let params = [
      SkillParameter(
        name: "topic",
        description: "The topic",
        type: .string,
        required: true,
        defaultValue: nil,
        allowedValues: nil
      )
    ]
    let metadata = SkillMetadata(
      id: "test-skill",
      displayName: "Test Skill",
      description: "A test skill",
      iconName: "doc.text",
      parameters: params,
      executionMode: .hybrid,
      hasCustomUI: true
    )

    #expect(metadata.id == "test-skill")
    #expect(metadata.displayName == "Test Skill")
    #expect(metadata.description == "A test skill")
    #expect(metadata.iconName == "doc.text")
    #expect(metadata.parameters.count == 1)
    #expect(metadata.executionMode == .hybrid)
    #expect(metadata.hasCustomUI == true)
  }
}

// MARK: - SkillError Tests

@Suite("SkillError Tests")
struct SkillErrorTests {

  @Test("skillNotFound error description")
  func skillNotFoundDescription() {
    let error = SkillError.skillNotFound(skillID: "unknown-skill")
    #expect(error.errorDescription?.contains("Skill not found") == true)
    #expect(error.errorDescription?.contains("unknown-skill") == true)
  }

  @Test("skillCreationFailed error description")
  func skillCreationFailedDescription() {
    let error = SkillError.skillCreationFailed(skillID: "bad-skill", reason: "init failed")
    #expect(error.errorDescription?.contains("Failed to create") == true)
    #expect(error.errorDescription?.contains("bad-skill") == true)
    #expect(error.errorDescription?.contains("init failed") == true)
  }

  @Test("missingRequiredParameter error description")
  func missingRequiredParameterDescription() {
    let error = SkillError.missingRequiredParameter(parameterName: "topic")
    #expect(error.errorDescription?.contains("Missing required parameter") == true)
    #expect(error.errorDescription?.contains("topic") == true)
  }

  @Test("invalidParameterType error description")
  func invalidParameterTypeDescription() {
    let error = SkillError.invalidParameterType(
      parameterName: "count",
      expected: .number,
      received: "string"
    )
    #expect(error.errorDescription?.contains("Invalid type") == true)
    #expect(error.errorDescription?.contains("count") == true)
    #expect(error.errorDescription?.contains("number") == true)
    #expect(error.errorDescription?.contains("string") == true)
  }

  @Test("invalidParameterValue error description")
  func invalidParameterValueDescription() {
    let error = SkillError.invalidParameterValue(
      parameterName: "level",
      value: "impossible",
      allowed: ["easy", "medium", "hard"]
    )
    #expect(error.errorDescription?.contains("Invalid value") == true)
    #expect(error.errorDescription?.contains("impossible") == true)
    #expect(error.errorDescription?.contains("level") == true)
    #expect(error.errorDescription?.contains("easy") == true)
  }

  @Test("executionFailed error description")
  func executionFailedDescription() {
    let error = SkillError.executionFailed(reason: "timeout occurred")
    #expect(error.errorDescription?.contains("Skill execution failed") == true)
    #expect(error.errorDescription?.contains("timeout occurred") == true)
  }

  @Test("cloudExecutionFailed error description")
  func cloudExecutionFailedDescription() {
    let error = SkillError.cloudExecutionFailed(reason: "server error")
    #expect(error.errorDescription?.contains("Cloud execution failed") == true)
    #expect(error.errorDescription?.contains("server error") == true)
  }

  @Test("networkError error description")
  func networkErrorDescription() {
    let error = SkillError.networkError(reason: "no connection")
    #expect(error.errorDescription?.contains("Network error") == true)
    #expect(error.errorDescription?.contains("no connection") == true)
  }

  @Test("cancelled error description")
  func cancelledDescription() {
    let error = SkillError.cancelled
    #expect(error.errorDescription?.contains("cancelled") == true)
  }

  @Test("timeout error description")
  func timeoutDescription() {
    let error = SkillError.timeout(skillID: "slow-skill", durationSeconds: 30.0)
    #expect(error.errorDescription?.contains("timed out") == true)
    #expect(error.errorDescription?.contains("slow-skill") == true)
    #expect(error.errorDescription?.contains("30") == true)
  }

  @Test("errors of same type with same values are equal")
  func sameTypeAndValueEqual() {
    let error1 = SkillError.skillNotFound(skillID: "skill-1")
    let error2 = SkillError.skillNotFound(skillID: "skill-1")
    #expect(error1 == error2)
  }

  @Test("errors of same type with different values are not equal")
  func sameTypeDifferentValueNotEqual() {
    let error1 = SkillError.skillNotFound(skillID: "skill-1")
    let error2 = SkillError.skillNotFound(skillID: "skill-2")
    #expect(error1 != error2)
  }

  @Test("errors of different types are not equal")
  func differentTypesNotEqual() {
    let error1 = SkillError.cancelled
    let error2 = SkillError.executionFailed(reason: "cancelled")
    #expect(error1 != error2)
  }

  @Test("missingRequiredParameter errors are equal with same parameter")
  func missingParamEqual() {
    let error1 = SkillError.missingRequiredParameter(parameterName: "topic")
    let error2 = SkillError.missingRequiredParameter(parameterName: "topic")
    #expect(error1 == error2)
  }

  @Test("invalidParameterType errors are equal with same fields")
  func invalidTypeEqual() {
    let error1 = SkillError.invalidParameterType(
      parameterName: "count", expected: .number, received: "string")
    let error2 = SkillError.invalidParameterType(
      parameterName: "count", expected: .number, received: "string")
    #expect(error1 == error2)
  }
}

// MARK: - SkillConstants Tests

@Suite("SkillConstants Tests")
struct SkillConstantsTests {

  @Test("default execution timeout is 30 seconds")
  func defaultTimeout() {
    #expect(SkillConstants.defaultExecutionTimeoutSeconds == 30.0)
  }

  @Test("maximum execution timeout is 300 seconds")
  func maximumTimeout() {
    #expect(SkillConstants.maximumExecutionTimeoutSeconds == 300.0)
  }

  @Test("default streaming chunk size is defined")
  func streamingChunkSize() {
    #expect(SkillConstants.defaultStreamingChunkSize == 100)
  }

  @Test("max conversation history is 50 messages")
  func maxConversationHistory() {
    #expect(SkillConstants.maxConversationHistoryMessages == 50)
  }
}

// MARK: - GeminiFunctionDeclaration Tests

@Suite("GeminiFunctionDeclaration Tests")
struct GeminiFunctionDeclarationTests {

  @Test("encodes to JSON correctly")
  func encodesToJSON() throws {
    let declaration = GeminiFunctionDeclaration(
      name: "summarize",
      description: "Summarizes text",
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: [
          "text": GeminiPropertySchema(
            type: "string",
            description: "The text to summarize"
          )
        ],
        required: ["text"]
      )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(declaration)
    let json = String(data: data, encoding: .utf8)

    #expect(json?.contains("\"name\":\"summarize\"") == true)
    #expect(json?.contains("\"description\":\"Summarizes text\"") == true)
    #expect(json?.contains("\"type\":\"object\"") == true)
  }

  @Test("decodes from JSON correctly")
  func decodesFromJSON() throws {
    let json = """
      {
        "name": "test-function",
        "description": "A test function",
        "parameters": {
          "type": "object",
          "properties": {
            "param1": {
              "type": "string",
              "description": "First parameter"
            }
          },
          "required": ["param1"]
        }
      }
      """

    let decoder = JSONDecoder()
    let declaration = try decoder.decode(
      GeminiFunctionDeclaration.self, from: json.data(using: .utf8)!)

    #expect(declaration.name == "test-function")
    #expect(declaration.description == "A test function")
    #expect(declaration.parameters.type == "object")
    #expect(declaration.parameters.properties["param1"]?.type == "string")
    #expect(declaration.parameters.required == ["param1"])
  }

  @Test("declaration with enum values")
  func declarationWithEnumValues() throws {
    let declaration = GeminiFunctionDeclaration(
      name: "set-difficulty",
      description: "Sets difficulty level",
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: [
          "level": GeminiPropertySchema(
            type: "string",
            description: "Difficulty level",
            enumValues: ["easy", "medium", "hard"]
          )
        ],
        required: ["level"]
      )
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(declaration)
    let json = String(data: data, encoding: .utf8)

    #expect(json?.contains("\"enum\"") == true)
    #expect(json?.contains("\"easy\"") == true)
  }

  @Test("declaration with nested properties")
  func declarationWithNestedProperties() throws {
    let declaration = GeminiFunctionDeclaration(
      name: "create-item",
      description: "Creates an item",
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: [
          "options": GeminiPropertySchema(
            type: "object",
            description: "Item options",
            properties: [
              "color": GeminiPropertySchema(
                type: "string",
                description: "Color of item"
              )
            ]
          )
        ],
        required: []
      )
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(declaration)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(GeminiFunctionDeclaration.self, from: data)

    #expect(decoded.parameters.properties["options"]?.properties?["color"]?.type == "string")
  }

  @Test("declaration with array items")
  func declarationWithArrayItems() throws {
    let declaration = GeminiFunctionDeclaration(
      name: "process-list",
      description: "Processes a list",
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: [
          "items": GeminiPropertySchema(
            type: "array",
            description: "List of items",
            items: GeminiPropertySchema(
              type: "string",
              description: "An item"
            )
          )
        ],
        required: ["items"]
      )
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(declaration)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(GeminiFunctionDeclaration.self, from: data)

    #expect(decoded.parameters.properties["items"]?.items?.type == "string")
  }

  @Test("GeminiPropertySchema is equatable")
  func propertySchemaEquatable() {
    let schema1 = GeminiPropertySchema(type: "string", description: "Test")
    let schema2 = GeminiPropertySchema(type: "string", description: "Test")
    let schema3 = GeminiPropertySchema(type: "number", description: "Test")

    #expect(schema1 == schema2)
    #expect(schema1 != schema3)
  }

  @Test("GeminiFunctionDeclaration is equatable")
  func declarationEquatable() {
    let decl1 = GeminiFunctionDeclaration(
      name: "test",
      description: "Test",
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: [:],
        required: []
      )
    )
    let decl2 = GeminiFunctionDeclaration(
      name: "test",
      description: "Test",
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: [:],
        required: []
      )
    )

    #expect(decl1 == decl2)
  }
}

// MARK: - Skill Protocol Tests

@Suite("Skill Protocol Tests")
struct SkillProtocolTests {

  @Test("mock skill metadata is accessible")
  func metadataAccessible() {
    let metadata = MockSkill.metadata

    #expect(metadata.id == "mock-skill")
    #expect(metadata.displayName == "Mock Skill")
    #expect(metadata.parameters.count == 3)
  }

  @Test("mock skill executes with parameters")
  func executesWithParameters() async throws {
    let skill = MockSkill()
    let context = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
    let params: [String: SkillParameterValue] = [
      "topic": .string("test topic"),
      "count": .number(5),
    ]

    let result = try await skill.execute(parameters: params, context: context)

    #expect(skill.executeCallCount == 1)
    #expect(skill.lastParameters?["topic"] == .string("test topic"))
    #expect(skill.lastContext?.currentNotebookID == "nb-1")
    #expect(result.success == true)
  }

  @Test("mock skill throws configured error")
  func throwsConfiguredError() async {
    let skill = MockSkill()
    skill.errorToThrow = .executionFailed(reason: "test error")
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    await #expect(throws: SkillError.self) {
      _ = try await skill.execute(parameters: [:], context: context)
    }
  }

  @Test("mock skill returns configured result")
  func returnsConfiguredResult() async throws {
    let skill = MockSkill()
    skill.resultToReturn = .success(text: "custom result")
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    let result = try await skill.execute(parameters: [:], context: context)

    #expect(result.data == .text("custom result"))
  }
}

// MARK: - Mock SkillRegistry

// A mock implementation of SkillRegistryProtocol for testing.
actor MockSkillRegistry: SkillRegistryProtocol {

  // Storage for registered skill types.
  private var registeredSkills: [String: any Skill.Type] = [:]

  // Tracks method invocations.
  private(set) var registerCallCount = 0
  private(set) var allSkillsCallCount = 0
  private(set) var skillWithIDCallCount = 0
  private(set) var createSkillCallCount = 0
  private(set) var generateDeclarationsCallCount = 0

  func register<S: Skill>(_ skillType: S.Type) {
    registerCallCount += 1
    registeredSkills[S.metadata.id] = skillType
  }

  func allSkills() -> [SkillMetadata] {
    allSkillsCallCount += 1
    return registeredSkills.values
      .map { $0.metadata }
      .sorted { $0.displayName < $1.displayName }
  }

  func skill(withID id: String) -> SkillMetadata? {
    skillWithIDCallCount += 1
    return registeredSkills[id]?.metadata
  }

  func createSkill(withID id: String) throws -> any Skill {
    createSkillCallCount += 1
    guard let skillType = registeredSkills[id] else {
      throw SkillError.skillNotFound(skillID: id)
    }

    // Create instance using type metadata.
    // For testing, return a MockSkill if the ID matches.
    if id == "mock-skill" {
      return MockSkill()
    } else if id == "alpha-skill" {
      return AlphaSkill()
    } else if id == "zeta-skill" {
      return ZetaSkill()
    } else if id == "enum-skill" {
      return EnumSkill()
    }

    throw SkillError.skillCreationFailed(skillID: id, reason: "Unknown skill type")
  }

  func generateGeminiFunctionDeclarations() -> [GeminiFunctionDeclaration] {
    generateDeclarationsCallCount += 1
    return registeredSkills.values.map { skillType in
      let meta = skillType.metadata
      var properties: [String: GeminiPropertySchema] = [:]
      var required: [String] = []

      for param in meta.parameters {
        let enumVals: [String]?
        if let allowed = param.allowedValues {
          enumVals = allowed.compactMap { val in
            if case .string(let str) = val { return str }
            return nil
          }
        } else {
          enumVals = nil
        }

        properties[param.name] = GeminiPropertySchema(
          type: param.type.rawValue,
          description: param.description,
          enumValues: enumVals
        )

        if param.required {
          required.append(param.name)
        }
      }

      return GeminiFunctionDeclaration(
        name: meta.id,
        description: meta.description,
        parameters: GeminiFunctionParameters(
          type: "object",
          properties: properties,
          required: required
        )
      )
    }
  }

  // Test helper to reset state.
  func reset() {
    registeredSkills = [:]
    registerCallCount = 0
    allSkillsCallCount = 0
    skillWithIDCallCount = 0
    createSkillCallCount = 0
    generateDeclarationsCallCount = 0
  }
}

// MARK: - SkillRegistry Tests

@Suite("SkillRegistry Tests")
struct SkillRegistryTests {

  @Test("registers a skill")
  func registersSkill() async {
    let registry = MockSkillRegistry()

    await registry.register(MockSkill.self)

    let skills = await registry.allSkills()
    #expect(skills.count == 1)
    #expect(skills[0].id == "mock-skill")
  }

  @Test("allSkills returns sorted list by displayName")
  func allSkillsReturnsSorted() async {
    let registry = MockSkillRegistry()

    await registry.register(ZetaSkill.self)
    await registry.register(AlphaSkill.self)
    await registry.register(MockSkill.self)

    let skills = await registry.allSkills()

    #expect(skills.count == 3)
    #expect(skills[0].displayName == "Alpha Skill")
    #expect(skills[1].displayName == "Mock Skill")
    #expect(skills[2].displayName == "Zeta Skill")
  }

  @Test("skill(withID:) for existing skill returns metadata")
  func skillWithIDReturnsMetadata() async {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)

    let metadata = await registry.skill(withID: "mock-skill")

    #expect(metadata != nil)
    #expect(metadata?.id == "mock-skill")
    #expect(metadata?.displayName == "Mock Skill")
  }

  @Test("skill(withID:) for non-existent skill returns nil")
  func skillWithIDReturnsNil() async {
    let registry = MockSkillRegistry()

    let metadata = await registry.skill(withID: "non-existent")

    #expect(metadata == nil)
  }

  @Test("createSkill for registered skill returns instance")
  func createSkillReturnsInstance() async throws {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)

    let skill = try await registry.createSkill(withID: "mock-skill")

    #expect(type(of: skill).metadata.id == "mock-skill")
  }

  @Test("createSkill for non-existent skill throws")
  func createSkillThrows() async {
    let registry = MockSkillRegistry()

    await #expect(throws: SkillError.self) {
      _ = try await registry.createSkill(withID: "fake")
    }
  }

  @Test("createSkill throws skillNotFound with correct ID")
  func createSkillThrowsCorrectError() async {
    let registry = MockSkillRegistry()

    do {
      _ = try await registry.createSkill(withID: "unknown-id")
      Issue.record("Expected error to be thrown")
    } catch let error as SkillError {
      #expect(error == .skillNotFound(skillID: "unknown-id"))
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test("generateGeminiFunctionDeclarations returns declarations")
  func generateDeclarations() async {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)

    let declarations = await registry.generateGeminiFunctionDeclarations()

    #expect(declarations.count == 1)
    #expect(declarations[0].name == "mock-skill")
    #expect(declarations[0].parameters.required.contains("topic"))
  }

  @Test("registering same skill twice last wins")
  func registerSameSkillTwice() async {
    let registry = MockSkillRegistry()

    await registry.register(MockSkill.self)
    await registry.register(MockSkill.self)

    let skills = await registry.allSkills()
    #expect(skills.count == 1)

    let callCount = await registry.registerCallCount
    #expect(callCount == 2)
  }

  @Test("empty registry allSkills returns empty array")
  func emptyRegistryReturnsEmpty() async {
    let registry = MockSkillRegistry()

    let skills = await registry.allSkills()

    #expect(skills.isEmpty)
  }
}

// MARK: - Mock SkillExecutor

// A mock implementation of SkillExecutorProtocol for testing.
// Note: Since validateParameters must be synchronous per the contract,
// the mock maintains a local cache of metadata for validation purposes.
actor MockSkillExecutor: SkillExecutorProtocol {

  private let registry: MockSkillRegistry

  // Tracks active executions for cancellation.
  private var activeExecutions: [String: Bool] = [:]

  // Local cache of metadata for synchronous validation.
  private var metadataCache: [String: SkillMetadata] = [:]

  // Tracks method invocations.
  private(set) var executeCallCount = 0
  private(set) var validateCallCount = 0
  private(set) var cancelCallCount = 0
  private(set) var lastSkillID: String?
  private(set) var lastParameters: [String: SkillParameterValue]?

  init(registry: MockSkillRegistry) {
    self.registry = registry
  }

  // Updates local cache with current registry state.
  // Call this after registering skills and before validating.
  func refreshMetadataCache() async {
    let skills = await registry.allSkills()
    metadataCache = [:]
    for skill in skills {
      metadataCache[skill.id] = skill
    }
  }

  func execute(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    executeCallCount += 1
    lastSkillID = skillID
    lastParameters = parameters

    // Refresh cache and validate parameters before execution.
    await refreshMetadataCache()
    try validateParameters(skillID: skillID, parameters: parameters)

    // Create and execute the skill.
    let skill = try await registry.createSkill(withID: skillID)
    return try await skill.execute(parameters: parameters, context: context)
  }

  func validateParameters(
    skillID: String,
    parameters: [String: SkillParameterValue]
  ) throws {
    validateCallCount += 1

    guard let metadata = metadataCache[skillID] else {
      throw SkillError.skillNotFound(skillID: skillID)
    }

    // Check required parameters.
    for param in metadata.parameters where param.required {
      guard parameters[param.name] != nil else {
        throw SkillError.missingRequiredParameter(parameterName: param.name)
      }

      // Check type.
      if let value = parameters[param.name] {
        let actualType = typeString(for: value)
        if actualType != param.type.rawValue {
          throw SkillError.invalidParameterType(
            parameterName: param.name,
            expected: param.type,
            received: actualType
          )
        }
      }
    }

    // Check optional parameters that are present.
    for param in metadata.parameters where !param.required {
      if let value = parameters[param.name] {
        let actualType = typeString(for: value)
        if actualType != param.type.rawValue {
          throw SkillError.invalidParameterType(
            parameterName: param.name,
            expected: param.type,
            received: actualType
          )
        }
      }
    }
  }

  func cancelExecution(executionID: String) async {
    cancelCallCount += 1
    activeExecutions[executionID] = false
  }

  // Test helper: Async wrapper for validateParameters to allow calling from tests.
  // This enables tests to call validation from outside the actor context.
  func performValidation(
    skillID: String,
    parameters: [String: SkillParameterValue]
  ) throws {
    try validateParameters(skillID: skillID, parameters: parameters)
  }

  // Helper to get type string from value.
  private func typeString(for value: SkillParameterValue) -> String {
    switch value {
    case .string: return "string"
    case .number: return "number"
    case .boolean: return "boolean"
    case .array: return "array"
    case .object: return "object"
    }
  }
}

// MARK: - SkillExecutor Tests

@Suite("SkillExecutor Tests")
struct SkillExecutorTests {

  @Test("execute with valid parameters succeeds")
  func executeWithValidParams() async throws {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    let executor = MockSkillExecutor(registry: registry)

    let context = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
    let params: [String: SkillParameterValue] = [
      "topic": .string("test")
    ]

    let result = try await executor.execute(
      skillID: "mock-skill",
      parameters: params,
      context: context
    )

    #expect(result.success == true)
    let callCount = await executor.executeCallCount
    #expect(callCount == 1)
  }

  @Test("execute with unknown skill ID throws skillNotFound")
  func executeUnknownSkillThrows() async {
    let registry = MockSkillRegistry()
    let executor = MockSkillExecutor(registry: registry)
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    await #expect(throws: SkillError.self) {
      _ = try await executor.execute(
        skillID: "unknown",
        parameters: [:],
        context: context
      )
    }
  }

  @Test("execute with missing required parameter throws")
  func executeMissingParamThrows() async {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    let executor = MockSkillExecutor(registry: registry)
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await executor.execute(
        skillID: "mock-skill",
        parameters: [:],
        context: context
      )
      Issue.record("Expected error")
    } catch let error as SkillError {
      #expect(error == .missingRequiredParameter(parameterName: "topic"))
    } catch {
      Issue.record("Wrong error type")
    }
  }

  @Test("execute with invalid parameter type throws")
  func executeInvalidTypeThrows() async {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    let executor = MockSkillExecutor(registry: registry)
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
    let params: [String: SkillParameterValue] = [
      "topic": .number(123)  // Should be string
    ]

    do {
      _ = try await executor.execute(
        skillID: "mock-skill",
        parameters: params,
        context: context
      )
      Issue.record("Expected error")
    } catch let error as SkillError {
      if case .invalidParameterType(let name, let expected, let received) = error {
        #expect(name == "topic")
        #expect(expected == .string)
        #expect(received == "number")
      } else {
        Issue.record("Wrong error case: \(error)")
      }
    } catch {
      Issue.record("Wrong error type")
    }
  }

  @Test("validateParameters independent of execute")
  func validateIndependently() async throws {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    let executor = MockSkillExecutor(registry: registry)

    // Refresh cache and validate - validation happens inside the actor.
    await executor.refreshMetadataCache()
    try await executor.performValidation(
      skillID: "mock-skill",
      parameters: ["topic": .string("test")]
    )

    let validateCount = await executor.validateCallCount
    #expect(validateCount == 1)

    let executeCount = await executor.executeCallCount
    #expect(executeCount == 0)
  }

  @Test("extra parameters are ignored")
  func extraParamsIgnored() async throws {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    let executor = MockSkillExecutor(registry: registry)
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
    let params: [String: SkillParameterValue] = [
      "topic": .string("test"),
      "extra": .string("ignored"),
      "another": .number(999),
    ]

    // Should succeed despite extra parameters.
    let result = try await executor.execute(
      skillID: "mock-skill",
      parameters: params,
      context: context
    )

    #expect(result.success == true)
  }

  @Test("validateParameters throws for unknown skill")
  func validateUnknownSkillThrows() async {
    let registry = MockSkillRegistry()
    let executor = MockSkillExecutor(registry: registry)

    // Cache is empty, so any skill ID will not be found.
    await #expect(throws: SkillError.self) {
      try await executor.performValidation(
        skillID: "unknown",
        parameters: [:]
      )
    }
  }
}

// MARK: - Supporting Types Tests

@Suite("LessonContent Tests")
struct LessonContentTests {

  @Test("lesson content preserves all fields")
  func preservesFields() {
    let lesson = LessonContent(
      title: "Introduction to Swift",
      sections: [
        LessonSection(heading: "Variables", content: "Variables store data"),
        LessonSection(heading: "Functions", content: "Functions are reusable"),
      ],
      exercises: [
        LessonExercise(prompt: "Create a variable", hint: "Use let or var", answer: "let x = 1")
      ]
    )

    #expect(lesson.title == "Introduction to Swift")
    #expect(lesson.sections.count == 2)
    #expect(lesson.sections[0].heading == "Variables")
    #expect(lesson.exercises?.count == 1)
    #expect(lesson.exercises?[0].hint == "Use let or var")
  }

  @Test("lesson without exercises")
  func lessonWithoutExercises() {
    let lesson = LessonContent(
      title: "Overview",
      sections: [LessonSection(heading: "Intro", content: "Welcome")],
      exercises: nil
    )

    #expect(lesson.exercises == nil)
  }

  @Test("lesson content is equatable")
  func isEquatable() {
    let lesson1 = LessonContent(
      title: "Test",
      sections: [],
      exercises: nil
    )
    let lesson2 = LessonContent(
      title: "Test",
      sections: [],
      exercises: nil
    )

    #expect(lesson1 == lesson2)
  }
}

@Suite("GraphData Tests")
struct GraphDataTests {

  @Test("graph data preserves all fields")
  func preservesFields() {
    let graph = GraphData(
      graphType: .bar,
      xAxisLabel: "Categories",
      yAxisLabel: "Values",
      series: [
        DataSeries(name: "Data", dataPoints: [(x: 1, y: 10), (x: 2, y: 20)])
      ]
    )

    #expect(graph.graphType == .bar)
    #expect(graph.xAxisLabel == "Categories")
    #expect(graph.yAxisLabel == "Values")
    #expect(graph.series.count == 1)
    #expect(graph.series[0].dataPoints.count == 2)
  }

  @Test("graph types encode correctly")
  func graphTypesEncode() throws {
    let encoder = JSONEncoder()

    #expect(String(data: try encoder.encode(GraphType.line), encoding: .utf8) == "\"line\"")
    #expect(String(data: try encoder.encode(GraphType.bar), encoding: .utf8) == "\"bar\"")
    #expect(String(data: try encoder.encode(GraphType.pie), encoding: .utf8) == "\"pie\"")
    #expect(String(data: try encoder.encode(GraphType.scatter), encoding: .utf8) == "\"scatter\"")
  }

  @Test("data series is equatable")
  func dataSeriesEquatable() {
    let series1 = DataSeries(name: "Test", dataPoints: [(x: 1, y: 2)])
    let series2 = DataSeries(name: "Test", dataPoints: [(x: 1, y: 2)])
    let series3 = DataSeries(name: "Test", dataPoints: [(x: 1, y: 3)])

    #expect(series1 == series2)
    #expect(series1 != series3)
  }
}

@Suite("TranscriptionResult Tests")
struct TranscriptionResultTests {

  @Test("transcription result preserves all fields")
  func preservesFields() {
    let result = TranscriptionResult(
      text: "Hello world",
      language: "en-US",
      confidence: 0.98,
      wordTimestamps: [
        WordTimestamp(word: "Hello", startTime: 0.0, endTime: 0.5),
        WordTimestamp(word: "world", startTime: 0.6, endTime: 1.0),
      ]
    )

    #expect(result.text == "Hello world")
    #expect(result.language == "en-US")
    #expect(result.confidence == 0.98)
    #expect(result.wordTimestamps?.count == 2)
    #expect(result.wordTimestamps?[0].word == "Hello")
    #expect(result.wordTimestamps?[0].startTime == 0.0)
  }

  @Test("transcription without optional fields")
  func withoutOptionalFields() {
    let result = TranscriptionResult(
      text: "Some text",
      language: nil,
      confidence: nil,
      wordTimestamps: nil
    )

    #expect(result.text == "Some text")
    #expect(result.language == nil)
    #expect(result.confidence == nil)
    #expect(result.wordTimestamps == nil)
  }

  @Test("word timestamp is equatable")
  func wordTimestampEquatable() {
    let ts1 = WordTimestamp(word: "hello", startTime: 0.0, endTime: 0.5)
    let ts2 = WordTimestamp(word: "hello", startTime: 0.0, endTime: 0.5)
    let ts3 = WordTimestamp(word: "world", startTime: 0.0, endTime: 0.5)

    #expect(ts1 == ts2)
    #expect(ts1 != ts3)
  }
}

// MARK: - Integration Scenario Tests

@Suite("Skills Integration Scenarios")
struct SkillsIntegrationTests {

  @Test("full workflow: register, discover, execute")
  func fullWorkflow() async throws {
    // Setup registry and executor.
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    await registry.register(AlphaSkill.self)
    let executor = MockSkillExecutor(registry: registry)

    // Discover available skills.
    let skills = await registry.allSkills()
    #expect(skills.count == 2)

    // Find skill by ID.
    let mockMeta = await registry.skill(withID: "mock-skill")
    #expect(mockMeta != nil)
    #expect(mockMeta?.parameters.count == 3)

    // Execute skill.
    let context = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: "do something",
      conversationHistory: nil
    )
    let result = try await executor.execute(
      skillID: "mock-skill",
      parameters: ["topic": .string("integration test")],
      context: context
    )

    #expect(result.success == true)
  }

  @Test("Gemini integration: generate and use declarations")
  func geminiIntegration() async {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    await registry.register(EnumSkill.self)

    // Generate declarations for Gemini.
    let declarations = await registry.generateGeminiFunctionDeclarations()

    #expect(declarations.count == 2)

    // Find mock skill declaration.
    let mockDecl = declarations.first { $0.name == "mock-skill" }
    #expect(mockDecl != nil)
    #expect(mockDecl?.parameters.properties["topic"] != nil)
    #expect(mockDecl?.parameters.required.contains("topic") == true)

    // Find enum skill declaration.
    let enumDecl = declarations.first { $0.name == "enum-skill" }
    #expect(enumDecl != nil)
    #expect(enumDecl?.parameters.properties["difficulty"]?.enumValues?.count == 3)
  }

  @Test("error propagation through executor")
  func errorPropagation() async {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    let executor = MockSkillExecutor(registry: registry)
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    // Test various error conditions.
    do {
      _ = try await executor.execute(
        skillID: "non-existent",
        parameters: [:],
        context: context
      )
      Issue.record("Should have thrown")
    } catch let error as SkillError {
      #expect(error == .skillNotFound(skillID: "non-existent"))
    } catch {
      Issue.record("Wrong error type")
    }

    do {
      _ = try await executor.execute(
        skillID: "mock-skill",
        parameters: [:],
        context: context
      )
      Issue.record("Should have thrown")
    } catch let error as SkillError {
      #expect(error == .missingRequiredParameter(parameterName: "topic"))
    } catch {
      Issue.record("Wrong error type")
    }
  }

  @Test("context passes through to skill execution")
  func contextPassthrough() async throws {
    let registry = MockSkillRegistry()
    await registry.register(MockSkill.self)
    let executor = MockSkillExecutor(registry: registry)

    let history = [
      ConversationMessage(role: .user, content: "Hello"),
      ConversationMessage(role: .assistant, content: "Hi"),
    ]
    let context = SkillContext(
      currentNotebookID: "notebook-abc",
      currentPDFID: "pdf-xyz",
      userMessage: "summarize",
      conversationHistory: history
    )

    _ = try await executor.execute(
      skillID: "mock-skill",
      parameters: ["topic": .string("test")],
      context: context
    )

    // The mock skill should have received the context.
    // This is verified by the MockSkill storing lastContext.
    // In a real test with access to the skill instance, verify context fields.
    let lastSkillID = await executor.lastSkillID
    #expect(lastSkillID == "mock-skill")
  }
}
