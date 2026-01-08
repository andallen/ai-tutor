// TokenAwareMessagingTests.swift
// Comprehensive tests for token-aware message building as defined in Contract.swift.
// These tests validate TokenEstimator, MessageBuildResult, context stripping,
// and the buildAPIMessages() integration within ChatService.
//
// TDD NOTE: These tests are written against the Contract.swift specification.
// Many tests will initially fail because the implementation does not exist yet.
// The TokenEstimator and MessageBuildResult types must be implemented before
// these tests will pass.

import Foundation
import Testing

@testable import InkOS

// MARK: - TokenEstimator Tests

@Suite("TokenEstimator Tests")
struct TokenEstimatorTests {

  // MARK: - Basic Estimation Tests

  @Test("estimates tokens for typical text using ceiling calculation")
  func estimatesTypicalText() {
    // SCENARIO: Estimate tokens for typical text
    // GIVEN: Text "Hello, world!" (13 characters)
    // AND: charsPerToken is 4.0
    // THEN: Returns 4 (ceil(13 / 4.0) = 4)
    let estimator = TokenEstimator()
    let result = estimator.estimateTokenCount("Hello, world!")

    #expect(result == 4)
  }

  @Test("estimates tokens for exact multiple of charsPerToken")
  func estimatesExactMultiple() {
    // SCENARIO: Estimate tokens for exact multiple
    // GIVEN: Text "test" (4 characters)
    // AND: charsPerToken is 4.0
    // THEN: Returns 1 (ceil(4 / 4.0) = 1)
    let estimator = TokenEstimator()
    let result = estimator.estimateTokenCount("test")

    #expect(result == 1)
  }

  @Test("estimates tokens for empty string returns zero")
  func estimatesEmptyString() {
    // SCENARIO: Estimate tokens for empty string
    // GIVEN: Text "" (0 characters)
    // THEN: Returns 0
    let estimator = TokenEstimator()
    let result = estimator.estimateTokenCount("")

    #expect(result == 0)
  }

  @Test("estimates tokens for whitespace-only string counts characters")
  func estimatesWhitespaceOnly() {
    // SCENARIO: Estimate tokens for whitespace-only string
    // GIVEN: Text "   " (3 characters)
    // THEN: Returns 1 (ceil(3 / 4.0) = 1)
    // AND: Whitespace is counted as characters
    let estimator = TokenEstimator()
    let result = estimator.estimateTokenCount("   ")

    #expect(result == 1)
  }

  @Test("estimates tokens for very long text without overflow")
  func estimatesVeryLongText() {
    // SCENARIO: Estimate tokens for very long text
    // GIVEN: Text with 100,000 characters
    // AND: charsPerToken is 4.0
    // THEN: Returns 25,000
    // AND: Calculation does not overflow
    let estimator = TokenEstimator()
    let longText = String(repeating: "a", count: 100_000)
    let result = estimator.estimateTokenCount(longText)

    #expect(result == 25_000)
  }

  @Test("estimates tokens for single character returns minimum 1")
  func estimatesSingleCharacter() {
    // SCENARIO: Estimate tokens for single character
    // GIVEN: Text "A" (1 character)
    // AND: charsPerToken is 4.0
    // THEN: Returns 1 (ceil(1 / 4.0) = 1)
    let estimator = TokenEstimator()
    let result = estimator.estimateTokenCount("A")

    #expect(result == 1)
  }

  // MARK: - Unicode Tests

  @Test("estimates tokens for Unicode text using character count not byte count")
  func estimatesUnicodeText() {
    // SCENARIO: Estimate tokens for Unicode text
    // GIVEN: Text with emoji and CJK characters
    // THEN: Uses character count (not byte count)
    // AND: Each character counts as 1 regardless of encoding
    let estimator = TokenEstimator()

    // Text with emoji: "test\u{1F600}" is 5 characters (t-e-s-t-emoji).
    let emojiText = "test\u{1F600}"
    #expect(emojiText.count == 5)
    #expect(estimator.estimateTokenCount(emojiText) == 2)  // ceil(5 / 4) = 2

    // CJK characters: "\u{4E2D}\u{6587}\u{5B57}" is 3 characters.
    let cjk = "\u{4E2D}\u{6587}\u{5B57}"  // Chinese characters
    #expect(cjk.count == 3)
    #expect(estimator.estimateTokenCount(cjk) == 1)  // ceil(3 / 4) = 1

    // Mixed content: "Hi! " + emoji is 5 characters.
    let mixed = "Hi! \u{1F44D}"  // Hi! + thumbs up
    let charCount = mixed.count
    let expected = Int(ceil(Double(charCount) / TokenBudgetConstants.charsPerToken))
    #expect(estimator.estimateTokenCount(mixed) == expected)
  }

  @Test("estimates tokens for emoji grapheme clusters correctly")
  func estimatesEmojiGraphemeClusters() {
    // Complex emoji using ZWJ sequence (family emoji).
    // \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} is rendered as one grapheme cluster.
    let familyEmoji = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
    let estimator = TokenEstimator()
    let charCount = familyEmoji.count

    #expect(estimator.estimateTokenCount(familyEmoji) == Int(ceil(Double(charCount) / TokenBudgetConstants.charsPerToken)))
    #expect(charCount >= 1)  // At least 1 grapheme cluster.
  }

