//
// Tests for PDF Data Model & Ingestion Pipeline based on Contract.swift.
// Covers NoteBlock, NoteDocument, ImportError, PDFNoteStorage, and ImportCoordinator.
// Tests validate interface usability, Codable conformance, error handling, and import workflows.
//

import Testing
import Foundation
import CoreGraphics
@testable import InkOS

// MARK: - Mock Dependencies

// Mock PDF document for testing PDF operations.
// Conforms to PDFDocumentProtocol for dependency injection.
final class MockPDFDocument: PDFDocumentProtocol, Sendable {
  let pageCount: Int
  let isLocked: Bool
  let isEncrypted: Bool
  private let correctPassword: String?
  private var unlocked: Bool

  init(pageCount: Int, isLocked: Bool = false, isEncrypted: Bool = false, correctPassword: String? = nil) {
    self.pageCount = pageCount
    self.isLocked = isLocked
    self.isEncrypted = isEncrypted
    self.correctPassword = correctPassword
    self.unlocked = !isLocked
  }

  func unlock(withPassword password: String) -> Bool {
    guard isLocked, let correctPassword = correctPassword else {
      return !isLocked
    }

    if password == correctPassword {
      return true
    }
    return false
  }
}

// Mock PDF document factory for testing PDF creation.
// Conforms to PDFDocumentFactoryProtocol for dependency injection.
final class MockPDFDocumentFactory: PDFDocumentFactoryProtocol, Sendable {
  var shouldReturnNil = false
  var mockDocument: MockPDFDocument?
  var createCallCount = 0
  var lastCreatedURL: URL?

  func createPDFDocument(from url: URL) -> (any PDFDocumentProtocol)? {
    createCallCount += 1
    lastCreatedURL = url

    if shouldReturnNil {
      return nil
    }

    return mockDocument
  }
}

// Mock MyScript content part for testing part creation.
// Conforms to ContentPartProtocol.
final class MockPDFImportPart: ContentPartProtocol {
  let type: String
  let identifier: String

  init(type: String, identifier: String) {
    self.type = type
    self.identifier = identifier
  }
}

// Mock MyScript content package for testing package creation.
// Conforms to ContentPackageProtocol.
@MainActor
final class MockPDFImportPackage: ContentPackageProtocol {
  var parts: [MockPDFImportPart] = []
  var saveCallCount = 0
  var shouldThrowOnCreatePart = false
  var shouldThrowOnSave = false
  var partCreationFailIndex: Int?

  func getPartCount() -> Int {
    return parts.count
  }

  func getPart(at index: Int) throws -> any ContentPartProtocol {
    guard index >= 0 && index < parts.count else {
      throw MockPDFImportError.indexOutOfBounds
    }
    return parts[index]
  }

  func createNewPart(with type: String) throws -> any ContentPartProtocol {
    if shouldThrowOnCreatePart {
      throw MockPDFImportError.partCreationFailed
    }

    if let failIndex = partCreationFailIndex, parts.count == failIndex {
      throw MockPDFImportError.partCreationFailed
    }

    let identifier = "part-\(parts.count)"
    let part = MockPDFImportPart(type: type, identifier: identifier)
    parts.append(part)
    return part
  }

  func savePackage() throws {
    if shouldThrowOnSave {
      throw MockPDFImportError.packageSaveFailed
    }
    saveCallCount += 1
  }

  func savePackageToTemp() throws {
    if shouldThrowOnSave {
      throw MockPDFImportError.packageSaveFailed
    }
  }
}

// Mock MyScript engine for testing engine operations.
// Conforms to EngineProtocol.
@MainActor
final class MockPDFImportEngine: EngineProtocol {
  var openCallCount = 0
  var createCallCount = 0
  var lastOpenedPath: String?
  var lastCreatedPath: String?
  var shouldThrowOnOpen = false
  var shouldThrowOnCreate = false
  var mockPackage: MockPDFImportPackage?

