// SkillRegistry.swift
// Production implementation of SkillRegistryProtocol.
// Manages skill registration, discovery, and instantiation.

import Foundation

// Actor that maintains the registry of available skills.
// Provides thread-safe access to skill metadata and instances.
actor SkillRegistry: SkillRegistryProtocol {

  // Shared instance for app-wide skill registration.
  static let shared = SkillRegistry()

  // Storage for registered skill types indexed by identifier.
  private var registeredSkills: [String: any Skill.Type] = [:]

  // Private init for singleton pattern.
  private init() {}

  // Registers a skill type with the registry.
  // If a skill with the same ID already exists, it is replaced.
  func register<S: Skill>(_ skillType: S.Type) {
    registeredSkills[S.metadata.id] = skillType
  }

  // Returns metadata for all registered skills.
  // Sorted alphabetically by displayName.
  func allSkills() -> [SkillMetadata] {
    registeredSkills.values
      .map { $0.metadata }
      .sorted { $0.displayName < $1.displayName }
  }

  // Returns metadata for a specific skill by ID.
  // Returns nil if skill is not registered.
  func skill(withID id: String) -> SkillMetadata? {
    registeredSkills[id]?.metadata
  }

  // Creates a new instance of a skill by ID.
  // Throws skillNotFound if ID is not registered.
  func createSkill(withID id: String) throws -> any Skill {
    guard let skillType = registeredSkills[id] else {
      throw SkillError.skillNotFound(skillID: id)
    }

    // Create instance using metatype.
    // Skills must have an init() that can be called.
    guard let instance = createInstance(of: skillType) else {
      throw SkillError.skillCreationFailed(
        skillID: id,
        reason: "Failed to instantiate skill type"
      )
    }

    return instance
  }

  // Generates Gemini-compatible function declarations for all skills.
  // Used to provide Gemini AI with available skill capabilities.
  func generateGeminiFunctionDeclarations() -> [GeminiFunctionDeclaration] {
    registeredSkills.values.map { skillType in
      let meta = skillType.metadata
      return buildGeminiFunctionDeclaration(from: meta)
    }
  }

  // Builds a Gemini function declaration from skill metadata.
  private func buildGeminiFunctionDeclaration(
    from metadata: SkillMetadata
  ) -> GeminiFunctionDeclaration {
    var properties: [String: GeminiPropertySchema] = [:]
    var required: [String] = []

    for param in metadata.parameters {
      // Extract enum values if present.
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
      name: metadata.id,
      description: metadata.description,
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: properties,
        required: required
      )
    )
  }

  // Helper to create instance of a skill type.
  // Uses reflection to instantiate the concrete type.
  private func createInstance(of skillType: any Skill.Type) -> (any Skill)? {
    // Attempt to create using default initializer.
    // This relies on the skill having an accessible init().
    if let creatableType = skillType as? any SkillCreatable.Type {
      return creatableType.createInstance()
    }
    return nil
  }
}

// Protocol for skills that can be instantiated by the registry.
// Skills should conform to this to enable dynamic creation.
protocol SkillCreatable: Skill {
  // Creates a new instance of the skill.
  static func createInstance() -> Self
}
