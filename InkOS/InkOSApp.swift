//
//  InkOSApp.swift
//  InkOS
//
//  Created by Andrew Allen on 12/18/25.
//

import SwiftUI

@main
struct InkOSApp: App {
  init() {
    // Register all available skills with the registry at app startup.
    Task {
      await SkillRegistry.shared.register(GraphingCalculatorSkill.self)
    }
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
  }
}
