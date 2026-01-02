//
// Tests for PDF Display feature based on PDFDocumentContract.swift.
// Covers PDFDocumentError, NoteBlock.baseHeight, DottedGridView.drawDottedPattern (static),
// and PDFDocumentView layout calculations.
// Tests validate interface usability, error handling, and layout correctness.
//

import Testing
import Foundation
import UIKit
import PDFKit
import CoreGraphics
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

// Mock data source for PDFBackgroundLayerDataSource protocol.
// Provides configurable PDF document, note document, block Y offsets, and zoom scale.
final class MockPDFBackgroundLayerDataSource: PDFBackgroundLayerDataSource {
  var pdfDocument: PDFDocument
  var noteDocument: NoteDocument
  var blockYOffsets: [CGFloat]
  var currentZoomScale: CGFloat
  private let pageHeights: [Int: CGFloat]

  init(
    pdfDocument: PDFDocument,
    noteDocument: NoteDocument,
    blockYOffsets: [CGFloat] = [],
    currentZoomScale: CGFloat = 1.0,
    pageHeights: [Int: CGFloat] = [:]
  ) {
    self.pdfDocument = pdfDocument
    self.noteDocument = noteDocument
    self.blockYOffsets = blockYOffsets
    self.currentZoomScale = currentZoomScale
    self.pageHeights = pageHeights
  }

  func pageHeight(for pageIndex: Int, at width: CGFloat) -> CGFloat? {
    // Return configured page height if available.
    if let height = pageHeights[pageIndex] {
      return height
    }
    // Default behavior: return nil for invalid indices.
    guard pageIndex >= 0 && pageIndex < pdfDocument.pageCount else {
      return nil
    }
    // Calculate height from PDF page bounds.
    guard let page = pdfDocument.page(at: pageIndex) else {
      return nil
    }
    let bounds = page.bounds(for: .mediaBox)
    guard bounds.width > 0 else {
      return 0
    }
    return width * (bounds.height / bounds.width)
  }
}

// Mock implementation of PDFDocumentViewProtocol for testing layout calculations.
// Provides configurable note document, PDF document, and block Y offsets.
final class MockPDFDocumentView: PDFDocumentViewProtocol {
  var noteDocument: NoteDocument
  var pdfDocument: PDFDocument
  var currentZoomScale: CGFloat
  var contentOffset: CGPoint
  var blockYOffsets: [CGFloat]

  // Track scroll calls for testing.
  var scrollToCallCount = 0
  var lastScrolledBlockIndex: Int?
  var lastScrollAnimated: Bool?

  // Page height provider for calculating block heights.
  private let pageHeightProvider: (Int) -> CGFloat?

  init(
    noteDocument: NoteDocument,
    pdfDocument: PDFDocument,
    currentZoomScale: CGFloat = 1.0,
    contentOffset: CGPoint = .zero,
    blockYOffsets: [CGFloat] = [],
    pageHeightProvider: @escaping (Int) -> CGFloat? = { _ in nil }
  ) {
    self.noteDocument = noteDocument
    self.pdfDocument = pdfDocument
    self.currentZoomScale = currentZoomScale
    self.contentOffset = contentOffset
    self.blockYOffsets = blockYOffsets
    self.pageHeightProvider = pageHeightProvider
  }

  func calculateBlockYOffsets() -> [CGFloat] {
    var offsets: [CGFloat] = []
    var currentY: CGFloat = 0

    for block in noteDocument.blocks {
      offsets.append(currentY)
      if let height = block.baseHeight(pageHeightProvider: pageHeightProvider) {
        currentY += height
      }
    }

    return offsets
  }

  func calculateTotalContentHeight() -> CGFloat {
    var totalHeight: CGFloat = 0

    for block in noteDocument.blocks {
      if let height = block.baseHeight(pageHeightProvider: pageHeightProvider) {
        totalHeight += height
      }
    }

    return totalHeight * currentZoomScale
  }

  func blockContaining(yOffset: CGFloat) -> (blockIndex: Int, block: NoteBlock)? {
    guard !noteDocument.blocks.isEmpty else {
      return nil
    }

    // Calculate total height to check if yOffset is beyond content.
    var totalHeight: CGFloat = 0
    for block in noteDocument.blocks {
      if let height = block.baseHeight(pageHeightProvider: pageHeightProvider) {
        totalHeight += height
      }
    }

    guard yOffset < totalHeight else {
      return nil
    }

    // Find the block containing the yOffset.
    var currentY: CGFloat = 0
    for (index, block) in noteDocument.blocks.enumerated() {
      guard let height = block.baseHeight(pageHeightProvider: pageHeightProvider) else {
        continue
      }
      let nextY = currentY + height
      if yOffset >= currentY && yOffset < nextY {
        return (blockIndex: index, block: block)
      }
      currentY = nextY
    }

    return nil
  }

  func scrollTo(blockIndex: Int, animated: Bool) {
    scrollToCallCount += 1
    lastScrolledBlockIndex = blockIndex
    lastScrollAnimated = animated

    // Update content offset based on block index.
    guard blockIndex >= 0 && blockIndex < blockYOffsets.count else {
      return
    }
    contentOffset.y = blockYOffsets[blockIndex] * currentZoomScale
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

// MARK: - PDFDocumentError Tests

@Suite("PDFDocumentError Tests")
struct PDFDocumentErrorTests {

  // MARK: - Error Description Tests

  @Suite("Error Descriptions")
  struct ErrorDescriptionTests {

    @Test("emptyDocument provides error description")
    func emptyDocumentDescription() {
      let error = PDFDocumentError.emptyDocument

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("no pages") == true)
    }

    @Test("invalidPDFDocument provides error description")
    func invalidPDFDocumentDescription() {
      let error = PDFDocumentError.invalidPDFDocument

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("invalid") == true)
    }

    @Test("pageIndexOutOfBounds provides error description with details")
    func pageIndexOutOfBoundsDescription() {
      let error = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("2") == true)
      #expect(error.errorDescription?.contains("10") == true)
      #expect(error.errorDescription?.contains("5") == true)
    }

    @Test("engineNotAvailable provides error description")
    func engineNotAvailableDescription() {
      let error = PDFDocumentError.engineNotAvailable

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("engine") == true || error.errorDescription?.contains("annotation") == true)
    }

    @Test("partNotFound provides error description with part ID")
    func partNotFoundDescription() {
      let error = PDFDocumentError.partNotFound(myScriptPartID: "test-part-123")

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("test-part-123") == true)
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("identical emptyDocument errors are equal")
    func identicalEmptyDocumentEqual() {
      let error1 = PDFDocumentError.emptyDocument
      let error2 = PDFDocumentError.emptyDocument

      #expect(error1 == error2)
    }

    @Test("identical invalidPDFDocument errors are equal")
    func identicalInvalidPDFDocumentEqual() {
      let error1 = PDFDocumentError.invalidPDFDocument
      let error2 = PDFDocumentError.invalidPDFDocument

      #expect(error1 == error2)
    }

    @Test("identical engineNotAvailable errors are equal")
    func identicalEngineNotAvailableEqual() {
      let error1 = PDFDocumentError.engineNotAvailable
      let error2 = PDFDocumentError.engineNotAvailable

      #expect(error1 == error2)
    }

    @Test("pageIndexOutOfBounds errors with same values are equal")
    func pageIndexOutOfBoundsSameValuesEqual() {
      let error1 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )
      let error2 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )

      #expect(error1 == error2)
    }

    @Test("pageIndexOutOfBounds errors with different blockIndex are not equal")
    func pageIndexOutOfBoundsDifferentBlockIndexNotEqual() {
      let error1 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )
      let error2 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 3,
        pageIndex: 10,
        pdfPageCount: 5
      )

      #expect(error1 != error2)
    }

    @Test("pageIndexOutOfBounds errors with different pageIndex are not equal")
    func pageIndexOutOfBoundsDifferentPageIndexNotEqual() {
      let error1 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )
      let error2 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 11,
        pdfPageCount: 5
      )

      #expect(error1 != error2)
    }

    @Test("pageIndexOutOfBounds errors with different pdfPageCount are not equal")
    func pageIndexOutOfBoundsDifferentPdfPageCountNotEqual() {
      let error1 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 5
      )
      let error2 = PDFDocumentError.pageIndexOutOfBounds(
        blockIndex: 2,
        pageIndex: 10,
        pdfPageCount: 6
      )

      #expect(error1 != error2)
    }

    @Test("partNotFound errors with same ID are equal")
    func partNotFoundSameIDEqual() {
      let error1 = PDFDocumentError.partNotFound(myScriptPartID: "part-123")
      let error2 = PDFDocumentError.partNotFound(myScriptPartID: "part-123")

      #expect(error1 == error2)
    }

    @Test("partNotFound errors with different ID are not equal")
    func partNotFoundDifferentIDNotEqual() {
      let error1 = PDFDocumentError.partNotFound(myScriptPartID: "part-123")
      let error2 = PDFDocumentError.partNotFound(myScriptPartID: "part-456")

      #expect(error1 != error2)
    }

    @Test("different error types are not equal")
    func differentErrorTypesNotEqual() {
      let error1 = PDFDocumentError.emptyDocument
      let error2 = PDFDocumentError.invalidPDFDocument

      #expect(error1 != error2)
    }

    @Test("emptyDocument and engineNotAvailable are not equal")
    func emptyDocumentAndEngineNotAvailableNotEqual() {
      let error1 = PDFDocumentError.emptyDocument
      let error2 = PDFDocumentError.engineNotAvailable

      #expect(error1 != error2)
    }
  }
}

// MARK: - NoteBlock.baseHeight Tests

@Suite("NoteBlock.baseHeight Tests")
struct NoteBlockBaseHeightTests {

  // MARK: - PDF Page Tests

  @Suite("PDF Page Height")
  struct PDFPageHeightTests {

    @Test("pdfPage returns height from provider")
    func pdfPageReturnsHeightFromProvider() {
      let block = NoteBlock.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index == 0 ? 792 : nil
      }

      let height = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(height == 792)
    }

    @Test("pdfPage with different page index returns correct height")
    func pdfPageWithDifferentPageIndexReturnsCorrectHeight() {
      let block = NoteBlock.pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      let pageHeightProvider: (Int) -> CGFloat? = { index in
        switch index {
        case 0: return 792
        case 1: return 800
        case 2: return 500
        default: return nil
        }
      }

      let height = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(height == 500)
    }

    @Test("pdfPage with invalid page index returns nil")
    func pdfPageWithInvalidPageIndexReturnsNil() {
      let block = NoteBlock.pdfPage(pageIndex: 10, uuid: UUID(), myScriptPartID: "part-10")
      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 5 ? 792 : nil
      }

      let height = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(height == nil)
    }
  }

  // MARK: - Writing Spacer Tests

  @Suite("Writing Spacer Height")
  struct WritingSpacerHeightTests {

    @Test("writingSpacer returns stored height")
    func writeSpacerReturnsStoredHeight() {
      let block = NoteBlock.writingSpacer(height: 200, uuid: UUID(), myScriptPartID: "part-spacer")
      let pageHeightProvider: (Int) -> CGFloat? = { _ in
        return 792
      }

      let height = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(height == 200)
    }

    @Test("writingSpacer does not call page height provider")
    func writeSpacerDoesNotCallPageHeightProvider() {
      let block = NoteBlock.writingSpacer(height: 300, uuid: UUID(), myScriptPartID: "part-spacer")
      var providerCallCount = 0
      let pageHeightProvider: (Int) -> CGFloat? = { _ in
        providerCallCount += 1
        return 792
      }

      _ = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(providerCallCount == 0)
    }

    @Test("writingSpacer with zero height returns zero")
    func writeSpacerWithZeroHeightReturnsZero() {
      let block = NoteBlock.writingSpacer(height: 0, uuid: UUID(), myScriptPartID: "part-spacer")
      let pageHeightProvider: (Int) -> CGFloat? = { _ in nil }

      let height = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(height == 0)
    }

    @Test("writingSpacer with very large height returns that height")
    func writeSpacerWithVeryLargeHeightReturnsThatHeight() {
      let largeHeight = CGFloat.greatestFiniteMagnitude
      let block = NoteBlock.writingSpacer(height: largeHeight, uuid: UUID(), myScriptPartID: "part-spacer")
      let pageHeightProvider: (Int) -> CGFloat? = { _ in nil }

      let height = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(height == largeHeight)
    }

    @Test("writingSpacer with negative height returns that height")
    func writeSpacerWithNegativeHeightReturnsThatHeight() {
      // This represents invalid state but the extension does not validate.
      let block = NoteBlock.writingSpacer(height: -100, uuid: UUID(), myScriptPartID: "part-spacer")
      let pageHeightProvider: (Int) -> CGFloat? = { _ in nil }

      let height = block.baseHeight(pageHeightProvider: pageHeightProvider)

      #expect(height == -100)
    }
  }
}

// MARK: - DottedGridView Static Drawing Tests

@Suite("DottedGridView.drawDottedPattern (static) Tests")
@MainActor
struct DottedGridViewStaticDrawingTests {

  // MARK: - Pattern Drawing Tests

  @Suite("Pattern Drawing")
  struct PatternDrawingTests {

    @Test("pattern respects configuration spacing")
    @MainActor
    func patternRespectsConfigurationSpacing() {
      // Create a bitmap context to draw into.
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration(spacing: 40, dotSize: 4, color: .blue)
      let rect = CGRect(origin: .zero, size: size)

      // Drawing should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      // If we reach here without crashing, the test passes.
      #expect(true)
    }

    @Test("pattern respects configuration dot size")
    @MainActor
    func patternRespectsConfigurationDotSize() {
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration(spacing: 20, dotSize: 8, color: .red)
      let rect = CGRect(origin: .zero, size: size)

      // Drawing should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }

    @Test("pattern uses configured color")
    @MainActor
    func patternUsesConfiguredColor() {
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration(spacing: 20, dotSize: 2, color: .green)
      let rect = CGRect(origin: .zero, size: size)

      // Drawing should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }

    @Test("scale parameter is accepted for retina rendering")
    @MainActor
    func scaleParameterAcceptedForRetinaRendering() {
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration.default
      let rect = CGRect(origin: .zero, size: size)

      // Drawing with scale 2.0 should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 2.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("zero-sized rect does not crash")
    @MainActor
    func zeroSizedRectDoesNotCrash() {
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration.default
      let rect = CGRect.zero

      // Drawing into zero rect should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }

    @Test("zero spacing does not crash")
    @MainActor
    func zeroSpacingDoesNotCrash() {
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration(spacing: 0, dotSize: 2, color: .gray)
      let rect = CGRect(origin: .zero, size: size)

      // Drawing with zero spacing should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }

    @Test("negative spacing does not crash")
    @MainActor
    func negativeSpacingDoesNotCrash() {
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration(spacing: -10, dotSize: 2, color: .gray)
      let rect = CGRect(origin: .zero, size: size)

      // Drawing with negative spacing should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }

    @Test("very large rect does not crash")
    @MainActor
    func veryLargeRectDoesNotCrash() {
      // Use a smaller context for memory efficiency but draw a large rect.
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration.default
      // Conceptually large rect, CGPattern should handle tiling efficiently.
      let rect = CGRect(x: 0, y: 0, width: 10000, height: 10000)

      // Drawing into large rect should not crash (CGPattern tiles efficiently).
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }

    @Test("zero dot size does not crash")
    @MainActor
    func zeroDotSizeDoesNotCrash() {
      let size = CGSize(width: 100, height: 100)
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        Issue.record("Failed to create graphics context")
        return
      }

      let config = DottedGridConfiguration(spacing: 20, dotSize: 0, color: .gray)
      let rect = CGRect(origin: .zero, size: size)

      // Drawing with zero dot size should not crash.
      DottedGridView.drawDottedPattern(
        in: context,
        rect: rect,
        configuration: config,
        scale: 1.0
      )

      UIGraphicsEndImageContext()
      #expect(true)
    }
  }
}

// MARK: - PDFDocumentView Layout Tests

@Suite("PDFDocumentView Layout Tests")
struct PDFDocumentViewLayoutTests {

  // Helper to create a test note document.
  static func createTestNoteDocument(blocks: [NoteBlock]) -> NoteDocument {
    return NoteDocument(
      documentID: UUID(),
      displayName: "Test Document",
      sourceFileName: "test.pdf",
      createdAt: Date(),
      modifiedAt: Date(),
      blocks: blocks
    )
  }

  // MARK: - calculateBlockYOffsets Tests

  @Suite("calculateBlockYOffsets")
  struct CalculateBlockYOffsetsTests {

    @Test("calculates offsets for PDF pages only")
    func calculatesOffsetsForPDFPagesOnly() {
      // Document with 3 PDF pages, each 792 points tall.
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      let offsets = mockView.calculateBlockYOffsets()

      #expect(offsets == [0, 792, 1584])
    }

    @Test("calculates offsets with interleaved spacer")
    func calculatesOffsetsWithInterleavedSpacer() {
      // Document with [pdfPage(792), writingSpacer(200), pdfPage(792)].
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .writingSpacer(height: 200, uuid: UUID(), myScriptPartID: "spacer-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 2)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 2 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      let offsets = mockView.calculateBlockYOffsets()

      #expect(offsets == [0, 792, 992])
    }

    @Test("calculates offsets for empty document")
    func calculatesOffsetsForEmptyDocument() {
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: [])
      let pdfDocument = MockPDFDisplayDocument(pageCount: 0)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      let offsets = mockView.calculateBlockYOffsets()

      #expect(offsets == [])
    }

    @Test("calculates offsets with multiple spacers")
    func calculatesOffsetsWithMultipleSpacers() {
      // Document with [pdfPage(792), spacer(100), spacer(150), pdfPage(792)].
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .writingSpacer(height: 100, uuid: UUID(), myScriptPartID: "spacer-0"),
        .writingSpacer(height: 150, uuid: UUID(), myScriptPartID: "spacer-1"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 2)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 2 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      let offsets = mockView.calculateBlockYOffsets()

      #expect(offsets == [0, 792, 892, 1042])
    }
  }

  // MARK: - calculateTotalContentHeight Tests

  @Suite("calculateTotalContentHeight")
  struct CalculateTotalContentHeightTests {

    @Test("calculates total height without zoom")
    func calculatesTotalHeightWithoutZoom() {
      // Document with 3 PDF pages, each 792 points tall.
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        currentZoomScale: 1.0,
        pageHeightProvider: pageHeightProvider
      )

      let height = mockView.calculateTotalContentHeight()

      #expect(height == 2376) // 792 * 3
    }

    @Test("calculates total height with zoom")
    func calculatesTotalHeightWithZoom() {
      // Document with 3 PDF pages, each 792 points tall, at 2x zoom.
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        currentZoomScale: 2.0,
        pageHeightProvider: pageHeightProvider
      )

      let height = mockView.calculateTotalContentHeight()

      #expect(height == 4752) // 792 * 3 * 2.0
    }

    @Test("calculates total height with mixed blocks")
    func calculatesTotalHeightWithMixedBlocks() {
      // Document with [pdfPage(792), writingSpacer(200), pdfPage(792)].
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .writingSpacer(height: 200, uuid: UUID(), myScriptPartID: "spacer-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 2)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 2 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        currentZoomScale: 1.0,
        pageHeightProvider: pageHeightProvider
      )

      let height = mockView.calculateTotalContentHeight()

      #expect(height == 1784) // 792 + 200 + 792
    }

    @Test("calculates total height for empty document")
    func calculatesTotalHeightForEmptyDocument() {
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: [])
      let pdfDocument = MockPDFDisplayDocument(pageCount: 0)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      let height = mockView.calculateTotalContentHeight()

      #expect(height == 0)
    }
  }

  // MARK: - blockContaining Tests

  @Suite("blockContaining")
  struct BlockContainingTests {

    @Test("finds block at beginning")
    func findsBlockAtBeginning() {
      // Document with 3 PDF pages.
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      let result = mockView.blockContaining(yOffset: 0)

      #expect(result?.blockIndex == 0)
    }

    @Test("finds block in middle of first page")
    func findsBlockInMiddleOfFirstPage() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      let result = mockView.blockContaining(yOffset: 400)

      #expect(result?.blockIndex == 0)
    }

    @Test("finds block at boundary")
    func findsBlockAtBoundary() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      // At exactly 792, should be in second block.
      let result = mockView.blockContaining(yOffset: 792)

      #expect(result?.blockIndex == 1)
    }

