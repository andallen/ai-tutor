// AttachmentServiceTests.swift
// Comprehensive tests for AttachmentValidator and AttachmentProcessor implementations.
// Tests validate interface usability, happy paths, sad paths, and edge cases
// as specified in AttachmentServiceContract.swift acceptance criteria.

import XCTest

@testable import InkOS

// MARK: - AttachmentValidator Tests

final class AttachmentValidatorTests: XCTestCase {

  // System under test.
  var sut: AttachmentValidator!

  override func setUp() {
    super.setUp()
    sut = AttachmentValidator()
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  // MARK: - Interface Usability Tests

  // Tests that AttachmentValidator can be instantiated.
  func test_init_createsValidInstance() {
    let validator = AttachmentValidator()
    XCTAssertNotNil(validator)
  }

  // Tests that AttachmentValidator conforms to AttachmentValidationProtocol.
  func test_conformsToProtocol() {
    let validator: AttachmentValidationProtocol = AttachmentValidator()
    XCTAssertNotNil(validator)
  }

  // MARK: - validateFile() Happy Path Tests

  // Tests that PNG extension returns png MIME type.
  func test_validateFile_pngExtension_returnsPng() throws {
    let url = URL(fileURLWithPath: "/documents/image.png")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .png)
  }

  // Tests that JPG extension returns jpeg MIME type.
  func test_validateFile_jpgExtension_returnsJpeg() throws {
    let url = URL(fileURLWithPath: "/documents/photo.jpg")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .jpeg)
  }

  // Tests that JPEG extension returns jpeg MIME type.
  func test_validateFile_jpegExtension_returnsJpeg() throws {
    let url = URL(fileURLWithPath: "/documents/photo.jpeg")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .jpeg)
  }

  // Tests that PDF extension returns pdf MIME type.
  func test_validateFile_pdfExtension_returnsPdf() throws {
    let url = URL(fileURLWithPath: "/documents/report.pdf")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .pdf)
  }

  // Tests that TXT extension returns plainText MIME type.
  func test_validateFile_txtExtension_returnsPlainText() throws {
    let url = URL(fileURLWithPath: "/documents/notes.txt")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .plainText)
  }

  // Tests that WebP extension returns webp MIME type.
  func test_validateFile_webpExtension_returnsWebp() throws {
    let url = URL(fileURLWithPath: "/documents/image.webp")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .webp)
  }

  // Tests that HEIC extension returns heic MIME type.
  func test_validateFile_heicExtension_returnsHeic() throws {
    let url = URL(fileURLWithPath: "/documents/photo.heic")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .heic)
  }

  // Tests that HEIF extension returns heif MIME type.
  func test_validateFile_heifExtension_returnsHeif() throws {
    let url = URL(fileURLWithPath: "/documents/photo.heif")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .heif)
  }

  // Tests that GIF extension returns gif MIME type.
  func test_validateFile_gifExtension_returnsGif() throws {
    let url = URL(fileURLWithPath: "/documents/animation.gif")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .gif)
  }

  // MARK: - validateFile() Sad Path Tests

  // Tests that unsupported DOCX extension throws unsupportedFileType.
  func test_validateFile_docxExtension_throwsUnsupportedFileType() {
    let url = URL(fileURLWithPath: "/documents/document.docx")

    XCTAssertThrowsError(try sut.validateFile(at: url)) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .unsupportedFileType(extension: "docx")
      )
    }
  }

  // Tests that unknown XYZ extension throws unsupportedFileType.
  func test_validateFile_unknownExtension_throwsUnsupportedFileType() {
    let url = URL(fileURLWithPath: "/documents/data.xyz")

    XCTAssertThrowsError(try sut.validateFile(at: url)) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .unsupportedFileType(extension: "xyz")
      )
    }
  }

  // MARK: - validateFile() Case Insensitivity Tests

  // Tests case insensitive PNG extension matching.
  func test_validateFile_uppercasePNG_returnsPng() throws {
    let url = URL(fileURLWithPath: "/documents/IMAGE.PNG")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .png)
  }

  // Tests mixed case JPEG extension matching.
  func test_validateFile_mixedCaseJpEg_returnsJpeg() throws {
    let url = URL(fileURLWithPath: "/documents/Photo.JpEg")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .jpeg)
  }

  // Tests case insensitive PDF extension matching.
  func test_validateFile_uppercasePDF_returnsPdf() throws {
    let url = URL(fileURLWithPath: "/documents/REPORT.PDF")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .pdf)
  }

  // MARK: - validateFile() Edge Case Tests

  // Tests that file with no extension throws unsupportedFileType with empty string.
  func test_validateFile_noExtension_throwsUnsupportedFileTypeWithEmptyString() {
    let url = URL(fileURLWithPath: "/documents/README")

    XCTAssertThrowsError(try sut.validateFile(at: url)) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .unsupportedFileType(extension: "")
      )
    }
  }

  // Tests that hidden file with valid extension is accepted.
  func test_validateFile_hiddenFileWithTxtExtension_returnsPlainText() throws {
    let url = URL(fileURLWithPath: "/documents/.txt")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .plainText)
  }

  // Tests that file with multiple dots uses last extension.
  func test_validateFile_multipleDots_usesLastExtension() throws {
    let url = URL(fileURLWithPath: "/documents/report.2024.final.pdf")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .pdf)
  }

  // Tests that file path with spaces works correctly.
  func test_validateFile_pathWithSpaces_worksCorrently() throws {
    let url = URL(fileURLWithPath: "/my documents/my file.png")
    let result = try sut.validateFile(at: url)
    XCTAssertEqual(result, .png)
  }

  // Tests that very long unsupported extension throws error with full extension.
  func test_validateFile_veryLongExtension_throwsUnsupportedFileType() {
    let url = URL(fileURLWithPath: "/documents/file.verylongextension")

    XCTAssertThrowsError(try sut.validateFile(at: url)) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .unsupportedFileType(extension: "verylongextension")
      )
    }
  }

  // Tests that numeric extension throws unsupportedFileType.
  func test_validateFile_numericExtension_throwsUnsupportedFileType() {
    let url = URL(fileURLWithPath: "/documents/archive.001")

    XCTAssertThrowsError(try sut.validateFile(at: url)) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .unsupportedFileType(extension: "001")
      )
    }
  }

  // MARK: - validateData() Happy Path Tests

  // Tests that image data within 20MB limit passes validation.
  func test_validateData_imageWithin20MB_passes() throws {
    // 10MB of data.
    let data = Data(count: 10 * 1024 * 1024)

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "photo.png", mimeType: .png)
    )
  }

  // Tests that image data at exact 20MB limit passes validation.
  func test_validateData_imageAtExact20MBLimit_passes() throws {
    // Exactly 20MB of data.
    let data = Data(count: 20 * 1024 * 1024)

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "large.png", mimeType: .png)
    )
  }

  // Tests that PDF data within 50MB limit passes validation.
  func test_validateData_pdfWithin50MB_passes() throws {
    // 30MB of data.
    let data = Data(count: 30 * 1024 * 1024)

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "document.pdf", mimeType: .pdf)
    )
  }

  // Tests that plain text data within 1MB limit passes validation.
  func test_validateData_plainTextWithin1MB_passes() throws {
    // 500KB of data.
    let data = Data(count: 500 * 1024)

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "notes.txt", mimeType: .plainText)
    )
  }

  // MARK: - validateData() Sad Path Tests

  // Tests that empty data throws emptyFile error.
  func test_validateData_emptyData_throwsEmptyFile() {
    let data = Data()

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "empty.png", mimeType: .png)
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .emptyFile(filename: "empty.png")
      )
    }
  }

  // Tests that oversized image data throws fileTooLarge.
  func test_validateData_imageOver20MB_throwsFileTooLarge() {
    // 25MB of data.
    let data = Data(count: 25 * 1024 * 1024)

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "huge.png", mimeType: .png)
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .fileTooLarge(
          filename: "huge.png",
          sizeBytes: 26_214_400,
          limitBytes: 20_971_520
        )
      )
    }
  }

  // Tests that oversized PDF data throws fileTooLarge.
  func test_validateData_pdfOver50MB_throwsFileTooLarge() {
    // 60MB of data.
    let data = Data(count: 60 * 1024 * 1024)

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "massive.pdf", mimeType: .pdf)
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .fileTooLarge(
          filename: "massive.pdf",
          sizeBytes: 62_914_560,
          limitBytes: 52_428_800
        )
      )
    }
  }

  // Tests that oversized plain text data throws fileTooLarge.
  func test_validateData_plainTextOver1MB_throwsFileTooLarge() {
    // 2MB of data.
    let data = Data(count: 2 * 1024 * 1024)

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "large.txt", mimeType: .plainText)
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .fileTooLarge(
          filename: "large.txt",
          sizeBytes: 2_097_152,
          limitBytes: 1_048_576
        )
      )
    }
  }

  // MARK: - validateData() Boundary Tests

  // Tests that single byte data passes (not empty).
  func test_validateData_singleByte_passes() throws {
    let data = Data([0x01])

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "tiny.txt", mimeType: .plainText)
    )
  }

  // Tests that data exactly one byte over 20MB limit throws fileTooLarge.
  func test_validateData_imageOneByteOverLimit_throwsFileTooLarge() {
    // 20MB + 1 byte.
    let data = Data(count: 20 * 1024 * 1024 + 1)

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "tooLarge.png", mimeType: .png)
    ) { error in
      guard case .fileTooLarge(let filename, let sizeBytes, let limitBytes) = error as? AttachmentError else {
        XCTFail("Expected fileTooLarge error")
        return
      }
      XCTAssertEqual(filename, "tooLarge.png")
      XCTAssertEqual(sizeBytes, 20 * 1024 * 1024 + 1)
      XCTAssertEqual(limitBytes, 20 * 1024 * 1024)
    }
  }

  // Tests that plain text at exact 1MB limit passes.
  func test_validateData_plainTextAtExact1MBLimit_passes() throws {
    // Exactly 1MB.
    let data = Data(count: 1 * 1024 * 1024)

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "exact.txt", mimeType: .plainText)
    )
  }

  // Tests that PDF at exact 50MB limit passes.
  func test_validateData_pdfAtExact50MBLimit_passes() throws {
    // Exactly 50MB.
    let data = Data(count: 50 * 1024 * 1024)

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "exact.pdf", mimeType: .pdf)
    )
  }

  // MARK: - validateData() All Image Types Tests

  // Tests that all image MIME types use 20MB limit.
  func test_validateData_allImageTypes_use20MBLimit() throws {
    // 15MB of data, within 20MB limit.
    let validData = Data(count: 15 * 1024 * 1024)
    let imageTypes: [AttachmentMimeType] = [.png, .jpeg, .webp, .heic, .heif, .gif]

    for mimeType in imageTypes {
      XCTAssertNoThrow(
        try sut.validateData(validData, filename: "test.\(mimeType)", mimeType: mimeType),
        "Expected \(mimeType) to pass with 15MB data"
      )
    }
  }

  // MARK: - validateData() Edge Case Tests

  // Tests that empty check occurs before size check.
  func test_validateData_emptyData_throwsEmptyFileNotFileTooLarge() {
    let data = Data()

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "empty.png", mimeType: .png)
    ) { error in
      // Should throw emptyFile, not fileTooLarge.
      XCTAssertEqual(
        error as? AttachmentError,
        .emptyFile(filename: "empty.png")
      )
    }
  }

  // Tests that unicode filename is preserved in error.
  func test_validateData_unicodeFilename_preservedInError() {
    let data = Data()

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "document.pdf", mimeType: .pdf)
    ) { error in
      guard case .emptyFile(let filename) = error as? AttachmentError else {
        XCTFail("Expected emptyFile error")
        return
      }
      XCTAssertEqual(filename, "document.pdf")
    }
  }

  // Tests that special characters in filename are preserved.
  func test_validateData_specialCharactersInFilename_preserved() {
    let data = Data()

    XCTAssertThrowsError(
      try sut.validateData(data, filename: "file (copy).png", mimeType: .png)
    ) { error in
      guard case .emptyFile(let filename) = error as? AttachmentError else {
        XCTFail("Expected emptyFile error")
        return
      }
      XCTAssertEqual(filename, "file (copy).png")
    }
  }

  // Tests that empty filename is handled (only used in error messages).
  func test_validateData_emptyFilename_passes() throws {
    let data = Data([0x01])

    XCTAssertNoThrow(
      try sut.validateData(data, filename: "", mimeType: .png)
    )
  }

  // MARK: - validateTokenBudget() Happy Path Tests

  // Tests that attachment within token budget passes.
  func test_validateTokenBudget_withinBudget_passes() throws {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 1000
    )

    XCTAssertNoThrow(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 5000,
        budget: 10000
      )
    )
  }

  // Tests that attachment exactly at token budget passes.
  func test_validateTokenBudget_exactlyAtBudget_passes() throws {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 5000
    )

    XCTAssertNoThrow(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 5000,
        budget: 10000
      )
    )
  }

  // Tests that attachment with nil estimatedTokens passes (defaults to 0).
  func test_validateTokenBudget_nilEstimatedTokens_passes() throws {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    XCTAssertNoThrow(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 5000,
        budget: 10000
      )
    )
  }

  // Tests that zero estimated tokens with zero budget passes.
  func test_validateTokenBudget_zeroTokensZeroBudget_passes() throws {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 0
    )

    XCTAssertNoThrow(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 10000,
        budget: 10000
      )
    )
  }

  // MARK: - validateTokenBudget() Sad Path Tests

  // Tests that attachment exceeds token budget by small amount throws error.
  func test_validateTokenBudget_exceedsBudgetByOne_throwsTokenBudgetExceeded() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 5001
    )

    XCTAssertThrowsError(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 5000,
        budget: 10000
      )
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .tokenBudgetExceeded(estimatedTokens: 5001, availableTokens: 5000)
      )
    }
  }

  // Tests that attachment greatly exceeds token budget throws error.
  func test_validateTokenBudget_greatlyExceedsBudget_throwsTokenBudgetExceeded() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 50000
    )

    XCTAssertThrowsError(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 8000,
        budget: 10000
      )
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .tokenBudgetExceeded(estimatedTokens: 50000, availableTokens: 2000)
      )
    }
  }

  // Tests that single token exceeds zero budget throws error.
  func test_validateTokenBudget_oneTokenZeroBudgetRemaining_throwsTokenBudgetExceeded() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 1
    )

    XCTAssertThrowsError(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 10000,
        budget: 10000
      )
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .tokenBudgetExceeded(estimatedTokens: 1, availableTokens: 0)
      )
    }
  }

  // MARK: - validateTokenBudget() Edge Case Tests

  // Tests that negative available tokens (usage exceeds budget) works correctly.
  func test_validateTokenBudget_negativeAvailableTokens_throwsTokenBudgetExceeded() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 100
    )

    XCTAssertThrowsError(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 12000,
        budget: 10000
      )
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .tokenBudgetExceeded(estimatedTokens: 100, availableTokens: -2000)
      )
    }
  }

  // Tests that very large estimatedTokens does not cause overflow.
  func test_validateTokenBudget_veryLargeEstimatedTokens_throwsWithoutOverflow() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: Int.max
    )

    XCTAssertThrowsError(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 0,
        budget: 100000
      )
    ) { error in
      guard case .tokenBudgetExceeded(let estimated, let available) = error as? AttachmentError else {
        XCTFail("Expected tokenBudgetExceeded error")
        return
      }
      XCTAssertEqual(estimated, Int.max)
      XCTAssertEqual(available, 100000)
    }
  }

  // Tests that budget of zero with nil estimatedTokens passes.
  func test_validateTokenBudget_zeroBudgetNilTokens_passes() throws {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    XCTAssertNoThrow(
      try sut.validateTokenBudget(
        attachment: attachment,
        currentUsage: 0,
        budget: 0
      )
    )
  }
}