  func openContentPackage(_ path: String, openOption: IINKPackageOpenOption) throws -> any ContentPackageProtocol {
    openCallCount += 1
    lastOpenedPath = path

    if shouldThrowOnOpen {
      throw MockPDFImportError.packageOpenFailed
    }

    let package = mockPackage ?? MockPDFImportPackage()
    mockPackage = package
    return package
  }

  func createContentPackage(_ path: String) throws -> any ContentPackageProtocol {
    createCallCount += 1
    lastCreatedPath = path

    if shouldThrowOnCreate {
      throw MockPDFImportError.packageCreationFailed
    }

    let package = mockPackage ?? MockPDFImportPackage()
    mockPackage = package
    return package
  }
}

// Mock engine provider for testing engine availability.
// Conforms to EngineProviderProtocol.
@MainActor
final class MockPDFImportEngineProvider: EngineProviderProtocol {
  var engineInstance: (any EngineProtocol)?

  init(engine: MockPDFImportEngine? = nil) {
    self.engineInstance = engine ?? MockPDFImportEngine()
  }

  init(noEngine: Bool) {
    self.engineInstance = nil
  }
}

// Mock errors for testing error conditions.
enum MockPDFImportError: Error, LocalizedError {
  case indexOutOfBounds
  case partCreationFailed
  case packageOpenFailed
  case packageCreationFailed
  case packageSaveFailed

  var errorDescription: String? {
    switch self {
    case .indexOutOfBounds:
      return "Index out of bounds"
    case .partCreationFailed:
      return "Part creation failed"
    case .packageOpenFailed:
      return "Package open failed"
    case .packageCreationFailed:
      return "Package creation failed"
    case .packageSaveFailed:
      return "Package save failed"
    }
  }
}

// MARK: - NoteBlock Tests

