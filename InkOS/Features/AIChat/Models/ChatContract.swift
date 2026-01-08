// ChatContract.swift
// Defines the API contract for the AI Chat backend feature.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.
// The chat system calls Firebase Cloud Functions to interact with Gemini AI,
// gathers context from notebooks based on user-selected scope,
// and manages conversations in memory.

import Foundation

// MARK: - Message Role

// Distinguishes between user and assistant messages in a conversation.
enum MessageRole: String, Sendable, Codable, Equatable {
  case user
  case assistant
}

// MARK: - Chat Scope

// Defines the scope for gathering context from documents.
// The scope determines which notebooks or folders are included when building AI context.
enum ChatScope: Sendable, Codable, Equatable {
  // AI determines the best scope based on the query.
  case auto

  // No document context; pure chat interaction.
  case chatOnly

  // Include content from a specific notebook by ID.
  case specificNote(String)

  // Include content from all notebooks in a specific folder.
  case specificFolder(String)

  // Include content from all notebooks in the library.
  case allNotes

  // Include only the current page of the open notebook.
  case thisPage

  // Include all content from the currently open notebook.
  case thisNote

  // Include only the current selection in the editor.
  case selection

  // Let user pick another notebook from a list.
  case otherNote
}

// MARK: - Message Context Metadata

// Stores metadata about the context used for a specific message.
// Attached to user messages to track what documents were referenced.
struct MessageContextMetadata: Sendable, Codable, Equatable {
  // The scope that was used to gather context.
  let scope: ChatScope

  // IDs of documents that were included in the context.
  let documentIDs: [String]

  // Number of documents included.
  let documentCount: Int

  // Total character count of the gathered context.
  let characterCount: Int
}

// MARK: - Token Metadata

// Stores token usage information for a message exchange.
// Tracks actual token consumption as reported by the Gemini API.
struct TokenMetadata: Sendable, Codable, Equatable {
  // Number of tokens used for input (user message + context + history).
  let inputTokens: Int

  // Number of tokens used for the model's output response.
  // Nil for user messages (only available after assistant responds).
  let outputTokens: Int?

  // Total tokens consumed for this message exchange.
  // Sum of inputTokens and outputTokens (if available).
  let totalTokens: Int

  // Whether conversation history was truncated to fit token limits.
  // True if older messages were dropped to stay within budget.
  let contextTruncated: Bool

  // Number of messages included in the API request after truncation.
  // Useful for tracking how much history was preserved.
  let messagesIncluded: Int

  // Creates metadata with explicit total calculation.
  init(
    inputTokens: Int,
    outputTokens: Int?,
    totalTokens: Int,
    contextTruncated: Bool,
    messagesIncluded: Int
  ) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.totalTokens = totalTokens
    self.contextTruncated = contextTruncated
    self.messagesIncluded = messagesIncluded
  }

  // Convenience initializer that calculates totalTokens automatically.
  init(
    inputTokens: Int,
    outputTokens: Int?,
    contextTruncated: Bool,
    messagesIncluded: Int
  ) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.totalTokens = inputTokens + (outputTokens ?? 0)
    self.contextTruncated = contextTruncated
    self.messagesIncluded = messagesIncluded
  }
}

// MARK: - Chat Message

// Represents a single message in a conversation.
// Messages are immutable once created.
struct ChatMessage: Sendable, Codable, Identifiable, Equatable {
  // Unique identifier for this message.
  let id: String

  // ID of the conversation this message belongs to.
  let conversationID: String

  // Whether this is a user or assistant message.
  let role: MessageRole

  // The text content of the message.
  let content: String

  // When this message was created.
  let timestamp: Date

  // Context metadata for user messages (nil for assistant messages).
  let contextMetadata: MessageContextMetadata?

  // Token usage metadata (nil for legacy messages without token tracking).
  // Present for new messages after token management is implemented.
  let tokenMetadata: TokenMetadata?

