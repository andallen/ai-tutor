// AttachmentServiceContract.swift
// Defines the implementation specifications for AttachmentValidator and AttachmentProcessor.
// Phase 2 of Document Upload Handling: Service layer implementations.
// This contract provides complete specifications for test-driven development.
// Implementations conform to protocols defined in AttachmentContract.swift.

import Foundation

// MARK: - AttachmentValidator Implementation Contract

// AttachmentValidator is a struct implementing AttachmentValidationProtocol.
// Provides stateless validation of file attachments.
// All methods are synchronous and do not retain state.

struct AttachmentValidator: AttachmentValidationProtocol {
  // Validates a file by checking its extension against supported types.
  // url: The file URL to validate.
  // Returns: The detected AttachmentMimeType.
  // Throws: AttachmentError.unsupportedFileType if extension not recognized.
  func validateFile(at url: URL) throws -> AttachmentMimeType {
    let ext = url.pathExtension
    guard let mimeType = AttachmentMimeType(fromExtension: ext) else {
      throw AttachmentError.unsupportedFileType(extension: ext)
    }
    return mimeType
  }

  // Validates file data for size and emptiness constraints.
  // data: The file data to validate.
  // filename: The original filename for error messages.
  // mimeType: The MIME type to determine size limits.
  // Throws: AttachmentError.emptyFile or AttachmentError.fileTooLarge.
  func validateData(
    _ data: Data,
    filename: String,
    mimeType: AttachmentMimeType
  ) throws {
    guard !data.isEmpty else {
      throw AttachmentError.emptyFile(filename: filename)
    }
    let limit = AttachmentSizeLimits.sizeLimit(for: mimeType)
    guard data.count <= limit else {
      throw AttachmentError.fileTooLarge(
        filename: filename,
        sizeBytes: data.count,
        limitBytes: limit
      )
    }
  }

  // Validates that an attachment fits within the available token budget.
  // attachment: The attachment to validate.
  // currentUsage: Tokens already used in the conversation.
  // budget: Maximum total token budget.
  // Throws: AttachmentError.tokenBudgetExceeded if over budget.
  func validateTokenBudget(
    attachment: FileAttachment,
    currentUsage: Int,
    budget: Int
  ) throws {
    let available = budget - currentUsage
    let estimated = attachment.estimatedTokens ?? 0
    guard estimated <= available else {
      throw AttachmentError.tokenBudgetExceeded(
        estimatedTokens: estimated,
        availableTokens: available
      )
    }
  }
}

// MARK: - AttachmentValidator.validateFile() Implementation Specification

/*
 IMPLEMENTATION: validateFile(at url: URL) throws -> AttachmentMimeType

 STEPS:
 1. Get file extension from URL using url.pathExtension
 2. Call AttachmentMimeType(fromExtension:) with the extension
 3. If result is nil, throw AttachmentError.unsupportedFileType(extension:)
 4. Return the detected MIME type
*/

/*
 ACCEPTANCE CRITERIA: AttachmentValidator.validateFile()

 SCENARIO: Validate PNG file
 GIVEN: A URL with path "/documents/image.png"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.png

 SCENARIO: Validate JPEG file with jpg extension
 GIVEN: A URL with path "/documents/photo.jpg"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.jpeg

 SCENARIO: Validate JPEG file with jpeg extension
 GIVEN: A URL with path "/documents/photo.jpeg"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.jpeg

 SCENARIO: Validate PDF file
 GIVEN: A URL with path "/documents/report.pdf"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.pdf

 SCENARIO: Validate plain text file with txt extension
 GIVEN: A URL with path "/documents/notes.txt"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.plainText

 SCENARIO: Validate WebP file
 GIVEN: A URL with path "/documents/image.webp"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.webp

 SCENARIO: Validate HEIC file
 GIVEN: A URL with path "/documents/photo.heic"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.heic

 SCENARIO: Validate HEIF file
 GIVEN: A URL with path "/documents/photo.heif"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.heif

 SCENARIO: Validate GIF file
 GIVEN: A URL with path "/documents/animation.gif"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.gif

 SCENARIO: Reject unsupported file type
 GIVEN: A URL with path "/documents/document.docx"
 WHEN: validateFile(at:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "docx")

 SCENARIO: Reject unknown file type
 GIVEN: A URL with path "/documents/data.xyz"
 WHEN: validateFile(at:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "xyz")

 SCENARIO: Case insensitive extension matching
 GIVEN: A URL with path "/documents/IMAGE.PNG"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.png

 SCENARIO: Mixed case extension
 GIVEN: A URL with path "/documents/Photo.JpEg"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.jpeg
*/

