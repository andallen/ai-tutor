//
// Tests for PDF Dashboard Integration based on PDFDashboardContract.swift.
// Covers PDFDocumentMetadata, DashboardItem.pdfDocument, PDFDocumentMetadataBuilder,
// and PDFDashboardError. Tests validate interface usability, Equatable conformance,
// property access, and error handling.
//

import Foundation
import Testing

@testable import InkOS

// MARK: - PDFDocumentMetadata Tests

@Suite("PDFDocumentMetadata Tests")
struct PDFDocumentMetadataTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can create metadata with all required fields")
    func canCreateMetadata() {
      let id = UUID().uuidString
      let displayName = "Test Document"
      let sourceFileName = "test.pdf"
      let createdAt = Date()
      let modifiedAt = Date()
      let pageCount = 5
      let previewImageData: Data? = nil

      let metadata = PDFDocumentMetadata(
        id: id,
        displayName: displayName,
        sourceFileName: sourceFileName,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        pageCount: pageCount,
        previewImageData: previewImageData
      )

      #expect(metadata.id == id)
      #expect(metadata.displayName == displayName)
      #expect(metadata.sourceFileName == sourceFileName)
      #expect(metadata.createdAt == createdAt)
      #expect(metadata.modifiedAt == modifiedAt)
      #expect(metadata.pageCount == pageCount)
      #expect(metadata.previewImageData == nil)
    }

    @Test("can create metadata with preview image data")
    func canCreateMetadataWithPreview() {
      let previewData = Data([0x89, 0x50, 0x4E, 0x47])

      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "With Preview",
        sourceFileName: "preview.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 3,
        previewImageData: previewData
      )

      #expect(metadata.previewImageData == previewData)
    }
  }

  // MARK: - Identifiable Conformance Tests

  @Suite("Identifiable Conformance")
  struct IdentifiableTests {

    @Test("id property returns document ID string")
    func idReturnsDocumentIDString() {
      let documentID = UUID().uuidString

      let metadata = PDFDocumentMetadata(
        id: documentID,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 1,
        previewImageData: nil
      )

      #expect(metadata.id == documentID)
    }

    @Test("id is accessible for SwiftUI ForEach")
    func idIsAccessibleForForEach() {
      let metadata = PDFDocumentMetadata(
        id: "unique-id-123",
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 1,
        previewImageData: nil
      )

      // Confirms Identifiable conformance by accessing id.
      let idValue: String = metadata.id
      #expect(!idValue.isEmpty)
    }
  }

  // MARK: - Equatable Conformance Tests

  @Suite("Equatable Conformance")
  struct EquatableTests {

    @Test("identical metadata are equal")
    func identicalMetadataAreEqual() {
      let id = UUID().uuidString
      let displayName = "Test Document"
      let sourceFileName = "test.pdf"
      let createdAt = Date()
      let modifiedAt = Date()
      let pageCount = 5
      let previewData = Data([0x01, 0x02, 0x03])

      let metadata1 = PDFDocumentMetadata(
        id: id,
        displayName: displayName,
        sourceFileName: sourceFileName,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        pageCount: pageCount,
        previewImageData: previewData
      )

      let metadata2 = PDFDocumentMetadata(
        id: id,
        displayName: displayName,
        sourceFileName: sourceFileName,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        pageCount: pageCount,
        previewImageData: previewData
      )

      #expect(metadata1 == metadata2)
    }

    @Test("metadata with different id are not equal")
    func differentIdNotEqual() {
      let createdAt = Date()

      let metadata1 = PDFDocumentMetadata(
        id: "id-1",
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: nil
      )

      let metadata2 = PDFDocumentMetadata(
        id: "id-2",
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: nil
      )

      #expect(metadata1 != metadata2)
    }

    @Test("metadata with different displayName are not equal")
    func differentDisplayNameNotEqual() {
      let id = UUID().uuidString
      let createdAt = Date()

      let metadata1 = PDFDocumentMetadata(
        id: id,
        displayName: "Document A",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: nil
      )

      let metadata2 = PDFDocumentMetadata(
        id: id,
        displayName: "Document B",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: nil
      )

      #expect(metadata1 != metadata2)
    }

    @Test("metadata with different pageCount are not equal")
    func differentPageCountNotEqual() {
      let id = UUID().uuidString
      let createdAt = Date()

      let metadata1 = PDFDocumentMetadata(
        id: id,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: nil
      )

      let metadata2 = PDFDocumentMetadata(
        id: id,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 10,
        previewImageData: nil
      )

      #expect(metadata1 != metadata2)
    }

    @Test("metadata with different previewImageData are not equal")
    func differentPreviewImageDataNotEqual() {
      let id = UUID().uuidString
      let createdAt = Date()

      let metadata1 = PDFDocumentMetadata(
        id: id,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: Data([0x01])
      )

      let metadata2 = PDFDocumentMetadata(
        id: id,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: Data([0x02])
      )

      #expect(metadata1 != metadata2)
    }

    @Test("metadata with nil vs non-nil previewImageData are not equal")
    func nilVsNonNilPreviewNotEqual() {
      let id = UUID().uuidString
      let createdAt = Date()

      let metadata1 = PDFDocumentMetadata(
        id: id,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: nil
      )

      let metadata2 = PDFDocumentMetadata(
        id: id,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        pageCount: 5,
        previewImageData: Data([0x01])
      )

      #expect(metadata1 != metadata2)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("pageCount of zero is valid")
    func pageCountZeroIsValid() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Empty",
        sourceFileName: "empty.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 0,
        previewImageData: nil
      )

      #expect(metadata.pageCount == 0)
    }

    @Test("nil previewImageData is valid")
    func nilPreviewImageDataIsValid() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "No Preview",
        sourceFileName: "nopreview.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      #expect(metadata.previewImageData == nil)
    }

    @Test("very long displayName is preserved without truncation")
    func veryLongDisplayNamePreserved() {
      let longName = String(repeating: "a", count: 500)

      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: longName,
        sourceFileName: "long.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 1,
        previewImageData: nil
      )

      #expect(metadata.displayName == longName)
      #expect(metadata.displayName.count == 500)
    }

    @Test("special characters in displayName are preserved")
    func specialCharactersInDisplayNamePreserved() {
      let specialName = "Report (2024) [Final]"

      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: specialName,
        sourceFileName: "report.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 10,
        previewImageData: nil
      )

      #expect(metadata.displayName == specialName)
    }

    @Test("unicode characters in displayName are preserved")
    func unicodeCharactersInDisplayNamePreserved() {
      let unicodeName = "Bericht 2024"

      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: unicodeName,
        sourceFileName: "bericht.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      #expect(metadata.displayName == unicodeName)
    }

    @Test("empty displayName is valid")
    func emptyDisplayNameIsValid() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "",
        sourceFileName: "empty-name.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 1,
        previewImageData: nil
      )

      #expect(metadata.displayName.isEmpty)
    }

    @Test("large pageCount is valid")
    func largePageCountIsValid() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Large Document",
        sourceFileName: "large.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 1000,
        previewImageData: nil
      )

      #expect(metadata.pageCount == 1000)
    }
  }
}