  // Creates a message with all fields including token metadata.
  init(
    id: String,
    conversationID: String,
    role: MessageRole,
    content: String,
    timestamp: Date,
    contextMetadata: MessageContextMetadata?,
    tokenMetadata: TokenMetadata?
  ) {
    self.id = id
    self.conversationID = conversationID
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.contextMetadata = contextMetadata
    self.tokenMetadata = tokenMetadata
  }

  // Convenience initializer without token metadata for backwards compatibility.
  init(
    id: String,
    conversationID: String,
    role: MessageRole,
    content: String,
    timestamp: Date,
    contextMetadata: MessageContextMetadata?
  ) {
    self.id = id
    self.conversationID = conversationID
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.contextMetadata = contextMetadata
    self.tokenMetadata = nil
  }
}

// MARK: - Chat Conversation

// Represents a conversation containing multiple messages.
// Conversations are identified by a unique ID and track message order.
struct ChatConversation: Sendable, Codable, Identifiable, Equatable {
  // Unique identifier for this conversation.
  let id: String

  // When this conversation was created.
  let createdAt: Date

  // When this conversation was last updated.
  var updatedAt: Date

  // Ordered list of message IDs in this conversation.
  var messageIDs: [String]

  // The initial scope when the conversation was started.
  let initialScope: ChatScope?
}

// MARK: - Gathered Context

// Contains the extracted context from documents based on the specified scope.
// Passed to the AI as part of the conversation context.
struct GatheredContext: Sendable, Equatable {
  // The scope that was used to gather this context.
  let scope: ChatScope

  // The concatenated text content from all included documents.
  let text: String

  // IDs of documents that were included.
  let documentIDs: [String]

  // Number of documents included.
  let documentCount: Int

  // Total character count of the text.
  let characterCount: Int

  // Creates an empty context for chatOnly scope.
  static func empty(scope: ChatScope) -> GatheredContext {
    return GatheredContext(
      scope: scope,
      text: "",
      documentIDs: [],
      documentCount: 0,
      characterCount: 0
    )
  }
}

// MARK: - API Message

// Structure for messages sent to the Firebase Cloud Function.
// Matches the expected format of the sendMessage/streamMessage endpoints.
struct APIMessage: Sendable, Codable, Equatable {
  // Role of the message sender.
  let role: String

  // Content of the message.
  let content: String

  // Creates an API message from a ChatMessage.
  init(from message: ChatMessage) {
    self.role = message.role.rawValue
    self.content = message.content
  }

  // Creates an API message with explicit values.
  init(role: String, content: String) {
    self.role = role
    self.content = content
  }
}

// MARK: - Chat Client Protocol

// Protocol for the Firebase HTTP client that calls Cloud Functions.
// Handles both synchronous and streaming message endpoints.
protocol ChatClientProtocol: Actor {
  // Sends a message to the AI and returns the complete response.
  // messages: Array of conversation messages to send.
  // Returns: The AI's response text.
  // Throws: ChatError if the request fails.
  func sendMessage(messages: [APIMessage]) async throws -> String

  // Sends a message and returns a stream of response chunks.
  // messages: Array of conversation messages to send.
  // Returns: AsyncThrowingStream that yields text chunks.
  func streamMessage(messages: [APIMessage]) -> AsyncThrowingStream<String, Error>

  // Uploads a file attachment to the Gemini Files API via Cloud Function.
  // attachment: The file attachment containing base64 data and metadata.
  // Returns: UploadedFileReference with the file URI for use in multimodal messages.
  // Throws: ChatError.uploadFailed, ChatError.processingFailed, or ChatError.processingTimeout.
  func uploadFile(_ attachment: FileAttachment) async throws -> UploadedFileReference

  // Sends multimodal messages (with file attachments) and returns the complete response.
  // messages: Array of multimodal conversation messages to send.
  // Returns: The AI's response text.
  // Throws: ChatError if the request fails.
  func sendMessageMultimodal(messages: [APIMessageMultimodal]) async throws -> String

  // Sends multimodal messages and returns a stream of response chunks.
  // messages: Array of multimodal conversation messages to send.
  // Returns: AsyncThrowingStream that yields text chunks.
  func streamMessageMultimodal(messages: [APIMessageMultimodal]) -> AsyncThrowingStream<String, Error>
}