// MARK: - AttachmentProcessor Tests

final class AttachmentProcessorTests: XCTestCase {

  // System under test.
  var sut: AttachmentProcessor!

  // Mock validator for testing.
  var mockValidator: MockAttachmentValidator!

  // Temporary directory for test files.
  var tempDirectory: URL!

  override func setUp() {
    super.setUp()
    mockValidator = MockAttachmentValidator()
    sut = AttachmentProcessor(validator: mockValidator)

    // Create a unique temporary directory for each test.
    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(
      at: tempDirectory,
      withIntermediateDirectories: true
    )
  }

  override func tearDown() {
    // Clean up temporary files.
    try? FileManager.default.removeItem(at: tempDirectory)
    tempDirectory = nil
    mockValidator = nil
    sut = nil
    super.tearDown()
  }

  // MARK: - Interface Usability Tests

  // Tests that AttachmentProcessor can be instantiated with a validator.
  func test_init_withValidator_createsValidInstance() {
    let validator = AttachmentValidator()
    let processor = AttachmentProcessor(validator: validator)
    XCTAssertNotNil(processor)
  }

  // Tests that AttachmentProcessor conforms to AttachmentProcessorProtocol.
  func test_conformsToProtocol() {
    let processor: AttachmentProcessorProtocol = AttachmentProcessor(validator: AttachmentValidator())
    XCTAssertNotNil(processor)
  }

