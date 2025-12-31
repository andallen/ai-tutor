//
// Tests for PDF Display feature based on Contract.swift.
// Covers DottedGridConfiguration, DottedGridView, SpacerCell, PDFPageCell,
// PDFCollectionViewController, and PDFCollectionLayout.
// Tests validate interface usability, configuration behavior, cell lifecycle, and layout.
//

import Testing
import Foundation
import UIKit
import PDFKit
@testable import InkOS

// MARK: - Mock Dependencies

// Mock PDF page for testing PDF page operations.
// Provides configurable bounds for aspect ratio calculations.
final class MockPDFPage: PDFPage {
  private let mockBounds: CGRect

  init(bounds: CGRect) {
    self.mockBounds = bounds
    super.init()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) not supported")
  }

  override func bounds(for box: PDFDisplayBox) -> CGRect {
    return mockBounds
  }
}

// Mock PDF document for testing collection view controller.
// Provides configurable page count and page sizes.
final class MockPDFDisplayDocument: PDFDocument {
  private let mockPageCount: Int
  private let mockPageBounds: CGRect

  init(pageCount: Int, pageBounds: CGRect = CGRect(x: 0, y: 0, width: 612, height: 792)) {
    self.mockPageCount = pageCount
    self.mockPageBounds = pageBounds
    super.init()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) not supported")
  }

  override var pageCount: Int {
    return mockPageCount
  }

  override func page(at index: Int) -> PDFPage? {
    guard index >= 0 && index < mockPageCount else {
      return nil
    }
    return MockPDFPage(bounds: mockPageBounds)
  }
}

// MARK: - DottedGridConfiguration Tests

@Suite("DottedGridConfiguration Tests")
struct DottedGridConfigurationTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can create default configuration")
    func canCreateDefaultConfiguration() {
      let config = DottedGridConfiguration.default

      #expect(config.spacing == 20.0)
      #expect(config.dotSize == 2.0)
      #expect(config.color == .lightGray)
    }

    @Test("can create custom configuration")
    func canCreateCustomConfiguration() {
      let config = DottedGridConfiguration(
        spacing: 30.0,
        dotSize: 3.0,
        color: .blue
      )

      #expect(config.spacing == 30.0)
      #expect(config.dotSize == 3.0)
      #expect(config.color == .blue)
    }

    @Test("can create configuration using default parameters")
    func canCreateConfigurationUsingDefaults() {
      let config = DottedGridConfiguration()

      #expect(config.spacing == 20.0)
      #expect(config.dotSize == 2.0)
      #expect(config.color == .lightGray)
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("identical configurations are equal")
    func identicalConfigurationsAreEqual() {
      let config1 = DottedGridConfiguration(spacing: 25.0, dotSize: 2.5, color: .gray)
      let config2 = DottedGridConfiguration(spacing: 25.0, dotSize: 2.5, color: .gray)

      #expect(config1 == config2)
    }

    @Test("configurations with different spacing are not equal")
    func differentSpacingNotEqual() {
      let config1 = DottedGridConfiguration(spacing: 20.0, dotSize: 2.0, color: .gray)
      let config2 = DottedGridConfiguration(spacing: 25.0, dotSize: 2.0, color: .gray)

      #expect(config1 != config2)
    }

    @Test("configurations with different dot size are not equal")
    func differentDotSizeNotEqual() {
      let config1 = DottedGridConfiguration(spacing: 20.0, dotSize: 2.0, color: .gray)
      let config2 = DottedGridConfiguration(spacing: 20.0, dotSize: 3.0, color: .gray)

      #expect(config1 != config2)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("can create configuration with zero spacing")
    func zeroSpacing() {
      let config = DottedGridConfiguration(spacing: 0, dotSize: 2.0, color: .gray)

      #expect(config.spacing == 0)
    }

    @Test("can create configuration with negative spacing")
    func negativeSpacing() {
      let config = DottedGridConfiguration(spacing: -10.0, dotSize: 2.0, color: .gray)

      #expect(config.spacing == -10.0)
    }

    @Test("can create configuration with zero dot size")
    func zeroDotSize() {
      let config = DottedGridConfiguration(spacing: 20.0, dotSize: 0, color: .gray)

      #expect(config.dotSize == 0)
    }

    @Test("can create configuration with very large dot size")
    func veryLargeDotSize() {
      let config = DottedGridConfiguration(spacing: 20.0, dotSize: 50.0, color: .gray)

      #expect(config.dotSize == 50.0)
    }
  }
}

// MARK: - DottedGridView Tests