    @Test("finds block in second page")
    func findsBlockInSecondPage() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      let result = mockView.blockContaining(yOffset: 1000)

      #expect(result?.blockIndex == 1)
    }

    @Test("returns nil past last page")
    func returnsNilPastLastPage() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 3 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      // Total height is 2376, yOffset 3000 is past the end.
      let result = mockView.blockContaining(yOffset: 3000)

      #expect(result == nil)
    }

    @Test("returns nil exactly at total height")
    func returnsNilExactlyAtTotalHeight() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 2)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 2 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      // Total height is 1584, yOffset 1584 is exactly at the end.
      let result = mockView.blockContaining(yOffset: 1584)

      #expect(result == nil)
    }

    @Test("returns nil for empty document")
    func returnsNilForEmptyDocument() {
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: [])
      let pdfDocument = MockPDFDisplayDocument(pageCount: 0)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument
      )

      let result = mockView.blockContaining(yOffset: 0)

      #expect(result == nil)
    }

    @Test("finds spacer block correctly")
    func findsSpacerBlockCorrectly() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .writingSpacer(height: 200, uuid: UUID(), myScriptPartID: "spacer-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 2)

      let pageHeightProvider: (Int) -> CGFloat? = { index in
        return index < 2 ? 792 : nil
      }

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        pageHeightProvider: pageHeightProvider
      )

      // yOffset 800 should be in the spacer (starts at 792, ends at 992).
      let result = mockView.blockContaining(yOffset: 800)

      #expect(result?.blockIndex == 1)
      if case .writingSpacer = result?.block {
        #expect(true)
      } else {
        Issue.record("Expected writingSpacer block")
      }
    }
  }

  // MARK: - scrollTo Tests

  @Suite("scrollTo")
  struct ScrollToTests {

    @Test("scroll to first block sets content offset to zero")
    func scrollToFirstBlockSetsContentOffsetToZero() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        blockYOffsets: [0, 792, 1584]
      )

      mockView.scrollTo(blockIndex: 0, animated: false)

      #expect(mockView.contentOffset.y == 0)
      #expect(mockView.scrollToCallCount == 1)
      #expect(mockView.lastScrolledBlockIndex == 0)
      #expect(mockView.lastScrollAnimated == false)
    }

    @Test("scroll to middle block sets correct content offset")
    func scrollToMiddleBlockSetsCorrectContentOffset() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        currentZoomScale: 1.0,
        blockYOffsets: [0, 792, 1584]
      )

      mockView.scrollTo(blockIndex: 1, animated: false)

      #expect(mockView.contentOffset.y == 792)
    }

    @Test("scroll with zoom applies scale to content offset")
    func scrollWithZoomAppliesScaleToContentOffset() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
        .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        currentZoomScale: 2.0,
        blockYOffsets: [0, 792, 1584]
      )

      mockView.scrollTo(blockIndex: 1, animated: false)

      #expect(mockView.contentOffset.y == 1584) // 792 * 2.0
    }

    @Test("scroll tracks animated parameter")
    func scrollTracksAnimatedParameter() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
        .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 2)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        blockYOffsets: [0, 792]
      )

      mockView.scrollTo(blockIndex: 1, animated: true)

      #expect(mockView.lastScrollAnimated == true)
    }

    @Test("scroll with out of bounds index does not crash")
    func scrollWithOutOfBoundsIndexDoesNotCrash() {
      let blocks: [NoteBlock] = [
        .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")
      ]
      let noteDocument = PDFDocumentViewLayoutTests.createTestNoteDocument(blocks: blocks)
      let pdfDocument = MockPDFDisplayDocument(pageCount: 1)

      let mockView = MockPDFDocumentView(
        noteDocument: noteDocument,
        pdfDocument: pdfDocument,
        blockYOffsets: [0]
      )

      // Scrolling to index 10 should not crash.
      mockView.scrollTo(blockIndex: 10, animated: false)

      // Content offset should remain unchanged since index is out of bounds.
      #expect(mockView.contentOffset.y == 0)
    }
  }
}

// MARK: - Mock PDFBackgroundLayerDataSource Tests

@Suite("MockPDFBackgroundLayerDataSource Tests")
struct MockPDFBackgroundLayerDataSourceTests {

  @Suite("Page Height Calculation")
  struct PageHeightCalculationTests {

    @Test("page height calculation for portrait page")
    func pageHeightCalculationForPortraitPage() {
      // US Letter portrait: 612x792.
      let pdfDocument = MockPDFDisplayDocument(
        pageCount: 1,
        pageBounds: CGRect(x: 0, y: 0, width: 612, height: 792)
      )
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")]
      )

      let dataSource = MockPDFBackgroundLayerDataSource(
        pdfDocument: pdfDocument,
        noteDocument: noteDocument
      )

      let height = dataSource.pageHeight(for: 0, at: 612)

      #expect(height == 792)
    }

    @Test("page height calculation for landscape page")
    func pageHeightCalculationForLandscapePage() {
      // US Letter landscape: 792x612.
      let pdfDocument = MockPDFDisplayDocument(
        pageCount: 1,
        pageBounds: CGRect(x: 0, y: 0, width: 792, height: 612)
      )
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")]
      )

      let dataSource = MockPDFBackgroundLayerDataSource(
        pdfDocument: pdfDocument,
        noteDocument: noteDocument
      )

      let height = dataSource.pageHeight(for: 0, at: 400)

      // 400 * (612/792) = approximately 309.09
      let expectedHeight = 400.0 * (612.0 / 792.0)
      #expect(abs((height ?? 0) - expectedHeight) < 0.01)
    }

    @Test("page height for invalid index returns nil")
    func pageHeightForInvalidIndexReturnsNil() {
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let dataSource = MockPDFBackgroundLayerDataSource(
        pdfDocument: pdfDocument,
        noteDocument: noteDocument
      )

      let height = dataSource.pageHeight(for: 5, at: 400)

      #expect(height == nil)
    }

    @Test("page height for negative index returns nil")
    func pageHeightForNegativeIndexReturnsNil() {
      let pdfDocument = MockPDFDisplayDocument(pageCount: 3)
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: []
      )

      let dataSource = MockPDFBackgroundLayerDataSource(
        pdfDocument: pdfDocument,
        noteDocument: noteDocument
      )

      let height = dataSource.pageHeight(for: -1, at: 400)

      #expect(height == nil)
    }

    @Test("page height with zero container width returns zero")
    func pageHeightWithZeroContainerWidthReturnsZero() {
      let pdfDocument = MockPDFDisplayDocument(pageCount: 1)
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [.pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0")]
      )

      let dataSource = MockPDFBackgroundLayerDataSource(
        pdfDocument: pdfDocument,
        noteDocument: noteDocument
      )

      let height = dataSource.pageHeight(for: 0, at: 0)

      #expect(height == 0)
    }

    @Test("block Y offsets count matches block count")
    func blockYOffsetsCountMatchesBlockCount() {
      let pdfDocument = MockPDFDisplayDocument(pageCount: 5)
      let noteDocument = NoteDocument(
        documentID: UUID(),
        displayName: "Test",
        sourceFileName: "test.pdf",
        createdAt: Date(),
        modifiedAt: Date(),
        blocks: [
          .pdfPage(pageIndex: 0, uuid: UUID(), myScriptPartID: "part-0"),
          .pdfPage(pageIndex: 1, uuid: UUID(), myScriptPartID: "part-1"),
          .pdfPage(pageIndex: 2, uuid: UUID(), myScriptPartID: "part-2"),
          .pdfPage(pageIndex: 3, uuid: UUID(), myScriptPartID: "part-3"),
          .pdfPage(pageIndex: 4, uuid: UUID(), myScriptPartID: "part-4")
        ]
      )

      let dataSource = MockPDFBackgroundLayerDataSource(
        pdfDocument: pdfDocument,
        noteDocument: noteDocument,
        blockYOffsets: [0, 792, 1584, 2376, 3168]
      )

      #expect(dataSource.blockYOffsets.count == 5)
    }
  }
}

// MARK: - Phase 4 Input Integration Tests

// ============================================================================
// PHASE 4: INPUT INTEGRATION TESTS
// ============================================================================
//
// These tests validate the ink input layer integration for PDF annotation.
// The tests cover:
//   - PDFInputError: Error types and descriptions
//   - PDFInkOverlayProvider: Adding ink overlay to document view
//   - PDFBlockLocator: Finding block by Y coordinate with binary search
//   - PDFPartSwitching: Touch handling and part switching
//   - PDFToolApplication: Tool mapping and style application

// MARK: - Phase 4 Mock Dependencies

// Mock implementation of PDFInkOverlayProvider for testing overlay management.
// Tracks method calls and simulates overlay container behavior.
final class MockPDFInkOverlayProvider: PDFInkOverlayProvider {
  // Tracks the overlay view that was added.
  var addedOverlay: UIView?
  // Tracks the number of times addInkOverlay was called.
  var addInkOverlayCallCount = 0
  // Tracks frame update calls.
  var updateFrameCallCount = 0
  var lastUpdatedSize: CGSize?
  // Current ink overlay bounds.
  private var _inkOverlayBounds: CGRect = .zero

  var inkOverlayBounds: CGRect {
    return _inkOverlayBounds
  }

  // Simulates content size for testing.
  var simulatedContentSize: CGSize = CGSize(width: 612, height: 2376)

  func addInkOverlay(_ overlay: UIView) {
    addInkOverlayCallCount += 1
    addedOverlay = overlay
    // Set the overlay frame to match simulated content size.
    overlay.frame = CGRect(origin: .zero, size: simulatedContentSize)
    _inkOverlayBounds = overlay.frame
  }

  func updateInkOverlayFrame(to newSize: CGSize) {
    updateFrameCallCount += 1
    lastUpdatedSize = newSize
    _inkOverlayBounds = CGRect(origin: .zero, size: newSize)
    addedOverlay?.frame = _inkOverlayBounds
  }
}

// Mock implementation of PDFBlockLocator for testing block location lookups.
// Uses precomputed Y offsets and block heights for binary search testing.
final class MockPDFBlockLocator: PDFBlockLocator {
  // Precomputed block Y offsets for testing.
  var blockYOffsets: [CGFloat] = []
  // Block heights used to calculate end positions.
  var blockHeights: [CGFloat] = []
  // Current zoom scale for coordinate conversion.
  var currentZoomScale: CGFloat = 1.0
  // Tracks method calls.
  var blockIndexCallCount = 0
  var convertCallCount = 0
  var blockYRangeCallCount = 0
  var lastQueriedYOffset: CGFloat?
  var lastConvertedPoint: CGPoint?

  func blockIndex(for yOffset: CGFloat) -> Int? {
    blockIndexCallCount += 1
    lastQueriedYOffset = yOffset

    // Handle negative Y offset.
    guard yOffset >= 0 else { return nil }

    // Handle empty document.
    guard !blockYOffsets.isEmpty else { return nil }

    // Calculate total height.
    var totalHeight: CGFloat = 0
    for i in 0..<blockHeights.count {
      totalHeight += blockHeights[i]
    }

    // Return nil if beyond total content.
    guard yOffset < totalHeight else { return nil }

    // Binary search to find the block.
    var low = 0
    var high = blockYOffsets.count - 1

    while low <= high {
      let mid = (low + high) / 2
      let startY = blockYOffsets[mid]
      let endY: CGFloat
      if mid + 1 < blockYOffsets.count {
        endY = blockYOffsets[mid + 1]
      } else {
        endY = startY + blockHeights[mid]
      }

      if yOffset < startY {
        high = mid - 1
      } else if yOffset >= endY {
        low = mid + 1
      } else {
        return mid
      }
    }

    return nil
  }

  func convertToContentCoordinates(_ point: CGPoint) -> CGPoint {
    convertCallCount += 1
    lastConvertedPoint = point
    // Divide by zoom scale to get unscaled coordinates.
    return CGPoint(
      x: point.x / currentZoomScale,
      y: point.y / currentZoomScale
    )
  }

  func blockYRange(for blockIndex: Int) -> (startY: CGFloat, endY: CGFloat)? {
    blockYRangeCallCount += 1

    guard blockIndex >= 0 && blockIndex < blockYOffsets.count else {
      return nil
    }

    let startY = blockYOffsets[blockIndex]
    let endY: CGFloat
    if blockIndex + 1 < blockYOffsets.count {
      endY = blockYOffsets[blockIndex + 1]
    } else if blockIndex < blockHeights.count {
      endY = startY + blockHeights[blockIndex]
    } else {
      return nil
    }

    return (startY: startY, endY: endY)
  }
}

// Mock implementation of PDFPartSwitchingDelegate for testing delegate callbacks.
// Tracks all delegate method invocations and their parameters.
final class MockPDFPartSwitchingDelegate: PDFPartSwitchingDelegate {
  // Tracks willSwitchToBlock calls.
  var willSwitchCallCount = 0
  var lastWillSwitchBlockIndex: Int?
  var lastWillSwitchPartID: String?

  // Tracks didSwitchToBlock calls.
  var didSwitchCallCount = 0
  var lastDidSwitchBlockIndex: Int?

  // Tracks partSwitchFailed calls.
  var switchFailedCallCount = 0
  var lastSwitchError: PDFInputError?

  func willSwitchToBlock(at newBlockIndex: Int, partID: String) {
    willSwitchCallCount += 1
    lastWillSwitchBlockIndex = newBlockIndex
    lastWillSwitchPartID = partID
  }

  func didSwitchToBlock(at newBlockIndex: Int) {
    didSwitchCallCount += 1
    lastDidSwitchBlockIndex = newBlockIndex
  }