  // MARK: - createAttachment() Happy Path Tests

  // Tests creating attachment from valid PNG file.
  func test_createAttachment_validPngFile_returnsCorrectAttachment() async throws {
    // Create a test PNG file.
    let testData = Data(repeating: 0x89, count: 1024)
    let testURL = tempDirectory.appendingPathComponent("test.png")
    try testData.write(to: testURL)

    // Configure mock validator.
    mockValidator.validateFileResult = .png

    // Create attachment.
    let attachment = try await sut.createAttachment(from: testURL)

    // Verify attachment properties.
    XCTAssertFalse(attachment.id.isEmpty)
    XCTAssertEqual(attachment.filename, "test.png")
    XCTAssertEqual(attachment.mimeType, .png)
    XCTAssertEqual(attachment.sizeBytes, 1024)
    XCTAssertEqual(attachment.base64Data, testData.base64EncodedString())
    XCTAssertNil(attachment.estimatedTokens)
  }

  // Tests creating attachment from valid PDF file.
  func test_createAttachment_validPdfFile_returnsCorrectAttachment() async throws {
    // Create a test PDF file.
    let testData = Data(repeating: 0x25, count: 2048)
    let testURL = tempDirectory.appendingPathComponent("document.pdf")
    try testData.write(to: testURL)

    // Configure mock validator.
    mockValidator.validateFileResult = .pdf

    // Create attachment.
    let attachment = try await sut.createAttachment(from: testURL)

    // Verify attachment properties.
    XCTAssertEqual(attachment.filename, "document.pdf")
    XCTAssertEqual(attachment.mimeType, .pdf)
    XCTAssertEqual(attachment.sizeBytes, 2048)
  }

