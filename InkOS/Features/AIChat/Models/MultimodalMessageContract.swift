// MultimodalMessageContract.swift
// Defines the API contract for multimodal message types in AI Chat.
// Phase 3 of Document Upload Handling: Multimodal API message types.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.
// These types enable sending file attachments to the Gemini API via Firebase Cloud Functions.
// Integrates with AttachmentContract.swift (Phase 1) and AttachmentServiceContract.swift (Phase 2).

import Foundation

// MARK: - API Contract

// MARK: - APIInlineData

// Represents inline binary data (base64 encoded) for multimodal API messages.
// Used for smaller files that can be embedded directly in the API request.
// Matches Gemini API's inlineData format.
struct APIInlineData: Sendable, Codable, Equatable {
  // The MIME type of the data (e.g., "image/png", "application/pdf").
  let mimeType: String

  // The base64-encoded binary data.
  let data: String

  // Creates inline data with MIME type and base64 data.
  init(mimeType: String, data: String) {
    self.mimeType = mimeType
    self.data = data
  }

  // Convenience initializer from FileAttachment.
  // attachment: The file attachment to convert.
  init(from attachment: FileAttachment) {
    self.mimeType = attachment.mimeType.rawValue
    self.data = attachment.base64Data
  }
}

/*
 ACCEPTANCE CRITERIA: APIInlineData Initialization

 SCENARIO: Create inline data with explicit values
 GIVEN: mimeType = "image/png" and data = "iVBORw0KGgo..."
 WHEN: APIInlineData is initialized with mimeType and data
 THEN: mimeType is "image/png"
  AND: data is "iVBORw0KGgo..."

 SCENARIO: Create inline data from FileAttachment
 GIVEN: FileAttachment with mimeType = .jpeg and base64Data = "abc123..."
 WHEN: APIInlineData(from: attachment) is called
 THEN: mimeType is "image/jpeg"
  AND: data is "abc123..."
  AND: mimeType uses rawValue from AttachmentMimeType enum
*/

/*
 ACCEPTANCE CRITERIA: APIInlineData Codable

 SCENARIO: Encode inline data to JSON
 GIVEN: APIInlineData(mimeType: "image/png", data: "base64string")
 WHEN: Encoded using JSONEncoder
 THEN: JSON is {"mimeType":"image/png","data":"base64string"}
  AND: Keys use camelCase (Swift default)

 SCENARIO: Decode inline data from JSON
 GIVEN: JSON {"mimeType":"image/png","data":"base64string"}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIInlineData with mimeType = "image/png" and data = "base64string"
*/

/*
 EDGE CASES: APIInlineData

 EDGE CASE: Empty data string
 GIVEN: APIInlineData with data = ""
 WHEN: Object is created
 THEN: Object is valid (validation happens at higher layer)

 EDGE CASE: Very long base64 data
 GIVEN: APIInlineData with data containing 100MB of base64 (approx 133 million chars)
 WHEN: Object is created and encoded
 THEN: No truncation occurs
  AND: Memory usage is proportional to data size

 EDGE CASE: MIME type with parameters
 GIVEN: mimeType = "text/plain; charset=utf-8"
 WHEN: APIInlineData is created
 THEN: mimeType is stored as-is with parameters
*/

// MARK: - APIFileData

// Represents a reference to a file uploaded via Gemini Files API.
// Used for larger files that are uploaded separately and referenced by URI.
// Matches Gemini API's fileData format.
struct APIFileData: Sendable, Codable, Equatable {
  // The URI returned by the Files API for referencing this file.
  // Format: files/{file_id} or https://generativelanguage.googleapis.com/...
  let fileUri: String

  // The MIME type of the uploaded file.
  let mimeType: String

  // Creates file data reference with URI and MIME type.
  init(fileUri: String, mimeType: String) {
    self.fileUri = fileUri
    self.mimeType = mimeType
  }

  // Convenience initializer from UploadedFileReference.
  // reference: The uploaded file reference to convert.
  init(from reference: UploadedFileReference) {
    self.fileUri = reference.fileUri
    self.mimeType = reference.mimeType
  }
}

