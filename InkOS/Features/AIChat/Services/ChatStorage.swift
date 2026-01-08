// ChatStorage.swift
// In-memory storage for conversations and messages.
// Provides CRUD operations for managing chat history.

import Foundation

// Actor for thread-safe in-memory storage of conversations and messages.
actor ChatStorage: ChatStorageProtocol {

  // In-memory storage for conversations, keyed by conversation ID.
  private var conversations: [String: ChatConversation] = [:]

  // In-memory storage for messages, keyed by message ID.
  private var messages: [String: ChatMessage] = [:]

  // Shared singleton instance.
  static let shared = ChatStorage()

  // Private initializer for singleton pattern.
  private init() {}

  // Creates a new conversation with a unique ID.
  func createConversation(initialScope: ChatScope?) -> ChatConversation {
    let now = Date()
    let conversation = ChatConversation(
      id: UUID().uuidString,
      createdAt: now,
      updatedAt: now,
      messageIDs: [],
      initialScope: initialScope
    )
    conversations[conversation.id] = conversation
    return conversation
  }

  // Retrieves a conversation by ID.
  func getConversation(id: String) -> ChatConversation? {
    return conversations[id]
  }

  // Updates an existing conversation.
  func updateConversation(_ conversation: ChatConversation) {
    conversations[conversation.id] = conversation
  }

  // Deletes a conversation and all its messages.
  func deleteConversation(id: String) {
    // Get the conversation to find its message IDs.
    guard let conversation = conversations[id] else {
      // No error thrown if conversation doesn't exist (idempotent).
      return
    }

    // Delete all messages belonging to this conversation.
    for messageID in conversation.messageIDs {
      messages.removeValue(forKey: messageID)
    }

    // Delete the conversation itself.
    conversations.removeValue(forKey: id)
  }

  // Adds a message to storage and updates the parent conversation.
  func addMessage(_ message: ChatMessage) {
    // Store the message.
    messages[message.id] = message

    // Update the conversation to include this message.
    guard var conversation = conversations[message.conversationID] else {
      // If conversation doesn't exist, message is still stored but orphaned.
      // This matches the mock behavior where addMessage doesn't throw.
      return
    }

    // Append message ID to conversation.
    conversation.messageIDs.append(message.id)
    conversation.updatedAt = Date()
    conversations[message.conversationID] = conversation
  }

  // Retrieves all messages for a conversation, sorted by timestamp.
  func getMessages(conversationID: String) -> [ChatMessage] {
    guard let conversation = conversations[conversationID] else {
      return []
    }

    // Get all messages and sort by timestamp ascending.
    return conversation.messageIDs
      .compactMap { messages[$0] }
      .sorted { $0.timestamp < $1.timestamp }
  }

  // Retrieves a single message by ID.
  func getMessage(id: String) -> ChatMessage? {
    return messages[id]
  }

  // Retrieves all conversations, sorted by most recently updated first.
  func getAllConversations() -> [ChatConversation] {
    return conversations.values
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  // Truncates a conversation from a specific message point.
  // Permanently deletes the specified message and all subsequent messages.
  // TODO: Implement per contract specification.
  func truncateConversation(conversationID: String, fromMessageID: String) throws -> ChatConversation {
    // Check if conversation exists.
    guard var conversation = conversations[conversationID] else {
      throw ChatError.conversationNotFound(conversationID: conversationID)
    }

    // Check if message exists in storage.
    guard messages[fromMessageID] != nil else {
      throw ChatError.messageNotFound(messageID: fromMessageID)
    }

    // Check if message is in this conversation.
    guard let messageIndex = conversation.messageIDs.firstIndex(of: fromMessageID) else {
      throw ChatError.messageNotInConversation(messageID: fromMessageID, conversationID: conversationID)
    }

    // Get message IDs to delete (from messageIndex to end).
    let messageIDsToDelete = Array(conversation.messageIDs[messageIndex...])

    // Delete messages from storage.
    for messageID in messageIDsToDelete {
      messages.removeValue(forKey: messageID)
    }

    // Update conversation messageIDs to only keep messages before the truncation point.
    conversation.messageIDs = Array(conversation.messageIDs[..<messageIndex])
    conversation.updatedAt = Date()

    // Save updated conversation.
    conversations[conversationID] = conversation

    return conversation
  }
}
