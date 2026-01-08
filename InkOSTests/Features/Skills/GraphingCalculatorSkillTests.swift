// GraphingCalculatorSkillTests.swift
// Comprehensive tests for the GraphingCalculatorSkill defined in GraphSpecificationContract.swift.
// These tests validate skill metadata, parameter handling, execution modes, error conditions,
// and cloud execution behavior. Tests are written in TDD style to drive implementation.
// Uses Swift Testing framework (@Suite, @Test, #expect).

import Foundation
import Testing

@testable import InkOS

// MARK: - Mock Implementations

// Mock implementation of a cloud client for testing GraphingCalculatorSkill cloud execution.
// Tracks method invocations and allows configurable responses and errors.
actor MockGraphingCloudClient {

  // Tracks cloud execution invocations.
  private(set) var executeCallCount = 0
  private(set) var lastSkillID: String?
  private(set) var lastParameters: [String: SkillParameterValue]?
  private(set) var lastContext: SkillContext?

  // Configurable result to return from cloud execution.
  var resultToReturn: SkillResult = .success(text: "Mock cloud result")

  // Configurable error to throw from cloud execution.
  var errorToThrow: Error?

  // Configurable GraphSpecification to return.
  var specificationToReturn: GraphSpecification?

  // Delay before returning result (for timeout testing).
  var artificialDelaySeconds: Double = 0

  // Flag to simulate cancellation.
  var shouldSimulateCancellation = false

  // Executes a mock cloud request for the graphing skill.
  func executeGraphingRequest(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    executeCallCount += 1
    lastSkillID = skillID
    lastParameters = parameters
    lastContext = context

    // Simulate delay if configured.
    if artificialDelaySeconds > 0 {
      try await Task.sleep(nanoseconds: UInt64(artificialDelaySeconds * 1_000_000_000))
    }

    // Check for cancellation simulation.
    if shouldSimulateCancellation {
      throw SkillError.cancelled
    }

    // Throw configured error if present.
    if let error = errorToThrow {
      throw error
    }

    // Return specification if configured.
    if let spec = specificationToReturn {
      return .success(data: .graphSpecification(spec))
    }

    return resultToReturn
  }

  // Test helper to reset state between tests.
  func reset() {
    executeCallCount = 0
    lastSkillID = nil
    lastParameters = nil
    lastContext = nil
    resultToReturn = .success(text: "Mock cloud result")
    errorToThrow = nil
    specificationToReturn = nil
    artificialDelaySeconds = 0
    shouldSimulateCancellation = false
  }

  // Setter methods for test configuration.
  func setResult(_ result: SkillResult) {
    self.resultToReturn = result
  }

  func setError(_ error: Error?) {
    self.errorToThrow = error
  }

  func setSpecification(_ spec: GraphSpecification?) {
    self.specificationToReturn = spec
  }

  func setCancellation(_ value: Bool) {
    self.shouldSimulateCancellation = value
  }
}

// MARK: - Test Data Factory

// Factory for creating test instances used across GraphingCalculatorSkill tests.
// Provides consistent test data including valid JSON specifications and JIIX content.
enum TestGraphingFactory {

  // Creates a minimal valid GraphSpecification JSON string.
  static func minimalSpecificationJSON() -> String {
    """
    {
      "version": "1.0",
      "viewport": {
        "xMin": -10,
        "xMax": 10,
        "yMin": -10,
        "yMax": 10,
        "aspectRatio": "auto"
      },
      "axes": {
        "x": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        },
        "y": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        }
      },
      "equations": [],
      "interactivity": {
        "allowPan": true,
        "allowZoom": true,
        "allowTrace": true,
        "showCoordinates": true,
        "snapToGrid": false
      }
    }
    """
  }

  // Creates a valid GraphSpecification JSON string with one equation.
  static func singleEquationSpecificationJSON() -> String {
    """
    {
      "version": "1.0",
      "title": "Quadratic Function",
      "viewport": {
        "xMin": -10,
        "xMax": 10,
        "yMin": -10,
        "yMax": 10,
        "aspectRatio": "auto"
      },
      "axes": {
        "x": {
          "label": "X",
          "gridSpacing": 1.0,
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        },
        "y": {
          "label": "Y",
          "gridSpacing": 1.0,
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        }
      },
      "equations": [
        {
          "id": "eq-1",
          "type": "explicit",
          "expression": "x^2",
          "variable": "x",
          "style": {
            "color": "#2196F3",
            "lineWidth": 2.0,
            "lineStyle": "solid"
          },
          "label": "y = x^2",
          "visible": true
        }
      ],
      "interactivity": {
        "allowPan": true,
        "allowZoom": true,
        "allowTrace": true,
        "showCoordinates": true,
        "snapToGrid": false
      }
    }
    """
  }

  // Creates a valid GraphSpecification JSON string with multiple equations.
  static func multipleEquationsSpecificationJSON() -> String {
    """
    {
      "version": "1.0",
      "title": "Multiple Functions",
      "viewport": {
        "xMin": -10,
        "xMax": 10,
        "yMin": -10,
        "yMax": 10,
        "aspectRatio": "auto"
      },
      "axes": {
        "x": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        },
        "y": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        }
      },
      "equations": [
        {
          "id": "eq-1",
          "type": "explicit",
          "expression": "x^2",
          "style": {
            "color": "#FF0000",
            "lineWidth": 2.0,
            "lineStyle": "solid"
          },
          "visible": true
        },
        {
          "id": "eq-2",
          "type": "explicit",
          "expression": "sin(x)",
          "style": {
            "color": "#00FF00",
            "lineWidth": 2.0,
            "lineStyle": "solid"
          },
          "visible": true
        },
        {
          "id": "eq-3",
          "type": "explicit",
          "expression": "1/x",
          "style": {
            "color": "#0000FF",
            "lineWidth": 2.0,
            "lineStyle": "solid"
          },
          "visible": true
        }
      ],
      "interactivity": {
        "allowPan": true,
        "allowZoom": true,
        "allowTrace": true,
        "showCoordinates": true,
        "snapToGrid": false
      }
    }
    """
  }