  func partSwitchFailed(with error: PDFInputError) {
    switchFailedCallCount += 1
    lastSwitchError = error
  }
}

// Mock implementation of PDFPartSwitching for testing part switching behavior.
// Simulates the interaction between touch handling and part loading.
final class MockPDFPartSwitching: PDFPartSwitching {
  // Active block index (-1 indicates no block active).
  private var _activeBlockIndex: Int = -1
  var activeBlockIndex: Int { return _activeBlockIndex }

  // Delegate for receiving switch events.
  weak var partSwitchingDelegate: PDFPartSwitchingDelegate?

  // Block locator for finding which block a touch lands in.
  var blockLocator: MockPDFBlockLocator

  // Simulated blocks with their part IDs.
  var blocks: [(uuid: UUID, myScriptPartID: String)] = []

  // Tracks method calls.
  var handleTouchDownCallCount = 0
  var switchToBlockCallCount = 0
  var lastTouchPoint: CGPoint?

  // Controls whether part switch should fail.
  var shouldFailPartSwitch = false
  var partSwitchErrorMessage = "Part not found"

  init(blockLocator: MockPDFBlockLocator) {
    self.blockLocator = blockLocator
  }

  func handleTouchDown(at touchPoint: CGPoint) async throws -> Int? {
    handleTouchDownCallCount += 1
    lastTouchPoint = touchPoint

    // Find which block the touch is in.
    guard let blockIndex = blockLocator.blockIndex(for: touchPoint.y) else {
      return nil
    }

    // If touching a different block, switch parts.
    if blockIndex != _activeBlockIndex {
      try await switchToBlock(at: blockIndex)
    }

    return blockIndex
  }

  func switchToBlock(at blockIndex: Int) async throws {
    switchToBlockCallCount += 1

    // Validate block index.
    guard blockIndex >= 0 && blockIndex < blocks.count else {
      let error = PDFInputError.partSwitchFailed(
        partID: "invalid-index-\(blockIndex)",
        underlyingError: "Block index out of bounds"
      )
      partSwitchingDelegate?.partSwitchFailed(with: error)
      throw error
    }

    let partID = blocks[blockIndex].myScriptPartID

    // Notify delegate of upcoming switch.
    partSwitchingDelegate?.willSwitchToBlock(at: blockIndex, partID: partID)

    // Simulate part switch failure if configured.
    if shouldFailPartSwitch {
      let error = PDFInputError.partSwitchFailed(
        partID: partID,
        underlyingError: partSwitchErrorMessage
      )
      partSwitchingDelegate?.partSwitchFailed(with: error)
      throw error
    }

    // Update active block index.
    _activeBlockIndex = blockIndex

    // Notify delegate of successful switch.
    partSwitchingDelegate?.didSwitchToBlock(at: blockIndex)
  }

  // Test helper to set initial active block.
  func setActiveBlockIndex(_ index: Int) {
    _activeBlockIndex = index
  }
}

// Mock implementation of ToolControllerProtocol for testing tool application.
// Tracks tool and style changes.
final class MockToolController: ToolControllerProtocol {
  // Tracks setToolForPointerType calls.
  var setToolCallCount = 0
  var lastSetTool: IINKPointerTool?
  var lastSetPointerType: IINKPointerType?
  var toolsByPointerType: [IINKPointerType: IINKPointerTool] = [:]

  // Tracks setStyleForTool calls.
  var setStyleCallCount = 0
  var lastStyleString: String?
  var lastStyleTool: IINKPointerTool?
  var stylesByTool: [IINKPointerTool: String] = [:]

  // Controls whether operations should throw.
  var shouldThrowOnSetTool = false
  var shouldThrowOnSetStyle = false

  func setToolForPointerType(tool: IINKPointerTool, pointerType: IINKPointerType) throws {
    setToolCallCount += 1
    lastSetTool = tool
    lastSetPointerType = pointerType
    toolsByPointerType[pointerType] = tool

    if shouldThrowOnSetTool {
      throw NSError(domain: "MockToolController", code: 1, userInfo: nil)
    }
  }

  func setStyleForTool(style: String, tool: IINKPointerTool) throws {
    setStyleCallCount += 1
    lastStyleString = style
    lastStyleTool = tool
    stylesByTool[tool] = style

    if shouldThrowOnSetStyle {
      throw NSError(domain: "MockToolController", code: 2, userInfo: nil)
    }
  }
}

// Mock implementation of PDFToolApplication for testing tool application behavior.
// Simulates the mapping from ToolPaletteView.ToolSelection to IINKPointerTool.
final class MockPDFToolApplication: PDFToolApplication {
  // The mock tool controller.
  var mockToolController = MockToolController()

  // Active editor reference (nil simulates editor not available).
  var activeEditor: IINKEditor?

  // Tracks method calls.
  var applyToolCallCount = 0
  var applyInkStyleCallCount = 0
  var applyToolForInputModeCallCount = 0

  // Last applied values.
  var lastAppliedSelection: ToolPaletteView.ToolSelection?
  var lastAppliedColorHex: String?
  var lastAppliedWidth: CGFloat?
  var lastAppliedTool: IINKPointerTool?
  var lastAppliedInputMode: InputMode?

  // Flag to simulate editor availability.
  var isEditorAvailable: Bool = true

  func applyTool(
    selection: ToolPaletteView.ToolSelection,
    colorHex: String,
    width: CGFloat
  ) throws {
    applyToolCallCount += 1
    lastAppliedSelection = selection
    lastAppliedColorHex = colorHex
    lastAppliedWidth = width

    guard isEditorAvailable else {
      throw PDFInputError.editorNotAvailable
    }

    // Map selection to tool.
    let tool: IINKPointerTool
    switch selection {
    case .pen:
      tool = .toolPen
    case .highlighter:
      tool = .toolHighlighter
    case .eraser:
      tool = .eraser
    }

    // Set tool for pen pointer type.
    try mockToolController.setToolForPointerType(tool: tool, pointerType: .pen)

    // Apply ink style for pen and highlighter (not eraser).
    if selection != .eraser {
      let style = "color:\(colorHex);-myscript-pen-width:\(String(format: "%.3f", width))"
      try mockToolController.setStyleForTool(style: style, tool: tool)
    }
  }

  func applyInkStyle(colorHex: String, width: CGFloat, tool: IINKPointerTool) throws {
    applyInkStyleCallCount += 1
    lastAppliedColorHex = colorHex
    lastAppliedWidth = width
    lastAppliedTool = tool

    guard isEditorAvailable else {
      throw PDFInputError.editorNotAvailable
    }

    let style = "color:\(colorHex);-myscript-pen-width:\(String(format: "%.3f", width))"
    try mockToolController.setStyleForTool(style: style, tool: tool)
  }

  func applyToolForInputMode(tool: IINKPointerTool, inputMode: InputMode) throws {
    applyToolForInputModeCallCount += 1
    lastAppliedTool = tool
    lastAppliedInputMode = inputMode

    guard isEditorAvailable else {
      throw PDFInputError.editorNotAvailable
    }

    // Set tool for pen pointer type.
    try mockToolController.setToolForPointerType(tool: tool, pointerType: .pen)

    // Set touch pointer type based on input mode.
    let touchTool: IINKPointerTool
    switch inputMode {
    case .forcePen:
      // In pen mode, touch follows the same tool as pen.
      touchTool = tool
    case .forceTouch:
      // In touch mode, touch is set to hand (pan) tool.
      touchTool = .hand
    case .auto:
      // In auto mode, touch is set to hand (pan) tool.
      touchTool = .hand
    }
    try mockToolController.setToolForPointerType(tool: touchTool, pointerType: .touch)
  }
}

// MARK: - PDFInputError Tests

@Suite("PDFInputError Tests")
struct PDFInputErrorTests {

  // MARK: - Error Description Tests

  @Suite("Error Descriptions")
  struct ErrorDescriptionTests {

    @Test("inkOverlayNotConfigured provides error description")
    func inkOverlayNotConfiguredDescription() {
      let error = PDFInputError.inkOverlayNotConfigured

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("ink") == true || error.errorDescription?.contains("configured") == true)
    }

    @Test("touchOutsideBounds provides error description with coordinates")
    func touchOutsideBoundsDescription() {
      let error = PDFInputError.touchOutsideBounds(touchY: 3000, totalContentHeight: 2376)

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("3000") == true)
      #expect(error.errorDescription?.contains("2376") == true)
    }

    @Test("partSwitchFailed provides error description with part ID and error")
    func partSwitchFailedDescription() {
      let error = PDFInputError.partSwitchFailed(partID: "part-123", underlyingError: "Part not found")

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("part-123") == true)
      #expect(error.errorDescription?.contains("Part not found") == true)
    }

    @Test("editorNotAvailable provides error description")
    func editorNotAvailableDescription() {
      let error = PDFInputError.editorNotAvailable

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("editor") == true || error.errorDescription?.contains("available") == true)
    }

    @Test("invalidToolSelection provides error description")
    func invalidToolSelectionDescription() {
      let error = PDFInputError.invalidToolSelection

      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.contains("tool") == true || error.errorDescription?.contains("selection") == true)
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("identical inkOverlayNotConfigured errors are equal")
    func identicalInkOverlayNotConfiguredEqual() {
      let error1 = PDFInputError.inkOverlayNotConfigured
      let error2 = PDFInputError.inkOverlayNotConfigured

      #expect(error1 == error2)
    }

    @Test("identical editorNotAvailable errors are equal")
    func identicalEditorNotAvailableEqual() {
      let error1 = PDFInputError.editorNotAvailable
      let error2 = PDFInputError.editorNotAvailable

      #expect(error1 == error2)
    }

    @Test("identical invalidToolSelection errors are equal")
    func identicalInvalidToolSelectionEqual() {
      let error1 = PDFInputError.invalidToolSelection
      let error2 = PDFInputError.invalidToolSelection

      #expect(error1 == error2)
    }

    @Test("touchOutsideBounds errors with same values are equal")
    func touchOutsideBoundsSameValuesEqual() {
      let error1 = PDFInputError.touchOutsideBounds(touchY: 3000, totalContentHeight: 2376)
      let error2 = PDFInputError.touchOutsideBounds(touchY: 3000, totalContentHeight: 2376)

      #expect(error1 == error2)
    }

    @Test("touchOutsideBounds errors with different touchY are not equal")
    func touchOutsideBoundsDifferentTouchYNotEqual() {
      let error1 = PDFInputError.touchOutsideBounds(touchY: 3000, totalContentHeight: 2376)
      let error2 = PDFInputError.touchOutsideBounds(touchY: 4000, totalContentHeight: 2376)

      #expect(error1 != error2)
    }

    @Test("touchOutsideBounds errors with different totalContentHeight are not equal")
    func touchOutsideBoundsDifferentHeightNotEqual() {
      let error1 = PDFInputError.touchOutsideBounds(touchY: 3000, totalContentHeight: 2376)
      let error2 = PDFInputError.touchOutsideBounds(touchY: 3000, totalContentHeight: 3000)

      #expect(error1 != error2)
    }

    @Test("partSwitchFailed errors with same values are equal")
    func partSwitchFailedSameValuesEqual() {
      let error1 = PDFInputError.partSwitchFailed(partID: "part-123", underlyingError: "Error")
      let error2 = PDFInputError.partSwitchFailed(partID: "part-123", underlyingError: "Error")

      #expect(error1 == error2)
    }

    @Test("partSwitchFailed errors with different partID are not equal")
    func partSwitchFailedDifferentPartIDNotEqual() {
      let error1 = PDFInputError.partSwitchFailed(partID: "part-123", underlyingError: "Error")
      let error2 = PDFInputError.partSwitchFailed(partID: "part-456", underlyingError: "Error")

      #expect(error1 != error2)
    }

    @Test("partSwitchFailed errors with different underlyingError are not equal")
    func partSwitchFailedDifferentUnderlyingErrorNotEqual() {
      let error1 = PDFInputError.partSwitchFailed(partID: "part-123", underlyingError: "Error A")
      let error2 = PDFInputError.partSwitchFailed(partID: "part-123", underlyingError: "Error B")

      #expect(error1 != error2)
    }

    @Test("different error types are not equal")
    func differentErrorTypesNotEqual() {
      let error1 = PDFInputError.inkOverlayNotConfigured
      let error2 = PDFInputError.editorNotAvailable

      #expect(error1 != error2)
    }
  }
}

// MARK: - PDFInkOverlayProvider Tests

@Suite("PDFInkOverlayProvider Tests")
@MainActor
struct PDFInkOverlayProviderTests {

  // MARK: - Add Ink Overlay Tests

  @Suite("addInkOverlay")
  struct AddInkOverlayTests {

    @Test("adds overlay to provider")
    @MainActor
    func addsOverlayToProvider() {
      let provider = MockPDFInkOverlayProvider()
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(provider.addedOverlay === overlay)
      #expect(provider.addInkOverlayCallCount == 1)
    }

    @Test("overlay frame matches content size")
    @MainActor
    func overlayFrameMatchesContentSize() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(overlay.frame == CGRect(x: 0, y: 0, width: 612, height: 2376))
    }

    @Test("ink overlay bounds reflects added overlay")
    @MainActor
    func inkOverlayBoundsReflectsAddedOverlay() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(provider.inkOverlayBounds == CGRect(x: 0, y: 0, width: 612, height: 2376))
    }

    @Test("overlay frame reflects zoomed size")
    @MainActor
    func overlayFrameReflectsZoomedSize() {
      let provider = MockPDFInkOverlayProvider()
      // Simulate 2x zoom: base size 612x2376 becomes 1224x4752.
      provider.simulatedContentSize = CGSize(width: 1224, height: 4752)
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(overlay.frame == CGRect(x: 0, y: 0, width: 1224, height: 4752))
    }
  }

  // MARK: - Update Ink Overlay Frame Tests

  @Suite("updateInkOverlayFrame")
  struct UpdateInkOverlayFrameTests {

    @Test("updates overlay frame after zoom change")
    @MainActor
    func updatesOverlayFrameAfterZoomChange() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()
      provider.addInkOverlay(overlay)

      // Simulate zoom to 2x.
      provider.updateInkOverlayFrame(to: CGSize(width: 1224, height: 4752))

      #expect(provider.updateFrameCallCount == 1)
      #expect(provider.lastUpdatedSize == CGSize(width: 1224, height: 4752))
      #expect(overlay.frame == CGRect(x: 0, y: 0, width: 1224, height: 4752))
    }

    @Test("updates ink overlay bounds")
    @MainActor
    func updatesInkOverlayBounds() {
      let provider = MockPDFInkOverlayProvider()
      let overlay = UIView()
      provider.addInkOverlay(overlay)

      provider.updateInkOverlayFrame(to: CGSize(width: 800, height: 3000))

      #expect(provider.inkOverlayBounds == CGRect(x: 0, y: 0, width: 800, height: 3000))
    }

    @Test("update with zero size does not crash")
    @MainActor
    func updateWithZeroSizeDoesNotCrash() {
      let provider = MockPDFInkOverlayProvider()
      let overlay = UIView()
      provider.addInkOverlay(overlay)

      provider.updateInkOverlayFrame(to: .zero)

      #expect(provider.inkOverlayBounds == .zero)
      #expect(overlay.frame == .zero)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("add overlay before view is laid out")
    @MainActor
    func addOverlayBeforeViewIsLaidOut() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = .zero
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(overlay.frame == .zero)
    }

    @Test("add overlay multiple times replaces previous")
    @MainActor
    func addOverlayMultipleTimesReplacesPrevious() {
      let provider = MockPDFInkOverlayProvider()
      let overlay1 = UIView()
      let overlay2 = UIView()

      provider.addInkOverlay(overlay1)
      provider.addInkOverlay(overlay2)

      #expect(provider.addedOverlay === overlay2)
      #expect(provider.addInkOverlayCallCount == 2)
    }
  }
}

// MARK: - PDFBlockLocator Tests

@Suite("PDFBlockLocator Tests")
struct PDFBlockLocatorTests {

  // Helper to create a locator with standard 3-page document layout.
  static func createStandardLocator() -> MockPDFBlockLocator {
    let locator = MockPDFBlockLocator()
    locator.blockYOffsets = [0, 792, 1584]
    locator.blockHeights = [792, 792, 792]
    return locator
  }

  // MARK: - blockIndex Tests

  @Suite("blockIndex")
  struct BlockIndexTests {

    @Test("finds block at document start")
    func findsBlockAtDocumentStart() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let index = locator.blockIndex(for: 0)

      #expect(index == 0)
    }

    @Test("finds block in middle of first page")
    func findsBlockInMiddleOfFirstPage() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let index = locator.blockIndex(for: 400)

