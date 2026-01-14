// SkillRegistration.swift
// Registers all available skills with the SkillRegistry.
// Called once during app initialization to make skills available to the UI and Gemini AI.

import Foundation

// Registers all skills with the shared SkillRegistry.
// Call this function once during app initialization.
func registerSkills() async {
  // Register the graphing calculator skill.
  await SkillRegistry.shared.register(GraphingCalculatorSkill.self)

  // Future skills can be registered here as they are implemented.
  // await SkillRegistry.shared.register(OtherSkill.self)
}
