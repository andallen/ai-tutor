// Contract.swift
// Defines the API contract for parsing token metadata from Firebase responses.
// Phase 4 of Token-Based Context Management: Firebase Backend Token Counting.
// The Firebase backend uses Gemini's countTokens API for precise token counting
// and includes token metadata in responses. This contract specifies the Swift
// client-side parsing of that metadata.

import Foundation

// MARK: - API Contract

// MARK: - FirebaseTokenResponse

// Represents the enhanced response from Firebase that includes token metadata.
// The Firebase backend returns both the AI response and precise token counts.
// Used for non-streaming sendMessage responses.
struct FirebaseTokenResponse: Sendable, Codable, Equatable {
  // The AI-generated response text from Gemini.
  let response: String

  // Token usage metadata from Gemini's countTokens API.
  // Present when the backend successfully counted tokens.
  // Nil if token counting failed (response is still returned).
  let tokenMetadata: FirebaseResponseTokenMetadata?

  // Indicates whether the backend truncated the message history.
  // True if older messages were dropped to fit within token limits.
  let historyTruncated: Bool?

  // Number of messages included in the API request after truncation.
  // Nil if truncation was not performed or not tracked.
  let messagesIncluded: Int?
}

/*
 ACCEPTANCE CRITERIA: FirebaseTokenResponse Parsing

 SCENARIO: Parse response with full token metadata
 GIVEN: Firebase response JSON with all token fields
 WHEN: Decoded to FirebaseTokenResponse
 THEN: response contains the AI text
  AND: tokenMetadata contains input and output token counts
  AND: historyTruncated indicates truncation status
  AND: messagesIncluded shows message count

 SCENARIO: Parse response without token metadata (legacy/fallback)
 GIVEN: Firebase response JSON without tokenMetadata field
 WHEN: Decoded to FirebaseTokenResponse
 THEN: response contains the AI text
  AND: tokenMetadata is nil
  AND: Client falls back to client-side estimation

 SCENARIO: Parse response with partial token metadata
 GIVEN: Firebase response JSON where token counting failed
 WHEN: Decoded to FirebaseTokenResponse
 THEN: response contains the AI text
  AND: tokenMetadata may be nil or have partial data
  AND: Client handles gracefully
*/

// MARK: - FirebaseResponseTokenMetadata

// Token usage information returned by the Firebase backend.
// Populated by calling Gemini's countTokens API.
// Provides precise token counts rather than client-side estimates.
struct FirebaseResponseTokenMetadata: Sendable, Codable, Equatable {
  // Tokens used for the input (prompt + context + history).
  // Counted by Gemini countTokens API before generateContent call.
  let promptTokenCount: Int

  // Tokens used for the model's response.
  // Reported by Gemini in the generateContent response usageMetadata.
  let candidatesTokenCount: Int

  // Total tokens consumed for this request.
  // Sum of promptTokenCount and candidatesTokenCount.
  let totalTokenCount: Int
}

/*
 ACCEPTANCE CRITERIA: FirebaseResponseTokenMetadata

 SCENARIO: Parse complete token metadata
 GIVEN: JSON with promptTokenCount, candidatesTokenCount, totalTokenCount
 WHEN: Decoded to FirebaseResponseTokenMetadata
 THEN: All fields are populated correctly
  AND: totalTokenCount equals promptTokenCount + candidatesTokenCount

 SCENARIO: Token metadata with zero values
 GIVEN: An API request with empty input (edge case)
 WHEN: Decoded to FirebaseResponseTokenMetadata
 THEN: promptTokenCount may be 0
  AND: candidatesTokenCount may be 0
  AND: No errors occur
*/

// MARK: - FirebaseStreamTokenMetadata

// Token metadata sent at the end of a streaming response.
// The Firebase backend sends a final SSE event with token counts.
// Streaming responses accumulate tokens as chunks are sent.
struct FirebaseStreamTokenMetadata: Sendable, Codable, Equatable {
  // Tokens used for the input prompt before streaming began.
  let promptTokenCount: Int

