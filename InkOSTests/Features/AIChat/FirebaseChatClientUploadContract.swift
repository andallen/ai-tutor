// FirebaseChatClientUploadContract.swift
// Test contract for FirebaseChatClient.uploadFile() functionality.
// Defines all test scenarios, acceptance criteria, and edge cases for the file upload feature.
// This contract enables test-driven verification of the existing implementation.

import Foundation

// MARK: - API Contract Reference

/*
 FUNCTION UNDER TEST:
 func uploadFile(_ attachment: FileAttachment) async throws -> UploadedFileReference

 LOCATION:
 /InkOS/Features/AIChat/Services/FirebaseChatClient.swift

 DESCRIPTION:
 Uploads a file attachment to the Gemini Files API via a Firebase Cloud Function.
 The Cloud Function handles base64 decoding, validation, upload to Gemini,
 and polling until the file is ready for use in multimodal messages.

 DEPENDENCIES:
 - FileAttachment (from AttachmentContract.swift)
 - UploadedFileReference (from AttachmentContract.swift)
 - ChatError (from ChatContract.swift)
 - ChatConfiguration (from ChatContract.swift)
 - ChatConstants.uploadTimeout (300 seconds)

 CLOUD FUNCTION ENDPOINT:
 POST {configuration.uploadFileURL}

 REQUEST FORMAT:
 {
   "base64Data": "<base64 encoded file data>",
   "mimeType": "<MIME type string>",
   "displayName": "<filename>"
 }

 SUCCESS RESPONSE (200):
 {
   "fileUri": "<Gemini file URI>",
   "mimeType": "<MIME type>",
   "name": "<Gemini file name>",
   "expiresAt": "<ISO 8601 timestamp or null>"
 }

 ERROR RESPONSE FORMAT:
 {
   "error": "<error message>",
   "errorCode": "<error code>",
   ... additional fields vary by error
 }
*/

// MARK: - Test Helper Types

/*
 TEST FIXTURE: MockFileAttachment
 Creates FileAttachment instances for testing with controlled properties.

 USAGE IN TESTS:
 let attachment = FileAttachment(
   id: "test-id",
   filename: "test.png",
   mimeType: .png,
   sizeBytes: 1024,
   base64Data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ...",
   estimatedTokens: 258
 )
*/

/*
 TEST FIXTURE: MockUploadResponse
 Creates JSON response data matching the Cloud Function's success format.

 USAGE IN TESTS:
 let responseJSON: [String: Any] = [
   "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/abc123",
   "mimeType": "image/png",
   "name": "files/abc123",
   "expiresAt": "2024-12-15T12:00:00Z"
 ]
 let responseData = try JSONSerialization.data(withJSONObject: responseJSON)
*/

/*
 TEST FIXTURE: MockErrorResponse
 Creates JSON error response data matching the Cloud Function's error format.

 USAGE IN TESTS:
 let errorJSON: [String: Any] = [
   "error": "File type not supported",
   "errorCode": "UNSUPPORTED_FILE_TYPE",
   "mimeType": "video/mp4",
   "supportedTypes": ["image/png", "image/jpeg", ...]
 ]
 let errorData = try JSONSerialization.data(withJSONObject: errorJSON)
*/

// MARK: - Acceptance Criteria: Successful Upload