// MARK: - Context Gatherer Protocol

// Protocol for extracting context from notebooks and folders.
// Uses the existing ContentExtractor from AIIndexing module.
protocol ContextGathererProtocol: Actor {
  // Gathers context based on the specified scope.
  // scope: The ChatScope determining which documents to include.
  // currentNoteID: ID of the currently open notebook (for thisNote/thisPage).
  // currentFolderID: ID of the current folder context.
  // Returns: GatheredContext with extracted text.
  // Throws: ChatError if extraction fails.
  func gatherContext(
    scope: ChatScope,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> GatheredContext

  // Resolves auto scope by calling AI to determine the best scope.
  // query: The user's query text.
  // Returns: Resolved ChatScope (never .auto).
  // Throws: ChatError if resolution fails.
  func resolveAutoScope(query: String) async throws -> ChatScope
}

// MARK: - Chat Storage Protocol

// Protocol for in-memory storage of conversations and messages.
// Provides CRUD operations for managing chat history.
protocol ChatStorageProtocol: Actor {
  // Creates a new conversation.
  // initialScope: Optional initial scope for the conversation.
  // Returns: The newly created conversation.
  func createConversation(initialScope: ChatScope?) -> ChatConversation

  // Retrieves a conversation by ID.
  // id: The conversation ID.
  // Returns: The conversation if found, nil otherwise.
  func getConversation(id: String) -> ChatConversation?

  // Updates an existing conversation.
  // conversation: The conversation with updated values.
  func updateConversation(_ conversation: ChatConversation)

  // Deletes a conversation and its messages.
  // id: The conversation ID to delete.
  func deleteConversation(id: String)

  // Adds a message to storage.
  // message: The message to add.
  // Updates the parent conversation's messageIDs and updatedAt.
  func addMessage(_ message: ChatMessage)

  // Retrieves all messages for a conversation.
  // conversationID: The conversation ID.
  // Returns: Messages sorted by timestamp ascending.
  func getMessages(conversationID: String) -> [ChatMessage]

  // Retrieves a single message by ID.
  // id: The message ID.
  // Returns: The message if found, nil otherwise.
  func getMessage(id: String) -> ChatMessage?

  // Retrieves all conversations.
  // Returns: All conversations sorted by updatedAt descending.
  func getAllConversations() -> [ChatConversation]

