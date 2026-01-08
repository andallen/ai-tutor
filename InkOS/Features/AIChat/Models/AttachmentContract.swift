// AttachmentContract.swift
// Defines the API contract for file attachments in AI Chat.
// Phase 1 of Document Upload Handling: Models and types for file attachments.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.
// UI components will be added in a later phase; this is backend/service layer only.

import Foundation

// MARK: - API Contract

// MARK: - AttachmentMimeType Enum

// Represents supported MIME types for file attachments.
// Based on Gemini API supported media types.
// String raw value for JSON encoding and API compatibility.
enum AttachmentMimeType: String, Sendable, Codable, CaseIterable, Equatable {
  // Image types
  case png = "image/png"
  case jpeg = "image/jpeg"
  case webp = "image/webp"
  case heic = "image/heic"
  case heif = "image/heif"
  case gif = "image/gif"

  // Document types
  case pdf = "application/pdf"
  case plainText = "text/plain"

  // Returns true if this MIME type represents an image.
  var isImage: Bool {
    switch self {
    case .png, .jpeg, .webp, .heic, .heif, .gif:
      return true
    case .pdf, .plainText:
      return false
    }
  }

  // Returns true if this MIME type represents a document.
  var isDocument: Bool {
    switch self {
    case .pdf, .plainText:
      return true
    case .png, .jpeg, .webp, .heic, .heif, .gif:
      return false
    }
  }

  // Creates a MIME type from a file extension.
  // Returns nil if the extension is not supported.
  // extension: The file extension without the leading dot (e.g., "png", "pdf").
  init?(fromExtension ext: String) {
    let lowercased = ext.lowercased()
    switch lowercased {
    case "png":
      self = .png
    case "jpg", "jpeg":
      self = .jpeg
    case "webp":
      self = .webp
    case "heic":
      self = .heic
    case "heif":
      self = .heif
    case "gif":
      self = .gif
    case "pdf":
      self = .pdf
    case "txt", "text":
      self = .plainText
    default:
      return nil
    }
  }
}

/*
 ACCEPTANCE CRITERIA: AttachmentMimeType Raw Values

 SCENARIO: All image MIME types have correct raw values
 GIVEN: Each image case in AttachmentMimeType
 WHEN: rawValue is accessed
 THEN: .png.rawValue is "image/png"
  AND: .jpeg.rawValue is "image/jpeg"
  AND: .webp.rawValue is "image/webp"
  AND: .heic.rawValue is "image/heic"
  AND: .heif.rawValue is "image/heif"
  AND: .gif.rawValue is "image/gif"

 SCENARIO: All document MIME types have correct raw values
 GIVEN: Each document case in AttachmentMimeType
 WHEN: rawValue is accessed
 THEN: .pdf.rawValue is "application/pdf"
  AND: .plainText.rawValue is "text/plain"
*/

/*
 ACCEPTANCE CRITERIA: AttachmentMimeType.isImage

 SCENARIO: Image types return true for isImage
 GIVEN: Any image MIME type (.png, .jpeg, .webp, .heic, .heif, .gif)
 WHEN: isImage is accessed
 THEN: Returns true

 SCENARIO: Document types return false for isImage
 GIVEN: Any document MIME type (.pdf, .plainText)
 WHEN: isImage is accessed
 THEN: Returns false
*/

/*
 ACCEPTANCE CRITERIA: AttachmentMimeType.isDocument

 SCENARIO: Document types return true for isDocument
 GIVEN: Any document MIME type (.pdf, .plainText)
 WHEN: isDocument is accessed
 THEN: Returns true

 SCENARIO: Image types return false for isDocument
 GIVEN: Any image MIME type (.png, .jpeg, .webp, .heic, .heif, .gif)
 WHEN: isDocument is accessed
 THEN: Returns false
*/