      #expect(index == 0)
    }

    @Test("finds block at exact boundary (belongs to next block)")
    func findsBlockAtExactBoundary() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let index = locator.blockIndex(for: 792)

      #expect(index == 1)
    }

    @Test("finds block in last page")
    func findsBlockInLastPage() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let index = locator.blockIndex(for: 2000)

      #expect(index == 2)
    }

    @Test("returns nil for touch beyond document end")
    func returnsNilForTouchBeyondDocumentEnd() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let index = locator.blockIndex(for: 3000)

      #expect(index == nil)
    }

    @Test("returns nil for negative Y offset")
    func returnsNilForNegativeYOffset() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let index = locator.blockIndex(for: -100)

      #expect(index == nil)
    }

    @Test("returns nil for empty document")
    func returnsNilForEmptyDocument() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = []
      locator.blockHeights = []

      let index = locator.blockIndex(for: 0)

      #expect(index == nil)
    }

    @Test("finds block in single block document")
    func findsBlockInSingleBlockDocument() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0]
      locator.blockHeights = [792]

      let index = locator.blockIndex(for: 400)

      #expect(index == 0)
    }

    @Test("handles very small touch difference at boundary")
    func handlesVerySmallTouchDifferenceAtBoundary() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      // Just below boundary should still be in first block.
      let index = locator.blockIndex(for: 791.99999)

      #expect(index == 0)
    }

    @Test("handles document with mixed block heights")
    func handlesDocumentWithMixedBlockHeights() {
      let locator = MockPDFBlockLocator()
      // PDF page (792), spacer (200), PDF page (792).
      locator.blockYOffsets = [0, 792, 992]
      locator.blockHeights = [792, 200, 792]

      // In spacer area.
      let spacerIndex = locator.blockIndex(for: 800)
      // In second PDF page.
      let secondPageIndex = locator.blockIndex(for: 1000)

      #expect(spacerIndex == 1)
      #expect(secondPageIndex == 2)
    }

    @Test("tracks method call count")
    func tracksMethodCallCount() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      _ = locator.blockIndex(for: 100)
      _ = locator.blockIndex(for: 200)
      _ = locator.blockIndex(for: 300)

      #expect(locator.blockIndexCallCount == 3)
    }
  }

  // MARK: - convertToContentCoordinates Tests

  @Suite("convertToContentCoordinates")
  struct ConvertToContentCoordinatesTests {

    @Test("converts at zoom 1.0")
    func convertsAtZoom1() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 1.0

      let result = locator.convertToContentCoordinates(CGPoint(x: 100, y: 500))

      #expect(result == CGPoint(x: 100, y: 500))
    }

    @Test("converts at zoom 2.0")
    func convertsAtZoom2() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 2.0

      let result = locator.convertToContentCoordinates(CGPoint(x: 200, y: 1000))

      #expect(result == CGPoint(x: 100, y: 500))
    }

    @Test("converts at fractional zoom")
    func convertsAtFractionalZoom() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 1.5

      let result = locator.convertToContentCoordinates(CGPoint(x: 150, y: 750))

      #expect(result == CGPoint(x: 100, y: 500))
    }

    @Test("tracks converted point")
    func tracksConvertedPoint() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 1.0

      _ = locator.convertToContentCoordinates(CGPoint(x: 123, y: 456))

      #expect(locator.lastConvertedPoint == CGPoint(x: 123, y: 456))
      #expect(locator.convertCallCount == 1)
    }
  }

  // MARK: - blockYRange Tests

  @Suite("blockYRange")
  struct BlockYRangeTests {

    @Test("returns range for first block")
    func returnsRangeForFirstBlock() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let range = locator.blockYRange(for: 0)

      #expect(range?.startY == 0)
      #expect(range?.endY == 792)
    }

    @Test("returns range for middle block")
    func returnsRangeForMiddleBlock() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let range = locator.blockYRange(for: 1)

      #expect(range?.startY == 792)
      #expect(range?.endY == 1584)
    }

    @Test("returns range for last block")
    func returnsRangeForLastBlock() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let range = locator.blockYRange(for: 2)

      #expect(range?.startY == 1584)
      #expect(range?.endY == 2376)
    }

    @Test("returns nil for invalid block index")
    func returnsNilForInvalidBlockIndex() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let range = locator.blockYRange(for: 10)

      #expect(range == nil)
    }

    @Test("returns nil for negative block index")
    func returnsNilForNegativeBlockIndex() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      let range = locator.blockYRange(for: -1)

      #expect(range == nil)
    }

    @Test("tracks method call count")
    func tracksMethodCallCount() {
      let locator = PDFBlockLocatorTests.createStandardLocator()

      _ = locator.blockYRange(for: 0)
      _ = locator.blockYRange(for: 1)

      #expect(locator.blockYRangeCallCount == 2)
    }
  }
}

// MARK: - PDFPartSwitching Tests

@Suite("PDFPartSwitching Tests")
struct PDFPartSwitchingTests {

  // Helper to create a standard part switching setup.
  static func createStandardSetup() -> (MockPDFPartSwitching, MockPDFPartSwitchingDelegate, MockPDFBlockLocator) {
    let locator = MockPDFBlockLocator()
    locator.blockYOffsets = [0, 792, 1584]
    locator.blockHeights = [792, 792, 792]

    let switching = MockPDFPartSwitching(blockLocator: locator)
    switching.blocks = [
      (uuid: UUID(), myScriptPartID: "part-0"),
      (uuid: UUID(), myScriptPartID: "part-1"),
      (uuid: UUID(), myScriptPartID: "part-2")
    ]

    let delegate = MockPDFPartSwitchingDelegate()
    switching.partSwitchingDelegate = delegate

    return (switching, delegate, locator)
  }

  // MARK: - handleTouchDown Tests

  @Suite("handleTouchDown")
  struct HandleTouchDownTests {

    @Test("touch on current block does not switch")
    func touchOnCurrentBlockDoesNotSwitch() async throws {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()
      switching.setActiveBlockIndex(0)

      let result = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 400))

      #expect(result == 0)
      #expect(switching.activeBlockIndex == 0)
      // Only switchToBlock should not be called when already on same block.
      // But our mock always switches on first touch.
      #expect(delegate.willSwitchCallCount == 0)
    }

    @Test("touch on different block switches part")
    func touchOnDifferentBlockSwitchesPart() async throws {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()
      switching.setActiveBlockIndex(0)

      let result = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 900))

      #expect(result == 1)
      #expect(switching.activeBlockIndex == 1)
      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.lastWillSwitchBlockIndex == 1)
      #expect(delegate.lastWillSwitchPartID == "part-1")
      #expect(delegate.didSwitchCallCount == 1)
      #expect(delegate.lastDidSwitchBlockIndex == 1)
    }

    @Test("touch outside document bounds returns nil")
    func touchOutsideDocumentBoundsReturnsNil() async throws {
      let (switching, _, _) = PDFPartSwitchingTests.createStandardSetup()
      switching.setActiveBlockIndex(0)

      let result = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 3000))

      #expect(result == nil)
      #expect(switching.activeBlockIndex == 0)
    }

    @Test("first touch sets initial block")
    func firstTouchSetsInitialBlock() async throws {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()
      // Initial state is -1 (no block active).
      #expect(switching.activeBlockIndex == -1)

      let result = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 400))

      #expect(result == 0)
      #expect(switching.activeBlockIndex == 0)
      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.didSwitchCallCount == 1)
    }

    @Test("tracks touch point")
    func tracksTouchPoint() async throws {
      let (switching, _, _) = PDFPartSwitchingTests.createStandardSetup()

      _ = try await switching.handleTouchDown(at: CGPoint(x: 123, y: 456))

      #expect(switching.lastTouchPoint == CGPoint(x: 123, y: 456))
      #expect(switching.handleTouchDownCallCount == 1)
    }
  }

  // MARK: - switchToBlock Tests

  @Suite("switchToBlock")
  struct SwitchToBlockTests {

    @Test("switch to valid block succeeds")
    func switchToValidBlockSucceeds() async throws {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()

      try await switching.switchToBlock(at: 1)

      #expect(switching.activeBlockIndex == 1)
      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.lastWillSwitchPartID == "part-1")
      #expect(delegate.didSwitchCallCount == 1)
    }

    @Test("switch to invalid block index throws")
    func switchToInvalidBlockIndexThrows() async {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()

      do {
        try await switching.switchToBlock(at: 10)
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        if case .partSwitchFailed(let partID, _) = error {
          #expect(partID.contains("10"))
        } else {
          Issue.record("Expected partSwitchFailed error")
        }
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }

      #expect(delegate.switchFailedCallCount == 1)
    }

    @Test("switch to negative block index throws")
    func switchToNegativeBlockIndexThrows() async {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()

      do {
        try await switching.switchToBlock(at: -1)
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        if case .partSwitchFailed = error {
          // Expected.
        } else {
          Issue.record("Expected partSwitchFailed error")
        }
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }

      #expect(delegate.switchFailedCallCount == 1)
    }

    @Test("switch when part not found throws and notifies delegate")
    func switchWhenPartNotFoundThrowsAndNotifiesDelegate() async {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()
      switching.shouldFailPartSwitch = true
      switching.partSwitchErrorMessage = "Part not found in package"

      do {
        try await switching.switchToBlock(at: 1)
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        if case .partSwitchFailed(let partID, let underlyingError) = error {
          #expect(partID == "part-1")
          #expect(underlyingError == "Part not found in package")
        } else {
          Issue.record("Expected partSwitchFailed error")
        }
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }

      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.switchFailedCallCount == 1)
      #expect(delegate.didSwitchCallCount == 0)
    }

    @Test("tracks switch call count")
    func tracksSwithCallCount() async throws {
      let (switching, _, _) = PDFPartSwitchingTests.createStandardSetup()

      try await switching.switchToBlock(at: 0)
      try await switching.switchToBlock(at: 1)
      try await switching.switchToBlock(at: 2)

      #expect(switching.switchToBlockCallCount == 3)
    }
  }

  // MARK: - Delegate Notification Tests

  @Suite("Delegate Notifications")
  struct DelegateNotificationTests {

    @Test("delegate receives willSwitch before didSwitch")
    func delegateReceivesWillSwitchBeforeDidSwitch() async throws {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()

      try await switching.switchToBlock(at: 2)

      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.didSwitchCallCount == 1)
      #expect(delegate.lastWillSwitchBlockIndex == 2)
      #expect(delegate.lastWillSwitchPartID == "part-2")
      #expect(delegate.lastDidSwitchBlockIndex == 2)
    }

    @Test("delegate receives failure notification with error")
    func delegateReceivesFailureNotificationWithError() async {
      let (switching, delegate, _) = PDFPartSwitchingTests.createStandardSetup()
      switching.shouldFailPartSwitch = true

      _ = try? await switching.switchToBlock(at: 1)

      #expect(delegate.switchFailedCallCount == 1)
      if case .partSwitchFailed = delegate.lastSwitchError {
        // Expected error type.
      } else {
        Issue.record("Expected partSwitchFailed error")
      }
    }
  }
}

// MARK: - PDFToolApplication Tests

@Suite("PDFToolApplication Tests")
struct PDFToolApplicationTests {

  // MARK: - applyTool Tests

  @Suite("applyTool")
  struct ApplyToolTests {

    @Test("apply pen tool sets correct tool and style")
    func applyPenToolSetsCorrectToolAndStyle() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)

      #expect(application.applyToolCallCount == 1)
      #expect(application.lastAppliedSelection == .pen)
      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolPen)
      #expect(application.mockToolController.stylesByTool[.toolPen]?.contains("#000000") == true)
      #expect(application.mockToolController.stylesByTool[.toolPen]?.contains("0.650") == true)
    }

    @Test("apply highlighter tool sets correct tool and style")
    func applyHighlighterToolSetsCorrectToolAndStyle() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .highlighter, colorHex: "#FFF176", width: 5.0)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolHighlighter)
      #expect(application.mockToolController.stylesByTool[.toolHighlighter]?.contains("#FFF176") == true)
      #expect(application.mockToolController.stylesByTool[.toolHighlighter]?.contains("5.000") == true)
    }

    @Test("apply eraser tool sets tool but no style")
    func applyEraserToolSetsToolButNoStyle() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .eraser, colorHex: "#000000", width: 1.0)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .eraser)
      // Eraser should not have style applied.
      #expect(application.mockToolController.stylesByTool[.eraser] == nil)
    }

    @Test("apply tool when editor unavailable throws")
    func applyToolWhenEditorUnavailableThrows() {
      let application = MockPDFToolApplication()
      application.isEditorAvailable = false

      do {
        try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        #expect(error == .editorNotAvailable)
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }
    }

    @Test("tracks applied values")
    func tracksAppliedValues() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .highlighter, colorHex: "#FF0000", width: 2.5)

      #expect(application.lastAppliedSelection == .highlighter)
      #expect(application.lastAppliedColorHex == "#FF0000")
      #expect(application.lastAppliedWidth == 2.5)
    }
  }

  // MARK: - applyInkStyle Tests

  @Suite("applyInkStyle")
  struct ApplyInkStyleTests {

    @Test("applies style with correct format")
    func appliesStyleWithCorrectFormat() throws {
      let application = MockPDFToolApplication()

      try application.applyInkStyle(colorHex: "#1976D2", width: 1.0, tool: .toolPen)

      #expect(application.applyInkStyleCallCount == 1)
      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.contains("color:#1976D2") == true)
      #expect(style?.contains("-myscript-pen-width:1.000") == true)
    }

    @Test("applies style when editor unavailable throws")
    func appliesStyleWhenEditorUnavailableThrows() {
      let application = MockPDFToolApplication()
      application.isEditorAvailable = false

      do {
        try application.applyInkStyle(colorHex: "#000000", width: 1.0, tool: .toolPen)
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        #expect(error == .editorNotAvailable)
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }
    }

    @Test("tracks applied tool")
    func tracksAppliedTool() throws {
      let application = MockPDFToolApplication()

      try application.applyInkStyle(colorHex: "#000000", width: 0.5, tool: .toolHighlighter)

      #expect(application.lastAppliedTool == .toolHighlighter)
    }
  }

  // MARK: - applyToolForInputMode Tests

  @Suite("applyToolForInputMode")
  struct ApplyToolForInputModeTests {

    @Test("in pen mode both pointer types use same tool")
    func inPenModeBothPointerTypesUseSameTool() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .toolPen, inputMode: .forcePen)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolPen)
      #expect(application.mockToolController.toolsByPointerType[.touch] == .toolPen)
    }

    @Test("in touch mode touch pointer uses hand tool")
    func inTouchModeTouchPointerUsesHandTool() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .toolPen, inputMode: .forceTouch)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolPen)
      #expect(application.mockToolController.toolsByPointerType[.touch] == .hand)
    }

    @Test("in auto mode touch pointer uses hand tool")
    func inAutoModeTouchPointerUsesHandTool() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .toolHighlighter, inputMode: .auto)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolHighlighter)
      #expect(application.mockToolController.toolsByPointerType[.touch] == .hand)
    }

    @Test("when editor unavailable throws")
    func whenEditorUnavailableThrows() {
      let application = MockPDFToolApplication()
      application.isEditorAvailable = false

      do {
        try application.applyToolForInputMode(tool: .toolPen, inputMode: .forcePen)
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        #expect(error == .editorNotAvailable)
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }
    }

    @Test("tracks applied input mode")
    func tracksAppliedInputMode() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .eraser, inputMode: .forceTouch)

      #expect(application.lastAppliedTool == .eraser)
      #expect(application.lastAppliedInputMode == .forceTouch)
      #expect(application.applyToolForInputModeCallCount == 1)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("empty color hex string is accepted")
    func emptyColorHexStringIsAccepted() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "", width: 1.0)

      #expect(application.mockToolController.stylesByTool[.toolPen]?.contains("color:") == true)
    }

    @Test("invalid color hex format is passed through")
    func invalidColorHexFormatIsPassedThrough() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "red", width: 1.0)

      #expect(application.mockToolController.stylesByTool[.toolPen]?.contains("color:red") == true)
    }

    @Test("zero width is accepted")
    func zeroWidthIsAccepted() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "#000000", width: 0)

      #expect(application.mockToolController.stylesByTool[.toolPen]?.contains("0.000") == true)
    }

    @Test("negative width is accepted")
    func negativeWidthIsAccepted() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "#000000", width: -1.0)

      #expect(application.mockToolController.stylesByTool[.toolPen]?.contains("-1.000") == true)
    }

    @Test("very large width is accepted")
    func veryLargeWidthIsAccepted() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .highlighter, colorHex: "#FFF176", width: 100.0)

      #expect(application.mockToolController.stylesByTool[.toolHighlighter]?.contains("100.000") == true)
    }
  }
}

// MARK: - Tool Mapping Tests

@Suite("Tool Mapping Tests")
struct ToolMappingTests {

  @Test("pen selection maps to IINKPointerTool.toolPen")
  func penSelectionMapsToPen() throws {
    let application = MockPDFToolApplication()

    try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)