/*
 SCENARIO: Upload PNG image successfully
 GIVEN: A valid FileAttachment with mimeType = .png
  AND: Valid base64Data representing a PNG image
  AND: Cloud Function returns HTTP 200 with valid response
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with:
  - fileUri matching response "fileUri"
  - mimeType matching response "mimeType"
  - name matching response "name"
  - expiresAt matching response "expiresAt" (if present)
  AND: No error is thrown

 SCENARIO: Upload JPEG image successfully
 GIVEN: A valid FileAttachment with mimeType = .jpeg
  AND: Valid base64Data representing a JPEG image
  AND: Cloud Function returns HTTP 200 with valid response
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with correct properties
  AND: No error is thrown

 SCENARIO: Upload PDF document successfully
 GIVEN: A valid FileAttachment with mimeType = .pdf
  AND: Valid base64Data representing a PDF document
  AND: Cloud Function returns HTTP 200 with valid response
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with correct properties
  AND: mimeType is "application/pdf"
  AND: No error is thrown

 SCENARIO: Upload plain text file successfully
 GIVEN: A valid FileAttachment with mimeType = .plainText
  AND: Valid base64Data representing UTF-8 text
  AND: Cloud Function returns HTTP 200 with valid response
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with correct properties
  AND: mimeType is "text/plain"
  AND: No error is thrown

 SCENARIO: Upload WebP image successfully
 GIVEN: A valid FileAttachment with mimeType = .webp
  AND: Cloud Function returns HTTP 200
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with mimeType "image/webp"

 SCENARIO: Upload HEIC image successfully
 GIVEN: A valid FileAttachment with mimeType = .heic
  AND: Cloud Function returns HTTP 200
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with mimeType "image/heic"

 SCENARIO: Upload HEIF image successfully
 GIVEN: A valid FileAttachment with mimeType = .heif
  AND: Cloud Function returns HTTP 200
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with mimeType "image/heif"

 SCENARIO: Upload GIF image successfully
 GIVEN: A valid FileAttachment with mimeType = .gif
  AND: Cloud Function returns HTTP 200
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with mimeType "image/gif"

 SCENARIO: Successful upload with null expiresAt
 GIVEN: A valid FileAttachment
  AND: Cloud Function returns HTTP 200 with expiresAt = null
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with expiresAt = nil
  AND: All other properties are populated correctly

 SCENARIO: Successful upload with missing expiresAt field
 GIVEN: A valid FileAttachment
  AND: Cloud Function returns HTTP 200 without expiresAt field in JSON
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with expiresAt = nil
  AND: All other properties are populated correctly
*/

// MARK: - Acceptance Criteria: Request Format Validation

/*
 SCENARIO: Request body contains correct fields
 GIVEN: A FileAttachment with:
  - filename = "document.pdf"
  - mimeType = .pdf (rawValue "application/pdf")
  - base64Data = "JVBERi0xLjQK..."
 WHEN: uploadFile(attachment) is called
 THEN: HTTP request body contains JSON with:
  - "base64Data" = "JVBERi0xLjQK..."
  - "mimeType" = "application/pdf"
  - "displayName" = "document.pdf"
  AND: Content-Type header is "application/json"
  AND: HTTP method is POST
  AND: URL matches configuration.uploadFileURL

 SCENARIO: Request uses correct timeout
 GIVEN: A valid FileAttachment
 WHEN: uploadFile(attachment) is called
 THEN: URLRequest.timeoutInterval equals ChatConstants.uploadTimeout (300 seconds)

 SCENARIO: Request uses mimeType rawValue
 GIVEN: A FileAttachment with mimeType = .png
 WHEN: uploadFile(attachment) is called
 THEN: Request body "mimeType" field is "image/png"
  AND: Uses AttachmentMimeType.rawValue for serialization

 SCENARIO: Request preserves filename with special characters
 GIVEN: A FileAttachment with filename = "Report (2024) - Final.pdf"
 WHEN: uploadFile(attachment) is called
 THEN: Request body "displayName" equals "Report (2024) - Final.pdf"
  AND: Special characters are preserved in JSON encoding

 SCENARIO: Request preserves filename with unicode
 GIVEN: A FileAttachment with filename = "Report.pdf"
 WHEN: uploadFile(attachment) is called
 THEN: Request body "displayName" equals "Report.pdf"
  AND: Unicode characters are preserved
*/

// MARK: - Acceptance Criteria: Error Code UNSUPPORTED_FILE_TYPE

/*
 SCENARIO: UNSUPPORTED_FILE_TYPE error returns uploadFailed
 GIVEN: Cloud Function returns HTTP 400 with:
  - errorCode = "UNSUPPORTED_FILE_TYPE"
  - error = "Unsupported file type"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "File type not supported")

 SCENARIO: UNSUPPORTED_FILE_TYPE preserves error mapping
 GIVEN: Cloud Function returns HTTP 400 with errorCode = "UNSUPPORTED_FILE_TYPE"
 WHEN: The error is caught
 THEN: The error is ChatError.uploadFailed
  AND: Error reason is "File type not supported"
  AND: Error does NOT include original server message
*/

// MARK: - Acceptance Criteria: Error Code FILE_TOO_LARGE

