// ChatClientTests.swift
// Tests for ChatClient Firebase HTTP operations.
// These tests use mock implementations until ChatClient is implemented.
// Tests against contract-defined types (APIMessage, ChatConfiguration, etc.)
// and mock implementations for protocol testing.

import Foundation
import Testing

@testable import InkOS

// MARK: - Mock URL Protocol for ChatClient Tests

// Custom URLProtocol to intercept and mock network requests for ChatClient.
// Allows testing HTTP interactions without actual network calls.
// Ready for use when ChatClient is implemented.
final class ChatClientMockURLProtocol: URLProtocol {
  // Handler to process requests and return mock responses.
  // Uses nonisolated(unsafe) for concurrent access in parallel tests.
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override static func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override static func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let handler = ChatClientMockURLProtocol.requestHandler else {
      client?.urlProtocol(
        self, didFailWithError: NSError(domain: "ChatClientMockURLProtocol", code: -1))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

// MARK: - MockChatClient

// Mock implementation of ChatClientProtocol for testing dependent services.
// Tracks method invocations and allows configuring return values and errors.
actor MockChatClient: ChatClientProtocol {

  // Tracks the number of times sendMessage was called.
  private(set) var sendMessageCallCount = 0

  // Tracks the messages passed to each sendMessage call.
  private(set) var sendMessageCalls: [[APIMessage]] = []

  // Tracks the number of times streamMessage was called.
  private(set) var streamMessageCallCount = 0

  // Tracks the messages passed to each streamMessage call.
  private(set) var streamMessageCalls: [[APIMessage]] = []

  // Response to return from sendMessage.
  var sendMessageResponse: String = "Mock response"

  // Error to throw from sendMessage.
  var sendMessageError: Error?

  // Chunks to yield from streamMessage.
  var streamMessageChunks: [String] = ["Mock ", "streaming ", "response"]

  // Error to throw during streaming.
  var streamError: Error?

  // Tracks the number of times uploadFile was called.
  private(set) var uploadFileCallCount = 0

  // Tracks the attachments passed to each uploadFile call.
  private(set) var uploadFileCalls: [FileAttachment] = []

  // Response to return from uploadFile.
  var uploadFileResponse: UploadedFileReference?

  // Error to throw from uploadFile.
  var uploadFileError: Error?

  // Tracks the number of times sendMessageMultimodal was called.
  private(set) var sendMessageMultimodalCallCount = 0

  // Tracks the messages passed to each sendMessageMultimodal call.
  private(set) var sendMessageMultimodalCalls: [[APIMessageMultimodal]] = []

  // Response to return from sendMessageMultimodal.
  var sendMessageMultimodalResponse: String = "Mock multimodal response"

  // Error to throw from sendMessageMultimodal.
  var sendMessageMultimodalError: Error?

  // Tracks the number of times streamMessageMultimodal was called.
  private(set) var streamMessageMultimodalCallCount = 0

  // Tracks the messages passed to each streamMessageMultimodal call.
  private(set) var streamMessageMultimodalCalls: [[APIMessageMultimodal]] = []

  // Chunks to yield from streamMessageMultimodal.
  var streamMessageMultimodalChunks: [String] = ["Mock ", "multimodal ", "streaming ", "response"]

  // Error to throw during multimodal streaming.
  var streamMessageMultimodalError: Error?

  func sendMessage(messages: [APIMessage]) async throws -> String {
    sendMessageCallCount += 1
    sendMessageCalls.append(messages)

    if let error = sendMessageError {
      throw error
    }

    return sendMessageResponse
  }

  func streamMessage(messages: [APIMessage]) -> AsyncThrowingStream<String, Error> {
    streamMessageCallCount += 1
    streamMessageCalls.append(messages)

    return AsyncThrowingStream { continuation in
      Task {
        for chunk in self.streamMessageChunks {
          if let error = self.streamError {
            continuation.finish(throwing: error)
            return
          }
          continuation.yield(chunk)
        }
        continuation.finish()
      }
    }
  }

  func uploadFile(_ attachment: FileAttachment) async throws -> UploadedFileReference {
    uploadFileCallCount += 1
    uploadFileCalls.append(attachment)

    if let error = uploadFileError {
      throw error
    }

    if let response = uploadFileResponse {
      return response
    }

    // Return default mock response.
    return UploadedFileReference(
      fileUri: "https://generativelanguage.googleapis.com/v1beta/files/mock-file-id",
      mimeType: attachment.mimeType.rawValue,
      name: "files/mock-file-id",
      expiresAt: nil
    )
  }

  func sendMessageMultimodal(messages: [APIMessageMultimodal]) async throws -> String {
    sendMessageMultimodalCallCount += 1
    sendMessageMultimodalCalls.append(messages)

    if let error = sendMessageMultimodalError {
      throw error
    }

    return sendMessageMultimodalResponse
  }

  func streamMessageMultimodal(messages: [APIMessageMultimodal]) -> AsyncThrowingStream<String, Error> {
    streamMessageMultimodalCallCount += 1
    streamMessageMultimodalCalls.append(messages)

    return AsyncThrowingStream { continuation in
      Task {
        for chunk in self.streamMessageMultimodalChunks {
          if let error = self.streamMessageMultimodalError {
            continuation.finish(throwing: error)
            return
          }
          continuation.yield(chunk)
        }
        continuation.finish()
      }
    }
  }

  // Resets all recorded state.
  func reset() {
    sendMessageCallCount = 0
    sendMessageCalls = []
    streamMessageCallCount = 0
    streamMessageCalls = []
    sendMessageResponse = "Mock response"
    sendMessageError = nil
    streamMessageChunks = ["Mock ", "streaming ", "response"]
    streamError = nil
    uploadFileCallCount = 0
    uploadFileCalls = []
    uploadFileResponse = nil
    uploadFileError = nil
    sendMessageMultimodalCallCount = 0
    sendMessageMultimodalCalls = []
    sendMessageMultimodalResponse = "Mock multimodal response"
    sendMessageMultimodalError = nil
    streamMessageMultimodalCallCount = 0
    streamMessageMultimodalCalls = []
    streamMessageMultimodalChunks = ["Mock ", "multimodal ", "streaming ", "response"]
    streamMessageMultimodalError = nil
  }
}

// MARK: - ChatClient Tests

// Note: Tests against the real ChatClient will be enabled once implementation exists.
// For now, these tests verify the mock implementation and contract types work correctly.
@Suite("ChatClient Tests", .serialized)
struct ChatClientTests {

  // Creates a URLSession configured with mock protocol.
  private func createMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ChatClientMockURLProtocol.self]
    return URLSession(configuration: config)
  }