  // Tests creating attachment from valid text file.
  func test_createAttachment_validTxtFile_returnsCorrectAttachment() async throws {
    // Create a test text file.
    let testContent = "Hello, World!"
    let testData = testContent.data(using: .utf8)!
    let testURL = tempDirectory.appendingPathComponent("notes.txt")
    try testData.write(to: testURL)

    // Configure mock validator.
    mockValidator.validateFileResult = .plainText

    // Create attachment.
    let attachment = try await sut.createAttachment(from: testURL)

    // Verify attachment properties.
    XCTAssertEqual(attachment.filename, "notes.txt")
    XCTAssertEqual(attachment.mimeType, .plainText)
    XCTAssertEqual(attachment.sizeBytes, testData.count)
  }

  // Tests that each call generates a unique ID.
  func test_createAttachment_multipleCalls_generatesUniqueIds() async throws {
    // Create a test file.
    let testData = Data([0x01, 0x02, 0x03])
    let testURL = tempDirectory.appendingPathComponent("test.png")
    try testData.write(to: testURL)

    mockValidator.validateFileResult = .png

    // Create two attachments.
    let attachment1 = try await sut.createAttachment(from: testURL)
    let attachment2 = try await sut.createAttachment(from: testURL)

    // Verify IDs are unique.
    XCTAssertNotEqual(attachment1.id, attachment2.id)

    // Verify both IDs are valid UUID format (36 characters with hyphens).
    XCTAssertEqual(attachment1.id.count, 36)
    XCTAssertEqual(attachment2.id.count, 36)
  }

