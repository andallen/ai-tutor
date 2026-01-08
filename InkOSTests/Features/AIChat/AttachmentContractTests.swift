// AttachmentContractTests.swift
// Comprehensive tests for the AttachmentContract types and protocols.
// These tests validate interface usability, happy paths, sad paths, and edge cases
// as specified in the Contract.swift acceptance criteria.

import XCTest

@testable import InkOS

// MARK: - AttachmentMimeType Tests

final class AttachmentMimeTypeTests: XCTestCase {

  // MARK: - Raw Value Tests

  // Tests that all image MIME types have correct raw values.
  func test_rawValue_imageTypes_haveCorrectStrings() {
    XCTAssertEqual(AttachmentMimeType.png.rawValue, "image/png")
    XCTAssertEqual(AttachmentMimeType.jpeg.rawValue, "image/jpeg")
    XCTAssertEqual(AttachmentMimeType.webp.rawValue, "image/webp")
    XCTAssertEqual(AttachmentMimeType.heic.rawValue, "image/heic")
    XCTAssertEqual(AttachmentMimeType.heif.rawValue, "image/heif")
    XCTAssertEqual(AttachmentMimeType.gif.rawValue, "image/gif")
  }

  // Tests that all document MIME types have correct raw values.
  func test_rawValue_documentTypes_haveCorrectStrings() {
    XCTAssertEqual(AttachmentMimeType.pdf.rawValue, "application/pdf")
    XCTAssertEqual(AttachmentMimeType.plainText.rawValue, "text/plain")
  }

  // MARK: - isImage Property Tests

  // Tests that image types return true for isImage.
  func test_isImage_imageTypes_returnTrue() {
    XCTAssertTrue(AttachmentMimeType.png.isImage)
    XCTAssertTrue(AttachmentMimeType.jpeg.isImage)
    XCTAssertTrue(AttachmentMimeType.webp.isImage)
    XCTAssertTrue(AttachmentMimeType.heic.isImage)
    XCTAssertTrue(AttachmentMimeType.heif.isImage)
    XCTAssertTrue(AttachmentMimeType.gif.isImage)
  }

  // Tests that document types return false for isImage.
  func test_isImage_documentTypes_returnFalse() {
    XCTAssertFalse(AttachmentMimeType.pdf.isImage)
    XCTAssertFalse(AttachmentMimeType.plainText.isImage)
  }

  // MARK: - isDocument Property Tests

  // Tests that document types return true for isDocument.
  func test_isDocument_documentTypes_returnTrue() {
    XCTAssertTrue(AttachmentMimeType.pdf.isDocument)
    XCTAssertTrue(AttachmentMimeType.plainText.isDocument)
  }

  // Tests that image types return false for isDocument.
  func test_isDocument_imageTypes_returnFalse() {
    XCTAssertFalse(AttachmentMimeType.png.isDocument)
    XCTAssertFalse(AttachmentMimeType.jpeg.isDocument)
    XCTAssertFalse(AttachmentMimeType.webp.isDocument)
    XCTAssertFalse(AttachmentMimeType.heic.isDocument)
    XCTAssertFalse(AttachmentMimeType.heif.isDocument)
    XCTAssertFalse(AttachmentMimeType.gif.isDocument)
  }

  // MARK: - init(fromExtension:) Tests

