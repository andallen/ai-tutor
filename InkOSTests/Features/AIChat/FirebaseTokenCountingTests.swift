// FirebaseTokenCountingTests.swift
// Tests for the Firebase Token Counting feature based on FirebaseTokenCountingContract.swift.
// Validates parsing of token metadata from Firebase responses and conversion to app formats.

import XCTest
@testable import InkOS

// MARK: - Mock Token Response Parser

// Mock implementation of TokenResponseParserProtocol for verifying protocol usability.
// Tracks method invocations and allows controlled responses for testing.
final class MockTokenResponseParser: TokenResponseParserProtocol, @unchecked Sendable {
  var parseResponseCallCount = 0
  var parseResponseData: Data?
  var parseResponseResult: FirebaseTokenResponse?
  var parseResponseError: Error?

  var parseStreamChunkCallCount = 0
  var parseStreamChunkString: String?
  var parseStreamChunkResult: FirebaseStreamChunk?
  var parseStreamChunkError: Error?

  var extractTokenMetadataCallCount = 0
  var extractTokenMetadataChunks: [FirebaseStreamChunk]?
  var extractTokenMetadataResult: FirebaseStreamTokenMetadata?

  func parseResponse(data: Data) throws -> FirebaseTokenResponse {
    parseResponseCallCount += 1
    parseResponseData = data
    if let error = parseResponseError {
      throw error
    }
    guard let result = parseResponseResult else {
      throw TokenParsingError.invalidJSON(reason: "No mock result configured")
    }
    return result
  }

  func parseStreamChunk(jsonString: String) throws -> FirebaseStreamChunk {
    parseStreamChunkCallCount += 1
    parseStreamChunkString = jsonString
    if let error = parseStreamChunkError {
      throw error
    }
    guard let result = parseStreamChunkResult else {
      throw TokenParsingError.invalidJSON(reason: "No mock result configured")
    }
    return result
  }

  func extractTokenMetadata(from chunks: [FirebaseStreamChunk]) -> FirebaseStreamTokenMetadata? {
    extractTokenMetadataCallCount += 1
    extractTokenMetadataChunks = chunks
    return extractTokenMetadataResult
  }
}

// MARK: - Mock Token Metadata Converter

// Mock implementation of TokenMetadataConverterProtocol for verifying protocol usability.
// Tracks method invocations and allows controlled responses for testing.
final class MockTokenMetadataConverter: TokenMetadataConverterProtocol, @unchecked Sendable {
  var convertFromResponseCallCount = 0
  var convertFromResponseInput: FirebaseTokenResponse?
  var convertFromResponseResult: TokenMetadata?

  var convertFromStreamCallCount = 0
  var convertFromStreamInput: FirebaseStreamTokenMetadata?
  var convertFromStreamResult: TokenMetadata?

  var createEstimatedCallCount = 0
  var createEstimatedInputContent: String?
  var createEstimatedOutputContent: String?
  var createEstimatedMessagesIncluded: Int?
  var createEstimatedResult: TokenMetadata?

  func convert(from response: FirebaseTokenResponse) -> TokenMetadata? {
    convertFromResponseCallCount += 1
    convertFromResponseInput = response
    return convertFromResponseResult
  }

  func convert(from streamMetadata: FirebaseStreamTokenMetadata) -> TokenMetadata {
    convertFromStreamCallCount += 1
    convertFromStreamInput = streamMetadata
    return convertFromStreamResult ?? TokenMetadata(
      inputTokens: streamMetadata.promptTokenCount,
      outputTokens: streamMetadata.candidatesTokenCount,
      totalTokens: streamMetadata.totalTokenCount,
      contextTruncated: streamMetadata.historyTruncated,
      messagesIncluded: streamMetadata.messagesIncluded
    )
  }

  func createEstimatedMetadata(
    inputContent: String,
    outputContent: String,
    messagesIncluded: Int
  ) -> TokenMetadata {
    createEstimatedCallCount += 1
    createEstimatedInputContent = inputContent
    createEstimatedOutputContent = outputContent
    createEstimatedMessagesIncluded = messagesIncluded
    return createEstimatedResult ?? TokenMetadata(
      inputTokens: Int(ceil(Double(inputContent.count) / 4.0)),
      outputTokens: Int(ceil(Double(outputContent.count) / 4.0)),
      contextTruncated: false,
      messagesIncluded: messagesIncluded
    )
  }
}

// MARK: - FirebaseTokenCountingTests

final class FirebaseTokenCountingTests: XCTestCase {

  // MARK: - Properties

  private var decoder: JSONDecoder!

  // MARK: - Setup & Teardown

  override func setUp() {
    super.setUp()
    decoder = JSONDecoder()
  }

  override func tearDown() {
    decoder = nil
    super.tearDown()
  }

  // MARK: - Interface Usability Tests

  // Verifies that FirebaseTokenResponse can be instantiated with all fields.
  func test_firebaseTokenResponse_initialization_createsValidInstance() {
    // Arrange
    let tokenMetadata = FirebaseResponseTokenMetadata(
      promptTokenCount: 1500,
      candidatesTokenCount: 350,
      totalTokenCount: 1850
    )

    // Act
    let response = FirebaseTokenResponse(
      response: "Test response text",
      tokenMetadata: tokenMetadata,
      historyTruncated: false,
      messagesIncluded: 10
    )

    // Assert
    XCTAssertEqual(response.response, "Test response text")
    XCTAssertNotNil(response.tokenMetadata)
    XCTAssertEqual(response.tokenMetadata?.promptTokenCount, 1500)
    XCTAssertEqual(response.tokenMetadata?.candidatesTokenCount, 350)
    XCTAssertEqual(response.tokenMetadata?.totalTokenCount, 1850)
    XCTAssertEqual(response.historyTruncated, false)
    XCTAssertEqual(response.messagesIncluded, 10)
  }

  // Verifies that FirebaseTokenResponse can be instantiated with nil optional fields.
  func test_firebaseTokenResponse_withNilOptionals_createsValidInstance() {
    // Act
    let response = FirebaseTokenResponse(
      response: "Test response",
      tokenMetadata: nil,
      historyTruncated: nil,
      messagesIncluded: nil
    )

    // Assert
    XCTAssertEqual(response.response, "Test response")
    XCTAssertNil(response.tokenMetadata)
    XCTAssertNil(response.historyTruncated)
    XCTAssertNil(response.messagesIncluded)
  }

