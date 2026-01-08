// TokenManagementTests.swift
// Tests for token-based context management models defined in Contract.swift.
// These tests validate TokenBudgetConstants, TokenMetadata, and ChatMessage integration
// for the token management system that replaces message-count-based limits.

import Foundation
import Testing

@testable import InkOS

// MARK: - TokenBudgetConstants Tests

@Suite("TokenBudgetConstants Tests")
struct TokenBudgetConstantsTests {

  // MARK: - Constant Value Tests

  @Test("geminiMaxTokens equals 1,048,576")
  func geminiMaxTokensValue() {
    #expect(TokenBudgetConstants.geminiMaxTokens == 1_048_576)
  }

  @Test("systemReserveTokens equals 10,000")
  func systemReserveTokensValue() {
    #expect(TokenBudgetConstants.systemReserveTokens == 10_000)
  }

  @Test("responseBufferTokens equals 8,192")
  func responseBufferTokensValue() {
    #expect(TokenBudgetConstants.responseBufferTokens == 8_192)
  }

  @Test("maxInputTokens equals 1,030,384")
  func maxInputTokensValue() {
    #expect(TokenBudgetConstants.maxInputTokens == 1_030_384)
  }

  @Test("maxContextTokens equals 500,000")
  func maxContextTokensValue() {
    #expect(TokenBudgetConstants.maxContextTokens == 500_000)
  }

  @Test("maxConversationHistoryTokens equals 530,384")
  func maxConversationHistoryTokensValue() {
    #expect(TokenBudgetConstants.maxConversationHistoryTokens == 530_384)
  }

  @Test("charsPerToken equals 4.0")
  func charsPerTokenValue() {
    #expect(TokenBudgetConstants.charsPerToken == 4.0)
  }

  // MARK: - Budget Arithmetic Tests

  @Test("budget arithmetic: systemReserve + responseBuffer + maxInput equals geminiMax")
  func budgetArithmeticTotalsGeminiMax() {
    let calculatedTotal =
      TokenBudgetConstants.systemReserveTokens
      + TokenBudgetConstants.responseBufferTokens
      + TokenBudgetConstants.maxInputTokens

    #expect(calculatedTotal == TokenBudgetConstants.geminiMaxTokens)
  }

  @Test("budget arithmetic: maxContext + maxConversationHistory equals maxInput")
  func contextAndHistoryTotalsMaxInput() {
    let calculatedTotal =
      TokenBudgetConstants.maxContextTokens
      + TokenBudgetConstants.maxConversationHistoryTokens

    #expect(calculatedTotal == TokenBudgetConstants.maxInputTokens)
  }

  @Test("all budget values are positive integers")
  func allValuesArePositive() {
    #expect(TokenBudgetConstants.geminiMaxTokens > 0)
    #expect(TokenBudgetConstants.systemReserveTokens > 0)
    #expect(TokenBudgetConstants.responseBufferTokens > 0)
    #expect(TokenBudgetConstants.maxInputTokens > 0)
    #expect(TokenBudgetConstants.maxContextTokens > 0)
    #expect(TokenBudgetConstants.maxConversationHistoryTokens > 0)
    #expect(TokenBudgetConstants.charsPerToken > 0)
  }

  // MARK: - Budget Balance Tests

  @Test("response buffer leaves room for multi-paragraph response")
  func responseBufferIsSubstantial() {
    // 8,192 tokens at ~4 chars/token = ~32,768 characters.
    // This is approximately 8-16 pages of text, plenty for a response.
    let estimatedResponseChars = Double(TokenBudgetConstants.responseBufferTokens) * TokenBudgetConstants.charsPerToken
    #expect(estimatedResponseChars >= 30_000)
  }

  @Test("maxContextTokens allows approximately 2 million characters")
  func contextBudgetAllowsLargeDocuments() {
    // 500,000 tokens * 4 chars/token = 2,000,000 characters.
    let estimatedContextChars = Double(TokenBudgetConstants.maxContextTokens) * TokenBudgetConstants.charsPerToken
    #expect(estimatedContextChars >= 2_000_000)
  }

  @Test("maxConversationHistoryTokens allows substantial conversation")
  func historyBudgetAllowsLongConversations() {
    // 530,384 tokens * 4 chars/token = 2,121,536 characters.
    // At ~100 chars per message, this allows ~21,000 messages.
    let estimatedHistoryChars = Double(TokenBudgetConstants.maxConversationHistoryTokens) * TokenBudgetConstants.charsPerToken
    #expect(estimatedHistoryChars > 2_000_000)
  }