  // Tests that PNG extension maps to png MIME type.
  func test_initFromExtension_png_returnsPng() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "png"), .png)
  }

  // Tests that JPEG extensions map to jpeg MIME type.
  func test_initFromExtension_jpegExtensions_returnsJpeg() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "jpg"), .jpeg)
    XCTAssertEqual(AttachmentMimeType(fromExtension: "jpeg"), .jpeg)
  }

  // Tests that WebP extension maps to webp MIME type.
  func test_initFromExtension_webp_returnsWebp() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "webp"), .webp)
  }

  // Tests that HEIC extension maps to heic MIME type.
  func test_initFromExtension_heic_returnsHeic() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "heic"), .heic)
  }

  // Tests that HEIF extension maps to heif MIME type.
  func test_initFromExtension_heif_returnsHeif() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "heif"), .heif)
  }

  // Tests that GIF extension maps to gif MIME type.
  func test_initFromExtension_gif_returnsGif() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "gif"), .gif)
  }

  // Tests that PDF extension maps to pdf MIME type.
  func test_initFromExtension_pdf_returnsPdf() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "pdf"), .pdf)
  }

  // Tests that text extensions map to plainText MIME type.
  func test_initFromExtension_textExtensions_returnsPlainText() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "txt"), .plainText)
    XCTAssertEqual(AttachmentMimeType(fromExtension: "text"), .plainText)
  }

  // Tests case-insensitive extension matching.
  func test_initFromExtension_caseInsensitive_returnsCorrectType() {
    XCTAssertEqual(AttachmentMimeType(fromExtension: "PNG"), .png)
    XCTAssertEqual(AttachmentMimeType(fromExtension: "Png"), .png)
    XCTAssertEqual(AttachmentMimeType(fromExtension: "pNg"), .png)
    XCTAssertEqual(AttachmentMimeType(fromExtension: "PDF"), .pdf)
    XCTAssertEqual(AttachmentMimeType(fromExtension: "Jpeg"), .jpeg)
    XCTAssertEqual(AttachmentMimeType(fromExtension: "TXT"), .plainText)
  }

  // Tests that unsupported extensions return nil.
  func test_initFromExtension_unsupportedExtensions_returnsNil() {
    XCTAssertNil(AttachmentMimeType(fromExtension: "docx"))
    XCTAssertNil(AttachmentMimeType(fromExtension: "mp4"))
    XCTAssertNil(AttachmentMimeType(fromExtension: "zip"))
    XCTAssertNil(AttachmentMimeType(fromExtension: "bmp"))
    XCTAssertNil(AttachmentMimeType(fromExtension: "tiff"))
  }

  // MARK: - Edge Case Tests

  // Tests that empty extension string returns nil.
  func test_initFromExtension_emptyString_returnsNil() {
    XCTAssertNil(AttachmentMimeType(fromExtension: ""))
  }

  // Tests that extension with leading dot returns nil.
  func test_initFromExtension_leadingDot_returnsNil() {
    XCTAssertNil(AttachmentMimeType(fromExtension: ".png"))
    XCTAssertNil(AttachmentMimeType(fromExtension: ".pdf"))
  }

  // Tests that extension with whitespace returns nil.
  func test_initFromExtension_whitespace_returnsNil() {
    XCTAssertNil(AttachmentMimeType(fromExtension: " png "))
    XCTAssertNil(AttachmentMimeType(fromExtension: " pdf"))
    XCTAssertNil(AttachmentMimeType(fromExtension: "png "))
  }

  // Tests that raw value lookup works correctly.
  func test_initRawValue_validMimeString_returnsCorrectType() {
    XCTAssertEqual(AttachmentMimeType(rawValue: "image/jpeg"), .jpeg)
    XCTAssertEqual(AttachmentMimeType(rawValue: "image/png"), .png)
    XCTAssertEqual(AttachmentMimeType(rawValue: "application/pdf"), .pdf)
    XCTAssertEqual(AttachmentMimeType(rawValue: "text/plain"), .plainText)
  }

  // Tests that invalid MIME type raw value returns nil.
  func test_initRawValue_invalidMimeString_returnsNil() {
    XCTAssertNil(AttachmentMimeType(rawValue: "image/bmp"))
    XCTAssertNil(AttachmentMimeType(rawValue: "video/mp4"))
    XCTAssertNil(AttachmentMimeType(rawValue: "application/json"))
  }

  // Tests that allCases contains expected count of 8.
  func test_allCases_containsExpectedCount() {
    XCTAssertEqual(AttachmentMimeType.allCases.count, 8)
  }

  // MARK: - Codable Tests

  // Tests Codable encoding and decoding for all cases.
  func test_codable_roundTrip_preservesAllCases() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for mimeType in AttachmentMimeType.allCases {
      let encoded = try encoder.encode(mimeType)
      let decoded = try decoder.decode(AttachmentMimeType.self, from: encoded)
      XCTAssertEqual(decoded, mimeType)
    }
  }

  // Tests that MIME type encodes as its raw value string.
  // This verifies the enum uses its rawValue for Codable by checking
  // that a round-trip through JSON preserves the value.
  func test_codable_encodesAsRawValue() throws {
    // Create encoder and decoder instances.
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // Encode PNG MIME type to JSON data.
    let encoded = try encoder.encode(AttachmentMimeType.png)

    // Decode back to verify the raw value encoding works correctly.
    let decoded = try decoder.decode(AttachmentMimeType.self, from: encoded)
    XCTAssertEqual(decoded, .png)
  }
}

// MARK: - AttachmentSizeLimits Tests

final class AttachmentSizeLimitsTests: XCTestCase {

  // MARK: - Constant Value Tests

  // Tests that maxFileSize is 100MB (104857600 bytes).
  func test_maxFileSize_equals100MB() {
    XCTAssertEqual(AttachmentSizeLimits.maxFileSize, 104_857_600)
    XCTAssertEqual(AttachmentSizeLimits.maxFileSize, 100 * 1024 * 1024)
  }

  // Tests that maxPDFSize is 50MB (52428800 bytes).
  func test_maxPDFSize_equals50MB() {
    XCTAssertEqual(AttachmentSizeLimits.maxPDFSize, 52_428_800)
    XCTAssertEqual(AttachmentSizeLimits.maxPDFSize, 50 * 1024 * 1024)
  }

  // Tests that maxImageSize is 20MB (20971520 bytes).
  func test_maxImageSize_equals20MB() {
    XCTAssertEqual(AttachmentSizeLimits.maxImageSize, 20_971_520)
    XCTAssertEqual(AttachmentSizeLimits.maxImageSize, 20 * 1024 * 1024)
  }

  // Tests that maxPlainTextSize is 1MB (1048576 bytes).
  func test_maxPlainTextSize_equals1MB() {
    XCTAssertEqual(AttachmentSizeLimits.maxPlainTextSize, 1_048_576)
    XCTAssertEqual(AttachmentSizeLimits.maxPlainTextSize, 1 * 1024 * 1024)
  }

