// ChatService.swift
// Main chat orchestration service that coordinates all components.
// Manages the flow: context gathering → Firebase call → storage.

import Foundation

// Actor for orchestrating chat operations.
// Coordinates between ContextGatherer, ChatClient, and ChatStorage.
actor ChatService: ChatServiceProtocol {

  // Firebase client for AI interactions.
  private let chatClient: any ChatClientProtocol

  // Context gatherer for extracting notebook content.
  private let contextGatherer: any ContextGathererProtocol

  // Storage for conversations and messages.
  private let storage: any ChatStorageProtocol

  // Track active streaming tasks by conversation ID for cancellation support.
  private var activeStreamTasks: [String: Task<Void, Never>] = [:]

  // Creates a chat service with the specified dependencies.
  init(
    chatClient: any ChatClientProtocol,
    contextGatherer: any ContextGathererProtocol,
    storage: any ChatStorageProtocol
  ) {
    self.chatClient = chatClient
    self.contextGatherer = contextGatherer
    self.storage = storage
  }

  // Convenience initializer with default dependencies.
  init() {
    let config = ChatConfiguration.default
    let client = FirebaseChatClient(configuration: config)
    let bundleManager = BundleManager.shared
    let contentExtractor = ContentExtractor()

    self.chatClient = client
    self.contextGatherer = ContextGatherer(
      bundleManager: bundleManager,
      contentExtractor: contentExtractor,
      chatClient: client
    )
    self.storage = ChatStorage.shared
  }

  // Sends a message and waits for the complete response.
  func sendMessage(
    text: String,
    attachment: FileAttachment?,
    scope: ChatScope,
    conversationID: String?,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> ChatMessage {
    // Validate input.
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else {
      throw ChatError.invalidRequest(reason: "Message text cannot be empty")
    }

    // Create or get conversation.
    let conversation: ChatConversation
    if let existingID = conversationID {
      guard let existing = await storage.getConversation(id: existingID) else {
        throw ChatError.conversationNotFound(conversationID: existingID)
      }
      conversation = existing
    } else {
      conversation = await storage.createConversation(initialScope: scope)
    }

    // Resolve Auto scope if needed.
    let resolvedScope: ChatScope
    if case .auto = scope {
      resolvedScope = try await contextGatherer.resolveAutoScope(query: trimmedText)
    } else {
      resolvedScope = scope
    }

    // Gather context based on resolved scope.
    let gatheredContext = try await contextGatherer.gatherContext(
      scope: resolvedScope,
      currentNoteID: currentNoteID,
      currentFolderID: currentFolderID
    )

    // Create user message with context embedded.
    let userMessageContent: String
    if gatheredContext.text.isEmpty {
      userMessageContent = trimmedText
    } else {
      userMessageContent = "\(gatheredContext.text)\n\n---\n\nUser: \(trimmedText)"
    }

    let userMessage = ChatMessage(
      id: UUID().uuidString,
      conversationID: conversation.id,
      role: .user,
      content: userMessageContent,
      timestamp: Date(),
      contextMetadata: MessageContextMetadata(
        scope: gatheredContext.scope,
        documentIDs: gatheredContext.documentIDs,
        documentCount: gatheredContext.documentCount,
        characterCount: gatheredContext.characterCount
      )
    )

    // Save user message.
    await storage.addMessage(userMessage)

    // Upload attachment if provided.
    var uploadedFileRef: UploadedFileReference?
    if let attachment = attachment {
      uploadedFileRef = try await chatClient.uploadFile(attachment)
    }

    // Build API message array from conversation history.
    let allMessages = await storage.getMessages(conversationID: conversation.id)

    // Call Firebase to get AI response.
    let responseText: String
    if let fileRef = uploadedFileRef {
      // Build multimodal request with file attachment.
      let apiMessages = buildAPIMessagesMultimodal(
        messages: allMessages,
        newMessage: userMessage,
        fileRef: fileRef
      )
      responseText = try await chatClient.sendMessageMultimodal(messages: apiMessages)
    } else {
      // Text-only request (existing path).
      let apiMessages = buildAPIMessages(messages: allMessages, newMessage: userMessage)
      responseText = try await chatClient.sendMessage(messages: apiMessages)
    }

    // Create and save assistant message.
    let assistantMessage = ChatMessage(
      id: UUID().uuidString,
      conversationID: conversation.id,
      role: .assistant,
      content: responseText,
      timestamp: Date(),
      contextMetadata: nil
    )
    await storage.addMessage(assistantMessage)

    return assistantMessage
  }

  // Sends a message and returns a stream for the response.
  func streamMessage(
    text: String,
    attachment: FileAttachment?,
    scope: ChatScope,
    conversationID: String?,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> (userMessage: ChatMessage, stream: AsyncThrowingStream<String, Error>) {
    // Validate input.
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else {
      throw ChatError.invalidRequest(reason: "Message text cannot be empty")
    }

    // Create or get conversation.
    let conversation: ChatConversation
    if let existingID = conversationID {
      guard let existing = await storage.getConversation(id: existingID) else {
        throw ChatError.conversationNotFound(conversationID: existingID)
      }
      conversation = existing
    } else {
      conversation = await storage.createConversation(initialScope: scope)
    }

    // Resolve Auto scope if needed.
    let resolvedScope: ChatScope
    if case .auto = scope {
      resolvedScope = try await contextGatherer.resolveAutoScope(query: trimmedText)
    } else {
      resolvedScope = scope
    }

    // Gather context.
    let gatheredContext = try await contextGatherer.gatherContext(
      scope: resolvedScope,
      currentNoteID: currentNoteID,
      currentFolderID: currentFolderID
    )

    // Create user message with context.
    let userMessageContent: String
    if gatheredContext.text.isEmpty {
      userMessageContent = trimmedText
    } else {
      userMessageContent = "\(gatheredContext.text)\n\n---\n\nUser: \(trimmedText)"
    }

    let userMessage = ChatMessage(
      id: UUID().uuidString,
      conversationID: conversation.id,
      role: .user,
      content: userMessageContent,
      timestamp: Date(),
      contextMetadata: MessageContextMetadata(
        scope: gatheredContext.scope,
        documentIDs: gatheredContext.documentIDs,
        documentCount: gatheredContext.documentCount,
        characterCount: gatheredContext.characterCount
      )
    )

    // Save user message.
    await storage.addMessage(userMessage)

    // Upload attachment if provided.
    var uploadedFileRef: UploadedFileReference?
    if let attachment = attachment {
      uploadedFileRef = try await chatClient.uploadFile(attachment)
    }

    // Build API messages.
    let allMessages = await storage.getMessages(conversationID: conversation.id)

    // Get the original stream from the client.
    let originalStream: AsyncThrowingStream<String, Error>
    if let fileRef = uploadedFileRef {
      // Build multimodal request with file attachment.
      let apiMessages = buildAPIMessagesMultimodal(
        messages: allMessages,
        newMessage: userMessage,
        fileRef: fileRef
      )
      originalStream = await chatClient.streamMessageMultimodal(messages: apiMessages)
    } else {
      // Text-only request (existing path).
      let apiMessages = buildAPIMessages(messages: allMessages, newMessage: userMessage)
      originalStream = await chatClient.streamMessage(messages: apiMessages)
    }

    // Create a wrapped stream that handles task tracking and cleanup.
    let wrappedStream = AsyncThrowingStream<String, Error> { continuation in
      let streamTask = Task {
        do {
          for try await chunk in originalStream {
            // Check for cancellation.
            guard !Task.isCancelled else {
              continuation.finish(throwing: CancellationError())
              return
            }
            continuation.yield(chunk)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }

        // Clean up task reference when stream completes.
        self.removeActiveStreamTask(conversationID: conversation.id)
      }

      // Store the task for cancellation.
      Task {
        self.storeActiveStreamTask(streamTask, conversationID: conversation.id)
      }

      // Handle cancellation from continuation.
      continuation.onTermination = { @Sendable _ in
        streamTask.cancel()
      }
    }

    return (userMessage, wrappedStream)
  }

  // Saves the accumulated streaming response as an assistant message.
  func saveStreamedResponse(
    conversationID: String,
    content: String
  ) async throws -> ChatMessage {
    // Verify conversation exists.
    guard await storage.getConversation(id: conversationID) != nil else {
      throw ChatError.conversationNotFound(conversationID: conversationID)
    }

    // Create assistant message.
    let assistantMessage = ChatMessage(
      id: UUID().uuidString,
      conversationID: conversationID,
      role: .assistant,
      content: content,
      timestamp: Date(),
      contextMetadata: nil
    )

    // Save to storage.
    await storage.addMessage(assistantMessage)

    return assistantMessage
  }

  // Cancels an active streaming response for the given conversation.
  func cancelStream(conversationID: String) async {
    guard let task = activeStreamTasks[conversationID] else {
      // No active stream for this conversation - no-op.
      return
    }

    // Cancel the task.
    task.cancel()

    // Remove from tracking (cleanup will happen in stream wrapper).
    activeStreamTasks.removeValue(forKey: conversationID)
  }

  // Returns whether a stream is currently active for the given conversation.
  func isStreamActive(conversationID: String) async -> Bool {
    return activeStreamTasks[conversationID] != nil
  }

  // Restarts a conversation from a specific message point by truncating.
  // Permanently deletes the specified message and all subsequent messages.
  // This is a destructive operation that cannot be undone.
  func restartConversationFromMessage(conversationID: String, messageID: String) async throws -> ChatConversation {
    // Delegate to storage layer, which handles all validation and truncation.
    return try await storage.truncateConversation(
      conversationID: conversationID,
      fromMessageID: messageID
    )
  }

  // Prepares a conversation for message editing by validating role and truncating.
  // Only user messages can be edited. Assistant messages will throw invalidMessageRole.
  // Cancels any active stream before truncating.
  func editMessage(conversationID: String, messageID: String) async throws -> ChatConversation {
    // Step 1: Retrieve the message from storage to validate its role.
    guard let message = await storage.getMessage(id: messageID) else {
      throw ChatError.messageNotFound(messageID: messageID)
    }

    // Step 2: Validate that only user messages can be edited.
    guard message.role == .user else {
      throw ChatError.invalidMessageRole(
        messageID: messageID,
        role: message.role,
        operation: "edit"
      )
    }

    // Step 3: Cancel any active stream for the conversation (idempotent, safe even if no stream exists).
    await cancelStream(conversationID: conversationID)

    // Step 4: Delegate to restartConversationFromMessage to handle truncation.
    // This validates conversation existence and message membership, then truncates.
    return try await restartConversationFromMessage(
      conversationID: conversationID,
      messageID: messageID
    )
  }

  // MARK: - Private Methods

  // Builds the API message array for sending to Firebase.
  // Uses token-based limiting instead of message count.
  // Strips context from old user messages to save tokens.
  private func buildAPIMessages(
    messages: [ChatMessage],
    newMessage: ChatMessage
  ) -> [APIMessage] {
    // Start with the newest message (always included).
    var includedMessages: [ChatMessage] = [newMessage]
    var estimatedTokens = estimateTokenCount(newMessage.content)

    // Add older messages in reverse order until approaching token limit.
    for message in messages.reversed() {
      // Skip if this is the new message (already included).
      guard message.id != newMessage.id else { continue }

      // Strip context from old user messages to save tokens.
      let processedContent: String
      if message.role == .user && message.contextMetadata != nil {
        processedContent = extractUserTextFromMessage(message.content)
      } else {
        processedContent = message.content
      }

      // Estimate tokens for this message.
      let messageTokens = estimateTokenCount(processedContent)

      // Stop if adding this message would exceed the budget.
      // Use maxConversationHistoryTokens as the budget for history.
      if estimatedTokens + messageTokens > TokenBudgetConstants.maxConversationHistoryTokens {
        break
      }

      // Create the processed message.
      let processedMessage = ChatMessage(
        id: message.id,
        conversationID: message.conversationID,
        role: message.role,
        content: processedContent,
        timestamp: message.timestamp,
        contextMetadata: nil
      )

      // Insert at the beginning to maintain chronological order.
      includedMessages.insert(processedMessage, at: 0)
      estimatedTokens += messageTokens
    }

    // Convert to API messages.
    return includedMessages.map { APIMessage(from: $0) }
  }

  // Builds multimodal API message array when attachment is present.
  // The newest message includes file reference + text as parts.
  // Older messages are converted to text-only multimodal format.
  private func buildAPIMessagesMultimodal(
    messages: [ChatMessage],
    newMessage: ChatMessage,
    fileRef: UploadedFileReference
  ) -> [APIMessageMultimodal] {
    // Build older messages first (same token-limiting logic as buildAPIMessages).
    var includedMessages: [ChatMessage] = [newMessage]
    var estimatedTokens = estimateTokenCount(newMessage.content)

    // Add attachment token cost estimate (~258 tokens for images).
    estimatedTokens += AttachmentTokenEstimation.tokensPerImage

    for message in messages.reversed() {
      guard message.id != newMessage.id else { continue }

      let processedContent: String
      if message.role == .user && message.contextMetadata != nil {
        processedContent = extractUserTextFromMessage(message.content)
      } else {
        processedContent = message.content
      }

      let messageTokens = estimateTokenCount(processedContent)
      if estimatedTokens + messageTokens > TokenBudgetConstants.maxConversationHistoryTokens {
        break
      }

      let processedMessage = ChatMessage(
        id: message.id,
        conversationID: message.conversationID,
        role: message.role,
        content: processedContent,
        timestamp: message.timestamp,
        contextMetadata: nil
      )
      includedMessages.insert(processedMessage, at: 0)
      estimatedTokens += messageTokens
    }

    // Convert to multimodal format.
    var result: [APIMessageMultimodal] = []
    for (index, message) in includedMessages.enumerated() {
      let isNewest = (index == includedMessages.count - 1)
      let role = message.role == .user ? "user" : "model"

      if isNewest && message.role == .user {
        // Newest user message includes file + text parts.
        let fileData = APIFileData(from: fileRef)
        let parts: [APIMessagePart] = [
          .fileData(fileData),
          .text(message.content)
        ]
        result.append(APIMessageMultimodal(role: role, parts: parts))
      } else {
        // Other messages are text-only.
        result.append(APIMessageMultimodal(role: role, text: message.content))
      }
    }

    return result
  }

  // Estimates the number of tokens in a text string.
  // Uses a conservative heuristic: characters / charsPerToken.
  private func estimateTokenCount(_ text: String) -> Int {
    return Int(ceil(Double(text.count) / TokenBudgetConstants.charsPerToken))
  }

  // Extracts user text from a message that contains context.
  // Looks for the "---" separator and returns text after it.
  private func extractUserTextFromMessage(_ content: String) -> String {
    // Find the separator pattern.
    if let range = content.range(of: "\n\n---\n\nUser: ") {
      return String(content[range.upperBound...])
    }
    // If no separator found, return the whole content.
    return content
  }

  // Helper method for actor-isolated task storage.
  private func storeActiveStreamTask(_ task: Task<Void, Never>, conversationID: String) {
    activeStreamTasks[conversationID] = task
  }

  // Helper method for actor-isolated task cleanup.
  private func removeActiveStreamTask(conversationID: String) {
    activeStreamTasks.removeValue(forKey: conversationID)
  }
}