  // Tests that base64 encoding is correct.
  func test_createAttachment_validFile_hasCorrectBase64Encoding() async throws {
    // Create a test file with known content.
    let testContent = "Test content for base64"
    let testData = testContent.data(using: .utf8)!
    let testURL = tempDirectory.appendingPathComponent("test.txt")
    try testData.write(to: testURL)

    mockValidator.validateFileResult = .plainText

    // Create attachment.
    let attachment = try await sut.createAttachment(from: testURL)

    // Verify base64 encoding.
    let expectedBase64 = testData.base64EncodedString()
    XCTAssertEqual(attachment.base64Data, expectedBase64)

    // Verify decoding works.
    let decodedData = Data(base64Encoded: attachment.base64Data)
    XCTAssertEqual(decodedData, testData)
  }

  // MARK: - createAttachment() Sad Path Tests

  // Tests that missing file throws readFailed.
  func test_createAttachment_missingFile_throwsReadFailed() async {
    let missingURL = tempDirectory.appendingPathComponent("missing.png")
    mockValidator.validateFileResult = .png

    do {
      _ = try await sut.createAttachment(from: missingURL)
      XCTFail("Expected error to be thrown")
    } catch {
      guard case .readFailed(let filename, _) = error as? AttachmentError else {
        XCTFail("Expected readFailed error, got \(error)")
        return
      }
      XCTAssertEqual(filename, "missing.png")
    }
  }

  // Tests that unsupported file type throws unsupportedFileType.
  func test_createAttachment_unsupportedFileType_throwsUnsupportedFileType() async {
    // Create a test file.
    let testURL = tempDirectory.appendingPathComponent("document.docx")
    try? Data([0x01]).write(to: testURL)

    // Configure mock validator to throw.
    mockValidator.validateFileError = .unsupportedFileType(extension: "docx")

    do {
      _ = try await sut.createAttachment(from: testURL)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(
        error as? AttachmentError,
        .unsupportedFileType(extension: "docx")
      )
    }
  }

  // Tests that empty file throws emptyFile.
  func test_createAttachment_emptyFile_throwsEmptyFile() async {
    // Create an empty file.
    let testURL = tempDirectory.appendingPathComponent("empty.txt")
    try? Data().write(to: testURL)

    mockValidator.validateFileResult = .plainText
    mockValidator.validateDataError = .emptyFile(filename: "empty.txt")

    do {
      _ = try await sut.createAttachment(from: testURL)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(
        error as? AttachmentError,
        .emptyFile(filename: "empty.txt")
      )
    }
  }

  // Tests that oversized file throws fileTooLarge.
  func test_createAttachment_oversizedFile_throwsFileTooLarge() async {
    // Create a file (we use mock to simulate validation failure).
    let testURL = tempDirectory.appendingPathComponent("large.png")
    try? Data([0x01]).write(to: testURL)

    mockValidator.validateFileResult = .png
    mockValidator.validateDataError = .fileTooLarge(
      filename: "large.png",
      sizeBytes: 25_000_000,
      limitBytes: 20_971_520
    )

    do {
      _ = try await sut.createAttachment(from: testURL)
      XCTFail("Expected error to be thrown")
    } catch {
      guard case .fileTooLarge(let filename, let sizeBytes, let limitBytes) = error as? AttachmentError else {
        XCTFail("Expected fileTooLarge error")
        return
      }
      XCTAssertEqual(filename, "large.png")
      XCTAssertEqual(sizeBytes, 25_000_000)
      XCTAssertEqual(limitBytes, 20_971_520)
    }
  }

  // MARK: - createAttachment() Edge Case Tests

  // Tests that filename with spaces is preserved.
  func test_createAttachment_filenameWithSpaces_preservesFilename() async throws {
    let testURL = tempDirectory.appendingPathComponent("my photo.png")
    try Data([0x01, 0x02]).write(to: testURL)

    mockValidator.validateFileResult = .png

    let attachment = try await sut.createAttachment(from: testURL)

    XCTAssertEqual(attachment.filename, "my photo.png")
  }

  // Tests that unicode filename is preserved.
  func test_createAttachment_unicodeFilename_preservesFilename() async throws {
    let testURL = tempDirectory.appendingPathComponent("document.pdf")
    try Data([0x01, 0x02]).write(to: testURL)

    mockValidator.validateFileResult = .pdf

    let attachment = try await sut.createAttachment(from: testURL)

    XCTAssertEqual(attachment.filename, "document.pdf")
  }

  // Tests that hidden file filename is preserved.
  func test_createAttachment_hiddenFile_preservesFilename() async throws {
    let testURL = tempDirectory.appendingPathComponent(".hidden.txt")
    try Data([0x01, 0x02]).write(to: testURL)

    mockValidator.validateFileResult = .plainText

    let attachment = try await sut.createAttachment(from: testURL)

    XCTAssertEqual(attachment.filename, ".hidden.txt")
  }