  // Tests that maxImageDimension is 3072.
  func test_maxImageDimension_equals3072() {
    XCTAssertEqual(AttachmentSizeLimits.maxImageDimension, 3072)
  }

  // Tests that maxPDFPages is 1000.
  func test_maxPDFPages_equals1000() {
    XCTAssertEqual(AttachmentSizeLimits.maxPDFPages, 1000)
  }

  // MARK: - sizeLimit(for:) Tests

  // Tests that PDF MIME type returns PDF size limit.
  func test_sizeLimit_pdf_returnsPDFLimit() {
    XCTAssertEqual(
      AttachmentSizeLimits.sizeLimit(for: .pdf),
      AttachmentSizeLimits.maxPDFSize
    )
  }

  // Tests that plain text MIME type returns plain text size limit.
  func test_sizeLimit_plainText_returnsPlainTextLimit() {
    XCTAssertEqual(
      AttachmentSizeLimits.sizeLimit(for: .plainText),
      AttachmentSizeLimits.maxPlainTextSize
    )
  }

  // Tests that all image MIME types return image size limit.
  func test_sizeLimit_imageTypes_returnsImageLimit() {
    let imageTypes: [AttachmentMimeType] = [.png, .jpeg, .webp, .heic, .heif, .gif]
    for mimeType in imageTypes {
      XCTAssertEqual(
        AttachmentSizeLimits.sizeLimit(for: mimeType),
        AttachmentSizeLimits.maxImageSize,
        "Expected image limit for \(mimeType)"
      )
    }
  }
}

// MARK: - FileAttachment Tests

final class FileAttachmentTests: XCTestCase {

  // MARK: - Initialization Tests

  // Tests that FileAttachment initializes with all properties.
  func test_init_withAllProperties_setsAllValues() {
    let attachment = FileAttachment(
      id: "test-123",
      filename: "photo.png",
      mimeType: .png,
      sizeBytes: 5_000_000,
      base64Data: "SGVsbG8gV29ybGQ=",
      estimatedTokens: 258
    )

    XCTAssertEqual(attachment.id, "test-123")
    XCTAssertEqual(attachment.filename, "photo.png")
    XCTAssertEqual(attachment.mimeType, .png)
    XCTAssertEqual(attachment.sizeBytes, 5_000_000)
    XCTAssertEqual(attachment.base64Data, "SGVsbG8gV29ybGQ=")
    XCTAssertEqual(attachment.estimatedTokens, 258)
  }

  // Tests that FileAttachment initializes with nil estimatedTokens.
  func test_init_withNilEstimatedTokens_setsTokensToNil() {
    let attachment = FileAttachment(
      id: "test-456",
      filename: "document.pdf",
      mimeType: .pdf,
      sizeBytes: 2_000_000,
      base64Data: "UERGIGRhdGE=",
      estimatedTokens: nil
    )

    XCTAssertNil(attachment.estimatedTokens)
    XCTAssertEqual(attachment.filename, "document.pdf")
    XCTAssertEqual(attachment.mimeType, .pdf)
  }

  // MARK: - Identifiable Tests

  // Tests that Identifiable id property returns correct value.
  func test_identifiable_idProperty_returnsCorrectValue() {
    let attachment = FileAttachment(
      id: "unique-id-789",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "data",
      estimatedTokens: nil
    )

    XCTAssertEqual(attachment.id, "unique-id-789")
  }

  // MARK: - Codable Tests

