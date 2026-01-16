//
// AlanContract.swift
// InkOS
//
// Core types for the Alan subagent architecture.
// Alan is the main tutoring agent that outputs Text/Input blocks directly
// and delegates Table/Visual blocks to specialized subagents.
//

import Foundation

// MARK: - SubagentRequestID

// Unique identifier for subagent requests.
// Used to track pending requests and match responses to placeholders.
struct SubagentRequestID: Hashable, Sendable, Codable, Equatable, CustomStringConvertible {
  let rawValue: String

  init() {
    self.rawValue = "req-\(UUID().uuidString)"
  }

  init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  var description: String { rawValue }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

// MARK: - AlanOutput

// Alan's structured output format.
// Contains notebook updates and the updated session model.
struct AlanOutput: Sendable, Codable, Equatable {
  let notebookUpdates: [NotebookUpdate]
  let sessionModel: SessionModel

  private enum CodingKeys: String, CodingKey {
    case notebookUpdates = "notebook_updates"
    case sessionModel = "session_model"
  }
}

// MARK: - NotebookUpdate

// A single update to the notebook from Alan.
// Either appends a direct block or requests content from a subagent.
struct NotebookUpdate: Sendable, Codable, Equatable {
  let action: UpdateAction
  let content: UpdateContent

  private enum CodingKeys: String, CodingKey {
    case action
    case content
  }
}

// MARK: - UpdateAction

// The type of notebook update.
enum UpdateAction: String, Sendable, Codable, Equatable {
  // Direct block insertion (Text, Input).
  case append

  // Subagent request (Table, Visual).
  case request
}

// MARK: - UpdateContent

// The content of a notebook update.
// Either a direct block content or a subagent request.
enum UpdateContent: Sendable, Equatable {
  case text(TextContent)
  case input(InputContent)
  case subagentRequest(SubagentRequest)
}

// MARK: - UpdateContent Codable

extension UpdateContent: Codable {
  private enum TypeKey: String, CodingKey {
    case type
  }

  private enum ContentType: String, Codable {
    case text
    case input
    case subagentRequest = "subagent_request"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(ContentType.self, forKey: .type)

    switch type {
    case .text:
      let content = try TextContent(from: decoder)
      self = .text(content)
    case .input:
      let content = try InputContent(from: decoder)
      self = .input(content)
    case .subagentRequest:
      let request = try SubagentRequest(from: decoder)
      self = .subagentRequest(request)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)

    switch self {
    case .text(let content):
      try container.encode(ContentType.text, forKey: .type)
      try content.encode(to: encoder)
    case .input(let content):
      try container.encode(ContentType.input, forKey: .type)
      try content.encode(to: encoder)
    case .subagentRequest(let request):
      try container.encode(ContentType.subagentRequest, forKey: .type)
      try request.encode(to: encoder)
    }
  }
}

// MARK: - SubagentTargetType

// The type of subagent to route the request to.
enum SubagentTargetType: String, Sendable, Codable, Equatable {
  // Table generation subagent.
  case table

  // Visual router (routes to image, graphics, or embed subagent).
  case visual
}

// MARK: - VisualIntent

// Why Alan wants this visual. Influences routing and fulfillment decisions.
enum VisualIntent: String, Sendable, Codable, Equatable {
  // Display anatomy, composition, or parts.
  case showStructure = "show_structure"

  // Illustrate a sequence, cycle, or transformation.
  case showProcess = "show_process"

  // Display how variables relate.
  case showRelationship = "show_relationship"

  // Concrete instance of an abstract concept.
  case showExample = "show_example"

  // Let student manipulate variables and see results.
  case interactiveExploration = "interactive_exploration"

  // Step through a specific problem with visuals.
  case workedExample = "worked_example"

  // Show differences or similarities.
  case comparison = "comparison"

  // Visual metaphor to aid understanding.
  case analogy = "analogy"

  // Show the concept in authentic context.
  case realWorld = "real_world"

  // Primary source, historical photo, or artwork.
  case historical = "historical"
}

// MARK: - SubagentRequest

// A request from Alan to a subagent for content generation.
// Contains concept-level information; the subagent handles implementation details.
struct SubagentRequest: Sendable, Codable, Equatable {
  // Unique request identifier for tracking.
  let id: SubagentRequestID

  // Which subagent should handle this request.
  let targetType: SubagentTargetType

  // What to create (e.g., "multiplication table 1-10", "projectile motion").
  let concept: String

  // Why this helps learning (VisualIntent for visual, free string for table).
  let intent: String

  // Detailed specification of what Alan wants.
  let description: String