/*
 SCENARIO: FILE_TOO_LARGE error returns uploadFailed with filename
 GIVEN: A FileAttachment with filename = "huge_image.png"
  AND: Cloud Function returns HTTP 400 with:
  - errorCode = "FILE_TOO_LARGE"
  - error = "File too large"
  - sizeBytes = 25000000
  - limitBytes = 20971520
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "File 'huge_image.png' is too large")
  AND: Error reason includes the filename

 SCENARIO: FILE_TOO_LARGE includes filename in error reason
 GIVEN: A FileAttachment with filename = "large.pdf"
  AND: Cloud Function returns HTTP 400 with errorCode = "FILE_TOO_LARGE"
 WHEN: The error is caught
 THEN: ChatError.uploadFailed reason contains "large.pdf"
*/

// MARK: - Acceptance Criteria: Error Code EMPTY_FILE

/*
 SCENARIO: EMPTY_FILE error returns uploadFailed with filename
 GIVEN: A FileAttachment with filename = "empty.txt"
  AND: Cloud Function returns HTTP 400 with:
  - errorCode = "EMPTY_FILE"
  - error = "Empty file"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "File 'empty.txt' is empty")
  AND: Error reason includes the filename

 SCENARIO: EMPTY_FILE includes filename in error reason
 GIVEN: A FileAttachment with filename = "blank.png"
  AND: Cloud Function returns HTTP 400 with errorCode = "EMPTY_FILE"
 WHEN: The error is caught
 THEN: ChatError.uploadFailed reason contains "blank.png"
*/

// MARK: - Acceptance Criteria: Error Code INVALID_BASE64

/*
 SCENARIO: INVALID_BASE64 error returns uploadFailed
 GIVEN: Cloud Function returns HTTP 400 with:
  - errorCode = "INVALID_BASE64"
  - error = "Invalid base64 data"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid file data")

 SCENARIO: INVALID_BASE64 uses fixed error message
 GIVEN: Cloud Function returns HTTP 400 with errorCode = "INVALID_BASE64"
 WHEN: The error is caught
 THEN: ChatError.uploadFailed reason is exactly "Invalid file data"
  AND: Does not include filename or original error message
*/

// MARK: - Acceptance Criteria: Error Code PROCESSING_FAILED

/*
 SCENARIO: PROCESSING_FAILED error returns processingFailed with filename
 GIVEN: A FileAttachment with filename = "corrupted.pdf"
  AND: Cloud Function returns HTTP 500 with:
  - errorCode = "PROCESSING_FAILED"
  - error = "File processing failed"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.processingFailed(filename: "corrupted.pdf")

 SCENARIO: PROCESSING_FAILED error type is distinct from uploadFailed
 GIVEN: Cloud Function returns HTTP 500 with errorCode = "PROCESSING_FAILED"
 WHEN: The error is caught
 THEN: Error is ChatError.processingFailed, NOT ChatError.uploadFailed
  AND: Error includes filename parameter
  AND: errorDescription mentions file may be corrupted
*/

// MARK: - Acceptance Criteria: Error Code PROCESSING_TIMEOUT

/*
 SCENARIO: PROCESSING_TIMEOUT error returns processingTimeout with filename
 GIVEN: A FileAttachment with filename = "slow.pdf"
  AND: Cloud Function returns HTTP 504 with:
  - errorCode = "PROCESSING_TIMEOUT"
  - error = "File processing timed out"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.processingTimeout(filename: "slow.pdf")

 SCENARIO: PROCESSING_TIMEOUT error type is distinct
 GIVEN: Cloud Function returns HTTP 504 with errorCode = "PROCESSING_TIMEOUT"
 WHEN: The error is caught
 THEN: Error is ChatError.processingTimeout, NOT ChatError.uploadFailed
  AND: Error includes filename parameter
  AND: errorDescription suggests trying again
*/

// MARK: - Acceptance Criteria: Error Code CONFIG_ERROR

/*
 SCENARIO: CONFIG_ERROR returns uploadFailed with server message
 GIVEN: Cloud Function returns HTTP 500 with:
  - errorCode = "CONFIG_ERROR"
  - error = "Server configuration error"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Server configuration error")
  AND: Uses the server's error message

 SCENARIO: CONFIG_ERROR passes through error message
 GIVEN: Cloud Function returns HTTP 500 with:
  - errorCode = "CONFIG_ERROR"
  - error = "GOOGLE_GENAI_API_KEY not configured"
 WHEN: The error is caught
 THEN: ChatError.uploadFailed reason is "GOOGLE_GENAI_API_KEY not configured"
*/