/*
 ACCEPTANCE CRITERIA: AttachmentMimeType.init(fromExtension:)

 SCENARIO: PNG extension maps to png MIME type
 GIVEN: File extension "png"
 WHEN: init(fromExtension: "png") is called
 THEN: Returns .png

 SCENARIO: JPEG extensions map to jpeg MIME type
 GIVEN: File extension "jpg" or "jpeg"
 WHEN: init(fromExtension:) is called
 THEN: Returns .jpeg for both "jpg" and "jpeg"

 SCENARIO: WebP extension maps to webp MIME type
 GIVEN: File extension "webp"
 WHEN: init(fromExtension: "webp") is called
 THEN: Returns .webp

 SCENARIO: HEIC extension maps to heic MIME type
 GIVEN: File extension "heic"
 WHEN: init(fromExtension: "heic") is called
 THEN: Returns .heic

 SCENARIO: HEIF extension maps to heif MIME type
 GIVEN: File extension "heif"
 WHEN: init(fromExtension: "heif") is called
 THEN: Returns .heif

 SCENARIO: GIF extension maps to gif MIME type
 GIVEN: File extension "gif"
 WHEN: init(fromExtension: "gif") is called
 THEN: Returns .gif

 SCENARIO: PDF extension maps to pdf MIME type
 GIVEN: File extension "pdf"
 WHEN: init(fromExtension: "pdf") is called
 THEN: Returns .pdf

 SCENARIO: Text extensions map to plainText MIME type
 GIVEN: File extension "txt" or "text"
 WHEN: init(fromExtension:) is called
 THEN: Returns .plainText for both "txt" and "text"

 SCENARIO: Case-insensitive extension matching
 GIVEN: File extensions in different cases ("PNG", "Png", "pNg")
 WHEN: init(fromExtension:) is called
 THEN: Returns the correct MIME type regardless of case

 SCENARIO: Unsupported extension returns nil
 GIVEN: An unsupported file extension (e.g., "docx", "mp4", "zip")
 WHEN: init(fromExtension:) is called
 THEN: Returns nil
*/

/*
 EDGE CASE: Empty extension string
 GIVEN: An empty string ""
 WHEN: init(fromExtension: "") is called
 THEN: Returns nil

 EDGE CASE: Extension with leading dot
 GIVEN: File extension ".png" (with dot)
 WHEN: init(fromExtension: ".png") is called
 THEN: Returns nil (extension should not include dot)

 EDGE CASE: Extension with whitespace
 GIVEN: File extension " png " (with whitespace)
 WHEN: init(fromExtension: " png ") is called
 THEN: Returns nil (whitespace not trimmed)
*/

// MARK: - AttachmentSizeLimits Constants

// Static constants for file size limits based on Gemini API documentation.
// All sizes are in bytes.
enum AttachmentSizeLimits {
  // Maximum file size for any attachment (100MB practical limit).
  static let maxFileSize = 100 * 1024 * 1024

  // Maximum file size for PDF documents (50MB per Gemini docs).
  static let maxPDFSize = 50 * 1024 * 1024

  // Maximum file size for image files (20MB).
  static let maxImageSize = 20 * 1024 * 1024

  // Maximum file size for plain text files (1MB).
  static let maxPlainTextSize = 1 * 1024 * 1024

  // Maximum image dimension in pixels (3072x3072 max resolution).
  static let maxImageDimension = 3072

  // Maximum number of pages for PDF documents (Gemini limit).
  static let maxPDFPages = 1000

  // Returns the size limit in bytes for a given MIME type.
  // mimeType: The MIME type to get the limit for.
  // Returns: The maximum file size in bytes for that type.
  static func sizeLimit(for mimeType: AttachmentMimeType) -> Int {
    switch mimeType {
    case .pdf:
      return maxPDFSize
    case .plainText:
      return maxPlainTextSize
    case .png, .jpeg, .webp, .heic, .heif, .gif:
      return maxImageSize
    }
  }
}

/*
 ACCEPTANCE CRITERIA: AttachmentSizeLimits Constants

 SCENARIO: All size constants have correct values
 GIVEN: AttachmentSizeLimits enum
 WHEN: Each constant is accessed
 THEN: maxFileSize is 104857600 (100 * 1024 * 1024)
  AND: maxPDFSize is 52428800 (50 * 1024 * 1024)
  AND: maxImageSize is 20971520 (20 * 1024 * 1024)
  AND: maxPlainTextSize is 1048576 (1 * 1024 * 1024)
  AND: maxImageDimension is 3072
  AND: maxPDFPages is 1000
*/

