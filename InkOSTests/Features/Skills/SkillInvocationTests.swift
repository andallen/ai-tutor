// SkillInvocationTests.swift
// Comprehensive tests for the Skills Invocation layer.
// These tests validate all types, protocols, and behaviors defined in InvocationContract.swift.
// Tests cover cloud skill execution via Firebase and AI-orchestrated skill invocation.

import Foundation
import Testing

@testable import InkOS

// MARK: - Mock Implementations

// Mock implementation of SkillCloudClientProtocol for testing cloud skill execution.
// Tracks method invocations and allows configurable responses and errors.
actor MockSkillCloudClient: SkillCloudClientProtocol {

  // Tracks executeSkill invocations.
  private(set) var executeSkillCallCount = 0
  private(set) var lastSkillID: String?
  private(set) var lastParameters: [String: SkillParameterValue]?
  private(set) var lastContext: SkillContext?

  // Tracks executeSkillStreaming invocations.
  private(set) var executeStreamingCallCount = 0
  private(set) var streamingSkillID: String?
  private(set) var streamingParameters: [String: SkillParameterValue]?
  private(set) var streamingContext: SkillContext?

  // Configurable result to return from executeSkill.
  var resultToReturn: SkillResult = .success(text: "Cloud result")

  // Configurable error to throw from executeSkill.
  var errorToThrow: InvocationError?

  // Configurable streaming chunks to emit.
  var streamingChunks: [SkillResultChunk] = []

  // Configurable streaming result after all chunks.
  var streamingFinalResult: SkillResult = .success(text: "Streaming complete")

  // Configurable streaming error to throw mid-stream.
  var streamingError: InvocationError?

  // Delay before returning result (for timeout testing).
  var artificialDelaySeconds: Double = 0

  // Flag to simulate cancellation.
  var shouldSimulateCancellation = false

  func executeSkill(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    executeSkillCallCount += 1
    lastSkillID = skillID
    lastParameters = parameters
    lastContext = context

    // Simulate delay if configured.
    if artificialDelaySeconds > 0 {
      try await Task.sleep(nanoseconds: UInt64(artificialDelaySeconds * 1_000_000_000))
    }

    // Check for cancellation simulation.
    if shouldSimulateCancellation {
      throw InvocationError.cancelled
    }

    // Throw configured error if present.
    if let error = errorToThrow {
      throw error
    }

    return resultToReturn
  }

  func executeSkillStreaming(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext,
    onChunk: @escaping @Sendable (SkillResultChunk) -> Void
  ) async throws -> SkillResult {
    executeStreamingCallCount += 1
    streamingSkillID = skillID
    streamingParameters = parameters
    streamingContext = context

    // Emit configured chunks.
    for chunk in streamingChunks {
      // Check for streaming error before each chunk.
      if let error = streamingError {
        throw error
      }
      onChunk(chunk)
    }

    // Check for cancellation after chunks.
    if shouldSimulateCancellation {
      throw InvocationError.cancelled
    }

    // Throw streaming error if configured.
    if let error = streamingError {
      throw error
    }

    return streamingFinalResult
  }

  // Test helper to reset state between tests.
  func reset() {
    executeSkillCallCount = 0
    lastSkillID = nil
    lastParameters = nil
    lastContext = nil
    executeStreamingCallCount = 0
    streamingSkillID = nil
    streamingParameters = nil
    streamingContext = nil
    resultToReturn = .success(text: "Cloud result")
    errorToThrow = nil
    streamingChunks = []
    streamingFinalResult = .success(text: "Streaming complete")
    streamingError = nil
    artificialDelaySeconds = 0
    shouldSimulateCancellation = false
  }
}

// Mock implementation of AISkillInvocationServiceProtocol for testing AI orchestration.
// Tracks method invocations and allows configurable responses.
actor MockAISkillInvocationService: AISkillInvocationServiceProtocol {

  // Tracks getToolDeclarations invocations.
  private(set) var getToolDeclarationsCallCount = 0

  // Tracks sendMessage invocations.
  private(set) var sendMessageCallCount = 0
  private(set) var lastMessages: [ConversationMessage]?
  private(set) var lastContext: SkillContext?

  // Tracks sendMessageStreaming invocations.
  private(set) var sendMessageStreamingCallCount = 0
  private(set) var streamingMessages: [ConversationMessage]?
  private(set) var streamingContext: SkillContext?

  // Configurable tool declarations to return.
  var toolDeclarations: [GeminiFunctionDeclaration] = []

  // Configurable response to return from sendMessage.
  var responseToReturn: AISkillResponse = .text("AI response")

  // Configurable error to throw from sendMessage.
  var errorToThrow: InvocationError?

  // Configurable streaming chunks to emit.
  var streamingChunks: [SkillResultChunk] = []

  // Configurable streaming response after all chunks.
  var streamingFinalResponse: AISkillResponse = .text("Streaming AI response")

  // Configurable streaming error to throw mid-stream.
  var streamingError: InvocationError?

  // Flag to simulate cancellation.
  var shouldSimulateCancellation = false

  func getToolDeclarations() async -> [GeminiFunctionDeclaration] {
    getToolDeclarationsCallCount += 1
    return toolDeclarations
  }

  func sendMessage(
    messages: [ConversationMessage],
    context: SkillContext
  ) async throws -> AISkillResponse {
    sendMessageCallCount += 1
    lastMessages = messages
    lastContext = context

    // Check for cancellation simulation.
    if shouldSimulateCancellation {
      throw InvocationError.cancelled
    }

    // Throw configured error if present.
    if let error = errorToThrow {
      throw error
    }

    return responseToReturn
  }

  func sendMessageStreaming(
    messages: [ConversationMessage],
    context: SkillContext,
    onChunk: @escaping @Sendable (SkillResultChunk) -> Void
  ) async throws -> AISkillResponse {
    sendMessageStreamingCallCount += 1
    streamingMessages = messages
    streamingContext = context

    // Emit configured chunks.
    for chunk in streamingChunks {
      // Check for streaming error before each chunk.
      if let error = streamingError {
        throw error
      }
      onChunk(chunk)
    }

    // Check for cancellation after chunks.
    if shouldSimulateCancellation {
      throw InvocationError.cancelled
    }

    // Throw streaming error if configured.
    if let error = streamingError {
      throw error
    }

    return streamingFinalResponse
  }

  // Test helper to reset state between tests.
  func reset() {
    getToolDeclarationsCallCount = 0
    sendMessageCallCount = 0
    lastMessages = nil
    lastContext = nil
    sendMessageStreamingCallCount = 0
    streamingMessages = nil
    streamingContext = nil
    toolDeclarations = []
    responseToReturn = .text("AI response")
    errorToThrow = nil
    streamingChunks = []
    streamingFinalResponse = .text("Streaming AI response")
    streamingError = nil
    shouldSimulateCancellation = false
  }
}

// MARK: - InvocationError Tests

@Suite("InvocationError Tests")
struct InvocationErrorTests {

  // MARK: - Error Case Tests

  @Test("networkError contains reason")
  func networkErrorContainsReason() {
    let error = InvocationError.networkError(reason: "Connection refused")

    if case .networkError(let reason) = error {
      #expect(reason == "Connection refused")
    } else {
      Issue.record("Expected networkError case")
    }
  }