  // Structured data when Alan has specific values (chart data, force diagrams, etc.).
  let parameters: [String: AnyCodable]?

  // Optional constraints for the subagent.
  let constraints: RequestConstraints?

  private enum CodingKeys: String, CodingKey {
    case id
    case targetType = "target_type"
    case concept
    case intent
    case description
    case parameters
    case constraints
  }

  init(
    id: SubagentRequestID = SubagentRequestID(),
    targetType: SubagentTargetType,
    concept: String,
    intent: String,
    description: String,
    parameters: [String: AnyCodable]? = nil,
    constraints: RequestConstraints? = nil
  ) {
    self.id = id
    self.targetType = targetType
    self.concept = concept
    self.intent = intent
    self.description = description
    self.parameters = parameters
    self.constraints = constraints
  }

  // Convenience initializer for visual requests with typed intent.
  init(
    id: SubagentRequestID = SubagentRequestID(),
    visualIntent: VisualIntent,
    concept: String,
    description: String,
    parameters: [String: AnyCodable]? = nil,
    constraints: RequestConstraints? = nil
  ) {
    self.id = id
    self.targetType = .visual
    self.concept = concept
    self.intent = visualIntent.rawValue
    self.description = description
    self.parameters = parameters
    self.constraints = constraints
  }
}

// MARK: - RequestConstraints

// Optional constraints for subagent requests.
struct RequestConstraints: Sendable, Codable, Equatable {
  // Maximum rows for table generation.
  let maxRows: Int?

  // Preferred graphics engine (chartjs, p5, three, jsxgraph).
  let preferredEngine: String?

  // Preferred embed provider (phet, geogebra, desmos, youtube).
  let preferredProvider: String?

  // Whether AI image generation is allowed.
  let allowAIGeneration: Bool?

  // Maximum wait time in milliseconds.
  let maxWaitTimeMs: Int?

  // Preferred format hint (static, animated, interactive).
  let preferredFormat: PreferredFormat?

  private enum CodingKeys: String, CodingKey {
    case maxRows = "max_rows"
    case preferredEngine = "preferred_engine"
    case preferredProvider = "preferred_provider"
    case allowAIGeneration = "allow_ai_generation"
    case maxWaitTimeMs = "max_wait_time_ms"
    case preferredFormat = "preferred_format"
  }

  init(
    maxRows: Int? = nil,
    preferredEngine: String? = nil,
    preferredProvider: String? = nil,
    allowAIGeneration: Bool? = nil,
    maxWaitTimeMs: Int? = nil,
    preferredFormat: PreferredFormat? = nil
  ) {
    self.maxRows = maxRows
    self.preferredEngine = preferredEngine
    self.preferredProvider = preferredProvider
    self.allowAIGeneration = allowAIGeneration
    self.maxWaitTimeMs = maxWaitTimeMs
    self.preferredFormat = preferredFormat
  }
}

// MARK: - PreferredFormat

// Hint for router when multiple formats could work.
enum PreferredFormat: String, Sendable, Codable, Equatable {
  case `static`
  case animated
  case interactive
}

// MARK: - SubagentStatus

// Status of a subagent response.
enum SubagentStatus: String, Sendable, Codable, Equatable {
  // Block is complete and ready to render.
  case ready

  // Block is being generated asynchronously (AI generation).
  case pending

  // Request could not be fulfilled.
  case failed
}

// MARK: - ResponseMetadata

// Metadata about how a response was fulfilled.
struct ResponseMetadata: Sendable, Codable, Equatable {
  // How the content was generated.
  let fulfillmentMethod: FulfillmentMethod?

  // Time taken to generate the response.
  let latencyMs: Int?

  // Selected engine (for graphics).
  let engineSelected: String?

  // Provider (for embed).
  let provider: String?

  // Sources searched (for image).
  let sourcesSearched: [String]?

  // Matched simulation (for embed).
  let simulationMatched: String?

  // Estimated wait time for pending responses.
  let estimatedWaitMs: Int?

  // Reason for using fallback.
  let fallbackReason: String?

  private enum CodingKeys: String, CodingKey {
    case fulfillmentMethod = "fulfillment_method"
    case latencyMs = "latency_ms"
    case engineSelected = "engine_selected"
    case provider
    case sourcesSearched = "sources_searched"
    case simulationMatched = "simulation_matched"
    case estimatedWaitMs = "estimated_wait_ms"
    case fallbackReason = "fallback_reason"
  }
}

// MARK: - FulfillmentMethod

// How the content was generated.
enum FulfillmentMethod: String, Sendable, Codable, Equatable {
  // From curated library.
  case librarySearch = "library_search"