/*
 ACCEPTANCE CRITERIA: AttachmentSizeLimits.sizeLimit(for:)

 SCENARIO: PDF MIME type returns PDF size limit
 GIVEN: AttachmentMimeType.pdf
 WHEN: sizeLimit(for: .pdf) is called
 THEN: Returns maxPDFSize (52428800)

 SCENARIO: Plain text MIME type returns plain text size limit
 GIVEN: AttachmentMimeType.plainText
 WHEN: sizeLimit(for: .plainText) is called
 THEN: Returns maxPlainTextSize (1048576)

 SCENARIO: All image MIME types return image size limit
 GIVEN: Any image MIME type (.png, .jpeg, .webp, .heic, .heif, .gif)
 WHEN: sizeLimit(for:) is called
 THEN: Returns maxImageSize (20971520)
*/

// MARK: - FileAttachment Model

// Represents a file attachment ready for inclusion in a chat message.
// Contains the file data encoded as base64 for API transmission.
// Immutable once created.
struct FileAttachment: Sendable, Codable, Equatable, Identifiable {
  // Unique identifier for this attachment.
  let id: String

  // Original filename including extension.
  let filename: String

  // MIME type of the file.
  let mimeType: AttachmentMimeType

  // File size in bytes (original, before base64 encoding).
  let sizeBytes: Int

  // File content encoded as base64 string.
  let base64Data: String

  // Estimated token cost for this attachment.
  // Nil if token estimation has not been performed.
  let estimatedTokens: Int?

  // Creates a file attachment with all properties.
  init(
    id: String,
    filename: String,
    mimeType: AttachmentMimeType,
    sizeBytes: Int,
    base64Data: String,
    estimatedTokens: Int?
  ) {
    self.id = id
    self.filename = filename
    self.mimeType = mimeType
    self.sizeBytes = sizeBytes
    self.base64Data = base64Data
    self.estimatedTokens = estimatedTokens
  }
}

/*
 ACCEPTANCE CRITERIA: FileAttachment Initialization

 SCENARIO: Create attachment with all properties
 GIVEN: Valid attachment properties
 WHEN: FileAttachment is initialized with id, filename, mimeType, sizeBytes, base64Data, estimatedTokens
 THEN: All properties are set correctly
  AND: The attachment is immutable

 SCENARIO: Create attachment without estimated tokens
 GIVEN: Valid attachment properties with estimatedTokens as nil
 WHEN: FileAttachment is initialized
 THEN: estimatedTokens is nil
  AND: All other properties are set correctly
*/

/*
 ACCEPTANCE CRITERIA: FileAttachment Codable

 SCENARIO: Encode attachment to JSON
 GIVEN: A valid FileAttachment
 WHEN: Encoded using JSONEncoder
 THEN: JSON contains all properties with correct keys
  AND: mimeType is encoded as its raw value string

 SCENARIO: Decode attachment from JSON
 GIVEN: Valid JSON with all FileAttachment fields
 WHEN: Decoded using JSONDecoder
 THEN: FileAttachment is created with all properties
  AND: mimeType is correctly decoded from raw value string

 SCENARIO: Decode attachment with null estimatedTokens
 GIVEN: JSON with estimatedTokens as null
 WHEN: Decoded using JSONDecoder
 THEN: FileAttachment is created with estimatedTokens as nil

 SCENARIO: Decode attachment with missing estimatedTokens
 GIVEN: JSON without estimatedTokens field
 WHEN: Decoded using JSONDecoder
 THEN: FileAttachment is created with estimatedTokens as nil
*/