  @Test("invalidResponse contains reason")
  func invalidResponseContainsReason() {
    let error = InvocationError.invalidResponse(reason: "Malformed JSON")

    if case .invalidResponse(let reason) = error {
      #expect(reason == "Malformed JSON")
    } else {
      Issue.record("Expected invalidResponse case")
    }
  }

  @Test("skillExecutionFailed contains skillID and reason")
  func skillExecutionFailedContainsDetails() {
    let error = InvocationError.skillExecutionFailed(skillID: "summarize", reason: "No content")

    if case .skillExecutionFailed(let skillID, let reason) = error {
      #expect(skillID == "summarize")
      #expect(reason == "No content")
    } else {
      Issue.record("Expected skillExecutionFailed case")
    }
  }

  @Test("streamingFailed contains reason")
  func streamingFailedContainsReason() {
    let error = InvocationError.streamingFailed(reason: "Stream interrupted")

    if case .streamingFailed(let reason) = error {
      #expect(reason == "Stream interrupted")
    } else {
      Issue.record("Expected streamingFailed case")
    }
  }

  @Test("timeout error case exists")
  func timeoutExists() {
    let error = InvocationError.timeout
    #expect(error == .timeout)
  }

  @Test("cancelled error case exists")
  func cancelledExists() {
    let error = InvocationError.cancelled
    #expect(error == .cancelled)
  }

  // MARK: - LocalizedError Conformance Tests

  @Test("networkError errorDescription contains reason")
  func networkErrorDescription() {
    let error = InvocationError.networkError(reason: "DNS lookup failed")
    #expect(error.errorDescription?.contains("Network error") == true)
    #expect(error.errorDescription?.contains("DNS lookup failed") == true)
  }

  @Test("invalidResponse errorDescription contains reason")
  func invalidResponseDescription() {
    let error = InvocationError.invalidResponse(reason: "Missing field 'data'")
    #expect(error.errorDescription?.contains("Invalid response") == true)
    #expect(error.errorDescription?.contains("Missing field 'data'") == true)
  }

  @Test("skillExecutionFailed errorDescription contains skillID and reason")
  func skillExecutionFailedDescription() {
    let error = InvocationError.skillExecutionFailed(skillID: "create-lesson", reason: "API error")
    #expect(error.errorDescription?.contains("create-lesson") == true)
    #expect(error.errorDescription?.contains("execution failed") == true)
    #expect(error.errorDescription?.contains("API error") == true)
  }

  @Test("streamingFailed errorDescription contains reason")
  func streamingFailedDescription() {
    let error = InvocationError.streamingFailed(reason: "Connection dropped")
    #expect(error.errorDescription?.contains("Streaming failed") == true)
    #expect(error.errorDescription?.contains("Connection dropped") == true)
  }

  @Test("timeout errorDescription indicates timeout")
  func timeoutDescription() {
    let error = InvocationError.timeout
    #expect(error.errorDescription?.contains("timed out") == true)
  }

  @Test("cancelled errorDescription indicates cancellation")
  func cancelledDescription() {
    let error = InvocationError.cancelled
    #expect(error.errorDescription?.contains("cancelled") == true)
  }

  // MARK: - Equatable Conformance Tests

  @Test("same networkError values are equal")
  func networkErrorEquatable() {
    let error1 = InvocationError.networkError(reason: "Offline")
    let error2 = InvocationError.networkError(reason: "Offline")
    #expect(error1 == error2)
  }

  @Test("different networkError values are not equal")
  func networkErrorNotEqual() {
    let error1 = InvocationError.networkError(reason: "Offline")
    let error2 = InvocationError.networkError(reason: "DNS failure")
    #expect(error1 != error2)
  }

  @Test("different error types are not equal")
  func differentTypesNotEqual() {
    let error1 = InvocationError.timeout
    let error2 = InvocationError.cancelled
    #expect(error1 != error2)
  }

  @Test("skillExecutionFailed with same values are equal")
  func skillExecutionFailedEquatable() {
    let error1 = InvocationError.skillExecutionFailed(skillID: "test", reason: "fail")
    let error2 = InvocationError.skillExecutionFailed(skillID: "test", reason: "fail")
    #expect(error1 == error2)
  }

  @Test("skillExecutionFailed with different skillID not equal")
  func skillExecutionFailedDifferentSkillID() {
    let error1 = InvocationError.skillExecutionFailed(skillID: "skill1", reason: "fail")
    let error2 = InvocationError.skillExecutionFailed(skillID: "skill2", reason: "fail")
    #expect(error1 != error2)
  }

  // MARK: - Edge Case Tests

  @Test("distinguishes timeout from networkError")
  func distinguishTimeoutFromNetwork() {
    // These should be distinct error cases for different failure modes.
    let timeoutError = InvocationError.timeout
    let networkError = InvocationError.networkError(reason: "Connection timed out")

    #expect(timeoutError != networkError)

    // Timeout is for deadline exceeded.
    #expect(timeoutError.errorDescription?.contains("timed out") == true)

    // Network error is for connection issues.
    #expect(networkError.errorDescription?.contains("Network error") == true)
  }
}

// MARK: - FirebaseConfiguration Tests

@Suite("FirebaseConfiguration Tests")
struct FirebaseConfigurationTests {

  @Test("creates configuration with required fields")
  func createsWithRequiredFields() {
    let config = FirebaseConfiguration(
      projectID: "my-project",
      region: "us-central1",
      apiKey: nil
    )

    #expect(config.projectID == "my-project")
    #expect(config.region == "us-central1")
    #expect(config.apiKey == nil)
  }

  @Test("creates configuration with API key")
  func createsWithAPIKey() {
    let config = FirebaseConfiguration(
      projectID: "my-project",
      region: "us-central1",
      apiKey: "AIzaSy..."
    )

    #expect(config.projectID == "my-project")
    #expect(config.region == "us-central1")
    #expect(config.apiKey == "AIzaSy...")
  }

  @Test("configuration is Sendable")
  func isSendable() async {
    // Create configuration on main actor.
    let config = FirebaseConfiguration(
      projectID: "test",
      region: "us-east1",
      apiKey: nil
    )

    // Pass to another actor context - should compile without warning.
    let result = await passConfigToActor(config)
    #expect(result == "test")
  }

  @Test("configuration is Equatable")
  func isEquatable() {
    let config1 = FirebaseConfiguration(
      projectID: "project",
      region: "region",
      apiKey: "key"
    )
    let config2 = FirebaseConfiguration(
      projectID: "project",
      region: "region",
      apiKey: "key"
    )
    let config3 = FirebaseConfiguration(
      projectID: "other",
      region: "region",
      apiKey: "key"
    )

    #expect(config1 == config2)
    #expect(config1 != config3)
  }

  @Test("empty projectID is allowed but invalid for use")
  func emptyProjectIDAllowed() {
    // The struct allows empty string, but client should reject at use time.
    let config = FirebaseConfiguration(
      projectID: "",
      region: "us-central1",
      apiKey: nil
    )

    #expect(config.projectID == "")
    // Actual validation happens in client implementation.
  }

  // Helper function to test Sendable conformance.
  private func passConfigToActor(_ config: FirebaseConfiguration) async -> String {
    // Simulates passing to another actor.
    return config.projectID
  }
}

// MARK: - SkillResultChunk Tests