/*
 EDGE CASES: AttachmentValidator.validateFile()

 EDGE CASE: File with no extension
 GIVEN: A URL with path "/documents/README"
 WHEN: validateFile(at:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "")
  AND: url.pathExtension returns "" for files without extensions

 EDGE CASE: File with empty name and extension only
 GIVEN: A URL with path "/documents/.txt"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.plainText
  AND: url.pathExtension correctly extracts "txt"

 EDGE CASE: File with multiple dots in name
 GIVEN: A URL with path "/documents/report.2024.final.pdf"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.pdf
  AND: url.pathExtension correctly returns "pdf" (last component)

 EDGE CASE: File path with spaces
 GIVEN: A URL with path "/my documents/my file.png"
 WHEN: validateFile(at:) is called
 THEN: Returns AttachmentMimeType.png
  AND: URL path handling manages spaces correctly

 EDGE CASE: URL with query parameters
 GIVEN: A URL with path "/documents/image.png?version=2"
 WHEN: validateFile(at:) is called
 THEN: Behavior depends on URL construction
  AND: File URLs typically do not have query parameters

 EDGE CASE: Very long extension
 GIVEN: A URL with path "/documents/file.verylongextension"
 WHEN: validateFile(at:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "verylongextension")

 EDGE CASE: Numeric extension
 GIVEN: A URL with path "/documents/archive.001"
 WHEN: validateFile(at:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "001")
*/

// MARK: - AttachmentValidator.validateData() Implementation Specification

/*
 IMPLEMENTATION: validateData(_ data: Data, filename: String, mimeType: AttachmentMimeType) throws

 STEPS:
 1. Check if data.isEmpty, if true throw AttachmentError.emptyFile(filename:)
 2. Get size limit by calling AttachmentSizeLimits.sizeLimit(for: mimeType)
 3. Compare data.count against the size limit
 4. If data.count > limit, throw AttachmentError.fileTooLarge(filename:sizeBytes:limitBytes:)
 5. If all validations pass, return without error
*/

/*
 ACCEPTANCE CRITERIA: AttachmentValidator.validateData()

 SCENARIO: Validate image data within size limit
 GIVEN: PNG data of 10MB (10 * 1024 * 1024 bytes)
  AND: filename = "photo.png"
  AND: mimeType = .png
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: Data is within 20MB limit for images

 SCENARIO: Validate image data at exact size limit
 GIVEN: PNG data of exactly 20MB (20 * 1024 * 1024 bytes)
  AND: filename = "large.png"
  AND: mimeType = .png
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: Boundary condition passes (equal to limit is valid)

 SCENARIO: Reject oversized image data
 GIVEN: PNG data of 25MB (25 * 1024 * 1024 bytes)
  AND: filename = "huge.png"
  AND: mimeType = .png
 WHEN: validateData() is called
 THEN: Throws AttachmentError.fileTooLarge(
   filename: "huge.png",
   sizeBytes: 26214400,
   limitBytes: 20971520
 )

 SCENARIO: Validate PDF data within size limit
 GIVEN: PDF data of 30MB (30 * 1024 * 1024 bytes)
  AND: filename = "document.pdf"
  AND: mimeType = .pdf
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: Data is within 50MB limit for PDFs

 SCENARIO: Reject oversized PDF data
 GIVEN: PDF data of 60MB (60 * 1024 * 1024 bytes)
  AND: filename = "massive.pdf"
  AND: mimeType = .pdf
 WHEN: validateData() is called
 THEN: Throws AttachmentError.fileTooLarge(
   filename: "massive.pdf",
   sizeBytes: 62914560,
   limitBytes: 52428800
 )

 SCENARIO: Validate plain text data within size limit
 GIVEN: Text data of 500KB (500 * 1024 bytes)
  AND: filename = "notes.txt"
  AND: mimeType = .plainText
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: Data is within 1MB limit for plain text

 SCENARIO: Reject oversized plain text data
 GIVEN: Text data of 2MB (2 * 1024 * 1024 bytes)
  AND: filename = "large.txt"
  AND: mimeType = .plainText
 WHEN: validateData() is called
 THEN: Throws AttachmentError.fileTooLarge(
   filename: "large.txt",
   sizeBytes: 2097152,
   limitBytes: 1048576
 )

 SCENARIO: Reject empty data
 GIVEN: Empty Data (0 bytes)
  AND: filename = "empty.png"
  AND: mimeType = .png
 WHEN: validateData() is called
 THEN: Throws AttachmentError.emptyFile(filename: "empty.png")

 SCENARIO: Empty data check happens before size check
 GIVEN: Empty Data (0 bytes)
  AND: Any filename and mimeType
 WHEN: validateData() is called
 THEN: Throws AttachmentError.emptyFile
  AND: Does not throw fileTooLarge even though 0 < limit
*/