/*
 ACCEPTANCE CRITERIA: FileAttachment Equatable

 SCENARIO: Equal attachments compare as equal
 GIVEN: Two FileAttachment instances with identical properties
 WHEN: Compared using ==
 THEN: Returns true

 SCENARIO: Attachments with different IDs compare as not equal
 GIVEN: Two FileAttachment instances with different id values
 WHEN: Compared using ==
 THEN: Returns false

 SCENARIO: Attachments with different base64Data compare as not equal
 GIVEN: Two FileAttachment instances with same ID but different base64Data
 WHEN: Compared using ==
 THEN: Returns false
*/

// MARK: - AttachmentError Enum

// Errors that can occur during attachment operations.
// Provides user-friendly error messages for UI display.
enum AttachmentError: Error, LocalizedError, Equatable {
  // The file type is not supported for attachment.
  case unsupportedFileType(extension: String)

  // The file exceeds the size limit for its type.
  case fileTooLarge(filename: String, sizeBytes: Int, limitBytes: Int)

  // The file is empty (zero bytes).
  case emptyFile(filename: String)

  // Reading the file from disk failed.
  case readFailed(filename: String, reason: String)

  // The attachment would exceed the available token budget.
  case tokenBudgetExceeded(estimatedTokens: Int, availableTokens: Int)

  // Uploading the file to the Files API failed.
  case uploadFailed(reason: String)

  // Processing the file (e.g., base64 encoding) failed.
  case processingFailed(reason: String)