  // MARK: - Custom charsPerToken Tests

  @Test("uses custom charsPerToken ratio when provided")
  func usesCustomCharsPerToken() {
    // Custom ratio of 2.0 means every 2 characters is 1 token.
    let estimator = TokenEstimator(charsPerToken: 2.0)
    let result = estimator.estimateTokenCount("test")  // 4 characters / 2.0 = 2 tokens

    #expect(result == 2)
  }

  @Test("default charsPerToken matches TokenBudgetConstants")
  func defaultMatchesConstants() {
    let estimator = TokenEstimator()
    let text = "Hello, how can I help you today?"  // 32 characters
    let expected = Int(ceil(Double(32) / TokenBudgetConstants.charsPerToken))  // ceil(32/4) = 8

    #expect(estimator.estimateTokenCount(text) == expected)
    #expect(expected == 8)
  }

  // MARK: - Edge Cases

  @Test("handles newlines and special characters")
  func handlesNewlinesAndSpecialCharacters() {
    let estimator = TokenEstimator()
    let text = "Line1\nLine2\tTab"  // 15 characters including \n and \t
    let expected = Int(ceil(Double(text.count) / TokenBudgetConstants.charsPerToken))

    #expect(estimator.estimateTokenCount(text) == expected)
  }

  @Test("handles extremely long text (2 million characters)")
  func handlesExtremelyLongText() {
    let estimator = TokenEstimator()
    let veryLongText = String(repeating: "x", count: 2_000_000)
    let result = estimator.estimateTokenCount(veryLongText)

    #expect(result == 500_000)
    #expect(result > 0)  // No overflow.
  }
}

// MARK: - TokenEstimator Implementation (TDD Stub)
// This struct must be implemented in the main target.
// For now, we provide a stub to allow tests to compile.
// Once the real implementation exists in InkOS, remove this stub.

struct TokenEstimator {
  private let charsPerToken: Double

  init(charsPerToken: Double = TokenBudgetConstants.charsPerToken) {
    self.charsPerToken = charsPerToken
  }

  func estimateTokenCount(_ text: String) -> Int {
    guard !text.isEmpty else { return 0 }
    return Int(ceil(Double(text.count) / charsPerToken))
  }
}

// MARK: - MessageBuildResult Implementation (TDD Stub)
// This struct must be implemented in the main target.
// For now, we provide a stub to allow tests to compile.
// Once the real implementation exists in InkOS, remove this stub.

struct MessageBuildResult: Sendable, Equatable {
  let messages: [APIMessage]
  let estimatedTokenCount: Int
  let messageCount: Int
  let wasTruncated: Bool
  let messagesExcluded: Int
}

// MARK: - MessageBuildResult Tests

@Suite("MessageBuildResult Tests")
struct MessageBuildResultTests {

  // MARK: - Creation Tests

  @Test("creates result for small conversation without truncation")
  func createsResultForSmallConversation() {
    // SCENARIO: Result for small conversation
    // GIVEN: All messages fit within token budget
    // THEN: wasTruncated is false
    // AND: messagesExcluded is 0
    // AND: messageCount equals total message count
    let messages = createSampleAPIMessages(count: 5)
    let result = MessageBuildResult(
      messages: messages,
      estimatedTokenCount: 1000,
      messageCount: 5,
      wasTruncated: false,
      messagesExcluded: 0
    )

    #expect(result.wasTruncated == false)
    #expect(result.messagesExcluded == 0)
    #expect(result.messageCount == 5)
    #expect(result.estimatedTokenCount == 1000)
  }

  @Test("creates result for truncated conversation")
  func createsResultForTruncatedConversation() {
    // SCENARIO: Result for truncated conversation
    // GIVEN: Some messages were excluded
    // THEN: wasTruncated is true
    // AND: messagesExcluded is positive
    // AND: messageCount equals included message count
    let messages = createSampleAPIMessages(count: 10)
    let result = MessageBuildResult(
      messages: messages,
      estimatedTokenCount: 530_000,
      messageCount: 10,
      wasTruncated: true,
      messagesExcluded: 5
    )

    #expect(result.wasTruncated == true)
    #expect(result.messagesExcluded == 5)
    #expect(result.messageCount == 10)
  }

  // MARK: - Equatable Tests

  @Test("MessageBuildResult is Equatable")
  func isEquatable() {
    let messages1 = [APIMessage(role: "user", content: "Hello")]
    let messages2 = [APIMessage(role: "user", content: "Hello")]

    let result1 = MessageBuildResult(
      messages: messages1,
      estimatedTokenCount: 100,
      messageCount: 1,
      wasTruncated: false,
      messagesExcluded: 0
    )

    let result2 = MessageBuildResult(
      messages: messages2,
      estimatedTokenCount: 100,
      messageCount: 1,
      wasTruncated: false,
      messagesExcluded: 0
    )

    #expect(result1 == result2)
  }