  // Tokens generated in the streamed response.
  // Final count after all chunks have been sent.
  let candidatesTokenCount: Int

  // Total tokens for the entire streaming interaction.
  let totalTokenCount: Int

  // True if the backend truncated history to fit token limits.
  let historyTruncated: Bool

  // Number of messages included in the API request.
  let messagesIncluded: Int
}

/*
 ACCEPTANCE CRITERIA: FirebaseStreamTokenMetadata

 SCENARIO: Parse streaming completion metadata
 GIVEN: Final SSE event with tokenMetadata field
 WHEN: Parsed after stream done signal
 THEN: All token counts are available
  AND: historyTruncated reflects truncation status
  AND: messagesIncluded shows message count

 SCENARIO: Streaming response without token metadata
 GIVEN: Firebase backend that does not send token metadata
 WHEN: Stream completes without tokenMetadata
 THEN: Client handles nil gracefully
  AND: Falls back to client-side estimation
*/

// MARK: - FirebaseStreamChunk

// Represents a single chunk in a streaming response.
// May contain text content, token metadata, or completion signal.
// Parsed from Server-Sent Events data field.
struct FirebaseStreamChunk: Sendable, Codable, Equatable {
  // Text content for this chunk.
  // Present for text streaming chunks.
  let text: String?

  // Completion signal.
  // True when the stream has ended.
  let done: Bool?

  // Error message if the stream encountered an error.
  let error: String?

  // Token metadata sent with the final chunk.
  // Only present when done is true.
  let tokenMetadata: FirebaseStreamTokenMetadata?
}

/*
 ACCEPTANCE CRITERIA: FirebaseStreamChunk

 SCENARIO: Parse text chunk
 GIVEN: SSE data {"text": "Hello"}
 WHEN: Decoded to FirebaseStreamChunk
 THEN: text is "Hello"
  AND: done is nil
  AND: tokenMetadata is nil

 SCENARIO: Parse completion chunk with token metadata
 GIVEN: SSE data {"done": true, "tokenMetadata": {...}}
 WHEN: Decoded to FirebaseStreamChunk
 THEN: done is true
  AND: tokenMetadata contains token counts
  AND: text is nil

 SCENARIO: Parse error chunk
 GIVEN: SSE data {"error": "Rate limit exceeded"}
 WHEN: Decoded to FirebaseStreamChunk
 THEN: error is "Rate limit exceeded"
  AND: text is nil
  AND: done may be nil or true
*/

// MARK: - TokenResponseParserProtocol

// Protocol for parsing token metadata from Firebase responses.
// Provides methods for both synchronous and streaming response parsing.
// Implementations should handle missing or malformed token data gracefully.
protocol TokenResponseParserProtocol: Sendable {
  // Parses a complete response from sendMessage endpoint.
  // data: Raw JSON data from HTTP response body.
  // Returns: Parsed response with text and optional token metadata.
  // Throws: TokenParsingError if JSON is malformed.
  func parseResponse(data: Data) throws -> FirebaseTokenResponse

  // Parses a single SSE chunk from streamMessage endpoint.
  // jsonString: The data portion of an SSE event (after "data: ").
  // Returns: Parsed chunk with text, completion signal, or error.
  // Throws: TokenParsingError if JSON is malformed.
  func parseStreamChunk(jsonString: String) throws -> FirebaseStreamChunk

  // Extracts token metadata from accumulated stream data.
  // Used when token metadata was sent across multiple chunks.
  // chunks: All parsed chunks from the stream.
  // Returns: Token metadata if available, nil otherwise.
  func extractTokenMetadata(from chunks: [FirebaseStreamChunk]) -> FirebaseStreamTokenMetadata?
}