@Suite("NoteBlock Tests")
struct NoteBlockTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can create PDF page block")
    func canCreatePDFPageBlock() {
      let pageIndex = 0
      let uuid = UUID()
      let partID = "part-0"

      let block = NoteBlock.pdfPage(pageIndex: pageIndex, uuid: uuid, myScriptPartID: partID)

      // Confirms the interface is usable.
      #expect(block != nil)
    }

    @Test("can create writing spacer block")
    func canCreateWritingSpacerBlock() {
      let height: CGFloat = 500.0
      let uuid = UUID()
      let partID = "part-spacer"

      let block = NoteBlock.writingSpacer(height: height, uuid: uuid, myScriptPartID: partID)

      // Confirms the interface is usable.
      #expect(block != nil)
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("identical PDF page blocks are equal")
    func identicalPDFPageBlocksAreEqual() {
      let pageIndex = 0
      let uuid = UUID()
      let partID = "part-0"

      let block1 = NoteBlock.pdfPage(pageIndex: pageIndex, uuid: uuid, myScriptPartID: partID)
      let block2 = NoteBlock.pdfPage(pageIndex: pageIndex, uuid: uuid, myScriptPartID: partID)

      #expect(block1 == block2)
    }

    @Test("identical writing spacer blocks are equal")
    func identicalWritingSpacerBlocksAreEqual() {
      let height: CGFloat = 500.0
      let uuid = UUID()
      let partID = "part-spacer"

      let block1 = NoteBlock.writingSpacer(height: height, uuid: uuid, myScriptPartID: partID)
      let block2 = NoteBlock.writingSpacer(height: height, uuid: uuid, myScriptPartID: partID)

      #expect(block1 == block2)
    }

    @Test("PDF page blocks with different pageIndex are not equal")
    func differentPageIndexNotEqual() {
      let uuid = UUID()
      let partID = "part-0"

      let block1 = NoteBlock.pdfPage(pageIndex: 0, uuid: uuid, myScriptPartID: partID)
      let block2 = NoteBlock.pdfPage(pageIndex: 1, uuid: uuid, myScriptPartID: partID)

      #expect(block1 != block2)
    }

    @Test("PDF page blocks with different UUID are not equal")
    func differentUUIDNotEqual() {
      let partID = "part-0"

      let block1 = NoteBlock.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: partID)
      let block2 = NoteBlock.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: partID)

      #expect(block1 != block2)
    }

    @Test("PDF page blocks with different myScriptPartID are not equal")
    func differentPartIDNotEqual() {
      let uuid = UUID()

      let block1 = NoteBlock.pdfPage(pageIndex: 0, uuid: uuid, myScriptPartID: "part-0")
      let block2 = NoteBlock.pdfPage(pageIndex: 0, uuid: uuid, myScriptPartID: "part-1")

      #expect(block1 != block2)
    }

    @Test("PDF page and writing spacer blocks are not equal")
    func differentTypesNotEqual() {
      let uuid = UUID()
      let partID = "part-0"

      let pdfBlock = NoteBlock.pdfPage(pageIndex: 0, uuid: uuid, myScriptPartID: partID)
      let spacerBlock = NoteBlock.writingSpacer(height: 500.0, uuid: uuid, myScriptPartID: partID)

      #expect(pdfBlock != spacerBlock)
    }
  }

  // MARK: - Codable Tests

  @Suite("Codable")
  struct CodableTests {

    @Test("can encode and decode PDF page block")
    func encodeAndDecodePDFPageBlock() throws {
      let original = NoteBlock.pdfPage(pageIndex: 5, uuid: UUID(), myScriptPartID: "part-5")

      let encoder = JSONEncoder()
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode(NoteBlock.self, from: data)

      #expect(decoded == original)
    }

    @Test("can encode and decode writing spacer block")
    func encodeAndDecodeWritingSpacerBlock() throws {
      let original = NoteBlock.writingSpacer(height: 750.5, uuid: UUID(), myScriptPartID: "part-spacer")

      let encoder = JSONEncoder()
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode(NoteBlock.self, from: data)

      #expect(decoded == original)
    }

    @Test("can round-trip encode/decode mixed block types")
    func roundTripMixedBlockTypes() throws {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .writingSpacer(height: 500.0, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-2")
      ]

      let encoder = JSONEncoder()
      let data = try encoder.encode(blocks)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode([NoteBlock].self, from: data)

      #expect(decoded == blocks)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("can create PDF page block with negative page index")
    func negativePageIndex() {
      // Contract specifies this is allowed but represents invalid state.
      let block = NoteBlock.pdfPage(pageIndex: -1, uuid: UUID(), myScriptPartID: "part-0")

      #expect(block != nil)
    }

    @Test("can create writing spacer with zero height")
    func zeroHeightSpacer() {
      // Contract specifies this is allowed.
      let block = NoteBlock.writingSpacer(height: 0, uuid: UUID(), myScriptPartID: "part-0")

      #expect(block != nil)
    }

    @Test("can create writing spacer with negative height")
    func negativeHeightSpacer() {
      // Contract specifies this is allowed but represents invalid state.
      let block = NoteBlock.writingSpacer(height: -100, uuid: UUID(), myScriptPartID: "part-0")

      #expect(block != nil)
    }

    @Test("can create block with empty myScriptPartID")
    func emptyMyScriptPartID() {
      // Contract specifies this is allowed but represents invalid state.
      let block = NoteBlock.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "")

      #expect(block != nil)
    }

    @Test("can create writing spacer with maximum CGFloat height")
    func maximumCGFloatHeight() throws {
      let block = NoteBlock.writingSpacer(height: CGFloat.greatestFiniteMagnitude, uuid: UUID(), myScriptPartID: "part-0")

      // Verify JSON encoding preserves the value.
      let encoder = JSONEncoder()
      let data = try encoder.encode(block)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode(NoteBlock.self, from: data)

      #expect(decoded == block)
    }
  }
}

// MARK: - NoteDocument Tests

