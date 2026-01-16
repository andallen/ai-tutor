//
// SSEParser.swift
// InkOS
//
// Parser for Server-Sent Events (SSE) streams from Alan and subagent endpoints.
// Converts raw SSE data lines into typed AlanStreamEvent values.
//

import Foundation

// MARK: - AlanStreamEvent

// Events that can be received from the Alan SSE stream.
enum AlanStreamEvent: Sendable, Equatable {
  // Streaming text chunk (partial content).
  case textChunk(String)

  // A complete direct block (Text or Input).
  case blockComplete(Block)

  // A subagent request that needs processing.
  case subagentRequest(SubagentRequest)

  // Updated session model from Alan.
  case sessionModelUpdate(SessionModel)

  // Stream completed successfully.
  case done(tokenMetadata: TokenMetadata?)

  // An error occurred.
  case error(code: String, message: String)
}

// MARK: - SSEParser

// Parses Server-Sent Events data into AlanStreamEvent values.
struct SSEParser {
  private init() {}

  // Parses a single SSE data line into an event.
  // Returns nil if the line is not a valid data line.
  static func parse(line: String) -> AlanStreamEvent? {
    // SSE data lines start with "data: "
    guard line.hasPrefix("data: ") else { return nil }

    let jsonString = String(line.dropFirst(6))

    // Empty data line.
    guard !jsonString.isEmpty else { return nil }

    // Special case: "[DONE]" marker used by some APIs.
    if jsonString == "[DONE]" {
      return .done(tokenMetadata: nil)
    }

    // Parse JSON.
    guard let data = jsonString.data(using: .utf8) else { return nil }

    do {
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      guard let json = json else { return nil }

      return parseJSON(json)
    } catch {
      return nil
    }
  }

  // Parses a JSON dictionary into an AlanStreamEvent.
  private static func parseJSON(_ json: [String: Any]) -> AlanStreamEvent? {
    // Check for done event.
    if let done = json["done"] as? Bool, done {
      let metadata = parseTokenMetadata(from: json)
      return .done(tokenMetadata: metadata)
    }

    // Check for error event.
    if let errorDict = json["error"] as? [String: Any] {
      let code = errorDict["code"] as? String ?? "unknown"
      let message = errorDict["message"] as? String ?? "Unknown error"
      return .error(code: code, message: message)
    }

    // Check for text chunk.
    if let text = json["text"] as? String {
      return .textChunk(text)
    }

    // Check for complete block.
    if let blockDict = json["block"] as? [String: Any] {
      if let block = decodeBlock(from: blockDict) {
        return .blockComplete(block)
      }
    }

    // Check for subagent request.
    if let requestDict = json["subagent_request"] as? [String: Any] {
      if let request = decodeSubagentRequest(from: requestDict) {
        return .subagentRequest(request)
      }
    }

    // Check for notebook update with action.
    if let updateDict = json["notebook_update"] as? [String: Any] {
      return parseNotebookUpdate(updateDict)
    }

    // Check for session model update.
    if let modelDict = json["session_model"] as? [String: Any] {
      if let sessionModel = decodeSessionModel(from: modelDict) {
        return .sessionModelUpdate(sessionModel)
      }
    }

    return nil
  }

  // Parses a notebook update dictionary.
  private static func parseNotebookUpdate(_ dict: [String: Any]) -> AlanStreamEvent? {
    guard let action = dict["action"] as? String else { return nil }

    switch action {
    case "append":
      if let contentDict = dict["content"] as? [String: Any] {
        if let block = decodeBlock(from: contentDict) {
          return .blockComplete(block)
        }
      }
    case "request":
      if let contentDict = dict["content"] as? [String: Any] {
        if let request = decodeSubagentRequest(from: contentDict) {
          return .subagentRequest(request)
        }
      }
    default:
      break
    }

    return nil
  }

  // Parses token metadata from JSON.
  private static func parseTokenMetadata(from json: [String: Any]) -> TokenMetadata? {
    guard let metadataDict = json["token_metadata"] as? [String: Any] else {
      // Try direct properties.
      let prompt = json["prompt_token_count"] as? Int
      let candidates = json["candidates_token_count"] as? Int
      let total = json["total_token_count"] as? Int

      if prompt != nil || candidates != nil || total != nil {
        return TokenMetadata(
          promptTokenCount: prompt,
          candidatesTokenCount: candidates,
          totalTokenCount: total
        )
      }
      return nil
    }

    return TokenMetadata(
      promptTokenCount: metadataDict["prompt_token_count"] as? Int,
      candidatesTokenCount: metadataDict["candidates_token_count"] as? Int,
      totalTokenCount: metadataDict["total_token_count"] as? Int
    )
  }

  // Decodes a Block from a dictionary.
  private static func decodeBlock(from dict: [String: Any]) -> Block? {
    do {
      let data = try JSONSerialization.data(withJSONObject: dict)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode(Block.self, from: data)
    } catch {
      return nil
    }
  }

  // Decodes a SubagentRequest from a dictionary.
  private static func decodeSubagentRequest(from dict: [String: Any]) -> SubagentRequest? {
    do {
      let data = try JSONSerialization.data(withJSONObject: dict)
      let decoder = JSONDecoder()
      return try decoder.decode(SubagentRequest.self, from: data)
    } catch {
      return nil
    }
  }

  // Decodes a SessionModel from a dictionary.
  private static func decodeSessionModel(from dict: [String: Any]) -> SessionModel? {
    do {
      let data = try JSONSerialization.data(withJSONObject: dict)
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return try decoder.decode(SessionModel.self, from: data)
    } catch {
      return nil
    }
  }
}

// MARK: - SSELineBuffer

// Buffers incoming data and extracts complete lines for SSE parsing.
// SSE uses newline-delimited JSON, so we need to buffer partial lines.
struct SSELineBuffer {
  private var buffer: String = ""

  // Appends data to the buffer and returns complete lines.
  mutating func append(_ data: Data) -> [String] {
    guard let string = String(data: data, encoding: .utf8) else {
      return []
    }

    buffer += string

    var lines: [String] = []
    while let newlineIndex = buffer.firstIndex(of: "\n") {
      let line = String(buffer[..<newlineIndex])
      buffer = String(buffer[buffer.index(after: newlineIndex)...])

      // Skip empty lines (SSE uses double newlines as event separators).
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if !trimmed.isEmpty {
        lines.append(trimmed)
      }
    }

    return lines
  }

  // Returns any remaining buffered content.
  func remainder() -> String {
    buffer
  }

  // Clears the buffer.
  mutating func clear() {
    buffer = ""
  }
}