/*
 EDGE CASES: AttachmentValidator.validateData()

 EDGE CASE: Single byte data
 GIVEN: Data with exactly 1 byte
  AND: filename = "tiny.txt"
  AND: mimeType = .plainText
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: Single byte is valid (not empty)

 EDGE CASE: Data exactly one byte over limit
 GIVEN: PNG data of 20MB + 1 byte
  AND: filename = "tooLarge.png"
  AND: mimeType = .png
 WHEN: validateData() is called
 THEN: Throws AttachmentError.fileTooLarge
  AND: Boundary is strictly enforced

 EDGE CASE: Filename with unicode characters
 GIVEN: Valid data
  AND: filename = "document.pdf"
  AND: mimeType = .pdf
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: Unicode filename is preserved in any error if thrown

 EDGE CASE: Filename with special characters
 GIVEN: Valid data
  AND: filename = "file (copy).png"
  AND: mimeType = .png
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: Special characters in filename are preserved

 EDGE CASE: Empty filename string
 GIVEN: Valid data
  AND: filename = ""
  AND: mimeType = .png
 WHEN: validateData() is called
 THEN: No error is thrown (filename only used for error messages)
  AND: Empty filename would appear in error if size exceeded

 EDGE CASE: Mismatched MIME type and actual content
 GIVEN: JPEG data
  AND: filename = "image.jpg"
  AND: mimeType = .png (mismatched)
 WHEN: validateData() is called
 THEN: No error is thrown
  AND: validateData does not inspect actual file content
  AND: Size limit for .png (20MB) is applied regardless of actual content

 EDGE CASE: All image MIME types use same size limit
 GIVEN: 15MB of data
  AND: Each image MIME type (.png, .jpeg, .webp, .heic, .heif, .gif)
 WHEN: validateData() is called for each
 THEN: No error is thrown for any
  AND: All image types share the 20MB limit
*/

// MARK: - AttachmentValidator.validateTokenBudget() Implementation Specification

/*
 IMPLEMENTATION: validateTokenBudget(attachment: FileAttachment, currentUsage: Int, budget: Int) throws

 STEPS:
 1. Calculate availableTokens = budget - currentUsage
 2. Get estimatedTokens from attachment.estimatedTokens, defaulting to 0 if nil
 3. If estimatedTokens > availableTokens, throw AttachmentError.tokenBudgetExceeded
 4. If within budget, return without error
*/

/*
 ACCEPTANCE CRITERIA: AttachmentValidator.validateTokenBudget()

 SCENARIO: Attachment within token budget
 GIVEN: Attachment with estimatedTokens = 1000
  AND: currentUsage = 5000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: No error is thrown
  AND: Available = 10000 - 5000 = 5000, which is >= 1000

 SCENARIO: Attachment exactly at token budget
 GIVEN: Attachment with estimatedTokens = 5000
  AND: currentUsage = 5000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: No error is thrown
  AND: Available = 5000, estimatedTokens = 5000, boundary passes

 SCENARIO: Attachment exceeds token budget by small amount
 GIVEN: Attachment with estimatedTokens = 5001
  AND: currentUsage = 5000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: Throws AttachmentError.tokenBudgetExceeded(
   estimatedTokens: 5001,
   availableTokens: 5000
 )

 SCENARIO: Attachment greatly exceeds token budget
 GIVEN: Attachment with estimatedTokens = 50000
  AND: currentUsage = 8000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: Throws AttachmentError.tokenBudgetExceeded(
   estimatedTokens: 50000,
   availableTokens: 2000
 )

 SCENARIO: Attachment with nil estimatedTokens
 GIVEN: Attachment with estimatedTokens = nil
  AND: currentUsage = 5000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: No error is thrown
  AND: Nil estimatedTokens defaults to 0

 SCENARIO: Zero token budget remaining
 GIVEN: Attachment with estimatedTokens = 1
  AND: currentUsage = 10000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: Throws AttachmentError.tokenBudgetExceeded(
   estimatedTokens: 1,
   availableTokens: 0
 )

 SCENARIO: Zero estimated tokens with zero budget
 GIVEN: Attachment with estimatedTokens = 0
  AND: currentUsage = 10000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: No error is thrown
  AND: Zero tokens fit in zero available budget
*/