  var errorDescription: String? {
    switch self {
    case .unsupportedFileType(let ext):
      return "The file type '\(ext)' is not supported. Supported types are: PNG, JPEG, WebP, HEIC, HEIF, GIF, PDF, and plain text."
    case .fileTooLarge(let filename, let sizeBytes, let limitBytes):
      let sizeMB = Double(sizeBytes) / (1024 * 1024)
      let limitMB = Double(limitBytes) / (1024 * 1024)
      return "'\(filename)' is too large (\(String(format: "%.1f", sizeMB)) MB). Maximum size is \(String(format: "%.0f", limitMB)) MB."
    case .emptyFile(let filename):
      return "'\(filename)' is empty and cannot be attached."
    case .readFailed(let filename, let reason):
      return "Failed to read '\(filename)': \(reason)"
    case .tokenBudgetExceeded(let estimated, let available):
      return "This attachment would use approximately \(estimated) tokens, but only \(available) tokens are available."
    case .uploadFailed(let reason):
      return "Failed to upload file: \(reason)"
    case .processingFailed(let reason):
      return "Failed to process file: \(reason)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: AttachmentError.errorDescription

 SCENARIO: Unsupported file type error provides helpful message
 GIVEN: AttachmentError.unsupportedFileType(extension: "docx")
 WHEN: errorDescription is accessed
 THEN: Returns a message indicating "docx" is not supported
  AND: Lists the supported file types

 SCENARIO: File too large error shows sizes in MB
 GIVEN: AttachmentError.fileTooLarge(filename: "large.pdf", sizeBytes: 60_000_000, limitBytes: 52_428_800)
 WHEN: errorDescription is accessed
 THEN: Returns a message showing the file is too large
  AND: Shows the actual size in MB (approximately 57.2 MB)
  AND: Shows the limit in MB (50 MB)

 SCENARIO: Empty file error shows filename
 GIVEN: AttachmentError.emptyFile(filename: "empty.txt")
 WHEN: errorDescription is accessed
 THEN: Returns a message indicating the file is empty
  AND: Includes the filename

 SCENARIO: Read failed error shows filename and reason
 GIVEN: AttachmentError.readFailed(filename: "missing.png", reason: "File not found")
 WHEN: errorDescription is accessed
 THEN: Returns a message with both filename and reason

 SCENARIO: Token budget exceeded error shows token counts
 GIVEN: AttachmentError.tokenBudgetExceeded(estimatedTokens: 50000, availableTokens: 30000)
 WHEN: errorDescription is accessed
 THEN: Returns a message showing estimated tokens (50000)
  AND: Shows available tokens (30000)

 SCENARIO: Upload failed error shows reason
 GIVEN: AttachmentError.uploadFailed(reason: "Network timeout")
 WHEN: errorDescription is accessed
 THEN: Returns a message including the reason

 SCENARIO: Processing failed error shows reason
 GIVEN: AttachmentError.processingFailed(reason: "Invalid image format")
 WHEN: errorDescription is accessed
 THEN: Returns a message including the reason
*/

/*
 ACCEPTANCE CRITERIA: AttachmentError Equatable

 SCENARIO: Same error cases with same values compare as equal
 GIVEN: Two AttachmentError instances of same case with same values
 WHEN: Compared using ==
 THEN: Returns true

 SCENARIO: Same error cases with different values compare as not equal
 GIVEN: AttachmentError.emptyFile(filename: "a.txt") and AttachmentError.emptyFile(filename: "b.txt")
 WHEN: Compared using ==
 THEN: Returns false

 SCENARIO: Different error cases compare as not equal
 GIVEN: AttachmentError.emptyFile(filename: "a.txt") and AttachmentError.unsupportedFileType(extension: "txt")
 WHEN: Compared using ==
 THEN: Returns false
*/

// MARK: - UploadedFileReference Model

// Represents a file that has been uploaded to the Gemini Files API.
// Contains the URI needed to reference the file in subsequent API calls.
// Files expire after a period determined by the API.
struct UploadedFileReference: Sendable, Codable, Equatable {
  // The URI returned by the Files API for referencing this file.
  // Format: files/{file_id}
  let fileUri: String

  // The MIME type of the uploaded file.
  let mimeType: String

  // The display name of the file.
  let name: String

  // When the file will expire, if provided by the API.
  // ISO 8601 format string.
  let expiresAt: String?

  // Creates an uploaded file reference with all properties.
  init(
    fileUri: String,
    mimeType: String,
    name: String,
    expiresAt: String?
  ) {
    self.fileUri = fileUri
    self.mimeType = mimeType
    self.name = name
    self.expiresAt = expiresAt
  }
}

/*
 ACCEPTANCE CRITERIA: UploadedFileReference Initialization

 SCENARIO: Create reference with all properties
 GIVEN: Valid file reference properties
 WHEN: UploadedFileReference is initialized
 THEN: All properties are set correctly

 SCENARIO: Create reference without expiration
 GIVEN: Valid properties with expiresAt as nil
 WHEN: UploadedFileReference is initialized
 THEN: expiresAt is nil
  AND: All other properties are set correctly
*/

/*
 ACCEPTANCE CRITERIA: UploadedFileReference Codable

 SCENARIO: Encode reference to JSON
 GIVEN: A valid UploadedFileReference
 WHEN: Encoded using JSONEncoder
 THEN: JSON contains all properties with correct keys

 SCENARIO: Decode reference from JSON
 GIVEN: Valid JSON with all UploadedFileReference fields
 WHEN: Decoded using JSONDecoder
 THEN: UploadedFileReference is created with all properties

 SCENARIO: Decode reference with null expiresAt
 GIVEN: JSON with expiresAt as null
 WHEN: Decoded using JSONDecoder
 THEN: UploadedFileReference is created with expiresAt as nil

 SCENARIO: Decode reference with missing expiresAt
 GIVEN: JSON without expiresAt field
 WHEN: Decoded using JSONDecoder
 THEN: UploadedFileReference is created with expiresAt as nil
*/

/*
 ACCEPTANCE CRITERIA: UploadedFileReference Equatable

 SCENARIO: Equal references compare as equal
 GIVEN: Two UploadedFileReference instances with identical properties
 WHEN: Compared using ==
 THEN: Returns true

 SCENARIO: References with different fileUri compare as not equal
 GIVEN: Two UploadedFileReference instances with different fileUri values
 WHEN: Compared using ==
 THEN: Returns false
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: FileAttachment with empty base64Data
 GIVEN: FileAttachment created with base64Data as empty string
 WHEN: The attachment is used
 THEN: The attachment is technically valid (sizeBytes could still be > 0 if original was empty)
  AND: Validation should occur at creation time via AttachmentError.emptyFile

 EDGE CASE: FileAttachment with mismatched sizeBytes
 GIVEN: FileAttachment where sizeBytes does not match decoded base64Data length
 WHEN: The attachment is used
 THEN: sizeBytes represents the original file size, not base64 length
  AND: Base64 length is approximately 4/3 * sizeBytes

 EDGE CASE: Very large base64Data string
 GIVEN: FileAttachment with 100MB file encoded as base64
 WHEN: Memory is allocated
 THEN: Approximately 133MB of string memory is used (4/3 ratio)
  AND: Should not cause memory issues on typical devices

 EDGE CASE: Unicode in filename
 GIVEN: Filename with unicode characters (e.g., "report_2024.pdf")
 WHEN: FileAttachment is created and encoded
 THEN: Filename is preserved correctly through JSON encoding/decoding

 EDGE CASE: Filename with special characters
 GIVEN: Filename with characters like spaces, quotes, slashes
 WHEN: FileAttachment is created
 THEN: Filename is stored as-is
  AND: Encoding/decoding handles special characters correctly

 EDGE CASE: MIME type raw value lookup
 GIVEN: A raw value string "image/jpeg"
 WHEN: AttachmentMimeType(rawValue: "image/jpeg") is called
 THEN: Returns .jpeg

 EDGE CASE: Invalid MIME type raw value
 GIVEN: A raw value string that is not a valid MIME type
 WHEN: AttachmentMimeType(rawValue: "image/bmp") is called
 THEN: Returns nil

 EDGE CASE: CaseIterable enumeration
 GIVEN: AttachmentMimeType.allCases
 WHEN: Count is accessed
 THEN: Returns 8 (6 image types + 2 document types)

 EDGE CASE: Zero sizeBytes
 GIVEN: FileAttachment with sizeBytes = 0
 WHEN: Compared or used
 THEN: Represents an empty file
  AND: Should have been rejected with AttachmentError.emptyFile during creation

 EDGE CASE: Negative sizeBytes
 GIVEN: FileAttachment created with negative sizeBytes
 WHEN: The model is used
 THEN: Swift Int allows negative values
  AND: Validation should prevent this at creation time
  AND: Implementation should guard against this

 EDGE CASE: estimatedTokens = 0
 GIVEN: FileAttachment with estimatedTokens = 0
 WHEN: Token budget is calculated
 THEN: Zero tokens means the file contributes no token cost
  AND: This may be valid for tiny files

 EDGE CASE: estimatedTokens very large
 GIVEN: FileAttachment with estimatedTokens = 1_000_000
 WHEN: Token budget is checked
 THEN: Should trigger tokenBudgetExceeded error if over budget
  AND: No integer overflow concerns (Int is 64-bit on modern devices)
*/

// MARK: - Token Estimation Constants

// Constants for estimating token costs of file attachments.
// Based on Gemini API documentation for multimodal inputs.
enum AttachmentTokenEstimation {
  // Approximate tokens per image (fixed cost per Gemini docs).
  // Images are resized and processed, resulting in a fixed token cost.
  static let tokensPerImage = 258

  // Approximate tokens per PDF page.
  // Based on typical page containing ~500-1000 words.
  static let tokensPerPDFPage = 750

  // Approximate characters per token for plain text.
  // Matches TokenBudgetConstants.charsPerToken.
  static let charsPerToken: Double = 4.0
}

/*
 ACCEPTANCE CRITERIA: AttachmentTokenEstimation Constants

 SCENARIO: Image token estimation constant
 GIVEN: AttachmentTokenEstimation
 WHEN: tokensPerImage is accessed
 THEN: Returns 258

 SCENARIO: PDF page token estimation constant
 GIVEN: AttachmentTokenEstimation
 WHEN: tokensPerPDFPage is accessed
 THEN: Returns 750

 SCENARIO: Characters per token constant
 GIVEN: AttachmentTokenEstimation
 WHEN: charsPerToken is accessed
 THEN: Returns 4.0
*/

// MARK: - AttachmentValidation Protocol

// Protocol for validating file attachments before processing.
// Implementations check size, type, and other constraints.
protocol AttachmentValidationProtocol: Sendable {
  // Validates a file before reading its contents.
  // url: The file URL to validate.
  // Returns: The detected MIME type if valid.
  // Throws: AttachmentError if validation fails.
  func validateFile(at url: URL) throws -> AttachmentMimeType

  // Validates file data after reading.
  // data: The file data to validate.
  // filename: The original filename.
  // mimeType: The detected or declared MIME type.
  // Throws: AttachmentError if validation fails.
  func validateData(
    _ data: Data,
    filename: String,
    mimeType: AttachmentMimeType
  ) throws

  // Checks if adding an attachment would exceed the token budget.
  // attachment: The attachment to check.
  // currentUsage: Current token usage in the conversation.
  // budget: Maximum available tokens.
  // Throws: AttachmentError.tokenBudgetExceeded if over budget.
  func validateTokenBudget(
    attachment: FileAttachment,
    currentUsage: Int,
    budget: Int
  ) throws
}

/*
 ACCEPTANCE CRITERIA: AttachmentValidationProtocol.validateFile()

 SCENARIO: Validate supported file type
 GIVEN: A URL pointing to a PNG file
 WHEN: validateFile(at:) is called
 THEN: Returns .png
  AND: No error is thrown

 SCENARIO: Validate unsupported file type
 GIVEN: A URL pointing to a .docx file
 WHEN: validateFile(at:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "docx")

 SCENARIO: Validate file with no extension
 GIVEN: A URL pointing to a file without extension
 WHEN: validateFile(at:) is called
 THEN: Throws AttachmentError.unsupportedFileType(extension: "")
*/

/*
 ACCEPTANCE CRITERIA: AttachmentValidationProtocol.validateData()

 SCENARIO: Validate data within size limits
 GIVEN: 10MB of PNG data
 WHEN: validateData() is called with .png MIME type
 THEN: No error is thrown (under 20MB limit)

 SCENARIO: Validate oversized image
 GIVEN: 25MB of PNG data
 WHEN: validateData() is called with .png MIME type
 THEN: Throws AttachmentError.fileTooLarge with correct sizes

 SCENARIO: Validate oversized PDF
 GIVEN: 60MB of PDF data
 WHEN: validateData() is called with .pdf MIME type
 THEN: Throws AttachmentError.fileTooLarge with correct sizes

 SCENARIO: Validate empty data
 GIVEN: Empty Data (0 bytes)
 WHEN: validateData() is called
 THEN: Throws AttachmentError.emptyFile
*/

/*
 ACCEPTANCE CRITERIA: AttachmentValidationProtocol.validateTokenBudget()

 SCENARIO: Attachment within token budget
 GIVEN: Attachment with estimatedTokens = 1000
  AND: currentUsage = 5000, budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: No error is thrown

 SCENARIO: Attachment exceeds token budget
 GIVEN: Attachment with estimatedTokens = 6000
  AND: currentUsage = 5000, budget = 10000
 WHEN: validateTokenBudget() is called
 THEN: Throws AttachmentError.tokenBudgetExceeded(estimatedTokens: 6000, availableTokens: 5000)

 SCENARIO: Attachment with nil estimatedTokens
 GIVEN: Attachment with estimatedTokens = nil
 WHEN: validateTokenBudget() is called
 THEN: Implementation should estimate tokens or skip validation
  AND: Behavior is documented
*/

// MARK: - AttachmentProcessor Protocol

// Protocol for reading and encoding file attachments.
// Handles file I/O and base64 encoding.
protocol AttachmentProcessorProtocol: Sendable {
  // Reads a file and creates a FileAttachment.
  // url: The file URL to read.
  // Returns: The created FileAttachment.
  // Throws: AttachmentError if reading or processing fails.
  func createAttachment(from url: URL) async throws -> FileAttachment

  // Estimates the token cost for an attachment.
  // attachment: The attachment to estimate.
  // Returns: Updated attachment with estimatedTokens populated.
  func estimateTokens(for attachment: FileAttachment) -> FileAttachment
}

/*
 ACCEPTANCE CRITERIA: AttachmentProcessorProtocol.createAttachment()

 SCENARIO: Create attachment from valid image file
 GIVEN: A valid 5MB PNG file at a URL
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with:
  - Unique id
  - Correct filename from URL
  - mimeType = .png
  - sizeBytes = 5MB
  - base64Data containing valid base64 encoding
  - estimatedTokens may be nil or populated

 SCENARIO: Create attachment from valid PDF file
 GIVEN: A valid 2MB PDF file at a URL
 WHEN: createAttachment(from:) is called
 THEN: Returns FileAttachment with mimeType = .pdf

 SCENARIO: Attempt to create attachment from missing file
 GIVEN: A URL pointing to a non-existent file
 WHEN: createAttachment(from:) is called
 THEN: Throws AttachmentError.readFailed with appropriate reason

 SCENARIO: Attempt to create attachment from unreadable file
 GIVEN: A URL pointing to a file without read permission
 WHEN: createAttachment(from:) is called
 THEN: Throws AttachmentError.readFailed with permission error reason
*/

/*
 ACCEPTANCE CRITERIA: AttachmentProcessorProtocol.estimateTokens()

 SCENARIO: Estimate tokens for image attachment
 GIVEN: FileAttachment with mimeType = .png
 WHEN: estimateTokens(for:) is called
 THEN: Returns attachment with estimatedTokens = 258 (tokensPerImage)

 SCENARIO: Estimate tokens for PDF attachment
 GIVEN: FileAttachment with mimeType = .pdf
 WHEN: estimateTokens(for:) is called
 THEN: Returns attachment with estimatedTokens based on page count estimate
  AND: Estimation uses sizeBytes to approximate page count

 SCENARIO: Estimate tokens for plain text attachment
 GIVEN: FileAttachment with mimeType = .plainText and sizeBytes = 4000
 WHEN: estimateTokens(for:) is called
 THEN: Returns attachment with estimatedTokens = 1000 (4000 / 4.0)
*/

// MARK: - Testing Support

/*
 TESTING: AttachmentMimeType Unit Tests

 1. Test all raw values match expected MIME type strings
 2. Test isImage returns correct value for all cases
 3. Test isDocument returns correct value for all cases
 4. Test init(fromExtension:) for all supported extensions
 5. Test init(fromExtension:) returns nil for unsupported extensions
 6. Test case insensitivity of extension matching
 7. Test allCases contains expected count
 8. Test Codable encoding/decoding for all cases

 TESTING: AttachmentSizeLimits Unit Tests

 1. Test all constant values are correct
 2. Test sizeLimit(for:) returns correct limit for each MIME type

 TESTING: FileAttachment Unit Tests

 1. Test initialization with all properties
 2. Test initialization with nil estimatedTokens
 3. Test Codable round-trip (encode then decode)
 4. Test Equatable for equal instances
 5. Test Equatable for different instances
 6. Test Identifiable id property

 TESTING: AttachmentError Unit Tests

 1. Test errorDescription for each error case
 2. Test Equatable for same case and values
 3. Test Equatable for different cases
 4. Test Equatable for same case but different values

 TESTING: UploadedFileReference Unit Tests

 1. Test initialization with all properties
 2. Test initialization with nil expiresAt
 3. Test Codable round-trip
 4. Test Equatable
*/

// MARK: - Future Considerations

/*
 FUTURE: Image Dimension Validation
 Phase 2 may add validation for maxImageDimension (3072x3072).
 This requires loading the image to read dimensions.
 Consider using CGImageSource for efficient dimension reading.

 FUTURE: PDF Page Count Validation
 Phase 2 may add validation for maxPDFPages (1000).
 This requires parsing the PDF to count pages.
 Consider using PDFKit for page counting.

 FUTURE: Files API Upload
 Phase 2 will implement UploadedFileReference creation.
 The processor will upload files to Gemini Files API.
 UploadedFileReference will be used for large files.

 FUTURE: Thumbnail Generation
 UI phase may require thumbnail generation for attachments.
 Consider caching thumbnails to avoid regeneration.
*/