  // Creates a mock HTTP response with the specified status code.
  private func createResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
    let url = request.url ?? URL(string: "https://test.example.com")!
    return HTTPURLResponse(
      url: url,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    ) ?? HTTPURLResponse()
  }

  // Creates a successful API response.
  private func createSuccessResponse(content: String) -> Data {
    let response: [String: Any] = [
      "result": [
        "response": content
      ]
    ]
    do {
      return try JSONSerialization.data(withJSONObject: response)
    } catch {
      return Data("{}".utf8)
    }
  }

  // MARK: - MockChatClient sendMessage Tests

  @Suite("sendMessage Operations via Mock")
  struct SendMessageMockTests {

    @Test("mock returns configured response")
    func mockReturnsConfiguredResponse() async throws {
      let mockClient = MockChatClient()
      await mockClient.setResponse("Custom AI response")

      let messages = [APIMessage(role: "user", content: "Hello")]
      let response = try await mockClient.sendMessage(messages: messages)

      #expect(response == "Custom AI response")
    }

    @Test("mock tracks call count")
    func mockTracksCallCount() async throws {
      let mockClient = MockChatClient()

      let messages = [APIMessage(role: "user", content: "Hello")]
      _ = try await mockClient.sendMessage(messages: messages)
      _ = try await mockClient.sendMessage(messages: messages)

      let count = await mockClient.sendMessageCallCount
      #expect(count == 2)
    }

    @Test("mock tracks message parameters")
    func mockTracksParameters() async throws {
      let mockClient = MockChatClient()

      let messages = [
        APIMessage(role: "user", content: "First message"),
        APIMessage(role: "assistant", content: "Response"),
        APIMessage(role: "user", content: "Second message")
      ]
      _ = try await mockClient.sendMessage(messages: messages)

      let calls = await mockClient.sendMessageCalls
      #expect(calls.count == 1)
      #expect(calls[0].count == 3)
      #expect(calls[0][0].content == "First message")
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let mockClient = MockChatClient()
      await mockClient.setError(ChatError.networkError(reason: "Connection failed"))

      let messages = [APIMessage(role: "user", content: "Hello")]

      await #expect(throws: ChatError.self) {
        _ = try await mockClient.sendMessage(messages: messages)
      }
    }

    @Test("mock throws specific error types")
    func mockThrowsSpecificErrorTypes() async {
      let mockClient = MockChatClient()
      await mockClient.setError(ChatError.requestFailed(statusCode: 500, message: "Server error"))

      let messages = [APIMessage(role: "user", content: "Hello")]

      do {
        _ = try await mockClient.sendMessage(messages: messages)
        Issue.record("Expected error to be thrown")
      } catch let error as ChatError {
        if case .requestFailed(let statusCode, let message) = error {
          #expect(statusCode == 500)
          #expect(message == "Server error")
        } else {
          Issue.record("Expected requestFailed error")
        }
      } catch {
        Issue.record("Expected ChatError")
      }
    }
  }

  // MARK: - MockChatClient streamMessage Tests

  @Suite("streamMessage Operations via Mock")
  struct StreamMessageMockTests {

    @Test("mock returns AsyncThrowingStream")
    func mockReturnsStream() async {
      let mockClient = MockChatClient()

      let messages = [APIMessage(role: "user", content: "Hello")]
      let stream = await mockClient.streamMessage(messages: messages)

      var chunks: [String] = []
      do {
        for try await chunk in stream {
          chunks.append(chunk)
        }
      } catch {
        Issue.record("Stream should not throw")
      }

      #expect(chunks.count > 0)
    }

    @Test("mock yields configured chunks in order")
    func mockYieldsChunksInOrder() async throws {
      let mockClient = MockChatClient()
      await mockClient.setStreamChunks(["First ", "Second ", "Third"])

      let messages = [APIMessage(role: "user", content: "Hello")]
      let stream = await mockClient.streamMessage(messages: messages)

      var chunks: [String] = []
      for try await chunk in stream {
        chunks.append(chunk)
      }

      #expect(chunks == ["First ", "Second ", "Third"])
    }

    @Test("mock handles empty chunks array")
    func mockHandlesEmptyChunks() async throws {
      let mockClient = MockChatClient()
      await mockClient.setStreamChunks([])

      let messages = [APIMessage(role: "user", content: "Hello")]
      let stream = await mockClient.streamMessage(messages: messages)

      var chunks: [String] = []
      for try await chunk in stream {
        chunks.append(chunk)
      }

      #expect(chunks.isEmpty)
    }

    @Test("mock stream propagates errors")
    func mockStreamPropagatesErrors() async {
      let mockClient = MockChatClient()
      await mockClient.setStreamError(ChatError.streamingFailed(reason: "Connection lost"))

      let messages = [APIMessage(role: "user", content: "Hello")]
      let stream = await mockClient.streamMessage(messages: messages)

      var didThrow = false
      do {
        for try await _ in stream {
          // Should throw before completing.
        }
      } catch {
        didThrow = true
        #expect(error is ChatError)
      }

      #expect(didThrow)
    }

    @Test("mock tracks stream call count")
    func mockTracksStreamCallCount() async {
      let mockClient = MockChatClient()

      let messages = [APIMessage(role: "user", content: "Hello")]
      _ = await mockClient.streamMessage(messages: messages)
      _ = await mockClient.streamMessage(messages: messages)

      let count = await mockClient.streamMessageCallCount
      #expect(count == 2)
    }

    @Test("mock tracks stream message parameters")
    func mockTracksStreamParameters() async {
      let mockClient = MockChatClient()

      let messages = [
        APIMessage(role: "user", content: "First"),
        APIMessage(role: "assistant", content: "Response"),
        APIMessage(role: "user", content: "Second")
      ]
      _ = await mockClient.streamMessage(messages: messages)

      let calls = await mockClient.streamMessageCalls
      #expect(calls.count == 1)
      #expect(calls[0].count == 3)
    }
  }

  // MARK: - Mock reset Tests

  @Suite("MockChatClient Reset")
  struct MockResetTests {

    @Test("reset clears call counts")
    func resetClearsCallCounts() async throws {
      let mockClient = MockChatClient()

      let messages = [APIMessage(role: "user", content: "Hello")]
      _ = try await mockClient.sendMessage(messages: messages)
      _ = await mockClient.streamMessage(messages: messages)

      await mockClient.reset()

      let sendCount = await mockClient.sendMessageCallCount
      let streamCount = await mockClient.streamMessageCallCount

      #expect(sendCount == 0)
      #expect(streamCount == 0)
    }

    @Test("reset clears recorded calls")
    func resetClearsCalls() async throws {
      let mockClient = MockChatClient()

      let messages = [APIMessage(role: "user", content: "Hello")]
      _ = try await mockClient.sendMessage(messages: messages)

      await mockClient.reset()

      let calls = await mockClient.sendMessageCalls
      #expect(calls.isEmpty)
    }

    @Test("reset clears configured error")
    func resetClearsError() async throws {
      let mockClient = MockChatClient()
      await mockClient.setError(ChatError.networkError(reason: "Test"))

      await mockClient.reset()

      // Should not throw after reset.
      let messages = [APIMessage(role: "user", content: "Hello")]
      let response = try await mockClient.sendMessage(messages: messages)

      #expect(response == "Mock response")
    }
  }
}

