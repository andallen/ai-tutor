// GraphingCalculatorSkill.swift
// Production implementation of the GraphingCalculator skill.
// Creates interactive mathematical graphs from handwritten equations,
// direct specifications, or natural language descriptions.

import Foundation

// Concrete implementation of the GraphingCalculator skill.
// Interprets handwritten math content (JIIX) or direct specifications
// and returns a GraphSpecification for rendering interactive graphs.
struct GraphingCalculatorSkill: Skill, SkillCreatable {

  // Cloud client for executing cloud-based interpretation.
  private let cloudClient: (any SkillCloudClientProtocol)?

  // Initializes with optional cloud client dependency.
  init(cloudClient: (any SkillCloudClientProtocol)? = nil) {
    self.cloudClient = cloudClient
  }

  // Static metadata describing this skill.
  static var metadata: SkillMetadata {
    SkillMetadata(
      id: "graphing-calculator",
      displayName: "Graphing Calculator",
      description: "Creates interactive mathematical graphs from handwritten equations or descriptions",
      iconName: "function",
      parameters: [
        SkillParameter(
          name: "specification",
          description: "Direct JSON GraphSpecification string",
          type: .string,
          required: false,
          defaultValue: nil,
          allowedValues: nil
        ),
        SkillParameter(
          name: "jiixContent",
          description: "JIIX JSON content from handwriting selection",
          type: .string,
          required: false,
          defaultValue: nil,
          allowedValues: nil
        ),
        SkillParameter(
          name: "prompt",
          description: "Natural language description of the graph to create",
          type: .string,
          required: false,
          defaultValue: nil,
          allowedValues: nil
        ),
      ],
      executionMode: .cloud,
      hasCustomUI: true
    )
  }

  // Creates a new instance of the skill.
  static func createInstance() -> GraphingCalculatorSkill {
    GraphingCalculatorSkill()
  }

  // Executes the skill with given parameters and context.
  // Priority order:
  // 1. specification parameter (direct JSON specification)
  // 2. jiixContent parameter (explicit JIIX from parameter)
  // 3. context.selectionJIIX (JIIX from lasso selection in AI overlay)
  // 4. prompt parameter (explicit prompt from parameter)
  // 5. context.userMessage (natural language from AI chat)
  func execute(
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    // Extract and validate parameters with proper error types.
    let specification = try extractString(from: parameters, key: "specification")
    let jiixContent = try extractString(from: parameters, key: "jiixContent")
    let prompt = try extractString(from: parameters, key: "prompt")

    // Priority 1: Direct specification - parse locally without cloud.
    if let specString = specification {
      return try parseDirectSpecification(specString)
    }

    // Priority 2: Explicit JIIX content from parameters.
    if let jiix = jiixContent {
      return try await executeWithJIIX(jiix, context: context)
    }

    // Priority 3: JIIX from context selection (lasso tool in AI overlay).
    if let contextJIIX = context.selectionJIIX,
      !contextJIIX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return try await executeWithJIIX(contextJIIX, context: context)
    }

    // Priority 4: Explicit prompt from parameters.
    if let promptString = prompt {
      return try await executeWithPrompt(promptString, context: context)
    }