// MARK: - Acceptance Criteria: Error Code UPLOAD_FAILED

/*
 SCENARIO: UPLOAD_FAILED returns uploadFailed with server message
 GIVEN: Cloud Function returns HTTP 500 with:
  - errorCode = "UPLOAD_FAILED"
  - error = "File upload failed"
  - details = "Connection reset by peer"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "File upload failed")
  AND: Uses the server's error message

 SCENARIO: UPLOAD_FAILED passes through error message
 GIVEN: Cloud Function returns HTTP 500 with:
  - errorCode = "UPLOAD_FAILED"
  - error = "Gemini API returned 503"
 WHEN: The error is caught
 THEN: ChatError.uploadFailed reason is "Gemini API returned 503"
*/

// MARK: - Acceptance Criteria: Server Errors (5xx)

/*
 SCENARIO: HTTP 500 with unknown errorCode returns requestFailed
 GIVEN: Cloud Function returns HTTP 500 with:
  - errorCode = "UNKNOWN_ERROR"
  - error = "Internal server error"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 500, message: "Server error during upload")

 SCENARIO: HTTP 500 without errorCode returns requestFailed
 GIVEN: Cloud Function returns HTTP 500 with:
  - error = "Internal server error"
  - (no errorCode field)
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 500, message: "Server error during upload")

 SCENARIO: HTTP 502 returns requestFailed
 GIVEN: Cloud Function returns HTTP 502 Bad Gateway
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 502, message: "Server error during upload")

 SCENARIO: HTTP 503 returns requestFailed
 GIVEN: Cloud Function returns HTTP 503 Service Unavailable
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 503, message: "Server error during upload")

 SCENARIO: HTTP 504 without PROCESSING_TIMEOUT returns requestFailed
 GIVEN: Cloud Function returns HTTP 504 without errorCode
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 504, message: "Server error during upload")
*/

// MARK: - Acceptance Criteria: Network Errors

/*
 SCENARIO: Network timeout throws networkError
 GIVEN: URLSession.data(for:) times out
  AND: Throws URLError.timedOut
 WHEN: uploadFile(attachment) is called
 THEN: Throws URLError (or underlying network error)
  AND: Error propagates to caller

 SCENARIO: Network unreachable throws error
 GIVEN: URLSession.data(for:) fails with URLError.notConnectedToInternet
 WHEN: uploadFile(attachment) is called
 THEN: Throws URLError
  AND: Error propagates to caller

 SCENARIO: Connection reset throws error
 GIVEN: URLSession.data(for:) fails with URLError.networkConnectionLost
 WHEN: uploadFile(attachment) is called
 THEN: Throws URLError
  AND: Error propagates to caller

 SCENARIO: Invalid URL throws error
 GIVEN: ChatConfiguration is misconfigured with invalid URL
 WHEN: uploadFile(attachment) is called
 THEN: Throws error during URL construction
*/

// MARK: - Acceptance Criteria: Invalid Response Format

/*
 SCENARIO: Missing fileUri in response throws uploadFailed
 GIVEN: Cloud Function returns HTTP 200 with:
  - mimeType = "image/png"
  - name = "files/abc123"
  - (missing fileUri)
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid response format")

 SCENARIO: Missing mimeType in response throws uploadFailed
 GIVEN: Cloud Function returns HTTP 200 with:
  - fileUri = "https://..."
  - name = "files/abc123"
  - (missing mimeType)
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid response format")

 SCENARIO: Missing name in response throws uploadFailed
 GIVEN: Cloud Function returns HTTP 200 with:
  - fileUri = "https://..."
  - mimeType = "image/png"
  - (missing name)
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid response format")

 SCENARIO: Non-JSON response throws uploadFailed
 GIVEN: Cloud Function returns HTTP 200 with plain text body
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid response format")

 SCENARIO: Empty response body throws uploadFailed
 GIVEN: Cloud Function returns HTTP 200 with empty body
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid response format")

 SCENARIO: Malformed JSON throws uploadFailed
 GIVEN: Cloud Function returns HTTP 200 with "{invalid json"
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid response format")

 SCENARIO: Response is not HTTPURLResponse throws networkError
 GIVEN: URLSession returns a non-HTTP response type
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.networkError(reason: "Invalid response type")
*/

// MARK: - Acceptance Criteria: HTTP Status Codes

