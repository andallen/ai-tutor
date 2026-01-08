// SkillsContract.swift
// Defines the API contract for the Skills Core infrastructure.
// Skills are modular capabilities invocable by users (UI palette) and Gemini AI (function calling).
// Skills support local, cloud, or hybrid execution modes.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation
import SwiftUI

// MARK: - API Contract

// MARK: - SkillParameterType Enum

// Defines the type of a skill parameter for validation and serialization.
// Used in parameter definitions and Gemini function declarations.
enum SkillParameterType: String, Sendable, Codable, Equatable {
  // A string value.
  case string

  // A numeric value (integer or floating point).
  case number

  // A boolean value (true/false).
  case boolean

  // An array of values.
  case array

  // A nested object with properties.
  case object
}

/*
 ACCEPTANCE CRITERIA: SkillParameterType

 SCENARIO: Encode parameter type to JSON
 GIVEN: A SkillParameterType value
 WHEN: Encoded to JSON
 THEN: Raw value is used (e.g., "string", "number")
  AND: Compatible with Gemini function declaration schema

 SCENARIO: Decode parameter type from JSON
 GIVEN: A JSON string representing a parameter type
 WHEN: Decoded to SkillParameterType
 THEN: Correct enum case is returned
  AND: Unknown values fail decoding

 SCENARIO: Equatable comparison
 GIVEN: Two SkillParameterType values
 WHEN: Compared for equality
 THEN: Returns true only if same case
*/

// MARK: - SkillParameterValue Enum

// Type-safe wrapper for parameter values with associated data.
// Preserves type information when passing parameters to skill execution.
enum SkillParameterValue: Sendable, Equatable {
  // A string value.
  case string(String)

  // A numeric value.
  case number(Double)

  // A boolean value.
  case boolean(Bool)

  // An array of parameter values.
  case array([SkillParameterValue])

  // A dictionary of parameter values.
  case object([String: SkillParameterValue])
}

/*
 ACCEPTANCE CRITERIA: SkillParameterValue

 SCENARIO: Wrap string value
 GIVEN: A Swift String "hello"
 WHEN: Wrapped as SkillParameterValue.string("hello")
 THEN: Type information is preserved
  AND: Value can be extracted later

 SCENARIO: Wrap numeric value
 GIVEN: A Swift Double 42.5
 WHEN: Wrapped as SkillParameterValue.number(42.5)
 THEN: Type information is preserved
  AND: Integer values are also stored as Double

 SCENARIO: Wrap boolean value
 GIVEN: A Swift Bool true
 WHEN: Wrapped as SkillParameterValue.boolean(true)
 THEN: Type information is preserved

 SCENARIO: Wrap array value
 GIVEN: An array of SkillParameterValue items
 WHEN: Wrapped as SkillParameterValue.array([...])
 THEN: All nested values preserve their types
  AND: Heterogeneous arrays are supported

 SCENARIO: Wrap object value
 GIVEN: A dictionary of String to SkillParameterValue
 WHEN: Wrapped as SkillParameterValue.object([...])
 THEN: All nested values preserve their types
  AND: Keys are preserved

 SCENARIO: Equatable comparison for nested values
 GIVEN: Two SkillParameterValue.array or .object values
 WHEN: Compared for equality
 THEN: Deep comparison is performed
  AND: Order matters for arrays
  AND: Key-value pairs are compared for objects

 EDGE CASE: Empty array comparison
 GIVEN: Two empty arrays SkillParameterValue.array([])
 WHEN: Compared for equality
 THEN: Returns true

 EDGE CASE: Empty object comparison
 GIVEN: Two empty objects SkillParameterValue.object([:])
 WHEN: Compared for equality
 THEN: Returns true
*/

// MARK: - SkillParameter Struct

// Defines a single parameter for a skill.
// Used to describe expected inputs and generate Gemini function declarations.
struct SkillParameter: Sendable, Equatable {
  // The parameter name (used as the key in parameter dictionaries).
  let name: String

  // Human-readable description of what this parameter does.
  let description: String

  // The expected type of this parameter's value.
  let type: SkillParameterType

  // Whether this parameter must be provided (vs optional).
  let required: Bool

  // Default value to use if parameter is not provided.
  // Only applicable for optional parameters.
  let defaultValue: SkillParameterValue?

  // List of allowed values for enum-like parameters.
  // If non-empty, the parameter value must be one of these.
  let allowedValues: [SkillParameterValue]?
}

/*
 ACCEPTANCE CRITERIA: SkillParameter

 SCENARIO: Required parameter without default
 GIVEN: A SkillParameter with required = true
 WHEN: The parameter definition is checked
 THEN: defaultValue should be nil
  AND: Execution fails if parameter is missing

 SCENARIO: Optional parameter with default
 GIVEN: A SkillParameter with required = false and defaultValue set
 WHEN: The parameter is not provided during execution
 THEN: defaultValue is used

 SCENARIO: Parameter with allowed values
 GIVEN: A SkillParameter with allowedValues = ["low", "medium", "high"]
 WHEN: Parameter value "invalid" is provided
 THEN: Validation fails with invalidParameterType error

 SCENARIO: Generate Gemini property schema
 GIVEN: A SkillParameter definition
 WHEN: Converted to GeminiPropertySchema
 THEN: Type maps correctly (string -> string, number -> number)
  AND: Description is preserved
  AND: Enum values are included if allowedValues present

 EDGE CASE: Optional parameter without default
 GIVEN: A SkillParameter with required = false and defaultValue = nil
 WHEN: The parameter is not provided
 THEN: Parameter is absent from execution context
  AND: Skill must handle nil case
*/

