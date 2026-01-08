// Contract.swift
// Defines the API contract for token-aware message building in ChatService.
// This contract specifies the token estimation algorithm, message inclusion logic,
// and comprehensive test scenarios for updating buildAPIMessages() to use
// token-based truncation instead of message count limits.

import Foundation

// MARK: - API Contract

// MARK: TokenEstimator

// Estimates token count for text content.
// Uses a character-based heuristic for fast estimation without API calls.
// The estimation is intentionally conservative to avoid exceeding limits.
struct TokenEstimator {
  // Approximate number of characters per token.
  // Uses the value from TokenBudgetConstants.charsPerToken (4.0).
  // This heuristic is based on typical English text; other languages may vary.
  private let charsPerToken: Double

  // Creates an estimator with the specified characters-per-token ratio.
  init(charsPerToken: Double = TokenBudgetConstants.charsPerToken)

  // Estimates the token count for the given text.
  // Returns: Ceiling of (text.count / charsPerToken), minimum 0.
  func estimateTokenCount(_ text: String) -> Int
}

/*
 ACCEPTANCE CRITERIA: TokenEstimator.estimateTokenCount()

 SCENARIO: Estimate tokens for typical text
 GIVEN: Text "Hello, world!" (13 characters)
  AND: charsPerToken is 4.0
 WHEN: estimateTokenCount() is called
 THEN: Returns 4 (ceil(13 / 4.0) = 4)

 SCENARIO: Estimate tokens for exact multiple
 GIVEN: Text "test" (4 characters)
  AND: charsPerToken is 4.0
 WHEN: estimateTokenCount() is called
 THEN: Returns 1 (ceil(4 / 4.0) = 1)

 SCENARIO: Estimate tokens for empty string
 GIVEN: Text "" (0 characters)
 WHEN: estimateTokenCount() is called
 THEN: Returns 0

 SCENARIO: Estimate tokens for whitespace-only string
 GIVEN: Text "   " (3 characters)
 WHEN: estimateTokenCount() is called
 THEN: Returns 1 (ceil(3 / 4.0) = 1)
  AND: Whitespace is counted as characters

 SCENARIO: Estimate tokens for very long text
 GIVEN: Text with 100,000 characters
  AND: charsPerToken is 4.0
 WHEN: estimateTokenCount() is called
 THEN: Returns 25,000
  AND: Calculation does not overflow

 SCENARIO: Estimate tokens for Unicode text
 GIVEN: Text with emoji and CJK characters
 WHEN: estimateTokenCount() is called
 THEN: Uses character count (not byte count)
  AND: Each character counts as 1 regardless of encoding

 SCENARIO: Estimate tokens for single character
 GIVEN: Text "A" (1 character)
  AND: charsPerToken is 4.0
 WHEN: estimateTokenCount() is called
 THEN: Returns 1 (ceil(1 / 4.0) = 1)
*/

// MARK: - MessageBuildResult

// Result of building API messages with token budget tracking.
// Contains both the messages and metadata about the build process.
struct MessageBuildResult: Sendable, Equatable {
  // The API messages to send, ordered chronologically (oldest first).
  let messages: [APIMessage]

  // Total estimated tokens used by all included messages.
  let estimatedTokenCount: Int

  // Number of messages included in the result.
  let messageCount: Int

  // Whether any messages were truncated due to token budget.
  let wasTruncated: Bool

  // Number of messages that were excluded due to token limits.
  let messagesExcluded: Int
}

/*
 ACCEPTANCE CRITERIA: MessageBuildResult

 SCENARIO: Result for small conversation
 GIVEN: All messages fit within token budget
 WHEN: MessageBuildResult is created
 THEN: wasTruncated is false
  AND: messagesExcluded is 0
  AND: messageCount equals total message count

 SCENARIO: Result for truncated conversation
 GIVEN: Some messages were excluded
 WHEN: MessageBuildResult is created
 THEN: wasTruncated is true
  AND: messagesExcluded is positive
  AND: messageCount equals included message count
*/

// MARK: - TokenAwareMessageBuilder

// Builds API message arrays using token-based truncation.
// Works backwards from newest message to include as many messages as fit.
// Private implementation within ChatService; no protocol needed.