/*
 SCENARIO: HTTP 400 with error body parses errorCode
 GIVEN: Cloud Function returns HTTP 400 with valid error JSON
 WHEN: uploadFile(attachment) is called
 THEN: Error is mapped based on errorCode field

 SCENARIO: HTTP 400 without error body returns uploadFailed
 GIVEN: Cloud Function returns HTTP 400 with empty body
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed (with generic message)

 SCENARIO: HTTP 401 returns requestFailed
 GIVEN: Cloud Function returns HTTP 401 Unauthorized
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 401, ...)

 SCENARIO: HTTP 403 returns requestFailed
 GIVEN: Cloud Function returns HTTP 403 Forbidden
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 403, ...)

 SCENARIO: HTTP 404 returns uploadFailed
 GIVEN: Cloud Function returns HTTP 404 Not Found
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed (endpoint not found is a client config issue)

 SCENARIO: HTTP 405 returns uploadFailed
 GIVEN: Cloud Function returns HTTP 405 Method Not Allowed
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed

 SCENARIO: HTTP 429 returns requestFailed
 GIVEN: Cloud Function returns HTTP 429 Too Many Requests
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.requestFailed(statusCode: 429, ...)
*/

// MARK: - Edge Cases: Request Encoding

/*
 EDGE CASE: Request JSON serialization fails
 GIVEN: FileAttachment with properties that cannot be serialized
  (Note: This should not happen with current types, but guard exists)
 WHEN: JSONSerialization.data fails
 THEN: Throws ChatError.uploadFailed(reason: "Failed to encode request")

 EDGE CASE: Very long base64Data string
 GIVEN: FileAttachment with 100MB file (133+ million character base64 string)
 WHEN: uploadFile(attachment) is called
 THEN: Request body includes full base64Data without truncation
  AND: Memory usage is proportional to data size

 EDGE CASE: Empty base64Data string
 GIVEN: FileAttachment with base64Data = ""
  AND: sizeBytes = 0
 WHEN: uploadFile(attachment) is called
 THEN: Cloud Function receives the empty string
  AND: Server returns EMPTY_FILE error

 EDGE CASE: Base64Data with newlines
 GIVEN: FileAttachment with base64Data containing newlines (line-wrapped encoding)
 WHEN: uploadFile(attachment) is called
 THEN: base64Data is sent as-is in JSON
  AND: Server handles newline-formatted base64

 EDGE CASE: Filename with path separators
 GIVEN: FileAttachment with filename = "../../../etc/passwd"
 WHEN: uploadFile(attachment) is called
 THEN: displayName in request is "../../../etc/passwd"
  AND: Filename is sent as-is (server-side validation handles security)

 EDGE CASE: Very long filename
 GIVEN: FileAttachment with 1000-character filename
 WHEN: uploadFile(attachment) is called
 THEN: Full filename is sent in request
  AND: Server may return an error for overly long names
*/

// MARK: - Edge Cases: Response Parsing

/*
 EDGE CASE: Response fileUri is empty string
 GIVEN: Cloud Function returns HTTP 200 with fileUri = ""
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with fileUri = ""
  AND: Caller is responsible for validating fileUri

 EDGE CASE: Response mimeType differs from request
 GIVEN: FileAttachment with mimeType = .heic
  AND: Cloud Function returns mimeType = "image/jpeg" (converted)
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with mimeType = "image/jpeg"
  AND: Server's mimeType is used, not client's

 EDGE CASE: Response expiresAt is empty string
 GIVEN: Cloud Function returns HTTP 200 with expiresAt = ""
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with expiresAt = ""
  AND: Caller handles empty string vs nil

 EDGE CASE: Response contains extra fields
 GIVEN: Cloud Function returns HTTP 200 with extra fields:
  - fileUri, mimeType, name, expiresAt (required)
  - sizeBytes, createdAt (extra)
 WHEN: uploadFile(attachment) is called
 THEN: Returns UploadedFileReference with standard fields
  AND: Extra fields are ignored

 EDGE CASE: Response field types are wrong
 GIVEN: Cloud Function returns HTTP 200 with:
  - fileUri = 12345 (number instead of string)
 WHEN: uploadFile(attachment) is called
 THEN: Throws ChatError.uploadFailed(reason: "Invalid response format")
*/

// MARK: - Edge Cases: Error Response Parsing