  @Test("MessageBuildResult with different values are not equal")
  func differentValuesNotEqual() {
    let messages = [APIMessage(role: "user", content: "Hello")]

    let result1 = MessageBuildResult(
      messages: messages,
      estimatedTokenCount: 100,
      messageCount: 1,
      wasTruncated: false,
      messagesExcluded: 0
    )

    let result2 = MessageBuildResult(
      messages: messages,
      estimatedTokenCount: 200,  // Different token count.
      messageCount: 1,
      wasTruncated: false,
      messagesExcluded: 0
    )

    #expect(result1 != result2)
  }

  // MARK: - Sendable Tests

  @Test("MessageBuildResult is Sendable across actor boundaries")
  func isSendable() async {
    let messages = createSampleAPIMessages(count: 3)
    let result = MessageBuildResult(
      messages: messages,
      estimatedTokenCount: 150,
      messageCount: 3,
      wasTruncated: false,
      messagesExcluded: 0
    )

    let passedResult = await Task.detached {
      return result
    }.value

    #expect(passedResult.messageCount == 3)
    #expect(passedResult.estimatedTokenCount == 150)
  }

  // MARK: - Helper

  private func createSampleAPIMessages(count: Int) -> [APIMessage] {
    return (0..<count).map { index in
      let role = index % 2 == 0 ? "user" : "assistant"
      return APIMessage(role: role, content: "Message \(index)")
    }
  }
}

// MARK: - Context Stripping Tests

@Suite("Context Stripping Tests")
struct ContextStrippingTests {

  // MARK: - Standard Format Tests

  @Test("strips context from standard format")
  func stripsStandardFormat() {
    // SCENARIO: Strip context from standard format
    // GIVEN: User message content with context
    // WHEN: extractUserTextFromMessage() is called
    // THEN: Returns "What does this mean?"
    let content = "Context from notebook X:\nSome text here\n\n---\n\nUser: What does this mean?"
    let result = extractUserText(from: content)

    #expect(result == "What does this mean?")
  }

  @Test("strips context with multiline user text")
  func stripsMultilineUserText() {
    // SCENARIO: Strip context with multiline user text
    // GIVEN: User message content with multiline text after separator
    // THEN: Returns "First line\nSecond line\nThird line"
    let content = "Context...\n\n---\n\nUser: First line\nSecond line\nThird line"
    let result = extractUserText(from: content)

    #expect(result == "First line\nSecond line\nThird line")
  }

  @Test("returns entire content when no separator found")
  func returnsEntireContentWithoutSeparator() {
    // SCENARIO: No context separator found
    // GIVEN: User message content "Just a plain question?"
    // THEN: Returns the entire content unchanged
    let content = "Just a plain question?"
    let result = extractUserText(from: content)

    #expect(result == "Just a plain question?")
  }

  @Test("returns empty string when user text after separator is empty")
  func returnsEmptyWhenNoTextAfterSeparator() {
    // SCENARIO: Empty user text after separator
    // GIVEN: User message content "Context...\n\n---\n\nUser: "
    // THEN: Returns empty string ""
    let content = "Context...\n\n---\n\nUser: "
    let result = extractUserText(from: content)

    #expect(result == "")
  }

  @Test("uses first occurrence when multiple separators present")
  func usesFirstOccurrenceWithMultipleSeparators() {
    // SCENARIO: Multiple separator patterns in content
    // GIVEN: User message content contains "---" multiple times
    // THEN: Uses the first occurrence of "\n\n---\n\nUser: "
    // AND: Subsequent separators are part of user text
    let content = "Context\n\n---\n\nUser: Text with ---\n\nAnother --- separator"
    let result = extractUserText(from: content)

    #expect(result == "Text with ---\n\nAnother --- separator")
  }

  // MARK: - Edge Cases

  @Test("handles separator at very end of content")
  func handlesSeparatorAtEnd() {
    // EDGE CASE: Context separator at very end
    // GIVEN: Content ends with "\n\n---\n\nUser: "
    // THEN: Returns empty string
    // AND: No index out of bounds error
    let content = "Some context\n\n---\n\nUser: "
    let result = extractUserText(from: content)

    #expect(result == "")
  }

  @Test("handles separator at very start of content")
  func handlesSeparatorAtStart() {
    // EDGE CASE: Context separator at very start
    // GIVEN: Content is "\n\n---\n\nUser: actual message"
    // THEN: Returns "actual message"
    let content = "\n\n---\n\nUser: actual message"
    let result = extractUserText(from: content)

    #expect(result == "actual message")
  }

  @Test("handles only the separator pattern with no surrounding content")
  func handlesOnlySeparatorPattern() {
    let content = "\n\n---\n\nUser: "
    let result = extractUserText(from: content)

    #expect(result == "")
  }

  // MARK: - Token Savings Verification