// MARK: - DashboardItem.pdfDocument Tests

@Suite("DashboardItem PDF Document Tests")
struct DashboardItemPDFDocumentTests {

  // Helper to create a test PDFDocumentMetadata.
  private func createTestMetadata(
    id: String = UUID().uuidString,
    displayName: String = "Test Document",
    pageCount: Int = 5
  ) -> PDFDocumentMetadata {
    return PDFDocumentMetadata(
      id: id,
      displayName: displayName,
      sourceFileName: "test.pdf",
      createdAt: Date(),
      modifiedAt: Date(),
      pageCount: pageCount,
      previewImageData: nil
    )
  }

  // MARK: - ID Generation Tests

  @Suite("ID Generation")
  struct IDGenerationTests {

    @Test("id has pdf prefix")
    func idHasPdfPrefix() {
      let metadata = PDFDocumentMetadata(
        id: "abc123",
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.id.hasPrefix("pdf-"))
    }

    @Test("id contains metadata id after prefix")
    func idContainsMetadataId() {
      let metadataID = "abc123"
      let metadata = PDFDocumentMetadata(
        id: metadataID,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.id == "pdf-\(metadataID)")
    }

    @Test("id does not collide with notebook id")
    func idDoesNotCollideWithNotebook() {
      let sharedID = "abc123"

      // Create PDF document item.
      let pdfMetadata = PDFDocumentMetadata(
        id: sharedID,
        displayName: "PDF Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )
      let pdfItem = DashboardItem.pdfDocument(pdfMetadata)

      // Create notebook item with same base ID.
      let notebookMetadata = NotebookMetadata(
        id: sharedID,
        displayName: "Notebook Test",
        previewImageData: nil,
        lastAccessedAt: Date()
      )
      let notebookItem = DashboardItem.notebook(notebookMetadata)

      // IDs should be different due to prefixes.
      #expect(pdfItem.id != notebookItem.id)
      #expect(pdfItem.id == "pdf-\(sharedID)")
      #expect(notebookItem.id == "notebook-\(sharedID)")
    }

    @Test("id does not collide with folder id")
    func idDoesNotCollideWithFolder() {
      let sharedID = "abc123"

      // Create PDF document item.
      let pdfMetadata = PDFDocumentMetadata(
        id: sharedID,
        displayName: "PDF Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )
      let pdfItem = DashboardItem.pdfDocument(pdfMetadata)

      // Create folder item with same base ID.
      let folderMetadata = FolderMetadata(
        id: sharedID,
        displayName: "Folder Test",
        previewImages: [],
        notebookCount: 0,
        modifiedAt: Date()
      )
      let folderItem = DashboardItem.folder(folderMetadata)

      // IDs should be different due to prefixes.
      #expect(pdfItem.id != folderItem.id)
      #expect(pdfItem.id == "pdf-\(sharedID)")
      #expect(folderItem.id == "folder-\(sharedID)")
    }
  }

  // MARK: - Display Name Tests

  @Suite("Display Name")
  struct DisplayNameTests {

    @Test("displayName returns metadata displayName")
    func displayNameReturnsMetadataDisplayName() {
      let expectedName = "Q4 Report"
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: expectedName,
        sourceFileName: "report.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 10,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.displayName == expectedName)
    }

    @Test("displayName preserves special characters")
    func displayNamePreservesSpecialCharacters() {
      let specialName = "Report (2024) [Final]"
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: specialName,
        sourceFileName: "report.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.displayName == specialName)
    }
  }

  // MARK: - Sort Date Tests

  @Suite("Sort Date")
  struct SortDateTests {

    @Test("sortDate returns modifiedAt")
    func sortDateReturnsModifiedAt() {
      let modifiedAt = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(timeIntervalSince1970: 1672531200), // 2023-01-01
        modifiedAt: modifiedAt,
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.sortDate == modifiedAt)
    }

    @Test("sortDate is non-nil for pdfDocument")
    func sortDateIsNonNil() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.sortDate != nil)
    }
  }

  // MARK: - Type Check Tests

  @Suite("Type Checks")
  struct TypeCheckTests {

    @Test("isPDFDocument returns true for pdfDocument")
    func isPDFDocumentReturnsTrue() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.isPDFDocument == true)
    }

    @Test("isNotebook returns false for pdfDocument")
    func isNotebookReturnsFalse() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.isNotebook == false)
    }

    @Test("isFolder returns false for pdfDocument")
    func isFolderReturnsFalse() {
      let metadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(metadata)

      #expect(item.isFolder == false)
    }

    @Test("isPDFDocument returns false for notebook")
    func isPDFDocumentReturnsFalseForNotebook() {
      let notebookMetadata = NotebookMetadata(
        id: UUID().uuidString,
        displayName: "Test Notebook",
        previewImageData: nil,
        lastAccessedAt: Date()
      )

      let item = DashboardItem.notebook(notebookMetadata)

      #expect(item.isPDFDocument == false)
    }

    @Test("isPDFDocument returns false for folder")
    func isPDFDocumentReturnsFalseForFolder() {
      let folderMetadata = FolderMetadata(
        id: UUID().uuidString,
        displayName: "Test Folder",
        previewImages: [],
        notebookCount: 0,
        modifiedAt: Date()
      )

      let item = DashboardItem.folder(folderMetadata)

      #expect(item.isPDFDocument == false)
    }
  }

  // MARK: - Metadata Extraction Tests

  @Suite("Metadata Extraction")
  struct MetadataExtractionTests {

    @Test("pdfDocumentMetadata returns metadata for pdfDocument")
    func pdfDocumentMetadataReturnsMetadata() {
      let originalMetadata = PDFDocumentMetadata(
        id: "test-id",
        displayName: "Test Document",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: Data([0x01, 0x02])
      )

      let item = DashboardItem.pdfDocument(originalMetadata)

      let extractedMetadata = item.pdfDocumentMetadata
      #expect(extractedMetadata != nil)
      #expect(extractedMetadata?.id == originalMetadata.id)
      #expect(extractedMetadata?.displayName == originalMetadata.displayName)
      #expect(extractedMetadata?.sourceFileName == originalMetadata.sourceFileName)
      #expect(extractedMetadata?.pageCount == originalMetadata.pageCount)
      #expect(extractedMetadata?.previewImageData == originalMetadata.previewImageData)
    }

    @Test("pdfDocumentMetadata returns nil for notebook")
    func pdfDocumentMetadataReturnsNilForNotebook() {
      let notebookMetadata = NotebookMetadata(
        id: UUID().uuidString,
        displayName: "Test Notebook",
        previewImageData: nil,
        lastAccessedAt: Date()
      )

      let item = DashboardItem.notebook(notebookMetadata)

      #expect(item.pdfDocumentMetadata == nil)
    }

    @Test("pdfDocumentMetadata returns nil for folder")
    func pdfDocumentMetadataReturnsNilForFolder() {
      let folderMetadata = FolderMetadata(
        id: UUID().uuidString,
        displayName: "Test Folder",
        previewImages: [],
        notebookCount: 0,
        modifiedAt: Date()
      )

      let item = DashboardItem.folder(folderMetadata)

      #expect(item.pdfDocumentMetadata == nil)
    }

    @Test("notebookMetadata returns nil for pdfDocument")
    func notebookMetadataReturnsNilForPDFDocument() {
      let pdfMetadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Test PDF",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(pdfMetadata)

      #expect(item.notebookMetadata == nil)
    }

    @Test("folderMetadata returns nil for pdfDocument")
    func folderMetadataReturnsNilForPDFDocument() {
      let pdfMetadata = PDFDocumentMetadata(
        id: UUID().uuidString,
        displayName: "Test PDF",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        pageCount: 5,
        previewImageData: nil
      )

      let item = DashboardItem.pdfDocument(pdfMetadata)

      #expect(item.folderMetadata == nil)
    }
  }

  // MARK: - Sorting Tests

  @Suite("Sorting")
  struct SortingTests {

    @Test("PDF documents sort correctly by modifiedAt")
    func pdfDocumentsSortByModifiedAt() {
      let olderDate = Date(timeIntervalSince1970: 1672531200) // 2023-01-01
      let newerDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01

      let olderMetadata = PDFDocumentMetadata(
        id: "older",
        displayName: "Older Document",
        sourceFileName: "older.pdf",
        createdAt: olderDate,
        modifiedAt: olderDate,
        pageCount: 5,
        previewImageData: nil
      )

      let newerMetadata = PDFDocumentMetadata(
        id: "newer",
        displayName: "Newer Document",
        sourceFileName: "newer.pdf",
        createdAt: newerDate,
        modifiedAt: newerDate,
        pageCount: 5,
        previewImageData: nil
      )

      let olderItem = DashboardItem.pdfDocument(olderMetadata)
      let newerItem = DashboardItem.pdfDocument(newerMetadata)

      // Newer should sort before older (most recent first).
      let olderSortDate = olderItem.sortDate ?? Date.distantPast
      let newerSortDate = newerItem.sortDate ?? Date.distantPast

      #expect(newerSortDate > olderSortDate)
    }
  }
}

