// ContentExtractorTests.swift
// Tests for ContentExtractor JIIX and PDF text extraction.

import Foundation
import Testing

@testable import InkOS

// MARK: - ContentExtractor Tests

@Suite("ContentExtractor Tests")
struct ContentExtractorTests {

  // MARK: - JIIX Extraction Tests

  @Suite("JIIX Extraction")
  struct JIIXExtractionTests {

    @Test("extracts text from simple JIIX document")
    func extractsTextFromSimpleJIIX() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "version": "3",
          "elements": [
            {
              "type": "Text",
              "label": "Hello World",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test Document",
        modifiedAt: Date()
      )

      #expect(result.text == "Hello World")
      #expect(result.blockCount == 1)
      #expect(result.blockTypes.contains(.text))
    }

    @Test("extracts multiple text blocks sorted by position")
    func extractsMultipleBlocksSorted() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Text",
              "label": "Second line",
              "bounding-box": {"x": 0, "y": 100, "width": 100, "height": 20}
            },
            {
              "type": "Text",
              "label": "First line",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text == "First line\nSecond line")
      #expect(result.blockCount == 2)
    }

    @Test("extracts math content with prefix")
    func extractsMathWithPrefix() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Math",
              "label": "x^2 + 3x + 2",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text == "Math: x^2 + 3x + 2")
      #expect(result.blockTypes.contains(.math))
    }

    @Test("skips drawing blocks")
    func skipsDrawingBlocks() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Text",
              "label": "Some text",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 20}
            },
            {
              "type": "Drawing",
              "id": "drawing-1",
              "bounding-box": {"x": 0, "y": 50, "width": 100, "height": 100}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text == "Some text")
      #expect(result.blockCount == 1)
      #expect(!result.blockTypes.contains(.drawing))
    }

    @Test("skips shape blocks")
    func skipsShapeBlocks() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Shape",
              "id": "shape-1",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 100}
            },
            {
              "type": "Text",
              "label": "Text after shape",
              "bounding-box": {"x": 0, "y": 150, "width": 100, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text == "Text after shape")
      #expect(result.blockCount == 1)
    }

    @Test("returns empty content for document with no elements")
    func emptyContentForNoElements() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "version": "3"
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text.isEmpty)
      #expect(result.blockCount == 0)
    }

    @Test("returns empty content for elements with empty labels")
    func emptyContentForEmptyLabels() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Text",
              "label": "",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text.isEmpty)
      #expect(result.blockCount == 0)
    }

    @Test("throws error for invalid JSON")
    func throwsErrorForInvalidJSON() async throws {
      let extractor = ContentExtractor()

      let invalidData = "not valid json".data(using: .utf8)!

      await #expect(throws: ExtractionError.self) {
        _ = try await extractor.extractFromJIIX(
          data: invalidData,
          documentID: "test-doc",
          displayName: "Test",
          modifiedAt: Date()
        )
      }
    }

    @Test("sorts blocks on same row by x position")
    func sortsSameRowByXPosition() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Text",
              "label": "Right",
              "bounding-box": {"x": 200, "y": 0, "width": 50, "height": 20}
            },
            {
              "type": "Text",
              "label": "Left",
              "bounding-box": {"x": 0, "y": 0, "width": 50, "height": 20}
            },
            {
              "type": "Text",
              "label": "Middle",
              "bounding-box": {"x": 100, "y": 0, "width": 50, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text == "Left\nMiddle\nRight")
    }

    @Test("extracts mixed text and math content")
    func extractsMixedContent() async throws {
      let extractor = ContentExtractor()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Text",
              "label": "The equation is",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 20}
            },
            {
              "type": "Math",
              "label": "E = mc^2",
              "bounding-box": {"x": 0, "y": 30, "width": 100, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "test-doc",
        displayName: "Test",
        modifiedAt: Date()
      )

      #expect(result.text == "The equation is\nMath: E = mc^2")
      #expect(result.blockTypes.contains(.text))
      #expect(result.blockTypes.contains(.math))
      #expect(result.blockCount == 2)
    }

    @Test("preserves document metadata in result")
    func preservesDocumentMetadata() async throws {
      let extractor = ContentExtractor()
      let modifiedDate = Date()

      let jiixJSON = """
        {
          "type": "Raw Content",
          "elements": [
            {
              "type": "Text",
              "label": "Test",
              "bounding-box": {"x": 0, "y": 0, "width": 100, "height": 20}
            }
          ]
        }
        """
      let data = jiixJSON.data(using: .utf8)!

      let result = try await extractor.extractFromJIIX(
        data: data,
        documentID: "doc-123",
        displayName: "My Document",
        modifiedAt: modifiedDate
      )

      #expect(result.documentID == "doc-123")
      #expect(result.displayName == "My Document")
      #expect(result.documentType == .notebook)
      #expect(result.modifiedAt == modifiedDate)
    }
  }

  // MARK: - Empty Content Tests

  @Suite("Empty Content")
  struct EmptyContentTests {

    @Test("empty extraction result has correct properties")
    func emptyExtractionResult() {
      let modifiedDate = Date()

      let result = ExtractedContent.empty(
        documentID: "empty-doc",
        documentType: .notebook,
        displayName: "Empty Notebook",
        modifiedAt: modifiedDate
      )

      #expect(result.text.isEmpty)
      #expect(result.documentID == "empty-doc")
      #expect(result.documentType == .notebook)
      #expect(result.displayName == "Empty Notebook")
      #expect(result.blockCount == 0)
      #expect(result.blockTypes.isEmpty)
      #expect(result.modifiedAt == modifiedDate)
      #expect(result.pageNumber == nil)
    }

    @Test("empty PDF extraction result")
    func emptyPDFExtractionResult() {
      let result = ExtractedContent.empty(
        documentID: "pdf-doc",
        documentType: .pdf,
        displayName: "Empty PDF",
        modifiedAt: Date()
      )

      #expect(result.documentType == .pdf)
    }
  }
}