// MARK: - APIMessage Tests

@Suite("APIMessage Tests")
struct APIMessageTests {

  @Test("creates APIMessage from ChatMessage")
  func createsFromChatMessage() {
    let chatMessage = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello world",
      timestamp: Date(),
      contextMetadata: nil
    )

    let apiMessage = APIMessage(from: chatMessage)

    #expect(apiMessage.role == "user")
    #expect(apiMessage.content == "Hello world")
  }

  @Test("creates APIMessage from assistant ChatMessage")
  func createsFromAssistantMessage() {
    let chatMessage = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .assistant,
      content: "AI response",
      timestamp: Date(),
      contextMetadata: nil
    )

    let apiMessage = APIMessage(from: chatMessage)

    #expect(apiMessage.role == "assistant")
    #expect(apiMessage.content == "AI response")
  }

  @Test("creates APIMessage with explicit values")
  func createsWithExplicitValues() {
    let apiMessage = APIMessage(role: "system", content: "System prompt")

    #expect(apiMessage.role == "system")
    #expect(apiMessage.content == "System prompt")
  }

  @Test("APIMessage is Equatable")
  func isEquatable() {
    let message1 = APIMessage(role: "user", content: "Hello")
    let message2 = APIMessage(role: "user", content: "Hello")
    let message3 = APIMessage(role: "assistant", content: "Hello")
    let message4 = APIMessage(role: "user", content: "Different")

    #expect(message1 == message2)
    #expect(message1 != message3)
    #expect(message1 != message4)
  }

  @Test("APIMessage is Codable")
  func isCodable() throws {
    let original = APIMessage(role: "user", content: "Test message")

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(APIMessage.self, from: data)

    #expect(decoded == original)
  }

  @Test("APIMessage encodes to expected JSON structure")
  func encodesToExpectedJSON() throws {
    let message = APIMessage(role: "user", content: "Hello")

    let encoder = JSONEncoder()
    let data = try encoder.encode(message)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: String]

    #expect(json?["role"] == "user")
    #expect(json?["content"] == "Hello")
  }

  @Test("APIMessage is Sendable")
  func isSendable() async {
    let message = APIMessage(role: "user", content: "Test")

    // Verify message can be passed across actor boundaries.
    let result = await Task {
      message
    }.value

    #expect(result == message)
  }
}