// MARK: - SkillExecutionMode Enum

// Defines where a skill executes its logic.
// Determines routing and infrastructure requirements.
enum SkillExecutionMode: String, Sendable, Codable, Equatable {
  // Executes entirely on-device.
  // No network required, fastest latency.
  case local

  // Executes on cloud infrastructure.
  // Requires network, may have higher latency.
  case cloud

  // Combines local and cloud execution.
  // May start locally and enhance with cloud.
  case hybrid
}

/*
 ACCEPTANCE CRITERIA: SkillExecutionMode

 SCENARIO: Local execution mode
 GIVEN: A skill with executionMode = .local
 WHEN: The skill is executed
 THEN: No network requests are made
  AND: Execution completes on-device

 SCENARIO: Cloud execution mode
 GIVEN: A skill with executionMode = .cloud
 WHEN: The skill is executed
 THEN: Network request is made to cloud infrastructure
  AND: SkillError.networkError thrown if offline

 SCENARIO: Hybrid execution mode
 GIVEN: A skill with executionMode = .hybrid
 WHEN: The skill is executed
 THEN: Executor determines optimal split
  AND: May function degraded if offline
*/

// MARK: - SkillResultData Enum

// Contains the actual data returned by a skill execution.
// Different skill types return different data structures.
enum SkillResultData: Sendable, Equatable {
  // Plain text result.
  case text(String)

  // Structured lesson content (title, sections, exercises).
  case lesson(SkillLessonContent)

  // Graph or chart data for visualization.
  case graph(GraphData)

  // Audio transcription result.
  case transcription(TranscriptionResult)

  // Generic analysis result with key-value pairs.
  case analysis([String: String])

  // Raw JSON data for custom handling.
  case json(Data)

  // Rich graph specification for interactive graphing calculator.
  // Provides Desmos/MATLAB-level graphing with full interactivity.
  case graphSpecification(GraphSpecification)
}

/*
 ACCEPTANCE CRITERIA: SkillResultData

 SCENARIO: Text result
 GIVEN: A skill that returns plain text
 WHEN: Result is SkillResultData.text("summary here")
 THEN: UI can display text directly
  AND: Value is extractable as String

 SCENARIO: Lesson result
 GIVEN: A skill that generates lesson content
 WHEN: Result is SkillResultData.lesson(SkillLessonContent)
 THEN: UI can render structured lesson
  AND: Sections and exercises are accessible

 SCENARIO: Graph result
 GIVEN: A skill that produces visualization data
 WHEN: Result is SkillResultData.graph(GraphData)
 THEN: UI can render chart using data
  AND: Axis labels and data points accessible

 SCENARIO: Transcription result
 GIVEN: An audio transcription skill
 WHEN: Result is SkillResultData.transcription(TranscriptionResult)
 THEN: Text and timestamps are accessible
  AND: Can be used for editing or display

 SCENARIO: Analysis result
 GIVEN: A skill that produces key-value analysis
 WHEN: Result is SkillResultData.analysis(["topic": "math", "difficulty": "medium"])
 THEN: Keys and values are accessible
  AND: UI can display as table or list

 SCENARIO: JSON result
 GIVEN: A skill with custom data format
 WHEN: Result is SkillResultData.json(Data)
 THEN: Data can be parsed by consumer
  AND: Flexibility for custom result types
*/

// MARK: - Supporting Result Data Types

// Structured content for lesson generation skills.
// Named SkillLessonContent to avoid conflict with Lesson feature types.
struct SkillLessonContent: Sendable, Equatable {
  // Lesson title.
  let title: String

  // Ordered list of section content.
  let sections: [SkillLessonSection]

  // Optional exercises or practice problems.
  let exercises: [SkillLessonExercise]?
}

// A section within a skill-generated lesson.
// Named SkillLessonSection to avoid conflict with Lesson feature types.
struct SkillLessonSection: Sendable, Equatable {
  // Section heading.
  let heading: String

  // Section body text.
  let content: String
}

// An exercise or practice problem from a skill-generated lesson.
// Named SkillLessonExercise to avoid conflict with Lesson feature types.
struct SkillLessonExercise: Sendable, Equatable {
  // Exercise prompt or question.
  let prompt: String

  // Optional hint text.
  let hint: String?

  // Expected answer (for self-check).
  let answer: String?
}

// Data for rendering graphs or charts.
struct GraphData: Sendable, Equatable {
  // Type of graph (line, bar, pie, scatter).
  let graphType: GraphType

  // Label for X axis.
  let xAxisLabel: String?

  // Label for Y axis.
  let yAxisLabel: String?

  // Data series to plot.
  let series: [DataSeries]
}

// Types of graphs that can be rendered.
enum GraphType: String, Sendable, Codable, Equatable {
  case line
  case bar
  case pie
  case scatter
}

// A single data series for graphing.
struct DataSeries: Sendable, Equatable {
  // Series name for legend.
  let name: String

  // Data points as (x, y) pairs.
  let dataPoints: [(x: Double, y: Double)]

  // Equatable implementation for tuple array.
  static func == (lhs: DataSeries, rhs: DataSeries) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.dataPoints.count == rhs.dataPoints.count else { return false }
    for (index, point) in lhs.dataPoints.enumerated() {
      if point.x != rhs.dataPoints[index].x || point.y != rhs.dataPoints[index].y {
        return false
      }
    }
    return true
  }
}