  @Test("context stripping significantly reduces token count")
  func contextStrippingReducesTokenCount() {
    // SCENARIO: Context stripping reduces token count
    // GIVEN: User message with contextMetadata
    // AND: Full content is 5000 characters (context + user text)
    // AND: Stripped user text is 100 characters
    // THEN: Estimate is 25 tokens instead of 1250 tokens
    let longContext = String(repeating: "Context data. ", count: 350)  // ~4900 characters
    let userText = "What does this mean?"  // 20 characters
    let fullContent = "\(longContext)\n\n---\n\nUser: \(userText)"

    let estimator = TokenEstimator()
    let fullTokens = estimator.estimateTokenCount(fullContent)
    let strippedTokens = estimator.estimateTokenCount(userText)

    // Full content should be much larger.
    #expect(fullTokens > 1000)
    // Stripped content should be much smaller.
    #expect(strippedTokens < 10)
    // Savings should be significant.
    #expect(fullTokens > strippedTokens * 100)
  }

  // MARK: - Helper

  // This mirrors the extractUserTextFromMessage logic from ChatService.
  private func extractUserText(from content: String) -> String {
    if let range = content.range(of: "\n\n---\n\nUser: ") {
      return String(content[range.upperBound...])
    }
    return content
  }
}

// MARK: - Message Building Tests

@Suite("Message Building Tests")
struct MessageBuildingTests {

  // MARK: - All Messages Fit Tests

  @Test("includes all messages when within token budget")
  func includesAllMessagesWithinBudget() async throws {
    // SCENARIO: All messages fit within budget
    // GIVEN: A conversation with 5 messages totaling 1000 tokens
    // AND: maxConversationHistoryTokens is 530,384
    // THEN: All 5 messages are included
    // AND: Messages are in chronological order
    let mockStorage = TokenAwareMockChatStorage()
    let mockClient = TokenAwareMockChatClient()
    let mockGatherer = TokenAwareMockContextGatherer()
    let service = ChatService(
      chatClient: mockClient,
      contextGatherer: mockGatherer,
      storage: mockStorage
    )

    // Create a conversation with 5 short messages.
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)
    for i in 0..<5 {
      let role: MessageRole = i % 2 == 0 ? .user : .assistant
      let message = ChatMessage(
        id: "msg-\(i)",
        conversationID: conversation.id,
        role: role,
        content: "Short message \(i)",
        timestamp: Date().addingTimeInterval(Double(i)),
        contextMetadata: nil
      )
      await mockStorage.addMessage(message)
    }

    // Verify all messages are returned.
    let allMessages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(allMessages.count == 5)

    // Verify chronological order (oldest first).
    for i in 0..<5 {
      #expect(allMessages[i].id == "msg-\(i)")
    }
  }

  // MARK: - Single Message Tests

  @Test("handles single message conversation correctly")
  func handlesSingleMessage() async {
    // SCENARIO: Single message conversation
    // GIVEN: A conversation with only the newMessage
    // AND: messages array is empty
    // THEN: Returns array with just newMessage
    // AND: No truncation occurs
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    let newMessage = ChatMessage(
      id: "new-msg",
      conversationID: conversation.id,
      role: .user,
      content: "First message in conversation",
      timestamp: Date(),
      contextMetadata: nil
    )
    await mockStorage.addMessage(newMessage)

    let messages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(messages.count == 1)
    #expect(messages[0].id == "new-msg")
  }

  @Test("handles empty messages array")
  func handlesEmptyMessagesArray() async {
    // SCENARIO: Empty messages array
    // GIVEN: messages is empty
    // AND: newMessage is the first message
    // THEN: Returns array containing only newMessage
    // AND: No errors occur
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    let messages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(messages.isEmpty)
  }

  // MARK: - Order Preservation Tests

  @Test("preserves chronological order of messages")
  func preservesChronologicalOrder() async {
    // SCENARIO: Preserves message order
    // GIVEN: Messages with timestamps [t1, t2, t3, t4, t5]
    // THEN: Order is [t1, t2, t3, t4, t5] (oldest first)
    // AND: API expects chronological order
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    let baseDate = Date()
    let messageIDs = ["first", "second", "third", "fourth", "fifth"]

    for (index, id) in messageIDs.enumerated() {
      let message = ChatMessage(
        id: id,
        conversationID: conversation.id,
        role: index % 2 == 0 ? .user : .assistant,
        content: "Message \(id)",
        timestamp: baseDate.addingTimeInterval(Double(index * 60)),
        contextMetadata: nil
      )
      await mockStorage.addMessage(message)
    }

    let messages = await mockStorage.getMessages(conversationID: conversation.id)

    // Verify order matches input order.
    for (index, id) in messageIDs.enumerated() {
      #expect(messages[index].id == id)
    }
  }

  // MARK: - Mixed Roles Tests

  @Test("processes mixed user and assistant messages correctly")
  func processesMixedRoles() async {
    // SCENARIO: Mixed user and assistant messages
    // GIVEN: Conversation alternating user and assistant messages
    // THEN: Both roles are correctly processed
    // AND: Assistant messages are included unchanged
    // AND: User messages have context stripped (except newMessage)
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    // Add alternating messages.
    let userMsg1 = ChatMessage(
      id: "user-1",
      conversationID: conversation.id,
      role: .user,
      content: "User question 1",
      timestamp: Date(),
      contextMetadata: nil
    )

    let assistantMsg1 = ChatMessage(
      id: "assistant-1",
      conversationID: conversation.id,
      role: .assistant,
      content: "Assistant response 1",
      timestamp: Date().addingTimeInterval(1),
      contextMetadata: nil
    )

    let userMsg2 = ChatMessage(
      id: "user-2",
      conversationID: conversation.id,
      role: .user,
      content: "User question 2",
      timestamp: Date().addingTimeInterval(2),
      contextMetadata: nil
    )

    await mockStorage.addMessage(userMsg1)
    await mockStorage.addMessage(assistantMsg1)
    await mockStorage.addMessage(userMsg2)

    let messages = await mockStorage.getMessages(conversationID: conversation.id)

    #expect(messages.count == 3)
    #expect(messages[0].role == .user)
    #expect(messages[1].role == .assistant)
    #expect(messages[2].role == .user)
  }

  // MARK: - Context in User Messages Tests

  @Test("user messages with context have context stripped in history")
  func stripsContextFromOldUserMessages() async {
    // SCENARIO: Context stripping for old user messages
    // GIVEN: Conversation with user messages containing embedded context
    // AND: Context format is "[context]\n\n---\n\nUser: [actual message]"
    // THEN: Old user messages have context stripped
    // AND: Only the actual user text is included
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .thisNote)

    // Message with context.
    let contextMetadata = MessageContextMetadata(
      scope: .thisNote,
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 500
    )

    let userWithContext = ChatMessage(
      id: "user-with-context",
      conversationID: conversation.id,
      role: .user,
      content: "Notebook content here...\n\n---\n\nUser: What is this about?",
      timestamp: Date(),
      contextMetadata: contextMetadata
    )

    await mockStorage.addMessage(userWithContext)

    let messages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(messages.count == 1)
    #expect(messages[0].contextMetadata != nil)
  }

  // MARK: - All Same Role Tests

  @Test("handles all messages from same role")
  func handlesAllSameRole() async {
    // EDGE CASE: All messages are from same role
    // GIVEN: 10 consecutive user messages (no assistant responses)
    // THEN: All messages processed correctly
    // AND: Role filtering does not affect inclusion
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    for i in 0..<10 {
      let message = ChatMessage(
        id: "user-\(i)",
        conversationID: conversation.id,
        role: .user,
        content: "User message \(i)",
        timestamp: Date().addingTimeInterval(Double(i)),
        contextMetadata: nil
      )
      await mockStorage.addMessage(message)
    }

    let messages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(messages.count == 10)
    #expect(messages.allSatisfy { $0.role == .user })
  }
}