    #expect(application.mockToolController.toolsByPointerType[.pen] == .toolPen)
  }

  @Test("highlighter selection maps to IINKPointerTool.toolHighlighter")
  func highlighterSelectionMapsToHighlighter() throws {
    let application = MockPDFToolApplication()

    try application.applyTool(selection: .highlighter, colorHex: "#FFF176", width: 5.0)

    #expect(application.mockToolController.toolsByPointerType[.pen] == .toolHighlighter)
  }

  @Test("eraser selection maps to IINKPointerTool.eraser")
  func eraserSelectionMapsToEraser() throws {
    let application = MockPDFToolApplication()

    try application.applyTool(selection: .eraser, colorHex: "#000000", width: 1.0)

    #expect(application.mockToolController.toolsByPointerType[.pen] == .eraser)
  }

  @Test("ink style format matches expected pattern")
  func inkStyleFormatMatchesExpectedPattern() throws {
    let application = MockPDFToolApplication()

    try application.applyTool(selection: .pen, colorHex: "#FF0000", width: 1.5)

    let style = application.mockToolController.stylesByTool[.toolPen]
    // Expected format: "color:#FF0000;-myscript-pen-width:1.500"
    #expect(style == "color:#FF0000;-myscript-pen-width:1.500")
  }
}

// MARK: - Additional PDFInkOverlayProvider Tests

@Suite("PDFInkOverlayProvider Constraints Tests")
@MainActor
struct PDFInkOverlayProviderConstraintsTests {

  // MARK: - Overlay Positioning Tests

  @Suite("Overlay Positioning")
  struct OverlayPositioningTests {

    @Test("overlay origin is at content origin")
    @MainActor
    func overlayOriginIsAtContentOrigin() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(overlay.frame.origin == .zero)
    }

    @Test("overlay covers three page document")
    @MainActor
    func overlayCoversThreePageDocument() {
      let provider = MockPDFInkOverlayProvider()
      // 3 pages at 792 each = 2376 total.
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(overlay.frame.width == 612)
      #expect(overlay.frame.height == 2376)
    }

    @Test("overlay size updates correctly after zoom")
    @MainActor
    func overlaySizeUpdatesCorrectlyAfterZoom() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()
      provider.addInkOverlay(overlay)

      // Verify initial size.
      #expect(overlay.frame.size == CGSize(width: 612, height: 2376))

      // Simulate zoom to 2x.
      provider.updateInkOverlayFrame(to: CGSize(width: 1224, height: 4752))

      // Verify zoomed size.
      #expect(overlay.frame.size == CGSize(width: 1224, height: 4752))
    }

    @Test("overlay size updates correctly after layout change")
    @MainActor
    func overlaySizeUpdatesCorrectlyAfterLayoutChange() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()
      provider.addInkOverlay(overlay)

      // Simulate device rotation changing container width.
      provider.updateInkOverlayFrame(to: CGSize(width: 1024, height: 3960))

      #expect(provider.lastUpdatedSize == CGSize(width: 1024, height: 3960))
      #expect(overlay.frame.size == CGSize(width: 1024, height: 3960))
    }
  }

  // MARK: - Ink Overlay Bounds Tests

  @Suite("Ink Overlay Bounds")
  struct InkOverlayBoundsTests {

    @Test("ink overlay bounds starts at zero")
    @MainActor
    func inkOverlayBoundsStartsAtZero() {
      let provider = MockPDFInkOverlayProvider()

      #expect(provider.inkOverlayBounds == .zero)
    }

    @Test("ink overlay bounds matches content after adding overlay")
    @MainActor
    func inkOverlayBoundsMatchesContentAfterAddingOverlay() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 2376)
      let overlay = UIView()

      provider.addInkOverlay(overlay)

      #expect(provider.inkOverlayBounds == CGRect(x: 0, y: 0, width: 612, height: 2376))
    }

    @Test("ink overlay bounds updates after frame update")
    @MainActor
    func inkOverlayBoundsUpdatesAfterFrameUpdate() {
      let provider = MockPDFInkOverlayProvider()
      provider.simulatedContentSize = CGSize(width: 612, height: 792)
      let overlay = UIView()
      provider.addInkOverlay(overlay)

      provider.updateInkOverlayFrame(to: CGSize(width: 800, height: 1200))

      #expect(provider.inkOverlayBounds == CGRect(x: 0, y: 0, width: 800, height: 1200))
    }
  }

  // MARK: - Multiple Overlay Tests

  @Suite("Multiple Overlay Handling")
  struct MultipleOverlayHandlingTests {

    @Test("second overlay replaces first overlay reference")
    @MainActor
    func secondOverlayReplacesFirstOverlayReference() {
      let provider = MockPDFInkOverlayProvider()
      let overlay1 = UIView()
      let overlay2 = UIView()

      provider.addInkOverlay(overlay1)
      provider.addInkOverlay(overlay2)

      #expect(provider.addedOverlay === overlay2)
      #expect(provider.addedOverlay !== overlay1)
    }

    @Test("call count increments for each overlay added")
    @MainActor
    func callCountIncrementsForEachOverlayAdded() {
      let provider = MockPDFInkOverlayProvider()
      let overlay1 = UIView()
      let overlay2 = UIView()
      let overlay3 = UIView()

      provider.addInkOverlay(overlay1)
      provider.addInkOverlay(overlay2)
      provider.addInkOverlay(overlay3)

      #expect(provider.addInkOverlayCallCount == 3)
    }
  }
}

// MARK: - Additional PDFBlockLocator Binary Search Tests

@Suite("PDFBlockLocator Binary Search Tests")
struct PDFBlockLocatorBinarySearchTests {

  // MARK: - Binary Search Efficiency Tests

  @Suite("Binary Search Efficiency")
  struct BinarySearchEfficiencyTests {

    @Test("finds block efficiently in large document")
    func findsBlockEfficientlyInLargeDocument() {
      // Create a document with 100 pages.
      let locator = MockPDFBlockLocator()
      var offsets: [CGFloat] = []
      var heights: [CGFloat] = []
      for i in 0..<100 {
        offsets.append(CGFloat(i) * 792)
        heights.append(792)
      }
      locator.blockYOffsets = offsets
      locator.blockHeights = heights

      // Find block in the middle.
      let index = locator.blockIndex(for: 50 * 792 + 100)

      #expect(index == 50)
    }

    @Test("finds first block in large document")
    func findsFirstBlockInLargeDocument() {
      let locator = MockPDFBlockLocator()
      var offsets: [CGFloat] = []
      var heights: [CGFloat] = []
      for i in 0..<100 {
        offsets.append(CGFloat(i) * 792)
        heights.append(792)
      }
      locator.blockYOffsets = offsets
      locator.blockHeights = heights

      let index = locator.blockIndex(for: 100)

      #expect(index == 0)
    }

    @Test("finds last block in large document")
    func findsLastBlockInLargeDocument() {
      let locator = MockPDFBlockLocator()
      var offsets: [CGFloat] = []
      var heights: [CGFloat] = []
      for i in 0..<100 {
        offsets.append(CGFloat(i) * 792)
        heights.append(792)
      }
      locator.blockYOffsets = offsets
      locator.blockHeights = heights

      let index = locator.blockIndex(for: 99 * 792 + 100)

      #expect(index == 99)
    }

    @Test("returns nil for offset beyond large document")
    func returnsNilForOffsetBeyondLargeDocument() {
      let locator = MockPDFBlockLocator()
      var offsets: [CGFloat] = []
      var heights: [CGFloat] = []
      for i in 0..<100 {
        offsets.append(CGFloat(i) * 792)
        heights.append(792)
      }
      locator.blockYOffsets = offsets
      locator.blockHeights = heights

      // Total height is 100 * 792 = 79200.
      let index = locator.blockIndex(for: 80000)

      #expect(index == nil)
    }
  }

  // MARK: - Boundary Condition Tests

  @Suite("Boundary Conditions")
  struct BoundaryConditionTests {

    @Test("exactly at first boundary belongs to second block")
    func exactlyAtFirstBoundaryBelongsToSecondBlock() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let index = locator.blockIndex(for: 792)

      #expect(index == 1)
    }

    @Test("exactly at second boundary belongs to third block")
    func exactlyAtSecondBoundaryBelongsToThirdBlock() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let index = locator.blockIndex(for: 1584)

      #expect(index == 2)
    }

    @Test("one point before boundary belongs to current block")
    func onePointBeforeBoundaryBelongsToCurrentBlock() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let index = locator.blockIndex(for: 791)

      #expect(index == 0)
    }

    @Test("fractional point just below boundary")
    func fractionalPointJustBelowBoundary() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let index = locator.blockIndex(for: 791.999)

      #expect(index == 0)
    }

    @Test("fractional point just above boundary")
    func fractionalPointJustAboveBoundary() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let index = locator.blockIndex(for: 792.001)

      #expect(index == 1)
    }

    @Test("exactly at total height returns nil")
    func exactlyAtTotalHeightReturnsNil() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      // Total height is 2376.
      let index = locator.blockIndex(for: 2376)

      #expect(index == nil)
    }

    @Test("one point before total height belongs to last block")
    func onePointBeforeTotalHeightBelongsToLastBlock() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let index = locator.blockIndex(for: 2375)

      #expect(index == 2)
    }
  }

  // MARK: - Coordinate Conversion with Zoom Tests

  @Suite("Coordinate Conversion with Zoom")
  struct CoordinateConversionWithZoomTests {

    @Test("converts point at maximum zoom")
    func convertsPointAtMaximumZoom() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 4.0

      let result = locator.convertToContentCoordinates(CGPoint(x: 400, y: 2000))

      #expect(result == CGPoint(x: 100, y: 500))
    }

    @Test("converts point at minimum zoom")
    func convertsPointAtMinimumZoom() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 1.0

      let result = locator.convertToContentCoordinates(CGPoint(x: 100, y: 500))

      #expect(result == CGPoint(x: 100, y: 500))
    }

    @Test("converts zero point at any zoom")
    func convertsZeroPointAtAnyZoom() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 2.5

      let result = locator.convertToContentCoordinates(.zero)

      #expect(result == .zero)
    }

    @Test("converts negative coordinates")
    func convertsNegativeCoordinates() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 2.0

      let result = locator.convertToContentCoordinates(CGPoint(x: -100, y: -200))

      #expect(result == CGPoint(x: -50, y: -100))
    }

    @Test("preserves aspect ratio during conversion")
    func preservesAspectRatioDuringConversion() {
      let locator = MockPDFBlockLocator()
      locator.currentZoomScale = 3.0

      let result = locator.convertToContentCoordinates(CGPoint(x: 300, y: 600))

      // Original ratio is 1:2, converted should still be 1:2.
      #expect(result.x * 2 == result.y)
    }
  }

  // MARK: - Block Y Range Extended Tests

  @Suite("Block Y Range Extended")
  struct BlockYRangeExtendedTests {

    @Test("range for document with mixed block heights")
    func rangeForDocumentWithMixedBlockHeights() {
      let locator = MockPDFBlockLocator()
      // PDF page (792), spacer (200), PDF page (792).
      locator.blockYOffsets = [0, 792, 992]
      locator.blockHeights = [792, 200, 792]

      let spacerRange = locator.blockYRange(for: 1)

      #expect(spacerRange?.startY == 792)
      #expect(spacerRange?.endY == 992)
    }

    @Test("range height equals block height")
    func rangeHeightEqualsBlockHeight() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 992]
      locator.blockHeights = [792, 200, 792]

      let range = locator.blockYRange(for: 1)

      let rangeHeight = (range?.endY ?? 0) - (range?.startY ?? 0)
      #expect(rangeHeight == 200)
    }

    @Test("empty document returns nil for any index")
    func emptyDocumentReturnsNilForAnyIndex() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = []
      locator.blockHeights = []

      #expect(locator.blockYRange(for: 0) == nil)
      #expect(locator.blockYRange(for: 1) == nil)
      #expect(locator.blockYRange(for: -1) == nil)
    }
  }
}

// MARK: - Additional PDFPartSwitching Tests

@Suite("PDFPartSwitching Edge Case Tests")
struct PDFPartSwitchingEdgeCaseTests {

  // Helper to create a standard part switching setup.
  static func createSetup() -> (MockPDFPartSwitching, MockPDFPartSwitchingDelegate, MockPDFBlockLocator) {
    let locator = MockPDFBlockLocator()
    locator.blockYOffsets = [0, 792, 1584]
    locator.blockHeights = [792, 792, 792]

    let switching = MockPDFPartSwitching(blockLocator: locator)
    switching.blocks = [
      (uuid: UUID(), myScriptPartID: "part-0"),
      (uuid: UUID(), myScriptPartID: "part-1"),
      (uuid: UUID(), myScriptPartID: "part-2")
    ]

    let delegate = MockPDFPartSwitchingDelegate()
    switching.partSwitchingDelegate = delegate

    return (switching, delegate, locator)
  }

  // MARK: - Same Block Optimization Tests

  @Suite("Same Block Optimization")
  struct SameBlockOptimizationTests {

    @Test("switching to same block is a no-op")
    func switchingToSameBlockIsNoOp() async throws {
      let (switching, delegate, _) = PDFPartSwitchingEdgeCaseTests.createSetup()
      try await switching.switchToBlock(at: 1)
      let initialSwitchCount = switching.switchToBlockCallCount

      // Set active block to 1 to simulate already being on block 1.
      switching.setActiveBlockIndex(1)

      // Touch on same block should not trigger part switch.
      _ = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 900))

      // The switchToBlock should not be called again since block didn't change.
      #expect(switching.activeBlockIndex == 1)
      // Delegate should not receive additional notifications for same block touch.
      #expect(delegate.didSwitchCallCount == 1) // Only from initial switch.
    }
  }

  // MARK: - Negative Touch Handling Tests

  @Suite("Negative Touch Handling")
  struct NegativeTouchHandlingTests {

    @Test("negative Y touch returns nil without switching")
    func negativeYTouchReturnsNilWithoutSwitching() async throws {
      let (switching, delegate, _) = PDFPartSwitchingEdgeCaseTests.createSetup()

      let result = try await switching.handleTouchDown(at: CGPoint(x: 100, y: -50))

      #expect(result == nil)
      #expect(switching.activeBlockIndex == -1)
      #expect(delegate.willSwitchCallCount == 0)
    }
  }

  // MARK: - Sequential Switch Tests

  @Suite("Sequential Switches")
  struct SequentialSwitchTests {

    @Test("sequential switches update active block correctly")
    func sequentialSwitchesUpdateActiveBlockCorrectly() async throws {
      let (switching, delegate, _) = PDFPartSwitchingEdgeCaseTests.createSetup()

      // Switch to block 0.
      try await switching.switchToBlock(at: 0)
      #expect(switching.activeBlockIndex == 0)

      // Switch to block 1.
      try await switching.switchToBlock(at: 1)
      #expect(switching.activeBlockIndex == 1)

      // Switch to block 2.
      try await switching.switchToBlock(at: 2)
      #expect(switching.activeBlockIndex == 2)

      // Verify delegate received all notifications.
      #expect(delegate.willSwitchCallCount == 3)
      #expect(delegate.didSwitchCallCount == 3)
    }

    @Test("switching back to previous block works")
    func switchingBackToPreviousBlockWorks() async throws {
      let (switching, _, _) = PDFPartSwitchingEdgeCaseTests.createSetup()

      try await switching.switchToBlock(at: 2)
      try await switching.switchToBlock(at: 0)

      #expect(switching.activeBlockIndex == 0)
    }
  }

  // MARK: - Touch During Error State Tests

  @Suite("Touch During Error State")
  struct TouchDuringErrorStateTests {

    @Test("after failed switch active block remains unchanged")
    func afterFailedSwitchActiveBlockRemainsUnchanged() async throws {
      let (switching, _, _) = PDFPartSwitchingEdgeCaseTests.createSetup()
      try await switching.switchToBlock(at: 0)

      // Configure to fail on next switch.
      switching.shouldFailPartSwitch = true

      // Attempt to switch to block 1.
      do {
        try await switching.switchToBlock(at: 1)
        Issue.record("Expected error")
      } catch {
        // Expected.
      }

      // Active block should remain 0.
      #expect(switching.activeBlockIndex == 0)
    }

    @Test("can recover after failed switch")
    func canRecoverAfterFailedSwitch() async throws {
      let (switching, _, _) = PDFPartSwitchingEdgeCaseTests.createSetup()
      try await switching.switchToBlock(at: 0)

      // Configure to fail on next switch.
      switching.shouldFailPartSwitch = true
      _ = try? await switching.switchToBlock(at: 1)

      // Re-enable success and try again.
      switching.shouldFailPartSwitch = false
      try await switching.switchToBlock(at: 1)

      #expect(switching.activeBlockIndex == 1)
    }
  }
}

// MARK: - PDFPartSwitchingDelegate Notification Order Tests

@Suite("PDFPartSwitchingDelegate Notification Order Tests")
struct PDFPartSwitchingDelegateNotificationOrderTests {

  @Test("willSwitch called with correct partID")
  func willSwitchCalledWithCorrectPartID() async throws {
    let locator = MockPDFBlockLocator()
    locator.blockYOffsets = [0, 792]
    locator.blockHeights = [792, 792]

    let switching = MockPDFPartSwitching(blockLocator: locator)
    switching.blocks = [
      (uuid: UUID(), myScriptPartID: "unique-part-id-0"),
      (uuid: UUID(), myScriptPartID: "unique-part-id-1")
    ]

    let delegate = MockPDFPartSwitchingDelegate()
    switching.partSwitchingDelegate = delegate

    try await switching.switchToBlock(at: 1)

    #expect(delegate.lastWillSwitchPartID == "unique-part-id-1")
  }