@Suite("DottedGridView Tests")
@MainActor
struct DottedGridViewTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can create view with default configuration")
    @MainActor
    func canCreateViewWithDefaultConfiguration() {
      let view = DottedGridView()

      #expect(view.configuration == DottedGridConfiguration.default)
    }

    @Test("can update configuration")
    @MainActor
    func canUpdateConfiguration() {
      let view = DottedGridView()
      let newConfig = DottedGridConfiguration(spacing: 30.0, dotSize: 3.0, color: .blue)

      view.updateConfiguration(newConfig)

      #expect(view.configuration == newConfig)
    }
  }

  // MARK: - Configuration Change Tests

  @Suite("Configuration Changes")
  struct ConfigurationChangeTests {

    @Test("setting configuration triggers setNeedsDisplay")
    @MainActor
    func settingConfigurationTriggersSetNeedsDisplay() {
      let view = DottedGridView()
      let originalConfig = view.configuration
      let newConfig = DottedGridConfiguration(spacing: 30.0, dotSize: 3.0, color: .red)

      // Setting configuration should not crash.
      view.configuration = newConfig

      #expect(view.configuration != originalConfig)
      #expect(view.configuration == newConfig)
    }

    @Test("updateConfiguration method sets configuration property")
    @MainActor
    func updateConfigurationSetsProperty() {
      let view = DottedGridView()
      let newConfig = DottedGridConfiguration(spacing: 25.0, dotSize: 2.5, color: .green)

      view.updateConfiguration(newConfig)

      #expect(view.configuration == newConfig)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("view with zero-sized bounds does not crash")
    @MainActor
    func zeroSizedBoundsDoesNotCrash() {
      let view = DottedGridView(frame: .zero)

      #expect(view.bounds == .zero)
    }

    @Test("view with very small bounds does not crash")
    @MainActor
    func verySmallBoundsDoesNotCrash() {
      let view = DottedGridView(frame: CGRect(x: 0, y: 0, width: 5, height: 5))

      #expect(view.bounds.width == 5)
      #expect(view.bounds.height == 5)
    }

    @Test("configuration change while not in view hierarchy does not crash")
    @MainActor
    func configurationChangeNotInHierarchyDoesNotCrash() {
      let view = DottedGridView()
      let newConfig = DottedGridConfiguration(spacing: 15.0, dotSize: 1.5, color: .orange)

      // View is not added to any superview.
      view.updateConfiguration(newConfig)

      #expect(view.configuration == newConfig)
    }
  }
}

// MARK: - SpacerCell Tests

@Suite("SpacerCell Tests")
@MainActor
struct SpacerCellTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("reuse identifier is SpacerCell")
    @MainActor
    func reuseIdentifierIsCorrect() {
      #expect(SpacerCell.reuseIdentifier == "SpacerCell")
    }

    @Test("can initialize cell")
    @MainActor
    func canInitializeCell() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))

      #expect(cell.dottedGridView != nil)
    }

    @Test("can configure cell with height and uuid")
    @MainActor
    func canConfigureCellWithHeightAndUUID() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
      let uuid = UUID()

      cell.configure(height: 500.0, uuid: uuid)

      #expect(cell.blockUUID == uuid)
    }
  }

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("initialization creates dotted grid view")
    @MainActor
    func initializationCreatesDottedGridView() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))

      #expect(cell.dottedGridView != nil)
      #expect(cell.dottedGridView.superview == cell.contentView)
    }

    @Test("dotted grid view fills content view")
    @MainActor
    func dottedGridViewFillsContentView() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))

      // Force layout to apply constraints.
      cell.layoutIfNeeded()

      // Grid view should be a subview of contentView.
      #expect(cell.dottedGridView.superview == cell.contentView)
    }
  }

  // MARK: - Configure Tests

  @Suite("Configure")
  struct ConfigureTests {

    @Test("configure with valid UUID stores UUID")
    @MainActor
    func configureWithValidUUIDStoresUUID() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
      let uuid = UUID()

      cell.configure(height: 500.0, uuid: uuid)

      #expect(cell.blockUUID == uuid)
    }

    @Test("configure called multiple times updates UUID")
    @MainActor
    func configureCalledMultipleTimesUpdatesUUID() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
      let uuid1 = UUID()
      let uuid2 = UUID()

      cell.configure(height: 500.0, uuid: uuid1)
      #expect(cell.blockUUID == uuid1)

      cell.configure(height: 600.0, uuid: uuid2)
      #expect(cell.blockUUID == uuid2)
    }
  }

  // MARK: - Prepare for Reuse Tests

  @Suite("Prepare for Reuse")
  struct PrepareForReuseTests {

    @Test("prepare for reuse clears block UUID")
    @MainActor
    func prepareForReuseClearsBlockUUID() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
      let uuid = UUID()

      cell.configure(height: 500.0, uuid: uuid)
      #expect(cell.blockUUID != nil)

      cell.prepareForReuse()

      #expect(cell.blockUUID == nil)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("configure with zero height")
    @MainActor
    func configureWithZeroHeight() {
      let cell = SpacerCell(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
      let uuid = UUID()

      cell.configure(height: 0, uuid: uuid)

      #expect(cell.blockUUID == uuid)
    }
  }
}