// Result from audio transcription.
struct TranscriptionResult: Sendable, Equatable {
  // Full transcribed text.
  let text: String

  // Language detected or specified.
  let language: String?

  // Confidence score (0.0 to 1.0).
  let confidence: Double?

  // Word-level timestamps if available.
  let wordTimestamps: [WordTimestamp]?
}

// Timestamp for a single word in transcription.
struct WordTimestamp: Sendable, Equatable {
  // The word text.
  let word: String

  // Start time in seconds.
  let startTime: Double

  // End time in seconds.
  let endTime: Double
}

// MARK: - SkillResult Struct

// Encapsulates the outcome of a skill execution.
// Contains success/failure status, data, and optional error information.
struct SkillResult: Sendable, Equatable {
  // Whether the execution succeeded.
  let success: Bool

  // The result data (present on success).
  let data: SkillResultData?

  // Human-readable message about the result.
  let message: String?

  // Error information (present on failure).
  let error: SkillError?

  // Factory method for successful result with data.
  static func success(data: SkillResultData, message: String? = nil) -> SkillResult {
    SkillResult(success: true, data: data, message: message, error: nil)
  }

  // Factory method for successful result with text shorthand.
  static func success(text: String) -> SkillResult {
    SkillResult(success: true, data: .text(text), message: nil, error: nil)
  }

  // Factory method for failure with error.
  static func failure(error: SkillError, message: String? = nil) -> SkillResult {
    SkillResult(success: false, data: nil, message: message, error: error)
  }
}

/*
 ACCEPTANCE CRITERIA: SkillResult

 SCENARIO: Create success result with data
 GIVEN: A successful skill execution
 WHEN: SkillResult.success(data: .text("result"), message: "Done") is called
 THEN: success is true
  AND: data contains the provided SkillResultData
  AND: message is "Done"
  AND: error is nil

 SCENARIO: Create success result with text shorthand
 GIVEN: A successful skill execution returning text
 WHEN: SkillResult.success(text: "Hello") is called
 THEN: success is true
  AND: data is .text("Hello")
  AND: error is nil

 SCENARIO: Create failure result with error
 GIVEN: A failed skill execution
 WHEN: SkillResult.failure(error: .executionFailed("reason"), message: "Failed") is called
 THEN: success is false
  AND: error contains the provided SkillError
  AND: message is "Failed"
  AND: data is nil

 SCENARIO: Equatable comparison
 GIVEN: Two SkillResult instances
 WHEN: Compared for equality
 THEN: All fields are compared
  AND: Data comparison is deep
*/

// MARK: - SkillContext Struct

// Provides execution context to skills.
// Contains information about the current state when the skill is invoked.
struct SkillContext: Sendable, Equatable {
  // ID of the currently open notebook (nil if none).
  let currentNotebookID: String?

  // ID of the currently open PDF document (nil if none).
  let currentPDFID: String?

  // User message that triggered the skill (for AI invocation).
  let userMessage: String?

  // Conversation history for context-aware skills.
  let conversationHistory: [ConversationMessage]?

  // JIIX content extracted from user's selection (via lasso tool in AI overlay).
  // Used by skills that can interpret handwritten content.
  let selectionJIIX: String?

  // Bounding rectangle of the user's selection in editor coordinates.
  // Indicates where the selection was made for positioning results.
  let selectionBounds: CGRect?

  // Creates context with all parameters (used primarily in tests and AI invocation).
  init(
    currentNotebookID: String? = nil,
    currentPDFID: String? = nil,
    userMessage: String? = nil,
    conversationHistory: [ConversationMessage]? = nil,
    selectionJIIX: String? = nil,
    selectionBounds: CGRect? = nil
  ) {
    self.currentNotebookID = currentNotebookID
    self.currentPDFID = currentPDFID
    self.userMessage = userMessage
    self.conversationHistory = conversationHistory
    self.selectionJIIX = selectionJIIX
    self.selectionBounds = selectionBounds
  }
}

// A single message in conversation history.
struct ConversationMessage: Sendable, Equatable {
  // Role of the message sender.
  let role: SkillMessageRole

  // Content of the message.
  let content: String
}

// Role of a conversation participant in skill invocations.
// Named SkillMessageRole to avoid conflict with AIChat MessageRole.
enum SkillMessageRole: String, Sendable, Codable, Equatable {
  case user
  case assistant
  case system
}

/*
 ACCEPTANCE CRITERIA: SkillContext

 SCENARIO: Context with notebook open
 GIVEN: User has a notebook open
 WHEN: SkillContext is created
 THEN: currentNotebookID contains the notebook ID
  AND: Skills can access notebook content

 SCENARIO: Context with PDF open
 GIVEN: User has a PDF open
 WHEN: SkillContext is created
 THEN: currentPDFID contains the PDF ID
  AND: Skills can access PDF content

 SCENARIO: Context from AI invocation
 GIVEN: Gemini AI invokes a skill with user message "summarize this"
 WHEN: SkillContext is created
 THEN: userMessage is "summarize this"
  AND: conversationHistory contains prior messages

 SCENARIO: Context from UI invocation
 GIVEN: User taps skill in UI palette
 WHEN: SkillContext is created
 THEN: userMessage is nil
  AND: conversationHistory is nil
  AND: currentNotebookID/currentPDFID reflect current state

 EDGE CASE: No document open
 GIVEN: User is on dashboard (no document open)
 WHEN: SkillContext is created
 THEN: currentNotebookID is nil
  AND: currentPDFID is nil

 SCENARIO: Context with selection from lasso tool
 GIVEN: User selects handwritten content with lasso in AI overlay
 WHEN: SkillContext is created
 THEN: selectionJIIX contains JIIX content from selection
  AND: selectionBounds contains CGRect of selection area
  AND: Skills can interpret handwritten content (e.g., equations)

 SCENARIO: Context without selection
 GIVEN: User invokes skill without using lasso tool
 WHEN: SkillContext is created
 THEN: selectionJIIX is nil
  AND: selectionBounds is nil
  AND: Skill uses other input methods (userMessage, parameters)

 SCENARIO: GraphingCalculatorSkill with selection
 GIVEN: User lasso-selects handwritten "y = x^2" and says "graph this"
 WHEN: GraphingCalculatorSkill executes
 THEN: selectionJIIX can be interpreted as equation
  AND: Graph is generated from handwritten expression
  AND: Result can be inserted near selectionBounds
*/

