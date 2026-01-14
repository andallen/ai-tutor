// ChatStorageTests.swift
// Tests for ChatStorage in-memory conversation and message storage.
// These tests use mock implementations until ChatStorage is implemented.
// Tests against contract-defined types (ChatMessage, ChatConversation, etc.)
// and mock implementations for protocol testing.

import Foundation
import Testing

@testable import InkOS

// MARK: - MockChatStorage

// Mock implementation of ChatStorageProtocol for testing dependent services.
// Provides a simple in-memory storage implementation with tracking.
actor MockChatStorage: ChatStorageProtocol {

  // In-memory storage for conversations.
  private var conversations: [String: ChatConversation] = [:]

  // In-memory storage for messages.
  private var messages: [String: ChatMessage] = [:]

  // Tracks the number of times createConversation was called.
  private(set) var createConversationCallCount = 0

  // Tracks the number of times getConversation was called.
  private(set) var getConversationCallCount = 0

  // Tracks the number of times updateConversation was called.
  private(set) var updateConversationCallCount = 0

  // Tracks the number of times deleteConversation was called.
  private(set) var deleteConversationCallCount = 0

  // Tracks the number of times addMessage was called.
  private(set) var addMessageCallCount = 0

  // Tracks the number of times getMessages was called.
  private(set) var getMessagesCallCount = 0

  // Tracks the number of times getMessage was called.
  private(set) var getMessageCallCount = 0

  // Tracks conversation IDs passed to delete.
  private(set) var deletedConversationIDs: [String] = []

  // Tracks messages that were added.
  private(set) var addedMessages: [ChatMessage] = []

  func createConversation(initialScope: ChatScope?) -> ChatConversation {
    createConversationCallCount += 1

    let id = UUID().uuidString
    let now = Date()
    let conversation = ChatConversation(
      id: id,
      createdAt: now,
      updatedAt: now,
      messageIDs: [],
      initialScope: initialScope
    )

    conversations[id] = conversation
    return conversation
  }

  func getConversation(id: String) -> ChatConversation? {
    getConversationCallCount += 1
    return conversations[id]
  }

  func updateConversation(_ conversation: ChatConversation) {
    updateConversationCallCount += 1
    conversations[conversation.id] = conversation
  }

  func deleteConversation(id: String) {
    deleteConversationCallCount += 1
    deletedConversationIDs.append(id)

    // Remove conversation and its messages.
    if let conversation = conversations[id] {
      for messageID in conversation.messageIDs {
        messages.removeValue(forKey: messageID)
      }
    }
    conversations.removeValue(forKey: id)
  }

  func addMessage(_ message: ChatMessage) {
    addMessageCallCount += 1
    addedMessages.append(message)
    messages[message.id] = message

    // Update the parent conversation.
    if var conversation = conversations[message.conversationID] {
      conversation.messageIDs.append(message.id)
      conversation.updatedAt = Date()
      conversations[message.conversationID] = conversation
    }
  }

  func getMessages(conversationID: String) -> [ChatMessage] {
    getMessagesCallCount += 1

    guard let conversation = conversations[conversationID] else {
      return []
    }

    return conversation.messageIDs
      .compactMap { messages[$0] }
      .sorted { $0.timestamp < $1.timestamp }
  }

  func getMessage(id: String) -> ChatMessage? {
    getMessageCallCount += 1
    return messages[id]
  }

  func getAllConversations() -> [ChatConversation] {
    return Array(conversations.values)
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  // Tracks the number of times truncateConversation was called.
  private(set) var truncateConversationCallCount = 0

  // Tracks parameters passed to truncateConversation.
  private(set) var truncateConversationCalls: [(conversationID: String, fromMessageID: String)] = []

  // Error to throw from truncateConversation.
  var truncateConversationError: Error?

  // Truncates a conversation from a specific message point.
  // Removes the specified message and all subsequent messages.
  func truncateConversation(conversationID: String, fromMessageID: String) throws -> ChatConversation {
    truncateConversationCallCount += 1
    truncateConversationCalls.append((conversationID: conversationID, fromMessageID: fromMessageID))

    // Throw configured error if set.
    if let error = truncateConversationError {
      throw error
    }

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

  // Resets all recorded state.
  func reset() {
    conversations = [:]
    messages = [:]
    createConversationCallCount = 0
    getConversationCallCount = 0
    updateConversationCallCount = 0
    deleteConversationCallCount = 0
    addMessageCallCount = 0
    getMessagesCallCount = 0
    getMessageCallCount = 0
    deletedConversationIDs = []
    addedMessages = []
    truncateConversationCallCount = 0
    truncateConversationCalls = []
    truncateConversationError = nil
  }

  // Adds a conversation directly for testing.
  func addConversation(_ conversation: ChatConversation) {
    conversations[conversation.id] = conversation
  }

  // Adds a message directly for testing without updating conversation.
  func addMessageDirectly(_ message: ChatMessage) {
    messages[message.id] = message
  }

  // Sets the error to throw from truncateConversation.
  func setTruncateConversationError(_ error: Error?) {
    truncateConversationError = error
  }
}

// MARK: - ChatStorage Tests via Mock

// Note: Tests against the real ChatStorage will be enabled once implementation exists.
// For now, these tests verify the mock implementation and contract types work correctly.
@Suite("ChatStorage Tests")
struct ChatStorageTests {

  // MARK: - MockChatStorage Conversation Tests

  @Suite("Conversation Operations via Mock")
  struct ConversationMockTests {

    @Test("creates conversation with unique ID")
    func createsConversationWithUniqueID() async {
      let storage = MockChatStorage()

      let conversation1 = await storage.createConversation(initialScope: nil)
      let conversation2 = await storage.createConversation(initialScope: nil)

      #expect(conversation1.id != conversation2.id)
    }

    @Test("creates conversation with timestamps")
    func createsConversationWithTimestamps() async {
      let storage = MockChatStorage()
      let beforeCreation = Date()

      let conversation = await storage.createConversation(initialScope: nil)

      #expect(conversation.createdAt >= beforeCreation)
      #expect(conversation.updatedAt >= beforeCreation)
    }

    @Test("creates conversation with empty messageIDs")
    func createsConversationWithEmptyMessages() async {
      let storage = MockChatStorage()

      let conversation = await storage.createConversation(initialScope: nil)

      #expect(conversation.messageIDs.isEmpty)
    }

    @Test("creates conversation with initialScope")
    func createsConversationWithInitialScope() async {
      let storage = MockChatStorage()

      let conversation = await storage.createConversation(initialScope: .allNotes)

      #expect(conversation.initialScope == .allNotes)
    }

    @Test("retrieves existing conversation by ID")
    func retrievesExistingConversation() async {
      let storage = MockChatStorage()
      let created = await storage.createConversation(initialScope: .chatOnly)

      let retrieved = await storage.getConversation(id: created.id)

      #expect(retrieved != nil)
      #expect(retrieved?.id == created.id)
      #expect(retrieved?.initialScope == .chatOnly)
    }

    @Test("returns nil for nonexistent conversation ID")
    func returnsNilForNonexistent() async {
      let storage = MockChatStorage()

      let retrieved = await storage.getConversation(id: "nonexistent-id")

      #expect(retrieved == nil)
    }

    @Test("updates existing conversation")
    func updatesExistingConversation() async {
      let storage = MockChatStorage()
      let created = await storage.createConversation(initialScope: nil)

      var updated = created
      updated.messageIDs = ["msg-1", "msg-2"]
      updated.updatedAt = Date().addingTimeInterval(60)

      await storage.updateConversation(updated)

      let retrieved = await storage.getConversation(id: created.id)

      #expect(retrieved?.messageIDs == ["msg-1", "msg-2"])
    }

    @Test("deletes conversation")
    func deletesConversation() async {
      let storage = MockChatStorage()
      let created = await storage.createConversation(initialScope: nil)

      await storage.deleteConversation(id: created.id)

      let retrieved = await storage.getConversation(id: created.id)

      #expect(retrieved == nil)
    }

    @Test("deletes conversation and its messages")
    func deletesConversationAndMessages() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      // Add messages to the conversation.
      let message1 = ChatMessage(
        id: "msg-1",
        conversationID: conversation.id,
        role: .user,
        content: "First",
        timestamp: Date(),
        contextMetadata: nil
      )
      let message2 = ChatMessage(
        id: "msg-2",
        conversationID: conversation.id,
        role: .assistant,
        content: "Response",
        timestamp: Date(),
        contextMetadata: nil
      )

      await storage.addMessage(message1)
      await storage.addMessage(message2)

      // Delete the conversation.
      await storage.deleteConversation(id: conversation.id)

      // Messages should also be deleted.
      let retrievedMessage1 = await storage.getMessage(id: "msg-1")
      let retrievedMessage2 = await storage.getMessage(id: "msg-2")

      #expect(retrievedMessage1 == nil)
      #expect(retrievedMessage2 == nil)
    }

    @Test("getAllConversations returns all conversations")
    func getAllConversationsReturnsAll() async {
      let storage = MockChatStorage()

      _ = await storage.createConversation(initialScope: .chatOnly)
      _ = await storage.createConversation(initialScope: .allNotes)
      _ = await storage.createConversation(initialScope: nil)

      let all = await storage.getAllConversations()

      #expect(all.count == 3)
    }

    @Test("tracks createConversation calls")
    func tracksCreateCalls() async {
      let storage = MockChatStorage()

      _ = await storage.createConversation(initialScope: nil)
      _ = await storage.createConversation(initialScope: .allNotes)

      let count = await storage.createConversationCallCount

      #expect(count == 2)
    }

    @Test("tracks deleteConversation calls")
    func tracksDeleteCalls() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      await storage.deleteConversation(id: conversation.id)

      let count = await storage.deleteConversationCallCount
      let deletedIDs = await storage.deletedConversationIDs

      #expect(count == 1)
      #expect(deletedIDs.contains(conversation.id))
    }
  }

  // MARK: - MockChatStorage Message Tests

  @Suite("Message Operations via Mock")
  struct MessageMockTests {

    @Test("adds message to storage")
    func addsMessage() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      let message = ChatMessage(
        id: "msg-1",
        conversationID: conversation.id,
        role: .user,
        content: "Hello",
        timestamp: Date(),
        contextMetadata: nil
      )

      await storage.addMessage(message)

      let retrieved = await storage.getMessage(id: "msg-1")

      #expect(retrieved != nil)
      #expect(retrieved?.content == "Hello")
    }

    @Test("addMessage updates conversation messageIDs")
    func addMessageUpdatesConversation() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      let message = ChatMessage(
        id: "msg-1",
        conversationID: conversation.id,
        role: .user,
        content: "Hello",
        timestamp: Date(),
        contextMetadata: nil
      )

      await storage.addMessage(message)

      let updatedConversation = await storage.getConversation(id: conversation.id)

      #expect(updatedConversation?.messageIDs.contains("msg-1") == true)
    }

    @Test("retrieves message by ID")
    func retrievesMessageByID() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      let message = ChatMessage(
        id: "msg-unique",
        conversationID: conversation.id,
        role: .assistant,
        content: "AI response",
        timestamp: Date(),
        contextMetadata: nil
      )

      await storage.addMessage(message)

      let retrieved = await storage.getMessage(id: "msg-unique")

      #expect(retrieved?.role == .assistant)
      #expect(retrieved?.content == "AI response")
    }

    @Test("returns nil for nonexistent message ID")
    func returnsNilForNonexistentMessage() async {
      let storage = MockChatStorage()

      let retrieved = await storage.getMessage(id: "nonexistent-msg")

      #expect(retrieved == nil)
    }

    @Test("getMessages returns messages for conversation")
    func getMessagesReturnsForConversation() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      let message1 = ChatMessage(
        id: "msg-1",
        conversationID: conversation.id,
        role: .user,
        content: "First",
        timestamp: Date(),
        contextMetadata: nil
      )
      let message2 = ChatMessage(
        id: "msg-2",
        conversationID: conversation.id,
        role: .assistant,
        content: "Second",
        timestamp: Date().addingTimeInterval(1),
        contextMetadata: nil
      )

      await storage.addMessage(message1)
      await storage.addMessage(message2)

      let messages = await storage.getMessages(conversationID: conversation.id)

      #expect(messages.count == 2)
    }

    @Test("getMessages returns sorted by timestamp ascending")
    func getMessagesReturnsSortedByTimestamp() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      let earlierTimestamp = Date()
      let laterTimestamp = earlierTimestamp.addingTimeInterval(60)

      // Add messages out of order.
      let laterMessage = ChatMessage(
        id: "msg-later",
        conversationID: conversation.id,
        role: .assistant,
        content: "Later",
        timestamp: laterTimestamp,
        contextMetadata: nil
      )
      let earlierMessage = ChatMessage(
        id: "msg-earlier",
        conversationID: conversation.id,
        role: .user,
        content: "Earlier",
        timestamp: earlierTimestamp,
        contextMetadata: nil
      )

      await storage.addMessage(laterMessage)
      await storage.addMessage(earlierMessage)

      let messages = await storage.getMessages(conversationID: conversation.id)

      #expect(messages.count == 2)
      #expect(messages[0].id == "msg-earlier")
      #expect(messages[1].id == "msg-later")
    }

    @Test("getMessages returns empty for nonexistent conversation")
    func getMessagesReturnsEmptyForNonexistent() async {
      let storage = MockChatStorage()

      let messages = await storage.getMessages(conversationID: "nonexistent")

      #expect(messages.isEmpty)
    }

    @Test("tracks addMessage calls")
    func tracksAddMessageCalls() async {
      let storage = MockChatStorage()
      let conversation = await storage.createConversation(initialScope: nil)

      let message = ChatMessage(
        id: "msg-1",
        conversationID: conversation.id,
        role: .user,
        content: "Test",
        timestamp: Date(),
        contextMetadata: nil
      )

      await storage.addMessage(message)

      let count = await storage.addMessageCallCount
      let added = await storage.addedMessages

      #expect(count == 1)
      #expect(added.count == 1)
      #expect(added[0].id == "msg-1")
    }

    @Test("messages are isolated between conversations")
    func messagesIsolatedBetweenConversations() async {
      let storage = MockChatStorage()
      let conversation1 = await storage.createConversation(initialScope: nil)
      let conversation2 = await storage.createConversation(initialScope: nil)

      let message1 = ChatMessage(
        id: "msg-1",
        conversationID: conversation1.id,
        role: .user,
        content: "In conv1",
        timestamp: Date(),
        contextMetadata: nil
      )
      let message2 = ChatMessage(
        id: "msg-2",
        conversationID: conversation2.id,
        role: .user,
        content: "In conv2",
        timestamp: Date(),
        contextMetadata: nil
      )

      await storage.addMessage(message1)
      await storage.addMessage(message2)

      let conv1Messages = await storage.getMessages(conversationID: conversation1.id)
      let conv2Messages = await storage.getMessages(conversationID: conversation2.id)

      #expect(conv1Messages.count == 1)
      #expect(conv1Messages[0].content == "In conv1")
      #expect(conv2Messages.count == 1)
      #expect(conv2Messages[0].content == "In conv2")
    }
  }

  // MARK: - Mock reset Tests

  @Suite("MockChatStorage Reset")
  struct MockResetTests {

    @Test("reset clears all state")
    func resetClearsState() async {
      let storage = MockChatStorage()

      let conversation = await storage.createConversation(initialScope: nil)
      let message = ChatMessage(
        id: "msg-1",
        conversationID: conversation.id,
        role: .user,
        content: "Test",
        timestamp: Date(),
        contextMetadata: nil
      )
      await storage.addMessage(message)

      await storage.reset()

      let createCount = await storage.createConversationCallCount
      let addCount = await storage.addMessageCallCount
      let conversations = await storage.getAllConversations()

      #expect(createCount == 0)
      #expect(addCount == 0)
      #expect(conversations.isEmpty)
    }
  }

  // MARK: - Truncate Conversation Tests

  @Suite("Truncate Conversation Operations via Mock")
  struct TruncateConversationMockTests {

    // Helper to create a conversation with multiple messages.
    private func createConversationWithMessages(
      storage: MockChatStorage,
      conversationID: String,
      messageIDs: [String]
    ) async -> ChatConversation {
      let now = Date()
      var conversation = ChatConversation(
        id: conversationID,
        createdAt: now,
        updatedAt: now,
        messageIDs: messageIDs,
        initialScope: .chatOnly
      )

      await storage.addConversation(conversation)

      // Add messages to storage.
      for (index, messageID) in messageIDs.enumerated() {
        let message = ChatMessage(
          id: messageID,
          conversationID: conversationID,
          role: index % 2 == 0 ? .user : .assistant,
          content: "Message \(index + 1)",
          timestamp: now.addingTimeInterval(Double(index)),
          contextMetadata: nil
        )
        await storage.addMessageDirectly(message)
      }

      return conversation
    }

    @Test("truncate at middle message removes specified and subsequent messages")
    func truncateAtMiddleMessage() async throws {
      let storage = MockChatStorage()
      _ = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-1",
        messageIDs: ["msg-1", "msg-2", "msg-3", "msg-4", "msg-5"]
      )

      // Truncate from msg-3.
      let result = try await storage.truncateConversation(
        conversationID: "conv-1",
        fromMessageID: "msg-3"
      )

      // Conversation should only have msg-1 and msg-2.
      #expect(result.messageIDs == ["msg-1", "msg-2"])

      // Messages msg-3, msg-4, msg-5 should be deleted.
      let msg3 = await storage.getMessage(id: "msg-3")
      let msg4 = await storage.getMessage(id: "msg-4")
      let msg5 = await storage.getMessage(id: "msg-5")

      #expect(msg3 == nil)
      #expect(msg4 == nil)
      #expect(msg5 == nil)

      // Messages msg-1 and msg-2 should still exist.
      let msg1 = await storage.getMessage(id: "msg-1")
      let msg2 = await storage.getMessage(id: "msg-2")

      #expect(msg1 != nil)
      #expect(msg2 != nil)
    }

    @Test("truncate at first message removes entire conversation history")
    func truncateAtFirstMessage() async throws {
      let storage = MockChatStorage()
      _ = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-1",
        messageIDs: ["msg-1", "msg-2", "msg-3"]
      )

      // Truncate from msg-1 (first message).
      let result = try await storage.truncateConversation(
        conversationID: "conv-1",
        fromMessageID: "msg-1"
      )

      // Conversation should have no messages.
      #expect(result.messageIDs.isEmpty)

      // All messages should be deleted.
      let msg1 = await storage.getMessage(id: "msg-1")
      let msg2 = await storage.getMessage(id: "msg-2")
      let msg3 = await storage.getMessage(id: "msg-3")

      #expect(msg1 == nil)
      #expect(msg2 == nil)
      #expect(msg3 == nil)
    }

    @Test("truncate at last message removes only that message")
    func truncateAtLastMessage() async throws {
      let storage = MockChatStorage()
      _ = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-1",
        messageIDs: ["msg-1", "msg-2", "msg-3"]
      )

      // Truncate from msg-3 (last message).
      let result = try await storage.truncateConversation(
        conversationID: "conv-1",
        fromMessageID: "msg-3"
      )

      // Conversation should have msg-1 and msg-2.
      #expect(result.messageIDs == ["msg-1", "msg-2"])

      // Only msg-3 should be deleted.
      let msg1 = await storage.getMessage(id: "msg-1")
      let msg2 = await storage.getMessage(id: "msg-2")
      let msg3 = await storage.getMessage(id: "msg-3")

      #expect(msg1 != nil)
      #expect(msg2 != nil)
      #expect(msg3 == nil)
    }

    @Test("throws conversationNotFound when conversation does not exist")
    func throwsConversationNotFound() async {
      let storage = MockChatStorage()

      // Attempt to truncate nonexistent conversation.
      await #expect(throws: ChatError.self) {
        _ = try await storage.truncateConversation(
          conversationID: "nonexistent",
          fromMessageID: "msg-1"
        )
      }

      // Verify exact error type.
      do {
        _ = try await storage.truncateConversation(
          conversationID: "nonexistent",
          fromMessageID: "msg-1"
        )
        Issue.record("Expected conversationNotFound error")
      } catch let error as ChatError {
        if case .conversationNotFound(let id) = error {
          #expect(id == "nonexistent")
        } else {
          Issue.record("Expected conversationNotFound but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    @Test("throws messageNotFound when message does not exist in storage")
    func throwsMessageNotFound() async throws {
      let storage = MockChatStorage()
      _ = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-1",
        messageIDs: ["msg-1", "msg-2"]
      )

      // Attempt to truncate with nonexistent message.
      do {
        _ = try await storage.truncateConversation(
          conversationID: "conv-1",
          fromMessageID: "msg-99"
        )
        Issue.record("Expected messageNotFound error")
      } catch let error as ChatError {
        if case .messageNotFound(let id) = error {
          #expect(id == "msg-99")
        } else {
          Issue.record("Expected messageNotFound but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    @Test("throws messageNotInConversation when message exists but not in conversation")
    func throwsMessageNotInConversation() async throws {
      let storage = MockChatStorage()

      // Create two conversations.
      _ = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-1",
        messageIDs: ["msg-1", "msg-2"]
      )
      _ = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-2",
        messageIDs: ["msg-3", "msg-4"]
      )

      // Attempt to truncate conv-1 with msg-3 (which belongs to conv-2).
      do {
        _ = try await storage.truncateConversation(
          conversationID: "conv-1",
          fromMessageID: "msg-3"
        )
        Issue.record("Expected messageNotInConversation error")
      } catch let error as ChatError {
        if case .messageNotInConversation(let msgID, let convID) = error {
          #expect(msgID == "msg-3")
          #expect(convID == "conv-1")
        } else {
          Issue.record("Expected messageNotInConversation but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    @Test("updates conversation updatedAt timestamp")
    func updatesConversationTimestamp() async throws {
      let storage = MockChatStorage()
      let originalConversation = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-1",
        messageIDs: ["msg-1", "msg-2", "msg-3"]
      )
      let originalUpdatedAt = originalConversation.updatedAt

      // Wait a small amount to ensure timestamp differs.
      try await Task.sleep(nanoseconds: 10_000_000) // 10ms

      // Truncate conversation.
      let result = try await storage.truncateConversation(
        conversationID: "conv-1",
        fromMessageID: "msg-2"
      )

      // updatedAt should be newer.
      #expect(result.updatedAt > originalUpdatedAt)
    }

    @Test("mock tracks truncateConversation calls")
    func mockTracksTruncateCalls() async throws {
      let storage = MockChatStorage()
      _ = await createConversationWithMessages(
        storage: storage,
        conversationID: "conv-1",
        messageIDs: ["msg-1", "msg-2", "msg-3"]
      )

      // Call truncateConversation.
      _ = try await storage.truncateConversation(
        conversationID: "conv-1",
        fromMessageID: "msg-2"
      )

      // Verify call was tracked.
      let count = await storage.truncateConversationCallCount
      let calls = await storage.truncateConversationCalls

      #expect(count == 1)
      #expect(calls.count == 1)
      #expect(calls[0].conversationID == "conv-1")
      #expect(calls[0].fromMessageID == "msg-2")
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let storage = MockChatStorage()

      // Configure error.
      await storage.setTruncateConversationError(
        ChatError.networkError(reason: "Test error")
      )

      // Create a conversation so we can test the error.
      let now = Date()
      let conversation = ChatConversation(
        id: "conv-1",
        createdAt: now,
        updatedAt: now,
        messageIDs: ["msg-1"],
        initialScope: nil
      )
      await storage.addConversation(conversation)

      // Attempt truncation - should throw configured error.
      await #expect(throws: ChatError.self) {
        _ = try await storage.truncateConversation(
          conversationID: "conv-1",
          fromMessageID: "msg-1"
        )
      }
    }

    @Test("preserves conversation metadata after truncation")
    func preservesConversationMetadata() async throws {
      let storage = MockChatStorage()
      let createdAt = Date()
      let originalConversation = ChatConversation(
        id: "conv-1",
        createdAt: createdAt,
        updatedAt: createdAt,
        messageIDs: ["msg-1", "msg-2", "msg-3"],
        initialScope: .allNotes
      )

      await storage.addConversation(originalConversation)

      // Add messages.
      for messageID in ["msg-1", "msg-2", "msg-3"] {
        let message = ChatMessage(
          id: messageID,
          conversationID: "conv-1",
          role: .user,
          content: "Test",
          timestamp: Date(),
          contextMetadata: nil
        )
        await storage.addMessageDirectly(message)
      }

      // Truncate.
      let result = try await storage.truncateConversation(
        conversationID: "conv-1",
        fromMessageID: "msg-2"
      )

      // Verify metadata is preserved.
      #expect(result.id == "conv-1")
      #expect(result.createdAt == createdAt)
      #expect(result.initialScope == .allNotes)
    }

    @Test("ChatError equality for messageNotFound")
    func chatErrorEqualityForMessageNotFound() {
      let error1 = ChatError.messageNotFound(messageID: "msg-1")
      let error2 = ChatError.messageNotFound(messageID: "msg-1")
      let error3 = ChatError.messageNotFound(messageID: "msg-2")

      #expect(error1 == error2)
      #expect(error1 != error3)
    }

    @Test("ChatError equality for messageNotInConversation")
    func chatErrorEqualityForMessageNotInConversation() {
      let error1 = ChatError.messageNotInConversation(messageID: "msg-1", conversationID: "conv-1")
      let error2 = ChatError.messageNotInConversation(messageID: "msg-1", conversationID: "conv-1")
      let error3 = ChatError.messageNotInConversation(messageID: "msg-2", conversationID: "conv-1")
      let error4 = ChatError.messageNotInConversation(messageID: "msg-1", conversationID: "conv-2")

      #expect(error1 == error2)
      #expect(error1 != error3)
      #expect(error1 != error4)
    }
  }
}

// MARK: - ChatMessage Tests

@Suite("ChatMessage Tests")
struct ChatMessageTests {

  @Test("creates message with all properties")
  func createsWithAllProperties() {
    let metadata = MessageContextMetadata(
      scope: .allNotes,
      documentIDs: ["doc-1", "doc-2"],
      documentCount: 2,
      characterCount: 100
    )

    let message = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello world",
      timestamp: Date(),
      contextMetadata: metadata
    )

    #expect(message.id == "msg-1")
    #expect(message.conversationID == "conv-1")
    #expect(message.role == .user)
    #expect(message.content == "Hello world")
    #expect(message.contextMetadata != nil)
  }

  @Test("creates assistant message without context metadata")
  func createsAssistantWithoutMetadata() {
    let message = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .assistant,
      content: "AI response",
      timestamp: Date(),
      contextMetadata: nil
    )

    #expect(message.role == .assistant)
    #expect(message.contextMetadata == nil)
  }

  @Test("ChatMessage is Identifiable")
  func isIdentifiable() {
    let message = ChatMessage(
      id: "unique-id",
      conversationID: "conv-1",
      role: .user,
      content: "Test",
      timestamp: Date(),
      contextMetadata: nil
    )

    #expect(message.id == "unique-id")
  }

  @Test("ChatMessage is Equatable")
  func isEquatable() {
    let timestamp = Date()

    let message1 = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil
    )

    let message2 = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil
    )

    let message3 = ChatMessage(
      id: "msg-2",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil
    )

    #expect(message1 == message2)
    #expect(message1 != message3)
  }

  @Test("ChatMessage is Codable")
  func isCodable() throws {
    let original = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Test content",
      timestamp: Date(),
      contextMetadata: nil
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ChatMessage.self, from: data)

    #expect(decoded.id == original.id)
    #expect(decoded.content == original.content)
  }

  @Test("ChatMessage is Sendable")
  func isSendable() async {
    let message = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Test",
      timestamp: Date(),
      contextMetadata: nil
    )

    // Verify message can be passed across actor boundaries.
    let result = await Task {
      message
    }.value

    #expect(result == message)
  }
}