  // Tests that deeply nested file uses only filename.
  func test_createAttachment_deeplyNestedFile_usesOnlyFilename() async throws {
    // Create nested directories.
    let nestedDir = tempDirectory.appendingPathComponent("a/b/c/d/e/f/g")
    try FileManager.default.createDirectory(
      at: nestedDir,
      withIntermediateDirectories: true
    )

    let testURL = nestedDir.appendingPathComponent("file.png")
    try Data([0x01, 0x02]).write(to: testURL)

    mockValidator.validateFileResult = .png

    let attachment = try await sut.createAttachment(from: testURL)

    XCTAssertEqual(attachment.filename, "file.png")
  }

  // Tests validator receives correct URL.
  func test_createAttachment_validatorReceivesCorrectURL() async throws {
    let testURL = tempDirectory.appendingPathComponent("test.png")
    try Data([0x01]).write(to: testURL)

    mockValidator.validateFileResult = .png

    _ = try await sut.createAttachment(from: testURL)

    XCTAssertEqual(mockValidator.lastValidatedURL, testURL)
  }

  // Tests validator receives correct data and filename.
  func test_createAttachment_validatorReceivesCorrectDataAndFilename() async throws {
    let testData = Data([0x01, 0x02, 0x03])
    let testURL = tempDirectory.appendingPathComponent("test.png")
    try testData.write(to: testURL)

    mockValidator.validateFileResult = .png

    _ = try await sut.createAttachment(from: testURL)

    XCTAssertEqual(mockValidator.lastValidatedData, testData)
    XCTAssertEqual(mockValidator.lastValidatedFilename, "test.png")
    XCTAssertEqual(mockValidator.lastValidatedMimeType, .png)
  }

  // MARK: - estimateTokens() Image Tests

