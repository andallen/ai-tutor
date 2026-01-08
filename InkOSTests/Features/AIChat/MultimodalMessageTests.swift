// MultimodalMessageTests.swift
// Comprehensive tests for the MultimodalMessageContract types.
// These tests validate interface usability, happy paths, sad paths, and edge cases
// as specified in the Contract.swift acceptance criteria.
// Phase 3 of Document Upload Handling: Multimodal API message types.

import XCTest

@testable import InkOS

// MARK: - APIInlineData Tests

final class APIInlineDataTests: XCTestCase {

  // MARK: - Initialization Tests

  // Tests that APIInlineData initializes with explicit mimeType and data values.
  func test_init_withExplicitValues_setsAllProperties() {
    let inlineData = APIInlineData(mimeType: "image/png", data: "iVBORw0KGgo...")

    XCTAssertEqual(inlineData.mimeType, "image/png")
    XCTAssertEqual(inlineData.data, "iVBORw0KGgo...")
  }

  // Tests that APIInlineData initializes from FileAttachment.
  func test_init_fromFileAttachment_setsCorrectValues() {
    let attachment = FileAttachment(
      id: "test-id",
      filename: "photo.jpeg",
      mimeType: .jpeg,
      sizeBytes: 5000,
      base64Data: "abc123...",
      estimatedTokens: 258
    )

    let inlineData = APIInlineData(from: attachment)

    XCTAssertEqual(inlineData.mimeType, "image/jpeg")
    XCTAssertEqual(inlineData.data, "abc123...")
  }

  // Tests that init from FileAttachment uses rawValue from AttachmentMimeType enum.
  func test_init_fromFileAttachment_usesRawValueForMimeType() {
    let pngAttachment = FileAttachment(
      id: "png-id",
      filename: "image.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "pngdata",
      estimatedTokens: nil
    )

    let pdfAttachment = FileAttachment(
      id: "pdf-id",
      filename: "doc.pdf",
      mimeType: .pdf,
      sizeBytes: 2000,
      base64Data: "pdfdata",
      estimatedTokens: nil
    )

    let pngInline = APIInlineData(from: pngAttachment)
    let pdfInline = APIInlineData(from: pdfAttachment)

    XCTAssertEqual(pngInline.mimeType, AttachmentMimeType.png.rawValue)
    XCTAssertEqual(pdfInline.mimeType, AttachmentMimeType.pdf.rawValue)
  }

  // MARK: - Codable Tests