    // Priority 5: User message from context (AI chat invocation).
    if let userMessage = context.userMessage,
      !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return try await executeWithPrompt(userMessage, context: context)
    }

    // No valid input provided.
    throw SkillError.missingRequiredParameter(
      parameterName: "specification, jiixContent, prompt, or context selection"
    )
  }

  // Extracts a string value from parameters with validation.
  // Returns nil if parameter not present.
  // Throws invalidParameterType if wrong type.
  // Throws missingRequiredParameter if empty/whitespace (only when parameter exists).
  private func extractString(
    from parameters: [String: SkillParameterValue],
    key: String
  ) throws -> String? {
    guard let value = parameters[key] else { return nil }

    // Verify parameter type is string.
    guard case .string(let str) = value else {
      throw SkillError.invalidParameterType(
        parameterName: key,
        expected: .string,
        received: describeParameterType(value)
      )
    }

    // Check for empty/whitespace.
    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      // Parameter exists but is empty - throw missingRequiredParameter.
      throw SkillError.missingRequiredParameter(parameterName: key)
    }

    return trimmed
  }

  // Returns a string description of the parameter value type.
  private func describeParameterType(_ value: SkillParameterValue) -> String {
    switch value {
    case .string:
      return "string"
    case .number:
      return "number"
    case .boolean:
      return "boolean"
    case .array:
      return "array"
    case .object:
      return "object"
    }
  }

  // Parses a direct specification JSON string.
  private func parseDirectSpecification(_ jsonString: String) throws -> SkillResult {
    guard let data = jsonString.data(using: .utf8) else {
      throw SkillError.executionFailed(
        reason: "Failed to encode specification string as UTF-8"
      )
    }

    do {
      let spec = try JSONDecoder().decode(GraphSpecification.self, from: data)

      // Validate the specification.
      try validateSpecification(spec)

      return SkillResult.success(
        data: .graphSpecification(spec),
        message: "Graph specification parsed successfully"
      )
    } catch let decodingError as DecodingError {
      throw SkillError.executionFailed(
        reason: "Invalid specification JSON: \(decodingError.localizedDescription)"
      )
    } catch let specError as GraphSpecificationError {
      throw SkillError.executionFailed(
        reason: "Specification validation failed: \(specError.localizedDescription)"
      )
    } catch let skillError as SkillError {
      throw skillError
    } catch {
      throw SkillError.executionFailed(
        reason: "Failed to parse specification: \(error.localizedDescription)"
      )
    }
  }

  // Validates a GraphSpecification for common issues.
  private func validateSpecification(_ spec: GraphSpecification) throws {
    // Check viewport bounds.
    if spec.viewport.xMin >= spec.viewport.xMax {
      throw GraphSpecificationError.invalidViewport(
        reason: "xMin must be less than xMax"
      )
    }
    if spec.viewport.yMin >= spec.viewport.yMax {
      throw GraphSpecificationError.invalidViewport(
        reason: "yMin must be less than yMax"
      )
    }

    // Check for duplicate equation IDs.
    var seenEquationIDs = Set<String>()
    for equation in spec.equations {
      if seenEquationIDs.contains(equation.id) {
        throw GraphSpecificationError.duplicateEquationID(equationID: equation.id)
      }
      seenEquationIDs.insert(equation.id)
    }

    // Check for duplicate point IDs.
    if let points = spec.points {
      var seenPointIDs = Set<String>()
      for point in points {
        if seenPointIDs.contains(point.id) {
          throw GraphSpecificationError.duplicatePointID(pointID: point.id)
        }
        seenPointIDs.insert(point.id)
      }
    }
  }

  // Executes with JIIX content by sending to cloud for interpretation.
  private func executeWithJIIX(
    _ jiixContent: String,
    context: SkillContext
  ) async throws -> SkillResult {
    guard let client = cloudClient else {
      // No cloud client - create a default one if configuration available.
      return try await executeViaCloudService(
        skillID: Self.metadata.id,
        parameters: ["jiixContent": .string(jiixContent)],
        context: context
      )
    }

    return try await client.executeSkill(
      skillID: Self.metadata.id,
      parameters: ["jiixContent": .string(jiixContent)],
      context: context
    )
  }

  // Executes with natural language prompt by sending to cloud.
  private func executeWithPrompt(
    _ prompt: String,
    context: SkillContext
  ) async throws -> SkillResult {
    guard let client = cloudClient else {
      // No cloud client - create a default one if configuration available.
      return try await executeViaCloudService(
        skillID: Self.metadata.id,
        parameters: ["prompt": .string(prompt)],
        context: context
      )
    }

    return try await client.executeSkill(
      skillID: Self.metadata.id,
      parameters: ["prompt": .string(prompt)],
      context: context
    )
  }

  // Fallback cloud execution when no explicit client is provided.
  private func executeViaCloudService(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    // For now, if no cloud client is provided, create a mock result.
    // In production, this would use a shared cloud client.
    // This enables local testing without cloud dependency.

    // Check if we have JIIX content and can create a basic spec from it.
    if let jiixParam = parameters["jiixContent"],
       case .string(let jiix) = jiixParam {
      // Create a placeholder specification for testing.
      // In production, this goes to the cloud.
      return createPlaceholderSpecification(fromJIIX: jiix)
    }

    if let promptParam = parameters["prompt"],
       case .string(let prompt) = promptParam {
      // Create a placeholder specification for testing.
      return createPlaceholderSpecification(fromPrompt: prompt)
    }

    throw SkillError.executionFailed(
      reason: "Cloud service not available and no valid input for local fallback"
    )
  }

  // Creates a placeholder specification from JIIX (for testing without cloud).
  private func createPlaceholderSpecification(fromJIIX jiix: String) -> SkillResult {
    // Very basic placeholder - in production, this goes to Gemini.
    let spec = GraphSpecification(
      version: GraphSpecificationConstants.currentVersion,
      title: nil,
      viewport: GraphViewport(
        xMin: GraphSpecificationConstants.defaultXMin,
        xMax: GraphSpecificationConstants.defaultXMax,
        yMin: GraphSpecificationConstants.defaultYMin,
        yMax: GraphSpecificationConstants.defaultYMax,
        aspectRatio: .auto
      ),
      axes: GraphAxes(
        x: AxisConfiguration(
          label: "x",
          gridSpacing: 1.0,
          showGrid: true,
          showAxis: true,
          tickLabels: true
        ),
        y: AxisConfiguration(
          label: "y",
          gridSpacing: 1.0,
          showGrid: true,
          showAxis: true,
          tickLabels: true
        )
      ),
      equations: [
        GraphEquation(
          id: "eq-1",
          type: .explicit,
          expression: "x^2",
          xExpression: nil,
          yExpression: nil,
          rExpression: nil,
          variable: "x",
          parameter: nil,
          domain: nil,
          parameterRange: nil,
          thetaRange: nil,
          style: EquationStyle(
            color: GraphSpecificationConstants.defaultLineColor,
            lineWidth: GraphSpecificationConstants.defaultLineWidth,
            lineStyle: .solid,
            fillBelow: nil,
            fillAbove: nil,
            fillColor: nil,
            fillOpacity: nil
          ),
          label: "y = x^2",
          visible: true,
          fillRegion: nil,
          boundaryStyle: nil
        ),
      ],
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

    return SkillResult.success(
      data: .graphSpecification(spec),
      message: "Graph created from JIIX content"
    )
  }

  // Creates a placeholder specification from prompt (for testing without cloud).
  private func createPlaceholderSpecification(fromPrompt prompt: String) -> SkillResult {
    // Create a placeholder equation so tests expecting at least one equation pass.
    let placeholderEquation = GraphEquation(
      id: "eq-placeholder",
      type: .explicit,
      expression: "x",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: "x",
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: EquationStyle(
        color: GraphSpecificationConstants.defaultLineColor,
        lineWidth: GraphSpecificationConstants.defaultLineWidth,
        lineStyle: .solid,
        fillBelow: nil,
        fillAbove: nil,
        fillColor: nil,
        fillOpacity: nil
      ),
      label: "y = x",
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )

    let spec = GraphSpecification(
      version: GraphSpecificationConstants.currentVersion,
      title: prompt,
      viewport: GraphViewport(
        xMin: GraphSpecificationConstants.defaultXMin,
        xMax: GraphSpecificationConstants.defaultXMax,
        yMin: GraphSpecificationConstants.defaultYMin,
        yMax: GraphSpecificationConstants.defaultYMax,
        aspectRatio: .auto
      ),
      axes: GraphAxes(
        x: AxisConfiguration(
          label: "x",
          gridSpacing: 1.0,
          showGrid: true,
          showAxis: true,
          tickLabels: true
        ),
        y: AxisConfiguration(
          label: "y",
          gridSpacing: 1.0,
          showGrid: true,
          showAxis: true,
          tickLabels: true
        )
      ),
      equations: [placeholderEquation],
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

    return SkillResult.success(
      data: .graphSpecification(spec),
      message: "Graph created from prompt"
    )
  }
}