  // Tests that PNG image returns 258 tokens.
  func test_estimateTokens_pngImage_returns258Tokens() {
    let attachment = FileAttachment(
      id: "test",
      filename: "image.png",
      mimeType: .png,
      sizeBytes: 5_000_000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    XCTAssertEqual(result.estimatedTokens, 258)
  }

  // Tests that JPEG image returns 258 tokens.
  func test_estimateTokens_jpegImage_returns258Tokens() {
    let attachment = FileAttachment(
      id: "test",
      filename: "photo.jpg",
      mimeType: .jpeg,
      sizeBytes: 2_000_000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    XCTAssertEqual(result.estimatedTokens, 258)
  }

  // Tests that all image types return 258 tokens.
  func test_estimateTokens_allImageTypes_return258Tokens() {
    let imageTypes: [AttachmentMimeType] = [.png, .jpeg, .webp, .heic, .heif, .gif]

    for mimeType in imageTypes {
      let attachment = FileAttachment(
        id: "test",
        filename: "file",
        mimeType: mimeType,
        sizeBytes: 1_000_000,
        base64Data: "dGVzdA==",
        estimatedTokens: nil
      )

      let result = sut.estimateTokens(for: attachment)

      XCTAssertEqual(
        result.estimatedTokens, 258,
        "Expected 258 tokens for \(mimeType)"
      )
    }
  }

  // Tests that image size does not affect token count.
  func test_estimateTokens_differentImageSizes_sameTokenCount() {
    let smallImage = FileAttachment(
      id: "small",
      filename: "small.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "c21hbGw=",
      estimatedTokens: nil
    )

    let largeImage = FileAttachment(
      id: "large",
      filename: "large.png",
      mimeType: .png,
      sizeBytes: 20_000_000,
      base64Data: "bGFyZ2U=",
      estimatedTokens: nil
    )

    let smallResult = sut.estimateTokens(for: smallImage)
    let largeResult = sut.estimateTokens(for: largeImage)

    XCTAssertEqual(smallResult.estimatedTokens, largeResult.estimatedTokens)
    XCTAssertEqual(smallResult.estimatedTokens, 258)
  }

  // MARK: - estimateTokens() PDF Tests

  // Tests that small PDF (1 page) returns 750 tokens.
  func test_estimateTokens_smallPdf_returns750Tokens() {
    // 50KB PDF, less than 100KB per page threshold.
    let attachment = FileAttachment(
      id: "test",
      filename: "small.pdf",
      mimeType: .pdf,
      sizeBytes: 50_000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // pages = max(1, 50000 / 102400) = max(1, 0) = 1
    // tokens = 1 * 750 = 750
    XCTAssertEqual(result.estimatedTokens, 750)
  }

  // Tests that medium PDF (5 pages) returns 3750 tokens.
  func test_estimateTokens_mediumPdf_returns3750Tokens() {
    // 500KB PDF, approximately 5 pages.
    let attachment = FileAttachment(
      id: "test",
      filename: "medium.pdf",
      mimeType: .pdf,
      sizeBytes: 512_000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // pages = max(1, 512000 / 102400) = max(1, 5) = 5
    // tokens = 5 * 750 = 3750
    XCTAssertEqual(result.estimatedTokens, 3750)
  }

  // Tests that large PDF (50 pages) returns 37500 tokens.
  func test_estimateTokens_largePdf_returns37500Tokens() {
    // 5MB PDF, approximately 50 pages.
    let attachment = FileAttachment(
      id: "test",
      filename: "large.pdf",
      mimeType: .pdf,
      sizeBytes: 5_120_000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // pages = max(1, 5120000 / 102400) = max(1, 50) = 50
    // tokens = 50 * 750 = 37500
    XCTAssertEqual(result.estimatedTokens, 37500)
  }

  // Tests that 1 byte PDF still returns minimum 1 page (750 tokens).
  func test_estimateTokens_tinyPdf_returnsMinimum750Tokens() {
    // 1 byte PDF.
    let attachment = FileAttachment(
      id: "test",
      filename: "tiny.pdf",
      mimeType: .pdf,
      sizeBytes: 1,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // pages = max(1, 1 / 102400) = max(1, 0) = 1
    // tokens = 1 * 750 = 750
    XCTAssertEqual(result.estimatedTokens, 750)
  }

  // Tests that PDF at exactly 100KB returns 750 tokens.
  func test_estimateTokens_pdfAtExact100KB_returns750Tokens() {
    // Exactly 100KB.
    let attachment = FileAttachment(
      id: "test",
      filename: "exact.pdf",
      mimeType: .pdf,
      sizeBytes: 102_400,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // pages = 102400 / 102400 = 1
    // tokens = 1 * 750 = 750
    XCTAssertEqual(result.estimatedTokens, 750)
  }

  // Tests that PDF just over 100KB returns 750 tokens (integer division truncates).
  func test_estimateTokens_pdfJustOver100KB_returns750Tokens() {
    // 100KB + 1 byte.
    let attachment = FileAttachment(
      id: "test",
      filename: "justOver.pdf",
      mimeType: .pdf,
      sizeBytes: 102_401,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // pages = 102401 / 102400 = 1 (integer division)
    // tokens = 1 * 750 = 750
    XCTAssertEqual(result.estimatedTokens, 750)
  }

  // Tests that very large PDF calculates correctly.
  func test_estimateTokens_veryLargePdf_calculatesCorrectly() {
    // 50MB PDF.
    let attachment = FileAttachment(
      id: "test",
      filename: "huge.pdf",
      mimeType: .pdf,
      sizeBytes: 50_000_000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // pages = 50000000 / 102400 = 488
    // tokens = 488 * 750 = 366000
    let expectedPages = 50_000_000 / 102_400
    let expectedTokens = expectedPages * 750
    XCTAssertEqual(result.estimatedTokens, expectedTokens)
  }

  // MARK: - estimateTokens() Plain Text Tests

  // Tests that plain text calculates tokens based on chars per token.
  func test_estimateTokens_plainText_calculatesBasedOnCharRatio() {
    // 4000 bytes.
    let attachment = FileAttachment(
      id: "test",
      filename: "notes.txt",
      mimeType: .plainText,
      sizeBytes: 4000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // tokens = Int(4000 / 4.0) = 1000
    XCTAssertEqual(result.estimatedTokens, 1000)
  }

  // Tests that larger plain text calculates correctly.
  func test_estimateTokens_largerPlainText_calculatesCorrectly() {
    // 100KB.
    let attachment = FileAttachment(
      id: "test",
      filename: "large.txt",
      mimeType: .plainText,
      sizeBytes: 100_000,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // tokens = Int(100000 / 4.0) = 25000
    XCTAssertEqual(result.estimatedTokens, 25000)
  }

  // Tests that single character text returns 0 tokens.
  func test_estimateTokens_singleCharText_returns0Tokens() {
    // 1 byte.
    let attachment = FileAttachment(
      id: "test",
      filename: "single.txt",
      mimeType: .plainText,
      sizeBytes: 1,
      base64Data: "YQ==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // tokens = Int(1 / 4.0) = Int(0.25) = 0
    XCTAssertEqual(result.estimatedTokens, 0)
  }

  // Tests that 3 bytes text returns 0 tokens.
  func test_estimateTokens_3BytesText_returns0Tokens() {
    let attachment = FileAttachment(
      id: "test",
      filename: "three.txt",
      mimeType: .plainText,
      sizeBytes: 3,
      base64Data: "YWJj",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // tokens = Int(3 / 4.0) = Int(0.75) = 0
    XCTAssertEqual(result.estimatedTokens, 0)
  }

  // Tests that 4 bytes text returns 1 token.
  func test_estimateTokens_4BytesText_returns1Token() {
    let attachment = FileAttachment(
      id: "test",
      filename: "four.txt",
      mimeType: .plainText,
      sizeBytes: 4,
      base64Data: "YWJjZA==",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // tokens = Int(4 / 4.0) = 1
    XCTAssertEqual(result.estimatedTokens, 1)
  }

  // Tests that empty text returns 0 tokens.
  func test_estimateTokens_emptyText_returns0Tokens() {
    let attachment = FileAttachment(
      id: "test",
      filename: "empty.txt",
      mimeType: .plainText,
      sizeBytes: 0,
      base64Data: "",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: attachment)

    // tokens = Int(0 / 4.0) = 0
    XCTAssertEqual(result.estimatedTokens, 0)
  }

  // MARK: - estimateTokens() Property Preservation Tests

  // Tests that all original properties are preserved.
  func test_estimateTokens_preservesOriginalProperties() {
    let original = FileAttachment(
      id: "abc123",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdCBkYXRh",
      estimatedTokens: nil
    )

    let result = sut.estimateTokens(for: original)

    XCTAssertEqual(result.id, original.id)
    XCTAssertEqual(result.filename, original.filename)
    XCTAssertEqual(result.mimeType, original.mimeType)
    XCTAssertEqual(result.sizeBytes, original.sizeBytes)
    XCTAssertEqual(result.base64Data, original.base64Data)
    XCTAssertEqual(result.estimatedTokens, 258)
  }

  // Tests that existing estimatedTokens is overwritten.
  func test_estimateTokens_overwritesExistingTokens() {
    let original = FileAttachment(
      id: "test",
      filename: "test.png",
      mimeType: .png,
      sizeBytes: 1000,
      base64Data: "dGVzdA==",
      estimatedTokens: 999
    )

    let result = sut.estimateTokens(for: original)

    XCTAssertEqual(result.estimatedTokens, 258)
    XCTAssertNotEqual(result.estimatedTokens, 999)
  }

  // Tests that function is pure and idempotent.
  func test_estimateTokens_isPureAndIdempotent() {
    let attachment = FileAttachment(
      id: "test",
      filename: "test.pdf",
      mimeType: .pdf,
      sizeBytes: 204_800,
      base64Data: "dGVzdA==",
      estimatedTokens: nil
    )

    let result1 = sut.estimateTokens(for: attachment)
    let result2 = sut.estimateTokens(for: attachment)
    let result3 = sut.estimateTokens(for: attachment)

    XCTAssertEqual(result1.estimatedTokens, result2.estimatedTokens)
    XCTAssertEqual(result2.estimatedTokens, result3.estimatedTokens)
  }
}

// MARK: - Integration Tests

final class AttachmentServiceIntegrationTests: XCTestCase {

  // Tests full flow with real validator.
  var validator: AttachmentValidator!
  var processor: AttachmentProcessor!
  var tempDirectory: URL!

  override func setUp() {
    super.setUp()
    validator = AttachmentValidator()
    processor = AttachmentProcessor(validator: validator)

    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(
      at: tempDirectory,
      withIntermediateDirectories: true
    )
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: tempDirectory)
    tempDirectory = nil
    processor = nil
    validator = nil
    super.tearDown()
  }

  // Tests full flow: create attachment then estimate tokens.
  func test_fullFlow_createThenEstimate_succeeds() async throws {
    // Create a test PNG file.
    let testData = Data(repeating: 0x89, count: 1024)
    let testURL = tempDirectory.appendingPathComponent("photo.png")
    try testData.write(to: testURL)

    // Create attachment.
    let attachment = try await processor.createAttachment(from: testURL)

    // Verify initial state.
    XCTAssertNil(attachment.estimatedTokens)

    // Estimate tokens.
    let withTokens = processor.estimateTokens(for: attachment)

    // Verify token estimation.
    XCTAssertEqual(withTokens.estimatedTokens, 258)
    XCTAssertEqual(withTokens.filename, "photo.png")
    XCTAssertEqual(withTokens.mimeType, .png)
  }

  // Tests error propagation through full stack.
  func test_errorPropagation_unsupportedFile_propagates() async {
    let testURL = tempDirectory.appendingPathComponent("document.docx")
    try? Data([0x01]).write(to: testURL)

    do {
      _ = try await processor.createAttachment(from: testURL)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(
        error as? AttachmentError,
        .unsupportedFileType(extension: "docx")
      )
    }
  }

  // Tests error propagation for empty file.
  func test_errorPropagation_emptyFile_propagates() async {
    let testURL = tempDirectory.appendingPathComponent("empty.txt")
    try? Data().write(to: testURL)

    do {
      _ = try await processor.createAttachment(from: testURL)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(
        error as? AttachmentError,
        .emptyFile(filename: "empty.txt")
      )
    }
  }

  // Tests token budget validation with estimated tokens.
  func test_fullFlow_validateTokenBudget_afterEstimation() async throws {
    // Create a test PDF file.
    let testData = Data(repeating: 0x25, count: 512_000)
    let testURL = tempDirectory.appendingPathComponent("document.pdf")
    try testData.write(to: testURL)

    // Create and estimate.
    let attachment = try await processor.createAttachment(from: testURL)
    let withTokens = processor.estimateTokens(for: attachment)

    // Expected tokens: 5 pages * 750 = 3750.
    XCTAssertEqual(withTokens.estimatedTokens, 3750)

    // Validate token budget - should pass.
    XCTAssertNoThrow(
      try validator.validateTokenBudget(
        attachment: withTokens,
        currentUsage: 1000,
        budget: 10000
      )
    )

    // Validate token budget - should fail.
    XCTAssertThrowsError(
      try validator.validateTokenBudget(
        attachment: withTokens,
        currentUsage: 7000,
        budget: 10000
      )
    ) { error in
      XCTAssertEqual(
        error as? AttachmentError,
        .tokenBudgetExceeded(estimatedTokens: 3750, availableTokens: 3000)
      )
    }
  }
}