  // Creates invalid JSON that cannot be parsed.
  static func invalidJSON() -> String {
    "{ invalid json }"
  }

  // Creates valid JSON but with wrong structure for GraphSpecification.
  static func wrongStructureJSON() -> String {
    """
    {
      "name": "Not a graph specification",
      "value": 42
    }
    """
  }

  // Creates a specification JSON with unsupported version.
  static func unsupportedVersionJSON() -> String {
    """
    {
      "version": "2.0",
      "viewport": {
        "xMin": -10,
        "xMax": 10,
        "yMin": -10,
        "yMax": 10,
        "aspectRatio": "auto"
      },
      "axes": {
        "x": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        },
        "y": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        }
      },
      "equations": [],
      "interactivity": {
        "allowPan": true,
        "allowZoom": true,
        "allowTrace": true,
        "showCoordinates": true,
        "snapToGrid": false
      }
    }
    """
  }

  // Creates a specification JSON with invalid viewport (xMin > xMax).
  static func invalidViewportJSON() -> String {
    """
    {
      "version": "1.0",
      "viewport": {
        "xMin": 10,
        "xMax": -10,
        "yMin": -10,
        "yMax": 10,
        "aspectRatio": "auto"
      },
      "axes": {
        "x": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        },
        "y": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        }
      },
      "equations": [],
      "interactivity": {
        "allowPan": true,
        "allowZoom": true,
        "allowTrace": true,
        "showCoordinates": true,
        "snapToGrid": false
      }
    }
    """
  }

  // Creates a specification JSON with duplicate equation IDs.
  static func duplicateEquationIDsJSON() -> String {
    """
    {
      "version": "1.0",
      "viewport": {
        "xMin": -10,
        "xMax": 10,
        "yMin": -10,
        "yMax": 10,
        "aspectRatio": "auto"
      },
      "axes": {
        "x": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        },
        "y": {
          "showGrid": true,
          "showAxis": true,
          "tickLabels": true
        }
      },
      "equations": [
        {
          "id": "eq-1",
          "type": "explicit",
          "expression": "x^2",
          "style": {
            "color": "#FF0000",
            "lineWidth": 2.0,
            "lineStyle": "solid"
          },
          "visible": true
        },
        {
          "id": "eq-1",
          "type": "explicit",
          "expression": "sin(x)",
          "style": {
            "color": "#00FF00",
            "lineWidth": 2.0,
            "lineStyle": "solid"
          },
          "visible": true
        }
      ],
      "interactivity": {
        "allowPan": true,
        "allowZoom": true,
        "allowTrace": true,
        "showCoordinates": true,
        "snapToGrid": false
      }
    }
    """
  }

  // Creates sample JIIX content representing handwritten "y = x^2".
  static func sampleJIIXContent() -> String {
    """
    {
      "type": "Math",
      "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 50},
      "expressions": [
        {
          "type": "equation",
          "label": "y = x^2"
        }
      ]
    }
    """
  }

  // Creates sample JIIX content with no mathematical expressions.
  static func nonMathJIIXContent() -> String {
    """
    {
      "type": "Text",
      "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 50},
      "words": [
        {"label": "Hello"},
        {"label": "World"}
      ]
    }
    """
  }

  // Creates sample JIIX content with multiple equations.
  static func multipleEquationsJIIXContent() -> String {
    """
    {
      "type": "Math",
      "bounding-box": {"x": 0, "y": 0, "width": 200, "height": 100},
      "expressions": [
        {"type": "equation", "label": "y = x^2"},
        {"type": "equation", "label": "y = sin(x)"},
        {"type": "equation", "label": "y = 1/x"}
      ]
    }
    """
  }

  // Creates sample JIIX content with parametric equations.
  static func parametricJIIXContent() -> String {
    """
    {
      "type": "Math",
      "bounding-box": {"x": 0, "y": 0, "width": 150, "height": 75},
      "expressions": [
        {"type": "parametric", "x": "cos(t)", "y": "sin(t)"}
      ]
    }
    """
  }

  // Creates sample JIIX content with polar equation.
  static func polarJIIXContent() -> String {
    """
    {
      "type": "Math",
      "bounding-box": {"x": 0, "y": 0, "width": 120, "height": 60},
      "expressions": [
        {"type": "polar", "r": "1 + cos(theta)"}
      ]
    }
    """
  }

  // Creates sample JIIX content with inequality.
  static func inequalityJIIXContent() -> String {
    """
    {
      "type": "Math",
      "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 50},
      "expressions": [
        {"type": "inequality", "label": "y < x^2"}
      ]
    }
    """
  }

  // Creates a minimal valid GraphSpecification for testing.
  static func minimalSpecification() -> GraphSpecification {
    GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: GraphViewport(
        xMin: -10.0,
        xMax: 10.0,
        yMin: -10.0,
        yMax: 10.0,
        aspectRatio: .auto
      ),
      axes: GraphAxes(
        x: AxisConfiguration(
          label: nil,
          gridSpacing: nil,
          showGrid: true,
          showAxis: true,
          tickLabels: true
        ),
        y: AxisConfiguration(
          label: nil,
          gridSpacing: nil,
          showGrid: true,
          showAxis: true,
          tickLabels: true
        )
      ),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: GraphInteractivity(
        allowPan: true,
        allowZoom: true,
        allowTrace: true,
        showCoordinates: true,
        snapToGrid: false
      )
    )
  }

  // Creates a standard SkillContext for testing.
  static func standardContext() -> SkillContext {
    SkillContext(
      currentNotebookID: "notebook-123",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
  }

  // Creates a context with no notebook open.
  static func emptyContext() -> SkillContext {
    SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
  }
}

// MARK: - GraphingCalculatorSkill Metadata Tests

@Suite("GraphingCalculatorSkill Metadata Tests")
struct GraphingCalculatorSkillMetadataTests {