/*
 ACCEPTANCE CRITERIA: APIFileData Initialization

 SCENARIO: Create file data with explicit values
 GIVEN: fileUri = "files/abc123" and mimeType = "application/pdf"
 WHEN: APIFileData is initialized with fileUri and mimeType
 THEN: fileUri is "files/abc123"
  AND: mimeType is "application/pdf"

 SCENARIO: Create file data from UploadedFileReference
 GIVEN: UploadedFileReference with fileUri = "files/xyz789" and mimeType = "image/png"
 WHEN: APIFileData(from: reference) is called
 THEN: fileUri is "files/xyz789"
  AND: mimeType is "image/png"
*/

/*
 ACCEPTANCE CRITERIA: APIFileData Codable

 SCENARIO: Encode file data to JSON
 GIVEN: APIFileData(fileUri: "files/abc", mimeType: "image/png")
 WHEN: Encoded using JSONEncoder
 THEN: JSON is {"fileUri":"files/abc","mimeType":"image/png"}

 SCENARIO: Decode file data from JSON
 GIVEN: JSON {"fileUri":"files/abc","mimeType":"image/png"}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIFileData with fileUri = "files/abc" and mimeType = "image/png"
*/

/*
 EDGE CASES: APIFileData

 EDGE CASE: Full URL as fileUri
 GIVEN: fileUri = "https://generativelanguage.googleapis.com/v1/files/abc123"
 WHEN: APIFileData is created
 THEN: fileUri is stored as-is (full URL format accepted)

 EDGE CASE: Empty fileUri
 GIVEN: fileUri = ""
 WHEN: APIFileData is created
 THEN: Object is valid (validation happens at API layer)

 EDGE CASE: fileUri with special characters
 GIVEN: fileUri containing URL-encoded characters
 WHEN: APIFileData is created
 THEN: fileUri is stored as-is without modification
*/

// MARK: - APIMessagePart

// Represents a single part of a multimodal message.
// Each message can contain multiple parts of different types.
// Custom Codable implementation matches Gemini API's expected format.
enum APIMessagePart: Sendable, Equatable {
  // Text content.
  case text(String)

  // Inline base64-encoded data.
  case inlineData(APIInlineData)

  // Reference to an uploaded file.
  case fileData(APIFileData)
}

/*
 ACCEPTANCE CRITERIA: APIMessagePart Initialization

 SCENARIO: Create text part
 GIVEN: Text content "Hello, world!"
 WHEN: APIMessagePart.text("Hello, world!") is created
 THEN: Part contains the text "Hello, world!"

 SCENARIO: Create inline data part
 GIVEN: APIInlineData with mimeType and data
 WHEN: APIMessagePart.inlineData(inlineData) is created
 THEN: Part contains the inline data

 SCENARIO: Create file data part
 GIVEN: APIFileData with fileUri and mimeType
 WHEN: APIMessagePart.fileData(fileData) is created
 THEN: Part contains the file data reference
*/

/*
 ACCEPTANCE CRITERIA: APIMessagePart Equatable

 SCENARIO: Equal text parts compare as equal
 GIVEN: Two APIMessagePart.text("same text")
 WHEN: Compared using ==
 THEN: Returns true

 SCENARIO: Text parts with different content compare as not equal
 GIVEN: APIMessagePart.text("hello") and APIMessagePart.text("world")
 WHEN: Compared using ==
 THEN: Returns false

 SCENARIO: Different part types compare as not equal
 GIVEN: APIMessagePart.text("hello") and APIMessagePart.inlineData(...)
 WHEN: Compared using ==
 THEN: Returns false

 SCENARIO: Equal inline data parts compare as equal
 GIVEN: Two APIMessagePart.inlineData with identical APIInlineData
 WHEN: Compared using ==
 THEN: Returns true

 SCENARIO: Equal file data parts compare as equal
 GIVEN: Two APIMessagePart.fileData with identical APIFileData
 WHEN: Compared using ==
 THEN: Returns true
*/

// MARK: - APIMessagePart Codable Implementation

// Custom Codable implementation for APIMessagePart.
// Encodes to match Gemini API's expected JSON format:
// - Text: {"text": "..."}
// - Inline: {"inlineData": {"mimeType": "...", "data": "..."}}
// - File: {"fileData": {"fileUri": "...", "mimeType": "..."}}

