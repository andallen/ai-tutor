// TokenResponseParser.swift
// Implementation of TokenResponseParserProtocol for parsing Firebase responses.
// Handles both non-streaming and streaming response formats.

import Foundation

// Parser for extracting token metadata from Firebase responses.
// Uses JSONDecoder for parsing. Thread-safe as it uses only value types.
struct TokenResponseParser: TokenResponseParserProtocol {

  // JSON decoder configured for Firebase response format.
  private let decoder: JSONDecoder

  // Creates a parser with default JSON decoder configuration.
  init() {
    self.decoder = JSONDecoder()
  }

  // Parses a complete response from sendMessage endpoint.
  func parseResponse(data: Data) throws -> FirebaseTokenResponse {
    // Check for empty data.
    guard !data.isEmpty else {
      throw TokenParsingError.invalidJSON(reason: "Empty data")
    }

    do {
      return try decoder.decode(FirebaseTokenResponse.self, from: data)
    } catch let error as DecodingError {
      // Check if the error is due to missing response field.
      if case .keyNotFound(let key, _) = error, key.stringValue == "response" {
        throw TokenParsingError.missingResponseField
      }
      throw TokenParsingError.invalidJSON(reason: error.localizedDescription)
    } catch {
      throw TokenParsingError.invalidJSON(reason: error.localizedDescription)
    }
  }

  // Parses a single SSE chunk from streamMessage endpoint.
  func parseStreamChunk(jsonString: String) throws -> FirebaseStreamChunk {
    // Check for empty or whitespace-only string.
    let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw TokenParsingError.invalidStreamChunk(reason: "Empty chunk data")
    }

    // Convert string to data.
    guard let data = trimmed.data(using: .utf8) else {
      throw TokenParsingError.encodingError
    }

    do {
      return try decoder.decode(FirebaseStreamChunk.self, from: data)
    } catch {
      throw TokenParsingError.invalidStreamChunk(reason: error.localizedDescription)
    }
  }

  // Extracts token metadata from accumulated stream chunks.
  // Returns the last chunk's tokenMetadata if present.
  func extractTokenMetadata(from chunks: [FirebaseStreamChunk]) -> FirebaseStreamTokenMetadata? {
    // Find the last chunk with token metadata.
    for chunk in chunks.reversed() {
      if let metadata = chunk.tokenMetadata {
        return metadata
      }
    }
    return nil
  }
}