/*
 EDGE CASE: Error response missing error message
 GIVEN: Cloud Function returns HTTP 400 with:
  - errorCode = "FILE_TOO_LARGE"
  - (no error field)
 WHEN: uploadFile(attachment) is called
 THEN: Maps based on errorCode
  AND: Uses default message for that error type

 EDGE CASE: Error response has nested error object
 GIVEN: Cloud Function returns HTTP 400 with:
  - error = { "message": "File too large", "code": 400 }
 WHEN: uploadFile(attachment) is called
 THEN: Parses nested error.message
  AND: Uses "File too large" as error message

 EDGE CASE: Error response has details field instead of error
 GIVEN: Cloud Function returns HTTP 400 with:
  - details = "File type not supported"
  - errorCode = "UNSUPPORTED_FILE_TYPE"
 WHEN: uploadFile(attachment) is called
 THEN: Falls back to details field
  AND: Maps based on errorCode

 EDGE CASE: Error response is plain text
 GIVEN: Cloud Function returns HTTP 500 with plain text "Internal Server Error"
 WHEN: uploadFile(attachment) is called
 THEN: Uses raw text as error message
  AND: No JSON parsing error

 EDGE CASE: Error response is empty
 GIVEN: Cloud Function returns HTTP 500 with empty body
 WHEN: uploadFile(attachment) is called
 THEN: Uses "Unknown error" as message
  AND: Maps to uploadFailed or requestFailed based on status code

 EDGE CASE: Unknown errorCode
 GIVEN: Cloud Function returns HTTP 400 with:
  - errorCode = "FUTURE_ERROR_CODE"
  - error = "Some future error"
 WHEN: uploadFile(attachment) is called
 THEN: Uses default mapping for status code
  AND: Does not crash on unknown error codes
*/

// MARK: - Test Organization

/*
 TESTING: FirebaseChatClient.uploadFile Unit Tests

 GROUP: Successful Upload Tests
 1. Test successful PNG upload returns correct UploadedFileReference
 2. Test successful JPEG upload returns correct UploadedFileReference
 3. Test successful PDF upload returns correct UploadedFileReference
 4. Test successful plain text upload returns correct UploadedFileReference
 5. Test successful upload with all image types (WebP, HEIC, HEIF, GIF)
 6. Test successful upload with null expiresAt
 7. Test successful upload without expiresAt field

 GROUP: Request Format Tests
 8. Test request body contains correct JSON fields
 9. Test request uses POST method
 10. Test request has correct Content-Type header
 11. Test request uses uploadTimeout
 12. Test request URL matches configuration.uploadFileURL
 13. Test mimeType uses AttachmentMimeType.rawValue
 14. Test filename with special characters is preserved
 15. Test filename with unicode is preserved

 GROUP: Error Code Mapping Tests
 16. Test UNSUPPORTED_FILE_TYPE maps to uploadFailed
 17. Test FILE_TOO_LARGE maps to uploadFailed with filename
 18. Test EMPTY_FILE maps to uploadFailed with filename
 19. Test INVALID_BASE64 maps to uploadFailed
 20. Test PROCESSING_FAILED maps to processingFailed
 21. Test PROCESSING_TIMEOUT maps to processingTimeout
 22. Test CONFIG_ERROR maps to uploadFailed with message
 23. Test UPLOAD_FAILED maps to uploadFailed with message

 GROUP: Server Error Tests (5xx)
 24. Test HTTP 500 returns requestFailed
 25. Test HTTP 502 returns requestFailed
 26. Test HTTP 503 returns requestFailed
 27. Test HTTP 504 without errorCode returns requestFailed
 28. Test HTTP 5xx with unknown errorCode returns requestFailed

 GROUP: Client Error Tests (4xx)
 29. Test HTTP 400 parses errorCode
 30. Test HTTP 401 returns requestFailed
 31. Test HTTP 403 returns requestFailed
 32. Test HTTP 404 returns uploadFailed
 33. Test HTTP 429 returns requestFailed

 GROUP: Invalid Response Tests
 34. Test missing fileUri throws uploadFailed
 35. Test missing mimeType throws uploadFailed
 36. Test missing name throws uploadFailed
 37. Test non-JSON response throws uploadFailed
 38. Test empty response throws uploadFailed
 39. Test malformed JSON throws uploadFailed
 40. Test non-HTTP response throws networkError

 GROUP: Network Error Tests
 41. Test network timeout propagates error
 42. Test no internet connection propagates error
 43. Test connection lost propagates error

 GROUP: Edge Case Tests
 44. Test empty base64Data is sent correctly
 45. Test very long base64Data is not truncated
 46. Test response mimeType differs from request
 47. Test extra response fields are ignored
 48. Test nested error object parsing
 49. Test error response with only details field
 50. Test empty error response body
*/