  // MARK: - Edge Case Tests

  @Test("charsPerToken matches ChunkingService heuristic")
  func charsPerTokenMatchesChunkingService() {
    // The contract specifies this should match ChunkingService.
    // Value of 4.0 is the standard for English text.
    #expect(TokenBudgetConstants.charsPerToken == 4.0)
  }
}

// MARK: - TokenMetadata Tests

@Suite("TokenMetadata Tests")
struct TokenMetadataTests {

  // MARK: - Creation Tests

  @Test("creates metadata with all fields using explicit initializer")
  func createsWithAllFieldsExplicit() {
    let metadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      totalTokens: 1500,
      contextTruncated: false,
      messagesIncluded: 10
    )

    #expect(metadata.inputTokens == 1000)
    #expect(metadata.outputTokens == 500)
    #expect(metadata.totalTokens == 1500)
    #expect(metadata.contextTruncated == false)
    #expect(metadata.messagesIncluded == 10)
  }

  @Test("convenience initializer calculates totalTokens automatically")
  func convenienceInitializerCalculatesTotal() {
    let metadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      contextTruncated: true,
      messagesIncluded: 5
    )

    #expect(metadata.inputTokens == 1000)
    #expect(metadata.outputTokens == 500)
    #expect(metadata.totalTokens == 1500)
    #expect(metadata.contextTruncated == true)
    #expect(metadata.messagesIncluded == 5)
  }

  @Test("creates metadata with nil outputTokens (user message scenario)")
  func createsWithNilOutputTokens() {
    let metadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 3
    )

    #expect(metadata.inputTokens == 1000)
    #expect(metadata.outputTokens == nil)
    #expect(metadata.totalTokens == 1000)
    #expect(metadata.messagesIncluded == 3)
  }

  @Test("creates user message metadata with outputTokens nil")
  func userMessageMetadata() {
    // User messages have no output tokens since no response generated yet.
    let metadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 1
    )

    #expect(metadata.outputTokens == nil)
    #expect(metadata.totalTokens == 5000)
  }

  @Test("creates assistant message metadata with outputTokens populated")
  func assistantMessageMetadata() {
    // Assistant messages have both input and output tokens.
    let metadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: 1500,
      contextTruncated: false,
      messagesIncluded: 3
    )

    #expect(metadata.outputTokens == 1500)
    #expect(metadata.totalTokens == 6500)
  }

  // MARK: - Equality Tests

  @Test("TokenMetadata is equatable - identical instances are equal")
  func equatableIdenticalInstances() {
    let metadata1 = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      totalTokens: 1500,
      contextTruncated: true,
      messagesIncluded: 10
    )

    let metadata2 = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      totalTokens: 1500,
      contextTruncated: true,
      messagesIncluded: 10
    )

    #expect(metadata1 == metadata2)
  }

  @Test("TokenMetadata is equatable - different instances are not equal")
  func equatableDifferentInstances() {
    let metadata1 = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      contextTruncated: false,
      messagesIncluded: 10
    )

    let metadata2 = TokenMetadata(
      inputTokens: 2000,
      outputTokens: 500,
      contextTruncated: false,
      messagesIncluded: 10
    )

    #expect(metadata1 != metadata2)
  }

  @Test("TokenMetadata equality handles nil outputTokens")
  func equatableWithNilOutputTokens() {
    let metadata1 = TokenMetadata(
      inputTokens: 1000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let metadata2 = TokenMetadata(
      inputTokens: 1000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let metadata3 = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 0,
      contextTruncated: false,
      messagesIncluded: 5
    )

    #expect(metadata1 == metadata2)
    #expect(metadata1 != metadata3)
  }

  // MARK: - Codable Tests

  @Test("TokenMetadata encodes and decodes correctly")
  func codableRoundTrip() throws {
    let original = TokenMetadata(
      inputTokens: 12345,
      outputTokens: 678,
      totalTokens: 13023,
      contextTruncated: true,
      messagesIncluded: 15
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(TokenMetadata.self, from: data)

    #expect(decoded == original)
    #expect(decoded.inputTokens == 12345)
    #expect(decoded.outputTokens == 678)
    #expect(decoded.totalTokens == 13023)
    #expect(decoded.contextTruncated == true)
    #expect(decoded.messagesIncluded == 15)
  }

  @Test("TokenMetadata encodes nil outputTokens as null in JSON")
  func codableWithNilOutputTokens() throws {
    let original = TokenMetadata(
      inputTokens: 1000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(TokenMetadata.self, from: data)

    #expect(decoded.outputTokens == nil)
    #expect(decoded == original)
  }

  @Test("TokenMetadata decodes from JSON with outputTokens present")
  func decodesFromJSONWithOutputTokens() throws {
    let json = """
      {
        "inputTokens": 5000,
        "outputTokens": 2500,
        "totalTokens": 7500,
        "contextTruncated": false,
        "messagesIncluded": 8
      }
      """
    let data = json.data(using: .utf8)!

    let decoder = JSONDecoder()
    let metadata = try decoder.decode(TokenMetadata.self, from: data)

    #expect(metadata.inputTokens == 5000)
    #expect(metadata.outputTokens == 2500)
    #expect(metadata.totalTokens == 7500)
    #expect(metadata.contextTruncated == false)
    #expect(metadata.messagesIncluded == 8)
  }

  @Test("TokenMetadata decodes from JSON with null outputTokens")
  func decodesFromJSONWithNullOutputTokens() throws {
    let json = """
      {
        "inputTokens": 3000,
        "outputTokens": null,
        "totalTokens": 3000,
        "contextTruncated": true,
        "messagesIncluded": 4
      }
      """
    let data = json.data(using: .utf8)!

    let decoder = JSONDecoder()
    let metadata = try decoder.decode(TokenMetadata.self, from: data)

    #expect(metadata.inputTokens == 3000)
    #expect(metadata.outputTokens == nil)
    #expect(metadata.totalTokens == 3000)
    #expect(metadata.contextTruncated == true)
  }

  // MARK: - Edge Case Tests

  @Test("handles zero input tokens")
  func zeroInputTokens() {
    let metadata = TokenMetadata(
      inputTokens: 0,
      outputTokens: 100,
      contextTruncated: false,
      messagesIncluded: 1
    )

    #expect(metadata.inputTokens == 0)
    #expect(metadata.totalTokens == 100)
  }

  @Test("handles zero output tokens (not nil)")
  func zeroOutputTokens() {
    let metadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 0,
      contextTruncated: false,
      messagesIncluded: 5
    )

    #expect(metadata.outputTokens == 0)
    #expect(metadata.totalTokens == 1000)
  }

  @Test("handles very large token counts near maxInputTokens")
  func veryLargeTokenCounts() {
    let largeInputTokens = 1_030_000
    let metadata = TokenMetadata(
      inputTokens: largeInputTokens,
      outputTokens: 8000,
      contextTruncated: true,
      messagesIncluded: 100
    )

    #expect(metadata.inputTokens == largeInputTokens)
    #expect(metadata.outputTokens == 8000)
    #expect(metadata.totalTokens == largeInputTokens + 8000)
  }

  @Test("handles output tokens exceeding response buffer")
  func outputTokensExceedBuffer() {
    // API might return more tokens than expected buffer.
    let largeOutputTokens = 10_000
    let metadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: largeOutputTokens,
      contextTruncated: false,
      messagesIncluded: 3
    )

    #expect(metadata.outputTokens == largeOutputTokens)
    #expect(metadata.totalTokens == 15_000)
  }

  @Test("handles zero messagesIncluded (system-only request)")
  func zeroMessagesIncluded() {
    let metadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 0
    )

    #expect(metadata.messagesIncluded == 0)
  }

  @Test("context truncation tracking when history exceeds budget")
  func contextTruncationTracking() {
    let truncatedMetadata = TokenMetadata(
      inputTokens: TokenBudgetConstants.maxInputTokens,
      outputTokens: nil,
      contextTruncated: true,
      messagesIncluded: 50
    )

    let nonTruncatedMetadata = TokenMetadata(
      inputTokens: 100_000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 10
    )

    #expect(truncatedMetadata.contextTruncated == true)
    #expect(nonTruncatedMetadata.contextTruncated == false)
  }

  // MARK: - Sendable Tests

  @Test("TokenMetadata is Sendable")
  func isSendable() async {
    let metadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      contextTruncated: false,
      messagesIncluded: 5
    )

    // Verify metadata can be passed across actor boundaries.
    let result = await Task {
      metadata
    }.value

    #expect(result == metadata)
  }

  @Test("TokenMetadata can be passed to detached task")
  func passableToDetachedTask() async {
    let metadata = TokenMetadata(
      inputTokens: 2000,
      outputTokens: 1000,
      contextTruncated: true,
      messagesIncluded: 8
    )

    let passedMetadata = await Task.detached {
      return metadata
    }.value

    #expect(passedMetadata.inputTokens == 2000)
    #expect(passedMetadata.outputTokens == 1000)
  }
}