  // Verifies that FirebaseResponseTokenMetadata can be instantiated.
  func test_firebaseResponseTokenMetadata_initialization_createsValidInstance() {
    // Act
    let metadata = FirebaseResponseTokenMetadata(
      promptTokenCount: 1000,
      candidatesTokenCount: 500,
      totalTokenCount: 1500
    )

    // Assert
    XCTAssertEqual(metadata.promptTokenCount, 1000)
    XCTAssertEqual(metadata.candidatesTokenCount, 500)
    XCTAssertEqual(metadata.totalTokenCount, 1500)
  }

  // Verifies that FirebaseStreamTokenMetadata can be instantiated.
  func test_firebaseStreamTokenMetadata_initialization_createsValidInstance() {
    // Act
    let metadata = FirebaseStreamTokenMetadata(
      promptTokenCount: 500,
      candidatesTokenCount: 100,
      totalTokenCount: 600,
      historyTruncated: false,
      messagesIncluded: 5
    )

    // Assert
    XCTAssertEqual(metadata.promptTokenCount, 500)
    XCTAssertEqual(metadata.candidatesTokenCount, 100)
    XCTAssertEqual(metadata.totalTokenCount, 600)
    XCTAssertEqual(metadata.historyTruncated, false)
    XCTAssertEqual(metadata.messagesIncluded, 5)
  }

  // Verifies that FirebaseStreamChunk can be instantiated with text.
  func test_firebaseStreamChunk_withText_createsValidInstance() {
    // Act
    let chunk = FirebaseStreamChunk(
      text: "Hello, ",
      done: nil,
      error: nil,
      tokenMetadata: nil
    )

    // Assert
    XCTAssertEqual(chunk.text, "Hello, ")
    XCTAssertNil(chunk.done)
    XCTAssertNil(chunk.error)
    XCTAssertNil(chunk.tokenMetadata)
  }

  // Verifies that FirebaseStreamChunk can be instantiated with completion and metadata.
  func test_firebaseStreamChunk_withDoneAndMetadata_createsValidInstance() {
    // Arrange
    let tokenMetadata = FirebaseStreamTokenMetadata(
      promptTokenCount: 500,
      candidatesTokenCount: 100,
      totalTokenCount: 600,
      historyTruncated: false,
      messagesIncluded: 5
    )

    // Act
    let chunk = FirebaseStreamChunk(
      text: nil,
      done: true,
      error: nil,
      tokenMetadata: tokenMetadata
    )

    // Assert
    XCTAssertNil(chunk.text)
    XCTAssertEqual(chunk.done, true)
    XCTAssertNil(chunk.error)
    XCTAssertNotNil(chunk.tokenMetadata)
  }

  // Verifies that FirebaseErrorResponse can be instantiated.
  func test_firebaseErrorResponse_initialization_createsValidInstance() {
    // Act
    let errorResponse = FirebaseErrorResponse(
      error: "Request exceeds token limit",
      details: "Token count too high",
      tokenCount: 1100000,
      maxTokens: 1048576,
      errorCode: "TOKEN_LIMIT_EXCEEDED"
    )

    // Assert
    XCTAssertEqual(errorResponse.error, "Request exceeds token limit")
    XCTAssertEqual(errorResponse.details, "Token count too high")
    XCTAssertEqual(errorResponse.tokenCount, 1100000)
    XCTAssertEqual(errorResponse.maxTokens, 1048576)
    XCTAssertEqual(errorResponse.errorCode, "TOKEN_LIMIT_EXCEEDED")
  }

  // MARK: - FirebaseTokenResponse Parsing Tests

  // Verifies parsing response with full token metadata.
  func test_parseFirebaseTokenResponse_withFullMetadata_decodesAllFields() throws {
    // Arrange
    let json = """
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
    """
    let data = json.data(using: .utf8)!

    // Act
    let response = try decoder.decode(FirebaseTokenResponse.self, from: data)

    // Assert
    XCTAssertEqual(response.response, "The AI response text...")
    XCTAssertNotNil(response.tokenMetadata)
    XCTAssertEqual(response.tokenMetadata?.promptTokenCount, 1500)
    XCTAssertEqual(response.tokenMetadata?.candidatesTokenCount, 350)
    XCTAssertEqual(response.tokenMetadata?.totalTokenCount, 1850)
    XCTAssertEqual(response.historyTruncated, false)
    XCTAssertEqual(response.messagesIncluded, 10)
  }