extension APIMessagePart: Codable {
  // Coding keys for the part wrapper.
  private enum CodingKeys: String, CodingKey {
    case text
    case inlineData
    case fileData
  }

  // Encodes the message part to JSON.
  // Uses the appropriate key based on part type.
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .text(let text):
      try container.encode(text, forKey: .text)
    case .inlineData(let inlineData):
      try container.encode(inlineData, forKey: .inlineData)
    case .fileData(let fileData):
      try container.encode(fileData, forKey: .fileData)
    }
  }

  // Decodes a message part from JSON.
  // Attempts to decode each type in order, using the first that succeeds.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Try to decode text first.
    if let text = try container.decodeIfPresent(String.self, forKey: .text) {
      self = .text(text)
      return
    }

    // Try to decode inline data.
    if let inlineData = try container.decodeIfPresent(APIInlineData.self, forKey: .inlineData) {
      self = .inlineData(inlineData)
      return
    }

    // Try to decode file data.
    if let fileData = try container.decodeIfPresent(APIFileData.self, forKey: .fileData) {
      self = .fileData(fileData)
      return
    }

    // No valid part type found.
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "APIMessagePart must contain text, inlineData, or fileData"
      )
    )
  }
}

/*
 ACCEPTANCE CRITERIA: APIMessagePart Encoding

 SCENARIO: Encode text part to JSON
 GIVEN: APIMessagePart.text("Hello, world!")
 WHEN: Encoded using JSONEncoder
 THEN: JSON is {"text":"Hello, world!"}
  AND: Only "text" key is present

 SCENARIO: Encode inline data part to JSON
 GIVEN: APIMessagePart.inlineData(APIInlineData(mimeType: "image/png", data: "abc123"))
 WHEN: Encoded using JSONEncoder
 THEN: JSON is {"inlineData":{"mimeType":"image/png","data":"abc123"}}
  AND: Nested structure matches Gemini format
  AND: Only "inlineData" key is present at top level

 SCENARIO: Encode file data part to JSON
 GIVEN: APIMessagePart.fileData(APIFileData(fileUri: "files/xyz", mimeType: "application/pdf"))
 WHEN: Encoded using JSONEncoder
 THEN: JSON is {"fileData":{"fileUri":"files/xyz","mimeType":"application/pdf"}}
  AND: Nested structure matches Gemini format
  AND: Only "fileData" key is present at top level

 SCENARIO: Encode empty text part
 GIVEN: APIMessagePart.text("")
 WHEN: Encoded using JSONEncoder
 THEN: JSON is {"text":""}
  AND: Empty string is valid

 SCENARIO: Encode text with special characters
 GIVEN: APIMessagePart.text("Hello\nWorld\t\"quoted\"")
 WHEN: Encoded using JSONEncoder
 THEN: JSON properly escapes special characters
  AND: Newlines become \n, tabs become \t, quotes become \"

 SCENARIO: Encode text with unicode
 GIVEN: APIMessagePart.text("Hello World")
 WHEN: Encoded using JSONEncoder
 THEN: Unicode characters are preserved in JSON
*/

/*
 ACCEPTANCE CRITERIA: APIMessagePart Decoding

 SCENARIO: Decode text part from JSON
 GIVEN: JSON {"text":"Hello, world!"}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIMessagePart.text("Hello, world!")

 SCENARIO: Decode inline data part from JSON
 GIVEN: JSON {"inlineData":{"mimeType":"image/png","data":"abc123"}}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIMessagePart.inlineData with mimeType="image/png" and data="abc123"

 SCENARIO: Decode file data part from JSON
 GIVEN: JSON {"fileData":{"fileUri":"files/xyz","mimeType":"application/pdf"}}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIMessagePart.fileData with fileUri="files/xyz" and mimeType="application/pdf"

 SCENARIO: Decode empty JSON object throws error
 GIVEN: JSON {}
 WHEN: Decoded using JSONDecoder
 THEN: Throws DecodingError.dataCorrupted
  AND: Error message indicates part must contain text, inlineData, or fileData

 SCENARIO: Decode JSON with unknown key throws error
 GIVEN: JSON {"unknownKey":"value"}
 WHEN: Decoded using JSONDecoder
 THEN: Throws DecodingError.dataCorrupted
  AND: No matching part type found

 SCENARIO: Decode JSON with multiple keys uses first match
 GIVEN: JSON {"text":"hello","inlineData":{"mimeType":"image/png","data":"abc"}}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIMessagePart.text("hello")
  AND: Text is decoded first in priority order
  AND: Additional keys are ignored
*/

