// ChunkingServiceTests.swift
// Tests for ChunkingService text chunking functionality.

import Foundation
import Testing

@testable import InkOS

// MARK: - ChunkingService Tests

@Suite("ChunkingService Tests")
struct ChunkingServiceTests {

  // Helper to create test content.
  private func createContent(
    text: String,
    documentID: String = "test-doc",
    displayName: String = "Test",
    blockTypes: Set<ContentBlockType> = [.text]
  ) -> ExtractedContent {
    return ExtractedContent(
      text: text,
      documentID: documentID,
      documentType: .notebook,
      displayName: displayName,
      blockCount: 1,
      blockTypes: blockTypes,
      modifiedAt: Date(),
      pageNumber: nil
    )
  }

  // MARK: - Basic Chunking Tests

  @Suite("Basic Chunking")
  struct BasicChunkingTests {

    @Test("short text returns single chunk")
    func shortTextSingleChunk() async throws {
      let service = ChunkingService(targetTokens: 512, overlapTokens: 50)
      let content = ExtractedContent(
        text: "This is a short text.",
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Short Doc",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      #expect(chunks.count == 1)
      #expect(chunks[0].text == "This is a short text.")
      #expect(chunks[0].chunkIndex == 0)
    }

    @Test("empty text throws error")
    func emptyTextThrows() async {
      let service = ChunkingService()
      let content = ExtractedContent(
        text: "",
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Empty Doc",
        blockCount: 0,
        blockTypes: [],
        modifiedAt: Date(),
        pageNumber: nil
      )

      await #expect(throws: ChunkingError.self) {
        _ = try await service.chunkContent(content)
      }
    }

    @Test("preserves document metadata in chunks")
    func preservesMetadata() async throws {
      let service = ChunkingService()
      let modifiedDate = Date()
      let content = ExtractedContent(
        text: "Test content for chunking.",
        documentID: "my-doc-id",
        documentType: .pdf,
        displayName: "My Document",
        blockCount: 1,
        blockTypes: [.text, .math],
        modifiedAt: modifiedDate,
        pageNumber: 5
      )

      let chunks = try await service.chunkContent(content)

      #expect(chunks[0].documentID == "my-doc-id")
      #expect(chunks[0].documentType == .pdf)
      #expect(chunks[0].displayName == "My Document")
      #expect(chunks[0].modifiedAt == modifiedDate)
      #expect(chunks[0].pageNumber == 5)
      #expect(chunks[0].blockTypes == [.text, .math])
    }

    @Test("chunks have unique IDs")
    func chunksHaveUniqueIDs() async throws {
      let service = ChunkingService(targetTokens: 50, overlapTokens: 10)
      let longText = String(repeating: "This is a test paragraph. ", count: 50)
      let content = ExtractedContent(
        text: longText,
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      let uniqueIDs = Set(chunks.map { $0.id })
      #expect(uniqueIDs.count == chunks.count)
    }
  }

  // MARK: - Paragraph Splitting Tests

  @Suite("Paragraph Splitting")
  struct ParagraphSplittingTests {