@Suite("SkillResultChunk Tests")
struct SkillResultChunkTests {

  @Test("intermediate chunk has text and isComplete false")
  func intermediateChunk() {
    let chunk = SkillResultChunk(text: "partial content", isComplete: false)

    #expect(chunk.text == "partial content")
    #expect(chunk.isComplete == false)
  }

  @Test("final chunk has isComplete true")
  func finalChunk() {
    let chunk = SkillResultChunk(text: "final", isComplete: true)

    #expect(chunk.text == "final")
    #expect(chunk.isComplete == true)
  }

  @Test("empty intermediate chunk keeps stream alive")
  func emptyIntermediateChunk() {
    let chunk = SkillResultChunk(text: "", isComplete: false)

    #expect(chunk.text == "")
    #expect(chunk.isComplete == false)
  }

  @Test("final chunk may have empty text")
  func finalChunkEmptyText() {
    let chunk = SkillResultChunk(text: "", isComplete: true)

    #expect(chunk.text == "")
    #expect(chunk.isComplete == true)
  }

  @Test("chunk equality compares both fields")
  func chunkEquality() {
    let chunk1 = SkillResultChunk(text: "hello", isComplete: false)
    let chunk2 = SkillResultChunk(text: "hello", isComplete: false)
    let chunk3 = SkillResultChunk(text: "hello", isComplete: true)
    let chunk4 = SkillResultChunk(text: "world", isComplete: false)

    #expect(chunk1 == chunk2)
    #expect(chunk1 != chunk3)  // Different isComplete.
    #expect(chunk1 != chunk4)  // Different text.
  }

  @Test("chunk is Sendable")
  func isSendable() async {
    let chunk = SkillResultChunk(text: "test", isComplete: false)

    // Pass to async context.
    let result = await passChunkToActor(chunk)
    #expect(result == "test")
  }

  private func passChunkToActor(_ chunk: SkillResultChunk) async -> String {
    return chunk.text
  }
}

// MARK: - GeminiFunctionCall Tests

@Suite("GeminiFunctionCall Tests")
struct GeminiFunctionCallTests {

  @Test("parses simple function call")
  func simpleCall() {
    let call = GeminiFunctionCall(
      name: "summarize",
      arguments: ["text": .string("content to summarize")]
    )

    #expect(call.name == "summarize")
    #expect(call.arguments["text"] == .string("content to summarize"))
  }

  @Test("parses function call with multiple arguments")
  func multipleArguments() {
    let call = GeminiFunctionCall(
      name: "create-lesson",
      arguments: [
        "topic": .string("math"),
        "difficulty": .string("medium"),
        "includeExercises": .boolean(true),
      ]
    )

    #expect(call.name == "create-lesson")
    #expect(call.arguments.count == 3)
    #expect(call.arguments["topic"] == .string("math"))
    #expect(call.arguments["difficulty"] == .string("medium"))
    #expect(call.arguments["includeExercises"] == .boolean(true))
  }

  @Test("parses function call with nested object arguments")
  func nestedObjectArguments() {
    let call = GeminiFunctionCall(
      name: "configure",
      arguments: [
        "options": .object([
          "format": .string("markdown"),
          "verbose": .boolean(true),
        ])
      ]
    )

    #expect(call.name == "configure")
    if case .object(let options) = call.arguments["options"] {
      #expect(options["format"] == .string("markdown"))
      #expect(options["verbose"] == .boolean(true))
    } else {
      Issue.record("Expected object value for options")
    }
  }

  @Test("parses function call with array arguments")
  func arrayArguments() {
    let call = GeminiFunctionCall(
      name: "process-topics",
      arguments: [
        "topics": .array([
          .string("algebra"),
          .string("geometry"),
          .string("calculus"),
        ])
      ]
    )

    #expect(call.name == "process-topics")
    if case .array(let topics) = call.arguments["topics"] {
      #expect(topics.count == 3)
      #expect(topics[0] == .string("algebra"))
      #expect(topics[1] == .string("geometry"))
      #expect(topics[2] == .string("calculus"))
    } else {
      Issue.record("Expected array value for topics")
    }
  }

  @Test("parses function call with no arguments")
  func noArguments() {
    let call = GeminiFunctionCall(
      name: "get-current-time",
      arguments: [:]
    )

    #expect(call.name == "get-current-time")
    #expect(call.arguments.isEmpty)
  }

  @Test("function call is Equatable")
  func isEquatable() {
    let call1 = GeminiFunctionCall(name: "test", arguments: ["a": .string("b")])
    let call2 = GeminiFunctionCall(name: "test", arguments: ["a": .string("b")])
    let call3 = GeminiFunctionCall(name: "test", arguments: ["a": .string("c")])

    #expect(call1 == call2)
    #expect(call1 != call3)
  }

  @Test("function call is Sendable")
  func isSendable() async {
    let call = GeminiFunctionCall(name: "test", arguments: [:])

    let result = await passFunctionCallToActor(call)
    #expect(result == "test")
  }

  @Test("parses function call with numeric arguments")
  func numericArguments() {
    let call = GeminiFunctionCall(
      name: "calculate",
      arguments: [
        "count": .number(42),
        "multiplier": .number(1.5),
      ]
    )

    #expect(call.arguments["count"] == .number(42))
    #expect(call.arguments["multiplier"] == .number(1.5))
  }

  private func passFunctionCallToActor(_ call: GeminiFunctionCall) async -> String {
    return call.name
  }
}

// MARK: - AISkillResponse Tests

@Suite("AISkillResponse Tests")
struct AISkillResponseTests {

  @Test("text response from AI")
  func textResponse() {
    let response = AISkillResponse.text("This is the answer to your question.")

    if case .text(let content) = response {
      #expect(content == "This is the answer to your question.")
    } else {
      Issue.record("Expected text case")
    }
  }

  @Test("skill invocation response")
  func skillInvocationResponse() {
    let result = SkillResult.success(text: "Summarized content here")
    let response = AISkillResponse.skillInvocation(skillID: "summarize", result: result)

    if case .skillInvocation(let skillID, let returnedResult) = response {
      #expect(skillID == "summarize")
      #expect(returnedResult.success == true)
      #expect(returnedResult.data == .text("Summarized content here"))
    } else {
      Issue.record("Expected skillInvocation case")
    }
  }

  @Test("pending skill call response")
  func pendingSkillCallResponse() {
    let response = AISkillResponse.pendingSkillCall(
      skillID: "create-lesson",
      parameters: [
        "topic": .string("history"),
        "difficulty": .string("easy"),
      ]
    )

    if case .pendingSkillCall(let skillID, let params) = response {
      #expect(skillID == "create-lesson")
      #expect(params["topic"] == .string("history"))
      #expect(params["difficulty"] == .string("easy"))
    } else {
      Issue.record("Expected pendingSkillCall case")
    }
  }

  @Test("skill invocation with error result")
  func skillInvocationWithError() {
    let result = SkillResult.failure(
      error: .executionFailed(reason: "No content to summarize"),
      message: "Summarization failed"
    )
    let response = AISkillResponse.skillInvocation(skillID: "summarize", result: result)

    if case .skillInvocation(let skillID, let returnedResult) = response {
      #expect(skillID == "summarize")
      #expect(returnedResult.success == false)
      #expect(returnedResult.error == .executionFailed(reason: "No content to summarize"))
    } else {
      Issue.record("Expected skillInvocation case")
    }
  }