// MARK: - ChatConversation Tests

@Suite("ChatConversation Tests")
struct ChatConversationTests {

  @Test("creates conversation with all properties")
  func createsWithAllProperties() {
    let now = Date()

    let conversation = ChatConversation(
      id: "conv-1",
      createdAt: now,
      updatedAt: now,
      messageIDs: ["msg-1", "msg-2"],
      initialScope: .allNotes
    )

    #expect(conversation.id == "conv-1")
    #expect(conversation.createdAt == now)
    #expect(conversation.updatedAt == now)
    #expect(conversation.messageIDs == ["msg-1", "msg-2"])
    #expect(conversation.initialScope == .allNotes)
  }

  @Test("ChatConversation is Identifiable")
  func isIdentifiable() {
    let conversation = ChatConversation(
      id: "unique-conv-id",
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: [],
      initialScope: nil
    )

    #expect(conversation.id == "unique-conv-id")
  }

  @Test("ChatConversation is Equatable")
  func isEquatable() {
    let now = Date()

    let conv1 = ChatConversation(
      id: "conv-1",
      createdAt: now,
      updatedAt: now,
      messageIDs: [],
      initialScope: nil
    )

    let conv2 = ChatConversation(
      id: "conv-1",
      createdAt: now,
      updatedAt: now,
      messageIDs: [],
      initialScope: nil
    )

    let conv3 = ChatConversation(
      id: "conv-2",
      createdAt: now,
      updatedAt: now,
      messageIDs: [],
      initialScope: nil
    )

    #expect(conv1 == conv2)
    #expect(conv1 != conv3)
  }