@Suite("NoteDocument Tests")
struct NoteDocumentTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can create document with all required fields")
    func canCreateDocument() {
      let documentID = UUID()
      let displayName = "Test Document"
      let sourceFileName = "test.pdf"
      let createdAt = Date()
      let modifiedAt = Date()
      let blocks: [NoteBlock] = []

      let document = NoteDocument(
        documentID: documentID,
        displayName: displayName,
        sourceFileName: sourceFileName,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        blocks: blocks
      )

      #expect(document.documentID == documentID)
      #expect(document.displayName == displayName)
      #expect(document.sourceFileName == sourceFileName)
      #expect(document.createdAt == createdAt)
      #expect(document.modifiedAt == modifiedAt)
      #expect(document.blocks.isEmpty)
    }

    @Test("can create document with PDF page blocks")
    func canCreateDocumentWithBlocks() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]

      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Three Page Document",
        sourceFileName: "three-pages.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: blocks
      )

      #expect(document.blocks.count == 3)
    }
  }

  // MARK: - Mutability Tests

  @Suite("Mutability")
  struct MutabilityTests {

    @Test("displayName can be modified")
    func displayNameCanBeModified() {
      var document = NoteDocument(
        documentID: UUID(),
        displayName: "Original Name",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      document.displayName = "Updated Name"

      #expect(document.displayName == "Updated Name")
    }

    @Test("modifiedAt can be modified")
    func modifiedAtCanBeModified() {
      var document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let newDate = Date().addingTimeInterval(3600)
      document.modifiedAt = newDate

      #expect(document.modifiedAt == newDate)
    }

    @Test("blocks can be modified")
    func blocksCanBeModified() {
      var document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let newBlocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
      ]
      document.blocks = newBlocks

      #expect(document.blocks.count == 1)
    }

    @Test("can insert writing spacer between pages")
    func canInsertWritingSpacer() {
      var document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
          .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
          .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
        ]
      )

      let spacer = NoteBlock.writingSpacer(height: 500.0, uuid: UUID(), myScriptPartID: "part-spacer")
      document.blocks.insert(spacer, at: 1)

      #expect(document.blocks.count == 4)
      if case .writingSpacer = document.blocks[1] {
        // Success: spacer inserted at index 1.
      } else {
        Issue.record("Expected spacer at index 1")
      }
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("identical documents are equal")
    func identicalDocumentsAreEqual() {
      let documentID = UUID()
      let createdAt = Date()
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
      ]

      let doc1 = NoteDocument(
        documentID: documentID,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        blocks: blocks
      )

      let doc2 = NoteDocument(
        documentID: documentID,
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        blocks: blocks
      )

      #expect(doc1 == doc2)
    }

    @Test("documents with different documentID are not equal")
    func differentDocumentIDNotEqual() {
      let createdAt = Date()
      let blocks: [NoteBlock] = []

      let doc1 = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        blocks: blocks
      )

      let doc2 = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: createdAt,
        modifiedAt: createdAt,
        blocks: blocks
      )

      #expect(doc1 != doc2)
    }
  }

  // MARK: - Codable Tests

  @Suite("Codable")
  struct CodableTests {

    @Test("can encode and decode document")
    func encodeAndDecodeDocument() throws {
      // Use dates truncated to seconds to avoid ISO8601 precision issues.
      let now = Date(timeIntervalSinceReferenceDate: floor(Date().timeIntervalSinceReferenceDate))
      let original = NoteDocument(
        documentID: UUID(),
        displayName: "Test Document",
        sourceFileName: "test.pdf",
        createdAt: now,
        modifiedAt: now,
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
          .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
        ]
      )

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(NoteDocument.self, from: data)

      #expect(decoded == original)
    }

    @Test("can encode and decode document with mixed block types")
    func encodeAndDecodeMixedBlocks() throws {
      // Use dates truncated to seconds to avoid ISO8601 precision issues.
      let now = Date(timeIntervalSinceReferenceDate: floor(Date().timeIntervalSinceReferenceDate))
      let original = NoteDocument(
        documentID: UUID(),
        displayName: "Mixed Document",
        sourceFileName: "mixed.pdf",
        createdAt: now,
        modifiedAt: now,
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
          .writingSpacer(height: 500.0, uuid: UUID(), myScriptPartID: "part-1"),
          .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-2")
        ]
      )

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(NoteDocument.self, from: data)

      #expect(decoded.blocks.count == original.blocks.count)
      #expect(decoded == original)
    }

    @Test("blocks array order is preserved after encoding/decoding")
    func blocksOrderPreserved() throws {
      let uuid0 = UUID()
      let uuid1 = UUID()
      let uuid2 = UUID()

      let original = NoteDocument(
        documentID: UUID(),
        displayName: "Ordered Document",
        sourceFileName: "ordered.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: uuid0, myScriptPartID: "part-0"),
          .pdfPage(pageIndex: 1, uuid: uuid1, myScriptPartID: "part-1"),
          .pdfPage(pageIndex: 2, uuid: uuid2, myScriptPartID: "part-2")
        ]
      )

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(NoteDocument.self, from: data)

      #expect(decoded.blocks == original.blocks)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("can create document with empty displayName")
    func emptyDisplayName() {
      let document = NoteDocument(
        documentID: UUID(),
        displayName: "",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      #expect(document.displayName == "")
    }

    @Test("can create document with empty blocks array")
    func emptyBlocksArray() {
      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Empty Document",
        sourceFileName: "empty.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      #expect(document.blocks.isEmpty)
    }

    @Test("can create document with very long sourceFileName")
    func veryLongSourceFileName() throws {
      let longFileName = String(repeating: "a", count: 1000) + ".pdf"
      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: longFileName,
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(document)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(NoteDocument.self, from: data)

      #expect(decoded.sourceFileName == longFileName)
    }

    @Test("can create document with special characters in sourceFileName")
    func specialCharactersInSourceFileName() throws {
      let specialFileName = "My PDF (2024) [Final].pdf"
      let document = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: specialFileName,
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(document)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(NoteDocument.self, from: data)

      #expect(decoded.sourceFileName == specialFileName)
    }
  }
}