// MARK: - ChatMessage TokenMetadata Integration Tests

@Suite("ChatMessage TokenMetadata Integration Tests")
struct ChatMessageTokenMetadataIntegrationTests {

  // MARK: - Creation Tests

  @Test("creates ChatMessage with tokenMetadata")
  func createsWithTokenMetadata() {
    let tokenMetadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: 1500,
      contextTruncated: false,
      messagesIncluded: 10
    )

    let message = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .assistant,
      content: "AI response",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    #expect(message.tokenMetadata != nil)
    #expect(message.tokenMetadata?.inputTokens == 5000)
    #expect(message.tokenMetadata?.outputTokens == 1500)
    #expect(message.tokenMetadata?.totalTokens == 6500)
  }

  @Test("creates ChatMessage without tokenMetadata (backwards compatibility)")
  func createsWithoutTokenMetadata() {
    let message = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: Date(),
      contextMetadata: nil
    )

    #expect(message.tokenMetadata == nil)
    #expect(message.id == "msg-1")
    #expect(message.content == "Hello")
  }

  @Test("creates user message with tokenMetadata and nil outputTokens")
  func userMessageWithTokenMetadata() {
    let tokenMetadata = TokenMetadata(
      inputTokens: 3000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let message = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "User question",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    #expect(message.role == .user)
    #expect(message.tokenMetadata?.outputTokens == nil)
    #expect(message.tokenMetadata?.totalTokens == 3000)
  }

  @Test("creates assistant message with tokenMetadata and outputTokens")
  func assistantMessageWithTokenMetadata() {
    let tokenMetadata = TokenMetadata(
      inputTokens: 3000,
      outputTokens: 1500,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let message = ChatMessage(
      id: "msg-2",
      conversationID: "conv-1",
      role: .assistant,
      content: "Assistant response",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    #expect(message.role == .assistant)
    #expect(message.tokenMetadata?.outputTokens == 1500)
    #expect(message.tokenMetadata?.totalTokens == 4500)
  }

  // MARK: - Codable Tests

  @Test("ChatMessage with tokenMetadata encodes and decodes correctly")
  func codableRoundTripWithTokenMetadata() throws {
    let tokenMetadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: 2000,
      contextTruncated: true,
      messagesIncluded: 12
    )

    let original = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .assistant,
      content: "Test content",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ChatMessage.self, from: data)

    #expect(decoded.id == original.id)
    #expect(decoded.content == original.content)
    #expect(decoded.tokenMetadata != nil)
    #expect(decoded.tokenMetadata?.inputTokens == 5000)
    #expect(decoded.tokenMetadata?.outputTokens == 2000)
    #expect(decoded.tokenMetadata?.contextTruncated == true)
  }

  @Test("ChatMessage without tokenMetadata encodes and decodes correctly")
  func codableRoundTripWithoutTokenMetadata() throws {
    let original = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "User message",
      timestamp: Date(),
      contextMetadata: nil
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ChatMessage.self, from: data)

    #expect(decoded.id == original.id)
    #expect(decoded.tokenMetadata == nil)
  }

  @Test("legacy message without tokenMetadata field decodes correctly")
  func decodesLegacyMessageWithoutTokenMetadataField() throws {
    // Simulate a legacy message JSON that was saved before tokenMetadata was added.
    let legacyJSON = """
      {
        "id": "legacy-msg-1",
        "conversationID": "conv-1",
        "role": "user",
        "content": "Legacy message content",
        "timestamp": 0
      }
      """
    let data = legacyJSON.data(using: .utf8)!

    let decoder = JSONDecoder()
    let message = try decoder.decode(ChatMessage.self, from: data)

    #expect(message.id == "legacy-msg-1")
    #expect(message.content == "Legacy message content")
    #expect(message.tokenMetadata == nil)
  }

  // MARK: - Equality Tests

  @Test("messages with same tokenMetadata are equal")
  func equalityWithSameTokenMetadata() {
    let timestamp = Date()
    let tokenMetadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let message1 = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    let message2 = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    #expect(message1 == message2)
  }

  @Test("messages with different tokenMetadata are not equal")
  func equalityWithDifferentTokenMetadata() {
    let timestamp = Date()

    let tokenMetadata1 = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let tokenMetadata2 = TokenMetadata(
      inputTokens: 2000,
      outputTokens: 500,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let message1 = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil,
      tokenMetadata: tokenMetadata1
    )

    let message2 = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil,
      tokenMetadata: tokenMetadata2
    )

    #expect(message1 != message2)
  }

  @Test("messages with nil tokenMetadata can equal each other")
  func equalityWithBothNilTokenMetadata() {
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

    #expect(message1 == message2)
  }

  @Test("message with tokenMetadata not equal to message without")
  func equalityOneNilOnePresent() {
    let timestamp = Date()
    let tokenMetadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let messageWithMetadata = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    let messageWithoutMetadata = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hello",
      timestamp: timestamp,
      contextMetadata: nil
    )

    #expect(messageWithMetadata != messageWithoutMetadata)
  }

  // MARK: - Edge Case Tests

  @Test("user message vs assistant message metadata patterns")
  func userVsAssistantMetadataPatterns() {
    // User message pattern: outputTokens is nil.
    let userMetadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 3
    )

    // Assistant message pattern: outputTokens is populated.
    let assistantMetadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: 1500,
      contextTruncated: false,
      messagesIncluded: 4
    )

    let userMessage = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Question",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: userMetadata
    )

    let assistantMessage = ChatMessage(
      id: "msg-2",
      conversationID: "conv-1",
      role: .assistant,
      content: "Answer",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: assistantMetadata
    )

    #expect(userMessage.tokenMetadata?.outputTokens == nil)
    #expect(assistantMessage.tokenMetadata?.outputTokens == 1500)
    #expect(userMessage.tokenMetadata?.inputTokens == assistantMessage.tokenMetadata?.inputTokens)
  }

  @Test("partial migration scenario - mixed messages with and without tokenMetadata")
  func partialMigrationScenario() {
    let legacyMessage = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Old message",
      timestamp: Date(),
      contextMetadata: nil
    )

    let newMessage = ChatMessage(
      id: "msg-2",
      conversationID: "conv-1",
      role: .assistant,
      content: "New response",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: TokenMetadata(
        inputTokens: 1000,
        outputTokens: 500,
        contextTruncated: false,
        messagesIncluded: 2
      )
    )

    #expect(legacyMessage.tokenMetadata == nil)
    #expect(newMessage.tokenMetadata != nil)
  }
}

