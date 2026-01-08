// FirebaseChatClient.swift
// Firebase HTTP client for calling sendMessage and streamMessage Cloud Functions.

import Foundation

// Actor that handles chat requests via Firebase Cloud Functions.
// Uses URLSession for HTTP POST requests and Server-Sent Events streaming.
actor FirebaseChatClient: ChatClientProtocol {

  // HTTP client for making requests.
  private let urlSession: URLSession

  // Configuration containing Firebase project settings and endpoint URLs.
  private let configuration: ChatConfiguration

  // Creates a chat client with the specified configuration.
  init(
    configuration: ChatConfiguration = .default,
    urlSession: URLSession = .shared
  ) {
    self.configuration = configuration
    self.urlSession = urlSession
  }

  // Sends a message and waits for the complete response.
  func sendMessage(messages: [APIMessage]) async throws -> String {
    // Validate input.
    guard !messages.isEmpty else {
      throw ChatError.emptyMessages
    }

    // Build the request body.
    let requestBody: [String: Any] = [
      "messages": messages.map { msg in
        [
          "role": msg.role,
          "content": msg.content
        ]
      }
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

    // Build the HTTP request.
    var request = URLRequest(url: configuration.sendMessageURL)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = ChatConstants.requestTimeout

    // Execute the request.
    let (data, response) = try await urlSession.data(for: request)

    // Check for HTTP errors.
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ChatError.networkError(reason: "Invalid response type")
    }

    guard httpResponse.statusCode == 200 else {
      let errorInfo = parseErrorResponse(data: data)
      throw mapHTTPError(
        statusCode: httpResponse.statusCode,
        message: errorInfo.message,
        errorCode: errorInfo.errorCode,
        tokenCount: errorInfo.tokenCount,
        maxTokens: errorInfo.maxTokens
      )
    }

    // Parse the response.
    return try parseMessageResponse(data: data)
  }

  // Sends multimodal messages (with file attachments) and waits for complete response.
  func sendMessageMultimodal(messages: [APIMessageMultimodal]) async throws -> String {
    // Validate input.
    guard !messages.isEmpty else {
      throw ChatError.emptyMessages
    }

    // Encode multimodal messages to JSON.
    let encoder = JSONEncoder()
    let requestBody: [String: Any]
    do {
      let messagesData = try encoder.encode(messages)
      guard let messagesArray = try JSONSerialization.jsonObject(with: messagesData) as? [[String: Any]] else {
        throw ChatError.invalidRequest(reason: "Failed to serialize multimodal messages")
      }
      requestBody = ["messages": messagesArray]
    } catch let error as ChatError {
      throw error
    } catch {
      throw ChatError.invalidRequest(reason: "Failed to encode multimodal messages: \(error.localizedDescription)")
    }

    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

    // Build the HTTP request.
    var request = URLRequest(url: configuration.sendMessageURL)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = ChatConstants.requestTimeout

    // Execute the request.
    let (data, response) = try await urlSession.data(for: request)

    // Check for HTTP errors.
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ChatError.networkError(reason: "Invalid response type")
    }

    guard httpResponse.statusCode == 200 else {
      let errorInfo = parseErrorResponse(data: data)
      throw mapHTTPError(
        statusCode: httpResponse.statusCode,
        message: errorInfo.message,
        errorCode: errorInfo.errorCode,
        tokenCount: errorInfo.tokenCount,
        maxTokens: errorInfo.maxTokens
      )
    }

    // Parse the response.
    return try parseMessageResponse(data: data)
  }

  // Sends a message and returns a stream of response chunks.
  func streamMessage(messages: [APIMessage]) -> AsyncThrowingStream<String, Error> {
    return AsyncThrowingStream { continuation in
      Task {
        do {
          // Validate input.
          guard !messages.isEmpty else {
            continuation.finish(throwing: ChatError.emptyMessages)
            return
          }

          // Build the request body.
          let requestBody: [String: Any] = [
            "messages": messages.map { msg in
              [
                "role": msg.role,
                "content": msg.content
              ]
            }
          ]

          let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

          // Build the HTTP request.
          var request = URLRequest(url: configuration.streamMessageURL)
          request.httpMethod = "POST"
          request.httpBody = jsonData
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.timeoutInterval = ChatConstants.streamingTimeout

          // Execute the request and get the byte stream.
          let (bytes, response) = try await urlSession.bytes(for: request)

          // Check for HTTP errors.
          guard let httpResponse = response as? HTTPURLResponse else {
            continuation.finish(throwing: ChatError.networkError(reason: "Invalid response type"))
            return
          }

          guard httpResponse.statusCode == 200 else {
            // For streaming errors, we can't easily read the body, so just use status code.
            continuation.finish(
              throwing: ChatError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: "Streaming request failed"
              )
            )
            return
          }

          // Parse Server-Sent Events.
          var buffer = ""
          for try await byte in bytes {
            // Check for cancellation.
            if Task.isCancelled {
              continuation.finish(throwing: CancellationError())
              return
            }

            let char = String(bytes: [byte], encoding: .utf8) ?? ""
            buffer.append(char)

            // Process complete lines (SSE events end with \n\n).
            while let newlineRange = buffer.range(of: "\n") {
              let line = String(buffer[..<newlineRange.lowerBound])
              buffer.removeSubrange(...newlineRange.upperBound)

              // Parse SSE data lines.
              if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))  // Remove "data: " prefix

                if jsonString.trimmingCharacters(in: .whitespaces).isEmpty {
                  continue
                }

                // Parse JSON from the data field.
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                else {
                  // Skip malformed JSON.
                  continue
                }

                // Check for done flag.
                if let done = json["done"] as? Bool, done {
                  continuation.finish()
                  return
                }

                // Yield text chunks.
                if let text = json["text"] as? String, !text.isEmpty {
                  continuation.yield(text)
                }
              }
            }
          }

          // Stream ended without "done: true" - finish normally.
          continuation.finish()

        } catch {
          if error is ChatError {
            continuation.finish(throwing: error)
          } else {
            continuation.finish(
              throwing: ChatError.streamingFailed(reason: error.localizedDescription)
            )
          }
        }
      }
    }
  }

  // Sends multimodal messages and returns a stream of response chunks.
  func streamMessageMultimodal(messages: [APIMessageMultimodal]) -> AsyncThrowingStream<String, Error> {
    return AsyncThrowingStream { continuation in
      Task {
        do {
          // Validate input.
          guard !messages.isEmpty else {
            continuation.finish(throwing: ChatError.emptyMessages)
            return
          }

          // Encode multimodal messages to JSON.
          let encoder = JSONEncoder()
          let requestBody: [String: Any]
          do {
            let messagesData = try encoder.encode(messages)
            guard let messagesArray = try JSONSerialization.jsonObject(with: messagesData) as? [[String: Any]] else {
              continuation.finish(throwing: ChatError.invalidRequest(reason: "Failed to serialize multimodal messages"))
              return
            }
            requestBody = ["messages": messagesArray]
          } catch {
            continuation.finish(throwing: ChatError.invalidRequest(reason: "Failed to encode multimodal messages"))
            return
          }

          let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

          // Build the HTTP request.
          var request = URLRequest(url: configuration.streamMessageURL)
          request.httpMethod = "POST"
          request.httpBody = jsonData
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.timeoutInterval = ChatConstants.streamingTimeout

          // Execute the request and get the byte stream.
          let (bytes, response) = try await urlSession.bytes(for: request)

          // Check for HTTP errors.
          guard let httpResponse = response as? HTTPURLResponse else {
            continuation.finish(throwing: ChatError.networkError(reason: "Invalid response type"))
            return
          }

          guard httpResponse.statusCode == 200 else {
            continuation.finish(
              throwing: ChatError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: "Streaming request failed"
              )
            )
            return
          }

          // Parse Server-Sent Events.
          var buffer = ""
          for try await byte in bytes {
            // Check for cancellation.
            if Task.isCancelled {
              continuation.finish(throwing: CancellationError())
              return
            }

            let char = String(bytes: [byte], encoding: .utf8) ?? ""
            buffer.append(char)

            // Process complete lines (SSE events end with \n\n).
            while let newlineRange = buffer.range(of: "\n") {
              let line = String(buffer[..<newlineRange.lowerBound])
              buffer.removeSubrange(...newlineRange.upperBound)

              // Parse SSE data lines.
              if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))

                if jsonString.trimmingCharacters(in: .whitespaces).isEmpty {
                  continue
                }

                // Parse JSON from the data field.
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                else {
                  continue
                }

                // Check for done flag.
                if let done = json["done"] as? Bool, done {
                  continuation.finish()
                  return
                }

                // Yield text chunks.
                if let text = json["text"] as? String, !text.isEmpty {
                  continuation.yield(text)
                }
              }
            }
          }

          // Stream ended without "done: true" - finish normally.
          continuation.finish()

        } catch {
          if error is ChatError {
            continuation.finish(throwing: error)
          } else {
            continuation.finish(
              throwing: ChatError.streamingFailed(reason: error.localizedDescription)
            )
          }
        }
      }
    }
  }

  // Uploads a file attachment to the Gemini Files API via Cloud Function.
  // Returns UploadedFileReference with file URI for use in multimodal messages.
  func uploadFile(_ attachment: FileAttachment) async throws -> UploadedFileReference {
    // Build request body matching Cloud Function schema.
    let requestBody: [String: Any] = [
      "base64Data": attachment.base64Data,
      "mimeType": attachment.mimeType.rawValue,
      "displayName": attachment.filename,
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
      throw ChatError.uploadFailed(reason: "Failed to encode request")
    }

    // Build the HTTP request.
    var request = URLRequest(url: configuration.uploadFileURL)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = ChatConstants.uploadTimeout

    // Execute the request.
    let (data, response) = try await urlSession.data(for: request)

    // Check for HTTP errors.
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ChatError.networkError(reason: "Invalid response type")
    }

    guard httpResponse.statusCode == 200 else {
      let errorInfo = parseErrorResponse(data: data)
      throw mapUploadError(
        statusCode: httpResponse.statusCode,
        errorCode: errorInfo.errorCode,
        message: errorInfo.message,
        filename: attachment.filename
      )
    }

    // Parse the successful response.
    return try parseUploadResponse(data: data, filename: attachment.filename)
  }

  // MARK: - Private Methods

  // Parses the response from sendMessage endpoint.
  // Expected format: { "response": "..." }
  private func parseMessageResponse(data: Data) throws -> String {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let response = json["response"] as? String
    else {
      throw ChatError.invalidResponse(reason: "Missing or invalid 'response' field")
    }
    return response
  }

  // Parses error details from the response body.
  // Returns a tuple of (message, errorCode, tokenCount, maxTokens)
  private func parseErrorResponse(data: Data) -> (message: String, errorCode: String?, tokenCount: Int?, maxTokens: Int?) {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      let errorMessage: String
      if let error = json["error"] as? String {
        errorMessage = error
      } else if let error = json["error"] as? [String: Any],
                let message = error["message"] as? String {
        errorMessage = message
      } else if let details = json["details"] as? String {
        errorMessage = details
      } else {
        errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
      }

      let errorCode = json["errorCode"] as? String
      let tokenCount = json["tokenCount"] as? Int
      let maxTokens = json["maxTokens"] as? Int

      return (errorMessage, errorCode, tokenCount, maxTokens)
    }

    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
    return (message, nil, nil, nil)
  }

  // Maps HTTP status codes to appropriate ChatError cases.
  private func mapHTTPError(statusCode: Int, message: String, errorCode: String?, tokenCount: Int?, maxTokens: Int?) -> ChatError {
    // Check for token limit errors
    if statusCode == 400 {
      if errorCode == FirebaseTokenConstants.messageTooLargeCode,
         let tokens = tokenCount,
         let max = maxTokens {
        // Single message is too large
        return .invalidRequest(reason: "Message is too large: \(tokens) tokens (maximum \(max) tokens). Please reduce the amount of context.")
      } else if errorCode == FirebaseTokenConstants.tokenLimitErrorCode,
                let tokens = tokenCount,
                let max = maxTokens {
        // Total request exceeds limit
        return .invalidRequest(reason: "Request exceeds token limit: \(tokens) tokens (maximum \(max) tokens).")
      } else {
        return .invalidRequest(reason: message)
      }
    }

    switch statusCode {
    case 401, 403, 429, 500..<600:
      return .requestFailed(statusCode: statusCode, message: message)
    default:
      return .networkError(reason: "HTTP \(statusCode): \(message)")
    }
  }

  // Parses the response from uploadFile endpoint.
  // Expected format: { "fileUri": "...", "mimeType": "...", "name": "...", "expiresAt": "..." }
  private func parseUploadResponse(data: Data, filename: String) throws -> UploadedFileReference {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let fileUri = json["fileUri"] as? String,
          let mimeType = json["mimeType"] as? String,
          let name = json["name"] as? String
    else {
      throw ChatError.uploadFailed(reason: "Invalid response format")
    }

    let expiresAt = json["expiresAt"] as? String

    return UploadedFileReference(
      fileUri: fileUri,
      mimeType: mimeType,
      name: name,
      expiresAt: expiresAt
    )
  }

  // Maps HTTP errors to domain errors for file uploads.
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
}