// MARK: - ChatConfiguration Tests

@Suite("ChatConfiguration Tests")
struct ChatConfigurationTests {

  @Test("default configuration has correct project ID")
  func defaultHasCorrectProjectID() {
    let config = ChatConfiguration.default

    #expect(config.projectID == "inkos-f58f1")
  }

  @Test("default configuration has correct region")
  func defaultHasCorrectRegion() {
    let config = ChatConfiguration.default

    #expect(config.region == "us-central1")
  }

  @Test("functionsBaseURL is correctly constructed")
  func functionsBaseURLIsCorrect() {
    let config = ChatConfiguration.default

    let expectedURL = URL(string: "https://us-central1-inkos-f58f1.cloudfunctions.net")

    #expect(config.functionsBaseURL == expectedURL)
  }

  @Test("sendMessageURL appends correct path")
  func sendMessageURLIsCorrect() {
    let config = ChatConfiguration.default

    #expect(config.sendMessageURL.path.contains("sendMessage"))
  }

  @Test("streamMessageURL appends correct path")
  func streamMessageURLIsCorrect() {
    let config = ChatConfiguration.default

    #expect(config.streamMessageURL.path.contains("streamMessage"))
  }

  @Test("testing configuration uses test project ID")
  func testingConfigurationUsesTestProject() {
    let testURL = URL(string: "https://localhost:5001")!
    let config = ChatConfiguration.testing(baseURL: testURL)

    #expect(config.projectID == "test-project")
  }