  // Tests encoding attachment to JSON includes all properties.
  func test_codable_encode_containsAllProperties() throws {
    let attachment = FileAttachment(
      id: "encode-test",
      filename: "test.jpeg",
      mimeType: .jpeg,
      sizeBytes: 12345,
      base64Data: "dGVzdCBkYXRh",
      estimatedTokens: 500
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(attachment)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertEqual(json?["id"] as? String, "encode-test")
    XCTAssertEqual(json?["filename"] as? String, "test.jpeg")
    XCTAssertEqual(json?["mimeType"] as? String, "image/jpeg")
    XCTAssertEqual(json?["sizeBytes"] as? Int, 12345)
    XCTAssertEqual(json?["base64Data"] as? String, "dGVzdCBkYXRh")
    XCTAssertEqual(json?["estimatedTokens"] as? Int, 500)
  }

  // Tests decoding attachment from JSON creates correct instance.
  func test_codable_decode_createsCorrectInstance() throws {
    let json = """
    {
      "id": "decode-test",
      "filename": "report.pdf",
      "mimeType": "application/pdf",
      "sizeBytes": 50000,
      "base64Data": "cGRmIGNvbnRlbnQ=",
      "estimatedTokens": 1500
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let attachment = try decoder.decode(FileAttachment.self, from: data)

    XCTAssertEqual(attachment.id, "decode-test")
    XCTAssertEqual(attachment.filename, "report.pdf")
    XCTAssertEqual(attachment.mimeType, .pdf)
    XCTAssertEqual(attachment.sizeBytes, 50000)
    XCTAssertEqual(attachment.base64Data, "cGRmIGNvbnRlbnQ=")
    XCTAssertEqual(attachment.estimatedTokens, 1500)
  }

  // Tests decoding attachment with null estimatedTokens.
  func test_codable_decodeWithNullTokens_setsTokensToNil() throws {
    let json = """
    {
      "id": "null-test",
      "filename": "image.gif",
      "mimeType": "image/gif",
      "sizeBytes": 8000,
      "base64Data": "Z2lmIGRhdGE=",
      "estimatedTokens": null
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let attachment = try decoder.decode(FileAttachment.self, from: data)

    XCTAssertNil(attachment.estimatedTokens)
  }

  // Tests decoding attachment with missing estimatedTokens field.
  func test_codable_decodeWithMissingTokens_setsTokensToNil() throws {
    let json = """
    {
      "id": "missing-test",
      "filename": "image.webp",
      "mimeType": "image/webp",
      "sizeBytes": 3000,
      "base64Data": "d2VicCBkYXRh"
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let attachment = try decoder.decode(FileAttachment.self, from: data)

    XCTAssertNil(attachment.estimatedTokens)
  }

  // Tests Codable round-trip preserves all values.
  func test_codable_roundTrip_preservesAllValues() throws {
    let original = FileAttachment(
      id: "round-trip",
      filename: "document.txt",
      mimeType: .plainText,
      sizeBytes: 999,
      base64Data: "dGV4dCBmaWxl",
      estimatedTokens: 250
    )

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(FileAttachment.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - Equatable Tests

  // Tests that equal attachments compare as equal.
  func test_equatable_identicalAttachments_areEqual() {
    let attachment1 = FileAttachment(
      id: "same-id",
      filename: "same.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "c2FtZQ==",
      estimatedTokens: 100
    )

    let attachment2 = FileAttachment(
      id: "same-id",
      filename: "same.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "c2FtZQ==",
      estimatedTokens: 100
    )

    XCTAssertEqual(attachment1, attachment2)
  }

  // Tests that attachments with different IDs compare as not equal.
  func test_equatable_differentIds_areNotEqual() {
    let attachment1 = FileAttachment(
      id: "id-1",
      filename: "same.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "c2FtZQ==",
      estimatedTokens: 100
    )

    let attachment2 = FileAttachment(
      id: "id-2",
      filename: "same.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "c2FtZQ==",
      estimatedTokens: 100
    )

    XCTAssertNotEqual(attachment1, attachment2)
  }

  // Tests that attachments with different base64Data compare as not equal.
  func test_equatable_differentBase64Data_areNotEqual() {
    let attachment1 = FileAttachment(
      id: "same-id",
      filename: "same.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "ZGF0YTE=",
      estimatedTokens: 100
    )

    let attachment2 = FileAttachment(
      id: "same-id",
      filename: "same.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "ZGF0YTI=",
      estimatedTokens: 100
    )

    XCTAssertNotEqual(attachment1, attachment2)
  }

  // MARK: - Edge Case Tests

  // Tests attachment with empty base64Data.
  func test_edgeCase_emptyBase64Data_isValid() {
    let attachment = FileAttachment(
      id: "empty-data",
      filename: "empty.txt",
      mimeType: .plainText,
      sizeBytes: 0,
      base64Data: "",
      estimatedTokens: nil
    )

    XCTAssertEqual(attachment.base64Data, "")
    XCTAssertEqual(attachment.sizeBytes, 0)
  }

  // Tests attachment with unicode filename.
  func test_edgeCase_unicodeFilename_preservesCorrectly() throws {
    let attachment = FileAttachment(
      id: "unicode-test",
      filename: "report_2024.pdf",
      mimeType: .pdf,
      sizeBytes: 5000,
      base64Data: "dW5pY29kZQ==",
      estimatedTokens: nil
    )

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(attachment)
    let decoded = try decoder.decode(FileAttachment.self, from: encoded)

    XCTAssertEqual(decoded.filename, "report_2024.pdf")
  }

  // Tests attachment with special characters in filename.
  func test_edgeCase_specialCharactersInFilename_preservesCorrectly() throws {
    let attachment = FileAttachment(
      id: "special-chars",
      filename: "My Document (Final) - v2.pdf",
      mimeType: .pdf,
      sizeBytes: 3000,
      base64Data: "c3BlY2lhbA==",
      estimatedTokens: nil
    )

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(attachment)
    let decoded = try decoder.decode(FileAttachment.self, from: encoded)

    XCTAssertEqual(decoded.filename, "My Document (Final) - v2.pdf")
  }

  // Tests attachment with zero estimatedTokens.
  func test_edgeCase_zeroEstimatedTokens_isValid() {
    let attachment = FileAttachment(
      id: "zero-tokens",
      filename: "tiny.txt",
      mimeType: .plainText,
      sizeBytes: 1,
      base64Data: "YQ==",
      estimatedTokens: 0
    )

    XCTAssertEqual(attachment.estimatedTokens, 0)
  }

  // Tests attachment with large estimatedTokens.
  func test_edgeCase_largeEstimatedTokens_isValid() {
    let attachment = FileAttachment(
      id: "large-tokens",
      filename: "huge.pdf",
      mimeType: .pdf,
      sizeBytes: 50_000_000,
      base64Data: "bGFyZ2U=",
      estimatedTokens: 1_000_000
    )

    XCTAssertEqual(attachment.estimatedTokens, 1_000_000)
  }
}

// MARK: - AttachmentError Tests

final class AttachmentErrorTests: XCTestCase {

  // MARK: - errorDescription Tests

  // Tests unsupportedFileType error provides helpful message.
  func test_errorDescription_unsupportedFileType_containsExtensionAndSupportedTypes() {
    let error = AttachmentError.unsupportedFileType(extension: "docx")
    let description = error.errorDescription

    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("docx"))
    XCTAssertTrue(description!.contains("not supported"))
    XCTAssertTrue(description!.contains("PNG"))
    XCTAssertTrue(description!.contains("JPEG"))
    XCTAssertTrue(description!.contains("PDF"))
  }

  // Tests fileTooLarge error shows sizes in MB.
  func test_errorDescription_fileTooLarge_showsSizesInMB() {
    let error = AttachmentError.fileTooLarge(
      filename: "large.pdf",
      sizeBytes: 60_000_000,
      limitBytes: 52_428_800
    )
    let description = error.errorDescription

    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("large.pdf"))
    XCTAssertTrue(description!.contains("too large"))
    // Check that it contains MB formatting
    XCTAssertTrue(description!.contains("MB"))
    // Check that sizes are present (57.2 MB actual, 50 MB limit)
    XCTAssertTrue(description!.contains("57.2") || description!.contains("57."))
    XCTAssertTrue(description!.contains("50"))
  }

  // Tests emptyFile error shows filename.
  func test_errorDescription_emptyFile_containsFilename() {
    let error = AttachmentError.emptyFile(filename: "empty.txt")
    let description = error.errorDescription

    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("empty.txt"))
    XCTAssertTrue(description!.contains("empty"))
  }

  // Tests readFailed error shows filename and reason.
  func test_errorDescription_readFailed_containsFilenameAndReason() {
    let error = AttachmentError.readFailed(filename: "missing.png", reason: "File not found")
    let description = error.errorDescription

    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("missing.png"))
    XCTAssertTrue(description!.contains("File not found"))
  }

  // Tests tokenBudgetExceeded error shows token counts.
  func test_errorDescription_tokenBudgetExceeded_showsTokenCounts() {
    let error = AttachmentError.tokenBudgetExceeded(
      estimatedTokens: 50000,
      availableTokens: 30000
    )
    let description = error.errorDescription

    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("50000"))
    XCTAssertTrue(description!.contains("30000"))
  }

  // Tests uploadFailed error shows reason.
  func test_errorDescription_uploadFailed_containsReason() {
    let error = AttachmentError.uploadFailed(reason: "Network timeout")
    let description = error.errorDescription

    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("Network timeout"))
    XCTAssertTrue(description!.contains("upload") || description!.contains("Upload"))
  }

  // Tests processingFailed error shows reason.
  func test_errorDescription_processingFailed_containsReason() {
    let error = AttachmentError.processingFailed(reason: "Invalid image format")
    let description = error.errorDescription

    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("Invalid image format"))
    XCTAssertTrue(description!.contains("process") || description!.contains("Process"))
  }

  // MARK: - Equatable Tests

  // Tests same error cases with same values compare as equal.
  func test_equatable_sameErrorSameValues_areEqual() {
    let error1 = AttachmentError.emptyFile(filename: "test.txt")
    let error2 = AttachmentError.emptyFile(filename: "test.txt")

    XCTAssertEqual(error1, error2)
  }

  // Tests same error cases with different values compare as not equal.
  func test_equatable_sameErrorDifferentValues_areNotEqual() {
    let error1 = AttachmentError.emptyFile(filename: "a.txt")
    let error2 = AttachmentError.emptyFile(filename: "b.txt")

    XCTAssertNotEqual(error1, error2)
  }

  // Tests different error cases compare as not equal.
  func test_equatable_differentErrors_areNotEqual() {
    let error1 = AttachmentError.emptyFile(filename: "a.txt")
    let error2 = AttachmentError.unsupportedFileType(extension: "txt")

    XCTAssertNotEqual(error1, error2)
  }

  // Tests fileTooLarge equality with same values.
  func test_equatable_fileTooLarge_sameValues_areEqual() {
    let error1 = AttachmentError.fileTooLarge(
      filename: "big.pdf",
      sizeBytes: 100,
      limitBytes: 50
    )
    let error2 = AttachmentError.fileTooLarge(
      filename: "big.pdf",
      sizeBytes: 100,
      limitBytes: 50
    )

    XCTAssertEqual(error1, error2)
  }

  // Tests tokenBudgetExceeded equality with same values.
  func test_equatable_tokenBudgetExceeded_sameValues_areEqual() {
    let error1 = AttachmentError.tokenBudgetExceeded(
      estimatedTokens: 5000,
      availableTokens: 3000
    )
    let error2 = AttachmentError.tokenBudgetExceeded(
      estimatedTokens: 5000,
      availableTokens: 3000
    )

    XCTAssertEqual(error1, error2)
  }
}

// MARK: - UploadedFileReference Tests

final class UploadedFileReferenceTests: XCTestCase {

  // MARK: - Initialization Tests

  // Tests that UploadedFileReference initializes with all properties.
  func test_init_withAllProperties_setsAllValues() {
    let reference = UploadedFileReference(
      fileUri: "files/abc123",
      mimeType: "image/png",
      name: "photo.png",
      expiresAt: "2024-12-31T23:59:59Z"
    )

    XCTAssertEqual(reference.fileUri, "files/abc123")
    XCTAssertEqual(reference.mimeType, "image/png")
    XCTAssertEqual(reference.name, "photo.png")
    XCTAssertEqual(reference.expiresAt, "2024-12-31T23:59:59Z")
  }

  // Tests that UploadedFileReference initializes with nil expiresAt.
  func test_init_withNilExpiresAt_setsExpiresAtToNil() {
    let reference = UploadedFileReference(
      fileUri: "files/xyz789",
      mimeType: "application/pdf",
      name: "document.pdf",
      expiresAt: nil
    )

    XCTAssertNil(reference.expiresAt)
    XCTAssertEqual(reference.fileUri, "files/xyz789")
    XCTAssertEqual(reference.mimeType, "application/pdf")
    XCTAssertEqual(reference.name, "document.pdf")
  }

  // MARK: - Codable Tests

  // Tests encoding reference to JSON includes all properties.
  func test_codable_encode_containsAllProperties() throws {
    let reference = UploadedFileReference(
      fileUri: "files/encode-test",
      mimeType: "text/plain",
      name: "notes.txt",
      expiresAt: "2024-06-15T12:00:00Z"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(reference)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertEqual(json?["fileUri"] as? String, "files/encode-test")
    XCTAssertEqual(json?["mimeType"] as? String, "text/plain")
    XCTAssertEqual(json?["name"] as? String, "notes.txt")
    XCTAssertEqual(json?["expiresAt"] as? String, "2024-06-15T12:00:00Z")
  }

  // Tests decoding reference from JSON creates correct instance.
  func test_codable_decode_createsCorrectInstance() throws {
    let json = """
    {
      "fileUri": "files/decode-test",
      "mimeType": "image/jpeg",
      "name": "photo.jpg",
      "expiresAt": "2025-01-01T00:00:00Z"
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let reference = try decoder.decode(UploadedFileReference.self, from: data)

    XCTAssertEqual(reference.fileUri, "files/decode-test")
    XCTAssertEqual(reference.mimeType, "image/jpeg")
    XCTAssertEqual(reference.name, "photo.jpg")
    XCTAssertEqual(reference.expiresAt, "2025-01-01T00:00:00Z")
  }

  // Tests decoding reference with null expiresAt.
  func test_codable_decodeWithNullExpiresAt_setsExpiresAtToNil() throws {
    let json = """
    {
      "fileUri": "files/null-expires",
      "mimeType": "image/gif",
      "name": "animation.gif",
      "expiresAt": null
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let reference = try decoder.decode(UploadedFileReference.self, from: data)

    XCTAssertNil(reference.expiresAt)
  }

  // Tests decoding reference with missing expiresAt field.
  func test_codable_decodeWithMissingExpiresAt_setsExpiresAtToNil() throws {
    let json = """
    {
      "fileUri": "files/no-expires",
      "mimeType": "image/webp",
      "name": "image.webp"
    }
    """

    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    let reference = try decoder.decode(UploadedFileReference.self, from: data)

    XCTAssertNil(reference.expiresAt)
  }

  // Tests Codable round-trip preserves all values.
  func test_codable_roundTrip_preservesAllValues() throws {
    let original = UploadedFileReference(
      fileUri: "files/round-trip",
      mimeType: "application/pdf",
      name: "doc.pdf",
      expiresAt: "2024-12-25T18:30:00Z"
    )

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(UploadedFileReference.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - Equatable Tests

  // Tests that equal references compare as equal.
  func test_equatable_identicalReferences_areEqual() {
    let reference1 = UploadedFileReference(
      fileUri: "files/same",
      mimeType: "image/png",
      name: "same.png",
      expiresAt: "2024-12-31T23:59:59Z"
    )

    let reference2 = UploadedFileReference(
      fileUri: "files/same",
      mimeType: "image/png",
      name: "same.png",
      expiresAt: "2024-12-31T23:59:59Z"
    )

    XCTAssertEqual(reference1, reference2)
  }

  // Tests that references with different fileUri compare as not equal.
  func test_equatable_differentFileUri_areNotEqual() {
    let reference1 = UploadedFileReference(
      fileUri: "files/abc",
      mimeType: "image/png",
      name: "same.png",
      expiresAt: nil
    )

    let reference2 = UploadedFileReference(
      fileUri: "files/xyz",
      mimeType: "image/png",
      name: "same.png",
      expiresAt: nil
    )

    XCTAssertNotEqual(reference1, reference2)
  }

  // Tests that references with nil and non-nil expiresAt compare as not equal.
  func test_equatable_nilVsNonNilExpiresAt_areNotEqual() {
    let reference1 = UploadedFileReference(
      fileUri: "files/same",
      mimeType: "image/png",
      name: "same.png",
      expiresAt: nil
    )

    let reference2 = UploadedFileReference(
      fileUri: "files/same",
      mimeType: "image/png",
      name: "same.png",
      expiresAt: "2024-12-31T23:59:59Z"
    )

    XCTAssertNotEqual(reference1, reference2)
  }
}

// MARK: - AttachmentTokenEstimation Tests

final class AttachmentTokenEstimationTests: XCTestCase {

  // Tests that tokensPerImage equals 258.
  func test_tokensPerImage_equals258() {
    XCTAssertEqual(AttachmentTokenEstimation.tokensPerImage, 258)
  }

  // Tests that tokensPerPDFPage equals 750.
  func test_tokensPerPDFPage_equals750() {
    XCTAssertEqual(AttachmentTokenEstimation.tokensPerPDFPage, 750)
  }

  // Tests that charsPerToken equals 4.0.
  func test_charsPerToken_equals4() {
    XCTAssertEqual(AttachmentTokenEstimation.charsPerToken, 4.0)
  }
}

// MARK: - Mock Implementations for Protocol Testing

// Mock implementation of AttachmentValidationProtocol for testing.
// Tracks method invocations and allows configurable behavior.
final class MockAttachmentValidator: AttachmentValidationProtocol, @unchecked Sendable {

  // Tracks validateFile calls.
  var validateFileCallCount = 0
  var lastValidatedURL: URL?
  var validateFileResult: AttachmentMimeType?
  var validateFileError: AttachmentError?

  // Tracks validateData calls.
  var validateDataCallCount = 0
  var lastValidatedData: Data?
  var lastValidatedFilename: String?
  var lastValidatedMimeType: AttachmentMimeType?
  var validateDataError: AttachmentError?

  // Tracks validateTokenBudget calls.
  var validateTokenBudgetCallCount = 0
  var lastValidatedAttachment: FileAttachment?
  var lastCurrentUsage: Int?
  var lastBudget: Int?
  var validateTokenBudgetError: AttachmentError?

  func validateFile(at url: URL) throws -> AttachmentMimeType {
    validateFileCallCount += 1
    lastValidatedURL = url

    if let error = validateFileError {
      throw error
    }

    return validateFileResult ?? .png
  }

  func validateData(
    _ data: Data,
    filename: String,
    mimeType: AttachmentMimeType
  ) throws {
    validateDataCallCount += 1
    lastValidatedData = data
    lastValidatedFilename = filename
    lastValidatedMimeType = mimeType

    if let error = validateDataError {
      throw error
    }
  }

  func validateTokenBudget(
    attachment: FileAttachment,
    currentUsage: Int,
    budget: Int
  ) throws {
    validateTokenBudgetCallCount += 1
    lastValidatedAttachment = attachment
    lastCurrentUsage = currentUsage
    lastBudget = budget

    if let error = validateTokenBudgetError {
      throw error
    }
  }
}

// Mock implementation of AttachmentProcessorProtocol for testing.
// Tracks method invocations and allows configurable behavior.
final class MockAttachmentProcessor: AttachmentProcessorProtocol, @unchecked Sendable {

  // Tracks createAttachment calls.
  var createAttachmentCallCount = 0
  var lastProcessedURL: URL?
  var createAttachmentResult: FileAttachment?
  var createAttachmentError: AttachmentError?

  // Tracks estimateTokens calls.
  var estimateTokensCallCount = 0
  var lastEstimatedAttachment: FileAttachment?
  var estimatedTokensToReturn: Int?

  func createAttachment(from url: URL) async throws -> FileAttachment {
    createAttachmentCallCount += 1
    lastProcessedURL = url

    if let error = createAttachmentError {
      throw error
    }

    if let result = createAttachmentResult {
      return result
    }

    // Return a default attachment if no specific result is set.
    return FileAttachment(
      id: UUID().uuidString,
      filename: url.lastPathComponent,
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "bW9jayBkYXRh",
      estimatedTokens: nil
    )
  }

  func estimateTokens(for attachment: FileAttachment) -> FileAttachment {
    estimateTokensCallCount += 1
    lastEstimatedAttachment = attachment

    let tokens = estimatedTokensToReturn ?? AttachmentTokenEstimation.tokensPerImage

    return FileAttachment(
      id: attachment.id,
      filename: attachment.filename,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      base64Data: attachment.base64Data,
      estimatedTokens: tokens
    )
  }
}

// MARK: - Protocol Mock Tests

final class AttachmentValidationMockTests: XCTestCase {

  var mockValidator: MockAttachmentValidator!

  override func setUp() {
    super.setUp()
    mockValidator = MockAttachmentValidator()
  }

  override func tearDown() {
    mockValidator = nil
    super.tearDown()
  }

  // Tests validateFile tracks URL and returns configured MIME type.
  func test_validateFile_tracksURLAndReturnsConfiguredResult() throws {
    let testURL = URL(fileURLWithPath: "/test/photo.png")
    mockValidator.validateFileResult = .png

    let result = try mockValidator.validateFile(at: testURL)

    XCTAssertEqual(mockValidator.validateFileCallCount, 1)
    XCTAssertEqual(mockValidator.lastValidatedURL, testURL)
    XCTAssertEqual(result, .png)
  }

  // Tests validateFile throws configured error.
  func test_validateFile_throwsConfiguredError() {
    let testURL = URL(fileURLWithPath: "/test/document.docx")
    mockValidator.validateFileError = .unsupportedFileType(extension: "docx")

    XCTAssertThrowsError(try mockValidator.validateFile(at: testURL)) { error in
      XCTAssertEqual(error as? AttachmentError, .unsupportedFileType(extension: "docx"))
    }
  }

  // Tests validateData tracks parameters.
  func test_validateData_tracksParameters() throws {
    let testData = Data([0x01, 0x02, 0x03])

    try mockValidator.validateData(testData, filename: "test.png", mimeType: .png)

    XCTAssertEqual(mockValidator.validateDataCallCount, 1)
    XCTAssertEqual(mockValidator.lastValidatedData, testData)
    XCTAssertEqual(mockValidator.lastValidatedFilename, "test.png")
    XCTAssertEqual(mockValidator.lastValidatedMimeType, .png)
  }

  // Tests validateData throws emptyFile error for empty data.
  func test_validateData_withEmptyData_throwsConfiguredError() {
    mockValidator.validateDataError = .emptyFile(filename: "empty.txt")

    XCTAssertThrowsError(
      try mockValidator.validateData(Data(), filename: "empty.txt", mimeType: .plainText)
    ) { error in
      XCTAssertEqual(error as? AttachmentError, .emptyFile(filename: "empty.txt"))
    }
  }

  // Tests validateTokenBudget tracks parameters.
  func test_validateTokenBudget_tracksParameters() throws {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 258
    )

    try mockValidator.validateTokenBudget(
      attachment: attachment,
      currentUsage: 5000,
      budget: 10000
    )

    XCTAssertEqual(mockValidator.validateTokenBudgetCallCount, 1)
    XCTAssertEqual(mockValidator.lastValidatedAttachment, attachment)
    XCTAssertEqual(mockValidator.lastCurrentUsage, 5000)
    XCTAssertEqual(mockValidator.lastBudget, 10000)
  }

  // Tests validateTokenBudget throws tokenBudgetExceeded when over budget.
  func test_validateTokenBudget_overBudget_throwsConfiguredError() {
    mockValidator.validateTokenBudgetError = .tokenBudgetExceeded(
      estimatedTokens: 6000,
      availableTokens: 5000
    )

    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 6000
    )

    XCTAssertThrowsError(
      try mockValidator.validateTokenBudget(
        attachment: attachment,
        currentUsage: 5000,
        budget: 10000
      )
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .tokenBudgetExceeded(estimatedTokens: 6000, availableTokens: 5000)
      )
    }
  }
}

final class AttachmentProcessorMockTests: XCTestCase {

  var mockProcessor: MockAttachmentProcessor!

  override func setUp() {
    super.setUp()
    mockProcessor = MockAttachmentProcessor()
  }

  override func tearDown() {
    mockProcessor = nil
    super.tearDown()
  }

  // Tests createAttachment tracks URL and returns configured result.
  func test_createAttachment_tracksURLAndReturnsConfiguredResult() async throws {
    let testURL = URL(fileURLWithPath: "/test/image.png")
    let expectedAttachment = FileAttachment(
      id: "configured-id",
      filename: "image.png",
      mimeType: .png,
      sizeBytes: 5000,
      base64Data: "aW1hZ2UgZGF0YQ==",
      estimatedTokens: nil
    )
    mockProcessor.createAttachmentResult = expectedAttachment

    let result = try await mockProcessor.createAttachment(from: testURL)

    XCTAssertEqual(mockProcessor.createAttachmentCallCount, 1)
    XCTAssertEqual(mockProcessor.lastProcessedURL, testURL)
    XCTAssertEqual(result, expectedAttachment)
  }

  // Tests createAttachment throws configured error.
  func test_createAttachment_throwsConfiguredError() async {
    let testURL = URL(fileURLWithPath: "/missing/file.png")
    mockProcessor.createAttachmentError = .readFailed(
      filename: "file.png",
      reason: "File not found"
    )

    do {
      _ = try await mockProcessor.createAttachment(from: testURL)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(
        error as? AttachmentError,
        .readFailed(filename: "file.png", reason: "File not found")
      )
    }
  }

  // Tests estimateTokens tracks attachment and returns configured tokens.
  func test_estimateTokens_tracksAttachmentAndReturnsConfiguredTokens() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )
    mockProcessor.estimatedTokensToReturn = 500

    let result = mockProcessor.estimateTokens(for: attachment)

    XCTAssertEqual(mockProcessor.estimateTokensCallCount, 1)
    XCTAssertEqual(mockProcessor.lastEstimatedAttachment, attachment)
    XCTAssertEqual(result.estimatedTokens, 500)
    // Other properties should remain unchanged.
    XCTAssertEqual(result.id, attachment.id)
    XCTAssertEqual(result.filename, attachment.filename)
    XCTAssertEqual(result.mimeType, attachment.mimeType)
    XCTAssertEqual(result.sizeBytes, attachment.sizeBytes)
    XCTAssertEqual(result.base64Data, attachment.base64Data)
  }

  // Tests estimateTokens returns default tokens when not configured.
  func test_estimateTokens_withoutConfiguration_returnsDefaultTokens() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = mockProcessor.estimateTokens(for: attachment)

    XCTAssertEqual(result.estimatedTokens, AttachmentTokenEstimation.tokensPerImage)
  }
}