// MARK: - SkillMetadata Struct

// Describes a skill for discovery and display.
// Used by the registry and UI palette.
struct SkillMetadata: Sendable, Equatable, Identifiable {
  // Unique identifier for this skill (e.g., "summarize", "create-lesson").
  let id: String

  // Human-readable name for UI display.
  let displayName: String

  // Description of what the skill does.
  let description: String

  // SF Symbol name for the skill icon.
  let iconName: String

  // Parameters this skill accepts.
  let parameters: [SkillParameter]

  // Where the skill executes.
  let executionMode: SkillExecutionMode

  // Whether the skill has a custom UI for configuration.
  let hasCustomUI: Bool
}

/*
 ACCEPTANCE CRITERIA: SkillMetadata

 SCENARIO: Metadata for local skill
 GIVEN: A text summarization skill
 WHEN: SkillMetadata is created
 THEN: id is unique (e.g., "summarize")
  AND: displayName is human-readable ("Summarize")
  AND: description explains functionality
  AND: iconName is valid SF Symbol ("doc.text.magnifyingglass")
  AND: executionMode is .local
  AND: hasCustomUI is false for simple skills

 SCENARIO: Metadata with parameters
 GIVEN: A lesson generation skill with options
 WHEN: SkillMetadata is created
 THEN: parameters array contains SkillParameter definitions
  AND: Required parameters are marked as such
  AND: Parameter types match expected inputs

 SCENARIO: Metadata identifiable in lists
 GIVEN: Multiple SkillMetadata instances
 WHEN: Used in SwiftUI List
 THEN: Each skill is uniquely identified by id
  AND: No duplicate IDs cause issues

 SCENARIO: Metadata for skill with custom UI
 GIVEN: A skill requiring user input beyond parameters
 WHEN: SkillMetadata is created
 THEN: hasCustomUI is true
  AND: UI can present custom configuration view
*/

// MARK: - SkillError Enum

// Errors that can occur during skill operations.
// Conforms to LocalizedError for user-friendly messages.
enum SkillError: Error, LocalizedError, Equatable, Sendable {
  // Skill with given ID was not found in registry.
  case skillNotFound(skillID: String)

  // Failed to create skill instance from type.
  case skillCreationFailed(skillID: String, reason: String)

  // A required parameter was not provided.
  case missingRequiredParameter(parameterName: String)

  // Parameter value does not match expected type.
  case invalidParameterType(parameterName: String, expected: SkillParameterType, received: String)

  // Parameter value not in allowed values list.
  case invalidParameterValue(parameterName: String, value: String, allowed: [String])

  // Skill execution failed for a reason.
  case executionFailed(reason: String)

  // Cloud execution specifically failed.
  case cloudExecutionFailed(reason: String)

  // Network error during cloud execution.
  case networkError(reason: String)

  // Skill execution was cancelled.
  case cancelled

  // Skill execution timed out.
  case timeout(skillID: String, durationSeconds: Double)

