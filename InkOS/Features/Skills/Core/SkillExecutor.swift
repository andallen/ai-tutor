// SkillExecutor.swift
// Production implementation of SkillExecutorProtocol.
// Orchestrates skill execution with validation, routing, and lifecycle management.

import Foundation

// Actor that orchestrates skill execution.
// Handles validation, routing to correct execution mode, and cancellation.
actor SkillExecutor: SkillExecutorProtocol {

  // The skill registry for looking up skills.
  private let registry: any SkillRegistryProtocol

  // Tracks active executions for cancellation.
  private var activeExecutions: [String: Bool] = [:]

  // Cache of skill metadata for validation.
  private var metadataCache: [String: SkillMetadata] = [:]

  // Initializes the executor with a registry.
  init(registry: any SkillRegistryProtocol) {
    self.registry = registry
  }

  // Convenience initializer using the shared registry.
  init() {
    self.registry = SkillRegistry.shared
  }

  // Executes a skill by ID with given parameters and context.
  func execute(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    // Refresh metadata cache.
    await refreshMetadataCache()

    // Validate parameters before execution.
    try validateParameters(skillID: skillID, parameters: parameters)

    // Create skill instance.
    let skill = try await registry.createSkill(withID: skillID)

    // Get metadata for routing.
    guard let metadata = metadataCache[skillID] else {
      throw SkillError.skillNotFound(skillID: skillID)
    }

    // Apply default values for missing optional parameters.
    var effectiveParameters = parameters
    for param in metadata.parameters where !param.required {
      if effectiveParameters[param.name] == nil, let defaultVal = param.defaultValue {
        effectiveParameters[param.name] = defaultVal
      }
    }

    // Execute based on mode.
    switch metadata.executionMode {
    case .local:
      return try await executeLocal(skill: skill, parameters: effectiveParameters, context: context)
    case .cloud:
      return try await executeCloud(skill: skill, parameters: effectiveParameters, context: context)
    case .hybrid:
      return try await executeHybrid(
        skill: skill, parameters: effectiveParameters, context: context)
    }
  }

  // Validates parameters against skill metadata before execution.
  func validateParameters(
    skillID: String,
    parameters: [String: SkillParameterValue]
  ) throws {
    guard let metadata = metadataCache[skillID] else {
      throw SkillError.skillNotFound(skillID: skillID)
    }

    // Check required parameters.
    for param in metadata.parameters where param.required {
      guard let value = parameters[param.name] else {
        throw SkillError.missingRequiredParameter(parameterName: param.name)
      }

      // Check type.
      try validateParameterType(value: value, expected: param.type, paramName: param.name)

      // Check allowed values if defined.
      if let allowed = param.allowedValues, !allowed.isEmpty {
        if !allowed.contains(value) {
          let allowedStrings = allowed.compactMap { val -> String? in
            if case .string(let str) = val { return str }
            return nil
          }
          let valueString: String
          if case .string(let str) = value {
            valueString = str
          } else {
            valueString = String(describing: value)
          }
          throw SkillError.invalidParameterValue(
            parameterName: param.name,
            value: valueString,
            allowed: allowedStrings
          )
        }
      }
    }

    // Check optional parameters that are present.
    for param in metadata.parameters where !param.required {
      if let value = parameters[param.name] {
        try validateParameterType(value: value, expected: param.type, paramName: param.name)
      }
    }
  }

  // Cancels an in-progress skill execution.
  func cancelExecution(executionID: String) async {
    activeExecutions[executionID] = false
  }

  // Refreshes the metadata cache from the registry.
  private func refreshMetadataCache() async {
    let skills = await registry.allSkills()
    metadataCache = [:]
    for skill in skills {
      metadataCache[skill.id] = skill
    }
  }

  // Validates that a parameter value matches the expected type.
  private func validateParameterType(
    value: SkillParameterValue,
    expected: SkillParameterType,
    paramName: String
  ) throws {
    let actualType = typeString(for: value)
    if actualType != expected.rawValue {
      throw SkillError.invalidParameterType(
        parameterName: paramName,
        expected: expected,
        received: actualType
      )
    }
  }

  // Gets type string from a parameter value.
  private func typeString(for value: SkillParameterValue) -> String {
    switch value {
    case .string: return "string"
    case .number: return "number"
    case .boolean: return "boolean"
    case .array: return "array"
    case .object: return "object"
    }
  }

  // Executes a skill locally on-device.
  private func executeLocal(
    skill: any Skill,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    return try await skill.execute(parameters: parameters, context: context)
  }

  // Executes a skill via cloud infrastructure.
  private func executeCloud(
    skill: any Skill,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    // For cloud skills, the skill implementation handles the cloud call.
    // The executor just invokes execute and lets the skill manage cloud communication.
    return try await skill.execute(parameters: parameters, context: context)
  }

  // Executes a hybrid skill with both local and cloud components.
  private func executeHybrid(
    skill: any Skill,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    // Hybrid skills manage their own local/cloud coordination.
    return try await skill.execute(parameters: parameters, context: context)
  }
}