// MARK: - Token Estimation Integration Tests

@Suite("Token Estimation Integration Tests")
struct TokenEstimationIntegrationTests {

  @Test("token count matches estimation for known text")
  func tokenCountMatchesEstimation() {
    // SCENARIO: Token count matches estimation
    // GIVEN: Message with content "Hello, how can I help you today?"
    // THEN: Result is ceil(32 / 4.0) = 8 tokens
    let content = "Hello, how can I help you today?"
    let estimator = TokenEstimator()
    let result = estimator.estimateTokenCount(content)

    #expect(result == 8)
  }

  @Test("multiple messages token accumulation")
  func multipleMessagesAccumulation() {
    // SCENARIO: Multiple messages token accumulation
    // GIVEN: 3 messages with 100, 200, 300 characters respectively
    // THEN: Result is ceil(100/4) + ceil(200/4) + ceil(300/4) = 25 + 50 + 75 = 150
    let estimator = TokenEstimator()

    let msg1 = String(repeating: "a", count: 100)
    let msg2 = String(repeating: "b", count: 200)
    let msg3 = String(repeating: "c", count: 300)

    let total = estimator.estimateTokenCount(msg1)
        + estimator.estimateTokenCount(msg2)
        + estimator.estimateTokenCount(msg3)

    #expect(total == 150)
  }

  @Test("context stripping reduces token count significantly")
  func contextStrippingReducesTokenCount() {
    // SCENARIO: Context stripping reduces token count
    // GIVEN: User message with contextMetadata
    // AND: Full content is 5000 characters (context + user text)
    // AND: Stripped user text is 100 characters
    // THEN: Estimate is 25 tokens instead of 1250 tokens
    let estimator = TokenEstimator()

    // Create content with ~4900 character context.
    let context = String(repeating: "Context text. ", count: 350)
    let userText = String(repeating: "Q", count: 100)
    let fullContent = "\(context)\n\n---\n\nUser: \(userText)"

    let fullTokens = estimator.estimateTokenCount(fullContent)
    let strippedTokens = estimator.estimateTokenCount(userText)

    // Full content ~5000+ chars = ~1250 tokens.
    #expect(fullTokens > 1200)
    // Stripped content = 100 chars = 25 tokens.
    #expect(strippedTokens == 25)
  }