/*
 FUNCTION SIGNATURE:

 private func buildAPIMessages(
   messages: [ChatMessage],
   newMessage: ChatMessage
 ) -> [APIMessage]

 ALGORITHM:

 1. Start with the newest message (newMessage) - this is always included
 2. Estimate tokens for newMessage content
 3. Iterate through messages in reverse order (newest to oldest)
 4. For each message (excluding newMessage):
    a. If user message with contextMetadata, strip context (extractUserTextFromMessage)
    b. Estimate tokens for the processed content
    c. If adding this message would exceed maxConversationHistoryTokens, stop
    d. Otherwise, prepend the message to the result
 5. Convert ChatMessages to APIMessages
 6. Return chronologically ordered array (oldest first)

 NOTES:
 - The newMessage is always included regardless of token count
 - Context stripping only applies to user messages that have contextMetadata
 - Context stripping removes the "[context]\n\n---\n\nUser: " prefix
 - Messages are processed in reverse but returned in chronological order
*/

// MARK: - Acceptance Criteria: Message Building

/*
 SCENARIO: All messages fit within budget
 GIVEN: A conversation with 5 messages totaling 1000 tokens
  AND: maxConversationHistoryTokens is 530,384
 WHEN: buildAPIMessages() is called
 THEN: All 5 messages are included
  AND: Messages are in chronological order
  AND: Estimated tokens is approximately 1000

 SCENARIO: Truncation needed - old messages excluded
 GIVEN: A conversation with 100 messages
  AND: Total token count exceeds maxConversationHistoryTokens
 WHEN: buildAPIMessages() is called
 THEN: Only the newest messages that fit are included
  AND: newMessage is always included
  AND: Messages are in chronological order
  AND: Oldest messages are excluded first

 SCENARIO: Single message conversation
 GIVEN: A conversation with only the newMessage
  AND: messages array is empty
 WHEN: buildAPIMessages() is called
 THEN: Returns array with just newMessage
  AND: No truncation occurs

 SCENARIO: newMessage already in messages array
 GIVEN: newMessage exists in messages array
 WHEN: buildAPIMessages() is called
 THEN: newMessage is not duplicated
  AND: newMessage appears exactly once at its chronological position

 SCENARIO: Empty messages array
 GIVEN: messages is empty
  AND: newMessage is the first message
 WHEN: buildAPIMessages() is called
 THEN: Returns array containing only newMessage
  AND: No errors occur

 SCENARIO: Context stripping for old user messages
 GIVEN: Conversation with user messages containing embedded context
  AND: Context format is "[context]\n\n---\n\nUser: [actual message]"
 WHEN: buildAPIMessages() is called
 THEN: Old user messages have context stripped
  AND: Only the actual user text is included
  AND: newMessage retains its full content (context not stripped)
  AND: Assistant messages are unchanged

 SCENARIO: Context stripping preserves token budget
 GIVEN: User message with 10,000 character context + 100 character user text
 WHEN: buildAPIMessages() processes this message
 THEN: Stripped message uses ~25 tokens instead of ~2500
  AND: More messages can fit within the budget

 SCENARIO: Exact token budget match
 GIVEN: Messages that exactly fill the token budget
 WHEN: buildAPIMessages() is called
 THEN: All messages that fit are included
  AND: The message that would exceed is excluded
  AND: No off-by-one errors

 SCENARIO: newMessage exceeds budget alone
 GIVEN: newMessage content is extremely long (>500,000 tokens)
  AND: It alone exceeds maxConversationHistoryTokens
 WHEN: buildAPIMessages() is called
 THEN: Only newMessage is included
  AND: No crash occurs
  AND: API call proceeds (server will handle the limit)

 SCENARIO: Mixed user and assistant messages
 GIVEN: Conversation alternating user and assistant messages
 WHEN: buildAPIMessages() is called
 THEN: Both roles are correctly processed
  AND: Assistant messages are included unchanged
  AND: User messages have context stripped (except newMessage)

 SCENARIO: Preserves message order
 GIVEN: Messages with timestamps [t1, t2, t3, t4, t5]
 WHEN: buildAPIMessages() returns messages
 THEN: Order is [t1, t2, t3, t4, t5] (oldest first)
  AND: API expects chronological order
*/

// MARK: - Acceptance Criteria: Token Estimation Integration

/*
 SCENARIO: Token count matches estimation
 GIVEN: Message with content "Hello, how can I help you today?"
 WHEN: Token estimation is calculated
 THEN: Result is ceil(32 / 4.0) = 8 tokens

 SCENARIO: Multiple messages token accumulation
 GIVEN: 3 messages with 100, 200, 300 characters respectively
 WHEN: Total tokens are estimated
 THEN: Result is ceil(100/4) + ceil(200/4) + ceil(300/4) = 25 + 50 + 75 = 150

 SCENARIO: Context stripping reduces token count
 GIVEN: User message with contextMetadata
  AND: Full content is 5000 characters (context + user text)
  AND: Stripped user text is 100 characters
 WHEN: Token estimation uses stripped content
 THEN: Estimate is 25 tokens instead of 1250 tokens

 SCENARIO: Token budget threshold respected
 GIVEN: Messages totaling 530,000 estimated tokens
  AND: Next message would add 1000 tokens (exceeding 530,384)
 WHEN: buildAPIMessages() decides inclusion
 THEN: The message causing overflow is excluded
  AND: Running total stays at 530,000
*/