  @Test("ChatConversation is Codable")
  func isCodable() throws {
    let original = ChatConversation(
      id: "conv-1",
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: ["msg-1"],
      initialScope: .chatOnly
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ChatConversation.self, from: data)

    #expect(decoded.id == original.id)
    #expect(decoded.initialScope == original.initialScope)
  }

  @Test("ChatConversation is Sendable")
  func isSendable() async {
    let conversation = ChatConversation(
      id: "conv-1",
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: [],
      initialScope: nil
    )

    // Verify conversation can be passed across actor boundaries.
    let result = await Task {
      conversation
    }.value

    #expect(result == conversation)
  }

  @Test("messageIDs can be mutated")
  func messageIDsCanBeMutated() {
    var conversation = ChatConversation(
      id: "conv-1",
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: [],
      initialScope: nil
    )

    conversation.messageIDs.append("msg-1")
    conversation.messageIDs.append("msg-2")

    #expect(conversation.messageIDs == ["msg-1", "msg-2"])
  }

  @Test("updatedAt can be mutated")
  func updatedAtCanBeMutated() {
    let originalDate = Date()
    let newDate = originalDate.addingTimeInterval(3600)

    var conversation = ChatConversation(
      id: "conv-1",
      createdAt: originalDate,
      updatedAt: originalDate,
      messageIDs: [],
      initialScope: nil
    )

    conversation.updatedAt = newDate

    #expect(conversation.updatedAt == newDate)
    #expect(conversation.createdAt == originalDate)  // createdAt unchanged.
  }
}