  @Test("empty text response is valid")
  func emptyTextResponse() {
    let response = AISkillResponse.text("")

    if case .text(let content) = response {
      #expect(content == "")
    } else {
      Issue.record("Expected text case")
    }
  }

  @Test("response is Equatable")
  func isEquatable() {
    let response1 = AISkillResponse.text("hello")
    let response2 = AISkillResponse.text("hello")
    let response3 = AISkillResponse.text("world")

    #expect(response1 == response2)
    #expect(response1 != response3)
  }

  @Test("different response types are not equal")
  func differentTypesNotEqual() {
    let textResponse = AISkillResponse.text("hello")
    let pendingResponse = AISkillResponse.pendingSkillCall(skillID: "test", parameters: [:])

    #expect(textResponse != pendingResponse)
  }

  @Test("response is Sendable")
  func isSendable() async {
    let response = AISkillResponse.text("test")

    let result = await passResponseToActor(response)
    #expect(result == true)
  }

  private func passResponseToActor(_ response: AISkillResponse) async -> Bool {
    if case .text = response {
      return true
    }
    return false
  }
}

// MARK: - InvocationConstants Tests

@Suite("InvocationConstants Tests")
struct InvocationConstantsTests {

  @Test("default cloud timeout is 60 seconds")
  func defaultCloudTimeout() {
    #expect(InvocationConstants.defaultCloudTimeoutSeconds == 60.0)
  }

  @Test("default AI timeout is 120 seconds")
  func defaultAITimeout() {
    #expect(InvocationConstants.defaultAITimeoutSeconds == 120.0)
  }

  @Test("maximum timeout is 300 seconds")
  func maximumTimeout() {
    #expect(InvocationConstants.maximumTimeoutSeconds == 300.0)
  }

  @Test("default streaming chunk size hint is 256")
  func defaultChunkSizeHint() {
    #expect(InvocationConstants.defaultStreamingChunkSizeHint == 256)
  }

  @Test("max retry attempts is 3")
  func maxRetryAttempts() {
    #expect(InvocationConstants.maxRetryAttempts == 3)
  }

  @Test("retry base delay is 1 second")
  func retryBaseDelay() {
    #expect(InvocationConstants.retryBaseDelaySeconds == 1.0)
  }

  @Test("cloud timeout is less than AI timeout")
  func cloudTimeoutLessThanAI() {
    // Cloud operations should be faster than full AI conversations.
    #expect(InvocationConstants.defaultCloudTimeoutSeconds < InvocationConstants.defaultAITimeoutSeconds)
  }

  @Test("AI timeout is less than maximum")
  func aiTimeoutLessThanMaximum() {
    #expect(InvocationConstants.defaultAITimeoutSeconds < InvocationConstants.maximumTimeoutSeconds)
  }
}

// MARK: - MockSkillCloudClient Tests

@Suite("MockSkillCloudClient Tests")
struct MockSkillCloudClientTests {

  @Test("executeSkill tracks invocation")
  func executeSkillTracksInvocation() async throws {
    let client = MockSkillCloudClient()
    let context = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
    let params: [String: SkillParameterValue] = ["text": .string("test")]

    _ = try await client.executeSkill(
      skillID: "summarize",
      parameters: params,
      context: context
    )

    let callCount = await client.executeSkillCallCount
    let lastSkillID = await client.lastSkillID
    let lastParams = await client.lastParameters
    let lastCtx = await client.lastContext

    #expect(callCount == 1)
    #expect(lastSkillID == "summarize")
    #expect(lastParams?["text"] == .string("test"))
    #expect(lastCtx?.currentNotebookID == "nb-1")
  }

  @Test("executeSkill returns configured result")
  func executeSkillReturnsConfiguredResult() async throws {
    let client = MockSkillCloudClient()
    await client.setResult(.success(text: "Custom result"))
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    let result = try await client.executeSkill(
      skillID: "test",
      parameters: [:],
      context: context
    )

    #expect(result.data == .text("Custom result"))
  }

