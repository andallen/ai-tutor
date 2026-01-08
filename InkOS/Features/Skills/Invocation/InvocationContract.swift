// InvocationContract.swift
// Defines the API contract for the Skills Invocation layer.
// This layer integrates Gemini AI function calling with the Skills system.
// Handles cloud skill execution via Firebase and AI-orchestrated skill invocation.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation

// MARK: - API Contract

// MARK: - InvocationError Enum

// Errors specific to the invocation layer.
// Distinct from SkillError to separate invocation concerns from skill concerns.
enum InvocationError: Error, LocalizedError, Equatable, Sendable {
  // Network request failed.
  case networkError(reason: String)

  // Response from cloud or AI was malformed or unexpected.
  case invalidResponse(reason: String)

  // A skill execution initiated via invocation failed.
  case skillExecutionFailed(skillID: String, reason: String)

  // Streaming operation failed.
  case streamingFailed(reason: String)

  // Operation timed out waiting for response.
  case timeout

  // Operation was cancelled by caller.
  case cancelled

  var errorDescription: String? {
    switch self {
    case .networkError(let reason):
      return "Network error: \(reason)"
    case .invalidResponse(let reason):
      return "Invalid response: \(reason)"
    case .skillExecutionFailed(let skillID, let reason):
      return "Skill '\(skillID)' execution failed: \(reason)"
    case .streamingFailed(let reason):
      return "Streaming failed: \(reason)"
    case .timeout:
      return "Operation timed out"
    case .cancelled:
      return "Operation was cancelled"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: InvocationError

 SCENARIO: Network error thrown
 GIVEN: A cloud skill execution or AI request
 WHEN: Network request fails (offline, DNS failure, connection refused)
 THEN: InvocationError.networkError is thrown
  AND: reason contains specific failure information

 SCENARIO: Invalid response from cloud
 GIVEN: A request to Firebase cloud function
 WHEN: Response JSON cannot be parsed
 THEN: InvocationError.invalidResponse is thrown
  AND: reason describes parsing failure

 SCENARIO: Skill execution failed via invocation
 GIVEN: AI invokes a skill via function calling
 WHEN: The skill throws during execution
 THEN: InvocationError.skillExecutionFailed is thrown
  AND: skillID identifies which skill failed
  AND: reason contains the underlying error

 SCENARIO: Streaming failure
 GIVEN: A streaming AI response
 WHEN: Stream is interrupted mid-response
 THEN: InvocationError.streamingFailed is thrown
  AND: reason describes the streaming failure

 SCENARIO: Timeout error
 GIVEN: A cloud or AI request in progress
 WHEN: Response not received within timeout period
 THEN: InvocationError.timeout is thrown
  AND: Partial data is not returned

 SCENARIO: Cancelled error
 GIVEN: A cloud or AI request in progress
 WHEN: Caller cancels the operation
 THEN: InvocationError.cancelled is thrown
  AND: Resources are cleaned up

 EDGE CASE: Network error vs timeout distinction
 GIVEN: A slow network connection
 WHEN: Connection eventually fails
 THEN: Error distinguishes between timeout (deadline exceeded) and networkError (connection dropped)
*/

// MARK: - FirebaseConfiguration Struct

// Configuration for connecting to Firebase services.
// Used by SkillCloudClient to authenticate and route requests.
struct FirebaseConfiguration: Sendable, Equatable {
  // The Firebase project identifier.
  let projectID: String

  // The cloud functions region (e.g., "us-central1").
  let region: String

  // Optional API key for additional authentication.
  // Some endpoints may require this beyond default Firebase auth.
  let apiKey: String?
}

/*
 ACCEPTANCE CRITERIA: FirebaseConfiguration

 SCENARIO: Create configuration with required fields
 GIVEN: A Firebase project "my-project" in region "us-central1"
 WHEN: FirebaseConfiguration is created
 THEN: projectID is "my-project"
  AND: region is "us-central1"
  AND: apiKey is nil

 SCENARIO: Create configuration with API key
 GIVEN: A Firebase project requiring API key authentication
 WHEN: FirebaseConfiguration is created with apiKey
 THEN: apiKey contains the key value
  AND: Client uses key in requests

 SCENARIO: Configuration is Sendable
 GIVEN: A FirebaseConfiguration instance
 WHEN: Passed across actor boundaries
 THEN: Compiles without warning
  AND: No data races possible

 EDGE CASE: Empty project ID
 GIVEN: An empty string for projectID
 WHEN: Client attempts to use configuration
 THEN: Request fails with invalid URL
  AND: Clear error message about configuration
*/

// MARK: - SkillResultChunk Struct

// Represents a partial result during streaming skill execution.
// Used by streaming callbacks to deliver incremental updates.
struct SkillResultChunk: Sendable, Equatable {
  // The partial text content of this chunk.
  let text: String

  // Whether this is the final chunk in the stream.
  let isComplete: Bool
}

/*
 ACCEPTANCE CRITERIA: SkillResultChunk

 SCENARIO: Intermediate chunk
 GIVEN: A streaming skill producing partial results
 WHEN: Chunk is emitted mid-stream
 THEN: text contains partial content
  AND: isComplete is false

 SCENARIO: Final chunk
 GIVEN: A streaming skill completing execution
 WHEN: Final chunk is emitted
 THEN: text may contain final content (or empty)
  AND: isComplete is true

 SCENARIO: Empty intermediate chunk
 GIVEN: A streaming skill with no new content
 WHEN: Heartbeat or progress chunk is emitted
 THEN: text is empty string
  AND: isComplete is false
  AND: Keeps stream alive

 SCENARIO: Chunk equality
 GIVEN: Two SkillResultChunk instances
 WHEN: Compared for equality
 THEN: Both text and isComplete are compared
*/

// MARK: - GeminiFunctionCall Struct

// Represents a function call request from Gemini AI.
// Parsed from Gemini API response when AI decides to invoke a skill.
struct GeminiFunctionCall: Sendable, Equatable {
  // The name of the function to call (maps to skill ID).
  let name: String

  // The arguments to pass to the function (skill parameters).
  let arguments: [String: SkillParameterValue]
}

/*
 ACCEPTANCE CRITERIA: GeminiFunctionCall

 SCENARIO: Parse simple function call
 GIVEN: Gemini response with functionCall for skill "summarize"
  AND: Arguments {"text": "content to summarize"}
 WHEN: GeminiFunctionCall is created
 THEN: name is "summarize"
  AND: arguments["text"] is .string("content to summarize")

 SCENARIO: Parse function call with multiple arguments
 GIVEN: Gemini response for skill "create-lesson"
  AND: Arguments {"topic": "math", "difficulty": "medium", "includeExercises": true}
 WHEN: GeminiFunctionCall is created
 THEN: name is "create-lesson"
  AND: arguments contains all three parameters with correct types

 SCENARIO: Parse function call with nested arguments
 GIVEN: Gemini response with nested object argument
  AND: Arguments {"options": {"format": "markdown", "verbose": true}}
 WHEN: GeminiFunctionCall is created
 THEN: arguments["options"] is .object with nested values

 SCENARIO: Parse function call with array arguments
 GIVEN: Gemini response with array argument
  AND: Arguments {"topics": ["algebra", "geometry", "calculus"]}
 WHEN: GeminiFunctionCall is created
 THEN: arguments["topics"] is .array with string elements

 SCENARIO: Parse function call with no arguments
 GIVEN: Gemini response for parameterless skill
  AND: Arguments {}
 WHEN: GeminiFunctionCall is created
 THEN: name is set
  AND: arguments is empty dictionary

 EDGE CASE: Function call with unknown argument types
 GIVEN: Gemini response with unexpected data format
 WHEN: Parsing to GeminiFunctionCall
 THEN: Parser handles gracefully or throws invalidResponse
*/

// MARK: - AISkillResponse Enum

// Represents the response from AI that may be text or a skill invocation.
// Allows the caller to handle both cases appropriately.
enum AISkillResponse: Sendable, Equatable {
  // Regular text response from the AI.
  case text(String)

  // AI invoked a skill and execution completed.
  // Contains the skill ID and the result of execution.
  case skillInvocation(skillID: String, result: SkillResult)

  // AI requested a skill call but execution is pending.
  // Used for multi-turn scenarios where caller handles execution.
  case pendingSkillCall(skillID: String, parameters: [String: SkillParameterValue])
}

/*
 ACCEPTANCE CRITERIA: AISkillResponse

 SCENARIO: Text response from AI
 GIVEN: User asks a general question
 WHEN: AI responds with text only (no function call)
 THEN: AISkillResponse.text contains the response
  AND: No skill was invoked

 SCENARIO: Skill invocation response
 GIVEN: User asks to summarize their notes
 WHEN: AI invokes summarize skill and it completes
 THEN: AISkillResponse.skillInvocation is returned
  AND: skillID is "summarize"
  AND: result contains the skill output

 SCENARIO: Pending skill call response
 GIVEN: AI decides to call a skill
 WHEN: Caller wants to handle execution separately
 THEN: AISkillResponse.pendingSkillCall is returned
  AND: skillID identifies the requested skill
  AND: parameters contains parsed arguments

 SCENARIO: Skill invocation with error result
 GIVEN: AI invokes a skill that fails
 WHEN: Skill returns error in result
 THEN: AISkillResponse.skillInvocation is returned
  AND: result.success is false
  AND: result.error contains failure information

 SCENARIO: Equatable comparison
 GIVEN: Two AISkillResponse values
 WHEN: Compared for equality
 THEN: Same case with same values returns true
  AND: Different cases return false

 EDGE CASE: Empty text response
 GIVEN: AI returns empty string
 WHEN: Response is processed
 THEN: AISkillResponse.text("") is returned
  AND: Caller handles empty case
*/

// MARK: - SkillCloudClientProtocol

// Actor protocol for executing skills via Firebase Cloud Functions.
// Handles cloud and hybrid skill execution over the network.
protocol SkillCloudClientProtocol: Actor {
  // Executes a skill on cloud infrastructure.
  // skillID: The identifier of the skill to execute.
  // parameters: Parameter values for the skill.
  // context: Execution context with current state.
  // Returns: SkillResult from cloud execution.
  // Throws: InvocationError for network or execution failures.
  func executeSkill(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult

  // Executes a skill with streaming response from cloud.
  // skillID: The identifier of the skill to execute.
  // parameters: Parameter values for the skill.
  // context: Execution context with current state.
  // onChunk: Callback invoked for each partial result chunk.
  // Returns: Final SkillResult after streaming completes.
  // Throws: InvocationError for network or streaming failures.
  func executeSkillStreaming(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext,
    onChunk: @escaping @Sendable (SkillResultChunk) -> Void
  ) async throws -> SkillResult
}

/*
 ACCEPTANCE CRITERIA: SkillCloudClientProtocol

 SCENARIO: Execute cloud skill successfully
 GIVEN: A registered cloud skill "generate-quiz"
  AND: Valid parameters and context
  AND: Network is available
 WHEN: executeSkill(skillID:parameters:context:) is called
 THEN: Request is sent to Firebase cloud function
  AND: Response is parsed to SkillResult
  AND: SkillResult.success is true

 SCENARIO: Execute cloud skill with network offline
 GIVEN: A cloud skill to execute
  AND: Device is offline
 WHEN: executeSkill is called
 THEN: InvocationError.networkError is thrown
  AND: reason indicates no connectivity
  AND: No partial result is returned

 SCENARIO: Execute cloud skill with server error
 GIVEN: A cloud skill to execute
  AND: Cloud function returns 500 error
 WHEN: executeSkill is called
 THEN: InvocationError.skillExecutionFailed is thrown
  AND: reason contains server error details

 SCENARIO: Execute cloud skill with invalid response
 GIVEN: A cloud skill to execute
  AND: Cloud function returns malformed JSON
 WHEN: executeSkill is called
 THEN: InvocationError.invalidResponse is thrown
  AND: reason describes parse failure

 SCENARIO: Execute streaming cloud skill
 GIVEN: A cloud skill that streams results
  AND: Valid parameters and context
 WHEN: executeSkillStreaming is called
 THEN: onChunk is called for each partial result
  AND: Final SkillResult is returned after completion
  AND: isComplete is true on final chunk

 SCENARIO: Streaming interrupted mid-execution
 GIVEN: A streaming cloud skill in progress
 WHEN: Connection is dropped
 THEN: InvocationError.streamingFailed is thrown
  AND: onChunk received partial results before failure
  AND: Final result is not returned

 SCENARIO: Cancel streaming execution
 GIVEN: A streaming cloud skill in progress
 WHEN: Task is cancelled
 THEN: InvocationError.cancelled is thrown
  AND: Stream is terminated
  AND: Network resources are released

 EDGE CASE: Empty parameters
 GIVEN: A cloud skill with no required parameters
 WHEN: executeSkill is called with empty parameters
 THEN: Request is sent with empty parameters object
  AND: Skill executes successfully

 EDGE CASE: Large parameter values
 GIVEN: A cloud skill with large text parameter (100KB)
 WHEN: executeSkill is called
 THEN: Request includes full parameter value
  AND: Cloud function handles or rejects based on its limits

 EDGE CASE: Context with nil notebook ID
 GIVEN: No notebook is currently open
 WHEN: executeSkill is called
 THEN: Context is serialized with null notebook ID
  AND: Cloud function handles missing context

 EDGE CASE: Timeout during cloud execution
 GIVEN: A cloud skill that takes too long
 WHEN: Timeout period is exceeded
 THEN: InvocationError.timeout is thrown
  AND: Request is cancelled on client side
*/

// MARK: - AISkillInvocationServiceProtocol

// Actor protocol for orchestrating AI chat with Gemini function calling.
// Manages the conversation flow and skill execution when AI requests it.
protocol AISkillInvocationServiceProtocol: Actor {
  // Returns Gemini-compatible function declarations for registered skills.
  // Used to inform Gemini what functions/skills are available to call.
  // Returns: Array of GeminiFunctionDeclaration for all registered skills.
  func getToolDeclarations() async -> [GeminiFunctionDeclaration]

  // Sends a message to the AI and processes the response.
  // If AI returns a function call, executes the skill and returns result.
  // messages: Conversation history including the new user message.
  // context: Execution context for skill invocation.
  // Returns: AISkillResponse with text or skill invocation result.
  // Throws: InvocationError for network or execution failures.
  func sendMessage(
    messages: [ConversationMessage],
    context: SkillContext
  ) async throws -> AISkillResponse

  // Sends a message with streaming response from AI.
  // messages: Conversation history including the new user message.
  // context: Execution context for skill invocation.
  // onChunk: Callback invoked for each text chunk during streaming.
  // Returns: Final AISkillResponse after streaming completes.
  // Throws: InvocationError for network or streaming failures.
  func sendMessageStreaming(
    messages: [ConversationMessage],
    context: SkillContext,
    onChunk: @escaping @Sendable (SkillResultChunk) -> Void
  ) async throws -> AISkillResponse
}

/*
 ACCEPTANCE CRITERIA: AISkillInvocationServiceProtocol

 SCENARIO: Get tool declarations
 GIVEN: Multiple skills registered in the registry
 WHEN: getToolDeclarations() is called
 THEN: Returns array of GeminiFunctionDeclaration
  AND: Each declaration maps to a registered skill
  AND: Parameters match skill metadata

 SCENARIO: Send message with text response
 GIVEN: User message "What is 2+2?"
  AND: No skill invocation needed
 WHEN: sendMessage is called
 THEN: AISkillResponse.text is returned
  AND: Contains AI's text answer

 SCENARIO: Send message triggering skill invocation
 GIVEN: User message "Summarize my notes"
  AND: Summarize skill is registered
 WHEN: sendMessage is called
 THEN: AI decides to call summarize function
  AND: Skill is executed automatically
  AND: AISkillResponse.skillInvocation is returned
  AND: result contains skill output

 SCENARIO: Send message with conversation history
 GIVEN: Prior messages in conversationHistory
  AND: New user message references prior context
 WHEN: sendMessage is called
 THEN: Full conversation is sent to AI
  AND: AI can reference prior context in response

 SCENARIO: Send message when AI calls non-existent skill
 GIVEN: AI hallucinates a function call for "non-existent-skill"
 WHEN: sendMessage processes the function call
 THEN: InvocationError.skillExecutionFailed is thrown
  AND: skillID is "non-existent-skill"
  AND: reason indicates skill not found

 SCENARIO: Send message with skill that fails
 GIVEN: User message triggers a skill that throws
 WHEN: sendMessage executes the skill
 THEN: AISkillResponse.skillInvocation is returned
  AND: result.success is false
  AND: result.error contains failure details

 SCENARIO: Streaming message with text response
 GIVEN: User message expecting long text response
 WHEN: sendMessageStreaming is called
 THEN: onChunk is called with partial text
  AND: Final AISkillResponse.text contains complete response

 SCENARIO: Streaming message triggering skill
 GIVEN: User message triggering skill invocation
 WHEN: sendMessageStreaming is called
 THEN: AI indicates function call (not streamed)
  AND: Skill is executed
  AND: AISkillResponse.skillInvocation is returned

 SCENARIO: Cancel streaming message
 GIVEN: Streaming response in progress
 WHEN: Task is cancelled
 THEN: InvocationError.cancelled is thrown
  AND: Partial text chunks already delivered

 EDGE CASE: Empty messages array
 GIVEN: sendMessage called with empty messages
 WHEN: Request is processed
 THEN: AI receives no context
  AND: Response may be generic or error

 EDGE CASE: AI returns multiple function calls
 GIVEN: AI decides to call multiple skills
 WHEN: Response is processed
 THEN: First skill is executed
  AND: Subsequent calls handled in follow-up
  AND: Multi-turn conversation continues

 EDGE CASE: AI returns function call with missing parameters
 GIVEN: AI calls skill but omits required parameter
 WHEN: Skill execution is attempted
 THEN: Parameter validation fails
  AND: Error is returned in AISkillResponse

 EDGE CASE: Network failure during AI request
 GIVEN: Network drops during sendMessage
 WHEN: Request fails
 THEN: InvocationError.networkError is thrown
  AND: No partial response is returned

 EDGE CASE: AI response timeout
 GIVEN: AI takes too long to respond
 WHEN: Timeout period is exceeded
 THEN: InvocationError.timeout is thrown
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Concurrent cloud skill executions
 GIVEN: Multiple cloud skills executing simultaneously
 WHEN: SkillCloudClient handles concurrent requests
 THEN: Each execution is independent
  AND: Results are returned to correct callers
  AND: No request mixing occurs

 EDGE CASE: Firebase configuration change at runtime
 GIVEN: FirebaseConfiguration is updated
 WHEN: Client is reconfigured
 THEN: New requests use new configuration
  AND: In-flight requests continue with old config

 EDGE CASE: Large streaming response
 GIVEN: AI or skill produces very large streaming output
 WHEN: Chunks are delivered
 THEN: Memory is managed appropriately
  AND: Chunks are sized reasonably
  AND: No out-of-memory crash

 EDGE CASE: Rapid consecutive messages
 GIVEN: User sends messages rapidly
 WHEN: Each triggers sendMessage
 THEN: Requests are queued appropriately
  AND: No race conditions in response handling
  AND: Conversation history remains consistent

 EDGE CASE: Skill invocation during streaming
 GIVEN: AI streaming text then decides to call skill
 WHEN: Function call is embedded in stream
 THEN: Text chunks before function call are delivered
  AND: Skill is executed
  AND: Final response reflects skill result

 EDGE CASE: Retry on transient network failure
 GIVEN: Cloud request fails with transient error
 WHEN: Implementation has retry logic
 THEN: Retry is attempted (implementation decision)
  AND: Eventual success or failure is returned
  AND: Caller is not blocked indefinitely

 EDGE CASE: Authentication expiry during request
 GIVEN: Firebase auth token expires mid-request
 WHEN: Cloud function rejects with 401
 THEN: InvocationError.networkError or specific auth error
  AND: Client may refresh token and retry

 EDGE CASE: Malformed skill result from cloud
 GIVEN: Cloud function returns unexpected result format
 WHEN: Result is parsed
 THEN: InvocationError.invalidResponse is thrown
  AND: Raw response may be logged for debugging

 EDGE CASE: Function call with type mismatch
 GIVEN: AI calls skill with wrong parameter types
  AND: Parameter "count" should be number but AI sends string
 WHEN: Parameters are parsed to SkillParameterValue
 THEN: Type is preserved as-is (string)
  AND: Skill validation catches type mismatch
  AND: Error is returned to AI or caller

 EDGE CASE: Empty function call arguments
 GIVEN: AI calls skill with empty arguments {}
  AND: Skill has required parameters
 WHEN: Skill execution is attempted
 THEN: Missing parameter error occurs
  AND: InvocationError.skillExecutionFailed wraps the error

 EDGE CASE: Unicode and special characters in parameters
 GIVEN: Parameter contains emojis, CJK, or RTL text
 WHEN: Serialized and sent to cloud
 THEN: Encoding is preserved
  AND: Cloud function receives correct characters

 EDGE CASE: Very deep nested parameters
 GIVEN: Parameter with deeply nested object structure
 WHEN: Serialized for cloud or AI
 THEN: Full structure is preserved
  AND: Parser handles depth appropriately

 EDGE CASE: Streaming chunk boundary in multi-byte character
 GIVEN: Streaming text with UTF-8 multi-byte characters
 WHEN: Chunk boundary falls mid-character
 THEN: Implementation buffers correctly
  AND: Complete characters are delivered
  AND: No garbled text

 EDGE CASE: Simultaneous sendMessage and sendMessageStreaming
 GIVEN: One caller uses sendMessage, another uses sendMessageStreaming
 WHEN: Both execute concurrently
 THEN: Each operates independently
  AND: No interference between calls
*/

// MARK: - Constants

// Configuration constants for the invocation layer.
enum InvocationConstants {
  // Default timeout for cloud skill execution in seconds.
  static let defaultCloudTimeoutSeconds: Double = 60.0

  // Default timeout for AI message requests in seconds.
  static let defaultAITimeoutSeconds: Double = 120.0

  // Maximum timeout for any invocation operation.
  static let maximumTimeoutSeconds: Double = 300.0

  // Default chunk size hint for streaming responses.
  static let defaultStreamingChunkSizeHint: Int = 256

  // Maximum retry attempts for transient failures.
  static let maxRetryAttempts: Int = 3

  // Base delay between retries in seconds.
  static let retryBaseDelaySeconds: Double = 1.0
}

/*
 ACCEPTANCE CRITERIA: InvocationConstants

 SCENARIO: Use default cloud timeout
 GIVEN: A cloud skill execution without custom timeout
 WHEN: Timeout is applied
 THEN: defaultCloudTimeoutSeconds (60s) is used

 SCENARIO: Use default AI timeout
 GIVEN: An AI message request without custom timeout
 WHEN: Timeout is applied
 THEN: defaultAITimeoutSeconds (120s) is used

 SCENARIO: Respect maximum timeout
 GIVEN: An operation requesting 600 second timeout
 WHEN: Timeout is configured
 THEN: Capped at maximumTimeoutSeconds (300)

 SCENARIO: Retry with exponential backoff
 GIVEN: A transient failure
 WHEN: Retry is attempted
 THEN: Delay is retryBaseDelaySeconds * 2^attempt
  AND: Maximum of maxRetryAttempts retries
*/