  // Truncates a conversation from a specific message point.
  // Permanently deletes the specified message and all subsequent messages.
  // conversationID: The ID of the conversation to truncate.
  // fromMessageID: The ID of the message to start deletion from (inclusive).
  // Returns: The updated conversation with truncated messageIDs.
  // Throws: ChatError.conversationNotFound if conversation doesn't exist.
  // Throws: ChatError.messageNotFound if message doesn't exist in storage.
  // Throws: ChatError.messageNotInConversation if message exists but not in this conversation.
  //
  // SCENARIO: Truncate conversation from middle message
  // GIVEN: A conversation with messages ["msg-1", "msg-2", "msg-3", "msg-4", "msg-5"]
  // WHEN: truncateConversation(conversationID: "conv-1", fromMessageID: "msg-3") is called
  // THEN: conversation.messageIDs becomes ["msg-1", "msg-2"]
  //  AND: Messages msg-3, msg-4, msg-5 are deleted from storage
  //  AND: conversation.updatedAt is updated to current time
  //  AND: Method returns the updated conversation
  //
  // SCENARIO: Truncate from first message (clear entire history)
  // GIVEN: A conversation with messages ["msg-1", "msg-2", "msg-3"]
  // WHEN: truncateConversation(conversationID: "conv-1", fromMessageID: "msg-1") is called
  // THEN: conversation.messageIDs becomes []
  //  AND: All messages are deleted from storage
  //  AND: conversation.updatedAt is updated to current time
  //  AND: Method returns the updated conversation with empty messageIDs
  //
  // SCENARIO: Truncate from last message (remove only last message)
  // GIVEN: A conversation with messages ["msg-1", "msg-2", "msg-3"]
  // WHEN: truncateConversation(conversationID: "conv-1", fromMessageID: "msg-3") is called
  // THEN: conversation.messageIDs becomes ["msg-1", "msg-2"]
  //  AND: Only msg-3 is deleted from storage
  //  AND: conversation.updatedAt is updated to current time
  //
  // EDGE CASE: Conversation not found
  // GIVEN: No conversation exists with ID "nonexistent"
  // WHEN: truncateConversation(conversationID: "nonexistent", fromMessageID: "msg-1") is called
  // THEN: Throws ChatError.conversationNotFound(conversationID: "nonexistent")
  //  AND: No storage changes occur
  //
  // EDGE CASE: Message not found in storage
  // GIVEN: A conversation with messages ["msg-1", "msg-2"]
  //  AND: Message "msg-99" does not exist in storage
  // WHEN: truncateConversation(conversationID: "conv-1", fromMessageID: "msg-99") is called
  // THEN: Throws ChatError.messageNotFound(messageID: "msg-99")
  //  AND: No storage changes occur
  //
  // EDGE CASE: Message exists but not in conversation
  // GIVEN: Conversation "conv-1" with messages ["msg-1", "msg-2"]
  //  AND: Conversation "conv-2" with messages ["msg-3", "msg-4"]
  // WHEN: truncateConversation(conversationID: "conv-1", fromMessageID: "msg-3") is called
  // THEN: Throws ChatError.messageNotInConversation(messageID: "msg-3", conversationID: "conv-1")
  //  AND: No storage changes occur
  //
  // EDGE CASE: Empty conversation
  // GIVEN: A conversation with messageIDs = []
  //  AND: Message "msg-1" exists in storage (orphaned)
  // WHEN: truncateConversation(conversationID: "conv-1", fromMessageID: "msg-1") is called
  // THEN: Throws ChatError.messageNotInConversation(messageID: "msg-1", conversationID: "conv-1")
  //  AND: No storage changes occur
  func truncateConversation(conversationID: String, fromMessageID: String) throws -> ChatConversation
}

// MARK: - Chat Service Protocol

// Protocol for the main chat orchestration service.
// Coordinates context gathering, Firebase calls, and storage.
protocol ChatServiceProtocol: Actor {
  // Sends a message and waits for complete response.
  // text: The user's message text.
  // attachment: Optional file attachment to include with the message.
  // scope: The ChatScope for context gathering.
  // conversationID: Optional existing conversation ID (creates new if nil).
  // currentNoteID: ID of currently open notebook.
  // currentFolderID: ID of current folder context.
  // Returns: The assistant's response message.
  // Throws: ChatError if any step fails.
  func sendMessage(
    text: String,
    attachment: FileAttachment?,
    scope: ChatScope,
    conversationID: String?,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> ChatMessage

  // Sends a message and returns a stream for the response.
  // Returns the user message immediately plus a stream for AI response.
  // text: The user's message text.
  // attachment: Optional file attachment to include with the message.
  // scope: The ChatScope for context gathering.
  // conversationID: Optional existing conversation ID.
  // currentNoteID: ID of currently open notebook.
  // currentFolderID: ID of current folder context.
  // Returns: Tuple of user message and response stream.
  // Throws: ChatError if initialization fails.
  func streamMessage(
    text: String,
    attachment: FileAttachment?,
    scope: ChatScope,
    conversationID: String?,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> (userMessage: ChatMessage, stream: AsyncThrowingStream<String, Error>)

  // Saves the accumulated streaming response as an assistant message.
  // conversationID: The conversation to add the message to.
  // content: The complete response text.
  // Returns: The saved assistant message.
  // Throws: ChatError if conversation not found.
  func saveStreamedResponse(
    conversationID: String,
    content: String
  ) async throws -> ChatMessage

  // Cancels an active streaming response for the given conversation.
  // conversationID: The ID of the conversation with an active stream.
  // Note: If no stream is active for this conversation, this is a no-op.
  func cancelStream(conversationID: String) async

  // Returns whether a stream is currently active for the given conversation.
  // conversationID: The ID of the conversation to check.
  // Returns: true if a stream is active, false otherwise.
  func isStreamActive(conversationID: String) async -> Bool

  // Restarts a conversation from a specific message point by truncating.
  // Permanently deletes the specified message and all subsequent messages.
  // This is a destructive operation that cannot be undone.
  // conversationID: The ID of the conversation to restart from.
  // messageID: The ID of the message to start deletion from (inclusive).
  // Returns: The updated conversation after truncation.
  // Throws: ChatError.conversationNotFound if conversation doesn't exist.
  // Throws: ChatError.messageNotFound if message doesn't exist in storage.
  // Throws: ChatError.messageNotInConversation if message exists but not in this conversation.
  //
  // SCENARIO: Restart conversation from middle message
  // GIVEN: A conversation with messages ["msg-1", "msg-2", "msg-3", "msg-4", "msg-5"]
  // WHEN: restartConversationFromMessage(conversationID: "conv-1", messageID: "msg-3") is called
  // THEN: Delegates to storage.truncateConversation
  //  AND: Returns the updated conversation with messageIDs ["msg-1", "msg-2"]
  //
  // SCENARIO: Restart from first message
  // GIVEN: A conversation with messages ["msg-1", "msg-2", "msg-3"]
  // WHEN: restartConversationFromMessage(conversationID: "conv-1", messageID: "msg-1") is called
  // THEN: Returns conversation with empty messageIDs
  //  AND: User can start fresh conversation from beginning
  //
  // EDGE CASE: All error cases propagate from storage layer
  // GIVEN: Any error condition from truncateConversation
  // WHEN: The error is thrown
  // THEN: The same error propagates to the caller unchanged
  func restartConversationFromMessage(conversationID: String, messageID: String) async throws -> ChatConversation

  // Prepares a conversation for message editing by validating the message role,
  // cancelling any active stream, and truncating the conversation.
  // This method orchestrates the edit workflow by:
  // 1. Retrieving the message from storage to validate its role
  // 2. Validating that the message has role .user (only user messages can be edited)
  // 3. Cancelling any active stream for the conversation (idempotent, no-op if none)
  // 4. Truncating the conversation from the specified message (inclusive)
  // 5. Returning the updated conversation so the frontend can re-send the edited message
  //
  // conversationID: The ID of the conversation containing the message to edit.
  // messageID: The ID of the message to edit. Must be a user message.
  // Returns: The updated ChatConversation after truncation, ready for the edited message.
  // Throws: ChatError.conversationNotFound if the conversation does not exist.
  // Throws: ChatError.messageNotFound if the message does not exist in storage.
  // Throws: ChatError.messageNotInConversation if the message exists but is not in this conversation.
  // Throws: ChatError.invalidMessageRole if the message is not a user message.
  //
  // SCENARIO: Successful edit of user message with no active stream
  // GIVEN: A conversation "conv-1" with messages ["msg-1" (user), "msg-2" (assistant), "msg-3" (user), "msg-4" (assistant)]
  //  AND: No stream is currently active for this conversation
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-3") is called
  // THEN: The method retrieves msg-3 and verifies role is .user
  //  AND: cancelStream is called (no-op since no active stream)
  //  AND: restartConversationFromMessage is called with conversationID and messageID
  //  AND: Returns conversation with messageIDs ["msg-1", "msg-2"]
  //  AND: Messages msg-3 and msg-4 are deleted from storage
  //
  // SCENARIO: Successful edit of user message with active stream (stream cancelled)
  // GIVEN: A conversation "conv-1" with messages ["msg-1" (user), "msg-2" (assistant), "msg-3" (user)]
  //  AND: A stream is currently active for this conversation (assistant is responding)
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-3") is called
  // THEN: The method retrieves msg-3 and verifies role is .user
  //  AND: cancelStream is called and cancels the active stream
  //  AND: restartConversationFromMessage is called with conversationID and messageID
  //  AND: Returns conversation with messageIDs ["msg-1", "msg-2"]
  //  AND: Message msg-3 is deleted from storage
  //
  // SCENARIO: Error when trying to edit an assistant message
  // GIVEN: A conversation "conv-1" with messages ["msg-1" (user), "msg-2" (assistant), "msg-3" (user)]
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-2") is called
  // THEN: Throws ChatError.invalidMessageRole(messageID: "msg-2", role: .assistant, operation: "edit")
  //  AND: No stream cancellation occurs
  //  AND: No conversation truncation occurs
  //  AND: The conversation remains unchanged
  //
  // SCENARIO: Error when message not found
  // GIVEN: A conversation "conv-1" with messages ["msg-1", "msg-2"]
  //  AND: Message "msg-99" does not exist in storage
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-99") is called
  // THEN: Throws ChatError.messageNotFound(messageID: "msg-99")
  //  AND: No stream cancellation occurs
  //  AND: No conversation truncation occurs
  //
  // SCENARIO: Error when message exists but not in conversation
  // GIVEN: Conversation "conv-1" with messages ["msg-1", "msg-2"]
  //  AND: Conversation "conv-2" with messages ["msg-3", "msg-4"]
  //  AND: Message "msg-3" exists in storage (belongs to conv-2)
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-3") is called
  // THEN: Throws ChatError.messageNotInConversation(messageID: "msg-3", conversationID: "conv-1")
  //  AND: No stream cancellation occurs
  //  AND: No conversation truncation occurs
  //
  // SCENARIO: Error when conversation not found
  // GIVEN: No conversation exists with ID "nonexistent"
  // WHEN: editMessage(conversationID: "nonexistent", messageID: "msg-1") is called
  // THEN: Throws ChatError.conversationNotFound(conversationID: "nonexistent")
  //  AND: No further operations are attempted
  //
  // EDGE CASE: Edit first message in conversation (truncates entire history)
  // GIVEN: A conversation "conv-1" with messages ["msg-1" (user), "msg-2" (assistant), "msg-3" (user)]
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-1") is called
  // THEN: Returns conversation with messageIDs = []
  //  AND: All messages (msg-1, msg-2, msg-3) are deleted from storage
  //  AND: The conversation is ready for a fresh start with the edited message
  //
  // EDGE CASE: Edit last message in conversation (removes only that message)
  // GIVEN: A conversation "conv-1" with messages ["msg-1" (user), "msg-2" (assistant), "msg-3" (user)]
  //  AND: msg-3 is the last message (most recent user message)
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-3") is called
  // THEN: Returns conversation with messageIDs ["msg-1", "msg-2"]
  //  AND: Only msg-3 is deleted from storage
  //
  // EDGE CASE: Edit only message in conversation
  // GIVEN: A conversation "conv-1" with messages ["msg-1" (user)]
  //  AND: msg-1 is the only message in the conversation
  // WHEN: editMessage(conversationID: "conv-1", messageID: "msg-1") is called
  // THEN: Returns conversation with messageIDs = []
  //  AND: msg-1 is deleted from storage
  //  AND: The conversation exists but has no messages
  func editMessage(conversationID: String, messageID: String) async throws -> ChatConversation
}

// MARK: - Chat Error

// Errors that can occur during chat operations.
// All cases conform to LocalizedError for user-friendly messages.
enum ChatError: LocalizedError, Equatable {
  // Request was malformed or invalid.
  case invalidRequest(reason: String)

  // Messages array was empty when it should not be.
  case emptyMessages

  // Network request failed.
  case networkError(reason: String)

  // HTTP request returned an error status.
  case requestFailed(statusCode: Int, message: String)

  // Response could not be parsed.
  case invalidResponse(reason: String)

  // Streaming connection failed.
  case streamingFailed(reason: String)

  // Context extraction from documents failed.
  case contextExtractionFailed(reason: String)

  // Specified document was not found.
  case documentNotFound(documentID: String)

  // Specified folder was not found.
  case folderNotFound(folderID: String)

  // Specified conversation was not found.
  case conversationNotFound(conversationID: String)

  // Specified message was not found in storage.
  case messageNotFound(messageID: String)

  // Message exists in storage but is not part of the specified conversation.
  case messageNotInConversation(messageID: String, conversationID: String)

  // Auto scope resolution failed.
  case scopeResolutionFailed(reason: String)

  // Attempted an operation on a message with an invalid role.
  // For example, trying to edit an assistant message when only user messages can be edited.
  case invalidMessageRole(messageID: String, role: MessageRole, operation: String)

  // File upload to Gemini Files API failed.
  case uploadFailed(reason: String)

  // File processing by Gemini failed (file may be corrupted).
  case processingFailed(filename: String)

  // File processing by Gemini timed out.
  case processingTimeout(filename: String)

  var errorDescription: String? {
    switch self {
    case .invalidRequest(let reason):
      return "Invalid request: \(reason)"
    case .emptyMessages:
      return "Cannot send an empty message"
    case .networkError(let reason):
      return "Network error: \(reason)"
    case .requestFailed(let statusCode, let message):
      return "Request failed (\(statusCode)): \(message)"
    case .invalidResponse(let reason):
      return "Invalid response: \(reason)"
    case .streamingFailed(let reason):
      return "Streaming failed: \(reason)"
    case .contextExtractionFailed(let reason):
      return "Failed to extract context: \(reason)"
    case .documentNotFound(let documentID):
      return "Document not found: \(documentID)"
    case .folderNotFound(let folderID):
      return "Folder not found: \(folderID)"
    case .conversationNotFound(let conversationID):
      return "Conversation not found: \(conversationID)"
    case .messageNotFound(let messageID):
      return "Message not found: \(messageID)"
    case .messageNotInConversation(let messageID, let conversationID):
      return "Message \(messageID) is not in conversation \(conversationID)"
    case .scopeResolutionFailed(let reason):
      return "Could not determine search scope: \(reason)"
    case .invalidMessageRole(let messageID, let role, let operation):
      return "Cannot \(operation) message \(messageID): only user messages can be edited, but this message has role '\(role.rawValue)'"
    case .uploadFailed(let reason):
      return "File upload failed: \(reason)"
    case .processingFailed(let filename):
      return "Processing failed for '\(filename)'. The file may be corrupted."
    case .processingTimeout(let filename):
      return "Processing timed out for '\(filename)'. Please try again."
    }
  }

  static func == (lhs: ChatError, rhs: ChatError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidRequest(let lhsReason), .invalidRequest(let rhsReason)):
      return lhsReason == rhsReason
    case (.emptyMessages, .emptyMessages):
      return true
    case (.networkError(let lhsReason), .networkError(let rhsReason)):
      return lhsReason == rhsReason
    case (.requestFailed(let lhsCode, let lhsMsg), .requestFailed(let rhsCode, let rhsMsg)):
      return lhsCode == rhsCode && lhsMsg == rhsMsg
    case (.invalidResponse(let lhsReason), .invalidResponse(let rhsReason)):
      return lhsReason == rhsReason
    case (.streamingFailed(let lhsReason), .streamingFailed(let rhsReason)):
      return lhsReason == rhsReason
    case (.contextExtractionFailed(let lhsReason), .contextExtractionFailed(let rhsReason)):
      return lhsReason == rhsReason
    case (.documentNotFound(let lhsID), .documentNotFound(let rhsID)):
      return lhsID == rhsID
    case (.folderNotFound(let lhsID), .folderNotFound(let rhsID)):
      return lhsID == rhsID
    case (.conversationNotFound(let lhsID), .conversationNotFound(let rhsID)):
      return lhsID == rhsID
    case (.messageNotFound(let lhsID), .messageNotFound(let rhsID)):
      return lhsID == rhsID
    case (.messageNotInConversation(let lhsMsgID, let lhsConvID), .messageNotInConversation(let rhsMsgID, let rhsConvID)):
      return lhsMsgID == rhsMsgID && lhsConvID == rhsConvID
    case (.scopeResolutionFailed(let lhsReason), .scopeResolutionFailed(let rhsReason)):
      return lhsReason == rhsReason
    case (.invalidMessageRole(let lhsMsgID, let lhsRole, let lhsOp), .invalidMessageRole(let rhsMsgID, let rhsRole, let rhsOp)):
      return lhsMsgID == rhsMsgID && lhsRole == rhsRole && lhsOp == rhsOp
    case (.uploadFailed(let lhsReason), .uploadFailed(let rhsReason)):
      return lhsReason == rhsReason
    case (.processingFailed(let lhsFilename), .processingFailed(let rhsFilename)):
      return lhsFilename == rhsFilename
    case (.processingTimeout(let lhsFilename), .processingTimeout(let rhsFilename)):
      return lhsFilename == rhsFilename
    default:
      return false
    }
  }
}

// MARK: - Configuration

// Configuration for the chat system.
// Contains Firebase project settings and endpoint URLs.
struct ChatConfiguration: Sendable {
  // Firebase project ID.
  let projectID: String