  // Tests encoding APIInlineData to JSON produces correct format.
  func test_codable_encode_producesCorrectJSON() throws {
    let inlineData = APIInlineData(mimeType: "image/png", data: "base64string")

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(inlineData)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["mimeType"] as? String, "image/png")
    XCTAssertEqual(json?["data"] as? String, "base64string")
  }

  // Tests decoding APIInlineData from JSON creates correct instance.
  func test_codable_decode_createsCorrectInstance() throws {
    let json = """
    {"mimeType":"image/png","data":"base64string"}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let inlineData = try decoder.decode(APIInlineData.self, from: data)

    XCTAssertEqual(inlineData.mimeType, "image/png")
    XCTAssertEqual(inlineData.data, "base64string")
  }

  // Tests Codable round-trip preserves all values.
  func test_codable_roundTrip_preservesAllValues() throws {
    let original = APIInlineData(mimeType: "application/pdf", data: "UERGIGRhdGE=")

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(APIInlineData.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - Equatable Tests

  // Tests that equal APIInlineData instances compare as equal.
  func test_equatable_identicalInstances_areEqual() {
    let inlineData1 = APIInlineData(mimeType: "image/png", data: "abc123")
    let inlineData2 = APIInlineData(mimeType: "image/png", data: "abc123")

    XCTAssertEqual(inlineData1, inlineData2)
  }

  // Tests that APIInlineData instances with different mimeType are not equal.
  func test_equatable_differentMimeType_areNotEqual() {
    let inlineData1 = APIInlineData(mimeType: "image/png", data: "abc123")
    let inlineData2 = APIInlineData(mimeType: "image/jpeg", data: "abc123")

    XCTAssertNotEqual(inlineData1, inlineData2)
  }

  // Tests that APIInlineData instances with different data are not equal.
  func test_equatable_differentData_areNotEqual() {
    let inlineData1 = APIInlineData(mimeType: "image/png", data: "abc123")
    let inlineData2 = APIInlineData(mimeType: "image/png", data: "xyz789")

    XCTAssertNotEqual(inlineData1, inlineData2)
  }

  // MARK: - Edge Case Tests

  // Tests that empty data string is valid (validation happens at higher layer).
  func test_edgeCase_emptyDataString_isValid() {
    let inlineData = APIInlineData(mimeType: "image/png", data: "")

    XCTAssertEqual(inlineData.data, "")
  }

  // Tests that MIME type with parameters is stored as-is.
  func test_edgeCase_mimeTypeWithParameters_preservesParameters() {
    let inlineData = APIInlineData(mimeType: "text/plain; charset=utf-8", data: "dGVzdA==")

    XCTAssertEqual(inlineData.mimeType, "text/plain; charset=utf-8")
  }

  // Tests that very long base64 data is preserved without truncation.
  func test_edgeCase_longBase64Data_isPreservedCompletely() throws {
    // Create a string of 10,000 characters to simulate large base64 data.
    let longData = String(repeating: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", count: 156)
    let inlineData = APIInlineData(mimeType: "image/png", data: longData)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(inlineData)
    let decoded = try decoder.decode(APIInlineData.self, from: encoded)

    XCTAssertEqual(decoded.data, longData)
    XCTAssertEqual(decoded.data.count, longData.count)
  }
}

// MARK: - APIFileData Tests

final class APIFileDataTests: XCTestCase {

  // MARK: - Initialization Tests

  // Tests that APIFileData initializes with explicit fileUri and mimeType.
  func test_init_withExplicitValues_setsAllProperties() {
    let fileData = APIFileData(fileUri: "files/abc123", mimeType: "application/pdf")

    XCTAssertEqual(fileData.fileUri, "files/abc123")
    XCTAssertEqual(fileData.mimeType, "application/pdf")
  }

  // Tests that APIFileData initializes from UploadedFileReference.
  func test_init_fromUploadedFileReference_setsCorrectValues() {
    let reference = UploadedFileReference(
      fileUri: "files/xyz789",
      mimeType: "image/png",
      name: "photo.png",
      expiresAt: "2024-12-31T23:59:59Z"
    )

    let fileData = APIFileData(from: reference)

    XCTAssertEqual(fileData.fileUri, "files/xyz789")
    XCTAssertEqual(fileData.mimeType, "image/png")
  }

  // MARK: - Codable Tests

  // Tests encoding APIFileData to JSON produces correct format.
  func test_codable_encode_producesCorrectJSON() throws {
    let fileData = APIFileData(fileUri: "files/abc", mimeType: "image/png")

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(fileData)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["fileUri"] as? String, "files/abc")
    XCTAssertEqual(json?["mimeType"] as? String, "image/png")
  }

  // Tests decoding APIFileData from JSON creates correct instance.
  func test_codable_decode_createsCorrectInstance() throws {
    let json = """
    {"fileUri":"files/abc","mimeType":"image/png"}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let fileData = try decoder.decode(APIFileData.self, from: data)

    XCTAssertEqual(fileData.fileUri, "files/abc")
    XCTAssertEqual(fileData.mimeType, "image/png")
  }

  // Tests Codable round-trip preserves all values.
  func test_codable_roundTrip_preservesAllValues() throws {
    let original = APIFileData(fileUri: "files/round-trip", mimeType: "application/pdf")

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(APIFileData.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - Equatable Tests

  // Tests that equal APIFileData instances compare as equal.
  func test_equatable_identicalInstances_areEqual() {
    let fileData1 = APIFileData(fileUri: "files/abc", mimeType: "image/png")
    let fileData2 = APIFileData(fileUri: "files/abc", mimeType: "image/png")

    XCTAssertEqual(fileData1, fileData2)
  }

  // Tests that APIFileData instances with different fileUri are not equal.
  func test_equatable_differentFileUri_areNotEqual() {
    let fileData1 = APIFileData(fileUri: "files/abc", mimeType: "image/png")
    let fileData2 = APIFileData(fileUri: "files/xyz", mimeType: "image/png")

    XCTAssertNotEqual(fileData1, fileData2)
  }

  // Tests that APIFileData instances with different mimeType are not equal.
  func test_equatable_differentMimeType_areNotEqual() {
    let fileData1 = APIFileData(fileUri: "files/abc", mimeType: "image/png")
    let fileData2 = APIFileData(fileUri: "files/abc", mimeType: "application/pdf")

    XCTAssertNotEqual(fileData1, fileData2)
  }

  // MARK: - Edge Case Tests

  // Tests that full URL as fileUri is stored as-is.
  func test_edgeCase_fullURLFileUri_isStoredAsIs() {
    let fullUrl = "https://generativelanguage.googleapis.com/v1/files/abc123"
    let fileData = APIFileData(fileUri: fullUrl, mimeType: "image/png")

    XCTAssertEqual(fileData.fileUri, fullUrl)
  }

  // Tests that empty fileUri is valid (validation at API layer).
  func test_edgeCase_emptyFileUri_isValid() {
    let fileData = APIFileData(fileUri: "", mimeType: "image/png")

    XCTAssertEqual(fileData.fileUri, "")
  }

  // Tests that fileUri with special characters is stored as-is.
  func test_edgeCase_fileUriWithSpecialCharacters_isStoredAsIs() {
    let fileUri = "files/abc%20def%2B123"
    let fileData = APIFileData(fileUri: fileUri, mimeType: "application/pdf")

    XCTAssertEqual(fileData.fileUri, fileUri)
  }
}

// MARK: - APIMessagePart Tests

final class APIMessagePartTests: XCTestCase {

  // MARK: - Initialization Tests

  // Tests creating a text part.
  func test_init_textPart_containsCorrectText() {
    let part = APIMessagePart.text("Hello, world!")

    if case .text(let text) = part {
      XCTAssertEqual(text, "Hello, world!")
    } else {
      XCTFail("Expected text part")
    }
  }

  // Tests creating an inline data part.
  func test_init_inlineDataPart_containsCorrectData() {
    let inlineData = APIInlineData(mimeType: "image/png", data: "abc123")
    let part = APIMessagePart.inlineData(inlineData)

    if case .inlineData(let data) = part {
      XCTAssertEqual(data.mimeType, "image/png")
      XCTAssertEqual(data.data, "abc123")
    } else {
      XCTFail("Expected inlineData part")
    }
  }

  // Tests creating a file data part.
  func test_init_fileDataPart_containsCorrectReference() {
    let fileData = APIFileData(fileUri: "files/xyz", mimeType: "application/pdf")
    let part = APIMessagePart.fileData(fileData)

    if case .fileData(let data) = part {
      XCTAssertEqual(data.fileUri, "files/xyz")
      XCTAssertEqual(data.mimeType, "application/pdf")
    } else {
      XCTFail("Expected fileData part")
    }
  }

  // MARK: - Equatable Tests

  // Tests that equal text parts compare as equal.
  func test_equatable_sameTextParts_areEqual() {
    let part1 = APIMessagePart.text("same text")
    let part2 = APIMessagePart.text("same text")

    XCTAssertEqual(part1, part2)
  }

  // Tests that text parts with different content are not equal.
  func test_equatable_differentTextParts_areNotEqual() {
    let part1 = APIMessagePart.text("hello")
    let part2 = APIMessagePart.text("world")

    XCTAssertNotEqual(part1, part2)
  }

  // Tests that different part types are not equal.
  func test_equatable_differentPartTypes_areNotEqual() {
    let textPart = APIMessagePart.text("hello")
    let inlineData = APIInlineData(mimeType: "image/png", data: "abc")
    let inlineDataPart = APIMessagePart.inlineData(inlineData)

    XCTAssertNotEqual(textPart, inlineDataPart)
  }

  // Tests that equal inline data parts compare as equal.
  func test_equatable_sameInlineDataParts_areEqual() {
    let inlineData = APIInlineData(mimeType: "image/png", data: "abc123")
    let part1 = APIMessagePart.inlineData(inlineData)
    let part2 = APIMessagePart.inlineData(inlineData)

    XCTAssertEqual(part1, part2)
  }

  // Tests that equal file data parts compare as equal.
  func test_equatable_sameFileDataParts_areEqual() {
    let fileData = APIFileData(fileUri: "files/abc", mimeType: "application/pdf")
    let part1 = APIMessagePart.fileData(fileData)
    let part2 = APIMessagePart.fileData(fileData)

    XCTAssertEqual(part1, part2)
  }

  // MARK: - Encoding Tests

  // Tests encoding text part to JSON produces {"text":"..."}.
  func test_codable_encodeTextPart_producesCorrectJSON() throws {
    let part = APIMessagePart.text("Hello, world!")

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(part)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["text"] as? String, "Hello, world!")
    XCTAssertNil(json?["inlineData"])
    XCTAssertNil(json?["fileData"])
  }

  // Tests encoding inline data part to JSON produces nested structure.
  func test_codable_encodeInlineDataPart_producesCorrectJSON() throws {
    let inlineData = APIInlineData(mimeType: "image/png", data: "abc123")
    let part = APIMessagePart.inlineData(inlineData)

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(part)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    let nestedInlineData = json?["inlineData"] as? [String: Any]
    XCTAssertNotNil(nestedInlineData)
    XCTAssertEqual(nestedInlineData?["mimeType"] as? String, "image/png")
    XCTAssertEqual(nestedInlineData?["data"] as? String, "abc123")
    XCTAssertNil(json?["text"])
    XCTAssertNil(json?["fileData"])
  }

  // Tests encoding file data part to JSON produces nested structure.
  func test_codable_encodeFileDataPart_producesCorrectJSON() throws {
    let fileData = APIFileData(fileUri: "files/xyz", mimeType: "application/pdf")
    let part = APIMessagePart.fileData(fileData)

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(part)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    let nestedFileData = json?["fileData"] as? [String: Any]
    XCTAssertNotNil(nestedFileData)
    XCTAssertEqual(nestedFileData?["fileUri"] as? String, "files/xyz")
    XCTAssertEqual(nestedFileData?["mimeType"] as? String, "application/pdf")
    XCTAssertNil(json?["text"])
    XCTAssertNil(json?["inlineData"])
  }

  // Tests encoding empty text part.
  func test_codable_encodeEmptyTextPart_producesEmptyString() throws {
    let part = APIMessagePart.text("")

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(part)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["text"] as? String, "")
  }

  // Tests encoding text with special characters properly escapes them.
  func test_codable_encodeTextWithSpecialCharacters_escapesCorrectly() throws {
    let part = APIMessagePart.text("Hello\nWorld\t\"quoted\"")

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(part)

    // Verify round-trip preserves special characters.
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(APIMessagePart.self, from: jsonData)

    if case .text(let text) = decoded {
      XCTAssertEqual(text, "Hello\nWorld\t\"quoted\"")
    } else {
      XCTFail("Expected text part")
    }
  }

  // Tests encoding text with unicode characters.
  func test_codable_encodeTextWithUnicode_preservesCharacters() throws {
    let part = APIMessagePart.text("Hello World")

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(part)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(APIMessagePart.self, from: jsonData)

    if case .text(let text) = decoded {
      XCTAssertEqual(text, "Hello World")
    } else {
      XCTFail("Expected text part")
    }
  }

  // MARK: - Decoding Tests

  // Tests decoding text part from JSON.
  func test_codable_decodeTextPart_createsCorrectInstance() throws {
    let json = """
    {"text":"Hello, world!"}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let part = try decoder.decode(APIMessagePart.self, from: data)

    XCTAssertEqual(part, .text("Hello, world!"))
  }

  // Tests decoding inline data part from JSON.
  func test_codable_decodeInlineDataPart_createsCorrectInstance() throws {
    let json = """
    {"inlineData":{"mimeType":"image/png","data":"abc123"}}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let part = try decoder.decode(APIMessagePart.self, from: data)

    if case .inlineData(let inlineData) = part {
      XCTAssertEqual(inlineData.mimeType, "image/png")
      XCTAssertEqual(inlineData.data, "abc123")
    } else {
      XCTFail("Expected inlineData part")
    }
  }

  // Tests decoding file data part from JSON.
  func test_codable_decodeFileDataPart_createsCorrectInstance() throws {
    let json = """
    {"fileData":{"fileUri":"files/xyz","mimeType":"application/pdf"}}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let part = try decoder.decode(APIMessagePart.self, from: data)

    if case .fileData(let fileData) = part {
      XCTAssertEqual(fileData.fileUri, "files/xyz")
      XCTAssertEqual(fileData.mimeType, "application/pdf")
    } else {
      XCTFail("Expected fileData part")
    }
  }

  // Tests decoding empty JSON object throws error.
  func test_codable_decodeEmptyObject_throwsDataCorruptedError() throws {
    let json = "{}"

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try decoder.decode(APIMessagePart.self, from: data)) { error in
      guard case DecodingError.dataCorrupted(let context) = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        return
      }
      XCTAssertTrue(context.debugDescription.contains("text"))
      XCTAssertTrue(context.debugDescription.contains("inlineData"))
      XCTAssertTrue(context.debugDescription.contains("fileData"))
    }
  }

  // Tests decoding JSON with unknown key throws error.
  func test_codable_decodeUnknownKey_throwsDataCorruptedError() throws {
    let json = """
    {"unknownKey":"value"}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try decoder.decode(APIMessagePart.self, from: data)) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        return
      }
    }
  }

  // Tests decoding JSON with multiple keys uses first match (text priority).
  func test_codable_decodeMultipleKeys_usesTextFirst() throws {
    let json = """
    {"text":"hello","inlineData":{"mimeType":"image/png","data":"abc"}}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let part = try decoder.decode(APIMessagePart.self, from: data)

    XCTAssertEqual(part, .text("hello"))
  }

  // MARK: - Round-Trip Tests

  // Tests round-trip encoding/decoding preserves text part.
  func test_codable_roundTrip_textPart_preservesData() throws {
    let original = APIMessagePart.text("Test message content")

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(APIMessagePart.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // Tests round-trip encoding/decoding preserves inline data part.
  func test_codable_roundTrip_inlineDataPart_preservesData() throws {
    let inlineData = APIInlineData(mimeType: "image/jpeg", data: "longbase64data==")
    let original = APIMessagePart.inlineData(inlineData)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(APIMessagePart.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // Tests round-trip encoding/decoding preserves file data part.
  func test_codable_roundTrip_fileDataPart_preservesData() throws {
    let fileData = APIFileData(fileUri: "files/document-id", mimeType: "application/pdf")
    let original = APIMessagePart.fileData(fileData)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(APIMessagePart.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - Edge Case Tests

  // Tests decoding null value for text key throws error.
  func test_codable_decodeNullText_throwsError() throws {
    let json = """
    {"text":null}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try decoder.decode(APIMessagePart.self, from: data))
  }

  // Tests decoding invalid inlineData structure throws error.
  func test_codable_decodeInvalidInlineDataStructure_throwsError() throws {
    let json = """
    {"inlineData":"not an object"}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try decoder.decode(APIMessagePart.self, from: data)) { error in
      guard case DecodingError.typeMismatch = error else {
        XCTFail("Expected DecodingError.typeMismatch, got \(error)")
        return
      }
    }
  }

  // Tests decoding inlineData with missing required field throws error.
  func test_codable_decodeInlineDataMissingField_throwsError() throws {
    let json = """
    {"inlineData":{"mimeType":"image/png"}}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try decoder.decode(APIMessagePart.self, from: data)) { error in
      guard case DecodingError.keyNotFound(let key, _) = error else {
        XCTFail("Expected DecodingError.keyNotFound, got \(error)")
        return
      }
      XCTAssertEqual(key.stringValue, "data")
    }
  }

  // Tests decoding fileData with missing required field throws error.
  func test_codable_decodeFileDataMissingField_throwsError() throws {
    let json = """
    {"fileData":{"fileUri":"files/abc"}}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try decoder.decode(APIMessagePart.self, from: data)) { error in
      guard case DecodingError.keyNotFound(let key, _) = error else {
        XCTFail("Expected DecodingError.keyNotFound, got \(error)")
        return
      }
      XCTAssertEqual(key.stringValue, "mimeType")
    }
  }

  // Tests decoding with extra fields in nested objects ignores them.
  func test_codable_decodeWithExtraFields_ignoresThem() throws {
    let json = """
    {"inlineData":{"mimeType":"image/png","data":"abc","extra":"ignored"}}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let part = try decoder.decode(APIMessagePart.self, from: data)

    if case .inlineData(let inlineData) = part {
      XCTAssertEqual(inlineData.mimeType, "image/png")
      XCTAssertEqual(inlineData.data, "abc")
    } else {
      XCTFail("Expected inlineData part")
    }
  }

  // Tests decoding with whitespace in JSON succeeds.
  func test_codable_decodeWithWhitespace_succeeds() throws {
    let json = """
    {
      "text": "Hello, world!"
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let part = try decoder.decode(APIMessagePart.self, from: data)

    XCTAssertEqual(part, .text("Hello, world!"))
  }
}

// MARK: - APIMessageMultimodal Tests

final class APIMessageMultimodalTests: XCTestCase {

  // MARK: - Initialization Tests

  // Tests creating message with role and parts array.
  func test_init_withRoleAndParts_setsAllProperties() {
    let inlineData = APIInlineData(mimeType: "image/png", data: "imagedata")
    let parts: [APIMessagePart] = [
      .text("Hello"),
      .inlineData(inlineData)
    ]

    let message = APIMessageMultimodal(role: "user", parts: parts)

    XCTAssertEqual(message.role, "user")
    XCTAssertEqual(message.parts.count, 2)
    XCTAssertEqual(message.parts[0], .text("Hello"))
    if case .inlineData(let data) = message.parts[1] {
      XCTAssertEqual(data.mimeType, "image/png")
    } else {
      XCTFail("Expected inlineData part")
    }
  }

  // Tests text-only convenience initializer.
  func test_init_textOnlyConvenience_createsSingleTextPart() {
    let message = APIMessageMultimodal(role: "user", text: "Hello, world!")

    XCTAssertEqual(message.role, "user")
    XCTAssertEqual(message.parts.count, 1)
    XCTAssertEqual(message.parts[0], .text("Hello, world!"))
  }

  // Tests conversion from legacy APIMessage.
  func test_init_fromAPIMessage_convertsCorrectly() {
    let apiMessage = APIMessage(role: "user", content: "Hello")

    let multimodal = APIMessageMultimodal(from: apiMessage)

    XCTAssertEqual(multimodal.role, "user")
    XCTAssertEqual(multimodal.parts.count, 1)
    XCTAssertEqual(multimodal.parts[0], .text("Hello"))
  }

  // Tests conversion from APIMessage created from ChatMessage.
  func test_init_fromAPIMessageCreatedFromChatMessage_preservesContent() {
    let chatMessage = ChatMessage(
      id: "msg-1",
      conversationID: "conv-1",
      role: .user,
      content: "Hi there",
      timestamp: Date(),
      contextMetadata: nil,
      tokenMetadata: nil
    )
    let apiMessage = APIMessage(from: chatMessage)
    let multimodal = APIMessageMultimodal(from: apiMessage)

    XCTAssertEqual(multimodal.role, "user")
    XCTAssertEqual(multimodal.parts[0], .text("Hi there"))
  }

  // Tests creating message with model role.
  func test_init_withModelRole_setsModelRole() {
    let message = APIMessageMultimodal(role: "model", text: "I can help with that.")

    XCTAssertEqual(message.role, "model")
    XCTAssertEqual(message.parts[0], .text("I can help with that."))
  }

  // MARK: - Codable Tests

  // Tests encoding text-only message to JSON.
  func test_codable_encodeTextOnlyMessage_producesCorrectJSON() throws {
    let message = APIMessageMultimodal(role: "user", text: "Hello")

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(message)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["role"] as? String, "user")
    let parts = json?["parts"] as? [[String: Any]]
    XCTAssertEqual(parts?.count, 1)
    XCTAssertEqual(parts?[0]["text"] as? String, "Hello")
  }

  // Tests encoding multipart message preserves order.
  func test_codable_encodeMultipartMessage_preservesOrder() throws {
    let inlineData = APIInlineData(mimeType: "image/png", data: "imagedata")
    let parts: [APIMessagePart] = [
      .text("What is in this image?"),
      .inlineData(inlineData)
    ]
    let message = APIMessageMultimodal(role: "user", parts: parts)

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(message)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    let partsJson = json?["parts"] as? [[String: Any]]
    XCTAssertEqual(partsJson?.count, 2)
    XCTAssertNotNil(partsJson?[0]["text"])
    XCTAssertNotNil(partsJson?[1]["inlineData"])
  }

  // Tests encoding message with all part types.
  func test_codable_encodeAllPartTypes_producesCorrectStructure() throws {
    let inlineData = APIInlineData(mimeType: "image/png", data: "imgdata")
    let fileData = APIFileData(fileUri: "files/doc", mimeType: "application/pdf")
    let parts: [APIMessagePart] = [
      .text("Describe these files"),
      .inlineData(inlineData),
      .fileData(fileData)
    ]
    let message = APIMessageMultimodal(role: "user", parts: parts)

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(message)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["role"] as? String, "user")
    let partsJson = json?["parts"] as? [[String: Any]]
    XCTAssertEqual(partsJson?.count, 3)
    XCTAssertNotNil(partsJson?[0]["text"])
    XCTAssertNotNil(partsJson?[1]["inlineData"])
    XCTAssertNotNil(partsJson?[2]["fileData"])
  }

  // Tests decoding multipart message from JSON.
  func test_codable_decodeMultipartMessage_createsCorrectInstance() throws {
    let json = """
    {
      "role": "user",
      "parts": [
        {"text": "Hello"},
        {"inlineData": {"mimeType": "image/png", "data": "abc123"}}
      ]
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let message = try decoder.decode(APIMessageMultimodal.self, from: data)

    XCTAssertEqual(message.role, "user")
    XCTAssertEqual(message.parts.count, 2)
    XCTAssertEqual(message.parts[0], .text("Hello"))
    if case .inlineData(let inlineData) = message.parts[1] {
      XCTAssertEqual(inlineData.mimeType, "image/png")
    } else {
      XCTFail("Expected inlineData part")
    }
  }

  // Tests decoding empty parts array is valid.
  func test_codable_decodeEmptyPartsArray_isValid() throws {
    let json = """
    {"role":"user","parts":[]}
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let message = try decoder.decode(APIMessageMultimodal.self, from: data)

    XCTAssertEqual(message.role, "user")
    XCTAssertTrue(message.parts.isEmpty)
  }

  // Tests Codable round-trip preserves all values.
  func test_codable_roundTrip_preservesAllValues() throws {
    let inlineData = APIInlineData(mimeType: "image/jpeg", data: "jpegdata")
    let fileData = APIFileData(fileUri: "files/abc", mimeType: "application/pdf")
    let original = APIMessageMultimodal(
      role: "user",
      parts: [
        .text("Analyze these"),
        .inlineData(inlineData),
        .fileData(fileData)
      ]
    )

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(APIMessageMultimodal.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - Equatable Tests

  // Tests that equal messages compare as equal.
  func test_equatable_identicalMessages_areEqual() {
    let message1 = APIMessageMultimodal(role: "user", text: "Hello")
    let message2 = APIMessageMultimodal(role: "user", text: "Hello")

    XCTAssertEqual(message1, message2)
  }

  // Tests that messages with different roles are not equal.
  func test_equatable_differentRoles_areNotEqual() {
    let message1 = APIMessageMultimodal(role: "user", text: "Hello")
    let message2 = APIMessageMultimodal(role: "model", text: "Hello")

    XCTAssertNotEqual(message1, message2)
  }

  // Tests that messages with different parts are not equal.
  func test_equatable_differentParts_areNotEqual() {
    let message1 = APIMessageMultimodal(role: "user", text: "Hello")
    let message2 = APIMessageMultimodal(role: "user", text: "World")

    XCTAssertNotEqual(message1, message2)
  }

  // Tests that messages with same parts in different order are not equal.
  func test_equatable_samePartsInDifferentOrder_areNotEqual() {
    let parts1: [APIMessagePart] = [.text("a"), .text("b")]
    let parts2: [APIMessagePart] = [.text("b"), .text("a")]

    let message1 = APIMessageMultimodal(role: "user", parts: parts1)
    let message2 = APIMessageMultimodal(role: "user", parts: parts2)

    XCTAssertNotEqual(message1, message2)
  }

  // MARK: - Edge Case Tests

  // Tests empty parts array is valid (API validation at higher layer).
  func test_edgeCase_emptyPartsArray_isValid() {
    let message = APIMessageMultimodal(role: "user", parts: [])

    XCTAssertTrue(message.parts.isEmpty)
  }

  // Tests message with many parts preserves all.
  func test_edgeCase_manyParts_preservesAll() throws {
    var parts: [APIMessagePart] = []
    for i in 0..<100 {
      parts.append(.text("Part \(i)"))
    }

    let message = APIMessageMultimodal(role: "user", parts: parts)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(message)
    let decoded = try decoder.decode(APIMessageMultimodal.self, from: encoded)

    XCTAssertEqual(decoded.parts.count, 100)
    XCTAssertEqual(decoded, message)
  }

  // Tests message with large text part.
  func test_edgeCase_largeTextPart_preservesContent() throws {
    let largeText = String(repeating: "A", count: 100_000)
    let message = APIMessageMultimodal(role: "user", text: largeText)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(message)
    let decoded = try decoder.decode(APIMessageMultimodal.self, from: encoded)

    if case .text(let text) = decoded.parts[0] {
      XCTAssertEqual(text.count, 100_000)
    } else {
      XCTFail("Expected text part")
    }
  }

  // Tests message with multiple text parts are not concatenated.
  func test_edgeCase_multipleTextParts_areNotConcatenated() {
    let parts: [APIMessagePart] = [.text("Hello"), .text("World")]
    let message = APIMessageMultimodal(role: "user", parts: parts)

    XCTAssertEqual(message.parts.count, 2)
    XCTAssertEqual(message.parts[0], .text("Hello"))
    XCTAssertEqual(message.parts[1], .text("World"))
  }

  // Tests unexpected role value is stored as-is.
  func test_edgeCase_unexpectedRoleValue_storedAsIs() {
    let message = APIMessageMultimodal(role: "system", text: "System prompt")

    XCTAssertEqual(message.role, "system")
  }

  // Tests mixed inline and file data parts.
  func test_edgeCase_mixedInlineAndFileData_preservesAll() throws {
    var parts: [APIMessagePart] = []
    for i in 0..<5 {
      let inlineData = APIInlineData(mimeType: "image/png", data: "inline\(i)")
      parts.append(.inlineData(inlineData))
    }
    for i in 0..<3 {
      let fileData = APIFileData(fileUri: "files/file\(i)", mimeType: "application/pdf")
      parts.append(.fileData(fileData))
    }

    let message = APIMessageMultimodal(role: "user", parts: parts)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(message)
    let decoded = try decoder.decode(APIMessageMultimodal.self, from: encoded)

    XCTAssertEqual(decoded.parts.count, 8)
    XCTAssertEqual(decoded, message)
  }
}

// MARK: - Array<APIMessage>.toMultimodal() Tests

final class APIMessageToMultimodalExtensionTests: XCTestCase {

  // Tests converting empty array returns empty array.
  func test_toMultimodal_emptyArray_returnsEmptyArray() {
    let messages: [APIMessage] = []

    let result = messages.toMultimodal()

    XCTAssertTrue(result.isEmpty)
  }

  // Tests converting single message.
  func test_toMultimodal_singleMessage_returnsCorrectMultimodal() {
    let messages = [APIMessage(role: "user", content: "Hello")]

    let result = messages.toMultimodal()

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].role, "user")
    XCTAssertEqual(result[0].parts.count, 1)
    XCTAssertEqual(result[0].parts[0], .text("Hello"))
  }

  // Tests converting multiple messages preserves order.
  func test_toMultimodal_multipleMessages_preservesOrder() {
    let messages = [
      APIMessage(role: "user", content: "Question 1"),
      APIMessage(role: "model", content: "Answer 1"),
      APIMessage(role: "user", content: "Question 2")
    ]

    let result = messages.toMultimodal()

    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result[0].role, "user")
    XCTAssertEqual(result[0].parts[0], .text("Question 1"))
    XCTAssertEqual(result[1].role, "model")
    XCTAssertEqual(result[1].parts[0], .text("Answer 1"))
    XCTAssertEqual(result[2].role, "user")
    XCTAssertEqual(result[2].parts[0], .text("Question 2"))
  }

  // Tests conversation turn order is preserved.
  func test_toMultimodal_conversationTurnOrder_isPreserved() {
    let messages = [
      APIMessage(role: "user", content: "First"),
      APIMessage(role: "model", content: "Response 1"),
      APIMessage(role: "user", content: "Second"),
      APIMessage(role: "model", content: "Response 2")
    ]

    let result = messages.toMultimodal()

    XCTAssertEqual(result[0].role, "user")
    XCTAssertEqual(result[1].role, "model")
    XCTAssertEqual(result[2].role, "user")
    XCTAssertEqual(result[3].role, "model")
  }
}

// MARK: - MultimodalMessageError Tests

final class MultimodalMessageErrorTests: XCTestCase {

  // MARK: - errorDescription Tests

  // Tests emptyParts error message.
  func test_errorDescription_emptyParts_returnsCorrectMessage() {
    let error = MultimodalMessageError.emptyParts
    let description = error.errorDescription

    XCTAssertEqual(description, "Message must contain at least one part")
  }

  // Tests invalidPartType error message.
  func test_errorDescription_invalidPartType_containsExpectedAndActual() {
    let error = MultimodalMessageError.invalidPartType(expected: "text", actual: "inlineData")
    let description = error.errorDescription

    XCTAssertEqual(description, "Expected part type 'text' but got 'inlineData'")
  }

  // Tests tooManyParts error message.
  func test_errorDescription_tooManyParts_containsCountAndLimit() {
    let error = MultimodalMessageError.tooManyParts(count: 150, limit: 100)
    let description = error.errorDescription

    XCTAssertEqual(description, "Message contains 150 parts but maximum is 100")
  }

  // MARK: - Equatable Tests

  // Tests same error cases with same values are equal.
  func test_equatable_emptyParts_areEqual() {
    let error1 = MultimodalMessageError.emptyParts
    let error2 = MultimodalMessageError.emptyParts

    XCTAssertEqual(error1, error2)
  }

  // Tests tooManyParts with same values are equal.
  func test_equatable_tooManyParts_sameValues_areEqual() {
    let error1 = MultimodalMessageError.tooManyParts(count: 10, limit: 5)
    let error2 = MultimodalMessageError.tooManyParts(count: 10, limit: 5)

    XCTAssertEqual(error1, error2)
  }

  // Tests tooManyParts with different values are not equal.
  func test_equatable_tooManyParts_differentValues_areNotEqual() {
    let error1 = MultimodalMessageError.tooManyParts(count: 10, limit: 5)
    let error2 = MultimodalMessageError.tooManyParts(count: 20, limit: 5)

    XCTAssertNotEqual(error1, error2)
  }

  // Tests invalidPartType with same values are equal.
  func test_equatable_invalidPartType_sameValues_areEqual() {
    let error1 = MultimodalMessageError.invalidPartType(expected: "text", actual: "file")
    let error2 = MultimodalMessageError.invalidPartType(expected: "text", actual: "file")

    XCTAssertEqual(error1, error2)
  }

  // Tests invalidPartType with different values are not equal.
  func test_equatable_invalidPartType_differentValues_areNotEqual() {
    let error1 = MultimodalMessageError.invalidPartType(expected: "text", actual: "file")
    let error2 = MultimodalMessageError.invalidPartType(expected: "text", actual: "inline")

    XCTAssertNotEqual(error1, error2)
  }

  // Tests different error cases are not equal.
  func test_equatable_differentErrorCases_areNotEqual() {
    let error1 = MultimodalMessageError.emptyParts
    let error2 = MultimodalMessageError.tooManyParts(count: 10, limit: 5)

    XCTAssertNotEqual(error1, error2)
  }

  // MARK: - LocalizedError Conformance Tests

  // Tests that MultimodalMessageError conforms to LocalizedError.
  func test_localizedError_conformance_providesDescription() {
    let error: LocalizedError = MultimodalMessageError.emptyParts

    XCTAssertNotNil(error.errorDescription)
  }
}

// MARK: - MultimodalMessageConstants Tests

final class MultimodalMessageConstantsTests: XCTestCase {

  // Tests maxPartsPerMessage constant value.
  func test_maxPartsPerMessage_equals100() {
    XCTAssertEqual(MultimodalMessageConstants.maxPartsPerMessage, 100)
  }

  // Tests maxInlineDataParts constant value.
  func test_maxInlineDataParts_equals16() {
    XCTAssertEqual(MultimodalMessageConstants.maxInlineDataParts, 16)
  }

  // Tests maxInlineDataSize constant value (20MB).
  func test_maxInlineDataSize_equals20MB() {
    XCTAssertEqual(MultimodalMessageConstants.maxInlineDataSize, 20_971_520)
    XCTAssertEqual(MultimodalMessageConstants.maxInlineDataSize, 20 * 1024 * 1024)
  }
}

// MARK: - Integration Tests

final class MultimodalMessageIntegrationTests: XCTestCase {

  // Tests full conversion flow: FileAttachment -> APIInlineData -> APIMessagePart -> APIMessageMultimodal.
  func test_fullConversionFlow_fileAttachmentToMultimodal() throws {
    // Create FileAttachment.
    let attachment = FileAttachment(
      id: "attach-1",
      filename: "photo.jpeg",
      mimeType: .jpeg,
      sizeBytes: 50000,
      base64Data: "longbase64encodedimagedata==",
      estimatedTokens: 258
    )

    // Convert to APIInlineData.
    let inlineData = APIInlineData(from: attachment)

    // Create APIMessagePart.
    let part = APIMessagePart.inlineData(inlineData)

    // Create APIMessageMultimodal with text and inline data.
    let message = APIMessageMultimodal(
      role: "user",
      parts: [
        .text("What's in this image?"),
        part
      ]
    )

    // Encode to JSON and verify structure.
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(message)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["role"] as? String, "user")
    let parts = json?["parts"] as? [[String: Any]]
    XCTAssertEqual(parts?.count, 2)
    XCTAssertEqual(parts?[0]["text"] as? String, "What's in this image?")

    let nestedInline = parts?[1]["inlineData"] as? [String: Any]
    XCTAssertEqual(nestedInline?["mimeType"] as? String, "image/jpeg")
    XCTAssertEqual(nestedInline?["data"] as? String, "longbase64encodedimagedata==")
  }

  // Tests full conversion flow: UploadedFileReference -> APIFileData -> APIMessagePart -> APIMessageMultimodal.
  func test_fullConversionFlow_uploadedFileReferenceToMultimodal() throws {
    // Create UploadedFileReference.
    let reference = UploadedFileReference(
      fileUri: "files/document-abc123",
      mimeType: "application/pdf",
      name: "report.pdf",
      expiresAt: "2024-12-31T23:59:59Z"
    )

    // Convert to APIFileData.
    let fileData = APIFileData(from: reference)

    // Create APIMessagePart.
    let part = APIMessagePart.fileData(fileData)

    // Create APIMessageMultimodal.
    let message = APIMessageMultimodal(
      role: "user",
      parts: [
        .text("Summarize this document"),
        part
      ]
    )

    // Encode to JSON and verify structure.
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(message)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertEqual(json?["role"] as? String, "user")
    let parts = json?["parts"] as? [[String: Any]]
    XCTAssertEqual(parts?.count, 2)

    let nestedFile = parts?[1]["fileData"] as? [String: Any]
    XCTAssertEqual(nestedFile?["fileUri"] as? String, "files/document-abc123")
    XCTAssertEqual(nestedFile?["mimeType"] as? String, "application/pdf")
  }

  // Tests encoding array of APIMessageMultimodal matches Gemini API expected format.
  func test_encodeMessageArray_matchesGeminiAPIFormat() throws {
    let messages = [
      APIMessageMultimodal(role: "user", text: "What's in this image?"),
      APIMessageMultimodal(role: "model", text: "I can see a beautiful landscape."),
      APIMessageMultimodal(role: "user", text: "Describe it in more detail.")
    ]

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(messages)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]

    XCTAssertEqual(json?.count, 3)
    XCTAssertEqual(json?[0]["role"] as? String, "user")
    XCTAssertEqual(json?[1]["role"] as? String, "model")
    XCTAssertEqual(json?[2]["role"] as? String, "user")

    // Verify parts structure.
    for messageJson in json ?? [] {
      let parts = messageJson["parts"] as? [[String: Any]]
      XCTAssertNotNil(parts)
      XCTAssertGreaterThan(parts?.count ?? 0, 0)
    }
  }

  // Tests JSON output matches exact Gemini API format.
  func test_jsonOutput_matchesExactGeminiFormat() throws {
    let inlineData = APIInlineData(mimeType: "image/png", data: "abc123")
    let message = APIMessageMultimodal(
      role: "user",
      parts: [
        .text("Describe"),
        .inlineData(inlineData)
      ]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let jsonData = try encoder.encode(message)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    // Verify key structure matches Gemini API expectations.
    XCTAssertTrue(jsonString.contains("\"parts\""))
    XCTAssertTrue(jsonString.contains("\"role\""))
    XCTAssertTrue(jsonString.contains("\"text\""))
    XCTAssertTrue(jsonString.contains("\"inlineData\""))
    XCTAssertTrue(jsonString.contains("\"mimeType\""))
    XCTAssertTrue(jsonString.contains("\"data\""))
  }
}