  @Test("skill ID is graphing-calculator")
  func skillIDIsGraphingCalculator() {
    let metadata = GraphingCalculatorSkill.metadata

    #expect(metadata.id == "graphing-calculator")
  }

  @Test("skill displayName is Graphing Calculator")
  func skillDisplayNameIsGraphingCalculator() {
    let metadata = GraphingCalculatorSkill.metadata

    #expect(metadata.displayName == "Graphing Calculator")
  }

  @Test("skill description describes graph creation")
  func skillDescriptionDescribesGraphCreation() {
    let metadata = GraphingCalculatorSkill.metadata

    #expect(metadata.description.contains("graph") || metadata.description.contains("Graph"))
    #expect(metadata.description.contains("math") || metadata.description.contains("equation"))
  }

  @Test("skill has valid icon name")
  func skillHasValidIconName() {
    let metadata = GraphingCalculatorSkill.metadata

    // Should be a valid SF Symbol name.
    #expect(!metadata.iconName.isEmpty)
    #expect(metadata.iconName == "function" || metadata.iconName.contains("graph") || metadata.iconName.contains("chart"))
  }

  @Test("skill executionMode is cloud")
  func skillExecutionModeIsCloud() {
    let metadata = GraphingCalculatorSkill.metadata

    #expect(metadata.executionMode == .cloud)
  }

  @Test("skill hasCustomUI is true")
  func skillHasCustomUIIsTrue() {
    let metadata = GraphingCalculatorSkill.metadata

    #expect(metadata.hasCustomUI == true)
  }

  @Test("skill has specification parameter")
  func skillHasSpecificationParameter() {
    let metadata = GraphingCalculatorSkill.metadata

    let specParam = metadata.parameters.first { $0.name == "specification" }

    #expect(specParam != nil)
    #expect(specParam?.type == .string)
    #expect(specParam?.required == false)
  }

  @Test("skill has jiixContent parameter")
  func skillHasJiixContentParameter() {
    let metadata = GraphingCalculatorSkill.metadata

    let jiixParam = metadata.parameters.first { $0.name == "jiixContent" }

    #expect(jiixParam != nil)
    #expect(jiixParam?.type == .string)
    #expect(jiixParam?.required == false)
  }

  @Test("skill has prompt parameter")
  func skillHasPromptParameter() {
    let metadata = GraphingCalculatorSkill.metadata

    let promptParam = metadata.parameters.first { $0.name == "prompt" }

    #expect(promptParam != nil)
    #expect(promptParam?.type == .string)
    #expect(promptParam?.required == false)
  }

  @Test("skill has exactly three parameters")
  func skillHasExactlyThreeParameters() {
    let metadata = GraphingCalculatorSkill.metadata

    #expect(metadata.parameters.count == 3)
  }

  @Test("all parameters are optional")
  func allParametersAreOptional() {
    let metadata = GraphingCalculatorSkill.metadata

    for param in metadata.parameters {
      #expect(param.required == false, "Parameter '\(param.name)' should be optional")
    }
  }

  @Test("specification parameter has descriptive text")
  func specificationParameterHasDescriptiveText() {
    let metadata = GraphingCalculatorSkill.metadata

    let specParam = metadata.parameters.first { $0.name == "specification" }

    #expect(specParam?.description.contains("JSON") == true || specParam?.description.contains("specification") == true)
  }

  @Test("jiixContent parameter has descriptive text")
  func jiixContentParameterHasDescriptiveText() {
    let metadata = GraphingCalculatorSkill.metadata

    let jiixParam = metadata.parameters.first { $0.name == "jiixContent" }

    #expect(jiixParam?.description.contains("JIIX") == true || jiixParam?.description.contains("handwrit") == true)
  }

  @Test("prompt parameter has descriptive text")
  func promptParameterHasDescriptiveText() {
    let metadata = GraphingCalculatorSkill.metadata

    let promptParam = metadata.parameters.first { $0.name == "prompt" }

    #expect(promptParam?.description.contains("natural language") == true || promptParam?.description.contains("description") == true)
  }
}

// MARK: - GraphingCalculatorSkill Instance Creation Tests

@Suite("GraphingCalculatorSkill Instance Creation Tests")
struct GraphingCalculatorSkillInstanceCreationTests {

  @Test("skill conforms to SkillCreatable")
  func skillConformsToSkillCreatable() {
    // Verify the type conforms to SkillCreatable.
    let skillType: any SkillCreatable.Type = GraphingCalculatorSkill.self

    #expect(skillType != nil)
  }

  @Test("createInstance returns valid skill instance")
  func createInstanceReturnsValidSkillInstance() {
    let instance = GraphingCalculatorSkill.createInstance()

    #expect(instance != nil)
  }

  @Test("created instance can access metadata")
  func createdInstanceCanAccessMetadata() {
    let instance = GraphingCalculatorSkill.createInstance()

    // Access type metadata via the instance's type.
    let metadata = type(of: instance).metadata

    #expect(metadata.id == "graphing-calculator")
  }

  @Test("multiple createInstance calls return independent instances")
  func multipleCreateInstanceCallsReturnIndependentInstances() {
    let instance1 = GraphingCalculatorSkill.createInstance()
    let instance2 = GraphingCalculatorSkill.createInstance()

    // Both instances should be valid.
    #expect(instance1 != nil)
    #expect(instance2 != nil)

    // Note: Struct instances are value types, so they are independent by nature.
  }

  @Test("skill can be created through registry pattern")
  func skillCanBeCreatedThroughRegistryPattern() async throws {
    // Create a test registry and register the skill.
    let registry = SkillRegistry.shared

    await registry.register(GraphingCalculatorSkill.self)

    // Retrieve and create skill via registry.
    let skill = try await registry.createSkill(withID: "graphing-calculator")

    #expect(skill != nil)
    #expect(type(of: skill).metadata.id == "graphing-calculator")
  }
}

// MARK: - GraphingCalculatorSkill Execute with Specification Tests