  // Firebase Cloud Functions region.
  let region: String

  // Base URL for Cloud Functions.
  var functionsBaseURL: URL {
    URL(string: "https://\(region)-\(projectID).cloudfunctions.net")!
  }

  // URL for the sendMessage endpoint.
  var sendMessageURL: URL {
    functionsBaseURL.appendingPathComponent("sendMessage")
  }

  // URL for the streamMessage endpoint.
  var streamMessageURL: URL {
    functionsBaseURL.appendingPathComponent("streamMessage")
  }

  // URL for the uploadFile endpoint.
  var uploadFileURL: URL {
    functionsBaseURL.appendingPathComponent("uploadFile")
  }

  // Default production configuration.
  static let `default` = ChatConfiguration(
    projectID: "inkos-f58f1",
    region: "us-central1"
  )

  // Configuration for testing with mock endpoints.
  static func testing(baseURL: URL) -> ChatConfiguration {
    // For testing, we create a configuration that will use mock URLs.
    // The actual URL override happens in the mock client.
    return ChatConfiguration(
      projectID: "test-project",
      region: "us-central1"
    )
  }
}

// MARK: - Constants

// Constants for token-based context management.
// Replaces deprecated character-based and message-count-based limits.
enum TokenBudgetConstants {
  // Gemini 1.5 Pro maximum context window size.
  static let geminiMaxTokens = 1_048_576