/*
 EDGE CASES: AttachmentValidator.validateTokenBudget()

 EDGE CASE: Negative available tokens (usage exceeds budget)
 GIVEN: Attachment with estimatedTokens = 100
  AND: currentUsage = 12000
  AND: budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: Throws AttachmentError.tokenBudgetExceeded(
   estimatedTokens: 100,
   availableTokens: -2000
 )
  AND: Negative available tokens handled correctly

 EDGE CASE: Very large estimatedTokens value
 GIVEN: Attachment with estimatedTokens = Int.max
  AND: currentUsage = 0
  AND: budget = 100000
 WHEN: validateTokenBudget() is called
 THEN: Throws AttachmentError.tokenBudgetExceeded
  AND: No integer overflow occurs

 EDGE CASE: Budget of zero
 GIVEN: Attachment with estimatedTokens = 0
  AND: currentUsage = 0
  AND: budget = 0
 WHEN: validateTokenBudget() is called
 THEN: No error is thrown
  AND: Zero fits in zero budget

 EDGE CASE: All zeros
 GIVEN: Attachment with estimatedTokens = nil (defaults to 0)
  AND: currentUsage = 0
  AND: budget = 0
 WHEN: validateTokenBudget() is called
 THEN: No error is thrown
*/

// MARK: - AttachmentProcessor Implementation Contract

// AttachmentProcessor is a struct implementing AttachmentProcessorProtocol.
// Uses dependency injection for the validator to enable testing.
// Handles file I/O and base64 encoding.

struct AttachmentProcessor: AttachmentProcessorProtocol {
  // Validator used for file and data validation.
  // Injected via initializer for testability.
  let validator: AttachmentValidationProtocol

  // Creates a processor with the specified validator.
  // validator: The validator to use for file validation.
  init(validator: AttachmentValidationProtocol) {
    self.validator = validator
  }

  // Reads a file and creates a FileAttachment.
  // url: The file URL to read.
  // Returns: FileAttachment with base64-encoded data.
  // Throws: AttachmentError if validation or reading fails.
  func createAttachment(from url: URL) async throws -> FileAttachment {
    // Validate file type first.
    let mimeType = try validator.validateFile(at: url)

    // Extract filename from URL.
    let filename = url.lastPathComponent

    // Read file data.
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw AttachmentError.readFailed(
        filename: filename,
        reason: error.localizedDescription
      )
    }

    // Validate data size.
    try validator.validateData(data, filename: filename, mimeType: mimeType)

    // Generate unique ID and encode data.
    let id = UUID().uuidString
    let base64Data = data.base64EncodedString()