/*
 ACCEPTANCE CRITERIA: TokenResponseParserProtocol.parseResponse()

 SCENARIO: Parse valid response with token metadata
 GIVEN: Valid JSON with response and tokenMetadata fields
 WHEN: parseResponse(data:) is called
 THEN: Returns FirebaseTokenResponse with all fields populated
  AND: No error is thrown

 SCENARIO: Parse response with missing tokenMetadata
 GIVEN: Valid JSON with response but no tokenMetadata field
 WHEN: parseResponse(data:) is called
 THEN: Returns FirebaseTokenResponse with response text
  AND: tokenMetadata is nil
  AND: No error is thrown

 SCENARIO: Parse invalid JSON
 GIVEN: Malformed JSON data
 WHEN: parseResponse(data:) is called
 THEN: Throws TokenParsingError.invalidJSON

 SCENARIO: Parse response missing required response field
 GIVEN: Valid JSON without "response" field
 WHEN: parseResponse(data:) is called
 THEN: Throws TokenParsingError.missingResponseField

 EDGE CASE: Parse empty data
 GIVEN: Empty Data
 WHEN: parseResponse(data:) is called
 THEN: Throws TokenParsingError.invalidJSON
*/

/*
 ACCEPTANCE CRITERIA: TokenResponseParserProtocol.parseStreamChunk()

 SCENARIO: Parse text chunk
 GIVEN: JSON string {"text": "Hello world"}
 WHEN: parseStreamChunk(jsonString:) is called
 THEN: Returns chunk with text "Hello world"

 SCENARIO: Parse completion chunk
 GIVEN: JSON string {"done": true, "tokenMetadata": {...}}
 WHEN: parseStreamChunk(jsonString:) is called
 THEN: Returns chunk with done true and tokenMetadata populated

 SCENARIO: Parse empty JSON string
 GIVEN: Empty string ""
 WHEN: parseStreamChunk(jsonString:) is called
 THEN: Throws TokenParsingError.invalidJSON

 SCENARIO: Parse whitespace-only string
 GIVEN: String "   "
 WHEN: parseStreamChunk(jsonString:) is called
 THEN: Throws TokenParsingError.invalidJSON

 EDGE CASE: Parse chunk with unknown fields
 GIVEN: JSON string {"text": "Hi", "unknownField": 123}
 WHEN: parseStreamChunk(jsonString:) is called
 THEN: Returns chunk with text "Hi"
  AND: Unknown fields are ignored
*/

/*
 ACCEPTANCE CRITERIA: TokenResponseParserProtocol.extractTokenMetadata()

 SCENARIO: Extract from chunks with final metadata
 GIVEN: Array of chunks where last chunk has tokenMetadata
 WHEN: extractTokenMetadata(from:) is called
 THEN: Returns the tokenMetadata from the final chunk

 SCENARIO: Extract from chunks without metadata
 GIVEN: Array of text-only chunks
 WHEN: extractTokenMetadata(from:) is called
 THEN: Returns nil

 SCENARIO: Extract from empty chunks array
 GIVEN: Empty array
 WHEN: extractTokenMetadata(from:) is called
 THEN: Returns nil
*/

// MARK: - TokenMetadataConverterProtocol

// Protocol for converting Firebase token metadata to ChatMessage TokenMetadata.
// Bridges the Firebase response format to the app's internal format.
protocol TokenMetadataConverterProtocol: Sendable {
  // Converts non-streaming response metadata to ChatMessage TokenMetadata.
  // response: The parsed Firebase response.
  // Returns: TokenMetadata for attaching to ChatMessage, nil if not available.
  func convert(from response: FirebaseTokenResponse) -> TokenMetadata?

  // Converts streaming response metadata to ChatMessage TokenMetadata.
  // streamMetadata: Token metadata from streaming response.
  // Returns: TokenMetadata for attaching to ChatMessage.
  func convert(from streamMetadata: FirebaseStreamTokenMetadata) -> TokenMetadata

  // Creates estimated TokenMetadata when Firebase metadata is unavailable.
  // Uses client-side character-based estimation as fallback.
  // inputContent: The full input text sent to the API.
  // outputContent: The response text from the API.
  // messagesIncluded: Number of messages in the request.
  // Returns: Estimated TokenMetadata using charsPerToken heuristic.
  func createEstimatedMetadata(
    inputContent: String,
    outputContent: String,
    messagesIncluded: Int
  ) -> TokenMetadata
}