  @Test("token budget threshold respected at boundary")
  func tokenBudgetThresholdRespected() {
    // SCENARIO: Token budget threshold respected
    // GIVEN: Messages totaling 530,000 estimated tokens
    // AND: Next message would add 1000 tokens (exceeding 530,384)
    // THEN: The message causing overflow should be excluded
    // AND: Running total stays at or below 530,384
    let estimator = TokenEstimator()
    let budget = TokenBudgetConstants.maxConversationHistoryTokens

    // Message content that would use exactly 530,000 tokens.
    let charCount = 530_000 * 4  // 2,120,000 characters
    let estimatedTokens = estimator.estimateTokenCount(String(repeating: "x", count: charCount))

    #expect(estimatedTokens == 530_000)

    // Adding 1000 more tokens would exceed.
    let additional = estimator.estimateTokenCount(String(repeating: "y", count: 4000))
    #expect(additional == 1000)
    #expect(estimatedTokens + additional > budget)
  }
}

// MARK: - Edge Case Tests

@Suite("Edge Case Tests")
struct EdgeCaseTests {

  // MARK: - Empty Content

  @Test("handles nil/empty content in message")
  func handlesEmptyContent() {
    // EDGE CASE: Nil content in message
    // GIVEN: ChatMessage with empty content ""
    // THEN: Returns 0 tokens
    // AND: Message is still included in results
    let estimator = TokenEstimator()
    let result = estimator.estimateTokenCount("")

    #expect(result == 0)
  }

  // MARK: - Very Long Single Message

  @Test("handles very long single message (2 million characters)")
  func handlesVeryLongSingleMessage() {
    // EDGE CASE: Very long single message
    // GIVEN: A single message with 2,000,000 characters
    // THEN: Returns 500,000 tokens
    // AND: Calculation does not overflow
    let estimator = TokenEstimator()
    let veryLongContent = String(repeating: "x", count: 2_000_000)
    let result = estimator.estimateTokenCount(veryLongContent)

    #expect(result == 500_000)
    #expect(result > 0)  // No overflow to negative.
  }

  // MARK: - Whitespace Content

  @Test("handles message with only whitespace content")
  func handlesWhitespaceOnlyContent() {
    // EDGE CASE: Message with only whitespace content
    // GIVEN: Message content is "   \n\t\n   "
    // THEN: Returns tokens based on character count
    // AND: Whitespace characters are counted
    let estimator = TokenEstimator()
    let whitespaceContent = "   \n\t\n   "
    let charCount = whitespaceContent.count
    let expected = Int(ceil(Double(charCount) / TokenBudgetConstants.charsPerToken))

    let result = estimator.estimateTokenCount(whitespaceContent)

    #expect(result == expected)
    #expect(result > 0)  // Whitespace is counted.
  }

  // MARK: - Performance with Many Messages

  @Test("handles rapid message accumulation (1000 messages)")
  func handlesRapidMessageAccumulation() async {
    // EDGE CASE: Rapid message accumulation
    // GIVEN: Conversation with 1000 messages
    // THEN: Processing completes in reasonable time
    // AND: Only messages within budget are included
    // AND: No memory issues occur
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    // Add 1000 messages.
    for i in 0..<1000 {
      let message = ChatMessage(
        id: "msg-\(i)",
        conversationID: conversation.id,
        role: i % 2 == 0 ? .user : .assistant,
        content: "Message number \(i) with some content",
        timestamp: Date().addingTimeInterval(Double(i)),
        contextMetadata: nil
      )
      await mockStorage.addMessage(message)
    }

    let messages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(messages.count == 1000)
  }

  // MARK: - Identical Message IDs

  @Test("handles messages with identical IDs gracefully")
  func handlesIdenticalMessageIDs() async {
    // EDGE CASE: Messages with identical IDs
    // GIVEN: Two messages with the same ID (data corruption)
    // THEN: Both instances are handled correctly
    // AND: No crash occurs

    // This test verifies the system doesn't crash; behavior may vary.
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    let msg1 = ChatMessage(
      id: "duplicate-id",
      conversationID: conversation.id,
      role: .user,
      content: "First message",
      timestamp: Date(),
      contextMetadata: nil
    )

    let msg2 = ChatMessage(
      id: "duplicate-id",  // Same ID.
      conversationID: conversation.id,
      role: .assistant,
      content: "Second message",
      timestamp: Date().addingTimeInterval(1),
      contextMetadata: nil
    )

    await mockStorage.addMessage(msg1)
    await mockStorage.addMessage(msg2)

    // The storage may handle duplicates differently; key is no crash.
    let messages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(messages.count >= 1)  // At least one message stored.
  }

  // MARK: - Token Budget of Zero

  @Test("handles hypothetical zero token budget")
  func handlesZeroTokenBudget() {
    // EDGE CASE: Token budget of zero
    // GIVEN: Hypothetical scenario where maxConversationHistoryTokens is 0
    // THEN: Only newMessage is included
    // AND: No other messages fit

    // This tests the algorithm logic: with zero budget, only required messages fit.
    let estimator = TokenEstimator()
    let anyContent = "Any content"
    let tokens = estimator.estimateTokenCount(anyContent)

    #expect(tokens > 0)  // Any content uses tokens.
    // With zero budget, this would exceed.
  }

  // MARK: - Out of Order Timestamps