// MARK: - Acceptance Criteria: Context Stripping

/*
 SCENARIO: Strip context from standard format
 GIVEN: User message content:
   "Context from notebook X:\nSome text here\n\n---\n\nUser: What does this mean?"
 WHEN: extractUserTextFromMessage() is called
 THEN: Returns "What does this mean?"

 SCENARIO: Strip context with multiline user text
 GIVEN: User message content:
   "Context...\n\n---\n\nUser: First line\nSecond line\nThird line"
 WHEN: extractUserTextFromMessage() is called
 THEN: Returns "First line\nSecond line\nThird line"

 SCENARIO: No context separator found
 GIVEN: User message content "Just a plain question?"
 WHEN: extractUserTextFromMessage() is called
 THEN: Returns the entire content unchanged

 SCENARIO: Empty user text after separator
 GIVEN: User message content "Context...\n\n---\n\nUser: "
 WHEN: extractUserTextFromMessage() is called
 THEN: Returns empty string ""

 SCENARIO: Multiple separator patterns in content
 GIVEN: User message content contains "---" multiple times
 WHEN: extractUserTextFromMessage() is called
 THEN: Uses the first occurrence of "\n\n---\n\nUser: "
  AND: Subsequent separators are part of user text

 SCENARIO: User message without contextMetadata
 GIVEN: User message with contextMetadata = nil
 WHEN: buildAPIMessages() processes the message
 THEN: Context stripping is skipped
  AND: Full content is used for token estimation

 SCENARIO: Assistant message is never stripped
 GIVEN: Assistant message (any content)
 WHEN: buildAPIMessages() processes the message
 THEN: Content is used unchanged
  AND: No context stripping occurs regardless of content
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Nil content in message
 GIVEN: ChatMessage with empty content ""
 WHEN: Token estimation is performed
 THEN: Returns 0 tokens
  AND: Message is still included in results

 EDGE CASE: Very long single message
 GIVEN: A single message with 2,000,000 characters
 WHEN: Token estimation is performed
 THEN: Returns 500,000 tokens
  AND: Calculation does not overflow

 EDGE CASE: Rapid message accumulation
 GIVEN: Conversation with 1000 messages
 WHEN: buildAPIMessages() is called
 THEN: Processing completes in reasonable time
  AND: Only messages within budget are included
  AND: No memory issues occur

 EDGE CASE: Unicode-heavy content
 GIVEN: Message with emoji, CJK, and special characters
 WHEN: Token estimation uses character count
 THEN: Swift String.count is used (not UTF-8 bytes)
  AND: Each grapheme cluster counts as 1 character

 EDGE CASE: Messages with identical IDs
 GIVEN: Two messages with the same ID (data corruption)
 WHEN: buildAPIMessages() checks msg.id != newMessage.id
 THEN: Both instances are handled correctly
  AND: No crash occurs

 EDGE CASE: Out-of-order timestamps
 GIVEN: Messages not sorted by timestamp
 WHEN: buildAPIMessages() uses messages array order
 THEN: Order from input array is preserved
  AND: Implementation assumes caller provides sorted messages

 EDGE CASE: newMessage not in messages array
 GIVEN: newMessage.id does not appear in messages array
 WHEN: buildAPIMessages() is called
 THEN: newMessage is included as the newest
  AND: All messages from array are candidates for inclusion

 EDGE CASE: Concurrent access during build
 GIVEN: ChatService is an actor
 WHEN: buildAPIMessages() is called
 THEN: Actor isolation prevents concurrent access
  AND: No race conditions occur

 EDGE CASE: Token budget of zero
 GIVEN: Hypothetical scenario where maxConversationHistoryTokens is 0
 WHEN: buildAPIMessages() is called
 THEN: Only newMessage is included
  AND: No other messages fit

 EDGE CASE: Negative character count (impossible but defensive)
 GIVEN: String.count returns non-negative by design
 WHEN: Token estimation divides by charsPerToken
 THEN: Result is always non-negative
  AND: Ceil function handles zero correctly

 EDGE CASE: Context separator at very end
 GIVEN: Content ends with "\n\n---\n\nUser: "
 WHEN: extractUserTextFromMessage() is called
 THEN: Returns empty string
  AND: No index out of bounds error

 EDGE CASE: Context separator at very start
 GIVEN: Content is "\n\n---\n\nUser: actual message"
 WHEN: extractUserTextFromMessage() is called
 THEN: Returns "actual message"
  AND: Leading newlines before separator are handled

 EDGE CASE: All messages are from same role
 GIVEN: 10 consecutive user messages (no assistant responses)
 WHEN: buildAPIMessages() is called
 THEN: All messages processed correctly
  AND: Role filtering does not affect inclusion

 EDGE CASE: Message with only whitespace content
 GIVEN: Message content is "   \n\t\n   "
 WHEN: Token estimation is performed
 THEN: Returns tokens based on character count
  AND: Whitespace characters are counted
*/