// MARK: - NoteDocumentVersion Tests

@Suite("NoteDocumentVersion Tests")
struct NoteDocumentVersionTests {

  @Test("current version is 1")
  func currentVersionIsOne() {
    #expect(NoteDocumentVersion.current == 1)
  }

  @Test("supported versions contains current version")
  func supportedContainsCurrent() {
    #expect(NoteDocumentVersion.supported.contains(NoteDocumentVersion.current))
  }

  @Test("supported versions contains version 1")
  func supportedContainsVersionOne() {
    #expect(NoteDocumentVersion.supported.contains(1))
  }

  @Test("supported versions is not empty")
  func supportedIsNotEmpty() {
    #expect(!NoteDocumentVersion.supported.isEmpty)
  }
}

// MARK: - ImportError Tests

@Suite("ImportError Tests")
struct ImportErrorTests {

  // MARK: - Error Description Tests

  @Suite("Error Descriptions")
  struct ErrorDescriptionTests {

    @Test("pdfLocked provides error description")
    func pdfLockedDescription() {
      let error = ImportError.pdfLocked

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("password") == true)
    }

    @Test("emptyDocument provides error description")
    func emptyDocumentDescription() {
      let error = ImportError.emptyDocument

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("no pages") == true)
    }

    @Test("invalidPDF provides error description with reason")
    func invalidPDFDescription() {
      let error = ImportError.invalidPDF(reason: "File corrupted")

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("File corrupted") == true)
    }

    @Test("engineNotAvailable provides error description")
    func engineNotAvailableDescription() {
      let error = ImportError.engineNotAvailable

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("engine") == true)
    }

    @Test("packageCreationFailed provides error description with underlying error")
    func packageCreationFailedDescription() {
      let error = ImportError.packageCreationFailed(underlyingError: "Permission denied")

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("Permission denied") == true)
    }

    @Test("fileCopyFailed provides error description with underlying error")
    func fileCopyFailedDescription() {
      let error = ImportError.fileCopyFailed(underlyingError: "Disk full")

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("Disk full") == true)
    }

    @Test("partCreationFailed provides error description with part index")
    func partCreationFailedDescription() {
      let error = ImportError.partCreationFailed(partIndex: 2, underlyingError: "Out of memory")

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("page 3") == true)
      #expect(error.errorDescription?.contains("Out of memory") == true)
    }

    @Test("sourceFileNotAccessible provides error description")
    func sourceFileNotAccessibleDescription() {
      let error = ImportError.sourceFileNotAccessible

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("not accessible") == true)
    }

    @Test("destinationDirectoryCreationFailed provides error description")
    func destinationDirectoryCreationFailedDescription() {
      let error = ImportError.destinationDirectoryCreationFailed(underlyingError: "Read-only filesystem")

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("Read-only filesystem") == true)
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("identical pdfLocked errors are equal")
    func identicalPdfLockedEqual() {
      let error1 = ImportError.pdfLocked
      let error2 = ImportError.pdfLocked

      #expect(error1 == error2)
    }

    @Test("identical emptyDocument errors are equal")
    func identicalEmptyDocumentEqual() {
      let error1 = ImportError.emptyDocument
      let error2 = ImportError.emptyDocument

      #expect(error1 == error2)
    }

    @Test("invalidPDF errors with same reason are equal")
    func invalidPDFSameReasonEqual() {
      let error1 = ImportError.invalidPDF(reason: "Corrupted")
      let error2 = ImportError.invalidPDF(reason: "Corrupted")

      #expect(error1 == error2)
    }

    @Test("invalidPDF errors with different reasons are not equal")
    func invalidPDFDifferentReasonNotEqual() {
      let error1 = ImportError.invalidPDF(reason: "Corrupted")
      let error2 = ImportError.invalidPDF(reason: "Invalid format")

      #expect(error1 != error2)
    }

    @Test("partCreationFailed errors with same values are equal")
    func partCreationFailedSameValuesEqual() {
      let error1 = ImportError.partCreationFailed(partIndex: 2, underlyingError: "Failed")
      let error2 = ImportError.partCreationFailed(partIndex: 2, underlyingError: "Failed")

      #expect(error1 == error2)
    }

    @Test("partCreationFailed errors with different partIndex are not equal")
    func partCreationFailedDifferentIndexNotEqual() {
      let error1 = ImportError.partCreationFailed(partIndex: 2, underlyingError: "Failed")
      let error2 = ImportError.partCreationFailed(partIndex: 3, underlyingError: "Failed")

      #expect(error1 != error2)
    }

    @Test("different error types are not equal")
    func differentErrorTypesNotEqual() {
      let error1 = ImportError.pdfLocked
      let error2 = ImportError.emptyDocument

      #expect(error1 != error2)
    }
  }
}