  // From external API.
  case apiSearch = "api_search"

  // Generated by AI.
  case aiGeneration = "ai_generation"

  // Rendered client-side (charts, graphics).
  case render

  // Matched to embed provider.
  case embedMatch = "embed_match"
}

// MARK: - SubagentResponse

// Response from a subagent after processing a request.
struct SubagentResponse: Sendable, Codable, Equatable {
  // The request ID this response corresponds to.
  let requestId: SubagentRequestID

  // Status of the response.
  let status: SubagentStatus

  // The generated block (nil if failed).
  let block: Block?

  // Error details (nil if successful).
  let error: SubagentError?

  // Metadata about fulfillment.
  let metadata: ResponseMetadata?

  private enum CodingKeys: String, CodingKey {
    case requestId = "request_id"
    case status
    case block
    case error
    case metadata
  }

  init(
    requestId: SubagentRequestID,
    status: SubagentStatus,
    block: Block? = nil,
    error: SubagentError? = nil,
    metadata: ResponseMetadata? = nil
  ) {
    self.requestId = requestId
    self.status = status
    self.block = block
    self.error = error
    self.metadata = metadata
  }

  // Whether the response was successful (ready status with a block).
  var isSuccess: Bool {
    status == .ready && block != nil
  }

  // Creates a successful response with a block.
  static func success(
    requestId: SubagentRequestID,
    block: Block,
    metadata: ResponseMetadata? = nil
  ) -> SubagentResponse {
    SubagentResponse(
      requestId: requestId,
      status: .ready,
      block: block,
      error: nil,
      metadata: metadata
    )
  }

  // Creates a failed response with an error.
  static func failure(requestId: SubagentRequestID, error: SubagentError) -> SubagentResponse {
    SubagentResponse(requestId: requestId, status: .failed, block: nil, error: error, metadata: nil)
  }
}

// MARK: - SubagentError

// Error details from a failed subagent request.
struct SubagentError: Sendable, Codable, Equatable {
  // Error code for programmatic handling.
  let code: String

  // Human-readable error message.
  let message: String

  // Additional error details.
  let details: [String: AnyCodable]?

  private enum CodingKeys: String, CodingKey {
    case code
    case message
    case details
  }

  init(code: String, message: String, details: [String: AnyCodable]? = nil) {
    self.code = code
    self.message = message
    self.details = details
  }
}

// MARK: - VisualRouterDecision

// Decision made by the visual router about which subagent to use.
struct VisualRouterDecision: Sendable, Codable, Equatable {
  // The selected visual type.
  let selectedType: VisualType

  // Explanation of why this type was chosen.
  let reasoning: String

  // Specific recommendation (e.g., "chartjs line chart", "phet projectile-motion").
  let specificRecommendation: String?

  private enum CodingKeys: String, CodingKey {
    case selectedType = "selected_type"
    case reasoning
    case specificRecommendation = "specific_recommendation"
  }

  init(
    selectedType: VisualType,
    reasoning: String,
    specificRecommendation: String? = nil
  ) {
    self.selectedType = selectedType
    self.reasoning = reasoning
    self.specificRecommendation = specificRecommendation
  }
}

// MARK: - VisualType

// The type of visual content.
enum VisualType: String, Sendable, Codable, Equatable {
  // Static images, diagrams, photos.
  case image

  // Interactive visualizations (Chart.js, p5.js, Three.js).
  case graphics

  // Embedded web tools (PhET, GeoGebra, Desmos, YouTube).
  case embed
}

// MARK: - ChatMessage

// A message in the conversation with Alan.
struct ChatMessage: Sendable, Codable, Equatable {
  let role: ChatRole
  let content: String

  init(role: ChatRole, content: String) {
    self.role = role
    self.content = content
  }
}

// MARK: - ChatRole

// The role of a message sender.
enum ChatRole: String, Sendable, Codable, Equatable {
  case user
  case assistant
}

// MARK: - NotebookContext

// Context about the current notebook for Alan.
struct NotebookContext: Sendable, Codable, Equatable {
  // The current notebook document ID.
  let documentId: String

  // Current blocks in the notebook (for context).
  let currentBlocks: [Block]?

  // The topic of the tutoring session.
  let sessionTopic: String?

  private enum CodingKeys: String, CodingKey {
    case documentId = "document_id"
    case currentBlocks = "current_blocks"
    case sessionTopic = "session_topic"
  }