// MARK: - Implementation Reference

/*
 mapUploadError FUNCTION REFERENCE (from FirebaseChatClient.swift):

 private func mapUploadError(
   statusCode: Int,
   errorCode: String?,
   message: String,
   filename: String
 ) -> ChatError {
   switch errorCode {
   case "UNSUPPORTED_FILE_TYPE":
     return .uploadFailed(reason: "File type not supported")
   case "FILE_TOO_LARGE":
     return .uploadFailed(reason: "File '\(filename)' is too large")
   case "EMPTY_FILE":
     return .uploadFailed(reason: "File '\(filename)' is empty")
   case "INVALID_BASE64":
     return .uploadFailed(reason: "Invalid file data")
   case "PROCESSING_FAILED":
     return .processingFailed(filename: filename)
   case "PROCESSING_TIMEOUT":
     return .processingTimeout(filename: filename)
   case "CONFIG_ERROR", "UPLOAD_FAILED":
     return .uploadFailed(reason: message)
   default:
     if statusCode >= 500 {
       return .requestFailed(statusCode: statusCode, message: "Server error during upload")
     }
     return .uploadFailed(reason: message)
   }
 }

 ERROR CODE TO CHAT ERROR MAPPING:
 - UNSUPPORTED_FILE_TYPE -> ChatError.uploadFailed(reason: "File type not supported")
 - FILE_TOO_LARGE        -> ChatError.uploadFailed(reason: "File '<filename>' is too large")
 - EMPTY_FILE            -> ChatError.uploadFailed(reason: "File '<filename>' is empty")
 - INVALID_BASE64        -> ChatError.uploadFailed(reason: "Invalid file data")
 - PROCESSING_FAILED     -> ChatError.processingFailed(filename: <filename>)
 - PROCESSING_TIMEOUT    -> ChatError.processingTimeout(filename: <filename>)
 - CONFIG_ERROR          -> ChatError.uploadFailed(reason: <server message>)
 - UPLOAD_FAILED         -> ChatError.uploadFailed(reason: <server message>)
 - (unknown) + 5xx       -> ChatError.requestFailed(statusCode: <code>, message: "Server error during upload")
 - (unknown) + other     -> ChatError.uploadFailed(reason: <server message>)
*/

// MARK: - Mock URLProtocol Usage

/*
 TEST SETUP PATTERN:

 The tests use ChatClientMockURLProtocol (from ChatClientTests.swift) to intercept
 network requests and return mock responses.

 Example test setup:
 ```swift
 @Test("successful PNG upload returns UploadedFileReference")
 func successfulPngUpload() async throws {
   // Configure mock to return success response
   ChatClientMockURLProtocol.requestHandler = { request in
     // Verify request
     #expect(request.httpMethod == "POST")
     #expect(request.url?.path.contains("uploadFile") == true)

     // Return mock response
     let responseJSON: [String: Any] = [
       "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/abc123",
       "mimeType": "image/png",
       "name": "files/abc123",
       "expiresAt": "2024-12-15T12:00:00Z"
     ]
     let data = try JSONSerialization.data(withJSONObject: responseJSON)
     let response = HTTPURLResponse(
       url: request.url!,
       statusCode: 200,
       httpVersion: nil,
       headerFields: nil
     )!
     return (response, data)
   }

   // Create client with mock session
   let session = createMockSession()
   let client = FirebaseChatClient(urlSession: session)

   // Create test attachment
   let attachment = FileAttachment(
     id: "test-id",
     filename: "test.png",
     mimeType: .png,
     sizeBytes: 1024,
     base64Data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ",
     estimatedTokens: 258
   )

   // Execute and verify
   let result = try await client.uploadFile(attachment)

   #expect(result.fileUri == "https://generativelanguage.googleapis.com/v1beta/files/abc123")
   #expect(result.mimeType == "image/png")
   #expect(result.name == "files/abc123")
   #expect(result.expiresAt == "2024-12-15T12:00:00Z")
 }
 ```
*/
