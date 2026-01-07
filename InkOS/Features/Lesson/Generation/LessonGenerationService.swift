//
// LessonGenerationService.swift
// InkOS
//
// Service for generating interactive lessons via Firebase Cloud Functions.
// Supports streaming responses for real-time progress feedback.
//

import Foundation

// MARK: - Lesson Generation Protocol

// Protocol for lesson generation services.
// Enables dependency injection and testing with mock implementations.
protocol LessonGenerationServiceProtocol: Sendable {
  // Generates a lesson from a text prompt with streaming progress.
  // onProgress: Called with accumulated character count during streaming.
  // Returns the generated Lesson object.
  func generateLesson(
    prompt: String,
    estimatedMinutes: Int,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> Lesson

  // Generates a lesson from PDF content with streaming progress.
  // pdfText: Extracted text from PDF to base the lesson on.
  func generateLessonFromPDF(
    prompt: String,
    pdfText: String,
    estimatedMinutes: Int,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> Lesson
}

// MARK: - Lesson Generation Errors

// Errors that can occur during lesson generation.
enum LessonGenerationError: LocalizedError, Equatable {
  case networkError(reason: String)
  case invalidResponse
  case jsonParsingFailed(reason: String)
  case streamingFailed(reason: String)
  case serverError(statusCode: Int, message: String)
  case apiKeyNotConfigured
  case generationCancelled

  var errorDescription: String? {
    switch self {
    case .networkError(let reason):
      return "Network error: \(reason)"
    case .invalidResponse:
      return "Invalid response from server"
    case .jsonParsingFailed(let reason):
      return "Failed to parse lesson JSON: \(reason)"
    case .streamingFailed(let reason):
      return "Streaming failed: \(reason)"
    case .serverError(let statusCode, let message):
      return "Server error (\(statusCode)): \(message)"
    case .apiKeyNotConfigured:
      return "API key not configured on server"
    case .generationCancelled:
      return "Lesson generation was cancelled"
    }
  }
}

// MARK: - Lesson Generation Service

// Actor that handles lesson generation via Firebase Cloud Functions.
// Uses Server-Sent Events (SSE) for streaming responses.
actor LessonGenerationService: LessonGenerationServiceProtocol {

  // HTTP client for calling Cloud Functions.
  private let urlSession: URLSession

  // Base URL for Firebase Cloud Functions.
  private let functionsBaseURL: URL

  // JSON decoder configured for lesson parsing.
  private let jsonDecoder: JSONDecoder

  // Creates a lesson generation service with the specified configuration.
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
    self.jsonDecoder.dateDecodingStrategy = .iso8601
  }

  // MARK: - Public Methods

  // Generates a lesson from a text prompt with streaming progress.
  func generateLesson(
    prompt: String,
    estimatedMinutes: Int = 15,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> Lesson {
    return try await generateLessonInternal(
      prompt: prompt,
      sourceText: nil,
      estimatedMinutes: estimatedMinutes,
      onProgress: onProgress
    )
  }

  // Generates a lesson from PDF content with streaming progress.
  func generateLessonFromPDF(
    prompt: String,
    pdfText: String,
    estimatedMinutes: Int = 15,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> Lesson {
    return try await generateLessonInternal(
      prompt: prompt,
      sourceText: pdfText,
      estimatedMinutes: estimatedMinutes,
      onProgress: onProgress
    )
  }

  // MARK: - Private Methods

  // Internal implementation for lesson generation with streaming.
  private func generateLessonInternal(
    prompt: String,
    sourceText: String?,
    estimatedMinutes: Int,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> Lesson {
    // Build the request URL.
    let functionURL = functionsBaseURL.appendingPathComponent("generateLesson")

    // Create the request body.
    var requestBody: [String: Any] = [
      "prompt": prompt,
      "estimatedMinutes": estimatedMinutes,
    ]

    if let sourceText = sourceText {
      requestBody["sourceText"] = sourceText
    }

    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

    // Build the HTTP request.
    var request = URLRequest(url: functionURL)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

    // Execute the streaming request.
    let (bytes, response) = try await urlSession.bytes(for: request)

    // Check for HTTP errors.
    guard let httpResponse = response as? HTTPURLResponse else {
      throw LessonGenerationError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw LessonGenerationError.serverError(
        statusCode: httpResponse.statusCode,
        message: "Server returned error"
      )
    }

    // Parse the SSE stream.
    let fullText = try await parseSSEStream(
      bytes: bytes,
      onProgress: onProgress
    )

    // Parse the accumulated JSON into a Lesson.
    return try parseLesson(from: fullText)
  }

  // Parses Server-Sent Events stream and accumulates text.
  private func parseSSEStream(
    bytes: URLSession.AsyncBytes,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> String {
    var accumulatedText = ""
    var lineBuffer = ""

    for try await byte in bytes {
      let char = Character(UnicodeScalar(byte))

      if char == "\n" {
        // Process complete line.
        if lineBuffer.hasPrefix("data: ") {
          let jsonString = String(lineBuffer.dropFirst(6))
          if !jsonString.isEmpty {
            do {
              if let data = jsonString.data(using: .utf8),
                 let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // Check for errors.
                if let error = json["error"] as? String {
                  throw LessonGenerationError.streamingFailed(reason: error)
                }

                // Check for completion.
                if let done = json["done"] as? Bool, done {
                  // Use fullText if provided, otherwise use accumulated.
                  if let fullText = json["fullText"] as? String {
                    accumulatedText = fullText
                  }
                  break
                }

                // Accumulate chunk.
                if let chunk = json["chunk"] as? String {
                  accumulatedText += chunk
                  // Report progress.
                  let count = accumulatedText.count
                  onProgress(count)
                }

                // Or use accumulated count from server.
                if let accumulated = json["accumulated"] as? Int {
                  onProgress(accumulated)
                }
              }
            } catch let error as LessonGenerationError {
              throw error
            } catch {
              // Skip malformed JSON lines.
            }
          }
        }
        lineBuffer = ""
      } else {
        lineBuffer.append(char)
      }
    }

    return accumulatedText
  }

  // Parses the accumulated JSON text into a Lesson object.
  private func parseLesson(from text: String) throws -> Lesson {
    // Clean up the text (remove any markdown code block markers).
    var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

    if cleanText.hasPrefix("```json") {
      cleanText = String(cleanText.dropFirst(7))
    } else if cleanText.hasPrefix("```") {
      cleanText = String(cleanText.dropFirst(3))
    }

    if cleanText.hasSuffix("```") {
      cleanText = String(cleanText.dropLast(3))
    }

    cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let data = cleanText.data(using: .utf8) else {
      throw LessonGenerationError.jsonParsingFailed(reason: "Invalid UTF-8 text")
    }

    do {
      let lesson = try jsonDecoder.decode(Lesson.self, from: data)
      return lesson
    } catch {
      throw LessonGenerationError.jsonParsingFailed(
        reason: error.localizedDescription
      )
    }
  }
}

// MARK: - Mock Lesson Generation Service

// Mock implementation for testing without network calls.
final class MockLessonGenerationService: LessonGenerationServiceProtocol, @unchecked Sendable {

  // Lesson to return from generate calls.
  var mockLesson: Lesson?

  // Error to throw if set.
  var errorToThrow: Error?

  // Simulated progress steps for streaming.
  var progressSteps: [Int] = [100, 500, 1000, 2000]

  // Records prompts that were requested.
  private(set) var requestedPrompts: [String] = []

  // Records source texts that were provided.
  private(set) var requestedSourceTexts: [String?] = []

  init(mockLesson: Lesson? = nil) {
    self.mockLesson = mockLesson
  }

  func generateLesson(
    prompt: String,
    estimatedMinutes: Int,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> Lesson {
    requestedPrompts.append(prompt)
    requestedSourceTexts.append(nil)

    if let error = errorToThrow {
      throw error
    }

    // Simulate streaming progress.
    for step in progressSteps {
      try await Task.sleep(nanoseconds: 50_000_000)
      onProgress(step)
    }

    guard let lesson = mockLesson else {
      throw LessonGenerationError.invalidResponse
    }

    return lesson
  }

  func generateLessonFromPDF(
    prompt: String,
    pdfText: String,
    estimatedMinutes: Int,
    onProgress: @escaping @Sendable (Int) -> Void
  ) async throws -> Lesson {
    requestedPrompts.append(prompt)
    requestedSourceTexts.append(pdfText)

    if let error = errorToThrow {
      throw error
    }

    // Simulate streaming progress.
    for step in progressSteps {
      try await Task.sleep(nanoseconds: 50_000_000)
      onProgress(step)
    }

    guard let lesson = mockLesson else {
      throw LessonGenerationError.invalidResponse
    }

    return lesson
  }

  // Resets recorded state for testing.
  func reset() {
    requestedPrompts = []
    requestedSourceTexts = []
    errorToThrow = nil
  }
}