// MARK: - PDFDocumentMetadataBuilder Tests

@Suite("PDFDocumentMetadataBuilder Tests")
struct PDFDocumentMetadataBuilderTests {

  // MARK: - Page Count Calculation Tests

  @Suite("Page Count Calculation")
  struct PageCountCalculationTests {

    @Test("build with PDF pages only returns correct pageCount")
    func buildWithPDFPagesOnlyCorrectPageCount() {
      // Create a NoteDocument with 5 pdfPage blocks.
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2"),
        .pdfPage(pageIndex: 3, uuid: UUID(), myScriptPartID: "part-3"),
        .pdfPage(pageIndex: 4, uuid: UUID(), myScriptPartID: "part-4")
      ]

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Test Document",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: blocks
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.pageCount == 5)
    }

    @Test("build with mixed blocks excludes writing spacers from pageCount")
    func buildWithMixedBlocksExcludesSpacers() {
      // Create a NoteDocument with 3 pdfPage blocks and 2 writingSpacer blocks.
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .writingSpacer(height: 500, uuid: UUID(), myScriptPartID: "spacer-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .writingSpacer(height: 300, uuid: UUID(), myScriptPartID: "spacer-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Mixed Document",
        sourceFileName: "mixed.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: blocks
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.pageCount == 3)
    }

    @Test("build with empty blocks returns pageCount of zero")
    func buildWithEmptyBlocksReturnsZero() {
      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Empty Document",
        sourceFileName: "empty.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.pageCount == 0)
    }

    @Test("build with only writing spacers returns pageCount of zero")
    func buildWithOnlySpacersReturnsZero() {
      let blocks: [NoteBlock] = [
        .writingSpacer(height: 500, uuid: UUID(), myScriptPartID: "spacer-0"),
        .writingSpacer(height: 300, uuid: UUID(), myScriptPartID: "spacer-1")
      ]

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Spacers Only",
        sourceFileName: "spacers.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: blocks
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.pageCount == 0)
    }
  }

  // MARK: - Field Mapping Tests

  @Suite("Field Mapping")
  struct FieldMappingTests {

    @Test("build maps id from documentID.uuidString")
    func buildMapsId() {
      let documentID = UUID()

      let document = NoteDocument(
        documentID: documentID,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.id == documentID.uuidString)
    }

    @Test("build maps displayName from document")
    func buildMapsDisplayName() {
      let expectedName = "My PDF Document"

      let document = NoteDocument(
        documentID: UUID(),
        displayName: expectedName,
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.displayName == expectedName)
    }

    @Test("build maps sourceFileName from document")
    func buildMapsSourceFileName() {
      let expectedFileName = "original-file.pdf"

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: expectedFileName,
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.sourceFileName == expectedFileName)
    }

    @Test("build maps createdAt from document")
    func buildMapsCreatedAt() {
      let expectedDate = Date(timeIntervalSince1970: 1672531200) // 2023-01-01

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: expectedDate,
        modifiedAt: Date(),
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.createdAt == expectedDate)
    }

    @Test("build maps modifiedAt from document")
    func buildMapsModifiedAt() {
      let expectedDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: expectedDate,
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.modifiedAt == expectedDate)
    }

    @Test("build maps all fields correctly")
    func buildMapsAllFields() {
      let documentID = UUID()
      let displayName = "Complete Document"
      let sourceFileName = "complete.pdf"
      let createdAt = Date(timeIntervalSince1970: 1672531200)
      let modifiedAt = Date(timeIntervalSince1970: 1704067200)
      let previewData = Data([0x89, 0x50, 0x4E, 0x47])

      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
      ]

      let document = NoteDocument(
        documentID: documentID,
        displayName: displayName,
        sourceFileName: sourceFileName,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        blocks: blocks
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: previewData)

      #expect(metadata.id == documentID.uuidString)
      #expect(metadata.displayName == displayName)
      #expect(metadata.sourceFileName == sourceFileName)
      #expect(metadata.createdAt == createdAt)
      #expect(metadata.modifiedAt == modifiedAt)
      #expect(metadata.pageCount == 2)
      #expect(metadata.previewImageData == previewData)
    }
  }

  // MARK: - Preview Image Data Tests

  @Suite("Preview Image Data")
  struct PreviewImageDataTests {

    @Test("build includes preview image data when provided")
    func buildIncludesPreviewData() {
      let previewData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "With Preview",
        sourceFileName: "preview.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")]
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: previewData)

      #expect(metadata.previewImageData == previewData)
    }

    @Test("build sets nil previewImageData when not provided")
    func buildSetsNilPreviewData() {
      let document = NoteDocument(
        documentID: UUID(),
        displayName: "No Preview",
        sourceFileName: "nopreview.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: nil)

      #expect(metadata.previewImageData == nil)
    }

    @Test("build preserves large preview image data")
    func buildPreservesLargePreviewData() {
      // Create a 1MB preview data.
      let largePreviewData = Data(repeating: 0xFF, count: 1024 * 1024)

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Large Preview",
        sourceFileName: "large.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let metadata = PDFDocumentMetadataBuilder.build(from: document, previewImageData: largePreviewData)

      #expect(metadata.previewImageData?.count == largePreviewData.count)
    }
  }
}