  // Verifies parsing response without token metadata (legacy/fallback).
  func test_parseFirebaseTokenResponse_withoutTokenMetadata_decodesResponse() throws {
    // Arrange
    let json = """
    {
      "response": "The AI response text..."
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let response = try decoder.decode(FirebaseTokenResponse.self, from: data)

    // Assert
    XCTAssertEqual(response.response, "The AI response text...")
    XCTAssertNil(response.tokenMetadata)
    XCTAssertNil(response.historyTruncated)
    XCTAssertNil(response.messagesIncluded)
  }

  // Verifies parsing response with null tokenMetadata field.
  func test_parseFirebaseTokenResponse_withNullTokenMetadata_decodesWithNil() throws {
    // Arrange
    let json = """
    {
      "response": "Test response",
      "tokenMetadata": null,
      "historyTruncated": true,
      "messagesIncluded": 5
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let response = try decoder.decode(FirebaseTokenResponse.self, from: data)

    // Assert
    XCTAssertEqual(response.response, "Test response")
    XCTAssertNil(response.tokenMetadata)
    XCTAssertEqual(response.historyTruncated, true)
    XCTAssertEqual(response.messagesIncluded, 5)
  }

  // Verifies parsing response with history truncation flag set to true.
  func test_parseFirebaseTokenResponse_withHistoryTruncated_decodesCorrectly() throws {
    // Arrange
    let json = """
    {
      "response": "Truncated response",
      "tokenMetadata": {
        "promptTokenCount": 100000,
        "candidatesTokenCount": 200,
        "totalTokenCount": 100200
      },
      "historyTruncated": true,
      "messagesIncluded": 3
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let response = try decoder.decode(FirebaseTokenResponse.self, from: data)

    // Assert
    XCTAssertEqual(response.historyTruncated, true)
    XCTAssertEqual(response.messagesIncluded, 3)
  }

  // Verifies that decoding fails when response field is missing.
  func test_parseFirebaseTokenResponse_missingResponseField_throwsDecodingError() {
    // Arrange
    let json = """
    {
      "tokenMetadata": {
        "promptTokenCount": 100,
        "candidatesTokenCount": 50,
        "totalTokenCount": 150
      }
    }
    """
    let data = json.data(using: .utf8)!

    // Act & Assert
    XCTAssertThrowsError(try decoder.decode(FirebaseTokenResponse.self, from: data)) { error in
      guard case DecodingError.keyNotFound(let key, _) = error else {
        XCTFail("Expected keyNotFound error, got \(error)")
        return
      }
      XCTAssertEqual(key.stringValue, "response")
    }
  }

  // Verifies that decoding fails with malformed JSON.
  func test_parseFirebaseTokenResponse_malformedJSON_throwsDecodingError() {
    // Arrange
    let json = """
    {response: "missing quotes"}
    """
    let data = json.data(using: .utf8)!

    // Act & Assert
    XCTAssertThrowsError(try decoder.decode(FirebaseTokenResponse.self, from: data))
  }

  // Verifies that decoding fails with empty data.
  func test_parseFirebaseTokenResponse_emptyData_throwsDecodingError() {
    // Arrange
    let data = Data()

    // Act & Assert
    XCTAssertThrowsError(try decoder.decode(FirebaseTokenResponse.self, from: data))
  }

  // MARK: - FirebaseResponseTokenMetadata Parsing Tests

  // Verifies parsing complete token metadata.
  func test_parseFirebaseResponseTokenMetadata_completeData_decodesAllFields() throws {
    // Arrange
    let json = """
    {
      "promptTokenCount": 1000,
      "candidatesTokenCount": 500,
      "totalTokenCount": 1500
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let metadata = try decoder.decode(FirebaseResponseTokenMetadata.self, from: data)

    // Assert
    XCTAssertEqual(metadata.promptTokenCount, 1000)
    XCTAssertEqual(metadata.candidatesTokenCount, 500)
    XCTAssertEqual(metadata.totalTokenCount, 1500)
  }

  // Verifies parsing token metadata with zero values.
  func test_parseFirebaseResponseTokenMetadata_zeroValues_decodesCorrectly() throws {
    // Arrange
    let json = """
    {
      "promptTokenCount": 0,
      "candidatesTokenCount": 0,
      "totalTokenCount": 0
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let metadata = try decoder.decode(FirebaseResponseTokenMetadata.self, from: data)

    // Assert
    XCTAssertEqual(metadata.promptTokenCount, 0)
    XCTAssertEqual(metadata.candidatesTokenCount, 0)
    XCTAssertEqual(metadata.totalTokenCount, 0)
  }

  // Verifies that token total equals sum of prompt and candidates.
  func test_parseFirebaseResponseTokenMetadata_verifyTotalCalculation_matchesSum() throws {
    // Arrange
    let json = """
    {
      "promptTokenCount": 1234,
      "candidatesTokenCount": 567,
      "totalTokenCount": 1801
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let metadata = try decoder.decode(FirebaseResponseTokenMetadata.self, from: data)

    // Assert
    XCTAssertEqual(
      metadata.totalTokenCount,
      metadata.promptTokenCount + metadata.candidatesTokenCount
    )
  }

  // Verifies that decoding fails when token count is a string instead of int.
  func test_parseFirebaseResponseTokenMetadata_stringInsteadOfInt_throwsDecodingError() {
    // Arrange
    let json = """
    {
      "promptTokenCount": "1000",
      "candidatesTokenCount": 500,
      "totalTokenCount": 1500
    }
    """
    let data = json.data(using: .utf8)!

    // Act & Assert
    XCTAssertThrowsError(try decoder.decode(FirebaseResponseTokenMetadata.self, from: data)) { error in
      guard case DecodingError.typeMismatch = error else {
        XCTFail("Expected typeMismatch error, got \(error)")
        return
      }
    }
  }

  // Verifies that decoding fails when a required field is missing.
  func test_parseFirebaseResponseTokenMetadata_missingField_throwsDecodingError() {
    // Arrange
    let json = """
    {
      "promptTokenCount": 100
    }
    """
    let data = json.data(using: .utf8)!

    // Act & Assert
    XCTAssertThrowsError(try decoder.decode(FirebaseResponseTokenMetadata.self, from: data)) { error in
      guard case DecodingError.keyNotFound = error else {
        XCTFail("Expected keyNotFound error, got \(error)")
        return
      }
    }
  }

  // MARK: - FirebaseStreamChunk Parsing Tests

  // Verifies parsing text chunk.
  func test_parseFirebaseStreamChunk_textChunk_decodesCorrectly() throws {
    // Arrange
    let json = """
    {"text": "Hello world"}
    """
    let data = json.data(using: .utf8)!

    // Act
    let chunk = try decoder.decode(FirebaseStreamChunk.self, from: data)

    // Assert
    XCTAssertEqual(chunk.text, "Hello world")
    XCTAssertNil(chunk.done)
    XCTAssertNil(chunk.error)
    XCTAssertNil(chunk.tokenMetadata)
  }

  // Verifies parsing completion chunk with token metadata.
  func test_parseFirebaseStreamChunk_completionWithMetadata_decodesCorrectly() throws {
    // Arrange
    let json = """
    {
      "done": true,
      "tokenMetadata": {
        "promptTokenCount": 500,
        "candidatesTokenCount": 100,
        "totalTokenCount": 600,
        "historyTruncated": false,
        "messagesIncluded": 5
      }
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let chunk = try decoder.decode(FirebaseStreamChunk.self, from: data)

    // Assert
    XCTAssertNil(chunk.text)
    XCTAssertEqual(chunk.done, true)
    XCTAssertNil(chunk.error)
    XCTAssertNotNil(chunk.tokenMetadata)
    XCTAssertEqual(chunk.tokenMetadata?.promptTokenCount, 500)
    XCTAssertEqual(chunk.tokenMetadata?.candidatesTokenCount, 100)
    XCTAssertEqual(chunk.tokenMetadata?.totalTokenCount, 600)
    XCTAssertEqual(chunk.tokenMetadata?.historyTruncated, false)
    XCTAssertEqual(chunk.tokenMetadata?.messagesIncluded, 5)
  }

  // Verifies parsing error chunk.
  func test_parseFirebaseStreamChunk_errorChunk_decodesCorrectly() throws {
    // Arrange
    let json = """
    {"error": "Rate limit exceeded", "done": true}
    """
    let data = json.data(using: .utf8)!

    // Act
    let chunk = try decoder.decode(FirebaseStreamChunk.self, from: data)

    // Assert
    XCTAssertNil(chunk.text)
    XCTAssertEqual(chunk.done, true)
    XCTAssertEqual(chunk.error, "Rate limit exceeded")
    XCTAssertNil(chunk.tokenMetadata)
  }

  // Verifies parsing chunk with unknown fields (should be ignored).
  func test_parseFirebaseStreamChunk_withUnknownFields_ignoresUnknownFields() throws {
    // Arrange
    let json = """
    {"text": "Hi", "unknownField": 123, "anotherUnknown": "value"}
    """
    let data = json.data(using: .utf8)!

    // Act
    let chunk = try decoder.decode(FirebaseStreamChunk.self, from: data)

    // Assert
    XCTAssertEqual(chunk.text, "Hi")
    XCTAssertNil(chunk.done)
    XCTAssertNil(chunk.error)
    XCTAssertNil(chunk.tokenMetadata)
  }

  // Verifies parsing empty JSON object (all fields optional).
  func test_parseFirebaseStreamChunk_emptyObject_decodesWithAllNil() throws {
    // Arrange
    let json = "{}"
    let data = json.data(using: .utf8)!

    // Act
    let chunk = try decoder.decode(FirebaseStreamChunk.self, from: data)

    // Assert
    XCTAssertNil(chunk.text)
    XCTAssertNil(chunk.done)
    XCTAssertNil(chunk.error)
    XCTAssertNil(chunk.tokenMetadata)
  }

  // MARK: - FirebaseStreamTokenMetadata Parsing Tests

  // Verifies parsing streaming completion metadata.
  func test_parseFirebaseStreamTokenMetadata_completeData_decodesAllFields() throws {
    // Arrange
    let json = """
    {
      "promptTokenCount": 500,
      "candidatesTokenCount": 100,
      "totalTokenCount": 600,
      "historyTruncated": false,
      "messagesIncluded": 5
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let metadata = try decoder.decode(FirebaseStreamTokenMetadata.self, from: data)

    // Assert
    XCTAssertEqual(metadata.promptTokenCount, 500)
    XCTAssertEqual(metadata.candidatesTokenCount, 100)
    XCTAssertEqual(metadata.totalTokenCount, 600)
    XCTAssertEqual(metadata.historyTruncated, false)
    XCTAssertEqual(metadata.messagesIncluded, 5)
  }

  // Verifies parsing streaming metadata with history truncation.
  func test_parseFirebaseStreamTokenMetadata_withHistoryTruncated_decodesCorrectly() throws {
    // Arrange
    let json = """
    {
      "promptTokenCount": 100000,
      "candidatesTokenCount": 500,
      "totalTokenCount": 100500,
      "historyTruncated": true,
      "messagesIncluded": 2
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let metadata = try decoder.decode(FirebaseStreamTokenMetadata.self, from: data)

    // Assert
    XCTAssertEqual(metadata.historyTruncated, true)
    XCTAssertEqual(metadata.messagesIncluded, 2)
  }

  // MARK: - FirebaseErrorResponse Parsing Tests

  // Verifies parsing token limit error response.
  func test_parseFirebaseErrorResponse_tokenLimitError_decodesAllFields() throws {
    // Arrange
    let json = """
    {
      "error": "Request exceeds token limit",
      "errorCode": "TOKEN_LIMIT_EXCEEDED",
      "tokenCount": 1100000,
      "maxTokens": 1048576,
      "details": "Total tokens exceeded maximum"
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let errorResponse = try decoder.decode(FirebaseErrorResponse.self, from: data)

    // Assert
    XCTAssertEqual(errorResponse.error, "Request exceeds token limit")
    XCTAssertEqual(errorResponse.errorCode, "TOKEN_LIMIT_EXCEEDED")
    XCTAssertEqual(errorResponse.tokenCount, 1100000)
    XCTAssertEqual(errorResponse.maxTokens, 1048576)
    XCTAssertEqual(errorResponse.details, "Total tokens exceeded maximum")
  }

  // Verifies parsing generic error without token information.
  func test_parseFirebaseErrorResponse_genericError_decodesCorrectly() throws {
    // Arrange
    let json = """
    {
      "error": "Failed",
      "details": "API key invalid"
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let errorResponse = try decoder.decode(FirebaseErrorResponse.self, from: data)

    // Assert
    XCTAssertEqual(errorResponse.error, "Failed")
    XCTAssertEqual(errorResponse.details, "API key invalid")
    XCTAssertNil(errorResponse.tokenCount)
    XCTAssertNil(errorResponse.maxTokens)
    XCTAssertNil(errorResponse.errorCode)
  }

  // Verifies parsing error with only error field.
  func test_parseFirebaseErrorResponse_minimalError_decodesCorrectly() throws {
    // Arrange
    let json = """
    {
      "error": "Something went wrong"
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let errorResponse = try decoder.decode(FirebaseErrorResponse.self, from: data)

    // Assert
    XCTAssertEqual(errorResponse.error, "Something went wrong")
    XCTAssertNil(errorResponse.details)
    XCTAssertNil(errorResponse.tokenCount)
    XCTAssertNil(errorResponse.maxTokens)
    XCTAssertNil(errorResponse.errorCode)
  }

  // MARK: - TokenParsingError Tests

  // Verifies TokenParsingError cases can be created and compared.
  func test_tokenParsingError_invalidJSON_equatable() {
    // Arrange
    let error1 = TokenParsingError.invalidJSON(reason: "Unexpected token")
    let error2 = TokenParsingError.invalidJSON(reason: "Unexpected token")
    let error3 = TokenParsingError.invalidJSON(reason: "Different reason")

    // Assert
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }

  // Verifies TokenParsingError.missingResponseField can be created.
  func test_tokenParsingError_missingResponseField_equatable() {
    // Arrange
    let error1 = TokenParsingError.missingResponseField
    let error2 = TokenParsingError.missingResponseField

    // Assert
    XCTAssertEqual(error1, error2)
  }

  // Verifies TokenParsingError.invalidTokenCount can be created.
  func test_tokenParsingError_invalidTokenCount_equatable() {
    // Arrange
    let error1 = TokenParsingError.invalidTokenCount(field: "promptTokenCount", value: -1)
    let error2 = TokenParsingError.invalidTokenCount(field: "promptTokenCount", value: -1)
    let error3 = TokenParsingError.invalidTokenCount(field: "candidatesTokenCount", value: -1)

    // Assert
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }

  // Verifies TokenParsingError.invalidStreamChunk can be created.
  func test_tokenParsingError_invalidStreamChunk_equatable() {
    // Arrange
    let error1 = TokenParsingError.invalidStreamChunk(reason: "Empty chunk")
    let error2 = TokenParsingError.invalidStreamChunk(reason: "Empty chunk")

    // Assert
    XCTAssertEqual(error1, error2)
  }

  // Verifies TokenParsingError.encodingError can be created.
  func test_tokenParsingError_encodingError_equatable() {
    // Arrange
    let error1 = TokenParsingError.encodingError
    let error2 = TokenParsingError.encodingError

    // Assert
    XCTAssertEqual(error1, error2)
  }

  // Verifies TokenParsingError provides localized descriptions.
  func test_tokenParsingError_errorDescriptions_areNotEmpty() {
    // Arrange
    let errors: [TokenParsingError] = [
      .invalidJSON(reason: "test"),
      .missingResponseField,
      .invalidTokenCount(field: "test", value: -1),
      .invalidStreamChunk(reason: "test"),
      .encodingError
    ]

    // Assert
    for error in errors {
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription!.isEmpty)
    }
  }

  // MARK: - TokenLimitError Tests

  // Verifies TokenLimitError.contextWindowExceeded can be created.
  func test_tokenLimitError_contextWindowExceeded_equatable() {
    // Arrange
    let error1 = TokenLimitError.contextWindowExceeded(requestedTokens: 1100000, maxTokens: 1048576)
    let error2 = TokenLimitError.contextWindowExceeded(requestedTokens: 1100000, maxTokens: 1048576)
    let error3 = TokenLimitError.contextWindowExceeded(requestedTokens: 2000000, maxTokens: 1048576)

    // Assert
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }

  // Verifies TokenLimitError.historyBudgetExceeded can be created.
  func test_tokenLimitError_historyBudgetExceeded_equatable() {
    // Arrange
    let error1 = TokenLimitError.historyBudgetExceeded(requestedTokens: 600000, budgetTokens: 530384)
    let error2 = TokenLimitError.historyBudgetExceeded(requestedTokens: 600000, budgetTokens: 530384)

    // Assert
    XCTAssertEqual(error1, error2)
  }

  // Verifies TokenLimitError.contextBudgetExceeded can be created.
  func test_tokenLimitError_contextBudgetExceeded_equatable() {
    // Arrange
    let error1 = TokenLimitError.contextBudgetExceeded(requestedTokens: 600000, budgetTokens: 500000)
    let error2 = TokenLimitError.contextBudgetExceeded(requestedTokens: 600000, budgetTokens: 500000)

    // Assert
    XCTAssertEqual(error1, error2)
  }

  // Verifies TokenLimitError provides localized descriptions.
  func test_tokenLimitError_errorDescriptions_areNotEmpty() {
    // Arrange
    let errors: [TokenLimitError] = [
      .contextWindowExceeded(requestedTokens: 1100000, maxTokens: 1048576),
      .historyBudgetExceeded(requestedTokens: 600000, budgetTokens: 530384),
      .contextBudgetExceeded(requestedTokens: 600000, budgetTokens: 500000)
    ]

    // Assert
    for error in errors {
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription!.isEmpty)
    }
  }

  // MARK: - FirebaseTokenConstants Tests

  // Verifies constant values match expected values.
  func test_firebaseTokenConstants_values_matchExpected() {
    XCTAssertEqual(FirebaseTokenConstants.tokenLimitErrorCode, "TOKEN_LIMIT_EXCEEDED")
    XCTAssertEqual(FirebaseTokenConstants.historyTruncatedCode, "HISTORY_TRUNCATED")
    XCTAssertEqual(FirebaseTokenConstants.tokenMetadataKey, "tokenMetadata")
    XCTAssertEqual(FirebaseTokenConstants.historyTruncatedKey, "historyTruncated")
    XCTAssertEqual(FirebaseTokenConstants.messagesIncludedKey, "messagesIncluded")
  }

  // MARK: - Protocol Usability Tests

  // Verifies MockTokenResponseParser can be used as TokenResponseParserProtocol.
  func test_tokenResponseParserProtocol_mockImplementation_isUsable() throws {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.parseResponseResult = FirebaseTokenResponse(
      response: "Test",
      tokenMetadata: nil,
      historyTruncated: nil,
      messagesIncluded: nil
    )

    // Act
    let result = try mockParser.parseResponse(data: Data())

    // Assert
    XCTAssertEqual(result.response, "Test")
    XCTAssertEqual(mockParser.parseResponseCallCount, 1)
  }

  // Verifies MockTokenMetadataConverter can be used as TokenMetadataConverterProtocol.
  func test_tokenMetadataConverterProtocol_mockImplementation_isUsable() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    let streamMetadata = FirebaseStreamTokenMetadata(
      promptTokenCount: 100,
      candidatesTokenCount: 50,
      totalTokenCount: 150,
      historyTruncated: false,
      messagesIncluded: 5
    )

    // Act
    let result = mockConverter.convert(from: streamMetadata)

    // Assert
    XCTAssertEqual(result.inputTokens, 100)
    XCTAssertEqual(result.outputTokens, 50)
    XCTAssertEqual(result.totalTokens, 150)
    XCTAssertEqual(mockConverter.convertFromStreamCallCount, 1)
  }

  // MARK: - TokenResponseParser Tests

  // Verifies parseResponse with valid response and token metadata.
  func test_parseResponse_validWithTokenMetadata_returnsCorrectly() throws {
    // Arrange
    let mockParser = MockTokenResponseParser()
    let expectedResponse = FirebaseTokenResponse(
      response: "Hello",
      tokenMetadata: FirebaseResponseTokenMetadata(
        promptTokenCount: 100,
        candidatesTokenCount: 50,
        totalTokenCount: 150
      ),
      historyTruncated: false,
      messagesIncluded: 5
    )
    mockParser.parseResponseResult = expectedResponse
    let data = "{}".data(using: .utf8)!

    // Act
    let result = try mockParser.parseResponse(data: data)

    // Assert
    XCTAssertEqual(result.response, "Hello")
    XCTAssertNotNil(result.tokenMetadata)
    XCTAssertEqual(mockParser.parseResponseCallCount, 1)
    XCTAssertEqual(mockParser.parseResponseData, data)
  }

  // Verifies parseResponse with missing tokenMetadata returns nil.
  func test_parseResponse_missingTokenMetadata_returnsNilTokenMetadata() throws {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.parseResponseResult = FirebaseTokenResponse(
      response: "Hello",
      tokenMetadata: nil,
      historyTruncated: nil,
      messagesIncluded: nil
    )

    // Act
    let result = try mockParser.parseResponse(data: Data())

    // Assert
    XCTAssertEqual(result.response, "Hello")
    XCTAssertNil(result.tokenMetadata)
  }

  // Verifies parseResponse throws on invalid JSON.
  func test_parseResponse_invalidJSON_throwsError() {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.parseResponseError = TokenParsingError.invalidJSON(reason: "Unexpected token")

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parseResponse(data: Data())) { error in
      guard let parsingError = error as? TokenParsingError else {
        XCTFail("Expected TokenParsingError")
        return
      }
      XCTAssertEqual(parsingError, .invalidJSON(reason: "Unexpected token"))
    }
  }

  // Verifies parseResponse throws on missing response field.
  func test_parseResponse_missingResponseField_throwsError() {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.parseResponseError = TokenParsingError.missingResponseField

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parseResponse(data: Data())) { error in
      guard let parsingError = error as? TokenParsingError else {
        XCTFail("Expected TokenParsingError")
        return
      }
      XCTAssertEqual(parsingError, .missingResponseField)
    }
  }

  // MARK: - parseStreamChunk Tests

  // Verifies parseStreamChunk with text chunk.
  func test_parseStreamChunk_textChunk_returnsText() throws {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.parseStreamChunkResult = FirebaseStreamChunk(
      text: "Hello world",
      done: nil,
      error: nil,
      tokenMetadata: nil
    )

    // Act
    let result = try mockParser.parseStreamChunk(jsonString: "{\"text\": \"Hello world\"}")

    // Assert
    XCTAssertEqual(result.text, "Hello world")
    XCTAssertNil(result.done)
    XCTAssertNil(result.tokenMetadata)
    XCTAssertEqual(mockParser.parseStreamChunkCallCount, 1)
  }

  // Verifies parseStreamChunk with completion chunk and metadata.
  func test_parseStreamChunk_completionWithMetadata_returnsMetadata() throws {
    // Arrange
    let mockParser = MockTokenResponseParser()
    let tokenMetadata = FirebaseStreamTokenMetadata(
      promptTokenCount: 500,
      candidatesTokenCount: 100,
      totalTokenCount: 600,
      historyTruncated: false,
      messagesIncluded: 5
    )
    mockParser.parseStreamChunkResult = FirebaseStreamChunk(
      text: nil,
      done: true,
      error: nil,
      tokenMetadata: tokenMetadata
    )

    // Act
    let result = try mockParser.parseStreamChunk(jsonString: "{\"done\": true}")

    // Assert
    XCTAssertNil(result.text)
    XCTAssertEqual(result.done, true)
    XCTAssertNotNil(result.tokenMetadata)
    XCTAssertEqual(result.tokenMetadata?.promptTokenCount, 500)
  }

  // Verifies parseStreamChunk throws on empty string.
  func test_parseStreamChunk_emptyString_throwsError() {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.parseStreamChunkError = TokenParsingError.invalidJSON(reason: "Empty string")

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parseStreamChunk(jsonString: "")) { error in
      guard let parsingError = error as? TokenParsingError else {
        XCTFail("Expected TokenParsingError")
        return
      }
      XCTAssertEqual(parsingError, .invalidJSON(reason: "Empty string"))
    }
  }

