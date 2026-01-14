// ExtractionModels.swift
// Data models for content extraction from JIIX and PDF documents.

import Foundation

// MARK: - Extracted Content Models

// Represents a single block of extracted content from a document.
// Blocks are sorted by spatial position before concatenation.
struct ExtractedTextBlock: Sendable, Equatable {
  // The recognized text content.
  let text: String

  // The type of content (text, math, drawing).
  let blockType: ContentBlockType

  // Vertical position for sorting (top-to-bottom ordering).
  let yPosition: Double

  // Horizontal position for tie-breaking (left-to-right ordering).
  let xPosition: Double
}

// Types of content blocks found in JIIX documents.
enum ContentBlockType: String, Sendable, Codable {
  case text = "Text"
  case math = "Math"
  case drawing = "Drawing"
  case shape = "Shape"
  case unknown = "Unknown"
}

// Result of extracting content from a single document.
// Contains the full text and metadata about the extraction.
struct ExtractedContent: Sendable, Equatable {
  // The concatenated text from all blocks, sorted by position.
  let text: String

  // Unique identifier for the source document.
  let documentID: String

  // Type of document that was extracted.
  let documentType: DocumentType

  // Display name of the source document.
  let displayName: String

  // Number of content blocks found.
  let blockCount: Int

  // Types of blocks present in the document.
  let blockTypes: Set<ContentBlockType>

  // Timestamp when the document was last modified.
  let modifiedAt: Date

  // Page number for PDF documents (nil for notebooks).
  let pageNumber: Int?

  // Creates an empty extraction result for documents with no content.
  static func empty(
    documentID: String,
    documentType: DocumentType,
    displayName: String,
    modifiedAt: Date
  ) -> ExtractedContent {
    return ExtractedContent(
      text: "",
      documentID: documentID,
      documentType: documentType,
      displayName: displayName,
      blockCount: 0,
      blockTypes: [],
      modifiedAt: modifiedAt,
      pageNumber: nil
    )
  }
}

// Types of documents that can be indexed.
enum DocumentType: String, Sendable, Codable {
  case notebook
  case pdf
  case lesson
  case folder
}

// MARK: - JIIX Parsing Models

// Represents the root structure of a JIIX document.
// Used for JSON decoding of MyScript JIIX exports.
struct JIIXDocument: Codable {
  let type: String?
  let version: String?
  let id: String?
  let boundingBox: JIIXBoundingBox?
  let elements: [JIIXElement]?

  private enum CodingKeys: String, CodingKey {
    case type
    case version
    case id
    case boundingBox = "bounding-box"
    case elements
  }
}

// Represents a content element in the JIIX document.
// Elements can be Text, Math, Drawing, or Shape blocks.
struct JIIXElement: Codable {
  let type: String?
  let id: String?
  let label: String?
  let boundingBox: JIIXBoundingBox?

  private enum CodingKeys: String, CodingKey {
    case type
    case id
    case label
    case boundingBox = "bounding-box"
  }
}

// Represents spatial bounds for positioning elements.
struct JIIXBoundingBox: Codable {
  let x: Double?
  let y: Double?
  let width: Double?
  let height: Double?
}

// MARK: - Document Chunk Models

// Represents a chunk of text ready for embedding.
// Chunks are created by splitting extracted content into smaller pieces.
struct DocumentChunk: Sendable, Equatable, Identifiable {
  // Unique identifier for this chunk.
  let id: String

  // The source document identifier.
  let documentID: String

  // Type of document (notebook or pdf).
  let documentType: DocumentType

  // Sequential index of this chunk within the document.
  let chunkIndex: Int

  // The text content of this chunk.
  let text: String

  // Approximate token count for this chunk.
  let tokenCount: Int

  // Display name of the source document.
  let displayName: String

  // Timestamp when the document was last modified.
  let modifiedAt: Date

  // Page number for PDF documents (nil for notebooks).
  let pageNumber: Int?

  // Types of content blocks present in this chunk.
  let blockTypes: Set<ContentBlockType>
}

// MARK: - Extraction Errors

// Errors that can occur during content extraction.
enum ExtractionError: LocalizedError, Equatable {
  case documentNotFound(documentID: String)
  case jiixParsingFailed(reason: String)
  case jiixFileNotFound(documentID: String)
  case pdfTextExtractionFailed(reason: String)
  case noContentExtracted(documentID: String)
  case invalidDocumentType

  var errorDescription: String? {
    switch self {
    case .documentNotFound(let documentID):
      return "Document not found: \(documentID)"
    case .jiixParsingFailed(let reason):
      return "Failed to parse JIIX content: \(reason)"
    case .jiixFileNotFound(let documentID):
      return "JIIX file not found for document: \(documentID)"
    case .pdfTextExtractionFailed(let reason):
      return "Failed to extract text from PDF: \(reason)"
    case .noContentExtracted(let documentID):
      return "No content could be extracted from document: \(documentID)"
    case .invalidDocumentType:
      return "Invalid document type for extraction"
    }
  }
}

// Errors that can occur during text chunking.
enum ChunkingError: LocalizedError, Equatable {
  case emptyInput
  case invalidChunkSize(requested: Int, minimum: Int)
  case invalidOverlap(overlap: Int, chunkSize: Int)

  var errorDescription: String? {
    switch self {
    case .emptyInput:
      return "Cannot chunk empty text"
    case .invalidChunkSize(let requested, let minimum):
      return "Invalid chunk size \(requested), minimum is \(minimum)"
    case .invalidOverlap(let overlap, let chunkSize):
      return "Overlap \(overlap) must be less than chunk size \(chunkSize)"
    }
  }
}