/*
 EDGE CASES: APIMessagePart Codable

 EDGE CASE: Round-trip encoding/decoding preserves data
 GIVEN: Any APIMessagePart instance
 WHEN: Encoded to JSON then decoded back
 THEN: Result equals original
  AND: No data loss occurs

 EDGE CASE: Null value for text key
 GIVEN: JSON {"text":null}
 WHEN: Decoded using JSONDecoder
 THEN: Throws DecodingError (null is not a valid String)

 EDGE CASE: Invalid inlineData structure
 GIVEN: JSON {"inlineData":"not an object"}
 WHEN: Decoded using JSONDecoder
 THEN: Throws DecodingError.typeMismatch

 EDGE CASE: Missing required field in inlineData
 GIVEN: JSON {"inlineData":{"mimeType":"image/png"}}
 WHEN: Decoded using JSONDecoder
 THEN: Throws DecodingError.keyNotFound for "data"

 EDGE CASE: Missing required field in fileData
 GIVEN: JSON {"fileData":{"fileUri":"files/abc"}}
 WHEN: Decoded using JSONDecoder
 THEN: Throws DecodingError.keyNotFound for "mimeType"

 EDGE CASE: Extra fields in nested objects are ignored
 GIVEN: JSON {"inlineData":{"mimeType":"image/png","data":"abc","extra":"ignored"}}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIMessagePart.inlineData successfully
  AND: Extra fields are ignored

 EDGE CASE: Whitespace in JSON is handled
 GIVEN: JSON with extra whitespace and newlines
 WHEN: Decoded using JSONDecoder
 THEN: Decoding succeeds
  AND: Whitespace does not affect result
*/

// MARK: - APIMessageMultimodal

// Represents a multimodal message with role and multiple parts.
// Used for API requests that include text and file attachments.
// Matches Gemini API's message format for multimodal content.
struct APIMessageMultimodal: Sendable, Codable, Equatable {
  // Role of the message sender ("user" or "model").
  let role: String

  // Array of message parts (text, inline data, file data).
  let parts: [APIMessagePart]

  // Creates a multimodal message with role and parts.
  init(role: String, parts: [APIMessagePart]) {
    self.role = role
    self.parts = parts
  }

  // Convenience initializer for text-only messages.
  // Creates a message with a single text part.
  init(role: String, text: String) {
    self.role = role
    self.parts = [.text(text)]
  }

  // Convenience initializer to convert from legacy APIMessage format.
  // Converts the content to a single text part.
  init(from message: APIMessage) {
    self.role = message.role
    self.parts = [.text(message.content)]
  }
}

/*
 ACCEPTANCE CRITERIA: APIMessageMultimodal Initialization

 SCENARIO: Create message with role and parts array
 GIVEN: role = "user" and parts = [.text("Hello"), .inlineData(...)]
 WHEN: APIMessageMultimodal is initialized with role and parts
 THEN: role is "user"
  AND: parts contains 2 elements
  AND: First part is text "Hello"
  AND: Second part is inline data

 SCENARIO: Create text-only message with convenience initializer
 GIVEN: role = "user" and text = "Hello, world!"
 WHEN: APIMessageMultimodal(role: role, text: text) is called
 THEN: role is "user"
  AND: parts contains exactly 1 element
  AND: parts[0] is .text("Hello, world!")

 SCENARIO: Convert from legacy APIMessage
 GIVEN: APIMessage(role: "user", content: "Hello")
 WHEN: APIMessageMultimodal(from: apiMessage) is called
 THEN: role is "user"
  AND: parts contains exactly 1 element
  AND: parts[0] is .text("Hello")

 SCENARIO: Convert from APIMessage created from ChatMessage
 GIVEN: ChatMessage with role = .user and content = "Hi there"
  AND: APIMessage created from ChatMessage
 WHEN: APIMessageMultimodal(from: apiMessage) is called
 THEN: role is "user"
  AND: parts[0] is .text("Hi there")

 SCENARIO: Create message with model role
 GIVEN: role = "model" and text = "I can help with that."
 WHEN: APIMessageMultimodal(role: role, text: text) is called
 THEN: role is "model"
  AND: Gemini uses "model" instead of "assistant"
*/