// MARK: - PDFDashboardError Tests

@Suite("PDFDashboardError Tests")
struct PDFDashboardErrorTests {

  // MARK: - Error Description Tests

  @Suite("Error Descriptions")
  struct ErrorDescriptionTests {

    @Test("pdfNotesDirectoryNotAccessible provides error description")
    func pdfNotesDirectoryNotAccessibleDescription() {
      let underlyingError = "Permission denied"
      let error = PDFDashboardError.pdfNotesDirectoryNotAccessible(underlyingError: underlyingError)

      let description = error.errorDescription
      #expect(description != nil)
      #expect(description?.contains(underlyingError) == true)
    }

    @Test("manifestReadFailed provides error description with documentID")
    func manifestReadFailedDescription() {
      let documentID = "test-doc-123"
      let reason = "File not found"
      let error = PDFDashboardError.manifestReadFailed(documentID: documentID, reason: reason)

      let description = error.errorDescription
      #expect(description != nil)
      #expect(description?.contains(documentID) == true)
      #expect(description?.contains(reason) == true)
    }

    @Test("manifestDecodeFailed provides error description with documentID and reason")
    func manifestDecodeFailedDescription() {
      let documentID = "test-doc-456"
      let reason = "Invalid JSON"
      let error = PDFDashboardError.manifestDecodeFailed(documentID: documentID, reason: reason)

      let description = error.errorDescription
      #expect(description != nil)
      #expect(description?.contains(documentID) == true)
      #expect(description?.contains(reason) == true)
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("same pdfNotesDirectoryNotAccessible errors are equal")
    func samePdfNotesDirectoryNotAccessibleEqual() {
      let error1 = PDFDashboardError.pdfNotesDirectoryNotAccessible(underlyingError: "Error A")
      let error2 = PDFDashboardError.pdfNotesDirectoryNotAccessible(underlyingError: "Error A")

      #expect(error1 == error2)
    }

    @Test("pdfNotesDirectoryNotAccessible with different messages are not equal")
    func differentPdfNotesDirectoryNotAccessibleNotEqual() {
      let error1 = PDFDashboardError.pdfNotesDirectoryNotAccessible(underlyingError: "Error A")
      let error2 = PDFDashboardError.pdfNotesDirectoryNotAccessible(underlyingError: "Error B")

      #expect(error1 != error2)
    }

    @Test("same manifestReadFailed errors are equal")
    func sameManifestReadFailedEqual() {
      let error1 = PDFDashboardError.manifestReadFailed(documentID: "doc-1", reason: "Not found")
      let error2 = PDFDashboardError.manifestReadFailed(documentID: "doc-1", reason: "Not found")

      #expect(error1 == error2)
    }

    @Test("manifestReadFailed with different documentID are not equal")
    func differentDocumentIDManifestReadFailedNotEqual() {
      let error1 = PDFDashboardError.manifestReadFailed(documentID: "doc-1", reason: "Not found")
      let error2 = PDFDashboardError.manifestReadFailed(documentID: "doc-2", reason: "Not found")

      #expect(error1 != error2)
    }

    @Test("manifestReadFailed with different reason are not equal")
    func differentReasonManifestReadFailedNotEqual() {
      let error1 = PDFDashboardError.manifestReadFailed(documentID: "doc-1", reason: "Not found")
      let error2 = PDFDashboardError.manifestReadFailed(documentID: "doc-1", reason: "Access denied")

      #expect(error1 != error2)
    }

    @Test("same manifestDecodeFailed errors are equal")
    func sameManifestDecodeFailedEqual() {
      let error1 = PDFDashboardError.manifestDecodeFailed(documentID: "doc-1", reason: "Invalid JSON")
      let error2 = PDFDashboardError.manifestDecodeFailed(documentID: "doc-1", reason: "Invalid JSON")

      #expect(error1 == error2)
    }

    @Test("manifestDecodeFailed with different documentID are not equal")
    func differentDocumentIDManifestDecodeFailedNotEqual() {
      let error1 = PDFDashboardError.manifestDecodeFailed(documentID: "doc-1", reason: "Invalid JSON")
      let error2 = PDFDashboardError.manifestDecodeFailed(documentID: "doc-2", reason: "Invalid JSON")

      #expect(error1 != error2)
    }

    @Test("manifestDecodeFailed with different reason are not equal")
    func differentReasonManifestDecodeFailedNotEqual() {
      let error1 = PDFDashboardError.manifestDecodeFailed(documentID: "doc-1", reason: "Invalid JSON")
      let error2 = PDFDashboardError.manifestDecodeFailed(documentID: "doc-1", reason: "Missing field")

      #expect(error1 != error2)
    }

    @Test("different error cases are not equal")
    func differentErrorCasesNotEqual() {
      let error1 = PDFDashboardError.pdfNotesDirectoryNotAccessible(underlyingError: "Error")
      let error2 = PDFDashboardError.manifestReadFailed(documentID: "doc-1", reason: "Error")
      let error3 = PDFDashboardError.manifestDecodeFailed(documentID: "doc-1", reason: "Error")

      #expect(error1 != error2)
      #expect(error2 != error3)
      #expect(error1 != error3)
    }
  }

  // MARK: - LocalizedError Conformance Tests

  @Suite("LocalizedError Conformance")
  struct LocalizedErrorConformanceTests {

    @Test("all error cases conform to LocalizedError")
    func allErrorCasesConformToLocalizedError() {
      let errors: [PDFDashboardError] = [
        .pdfNotesDirectoryNotAccessible(underlyingError: "Test"),
        .manifestReadFailed(documentID: "doc-1", reason: "Test"),
        .manifestDecodeFailed(documentID: "doc-1", reason: "Test")
      ]

      for error in errors {
        // LocalizedError conformance means errorDescription is accessible.
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
      }
    }
  }
}
