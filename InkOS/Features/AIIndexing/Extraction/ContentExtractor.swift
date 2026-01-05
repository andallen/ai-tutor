// ContentExtractor.swift
// Extracts text content from JIIX and PDF documents for indexing.

import Foundation
import PDFKit

// Protocol for content extraction to support dependency injection.
protocol ContentExtractorProtocol: Actor {
  func extractFromJIIX(data: Data, documentID: String, displayName: String, modifiedAt: Date)
    throws -> ExtractedContent
  func extractFromPDF(url: URL, documentID: String, displayName: String, modifiedAt: Date)
    throws -> ExtractedContent
  func extractFromPDFWithAnnotations(
    pdfURL: URL,
    annotationsData: Data?,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent
}

// Actor responsible for extracting text content from documents.
// Parses JIIX JSON for handwritten note recognition results.
// Extracts text from PDF pages using PDFKit.
actor ContentExtractor: ContentExtractorProtocol {

  // JSON decoder configured for JIIX parsing.
  private let decoder: JSONDecoder

  // Initializes the content extractor with default configuration.
  init() {
    self.decoder = JSONDecoder()
  }

  // MARK: - JIIX Extraction

  // Extracts text content from JIIX data exported by MyScript.
  // Parses the JSON structure to find Text and Math labels.
  // Sorts blocks by spatial position (top-to-bottom, left-to-right).
  // Returns concatenated text suitable for embedding.
  func extractFromJIIX(
    data: Data,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent {
    // Parse the JIIX JSON structure.
    let jiixDocument: JIIXDocument
    do {
      jiixDocument = try decoder.decode(JIIXDocument.self, from: data)
    } catch {
      throw ExtractionError.jiixParsingFailed(reason: error.localizedDescription)
    }

    // Extract text blocks from elements.
    var textBlocks: [ExtractedTextBlock] = []
    var blockTypes: Set<ContentBlockType> = []

    guard let elements = jiixDocument.elements else {
      return ExtractedContent.empty(
        documentID: documentID,
        documentType: .notebook,
        displayName: displayName,
        modifiedAt: modifiedAt
      )
    }

    for element in elements {
      guard let typeString = element.type else { continue }
      let blockType = ContentBlockType(rawValue: typeString) ?? .unknown

      // Skip Drawing and Shape blocks - they don't have semantic text.
      guard blockType == .text || blockType == .math else { continue }

      // Get the label (recognized text).
      guard let label = element.label, !label.isEmpty else { continue }

      // Format math content with prefix for clarity.
      let text: String
      if blockType == .math {
        text = "Math: \(label)"
      } else {
        text = label
      }

      // Get spatial position for sorting.
      let yPosition = element.boundingBox?.y ?? 0.0
      let xPosition = element.boundingBox?.x ?? 0.0

      textBlocks.append(ExtractedTextBlock(
        text: text,
        blockType: blockType,
        yPosition: yPosition,
        xPosition: xPosition
      ))
      blockTypes.insert(blockType)
    }

    // Return empty content if no text blocks found.
    guard !textBlocks.isEmpty else {
      return ExtractedContent.empty(
        documentID: documentID,
        documentType: .notebook,
        displayName: displayName,
        modifiedAt: modifiedAt
      )
    }

    // Sort blocks by vertical position, then horizontal position.
    textBlocks.sort { lhs, rhs in
      if abs(lhs.yPosition - rhs.yPosition) < 10.0 {
        // Same row - sort by horizontal position.
        return lhs.xPosition < rhs.xPosition
      }
      return lhs.yPosition < rhs.yPosition
    }

    // Concatenate text from sorted blocks.
    let fullText = textBlocks.map { $0.text }.joined(separator: "\n")

    return ExtractedContent(
      text: fullText,
      documentID: documentID,
      documentType: .notebook,
      displayName: displayName,
      blockCount: textBlocks.count,
      blockTypes: blockTypes,
      modifiedAt: modifiedAt,
      pageNumber: nil
    )
  }

  // MARK: - PDF Extraction

  // Extracts text content from a PDF file.
  // Uses PDFKit to read text from each page.
  // Concatenates page text with page number headers.
  func extractFromPDF(
    url: URL,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent {
    guard let pdfDocument = PDFDocument(url: url) else {
      throw ExtractionError.pdfTextExtractionFailed(reason: "Could not open PDF file")
    }

    let pageCount = pdfDocument.pageCount
    guard pageCount > 0 else {
      return ExtractedContent.empty(
        documentID: documentID,
        documentType: .pdf,
        displayName: displayName,
        modifiedAt: modifiedAt
      )
    }

    var pageTexts: [String] = []

    for pageIndex in 0..<pageCount {
      guard let page = pdfDocument.page(at: pageIndex) else { continue }
      guard let pageText = page.string, !pageText.isEmpty else { continue }

      // Add page header for context.
      let pageHeader = "--- Page \(pageIndex + 1) ---"
      pageTexts.append("\(pageHeader)\n\(pageText)")
    }

    guard !pageTexts.isEmpty else {
      return ExtractedContent.empty(
        documentID: documentID,
        documentType: .pdf,
        displayName: displayName,
        modifiedAt: modifiedAt
      )
    }

    let fullText = pageTexts.joined(separator: "\n\n")

    return ExtractedContent(
      text: fullText,
      documentID: documentID,
      documentType: .pdf,
      displayName: displayName,
      blockCount: pageCount,
      blockTypes: [.text],
      modifiedAt: modifiedAt,
      pageNumber: nil
    )
  }

  // MARK: - Combined Extraction

  // Extracts content from a PDF document including its annotations.
  // Combines original PDF text with JIIX annotations for each page.
  // annotationsData: Optional JIIX data for annotations.
  // Returns combined content from PDF and annotations.
  func extractFromPDFWithAnnotations(
    pdfURL: URL,
    annotationsData: Data?,
    documentID: String,
    displayName: String,
    modifiedAt: Date
  ) throws -> ExtractedContent {
    // Extract PDF text.
    let pdfContent = try extractFromPDF(
      url: pdfURL,
      documentID: documentID,
      displayName: displayName,
      modifiedAt: modifiedAt
    )

    // If no annotations, return PDF content only.
    guard let annotationsData = annotationsData, !annotationsData.isEmpty else {
      return pdfContent
    }

    // Extract annotation text.
    let annotationContent = try extractFromJIIX(
      data: annotationsData,
      documentID: documentID,
      displayName: displayName,
      modifiedAt: modifiedAt
    )

    // If no annotation text, return PDF content only.
    guard !annotationContent.text.isEmpty else {
      return pdfContent
    }

    // Combine PDF text and annotations.
    let combinedText: String
    if pdfContent.text.isEmpty {
      combinedText = "--- Annotations ---\n\(annotationContent.text)"
    } else {
      combinedText = "\(pdfContent.text)\n\n--- Annotations ---\n\(annotationContent.text)"
    }

    // Merge block types.
    var combinedBlockTypes = pdfContent.blockTypes
    combinedBlockTypes.formUnion(annotationContent.blockTypes)

    return ExtractedContent(
      text: combinedText,
      documentID: documentID,
      documentType: .pdf,
      displayName: displayName,
      blockCount: pdfContent.blockCount + annotationContent.blockCount,
      blockTypes: combinedBlockTypes,
      modifiedAt: modifiedAt,
      pageNumber: nil
    )
  }
}

// MARK: - Notebook Extraction Helper

extension ContentExtractor {

  // Extracts content from a notebook using its document handle.
  // Loads JIIX data from the document handle and parses it.
  // handle: The document handle for the opened notebook.
  // manifest: The notebook manifest containing metadata.
  func extractFromNotebook(
    handle: DocumentHandle,
    manifest: Manifest
  ) async throws -> ExtractedContent {
    // Load JIIX data from the document handle.
    guard let jiixData = try await handle.loadJIIXData() else {
      throw ExtractionError.jiixFileNotFound(documentID: manifest.notebookID)
    }

    // Extract content from JIIX.
    return try extractFromJIIX(
      data: jiixData,
      documentID: manifest.notebookID,
      displayName: manifest.displayName,
      modifiedAt: manifest.modifiedAt
    )
  }
}