/*
 ACCEPTANCE CRITERIA: APIMessageMultimodal Codable

 SCENARIO: Encode text-only message to JSON
 GIVEN: APIMessageMultimodal(role: "user", text: "Hello")
 WHEN: Encoded using JSONEncoder
 THEN: JSON is {"role":"user","parts":[{"text":"Hello"}]}

 SCENARIO: Encode multipart message to JSON
 GIVEN: APIMessageMultimodal with text and inline data parts
 WHEN: Encoded using JSONEncoder
 THEN: JSON contains role and parts array
  AND: Each part is encoded according to its type
  AND: Parts array preserves order

 SCENARIO: Encode message with all part types to JSON
 GIVEN: APIMessageMultimodal with .text, .inlineData, and .fileData parts
 WHEN: Encoded using JSONEncoder
 THEN: JSON is:
  {
    "role": "user",
    "parts": [
      {"text": "..."},
      {"inlineData": {"mimeType": "...", "data": "..."}},
      {"fileData": {"fileUri": "...", "mimeType": "..."}}
    ]
  }

 SCENARIO: Decode multipart message from JSON
 GIVEN: JSON {"role":"user","parts":[{"text":"Hello"},{"inlineData":{...}}]}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIMessageMultimodal with role "user"
  AND: parts array contains 2 elements in order
  AND: First part is text, second is inline data

 SCENARIO: Decode empty parts array
 GIVEN: JSON {"role":"user","parts":[]}
 WHEN: Decoded using JSONDecoder
 THEN: Returns APIMessageMultimodal with empty parts array
  AND: Empty parts array is valid (API may reject)
*/

/*
 ACCEPTANCE CRITERIA: APIMessageMultimodal Equatable

 SCENARIO: Equal messages compare as equal
 GIVEN: Two APIMessageMultimodal with same role and parts
 WHEN: Compared using ==
 THEN: Returns true

 SCENARIO: Messages with different roles compare as not equal
 GIVEN: APIMessageMultimodal with role "user" and role "model"
 WHEN: Compared using ==
 THEN: Returns false

 SCENARIO: Messages with different parts compare as not equal
 GIVEN: Two messages with different parts arrays
 WHEN: Compared using ==
 THEN: Returns false

 SCENARIO: Messages with same parts in different order compare as not equal
 GIVEN: Message with [.text("a"), .text("b")] and [.text("b"), .text("a")]
 WHEN: Compared using ==
 THEN: Returns false
  AND: Parts order matters
*/

/*
 EDGE CASES: APIMessageMultimodal

 EDGE CASE: Empty parts array
 GIVEN: APIMessageMultimodal(role: "user", parts: [])
 WHEN: Message is created and encoded
 THEN: Valid object with empty parts array
  AND: API may reject empty parts (validation at higher layer)

 EDGE CASE: Many parts in message
 GIVEN: Message with 100 parts
 WHEN: Message is encoded
 THEN: All 100 parts are preserved
  AND: No truncation occurs

 EDGE CASE: Large text parts
 GIVEN: Message with text part containing 1 million characters
 WHEN: Message is encoded
 THEN: Full text is preserved
  AND: No truncation occurs

 EDGE CASE: Multiple text parts
 GIVEN: Message with [.text("Hello"), .text("World")]
 WHEN: Message is encoded
 THEN: Both text parts are preserved separately
  AND: Parts are not concatenated

 EDGE CASE: Role with unexpected value
 GIVEN: role = "system" (not user or model)
 WHEN: APIMessageMultimodal is created
 THEN: Object is valid (API validation at higher layer)
  AND: Role is stored as-is

 EDGE CASE: Mixed inline and file data
 GIVEN: Message with 5 inline data parts and 3 file data parts
 WHEN: Message is encoded
 THEN: All parts maintain their types
  AND: Order is preserved
*/

// MARK: - Conversion Utilities

// Extension to convert arrays of APIMessage to APIMessageMultimodal.
// Enables easy migration from legacy message format.
extension Array where Element == APIMessage {
  // Converts an array of legacy APIMessages to multimodal format.
  // Returns: Array of APIMessageMultimodal with text-only parts.
  func toMultimodal() -> [APIMessageMultimodal] {
    return self.map { APIMessageMultimodal(from: $0) }
  }
}