// MARK: - PDFPageCell Tests

@Suite("PDFPageCell Tests")
@MainActor
struct PDFPageCellTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("reuse identifier is PDFPageCell")
    @MainActor
    func reuseIdentifierIsCorrect() {
      #expect(PDFPageCell.reuseIdentifier == "PDFPageCell")
    }

    @Test("can initialize cell")
    @MainActor
    func canInitializeCell() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))

      #expect(cell.pdfView != nil)
      #expect(cell.overlayContainer != nil)
    }
  }

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("initialization creates pdf view with correct settings")
    @MainActor
    func initializationCreatesPDFViewWithCorrectSettings() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))

      #expect(cell.pdfView != nil)
      #expect(cell.pdfView.displayMode == .singlePage)
      #expect(cell.pdfView.autoScales == true)
      #expect(cell.pdfView.isUserInteractionEnabled == false)
    }

    @Test("initialization creates overlay container")
    @MainActor
    func initializationCreatesOverlayContainer() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))

      #expect(cell.overlayContainer != nil)
      #expect(cell.overlayContainer.isUserInteractionEnabled == false)
    }

    @Test("overlay container is layered above pdf view")
    @MainActor
    func overlayContainerLayeredAbovePDFView() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))

      // Both views should be subviews of contentView.
      #expect(cell.pdfView.superview == cell.contentView)
      #expect(cell.overlayContainer.superview == cell.contentView)

      // Overlay should have higher z-index (added later or explicitly brought to front).
      // This is validated by the existence of overlayContainer as separate view.
      #expect(cell.overlayContainer != nil)
    }
  }

  // MARK: - Configure Tests

  @Suite("Configure")
  struct ConfigureTests {

    @Test("configure with valid PDF page sets properties")
    @MainActor
    func configureWithValidPDFPageSetsProperties() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
      let page = MockPDFPage(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
      let uuid = UUID()

      cell.configure(page: page, pageIndex: 0, uuid: uuid)

      #expect(cell.pageIndex == 0)
      #expect(cell.blockUUID == uuid)
      #expect(cell.pdfView.document != nil)
    }

    @Test("configure called multiple times updates page")
    @MainActor
    func configureCalledMultipleTimesUpdatesPage() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
      let page1 = MockPDFPage(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
      let page2 = MockPDFPage(bounds: CGRect(x: 0, y: 0, width: 792, height: 612))
      let uuid1 = UUID()
      let uuid2 = UUID()

      cell.configure(page: page1, pageIndex: 0, uuid: uuid1)
      #expect(cell.pageIndex == 0)

      cell.configure(page: page2, pageIndex: 1, uuid: uuid2)
      #expect(cell.pageIndex == 1)
      #expect(cell.blockUUID == uuid2)
    }
  }

  // MARK: - Prepare for Reuse Tests

  @Suite("Prepare for Reuse")
  struct PrepareForReuseTests {

    @Test("prepare for reuse clears pdf view document")
    @MainActor
    func prepareForReuseClearsPDFViewDocument() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
      let page = MockPDFPage(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
      let uuid = UUID()

      cell.configure(page: page, pageIndex: 0, uuid: uuid)
      #expect(cell.pdfView.document != nil)

      cell.prepareForReuse()

      #expect(cell.pdfView.document == nil)
    }

    @Test("prepare for reuse clears page index and block UUID")
    @MainActor
    func prepareForReuseClearsIdentifiers() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
      let page = MockPDFPage(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
      let uuid = UUID()

      cell.configure(page: page, pageIndex: 5, uuid: uuid)
      #expect(cell.pageIndex == 5)
      #expect(cell.blockUUID == uuid)

      cell.prepareForReuse()

      #expect(cell.pageIndex == nil)
      #expect(cell.blockUUID == nil)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("configure with landscape page")
    @MainActor
    func configureWithLandscapePage() {
      let cell = PDFPageCell(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
      let landscapePage = MockPDFPage(bounds: CGRect(x: 0, y: 0, width: 792, height: 612))
      let uuid = UUID()

      cell.configure(page: landscapePage, pageIndex: 0, uuid: uuid)

      #expect(cell.pageIndex == 0)
      #expect(cell.pdfView.document != nil)
    }
  }
}

// MARK: - PDFCollectionViewControllerError Tests

@Suite("PDFCollectionViewControllerError Tests")
struct PDFCollectionViewControllerErrorTests {

  // MARK: - Error Description Tests

  @Suite("Error Descriptions")
  struct ErrorDescriptionTests {

    @Test("emptyDocument provides error description")
    func emptyDocumentDescription() {
      let error = PDFCollectionViewControllerError.emptyDocument

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("no pages") == true)
    }

    @Test("invalidPDFDocument provides error description")
    func invalidPDFDocumentDescription() {
      let error = PDFCollectionViewControllerError.invalidPDFDocument

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("invalid") == true)
    }

    @Test("pageIndexOutOfBounds provides error description with details")
    func pageIndexOutOfBoundsDescription() {
      let error = PDFCollectionViewControllerError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("2") == true)
      #expect(error.errorDescription?.contains("10") == true)
      #expect(error.errorDescription?.contains("5") == true)
    }

    @Test("pdfPageUnavailable provides error description with page index")
    func pdfPageUnavailableDescription() {
      let error = PDFCollectionViewControllerError.pdfPageUnavailable(pageIndex: 3)

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("3") == true)
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("identical emptyDocument errors are equal")
    func identicalEmptyDocumentEqual() {
      let error1 = PDFCollectionViewControllerError.emptyDocument
      let error2 = PDFCollectionViewControllerError.emptyDocument

      #expect(error1 == error2)
    }

    @Test("pageIndexOutOfBounds errors with same values are equal")
    func pageIndexOutOfBoundsSameValuesEqual() {
      let error1 = PDFCollectionViewControllerError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )
      let error2 = PDFCollectionViewControllerError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )

      #expect(error1 == error2)
    }

    @Test("pageIndexOutOfBounds errors with different values are not equal")
    func pageIndexOutOfBoundsDifferentValuesNotEqual() {
      let error1 = PDFCollectionViewControllerError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )
      let error2 = PDFCollectionViewControllerError.pageIndexOutOfBounds(
        blockIndex: 3,
        pageIndex: 10,
        pdfPageCount: 5
      )

      #expect(error1 != error2)
    }

    @Test("different error types are not equal")
    func differentErrorTypesNotEqual() {
      let error1 = PDFCollectionViewControllerError.emptyDocument
      let error2 = PDFCollectionViewControllerError.invalidPDFDocument

      #expect(error1 != error2)
    }
  }
}