// MARK: - MessageContextMetadata Tests

@Suite("MessageContextMetadata Tests")
struct MessageContextMetadataTests {

  @Test("creates metadata with all properties")
  func createsWithAllProperties() {
    let metadata = MessageContextMetadata(
      scope: .specificNote("note-123"),
      documentIDs: ["note-123"],
      documentCount: 1,
      characterCount: 500
    )

    #expect(metadata.documentIDs == ["note-123"])
    #expect(metadata.documentCount == 1)
    #expect(metadata.characterCount == 500)
  }

  @Test("MessageContextMetadata is Equatable")
  func isEquatable() {
    let metadata1 = MessageContextMetadata(
      scope: .allNotes,
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 100
    )

    let metadata2 = MessageContextMetadata(
      scope: .allNotes,
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 100
    )

    let metadata3 = MessageContextMetadata(
      scope: .chatOnly,
      documentIDs: [],
      documentCount: 0,
      characterCount: 0
    )

    #expect(metadata1 == metadata2)
    #expect(metadata1 != metadata3)
  }

  @Test("MessageContextMetadata is Codable")
  func isCodable() throws {
    let original = MessageContextMetadata(
      scope: .specificFolder("folder-1"),
      documentIDs: ["doc-1", "doc-2"],
      documentCount: 2,
      characterCount: 1000
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(MessageContextMetadata.self, from: data)

    #expect(decoded == original)
  }

  @Test("MessageContextMetadata is Sendable")
  func isSendable() async {
    let metadata = MessageContextMetadata(
      scope: .allNotes,
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 100
    )

    // Verify metadata can be passed across actor boundaries.
    let result = await Task {
      metadata
    }.value

    #expect(result == metadata)
  }
}

// MARK: - MessageRole Tests

@Suite("Chat MessageRole Tests")
struct ChatMessageRoleTests {

  @Test("MessageRole has user case")
  func hasUserCase() {
    let role = MessageRole.user
    #expect(role.rawValue == "user")
  }

  @Test("MessageRole has assistant case")
  func hasAssistantCase() {
    let role = MessageRole.assistant
    #expect(role.rawValue == "assistant")
  }

  @Test("MessageRole is Codable")
  func isCodable() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for role in [MessageRole.user, MessageRole.assistant] {
      let data = try encoder.encode(role)
      let decoded = try decoder.decode(MessageRole.self, from: data)
      #expect(decoded == role)
    }
  }

  @Test("MessageRole is Equatable")
  func isEquatable() {
    #expect(MessageRole.user == MessageRole.user)
    #expect(MessageRole.assistant == MessageRole.assistant)
    #expect(MessageRole.user != MessageRole.assistant)
  }
}