/*
 ACCEPTANCE CRITERIA: Array<APIMessage>.toMultimodal()

 SCENARIO: Convert empty array
 GIVEN: Empty array of APIMessage
 WHEN: toMultimodal() is called
 THEN: Returns empty array of APIMessageMultimodal

 SCENARIO: Convert single message
 GIVEN: Array with one APIMessage(role: "user", content: "Hello")
 WHEN: toMultimodal() is called
 THEN: Returns array with one APIMessageMultimodal
  AND: Message has role "user" and single text part "Hello"

 SCENARIO: Convert multiple messages
 GIVEN: Array with 3 APIMessages
 WHEN: toMultimodal() is called
 THEN: Returns array with 3 APIMessageMultimodal messages
  AND: Order is preserved
  AND: Each message is converted correctly

 SCENARIO: Preserve conversation turn order
 GIVEN: Array [user message, model message, user message]
 WHEN: toMultimodal() is called
 THEN: Returns array with same order
  AND: Roles alternate correctly
*/

// MARK: - Error Definitions

// Errors specific to multimodal message operations.
// Complements existing ChatError and AttachmentError types.
enum MultimodalMessageError: Error, LocalizedError, Equatable {
  // No valid parts in the message.
  case emptyParts

  // Part type mismatch during conversion.
  case invalidPartType(expected: String, actual: String)

  // Message exceeds part count limit.
  case tooManyParts(count: Int, limit: Int)