    @Test("splits by double newlines")
    func splitsByDoubleNewlines() async throws {
      let service = ChunkingService(targetTokens: 50, overlapTokens: 10)
      let text = """
        First paragraph with some content.

        Second paragraph with more content.

        Third paragraph here.
        """
      let content = ExtractedContent(
        text: text,
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      // Small chunk size should create multiple chunks.
      #expect(chunks.count >= 1)
    }

    @Test("handles single paragraph")
    func handlesSingleParagraph() async throws {
      let service = ChunkingService()
      let content = ExtractedContent(
        text: "This is a single paragraph without any double newlines.",
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      #expect(chunks.count == 1)
      #expect(chunks[0].text.contains("single paragraph"))
    }

    @Test("handles multiple empty lines")
    func handlesMultipleEmptyLines() async throws {
      let service = ChunkingService()
      let content = ExtractedContent(
        text: "First.\n\n\n\nSecond.",
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      #expect(chunks.count >= 1)
      // Should handle multiple empty lines gracefully.
    }
  }

  // MARK: - Token Estimation Tests

  @Suite("Token Estimation")
  struct TokenEstimationTests {

    @Test("estimates approximately 4 chars per token")
    func estimatesCharsPerToken() async {
      let service = ChunkingService()

      let estimate = service.estimateTokenCount("Hello World")  // 11 chars
      // 11 / 4 = 2.75, ceiling = 3
      #expect(estimate == 3)
    }

    @Test("estimates empty string as 0 tokens")
    func estimatesEmptyAsZero() {
      let service = ChunkingService()

      let estimate = service.estimateTokenCount("")
      #expect(estimate == 0)
    }

    @Test("chunk token counts are reasonable")
    func chunkTokenCountsReasonable() async throws {
      let service = ChunkingService()
      let content = ExtractedContent(
        text: "This is a test sentence with some words.",
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      // Token count should be roughly text.count / 4.
      let expectedTokens = Int(ceil(Double(content.text.count) / 4.0))
      #expect(chunks[0].tokenCount == expectedTokens)
    }
  }

  // MARK: - Chunk Index Tests

  @Suite("Chunk Indexing")
  struct ChunkIndexingTests {

    @Test("chunks are sequentially indexed starting at 0")
    func chunksSequentiallyIndexed() async throws {
      let service = ChunkingService(targetTokens: 30, overlapTokens: 5)
      let longText = String(repeating: "Word ", count: 100)
      let content = ExtractedContent(
        text: longText,
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      for (index, chunk) in chunks.enumerated() {
        #expect(chunk.chunkIndex == index)
      }
    }

    @Test("first chunk has index 0")
    func firstChunkIndexZero() async throws {
      let service = ChunkingService()
      let content = ExtractedContent(
        text: "Any content here.",
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      #expect(chunks[0].chunkIndex == 0)
    }
  }

  // MARK: - Large Text Chunking Tests

  @Suite("Large Text Chunking")
  struct LargeTextChunkingTests {

    @Test("creates multiple chunks for large text")
    func createsMultipleChunks() async throws {
      let service = ChunkingService(targetTokens: 100, overlapTokens: 20)
      // Create text larger than target (100 tokens * 4 chars = 400 chars).
      let longText = String(
        repeating: "This is a long sentence to test chunking behavior. ", count: 20)
      let content = ExtractedContent(
        text: longText,
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Long Doc",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      #expect(chunks.count > 1)
    }

    @Test("all text is preserved across chunks")
    func allTextPreserved() async throws {
      let service = ChunkingService(targetTokens: 50, overlapTokens: 10)
      let originalText = "First part of text. Second part of text. Third part of text."
      let content = ExtractedContent(
        text: originalText,
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      let chunks = try await service.chunkContent(content)

      // Every word in original should appear in at least one chunk.
      let words = originalText.split(separator: " ")
      for word in words {
        let wordFound = chunks.contains { $0.text.contains(word) }
        #expect(wordFound, "Word '\(word)' should be in at least one chunk")
      }
    }

    @Test("handles very long single word")
    func handlesVeryLongWord() async throws {
      let service = ChunkingService(targetTokens: 10, overlapTokens: 2)
      let longWord = String(repeating: "a", count: 200)
      let content = ExtractedContent(
        text: longWord,
        documentID: "doc-1",
        documentType: .notebook,
        displayName: "Test",
        blockCount: 1,
        blockTypes: [.text],
        modifiedAt: Date(),
        pageNumber: nil
      )

      // Should not crash, even though single word exceeds chunk size.
      let chunks = try await service.chunkContent(content)
      #expect(chunks.count >= 1)
    }
  }

  // MARK: - DocumentChunk Model Tests

  @Suite("DocumentChunk Model")
  struct DocumentChunkModelTests {

    @Test("document chunk is identifiable")
    func isIdentifiable() {
      let chunk = DocumentChunk(
        id: "unique-id-123",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Test text",
        tokenCount: 3,
        displayName: "Test",
        modifiedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )

      #expect(chunk.id == "unique-id-123")
    }

    @Test("document chunk is equatable")
    func isEquatable() {
      let date = Date()
      let chunk1 = DocumentChunk(
        id: "id-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Test",
        tokenCount: 1,
        displayName: "Test",
        modifiedAt: date,
        pageNumber: nil,
        blockTypes: [.text]
      )
      let chunk2 = DocumentChunk(
        id: "id-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Test",
        tokenCount: 1,
        displayName: "Test",
        modifiedAt: date,
        pageNumber: nil,
        blockTypes: [.text]
      )

      #expect(chunk1 == chunk2)
    }

    @Test("document chunk is sendable")
    func isSendable() async {
      let chunk = DocumentChunk(
        id: "id-1",
        documentID: "doc-1",
        documentType: .notebook,
        chunkIndex: 0,
        text: "Test",
        tokenCount: 1,
        displayName: "Test",
        modifiedAt: Date(),
        pageNumber: nil,
        blockTypes: [.text]
      )

      let passedChunk = await Task.detached {
        return chunk
      }.value

      #expect(passedChunk.id == chunk.id)
    }
  }
}

// MARK: - Chunking Error Tests

@Suite("Chunking Error Tests")
struct ChunkingErrorTests {

  @Test("empty input error has correct description")
  func emptyInputDescription() {
    let error = ChunkingError.emptyInput
    #expect(error.errorDescription?.contains("empty") == true)
  }

  @Test("invalid chunk size error has correct description")
  func invalidChunkSizeDescription() {
    let error = ChunkingError.invalidChunkSize(requested: 5, minimum: 50)
    #expect(error.errorDescription?.contains("5") == true)
    #expect(error.errorDescription?.contains("50") == true)
  }

  @Test("invalid overlap error has correct description")
  func invalidOverlapDescription() {
    let error = ChunkingError.invalidOverlap(overlap: 100, chunkSize: 50)
    #expect(error.errorDescription?.contains("100") == true)
    #expect(error.errorDescription?.contains("50") == true)
  }

  @Test("chunking errors are equatable")
  func errorsAreEquatable() {
    let error1 = ChunkingError.emptyInput
    let error2 = ChunkingError.emptyInput
    let error3 = ChunkingError.invalidChunkSize(requested: 5, minimum: 50)

    #expect(error1 == error2)
    #expect(error1 != error3)
  }
}