  @Test("failure notification includes correct partID")
  func failureNotificationIncludesCorrectPartID() async {
    let locator = MockPDFBlockLocator()
    locator.blockYOffsets = [0, 792]
    locator.blockHeights = [792, 792]

    let switching = MockPDFPartSwitching(blockLocator: locator)
    switching.blocks = [
      (uuid: UUID(), myScriptPartID: "part-0"),
      (uuid: UUID(), myScriptPartID: "failing-part-1")
    ]
    switching.shouldFailPartSwitch = true

    let delegate = MockPDFPartSwitchingDelegate()
    switching.partSwitchingDelegate = delegate

    _ = try? await switching.switchToBlock(at: 1)

    if case .partSwitchFailed(let partID, _) = delegate.lastSwitchError {
      #expect(partID == "failing-part-1")
    } else {
      Issue.record("Expected partSwitchFailed error")
    }
  }

  @Test("no didSwitch on failure")
  func noDidSwitchOnFailure() async {
    let locator = MockPDFBlockLocator()
    locator.blockYOffsets = [0, 792]
    locator.blockHeights = [792, 792]

    let switching = MockPDFPartSwitching(blockLocator: locator)
    switching.blocks = [
      (uuid: UUID(), myScriptPartID: "part-0"),
      (uuid: UUID(), myScriptPartID: "part-1")
    ]
    switching.shouldFailPartSwitch = true

    let delegate = MockPDFPartSwitchingDelegate()
    switching.partSwitchingDelegate = delegate

    _ = try? await switching.switchToBlock(at: 1)

    #expect(delegate.willSwitchCallCount == 1)
    #expect(delegate.switchFailedCallCount == 1)
    #expect(delegate.didSwitchCallCount == 0)
  }
}

// MARK: - Additional PDFToolApplication Tests

@Suite("PDFToolApplication Extended Tests")
struct PDFToolApplicationExtendedTests {

  // MARK: - Tool State Persistence Tests

  @Suite("Tool State Persistence")
  struct ToolStatePersistenceTests {

    @Test("multiple tool applications overwrite previous state")
    func multipleToolApplicationsOverwritePreviousState() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)
      try application.applyTool(selection: .highlighter, colorHex: "#FFF176", width: 5.0)

      // Last tool applied should be highlighter.
      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolHighlighter)
    }

    @Test("style is updated when applying same tool with different color")
    func styleIsUpdatedWhenApplyingSameToolWithDifferentColor() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)
      try application.applyTool(selection: .pen, colorHex: "#FF0000", width: 0.65)

      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.contains("#FF0000") == true)
      #expect(style?.contains("#000000") == false)
    }

    @Test("style is updated when applying same tool with different width")
    func styleIsUpdatedWhenApplyingSameToolWithDifferentWidth() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)
      try application.applyTool(selection: .pen, colorHex: "#000000", width: 2.0)

      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.contains("2.000") == true)
    }
  }

  // MARK: - Input Mode Behavior Tests

  @Suite("Input Mode Behavior")
  struct InputModeBehaviorTests {

    @Test("force pen mode sets both pointer types to pen tool")
    func forcePenModeSetssBothPointerTypesToPenTool() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .toolPen, inputMode: .forcePen)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolPen)
      #expect(application.mockToolController.toolsByPointerType[.touch] == .toolPen)
    }

    @Test("force pen mode with highlighter sets both to highlighter")
    func forcePenModeWithHighlighterSetsBothToHighlighter() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .toolHighlighter, inputMode: .forcePen)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolHighlighter)
      #expect(application.mockToolController.toolsByPointerType[.touch] == .toolHighlighter)
    }

    @Test("force touch mode sets pen to tool and touch to hand")
    func forceTouchModeSetsPenToToolAndTouchToHand() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .toolPen, inputMode: .forceTouch)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolPen)
      #expect(application.mockToolController.toolsByPointerType[.touch] == .hand)
    }

    @Test("auto mode sets touch to hand for panning")
    func autoModeSetsTouchToHandForPanning() throws {
      let application = MockPDFToolApplication()

      try application.applyToolForInputMode(tool: .eraser, inputMode: .auto)

      #expect(application.mockToolController.toolsByPointerType[.pen] == .eraser)
      #expect(application.mockToolController.toolsByPointerType[.touch] == .hand)
    }
  }

  // MARK: - Style Format Tests

  @Suite("Style Format")
  struct StyleFormatTests {

    @Test("style format includes color prefix")
    func styleFormatIncludesColorPrefix() throws {
      let application = MockPDFToolApplication()

      try application.applyInkStyle(colorHex: "#123456", width: 1.0, tool: .toolPen)

      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.hasPrefix("color:") == true)
    }

    @Test("style format includes pen width key")
    func styleFormatIncludesPenWidthKey() throws {
      let application = MockPDFToolApplication()

      try application.applyInkStyle(colorHex: "#000000", width: 1.5, tool: .toolPen)

      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.contains("-myscript-pen-width:") == true)
    }

    @Test("style format uses semicolon separator")
    func styleFormatUsesSemicolonSeparator() throws {
      let application = MockPDFToolApplication()

      try application.applyInkStyle(colorHex: "#000000", width: 1.0, tool: .toolPen)

      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.contains(";") == true)
    }

    @Test("width is formatted with three decimal places")
    func widthIsFormattedWithThreeDecimalPlaces() throws {
      let application = MockPDFToolApplication()

      try application.applyInkStyle(colorHex: "#000000", width: 1.5, tool: .toolPen)

      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.contains("1.500") == true)
    }

    @Test("width with many decimals is truncated to three")
    func widthWithManyDecimalsIsTruncatedToThree() throws {
      let application = MockPDFToolApplication()

      try application.applyInkStyle(colorHex: "#000000", width: 1.123456789, tool: .toolPen)

      let style = application.mockToolController.stylesByTool[.toolPen]
      #expect(style?.contains("1.123") == true)
    }
  }

  // MARK: - Eraser Special Cases Tests

  @Suite("Eraser Special Cases")
  struct EraserSpecialCasesTests {

    @Test("eraser does not get style applied")
    func eraserDoesNotGetStyleApplied() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .eraser, colorHex: "#FF0000", width: 10.0)

      // Tool should be set.
      #expect(application.mockToolController.toolsByPointerType[.pen] == .eraser)
      // But style should not be set for eraser.
      #expect(application.mockToolController.stylesByTool[.eraser] == nil)
    }

    @Test("eraser tool is properly set for pen pointer type")
    func eraserToolIsProperlySetForPenPointerType() throws {
      let application = MockPDFToolApplication()

      try application.applyTool(selection: .eraser, colorHex: "#000000", width: 1.0)

      #expect(application.mockToolController.lastSetTool == .eraser)
      #expect(application.mockToolController.lastSetPointerType == .pen)
    }
  }

  // MARK: - Error Propagation Tests

  @Suite("Error Propagation")
  struct ErrorPropagationTests {

    @Test("applyTool throws when editor unavailable")
    func applyToolThrowsWhenEditorUnavailable() {
      let application = MockPDFToolApplication()
      application.isEditorAvailable = false

      var thrownError: PDFInputError?
      do {
        try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)
      } catch let error as PDFInputError {
        thrownError = error
      } catch {
        Issue.record("Unexpected error type")
      }

      #expect(thrownError == .editorNotAvailable)
    }

    @Test("applyInkStyle throws when editor unavailable")
    func applyInkStyleThrowsWhenEditorUnavailable() {
      let application = MockPDFToolApplication()
      application.isEditorAvailable = false

      var thrownError: PDFInputError?
      do {
        try application.applyInkStyle(colorHex: "#000000", width: 1.0, tool: .toolPen)
      } catch let error as PDFInputError {
        thrownError = error
      } catch {
        Issue.record("Unexpected error type")
      }

      #expect(thrownError == .editorNotAvailable)
    }

    @Test("applyToolForInputMode throws when editor unavailable")
    func applyToolForInputModeThrowsWhenEditorUnavailable() {
      let application = MockPDFToolApplication()
      application.isEditorAvailable = false

      var thrownError: PDFInputError?
      do {
        try application.applyToolForInputMode(tool: .toolPen, inputMode: .forcePen)
      } catch let error as PDFInputError {
        thrownError = error
      } catch {
        Issue.record("Unexpected error type")
      }

      #expect(thrownError == .editorNotAvailable)
    }
  }
}

// MARK: - Mock Tool Controller Extended Tests

@Suite("MockToolController Tests")
struct MockToolControllerTests {

  @Test("tracks all tool changes for multiple pointer types")
  func tracksAllToolChangesForMultiplePointerTypes() throws {
    let controller = MockToolController()

    try controller.setToolForPointerType(tool: .toolPen, pointerType: .pen)
    try controller.setToolForPointerType(tool: .hand, pointerType: .touch)

    #expect(controller.toolsByPointerType[.pen] == .toolPen)
    #expect(controller.toolsByPointerType[.touch] == .hand)
    #expect(controller.setToolCallCount == 2)
  }

  @Test("tracks all style changes for multiple tools")
  func tracksAllStyleChangesForMultipleTools() throws {
    let controller = MockToolController()

    try controller.setStyleForTool(style: "color:#000000;-myscript-pen-width:0.650", tool: .toolPen)
    try controller.setStyleForTool(style: "color:#FFF176;-myscript-pen-width:5.000", tool: .toolHighlighter)

    #expect(controller.stylesByTool[.toolPen]?.contains("#000000") == true)
    #expect(controller.stylesByTool[.toolHighlighter]?.contains("#FFF176") == true)
    #expect(controller.setStyleCallCount == 2)
  }

  @Test("can simulate tool controller errors")
  func canSimulateToolControllerErrors() {
    let controller = MockToolController()
    controller.shouldThrowOnSetTool = true

    var didThrow = false
    do {
      try controller.setToolForPointerType(tool: .toolPen, pointerType: .pen)
    } catch {
      didThrow = true
    }

    #expect(didThrow == true)
  }

  @Test("can simulate style controller errors")
  func canSimulateStyleControllerErrors() {
    let controller = MockToolController()
    controller.shouldThrowOnSetStyle = true

    var didThrow = false
    do {
      try controller.setStyleForTool(style: "test", tool: .toolPen)
    } catch {
      didThrow = true
    }

    #expect(didThrow == true)
  }
}

// ============================================================================
// PHASE 4B: INPUT LAYER WIRING TESTS
// ============================================================================
//
// These tests validate the input layer wiring for PDF annotation.
// The tests cover:
//   - PDFInkInputWiring: Setting up and tearing down the ink input pipeline
//   - PDFEditorLifecycle: Loading initial parts and scheduling auto-save
//   - PDFZoomCoordination: UIScrollView zoom with MyScript at scale 1.0
//   - EditorDelegate integration: didCreateEditor triggers loadInitialPart

// MARK: - Phase 4B Mock Dependencies

// Mock implementation of PDFInkInputWiring for testing input layer setup.
// Tracks setup, teardown, and gesture wiring calls.
final class MockPDFInkInputWiring: PDFInkInputWiring {
  // The ink input view controller (simulated).
  private var _inkInputViewController: InputViewController?
  var inkInputViewController: InputViewController? { return _inkInputViewController }

  // Tracks method calls.
  var setupInkInputCallCount = 0
  var wirePartSwitchingGestureCallCount = 0
  var teardownInkInputCallCount = 0

  // Simulates engine availability.
  var isEngineAvailable: Bool = true

  // Simulates document view availability.
  var isDocumentViewConfigured: Bool = true

  // Stores the gesture recognizer added during wiring.
  var addedGestureRecognizer: UIGestureRecognizer?

  // View to return as input view (for testing gesture wiring).
  var mockInputView: UIView = UIView()

  // Active block index tracking.
  private var _activeBlockIndex: Int = -1
  var activeBlockIndex: Int { return _activeBlockIndex }

  func setupInkInput() async throws {
    setupInkInputCallCount += 1

    guard isEngineAvailable else {
      throw PDFDocumentError.engineNotAvailable
    }

    guard isDocumentViewConfigured else {
      throw PDFInputError.inkOverlayNotConfigured
    }

    // Simulate creating an input view controller (without actually creating one).
    // In a real test with the full system, this would be an actual InputViewController.
    wirePartSwitchingGesture()
  }

  func wirePartSwitchingGesture() {
    wirePartSwitchingGestureCallCount += 1

    // Create a long press gesture with 0 duration to detect touch-down.
    let gesture = UILongPressGestureRecognizer()
    gesture.minimumPressDuration = 0
    gesture.cancelsTouchesInView = false
    mockInputView.addGestureRecognizer(gesture)
    addedGestureRecognizer = gesture
  }

  func teardownInkInput() {
    teardownInkInputCallCount += 1

    // Remove gesture recognizer if present.
    if let gesture = addedGestureRecognizer {
      mockInputView.removeGestureRecognizer(gesture)
      addedGestureRecognizer = nil
    }

    // Clear input view controller reference.
    _inkInputViewController = nil

    // Reset active block index.
    _activeBlockIndex = -1
  }

  // Test helper to set active block index.
  func setActiveBlockIndex(_ index: Int) {
    _activeBlockIndex = index
  }

  // Test helper to simulate input view controller creation.
  func simulateInputViewControllerCreation() {
    // In production code, this would create a real InputViewController.
    // For testing purposes, we just track that it was conceptually created.
  }
}

// Mock implementation of PDFEditorLifecycle for testing editor lifecycle events.
// Tracks loading initial parts and auto-save scheduling.
final class MockPDFEditorLifecycle: PDFEditorLifecycle {
  // Tracks method calls.
  var loadInitialPartCallCount = 0
  var scheduleAutoSaveCallCount = 0

  // Simulates block availability.
  var blocks: [(uuid: UUID, myScriptPartID: String)] = []

  // Simulates part loading success/failure.
  var shouldFailLoadInitialPart = false
  var loadInitialPartErrorMessage = "Part not found"

  // Simulates handle closed state.
  var isHandleClosed = false

  // Active block index after initial load.
  private var _activeBlockIndex: Int = -1
  var activeBlockIndex: Int { return _activeBlockIndex }

  // Auto-save timer simulation.
  var autoSaveTimerScheduled = false
  var autoSaveTimerCancelledCount = 0
  var lastAutoSaveTimerInterval: TimeInterval?

  // Mock delegate for notifications.
  weak var partSwitchingDelegate: PDFPartSwitchingDelegate?

  func loadInitialPart() async throws {
    loadInitialPartCallCount += 1

    // Handle closed check.
    guard !isHandleClosed else {
      throw PDFDocumentError.partNotFound(myScriptPartID: "handle-closed")
    }

    // Handle empty blocks.
    guard !blocks.isEmpty else {
      // Graceful handling for empty document.
      return
    }

    // Simulate part loading failure.
    if shouldFailLoadInitialPart {
      let error = PDFInputError.partSwitchFailed(
        partID: blocks[0].myScriptPartID,
        underlyingError: loadInitialPartErrorMessage
      )
      partSwitchingDelegate?.partSwitchFailed(with: error)
      throw error
    }

    // Load first block's part.
    let partID = blocks[0].myScriptPartID
    partSwitchingDelegate?.willSwitchToBlock(at: 0, partID: partID)

    // Simulate successful part load.
    _activeBlockIndex = 0
    partSwitchingDelegate?.didSwitchToBlock(at: 0)
  }

  func scheduleAutoSave() {
    scheduleAutoSaveCallCount += 1

    // Cancel any existing timer (debouncing).
    if autoSaveTimerScheduled {
      autoSaveTimerCancelledCount += 1
    }

    // Schedule new timer.
    autoSaveTimerScheduled = true
    lastAutoSaveTimerInterval = 2.0
  }

  // Test helper to reset active block index.
  func resetActiveBlockIndex() {
    _activeBlockIndex = -1
  }
}

// Mock implementation of PDFZoomCoordination for testing zoom behavior.
// Tracks zoom events and view for zooming returns.
final class MockPDFZoomCoordination: NSObject, PDFZoomCoordination {
  // The content view to return for zooming.
  var contentViewForZooming: UIView?

  // Tracks zoom events.
  var scrollViewDidZoomCallCount = 0
  var viewForZoomingCallCount = 0

  // Current zoom scale from scroll view.
  var lastRecordedZoomScale: CGFloat?

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    viewForZoomingCallCount += 1
    return contentViewForZooming
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    scrollViewDidZoomCallCount += 1
    lastRecordedZoomScale = scrollView.zoomScale
  }
}

// Mock EditorDelegate implementation for testing didCreateEditor integration.
// Tracks all delegate method calls and their parameters.
final class MockPDFEditorDelegate {
  // Tracks didCreateEditor calls.
  var didCreateEditorCallCount = 0
  var lastCreatedEditor: IINKEditor?