// MARK: - Migration Compatibility Tests

@Suite("Migration Compatibility Tests")
struct MigrationCompatibilityTests {

  @Test("TokenBudgetConstants replaces deprecated maxContextLength")
  func replacesDeprecatedMaxContextLength() {
    // ChatConstants.maxContextLength was 50,000 characters.
    // TokenBudgetConstants.maxContextTokens is 500,000 tokens.
    // At ~4 chars/token, this is ~2,000,000 characters (40x more capacity).
    let oldCharLimit = 50_000
    let newCharCapacity = Double(TokenBudgetConstants.maxContextTokens) * TokenBudgetConstants.charsPerToken

    #expect(newCharCapacity > Double(oldCharLimit))
  }

  @Test("TokenBudgetConstants replaces deprecated maxMessageHistory")
  func replacesDeprecatedMaxMessageHistory() {
    // ChatConstants.maxMessageHistory was 50 messages.
    // TokenBudgetConstants.maxConversationHistoryTokens allows far more.
    // At ~100 chars/message and 4 chars/token, that is ~25 tokens/message.
    // 530,384 tokens / 25 = ~21,000 messages (420x more capacity).
    let oldMessageLimit = 50
    let tokensPerMessage = 25  // Conservative estimate.
    let newMessageCapacity = TokenBudgetConstants.maxConversationHistoryTokens / tokensPerMessage

    #expect(newMessageCapacity > oldMessageLimit)
  }