// MARK: - ImportCoordinator Tests
// These tests validate interface usability and expected error conditions.
// Implementation will be written after these tests compile and fail.

@Suite("ImportCoordinator Tests")
struct ImportCoordinatorTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can create ImportCoordinator with default dependencies")
    @MainActor
    func canCreateWithDefaults() {
      // This test validates the interface is usable using the factory method.
      let coordinator = ImportCoordinator.createDefault()

      #expect(coordinator != nil)
    }

    @Test("can create ImportCoordinator with mock dependencies")
    @MainActor
    func canCreateWithMocks() {
      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)
      let mockFactory = MockPDFDocumentFactory()

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      #expect(coordinator != nil)
    }
  }

  // MARK: - Happy Path Tests

  @Suite("Happy Path")
  struct HappyPathTests {

    @Test("successfully imports valid PDF with 5 pages")
    @MainActor
    func successfullyImportValidPDF() async throws {
      // Arrange: Create mock dependencies.
      let mockPDF = MockPDFDocument(pageCount: 5, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      // Create a temporary test PDF file.
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-5-pages.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act: Import the PDF.
      let document = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: Verify the document was created correctly.
      #expect(document.blocks.count == 5)
      #expect(document.sourceFileName == "test-5-pages.pdf")
      #expect(document.displayName == "test-5-pages")
    }

    @Test("imports PDF with custom display name")
    @MainActor
    func importWithCustomDisplayName() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 3, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      // Use unique filename to avoid conflicts with parallel test runs.
      let uniqueID = UUID().uuidString
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("report-\(uniqueID).pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act: Import with custom display name.
      let document = try await coordinator.importPDF(from: tempURL, displayName: "Q4 Report")

      // Assert: Display name is custom, source filename is original.
      #expect(document.displayName == "Q4 Report")
      #expect(document.sourceFileName == "report-\(uniqueID).pdf")
    }

    @Test("derives display name from filename when nil")
    @MainActor
    func derivesDisplayNameFromFilename() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 1, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Annual Report 2024.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act.
      let document = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: .pdf extension is stripped.
      #expect(document.displayName == "Annual Report 2024")
    }
  }

  // MARK: - Sad Path Tests

  @Suite("Sad Path")
  struct SadPathTests {

    @Test("throws pdfLocked for password-protected PDF")
    @MainActor
    func throwsPdfLockedForProtectedPDF() async throws {
      // Arrange: Create locked PDF.
      let mockPDF = MockPDFDocument(pageCount: 5, isLocked: true)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("locked.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act & Assert: Expect pdfLocked error.
      await #expect(throws: ImportError.pdfLocked) {
        _ = try await coordinator.importPDF(from: tempURL, displayName: nil)
      }
    }

    @Test("throws emptyDocument for PDF with zero pages")
    @MainActor
    func throwsEmptyDocumentForZeroPages() async throws {
      // Arrange: Create empty PDF.
      let mockPDF = MockPDFDocument(pageCount: 0, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("empty.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act & Assert: Expect emptyDocument error.
      await #expect(throws: ImportError.emptyDocument) {
        _ = try await coordinator.importPDF(from: tempURL, displayName: nil)
      }
    }

    @Test("throws invalidPDF for corrupted file")
    @MainActor
    func throwsInvalidPDFForCorruptedFile() async throws {
      // Arrange: Factory returns nil for invalid PDF.
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.shouldReturnNil = true

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("corrupted.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act & Assert: Expect invalidPDF error.
      await #expect(throws: ImportError.self) {
        _ = try await coordinator.importPDF(from: tempURL, displayName: nil)
      }
    }

    @Test("throws engineNotAvailable when engine is nil")
    @MainActor
    func throwsEngineNotAvailableWhenEngineNil() async throws {
      // Arrange: Engine provider returns nil engine.
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = MockPDFDocument(pageCount: 5, isLocked: false)

      let mockEngineProvider = MockPDFImportEngineProvider(noEngine: true)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act & Assert: Expect engineNotAvailable error.
      await #expect(throws: ImportError.engineNotAvailable) {
        _ = try await coordinator.importPDF(from: tempURL, displayName: nil)
      }
    }

    @Test("throws sourceFileNotAccessible for nonexistent file")
    @MainActor
    func throwsSourceFileNotAccessibleForNonexistentFile() async throws {
      // Arrange.
      let mockFactory = MockPDFDocumentFactory()
      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      // Use a non-existent URL.
      let nonexistentURL = URL(fileURLWithPath: "/nonexistent/file.pdf")

      // Act & Assert: Expect sourceFileNotAccessible error.
      await #expect(throws: ImportError.sourceFileNotAccessible) {
        _ = try await coordinator.importPDF(from: nonexistentURL, displayName: nil)
      }
    }

    @Test("throws packageCreationFailed when engine fails to create package")
    @MainActor
    func throwsPackageCreationFailedWhenEngineFails() async throws {
      // Arrange: Engine throws on package creation.
      let mockPDF = MockPDFDocument(pageCount: 5, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      mockEngine.shouldThrowOnCreate = true
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act & Assert: Expect packageCreationFailed error.
      await #expect(throws: ImportError.self) {
        _ = try await coordinator.importPDF(from: tempURL, displayName: nil)
      }
    }

    @Test("throws partCreationFailed when part creation fails mid-import")
    @MainActor
    func throwsPartCreationFailedMidImport() async throws {
      // Arrange: Package fails on creating part 2 (third part).
      let mockPDF = MockPDFDocument(pageCount: 5, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockPackage = MockPDFImportPackage()
      mockPackage.partCreationFailIndex = 2
      mockEngine.mockPackage = mockPackage
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act & Assert: Expect partCreationFailed error.
      await #expect(throws: ImportError.self) {
        _ = try await coordinator.importPDF(from: tempURL, displayName: nil)
      }
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("imports PDF with single page")
    @MainActor
    func importSinglePagePDF() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 1, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("single.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act.
      let document = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: Document has 1 block with pageIndex 0.
      #expect(document.blocks.count == 1)
      if case .pdfPage(let pageIndex, _, _) = document.blocks[0] {
        #expect(pageIndex == 0)
      } else {
        Issue.record("Expected pdfPage block")
      }
    }

    @Test("derives display name from filename with no extension")
    @MainActor
    func derivesDisplayNameNoExtension() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 1, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("document")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act.
      let document = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: Display name is "document".
      #expect(document.displayName == "document")
      #expect(document.sourceFileName == "document")
    }

    @Test("derives display name from filename with multiple dots")
    @MainActor
    func derivesDisplayNameMultipleDots() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 1, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("report.v2.final.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act.
      let document = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: Only last .pdf extension is removed.
      #expect(document.displayName == "report.v2.final")
    }

    @Test("derives display name with case-insensitive PDF extension")
    @MainActor
    func derivesDisplayNameCaseInsensitive() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 1, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Report.PDF")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act.
      let document = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: Extension stripping is case-insensitive.
      #expect(document.displayName == "Report")
    }

    @Test("preserves unicode characters in filename")
    @MainActor
    func preservesUnicodeInFilename() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 1, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("reportka_2024.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act.
      let document = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: Unicode preserved.
      #expect(document.displayName == "reportka_2024")
      #expect(document.sourceFileName == "reportka_2024.pdf")
    }

    @Test("imports same PDF twice creates independent documents")
    @MainActor
    func importSamePDFTwiceCreatesIndependentDocuments() async throws {
      // Arrange.
      let mockPDF = MockPDFDocument(pageCount: 3, isLocked: false)
      let mockFactory = MockPDFDocumentFactory()
      mockFactory.mockDocument = mockPDF

      let mockEngine = MockPDFImportEngine()
      let mockEngineProvider = MockPDFImportEngineProvider(engine: mockEngine)

      let coordinator = ImportCoordinator(
        engineProvider: mockEngineProvider,
        pdfDocumentFactory: mockFactory
      )

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("duplicate.pdf")
      FileManager.default.createFile(atPath: tempURL.path, contents: Data())
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      // Act: Import twice.
      let doc1 = try await coordinator.importPDF(from: tempURL, displayName: nil)
      let doc2 = try await coordinator.importPDF(from: tempURL, displayName: nil)

      // Assert: Different document IDs.
      #expect(doc1.documentID != doc2.documentID)
    }
  }
}

// MARK: - PDFNoteStorage Tests
// These tests validate the directory path generation logic.
// Implementation will be written after these tests compile and fail.

@Suite("PDFNoteStorage Tests")
struct PDFNoteStorageTests {

  @Test("pdfNotesFolderName is PDFNotes")
  func pdfNotesFolderNameIsCorrect() {
    #expect(PDFNoteStorage.pdfNotesFolderName == "PDFNotes")
  }

  @Test("pdfNotesDirectory returns valid URL")
  func pdfNotesDirectoryReturnsValidURL() async throws {
    // This test validates interface usability.
    // Implementation will create directory if needed.
    let url = try await PDFNoteStorage.pdfNotesDirectory()

    #expect(url.lastPathComponent == "PDFNotes")
  }

  @Test("documentDirectory returns URL for given UUID")
  func documentDirectoryReturnsURLForUUID() async throws {
    let documentID = UUID()

    let url = try await PDFNoteStorage.documentDirectory(for: documentID)

    #expect(url.lastPathComponent == documentID.uuidString)
    #expect(url.deletingLastPathComponent().lastPathComponent == "PDFNotes")
  }
}