// MARK: - JIIX Parsing Model Tests

@Suite("JIIX Parsing Model Tests")
struct JIIXParsingModelTests {

  @Test("can decode JIIX document")
  func canDecodeJIIXDocument() throws {
    let jiixJSON = """
      {
        "type": "Raw Content",
        "version": "3",
        "id": "MainBlock"
      }
      """
    let data = jiixJSON.data(using: .utf8)!

    let document = try JSONDecoder().decode(JIIXDocument.self, from: data)

    #expect(document.type == "Raw Content")
    #expect(document.version == "3")
    #expect(document.id == "MainBlock")
  }

  @Test("can decode JIIX element")
  func canDecodeJIIXElement() throws {
    let elementJSON = """
      {
        "type": "Text",
        "id": "elem-1",
        "label": "Hello",
        "bounding-box": {"x": 10.5, "y": 20.5, "width": 100.0, "height": 30.0}
      }
      """
    let data = elementJSON.data(using: .utf8)!

    let element = try JSONDecoder().decode(JIIXElement.self, from: data)

    #expect(element.type == "Text")
    #expect(element.id == "elem-1")
    #expect(element.label == "Hello")
    #expect(element.boundingBox?.x == 10.5)
    #expect(element.boundingBox?.y == 20.5)
    #expect(element.boundingBox?.width == 100.0)
    #expect(element.boundingBox?.height == 30.0)
  }

  @Test("handles missing optional fields")
  func handlesMissingOptionalFields() throws {
    let jiixJSON = """
      {
        "type": "Text"
      }
      """
    let data = jiixJSON.data(using: .utf8)!

    let element = try JSONDecoder().decode(JIIXElement.self, from: data)

    #expect(element.type == "Text")
    #expect(element.id == nil)
    #expect(element.label == nil)
    #expect(element.boundingBox == nil)
  }
}

// MARK: - ContentBlockType Tests

@Suite("ContentBlockType Tests")
struct ContentBlockTypeTests {

  @Test("text type has correct raw value")
  func textTypeRawValue() {
    #expect(ContentBlockType.text.rawValue == "Text")
  }

  @Test("math type has correct raw value")
  func mathTypeRawValue() {
    #expect(ContentBlockType.math.rawValue == "Math")
  }

  @Test("drawing type has correct raw value")
  func drawingTypeRawValue() {
    #expect(ContentBlockType.drawing.rawValue == "Drawing")
  }

  @Test("shape type has correct raw value")
  func shapeTypeRawValue() {
    #expect(ContentBlockType.shape.rawValue == "Shape")
  }

  @Test("unknown type has correct raw value")
  func unknownTypeRawValue() {
    #expect(ContentBlockType.unknown.rawValue == "Unknown")
  }

  @Test("can initialize from string")
  func canInitializeFromString() {
    #expect(ContentBlockType(rawValue: "Text") == .text)
    #expect(ContentBlockType(rawValue: "Math") == .math)
    #expect(ContentBlockType(rawValue: "Drawing") == .drawing)
    #expect(ContentBlockType(rawValue: "Shape") == .shape)
    #expect(ContentBlockType(rawValue: "Unknown") == .unknown)
  }

  @Test("returns nil for invalid string")
  func returnsNilForInvalidString() {
    #expect(ContentBlockType(rawValue: "InvalidType") == nil)
  }

  @Test("is codable")
  func isCodable() throws {
    let original = ContentBlockType.text
    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ContentBlockType.self, from: data)

    #expect(decoded == original)
  }
}

// MARK: - Extraction Error Tests

@Suite("Extraction Error Tests")
struct ExtractionErrorTests {

  @Test("documentNotFound error has correct description")
  func documentNotFoundDescription() {
    let error = ExtractionError.documentNotFound(documentID: "doc-123")
    #expect(error.errorDescription?.contains("doc-123") == true)
    #expect(error.errorDescription?.contains("not found") == true)
  }

  @Test("jiixParsingFailed error has correct description")
  func jiixParsingFailedDescription() {
    let error = ExtractionError.jiixParsingFailed(reason: "Invalid JSON")
    #expect(error.errorDescription?.contains("Invalid JSON") == true)
    #expect(error.errorDescription?.contains("parse") == true)
  }

  @Test("jiixFileNotFound error has correct description")
  func jiixFileNotFoundDescription() {
    let error = ExtractionError.jiixFileNotFound(documentID: "notebook-456")
    #expect(error.errorDescription?.contains("notebook-456") == true)
    #expect(error.errorDescription?.contains("JIIX") == true)
  }

  @Test("noContentExtracted error has correct description")
  func noContentExtractedDescription() {
    let error = ExtractionError.noContentExtracted(documentID: "empty-doc")
    #expect(error.errorDescription?.contains("empty-doc") == true)
    #expect(error.errorDescription?.contains("content") == true)
  }

  @Test("extraction errors are equatable")
  func errorsAreEquatable() {
    let error1 = ExtractionError.documentNotFound(documentID: "doc-1")
    let error2 = ExtractionError.documentNotFound(documentID: "doc-1")
    let error3 = ExtractionError.documentNotFound(documentID: "doc-2")

    #expect(error1 == error2)
    #expect(error1 != error3)
  }
}