  @Test("custom configuration uses provided values")
  func customConfigurationUsesProvidedValues() {
    let config = ChatConfiguration(
      projectID: "custom-project",
      region: "europe-west1"
    )

    #expect(config.projectID == "custom-project")
    #expect(config.region == "europe-west1")
  }

  @Test("functionsBaseURL updates with custom region")
  func functionsBaseURLUpdatesWithRegion() {
    let config = ChatConfiguration(
      projectID: "test-project",
      region: "asia-east1"
    )

    #expect(config.functionsBaseURL.absoluteString.contains("asia-east1"))
    #expect(config.functionsBaseURL.absoluteString.contains("test-project"))
  }
}

// MARK: - MockChatClient Extension

extension MockChatClient {
  func setResponse(_ response: String) {
    sendMessageResponse = response
  }

  func setError(_ error: Error) {
    sendMessageError = error
  }

  func setStreamChunks(_ chunks: [String]) {
    streamMessageChunks = chunks
  }

  func setStreamError(_ error: Error) {
    streamError = error
  }

  func setUploadFileResponse(_ response: UploadedFileReference) {
    uploadFileResponse = response
  }

  func setUploadFileError(_ error: Error) {
    uploadFileError = error
  }

  func setMultimodalResponse(_ response: String) {
    sendMessageMultimodalResponse = response
  }

  func setMultimodalStreamChunks(_ chunks: [String]) {
    streamMessageMultimodalChunks = chunks
  }
}