  @Test("TokenBudgetConstants values match contract specifications")
  func valuesMatchContractSpecifications() {
    // Verify all values match the contract exactly.
    #expect(TokenBudgetConstants.geminiMaxTokens == 1_048_576)
    #expect(TokenBudgetConstants.systemReserveTokens == 10_000)
    #expect(TokenBudgetConstants.responseBufferTokens == 8_192)
    #expect(TokenBudgetConstants.maxInputTokens == 1_030_384)
    #expect(TokenBudgetConstants.maxContextTokens == 500_000)
    #expect(TokenBudgetConstants.maxConversationHistoryTokens == 530_384)
    #expect(TokenBudgetConstants.charsPerToken == 4.0)
  }
}

// MARK: - Token Estimation Contract Tests

@Suite("Token Estimation Contract Tests")
struct TokenEstimationContractTests {

  // These tests define the expected behavior for token estimation utilities
  // that will be implemented based on the contract.

  @Test("estimating tokens for simple text follows chars/token heuristic")
  func estimateSimpleText() {
    // "Hello world" = 11 characters.
    // 11 / 4.0 = 2.75, rounded up = 3 tokens.
    let text = "Hello world"
    let expectedTokens = Int(ceil(Double(text.count) / TokenBudgetConstants.charsPerToken))

    #expect(expectedTokens == 3)
  }

