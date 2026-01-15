//
// AlanEndpoints.swift
// InkOS
//
// URL configuration for Alan and subagent API endpoints.
// Supports development, staging, and production environments.
//

import Foundation

// MARK: - AlanEndpoints

// Configuration for Alan API endpoints.
struct AlanEndpoints {
  // The base URL for all API requests.
  let baseURL: URL

  // Alan chat endpoint (SSE streaming).
  var alanURL: URL {
    baseURL.appendingPathComponent("alan")
  }

  // Subagent execution endpoint.
  var subagentURL: URL {
    baseURL.appendingPathComponent("executeSubagent")
  }

  // Skill router endpoint (for legacy skills).
  var skillRouterURL: URL {
    baseURL.appendingPathComponent("executeSkill")
  }

  // Creates endpoints with the given base URL.
  init(baseURL: URL) {
    self.baseURL = baseURL
  }

  // Creates endpoints from a base URL string.
  init?(baseURLString: String) {
    guard let url = URL(string: baseURLString) else {
      return nil
    }
    self.baseURL = url
  }
}

// MARK: - Environment Presets

extension AlanEndpoints {
  // Production Cloud Functions endpoint.
  static var production: AlanEndpoints {
    AlanEndpoints(baseURL: URL(string: "https://us-central1-inkos-f58f1.cloudfunctions.net")!)
  }

  // Local emulator endpoint for development.
  static var localEmulator: AlanEndpoints {
    AlanEndpoints(baseURL: URL(string: "http://127.0.0.1:5001/inkos-f58f1/us-central1")!)
  }

  // Staging environment (if configured).
  static var staging: AlanEndpoints {
    // For now, use production. Update when staging environment is set up.
    production
  }
}

// MARK: - Environment Selection

extension AlanEndpoints {
  // Returns the appropriate endpoints for the current build configuration.
  static var current: AlanEndpoints {
    #if DEBUG
      // Use local emulator in debug builds if available, otherwise production.
      // To use local emulator, set ALAN_USE_EMULATOR environment variable.
      if ProcessInfo.processInfo.environment["ALAN_USE_EMULATOR"] != nil {
        return .localEmulator
      }
      return .production
    #else
      return .production
    #endif
  }
}

// MARK: - Request Configuration

extension AlanEndpoints {
  // Default timeout for API requests (in seconds).
  static let defaultTimeoutInterval: TimeInterval = 60

  // Extended timeout for streaming requests.
  static let streamingTimeoutInterval: TimeInterval = 120

  // Maximum number of retry attempts for failed requests.
  static let maxRetryAttempts: Int = 3

  // Base delay for exponential backoff (in seconds).
  static let retryBaseDelay: TimeInterval = 1.0
}