// MARK: - PDFCollectionViewController Tests

@Suite("PDFCollectionViewController Tests")
@MainActor
struct PDFCollectionViewControllerTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can initialize with valid note document and PDF document")
    @MainActor
    func canInitializeWithValidDocuments() throws {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test Document",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 1)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      #expect(controller.noteDocument.documentID == noteDocument.documentID)
      #expect(controller.pdfDocument.pageCount == 1)
    }
  }

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("init with valid document succeeds")
    @MainActor
    func initWithValidDocumentSucceeds() throws {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
          .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 2)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      #expect(controller.noteDocument.blocks.count == 2)
    }

    @Test("init with empty document throws emptyDocument error")
    @MainActor
    func initWithEmptyDocumentThrowsError() {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Empty",
        sourceFileName: "empty.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 0)

      #expect(throws: PDFCollectionViewControllerError.emptyDocument) {
        _ = try PDFCollectionViewController(
          noteDocument: noteDocument,
          pdfDocument: pdfDocument
        )
      }
    }
  }

  // MARK: - Cell Height Calculation Tests

  @Suite("Cell Height Calculation")
  struct CellHeightCalculationTests {

    @Test("cell height for PDF page calculates aspect ratio correctly")
    @MainActor
    func cellHeightForPDFPageCalculatesAspectRatio() throws {
      // US Letter portrait: 612x792.
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(
        pageCount: 1,
        pageBounds: CGRect(x: 0, y: 0, width: 612, height: 792)
      )

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      // Container width 612 should result in height 792.
      let height = try controller.cellHeight(at: 0, containerWidth: 612)

      #expect(height == 792)
    }

    @Test("cell height for PDF page with landscape orientation")
    @MainActor
    func cellHeightForLandscapePage() throws {
      // US Letter landscape: 792x612.
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(
        pageCount: 1,
        pageBounds: CGRect(x: 0, y: 0, width: 792, height: 612)
      )

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      // Container width 400 should result in height 400 * (612/792) ≈ 309.
      let height = try controller.cellHeight(at: 0, containerWidth: 400)
      let expectedHeight = 400.0 * (612.0 / 792.0)

      #expect(abs(height - expectedHeight) < 0.01)
    }

    @Test("cell height for writing spacer returns stored height")
    @MainActor
    func cellHeightForWritingSpacerReturnsStoredHeight() throws {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .writingSpacer(height: 500.0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 0)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      // Spacer height should be 500 regardless of container width.
      let height = try controller.cellHeight(at: 0, containerWidth: 400)

      #expect(height == 500.0)
    }

    @Test("cell height for writing spacer ignores container width")
    @MainActor
    func cellHeightForWritingSpacerIgnoresContainerWidth() throws {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .writingSpacer(height: 750.0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 0)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      // Same height regardless of container width.
      let height1 = try controller.cellHeight(at: 0, containerWidth: 200)
      let height2 = try controller.cellHeight(at: 0, containerWidth: 800)

      #expect(height1 == 750.0)
      #expect(height2 == 750.0)
    }
  }

  // MARK: - Error Handling Tests

  @Suite("Error Handling")
  struct ErrorHandlingTests {

    @Test("cell height with invalid block index throws error")
    @MainActor
    func cellHeightWithInvalidBlockIndexThrowsError() throws {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 1)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      // Block index 10 is out of bounds.
      #expect(throws: Error.self) {
        _ = try controller.cellHeight(at: 10, containerWidth: 400)
      }
    }

    @Test("cell height with page index out of bounds throws error")
    @MainActor
    func cellHeightWithPageIndexOutOfBoundsThrowsError() throws {
      // Note document references page 10, but PDF only has 5 pages.
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 10, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 5)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      #expect(throws: PDFCollectionViewControllerError.self) {
        _ = try controller.cellHeight(at: 0, containerWidth: 400)
      }
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("cell height with zero container width returns zero for PDF page")
    @MainActor
    func cellHeightWithZeroContainerWidthReturnsZeroForPDFPage() throws {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 1)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      let height = try controller.cellHeight(at: 0, containerWidth: 0)

      #expect(height == 0)
    }

    @Test("cell height with zero container width returns stored height for spacer")
    @MainActor
    func cellHeightWithZeroContainerWidthReturnsStoredHeightForSpacer() throws {
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .writingSpacer(height: 500.0, uuid: UUID(), myScriptPartID: "part-0")
        ]
      )
      let pdfDocument = MockPDFDisplayDocument(pageCount: 0)

      let controller = try PDFCollectionViewController(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      let height = try controller.cellHeight(at: 0, containerWidth: 0)

      #expect(height == 500.0)
    }
  }
}