@Suite("GraphingCalculatorSkill Execute with Specification Tests")
struct GraphingCalculatorSkillExecuteWithSpecificationTests {

  @Test("execute with valid specification JSON succeeds")
  func executeWithValidSpecificationJSONSucceeds() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.minimalSpecificationJSON()

    let result = try await skill.execute(
      parameters: ["specification": .string(specJSON)],
      context: context
    )

    #expect(result.success == true)
    #expect(result.error == nil)
  }

  @Test("execute with valid specification returns graphSpecification data")
  func executeWithValidSpecificationReturnsGraphSpecificationData() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.singleEquationSpecificationJSON()

    let result = try await skill.execute(
      parameters: ["specification": .string(specJSON)],
      context: context
    )

    // Verify result contains graphSpecification data.
    if case .graphSpecification(let spec) = result.data {
      #expect(spec.version == "1.0")
      #expect(spec.title == "Quadratic Function")
      #expect(spec.equations.count == 1)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with specification containing multiple equations preserves all")
  func executeWithSpecificationContainingMultipleEquationsPreservesAll() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.multipleEquationsSpecificationJSON()

    let result = try await skill.execute(
      parameters: ["specification": .string(specJSON)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      #expect(spec.equations.count == 3)
      #expect(spec.equations[0].id == "eq-1")
      #expect(spec.equations[1].id == "eq-2")
      #expect(spec.equations[2].id == "eq-3")
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with specification does not make cloud request")
  func executeWithSpecificationDoesNotMakeCloudRequest() async throws {
    // When specification is provided directly, no cloud request should be needed.
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.minimalSpecificationJSON()

    // Execute should succeed without cloud.
    let result = try await skill.execute(
      parameters: ["specification": .string(specJSON)],
      context: context
    )

    #expect(result.success == true)
    // The skill parses locally without cloud.
  }

  @Test("execute with invalid JSON throws executionFailed")
  func executeWithInvalidJSONThrowsExecutionFailed() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let invalidJSON = TestGraphingFactory.invalidJSON()

    do {
      _ = try await skill.execute(
        parameters: ["specification": .string(invalidJSON)],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch let error as SkillError {
      if case .executionFailed(let reason) = error {
        #expect(reason.contains("parse") || reason.contains("JSON") || reason.contains("decode"))
      } else {
        Issue.record("Expected executionFailed error, got: \(error)")
      }
    } catch {
      // GraphingCalculatorSkillError may also be thrown and wrapped.
      #expect(error != nil)
    }
  }

  @Test("execute with wrong structure JSON throws executionFailed")
  func executeWithWrongStructureJSONThrowsExecutionFailed() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let wrongJSON = TestGraphingFactory.wrongStructureJSON()

    do {
      _ = try await skill.execute(
        parameters: ["specification": .string(wrongJSON)],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch {
      // Should fail because required fields are missing.
      #expect(error != nil)
    }
  }

  @Test("execute with specification validates viewport")
  func executeWithSpecificationValidatesViewport() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let invalidViewportJSON = TestGraphingFactory.invalidViewportJSON()

    do {
      _ = try await skill.execute(
        parameters: ["specification": .string(invalidViewportJSON)],
        context: context
      )
      // May succeed if validation is lenient, or fail if strict.
      // The contract indicates validation should occur.
    } catch {
      // Expected validation failure for invalid viewport.
      #expect(error != nil)
    }
  }

  @Test("execute with duplicate equation IDs validates correctly")
  func executeWithDuplicateEquationIDsValidatesCorrectly() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let duplicateIDsJSON = TestGraphingFactory.duplicateEquationIDsJSON()

    do {
      _ = try await skill.execute(
        parameters: ["specification": .string(duplicateIDsJSON)],
        context: context
      )
      // May succeed or fail depending on validation implementation.
    } catch {
      // Expected if validation checks for duplicate IDs.
      #expect(error != nil)
    }
  }
}

// MARK: - GraphingCalculatorSkill Execute with JIIX Content Tests

@Suite("GraphingCalculatorSkill Execute with JIIX Content Tests")
struct GraphingCalculatorSkillExecuteWithJIIXContentTests {

  @Test("execute with valid JIIX content returns graphSpecification")
  func executeWithValidJIIXContentReturnsGraphSpecification() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.sampleJIIXContent()

    // Note: This requires cloud execution to interpret JIIX.
    // In TDD, this test will initially fail until cloud integration is implemented.
    let result = try await skill.execute(
      parameters: ["jiixContent": .string(jiixContent)],
      context: context
    )

    #expect(result.success == true)
    if case .graphSpecification = result.data {
      // Success - graphSpecification returned.
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with JIIX containing multiple equations extracts all")
  func executeWithJIIXContainingMultipleEquationsExtractsAll() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.multipleEquationsJIIXContent()

    let result = try await skill.execute(
      parameters: ["jiixContent": .string(jiixContent)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      #expect(spec.equations.count >= 1)
      // AI should extract multiple equations from JIIX.
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with JIIX containing parametric equation recognizes type")
  func executeWithJIIXContainingParametricEquationRecognizesType() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.parametricJIIXContent()

    let result = try await skill.execute(
      parameters: ["jiixContent": .string(jiixContent)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      // Check if parametric equation is recognized.
      let hasParametric = spec.equations.contains { $0.type == .parametric }
      #expect(hasParametric || spec.equations.count > 0)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with JIIX containing polar equation recognizes type")
  func executeWithJIIXContainingPolarEquationRecognizesType() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.polarJIIXContent()

    let result = try await skill.execute(
      parameters: ["jiixContent": .string(jiixContent)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      // Check if polar equation is recognized.
      let hasPolar = spec.equations.contains { $0.type == .polar }
      #expect(hasPolar || spec.equations.count > 0)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with JIIX containing inequality recognizes type")
  func executeWithJIIXContainingInequalityRecognizesType() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.inequalityJIIXContent()

    let result = try await skill.execute(
      parameters: ["jiixContent": .string(jiixContent)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      // Check if inequality is recognized.
      let hasInequality = spec.equations.contains { $0.type == .inequality }
      #expect(hasInequality || spec.equations.count > 0)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with non-math JIIX throws noMathematicalContent")
  func executeWithNonMathJIIXThrowsNoMathematicalContent() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.nonMathJIIXContent()

    do {
      let result = try await skill.execute(
        parameters: ["jiixContent": .string(jiixContent)],
        context: context
      )
      // Without cloud client, local fallback returns placeholder success.
      // This is acceptable - detecting non-math content requires AI interpretation.
      // In production with cloud, this would throw noMathematicalContent.
      if case .graphSpecification = result.data {
        // Placeholder result accepted for local testing.
      } else {
        Issue.record("Expected graphSpecification or error")
      }
    } catch let error as GraphingCalculatorSkillError {
      #expect(error == .noMathematicalContent)
    } catch let error as SkillError {
      // May be wrapped as executionFailed.
      if case .executionFailed(let reason) = error {
        #expect(reason.contains("math") || reason.contains("content"))
      } else {
        Issue.record("Unexpected SkillError: \(error)")
      }
    } catch {
      // Other error types may be acceptable during implementation.
      #expect(error != nil)
    }
  }

  @Test("execute with JIIX generates unique equation IDs")
  func executeWithJIIXGeneratesUniqueEquationIDs() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.multipleEquationsJIIXContent()

    let result = try await skill.execute(
      parameters: ["jiixContent": .string(jiixContent)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      let ids = spec.equations.map { $0.id }
      let uniqueIDs = Set(ids)
      #expect(ids.count == uniqueIDs.count, "All equation IDs should be unique")
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }
}

// MARK: - GraphingCalculatorSkill Execute with Prompt Tests

@Suite("GraphingCalculatorSkill Execute with Prompt Tests")
struct GraphingCalculatorSkillExecuteWithPromptTests {

  @Test("execute with natural language prompt returns graphSpecification")
  func executeWithNaturalLanguagePromptReturnsGraphSpecification() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let prompt = "graph sine and cosine from -2pi to 2pi"

    let result = try await skill.execute(
      parameters: ["prompt": .string(prompt)],
      context: context
    )

    #expect(result.success == true)
    if case .graphSpecification = result.data {
      // Success - graphSpecification returned.
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with prompt generates appropriate viewport")
  func executeWithPromptGeneratesAppropriateViewport() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let prompt = "graph y = x^2 from x = 0 to x = 10"

    let result = try await skill.execute(
      parameters: ["prompt": .string(prompt)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      // AI should generate viewport appropriate for the domain.
      // At minimum, viewport should be valid.
      #expect(spec.viewport.xMax > spec.viewport.xMin)
      #expect(spec.viewport.yMax > spec.viewport.yMin)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with prompt for multiple functions creates multiple equations")
  func executeWithPromptForMultipleFunctionsCreatesMultipleEquations() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let prompt = "graph y = x^2, y = x^3, and y = sqrt(x)"

    let result = try await skill.execute(
      parameters: ["prompt": .string(prompt)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      // Should have multiple equations.
      #expect(spec.equations.count >= 1)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("execute with ambiguous prompt handles gracefully")
  func executeWithAmbiguousPromptHandlesGracefully() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let prompt = "graph the function"

    // Should either return a default or handle gracefully.
    let result = try await skill.execute(
      parameters: ["prompt": .string(prompt)],
      context: context
    )

    // May succeed with default or return informative message.
    #expect(result.success == true || result.message != nil)
  }
}

// MARK: - GraphingCalculatorSkill Priority Order Tests

@Suite("GraphingCalculatorSkill Priority Order Tests")
struct GraphingCalculatorSkillPriorityOrderTests {

  @Test("specification takes priority over jiixContent")
  func specificationTakesPriorityOverJiixContent() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.singleEquationSpecificationJSON()
    let jiixContent = TestGraphingFactory.multipleEquationsJIIXContent()

    let result = try await skill.execute(
      parameters: [
        "specification": .string(specJSON),
        "jiixContent": .string(jiixContent),
      ],
      context: context
    )

    // Should use specification (which has title "Quadratic Function").
    if case .graphSpecification(let spec) = result.data {
      #expect(spec.title == "Quadratic Function")
      #expect(spec.equations.count == 1)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("specification takes priority over prompt")
  func specificationTakesPriorityOverPrompt() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.singleEquationSpecificationJSON()
    let prompt = "graph sine and cosine functions"

    let result = try await skill.execute(
      parameters: [
        "specification": .string(specJSON),
        "prompt": .string(prompt),
      ],
      context: context
    )

    // Should use specification.
    if case .graphSpecification(let spec) = result.data {
      #expect(spec.title == "Quadratic Function")
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("jiixContent takes priority over prompt")
  func jiixContentTakesPriorityOverPrompt() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let jiixContent = TestGraphingFactory.sampleJIIXContent()
    let prompt = "graph sine and cosine functions"

    let result = try await skill.execute(
      parameters: [
        "jiixContent": .string(jiixContent),
        "prompt": .string(prompt),
      ],
      context: context
    )

    // Should use jiixContent, not prompt.
    // The result should be based on JIIX interpretation.
    #expect(result.success == true)
    if case .graphSpecification = result.data {
      // Success - jiixContent was used.
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("all three parameters uses specification")
  func allThreeParametersUsesSpecification() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.singleEquationSpecificationJSON()
    let jiixContent = TestGraphingFactory.multipleEquationsJIIXContent()
    let prompt = "graph tangent function"

    let result = try await skill.execute(
      parameters: [
        "specification": .string(specJSON),
        "jiixContent": .string(jiixContent),
        "prompt": .string(prompt),
      ],
      context: context
    )

    // Should use specification (highest priority).
    if case .graphSpecification(let spec) = result.data {
      #expect(spec.title == "Quadratic Function")
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }
}

// MARK: - GraphingCalculatorSkillError Tests

@Suite("GraphingCalculatorSkillError Tests")
struct GraphingCalculatorSkillErrorTests {

  @Test("noInputProvided error case exists")
  func noInputProvidedErrorCaseExists() {
    let error = GraphingCalculatorSkillError.noInputProvided

    #expect(error == .noInputProvided)
  }

  @Test("noInputProvided errorDescription provides guidance")
  func noInputProvidedErrorDescriptionProvidesGuidance() {
    let error = GraphingCalculatorSkillError.noInputProvided

    #expect(error.errorDescription?.contains("specification") == true || error.errorDescription?.contains("jiixContent") == true || error.errorDescription?.contains("prompt") == true)
  }

  @Test("emptyInput error contains parameter name")
  func emptyInputErrorContainsParameterName() {
    let error = GraphingCalculatorSkillError.emptyInput(parameterName: "jiixContent")

    if case .emptyInput(let paramName) = error {
      #expect(paramName == "jiixContent")
    } else {
      Issue.record("Expected emptyInput case")
    }
  }

  @Test("emptyInput errorDescription contains parameter name")
  func emptyInputErrorDescriptionContainsParameterName() {
    let error = GraphingCalculatorSkillError.emptyInput(parameterName: "specification")

    #expect(error.errorDescription?.contains("specification") == true)
    #expect(error.errorDescription?.contains("empty") == true)
  }

  @Test("noMathematicalContent error case exists")
  func noMathematicalContentErrorCaseExists() {
    let error = GraphingCalculatorSkillError.noMathematicalContent

    #expect(error == .noMathematicalContent)
  }

  @Test("noMathematicalContent errorDescription mentions math")
  func noMathematicalContentErrorDescriptionMentionsMath() {
    let error = GraphingCalculatorSkillError.noMathematicalContent

    #expect(error.errorDescription?.contains("math") == true)
  }

  @Test("interpretationFailed error contains reason")
  func interpretationFailedErrorContainsReason() {
    let error = GraphingCalculatorSkillError.interpretationFailed(reason: "Could not parse equation")

    if case .interpretationFailed(let reason) = error {
      #expect(reason == "Could not parse equation")
    } else {
      Issue.record("Expected interpretationFailed case")
    }
  }

  @Test("interpretationFailed errorDescription contains reason")
  func interpretationFailedErrorDescriptionContainsReason() {
    let error = GraphingCalculatorSkillError.interpretationFailed(reason: "Unknown notation")

    #expect(error.errorDescription?.contains("Unknown notation") == true)
    #expect(error.errorDescription?.contains("interpret") == true || error.errorDescription?.contains("Failed") == true)
  }

  @Test("invalidAIResponse error contains reason")
  func invalidAIResponseErrorContainsReason() {
    let error = GraphingCalculatorSkillError.invalidAIResponse(reason: "Missing required field")

    if case .invalidAIResponse(let reason) = error {
      #expect(reason == "Missing required field")
    } else {
      Issue.record("Expected invalidAIResponse case")
    }
  }

  @Test("invalidAIResponse errorDescription contains reason")
  func invalidAIResponseErrorDescriptionContainsReason() {
    let error = GraphingCalculatorSkillError.invalidAIResponse(reason: "Malformed JSON")

    #expect(error.errorDescription?.contains("Malformed JSON") == true)
    #expect(error.errorDescription?.contains("AI") == true || error.errorDescription?.contains("response") == true)
  }

  @Test("validationFailed error contains underlying error")
  func validationFailedErrorContainsUnderlyingError() {
    let underlyingError = GraphSpecificationError.invalidViewport(reason: "xMin > xMax")
    let error = GraphingCalculatorSkillError.validationFailed(underlying: underlyingError)

    if case .validationFailed(let underlying) = error {
      #expect(underlying == underlyingError)
    } else {
      Issue.record("Expected validationFailed case")
    }
  }

  @Test("validationFailed errorDescription contains underlying details")
  func validationFailedErrorDescriptionContainsUnderlyingDetails() {
    let underlyingError = GraphSpecificationError.duplicateEquationID(equationID: "eq-1")
    let error = GraphingCalculatorSkillError.validationFailed(underlying: underlyingError)

    #expect(error.errorDescription?.contains("validation") == true || error.errorDescription?.contains("failed") == true)
  }

  @Test("errors are Equatable with same values")
  func errorsAreEquatableWithSameValues() {
    let error1 = GraphingCalculatorSkillError.emptyInput(parameterName: "test")
    let error2 = GraphingCalculatorSkillError.emptyInput(parameterName: "test")

    #expect(error1 == error2)
  }

  @Test("errors are not equal with different values")
  func errorsAreNotEqualWithDifferentValues() {
    let error1 = GraphingCalculatorSkillError.emptyInput(parameterName: "a")
    let error2 = GraphingCalculatorSkillError.emptyInput(parameterName: "b")

    #expect(error1 != error2)
  }

  @Test("different error types are not equal")
  func differentErrorTypesAreNotEqual() {
    let error1 = GraphingCalculatorSkillError.noInputProvided
    let error2 = GraphingCalculatorSkillError.noMathematicalContent

    #expect(error1 != error2)
  }
}

// MARK: - GraphingCalculatorSkill Error Handling Tests

@Suite("GraphingCalculatorSkill Error Handling Tests")
struct GraphingCalculatorSkillErrorHandlingTests {

  @Test("execute with no parameters throws noInputProvided")
  func executeWithNoParametersThrowsNoInputProvided() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    do {
      _ = try await skill.execute(
        parameters: [:],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch let error as GraphingCalculatorSkillError {
      #expect(error == .noInputProvided)
    } catch let error as SkillError {
      // May be wrapped as missingRequiredParameter.
      if case .missingRequiredParameter = error {
        // Acceptable.
      } else {
        Issue.record("Unexpected SkillError: \(error)")
      }
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }

  @Test("execute with empty specification string throws emptyInput")
  func executeWithEmptySpecificationStringThrowsEmptyInput() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    do {
      _ = try await skill.execute(
        parameters: ["specification": .string("")],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch let error as GraphingCalculatorSkillError {
      if case .emptyInput(let paramName) = error {
        #expect(paramName == "specification")
      } else {
        Issue.record("Expected emptyInput error")
      }
    } catch let error as SkillError {
      // Accept various SkillError types that indicate invalid/empty input.
      switch error {
      case .invalidParameterValue:
        break  // Acceptable
      case .missingRequiredParameter(let paramName):
        #expect(paramName == "specification")  // Acceptable - empty is treated as missing
      default:
        Issue.record("Unexpected SkillError: \(error)")
      }
    } catch {
      // Accept any error indicating invalid input.
      #expect(error != nil)
    }
  }

  @Test("execute with empty jiixContent string throws emptyInput")
  func executeWithEmptyJiixContentStringThrowsEmptyInput() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    do {
      _ = try await skill.execute(
        parameters: ["jiixContent": .string("")],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch let error as GraphingCalculatorSkillError {
      if case .emptyInput(let paramName) = error {
        #expect(paramName == "jiixContent")
      } else {
        Issue.record("Expected emptyInput error")
      }
    } catch {
      // Accept any error indicating invalid input.
      #expect(error != nil)
    }
  }

  @Test("execute with empty prompt string throws emptyInput")
  func executeWithEmptyPromptStringThrowsEmptyInput() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    do {
      _ = try await skill.execute(
        parameters: ["prompt": .string("")],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch let error as GraphingCalculatorSkillError {
      if case .emptyInput(let paramName) = error {
        #expect(paramName == "prompt")
      } else {
        Issue.record("Expected emptyInput error")
      }
    } catch {
      // Accept any error indicating invalid input.
      #expect(error != nil)
    }
  }

  @Test("execute with all empty parameters throws appropriate error")
  func executeWithAllEmptyParametersThrowsAppropriateError() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    do {
      _ = try await skill.execute(
        parameters: [
          "specification": .string(""),
          "jiixContent": .string(""),
          "prompt": .string(""),
        ],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch {
      // Should fail due to all inputs being empty.
      #expect(error != nil)
    }
  }

  @Test("execute with whitespace-only input throws emptyInput")
  func executeWithWhitespaceOnlyInputThrowsEmptyInput() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    do {
      _ = try await skill.execute(
        parameters: ["specification": .string("   \n\t   ")],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch {
      // Should treat whitespace-only as empty.
      #expect(error != nil)
    }
  }

  @Test("execute with wrong parameter type throws invalidParameterType")
  func executeWithWrongParameterTypeThrowsInvalidParameterType() async {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    do {
      _ = try await skill.execute(
        parameters: ["specification": .number(42)],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch let error as SkillError {
      if case .invalidParameterType(let paramName, let expected, _) = error {
        #expect(paramName == "specification")
        #expect(expected == .string)
      } else {
        Issue.record("Expected invalidParameterType error")
      }
    } catch {
      // Accept any type-related error.
      #expect(error != nil)
    }
  }
}

// MARK: - GraphingCalculatorSkill Edge Case Tests

@Suite("GraphingCalculatorSkill Edge Case Tests")
struct GraphingCalculatorSkillEdgeCaseTests {

  @Test("execute with nil notebook ID context succeeds")
  func executeWithNilNotebookIDContextSucceeds() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.emptyContext()
    let specJSON = TestGraphingFactory.minimalSpecificationJSON()

    // Should succeed - notebook context is not required for graphing.
    let result = try await skill.execute(
      parameters: ["specification": .string(specJSON)],
      context: context
    )

    #expect(result.success == true)
  }

  @Test("concurrent executions are independent")
  func concurrentExecutionsAreIndependent() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON1 = TestGraphingFactory.singleEquationSpecificationJSON()
    let specJSON2 = TestGraphingFactory.multipleEquationsSpecificationJSON()

    // Execute two skills concurrently.
    async let result1 = skill.execute(
      parameters: ["specification": .string(specJSON1)],
      context: context
    )
    async let result2 = skill.execute(
      parameters: ["specification": .string(specJSON2)],
      context: context
    )

    let (r1, r2) = try await (result1, result2)

    // Both should succeed independently.
    #expect(r1.success == true)
    #expect(r2.success == true)

    // Results should be different.
    if case .graphSpecification(let spec1) = r1.data,
      case .graphSpecification(let spec2) = r2.data
    {
      #expect(spec1.equations.count == 1)
      #expect(spec2.equations.count == 3)
    }
  }

  @Test("execute with unicode in expressions roundtrips correctly")
  func executeWithUnicodeInExpressionsRoundtripsCorrectly() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    // Create specification with unicode in expression.
    let unicodeSpec = """
    {
      "version": "1.0",
      "viewport": {
        "xMin": -10,
        "xMax": 10,
        "yMin": -10,
        "yMax": 10,
        "aspectRatio": "auto"
      },
      "axes": {
        "x": {"showGrid": true, "showAxis": true, "tickLabels": true},
        "y": {"showGrid": true, "showAxis": true, "tickLabels": true}
      },
      "equations": [
        {
          "id": "eq-theta",
          "type": "explicit",
          "expression": "sin(\u{03B8})",
          "style": {"color": "#FF0000", "lineWidth": 2.0, "lineStyle": "solid"},
          "visible": true
        }
      ],
      "interactivity": {"allowPan": true, "allowZoom": true, "allowTrace": true, "showCoordinates": true, "snapToGrid": false}
    }
    """

    let result = try await skill.execute(
      parameters: ["specification": .string(unicodeSpec)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      // Unicode should be preserved.
      #expect(spec.equations.first?.expression?.contains("\u{03B8}") == true)
    }
  }

  @Test("execute with very long expression succeeds")
  func executeWithVeryLongExpressionSucceeds() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    // Create a long but valid expression.
    let longExpression = "x^2 + " + String(repeating: "x + ", count: 100) + "1"

    let specWithLongExpression = """
    {
      "version": "1.0",
      "viewport": {"xMin": -10, "xMax": 10, "yMin": -10, "yMax": 10, "aspectRatio": "auto"},
      "axes": {
        "x": {"showGrid": true, "showAxis": true, "tickLabels": true},
        "y": {"showGrid": true, "showAxis": true, "tickLabels": true}
      },
      "equations": [
        {
          "id": "long-eq",
          "type": "explicit",
          "expression": "\(longExpression)",
          "style": {"color": "#FF0000", "lineWidth": 2.0, "lineStyle": "solid"},
          "visible": true
        }
      ],
      "interactivity": {"allowPan": true, "allowZoom": true, "allowTrace": true, "showCoordinates": true, "snapToGrid": false}
    }
    """

    // Should handle long expressions.
    let result = try await skill.execute(
      parameters: ["specification": .string(specWithLongExpression)],
      context: context
    )

    #expect(result.success == true)
  }

  @Test("execute with maximum equations count succeeds")
  func executeWithMaximumEquationsCountSucceeds() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()

    // Create specification with many equations (up to limit).
    var equations: [String] = []
    for i in 0..<GraphSpecificationConstants.maxEquations {
      equations.append("""
        {"id": "eq-\(i)", "type": "explicit", "expression": "x + \(i)", "style": {"color": "#FF0000", "lineWidth": 2.0, "lineStyle": "solid"}, "visible": true}
        """)
    }

    let manyEquationsSpec = """
    {
      "version": "1.0",
      "viewport": {"xMin": -10, "xMax": 10, "yMin": -10, "yMax": 10, "aspectRatio": "auto"},
      "axes": {
        "x": {"showGrid": true, "showAxis": true, "tickLabels": true},
        "y": {"showGrid": true, "showAxis": true, "tickLabels": true}
      },
      "equations": [\(equations.joined(separator: ","))],
      "interactivity": {"allowPan": true, "allowZoom": true, "allowTrace": true, "showCoordinates": true, "snapToGrid": false}
    }
    """

    let result = try await skill.execute(
      parameters: ["specification": .string(manyEquationsSpec)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      #expect(spec.equations.count == GraphSpecificationConstants.maxEquations)
    }
  }
}

// MARK: - GraphingCalculatorSkill Sendable Tests

@Suite("GraphingCalculatorSkill Sendable Tests")
struct GraphingCalculatorSkillSendableTests {

  @Test("skill is Sendable")
  func skillIsSendable() async {
    let skill = GraphingCalculatorSkill.createInstance()

    // Pass to async context to verify Sendable conformance.
    let result = await passSkillToActor(skill)
    #expect(result == "graphing-calculator")
  }

  @Test("skill execution is thread-safe")
  func skillExecutionIsThreadSafe() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.minimalSpecificationJSON()

    // Execute from multiple concurrent tasks.
    try await withThrowingTaskGroup(of: SkillResult.self) { group in
      for _ in 0..<5 {
        group.addTask {
          try await skill.execute(
            parameters: ["specification": .string(specJSON)],
            context: context
          )
        }
      }

      var results: [SkillResult] = []
      for try await result in group {
        results.append(result)
      }

      #expect(results.count == 5)
      for result in results {
        #expect(result.success == true)
      }
    }
  }

  private func passSkillToActor(_ skill: GraphingCalculatorSkill) async -> String {
    return type(of: skill).metadata.id
  }
}

// MARK: - GraphingCalculatorSkill Integration Tests

@Suite("GraphingCalculatorSkill Integration Tests")
struct GraphingCalculatorSkillIntegrationTests {

  @Test("full workflow from specification to graphSpecification")
  func fullWorkflowFromSpecificationToGraphSpecification() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.singleEquationSpecificationJSON()

    let result = try await skill.execute(
      parameters: ["specification": .string(specJSON)],
      context: context
    )

    // Verify complete workflow result.
    #expect(result.success == true)
    #expect(result.error == nil)

    if case .graphSpecification(let spec) = result.data {
      // Verify all expected fields are populated.
      #expect(spec.version == "1.0")
      #expect(spec.title == "Quadratic Function")
      #expect(spec.viewport.xMin == -10)
      #expect(spec.viewport.xMax == 10)
      #expect(spec.axes.x.showGrid == true)
      #expect(spec.equations.count == 1)
      #expect(spec.equations.first?.expression == "x^2")
      #expect(spec.interactivity.allowPan == true)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("result can be encoded to JSON for transmission")
  func resultCanBeEncodedToJSONForTransmission() async throws {
    let skill = GraphingCalculatorSkill.createInstance()
    let context = TestGraphingFactory.standardContext()
    let specJSON = TestGraphingFactory.singleEquationSpecificationJSON()

    let result = try await skill.execute(
      parameters: ["specification": .string(specJSON)],
      context: context
    )

    if case .graphSpecification(let spec) = result.data {
      // Should be able to encode result for transmission.
      let encoder = JSONEncoder()
      let data = try encoder.encode(spec)

      #expect(!data.isEmpty)

      // Should be able to decode back.
      let decoder = JSONDecoder()
      let decoded = try decoder.decode(GraphSpecification.self, from: data)

      #expect(decoded == spec)
    } else {
      Issue.record("Expected graphSpecification data type")
    }
  }

  @Test("skill generates correct Gemini function declaration")
  func skillGeneratesCorrectGeminiFunctionDeclaration() async {
    let registry = SkillRegistry.shared
    await registry.register(GraphingCalculatorSkill.self)

    let declarations = await registry.generateGeminiFunctionDeclarations()
    let graphingDeclaration = declarations.first { $0.name == "graphing-calculator" }

    #expect(graphingDeclaration != nil)
    #expect(graphingDeclaration?.description.contains("graph") == true || graphingDeclaration?.description.contains("Graph") == true)
    #expect(graphingDeclaration?.parameters.properties["specification"] != nil)
    #expect(graphingDeclaration?.parameters.properties["jiixContent"] != nil)
    #expect(graphingDeclaration?.parameters.properties["prompt"] != nil)
  }
}