  @Test("executeSkill throws configured error")
  func executeSkillThrowsConfiguredError() async {
    let client = MockSkillCloudClient()
    await client.setError(.networkError(reason: "Offline"))
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await client.executeSkill(
        skillID: "test",
        parameters: [:],
        context: context
      )
      Issue.record("Expected error to be thrown")
    } catch let error as InvocationError {
      #expect(error == .networkError(reason: "Offline"))
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test("executeSkillStreaming emits chunks and returns result")
  func executeSkillStreamingEmitsChunks() async throws {
    let client = MockSkillCloudClient()
    await client.setStreamingChunks([
      SkillResultChunk(text: "Hello ", isComplete: false),
      SkillResultChunk(text: "World", isComplete: false),
    ])
    await client.setStreamingFinalResult(.success(text: "Hello World"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    var receivedChunks: [SkillResultChunk] = []
    let result = try await client.executeSkillStreaming(
      skillID: "test",
      parameters: [:],
      context: context
    ) { chunk in
      receivedChunks.append(chunk)
    }

    #expect(receivedChunks.count == 2)
    #expect(receivedChunks[0].text == "Hello ")
    #expect(receivedChunks[1].text == "World")
    #expect(result.data == .text("Hello World"))
  }

  @Test("executeSkillStreaming throws on error")
  func executeSkillStreamingThrowsOnError() async {
    let client = MockSkillCloudClient()
    await client.setStreamingError(.streamingFailed(reason: "Connection lost"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await client.executeSkillStreaming(
        skillID: "test",
        parameters: [:],
        context: context
      ) { _ in }
      Issue.record("Expected error to be thrown")
    } catch let error as InvocationError {
      #expect(error == .streamingFailed(reason: "Connection lost"))
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test("executeSkill handles cancellation")
  func executeSkillHandlesCancellation() async {
    let client = MockSkillCloudClient()
    await client.setCancellation(true)

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await client.executeSkill(
        skillID: "test",
        parameters: [:],
        context: context
      )
      Issue.record("Expected cancellation error")
    } catch let error as InvocationError {
      #expect(error == .cancelled)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }
}

// Helper extensions for MockSkillCloudClient to set properties from outside.
extension MockSkillCloudClient {
  func setResult(_ result: SkillResult) {
    self.resultToReturn = result
  }

  func setError(_ error: InvocationError?) {
    self.errorToThrow = error
  }

  func setStreamingChunks(_ chunks: [SkillResultChunk]) {
    self.streamingChunks = chunks
  }

  func setStreamingFinalResult(_ result: SkillResult) {
    self.streamingFinalResult = result
  }

  func setStreamingError(_ error: InvocationError?) {
    self.streamingError = error
  }

  func setCancellation(_ value: Bool) {
    self.shouldSimulateCancellation = value
  }
}

// MARK: - MockAISkillInvocationService Tests

@Suite("MockAISkillInvocationService Tests")
struct MockAISkillInvocationServiceTests {

  @Test("getToolDeclarations returns configured declarations")
  func getToolDeclarationsReturnsConfigured() async {
    let service = MockAISkillInvocationService()
    let declaration = GeminiFunctionDeclaration(
      name: "summarize",
      description: "Summarizes text",
      parameters: GeminiFunctionParameters(
        type: "object",
        properties: [:],
        required: []
      )
    )
    await service.setToolDeclarations([declaration])

    let declarations = await service.getToolDeclarations()

    #expect(declarations.count == 1)
    #expect(declarations[0].name == "summarize")

    let callCount = await service.getToolDeclarationsCallCount
    #expect(callCount == 1)
  }

  @Test("sendMessage tracks invocation and returns response")
  func sendMessageTracksInvocation() async throws {
    let service = MockAISkillInvocationService()
    await service.setResponse(.text("AI answer"))

    let messages = [
      ConversationMessage(role: .user, content: "What is 2+2?")
    ]
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: "What is 2+2?",
      conversationHistory: nil
    )

    let response = try await service.sendMessage(messages: messages, context: context)

    if case .text(let content) = response {
      #expect(content == "AI answer")
    } else {
      Issue.record("Expected text response")
    }

    let callCount = await service.sendMessageCallCount
    let lastMsgs = await service.lastMessages
    let lastCtx = await service.lastContext

    #expect(callCount == 1)
    #expect(lastMsgs?.count == 1)
    #expect(lastMsgs?[0].content == "What is 2+2?")
    #expect(lastCtx?.userMessage == "What is 2+2?")
  }

  @Test("sendMessage throws configured error")
  func sendMessageThrowsError() async {
    let service = MockAISkillInvocationService()
    await service.setError(.networkError(reason: "No internet"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await service.sendMessage(messages: [], context: context)
      Issue.record("Expected error")
    } catch let error as InvocationError {
      #expect(error == .networkError(reason: "No internet"))
    } catch {
      Issue.record("Wrong error type")
    }
  }

  @Test("sendMessageStreaming emits chunks and returns response")
  func sendMessageStreamingEmitsChunks() async throws {
    let service = MockAISkillInvocationService()
    await service.setStreamingChunks([
      SkillResultChunk(text: "The ", isComplete: false),
      SkillResultChunk(text: "answer ", isComplete: false),
      SkillResultChunk(text: "is 4", isComplete: false),
    ])
    await service.setStreamingFinalResponse(.text("The answer is 4"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    var receivedChunks: [SkillResultChunk] = []
    let response = try await service.sendMessageStreaming(
      messages: [],
      context: context
    ) { chunk in
      receivedChunks.append(chunk)
    }

    #expect(receivedChunks.count == 3)
    if case .text(let content) = response {
      #expect(content == "The answer is 4")
    } else {
      Issue.record("Expected text response")
    }
  }

  @Test("sendMessageStreaming handles cancellation")
  func sendMessageStreamingHandlesCancellation() async {
    let service = MockAISkillInvocationService()
    await service.setCancellation(true)

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await service.sendMessageStreaming(
        messages: [],
        context: context
      ) { _ in }
      Issue.record("Expected cancellation")
    } catch let error as InvocationError {
      #expect(error == .cancelled)
    } catch {
      Issue.record("Wrong error type")
    }
  }
}

// Helper extensions for MockAISkillInvocationService.
extension MockAISkillInvocationService {
  func setToolDeclarations(_ declarations: [GeminiFunctionDeclaration]) {
    self.toolDeclarations = declarations
  }

  func setResponse(_ response: AISkillResponse) {
    self.responseToReturn = response
  }

  func setError(_ error: InvocationError?) {
    self.errorToThrow = error
  }

  func setStreamingChunks(_ chunks: [SkillResultChunk]) {
    self.streamingChunks = chunks
  }

  func setStreamingFinalResponse(_ response: AISkillResponse) {
    self.streamingFinalResponse = response
  }

  func setStreamingError(_ error: InvocationError?) {
    self.streamingError = error
  }

  func setCancellation(_ value: Bool) {
    self.shouldSimulateCancellation = value
  }
}

// MARK: - SkillCloudClientProtocol Acceptance Tests

@Suite("SkillCloudClientProtocol Acceptance Tests")
struct SkillCloudClientProtocolAcceptanceTests {

  // SCENARIO: Execute cloud skill successfully.
  @Test("execute cloud skill successfully")
  func executeCloudSkillSuccessfully() async throws {
    let client = MockSkillCloudClient()
    await client.setResult(.success(text: "Quiz generated"))

    let context = SkillContext(
      currentNotebookID: "nb-123",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
    let params: [String: SkillParameterValue] = [
      "topic": .string("history"),
      "questionCount": .number(10),
    ]

    let result = try await client.executeSkill(
      skillID: "generate-quiz",
      parameters: params,
      context: context
    )

    #expect(result.success == true)
    #expect(result.data == .text("Quiz generated"))
  }

  // SCENARIO: Execute cloud skill with network offline.
  @Test("execute cloud skill with network offline throws networkError")
  func executeCloudSkillOfflineThrows() async {
    let client = MockSkillCloudClient()
    await client.setError(.networkError(reason: "No connectivity"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await client.executeSkill(
        skillID: "cloud-skill",
        parameters: [:],
        context: context
      )
      Issue.record("Expected networkError")
    } catch let error as InvocationError {
      if case .networkError(let reason) = error {
        #expect(reason.contains("connectivity") || reason.contains("No"))
      } else {
        Issue.record("Expected networkError case")
      }
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // SCENARIO: Execute cloud skill with server error.
  @Test("execute cloud skill with server error throws skillExecutionFailed")
  func executeCloudSkillServerErrorThrows() async {
    let client = MockSkillCloudClient()
    await client.setError(.skillExecutionFailed(skillID: "generate-quiz", reason: "500 Internal Server Error"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await client.executeSkill(
        skillID: "generate-quiz",
        parameters: [:],
        context: context
      )
      Issue.record("Expected skillExecutionFailed")
    } catch let error as InvocationError {
      if case .skillExecutionFailed(let skillID, let reason) = error {
        #expect(skillID == "generate-quiz")
        #expect(reason.contains("500"))
      } else {
        Issue.record("Expected skillExecutionFailed case")
      }
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // SCENARIO: Execute cloud skill with invalid response.
  @Test("execute cloud skill with invalid response throws invalidResponse")
  func executeCloudSkillInvalidResponseThrows() async {
    let client = MockSkillCloudClient()
    await client.setError(.invalidResponse(reason: "JSON parse error: unexpected token"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await client.executeSkill(
        skillID: "test",
        parameters: [:],
        context: context
      )
      Issue.record("Expected invalidResponse")
    } catch let error as InvocationError {
      if case .invalidResponse(let reason) = error {
        #expect(reason.contains("parse") || reason.contains("JSON"))
      } else {
        Issue.record("Expected invalidResponse case")
      }
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // SCENARIO: Execute streaming cloud skill.
  @Test("execute streaming cloud skill emits chunks and returns final result")
  func executeStreamingCloudSkill() async throws {
    let client = MockSkillCloudClient()
    await client.setStreamingChunks([
      SkillResultChunk(text: "Generating", isComplete: false),
      SkillResultChunk(text: " quiz...", isComplete: false),
      SkillResultChunk(text: " Done!", isComplete: true),
    ])
    await client.setStreamingFinalResult(.success(text: "Quiz complete"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    var chunks: [SkillResultChunk] = []
    let result = try await client.executeSkillStreaming(
      skillID: "streaming-quiz",
      parameters: [:],
      context: context
    ) { chunk in
      chunks.append(chunk)
    }

    #expect(chunks.count == 3)
    #expect(chunks.last?.isComplete == true)
    #expect(result.success == true)
  }

  // SCENARIO: Streaming interrupted mid-execution.
  @Test("streaming interrupted throws streamingFailed")
  func streamingInterruptedThrows() async {
    let client = MockSkillCloudClient()
    await client.setStreamingChunks([
      SkillResultChunk(text: "Starting...", isComplete: false)
    ])
    await client.setStreamingError(.streamingFailed(reason: "Connection dropped"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    var receivedChunks: [SkillResultChunk] = []
    do {
      _ = try await client.executeSkillStreaming(
        skillID: "test",
        parameters: [:],
        context: context
      ) { chunk in
        receivedChunks.append(chunk)
      }
      Issue.record("Expected streamingFailed")
    } catch let error as InvocationError {
      #expect(error == .streamingFailed(reason: "Connection dropped"))
      // Partial chunks may have been received before failure.
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // SCENARIO: Cancel streaming execution.
  @Test("cancel streaming execution throws cancelled")
  func cancelStreamingExecutionThrows() async {
    let client = MockSkillCloudClient()
    await client.setCancellation(true)

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await client.executeSkillStreaming(
        skillID: "test",
        parameters: [:],
        context: context
      ) { _ in }
      Issue.record("Expected cancelled error")
    } catch let error as InvocationError {
      #expect(error == .cancelled)
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // EDGE CASE: Empty parameters.
  @Test("execute cloud skill with empty parameters succeeds")
  func executeCloudSkillEmptyParams() async throws {
    let client = MockSkillCloudClient()
    await client.setResult(.success(text: "No params needed"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    let result = try await client.executeSkill(
      skillID: "no-params-skill",
      parameters: [:],
      context: context
    )

    #expect(result.success == true)
  }

  // EDGE CASE: Context with nil notebook ID.
  @Test("execute cloud skill with nil notebook ID succeeds")
  func executeCloudSkillNilNotebook() async throws {
    let client = MockSkillCloudClient()

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    let result = try await client.executeSkill(
      skillID: "test",
      parameters: [:],
      context: context
    )

    let lastCtx = await client.lastContext
    #expect(lastCtx?.currentNotebookID == nil)
    #expect(result.success == true)
  }
}

// MARK: - AISkillInvocationServiceProtocol Acceptance Tests

@Suite("AISkillInvocationServiceProtocol Acceptance Tests")
struct AISkillInvocationServiceProtocolAcceptanceTests {

  // SCENARIO: Get tool declarations.
  @Test("getToolDeclarations returns declarations for registered skills")
  func getToolDeclarationsReturnsDecs() async {
    let service = MockAISkillInvocationService()
    let declarations = [
      GeminiFunctionDeclaration(
        name: "summarize",
        description: "Summarizes text",
        parameters: GeminiFunctionParameters(
          type: "object",
          properties: [
            "text": GeminiPropertySchema(type: "string", description: "Text to summarize")
          ],
          required: ["text"]
        )
      ),
      GeminiFunctionDeclaration(
        name: "create-lesson",
        description: "Creates a lesson",
        parameters: GeminiFunctionParameters(
          type: "object",
          properties: [:],
          required: []
        )
      ),
    ]
    await service.setToolDeclarations(declarations)

    let result = await service.getToolDeclarations()

    #expect(result.count == 2)
    #expect(result[0].name == "summarize")
    #expect(result[1].name == "create-lesson")
  }

  // SCENARIO: Send message with text response.
  @Test("sendMessage with text response returns text")
  func sendMessageTextResponse() async throws {
    let service = MockAISkillInvocationService()
    await service.setResponse(.text("The answer is 4"))

    let messages = [
      ConversationMessage(role: .user, content: "What is 2+2?")
    ]
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: "What is 2+2?",
      conversationHistory: nil
    )

    let response = try await service.sendMessage(messages: messages, context: context)

    if case .text(let content) = response {
      #expect(content == "The answer is 4")
    } else {
      Issue.record("Expected text response")
    }
  }

  // SCENARIO: Send message triggering skill invocation.
  @Test("sendMessage triggering skill returns skillInvocation")
  func sendMessageSkillInvocation() async throws {
    let service = MockAISkillInvocationService()
    let skillResult = SkillResult.success(text: "Here is your summary...")
    await service.setResponse(.skillInvocation(skillID: "summarize", result: skillResult))

    let messages = [
      ConversationMessage(role: .user, content: "Summarize my notes")
    ]
    let context = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: "Summarize my notes",
      conversationHistory: nil
    )

    let response = try await service.sendMessage(messages: messages, context: context)

    if case .skillInvocation(let skillID, let result) = response {
      #expect(skillID == "summarize")
      #expect(result.success == true)
    } else {
      Issue.record("Expected skillInvocation response")
    }
  }

  // SCENARIO: Send message with conversation history.
  @Test("sendMessage with conversation history passes full context")
  func sendMessageWithHistory() async throws {
    let service = MockAISkillInvocationService()

    let history = [
      ConversationMessage(role: .user, content: "My topic is math"),
      ConversationMessage(role: .assistant, content: "Great, I can help with math"),
    ]
    let messages = history + [ConversationMessage(role: .user, content: "What is algebra?")]
    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: "What is algebra?",
      conversationHistory: history
    )

    _ = try await service.sendMessage(messages: messages, context: context)

    let lastMsgs = await service.lastMessages
    let lastCtx = await service.lastContext

    #expect(lastMsgs?.count == 3)
    #expect(lastCtx?.conversationHistory?.count == 2)
  }

  // SCENARIO: Send message when AI calls non-existent skill.
  @Test("sendMessage with non-existent skill returns error")
  func sendMessageNonExistentSkill() async {
    let service = MockAISkillInvocationService()
    await service.setError(.skillExecutionFailed(skillID: "non-existent-skill", reason: "Skill not found"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await service.sendMessage(messages: [], context: context)
      Issue.record("Expected error")
    } catch let error as InvocationError {
      if case .skillExecutionFailed(let skillID, let reason) = error {
        #expect(skillID == "non-existent-skill")
        #expect(reason.contains("not found"))
      } else {
        Issue.record("Expected skillExecutionFailed")
      }
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // SCENARIO: Send message with skill that fails.
  @Test("sendMessage with failing skill returns error in result")
  func sendMessageFailingSkill() async throws {
    let service = MockAISkillInvocationService()
    let failedResult = SkillResult.failure(
      error: .executionFailed(reason: "API rate limit exceeded"),
      message: "Summarization failed"
    )
    await service.setResponse(.skillInvocation(skillID: "summarize", result: failedResult))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    let response = try await service.sendMessage(messages: [], context: context)

    if case .skillInvocation(let skillID, let result) = response {
      #expect(skillID == "summarize")
      #expect(result.success == false)
      #expect(result.error == .executionFailed(reason: "API rate limit exceeded"))
    } else {
      Issue.record("Expected skillInvocation response")
    }
  }

  // SCENARIO: Streaming message with text response.
  @Test("sendMessageStreaming with text emits chunks")
  func sendMessageStreamingText() async throws {
    let service = MockAISkillInvocationService()
    await service.setStreamingChunks([
      SkillResultChunk(text: "The ", isComplete: false),
      SkillResultChunk(text: "answer ", isComplete: false),
      SkillResultChunk(text: "is 4", isComplete: true),
    ])
    await service.setStreamingFinalResponse(.text("The answer is 4"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    var chunks: [SkillResultChunk] = []
    let response = try await service.sendMessageStreaming(
      messages: [],
      context: context
    ) { chunk in
      chunks.append(chunk)
    }

    #expect(chunks.count == 3)
    if case .text(let content) = response {
      #expect(content == "The answer is 4")
    } else {
      Issue.record("Expected text response")
    }
  }

  // SCENARIO: Streaming message triggering skill.
  @Test("sendMessageStreaming triggering skill returns skillInvocation")
  func sendMessageStreamingSkill() async throws {
    let service = MockAISkillInvocationService()
    let skillResult = SkillResult.success(text: "Summarized")
    await service.setStreamingFinalResponse(.skillInvocation(skillID: "summarize", result: skillResult))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    let response = try await service.sendMessageStreaming(
      messages: [],
      context: context
    ) { _ in }

    if case .skillInvocation(let skillID, let result) = response {
      #expect(skillID == "summarize")
      #expect(result.success == true)
    } else {
      Issue.record("Expected skillInvocation response")
    }
  }

  // SCENARIO: Cancel streaming message.
  @Test("cancel sendMessageStreaming throws cancelled")
  func cancelSendMessageStreaming() async {
    let service = MockAISkillInvocationService()
    await service.setCancellation(true)

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await service.sendMessageStreaming(
        messages: [],
        context: context
      ) { _ in }
      Issue.record("Expected cancelled")
    } catch let error as InvocationError {
      #expect(error == .cancelled)
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // EDGE CASE: Empty messages array.
  @Test("sendMessage with empty messages succeeds")
  func sendMessageEmptyMessages() async throws {
    let service = MockAISkillInvocationService()

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    let response = try await service.sendMessage(messages: [], context: context)

    // Empty messages should still work, AI may give generic response.
    if case .text = response {
      // Expected.
    } else {
      // Other responses also valid.
    }

    let lastMsgs = await service.lastMessages
    #expect(lastMsgs?.isEmpty == true)
  }

  // EDGE CASE: Network failure during AI request.
  @Test("sendMessage with network failure throws networkError")
  func sendMessageNetworkFailure() async {
    let service = MockAISkillInvocationService()
    await service.setError(.networkError(reason: "Unable to connect to Gemini API"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await service.sendMessage(messages: [], context: context)
      Issue.record("Expected networkError")
    } catch let error as InvocationError {
      if case .networkError(let reason) = error {
        #expect(reason.contains("Gemini") || reason.contains("connect"))
      } else {
        Issue.record("Expected networkError case")
      }
    } catch {
      Issue.record("Wrong error type")
    }
  }

  // EDGE CASE: AI response timeout.
  @Test("sendMessage with timeout throws timeout error")
  func sendMessageTimeout() async {
    let service = MockAISkillInvocationService()
    await service.setError(.timeout)

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    do {
      _ = try await service.sendMessage(messages: [], context: context)
      Issue.record("Expected timeout")
    } catch let error as InvocationError {
      #expect(error == .timeout)
    } catch {
      Issue.record("Wrong error type")
    }
  }
}

// MARK: - Edge Cases & Error Conditions Tests

@Suite("Invocation Edge Cases Tests")
struct InvocationEdgeCasesTests {

  // EDGE CASE: Concurrent cloud skill executions.
  @Test("concurrent cloud skill executions are independent")
  func concurrentExecutionsIndependent() async throws {
    let client = MockSkillCloudClient()

    let context1 = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )
    let context2 = SkillContext(
      currentNotebookID: "nb-2",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    // Execute two skills concurrently.
    async let result1 = client.executeSkill(
      skillID: "skill-1",
      parameters: ["id": .string("1")],
      context: context1
    )
    async let result2 = client.executeSkill(
      skillID: "skill-2",
      parameters: ["id": .string("2")],
      context: context2
    )

    let (r1, r2) = try await (result1, result2)

    #expect(r1.success == true)
    #expect(r2.success == true)

    let callCount = await client.executeSkillCallCount
    #expect(callCount == 2)
  }

  // EDGE CASE: Large parameter values.
  @Test("large parameter values are passed correctly")
  func largeParameterValues() async throws {
    let client = MockSkillCloudClient()

    // Create a large string (100KB).
    let largeText = String(repeating: "a", count: 100_000)
    let params: [String: SkillParameterValue] = ["text": .string(largeText)]

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    _ = try await client.executeSkill(
      skillID: "process-large",
      parameters: params,
      context: context
    )

    let lastParams = await client.lastParameters
    if case .string(let value) = lastParams?["text"] {
      #expect(value.count == 100_000)
    } else {
      Issue.record("Expected string parameter")
    }
  }

  // EDGE CASE: Unicode and special characters in parameters.
  @Test("unicode and special characters are preserved")
  func unicodeCharactersPreserved() async throws {
    let client = MockSkillCloudClient()

    // Parameters with emojis, CJK, and RTL text.
    let params: [String: SkillParameterValue] = [
      "emoji": .string("Hello 👋 World 🌍"),
      "cjk": .string("你好世界"),
      "rtl": .string("مرحبا بالعالم"),
    ]

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    _ = try await client.executeSkill(
      skillID: "unicode-test",
      parameters: params,
      context: context
    )

    let lastParams = await client.lastParameters
    #expect(lastParams?["emoji"] == .string("Hello 👋 World 🌍"))
    #expect(lastParams?["cjk"] == .string("你好世界"))
    #expect(lastParams?["rtl"] == .string("مرحبا بالعالم"))
  }

  // EDGE CASE: Very deep nested parameters.
  @Test("deeply nested parameters are preserved")
  func deeplyNestedParameters() async throws {
    let client = MockSkillCloudClient()

    // Create deeply nested structure.
    let nested = SkillParameterValue.object([
      "level1": .object([
        "level2": .object([
          "level3": .object([
            "level4": .string("deep value")
          ])
        ])
      ])
    ])
    let params: [String: SkillParameterValue] = ["nested": nested]

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    _ = try await client.executeSkill(
      skillID: "nested-test",
      parameters: params,
      context: context
    )

    let lastParams = await client.lastParameters
    if case .object(let l1) = lastParams?["nested"],
      case .object(let l2) = l1["level1"],
      case .object(let l3) = l2["level2"],
      case .object(let l4) = l3["level3"],
      case .string(let value) = l4["level4"]
    {
      #expect(value == "deep value")
    } else {
      Issue.record("Nested structure not preserved")
    }
  }

  // EDGE CASE: Rapid consecutive messages.
  @Test("rapid consecutive messages are handled")
  func rapidConsecutiveMessages() async throws {
    let service = MockAISkillInvocationService()

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    // Send multiple messages rapidly.
    var results: [AISkillResponse] = []
    for i in 0..<5 {
      let messages = [ConversationMessage(role: .user, content: "Message \(i)")]
      let response = try await service.sendMessage(messages: messages, context: context)
      results.append(response)
    }

    #expect(results.count == 5)

    let callCount = await service.sendMessageCallCount
    #expect(callCount == 5)
  }

  // EDGE CASE: Simultaneous sendMessage and sendMessageStreaming.
  @Test("simultaneous sendMessage and sendMessageStreaming operate independently")
  func simultaneousMessageCalls() async throws {
    let service = MockAISkillInvocationService()
    await service.setResponse(.text("Non-streaming response"))
    await service.setStreamingFinalResponse(.text("Streaming response"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    // Execute both concurrently.
    async let normalResponse = service.sendMessage(messages: [], context: context)
    async let streamingResponse = service.sendMessageStreaming(
      messages: [],
      context: context
    ) { _ in }

    let (r1, r2) = try await (normalResponse, streamingResponse)

    // Both should complete independently.
    if case .text(let content1) = r1,
      case .text(let content2) = r2
    {
      #expect(content1 == "Non-streaming response")
      #expect(content2 == "Streaming response")
    } else {
      Issue.record("Expected text responses")
    }
  }

  // EDGE CASE: Empty function call arguments.
  @Test("function call with empty arguments is valid")
  func emptyFunctionCallArguments() {
    let call = GeminiFunctionCall(name: "get-time", arguments: [:])

    #expect(call.name == "get-time")
    #expect(call.arguments.isEmpty)
  }

  // EDGE CASE: Function call with type mismatch (string instead of number).
  @Test("function call with type mismatch preserves value as-is")
  func functionCallTypeMismatch() {
    // AI sends string "5" instead of number 5.
    let call = GeminiFunctionCall(
      name: "calculate",
      arguments: ["count": .string("5")]  // Should be number.
    )

    // The call struct preserves the value as-is.
    // Type validation happens in skill execution layer.
    #expect(call.arguments["count"] == .string("5"))
  }
}

// MARK: - Integration Scenario Tests

@Suite("Invocation Integration Scenarios")
struct InvocationIntegrationTests {

  @Test("full cloud skill execution workflow")
  func fullCloudSkillWorkflow() async throws {
    // Setup mock client.
    let client = MockSkillCloudClient()
    await client.setResult(.success(text: "Generated quiz with 10 questions"))

    // Create context with notebook open.
    let context = SkillContext(
      currentNotebookID: "notebook-abc",
      currentPDFID: nil,
      userMessage: "Create a quiz about history",
      conversationHistory: [
        ConversationMessage(role: .user, content: "I want to study history")
      ]
    )

    // Execute skill with parameters.
    let params: [String: SkillParameterValue] = [
      "topic": .string("history"),
      "questionCount": .number(10),
      "difficulty": .string("medium"),
    ]

    let result = try await client.executeSkill(
      skillID: "generate-quiz",
      parameters: params,
      context: context
    )

    // Verify result.
    #expect(result.success == true)
    #expect(result.data == .text("Generated quiz with 10 questions"))

    // Verify invocation tracking.
    let lastSkillID = await client.lastSkillID
    let lastParams = await client.lastParameters
    let lastCtx = await client.lastContext

    #expect(lastSkillID == "generate-quiz")
    #expect(lastParams?["topic"] == .string("history"))
    #expect(lastCtx?.currentNotebookID == "notebook-abc")
  }

  @Test("full AI message workflow with skill invocation")
  func fullAIMessageWorkflowWithSkill() async throws {
    // Setup mock service.
    let service = MockAISkillInvocationService()
    let skillResult = SkillResult.success(text: "Here is your summary of the notes...")
    await service.setResponse(.skillInvocation(skillID: "summarize", result: skillResult))

    // Create context.
    let history = [
      ConversationMessage(role: .user, content: "I have some notes"),
      ConversationMessage(role: .assistant, content: "I can help with your notes"),
    ]
    let context = SkillContext(
      currentNotebookID: "nb-123",
      currentPDFID: nil,
      userMessage: "Please summarize my notes",
      conversationHistory: history
    )

    // Send message.
    let messages = history + [ConversationMessage(role: .user, content: "Please summarize my notes")]
    let response = try await service.sendMessage(messages: messages, context: context)

    // Verify response.
    if case .skillInvocation(let skillID, let result) = response {
      #expect(skillID == "summarize")
      #expect(result.success == true)
      #expect(result.data == .text("Here is your summary of the notes..."))
    } else {
      Issue.record("Expected skillInvocation response")
    }
  }

  @Test("full streaming workflow with chunks")
  func fullStreamingWorkflow() async throws {
    // Setup mock client.
    let client = MockSkillCloudClient()
    await client.setStreamingChunks([
      SkillResultChunk(text: "Analyzing ", isComplete: false),
      SkillResultChunk(text: "your notes... ", isComplete: false),
      SkillResultChunk(text: "Creating summary... ", isComplete: false),
      SkillResultChunk(text: "Done!", isComplete: true),
    ])
    await client.setStreamingFinalResult(.success(text: "Complete summary of your notes."))

    let context = SkillContext(
      currentNotebookID: "nb-1",
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    // Track chunks as they arrive.
    var receivedChunks: [SkillResultChunk] = []
    var accumulatedText = ""

    let result = try await client.executeSkillStreaming(
      skillID: "summarize-streaming",
      parameters: ["text": .string("My notes content")],
      context: context
    ) { chunk in
      receivedChunks.append(chunk)
      accumulatedText += chunk.text
    }

    // Verify streaming behavior.
    #expect(receivedChunks.count == 4)
    #expect(accumulatedText == "Analyzing your notes... Creating summary... Done!")
    #expect(receivedChunks.last?.isComplete == true)

    // Verify final result.
    #expect(result.success == true)
    #expect(result.data == .text("Complete summary of your notes."))
  }

  @Test("error recovery workflow")
  func errorRecoveryWorkflow() async {
    // Setup mock service that fails.
    let service = MockAISkillInvocationService()
    await service.setError(.networkError(reason: "Connection reset"))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    // First attempt fails.
    var firstAttemptFailed = false
    do {
      _ = try await service.sendMessage(messages: [], context: context)
    } catch let error as InvocationError {
      if case .networkError = error {
        firstAttemptFailed = true
      }
    } catch {}

    #expect(firstAttemptFailed == true)

    // Clear error for retry.
    await service.setError(nil)
    await service.setResponse(.text("Success after retry"))

    // Second attempt succeeds.
    let response = try? await service.sendMessage(messages: [], context: context)

    if case .text(let content) = response {
      #expect(content == "Success after retry")
    } else {
      Issue.record("Expected successful text response after retry")
    }
  }

  @Test("pending skill call workflow")
  func pendingSkillCallWorkflow() async throws {
    // Setup mock service to return pending skill call.
    let service = MockAISkillInvocationService()
    await service.setResponse(.pendingSkillCall(
      skillID: "custom-skill",
      parameters: [
        "option": .string("value"),
        "enabled": .boolean(true),
      ]
    ))

    let context = SkillContext(
      currentNotebookID: nil,
      currentPDFID: nil,
      userMessage: nil,
      conversationHistory: nil
    )

    // Get pending skill call.
    let response = try await service.sendMessage(messages: [], context: context)

    // Verify pending call details.
    if case .pendingSkillCall(let skillID, let params) = response {
      #expect(skillID == "custom-skill")
      #expect(params["option"] == .string("value"))
      #expect(params["enabled"] == .boolean(true))

      // Caller can now execute this skill manually.
      // This enables multi-turn scenarios where caller handles execution.
    } else {
      Issue.record("Expected pendingSkillCall response")
    }
  }
}
