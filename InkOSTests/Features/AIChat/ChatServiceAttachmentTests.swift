// ChatServiceAttachmentTests.swift
// Comprehensive tests for ChatService attachment integration.
// Validates that ChatService correctly routes messages with attachments
// through the multimodal API path (upload, build multimodal message, send/stream multimodal).
// Tests written against ChatServiceAttachmentContract.swift specification.

import Foundation
import Testing

@testable import InkOS

// MARK: - Test Helpers

// Creates a test FileAttachment with specified parameters.
// mimeType: The MIME type for the attachment.
// sizeBytes: Simulated file size in bytes.
// filename: Optional custom filename.
// Returns: A FileAttachment ready for testing.
private func createTestAttachment(
  mimeType: AttachmentMimeType = .png,
  sizeBytes: Int = 1024,
  filename: String? = nil
) -> FileAttachment {
  let resolvedFilename = filename ?? "test.\(mimeType == .pdf ? "pdf" : "png")"
  // Create synthetic base64 data (just repeating character for testing).
  let base64Data = String(repeating: "A", count: sizeBytes)
  return FileAttachment(
    id: UUID().uuidString,
    filename: resolvedFilename,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    base64Data: base64Data,
    estimatedTokens: AttachmentTokenEstimation.tokensPerImage
  )
}

// Creates a test UploadedFileReference for configuring mock responses.
// fileUri: The file URI to use.
// mimeType: The MIME type string.
// Returns: An UploadedFileReference for mock configuration.
private func createTestUploadedFileReference(
  fileUri: String = "https://generativelanguage.googleapis.com/v1/files/test-123",
  mimeType: String = "image/png"
) -> UploadedFileReference {
  return UploadedFileReference(
    fileUri: fileUri,
    mimeType: mimeType,
    name: "files/test-123",
    expiresAt: nil
  )
}

// Extracts the APIFileData from an APIMessageMultimodal for verification.
// message: The multimodal message to extract from.
// Returns: The APIFileData if found, nil otherwise.
private func extractFileDataFromMessage(_ message: APIMessageMultimodal) -> APIFileData? {
  for part in message.parts {
    if case .fileData(let fileData) = part {
      return fileData
    }
  }
  return nil
}

// Extracts the text content from an APIMessageMultimodal for verification.
// message: The multimodal message to extract from.
// Returns: The text content if found, nil otherwise.
private func extractTextFromMessage(_ message: APIMessageMultimodal) -> String? {
  for part in message.parts {
    if case .text(let text) = part {
      return text
    }
  }
  return nil
}

// MARK: - Mock Dependencies for Attachment Tests

// Mock ChatStorage specifically for attachment tests.
// Tracks method calls and allows configuration of return values.
actor AttachmentTestMockChatStorage: ChatStorageProtocol {
  private var conversations: [String: ChatConversation] = [:]
  private var messages: [String: ChatMessage] = [:]

  var createConversationCallCount = 0
  var addMessageCallCount = 0
  var addMessageCalls: [ChatMessage] = []

  func createConversation(initialScope: ChatScope?) -> ChatConversation {
    createConversationCallCount += 1
    let conversation = ChatConversation(
      id: UUID().uuidString,
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: [],
      initialScope: initialScope
    )
    conversations[conversation.id] = conversation
    return conversation
  }

  func getConversation(id: String) -> ChatConversation? {
    return conversations[id]
  }

  func updateConversation(_ conversation: ChatConversation) {
    conversations[conversation.id] = conversation
  }

  func deleteConversation(id: String) {
    if let conversation = conversations[id] {
      for messageID in conversation.messageIDs {
        messages.removeValue(forKey: messageID)
      }
      conversations.removeValue(forKey: id)
    }
  }

  func addMessage(_ message: ChatMessage) {
    addMessageCallCount += 1
    addMessageCalls.append(message)
    messages[message.id] = message
    if var conversation = conversations[message.conversationID] {
      conversation.messageIDs.append(message.id)
      conversation.updatedAt = Date()
      conversations[message.conversationID] = conversation
    }
  }

  func getMessages(conversationID: String) -> [ChatMessage] {
    guard let conversation = conversations[conversationID] else {
      return []
    }
    return conversation.messageIDs
      .compactMap { messages[$0] }
      .sorted { $0.timestamp < $1.timestamp }
  }

  func getMessage(id: String) -> ChatMessage? {
    return messages[id]
  }

  func getAllConversations() -> [ChatConversation] {
    return Array(conversations.values).sorted { $0.updatedAt > $1.updatedAt }
  }

  func truncateConversation(conversationID: String, fromMessageID: String) throws -> ChatConversation {
    guard var conversation = conversations[conversationID] else {
      throw ChatError.conversationNotFound(conversationID: conversationID)
    }

    guard messages[fromMessageID] != nil else {
      throw ChatError.messageNotFound(messageID: fromMessageID)
    }

    guard let index = conversation.messageIDs.firstIndex(of: fromMessageID) else {
      throw ChatError.messageNotInConversation(messageID: fromMessageID, conversationID: conversationID)
    }

    let idsToRemove = Array(conversation.messageIDs[index...])
    for id in idsToRemove {
      messages.removeValue(forKey: id)
    }

    conversation.messageIDs = Array(conversation.messageIDs[..<index])
    conversation.updatedAt = Date()
    conversations[conversationID] = conversation

    return conversation
  }

  // Adds existing messages to the storage for test setup.
  func setupConversationWithMessages(_ conversationID: String, messages: [ChatMessage]) {
    var conversation = ChatConversation(
      id: conversationID,
      createdAt: Date(),
      updatedAt: Date(),
      messageIDs: [],
      initialScope: .chatOnly
    )
    for message in messages {
      self.messages[message.id] = message
      conversation.messageIDs.append(message.id)
    }
    conversations[conversationID] = conversation
  }

  func reset() {
    conversations = [:]
    messages = [:]
    createConversationCallCount = 0
    addMessageCallCount = 0
    addMessageCalls = []
  }
}

