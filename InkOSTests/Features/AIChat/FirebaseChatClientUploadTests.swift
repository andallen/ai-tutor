// FirebaseChatClientUploadTests.swift
// Tests for FirebaseChatClient.uploadFile() functionality.
// Validates file upload to Gemini Files API via Cloud Function.
// Uses ChatClientMockURLProtocol to intercept network requests.

import Foundation
import Testing

@testable import InkOS

// MARK: - FirebaseChatClient Upload Tests

@Suite("FirebaseChatClient Upload Tests", .serialized)
struct FirebaseChatClientUploadTests {

  // Creates a URLSession configured with mock protocol for intercepting requests.
  private func createMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ChatClientMockURLProtocol.self]
    return URLSession(configuration: config)
  }

  // Creates a test FileAttachment with configurable properties.
  private func createTestAttachment(
    id: String = "test-attachment-id",
    filename: String = "test.png",
    mimeType: AttachmentMimeType = .png,
    sizeBytes: Int = 1024,
    base64Data: String = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ",
    estimatedTokens: Int? = 258
  ) -> FileAttachment {
    return FileAttachment(
      id: id,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      base64Data: base64Data,
      estimatedTokens: estimatedTokens
    )
  }

  // Creates a successful upload response JSON data.
  private func createSuccessResponse(
    fileUri: String = "https://generativelanguage.googleapis.com/v1beta/files/abc123",
    mimeType: String = "image/png",
    name: String = "files/abc123",
    expiresAt: String? = "2024-12-15T12:00:00Z"
  ) throws -> Data {
    var response: [String: Any] = [
      "fileUri": fileUri,
      "mimeType": mimeType,
      "name": name
    ]
    if let expiresAt = expiresAt {
      response["expiresAt"] = expiresAt
    }
    return try JSONSerialization.data(withJSONObject: response)
  }

  // Creates an error response JSON data.
  private func createErrorResponse(
    errorCode: String? = nil,
    error: String = "Error message"
  ) throws -> Data {
    var response: [String: Any] = ["error": error]
    if let errorCode = errorCode {
      response["errorCode"] = errorCode
    }
    return try JSONSerialization.data(withJSONObject: response)
  }

  // Creates an HTTPURLResponse with the specified status code.
  private func createHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
    return HTTPURLResponse(
      url: url,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
  }

  // MARK: - Successful Upload Tests

  @Suite("Successful Upload")
  struct SuccessfulUploadTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ChatClientMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    private func createTestAttachment(
      filename: String = "test.png",
      mimeType: AttachmentMimeType = .png
    ) -> FileAttachment {
      return FileAttachment(
        id: "test-id",
        filename: filename,
        mimeType: mimeType,
        sizeBytes: 1024,
        base64Data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ",
        estimatedTokens: 258
      )
    }

    @Test("successful PNG upload returns correct UploadedFileReference")
    func successfulPngUpload() async throws {
      // Configure mock to return success response.
      ChatClientMockURLProtocol.requestHandler = { request in
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment(filename: "test.png", mimeType: .png)

      let result = try await client.uploadFile(attachment)

      #expect(result.fileUri == "https://generativelanguage.googleapis.com/v1beta/files/abc123")
      #expect(result.mimeType == "image/png")
      #expect(result.name == "files/abc123")
      #expect(result.expiresAt == "2024-12-15T12:00:00Z")
    }

    @Test("successful JPEG upload returns correct UploadedFileReference")
    func successfulJpegUpload() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let responseJSON: [String: Any] = [
          "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/jpeg123",
          "mimeType": "image/jpeg",
          "name": "files/jpeg123",
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment(filename: "photo.jpg", mimeType: .jpeg)

      let result = try await client.uploadFile(attachment)

      #expect(result.mimeType == "image/jpeg")
    }

    @Test("successful PDF upload returns correct UploadedFileReference")
    func successfulPdfUpload() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let responseJSON: [String: Any] = [
          "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/pdf123",
          "mimeType": "application/pdf",
          "name": "files/pdf123",
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment(filename: "document.pdf", mimeType: .pdf)

      let result = try await client.uploadFile(attachment)

      #expect(result.mimeType == "application/pdf")
    }

    @Test("successful upload with null expiresAt returns nil expiration")
    func successfulUploadWithNullExpiresAt() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let responseJSON: [String: Any] = [
          "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/abc123",
          "mimeType": "image/png",
          "name": "files/abc123",
          "expiresAt": NSNull()
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      let result = try await client.uploadFile(attachment)

      #expect(result.expiresAt == nil)
      #expect(result.fileUri == "https://generativelanguage.googleapis.com/v1beta/files/abc123")
    }

    @Test("successful upload without expiresAt field returns nil expiration")
    func successfulUploadWithMissingExpiresAt() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        // Response JSON without expiresAt field.
        let responseJSON: [String: Any] = [
          "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/abc123",
          "mimeType": "image/png",
          "name": "files/abc123"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      let result = try await client.uploadFile(attachment)

      #expect(result.expiresAt == nil)
    }
  }

  // MARK: - Request Format Tests

  @Suite("Request Format Validation")
  struct RequestFormatTests {

    // Static storage for captured values (needed for URLProtocol closure capture).
    nonisolated(unsafe) private static var capturedMethod: String?
    nonisolated(unsafe) private static var capturedContentType: String?
    nonisolated(unsafe) private static var capturedURLPath: String?

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ChatClientMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    private static func resetCapturedValues() {
      capturedMethod = nil
      capturedContentType = nil
      capturedURLPath = nil
    }

    @Test("request uses POST method")
    func requestUsesPostMethod() async throws {
      Self.resetCapturedValues()

      ChatClientMockURLProtocol.requestHandler = { request in
        Self.capturedMethod = request.httpMethod
        let responseJSON: [String: Any] = [
          "fileUri": "https://test.com/files/abc",
          "mimeType": "image/png",
          "name": "files/abc"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )

      _ = try await client.uploadFile(attachment)

      #expect(Self.capturedMethod == "POST")
    }

    @Test("request has correct Content-Type header")
    func requestHasCorrectContentTypeHeader() async throws {
      Self.resetCapturedValues()

      ChatClientMockURLProtocol.requestHandler = { request in
        Self.capturedContentType = request.value(forHTTPHeaderField: "Content-Type")
        let responseJSON: [String: Any] = [
          "fileUri": "https://test.com/files/abc",
          "mimeType": "image/png",
          "name": "files/abc"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )

      _ = try await client.uploadFile(attachment)

      #expect(Self.capturedContentType == "application/json")
    }

    @Test("request URL matches configuration uploadFileURL")
    func requestUrlMatchesConfiguration() async throws {
      Self.resetCapturedValues()

      ChatClientMockURLProtocol.requestHandler = { request in
        Self.capturedURLPath = request.url?.path
        let responseJSON: [String: Any] = [
          "fileUri": "https://test.com/files/abc",
          "mimeType": "image/png",
          "name": "files/abc"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )

      _ = try await client.uploadFile(attachment)

      #expect(Self.capturedURLPath?.contains("uploadFile") == true)
    }
  }

  // MARK: - Error Code Mapping Tests

  @Suite("Error Code Mapping")
  struct ErrorCodeMappingTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ChatClientMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    private func createTestAttachment(filename: String = "test.png") -> FileAttachment {
      return FileAttachment(
        id: "test-id",
        filename: filename,
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )
    }

    @Test("UNSUPPORTED_FILE_TYPE maps to uploadFailed")
    func unsupportedFileTypeMapsToUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "Unsupported file type",
          "errorCode": "UNSUPPORTED_FILE_TYPE"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 400,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "File type not supported")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("FILE_TOO_LARGE maps to uploadFailed with filename")
    func fileTooLargeMapsToUploadFailedWithFilename() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "File too large",
          "errorCode": "FILE_TOO_LARGE"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 400,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment(filename: "huge_image.png")

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason.contains("huge_image.png"))
          #expect(reason.contains("too large"))
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("EMPTY_FILE maps to uploadFailed with filename")
    func emptyFileMapsToUploadFailedWithFilename() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "Empty file",
          "errorCode": "EMPTY_FILE"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 400,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment(filename: "empty.txt")

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason.contains("empty.txt"))
          #expect(reason.contains("empty"))
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("INVALID_BASE64 maps to uploadFailed")
    func invalidBase64MapsToUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "Invalid base64 data",
          "errorCode": "INVALID_BASE64"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 400,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Invalid file data")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("PROCESSING_FAILED maps to processingFailed with filename")
    func processingFailedMapsToProcessingFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "File processing failed",
          "errorCode": "PROCESSING_FAILED"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 500,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment(filename: "corrupted.pdf")

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected processingFailed error")
      } catch let error as ChatError {
        if case .processingFailed(let filename) = error {
          #expect(filename == "corrupted.pdf")
        } else {
          Issue.record("Expected processingFailed error, got: \(error)")
        }
      }
    }

    @Test("PROCESSING_TIMEOUT maps to processingTimeout with filename")
    func processingTimeoutMapsToProcessingTimeout() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "File processing timed out",
          "errorCode": "PROCESSING_TIMEOUT"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 504,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment(filename: "slow.pdf")

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected processingTimeout error")
      } catch let error as ChatError {
        if case .processingTimeout(let filename) = error {
          #expect(filename == "slow.pdf")
        } else {
          Issue.record("Expected processingTimeout error, got: \(error)")
        }
      }
    }

    @Test("CONFIG_ERROR maps to uploadFailed with server message")
    func configErrorMapsToUploadFailedWithMessage() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "GOOGLE_GENAI_API_KEY not configured",
          "errorCode": "CONFIG_ERROR"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 500,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "GOOGLE_GENAI_API_KEY not configured")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("UPLOAD_FAILED maps to uploadFailed with server message")
    func uploadFailedCodeMapsToUploadFailedWithMessage() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "Gemini API returned 503",
          "errorCode": "UPLOAD_FAILED"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 500,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Gemini API returned 503")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }
  }

  // MARK: - Server Error Tests (5xx)

  @Suite("Server Errors (5xx)")
  struct ServerErrorTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ChatClientMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    private func createTestAttachment() -> FileAttachment {
      return FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )
    }

    @Test("HTTP 500 with unknown errorCode returns requestFailed")
    func http500WithUnknownErrorCodeReturnsRequestFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "Internal server error",
          "errorCode": "UNKNOWN_ERROR"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 500,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected requestFailed error")
      } catch let error as ChatError {
        if case .requestFailed(let statusCode, let message) = error {
          #expect(statusCode == 500)
          #expect(message == "Server error during upload")
        } else {
          Issue.record("Expected requestFailed error, got: \(error)")
        }
      }
    }

    @Test("HTTP 500 without errorCode returns requestFailed")
    func http500WithoutErrorCodeReturnsRequestFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "Internal server error"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 500,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected requestFailed error")
      } catch let error as ChatError {
        if case .requestFailed(let statusCode, _) = error {
          #expect(statusCode == 500)
        } else {
          Issue.record("Expected requestFailed error, got: \(error)")
        }
      }
    }

    @Test("HTTP 502 returns requestFailed")
    func http502ReturnsRequestFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = ["error": "Bad Gateway"]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 502,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected requestFailed error")
      } catch let error as ChatError {
        if case .requestFailed(let statusCode, _) = error {
          #expect(statusCode == 502)
        } else {
          Issue.record("Expected requestFailed error, got: \(error)")
        }
      }
    }

    @Test("HTTP 503 returns requestFailed")
    func http503ReturnsRequestFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = ["error": "Service Unavailable"]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 503,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected requestFailed error")
      } catch let error as ChatError {
        if case .requestFailed(let statusCode, _) = error {
          #expect(statusCode == 503)
        } else {
          Issue.record("Expected requestFailed error, got: \(error)")
        }
      }
    }

    @Test("HTTP 504 without PROCESSING_TIMEOUT returns requestFailed")
    func http504WithoutProcessingTimeoutReturnsRequestFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = ["error": "Gateway Timeout"]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 504,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected requestFailed error")
      } catch let error as ChatError {
        if case .requestFailed(let statusCode, _) = error {
          #expect(statusCode == 504)
        } else {
          Issue.record("Expected requestFailed error, got: \(error)")
        }
      }
    }
  }

  // MARK: - Invalid Response Tests

  @Suite("Invalid Response Handling")
  struct InvalidResponseTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ChatClientMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    private func createTestAttachment() -> FileAttachment {
      return FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )
    }

    @Test("missing fileUri in response throws uploadFailed")
    func missingFileUriThrowsUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let responseJSON: [String: Any] = [
          "mimeType": "image/png",
          "name": "files/abc123"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Invalid response format")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("missing mimeType in response throws uploadFailed")
    func missingMimeTypeThrowsUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let responseJSON: [String: Any] = [
          "fileUri": "https://test.com/files/abc",
          "name": "files/abc123"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Invalid response format")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("missing name in response throws uploadFailed")
    func missingNameThrowsUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let responseJSON: [String: Any] = [
          "fileUri": "https://test.com/files/abc",
          "mimeType": "image/png"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Invalid response format")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("non-JSON response throws uploadFailed")
    func nonJsonResponseThrowsUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let data = "This is plain text, not JSON".data(using: .utf8)!
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Invalid response format")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("empty response body throws uploadFailed")
    func emptyResponseBodyThrowsUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let data = Data()
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Invalid response format")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("malformed JSON throws uploadFailed")
    func malformedJsonThrowsUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let data = "{invalid json".data(using: .utf8)!
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Invalid response format")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }
  }

  // MARK: - HTTP Status Code Tests

  @Suite("HTTP Status Codes")
  struct HTTPStatusCodeTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ChatClientMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    private func createTestAttachment() -> FileAttachment {
      return FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )
    }

    @Test("HTTP 400 with error body parses errorCode")
    func http400ParsesErrorCode() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "error": "File type not supported",
          "errorCode": "UNSUPPORTED_FILE_TYPE"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 400,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected error")
      } catch let error as ChatError {
        // The error code is parsed and mapped correctly.
        if case .uploadFailed(let reason) = error {
          #expect(reason == "File type not supported")
        } else {
          Issue.record("Expected uploadFailed error")
        }
      }
    }

    @Test("HTTP 401 returns requestFailed")
    func http401ReturnsRequestFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = ["error": "Unauthorized"]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 401,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected error")
      } catch let error as ChatError {
        // HTTP 401 without special errorCode falls through to uploadFailed based on status code.
        // Per the implementation, 4xx without known errorCode returns uploadFailed with server message.
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Unauthorized")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("HTTP 429 returns uploadFailed")
    func http429ReturnsUploadFailed() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = ["error": "Too Many Requests"]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 429,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = createTestAttachment()

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected error")
      } catch let error as ChatError {
        // Per implementation, 4xx without known errorCode returns uploadFailed.
        if case .uploadFailed(let reason) = error {
          #expect(reason == "Too Many Requests")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    private func createMockSession() -> URLSession {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ChatClientMockURLProtocol.self]
      return URLSession(configuration: config)
    }

    @Test("response mimeType differs from request mimeType")
    func responseMimeTypeDiffersFromRequest() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        // Server converted HEIC to JPEG.
        let responseJSON: [String: Any] = [
          "fileUri": "https://test.com/files/abc",
          "mimeType": "image/jpeg",
          "name": "files/abc"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = FileAttachment(
        id: "test-id",
        filename: "photo.heic",
        mimeType: .heic,
        sizeBytes: 1024,
        base64Data: "somebase64data",
        estimatedTokens: 258
      )

      let result = try await client.uploadFile(attachment)

      // Server's mimeType is used, not the client's.
      #expect(result.mimeType == "image/jpeg")
    }

    @Test("extra response fields are ignored")
    func extraResponseFieldsIgnored() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let responseJSON: [String: Any] = [
          "fileUri": "https://test.com/files/abc",
          "mimeType": "image/png",
          "name": "files/abc",
          "expiresAt": "2024-12-15T12:00:00Z",
          "sizeBytes": 12345,
          "createdAt": "2024-12-01T12:00:00Z",
          "unknownField": "some value"
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

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )

      let result = try await client.uploadFile(attachment)

      // Standard fields are parsed correctly.
      #expect(result.fileUri == "https://test.com/files/abc")
      #expect(result.mimeType == "image/png")
      #expect(result.name == "files/abc")
      #expect(result.expiresAt == "2024-12-15T12:00:00Z")
    }

    @Test("nested error object parsing uses message field")
    func nestedErrorObjectParsing() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        // Error response with nested error object.
        let errorJSON: [String: Any] = [
          "error": [
            "message": "File too large",
            "code": 400
          ] as [String : Any],
          "errorCode": "FILE_TOO_LARGE"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 400,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = FileAttachment(
        id: "test-id",
        filename: "large.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        // Error code mapping should still work.
        if case .uploadFailed(let reason) = error {
          #expect(reason.contains("large.png"))
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }

    @Test("error response with details field instead of error")
    func errorResponseWithDetailsField() async throws {
      ChatClientMockURLProtocol.requestHandler = { request in
        let errorJSON: [String: Any] = [
          "details": "File type not supported",
          "errorCode": "UNSUPPORTED_FILE_TYPE"
        ]
        let data = try JSONSerialization.data(withJSONObject: errorJSON)
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 400,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, data)
      }

      let session = createMockSession()
      let client = FirebaseChatClient(urlSession: session)
      let attachment = FileAttachment(
        id: "test-id",
        filename: "test.png",
        mimeType: .png,
        sizeBytes: 1024,
        base64Data: "iVBORw0K",
        estimatedTokens: 258
      )

      do {
        _ = try await client.uploadFile(attachment)
        Issue.record("Expected uploadFailed error")
      } catch let error as ChatError {
        // Error code mapping should use the errorCode to determine error type.
        if case .uploadFailed(let reason) = error {
          #expect(reason == "File type not supported")
        } else {
          Issue.record("Expected uploadFailed error, got: \(error)")
        }
      }
    }
  }
}
