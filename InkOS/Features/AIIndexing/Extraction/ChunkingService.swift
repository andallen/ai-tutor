// ChunkingService.swift
// Splits extracted text into chunks suitable for embedding.

import Foundation

// Protocol for chunking service to support dependency injection.
protocol ChunkingServiceProtocol: Actor {
  func chunkContent(_ content: ExtractedContent) throws -> [DocumentChunk]
}

// Actor responsible for splitting text into chunks for embedding.
// Uses paragraph-based splitting with overlapping boundaries.
// Target chunk size is 512 tokens (~2000 characters).
// Overlap is 50 tokens (~200 characters) for context preservation.
actor ChunkingService: ChunkingServiceProtocol {

  // Configuration for chunk sizes.
  // Target character count per chunk (approximately 512 tokens).
  private let targetChunkSize: Int

  // Overlap character count between chunks (approximately 50 tokens).
  private let overlapSize: Int

  // Minimum chunk size to avoid tiny fragments.
  private let minimumChunkSize: Int

  // Approximate characters per token for estimation.
  // English text averages about 4 characters per token.
  private static let charsPerToken: Double = 4.0

  // Initializes the chunking service with default configuration.
  // targetTokens: Target tokens per chunk (default 512).
  // overlapTokens: Overlap tokens between chunks (default 50).
  init(targetTokens: Int = 512, overlapTokens: Int = 50) {
    self.targetChunkSize = Int(Double(targetTokens) * Self.charsPerToken)
    self.overlapSize = Int(Double(overlapTokens) * Self.charsPerToken)
    self.minimumChunkSize = Int(Double(overlapTokens) * Self.charsPerToken)
  }

  // Chunks the extracted content into smaller pieces for embedding.
  // Splits by paragraphs and groups them under the target size.
  // Returns an array of DocumentChunk ready for embedding.
  func chunkContent(_ content: ExtractedContent) throws -> [DocumentChunk] {
    // Handle empty content.
    guard !content.text.isEmpty else {
      throw ChunkingError.emptyInput
    }

    // If content is small enough, return as single chunk.
    if content.text.count <= targetChunkSize {
      let chunk = createChunk(
        text: content.text,
        index: 0,
        content: content
      )
      return [chunk]
    }

    // Split text into paragraphs.
    let paragraphs = splitIntoParagraphs(content.text)

    // Group paragraphs into chunks with overlap.
    let chunkTexts = groupParagraphsIntoChunks(paragraphs)

    // Create DocumentChunk objects.
    var chunks: [DocumentChunk] = []
    for (index, text) in chunkTexts.enumerated() {
      let chunk = createChunk(
        text: text,
        index: index,
        content: content
      )
      chunks.append(chunk)
    }

    return chunks
  }

  // MARK: - Private Methods

  // Splits text into paragraphs by newlines.
  // Preserves paragraph breaks for natural chunking boundaries.
  private func splitIntoParagraphs(_ text: String) -> [String] {
    // Split by double newlines (paragraph breaks).
    let paragraphs = text.components(separatedBy: "\n\n")

    // Filter out empty paragraphs and trim whitespace.
    return paragraphs
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  // Groups paragraphs into chunks respecting size limits.
  // Uses overlapping windows for context preservation.
  private func groupParagraphsIntoChunks(_ paragraphs: [String]) -> [String] {
    var chunks: [String] = []
    var currentChunk = ""
    var overlapBuffer = ""

    for paragraph in paragraphs {
      // Check if adding this paragraph would exceed limit.
      let combinedLength = currentChunk.isEmpty
        ? paragraph.count
        : currentChunk.count + 2 + paragraph.count  // +2 for "\n\n"

      if combinedLength <= targetChunkSize {
        // Add paragraph to current chunk.
        if currentChunk.isEmpty {
          currentChunk = paragraph
        } else {
          currentChunk += "\n\n" + paragraph
        }
      } else {
        // Current chunk is full, save it and start new one.
        if !currentChunk.isEmpty {
          chunks.append(currentChunk)

          // Build overlap from end of current chunk.
          overlapBuffer = buildOverlap(from: currentChunk)
        }

        // Start new chunk with overlap + new paragraph.
        if overlapBuffer.isEmpty {
          currentChunk = paragraph
        } else {
          currentChunk = overlapBuffer + "\n\n" + paragraph
        }

        // Handle case where single paragraph exceeds limit.
        if currentChunk.count > targetChunkSize {
          // Split the large paragraph into sentences.
          let sentenceChunks = splitLargeParagraph(paragraph, overlap: overlapBuffer)
          chunks.append(contentsOf: sentenceChunks.dropLast())
          currentChunk = sentenceChunks.last ?? ""
        }
      }
    }

    // Add final chunk if not empty.
    if !currentChunk.isEmpty {
      chunks.append(currentChunk)
    }

    return chunks
  }

  // Builds overlap text from the end of a chunk.
  // Takes approximately overlapSize characters from the end.
  private func buildOverlap(from text: String) -> String {
    guard text.count > overlapSize else {
      return text
    }

    // Find a good break point (sentence or word boundary).
    let startIndex = text.index(text.endIndex, offsetBy: -overlapSize)
    let overlapRange = startIndex..<text.endIndex
    var overlap = String(text[overlapRange])

    // Try to start at a sentence boundary.
    if let sentenceStart = findSentenceStart(in: overlap) {
      overlap = String(overlap[sentenceStart...])
    } else if let wordStart = findWordStart(in: overlap) {
      // Fall back to word boundary.
      overlap = String(overlap[wordStart...])
    }

    return overlap.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // Finds the start of a sentence within text.
  // Looks for ". " or ".\n" followed by content.
  private func findSentenceStart(in text: String) -> String.Index? {
    // Look for sentence ending markers.
    let markers = [". ", ".\n", "! ", "!\n", "? ", "?\n"]

    for marker in markers {
      if let range = text.range(of: marker) {
        let afterMarker = text.index(after: range.upperBound)
        if afterMarker < text.endIndex {
          return afterMarker
        }
      }
    }

    return nil
  }

  // Finds the start of a word within text.
  // Looks for space followed by non-space.
  private func findWordStart(in text: String) -> String.Index? {
    if let spaceIndex = text.firstIndex(of: " ") {
      let afterSpace = text.index(after: spaceIndex)
      if afterSpace < text.endIndex {
        return afterSpace
      }
    }
    return nil
  }

  // Splits a large paragraph that exceeds chunk size.
  // Breaks by sentences when possible.
  private func splitLargeParagraph(_ paragraph: String, overlap: String) -> [String] {
    var chunks: [String] = []
    var currentChunk = overlap.isEmpty ? "" : overlap

    // Split by sentences.
    let sentences = splitIntoSentences(paragraph)

    for sentence in sentences {
      let combinedLength = currentChunk.isEmpty
        ? sentence.count
        : currentChunk.count + 1 + sentence.count

      if combinedLength <= targetChunkSize {
        if currentChunk.isEmpty {
          currentChunk = sentence
        } else {
          currentChunk += " " + sentence
        }
      } else {
        // Save current chunk and start new one.
        if !currentChunk.isEmpty {
          chunks.append(currentChunk)
        }

        // If single sentence exceeds limit, split by words.
        if sentence.count > targetChunkSize {
          let wordChunks = splitByWords(sentence)
          chunks.append(contentsOf: wordChunks.dropLast())
          currentChunk = wordChunks.last ?? ""
        } else {
          currentChunk = sentence
        }
      }
    }

    if !currentChunk.isEmpty {
      chunks.append(currentChunk)
    }

    return chunks
  }

  // Splits text into sentences.
  // Uses common sentence-ending punctuation.
  private func splitIntoSentences(_ text: String) -> [String] {
    // Use regex to split by sentence boundaries.
    let pattern = "(?<=[.!?])\\s+"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return [text]
    }

    let range = NSRange(text.startIndex..., in: text)
    var sentences: [String] = []
    var lastEnd = text.startIndex

    regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
      guard let matchRange = match?.range, let swiftRange = Range(matchRange, in: text) else {
        return
      }
      let sentence = String(text[lastEnd..<swiftRange.lowerBound])
      if !sentence.isEmpty {
        sentences.append(sentence.trimmingCharacters(in: .whitespaces))
      }
      lastEnd = swiftRange.upperBound
    }

    // Add remaining text.
    let remaining = String(text[lastEnd...])
    if !remaining.isEmpty {
      sentences.append(remaining.trimmingCharacters(in: .whitespaces))
    }

    return sentences.filter { !$0.isEmpty }
  }

  // Splits text by words when sentence splitting is not enough.
  // Used for very long sentences or non-sentence text.
  private func splitByWords(_ text: String) -> [String] {
    let words = text.split(separator: " ")
    var chunks: [String] = []
    var currentChunk = ""

    for word in words {
      let wordStr = String(word)
      let combinedLength = currentChunk.isEmpty
        ? wordStr.count
        : currentChunk.count + 1 + wordStr.count

      if combinedLength <= targetChunkSize {
        if currentChunk.isEmpty {
          currentChunk = wordStr
        } else {
          currentChunk += " " + wordStr
        }
      } else {
        if !currentChunk.isEmpty {
          chunks.append(currentChunk)
        }
        currentChunk = wordStr
      }
    }

    if !currentChunk.isEmpty {
      chunks.append(currentChunk)
    }

    return chunks
  }

  // Creates a DocumentChunk from chunk text and metadata.
  private func createChunk(
    text: String,
    index: Int,
    content: ExtractedContent
  ) -> DocumentChunk {
    // Estimate token count.
    let tokenCount = Int(ceil(Double(text.count) / Self.charsPerToken))

    return DocumentChunk(
      id: UUID().uuidString,
      documentID: content.documentID,
      documentType: content.documentType,
      chunkIndex: index,
      text: text,
      tokenCount: tokenCount,
      displayName: content.displayName,
      modifiedAt: content.modifiedAt,
      pageNumber: content.pageNumber,
      blockTypes: content.blockTypes
    )
  }
}

// MARK: - Token Estimation

extension ChunkingService {

  // Estimates the token count for a given text.
  // Uses a simple heuristic of ~4 characters per token.
  nonisolated func estimateTokenCount(_ text: String) -> Int {
    return Int(ceil(Double(text.count) / Self.charsPerToken))
  }
}