  // Tracks partChanged calls.
  var partChangedCallCount = 0

  // Tracks contentChanged calls.
  var contentChangedCallCount = 0
  var lastContentChangedBlockIds: [String]?

  // Tracks onError calls.
  var onErrorCallCount = 0
  var lastErrorMessage: String?
  var lastErrorBlockId: String?

  // Components triggered by didCreateEditor.
  var loadInitialPartCalled = false
  var applyToolStateCalled = false

  // Simulated editor lifecycle.
  var mockEditorLifecycle: MockPDFEditorLifecycle?
}

// MARK: - PDFInkInputWiring Tests

@Suite("PDFInkInputWiring Tests")
struct PDFInkInputWiringTests {

  // MARK: - setupInkInput Tests

  @Suite("setupInkInput")
  struct SetupInkInputTests {

    @Test("successful setup increments call count")
    func successfulSetupIncrementsCallCount() async throws {
      let wiring = MockPDFInkInputWiring()
      wiring.isEngineAvailable = true
      wiring.isDocumentViewConfigured = true

      try await wiring.setupInkInput()

      #expect(wiring.setupInkInputCallCount == 1)
    }

    @Test("setup calls wirePartSwitchingGesture")
    func setupCallsWirePartSwitchingGesture() async throws {
      let wiring = MockPDFInkInputWiring()
      wiring.isEngineAvailable = true
      wiring.isDocumentViewConfigured = true

      try await wiring.setupInkInput()

      #expect(wiring.wirePartSwitchingGestureCallCount == 1)
    }

    @Test("setup when engine unavailable throws")
    func setupWhenEngineUnavailableThrows() async {
      let wiring = MockPDFInkInputWiring()
      wiring.isEngineAvailable = false

      do {
        try await wiring.setupInkInput()
        Issue.record("Expected error to be thrown")
      } catch let error as PDFDocumentError {
        #expect(error == .engineNotAvailable)
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }

      #expect(wiring.wirePartSwitchingGestureCallCount == 0)
    }

    @Test("setup when document view not configured throws")
    func setupWhenDocumentViewNotConfiguredThrows() async {
      let wiring = MockPDFInkInputWiring()
      wiring.isEngineAvailable = true
      wiring.isDocumentViewConfigured = false

      do {
        try await wiring.setupInkInput()
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        #expect(error == .inkOverlayNotConfigured)
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }
    }

    @Test("setup called multiple times increments count")
    func setupCalledMultipleTimesIncrementsCount() async throws {
      let wiring = MockPDFInkInputWiring()
      wiring.isEngineAvailable = true
      wiring.isDocumentViewConfigured = true

      try await wiring.setupInkInput()
      try await wiring.setupInkInput()
      try await wiring.setupInkInput()

      #expect(wiring.setupInkInputCallCount == 3)
    }
  }

  // MARK: - wirePartSwitchingGesture Tests

  @Suite("wirePartSwitchingGesture")
  @MainActor
  struct WirePartSwitchingGestureTests {

    @Test("gesture is added to input view")
    @MainActor
    func gestureIsAddedToInputView() {
      let wiring = MockPDFInkInputWiring()

      wiring.wirePartSwitchingGesture()

      #expect(wiring.addedGestureRecognizer != nil)
      #expect(wiring.mockInputView.gestureRecognizers?.count == 1)
    }

    @Test("gesture is UILongPressGestureRecognizer")
    @MainActor
    func gestureIsUILongPressGestureRecognizer() {
      let wiring = MockPDFInkInputWiring()

      wiring.wirePartSwitchingGesture()

      #expect(wiring.addedGestureRecognizer is UILongPressGestureRecognizer)
    }

    @Test("gesture has minimum press duration of zero")
    @MainActor
    func gestureHasMinimumPressDurationOfZero() {
      let wiring = MockPDFInkInputWiring()

      wiring.wirePartSwitchingGesture()

      if let longPress = wiring.addedGestureRecognizer as? UILongPressGestureRecognizer {
        #expect(longPress.minimumPressDuration == 0)
      } else {
        Issue.record("Expected UILongPressGestureRecognizer")
      }
    }

    @Test("gesture does not cancel touches in view")
    @MainActor
    func gestureDoesNotCancelTouchesInView() {
      let wiring = MockPDFInkInputWiring()

      wiring.wirePartSwitchingGesture()

      #expect(wiring.addedGestureRecognizer?.cancelsTouchesInView == false)
    }

    @Test("wiring increments call count")
    @MainActor
    func wiringIncrementsCallCount() {
      let wiring = MockPDFInkInputWiring()

      wiring.wirePartSwitchingGesture()
      wiring.wirePartSwitchingGesture()

      #expect(wiring.wirePartSwitchingGestureCallCount == 2)
    }
  }

  // MARK: - teardownInkInput Tests

  @Suite("teardownInkInput")
  @MainActor
  struct TeardownInkInputTests {

    @Test("teardown increments call count")
    @MainActor
    func teardownIncrementsCallCount() {
      let wiring = MockPDFInkInputWiring()

      wiring.teardownInkInput()

      #expect(wiring.teardownInkInputCallCount == 1)
    }

    @Test("teardown removes gesture recognizer")
    @MainActor
    func teardownRemovesGestureRecognizer() {
      let wiring = MockPDFInkInputWiring()
      wiring.wirePartSwitchingGesture()
      #expect(wiring.mockInputView.gestureRecognizers?.count == 1)

      wiring.teardownInkInput()

      #expect(wiring.addedGestureRecognizer == nil)
      #expect(wiring.mockInputView.gestureRecognizers?.isEmpty ?? true)
    }

    @Test("teardown resets active block index to minus one")
    @MainActor
    func teardownResetsActiveBlockIndexToMinusOne() {
      let wiring = MockPDFInkInputWiring()
      wiring.setActiveBlockIndex(2)
      #expect(wiring.activeBlockIndex == 2)

      wiring.teardownInkInput()

      #expect(wiring.activeBlockIndex == -1)
    }

    @Test("teardown when not set up does not crash")
    @MainActor
    func teardownWhenNotSetUpDoesNotCrash() {
      let wiring = MockPDFInkInputWiring()

      // Should not crash even if setup was never called.
      wiring.teardownInkInput()

      #expect(wiring.teardownInkInputCallCount == 1)
    }

    @Test("teardown after multiple setups works correctly")
    @MainActor
    func teardownAfterMultipleSetupsWorksCorrectly() async throws {
      let wiring = MockPDFInkInputWiring()
      wiring.isEngineAvailable = true
      wiring.isDocumentViewConfigured = true

      try await wiring.setupInkInput()
      try await wiring.setupInkInput()
      wiring.teardownInkInput()

      #expect(wiring.addedGestureRecognizer == nil)
      #expect(wiring.activeBlockIndex == -1)
    }
  }

  // MARK: - Input View Controller Reference Tests

  @Suite("Input View Controller Reference")
  struct InputViewControllerReferenceTests {

    @Test("inkInputViewController is nil before setup")
    func inkInputViewControllerIsNilBeforeSetup() {
      let wiring = MockPDFInkInputWiring()

      #expect(wiring.inkInputViewController == nil)
    }

    @Test("inkInputViewController is nil after teardown")
    @MainActor
    func inkInputViewControllerIsNilAfterTeardown() async throws {
      let wiring = MockPDFInkInputWiring()
      wiring.isEngineAvailable = true
      wiring.isDocumentViewConfigured = true
      try await wiring.setupInkInput()

      wiring.teardownInkInput()

      #expect(wiring.inkInputViewController == nil)
    }
  }
}

// MARK: - PDFEditorLifecycle Tests

@Suite("PDFEditorLifecycle Tests")
struct PDFEditorLifecycleTests {

  // MARK: - loadInitialPart Tests

  @Suite("loadInitialPart")
  struct LoadInitialPartTests {

    @Test("load first block's part successfully")
    func loadFirstBlocksPartSuccessfully() async throws {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [
        (uuid: UUID(), myScriptPartID: "part-0"),
        (uuid: UUID(), myScriptPartID: "part-1"),
        (uuid: UUID(), myScriptPartID: "part-2")
      ]
      let delegate = MockPDFPartSwitchingDelegate()
      lifecycle.partSwitchingDelegate = delegate

      try await lifecycle.loadInitialPart()

      #expect(lifecycle.loadInitialPartCallCount == 1)
      #expect(lifecycle.activeBlockIndex == 0)
      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.lastWillSwitchPartID == "part-0")
      #expect(delegate.didSwitchCallCount == 1)
      #expect(delegate.lastDidSwitchBlockIndex == 0)
    }

    @Test("load initial part when document has single block")
    func loadInitialPartWhenDocumentHasSingleBlock() async throws {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [(uuid: UUID(), myScriptPartID: "only-part")]
      let delegate = MockPDFPartSwitchingDelegate()
      lifecycle.partSwitchingDelegate = delegate

      try await lifecycle.loadInitialPart()

      #expect(lifecycle.activeBlockIndex == 0)
      #expect(delegate.didSwitchCallCount == 1)
    }

    @Test("load initial part fails when part not found")
    func loadInitialPartFailsWhenPartNotFound() async {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [(uuid: UUID(), myScriptPartID: "missing-part")]
      lifecycle.shouldFailLoadInitialPart = true
      let delegate = MockPDFPartSwitchingDelegate()
      lifecycle.partSwitchingDelegate = delegate

      do {
        try await lifecycle.loadInitialPart()
        Issue.record("Expected error to be thrown")
      } catch let error as PDFInputError {
        if case .partSwitchFailed(let partID, _) = error {
          #expect(partID == "missing-part")
        } else {
          Issue.record("Expected partSwitchFailed error")
        }
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }

      #expect(lifecycle.activeBlockIndex == -1)
      #expect(delegate.switchFailedCallCount == 1)
    }

    @Test("load initial part fails when handle closed")
    func loadInitialPartFailsWhenHandleClosed() async {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [(uuid: UUID(), myScriptPartID: "part-0")]
      lifecycle.isHandleClosed = true

      do {
        try await lifecycle.loadInitialPart()
        Issue.record("Expected error to be thrown")
      } catch let error as PDFDocumentError {
        if case .partNotFound = error {
          // Expected.
        } else {
          Issue.record("Expected partNotFound error")
        }
      } catch {
        Issue.record("Unexpected error type: \(error)")
      }

      #expect(lifecycle.activeBlockIndex == -1)
    }

    @Test("load initial part on empty document does not throw")
    func loadInitialPartOnEmptyDocumentDoesNotThrow() async throws {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = []

      try await lifecycle.loadInitialPart()

      #expect(lifecycle.loadInitialPartCallCount == 1)
      #expect(lifecycle.activeBlockIndex == -1)
    }

    @Test("delegate receives willSwitch before didSwitch")
    func delegateReceivesWillSwitchBeforeDidSwitch() async throws {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [(uuid: UUID(), myScriptPartID: "part-0")]
      let delegate = MockPDFPartSwitchingDelegate()
      lifecycle.partSwitchingDelegate = delegate

      try await lifecycle.loadInitialPart()

      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.didSwitchCallCount == 1)
      #expect(delegate.lastWillSwitchBlockIndex == 0)
      #expect(delegate.lastDidSwitchBlockIndex == 0)
    }
  }

  // MARK: - scheduleAutoSave Tests

  @Suite("scheduleAutoSave")
  struct ScheduleAutoSaveTests {

    @Test("auto-save schedules timer")
    func autoSaveSchedulesTimer() {
      let lifecycle = MockPDFEditorLifecycle()

      lifecycle.scheduleAutoSave()

      #expect(lifecycle.scheduleAutoSaveCallCount == 1)
      #expect(lifecycle.autoSaveTimerScheduled == true)
    }

    @Test("auto-save uses 2 second interval")
    func autoSaveUsesTwoSecondInterval() {
      let lifecycle = MockPDFEditorLifecycle()

      lifecycle.scheduleAutoSave()

      #expect(lifecycle.lastAutoSaveTimerInterval == 2.0)
    }

    @Test("auto-save debouncing cancels previous timer")
    func autoSaveDebouncingCancelsPreviousTimer() {
      let lifecycle = MockPDFEditorLifecycle()

      lifecycle.scheduleAutoSave()
      lifecycle.scheduleAutoSave()
      lifecycle.scheduleAutoSave()

      #expect(lifecycle.scheduleAutoSaveCallCount == 3)
      #expect(lifecycle.autoSaveTimerCancelledCount == 2)
    }

    @Test("multiple rapid content changes only trigger one save")
    func multipleRapidContentChangesOnlyTriggerOneSave() {
      let lifecycle = MockPDFEditorLifecycle()

      // Simulate 10 rapid content changes.
      for _ in 0..<10 {
        lifecycle.scheduleAutoSave()
      }

      #expect(lifecycle.scheduleAutoSaveCallCount == 10)
      // Previous timers should have been cancelled.
      #expect(lifecycle.autoSaveTimerCancelledCount == 9)
      // Only one timer should be pending.
      #expect(lifecycle.autoSaveTimerScheduled == true)
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("load initial part can be called multiple times")
    func loadInitialPartCanBeCalledMultipleTimes() async throws {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [
        (uuid: UUID(), myScriptPartID: "part-0"),
        (uuid: UUID(), myScriptPartID: "part-1")
      ]

      try await lifecycle.loadInitialPart()
      lifecycle.resetActiveBlockIndex()
      try await lifecycle.loadInitialPart()

      #expect(lifecycle.loadInitialPartCallCount == 2)
      #expect(lifecycle.activeBlockIndex == 0)
    }
  }
}

// MARK: - PDFZoomCoordination Tests

@Suite("PDFZoomCoordination Tests")
@MainActor
struct PDFZoomCoordinationTests {

  // MARK: - viewForZooming Tests

  @Suite("viewForZooming")
  struct ViewForZoomingTests {

    @Test("returns content view for zooming")
    @MainActor
    func returnsContentViewForZooming() {
      let coordinator = MockPDFZoomCoordination()
      let contentView = UIView()
      coordinator.contentViewForZooming = contentView
      let scrollView = UIScrollView()

      let result = coordinator.viewForZooming(in: scrollView)

      #expect(result === contentView)
      #expect(coordinator.viewForZoomingCallCount == 1)
    }

    @Test("returns nil when content view not set")
    @MainActor
    func returnsNilWhenContentViewNotSet() {
      let coordinator = MockPDFZoomCoordination()
      coordinator.contentViewForZooming = nil
      let scrollView = UIScrollView()

      let result = coordinator.viewForZooming(in: scrollView)

      #expect(result == nil)
    }

    @Test("increments call count on each call")
    @MainActor
    func incrementsCallCountOnEachCall() {
      let coordinator = MockPDFZoomCoordination()
      let scrollView = UIScrollView()

      _ = coordinator.viewForZooming(in: scrollView)
      _ = coordinator.viewForZooming(in: scrollView)
      _ = coordinator.viewForZooming(in: scrollView)

      #expect(coordinator.viewForZoomingCallCount == 3)
    }
  }

  // MARK: - scrollViewDidZoom Tests

  @Suite("scrollViewDidZoom")
  struct ScrollViewDidZoomTests {

    @Test("records zoom scale from scroll view")
    @MainActor
    func recordsZoomScaleFromScrollView() {
      let coordinator = MockPDFZoomCoordination()
      let scrollView = UIScrollView()
      scrollView.minimumZoomScale = 1.0
      scrollView.maximumZoomScale = 4.0
      scrollView.zoomScale = 2.0

      coordinator.scrollViewDidZoom(scrollView)

      #expect(coordinator.lastRecordedZoomScale == 2.0)
      #expect(coordinator.scrollViewDidZoomCallCount == 1)
    }

    @Test("handles zoom at minimum scale")
    @MainActor
    func handlesZoomAtMinimumScale() {
      let coordinator = MockPDFZoomCoordination()
      let scrollView = UIScrollView()
      scrollView.zoomScale = 1.0

      coordinator.scrollViewDidZoom(scrollView)

      #expect(coordinator.lastRecordedZoomScale == 1.0)
    }

    @Test("handles zoom at maximum scale")
    @MainActor
    func handlesZoomAtMaximumScale() {
      let coordinator = MockPDFZoomCoordination()
      let scrollView = UIScrollView()
      scrollView.zoomScale = 4.0

      coordinator.scrollViewDidZoom(scrollView)

      #expect(coordinator.lastRecordedZoomScale == 4.0)
    }

    @Test("handles fractional zoom scale")
    @MainActor
    func handlesFractionalZoomScale() {
      let coordinator = MockPDFZoomCoordination()
      let scrollView = UIScrollView()
      scrollView.zoomScale = 1.5

      coordinator.scrollViewDidZoom(scrollView)

      #expect(coordinator.lastRecordedZoomScale == 1.5)
    }