  var errorDescription: String? {
    switch self {
    case .skillNotFound(let skillID):
      return "Skill not found: \(skillID)"
    case .skillCreationFailed(let skillID, let reason):
      return "Failed to create skill '\(skillID)': \(reason)"
    case .missingRequiredParameter(let parameterName):
      return "Missing required parameter: \(parameterName)"
    case .invalidParameterType(let parameterName, let expected, let received):
      return
        "Invalid type for parameter '\(parameterName)': expected \(expected.rawValue), received \(received)"
    case .invalidParameterValue(let parameterName, let value, let allowed):
      return
        "Invalid value '\(value)' for parameter '\(parameterName)'. Allowed: \(allowed.joined(separator: ", "))"
    case .executionFailed(let reason):
      return "Skill execution failed: \(reason)"
    case .cloudExecutionFailed(let reason):
      return "Cloud execution failed: \(reason)"
    case .networkError(let reason):
      return "Network error: \(reason)"
    case .cancelled:
      return "Skill execution was cancelled"
    case .timeout(let skillID, let durationSeconds):
      return "Skill '\(skillID)' timed out after \(durationSeconds) seconds"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: SkillError

 SCENARIO: Skill not found error
 GIVEN: An unknown skill ID "unknown-skill"
 WHEN: Registry lookup fails
 THEN: SkillError.skillNotFound(skillID: "unknown-skill") is thrown
  AND: Error message includes the skill ID

 SCENARIO: Missing required parameter error
 GIVEN: A skill requiring parameter "topic"
  AND: Parameter "topic" is not provided
 WHEN: Validation runs before execution
 THEN: SkillError.missingRequiredParameter(parameterName: "topic") is thrown
  AND: Error message names the missing parameter

 SCENARIO: Invalid parameter type error
 GIVEN: A skill expecting number parameter "count"
  AND: String "five" is provided instead
 WHEN: Validation runs
 THEN: SkillError.invalidParameterType is thrown
  AND: Error message shows expected vs received types

 SCENARIO: Invalid parameter value error
 GIVEN: A skill with allowed values ["easy", "medium", "hard"]
  AND: Value "impossible" is provided
 WHEN: Validation runs
 THEN: SkillError.invalidParameterValue is thrown
  AND: Error message lists allowed values

 SCENARIO: Execution failed error
 GIVEN: A skill throws during execution
 WHEN: Error is caught and wrapped
 THEN: SkillError.executionFailed(reason:) is used
  AND: Original error reason is preserved

 SCENARIO: Network error for cloud skill
 GIVEN: A cloud skill executes while offline
 WHEN: Network request fails
 THEN: SkillError.networkError is thrown
  AND: Reason describes connection failure

 SCENARIO: Timeout error
 GIVEN: A skill takes longer than allowed
 WHEN: Timeout period expires
 THEN: SkillError.timeout is thrown
  AND: Skill ID and duration are included

 SCENARIO: Cancelled error
 GIVEN: User cancels skill execution
 WHEN: Cancellation is detected
 THEN: SkillError.cancelled is thrown
*/

// MARK: - Skill Protocol

// Core protocol that all skills must implement.
// Defines static metadata and async execution method.
protocol Skill: Sendable {
  // Static metadata describing this skill.
  // Used for registration and discovery.
  static var metadata: SkillMetadata { get }

  // Executes the skill with given parameters and context.
  // parameters: Dictionary of parameter name to value.
  // context: Execution context with current state.
  // Returns: SkillResult with success/failure and data.
  // Throws: SkillError if execution cannot proceed.
  func execute(
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult
}

/*
 ACCEPTANCE CRITERIA: Skill Protocol

 SCENARIO: Access skill metadata
 GIVEN: A type conforming to Skill protocol
 WHEN: SomeSkill.metadata is accessed
 THEN: SkillMetadata is returned
  AND: Metadata is consistent across accesses

 SCENARIO: Execute skill with valid parameters
 GIVEN: A Skill instance
  AND: Valid parameters matching metadata.parameters
 WHEN: execute(parameters:context:) is called
 THEN: Skill performs its function
  AND: SkillResult is returned
  AND: success is true if operation succeeded

 SCENARIO: Execute skill with missing required parameter
 GIVEN: A Skill instance
  AND: Required parameter "topic" is missing
 WHEN: execute(parameters:context:) is called
 THEN: SkillError.missingRequiredParameter is thrown
  AND: Execution does not proceed

 SCENARIO: Skill uses context
 GIVEN: A Skill that needs current notebook content
  AND: SkillContext.currentNotebookID is set
 WHEN: execute(parameters:context:) is called
 THEN: Skill can access notebook via ID
  AND: Result reflects notebook content

 EDGE CASE: Execute with empty parameters
 GIVEN: A Skill with no required parameters
 WHEN: execute(parameters: [:], context:) is called
 THEN: Skill executes successfully
  AND: Default values are used where defined
*/

// MARK: - SkillWithUI Protocol

// Protocol for skills that provide a custom configuration UI.
// Extends Skill with SwiftUI view building capability.
@MainActor
protocol SkillWithUI: Skill {
  // The type of view this skill provides for configuration.
  associatedtype ConfigurationView: View

  // Builds the custom configuration view.
  // onExecute: Callback to invoke when user confirms parameters.
  func makeConfigurationView(
    context: SkillContext,
    onExecute: @escaping ([String: SkillParameterValue]) -> Void
  ) -> ConfigurationView
}

/*
 ACCEPTANCE CRITERIA: SkillWithUI Protocol

 SCENARIO: Skill with custom UI
 GIVEN: A skill conforming to SkillWithUI
  AND: metadata.hasCustomUI is true
 WHEN: makeConfigurationView(context:onExecute:) is called
 THEN: A SwiftUI View is returned
  AND: View allows user to configure parameters
  AND: onExecute is called with final parameters

 SCENARIO: User configures and executes
 GIVEN: A configuration view is displayed
  AND: User sets parameter values
 WHEN: User taps execute/confirm button
 THEN: onExecute callback is invoked
  AND: Parameters dictionary contains user selections
  AND: Execution proceeds with those parameters

 SCENARIO: User cancels configuration
 GIVEN: A configuration view is displayed
 WHEN: User dismisses without executing
 THEN: onExecute is not called
  AND: No execution occurs
*/

// MARK: - StreamingSkill Protocol

// Protocol for skills that stream results incrementally.
// Extends Skill with streaming execution capability.
protocol StreamingSkill: Skill {
  // Executes the skill and streams results via AsyncThrowingStream.
  // parameters: Dictionary of parameter name to value.
  // context: Execution context with current state.
  // Returns: AsyncThrowingStream that yields SkillResult chunks.
  func executeStreaming(
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) -> AsyncThrowingStream<SkillResult, Error>
}

/*
 ACCEPTANCE CRITERIA: StreamingSkill Protocol

 SCENARIO: Stream text generation
 GIVEN: A StreamingSkill for text generation
 WHEN: executeStreaming(parameters:context:) is called
 THEN: AsyncThrowingStream is returned
  AND: Partial results are yielded as available
  AND: Final result marks completion

 SCENARIO: Consume streaming results
 GIVEN: An AsyncThrowingStream from executeStreaming
 WHEN: Consumer iterates with for await
 THEN: Each yielded SkillResult contains partial data
  AND: Can update UI progressively
  AND: Stream completes when skill finishes

 SCENARIO: Streaming error handling
 GIVEN: A StreamingSkill execution encounters error
 WHEN: Error occurs mid-stream
 THEN: Stream throws the error
  AND: Consumer can catch and handle
  AND: Partial results already yielded are preserved

 SCENARIO: Cancel streaming execution
 GIVEN: A streaming skill in progress
 WHEN: Task is cancelled
 THEN: Stream terminates
  AND: Resources are cleaned up
*/

// MARK: - SkillRegistryProtocol

// Actor protocol for managing skill registration and discovery.
// Thread-safe registration and lookup of available skills.
protocol SkillRegistryProtocol: Actor {
  // Registers a skill type with the registry.
  // skillType: The Skill-conforming type to register.
  func register<S: Skill>(_ skillType: S.Type)

  // Returns metadata for all registered skills.
  // Sorted alphabetically by displayName.
  func allSkills() -> [SkillMetadata]

  // Returns metadata for a specific skill by ID.
  // Returns nil if skill is not registered.
  func skill(withID id: String) -> SkillMetadata?

  // Creates a new instance of a skill by ID.
  // Throws skillNotFound if ID is not registered.
  // Throws skillCreationFailed if instantiation fails.
  func createSkill(withID id: String) throws -> any Skill

  // Generates Gemini-compatible function declarations for all skills.
  // Used to provide Gemini AI with available skill capabilities.
  func generateGeminiFunctionDeclarations() -> [GeminiFunctionDeclaration]
}

/*
 ACCEPTANCE CRITERIA: SkillRegistryProtocol

 SCENARIO: Register a skill type
 GIVEN: An empty skill registry
  AND: A type SummarizeSkill conforming to Skill
 WHEN: register(SummarizeSkill.self) is called
 THEN: Skill is added to registry
  AND: skill(withID: "summarize") returns metadata
  AND: allSkills() includes the skill

 SCENARIO: Retrieve all skills sorted
 GIVEN: A registry with skills "Zoom", "Alpha", "Beta"
 WHEN: allSkills() is called
 THEN: Returns [Alpha, Beta, Zoom] (sorted by displayName)

 SCENARIO: Look up skill by ID
 GIVEN: A registered skill with id "create-lesson"
 WHEN: skill(withID: "create-lesson") is called
 THEN: Returns the SkillMetadata for that skill

 SCENARIO: Look up non-existent skill
 GIVEN: No skill with id "unknown"
 WHEN: skill(withID: "unknown") is called
 THEN: Returns nil

 SCENARIO: Create skill instance
 GIVEN: A registered skill with id "summarize"
 WHEN: createSkill(withID: "summarize") is called
 THEN: Returns a new Skill instance
  AND: Instance can execute

 SCENARIO: Create non-existent skill
 GIVEN: No skill with id "fake"
 WHEN: createSkill(withID: "fake") is called
 THEN: Throws SkillError.skillNotFound(skillID: "fake")

 SCENARIO: Generate Gemini function declarations
 GIVEN: A registry with multiple skills
 WHEN: generateGeminiFunctionDeclarations() is called
 THEN: Returns array of GeminiFunctionDeclaration
  AND: Each declaration has name matching skill ID
  AND: Each declaration has parameters matching skill parameters
  AND: Descriptions are included

 EDGE CASE: Register same skill twice
 GIVEN: A skill already registered with id "summarize"
 WHEN: register(SummarizeSkill.self) is called again
 THEN: No duplicate is created
  AND: Only one entry exists for that ID

 EDGE CASE: Empty registry
 GIVEN: No skills registered
 WHEN: allSkills() is called
 THEN: Returns empty array []
  AND: No error thrown

 EDGE CASE: Concurrent registration
 GIVEN: Multiple tasks calling register() simultaneously
 WHEN: Actor serializes the calls
 THEN: All skills are registered
  AND: No race conditions occur
*/

// MARK: - SkillExecutorProtocol

// Actor protocol for orchestrating skill execution.
// Handles validation, routing, and execution lifecycle.
protocol SkillExecutorProtocol: Actor {
  // Executes a skill by ID with given parameters and context.
  // skillID: Identifier of the skill to execute.
  // parameters: Parameter values to pass to the skill.
  // context: Execution context with current state.
  // Returns: SkillResult from the skill execution.
  // Throws: SkillError for validation or execution failures.
  func execute(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult

  // Validates parameters against skill metadata before execution.
  // skillID: Identifier of the skill.
  // parameters: Parameters to validate.
  // Throws: SkillError if validation fails.
  func validateParameters(
    skillID: String,
    parameters: [String: SkillParameterValue]
  ) throws

  // Cancels an in-progress skill execution.
  // executionID: Identifier for the execution to cancel.
  func cancelExecution(executionID: String) async
}

/*
 ACCEPTANCE CRITERIA: SkillExecutorProtocol

 SCENARIO: Execute valid skill with valid parameters
 GIVEN: A registered skill "summarize"
  AND: Valid parameters ["length": .string("short")]
  AND: Valid context with currentNotebookID
 WHEN: execute(skillID:parameters:context:) is called
 THEN: Skill is looked up in registry
  AND: Parameters are validated
  AND: Skill.execute() is called
  AND: SkillResult is returned

 SCENARIO: Execute with unknown skill ID
 GIVEN: No skill with ID "unknown"
 WHEN: execute(skillID: "unknown", ...) is called
 THEN: Throws SkillError.skillNotFound(skillID: "unknown")
  AND: No execution attempt is made

 SCENARIO: Execute with missing required parameter
 GIVEN: A skill requiring "topic" parameter
  AND: Parameters do not include "topic"
 WHEN: execute(...) is called
 THEN: Throws SkillError.missingRequiredParameter(parameterName: "topic")
  AND: Skill.execute() is not called

 SCENARIO: Execute with invalid parameter type
 GIVEN: A skill expecting number parameter "count"
  AND: Parameters include ["count": .string("five")]
 WHEN: execute(...) is called
 THEN: Throws SkillError.invalidParameterType
  AND: Error specifies expected vs received

 SCENARIO: Execute routes to correct execution mode
 GIVEN: A skill with executionMode = .cloud
 WHEN: execute(...) is called
 THEN: Cloud execution path is used
  AND: Network call is made

 SCENARIO: Validate parameters independently
 GIVEN: A skill "create-lesson" with parameters
  AND: Parameter values to check
 WHEN: validateParameters(skillID:parameters:) is called
 THEN: Validation runs without executing
  AND: Throws if validation fails
  AND: Returns normally if valid

 SCENARIO: Cancel in-progress execution
 GIVEN: A skill execution in progress
  AND: Execution has ID "exec-123"
 WHEN: cancelExecution(executionID: "exec-123") is called
 THEN: Execution is marked for cancellation
  AND: Skill receives cancellation signal
  AND: SkillError.cancelled is thrown

 EDGE CASE: Execute with extra parameters
 GIVEN: A skill with defined parameters ["topic"]
  AND: Parameters include ["topic": ..., "extra": ...]
 WHEN: execute(...) is called
 THEN: Extra parameters are ignored
  AND: Execution proceeds with known parameters

 EDGE CASE: Execute with empty context
 GIVEN: A skill that needs notebook context
  AND: context.currentNotebookID is nil
 WHEN: execute(...) is called
 THEN: Skill handles missing context gracefully
  AND: May return error in result or throw
*/

// MARK: - Gemini Integration Types

// Represents a function declaration for Gemini AI integration.
// Follows Google's function calling specification.
struct GeminiFunctionDeclaration: Sendable, Equatable, Codable {
  // Function name (maps to skill ID).
  let name: String

  // Description of what the function does.
  let description: String

  // Parameter schema for the function.
  let parameters: GeminiFunctionParameters
}

// Parameter schema for a Gemini function declaration.
struct GeminiFunctionParameters: Sendable, Equatable, Codable {
  // Always "object" for Gemini function parameters.
  let type: String

  // Property definitions keyed by parameter name.
  let properties: [String: GeminiPropertySchema]

  // Names of required parameters.
  let required: [String]
}

// Schema for a single property in Gemini function parameters.
// Uses class to allow recursive structure (items, properties can reference self).
final class GeminiPropertySchema: Sendable, Equatable, Codable {
  // Type of the property (string, number, boolean, array, object).
  let type: String

  // Description of the property.
  let description: String

  // Allowed values for enum-like properties.
  let enumValues: [String]?

  // Nested properties for object types.
  let properties: [String: GeminiPropertySchema]?

  // Items schema for array types.
  let items: GeminiPropertySchema?

  private enum CodingKeys: String, CodingKey {
    case type
    case description
    case enumValues = "enum"
    case properties
    case items
  }

  init(
    type: String,
    description: String,
    enumValues: [String]? = nil,
    properties: [String: GeminiPropertySchema]? = nil,
    items: GeminiPropertySchema? = nil
  ) {
    self.type = type
    self.description = description
    self.enumValues = enumValues
    self.properties = properties
    self.items = items
  }

  static func == (lhs: GeminiPropertySchema, rhs: GeminiPropertySchema) -> Bool {
    lhs.type == rhs.type
      && lhs.description == rhs.description
      && lhs.enumValues == rhs.enumValues
      && lhs.properties == rhs.properties
      && lhs.items == rhs.items
  }
}

/*
 ACCEPTANCE CRITERIA: Gemini Integration Types

 SCENARIO: Generate declaration for simple skill
 GIVEN: A skill "summarize" with string parameter "text"
 WHEN: GeminiFunctionDeclaration is created
 THEN: name is "summarize"
  AND: description matches skill description
  AND: parameters.type is "object"
  AND: parameters.properties contains "text" with type "string"
  AND: parameters.required contains "text" if required

 SCENARIO: Generate declaration with enum parameter
 GIVEN: A skill with parameter having allowedValues ["short", "medium", "long"]
 WHEN: GeminiPropertySchema is created
 THEN: enumValues contains ["short", "medium", "long"]
  AND: Gemini can validate against allowed values

 SCENARIO: Generate declaration with nested object
 GIVEN: A skill with object parameter containing properties
 WHEN: GeminiPropertySchema is created for that parameter
 THEN: type is "object"
  AND: properties contains nested property schemas
  AND: Gemini can parse nested structure

 SCENARIO: Generate declaration with array parameter
 GIVEN: A skill with array parameter of strings
 WHEN: GeminiPropertySchema is created
 THEN: type is "array"
  AND: items.type is "string"
  AND: Gemini can parse array input

 SCENARIO: Encode declaration to JSON
 GIVEN: A complete GeminiFunctionDeclaration
 WHEN: Encoded to JSON
 THEN: Valid JSON is produced
  AND: Matches Gemini function calling spec
  AND: Can be used in API request

 SCENARIO: Decode declaration from JSON
 GIVEN: A JSON function declaration from Gemini
 WHEN: Decoded to GeminiFunctionDeclaration
 THEN: All fields are populated
  AND: Nested structures are preserved
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Skill execution timeout
 GIVEN: A skill that takes too long to execute
 WHEN: Timeout threshold is exceeded
 THEN: SkillError.timeout is thrown
  AND: Skill ID and duration are included
  AND: Resources are cleaned up

 EDGE CASE: Concurrent skill executions
 GIVEN: Multiple skills being executed simultaneously
 WHEN: Executor handles concurrent requests
 THEN: Each execution is independent
  AND: Results are returned to correct callers
  AND: No cross-contamination of context

 EDGE CASE: Skill throws unexpected error
 GIVEN: A skill that throws a non-SkillError
 WHEN: Executor catches the error
 THEN: Wrapped as SkillError.executionFailed
  AND: Original error message is preserved
  AND: Caller receives structured error

 EDGE CASE: Cloud skill with no network
 GIVEN: A cloud skill (executionMode = .cloud)
  AND: Device is offline
 WHEN: execute() is called
 THEN: SkillError.networkError is thrown
  AND: Reason indicates no connectivity
  AND: No partial execution occurs

 EDGE CASE: Hybrid skill degrades gracefully
 GIVEN: A hybrid skill (executionMode = .hybrid)
  AND: Device is offline
 WHEN: execute() is called
 THEN: Skill attempts local-only execution
  AND: Result may be degraded quality
  AND: Success indicates partial functionality

 EDGE CASE: Parameter validation with nested objects
 GIVEN: A skill with object parameter containing nested required fields
  AND: Nested required field is missing
 WHEN: validateParameters() is called
 THEN: SkillError.missingRequiredParameter is thrown
  AND: Parameter path indicates nesting (e.g., "options.format")

 EDGE CASE: Array parameter with wrong element types
 GIVEN: A skill expecting array of numbers
  AND: Array contains string elements
 WHEN: validateParameters() is called
 THEN: SkillError.invalidParameterType is thrown
  AND: Error indicates array element type mismatch

 EDGE CASE: Very large parameter values
 GIVEN: A parameter with very long string (100KB)
 WHEN: execute() is called
 THEN: Parameter is passed to skill
  AND: Skill may apply its own limits
  AND: Memory is handled appropriately

 EDGE CASE: Null/nil parameter values
 GIVEN: A parameter value that should be nil
 WHEN: Represented in SkillParameterValue
 THEN: Not directly supported (use absence of key)
  AND: Optional parameters simply omitted
  AND: Skills check key presence

 EDGE CASE: Context with stale notebook ID
 GIVEN: Context with currentNotebookID for deleted notebook
 WHEN: Skill tries to access notebook
 THEN: Skill handles not-found gracefully
  AND: Returns appropriate error in result
  AND: Does not crash

 EDGE CASE: Register skill with duplicate ID
 GIVEN: Two different skill types with same ID
 WHEN: Both are registered
 THEN: Second registration overwrites first
  AND: Only latest is available
  AND: No error thrown (last wins)

 EDGE CASE: Create skill when registry is empty
 GIVEN: Empty skill registry
 WHEN: createSkill(withID:) is called
 THEN: SkillError.skillNotFound is thrown
  AND: Error message is clear

 EDGE CASE: Streaming skill cancellation
 GIVEN: A streaming skill mid-execution
 WHEN: Consumer cancels the task
 THEN: Stream terminates cleanly
  AND: No resource leaks
  AND: Partial results are usable

 EDGE CASE: SkillWithUI on background thread
 GIVEN: makeConfigurationView called from background
 WHEN: @MainActor is enforced
 THEN: Compiler error prevents misuse
  AND: UI code runs on main thread

 EDGE CASE: Gemini function declaration with no parameters
 GIVEN: A skill with empty parameters array
 WHEN: GeminiFunctionDeclaration is generated
 THEN: parameters.properties is empty {}
  AND: parameters.required is empty []
  AND: Valid for Gemini function calling
*/

// MARK: - Constants

// Configuration constants for the skills system.
enum SkillConstants {
  // Default timeout for skill execution in seconds.
  static let defaultExecutionTimeoutSeconds: Double = 30.0

  // Maximum timeout for any skill execution.
  static let maximumExecutionTimeoutSeconds: Double = 300.0

  // Default limit for streaming chunk size in characters.
  static let defaultStreamingChunkSize: Int = 100

  // Maximum number of conversation history messages in context.
  static let maxConversationHistoryMessages: Int = 50
}

/*
 ACCEPTANCE CRITERIA: SkillConstants

 SCENARIO: Use default timeout
 GIVEN: A skill without custom timeout
 WHEN: Execution starts
 THEN: defaultExecutionTimeoutSeconds is used
  AND: Timeout error thrown after 30 seconds

 SCENARIO: Respect maximum timeout
 GIVEN: A skill requesting 600 second timeout
 WHEN: Timeout is configured
 THEN: Capped at maximumExecutionTimeoutSeconds (300)
  AND: Skill cannot exceed maximum

 SCENARIO: Limit conversation history
 GIVEN: Context with 100 conversation messages
 WHEN: Context is created
 THEN: Only last 50 messages retained
  AND: Oldest messages are dropped
*/
