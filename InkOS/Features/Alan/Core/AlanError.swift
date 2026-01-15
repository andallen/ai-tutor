//
// AlanError.swift
// InkOS
//
// Error types for the Alan subagent architecture.
// Covers network errors, server errors, parsing errors, and subagent failures.
//

import Foundation

// MARK: - AlanError

// Errors that can occur during Alan operations.
enum AlanError: Error, LocalizedError, Sendable, Equatable {
  // Network connectivity or request failed.
  case networkError(message: String)

  // Server returned an error status code.
  case serverError(statusCode: Int, message: String)

  // Failed to decode response data.
  case decodingError(context: String)

  // Operation timed out.
  case timeout(operation: String)

  // Server returned an invalid or unexpected response.
  case invalidResponse(reason: String)

  // A subagent request failed.
  case subagentFailed(requestId: SubagentRequestID, code: String, message: String)

  // Stream was interrupted before completion.
  case streamInterrupted(reason: String)

  // Request was cancelled.
  case cancelled

  // API key or configuration is missing.
  case configurationError(detail: String)

  var errorDescription: String? {
    switch self {
    case .networkError(let message):
      return "Network error: \(message)"
    case .serverError(let code, let message):
      return "Server error (\(code)): \(message)"
    case .decodingError(let context):
      return "Failed to decode response: \(context)"
    case .timeout(let operation):
      return "Operation timed out: \(operation)"
    case .invalidResponse(let reason):
      return "Invalid response: \(reason)"
    case .subagentFailed(_, let code, let message):
      return "Content generation failed [\(code)]: \(message)"
    case .streamInterrupted(let reason):
      return "Stream interrupted: \(reason)"
    case .cancelled:
      return "Operation was cancelled"
    case .configurationError(let detail):
      return "Configuration error: \(detail)"
    }
  }

  // Whether this error is retryable.
  var isRetryable: Bool {
    switch self {
    case .networkError, .timeout, .streamInterrupted:
      return true
    case .serverError(let code, _):
      // Retry on 5xx errors and rate limiting (429).
      return code >= 500 || code == 429
    case .decodingError, .invalidResponse, .subagentFailed, .cancelled, .configurationError:
      return false
    }
  }
}

// MARK: - AlanError from URLError

extension AlanError {
  // Creates an AlanError from a URLError.
  static func from(_ urlError: URLError) -> AlanError {
    switch urlError.code {
    case .timedOut:
      return .timeout(operation: "network request")
    case .cancelled:
      return .cancelled
    case .notConnectedToInternet, .networkConnectionLost:
      return .networkError(message: "No internet connection")
    case .cannotFindHost, .cannotConnectToHost:
      return .networkError(message: "Cannot connect to server")
    default:
      return .networkError(message: urlError.localizedDescription)
    }
  }
}

// MARK: - AlanError from SubagentError

extension AlanError {
  // Creates an AlanError from a SubagentError.
  static func from(_ subagentError: SubagentError, requestId: SubagentRequestID) -> AlanError {
    .subagentFailed(requestId: requestId, code: subagentError.code, message: subagentError.message)
  }
}