/*
 ACCEPTANCE CRITERIA: TokenMetadataConverterProtocol.convert(from response:)

 SCENARIO: Convert complete Firebase response metadata
 GIVEN: FirebaseTokenResponse with tokenMetadata populated
 WHEN: convert(from response:) is called
 THEN: Returns TokenMetadata with:
  - inputTokens = promptTokenCount
  - outputTokens = candidatesTokenCount
  - totalTokens = totalTokenCount
  - contextTruncated = historyTruncated
  - messagesIncluded = messagesIncluded

 SCENARIO: Convert response with nil tokenMetadata
 GIVEN: FirebaseTokenResponse with tokenMetadata nil
 WHEN: convert(from response:) is called
 THEN: Returns nil
  AND: Caller should use createEstimatedMetadata as fallback

 SCENARIO: Convert response with partial data
 GIVEN: FirebaseTokenResponse with tokenMetadata but nil historyTruncated
 WHEN: convert(from response:) is called
 THEN: Returns TokenMetadata with contextTruncated = false (default)
*/

/*
 ACCEPTANCE CRITERIA: TokenMetadataConverterProtocol.convert(from streamMetadata:)

 SCENARIO: Convert streaming metadata
 GIVEN: FirebaseStreamTokenMetadata with all fields
 WHEN: convert(from streamMetadata:) is called
 THEN: Returns TokenMetadata with all fields mapped correctly

 SCENARIO: Verify field mapping
 GIVEN: FirebaseStreamTokenMetadata with promptTokenCount=1000, candidatesTokenCount=500
 WHEN: convert(from streamMetadata:) is called
 THEN: Returns TokenMetadata with inputTokens=1000, outputTokens=500, totalTokens=1500
*/

/*
 ACCEPTANCE CRITERIA: TokenMetadataConverterProtocol.createEstimatedMetadata()

 SCENARIO: Create estimated metadata for typical request
 GIVEN: inputContent of 4000 characters, outputContent of 1000 characters
 WHEN: createEstimatedMetadata is called
 THEN: Returns TokenMetadata with:
  - inputTokens = ceil(4000 / 4.0) = 1000
  - outputTokens = ceil(1000 / 4.0) = 250
  - totalTokens = 1250
  - contextTruncated = false (estimation cannot determine this)
  - messagesIncluded = provided value

 SCENARIO: Create estimated metadata for empty content
 GIVEN: Empty inputContent and empty outputContent
 WHEN: createEstimatedMetadata is called
 THEN: Returns TokenMetadata with inputTokens=0, outputTokens=0, totalTokens=0
*/

// MARK: - Error Definitions

// Errors that can occur during token metadata parsing.
// Provides specific error cases for debugging and error handling.
enum TokenParsingError: Error, LocalizedError, Equatable {
  // JSON data could not be parsed.
  case invalidJSON(reason: String)

  // Required "response" field is missing from the response.
  case missingResponseField

  // Token count values are negative or invalid.
  case invalidTokenCount(field: String, value: Int)

  // Stream chunk format is unexpected.
  case invalidStreamChunk(reason: String)

  // UTF-8 decoding failed.
  case encodingError

  var errorDescription: String? {
    switch self {
    case .invalidJSON(let reason):
      return "Invalid JSON in Firebase response: \(reason)"
    case .missingResponseField:
      return "Firebase response missing required 'response' field"
    case .invalidTokenCount(let field, let value):
      return "Invalid token count for '\(field)': \(value)"
    case .invalidStreamChunk(let reason):
      return "Invalid stream chunk: \(reason)"
    case .encodingError:
      return "Failed to decode UTF-8 data"
    }
  }
}

/*
 EDGE CASE: Negative token counts
 GIVEN: Firebase response with promptTokenCount: -1
 WHEN: Parsed
 THEN: Implementation should either:
  - Throw TokenParsingError.invalidTokenCount, OR
  - Treat negative values as 0 (defensive)
  AND: Behavior is documented and consistent

 EDGE CASE: Integer overflow in token counts
 GIVEN: Firebase response with extremely large token count
 WHEN: Parsed
 THEN: Swift Int handles values up to 2^63-1
  AND: No overflow occurs for realistic token counts

 EDGE CASE: Floating point token counts in JSON
 GIVEN: Firebase response with "promptTokenCount": 1000.5
 WHEN: Decoded to Int
 THEN: Decoding may fail or truncate
  AND: Behavior depends on JSONDecoder configuration
*/