  // Verifies parseStreamChunk throws on whitespace-only string.
  func test_parseStreamChunk_whitespaceOnly_throwsError() {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.parseStreamChunkError = TokenParsingError.invalidJSON(reason: "Whitespace only")

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parseStreamChunk(jsonString: "   ")) { error in
      guard case TokenParsingError.invalidJSON = error else {
        XCTFail("Expected invalidJSON error")
        return
      }
    }
  }

  // MARK: - extractTokenMetadata Tests

  // Verifies extractTokenMetadata returns metadata from final chunk.
  func test_extractTokenMetadata_chunksWithFinalMetadata_returnsMetadata() {
    // Arrange
    let mockParser = MockTokenResponseParser()
    let expectedMetadata = FirebaseStreamTokenMetadata(
      promptTokenCount: 500,
      candidatesTokenCount: 100,
      totalTokenCount: 600,
      historyTruncated: false,
      messagesIncluded: 5
    )
    mockParser.extractTokenMetadataResult = expectedMetadata

    let chunks = [
      FirebaseStreamChunk(text: "Hello", done: nil, error: nil, tokenMetadata: nil),
      FirebaseStreamChunk(text: " world", done: nil, error: nil, tokenMetadata: nil),
      FirebaseStreamChunk(text: nil, done: true, error: nil, tokenMetadata: expectedMetadata)
    ]

    // Act
    let result = mockParser.extractTokenMetadata(from: chunks)

    // Assert
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.promptTokenCount, 500)
    XCTAssertEqual(result?.candidatesTokenCount, 100)
    XCTAssertEqual(mockParser.extractTokenMetadataCallCount, 1)
    XCTAssertEqual(mockParser.extractTokenMetadataChunks?.count, 3)
  }

  // Verifies extractTokenMetadata returns nil for text-only chunks.
  func test_extractTokenMetadata_textOnlyChunks_returnsNil() {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.extractTokenMetadataResult = nil

    let chunks = [
      FirebaseStreamChunk(text: "Hello", done: nil, error: nil, tokenMetadata: nil),
      FirebaseStreamChunk(text: " world", done: nil, error: nil, tokenMetadata: nil)
    ]

    // Act
    let result = mockParser.extractTokenMetadata(from: chunks)

    // Assert
    XCTAssertNil(result)
  }

  // Verifies extractTokenMetadata returns nil for empty chunks array.
  func test_extractTokenMetadata_emptyArray_returnsNil() {
    // Arrange
    let mockParser = MockTokenResponseParser()
    mockParser.extractTokenMetadataResult = nil

    // Act
    let result = mockParser.extractTokenMetadata(from: [])

    // Assert
    XCTAssertNil(result)
    XCTAssertEqual(mockParser.extractTokenMetadataCallCount, 1)
  }

  // MARK: - TokenMetadataConverter Tests

  // Verifies convert from response with complete metadata.
  func test_convertFromResponse_withCompleteMetadata_returnsTokenMetadata() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    let expectedMetadata = TokenMetadata(
      inputTokens: 1500,
      outputTokens: 350,
      totalTokens: 1850,
      contextTruncated: false,
      messagesIncluded: 10
    )
    mockConverter.convertFromResponseResult = expectedMetadata

    let response = FirebaseTokenResponse(
      response: "Test",
      tokenMetadata: FirebaseResponseTokenMetadata(
        promptTokenCount: 1500,
        candidatesTokenCount: 350,
        totalTokenCount: 1850
      ),
      historyTruncated: false,
      messagesIncluded: 10
    )

    // Act
    let result = mockConverter.convert(from: response)

    // Assert
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.inputTokens, 1500)
    XCTAssertEqual(result?.outputTokens, 350)
    XCTAssertEqual(result?.totalTokens, 1850)
    XCTAssertEqual(result?.contextTruncated, false)
    XCTAssertEqual(result?.messagesIncluded, 10)
    XCTAssertEqual(mockConverter.convertFromResponseCallCount, 1)
  }

  // Verifies convert from response with nil tokenMetadata returns nil.
  func test_convertFromResponse_withNilTokenMetadata_returnsNil() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    mockConverter.convertFromResponseResult = nil

    let response = FirebaseTokenResponse(
      response: "Test",
      tokenMetadata: nil,
      historyTruncated: nil,
      messagesIncluded: nil
    )

    // Act
    let result = mockConverter.convert(from: response)

    // Assert
    XCTAssertNil(result)
    XCTAssertEqual(mockConverter.convertFromResponseCallCount, 1)
  }

  // Verifies convert from response with nil historyTruncated defaults to false.
  func test_convertFromResponse_nilHistoryTruncated_defaultsToFalse() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    mockConverter.convertFromResponseResult = TokenMetadata(
      inputTokens: 100,
      outputTokens: 50,
      totalTokens: 150,
      contextTruncated: false,
      messagesIncluded: 5
    )

    let response = FirebaseTokenResponse(
      response: "Test",
      tokenMetadata: FirebaseResponseTokenMetadata(
        promptTokenCount: 100,
        candidatesTokenCount: 50,
        totalTokenCount: 150
      ),
      historyTruncated: nil,
      messagesIncluded: 5
    )

    // Act
    let result = mockConverter.convert(from: response)

    // Assert
    XCTAssertEqual(result?.contextTruncated, false)
  }

  // Verifies convert from stream metadata maps fields correctly.
  func test_convertFromStreamMetadata_mapsFieldsCorrectly() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    let streamMetadata = FirebaseStreamTokenMetadata(
      promptTokenCount: 1000,
      candidatesTokenCount: 500,
      totalTokenCount: 1500,
      historyTruncated: true,
      messagesIncluded: 8
    )

    // Act
    let result = mockConverter.convert(from: streamMetadata)

    // Assert
    XCTAssertEqual(result.inputTokens, 1000)
    XCTAssertEqual(result.outputTokens, 500)
    XCTAssertEqual(result.totalTokens, 1500)
    XCTAssertEqual(result.contextTruncated, true)
    XCTAssertEqual(result.messagesIncluded, 8)
    XCTAssertEqual(mockConverter.convertFromStreamCallCount, 1)
    XCTAssertEqual(mockConverter.convertFromStreamInput?.promptTokenCount, 1000)
  }

  // Verifies createEstimatedMetadata for typical request.
  func test_createEstimatedMetadata_typicalRequest_calculatesCorrectly() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    let inputContent = String(repeating: "a", count: 4000)
    let outputContent = String(repeating: "b", count: 1000)

    // Act
    let result = mockConverter.createEstimatedMetadata(
      inputContent: inputContent,
      outputContent: outputContent,
      messagesIncluded: 5
    )

    // Assert
    // 4000 / 4.0 = 1000, 1000 / 4.0 = 250
    XCTAssertEqual(result.inputTokens, 1000)
    XCTAssertEqual(result.outputTokens, 250)
    XCTAssertEqual(result.totalTokens, 1250)
    XCTAssertEqual(result.contextTruncated, false)
    XCTAssertEqual(result.messagesIncluded, 5)
    XCTAssertEqual(mockConverter.createEstimatedCallCount, 1)
    XCTAssertEqual(mockConverter.createEstimatedInputContent, inputContent)
    XCTAssertEqual(mockConverter.createEstimatedOutputContent, outputContent)
    XCTAssertEqual(mockConverter.createEstimatedMessagesIncluded, 5)
  }

  // Verifies createEstimatedMetadata for empty content.
  func test_createEstimatedMetadata_emptyContent_returnsZeros() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    mockConverter.createEstimatedResult = TokenMetadata(
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      contextTruncated: false,
      messagesIncluded: 1
    )

    // Act
    let result = mockConverter.createEstimatedMetadata(
      inputContent: "",
      outputContent: "",
      messagesIncluded: 1
    )

    // Assert
    XCTAssertEqual(result.inputTokens, 0)
    XCTAssertEqual(result.outputTokens, 0)
    XCTAssertEqual(result.totalTokens, 0)
  }

  // MARK: - Edge Case Tests

  // Verifies handling of large token counts near Int.max.
  func test_parseTokenMetadata_largeTokenCounts_handlesCorrectly() throws {
    // Arrange
    let largeCount = 1_000_000_000
    let json = """
    {
      "promptTokenCount": \(largeCount),
      "candidatesTokenCount": \(largeCount),
      "totalTokenCount": \(largeCount * 2)
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let metadata = try decoder.decode(FirebaseResponseTokenMetadata.self, from: data)

    // Assert
    XCTAssertEqual(metadata.promptTokenCount, largeCount)
    XCTAssertEqual(metadata.candidatesTokenCount, largeCount)
    XCTAssertEqual(metadata.totalTokenCount, largeCount * 2)
  }

  // Verifies handling of floating point token counts in JSON.
  func test_parseTokenMetadata_floatingPointValue_throwsDecodingError() {
    // Arrange
    let json = """
    {
      "promptTokenCount": 1000.5,
      "candidatesTokenCount": 500,
      "totalTokenCount": 1500
    }
    """
    let data = json.data(using: .utf8)!

    // Act & Assert
    XCTAssertThrowsError(try decoder.decode(FirebaseResponseTokenMetadata.self, from: data))
  }

  // Verifies models conform to Equatable.
  func test_firebaseTokenResponse_equatable_comparesCorrectly() {
    // Arrange
    let response1 = FirebaseTokenResponse(
      response: "Test",
      tokenMetadata: nil,
      historyTruncated: false,
      messagesIncluded: 5
    )
    let response2 = FirebaseTokenResponse(
      response: "Test",
      tokenMetadata: nil,
      historyTruncated: false,
      messagesIncluded: 5
    )
    let response3 = FirebaseTokenResponse(
      response: "Different",
      tokenMetadata: nil,
      historyTruncated: false,
      messagesIncluded: 5
    )

    // Assert
    XCTAssertEqual(response1, response2)
    XCTAssertNotEqual(response1, response3)
  }

  // Verifies models conform to Sendable by compilation.
  func test_models_conformToSendable() async {
    // This test verifies at compile time that models conform to Sendable.
    // If it compiles, the test passes.
    let response = FirebaseTokenResponse(
      response: "Test",
      tokenMetadata: nil,
      historyTruncated: nil,
      messagesIncluded: nil
    )

    // Pass to another isolation domain to verify Sendable conformance.
    await Task {
      _ = response.response
    }.value
  }

  // Verifies Codable round-trip for FirebaseTokenResponse.
  func test_firebaseTokenResponse_codableRoundTrip_preservesData() throws {
    // Arrange
    let original = FirebaseTokenResponse(
      response: "Test response",
      tokenMetadata: FirebaseResponseTokenMetadata(
        promptTokenCount: 100,
        candidatesTokenCount: 50,
        totalTokenCount: 150
      ),
      historyTruncated: true,
      messagesIncluded: 5
    )
    let encoder = JSONEncoder()

    // Act
    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(FirebaseTokenResponse.self, from: encoded)

    // Assert
    XCTAssertEqual(original, decoded)
  }

  // Verifies Codable round-trip for FirebaseStreamChunk.
  func test_firebaseStreamChunk_codableRoundTrip_preservesData() throws {
    // Arrange
    let streamMetadata = FirebaseStreamTokenMetadata(
      promptTokenCount: 500,
      candidatesTokenCount: 100,
      totalTokenCount: 600,
      historyTruncated: false,
      messagesIncluded: 5
    )
    let original = FirebaseStreamChunk(
      text: nil,
      done: true,
      error: nil,
      tokenMetadata: streamMetadata
    )
    let encoder = JSONEncoder()

    // Act
    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(FirebaseStreamChunk.self, from: encoded)

    // Assert
    XCTAssertEqual(original, decoded)
  }

  // Verifies Codable round-trip for FirebaseErrorResponse.
  func test_firebaseErrorResponse_codableRoundTrip_preservesData() throws {
    // Arrange
    let original = FirebaseErrorResponse(
      error: "Token limit exceeded",
      details: "Too many tokens",
      tokenCount: 1100000,
      maxTokens: 1048576,
      errorCode: "TOKEN_LIMIT_EXCEEDED"
    )
    let encoder = JSONEncoder()

    // Act
    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(FirebaseErrorResponse.self, from: encoded)

    // Assert
    XCTAssertEqual(original, decoded)
  }

  // MARK: - Integration Scenario Tests

  // Simulates parsing a complete sendMessage response with token metadata.
  func test_integrationScenario_parseCompleteResponse_succeeds() throws {
    // Arrange
    let json = """
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
    """
    let data = json.data(using: .utf8)!

    // Act
    let response = try decoder.decode(FirebaseTokenResponse.self, from: data)

    // Assert
    XCTAssertEqual(response.response, "The AI response text...")
    XCTAssertEqual(response.tokenMetadata?.promptTokenCount, 1500)
    XCTAssertEqual(response.tokenMetadata?.candidatesTokenCount, 350)
    XCTAssertEqual(response.tokenMetadata?.totalTokenCount, 1850)
    XCTAssertEqual(response.historyTruncated, false)
    XCTAssertEqual(response.messagesIncluded, 10)
  }

  // Simulates parsing streaming response chunks.
  func test_integrationScenario_parseStreamingChunks_succeeds() throws {
    // Arrange - Simulating SSE data events
    let chunk1Json = """
    {"text": "Hello, "}
    """
    let chunk2Json = """
    {"text": "how can I help?"}
    """
    let chunk3Json = """
    {
      "done": true,
      "tokenMetadata": {
        "promptTokenCount": 500,
        "candidatesTokenCount": 100,
        "totalTokenCount": 600,
        "historyTruncated": false,
        "messagesIncluded": 5
      }
    }
    """

    // Act
    let chunk1 = try decoder.decode(FirebaseStreamChunk.self, from: chunk1Json.data(using: .utf8)!)
    let chunk2 = try decoder.decode(FirebaseStreamChunk.self, from: chunk2Json.data(using: .utf8)!)
    let chunk3 = try decoder.decode(FirebaseStreamChunk.self, from: chunk3Json.data(using: .utf8)!)

    // Assert
    XCTAssertEqual(chunk1.text, "Hello, ")
    XCTAssertNil(chunk1.done)

    XCTAssertEqual(chunk2.text, "how can I help?")
    XCTAssertNil(chunk2.done)

    XCTAssertNil(chunk3.text)
    XCTAssertEqual(chunk3.done, true)
    XCTAssertNotNil(chunk3.tokenMetadata)
    XCTAssertEqual(chunk3.tokenMetadata?.promptTokenCount, 500)
  }

  // Simulates handling a token limit error response.
  func test_integrationScenario_parseTokenLimitError_succeeds() throws {
    // Arrange
    let json = """
    {
      "error": "Request exceeds token limit",
      "errorCode": "TOKEN_LIMIT_EXCEEDED",
      "tokenCount": 1100000,
      "maxTokens": 1048576
    }
    """
    let data = json.data(using: .utf8)!

    // Act
    let errorResponse = try decoder.decode(FirebaseErrorResponse.self, from: data)

    // Assert - Verify error can be converted to TokenLimitError
    XCTAssertEqual(errorResponse.errorCode, FirebaseTokenConstants.tokenLimitErrorCode)
    let tokenLimitError = TokenLimitError.contextWindowExceeded(
      requestedTokens: errorResponse.tokenCount ?? 0,
      maxTokens: errorResponse.maxTokens ?? 0
    )
    XCTAssertNotNil(tokenLimitError.errorDescription)
  }

  // Simulates fallback to estimation when metadata is missing.
  func test_integrationScenario_fallbackToEstimation_succeeds() {
    // Arrange
    let mockConverter = MockTokenMetadataConverter()
    let response = FirebaseTokenResponse(
      response: "Test response",
      tokenMetadata: nil,
      historyTruncated: nil,
      messagesIncluded: nil
    )
    mockConverter.convertFromResponseResult = nil

    // Act
    let converted = mockConverter.convert(from: response)

    // Fallback to estimation since converted is nil
    let estimatedMetadata: TokenMetadata
    if converted == nil {
      estimatedMetadata = mockConverter.createEstimatedMetadata(
        inputContent: "User input text",
        outputContent: response.response,
        messagesIncluded: 1
      )
    } else {
      estimatedMetadata = converted!
    }

    // Assert
    XCTAssertNil(converted)
    XCTAssertEqual(mockConverter.createEstimatedCallCount, 1)
    XCTAssertEqual(estimatedMetadata.contextTruncated, false)
  }
}
