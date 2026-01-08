// ChatServiceTests.swift
// Tests for ChatService orchestration of context gathering, Firebase calls, and storage.
// These tests use mock implementations until ChatService is implemented.
// Tests against contract-defined types (ChatError, ChatConstants, etc.)
// and mock implementations for protocol testing.

import Foundation
import Testing

@testable import InkOS

// MARK: - MockChatService

// Mock implementation of ChatServiceProtocol for testing dependent components.
// Tracks method invocations and allows configuring return values and errors.
actor MockChatService: ChatServiceProtocol {

  // Tracks the number of times sendMessage was called.
  private(set) var sendMessageCallCount = 0

  // Tracks parameters passed to sendMessage.
  private(set) var sendMessageCalls: [(text: String, attachment: FileAttachment?, scope: ChatScope, conversationID: String?, currentNoteID: String?, currentFolderID: String?)] = []

  // Tracks the number of times streamMessage was called.
  private(set) var streamMessageCallCount = 0

  // Tracks parameters passed to streamMessage.
  private(set) var streamMessageCalls: [(text: String, attachment: FileAttachment?, scope: ChatScope, conversationID: String?, currentNoteID: String?, currentFolderID: String?)] = []

  // Tracks the number of times saveStreamedResponse was called.
  private(set) var saveStreamedResponseCallCount = 0

  // Tracks parameters passed to saveStreamedResponse.
  private(set) var saveStreamedResponseCalls: [(conversationID: String, content: String)] = []

  // Response message to return from sendMessage.
  var sendMessageResponse: ChatMessage?

  // Error to throw from sendMessage.
  var sendMessageError: Error?

  // User message to return from streamMessage.
  var streamUserMessage: ChatMessage?

  // Chunks to yield from stream.
  var streamChunks: [String] = ["Streamed ", "response ", "content"]

  // Error to throw from streamMessage.
  var streamMessageError: Error?

  // Response to return from saveStreamedResponse.
  var saveStreamedResponseResult: ChatMessage?

  // Error to throw from saveStreamedResponse.
  var saveStreamedResponseError: Error?

  // Tracks the number of times cancelStream was called.
  private(set) var cancelStreamCallCount = 0

  // Tracks conversationIDs passed to cancelStream.
  private(set) var cancelStreamCalls: [String] = []

  // Tracks the number of times isStreamActive was called.
  private(set) var isStreamActiveCallCount = 0

  // Tracks conversationIDs passed to isStreamActive.
  private(set) var isStreamActiveCalls: [String] = []

  // Mock return value for isStreamActive.
  var mockIsStreamActive: Bool = false

  // Tracks the number of times restartConversationFromMessage was called.
  private(set) var restartConversationFromMessageCallCount = 0

  // Tracks parameters passed to restartConversationFromMessage.
  private(set) var restartConversationFromMessageCalls: [(conversationID: String, messageID: String)] = []

  // Response to return from restartConversationFromMessage.
  var restartConversationFromMessageResult: ChatConversation?

  // Error to throw from restartConversationFromMessage.
  var restartConversationFromMessageError: Error?

  // Tracks the number of times editMessage was called.
  private(set) var editMessageCallCount = 0

  // Tracks parameters passed to editMessage.
  private(set) var editMessageCalls: [(conversationID: String, messageID: String)] = []

  // Response to return from editMessage.
  var editMessageResult: ChatConversation?

  // Error to throw from editMessage.
  var editMessageError: Error?

  func sendMessage(
    text: String,
    attachment: FileAttachment?,
    scope: ChatScope,
    conversationID: String?,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> ChatMessage {
    sendMessageCallCount += 1
    sendMessageCalls.append((
      text: text,
      attachment: attachment,
      scope: scope,
      conversationID: conversationID,
      currentNoteID: currentNoteID,
      currentFolderID: currentFolderID
    ))

    if let error = sendMessageError {
      throw error
    }

    if let response = sendMessageResponse {
      return response
    }

    // Return a default response.
    return ChatMessage(
      id: UUID().uuidString,
      conversationID: conversationID ?? UUID().uuidString,
      role: .assistant,
      content: "Default mock response",
      timestamp: Date(),
      contextMetadata: nil
    )
  }

  func streamMessage(
    text: String,
    attachment: FileAttachment?,
    scope: ChatScope,
    conversationID: String?,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> (userMessage: ChatMessage, stream: AsyncThrowingStream<String, Error>) {
    streamMessageCallCount += 1
    streamMessageCalls.append((
      text: text,
      attachment: attachment,
      scope: scope,
      conversationID: conversationID,
      currentNoteID: currentNoteID,
      currentFolderID: currentFolderID
    ))

    if let error = streamMessageError {
      throw error
    }

    let userMessage = streamUserMessage ?? ChatMessage(
      id: UUID().uuidString,
      conversationID: conversationID ?? UUID().uuidString,
      role: .user,
      content: text,
      timestamp: Date(),
      contextMetadata: nil
    )

    let chunks = streamChunks
    let stream = AsyncThrowingStream<String, Error> { continuation in
      Task {
        for chunk in chunks {
          continuation.yield(chunk)
        }
        continuation.finish()
      }
    }

    return (userMessage: userMessage, stream: stream)
  }

  func saveStreamedResponse(
    conversationID: String,
    content: String
  ) async throws -> ChatMessage {
    saveStreamedResponseCallCount += 1
    saveStreamedResponseCalls.append((conversationID: conversationID, content: content))

    if let error = saveStreamedResponseError {
      throw error
    }

    if let result = saveStreamedResponseResult {
      return result
    }

    return ChatMessage(
      id: UUID().uuidString,
      conversationID: conversationID,
      role: .assistant,
      content: content,
      timestamp: Date(),
      contextMetadata: nil
    )
  }

  func cancelStream(conversationID: String) async {
    cancelStreamCallCount += 1
    cancelStreamCalls.append(conversationID)
  }

  func isStreamActive(conversationID: String) async -> Bool {
    isStreamActiveCallCount += 1
    isStreamActiveCalls.append(conversationID)
    return mockIsStreamActive
  }

  func restartConversationFromMessage(conversationID: String, messageID: String) async throws -> ChatConversation {
    restartConversationFromMessageCallCount += 1
    restartConversationFromMessageCalls.append((conversationID: conversationID, messageID: messageID))

    if let error = restartConversationFromMessageError {
      throw error
    }

    if let result = restartConversationFromMessageResult {
      return result
    }

    // Return a default conversation.
    return ChatConversation(
      id: conversationID,
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: [],
      initialScope: nil
    )
  }

  func editMessage(conversationID: String, messageID: String) async throws -> ChatConversation {
    editMessageCallCount += 1
    editMessageCalls.append((conversationID: conversationID, messageID: messageID))

    if let error = editMessageError {
      throw error
    }

    if let result = editMessageResult {
      return result
    }

    // Return a default conversation with empty message IDs.
    return ChatConversation(
      id: conversationID,
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: [],
      initialScope: nil
    )
  }

  // Sets the mock return value for isStreamActive.
  func setMockIsStreamActive(_ value: Bool) {
    mockIsStreamActive = value
  }

  // Resets all recorded state.
  func reset() {
    sendMessageCallCount = 0
    sendMessageCalls = []
    streamMessageCallCount = 0
    streamMessageCalls = []
    saveStreamedResponseCallCount = 0
    saveStreamedResponseCalls = []
    sendMessageResponse = nil
    sendMessageError = nil
    streamUserMessage = nil
    streamChunks = ["Streamed ", "response ", "content"]
    streamMessageError = nil
    saveStreamedResponseResult = nil
    saveStreamedResponseError = nil
    cancelStreamCallCount = 0
    cancelStreamCalls = []
    isStreamActiveCallCount = 0
    isStreamActiveCalls = []
    mockIsStreamActive = false
    restartConversationFromMessageCallCount = 0
    restartConversationFromMessageCalls = []
    restartConversationFromMessageResult = nil
    restartConversationFromMessageError = nil
    editMessageCallCount = 0
    editMessageCalls = []
    editMessageResult = nil
    editMessageError = nil
  }
}

// MARK: - ChatService Tests via Mock

// Note: Tests against the real ChatService will be enabled once implementation exists.
// For now, these tests verify the mock implementation and contract types work correctly.
@Suite("ChatService Tests")
struct ChatServiceTests {

  // MARK: - MockChatService sendMessage Tests

  @Suite("sendMessage Operations via Mock")
  struct SendMessageMockTests {

    @Test("mock returns configured response")
    func mockReturnsConfiguredResponse() async throws {
      let service = MockChatService()
      let configuredMessage = ChatMessage(
        id: "configured-id",
        conversationID: "conv-1",
        role: .assistant,
        content: "Configured response",
        timestamp: Date(),
        contextMetadata: nil
      )
      await service.setSendMessageResponse(configuredMessage)

      let response = try await service.sendMessage(
        text: "Test",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      #expect(response.id == "configured-id")
      #expect(response.content == "Configured response")
    }

    @Test("mock tracks call count")
    func mockTracksCallCount() async throws {
      let service = MockChatService()

      _ = try await service.sendMessage(text: "First", attachment: nil, scope: .chatOnly, conversationID: nil, currentNoteID: nil, currentFolderID: nil)
      _ = try await service.sendMessage(text: "Second", attachment: nil, scope: .allNotes, conversationID: nil, currentNoteID: nil, currentFolderID: nil)

      let count = await service.sendMessageCallCount
      #expect(count == 2)
    }

    @Test("mock tracks all parameters")
    func mockTracksAllParameters() async throws {
      let service = MockChatService()

      _ = try await service.sendMessage(
        text: "Test message",
        attachment: nil,
        scope: .specificNote("note-123"),
        conversationID: "conv-456",
        currentNoteID: "current-note",
        currentFolderID: "current-folder"
      )

      let calls = await service.sendMessageCalls
      #expect(calls.count == 1)
      #expect(calls[0].text == "Test message")
      #expect(calls[0].scope == .specificNote("note-123"))
      #expect(calls[0].conversationID == "conv-456")
      #expect(calls[0].currentNoteID == "current-note")
      #expect(calls[0].currentFolderID == "current-folder")
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let service = MockChatService()
      await service.setSendMessageError(ChatError.networkError(reason: "Test"))

      await #expect(throws: ChatError.self) {
        _ = try await service.sendMessage(
          text: "Test",
        attachment: nil,
        scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
      }
    }

    @Test("mock throws conversationNotFound error")
    func mockThrowsConversationNotFound() async {
      let service = MockChatService()
      await service.setSendMessageError(ChatError.conversationNotFound(conversationID: "invalid-id"))

      do {
        _ = try await service.sendMessage(
          text: "Test",
        attachment: nil,
        scope: .chatOnly,
          conversationID: "invalid-id",
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected conversationNotFound error")
      } catch let error as ChatError {
        if case .conversationNotFound(let id) = error {
          #expect(id == "invalid-id")
        } else {
          Issue.record("Expected conversationNotFound but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }
  }

  // MARK: - MockChatService streamMessage Tests

  @Suite("streamMessage Operations via Mock")
  struct StreamMessageMockTests {

    @Test("mock returns user message and stream")
    func mockReturnsUserMessageAndStream() async throws {
      let service = MockChatService()

      let result = try await service.streamMessage(
        text: "Hello",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      #expect(result.userMessage.role == .user)
      #expect(result.userMessage.content == "Hello")

      // Verify stream yields chunks.
      var chunks: [String] = []
      for try await chunk in result.stream {
        chunks.append(chunk)
      }
      #expect(chunks.count > 0)
    }

    @Test("mock tracks call count")
    func mockTracksCallCount() async throws {
      let service = MockChatService()

      let result = try await service.streamMessage(
        text: "Test",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // Consume stream.
      for try await _ in result.stream {}

      let count = await service.streamMessageCallCount
      #expect(count == 1)
    }

    @Test("mock tracks all parameters")
    func mockTracksAllParameters() async throws {
      let service = MockChatService()

      let result = try await service.streamMessage(
        text: "Stream test",
        attachment: nil,
        scope: .thisNote,
        conversationID: "conv-1",
        currentNoteID: "note-1",
        currentFolderID: "folder-1"
      )

      // Consume stream.
      for try await _ in result.stream {}

      let calls = await service.streamMessageCalls
      #expect(calls.count == 1)
      #expect(calls[0].text == "Stream test")
      #expect(calls[0].scope == .thisNote)
      #expect(calls[0].conversationID == "conv-1")
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let service = MockChatService()
      await service.setStreamMessageError(ChatError.streamingFailed(reason: "Connection lost"))

      await #expect(throws: ChatError.self) {
        _ = try await service.streamMessage(
          text: "Test",
        attachment: nil,
        scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
      }
    }

    @Test("mock stream yields configured chunks")
    func mockStreamYieldsConfiguredChunks() async throws {
      let service = MockChatService()
      await service.setStreamChunks(["First ", "Second ", "Third"])

      let result = try await service.streamMessage(
        text: "Test",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      var chunks: [String] = []
      for try await chunk in result.stream {
        chunks.append(chunk)
      }

      #expect(chunks == ["First ", "Second ", "Third"])
    }
  }

  // MARK: - MockChatService saveStreamedResponse Tests

  @Suite("saveStreamedResponse Operations via Mock")
  struct SaveStreamedResponseMockTests {

    @Test("mock returns configured response")
    func mockReturnsConfiguredResponse() async throws {
      let service = MockChatService()
      let configuredMessage = ChatMessage(
        id: "saved-id",
        conversationID: "conv-1",
        role: .assistant,
        content: "Saved content",
        timestamp: Date(),
        contextMetadata: nil
      )
      await service.setSaveStreamedResponseResult(configuredMessage)

      let result = try await service.saveStreamedResponse(
        conversationID: "conv-1",
        content: "Accumulated content"
      )

      #expect(result.id == "saved-id")
    }

    @Test("mock tracks call count")
    func mockTracksCallCount() async throws {
      let service = MockChatService()

      _ = try await service.saveStreamedResponse(conversationID: "conv-1", content: "First")
      _ = try await service.saveStreamedResponse(conversationID: "conv-2", content: "Second")

      let count = await service.saveStreamedResponseCallCount
      #expect(count == 2)
    }

    @Test("mock tracks parameters")
    func mockTracksParameters() async throws {
      let service = MockChatService()

      _ = try await service.saveStreamedResponse(
        conversationID: "test-conv",
        content: "Streamed response content"
      )

      let calls = await service.saveStreamedResponseCalls
      #expect(calls.count == 1)
      #expect(calls[0].conversationID == "test-conv")
      #expect(calls[0].content == "Streamed response content")
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let service = MockChatService()
      await service.setSaveStreamedResponseError(ChatError.conversationNotFound(conversationID: "invalid"))

      await #expect(throws: ChatError.self) {
        _ = try await service.saveStreamedResponse(
          conversationID: "invalid",
          content: "Content"
        )
      }
    }
  }

  // MARK: - Mock reset Tests

  @Suite("MockChatService Reset")
  struct MockResetTests {

    @Test("reset clears all state")
    func resetClearsState() async throws {
      let service = MockChatService()

      _ = try await service.sendMessage(text: "Test", attachment: nil, scope: .chatOnly, conversationID: nil, currentNoteID: nil, currentFolderID: nil)
      let streamResult = try await service.streamMessage(text: "Test", attachment: nil, scope: .chatOnly, conversationID: nil, currentNoteID: nil, currentFolderID: nil)
      for try await _ in streamResult.stream {}
      _ = try await service.saveStreamedResponse(conversationID: "conv", content: "Content")

      await service.reset()

      let sendCount = await service.sendMessageCallCount
      let streamCount = await service.streamMessageCallCount
      let saveCount = await service.saveStreamedResponseCallCount

      #expect(sendCount == 0)
      #expect(streamCount == 0)
      #expect(saveCount == 0)
    }

    @Test("reset clears configured errors")
    func resetClearsErrors() async throws {
      let service = MockChatService()
      await service.setSendMessageError(ChatError.networkError(reason: "Test"))

      await service.reset()

      // Should not throw after reset.
      let response = try await service.sendMessage(
        text: "Test",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      #expect(response.content == "Default mock response")
    }
  }

  // MARK: - Stream Cancellation Tests

  @Suite("Stream Cancellation Operations via Mock")
  struct CancellationMockTests {

    @Test("mock tracks cancelStream calls")
    func mockTracksCancelCalls() async {
      let service = MockChatService()

      await service.cancelStream(conversationID: "conv-1")
      await service.cancelStream(conversationID: "conv-2")

      let calls = await service.cancelStreamCalls
      let count = await service.cancelStreamCallCount

      #expect(calls == ["conv-1", "conv-2"])
      #expect(count == 2)
    }

    @Test("mock tracks isStreamActive calls")
    func mockTracksIsActiveCalls() async {
      let service = MockChatService()
      await service.setMockIsStreamActive(true)

      let active1 = await service.isStreamActive(conversationID: "conv-1")
      let active2 = await service.isStreamActive(conversationID: "conv-2")

      let calls = await service.isStreamActiveCalls
      let count = await service.isStreamActiveCallCount

      #expect(active1 == true)
      #expect(active2 == true)
      #expect(calls == ["conv-1", "conv-2"])
      #expect(count == 2)
    }

    @Test("mock reset clears cancellation state")
    func mockResetClearsCancellation() async {
      let service = MockChatService()

      await service.cancelStream(conversationID: "conv-1")
      _ = await service.isStreamActive(conversationID: "conv-1")

      await service.reset()

      let cancelCalls = await service.cancelStreamCalls
      let activeCalls = await service.isStreamActiveCalls
      let cancelCount = await service.cancelStreamCallCount
      let activeCount = await service.isStreamActiveCallCount

      #expect(cancelCalls.isEmpty)
      #expect(activeCalls.isEmpty)
      #expect(cancelCount == 0)
      #expect(activeCount == 0)
    }
  }

  // MARK: - Restart Conversation From Message Tests

  @Suite("restartConversationFromMessage Operations via Mock")
  struct RestartConversationMockTests {

    @Test("mock tracks restartConversationFromMessage calls")
    func mockTracksRestartCalls() async throws {
      let service = MockChatService()

      // Call restartConversationFromMessage.
      _ = try await service.restartConversationFromMessage(
        conversationID: "conv-1",
        messageID: "msg-3"
      )

      // Verify call was tracked.
      let count = await service.restartConversationFromMessageCallCount
      let calls = await service.restartConversationFromMessageCalls

      #expect(count == 1)
      #expect(calls.count == 1)
      #expect(calls[0].conversationID == "conv-1")
      #expect(calls[0].messageID == "msg-3")
    }

    @Test("mock returns configured conversation result")
    func mockReturnsConfiguredResult() async throws {
      let service = MockChatService()
      let configuredConversation = ChatConversation(
        id: "conv-1",
        createdAt: Date(),
        updatedAt: Date(),
        messageIDs: ["msg-1", "msg-2"],
        initialScope: .allNotes
      )
      await service.setRestartConversationFromMessageResult(configuredConversation)

      // Call restartConversationFromMessage.
      let result = try await service.restartConversationFromMessage(
        conversationID: "conv-1",
        messageID: "msg-3"
      )

      // Verify configured result was returned.
      #expect(result.id == "conv-1")
      #expect(result.messageIDs == ["msg-1", "msg-2"])
      #expect(result.initialScope == .allNotes)
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let service = MockChatService()
      await service.setRestartConversationFromMessageError(
        ChatError.networkError(reason: "Test error")
      )

      // Attempt to call restartConversationFromMessage.
      await #expect(throws: ChatError.self) {
        _ = try await service.restartConversationFromMessage(
          conversationID: "conv-1",
          messageID: "msg-1"
        )
      }
    }

    @Test("mock throws conversationNotFound error")
    func mockThrowsConversationNotFound() async {
      let service = MockChatService()
      await service.setRestartConversationFromMessageError(
        ChatError.conversationNotFound(conversationID: "invalid-id")
      )

      // Attempt to call restartConversationFromMessage.
      do {
        _ = try await service.restartConversationFromMessage(
          conversationID: "invalid-id",
          messageID: "msg-1"
        )
        Issue.record("Expected conversationNotFound error")
      } catch let error as ChatError {
        if case .conversationNotFound(let id) = error {
          #expect(id == "invalid-id")
        } else {
          Issue.record("Expected conversationNotFound but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    @Test("mock throws messageNotInConversation error")
    func mockThrowsMessageNotInConversation() async {
      let service = MockChatService()
      await service.setRestartConversationFromMessageError(
        ChatError.messageNotInConversation(messageID: "msg-99", conversationID: "conv-1")
      )

      // Attempt to call restartConversationFromMessage.
      do {
        _ = try await service.restartConversationFromMessage(
          conversationID: "conv-1",
          messageID: "msg-99"
        )
        Issue.record("Expected messageNotInConversation error")
      } catch let error as ChatError {
        if case .messageNotInConversation(let msgID, let convID) = error {
          #expect(msgID == "msg-99")
          #expect(convID == "conv-1")
        } else {
          Issue.record("Expected messageNotInConversation but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    @Test("mock reset clears restart conversation state")
    func mockResetClearsRestartState() async throws {
      let service = MockChatService()

      // Set up some state.
      let conversation = ChatConversation(
        id: "conv-1",
        createdAt: Date(),
        updatedAt: Date(),
        messageIDs: [],
        initialScope: nil
      )
      await service.setRestartConversationFromMessageResult(conversation)

      // Make a call.
      _ = try await service.restartConversationFromMessage(
        conversationID: "conv-1",
        messageID: "msg-1"
      )

      // Reset.
      await service.reset()

      // Verify state was cleared.
      let count = await service.restartConversationFromMessageCallCount
      let calls = await service.restartConversationFromMessageCalls

      #expect(count == 0)
      #expect(calls.isEmpty)
    }
  }

  // MARK: - Edit Message Tests

  @Suite("editMessage Operations via Mock")
  struct EditMessageMockTests {

    // MARK: - Mock Infrastructure Tests

    @Test("mock tracks single editMessage call")
    func mockTracksSingleCall() async throws {
      let service = MockChatService()

      // Call editMessage.
      _ = try await service.editMessage(
        conversationID: "conv-1",
        messageID: "msg-3"
      )

      // Verify call was tracked.
      let count = await service.editMessageCallCount
      let calls = await service.editMessageCalls

      #expect(count == 1)
      #expect(calls.count == 1)
      #expect(calls[0].conversationID == "conv-1")
      #expect(calls[0].messageID == "msg-3")
    }

    @Test("mock tracks multiple editMessage calls")
    func mockTracksMultipleCalls() async throws {
      let service = MockChatService()

      // Call editMessage multiple times.
      _ = try await service.editMessage(conversationID: "conv-1", messageID: "msg-1")
      _ = try await service.editMessage(conversationID: "conv-2", messageID: "msg-5")
      _ = try await service.editMessage(conversationID: "conv-1", messageID: "msg-3")

      // Verify all calls were tracked.
      let count = await service.editMessageCallCount
      let calls = await service.editMessageCalls

      #expect(count == 3)
      #expect(calls.count == 3)
      #expect(calls[0].conversationID == "conv-1")
      #expect(calls[0].messageID == "msg-1")
      #expect(calls[1].conversationID == "conv-2")
      #expect(calls[1].messageID == "msg-5")
      #expect(calls[2].conversationID == "conv-1")
      #expect(calls[2].messageID == "msg-3")
    }

    @Test("mock returns configured conversation result")
    func mockReturnsConfiguredResult() async throws {
      let service = MockChatService()
      let configuredConversation = ChatConversation(
        id: "conv-1",
        createdAt: Date(),
        updatedAt: Date(),
        messageIDs: ["msg-1", "msg-2"],
        initialScope: .thisNote
      )
      await service.setEditMessageResult(configuredConversation)

      // Call editMessage.
      let result = try await service.editMessage(
        conversationID: "conv-1",
        messageID: "msg-3"
      )

      // Verify configured result was returned.
      #expect(result.id == "conv-1")
      #expect(result.messageIDs == ["msg-1", "msg-2"])
      #expect(result.initialScope == .thisNote)
    }

    @Test("mock returns default conversation when result not configured")
    func mockReturnsDefaultResult() async throws {
      let service = MockChatService()

      // Call editMessage without configuring a result.
      let result = try await service.editMessage(
        conversationID: "conv-123",
        messageID: "msg-456"
      )

      // Verify default result has expected structure.
      #expect(result.id == "conv-123")
      #expect(result.messageIDs.isEmpty)
      #expect(result.initialScope == nil)
    }

    // MARK: - Error Handling Tests

    @Test("mock throws generic configured error")
    func mockThrowsGenericError() async {
      let service = MockChatService()
      await service.setEditMessageError(
        ChatError.networkError(reason: "Connection timeout")
      )

      // Attempt to call editMessage.
      await #expect(throws: ChatError.self) {
        _ = try await service.editMessage(
          conversationID: "conv-1",
          messageID: "msg-1"
        )
      }
    }

    @Test("mock throws conversationNotFound error")
    func mockThrowsConversationNotFound() async {
      let service = MockChatService()
      await service.setEditMessageError(
        ChatError.conversationNotFound(conversationID: "nonexistent")
      )

      // Attempt to call editMessage.
      do {
        _ = try await service.editMessage(
          conversationID: "nonexistent",
          messageID: "msg-1"
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

    @Test("mock throws messageNotFound error")
    func mockThrowsMessageNotFound() async {
      let service = MockChatService()
      await service.setEditMessageError(
        ChatError.messageNotFound(messageID: "msg-99")
      )

      // Attempt to call editMessage.
      do {
        _ = try await service.editMessage(
          conversationID: "conv-1",
          messageID: "msg-99"
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

    @Test("mock throws messageNotInConversation error")
    func mockThrowsMessageNotInConversation() async {
      let service = MockChatService()
      await service.setEditMessageError(
        ChatError.messageNotInConversation(messageID: "msg-3", conversationID: "conv-1")
      )

      // Attempt to call editMessage.
      do {
        _ = try await service.editMessage(
          conversationID: "conv-1",
          messageID: "msg-3"
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

    @Test("mock throws invalidMessageRole error")
    func mockThrowsInvalidMessageRole() async {
      let service = MockChatService()
      await service.setEditMessageError(
        ChatError.invalidMessageRole(messageID: "msg-2", role: .assistant, operation: "edit")
      )

      // Attempt to call editMessage.
      do {
        _ = try await service.editMessage(
          conversationID: "conv-1",
          messageID: "msg-2"
        )
        Issue.record("Expected invalidMessageRole error")
      } catch let error as ChatError {
        if case .invalidMessageRole(let msgID, let role, let operation) = error {
          #expect(msgID == "msg-2")
          #expect(role == .assistant)
          #expect(operation == "edit")
        } else {
          Issue.record("Expected invalidMessageRole but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    // MARK: - State Management Tests

    @Test("mock reset clears all editMessage state")
    func mockResetClearsEditMessageState() async throws {
      let service = MockChatService()

      // Set up configured result.
      let conversation = ChatConversation(
        id: "conv-1",
        createdAt: Date(),
        updatedAt: Date(),
        messageIDs: ["msg-1"],
        initialScope: .allNotes
      )
      await service.setEditMessageResult(conversation)

      // Make a call.
      _ = try await service.editMessage(
        conversationID: "conv-1",
        messageID: "msg-3"
      )

      // Reset.
      await service.reset()

      // Verify state was cleared.
      let count = await service.editMessageCallCount
      let calls = await service.editMessageCalls

      #expect(count == 0)
      #expect(calls.isEmpty)

      // Verify configured result was also cleared by checking default is returned.
      let result = try await service.editMessage(conversationID: "conv-2", messageID: "msg-1")
      #expect(result.messageIDs.isEmpty)
    }
  }
}

// MARK: - ChatError Tests

@Suite("ChatError Tests")
struct ChatErrorTests {

  @Test("invalidRequest has correct description")
  func invalidRequestDescription() {
    let error = ChatError.invalidRequest(reason: "Test reason")

    #expect(error.errorDescription?.contains("Invalid request") == true)
    #expect(error.errorDescription?.contains("Test reason") == true)
  }

  @Test("emptyMessages has correct description")
  func emptyMessagesDescription() {
    let error = ChatError.emptyMessages

    #expect(error.errorDescription?.contains("empty message") == true)
  }

  @Test("networkError has correct description")
  func networkErrorDescription() {
    let error = ChatError.networkError(reason: "Connection lost")

    #expect(error.errorDescription?.contains("Network error") == true)
    #expect(error.errorDescription?.contains("Connection lost") == true)
  }

  @Test("requestFailed has correct description")
  func requestFailedDescription() {
    let error = ChatError.requestFailed(statusCode: 500, message: "Server error")

    #expect(error.errorDescription?.contains("500") == true)
    #expect(error.errorDescription?.contains("Server error") == true)
  }

  @Test("invalidResponse has correct description")
  func invalidResponseDescription() {
    let error = ChatError.invalidResponse(reason: "Missing field")

    #expect(error.errorDescription?.contains("Invalid response") == true)
    #expect(error.errorDescription?.contains("Missing field") == true)
  }

  @Test("streamingFailed has correct description")
  func streamingFailedDescription() {
    let error = ChatError.streamingFailed(reason: "Timeout")

    #expect(error.errorDescription?.contains("Streaming failed") == true)
    #expect(error.errorDescription?.contains("Timeout") == true)
  }

  @Test("contextExtractionFailed has correct description")
  func contextExtractionFailedDescription() {
    let error = ChatError.contextExtractionFailed(reason: "Parse error")

    #expect(error.errorDescription?.contains("extract context") == true)
    #expect(error.errorDescription?.contains("Parse error") == true)
  }

  @Test("documentNotFound has correct description")
  func documentNotFoundDescription() {
    let error = ChatError.documentNotFound(documentID: "doc-123")

    #expect(error.errorDescription?.contains("Document not found") == true)
    #expect(error.errorDescription?.contains("doc-123") == true)
  }

  @Test("folderNotFound has correct description")
  func folderNotFoundDescription() {
    let error = ChatError.folderNotFound(folderID: "folder-456")

    #expect(error.errorDescription?.contains("Folder not found") == true)
    #expect(error.errorDescription?.contains("folder-456") == true)
  }

  @Test("conversationNotFound has correct description")
  func conversationNotFoundDescription() {
    let error = ChatError.conversationNotFound(conversationID: "conv-789")

    #expect(error.errorDescription?.contains("Conversation not found") == true)
    #expect(error.errorDescription?.contains("conv-789") == true)
  }

  @Test("messageNotFound has correct description")
  func messageNotFoundDescription() {
    let error = ChatError.messageNotFound(messageID: "msg-123")

    #expect(error.errorDescription?.contains("Message not found") == true)
    #expect(error.errorDescription?.contains("msg-123") == true)
  }

  @Test("messageNotInConversation has correct description")
  func messageNotInConversationDescription() {
    let error = ChatError.messageNotInConversation(messageID: "msg-456", conversationID: "conv-789")

    #expect(error.errorDescription?.contains("msg-456") == true)
    #expect(error.errorDescription?.contains("conv-789") == true)
  }

  @Test("scopeResolutionFailed has correct description")
  func scopeResolutionFailedDescription() {
    let error = ChatError.scopeResolutionFailed(reason: "AI unavailable")

    #expect(error.errorDescription?.contains("scope") == true)
    #expect(error.errorDescription?.contains("AI unavailable") == true)
  }

  @Test("invalidMessageRole has correct description")
  func invalidMessageRoleDescription() {
    let error = ChatError.invalidMessageRole(messageID: "msg-123", role: .assistant, operation: "edit")

    #expect(error.errorDescription?.contains("msg-123") == true)
    #expect(error.errorDescription?.contains("assistant") == true)
    #expect(error.errorDescription?.contains("edit") == true)
    #expect(error.errorDescription?.contains("only user messages") == true)
  }

  @Test("invalidMessageRole equality checks all parameters")
  func invalidMessageRoleEquality() {
    let error1 = ChatError.invalidMessageRole(messageID: "msg-1", role: .assistant, operation: "edit")
    let error2 = ChatError.invalidMessageRole(messageID: "msg-1", role: .assistant, operation: "edit")
    let error3 = ChatError.invalidMessageRole(messageID: "msg-2", role: .assistant, operation: "edit")
    let error4 = ChatError.invalidMessageRole(messageID: "msg-1", role: .user, operation: "edit")
    let error5 = ChatError.invalidMessageRole(messageID: "msg-1", role: .assistant, operation: "delete")

    #expect(error1 == error2)
    #expect(error1 != error3)
    #expect(error1 != error4)
    #expect(error1 != error5)
  }

  @Test("ChatError is Equatable")
  func isEquatable() {
    let error1 = ChatError.invalidRequest(reason: "Same")
    let error2 = ChatError.invalidRequest(reason: "Same")
    let error3 = ChatError.invalidRequest(reason: "Different")
    let error4 = ChatError.emptyMessages

    #expect(error1 == error2)
    #expect(error1 != error3)
    #expect(error1 != error4)
  }

  @Test("requestFailed equality checks both statusCode and message")
  func requestFailedEquality() {
    let error1 = ChatError.requestFailed(statusCode: 400, message: "Bad")
    let error2 = ChatError.requestFailed(statusCode: 400, message: "Bad")
    let error3 = ChatError.requestFailed(statusCode: 500, message: "Bad")
    let error4 = ChatError.requestFailed(statusCode: 400, message: "Different")

    #expect(error1 == error2)
    #expect(error1 != error3)
    #expect(error1 != error4)
  }

  @Test("all error cases are distinct")
  func allCasesAreDistinct() {
    let errors: [ChatError] = [
      .invalidRequest(reason: "test"),
      .emptyMessages,
      .networkError(reason: "test"),
      .requestFailed(statusCode: 500, message: "test"),
      .invalidResponse(reason: "test"),
      .streamingFailed(reason: "test"),
      .contextExtractionFailed(reason: "test"),
      .documentNotFound(documentID: "test"),
      .folderNotFound(folderID: "test"),
      .conversationNotFound(conversationID: "test"),
      .messageNotFound(messageID: "test"),
      .messageNotInConversation(messageID: "test", conversationID: "test"),
      .scopeResolutionFailed(reason: "test"),
      .invalidMessageRole(messageID: "test", role: .assistant, operation: "test")
    ]

    for i in 0..<errors.count {
      for j in (i + 1)..<errors.count {
        #expect(errors[i] != errors[j])
      }
    }
  }
}

// MARK: - ChatConstants Tests

@Suite("ChatConstants Tests")
struct ChatConstantsTests {

  // DEPRECATED: These constants have been replaced by TokenBudgetConstants.
  // The token management tests now verify the new token-based limits.
  // @Test("maxContextLength is reasonable")
  // func maxContextLengthIsReasonable() {
  //   #expect(ChatConstants.maxContextLength > 0)
  //   #expect(ChatConstants.maxContextLength == 50_000)
  // }
  //
  // @Test("maxMessageHistory is reasonable")
  // func maxMessageHistoryIsReasonable() {
  //   #expect(ChatConstants.maxMessageHistory > 0)
  //   #expect(ChatConstants.maxMessageHistory == 50)
  // }

  @Test("requestTimeout is reasonable")
  func requestTimeoutIsReasonable() {
    #expect(ChatConstants.requestTimeout > 0)
    #expect(ChatConstants.requestTimeout == 30)
  }

  @Test("streamingTimeout is longer than requestTimeout")
  func streamingTimeoutIsLonger() {
    #expect(ChatConstants.streamingTimeout > ChatConstants.requestTimeout)
    #expect(ChatConstants.streamingTimeout == 120)
  }

  @Test("maxNotebooksPerFolder is reasonable")
  func maxNotebooksPerFolderIsReasonable() {
    #expect(ChatConstants.maxNotebooksPerFolder > 0)
    #expect(ChatConstants.maxNotebooksPerFolder == 10)
  }

  @Test("maxNotebooksForAllNotes is reasonable")
  func maxNotebooksForAllNotesIsReasonable() {
    #expect(ChatConstants.maxNotebooksForAllNotes > 0)
    #expect(ChatConstants.maxNotebooksForAllNotes >= ChatConstants.maxNotebooksPerFolder)
  }

  @Test("contextSystemPromptPrefix is not empty")
  func contextSystemPromptPrefixNotEmpty() {
    #expect(ChatConstants.contextSystemPromptPrefix.isEmpty == false)
  }

  @Test("contextSystemPromptSuffix is not empty")
  func contextSystemPromptSuffixNotEmpty() {
    #expect(ChatConstants.contextSystemPromptSuffix.isEmpty == false)
  }
}

// MARK: - MockChatService Extension

extension MockChatService {
  func setSendMessageResponse(_ message: ChatMessage) {
    sendMessageResponse = message
  }

  func setSendMessageError(_ error: Error) {
    sendMessageError = error
  }

  func setStreamChunks(_ chunks: [String]) {
    streamChunks = chunks
  }

  func setStreamMessageError(_ error: Error) {
    streamMessageError = error
  }

  func setSaveStreamedResponseResult(_ message: ChatMessage) {
    saveStreamedResponseResult = message
  }

  func setSaveStreamedResponseError(_ error: Error) {
    saveStreamedResponseError = error
  }

  func setRestartConversationFromMessageResult(_ conversation: ChatConversation) {
    restartConversationFromMessageResult = conversation
  }

  func setRestartConversationFromMessageError(_ error: Error) {
    restartConversationFromMessageError = error
  }

  func setEditMessageResult(_ conversation: ChatConversation) {
    editMessageResult = conversation
  }

  func setEditMessageError(_ error: Error) {
    editMessageError = error
  }
}