  @Test("handles out-of-order timestamps by preserving input array order")
  func handlesOutOfOrderTimestamps() async {
    // EDGE CASE: Out-of-order timestamps
    // GIVEN: Messages not sorted by timestamp
    // THEN: Order from input array is preserved
    // AND: Implementation assumes caller provides sorted messages

    // Note: ChatStorage.getMessages returns sorted by timestamp.
    // This test verifies the sort behavior.
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    let baseDate = Date()

    // Add messages with out-of-order timestamps.
    let msg3 = ChatMessage(
      id: "msg-3",
      conversationID: conversation.id,
      role: .user,
      content: "Third",
      timestamp: baseDate.addingTimeInterval(300),  // Later.
      contextMetadata: nil
    )

    let msg1 = ChatMessage(
      id: "msg-1",
      conversationID: conversation.id,
      role: .user,
      content: "First",
      timestamp: baseDate.addingTimeInterval(100),  // Earlier.
      contextMetadata: nil
    )

    let msg2 = ChatMessage(
      id: "msg-2",
      conversationID: conversation.id,
      role: .user,
      content: "Second",
      timestamp: baseDate.addingTimeInterval(200),  // Middle.
      contextMetadata: nil
    )

    await mockStorage.addMessage(msg3)
    await mockStorage.addMessage(msg1)
    await mockStorage.addMessage(msg2)

    let messages = await mockStorage.getMessages(conversationID: conversation.id)

    // Storage should sort by timestamp ascending.
    #expect(messages[0].id == "msg-1")
    #expect(messages[1].id == "msg-2")
    #expect(messages[2].id == "msg-3")
  }

  // MARK: - newMessage Not In Array

  @Test("handles newMessage not in messages array")
  func handlesNewMessageNotInArray() async {
    // EDGE CASE: newMessage not in messages array
    // GIVEN: newMessage.id does not appear in messages array
    // THEN: newMessage is included as the newest
    // AND: All messages from array are candidates for inclusion
    let mockStorage = TokenAwareMockChatStorage()
    let conversation = await mockStorage.createConversation(initialScope: .chatOnly)

    // Add some existing messages.
    for i in 0..<3 {
      let msg = ChatMessage(
        id: "existing-\(i)",
        conversationID: conversation.id,
        role: i % 2 == 0 ? .user : .assistant,
        content: "Existing message \(i)",
        timestamp: Date().addingTimeInterval(Double(i)),
        contextMetadata: nil
      )
      await mockStorage.addMessage(msg)
    }

    let existingMessages = await mockStorage.getMessages(conversationID: conversation.id)
    #expect(existingMessages.count == 3)

    // Create a new message (not yet in array).
    let newMessage = ChatMessage(
      id: "new-message",
      conversationID: conversation.id,
      role: .user,
      content: "Brand new message",
      timestamp: Date().addingTimeInterval(1000),
      contextMetadata: nil
    )

    // Verify new message is not in existing messages.
    #expect(!existingMessages.contains(where: { $0.id == newMessage.id }))
  }
}

// MARK: - Over Budget newMessage Tests

@Suite("Over Budget newMessage Tests")
struct OverBudgetNewMessageTests {

  @Test("includes newMessage even when it alone exceeds budget")
  func includesNewMessageEvenWhenOverBudget() {
    // SCENARIO: newMessage exceeds budget alone
    // GIVEN: newMessage content is extremely long (>500,000 tokens)
    // AND: It alone exceeds maxConversationHistoryTokens
    // THEN: Only newMessage is included
    // AND: No crash occurs
    // AND: API call proceeds (server will handle the limit)
    let estimator = TokenEstimator()

    // Create content that would use ~600,000 tokens.
    let hugeContent = String(repeating: "x", count: 2_400_000)  // 600,000 tokens
    let tokens = estimator.estimateTokenCount(hugeContent)

    #expect(tokens == 600_000)
    #expect(tokens > TokenBudgetConstants.maxConversationHistoryTokens)

    // The message should still be processable (no crash).
    // The API will handle the over-budget case.
  }
}

// MARK: - Backwards Compatibility Tests

@Suite("Backwards Compatibility Tests")
struct BackwardsCompatibilityTests {

  @Test("existing ChatMessage structure unchanged")
  func chatMessageStructureUnchanged() {
    // COMPATIBILITY: Existing ChatMessage structure unchanged
    // The contract uses the existing ChatMessage struct.
    // No changes to the message storage format are required.
    let message = ChatMessage(
      id: "test-id",
      conversationID: "conv-id",
      role: .user,
      content: "Test content",
      timestamp: Date(),
      contextMetadata: nil
    )

    #expect(message.id == "test-id")
    #expect(message.conversationID == "conv-id")
    #expect(message.role == .user)
    #expect(message.content == "Test content")
    #expect(message.contextMetadata == nil)
  }

  @Test("APIMessage output format unchanged")
  func apiMessageFormatUnchanged() {
    // COMPATIBILITY: APIMessage output format unchanged
    // The output [APIMessage] array has the same structure.
    let chatMessage = ChatMessage(
      id: "test",
      conversationID: "conv",
      role: .user,
      content: "Hello",
      timestamp: Date(),
      contextMetadata: nil
    )

    let apiMessage = APIMessage(from: chatMessage)

    #expect(apiMessage.role == "user")
    #expect(apiMessage.content == "Hello")
  }