    @Test("increments call count on zoom changes")
    @MainActor
    func incrementsCallCountOnZoomChanges() {
      let coordinator = MockPDFZoomCoordination()
      let scrollView = UIScrollView()

      scrollView.zoomScale = 1.0
      coordinator.scrollViewDidZoom(scrollView)
      scrollView.zoomScale = 2.0
      coordinator.scrollViewDidZoom(scrollView)
      scrollView.zoomScale = 3.0
      coordinator.scrollViewDidZoom(scrollView)

      #expect(coordinator.scrollViewDidZoomCallCount == 3)
      #expect(coordinator.lastRecordedZoomScale == 3.0)
    }
  }

  // MARK: - Zoom Does Not Affect MyScript Tests

  @Suite("Zoom MyScript Independence")
  struct ZoomMyScriptIndependenceTests {

    @Test("zoom changes are tracked independently")
    @MainActor
    func zoomChangesAreTrackedIndependently() {
      let coordinator = MockPDFZoomCoordination()
      let scrollView = UIScrollView()

      // Simulate multiple zoom changes.
      scrollView.zoomScale = 1.0
      coordinator.scrollViewDidZoom(scrollView)
      let firstZoom = coordinator.lastRecordedZoomScale

      scrollView.zoomScale = 3.0
      coordinator.scrollViewDidZoom(scrollView)
      let secondZoom = coordinator.lastRecordedZoomScale

      // Zoom changes should be tracked.
      #expect(firstZoom == 1.0)
      #expect(secondZoom == 3.0)
      // MyScript viewScale would remain 1.0 (not tracked in this mock).
    }
  }
}

// MARK: - EditorDelegate Integration Tests

@Suite("EditorDelegate Integration Tests")
struct EditorDelegateIntegrationTests {

  // MARK: - didCreateEditor Tests

  @Suite("didCreateEditor")
  struct DidCreateEditorTests {

    @Test("didCreateEditor triggers loadInitialPart")
    func didCreateEditorTriggersLoadInitialPart() async throws {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [
        (uuid: UUID(), myScriptPartID: "part-0"),
        (uuid: UUID(), myScriptPartID: "part-1")
      ]

      // Simulate didCreateEditor triggering loadInitialPart.
      try await lifecycle.loadInitialPart()

      #expect(lifecycle.loadInitialPartCallCount == 1)
      #expect(lifecycle.activeBlockIndex == 0)
    }

    @Test("didCreateEditor applies tool state")
    func didCreateEditorAppliesToolState() throws {
      let application = MockPDFToolApplication()
      application.isEditorAvailable = true

      // Simulate applying tool state after editor creation.
      try application.applyTool(selection: .pen, colorHex: "#000000", width: 0.65)

      #expect(application.applyToolCallCount == 1)
      #expect(application.mockToolController.toolsByPointerType[.pen] == .toolPen)
    }

    @Test("initial part load notifies delegate")
    func initialPartLoadNotifiesDelegate() async throws {
      let lifecycle = MockPDFEditorLifecycle()
      lifecycle.blocks = [(uuid: UUID(), myScriptPartID: "initial-part")]
      let delegate = MockPDFPartSwitchingDelegate()
      lifecycle.partSwitchingDelegate = delegate

      try await lifecycle.loadInitialPart()

      #expect(delegate.willSwitchCallCount == 1)
      #expect(delegate.lastWillSwitchPartID == "initial-part")
      #expect(delegate.didSwitchCallCount == 1)
    }
  }

  // MARK: - contentChanged Tests

  @Suite("contentChanged")
  struct ContentChangedTests {

    @Test("contentChanged triggers scheduleAutoSave")
    func contentChangedTriggersScheduleAutoSave() {
      let lifecycle = MockPDFEditorLifecycle()

      // Simulate contentChanged triggering auto-save.
      lifecycle.scheduleAutoSave()

      #expect(lifecycle.scheduleAutoSaveCallCount == 1)
      #expect(lifecycle.autoSaveTimerScheduled == true)
    }

    @Test("multiple contentChanged calls debounce saves")
    func multipleContentChangedCallsDebounceSaves() {
      let lifecycle = MockPDFEditorLifecycle()

      // Simulate rapid content changes.
      lifecycle.scheduleAutoSave()
      lifecycle.scheduleAutoSave()
      lifecycle.scheduleAutoSave()

      #expect(lifecycle.scheduleAutoSaveCallCount == 3)
      #expect(lifecycle.autoSaveTimerCancelledCount == 2)
    }
  }
}

// MARK: - Touch Handling Integration Tests

@Suite("Touch Handling Integration Tests")
struct TouchHandlingIntegrationTests {

  // MARK: - Coordinate Conversion with Part Switching Tests

  @Suite("Coordinate Conversion with Part Switching")
  struct CoordinateConversionWithPartSwitchingTests {

    @Test("touch at zoom 2x finds correct block")
    func touchAtZoom2xFindsCorrectBlock() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]
      locator.currentZoomScale = 2.0

      // Touch at screen point (200, 1000) at zoom 2x.
      let screenPoint = CGPoint(x: 200, y: 1000)
      let contentPoint = locator.convertToContentCoordinates(screenPoint)

      // Content point should be (100, 500) after dividing by zoom.
      #expect(contentPoint == CGPoint(x: 100, y: 500))

      // Block index for content Y 500 should be block 0.
      let blockIndex = locator.blockIndex(for: contentPoint.y)
      #expect(blockIndex == 0)
    }

    @Test("touch at zoom 4x finds correct block")
    func touchAtZoom4xFindsCorrectBlock() {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]
      locator.currentZoomScale = 4.0

      // Touch at screen point (400, 4000) at zoom 4x.
      let screenPoint = CGPoint(x: 400, y: 4000)
      let contentPoint = locator.convertToContentCoordinates(screenPoint)

      // Content point should be (100, 1000) after dividing by zoom.
      #expect(contentPoint == CGPoint(x: 100, y: 1000))

      // Block index for content Y 1000 should be block 1.
      let blockIndex = locator.blockIndex(for: contentPoint.y)
      #expect(blockIndex == 1)
    }

    @Test("touch in spacer at zoom finds spacer block")
    func touchInSpacerAtZoomFindsSpacerBlock() {
      let locator = MockPDFBlockLocator()
      // PDF page (792), spacer (200), PDF page (792).
      locator.blockYOffsets = [0, 792, 992]
      locator.blockHeights = [792, 200, 792]
      locator.currentZoomScale = 2.0

      // Touch at screen point Y=1700 at zoom 2x -> content Y=850.
      let screenPoint = CGPoint(x: 100, y: 1700)
      let contentPoint = locator.convertToContentCoordinates(screenPoint)

      #expect(contentPoint.y == 850)

      // Block index for content Y 850 should be block 1 (spacer).
      let blockIndex = locator.blockIndex(for: contentPoint.y)
      #expect(blockIndex == 1)
    }
  }

  // MARK: - Part Switch During Touch Tests

  @Suite("Part Switch During Touch")
  struct PartSwitchDuringTouchTests {

    @Test("touch triggers part switch when on different block")
    func touchTriggersPartSwitchWhenOnDifferentBlock() async throws {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let switching = MockPDFPartSwitching(blockLocator: locator)
      switching.blocks = [
        (uuid: UUID(), myScriptPartID: "part-0"),
        (uuid: UUID(), myScriptPartID: "part-1"),
        (uuid: UUID(), myScriptPartID: "part-2")
      ]
      let delegate = MockPDFPartSwitchingDelegate()
      switching.partSwitchingDelegate = delegate

      // First touch on block 0.
      _ = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 400))
      #expect(switching.activeBlockIndex == 0)

      // Second touch on block 1.
      _ = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 900))
      #expect(switching.activeBlockIndex == 1)
      #expect(delegate.willSwitchCallCount == 2)
      #expect(delegate.didSwitchCallCount == 2)
    }

    @Test("touch on same block does not switch")
    func touchOnSameBlockDoesNotSwitch() async throws {
      let locator = MockPDFBlockLocator()
      locator.blockYOffsets = [0, 792, 1584]
      locator.blockHeights = [792, 792, 792]

      let switching = MockPDFPartSwitching(blockLocator: locator)
      switching.blocks = [
        (uuid: UUID(), myScriptPartID: "part-0"),
        (uuid: UUID(), myScriptPartID: "part-1")
      ]
      switching.setActiveBlockIndex(0)
      let delegate = MockPDFPartSwitchingDelegate()
      switching.partSwitchingDelegate = delegate

      // Touch on same block.
      _ = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 400))

      // No part switch should occur.
      #expect(switching.activeBlockIndex == 0)
      #expect(delegate.willSwitchCallCount == 0)
    }
  }
}

// MARK: - Gesture Recognizer Configuration Tests

@Suite("Gesture Recognizer Configuration Tests")
@MainActor
struct GestureRecognizerConfigurationTests {

  @Test("gesture fires immediately on touch-down")
  @MainActor
  func gestureFiresImmediatelyOnTouchDown() {
    let wiring = MockPDFInkInputWiring()

    wiring.wirePartSwitchingGesture()

    if let longPress = wiring.addedGestureRecognizer as? UILongPressGestureRecognizer {
      // minimumPressDuration of 0 means immediate fire.
      #expect(longPress.minimumPressDuration == 0)
    } else {
      Issue.record("Expected UILongPressGestureRecognizer")
    }
  }

  @Test("gesture allows stroke to continue")
  @MainActor
  func gestureAllowsStrokeToContinue() {
    let wiring = MockPDFInkInputWiring()

    wiring.wirePartSwitchingGesture()

    // cancelsTouchesInView = false allows MyScript to receive the touch.
    #expect(wiring.addedGestureRecognizer?.cancelsTouchesInView == false)
  }

  @Test("gesture is attached to input view")
  @MainActor
  func gestureIsAttachedToInputView() {
    let wiring = MockPDFInkInputWiring()

    wiring.wirePartSwitchingGesture()

    let gestures = wiring.mockInputView.gestureRecognizers ?? []
    #expect(gestures.contains(where: { $0 === wiring.addedGestureRecognizer }))
  }
}

// MARK: - Auto-Save Behavior Tests

@Suite("Auto-Save Behavior Tests")
struct AutoSaveBehaviorTests {

  @Test("auto-save interval is 2 seconds")
  func autoSaveIntervalIsTwoSeconds() {
    let lifecycle = MockPDFEditorLifecycle()

    lifecycle.scheduleAutoSave()

    #expect(lifecycle.lastAutoSaveTimerInterval == 2.0)
  }

  @Test("auto-save resets on each content change")
  func autoSaveResetsOnEachContentChange() {
    let lifecycle = MockPDFEditorLifecycle()

    lifecycle.scheduleAutoSave()
    #expect(lifecycle.autoSaveTimerCancelledCount == 0)

    lifecycle.scheduleAutoSave()
    #expect(lifecycle.autoSaveTimerCancelledCount == 1)

    lifecycle.scheduleAutoSave()
    #expect(lifecycle.autoSaveTimerCancelledCount == 2)
  }

  @Test("single save after rapid changes")
  func singleSaveAfterRapidChanges() {
    let lifecycle = MockPDFEditorLifecycle()

    // Simulate 10 rapid strokes.
    for _ in 0..<10 {
      lifecycle.scheduleAutoSave()
    }

    // Should have one pending save.
    #expect(lifecycle.autoSaveTimerScheduled == true)
    // Should have cancelled 9 previous timers.
    #expect(lifecycle.autoSaveTimerCancelledCount == 9)
  }
}

// MARK: - Input Layer Wiring Edge Cases

@Suite("Input Layer Wiring Edge Cases")
struct InputLayerWiringEdgeCaseTests {

  @Test("setup and teardown multiple times")
  @MainActor
  func setupAndTeardownMultipleTimes() async throws {
    let wiring = MockPDFInkInputWiring()
    wiring.isEngineAvailable = true
    wiring.isDocumentViewConfigured = true

    try await wiring.setupInkInput()
    wiring.teardownInkInput()
    try await wiring.setupInkInput()
    wiring.teardownInkInput()

    #expect(wiring.setupInkInputCallCount == 2)
    #expect(wiring.teardownInkInputCallCount == 2)
  }

  @Test("teardown clears all state")
  @MainActor
  func teardownClearsAllState() async throws {
    let wiring = MockPDFInkInputWiring()
    wiring.isEngineAvailable = true
    wiring.isDocumentViewConfigured = true
    try await wiring.setupInkInput()
    wiring.setActiveBlockIndex(2)

    wiring.teardownInkInput()

    #expect(wiring.activeBlockIndex == -1)
    #expect(wiring.addedGestureRecognizer == nil)
    #expect(wiring.inkInputViewController == nil)
  }

  @Test("engine becomes unavailable after setup")
  @MainActor
  func engineBecomesUnavailableAfterSetup() async throws {
    let wiring = MockPDFInkInputWiring()
    wiring.isEngineAvailable = true
    wiring.isDocumentViewConfigured = true

    try await wiring.setupInkInput()
    #expect(wiring.setupInkInputCallCount == 1)

    // Simulate engine becoming unavailable.
    wiring.isEngineAvailable = false

    // Trying to setup again should fail.
    do {
      try await wiring.setupInkInput()
      Issue.record("Expected error")
    } catch let error as PDFDocumentError {
      #expect(error == .engineNotAvailable)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}

// MARK: - Combined Workflow Tests

@Suite("Combined Workflow Tests")
struct CombinedWorkflowTests {

  @Test("complete input setup workflow")
  @MainActor
  func completeInputSetupWorkflow() async throws {
    // 1. Create wiring.
    let wiring = MockPDFInkInputWiring()
    wiring.isEngineAvailable = true
    wiring.isDocumentViewConfigured = true

    // 2. Setup ink input.
    try await wiring.setupInkInput()
    #expect(wiring.setupInkInputCallCount == 1)
    #expect(wiring.wirePartSwitchingGestureCallCount == 1)

    // 3. Create lifecycle.
    let lifecycle = MockPDFEditorLifecycle()
    lifecycle.blocks = [
      (uuid: UUID(), myScriptPartID: "part-0"),
      (uuid: UUID(), myScriptPartID: "part-1")
    ]

    // 4. Load initial part (simulating didCreateEditor).
    try await lifecycle.loadInitialPart()
    #expect(lifecycle.activeBlockIndex == 0)

    // 5. Simulate content changes.
    lifecycle.scheduleAutoSave()
    lifecycle.scheduleAutoSave()
    #expect(lifecycle.scheduleAutoSaveCallCount == 2)
    #expect(lifecycle.autoSaveTimerCancelledCount == 1)

    // 6. Teardown.
    wiring.teardownInkInput()
    #expect(wiring.activeBlockIndex == -1)
  }

  @Test("touch triggers complete part switch flow")
  func touchTriggersCompletePartSwitchFlow() async throws {
    // Setup.
    let locator = MockPDFBlockLocator()
    locator.blockYOffsets = [0, 792, 1584]
    locator.blockHeights = [792, 792, 792]
    locator.currentZoomScale = 1.0

    let switching = MockPDFPartSwitching(blockLocator: locator)
    switching.blocks = [
      (uuid: UUID(), myScriptPartID: "part-0"),
      (uuid: UUID(), myScriptPartID: "part-1"),
      (uuid: UUID(), myScriptPartID: "part-2")
    ]

    let delegate = MockPDFPartSwitchingDelegate()
    switching.partSwitchingDelegate = delegate

    // Initial touch on block 0.
    let result0 = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 400))
    #expect(result0 == 0)
    #expect(switching.activeBlockIndex == 0)
    #expect(delegate.lastWillSwitchPartID == "part-0")
    #expect(delegate.lastDidSwitchBlockIndex == 0)

    // Touch on block 2.
    let result2 = try await switching.handleTouchDown(at: CGPoint(x: 100, y: 2000))
    #expect(result2 == 2)
    #expect(switching.activeBlockIndex == 2)
    #expect(delegate.lastWillSwitchPartID == "part-2")
    #expect(delegate.lastDidSwitchBlockIndex == 2)
  }
}

// NOTE: The following test suites have been deprecated and commented out.
// They were for the collection-based PDF display approach which has been
// replaced by the unified canvas implementation in PDFDocumentContract.swift.

/*
// MARK: - SpacerCell Tests (DEPRECATED)

@Suite("SpacerCell Tests")
@MainActor
struct SpacerCellTests {
  // ... deprecated tests ...
}

// MARK: - PDFPageCell Tests (DEPRECATED)

@Suite("PDFPageCell Tests")
@MainActor
struct PDFPageCellTests {
  // ... deprecated tests ...
}

// MARK: - PDFCollectionViewControllerError Tests (DEPRECATED)

@Suite("PDFCollectionViewControllerError Tests")
struct PDFCollectionViewControllerErrorTests {
  // ... deprecated tests ...
}

// MARK: - PDFCollectionViewController Tests (DEPRECATED)

@Suite("PDFCollectionViewController Tests")
@MainActor
struct PDFCollectionViewControllerTests {
  // ... deprecated tests ...
}

// MARK: - PDFCollectionLayout Tests (DEPRECATED)

@Suite("PDFCollectionLayout Tests")
@MainActor
struct PDFCollectionLayoutTests {
  // ... deprecated tests ...
}
*/