  var errorDescription: String? {
    switch self {
    case .emptyParts:
      return "Message must contain at least one part"
    case .invalidPartType(let expected, let actual):
      return "Expected part type '\(expected)' but got '\(actual)'"
    case .tooManyParts(let count, let limit):
      return "Message contains \(count) parts but maximum is \(limit)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: MultimodalMessageError.errorDescription

 SCENARIO: Empty parts error message
 GIVEN: MultimodalMessageError.emptyParts
 WHEN: errorDescription is accessed
 THEN: Returns "Message must contain at least one part"

 SCENARIO: Invalid part type error message
 GIVEN: MultimodalMessageError.invalidPartType(expected: "text", actual: "inlineData")
 WHEN: errorDescription is accessed
 THEN: Returns "Expected part type 'text' but got 'inlineData'"

 SCENARIO: Too many parts error message
 GIVEN: MultimodalMessageError.tooManyParts(count: 150, limit: 100)
 WHEN: errorDescription is accessed
 THEN: Returns "Message contains 150 parts but maximum is 100"
*/

/*
 ACCEPTANCE CRITERIA: MultimodalMessageError Equatable

 SCENARIO: Same error cases with same values compare as equal
 GIVEN: Two MultimodalMessageError.emptyParts
 WHEN: Compared using ==
 THEN: Returns true

 SCENARIO: Same error cases with different values compare as not equal
 GIVEN: MultimodalMessageError.tooManyParts(count: 10, limit: 5)
  AND: MultimodalMessageError.tooManyParts(count: 20, limit: 5)
 WHEN: Compared using ==
 THEN: Returns false

 SCENARIO: Different error cases compare as not equal
 GIVEN: MultimodalMessageError.emptyParts
  AND: MultimodalMessageError.tooManyParts(count: 10, limit: 5)
 WHEN: Compared using ==
 THEN: Returns false
*/

// MARK: - Constants

// Constants for multimodal message limits.
// Based on Gemini API documentation and practical limits.
enum MultimodalMessageConstants {
  // Maximum number of parts per message (practical limit).
  static let maxPartsPerMessage = 100

  // Maximum number of inline data parts per request.
  // Larger files should use file data references.
  static let maxInlineDataParts = 16

  // Maximum size of inline data in bytes (20MB matches image limit).
  static let maxInlineDataSize = 20 * 1024 * 1024
}

/*
 ACCEPTANCE CRITERIA: MultimodalMessageConstants

 SCENARIO: All constants have correct values
 GIVEN: MultimodalMessageConstants
 WHEN: Each constant is accessed
 THEN: maxPartsPerMessage is 100
  AND: maxInlineDataParts is 16
  AND: maxInlineDataSize is 20971520 (20 * 1024 * 1024)
*/

// MARK: - Testing Support

/*
 TESTING: APIInlineData Unit Tests

 1. Test initialization with explicit values
 2. Test initialization from FileAttachment
 3. Test Codable round-trip encoding/decoding
 4. Test Equatable for equal instances
 5. Test Equatable for different instances

 TESTING: APIFileData Unit Tests

 1. Test initialization with explicit values
 2. Test initialization from UploadedFileReference
 3. Test Codable round-trip encoding/decoding
 4. Test Equatable for equal instances
 5. Test Equatable for different instances

 TESTING: APIMessagePart Unit Tests

 1. Test creation of each case type
 2. Test Equatable for same case with same values
 3. Test Equatable for same case with different values
 4. Test Equatable for different cases
 5. Test encoding of .text to JSON format
 6. Test encoding of .inlineData to JSON format
 7. Test encoding of .fileData to JSON format
 8. Test decoding of text JSON
 9. Test decoding of inlineData JSON
 10. Test decoding of fileData JSON
 11. Test decoding of empty JSON object fails
 12. Test decoding of invalid JSON fails appropriately
 13. Test round-trip encoding/decoding for all cases

 TESTING: APIMessageMultimodal Unit Tests

 1. Test initialization with role and parts
 2. Test text-only convenience initializer
 3. Test conversion from APIMessage
 4. Test Codable encoding to expected JSON format
 5. Test Codable decoding from valid JSON
 6. Test Equatable for equal messages
 7. Test Equatable for different messages
 8. Test empty parts array handling
 9. Test multiple parts of same type
 10. Test mixed part types

 TESTING: Array<APIMessage>.toMultimodal() Unit Tests

 1. Test empty array conversion
 2. Test single message conversion
 3. Test multiple message conversion
 4. Test order preservation

 TESTING: MultimodalMessageError Unit Tests

 1. Test errorDescription for each error case
 2. Test Equatable for same case and values
 3. Test Equatable for different cases

 TESTING: Integration Tests

 1. Test full conversion flow: FileAttachment -> APIInlineData -> APIMessagePart -> APIMessageMultimodal
 2. Test full conversion flow: UploadedFileReference -> APIFileData -> APIMessagePart -> APIMessageMultimodal
 3. Test JSON encoding matches Gemini API expected format
 4. Test encoding array of APIMessageMultimodal for API request body
*/

// MARK: - Gemini API Format Reference

/*
 GEMINI API FORMAT: Message Structure

 The Gemini API expects messages in this format:
 {
   "contents": [
     {
       "role": "user",
       "parts": [
         {"text": "What's in this image?"},
         {"inlineData": {"mimeType": "image/png", "data": "base64..."}}
       ]
     },
     {
       "role": "model",
       "parts": [
         {"text": "I can see..."}
       ]
     }
   ]
 }

 NOTES:
 - "role" must be "user" or "model" (not "assistant")
 - "parts" is an array, even for single text messages
 - Each part has exactly one key: "text", "inlineData", or "fileData"
 - "inlineData" contains nested "mimeType" and "data" fields
 - "fileData" contains nested "fileUri" and "mimeType" fields

 FIREBASE CLOUD FUNCTION:
 The Cloud Function wraps this format and handles API key authentication.
 Client sends messages in the format above, function forwards to Gemini.
*/

// MARK: - Future Considerations

/*
 FUTURE: Video and Audio Support
 Gemini supports video and audio files. Future phases may add:
 - AttachmentMimeType cases for video/mp4, audio/mp3, etc.
 - Token estimation for video (per-second cost)
 - Duration-based size limits

 FUTURE: Streaming with Attachments
 Current streaming implementation is text-only.
 Future phases may support:
 - Streaming responses that reference attachments
 - Incremental file uploads during conversation

 FUTURE: File Caching
 Large files uploaded via Files API can be reused.
 Future phases may implement:
 - Cache of UploadedFileReference by file hash
 - Expiration tracking and refresh
 - Deduplication of identical files

 FUTURE: Image Generation
 Gemini can generate images in responses.
 Future phases may add:
 - Response parsing for generated images
 - Display of inline image responses
 - Save/export of generated content
*/