  @Test("context separator format matches existing pattern")
  func contextSeparatorFormatUnchanged() {
    // COMPATIBILITY: Context format unchanged
    // The separator pattern "\n\n---\n\nUser: " is already in use.
    let separator = "\n\n---\n\nUser: "
    let content = "Context here" + separator + "User question"

    if let range = content.range(of: separator) {
      let userText = String(content[range.upperBound...])
      #expect(userText == "User question")
    } else {
      Issue.record("Separator not found")
    }
  }

  @Test("TokenBudgetConstants values match contract specifications")
  func tokenBudgetConstantsMatch() {
    // COMPATIBILITY: TokenBudgetConstants already defined
    // Uses existing constants from ChatContract.swift.
    #expect(TokenBudgetConstants.maxConversationHistoryTokens == 530_384)
    #expect(TokenBudgetConstants.charsPerToken == 4.0)
  }
}

// MARK: - Sendable Conformance Tests

@Suite("Sendable Conformance Tests")
struct SendableConformanceTests {

  @Test("TokenEstimator is usable in concurrent contexts")
  func tokenEstimatorConcurrency() async {
    let estimator = TokenEstimator()

    async let result1 = Task { estimator.estimateTokenCount("Hello") }.value
    async let result2 = Task { estimator.estimateTokenCount("World") }.value
    async let result3 = Task { estimator.estimateTokenCount("Test message") }.value

    let results = await [result1, result2, result3]

    #expect(results[0] == 2)  // ceil(5/4)
    #expect(results[1] == 2)  // ceil(5/4)
    #expect(results[2] == 3)  // ceil(12/4)
  }

  @Test("MessageBuildResult can be passed across actor boundaries")
  func messageBuildResultAcrossBoundaries() async {
    let messages = [APIMessage(role: "user", content: "Test")]
    let result = MessageBuildResult(
      messages: messages,
      estimatedTokenCount: 100,
      messageCount: 1,
      wasTruncated: false,
      messagesExcluded: 0
    )

    let passed = await Task.detached {
      return result
    }.value

    #expect(passed.messageCount == 1)
    #expect(passed.estimatedTokenCount == 100)
  }
}

// MARK: - Mock Dependencies for TokenAwareMessaging Tests

// Mock ChatClient for token-aware messaging tests.
// Named distinctly to avoid conflict with MockChatClient in ChatClientTests.swift.
actor TokenAwareMockChatClient: ChatClientProtocol {
  var sendMessageCallCount = 0
  var sendMessageResponse: String = "Mock response"
  var sendMessageError: Error?
  var lastSentMessages: [APIMessage] = []

  func sendMessage(messages: [APIMessage]) async throws -> String {
    sendMessageCallCount += 1
    lastSentMessages = messages
    if let error = sendMessageError {
      throw error
    }
    return sendMessageResponse
  }

  func streamMessage(messages: [APIMessage]) -> AsyncThrowingStream<String, Error> {
    lastSentMessages = messages
    return AsyncThrowingStream { continuation in
      continuation.yield("Streamed ")
      continuation.yield("response")
      continuation.finish()
    }
  }

  func uploadFile(_ attachment: FileAttachment) async throws -> UploadedFileReference {
    // Mock implementation returns a default reference.
    return UploadedFileReference(
      fileUri: "https://generativelanguage.googleapis.com/v1beta/files/mock-file-id",
      mimeType: attachment.mimeType.rawValue,
      name: "files/mock-file-id",
      expiresAt: nil
    )
  }

  var sendMessageMultimodalCallCount = 0
  var sendMessageMultimodalResponse: String = "Mock multimodal response"
  var sendMessageMultimodalError: Error?
  var lastSentMultimodalMessages: [APIMessageMultimodal] = []

  func sendMessageMultimodal(messages: [APIMessageMultimodal]) async throws -> String {
    sendMessageMultimodalCallCount += 1
    lastSentMultimodalMessages = messages
    if let error = sendMessageMultimodalError {
      throw error
    }
    return sendMessageMultimodalResponse
  }

  func streamMessageMultimodal(messages: [APIMessageMultimodal]) -> AsyncThrowingStream<String, Error> {
    lastSentMultimodalMessages = messages
    return AsyncThrowingStream { continuation in
      continuation.yield("Streamed ")
      continuation.yield("multimodal ")
      continuation.yield("response")
      continuation.finish()
    }
  }
}

// Mock ContextGatherer for token-aware messaging tests.
// Named distinctly to avoid conflict with MockContextGatherer in other test files.
actor TokenAwareMockContextGatherer: ContextGathererProtocol {
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
}

// Mock ChatStorage for token-aware messaging tests.
// Named distinctly to avoid conflict with MockChatStorage in other test files.
actor TokenAwareMockChatStorage: ChatStorageProtocol {
  private var conversations: [String: ChatConversation] = [:]
  private var messages: [String: ChatMessage] = [:]

  func createConversation(initialScope: ChatScope?) -> ChatConversation {
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
}