// Mock ContextGatherer specifically for attachment tests.
// Returns configurable context for testing different scenarios.
actor AttachmentTestMockContextGatherer: ContextGathererProtocol {
  var gatherContextCallCount = 0
  var resolveAutoScopeCallCount = 0
  var mockContext: GatheredContext?
  var mockResolvedScope: ChatScope = .chatOnly

  func gatherContext(
    scope: ChatScope,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> GatheredContext {
    gatherContextCallCount += 1
    return mockContext ?? GatheredContext.empty(scope: scope)
  }

  func resolveAutoScope(query: String) async throws -> ChatScope {
    resolveAutoScopeCallCount += 1
    return mockResolvedScope
  }

  func setMockContext(_ context: GatheredContext) {
    mockContext = context
  }

  func reset() {
    gatherContextCallCount = 0
    resolveAutoScopeCallCount = 0
    mockContext = nil
    mockResolvedScope = .chatOnly
  }
}

// MARK: - ChatService Attachment Integration Tests

@Suite("ChatService Attachment Integration Tests")
struct ChatServiceAttachmentTests {

  // MARK: - sendMessage Without Attachment Tests

  @Suite("sendMessage Without Attachment")
  struct SendWithoutAttachmentTests {

    @Test("send message without attachment uses text-only path")
    func sendsWithoutAttachmentUsesTextPath() async throws {
      // SCENARIO: Send message without attachment uses text-only path
      // GIVEN: A ChatService with MockChatClient, MockContextGatherer, and MockChatStorage
      // AND: MockContextGatherer configured to return empty context
      // AND: MockChatClient configured to return "AI response"
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setResponse("AI response")

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      // WHEN: sendMessage(text: "Hello", attachment: nil, ...) is called
      let response = try await service.sendMessage(
        text: "Hello",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: chatClient.uploadFile() is NOT called (uploadFileCallCount == 0)
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 0)

      // AND: chatClient.sendMessage() IS called (sendMessageCallCount == 1)
      let sendCount = await mockClient.sendMessageCallCount
      #expect(sendCount == 1)

      // AND: chatClient.sendMessageMultimodal() is NOT called
      let multimodalCount = await mockClient.sendMessageMultimodalCallCount
      #expect(multimodalCount == 0)

      // AND: The returned ChatMessage contains "AI response"
      #expect(response.content == "AI response")
      #expect(response.role == .assistant)
    }

    @Test("send message without attachment passes correct APIMessage format")
    func passesCorrectAPIMessageFormat() async throws {
      // SCENARIO: Send message without attachment passes correct APIMessage format
      // GIVEN: A ChatService with MockChatClient
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setResponse("Response")

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      // WHEN: sendMessage(text: "New question", attachment: nil, ...) is called
      _ = try await service.sendMessage(
        text: "New question",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: chatClient.sendMessage() receives [APIMessage] array
      let calls = await mockClient.sendMessageCalls
      #expect(calls.count == 1)

      // AND: Messages are in text-only APIMessage format
      let sentMessages = calls[0]
      #expect(!sentMessages.isEmpty)

      // AND: The last message content matches user text
      let lastMessage = sentMessages.last
      #expect(lastMessage?.role == "user")
      #expect(lastMessage?.content == "New question")
    }
  }

  // MARK: - sendMessage With Attachment Tests

  @Suite("sendMessage With Attachment")
  struct SendWithAttachmentTests {

    @Test("send message with attachment uploads file first")
    func uploadsFileFirst() async throws {
      // SCENARIO: Send message with attachment uploads file first
      // GIVEN: A ChatService with MockChatClient
      // AND: A valid FileAttachment (PNG image, 1KB, base64 encoded)
      // AND: MockChatClient configured to return UploadedFileReference
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference(fileUri: "files/test-123", mimeType: "image/png")
      await mockClient.setUploadFileResponse(uploadedRef)
      await mockClient.setResponse("Multimodal response")

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment(mimeType: .png, sizeBytes: 1024)

      // WHEN: sendMessage(text: "What is in this image?", attachment: attachment, ...) is called
      _ = try await service.sendMessage(
        text: "What is in this image?",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: chatClient.uploadFile() is called
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 1)

      // AND: uploadFile() receives the exact FileAttachment passed to sendMessage()
      let uploadCalls = await mockClient.uploadFileCalls
      #expect(uploadCalls.count == 1)
      #expect(uploadCalls[0].id == attachment.id)
    }

    @Test("send message with attachment uses multimodal path")
    func usesMultimodalPath() async throws {
      // SCENARIO: Send message with attachment uses multimodal path
      // GIVEN: A ChatService with MockChatClient
      // AND: A valid FileAttachment
      // AND: MockChatClient.sendMessageMultimodalResponse = "I see a cat in the image"
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)
      await mockClient.setMultimodalResponse("I see a cat in the image")

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage(text: "Describe this", attachment: attachment, ...) is called
      let response = try await service.sendMessage(
        text: "Describe this",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: chatClient.sendMessageMultimodal() IS called
      let multimodalCount = await mockClient.sendMessageMultimodalCallCount
      #expect(multimodalCount == 1)

      // AND: chatClient.sendMessage() is NOT called
      let sendCount = await mockClient.sendMessageCallCount
      #expect(sendCount == 0)

      // AND: The returned ChatMessage.content == "I see a cat in the image"
      #expect(response.content == "I see a cat in the image")
    }

    @Test("send message with attachment builds correct multimodal message format")
    func buildsCorrectMultimodalFormat() async throws {
      // SCENARIO: Send message with attachment builds correct multimodal message format
      // GIVEN: A ChatService with MockChatClient
      // AND: FileAttachment with mimeType .png
      // AND: MockChatClient returns UploadedFileReference
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference(
        fileUri: "files/abc",
        mimeType: "image/png"
      )
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment(mimeType: .png)

      // WHEN: sendMessage(text: "What is this?", attachment: attachment, ...) is called
      _ = try await service.sendMessage(
        text: "What is this?",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: chatClient.sendMessageMultimodal() receives [APIMessageMultimodal] array
      let calls = await mockClient.sendMessageMultimodalCalls
      #expect(calls.count == 1)

      let messages = calls[0]
      #expect(!messages.isEmpty)

      // AND: The last message (user's new message) has role "user"
      let lastMessage = messages.last!
      #expect(lastMessage.role == "user")

      // AND: The last message has parts array with 2 elements
      #expect(lastMessage.parts.count == 2)

      // AND: parts[0] is .fileData with correct fileUri and mimeType
      if case .fileData(let fileData) = lastMessage.parts[0] {
        #expect(fileData.fileUri == "files/abc")
        #expect(fileData.mimeType == "image/png")
      } else {
        Issue.record("First part should be fileData")
      }

      // AND: parts[1] is .text containing the user's text
      if case .text(let text) = lastMessage.parts[1] {
        #expect(text.contains("What is this?"))
      } else {
        Issue.record("Second part should be text")
      }
    }

    @Test("send message with attachment preserves conversation history")
    func preservesConversationHistory() async throws {
      // SCENARIO: Send message with attachment preserves conversation history
      // GIVEN: A ChatService with MockChatClient and MockChatStorage
      // AND: An existing conversation with 3 messages
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      // Setup existing conversation with history.
      let conversationID = "conv-1"
      let existingMessages = [
        ChatMessage(
          id: "msg-1",
          conversationID: conversationID,
          role: .user,
          content: "First question",
          timestamp: Date().addingTimeInterval(-300),
          contextMetadata: nil
        ),
        ChatMessage(
          id: "msg-2",
          conversationID: conversationID,
          role: .assistant,
          content: "First answer",
          timestamp: Date().addingTimeInterval(-200),
          contextMetadata: nil
        ),
        ChatMessage(
          id: "msg-3",
          conversationID: conversationID,
          role: .user,
          content: "Second question",
          timestamp: Date().addingTimeInterval(-100),
          contextMetadata: nil
        )
      ]
      await mockStorage.setupConversationWithMessages(conversationID, messages: existingMessages)

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage(text: "New message", attachment: attachment, conversationID: "conv-1", ...) is called
      _ = try await service.sendMessage(
        text: "New message",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: conversationID,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: chatClient.sendMessageMultimodal() receives all messages
      let calls = await mockClient.sendMessageMultimodalCalls
      #expect(calls.count == 1)

      let sentMessages = calls[0]
      // Should have existing 3 messages plus the new message.
      #expect(sentMessages.count >= 4)

      // AND: Only the newest user message contains the file attachment parts.
      let lastMessage = sentMessages.last!
      #expect(lastMessage.parts.count == 2)  // File + text.

      // Older messages should be text-only.
      for i in 0..<(sentMessages.count - 1) {
        let olderMessage = sentMessages[i]
        #expect(olderMessage.parts.count == 1)
        if case .text = olderMessage.parts[0] {
          // Expected text-only part.
        } else {
          Issue.record("Older messages should have text-only parts")
        }
      }
    }
  }

  // MARK: - streamMessage Without Attachment Tests

  @Suite("streamMessage Without Attachment")
  struct StreamWithoutAttachmentTests {

    @Test("stream message without attachment uses text-only path")
    func usesTextOnlyPath() async throws {
      // SCENARIO: Stream message without attachment uses text-only path
      // GIVEN: A ChatService with MockChatClient
      // AND: MockChatClient.streamMessageChunks = ["Hello", " there"]
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setStreamChunks(["Hello", " there"])

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      // WHEN: streamMessage(text: "Hi", attachment: nil, ...) is called
      let (userMessage, stream) = try await service.streamMessage(
        text: "Hi",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // Consume stream to trigger calls.
      var chunks: [String] = []
      for try await chunk in stream {
        chunks.append(chunk)
      }

      // THEN: chatClient.uploadFile() is NOT called
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 0)

      // AND: chatClient.streamMessage() IS called
      let streamCount = await mockClient.streamMessageCallCount
      #expect(streamCount == 1)

      // AND: chatClient.streamMessageMultimodal() is NOT called
      let multimodalStreamCount = await mockClient.streamMessageMultimodalCallCount
      #expect(multimodalStreamCount == 0)

      // AND: The returned stream yields "Hello", " there" in order
      #expect(chunks == ["Hello", " there"])

      // AND: User message is returned
      #expect(userMessage.role == .user)
      #expect(userMessage.content == "Hi")
    }

    @Test("stream message without attachment returns user message immediately")
    func returnsUserMessageImmediately() async throws {
      // SCENARIO: Stream message without attachment returns user message immediately
      // GIVEN: A ChatService with MockChatClient
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      // WHEN: streamMessage(text: "Question", attachment: nil, ...) is called
      let (userMessage, _) = try await service.streamMessage(
        text: "Question",
        attachment: nil,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: The returned tuple contains userMessage with role .user
      #expect(userMessage.role == .user)

      // AND: userMessage.content contains "Question"
      #expect(userMessage.content.contains("Question"))

      // AND: userMessage is already saved to storage
      let addMessageCount = await mockStorage.addMessageCallCount
      #expect(addMessageCount >= 1)
    }
  }

  // MARK: - streamMessage With Attachment Tests

  @Suite("streamMessage With Attachment")
  struct StreamWithAttachmentTests {

    @Test("stream message with attachment uploads file first")
    func uploadsFileFirst() async throws {
      // SCENARIO: Stream message with attachment uploads file first
      // GIVEN: A ChatService with MockChatClient
      // AND: A valid FileAttachment (PDF, 5KB)
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference(mimeType: "application/pdf")
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment(mimeType: .pdf, sizeBytes: 5120)

      // WHEN: streamMessage(text: "Summarize this document", attachment: attachment, ...) is called
      let (_, stream) = try await service.streamMessage(
        text: "Summarize this document",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // Consume stream.
      for try await _ in stream {}

      // THEN: chatClient.uploadFile() is called
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 1)

      // AND: uploadFile() receives the FileAttachment
      let uploadCalls = await mockClient.uploadFileCalls
      #expect(uploadCalls[0].mimeType == .pdf)
    }

    @Test("stream message with attachment uses multimodal streaming path")
    func usesMultimodalStreamingPath() async throws {
      // SCENARIO: Stream message with attachment uses multimodal streaming path
      // GIVEN: A ChatService with MockChatClient
      // AND: MockChatClient.streamMessageMultimodalChunks = ["Summary: ", "This document ", "contains..."]
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)
      await mockClient.setMultimodalStreamChunks(["Summary: ", "This document ", "contains..."])

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: streamMessage(text: "Summarize", attachment: attachment, ...) is called
      let (_, stream) = try await service.streamMessage(
        text: "Summarize",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // Consume stream.
      var chunks: [String] = []
      for try await chunk in stream {
        chunks.append(chunk)
      }

      // THEN: chatClient.streamMessageMultimodal() IS called
      let multimodalStreamCount = await mockClient.streamMessageMultimodalCallCount
      #expect(multimodalStreamCount == 1)

      // AND: chatClient.streamMessage() is NOT called
      let streamCount = await mockClient.streamMessageCallCount
      #expect(streamCount == 0)

      // AND: The returned stream yields the expected chunks
      #expect(chunks == ["Summary: ", "This document ", "contains..."])
    }

    @Test("stream message with attachment builds correct multimodal format")
    func buildsCorrectMultimodalFormat() async throws {
      // SCENARIO: Stream message with attachment builds correct multimodal format
      // GIVEN: A ChatService with MockChatClient
      // AND: FileAttachment with mimeType .pdf
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference(
        fileUri: "files/pdf-doc",
        mimeType: "application/pdf"
      )
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment(mimeType: .pdf)

      // WHEN: streamMessage(text: "Analyze", attachment: attachment, ...) is called
      let (_, stream) = try await service.streamMessage(
        text: "Analyze",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // Consume stream.
      for try await _ in stream {}

      // THEN: chatClient.streamMessageMultimodal() receives [APIMessageMultimodal] array
      let calls = await mockClient.streamMessageMultimodalCalls
      #expect(calls.count == 1)

      let messages = calls[0]
      let lastMessage = messages.last!

      // AND: The last message has parts[0] as .fileData
      if case .fileData(let fileData) = lastMessage.parts[0] {
        #expect(fileData.fileUri == "files/pdf-doc")
        #expect(fileData.mimeType == "application/pdf")
      } else {
        Issue.record("First part should be fileData")
      }

      // AND: The last message has parts[1] as .text containing user text
      if case .text(let text) = lastMessage.parts[1] {
        #expect(text.contains("Analyze"))
      } else {
        Issue.record("Second part should be text")
      }
    }

    @Test("stream message with attachment saves user message before streaming")
    func savesUserMessageBeforeStreaming() async throws {
      // SCENARIO: Stream message with attachment saves user message before streaming
      // GIVEN: A ChatService with MockChatClient and MockChatStorage
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: streamMessage(text: "What is this?", attachment: attachment, ...) is called
      let (userMessage, _) = try await service.streamMessage(
        text: "What is this?",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: storage.addMessage() is called with user message
      let addedMessages = await mockStorage.addMessageCalls
      #expect(!addedMessages.isEmpty)

      // AND: User message is saved BEFORE streaming begins
      let firstAddedMessage = addedMessages[0]
      #expect(firstAddedMessage.role == .user)

      // AND: The returned userMessage has the same ID as the stored message
      #expect(userMessage.id == firstAddedMessage.id)
    }
  }

  // MARK: - Upload Error Propagation Tests

  @Suite("Upload Error Propagation")
  struct UploadErrorTests {

    @Test("sendMessage propagates uploadFile network error")
    func propagatesNetworkError() async throws {
      // SCENARIO: sendMessage propagates uploadFile network error
      // GIVEN: MockChatClient.uploadFileError = ChatError.networkError
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setUploadFileError(ChatError.networkError(reason: "Connection failed"))

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage(text: "Test", attachment: attachment, ...) is called
      // THEN: ChatError.networkError is thrown
      await #expect(throws: ChatError.self) {
        _ = try await service.sendMessage(
          text: "Test",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
      }

      // AND: chatClient.sendMessageMultimodal() is NOT called
      let multimodalCount = await mockClient.sendMessageMultimodalCallCount
      #expect(multimodalCount == 0)
    }

    @Test("sendMessage propagates uploadFile uploadFailed error")
    func propagatesUploadFailedError() async throws {
      // SCENARIO: sendMessage propagates uploadFile uploadFailed error
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setUploadFileError(ChatError.uploadFailed(reason: "Server rejected file"))

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage is called
      // THEN: ChatError.uploadFailed is thrown
      do {
        _ = try await service.sendMessage(
          text: "Test",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected error to be thrown")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Server rejected file")
        } else {
          Issue.record("Expected uploadFailed error")
        }
      }
    }

    @Test("sendMessage propagates uploadFile processingFailed error")
    func propagatesProcessingFailedError() async throws {
      // SCENARIO: sendMessage propagates uploadFile processingFailed error
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setUploadFileError(ChatError.processingFailed(filename: "test.pdf"))

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage is called
      // THEN: ChatError.processingFailed is thrown
      do {
        _ = try await service.sendMessage(
          text: "Test",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected error to be thrown")
      } catch let error as ChatError {
        if case .processingFailed(let filename) = error {
          #expect(filename == "test.pdf")
        } else {
          Issue.record("Expected processingFailed error")
        }
      }
    }

    @Test("sendMessage propagates uploadFile processingTimeout error")
    func propagatesProcessingTimeoutError() async throws {
      // SCENARIO: sendMessage propagates uploadFile processingTimeout error
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setUploadFileError(ChatError.processingTimeout(filename: "large.pdf"))

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage is called
      // THEN: ChatError.processingTimeout is thrown
      do {
        _ = try await service.sendMessage(
          text: "Test",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected error to be thrown")
      } catch let error as ChatError {
        if case .processingTimeout(let filename) = error {
          #expect(filename == "large.pdf")
        } else {
          Issue.record("Expected processingTimeout error")
        }
      }
    }

    @Test("streamMessage propagates uploadFile errors")
    func streamPropagatesUploadErrors() async throws {
      // SCENARIO: streamMessage propagates uploadFile errors
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      await mockClient.setUploadFileError(ChatError.uploadFailed(reason: "Quota exceeded"))

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: streamMessage(text: "Test", attachment: attachment, ...) is called
      // THEN: ChatError.uploadFailed is thrown
      await #expect(throws: ChatError.self) {
        _ = try await service.streamMessage(
          text: "Test",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
      }

      // AND: chatClient.streamMessageMultimodal() is NOT called
      let multimodalStreamCount = await mockClient.streamMessageMultimodalCallCount
      #expect(multimodalStreamCount == 0)
    }
  }

  // MARK: - Multimodal Message Format Tests

  @Suite("Multimodal Message Format")
  struct MessageFormatTests {

    @Test("file reference appears first in parts array")
    func fileReferenceAppearsFirst() async throws {
      // SCENARIO: File reference appears first in parts array
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage is called with attachment
      _ = try await service.sendMessage(
        text: "Analyze this",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: The APIMessageMultimodal parts array has file data at index 0
      let calls = await mockClient.sendMessageMultimodalCalls
      let lastMessage = calls[0].last!

      // File data should be at index 0.
      if case .fileData = lastMessage.parts[0] {
        // Expected.
      } else {
        Issue.record("File data should be at index 0")
      }

      // Text content should be at index 1.
      if case .text = lastMessage.parts[1] {
        // Expected.
      } else {
        Issue.record("Text should be at index 1")
      }
    }

    @Test("file data part contains correct URI from upload response")
    func fileDataContainsCorrectURI() async throws {
      // SCENARIO: File data part contains correct URI from upload response
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = UploadedFileReference(
        fileUri: "https://generativelanguage.googleapis.com/v1/files/unique-id-123",
        mimeType: "image/jpeg",
        name: "files/unique-id-123",
        expiresAt: "2024-12-31T23:59:59Z"
      )
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment(mimeType: .jpeg)

      // WHEN: sendMessage is called
      _ = try await service.sendMessage(
        text: "What is this?",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: The APIMessageMultimodal parts[0] is .fileData
      let calls = await mockClient.sendMessageMultimodalCalls
      let lastMessage = calls[0].last!

      if case .fileData(let fileData) = lastMessage.parts[0] {
        // AND: fileData.fileUri matches the upload response
        #expect(fileData.fileUri == "https://generativelanguage.googleapis.com/v1/files/unique-id-123")
        // AND: fileData.mimeType == "image/jpeg"
        #expect(fileData.mimeType == "image/jpeg")
      } else {
        Issue.record("Expected fileData part")
      }
    }

    @Test("text part contains user message with context")
    func textPartContainsContext() async throws {
      // SCENARIO: Text part contains user message with context
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      // Configure context gatherer to return context.
      let context = GatheredContext(
        scope: .thisNote,
        text: "Context: Meeting notes from yesterday",
        documentIDs: ["doc-1"],
        documentCount: 1,
        characterCount: 38
      )
      await mockGatherer.setMockContext(context)

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage is called with context-aware scope
      _ = try await service.sendMessage(
        text: "Summarize based on my notes",
        attachment: attachment,
        scope: .thisNote,
        conversationID: nil,
        currentNoteID: "note-1",
        currentFolderID: nil
      )

      // THEN: The text part contains both context and user text
      let calls = await mockClient.sendMessageMultimodalCalls
      let lastMessage = calls[0].last!

      if case .text(let text) = lastMessage.parts[1] {
        #expect(text.contains("Context: Meeting notes"))
        #expect(text.contains("Summarize based on my notes"))
        // AND: Format matches existing context embedding behavior
        #expect(text.contains("---"))
        #expect(text.contains("User:"))
      } else {
        Issue.record("Expected text part")
      }
    }

    @Test("text part contains only user text when context is empty")
    func textPartContainsOnlyUserTextWhenNoContext() async throws {
      // SCENARIO: Text part contains only user text when context is empty
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      // Configure context gatherer to return empty context.
      let emptyContext = GatheredContext.empty(scope: .chatOnly)
      await mockGatherer.setMockContext(emptyContext)

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage is called with chatOnly scope
      _ = try await service.sendMessage(
        text: "Describe the image",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: The text part contains only the user text
      let calls = await mockClient.sendMessageMultimodalCalls
      let lastMessage = calls[0].last!

      if case .text(let text) = lastMessage.parts[1] {
        #expect(text == "Describe the image")
        // AND: No context separator is present
        #expect(!text.contains("---"))
      } else {
        Issue.record("Expected text part")
      }
    }

    @Test("historical messages in multimodal array are text-only")
    func historicalMessagesAreTextOnly() async throws {
      // SCENARIO: Historical messages in multimodal array are text-only
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      // Setup existing conversation with history.
      let conversationID = "conv-1"
      let existingMessages = [
        ChatMessage(
          id: "msg-1",
          conversationID: conversationID,
          role: .user,
          content: "First question",
          timestamp: Date().addingTimeInterval(-300),
          contextMetadata: nil
        ),
        ChatMessage(
          id: "msg-2",
          conversationID: conversationID,
          role: .assistant,
          content: "First answer",
          timestamp: Date().addingTimeInterval(-200),
          contextMetadata: nil
        ),
        ChatMessage(
          id: "msg-3",
          conversationID: conversationID,
          role: .user,
          content: "Second question",
          timestamp: Date().addingTimeInterval(-100),
          contextMetadata: nil
        )
      ]
      await mockStorage.setupConversationWithMessages(conversationID, messages: existingMessages)

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage is called with attachment
      _ = try await service.sendMessage(
        text: "New question",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: conversationID,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: chatClient.sendMessageMultimodal() receives 4 APIMessageMultimodal messages
      let calls = await mockClient.sendMessageMultimodalCalls
      let messages = calls[0]
      #expect(messages.count == 4)

      // AND: Messages 0-2 each have a single .text part (no file data)
      for i in 0..<3 {
        let olderMessage = messages[i]
        #expect(olderMessage.parts.count == 1)
        if case .text = olderMessage.parts[0] {
          // Expected.
        } else {
          Issue.record("Older messages should have text-only parts")
        }
      }

      // AND: Message 3 (newest) has [.fileData, .text] parts
      let newestMessage = messages[3]
      #expect(newestMessage.parts.count == 2)
      if case .fileData = newestMessage.parts[0] {
        // Expected.
      } else {
        Issue.record("Newest message should have fileData first")
      }
    }
  }

  // MARK: - Edge Cases

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("empty text with attachment throws invalidRequest")
    func emptyTextWithAttachmentThrows() async throws {
      // EDGE CASE: Empty text with attachment
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage(text: "", attachment: attachment, ...) is called
      // THEN: ChatError.invalidRequest is thrown
      do {
        _ = try await service.sendMessage(
          text: "",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected error to be thrown")
      } catch let error as ChatError {
        if case .invalidRequest(let reason) = error {
          #expect(reason.contains("empty"))
        } else {
          Issue.record("Expected invalidRequest error")
        }
      }

      // AND: uploadFile() is NOT called
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 0)
    }

    @Test("whitespace-only text with attachment throws invalidRequest")
    func whitespaceOnlyTextWithAttachmentThrows() async throws {
      // EDGE CASE: Whitespace-only text with attachment
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage(text: "   \n\t  ", attachment: attachment, ...) is called
      // THEN: ChatError.invalidRequest is thrown
      await #expect(throws: ChatError.self) {
        _ = try await service.sendMessage(
          text: "   \n\t  ",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )
      }

      // AND: uploadFile() is NOT called
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 0)
    }

    @Test("conversation not found with attachment throws error")
    func conversationNotFoundWithAttachmentThrows() async throws {
      // EDGE CASE: Conversation not found with attachment
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage with invalid conversationID is called
      // THEN: ChatError.conversationNotFound is thrown
      do {
        _ = try await service.sendMessage(
          text: "Test",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: "invalid-conv",
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected error to be thrown")
      } catch let error as ChatError {
        if case .conversationNotFound(let convID) = error {
          #expect(convID == "invalid-conv")
        } else {
          Issue.record("Expected conversationNotFound error")
        }
      }

      // AND: uploadFile() is NOT called
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 0)
    }

    @Test("new conversation created when conversationID is nil with attachment")
    func newConversationCreatedWithAttachment() async throws {
      // EDGE CASE: New conversation created when conversationID is nil
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      let attachment = createTestAttachment()

      // WHEN: sendMessage(text: "First message", attachment: attachment, conversationID: nil, ...) is called
      let response = try await service.sendMessage(
        text: "First message",
        attachment: attachment,
        scope: .chatOnly,
        conversationID: nil,
        currentNoteID: nil,
        currentFolderID: nil
      )

      // THEN: storage.createConversation() is called
      let createCount = await mockStorage.createConversationCallCount
      #expect(createCount == 1)

      // AND: Upload and multimodal send proceed normally
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 1)

      let multimodalCount = await mockClient.sendMessageMultimodalCallCount
      #expect(multimodalCount == 1)

      // AND: Messages are stored in the new conversation
      #expect(!response.conversationID.isEmpty)
    }

    @Test("attachment with all MIME types works")
    func allMimeTypesWork() async throws {
      // EDGE CASE: Attachment with all MIME types works
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let mimeTypes: [AttachmentMimeType] = [.png, .jpeg, .webp, .heic, .heif, .gif, .pdf, .plainText]

      for mimeType in mimeTypes {
        await mockClient.reset()
        await mockStorage.reset()

        let uploadedRef = createTestUploadedFileReference(mimeType: mimeType.rawValue)
        await mockClient.setUploadFileResponse(uploadedRef)

        let service = ChatService(
          chatClient: mockClient,
          contextGatherer: mockGatherer,
          storage: mockStorage
        )

        let attachment = createTestAttachment(mimeType: mimeType)

        // WHEN: sendMessage is called with this MIME type
        // THEN: Upload and send complete successfully
        _ = try await service.sendMessage(
          text: "Test \(mimeType.rawValue)",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: nil,
          currentNoteID: nil,
          currentFolderID: nil
        )

        let uploadCount = await mockClient.uploadFileCallCount
        #expect(uploadCount == 1, "Upload should be called for \(mimeType.rawValue)")

        // AND: The correct mimeType string is included in APIFileData
        let calls = await mockClient.sendMessageMultimodalCalls
        let lastMessage = calls[0].last!
        if case .fileData(let fileData) = lastMessage.parts[0] {
          #expect(fileData.mimeType == mimeType.rawValue)
        }
      }
    }

    @Test("multiple sequential messages with attachments")
    func multipleSequentialMessagesWithAttachments() async throws {
      // EDGE CASE: Multiple sequential messages with attachments
      let mockClient = MockChatClient()
      let mockStorage = AttachmentTestMockChatStorage()
      let mockGatherer = AttachmentTestMockContextGatherer()

      let uploadedRef = createTestUploadedFileReference()
      await mockClient.setUploadFileResponse(uploadedRef)

      let service = ChatService(
        chatClient: mockClient,
        contextGatherer: mockGatherer,
        storage: mockStorage
      )

      // Create initial conversation.
      let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

      // WHEN: sendMessage with attachment is called 3 times in sequence
      for i in 1...3 {
        let attachment = createTestAttachment()
        _ = try await service.sendMessage(
          text: "Message \(i)",
          attachment: attachment,
          scope: .chatOnly,
          conversationID: conversation.id,
          currentNoteID: nil,
          currentFolderID: nil
        )
      }

      // THEN: Each call uploads its own attachment
      let uploadCount = await mockClient.uploadFileCallCount
      #expect(uploadCount == 3)

      // AND: Each subsequent message includes the growing history
      let calls = await mockClient.sendMessageMultimodalCalls
      #expect(calls.count == 3)

      // First call: 1 message (the new one).
      // Second call: 3 messages (user + assistant + new user).
      // Third call: 5 messages (previous + assistant + new user).
      // Message counts depend on whether assistant responses are saved.
    }
  }
}