// MARK: - Error Definitions for Token Limit Exceeded

// Errors specific to token limit scenarios.
// Used when the Firebase backend rejects a request due to token limits.
enum TokenLimitError: Error, LocalizedError, Equatable {
  // A single message exceeded Gemini's maximum context window.
  // The message alone is too large, even without history.
  case messageTooLarge(tokenCount: Int, maxTokens: Int)

  // The request exceeded Gemini's maximum context window.
  // Includes the token count that was attempted.
  case contextWindowExceeded(requestedTokens: Int, maxTokens: Int)

  // The message history exceeded the allocated history budget.
  case historyBudgetExceeded(requestedTokens: Int, budgetTokens: Int)

  // The document context exceeded the allocated context budget.
  case contextBudgetExceeded(requestedTokens: Int, budgetTokens: Int)

  var errorDescription: String? {
    switch self {
    case .messageTooLarge(let tokens, let max):
      return "Message is too large: \(tokens) tokens, maximum is \(max). Please reduce the amount of context or split into multiple messages."
    case .contextWindowExceeded(let requested, let max):
      return "Request exceeded context window: \(requested) tokens requested, maximum is \(max)"
    case .historyBudgetExceeded(let requested, let budget):
      return "Conversation history too long: \(requested) tokens, budget is \(budget)"
    case .contextBudgetExceeded(let requested, let budget):
      return "Document context too large: \(requested) tokens, budget is \(budget)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: Token Limit Error Handling

 SCENARIO: Context window exceeded
 GIVEN: A request with 1,100,000 tokens (exceeds 1,048,576 max)
 WHEN: Firebase backend returns error
 THEN: Client receives ChatError.requestFailed with status 400
  AND: Error details indicate token limit exceeded
  AND: Client can extract token counts from error response

 SCENARIO: Backend truncates to fit
 GIVEN: A request that would exceed limits
 WHEN: Firebase backend truncates and succeeds
 THEN: Response includes historyTruncated = true
  AND: messagesIncluded shows reduced message count
  AND: Client can inform user of truncation

 SCENARIO: Graceful degradation
 GIVEN: Token counting API unavailable
 WHEN: Firebase backend cannot count tokens
 THEN: Backend should fall back to estimation
  AND: Response may not include tokenMetadata
  AND: Client uses createEstimatedMetadata
*/

// MARK: - Firebase Error Response

// Represents an error response from Firebase that may include token information.
// Used when the request failed due to token limits.
struct FirebaseErrorResponse: Sendable, Codable, Equatable {
  // Error message from the backend.
  let error: String

  // Detailed error information.
  let details: String?

  // Token count that caused the error (if applicable).
  let tokenCount: Int?

  // Maximum allowed token count (if applicable).
  let maxTokens: Int?

  // Specific error code for programmatic handling.
  let errorCode: String?
}

/*
 ACCEPTANCE CRITERIA: FirebaseErrorResponse Parsing

 SCENARIO: Parse token limit error
 GIVEN: Error response with tokenCount and maxTokens
 WHEN: Decoded to FirebaseErrorResponse
 THEN: All fields are populated
  AND: Client can create TokenLimitError.contextWindowExceeded

 SCENARIO: Parse generic error
 GIVEN: Error response without token information
 WHEN: Decoded to FirebaseErrorResponse
 THEN: error contains the message
  AND: tokenCount and maxTokens are nil

 SCENARIO: Parse error with details
 GIVEN: Error response {"error": "Failed", "details": "API key invalid"}
 WHEN: Decoded to FirebaseErrorResponse
 THEN: error is "Failed"
  AND: details is "API key invalid"
*/

// MARK: - Constants

// Constants for Firebase token counting configuration.
enum FirebaseTokenConstants {
  // Error code for single message too large.
  static let messageTooLargeCode = "MESSAGE_TOO_LARGE"

  // Error code for token limit exceeded.
  static let tokenLimitErrorCode = "TOKEN_LIMIT_EXCEEDED"

  // Error code for truncation occurred.
  static let historyTruncatedCode = "HISTORY_TRUNCATED"

  // JSON key for token metadata in responses.
  static let tokenMetadataKey = "tokenMetadata"

  // JSON key for history truncation flag.
  static let historyTruncatedKey = "historyTruncated"

  // JSON key for messages included count.
  static let messagesIncludedKey = "messagesIncluded"
}

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Response with tokenMetadata but missing fields
 GIVEN: Firebase response {"response": "Hi", "tokenMetadata": {"promptTokenCount": 100}}
  AND: candidatesTokenCount and totalTokenCount are missing
 WHEN: Decoded to FirebaseTokenResponse
 THEN: Decoding fails or uses default values
  AND: Implementation defines clear behavior

 EDGE CASE: Streaming response ends without done signal
 GIVEN: A streaming response that terminates unexpectedly
 WHEN: Client attempts to extract token metadata
 THEN: extractTokenMetadata returns nil
  AND: Client falls back to estimation

 EDGE CASE: Streaming response with multiple tokenMetadata chunks
 GIVEN: Multiple chunks contain tokenMetadata (server error)
 WHEN: extractTokenMetadata is called
 THEN: Returns the last tokenMetadata received
  AND: Logs warning about multiple metadata chunks

 EDGE CASE: Very large token counts near Int.max
 GIVEN: tokenMetadata with counts near Int.max
 WHEN: Totals are calculated
 THEN: No integer overflow occurs
  AND: Values are handled correctly

 EDGE CASE: Response with null vs missing fields
 GIVEN: JSON with "tokenMetadata": null
 WHEN: Decoded
 THEN: tokenMetadata is nil (not error)
  AND: Distinguishes between null and missing

 EDGE CASE: Concurrent parsing of multiple responses
 GIVEN: Multiple responses being parsed simultaneously
 WHEN: TokenResponseParser is used from multiple tasks
 THEN: Parsing is thread-safe (struct-based, no shared state)
  AND: No data races occur

 EDGE CASE: Malformed UTF-8 in JSON
 GIVEN: Response data with invalid UTF-8 bytes
 WHEN: Parsing is attempted
 THEN: Throws TokenParsingError.encodingError
  AND: Error message is helpful for debugging

 EDGE CASE: JSON with duplicate keys
 GIVEN: JSON with {"response": "first", "response": "second"}
 WHEN: Decoded
 THEN: Behavior follows JSONDecoder default (last value wins)
  AND: No error is thrown

 EDGE CASE: Token metadata with string values instead of integers
 GIVEN: JSON with "promptTokenCount": "1000" (string instead of int)
 WHEN: Decoded to FirebaseResponseTokenMetadata
 THEN: Decoding fails (type mismatch)
  AND: Error indicates the parsing failure

 EDGE CASE: Extremely long response text
 GIVEN: Response with 10MB of text content
 WHEN: Parsed
 THEN: Parsing completes (may be slow)
  AND: No memory issues with reasonable hardware
*/

// MARK: - Integration Points

/*
 INTEGRATION: FirebaseChatClient
 TokenResponseParser integrates with FirebaseChatClient:
 - parseResponse() called in sendMessage() after receiving HTTP response
 - parseStreamChunk() called for each SSE event in streamMessage()
 - TokenMetadata attached to ChatMessage after parsing

 INTEGRATION: ChatService
 ChatService uses TokenMetadataConverter:
 - Converts Firebase metadata to TokenMetadata for ChatMessage
 - Falls back to estimation when Firebase metadata unavailable
 - Tracks truncation status for UI feedback

 INTEGRATION: ChatMessage
 Parsed token metadata attaches to ChatMessage:
 - User message: inputTokens from prompt, outputTokens nil
 - Assistant message: full TokenMetadata with both counts

 INTEGRATION: UI Layer
 Token information can be displayed to users:
 - "Using X tokens" indicator
 - Warning when approaching limits
 - Notification when history was truncated
*/

// MARK: - Expected Firebase Response Format

/*
 EXPECTED FORMAT: sendMessage Response

 Success with token metadata:
 {
   "response": "The AI response text...",
   "tokenMetadata": {
     "promptTokenCount": 1500,
     "candidatesTokenCount": 350,
     "totalTokenCount": 1850
   },
   "historyTruncated": false,
   "messagesIncluded": 10
 }

 Success without token metadata (fallback):
 {
   "response": "The AI response text..."
 }

 Error with token information:
 {
   "error": "Request exceeds token limit",
   "errorCode": "TOKEN_LIMIT_EXCEEDED",
   "tokenCount": 1100000,
   "maxTokens": 1048576
 }
*/

/*
 EXPECTED FORMAT: streamMessage SSE Events

 Text chunk:
 data: {"text": "Hello, "}

 More text:
 data: {"text": "how can I help?"}

 Completion with metadata:
 data: {"done": true, "tokenMetadata": {"promptTokenCount": 500, "candidatesTokenCount": 100, "totalTokenCount": 600, "historyTruncated": false, "messagesIncluded": 5}}

 Error during streaming:
 data: {"error": "Rate limit exceeded", "done": true}
*/

// MARK: - Implementation Notes

/*
 IMPLEMENTATION: TokenResponseParser

 The parser should be a simple struct with no stored state.
 All methods use JSONDecoder for parsing.
 Custom decoding logic may be needed for optional fields.

 Example implementation structure:

 struct TokenResponseParser: TokenResponseParserProtocol {
   private let decoder = JSONDecoder()

   func parseResponse(data: Data) throws -> FirebaseTokenResponse {
     do {
       return try decoder.decode(FirebaseTokenResponse.self, from: data)
     } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "response" {
       throw TokenParsingError.missingResponseField
     } catch {
       throw TokenParsingError.invalidJSON(reason: error.localizedDescription)
     }
   }

   // ... other methods
 }
*/

/*
 IMPLEMENTATION: TokenMetadataConverter

 The converter maps between Firebase and app formats.
 Should handle nil/missing values gracefully.

 Mapping:
 - promptTokenCount -> inputTokens
 - candidatesTokenCount -> outputTokens
 - totalTokenCount -> totalTokens
 - historyTruncated -> contextTruncated
 - messagesIncluded -> messagesIncluded
*/

/*
 IMPLEMENTATION: Fallback Estimation

 When Firebase does not return token metadata:
 1. Calculate inputTokens as ceil(inputContent.count / 4.0)
 2. Calculate outputTokens as ceil(outputContent.count / 4.0)
 3. Set contextTruncated = false (cannot determine without server info)
 4. Use provided messagesIncluded value

 This matches existing TokenEstimator behavior in the codebase.
*/

// MARK: - Testing Strategy

/*
 TESTING: Unit Tests for TokenResponseParser

 1. Parse valid responses with all fields
 2. Parse responses with missing optional fields
 3. Parse responses with null values
 4. Parse malformed JSON (various error conditions)
 5. Parse streaming chunks of different types
 6. Extract metadata from chunk arrays

 TESTING: Unit Tests for TokenMetadataConverter

 1. Convert complete Firebase metadata
 2. Convert streaming metadata
 3. Handle nil tokenMetadata gracefully
 4. Create estimated metadata with various inputs
 5. Verify token calculation matches TokenBudgetConstants.charsPerToken

 TESTING: Integration Tests

 1. End-to-end sendMessage with token metadata parsing
 2. End-to-end streamMessage with final metadata extraction
 3. Fallback to estimation when metadata missing
 4. Error handling for token limit exceeded responses

 TESTING: Mock Responses

 Create mock JSON responses for all scenarios:
 - Success with full metadata
 - Success without metadata
 - Token limit exceeded error
 - Malformed responses
 - Streaming chunks with various content
*/