  init(
    documentId: String,
    currentBlocks: [Block]? = nil,
    sessionTopic: String? = nil
  ) {
    self.documentId = documentId
    self.currentBlocks = currentBlocks
    self.sessionTopic = sessionTopic
  }
}

// MARK: - SessionModel

// Per-session user model that tracks student state throughout a tutoring session.
// Passed with each request and updated by Alan in each response.
struct SessionModel: Sendable, Codable, Equatable {
  // Unique identifier for this session.
  let sessionId: String

  // Number of turns in this session.
  var turnCount: Int

  // Current learning goal, if set.
  var goal: SessionGoal?

  // Status of concepts covered in this session.
  var concepts: [String: ConceptStatus]

  // Engagement and learning signals.
  var signals: SessionSignals

  // Facts learned about this student.
  var facts: [String]

  private enum CodingKeys: String, CodingKey {
    case sessionId = "session_id"
    case turnCount = "turn_count"
    case goal
    case concepts
    case signals
    case facts
  }

  init(
    sessionId: String,
    turnCount: Int = 0,
    goal: SessionGoal? = nil,
    concepts: [String: ConceptStatus] = [:],
    signals: SessionSignals = SessionSignals(),
    facts: [String] = []
  ) {
    self.sessionId = sessionId
    self.turnCount = turnCount
    self.goal = goal
    self.concepts = concepts
    self.signals = signals
    self.facts = facts
  }

  // Creates a new session model with default values.
  static func new(sessionId: String) -> SessionModel {
    SessionModel(sessionId: sessionId)
  }
}

// MARK: - SessionGoal

// A learning goal for the session.
struct SessionGoal: Sendable, Codable, Equatable {
  // Description of what the student wants to learn.
  var description: String

  // Current status of the goal.
  var status: GoalStatus

  // Progress toward the goal (0-100).
  var progress: Int

  enum GoalStatus: String, Sendable, Codable, Equatable {
    case active
    case completed
    case abandoned
  }

  init(description: String, status: GoalStatus = .active, progress: Int = 0) {
    self.description = description
    self.status = status
    self.progress = progress
  }
}

// MARK: - ConceptStatus

// Status of a concept in the session.
struct ConceptStatus: Sendable, Codable, Equatable {
  // Current learning status.
  var status: Status

  // Number of attempts/interactions with this concept.
  var attempts: Int

  enum Status: String, Sendable, Codable, Equatable {
    case introduced
    case practicing
    case mastered
    case struggling
  }

  init(status: Status = .introduced, attempts: Int = 0) {
    self.status = status
    self.attempts = attempts
  }
}

// MARK: - SessionSignals

// Engagement and learning signals detected during the session.
struct SessionSignals: Sendable, Codable, Equatable {
  // Current engagement level.
  var engagement: Engagement

  // Current frustration level.
  var frustration: Frustration

  // Current learning pace.
  var pace: Pace

  enum Engagement: String, Sendable, Codable, Equatable {
    case high
    case medium
    case low
  }

  enum Frustration: String, Sendable, Codable, Equatable {
    case none
    case mild
    case high
  }

  enum Pace: String, Sendable, Codable, Equatable {
    case fast
    case normal
    case slow
  }

  init(
    engagement: Engagement = .medium,
    frustration: Frustration = .none,
    pace: Pace = .normal
  ) {
    self.engagement = engagement
    self.frustration = frustration
    self.pace = pace
  }
}

// MARK: - TokenMetadata

// Token usage metadata from Alan's response.
struct TokenMetadata: Sendable, Codable, Equatable {
  let promptTokenCount: Int?
  let candidatesTokenCount: Int?
  let totalTokenCount: Int?

  private enum CodingKeys: String, CodingKey {
    case promptTokenCount = "prompt_token_count"
    case candidatesTokenCount = "candidates_token_count"
    case totalTokenCount = "total_token_count"
  }
}

// MARK: - AlanRequest

// Request sent to the Alan endpoint.
struct AlanRequest: Sendable, Codable, Equatable {
  let messages: [ChatMessage]
  let notebookContext: NotebookContext
  let sessionModel: SessionModel?

  private enum CodingKeys: String, CodingKey {
    case messages
    case notebookContext = "notebook_context"
    case sessionModel = "session_model"
  }

  init(
    messages: [ChatMessage],
    notebookContext: NotebookContext,
    sessionModel: SessionModel? = nil
  ) {
    self.messages = messages
    self.notebookContext = notebookContext
    self.sessionModel = sessionModel
  }
}

// AnyCodable is defined in GraphicsContent.swift - reused here for JSON flexibility.
