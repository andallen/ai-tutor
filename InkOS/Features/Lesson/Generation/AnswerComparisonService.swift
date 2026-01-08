//
// AnswerComparisonService.swift
// InkOS
//
// Service for comparing user answers to correct answers via AI.
// Provides intelligent feedback for free response and math questions.
//

import Foundation

// MARK: - Answer Comparison Models

// Result of an answer comparison.
struct AnswerComparisonResult: Codable, Sendable, Equatable {
  // Whether the user's answer is correct.
  let isCorrect: Bool

  // Detailed feedback message for the user.
  let feedback: String

  // Optional explanation if an alternative answer was accepted.
  let acceptedReason: String?

  init(isCorrect: Bool, feedback: String, acceptedReason: String? = nil) {
    self.isCorrect = isCorrect
    self.feedback = feedback
    self.acceptedReason = acceptedReason
  }
}

// MARK: - Answer Comparison Protocol

// Protocol for answer comparison services.
// Enables dependency injection and testing with mock implementations.
protocol AnswerComparisonServiceProtocol: Sendable {
  // Compares a user's answer to the correct answer.
  // Returns feedback and correctness evaluation.
  func compareAnswer(
    userAnswer: String,
    correctAnswer: String,
    questionType: QuestionType,
    questionPrompt: String,
    explanation: String?
  ) async throws -> AnswerComparisonResult
}

// MARK: - Answer Comparison Errors

// Errors that can occur during answer comparison.
enum AnswerComparisonError: LocalizedError, Equatable {
  case networkError(reason: String)
  case invalidResponse
  case jsonParsingFailed(reason: String)
  case serverError(statusCode: Int, message: String)
  case apiKeyNotConfigured

  var errorDescription: String? {
    switch self {
    case .networkError(let reason):
      return "Network error: \(reason)"
    case .invalidResponse:
      return "Invalid response from server"
    case .jsonParsingFailed(let reason):
      return "Failed to parse comparison result: \(reason)"
    case .serverError(let statusCode, let message):
      return "Server error (\(statusCode)): \(message)"
    case .apiKeyNotConfigured:
      return "API key not configured on server"
    }
  }
}

// MARK: - Answer Comparison Service

// Actor that handles answer comparison via Firebase Cloud Functions.
// Uses Gemini AI for intelligent evaluation of free response and math answers.
actor AnswerComparisonService: AnswerComparisonServiceProtocol {

  // HTTP client for calling Cloud Functions.
  private let urlSession: URLSession

  // Base URL for Firebase Cloud Functions.
  private let functionsBaseURL: URL

  // JSON decoder configured for response parsing.
  private let jsonDecoder: JSONDecoder

  // Creates an answer comparison service with the specified configuration.
  // projectID: Firebase project ID.
  // region: Cloud Functions region (default: us-central1).
  init(
    projectID: String,
    region: String = "us-central1",
    urlSession: URLSession = .shared
  ) {
    self.urlSession = urlSession

    let baseURLString = "https://\(region)-\(projectID).cloudfunctions.net"
    self.functionsBaseURL = URL(string: baseURLString)!

    self.jsonDecoder = JSONDecoder()
  }

  // MARK: - Public Methods

  // Compares a user's answer to the correct answer.
  func compareAnswer(
    userAnswer: String,
    correctAnswer: String,
    questionType: QuestionType,
    questionPrompt: String,
    explanation: String? = nil
  ) async throws -> AnswerComparisonResult {
    // Build the request URL.
    let functionURL = functionsBaseURL.appendingPathComponent("compareAnswer")

    // Create the request body.
    var requestBody: [String: Any] = [
      "userAnswer": userAnswer,
      "correctAnswer": correctAnswer,
      "questionType": questionType.rawValue,
      "questionPrompt": questionPrompt,
    ]

    if let explanation = explanation {
      requestBody["explanation"] = explanation
    }

    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

    // Build the HTTP request.
    var request = URLRequest(url: functionURL)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Execute the request.
    let (data, response) = try await urlSession.data(for: request)

    // Check for HTTP errors.
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AnswerComparisonError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      let errorMessage = parseErrorResponse(data: data)
      throw AnswerComparisonError.serverError(
        statusCode: httpResponse.statusCode,
        message: errorMessage
      )
    }

    // Parse the response.
    return try parseComparisonResult(from: data)
  }

  // MARK: - Private Methods

  // Parses the comparison result from the response data.
  private func parseComparisonResult(from data: Data) throws -> AnswerComparisonResult {
    do {
      let result = try jsonDecoder.decode(AnswerComparisonResult.self, from: data)
      return result
    } catch {
      throw AnswerComparisonError.jsonParsingFailed(
        reason: error.localizedDescription
      )
    }
  }

  // Parses error details from the response body.
  private func parseErrorResponse(data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let error = json["error"] as? String {
      return error
    }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let errorObj = json["error"] as? [String: Any],
       let message = errorObj["message"] as? String {
      return message
    }
    return String(data: data, encoding: .utf8) ?? "Unknown error"
  }
}

// MARK: - Mock Answer Comparison Service

// Mock implementation for testing without network calls.
final class MockAnswerComparisonService: AnswerComparisonServiceProtocol, @unchecked Sendable {

  // Result to return from compare calls.
  var mockResult: AnswerComparisonResult?

  // Error to throw if set.
  var errorToThrow: Error?

  // Records requests that were made.
  private(set) var requestedComparisons: [(
    userAnswer: String,
    correctAnswer: String,
    questionType: QuestionType
  )] = []

  init(mockResult: AnswerComparisonResult? = nil) {
    self.mockResult = mockResult
  }

  func compareAnswer(
    userAnswer: String,
    correctAnswer: String,
    questionType: QuestionType,
    questionPrompt: String,
    explanation: String?
  ) async throws -> AnswerComparisonResult {
    requestedComparisons.append((userAnswer, correctAnswer, questionType))

    if let error = errorToThrow {
      throw error
    }

    if let result = mockResult {
      return result
    }

    // Default: simple string comparison.
    let isCorrect = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
      correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    return AnswerComparisonResult(
      isCorrect: isCorrect,
      feedback: isCorrect ? "Correct!" : "Not quite. Try again."
    )
  }

  // Resets recorded state for testing.
  func reset() {
    requestedComparisons = []
    errorToThrow = nil
  }
}