    return FileAttachment(
      id: id,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: data.count,
      base64Data: base64Data,
      estimatedTokens: nil
    )
  }

  // Estimates token cost for an attachment based on its type and size.
  // attachment: The attachment to estimate tokens for.
  // Returns: New FileAttachment with estimatedTokens populated.
  func estimateTokens(for attachment: FileAttachment) -> FileAttachment {
    let tokens: Int
    switch attachment.mimeType {
    case .png, .jpeg, .webp, .heic, .heif, .gif:
      // Fixed token cost for images.
      tokens = AttachmentTokenEstimation.tokensPerImage
    case .pdf:
      // Estimate pages from size (assume ~100KB per page).
      let bytesPerPage = 100 * 1024
      let pages = max(1, attachment.sizeBytes / bytesPerPage)
      tokens = pages * AttachmentTokenEstimation.tokensPerPDFPage
    case .plainText:
      // Calculate tokens from character count.
      tokens = Int(Double(attachment.sizeBytes) / AttachmentTokenEstimation.charsPerToken)
    }

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

// MARK: - AttachmentProcessor.createAttachment() Implementation Specification

/*
 IMPLEMENTATION: createAttachment(from url: URL) async throws -> FileAttachment

 STEPS:
 1. Call validator.validateFile(at: url) to get mimeType
    - Throws AttachmentError.unsupportedFileType if extension not recognized
 2. Extract filename from url using url.lastPathComponent
 3. Read file data using Data(contentsOf: url)
    - Catch any errors and wrap in AttachmentError.readFailed(filename:reason:)
 4. Call validator.validateData(data, filename: filename, mimeType: mimeType)
    - Throws AttachmentError.emptyFile or AttachmentError.fileTooLarge
 5. Generate unique ID using UUID().uuidString
 6. Encode data to base64 using data.base64EncodedString()
 7. Create and return FileAttachment with:
    - id: Generated UUID string
    - filename: Extracted from URL
    - mimeType: From validation
    - sizeBytes: data.count
    - base64Data: Encoded string
    - estimatedTokens: nil (not estimated at creation time)
*/

/*
 ACCEPTANCE CRITERIA: AttachmentProcessor.createAttachment()

 SCENARIO: Create attachment from valid PNG file
 GIVEN: A valid PNG file at path "/tmp/test.png" with 1KB of data
  AND: File exists and is readable
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with:
  - id is a valid UUID string (36 characters, hyphenated format)
  - filename = "test.png"
  - mimeType = .png
  - sizeBytes = 1024
  - base64Data is valid base64 encoding of file contents
  - estimatedTokens = nil

 SCENARIO: Create attachment from valid PDF file
 GIVEN: A valid PDF file at path "/documents/report.pdf" with 2MB of data
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with:
  - mimeType = .pdf
  - sizeBytes = 2097152
  - base64Data length is approximately 4/3 * sizeBytes

 SCENARIO: Create attachment from valid text file
 GIVEN: A valid text file at path "/notes/readme.txt" with 500 bytes
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with:
  - mimeType = .plainText
  - sizeBytes = 500

 SCENARIO: Validation occurs before file read
 GIVEN: A URL pointing to an unsupported file type "/tmp/doc.docx"
 WHEN: createAttachment(from:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "docx")
  AND: File contents are never read

 SCENARIO: File read error wrapped in AttachmentError
 GIVEN: A URL pointing to a non-existent file "/tmp/missing.png"
 WHEN: createAttachment(from:) is called
 THEN: Throws AttachmentError.readFailed(
   filename: "missing.png",
   reason: <system error description>
 )

 SCENARIO: Permission denied wrapped in AttachmentError
 GIVEN: A URL pointing to a file without read permission
 WHEN: createAttachment(from:) is called
 THEN: Throws AttachmentError.readFailed(
   filename: <filename>,
   reason: <permission error description>
 )

 SCENARIO: Empty file rejected after read
 GIVEN: A file that exists but contains 0 bytes at "/tmp/empty.txt"
 WHEN: createAttachment(from:) is called
 THEN: Throws AttachmentError.emptyFile(filename: "empty.txt")

 SCENARIO: Oversized file rejected after read
 GIVEN: A PNG file of 25MB at "/tmp/large.png"
 WHEN: createAttachment(from:) is called
 THEN: Throws AttachmentError.fileTooLarge(
   filename: "large.png",
   sizeBytes: 26214400,
   limitBytes: 20971520
 )

 SCENARIO: Each call generates unique ID
 GIVEN: The same file at "/tmp/test.png"
 WHEN: createAttachment(from:) is called twice
 THEN: Each returned FileAttachment has a different id
  AND: Both ids are valid UUID strings
*/

/*
 EDGE CASES: AttachmentProcessor.createAttachment()

 EDGE CASE: Filename with spaces
 GIVEN: File at "/tmp/my photo.png"
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with filename = "my photo.png"
  AND: Spaces preserved in filename

 EDGE CASE: Filename with unicode characters
 GIVEN: File at "/tmp/document.pdf"
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with filename containing unicode
  AND: Unicode preserved correctly

 EDGE CASE: Very long filename
 GIVEN: File with 255-character filename
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with full filename
  AND: No truncation occurs

 EDGE CASE: File in deeply nested directory
 GIVEN: File at "/a/b/c/d/e/f/g/file.png"
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with filename = "file.png"
  AND: Only the last path component is used

 EDGE CASE: Hidden file (starts with dot)
 GIVEN: File at "/tmp/.hidden.txt"
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with filename = ".hidden.txt"

 EDGE CASE: Concurrent reads of same file
 GIVEN: Same file URL
 WHEN: createAttachment(from:) is called concurrently
 THEN: Both calls succeed independently
  AND: Each returns a unique id
  AND: File system handles concurrent reads

 EDGE CASE: File deleted between validation and read
 GIVEN: File exists during validateFile() call
 WHEN: File is deleted before Data(contentsOf:) call
 THEN: Throws AttachmentError.readFailed
  AND: Race condition produces appropriate error

 EDGE CASE: File modified between read and return
 GIVEN: File is modified during createAttachment execution
 WHEN: Modification occurs after Data(contentsOf:)
 THEN: Returned FileAttachment contains data as read
  AND: Modifications not reflected (snapshot in time)

 EDGE CASE: Symbolic link to file
 GIVEN: A symbolic link at "/tmp/link.png" pointing to "/tmp/real.png"
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with filename = "link.png"
  AND: Data is read from the target file
  AND: Extension is determined from link name, not target

 EDGE CASE: URL with file:// scheme
 GIVEN: URL(string: "file:///tmp/test.png")
 WHEN: createAttachment(from:) is called
 THEN: Works correctly with file scheme URLs

 EDGE CASE: Very large file causing memory pressure
 GIVEN: A 90MB PDF file (under 100MB general limit, under 50MB PDF limit... wait)
 NOTE: This should be caught by validateData as 90MB > 50MB PDF limit
 GIVEN: A 45MB PDF file (under 50MB limit)
 WHEN: createAttachment(from:) is called
 THEN: Successfully creates attachment
  AND: Memory holds ~45MB data + ~60MB base64 string temporarily
*/

// MARK: - AttachmentProcessor.estimateTokens() Implementation Specification

/*
 IMPLEMENTATION: estimateTokens(for attachment: FileAttachment) -> FileAttachment

 STEPS:
 1. Determine token estimate based on mimeType:
    a. For image types (.png, .jpeg, .webp, .heic, .heif, .gif):
       - Return AttachmentTokenEstimation.tokensPerImage (258)
    b. For .pdf:
       - Estimate page count from sizeBytes (assume ~100KB per page)
       - pages = max(1, sizeBytes / (100 * 1024))
       - tokens = pages * AttachmentTokenEstimation.tokensPerPDFPage (750)
    c. For .plainText:
       - tokens = Int(Double(sizeBytes) / AttachmentTokenEstimation.charsPerToken)
 2. Create and return new FileAttachment with same properties but estimatedTokens populated
*/

/*
 ACCEPTANCE CRITERIA: AttachmentProcessor.estimateTokens()

 SCENARIO: Estimate tokens for PNG image
 GIVEN: FileAttachment with mimeType = .png, sizeBytes = 5_000_000
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with estimatedTokens = 258
  AND: All other properties unchanged

 SCENARIO: Estimate tokens for JPEG image
 GIVEN: FileAttachment with mimeType = .jpeg, sizeBytes = 2_000_000
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with estimatedTokens = 258
  AND: Image size does not affect token count

 SCENARIO: Estimate tokens for all image types
 GIVEN: FileAttachments with each image mimeType (.png, .jpeg, .webp, .heic, .heif, .gif)
 WHEN: estimateTokens(for:) is called for each
 THEN: Each returns estimatedTokens = 258
  AND: All image types have fixed token cost

 SCENARIO: Estimate tokens for small PDF (1 page)
 GIVEN: FileAttachment with mimeType = .pdf, sizeBytes = 50_000 (50KB)
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with estimatedTokens = 750
  AND: pages = max(1, 50000 / 102400) = max(1, 0) = 1
  AND: tokens = 1 * 750 = 750

 SCENARIO: Estimate tokens for medium PDF (5 pages)
 GIVEN: FileAttachment with mimeType = .pdf, sizeBytes = 512_000 (500KB)
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with estimatedTokens = 3750
  AND: pages = max(1, 512000 / 102400) = max(1, 5) = 5
  AND: tokens = 5 * 750 = 3750

 SCENARIO: Estimate tokens for large PDF (50 pages)
 GIVEN: FileAttachment with mimeType = .pdf, sizeBytes = 5_120_000 (5MB)
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with estimatedTokens = 37500
  AND: pages = max(1, 5120000 / 102400) = max(1, 50) = 50
  AND: tokens = 50 * 750 = 37500

 SCENARIO: Estimate tokens for plain text
 GIVEN: FileAttachment with mimeType = .plainText, sizeBytes = 4000
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with estimatedTokens = 1000
  AND: tokens = Int(4000 / 4.0) = 1000

 SCENARIO: Estimate tokens for larger plain text
 GIVEN: FileAttachment with mimeType = .plainText, sizeBytes = 100_000 (100KB)
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with estimatedTokens = 25000
  AND: tokens = Int(100000 / 4.0) = 25000

 SCENARIO: Returned attachment preserves original properties
 GIVEN: FileAttachment with id="abc", filename="test.png", mimeType=.png,
        sizeBytes=1000, base64Data="...", estimatedTokens=nil
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with:
  - id = "abc" (unchanged)
  - filename = "test.png" (unchanged)
  - mimeType = .png (unchanged)
  - sizeBytes = 1000 (unchanged)
  - base64Data = "..." (unchanged)
  - estimatedTokens = 258 (newly calculated)

 SCENARIO: Overwrite existing estimatedTokens
 GIVEN: FileAttachment with estimatedTokens = 999 (pre-existing value)
 WHEN: estimateTokens(for:) is called
 THEN: Returns FileAttachment with newly calculated estimatedTokens
  AND: Previous value is replaced
*/

/*
 EDGE CASES: AttachmentProcessor.estimateTokens()

 EDGE CASE: Very small PDF (minimum 1 page)
 GIVEN: FileAttachment with mimeType = .pdf, sizeBytes = 1 (1 byte)
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 750
  AND: pages = max(1, 0) = 1 (minimum of 1 page)

 EDGE CASE: PDF exactly at 100KB boundary
 GIVEN: FileAttachment with mimeType = .pdf, sizeBytes = 102_400 (100KB)
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 750
  AND: pages = 102400 / 102400 = 1

 EDGE CASE: PDF just over 100KB boundary
 GIVEN: FileAttachment with mimeType = .pdf, sizeBytes = 102_401
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 750
  AND: pages = 102401 / 102400 = 1 (integer division truncates)

 EDGE CASE: Very large PDF
 GIVEN: FileAttachment with mimeType = .pdf, sizeBytes = 50_000_000 (50MB)
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 366750
  AND: pages = 50000000 / 102400 = 488
  AND: tokens = 488 * 750 = 366000 (approximately)

 EDGE CASE: Empty plain text file (sizeBytes = 0)
 GIVEN: FileAttachment with mimeType = .plainText, sizeBytes = 0
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 0
  AND: tokens = Int(0 / 4.0) = 0
 NOTE: Empty files should be rejected earlier by validateData

 EDGE CASE: Single character text file
 GIVEN: FileAttachment with mimeType = .plainText, sizeBytes = 1
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 0
  AND: tokens = Int(1 / 4.0) = Int(0.25) = 0

 EDGE CASE: Plain text with 3 bytes
 GIVEN: FileAttachment with mimeType = .plainText, sizeBytes = 3
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 0
  AND: tokens = Int(3 / 4.0) = Int(0.75) = 0

 EDGE CASE: Plain text with 4 bytes
 GIVEN: FileAttachment with mimeType = .plainText, sizeBytes = 4
 WHEN: estimateTokens(for:) is called
 THEN: Returns estimatedTokens = 1
  AND: tokens = Int(4 / 4.0) = 1

 EDGE CASE: Function is pure and idempotent
 GIVEN: Same FileAttachment
 WHEN: estimateTokens(for:) is called multiple times
 THEN: Returns identical results each time
  AND: No side effects occur
*/

// MARK: - Error Handling Specifications

/*
 ERROR FLOW: File validation errors propagate correctly

 SCENARIO: Unsupported file type error propagation
 GIVEN: URL to unsupported file type
 WHEN: createAttachment(from:) is called
 THEN: validator.validateFile() throws AttachmentError.unsupportedFileType
  AND: Error propagates to caller unchanged
  AND: No file read is attempted

 SCENARIO: Empty file error propagation
 GIVEN: URL to empty file
 WHEN: createAttachment(from:) is called
 THEN: validator.validateData() throws AttachmentError.emptyFile
  AND: Error propagates to caller unchanged

 SCENARIO: File too large error propagation
 GIVEN: URL to oversized file
 WHEN: createAttachment(from:) is called
 THEN: validator.validateData() throws AttachmentError.fileTooLarge
  AND: Error propagates to caller unchanged

 SCENARIO: System file read error wrapping
 GIVEN: URL to missing file
 WHEN: Data(contentsOf:) throws NSError
 THEN: Error is caught and wrapped in AttachmentError.readFailed
  AND: Original error's localizedDescription becomes the reason
*/

// MARK: - Dependency Injection Pattern

/*
 DESIGN: AttachmentProcessor uses dependency injection for validator

 RATIONALE:
 1. Enables unit testing with mock validator
 2. Allows different validation strategies
 3. Follows SOLID principles (Dependency Inversion)

 USAGE:
 - Production: AttachmentProcessor(validator: AttachmentValidator())
 - Testing: AttachmentProcessor(validator: MockValidator())

 MOCK VALIDATOR REQUIREMENTS:
 - Conforms to AttachmentValidationProtocol
 - Can be configured to return specific results or throw specific errors
 - Enables testing of createAttachment error paths
*/

// MARK: - Concurrency Considerations

/*
 CONCURRENCY: AttachmentValidator is Sendable

 - AttachmentValidator has no mutable state
 - All methods are synchronous and stateless
 - Safe to use from any actor or thread
 - Conforms to Sendable via AttachmentValidationProtocol requirement
*/

/*
 CONCURRENCY: AttachmentProcessor is Sendable

 - AttachmentProcessor stores only a validator reference (also Sendable)
 - createAttachment is async but stateless
 - estimateTokens is synchronous and stateless
 - Safe to use from any actor or thread
 - Conforms to Sendable via AttachmentProcessorProtocol requirement
*/

/*
 CONCURRENCY: File I/O considerations

 - Data(contentsOf:) performs synchronous I/O
 - Wrapped in async function for use with Swift concurrency
 - Large files may block the calling thread briefly
 - Consider using file coordinator for shared file access in future

 FUTURE CONSIDERATION: Use FileManager with Data.ReadingOptions.mappedIfSafe
 for very large files to reduce memory pressure.
*/

// MARK: - Testing Support

/*
 TESTING: AttachmentValidator Unit Tests

 1. validateFile happy paths for all supported extensions
 2. validateFile case insensitivity
 3. validateFile rejection of unsupported types
 4. validateFile handling of empty extension
 5. validateData acceptance of valid sizes per type
 6. validateData rejection of empty data
 7. validateData rejection of oversized data per type
 8. validateData boundary conditions (exact limit, limit + 1)
 9. validateTokenBudget acceptance when within budget
 10. validateTokenBudget rejection when over budget
 11. validateTokenBudget handling of nil estimatedTokens
 12. validateTokenBudget handling of negative available tokens

 TESTING: AttachmentProcessor Unit Tests

 1. createAttachment with valid files (requires file system setup)
 2. createAttachment with mock validator for error path testing
 3. createAttachment unique ID generation
 4. createAttachment base64 encoding correctness
 5. estimateTokens for image types (fixed 258)
 6. estimateTokens for PDF (page calculation)
 7. estimateTokens for plain text (character division)
 8. estimateTokens preservation of original properties
 9. estimateTokens edge cases (minimum pages, boundary conditions)

 TESTING: Integration Tests

 1. Full flow: validate -> read -> encode -> estimate
 2. Error propagation through full stack
 3. Concurrent processing of multiple files
*/

// MARK: - Constants Reference

/*
 CONSTANTS USED (from AttachmentContract.swift):

 AttachmentSizeLimits:
 - maxImageSize: 20 * 1024 * 1024 (20MB)
 - maxPDFSize: 50 * 1024 * 1024 (50MB)
 - maxPlainTextSize: 1 * 1024 * 1024 (1MB)

 AttachmentTokenEstimation:
 - tokensPerImage: 258
 - tokensPerPDFPage: 750
 - charsPerToken: 4.0

 PDF Page Estimation:
 - Assumed bytes per page: 100 * 1024 (100KB)
 - Formula: pages = max(1, sizeBytes / 102400)
*/