  // Tokens reserved for system prompt and formatting overhead.
  static let systemReserveTokens = 10_000

  // Buffer reserved for the model's response generation.
  static let responseBufferTokens = 8_192

  // Maximum tokens available for user input (messages + context).
  // Calculated as: geminiMaxTokens - systemReserveTokens - responseBufferTokens
  static let maxInputTokens = 1_030_384

  // Maximum tokens to allocate for document context.
  static let maxContextTokens = 500_000

  // Maximum tokens to allocate for conversation history.
  // Calculated as: maxInputTokens - maxContextTokens
  static let maxConversationHistoryTokens = 530_384

  // Approximate characters per token for estimation.
  static let charsPerToken: Double = 4.0
}

// Constants for chat system configuration.
enum ChatConstants {
  // Timeout for non-streaming requests in seconds.
  static let requestTimeout: TimeInterval = 30

  // Timeout for streaming requests in seconds.
  static let streamingTimeout: TimeInterval = 120

  // Timeout for file uploads in seconds (5 minutes for large files).
  static let uploadTimeout: TimeInterval = 300

  // Maximum notebooks to include from a folder.
  static let maxNotebooksPerFolder = 10

  // Maximum notebooks to include for allNotes scope.
  static let maxNotebooksForAllNotes = 20

  // System prompt prefix for context.
  static let contextSystemPromptPrefix = """
    You are an AI assistant helping the user with their notes.
    The following is context from the user's notebooks:

    """

  // System prompt suffix after context.
  static let contextSystemPromptSuffix = """

    Use this context to answer the user's questions.
    If the answer is not in the context, say so.
    """
}