  @Test("estimating tokens for empty string returns zero")
  func estimateEmptyString() {
    let text = ""
    let expectedTokens = Int(ceil(Double(text.count) / TokenBudgetConstants.charsPerToken))

    #expect(expectedTokens == 0)
  }

  @Test("estimating tokens for 4000 characters returns approximately 1000 tokens")
  func estimateConversationTokens() {
    let characterCount = 4000
    let expectedTokens = Int(ceil(Double(characterCount) / TokenBudgetConstants.charsPerToken))

    #expect(expectedTokens == 1000)
  }

  @Test("budget check: 600K tokens within 1.03M limit passes")
  func budgetCheckWithinLimit() {
    let messageTokens = 100_000
    let contextTokens = 500_000
    let totalTokens = messageTokens + contextTokens
    let withinBudget = totalTokens <= TokenBudgetConstants.maxInputTokens

    #expect(withinBudget == true)
  }

  @Test("budget check: 1.1M tokens exceeds 1.03M limit fails")
  func budgetCheckExceedsLimit() {
    let messageTokens = 600_000
    let contextTokens = 500_000
    let totalTokens = messageTokens + contextTokens
    let withinBudget = totalTokens <= TokenBudgetConstants.maxInputTokens

    #expect(withinBudget == false)
  }

  @Test("very long text estimation does not overflow")
  func veryLongTextEstimation() {
    // 10 million characters.
    let characterCount = 10_000_000
    let expectedTokens = Int(ceil(Double(characterCount) / TokenBudgetConstants.charsPerToken))

    #expect(expectedTokens == 2_500_000)
    #expect(expectedTokens > 0)
  }

  @Test("whitespace-only text is counted by character")
  func whitespaceOnlyText() {
    let text = "     "  // 5 spaces
    let expectedTokens = Int(ceil(Double(text.count) / TokenBudgetConstants.charsPerToken))

    #expect(expectedTokens == 2)  // ceil(5 / 4) = 2
  }
}

// MARK: - Threading and Sendable Conformance Tests

@Suite("Threading and Sendable Conformance Tests")
struct ThreadingAndSendableTests {

  @Test("TokenBudgetConstants static properties are thread-safe")
  func constantsAreThreadSafe() async {
    // Access constants from multiple concurrent tasks.
    async let value1 = Task { TokenBudgetConstants.geminiMaxTokens }.value
    async let value2 = Task { TokenBudgetConstants.maxInputTokens }.value
    async let value3 = Task { TokenBudgetConstants.maxContextTokens }.value

    let results = await [value1, value2, value3]

    #expect(results[0] == 1_048_576)
    #expect(results[1] == 1_030_384)
    #expect(results[2] == 500_000)
  }

  @Test("TokenMetadata is Sendable across actor boundaries")
  func tokenMetadataSendable() async {
    let metadata = TokenMetadata(
      inputTokens: 5000,
      outputTokens: 2500,
      contextTruncated: true,
      messagesIncluded: 10
    )

    let result = await Task.detached {
      return metadata
    }.value

    #expect(result.inputTokens == 5000)
    #expect(result.outputTokens == 2500)
    #expect(result.contextTruncated == true)
  }

  @Test("ChatMessage with TokenMetadata is Sendable")
  func chatMessageWithMetadataSendable() async {
    let tokenMetadata = TokenMetadata(
      inputTokens: 1000,
      outputTokens: 500,
      contextTruncated: false,
      messagesIncluded: 3
    )

    let message = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .assistant,
      content: "Response",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: tokenMetadata
    )

    let result = await Task.detached {
      return message
    }.value

    #expect(result.id == "msg-1")
    #expect(result.tokenMetadata?.inputTokens == 1000)
  }

  @Test("Optional TokenMetadata is Sendable")
  func optionalTokenMetadataSendable() async {
    let metadata: TokenMetadata? = TokenMetadata(
      inputTokens: 2000,
      outputTokens: nil,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let result: TokenMetadata? = await Task.detached {
      return metadata
    }.value

    #expect(result?.inputTokens == 2000)
  }
}