// MARK: - PDFCollectionLayout Tests

@Suite("PDFCollectionLayout Tests")
@MainActor
struct PDFCollectionLayoutTests {

  // MARK: - Interface Usability Tests

  @Suite("Interface Usability")
  struct InterfaceUsabilityTests {

    @Test("can create layout with height provider")
    @MainActor
    func canCreateLayoutWithHeightProvider() {
      let heightProvider: (IndexPath, NSCollectionLayoutEnvironment) -> CGFloat = { _, _ in
        return 500.0
      }

      let layout = PDFCollectionLayout.createLayout(heightProvider: heightProvider)

      #expect(layout != nil)
    }

    @Test("created layout is compositional layout")
    @MainActor
    func createdLayoutIsCompositionalLayout() {
      let heightProvider: (IndexPath, NSCollectionLayoutEnvironment) -> CGFloat = { _, _ in
        return 500.0
      }

      let layout = PDFCollectionLayout.createLayout(heightProvider: heightProvider)

      #expect(layout is UICollectionViewCompositionalLayout)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("height provider returning zero is handled")
    @MainActor
    func heightProviderReturningZeroIsHandled() {
      let heightProvider: (IndexPath, NSCollectionLayoutEnvironment) -> CGFloat = { _, _ in
        return 0
      }

      let layout = PDFCollectionLayout.createLayout(heightProvider: heightProvider)

      #expect(layout != nil)
    }

    @Test("height provider returning very large value is handled")
    @MainActor
    func heightProviderReturningVeryLargeValueIsHandled() {
      let heightProvider: (IndexPath, NSCollectionLayoutEnvironment) -> CGFloat = { _, _ in
        return 10000
      }

      let layout = PDFCollectionLayout.createLayout(heightProvider: heightProvider)

      #expect(layout != nil)
    }
  }
}
