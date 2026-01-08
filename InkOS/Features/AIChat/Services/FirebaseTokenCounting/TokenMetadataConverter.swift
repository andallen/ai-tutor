// TokenMetadataConverter.swift
// Implementation of TokenMetadataConverterProtocol for converting Firebase metadata.
// Bridges Firebase response format to the app's internal TokenMetadata format.

import Foundation

// Converter for mapping Firebase token metadata to ChatMessage TokenMetadata.
// Provides fallback estimation when Firebase metadata is unavailable.
struct TokenMetadataConverter: TokenMetadataConverterProtocol {

  // Converts non-streaming response metadata to ChatMessage TokenMetadata.
  func convert(from response: FirebaseTokenResponse) -> TokenMetadata? {
    // Return nil if tokenMetadata is not present.
    guard let firebaseMetadata = response.tokenMetadata else {
      return nil
    }

    return TokenMetadata(
      inputTokens: firebaseMetadata.promptTokenCount,
      outputTokens: firebaseMetadata.candidatesTokenCount,
      totalTokens: firebaseMetadata.totalTokenCount,
      contextTruncated: response.historyTruncated ?? false,
      messagesIncluded: response.messagesIncluded ?? 0
    )
  }

  // Converts streaming response metadata to ChatMessage TokenMetadata.
  func convert(from streamMetadata: FirebaseStreamTokenMetadata) -> TokenMetadata {
    return TokenMetadata(
      inputTokens: streamMetadata.promptTokenCount,
      outputTokens: streamMetadata.candidatesTokenCount,
      totalTokens: streamMetadata.totalTokenCount,
      contextTruncated: streamMetadata.historyTruncated,
      messagesIncluded: streamMetadata.messagesIncluded
    )
  }

  // Creates estimated TokenMetadata when Firebase metadata is unavailable.
  // Uses client-side character-based estimation as fallback.
  func createEstimatedMetadata(
    inputContent: String,
    outputContent: String,
    messagesIncluded: Int
  ) -> TokenMetadata {
    let inputTokens = estimateTokenCount(inputContent)
    let outputTokens = estimateTokenCount(outputContent)

    return TokenMetadata(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: inputTokens + outputTokens,
      contextTruncated: false,  // Cannot determine without server info.
      messagesIncluded: messagesIncluded
    )
  }

  // Estimates token count using characters per token heuristic.
  private func estimateTokenCount(_ text: String) -> Int {
    guard !text.isEmpty else { return 0 }
    return Int(ceil(Double(text.count) / TokenBudgetConstants.charsPerToken))
  }
}