// MARK: - Backwards Compatibility

/*
 COMPATIBILITY: Existing ChatMessage structure unchanged
 The contract uses the existing ChatMessage struct from ChatContract.swift.
 No changes to the message storage format are required.
 The tokenMetadata field (already defined) can be populated after implementation.

 COMPATIBILITY: APIMessage output format unchanged
 The output [APIMessage] array has the same structure.
 Only the selection algorithm changes, not the format.

 COMPATIBILITY: Context format unchanged
 The separator pattern "\n\n---\n\nUser: " is already in use.
 extractUserTextFromMessage() already exists in ChatService.

 COMPATIBILITY: TokenBudgetConstants already defined
 Uses existing constants from ChatContract.swift:
 - maxConversationHistoryTokens: 530,384
 - charsPerToken: 4.0
*/

// MARK: - Constants Reference

/*
 TOKEN BUDGET CONSTANTS (from ChatContract.swift):

 TokenBudgetConstants.maxConversationHistoryTokens = 530,384
   Maximum tokens for conversation history.
   This is the budget that buildAPIMessages() must respect.

 TokenBudgetConstants.charsPerToken = 4.0
   Approximate characters per token for estimation.
   Used by TokenEstimator for fast heuristic calculation.

 TokenBudgetConstants.maxInputTokens = 1,030,384
   Total budget for all input (context + history).
   Context gathering uses maxContextTokens (500,000).
   History uses maxConversationHistoryTokens (530,384).

 NOTE: These constants assume Gemini 1.5 Pro's 1M token context window.
 The conservative budgeting leaves room for system prompts and response.
*/

// MARK: - Implementation Notes

/*
 IMPLEMENTATION: No new public API
 This is a private method update within ChatService.
 The public ChatServiceProtocol interface remains unchanged.
 Only the internal message selection algorithm is modified.

 IMPLEMENTATION: TokenEstimator can be a simple struct
 No actor isolation needed for pure calculation.
 Can be implemented inline or as a helper struct.
 Should be testable in isolation.

 IMPLEMENTATION: Performance considerations
 Token estimation is O(1) per message (character count).
 Message iteration is O(n) where n is conversation length.
 Context stripping uses String range finding (efficient).

 IMPLEMENTATION: Testing approach
 Unit tests for TokenEstimator in isolation.
 Unit tests for extractUserTextFromMessage in isolation.
 Integration tests for buildAPIMessages with mock messages.
 Edge case tests for boundary conditions.

 IMPLEMENTATION: Future enhancements
 Consider caching token estimates on ChatMessage.
 Consider using actual tokenizer for high-accuracy mode.
 Consider dynamic charsPerToken based on content analysis.
*/

// MARK: - Test Scenarios Summary

/*
 TOKEN ESTIMATION TESTS:
 1. Typical text (verify ceiling calculation)
 2. Exact multiple (no rounding needed)
 3. Empty string (returns 0)
 4. Whitespace-only (counts as characters)
 5. Very long text (no overflow)
 6. Unicode content (uses character count)
 7. Single character (minimum 1 token)

 MESSAGE BUILDING TESTS:
 1. All messages fit (no truncation)
 2. Truncation needed (old messages excluded)
 3. Single message (just newMessage)
 4. Empty messages array
 5. Duplicate handling (newMessage in array)
 6. Context stripping (user messages)
 7. Exact budget match
 8. Over-budget newMessage (include anyway)
 9. Mixed roles (user and assistant)
 10. Order preservation (chronological)

 CONTEXT STRIPPING TESTS:
 1. Standard format extraction
 2. Multiline user text
 3. No separator found
 4. Empty after separator
 5. Multiple separators
 6. No contextMetadata (skip stripping)
 7. Assistant messages (never strip)

 EDGE CASE TESTS:
 1. Empty content
 2. Very long single message
 3. Many messages (performance)
 4. Unicode-heavy content
 5. Identical message IDs
 6. Out-of-order timestamps
 7. newMessage not in array
 8. Whitespace-only content
 9. Separator at boundaries
*/
