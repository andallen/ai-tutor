// PDFDocumentContract.swift
// API Contract for PDF Unified Canvas Implementation
//
// This file defines the complete specification for displaying PDF documents in a unified
// scroll view canvas where a single IINKEditor overlays the entire document. PDF pages
// render as background using PDFPage.draw(), with ink captured in a continuous coordinate space.
//
// Architecture:
//   PDFDocumentViewController
//     |
//     +-- PDFDocumentView (UIScrollView subclass)
//           |
//           +-- PDFBackgroundLayer (draws PDF pages at Y offsets)
//           |
//           +-- InputViewController (single IINKEditor for entire doc)
//                 +-- DisplayViewController (RenderView for ink)
//                 +-- InputView (touch capture)
//
// Test writers can implement tests from this contract without ambiguity.

import CoreGraphics
import PDFKit
import UIKit

// MARK: - PDFDocumentError

// Errors that can occur when creating or operating the PDF document view.
// Each case provides specific information about the failure.
enum PDFDocumentError: LocalizedError, Equatable {
  // The NoteDocument contains no blocks to display.
  case emptyDocument

  // PDFDocument reference is nil or invalid.
  case invalidPDFDocument

  // A NoteBlock.pdfPage references a page index not in the PDFDocument.
  // blockIndex: Index of the block in the NoteDocument.blocks array.
  // pageIndex: The pageIndex value from the pdfPage block.
  // pdfPageCount: Actual number of pages in the PDFDocument.
  case pageIndexOutOfBounds(blockIndex: Int, pageIndex: Int, pdfPageCount: Int)

  // MyScript engine is not initialized or unavailable.
  case engineNotAvailable

  // Failed to find a MyScript part with the specified identifier.
  // myScriptPartID: The identifier that was not found in the package.
  case partNotFound(myScriptPartID: String)

  var errorDescription: String? {
    switch self {
    case .emptyDocument:
      return "The document contains no pages to display."
    case .invalidPDFDocument:
      return "The PDF document is invalid or could not be loaded."
    case .pageIndexOutOfBounds(let blockIndex, let pageIndex, let pdfPageCount):
      return
        "Block \(blockIndex) references page \(pageIndex), but PDF only has \(pdfPageCount) pages."
    case .engineNotAvailable:
      return "The annotation engine is not available. Please restart the app."
    case .partNotFound(let myScriptPartID):
      return "Could not find annotation layer with identifier: \(myScriptPartID)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentError

 SCENARIO: Error provides localized description
 GIVEN: Any PDFDocumentError case
 WHEN: errorDescription is accessed
 THEN: A non-nil user-facing message is returned

 SCENARIO: Error equality for simple cases
 GIVEN: Two PDFDocumentError.emptyDocument values
 WHEN: Compared for equality
 THEN: They are equal

 SCENARIO: Error equality with associated values
 GIVEN: Two identical pageIndexOutOfBounds errors
 WHEN: Compared for equality
 THEN: They are equal

 GIVEN: Two pageIndexOutOfBounds errors with different values
 WHEN: Compared for equality
 THEN: They are not equal
*/

// MARK: - PDFBackgroundLayerDataSource

// Data source protocol providing PDF and layout information to the background layer.
// The background layer queries this data source to determine what to draw and where.
// Weak reference prevents retain cycles with the view hierarchy.
protocol PDFBackgroundLayerDataSource: AnyObject {
  // The PDFDocument containing pages to render.
  var pdfDocument: PDFDocument { get }

  // The NoteDocument containing block definitions and order.
  var noteDocument: NoteDocument { get }

  // Precomputed Y offsets for each block in the document.
  // blockYOffsets[i] is the Y position where block i starts.
  // Array count equals noteDocument.blocks.count.
  var blockYOffsets: [CGFloat] { get }

  // Current zoom scale applied to the document view.
  // 1.0 means no zoom, 2.0 means double size.
  var currentZoomScale: CGFloat { get }

  // Returns the unscaled height for a PDF page at the given index.
  // The height is calculated for the specified container width.
  // For a portrait US Letter page (612x792) at width 612, returns 792.
  // pageIndex: Zero-based index into the PDFDocument.
  // width: Container width in points.
  // Returns nil if pageIndex is out of bounds.
  func pageHeight(for pageIndex: Int, at width: CGFloat) -> CGFloat?
}

/*
 ACCEPTANCE CRITERIA: PDFBackgroundLayerDataSource

 SCENARIO: Page height calculation for portrait page
 GIVEN: A PDFDocument with a US Letter page (612x792)
  AND: Container width is 612
 WHEN: pageHeight(for: 0, at: 612) is called
 THEN: Returns 792

 SCENARIO: Page height calculation for landscape page
 GIVEN: A PDFDocument with a landscape page (792x612)
  AND: Container width is 400
 WHEN: pageHeight(for: 0, at: 400) is called
 THEN: Returns 400 * (612/792) = approximately 309

 SCENARIO: Page height for invalid index
 GIVEN: A PDFDocument with 3 pages
 WHEN: pageHeight(for: 5, at: 400) is called
 THEN: Returns nil

 SCENARIO: Block Y offsets match block count
 GIVEN: A NoteDocument with 5 blocks
 WHEN: blockYOffsets is accessed
 THEN: Array count equals 5
*/

/*
 EDGE CASES: PDFBackgroundLayerDataSource

 EDGE CASE: Container width is zero
 GIVEN: Any valid page index
 WHEN: pageHeight(for: index, at: 0) is called
 THEN: Returns 0

 EDGE CASE: PDF page has zero width
 GIVEN: A malformed page with zero width dimension
 WHEN: pageHeight is calculated
 THEN: Implementation should handle gracefully (return 0 or container width)

 EDGE CASE: Negative page index
 GIVEN: A valid PDFDocument
 WHEN: pageHeight(for: -1, at: 400) is called
 THEN: Returns nil
*/

// MARK: - PDFBackgroundLayerProtocol

// Protocol for the layer that draws PDF pages and dotted grids as the document background.
// This layer is positioned behind the ink overlay and handles efficient rendering
// of only the visible portions of the document.
protocol PDFBackgroundLayerProtocol: AnyObject {
  // Weak reference to the data source providing PDF and layout information.
  var dataSource: PDFBackgroundLayerDataSource? { get set }

  // Configuration for the dotted grid pattern drawn in spacer areas.
  var dottedGridConfiguration: DottedGridConfiguration { get set }

  // Marks a specific rect as needing redraw.
  // Used when scrolling reveals new content or zoom changes.
  // rect: The area in the layer's coordinate space that needs updating.
  // Note: This method name matches UIView's method; implementations override both.
  func markRectNeedsDisplay(_ rect: CGRect)

  // Updates the layer's tile cache based on the currently visible rect.
  // Preloads tiles just outside the visible area for smooth scrolling.
  // Releases tiles far outside the visible area to conserve memory.
  // visibleRect: The currently visible area in the layer's coordinate space.
  func updateForVisibleRect(_ visibleRect: CGRect)
}

/*
 ACCEPTANCE CRITERIA: PDFBackgroundLayerProtocol

 SCENARIO: Initialize with default dotted grid configuration
 GIVEN: A new PDFBackgroundLayer instance
 WHEN: dottedGridConfiguration is accessed
 THEN: Returns DottedGridConfiguration.default

 SCENARIO: Update configuration
 GIVEN: A PDFBackgroundLayer instance
 WHEN: dottedGridConfiguration is set to a new value
 THEN: The layer is marked for redraw

 SCENARIO: Set data source
 GIVEN: A PDFBackgroundLayer instance
 WHEN: dataSource is set to a valid PDFBackgroundLayerDataSource
 THEN: The layer can query PDF and layout information

 SCENARIO: Data source is weak reference
 GIVEN: A PDFBackgroundLayer with a data source
 WHEN: All strong references to the data source are released
 THEN: dataSource becomes nil (no retain cycle)
*/

/*
 ACCEPTANCE CRITERIA: PDFBackgroundLayer Rendering

 SCENARIO: Draw visible PDF page
 GIVEN: A visible rect that covers only page 1 (blockYOffsets[0] to blockYOffsets[1])
 WHEN: draw(_:) is called
 THEN: Only page 1 is rendered
  AND: Page 2 is not rendered (outside visible rect)

 SCENARIO: Draw across page boundary
 GIVEN: A visible rect spanning from halfway through page 1 to halfway through page 2
 WHEN: draw(_:) is called
 THEN: Both page 1 and page 2 are rendered
  AND: Each page is rendered at its correct Y offset

 SCENARIO: Draw spacer with dotted grid
 GIVEN: A visible rect covering a writingSpacer block
 WHEN: draw(_:) is called
 THEN: A dotted grid pattern is drawn in the spacer area
  AND: The pattern uses dottedGridConfiguration settings

 SCENARIO: Apply zoom scale to rendering
 GIVEN: currentZoomScale is 2.0
 WHEN: draw(_:) is called
 THEN: PDF pages are rendered at 2x their base size
  AND: Dotted grids scale proportionally
*/

/*
 EDGE CASES: PDFBackgroundLayer

 EDGE CASE: No data source
 GIVEN: A PDFBackgroundLayer with dataSource = nil
 WHEN: draw(_:) is called
 THEN: Nothing is drawn
  AND: No crash occurs

 EDGE CASE: Empty visible rect
 GIVEN: A PDFBackgroundLayer with valid data source
 WHEN: updateForVisibleRect(CGRect.zero) is called
 THEN: No tiles are loaded
  AND: No crash occurs

 EDGE CASE: Very large visible rect
 GIVEN: A visible rect larger than the entire document
 WHEN: draw(_:) is called
 THEN: All visible blocks are rendered
  AND: Areas beyond the document are not rendered

 EDGE CASE: Rapid scrolling
 GIVEN: Many consecutive updateForVisibleRect calls
 WHEN: Visible rect changes rapidly
 THEN: Tile loading is efficient (no excessive memory allocation)
  AND: Previously loaded tiles are reused when returning to viewed areas
*/

// MARK: - PDFDocumentViewProtocol

// Protocol for the main scroll view that contains the PDF document.
// This view manages scrolling, zooming, and coordinates the background layer
// with the ink overlay (InputViewController).
protocol PDFDocumentViewProtocol: AnyObject {
  // The NoteDocument defining the document structure.
  var noteDocument: NoteDocument { get }

  // The PDFDocument containing page content.
  var pdfDocument: PDFDocument { get }

  // Current zoom scale. 1.0 is no zoom.
  var currentZoomScale: CGFloat { get }

  // Current scroll position in the content coordinate space.
  var contentOffset: CGPoint { get }

  // Precomputed Y offsets for each block.
  // blockYOffsets[i] is the unscaled Y position where block i starts.
  var blockYOffsets: [CGFloat] { get }

  // Calculates the Y offset for each block based on block heights.
  // Returns array where element i is the cumulative height of blocks 0..<i.
  // First element is always 0.
  // Uses unscaled heights (zoom not applied).
  func calculateBlockYOffsets() -> [CGFloat]

  // Calculates the total content height of the document.
  // Returns the sum of all block heights at the current zoom scale.
  func calculateTotalContentHeight() -> CGFloat

  // Finds the block containing the given Y offset.
  // yOffset: Position in unscaled content coordinates.
  // Returns the block index and block data, or nil if yOffset is beyond content.
  func blockContaining(yOffset: CGFloat) -> (blockIndex: Int, block: NoteBlock)?

  // Scrolls to make the specified block visible.
  // blockIndex: Zero-based index of the block to scroll to.
  // animated: Whether to animate the scroll.
  func scrollTo(blockIndex: Int, animated: Bool)
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentViewProtocol.calculateBlockYOffsets

 SCENARIO: Calculate offsets for PDF pages only
 GIVEN: A document with 3 PDF pages (heights 792, 792, 792)
  AND: No spacers
 WHEN: calculateBlockYOffsets() is called
 THEN: Returns [0, 792, 1584]

 SCENARIO: Calculate offsets with interleaved spacer
 GIVEN: A document with [pdfPage(792), writingSpacer(200), pdfPage(792)]
 WHEN: calculateBlockYOffsets() is called
 THEN: Returns [0, 792, 992]
  AND: First PDF page starts at 0
  AND: Spacer starts at 792
  AND: Second PDF page starts at 992

 SCENARIO: Calculate offsets for empty document
 GIVEN: A document with zero blocks
 WHEN: calculateBlockYOffsets() is called
 THEN: Returns empty array []
*/

/*
 ACCEPTANCE CRITERIA: PDFDocumentViewProtocol.calculateTotalContentHeight

 SCENARIO: Total height without zoom
 GIVEN: A document with 3 PDF pages (each 792 points)
  AND: currentZoomScale is 1.0
 WHEN: calculateTotalContentHeight() is called
 THEN: Returns 2376 (792 * 3)

 SCENARIO: Total height with zoom
 GIVEN: A document with 3 PDF pages (each 792 points)
  AND: currentZoomScale is 2.0
 WHEN: calculateTotalContentHeight() is called
 THEN: Returns 4752 (792 * 3 * 2.0)

 SCENARIO: Total height with mixed blocks
 GIVEN: A document with [pdfPage(792), writingSpacer(200), pdfPage(792)]
  AND: currentZoomScale is 1.0
 WHEN: calculateTotalContentHeight() is called
 THEN: Returns 1784 (792 + 200 + 792)
*/

/*
 ACCEPTANCE CRITERIA: PDFDocumentViewProtocol.blockContaining

 SCENARIO: Find block at beginning
 GIVEN: blockYOffsets = [0, 792, 1584]
 WHEN: blockContaining(yOffset: 0) is called
 THEN: Returns (blockIndex: 0, block: first block)

 SCENARIO: Find block in middle of first page
 GIVEN: blockYOffsets = [0, 792, 1584]
 WHEN: blockContaining(yOffset: 400) is called
 THEN: Returns (blockIndex: 0, block: first block)

 SCENARIO: Find block at boundary
 GIVEN: blockYOffsets = [0, 792, 1584]
 WHEN: blockContaining(yOffset: 792) is called
 THEN: Returns (blockIndex: 1, block: second block)

 SCENARIO: Find block past last page
 GIVEN: blockYOffsets = [0, 792, 1584] with total height 2376
 WHEN: blockContaining(yOffset: 3000) is called
 THEN: Returns nil
*/

/*
 EDGE CASES: PDFDocumentViewProtocol.blockContaining

 EDGE CASE: Negative yOffset
 GIVEN: A valid document
 WHEN: blockContaining(yOffset: -100) is called
 THEN: Returns nil or (blockIndex: 0, block: first block)
  AND: Behavior is consistent and documented

 EDGE CASE: Exactly at total height
 GIVEN: blockYOffsets = [0, 792] with total height 1584
 WHEN: blockContaining(yOffset: 1584) is called
 THEN: Returns nil (past the end of content)

 EDGE CASE: Empty document
 GIVEN: A document with no blocks
 WHEN: blockContaining(yOffset: 0) is called
 THEN: Returns nil
*/

/*
 ACCEPTANCE CRITERIA: PDFDocumentViewProtocol.scrollTo

 SCENARIO: Scroll to first block
 GIVEN: A document with 3 blocks
 WHEN: scrollTo(blockIndex: 0, animated: false) is called
 THEN: contentOffset.y becomes 0

 SCENARIO: Scroll to middle block
 GIVEN: A document with 3 blocks, blockYOffsets = [0, 792, 1584]
 WHEN: scrollTo(blockIndex: 1, animated: false) is called
 THEN: contentOffset.y becomes 792 * currentZoomScale

 SCENARIO: Animated scroll
 GIVEN: A document with multiple blocks
 WHEN: scrollTo(blockIndex: 2, animated: true) is called
 THEN: The scroll animates to the target position
*/

/*
 EDGE CASES: PDFDocumentViewProtocol.scrollTo

 EDGE CASE: Block index out of bounds (too large)
 GIVEN: A document with 3 blocks
 WHEN: scrollTo(blockIndex: 10, animated: false) is called
 THEN: Scrolls to the last block
  OR: No action taken (implementation choice, must be consistent)

 EDGE CASE: Negative block index
 GIVEN: A document with 3 blocks
 WHEN: scrollTo(blockIndex: -1, animated: false) is called
 THEN: Scrolls to first block (index 0)
  OR: No action taken (implementation choice, must be consistent)
*/

// MARK: - PDFDocumentViewControllerProtocol

// Protocol for the view controller managing the PDF document display.
// Coordinates between the scroll view, background layer, and ink input controller.
protocol PDFDocumentViewControllerProtocol: AnyObject {
  // The NoteDocument being displayed.
  var noteDocument: NoteDocument { get }

  // The PDFDocument containing page content.
  var pdfDocument: PDFDocument { get }

  // Current zoom scale.
  var currentZoomScale: CGFloat { get }

  // The main document view (UIScrollView subclass).
  var documentView: (any PDFDocumentViewProtocol)? { get }

  // Scrolls to make the specified block visible.
  // Delegates to documentView.scrollTo.
  func scrollTo(blockIndex: Int, animated: Bool)
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentViewControllerProtocol

 SCENARIO: Initialize with valid documents
 GIVEN: A valid NoteDocument with 3 pdfPage blocks
  AND: A valid PDFDocument with 3 pages
 WHEN: PDFDocumentViewController is initialized
 THEN: noteDocument matches the provided document
  AND: pdfDocument matches the provided PDF
  AND: documentView is non-nil after view loads
  AND: No error is thrown

 SCENARIO: Initialize with empty NoteDocument
 GIVEN: A NoteDocument with empty blocks array
 WHEN: PDFDocumentViewController is initialized
 THEN: Initialization fails with PDFDocumentError.emptyDocument

 SCENARIO: Initialize with invalid PDF
 GIVEN: A valid NoteDocument
  AND: pdfDocument is nil or corrupt
 WHEN: PDFDocumentViewController is initialized
 THEN: Initialization fails with PDFDocumentError.invalidPDFDocument

 SCENARIO: Initialize with mismatched page indices
 GIVEN: A NoteDocument with pdfPage block referencing pageIndex 5
  AND: A PDFDocument with only 3 pages
 WHEN: PDFDocumentViewController validates blocks
 THEN: Throws PDFDocumentError.pageIndexOutOfBounds(blockIndex:_, pageIndex: 5, pdfPageCount: 3)
*/

/*
 EDGE CASES: PDFDocumentViewControllerProtocol

 EDGE CASE: Single page document
 GIVEN: A NoteDocument with exactly one pdfPage block
  AND: A PDFDocument with one page
 WHEN: PDFDocumentViewController is initialized
 THEN: Initialization succeeds
  AND: Document displays correctly

 EDGE CASE: Large document (100+ pages)
 GIVEN: A NoteDocument with 100 pdfPage blocks
 WHEN: The document is scrolled
 THEN: Only visible pages are rendered
  AND: Memory usage remains bounded
  AND: Scrolling remains smooth

 EDGE CASE: Document with only spacers
 GIVEN: A NoteDocument with only writingSpacer blocks (no PDF pages)
 WHEN: PDFDocumentViewController is initialized
 THEN: Initialization succeeds
  AND: Only dotted grids are displayed

 EDGE CASE: Zoom changes
 GIVEN: A displayed document at zoom 1.0
 WHEN: currentZoomScale changes to 2.0
 THEN: Content size doubles
  AND: Block Y offsets are recalculated
  AND: Visible content is re-rendered at new scale
*/

// MARK: - PDFDocumentHandleProtocol

// Protocol for managing an open PDF document with MyScript annotation support.
// Extends DocumentHandleProtocol patterns for PDF-specific operations.
// Must be Sendable for safe passing across actor boundaries.
protocol PDFDocumentHandleProtocol: AnyObject, Sendable {
  // Unique identifier for this document.
  var documentID: UUID { get }

  // Retrieves the MyScript content part for a specific part identifier.
  // myScriptPartID: The identifier stored in NoteBlock.
  // Returns the ContentPartProtocol for that part.
  // Throws PDFDocumentError.partNotFound if not found.
  func part(for myScriptPartID: String) async throws -> any ContentPartProtocol

  // Saves the MyScript package to persistent storage.
  // Should be called after ink modifications.
  func savePackage() async throws

  // Closes the document handle and releases resources.
  // Package is saved before closing if there are unsaved changes.
  func close() async
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentHandleProtocol

 SCENARIO: Retrieve part by identifier
 GIVEN: A PDF document with 3 pages
  AND: Each page has a corresponding MyScript part
 WHEN: part(for: "validPartID") is called
 THEN: Returns the correct ContentPartProtocol
  AND: The part can be used with IINKEditor

 SCENARIO: Part not found
 GIVEN: A PDF document handle
 WHEN: part(for: "nonexistentID") is called
 THEN: Throws PDFDocumentError.partNotFound("nonexistentID")

 SCENARIO: Save package
 GIVEN: A PDF document with ink modifications
 WHEN: savePackage() is called
 THEN: Changes are persisted to the .iink file
  AND: No data loss occurs

 SCENARIO: Close document
 GIVEN: An open PDF document handle
 WHEN: close() is called
 THEN: Resources are released
  AND: Subsequent calls to part() throw an error
*/

/*
 EDGE CASES: PDFDocumentHandleProtocol

 EDGE CASE: Close without save
 GIVEN: A document with unsaved changes
 WHEN: close() is called
 THEN: Changes are saved before closing

 EDGE CASE: Multiple concurrent part requests
 GIVEN: A PDF document handle
 WHEN: Multiple part(for:) calls are made concurrently
 THEN: All calls complete successfully
  AND: No race conditions occur

 EDGE CASE: Part identifier is empty string
 GIVEN: A PDF document handle
 WHEN: part(for: "") is called
 THEN: Throws PDFDocumentError.partNotFound("")
*/

// MARK: - NoteBlock Height Extension

// Extension on NoteBlock to calculate base height without zoom.
// Defined in contract to specify expected behavior for test writers.

/*
 API SIGNATURE: NoteBlock.baseHeight

 extension NoteBlock {
   // Calculates the unscaled height of this block.
   // For pdfPage: Queries the page height from the provider.
   // For writingSpacer: Returns the stored height value.
   //
   // pageHeightProvider: Closure that returns page height for a given page index.
   //                     Returns nil if the page index is invalid.
   //
   // Returns: The height in points, or nil if the page index is invalid.
   func baseHeight(pageHeightProvider: (Int) -> CGFloat?) -> CGFloat?
 }
*/

/*
 ACCEPTANCE CRITERIA: NoteBlock.baseHeight

 SCENARIO: PDF page height
 GIVEN: A NoteBlock.pdfPage with pageIndex 0
  AND: pageHeightProvider returns 792 for index 0
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns 792

 SCENARIO: PDF page with different aspect ratio
 GIVEN: A NoteBlock.pdfPage with pageIndex 2
  AND: pageHeightProvider returns 500 for index 2
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns 500

 SCENARIO: Writing spacer height
 GIVEN: A NoteBlock.writingSpacer with height 200
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns 200
  AND: pageHeightProvider is not called

 SCENARIO: Invalid page index
 GIVEN: A NoteBlock.pdfPage with pageIndex 10
  AND: pageHeightProvider returns nil for index 10
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns nil
*/

/*
 EDGE CASES: NoteBlock.baseHeight

 EDGE CASE: Zero height spacer
 GIVEN: A NoteBlock.writingSpacer with height 0
 WHEN: baseHeight is called
 THEN: Returns 0

 EDGE CASE: Negative height spacer
 GIVEN: A NoteBlock.writingSpacer with height -100
 WHEN: baseHeight is called
 THEN: Returns -100 (invalid state, but contract does not validate)

 EDGE CASE: Very large height
 GIVEN: A NoteBlock.writingSpacer with height CGFloat.greatestFiniteMagnitude
 WHEN: baseHeight is called
 THEN: Returns CGFloat.greatestFiniteMagnitude
*/

// MARK: - DottedGridView Static Drawing Method

// Static method for drawing dotted patterns, extracted for reuse by PDFBackgroundLayer.
// This allows both DottedGridView and PDFBackgroundLayer to share the same drawing code.

/*
 API SIGNATURE: DottedGridView.drawDottedPattern (static)

 extension DottedGridView {
   // Draws a dotted grid pattern in the specified rect using the given context.
   // This static method can be called from any layer or view that needs the pattern.
   //
   // context: The CGContext to draw into.
   // rect: The area to fill with the pattern.
   // configuration: The dotted grid configuration (spacing, dot size, color).
   // scale: The current display scale (for retina rendering).
   static func drawDottedPattern(
     in context: CGContext,
     rect: CGRect,
     configuration: DottedGridConfiguration,
     scale: CGFloat
   )
 }
*/

/*
 ACCEPTANCE CRITERIA: DottedGridView.drawDottedPattern (static)

 SCENARIO: Draw pattern in standard rect
 GIVEN: A CGContext and rect of 100x100
  AND: Default configuration (spacing: 20, dotSize: 2)
 WHEN: drawDottedPattern is called
 THEN: Dots are drawn at 20pt intervals
  AND: Each dot has diameter 2
  AND: Pattern fills entire rect

 SCENARIO: Pattern respects configuration
 GIVEN: A custom configuration (spacing: 40, dotSize: 4, color: .blue)
 WHEN: drawDottedPattern is called
 THEN: Dots are spaced 40pt apart
  AND: Each dot has diameter 4
  AND: Dots are blue

 SCENARIO: Scale affects rendering
 GIVEN: scale = 2.0 (retina display)
 WHEN: drawDottedPattern is called
 THEN: Pattern is rendered at 2x resolution
  AND: Dots appear crisp on retina displays
*/

/*
 EDGE CASES: DottedGridView.drawDottedPattern (static)

 EDGE CASE: Zero-sized rect
 GIVEN: rect = CGRect.zero
 WHEN: drawDottedPattern is called
 THEN: Nothing is drawn
  AND: No crash occurs

 EDGE CASE: Zero spacing
 GIVEN: configuration with spacing = 0
 WHEN: drawDottedPattern is called
 THEN: Nothing is drawn (avoid division by zero)
  AND: No crash occurs

 EDGE CASE: Very large rect
 GIVEN: A rect of 10000x10000
 WHEN: drawDottedPattern is called
 THEN: CGPattern efficiently tiles the area
  AND: Performance is acceptable

 EDGE CASE: Negative spacing
 GIVEN: configuration with spacing = -10
 WHEN: drawDottedPattern is called
 THEN: Nothing is drawn
  AND: No crash occurs
*/

// MARK: - Coordinate System

/*
 COORDINATE SYSTEM DOCUMENTATION:

 The PDF document canvas uses a continuous vertical coordinate system where:
 - Origin (0, 0) is at the top-left corner of the first block
 - Y increases downward
 - X spans the full width of the container

 Block Layout:
   Y = 0          +---------------------------+
                  |        Block 0            |
                  |       (PDF Page 1)        |
   Y = h0         +---------------------------+
                  |        Block 1            |
                  |       (Spacer)            |
   Y = h0+h1      +---------------------------+
                  |        Block 2            |
                  |       (PDF Page 2)        |
   Y = total      +---------------------------+

 Zoom Transformation:
 - Base coordinates are stored without zoom (blockYOffsets)
 - Display coordinates = base coordinates * currentZoomScale
 - contentOffset is in display coordinates
 - PDFBackgroundLayer draws using display coordinates
 - MyScript ink is captured in its own coordinate space

 Scroll View Metrics:
 - contentSize.height = calculateTotalContentHeight() (includes zoom)
 - contentSize.width = container width * currentZoomScale
 - contentOffset tracks the top-left visible point

 MyScript Integration:
 - Single IINKEditor overlays entire scroll content
 - Editor view size matches contentSize
 - Each block has a myScriptPartID linking to annotation storage
 - Part switching occurs when the active block changes (if needed)
*/

// MARK: - Zooming Behavior

/*
 ZOOMING BEHAVIOR SPECIFICATION:

 Zoom Range:
 - Minimum zoom: 1.0 (fit to width)
 - Maximum zoom: 4.0 (400% magnification)

 Zoom Gestures:
 - Pinch gesture on the document view
 - Double-tap to toggle between 1.0 and 2.0
 - Zoom centers on the gesture focal point

 Content Scaling:
 - PDF pages are rendered at the current zoom scale
 - Dotted grids scale proportionally
 - MyScript ink scales with the view transform

 Performance:
 - Tile-based rendering for PDF pages at high zoom
 - Only visible tiles are in memory
 - Tiles are generated on-demand during scroll

 Zoom Change Events:
 1. User begins pinch gesture
 2. currentZoomScale updates continuously
 3. contentSize is recalculated
 4. blockYOffsets are scaled for display
 5. PDFBackgroundLayer redraws visible content
 6. User ends gesture, final scale is committed
*/

// MARK: - Memory Management

/*
 MEMORY MANAGEMENT STRATEGY:

 PDF Page Caching:
 - PDFDocument handles internal page caching
 - Pages are drawn directly to the layer, not cached as images
 - PDF rendering scales to current zoom level

 Tile Management (PDFBackgroundLayer):
 - Visible rect + buffer zone tiles are kept in memory
 - Tiles outside 2x visible rect are released
 - Tile size is based on screen dimensions

 MyScript Ink:
 - Ink strokes are managed by the MyScript SDK
 - Rendering is handled by DisplayViewController
 - Package file backs persistent storage

 View Hierarchy:
 - PDFDocumentView is the scroll view
 - PDFBackgroundLayer is a CALayer subclass (not a view)
 - InputViewController manages ink input/display views

 Low Memory Handling:
 - Register for UIApplication.didReceiveMemoryWarningNotification
 - Release non-visible tiles
 - PDFDocument releases cached pages
*/

// MARK: - Thread Safety

/*
 THREAD SAFETY REQUIREMENTS:

 Main Thread:
 - All UIKit operations (PDFDocumentView, PDFBackgroundLayer drawing)
 - PDFPage.draw() must be called on main thread
 - MyScript IINKEditor operations

 Background Thread:
 - PDFDocumentHandle.savePackage() can run on background
 - Tile generation (if implemented) can be background

 Actor Isolation:
 - PDFDocumentHandle should be an actor for safe file operations
 - BundleManager patterns from existing codebase apply

 Synchronization:
 - blockYOffsets array is read-only after calculation
 - Recalculation happens on main thread only
 - Zoom scale updates are synchronized with rendering
*/

// MARK: - Integration with Existing Codebase

/*
 INTEGRATION NOTES:

 This feature replaces PDFCollectionViewController for the unified canvas approach.
 The collection view implementation remains for reference but will not be used.

 Shared Components:
 - DottedGridConfiguration from PDFDisplayContract.swift
 - NoteDocument and NoteBlock from PDFImport/Contract.swift
 - ContentPartProtocol and related protocols from SDKProtocols.swift
 - InputViewController from Frameworks/Ink/Input/

 Storage Integration:
 - Uses PDFNoteStorage for document directories
 - Creates PDFDocumentHandle (new actor) for open document management
 - Follows DocumentHandle patterns for package lifecycle

 MyScript Integration:
 - Reuses EngineProvider.sharedInstance for engine access
 - Creates single InputViewController for entire document
 - Part switching may be needed when scrolling between blocks
   (implementation detail to be determined)

 Navigation:
 - PDFDocumentViewController is presented from Dashboard
 - Configure with PDFDocumentHandle before presentation
 - Back button closes handle and returns to Dashboard
*/

// MARK: - Future Extensions (Not Part of Current Contract)

/*
 FUTURE FEATURES (documented for context, not implemented now):

 1. Thumbnail Navigation
    - Sidebar with page thumbnails
    - Tap to scroll to page
    - Highlight current visible page

 2. Search in PDF
    - Text search using PDFDocument.findString
    - Highlight matches
    - Navigate between results

 3. Annotations Export
    - Flatten ink onto PDF pages
    - Export as new PDF file
    - Share via system share sheet

 4. Split View
    - Two-page spread view for landscape
    - Synchronized scrolling

 5. Page Rotation
    - Rotate individual pages
    - Persist rotation in NoteDocument

 These features will have their own contracts when implemented.
*/

// ============================================================================
// PHASE 4: INPUT INTEGRATION CONTRACT
// ============================================================================
//
// This section specifies the ink input layer integration for PDF annotation.
// The goal is to wire InputViewController into PDFDocumentViewController so
// users can draw on the PDF. The single IINKEditor overlays the entire document,
// with part switching occurring when touches land on different blocks.
//
// Key components:
//   - PDFInkOverlayProvider: Adding ink overlay to the document view
//   - PDFBlockLocator: Finding which block a touch lands in
//   - PDFPartSwitching: Switching the active MyScript part
//   - PDFToolApplication: Applying tool state to the editor
//
// The InputViewController uses its own scroll/zoom handling via InputViewModel,
// but the PDF canvas requires coordination between UIScrollView and MyScript.

// MARK: - Phase 4 Error Types

// Errors specific to input integration operations.
// Extends the existing PDFDocumentError with input-related cases.
enum PDFInputError: LocalizedError, Equatable {
  // The ink overlay has not been set up.
  case inkOverlayNotConfigured

  // Touch occurred outside all block boundaries.
  case touchOutsideBounds(touchY: CGFloat, totalContentHeight: CGFloat)

  // Failed to switch to a different MyScript part.
  // partID: The identifier of the part that could not be loaded.
  case partSwitchFailed(partID: String, underlyingError: String)

  // The editor is not available for tool application.
  case editorNotAvailable

  // Invalid tool selection received.
  case invalidToolSelection

  var errorDescription: String? {
    switch self {
    case .inkOverlayNotConfigured:
      return "The ink input layer has not been configured."
    case .touchOutsideBounds(let touchY, let totalHeight):
      return "Touch at Y=\(touchY) is outside document bounds (height=\(totalHeight))."
    case .partSwitchFailed(let partID, let error):
      return "Failed to switch to annotation layer '\(partID)': \(error)"
    case .editorNotAvailable:
      return "The annotation editor is not available."
    case .invalidToolSelection:
      return "Invalid tool selection."
    }
  }
}

/*
 ACCEPTANCE CRITERIA: PDFInputError

 SCENARIO: Error provides localized description
 GIVEN: Any PDFInputError case
 WHEN: errorDescription is accessed
 THEN: A non-nil user-facing message is returned

 SCENARIO: Error equality for touchOutsideBounds
 GIVEN: Two identical touchOutsideBounds errors
 WHEN: Compared for equality
 THEN: They are equal

 GIVEN: Two touchOutsideBounds errors with different values
 WHEN: Compared for equality
 THEN: They are not equal
*/

// MARK: - PDFInkOverlayProvider Protocol

// Protocol for adding the ink input overlay to the document view.
// The ink overlay captures touch input and renders strokes.
// It must be positioned to cover the entire scrollable content area.
protocol PDFInkOverlayProvider: AnyObject {
  // Adds the ink overlay view to the document's content area.
  // The overlay is positioned on top of the PDF background layer.
  // The overlay's frame matches the scroll view's contentSize.
  //
  // overlay: The UIView from InputViewController that captures touches.
  //
  // After this call, the overlay receives touch events for ink input.
  func addInkOverlay(_ overlay: UIView)

  // Updates the ink overlay frame when content size changes.
  // Called when zoom or layout changes affect contentSize.
  //
  // newSize: The updated contentSize of the scroll view.
  func updateInkOverlayFrame(to newSize: CGSize)

  // Returns the current bounds of the ink overlay in content coordinates.
  var inkOverlayBounds: CGRect { get }
}

/*
 ACCEPTANCE CRITERIA: PDFInkOverlayProvider.addInkOverlay

 SCENARIO: Add ink overlay to empty document view
 GIVEN: A PDFDocumentView with no ink overlay
  AND: An InputViewController's view as the overlay
 WHEN: addInkOverlay is called
 THEN: The overlay is added to the inkOverlayContainer
  AND: The overlay's frame equals the contentSize
  AND: The overlay is positioned above the background layer
  AND: Touch events reach the overlay for ink capture

 SCENARIO: Add ink overlay with existing content
 GIVEN: A PDFDocumentView displaying a 3-page PDF
  AND: contentSize is (width: 612, height: 2376)
 WHEN: addInkOverlay is called
 THEN: The overlay's frame is (0, 0, 612, 2376)
  AND: The overlay covers all three pages

 SCENARIO: Overlay respects zoom scale
 GIVEN: A PDFDocumentView at zoom scale 2.0
  AND: Base contentSize is (612, 2376)
 WHEN: addInkOverlay is called
 THEN: The overlay's frame reflects zoomed size (1224, 4752)
*/

/*
 ACCEPTANCE CRITERIA: PDFInkOverlayProvider.updateInkOverlayFrame

 SCENARIO: Update overlay after zoom change
 GIVEN: A PDFDocumentView with ink overlay at zoom 1.0
  AND: Overlay frame is (0, 0, 612, 2376)
 WHEN: Zoom changes to 2.0 and updateInkOverlayFrame is called
 THEN: Overlay frame becomes (0, 0, 1224, 4752)

 SCENARIO: Update overlay after layout change
 GIVEN: A PDFDocumentView with ink overlay
  AND: Device rotates changing container width
 WHEN: updateInkOverlayFrame is called with new size
 THEN: Overlay frame updates to match new dimensions
*/

/*
 EDGE CASES: PDFInkOverlayProvider

 EDGE CASE: Add overlay before view is laid out
 GIVEN: A PDFDocumentView with zero bounds
 WHEN: addInkOverlay is called
 THEN: Overlay is added with zero frame
  AND: Frame updates when layoutSubviews triggers

 EDGE CASE: Update frame with zero size
 GIVEN: A PDFDocumentView with ink overlay
 WHEN: updateInkOverlayFrame(to: .zero) is called
 THEN: Overlay frame becomes zero
  AND: No crash occurs

 EDGE CASE: Add overlay multiple times
 GIVEN: A PDFDocumentView with existing ink overlay
 WHEN: addInkOverlay is called again with a new view
 THEN: The previous overlay is replaced
  AND: Only one overlay exists in the view hierarchy
*/

// MARK: - PDFBlockLocator Protocol

// Protocol for finding which block contains a given point.
// Used to determine which MyScript part should receive the stroke.
// The locator uses binary search through precomputed block Y offsets.
protocol PDFBlockLocator: AnyObject {
  // Finds the block index for a given Y offset in unscaled content coordinates.
  // Uses binary search through blockYOffsets for O(log n) performance.
  //
  // yOffset: The Y position in unscaled content coordinates.
  //
  // Returns: The zero-based block index, or nil if outside all blocks.
  func blockIndex(for yOffset: CGFloat) -> Int?

  // Converts a point from the overlay's coordinate space to unscaled content coordinates.
  // Accounts for current zoom scale and content offset.
  //
  // point: The point in the overlay/InputView coordinate space.
  //
  // Returns: The corresponding point in unscaled content coordinates.
  func convertToContentCoordinates(_ point: CGPoint) -> CGPoint

  // Returns the Y offset range for a specific block.
  // blockIndex: Zero-based index of the block.
  //
  // Returns: Tuple of (startY, endY) in unscaled coordinates, or nil if invalid index.
  func blockYRange(for blockIndex: Int) -> (startY: CGFloat, endY: CGFloat)?
}

/*
 ACCEPTANCE CRITERIA: PDFBlockLocator.blockIndex

 SCENARIO: Find block at document start
 GIVEN: blockYOffsets = [0, 792, 1584]
  AND: Block heights are [792, 792, 792]
 WHEN: blockIndex(for: 0) is called
 THEN: Returns 0

 SCENARIO: Find block in middle of first page
 GIVEN: blockYOffsets = [0, 792, 1584]
 WHEN: blockIndex(for: 400) is called
 THEN: Returns 0

 SCENARIO: Find block at exact boundary
 GIVEN: blockYOffsets = [0, 792, 1584]
 WHEN: blockIndex(for: 792) is called
 THEN: Returns 1 (boundary belongs to next block)

 SCENARIO: Find block in last page
 GIVEN: blockYOffsets = [0, 792, 1584] with total height 2376
 WHEN: blockIndex(for: 2000) is called
 THEN: Returns 2

 SCENARIO: Touch beyond document end
 GIVEN: blockYOffsets = [0, 792, 1584] with total height 2376
 WHEN: blockIndex(for: 3000) is called
 THEN: Returns nil
*/

/*
 ACCEPTANCE CRITERIA: PDFBlockLocator.convertToContentCoordinates

 SCENARIO: Convert at zoom 1.0
 GIVEN: currentZoomScale = 1.0
  AND: A point at (100, 500) in overlay coordinates
 WHEN: convertToContentCoordinates is called
 THEN: Returns (100, 500)

 SCENARIO: Convert at zoom 2.0
 GIVEN: currentZoomScale = 2.0
  AND: A point at (200, 1000) in overlay coordinates
 WHEN: convertToContentCoordinates is called
 THEN: Returns (100, 500) (divided by zoom)

 SCENARIO: Convert with content offset
 GIVEN: currentZoomScale = 1.0
  AND: contentOffset.y = 100
  AND: A point at (100, 500) in overlay coordinates
 WHEN: convertToContentCoordinates is called
 THEN: Returns (100, 500) (offset does not affect content coords)
*/

/*
 ACCEPTANCE CRITERIA: PDFBlockLocator.blockYRange

 SCENARIO: Get range for first block
 GIVEN: blockYOffsets = [0, 792, 1584]
  AND: Block 0 has height 792
 WHEN: blockYRange(for: 0) is called
 THEN: Returns (startY: 0, endY: 792)

 SCENARIO: Get range for middle block
 GIVEN: blockYOffsets = [0, 792, 1584]
  AND: Block 1 has height 792
 WHEN: blockYRange(for: 1) is called
 THEN: Returns (startY: 792, endY: 1584)

 SCENARIO: Get range for last block
 GIVEN: blockYOffsets = [0, 792, 1584]
  AND: Block 2 has height 792
 WHEN: blockYRange(for: 2) is called
 THEN: Returns (startY: 1584, endY: 2376)

 SCENARIO: Invalid block index
 GIVEN: blockYOffsets = [0, 792, 1584]
 WHEN: blockYRange(for: 10) is called
 THEN: Returns nil
*/

/*
 EDGE CASES: PDFBlockLocator

 EDGE CASE: Negative Y offset
 GIVEN: A valid document
 WHEN: blockIndex(for: -100) is called
 THEN: Returns nil

 EDGE CASE: Empty document
 GIVEN: A document with no blocks (blockYOffsets = [])
 WHEN: blockIndex(for: 0) is called
 THEN: Returns nil

 EDGE CASE: Single block document
 GIVEN: blockYOffsets = [0] with height 792
 WHEN: blockIndex(for: 400) is called
 THEN: Returns 0

 EDGE CASE: Very small touch difference
 GIVEN: blockYOffsets = [0, 792]
 WHEN: blockIndex(for: 791.99999) is called
 THEN: Returns 0 (still in first block)

 EDGE CASE: Negative block index
 GIVEN: A valid document
 WHEN: blockYRange(for: -1) is called
 THEN: Returns nil
*/

// MARK: - PDFPartSwitchingDelegate Protocol

// Delegate protocol for receiving part switching events.
// The view controller implements this to respond to block changes.
protocol PDFPartSwitchingDelegate: AnyObject {
  // Called when a touch initiates on a different block.
  // The delegate should load the corresponding MyScript part.
  //
  // newBlockIndex: The index of the block receiving the touch.
  // partID: The myScriptPartID for the block.
  func willSwitchToBlock(at newBlockIndex: Int, partID: String)

  // Called after successfully switching to a new part.
  //
  // newBlockIndex: The index of the block now active.
  func didSwitchToBlock(at newBlockIndex: Int)

  // Called if part switching fails.
  //
  // error: The error that occurred during switching.
  func partSwitchFailed(with error: PDFInputError)
}

/*
 ACCEPTANCE CRITERIA: PDFPartSwitchingDelegate

 SCENARIO: Delegate receives willSwitch notification
 GIVEN: A PDFDocumentViewController implementing PDFPartSwitchingDelegate
  AND: User touches block 2
 WHEN: Part switch is initiated
 THEN: willSwitchToBlock(at: 2, partID: "part-id-2") is called

 SCENARIO: Delegate receives didSwitch notification
 GIVEN: Part switch completes successfully
 WHEN: New part is loaded into editor
 THEN: didSwitchToBlock(at: 2) is called

 SCENARIO: Delegate receives failure notification
 GIVEN: Part switch fails (part not found)
 WHEN: Error occurs during switch
 THEN: partSwitchFailed(with: .partSwitchFailed(...)) is called
*/

// MARK: - PDFPartSwitching Protocol

// Protocol for switching the active MyScript part based on touch location.
// Coordinates between the block locator, document handle, and editor.
protocol PDFPartSwitching: AnyObject {
  // The index of the currently active block.
  // -1 indicates no block is active (initial state).
  var activeBlockIndex: Int { get }

  // Delegate receiving part switching events.
  var partSwitchingDelegate: PDFPartSwitchingDelegate? { get set }

  // Handles touch-down by determining the target block and switching parts if needed.
  // Called at the beginning of each stroke before any touch data is sent to the editor.
  //
  // touchPoint: The touch location in content coordinates.
  //
  // Returns: The block index that will receive the stroke, or nil if outside bounds.
  //
  // If the touch lands on a different block than activeBlockIndex, the part is switched
  // before returning. The delegate is notified of the switch.
  func handleTouchDown(at touchPoint: CGPoint) async throws -> Int?

  // Switches the editor to the part for the specified block.
  // Called internally by handleTouchDown or can be called directly for programmatic switching.
  //
  // blockIndex: The zero-based index of the target block.
  //
  // Throws: PDFInputError.partSwitchFailed if the part cannot be loaded.
  func switchToBlock(at blockIndex: Int) async throws
}

/*
 ACCEPTANCE CRITERIA: PDFPartSwitching.handleTouchDown

 SCENARIO: Touch on current block (no switch needed)
 GIVEN: activeBlockIndex is 0
  AND: Touch lands at Y=400 (within block 0)
 WHEN: handleTouchDown is called
 THEN: Returns 0
  AND: activeBlockIndex remains 0
  AND: No part switch occurs
  AND: Delegate is not notified

 SCENARIO: Touch on different block (switch needed)
 GIVEN: activeBlockIndex is 0
  AND: Touch lands at Y=900 (within block 1)
 WHEN: handleTouchDown is called
 THEN: Returns 1
  AND: activeBlockIndex becomes 1
  AND: Part for block 1 is loaded into editor
  AND: Delegate receives willSwitchToBlock and didSwitchToBlock

 SCENARIO: Touch outside document bounds
 GIVEN: Document total height is 2376
  AND: Touch lands at Y=3000
 WHEN: handleTouchDown is called
 THEN: Returns nil
  AND: activeBlockIndex does not change
  AND: No error is thrown (touch is ignored)

 SCENARIO: First touch sets initial block
 GIVEN: activeBlockIndex is -1 (initial state)
  AND: Touch lands at Y=400 (within block 0)
 WHEN: handleTouchDown is called
 THEN: Returns 0
  AND: activeBlockIndex becomes 0
  AND: Part for block 0 is loaded into editor
  AND: Delegate receives willSwitchToBlock and didSwitchToBlock
*/

/*
 ACCEPTANCE CRITERIA: PDFPartSwitching.switchToBlock

 SCENARIO: Switch to valid block
 GIVEN: A document with 3 blocks
  AND: Block 1 has myScriptPartID "part-1"
 WHEN: switchToBlock(at: 1) is called
 THEN: Part "part-1" is retrieved from PDFDocumentHandle
  AND: Part is loaded into the IINKEditor
  AND: activeBlockIndex becomes 1
  AND: No error is thrown

 SCENARIO: Switch to invalid block index
 GIVEN: A document with 3 blocks
 WHEN: switchToBlock(at: 10) is called
 THEN: Throws PDFInputError.partSwitchFailed
  AND: activeBlockIndex does not change

 SCENARIO: Switch when part not found
 GIVEN: A document with block referencing non-existent part
 WHEN: switchToBlock is called for that block
 THEN: Throws PDFInputError.partSwitchFailed
  AND: activeBlockIndex does not change
  AND: Delegate receives partSwitchFailed
*/

/*
 EDGE CASES: PDFPartSwitching

 EDGE CASE: Switch to same block
 GIVEN: activeBlockIndex is 2
 WHEN: switchToBlock(at: 2) is called
 THEN: No part reload occurs (optimization)
  AND: activeBlockIndex remains 2
  AND: No delegate notifications

 EDGE CASE: Rapid consecutive touches on different blocks
 GIVEN: User rapidly taps block 0, then block 1, then block 2
 WHEN: handleTouchDown is called for each touch
 THEN: Each switch completes in order
  AND: Final activeBlockIndex is 2
  AND: No race conditions occur

 EDGE CASE: Touch during active stroke
 GIVEN: A stroke is in progress on block 0
  AND: Another touch begins on block 1
 WHEN: handleTouchDown is called for the new touch
 THEN: Part switch is deferred until current stroke ends
  OR: New touch is ignored (implementation choice)

 EDGE CASE: Document handle closed
 GIVEN: PDFDocumentHandle has been closed
 WHEN: switchToBlock is called
 THEN: Throws PDFInputError.partSwitchFailed
  AND: Error message indicates handle is closed

 EDGE CASE: Negative block index
 GIVEN: A valid document
 WHEN: switchToBlock(at: -1) is called
 THEN: Throws PDFInputError.partSwitchFailed
*/

// MARK: - PDFToolApplication Protocol

// Protocol for applying tool palette selections to the editor.
// Maps ToolPaletteView.ToolSelection to IINKPointerTool and applies ink styles.
protocol PDFToolApplication: AnyObject {
  // The currently active IINKEditor, if available.
  var activeEditor: IINKEditor? { get }

  // Applies the current tool selection to the editor.
  // Maps ToolPaletteView.ToolSelection to the corresponding IINKPointerTool.
  // Also applies the current ink color and width for pen/highlighter tools.
  //
  // selection: The tool selected in the palette.
  // colorHex: The hex color string (e.g., "#000000") for pen/highlighter.
  // width: The stroke width in millimeters.
  //
  // Throws: PDFInputError.editorNotAvailable if editor is nil.
  func applyTool(
    selection: ToolPaletteView.ToolSelection,
    colorHex: String,
    width: CGFloat
  ) throws

  // Applies only the ink style without changing the tool.
  // Used when color or thickness changes without changing tool type.
  //
  // colorHex: The hex color string.
  // width: The stroke width in millimeters.
  // tool: The IINKPointerTool to apply the style to.
  //
  // Throws: PDFInputError.editorNotAvailable if editor is nil.
  func applyInkStyle(colorHex: String, width: CGFloat, tool: IINKPointerTool) throws

  // Applies the tool to both pen and touch pointer types.
  // When in pen mode, touch follows the same tool as pen.
  // When in touch mode, touch is set to hand (pan) tool.
  //
  // tool: The IINKPointerTool to apply.
  // inputMode: The current input mode (forcePen or forceTouch).
  //
  // Throws: PDFInputError.editorNotAvailable if editor is nil.
  func applyToolForInputMode(tool: IINKPointerTool, inputMode: InputMode) throws
}

/*
 ACCEPTANCE CRITERIA: PDFToolApplication.applyTool

 SCENARIO: Apply pen tool
 GIVEN: An active IINKEditor
  AND: selection is .pen
  AND: colorHex is "#000000"
  AND: width is 0.65
 WHEN: applyTool is called
 THEN: Editor's tool is set to .toolPen for pen pointer type
  AND: Ink style is set to "color:#000000;-myscript-pen-width:0.650"
  AND: No error is thrown

 SCENARIO: Apply highlighter tool
 GIVEN: An active IINKEditor
  AND: selection is .highlighter
  AND: colorHex is "#FFF176"
  AND: width is 5.0
 WHEN: applyTool is called
 THEN: Editor's tool is set to .toolHighlighter for pen pointer type
  AND: Ink style is set appropriately

 SCENARIO: Apply eraser tool
 GIVEN: An active IINKEditor
  AND: selection is .eraser
 WHEN: applyTool is called
 THEN: Editor's tool is set to .eraser for pen pointer type
  AND: Ink style is not applied (eraser has no style)

 SCENARIO: Apply tool when editor unavailable
 GIVEN: activeEditor is nil
 WHEN: applyTool is called
 THEN: Throws PDFInputError.editorNotAvailable
*/

/*
 ACCEPTANCE CRITERIA: PDFToolApplication.applyToolForInputMode

 SCENARIO: Apply tool in pen mode
 GIVEN: inputMode is .forcePen
  AND: tool is .toolPen
 WHEN: applyToolForInputMode is called
 THEN: Pen pointer type is set to .toolPen
  AND: Touch pointer type is also set to .toolPen

 SCENARIO: Apply tool in touch mode
 GIVEN: inputMode is .forceTouch
  AND: tool is .toolPen
 WHEN: applyToolForInputMode is called
 THEN: Pen pointer type is set to .toolPen
  AND: Touch pointer type is set to .hand (for panning)
*/

/*
 EDGE CASES: PDFToolApplication

 EDGE CASE: Empty color hex string
 GIVEN: colorHex is ""
 WHEN: applyTool is called
 THEN: The style string uses empty color (implementation behavior)
  AND: No crash occurs

 EDGE CASE: Invalid color hex format
 GIVEN: colorHex is "red" (not hex format)
 WHEN: applyTool is called
 THEN: The style string uses the provided value
  AND: MyScript handles invalid color gracefully

 EDGE CASE: Zero width
 GIVEN: width is 0
 WHEN: applyTool is called
 THEN: The style string uses width 0
  AND: Strokes may not be visible (SDK behavior)

 EDGE CASE: Negative width
 GIVEN: width is -1.0
 WHEN: applyTool is called
 THEN: The style string uses the negative value
  AND: SDK handles gracefully (likely treats as 0)

 EDGE CASE: Very large width
 GIVEN: width is 100.0
 WHEN: applyTool is called
 THEN: The style string uses the large value
  AND: SDK may clamp to maximum supported width
*/

// MARK: - PDFEditorDelegate Protocol

// Extended EditorDelegate for PDF-specific editor lifecycle events.
// PDFDocumentViewController conforms to this for editor integration.
protocol PDFEditorDelegate: EditorDelegate {
  // Called when the editor is ready to receive a part.
  // This is the opportunity to load the first block's part.
  //
  // editor: The newly created IINKEditor.
  func editorReadyForPart(_ editor: IINKEditor)

  // Called when the view controller should apply the current tool state.
  // Triggered after editor creation and after part switches.
  //
  // editor: The active IINKEditor.
  func shouldApplyToolState(to editor: IINKEditor)
}

/*
 ACCEPTANCE CRITERIA: PDFEditorDelegate

 SCENARIO: Editor creation triggers part loading
 GIVEN: PDFDocumentViewController conforms to PDFEditorDelegate
  AND: Document has 3 blocks
 WHEN: didCreateEditor is called
 THEN: editorReadyForPart is called
  AND: First block's part is loaded into editor
  AND: activeBlockIndex becomes 0

 SCENARIO: Tool state applied after editor creation
 GIVEN: Current tool is .highlighter with color "#FFF176"
 WHEN: didCreateEditor is called
 THEN: shouldApplyToolState is called
  AND: Editor has highlighter tool applied
  AND: Ink style matches current settings

 SCENARIO: Tool state applied after part switch
 GIVEN: Tool state is pen with black color
 WHEN: Part switch completes
 THEN: shouldApplyToolState is called
  AND: Editor tool state is reapplied to new part
*/

// MARK: - PDFInputCoordinator Protocol

// High-level coordinator protocol that combines all input-related functionality.
// Implemented by PDFDocumentViewController to manage the complete input pipeline.
protocol PDFInputCoordinator: PDFInkOverlayProvider, PDFBlockLocator, PDFPartSwitching, PDFToolApplication {
  // The document handle providing access to MyScript parts.
  var documentHandle: PDFDocumentHandle? { get }

  // The input view controller managing ink capture.
  var inkInputViewController: InputViewController? { get }

  // Sets up the complete ink input pipeline.
  // Creates InputViewModel and InputViewController.
  // Adds ink overlay to document view.
  // Wires up touch handling for part switching.
  //
  // Throws: PDFDocumentError.engineNotAvailable if engine not initialized.
  func setupInkInput() async throws

  // Tears down the ink input pipeline.
  // Releases InputViewController and associated resources.
  func teardownInkInput()
}

/*
 ACCEPTANCE CRITERIA: PDFInputCoordinator.setupInkInput

 SCENARIO: Successful setup
 GIVEN: PDFDocumentViewController with valid documentHandle
  AND: MyScript engine is initialized
 WHEN: setupInkInput() is called
 THEN: InputViewModel is created with engine and delegate
  AND: InputViewController is created and added as child
  AND: Ink overlay is added to inkOverlayContainer
  AND: First block's part is loaded into editor
  AND: Current tool state is applied

 SCENARIO: Setup when engine unavailable
 GIVEN: MyScript engine is not initialized
 WHEN: setupInkInput() is called
 THEN: Throws PDFDocumentError.engineNotAvailable
  AND: No InputViewController is created

 SCENARIO: Setup when document handle missing
 GIVEN: documentHandle is nil
 WHEN: setupInkInput() is called
 THEN: Throws appropriate error
  AND: No InputViewController is created
*/

/*
 ACCEPTANCE CRITERIA: PDFInputCoordinator.teardownInkInput

 SCENARIO: Teardown releases resources
 GIVEN: Ink input has been set up
 WHEN: teardownInkInput() is called
 THEN: InputViewController is removed from parent
  AND: Ink overlay is removed from view hierarchy
  AND: activeBlockIndex resets to -1
  AND: activeEditor reference is cleared
*/

// MARK: - Integration Sequence

/*
 INPUT INTEGRATION SEQUENCE:

 1. PDFDocumentViewController.viewDidLoad()
    - Calls setupDocumentView() (existing)
    - Calls setupInkInput() (new)

 2. setupInkInput()
    a. Get engine from EngineProvider.sharedInstance
    b. Create InputViewModel with engine, .forcePen mode, self as delegate
    c. Create InputViewController with viewModel
    d. Add InputViewController as child view controller
    e. Call documentView.addInkOverlay(inputVC.view)
    f. Store reference to InputViewController

 3. InputViewModel.setupModel() [internal]
    a. Creates IINKEditor via engine
    b. Calls editorDelegate.didCreateEditor(editor)

 4. PDFDocumentViewController.didCreateEditor() [EditorDelegate]
    a. Store reference to editor (activeEditor)
    b. Apply Raw Content configuration (optional for PDF)
    c. Call editorReadyForPart(editor)
    d. Call shouldApplyToolState(to: editor)

 5. editorReadyForPart()
    a. Load first block's part: documentHandle.part(for: blocks[0].myScriptPartID)
    b. Set part on editor: editor.set(part: part)
    c. Set activeBlockIndex = 0

 6. User touches screen
    a. Touch event reaches InputView
    b. Before sending to editor, handleTouchDown(at: point) is called
    c. If touch is on different block:
       - Switch part: switchToBlock(at: newIndex)
       - Apply tool state: shouldApplyToolState(to: editor)
    d. Touch data sent to editor for ink capture

 7. Part switch during stroke
    a. Current stroke completes on current block
    b. New stroke starts on new block with new part
    c. Ink renders correctly in both parts

 COORDINATE FLOW:

   Touch (screen coords)
         |
         v
   InputView (captures touch)
         |
         v
   convertToContentCoordinates() <- Divides by zoom
         |
         v
   blockIndex(for: yOffset) <- Binary search
         |
         v
   Block index determines part
         |
         v
   Part loaded, stroke captured
*/

// MARK: - Tool Mapping

/*
 TOOL MAPPING SPECIFICATION:

 ToolPaletteView.ToolSelection -> IINKPointerTool:
   .pen        -> .toolPen
   .highlighter -> .toolHighlighter
   .eraser     -> .eraser

 Ink Style Format:
   "color:{colorHex};-myscript-pen-width:{width}"

 Example:
   .pen with "#FF0000" and width 1.0:
   "color:#FF0000;-myscript-pen-width:1.000"

 Input Mode Tool Behavior:
   - forcePen mode:
     - pen pointer: selected tool
     - touch pointer: selected tool (touch draws)
   - forceTouch mode:
     - pen pointer: selected tool
     - touch pointer: .hand (touch pans)
   - auto mode (not used for PDF):
     - pen pointer: selected tool
     - touch pointer: .hand (touch pans)
*/

// MARK: - View Hierarchy After Integration

/*
 VIEW HIERARCHY:

 PDFDocumentViewController.view
   |
   +-- PDFDocumentView (UIScrollView)
   |     |
   |     +-- contentView (UIView)
   |           |
   |           +-- PDFBackgroundLayer (renders PDF pages)
   |           |
   |           +-- inkOverlayContainer (UIView)
   |                 |
   |                 +-- InputViewController.view
   |                       |
   |                       +-- containerView (white background, hidden for PDF)
   |                       |     |
   |                       |     +-- DisplayViewController.view (renders ink)
   |                       |
   |                       +-- InputView (captures touches)
   |
   +-- ToolPaletteView (floating)
   |
   +-- EditingToolbarView (floating)

 NOTE: For PDF canvas, the InputViewController's containerView should have
 transparent background instead of white, so PDF shows through.
*/

// MARK: - Memory and Performance Considerations

/*
 PERFORMANCE NOTES:

 Part Switching:
 - Part switch involves loading part from package (async)
 - Should be fast (<50ms) for responsive touch experience
 - Consider preloading adjacent parts for faster switching

 Binary Search:
 - blockIndex(for:) uses O(log n) binary search
 - Suitable for documents with many blocks
 - blockYOffsets array must be sorted (guaranteed by layout)

 Editor State:
 - Tool state is applied to ToolController, not individual parts
 - Single editor instance reuses renderer and configuration
 - Part switch preserves tool settings

 Ink Rendering:
 - DisplayViewController renders current part's ink
 - Part switch triggers re-render of new part's content
 - Previous part's ink is preserved in package

 Memory:
 - Only one part is active in editor at a time
 - Inactive parts remain in package file
 - Part cache in PDFDocumentHandle prevents repeated loading
*/

// MARK: - Thread Safety

/*
 THREAD SAFETY REQUIREMENTS:

 Main Thread:
 - All UIKit operations (adding overlay, touch handling)
 - IINKEditor operations (tool selection, part setting)
 - InputViewController and InputViewModel methods

 Actor Isolation:
 - PDFDocumentHandle.part(for:) is async actor method
 - Part retrieval happens on handle's actor
 - Result is passed back to main thread for editor

 Async Part Switch:
 - switchToBlock must await part retrieval
 - Touch handling may need to be async
 - Consider using MainActor for coordinator methods

 Synchronization:
 - activeBlockIndex must be updated atomically with part switch
 - Prevent race between touch handling and part loading
 - Use Task for sequential async operations
*/

// ============================================================================
// PHASE 4B: INPUT LAYER WIRING CONTRACT
// ============================================================================
//
// This section specifies the wiring of InputViewController to PDFDocumentViewController
// for ink capture. Extends the Phase 4 input integration with specific protocols for
// the mechanics of setting up, coordinating, and managing the input layer.
//
// Key components:
//   - PDFInkInputWiring: Creating and positioning InputViewController
//   - PDFEditorLifecycle: Loading initial part and auto-save scheduling
//   - PDFZoomCoordination: UIScrollView-only zoom with MyScript at scale 1.0
//   - Gesture-based part switching before stroke processing

// MARK: - PDFInkInputWiring Protocol

// Protocol for setting up the ink input layer in PDFDocumentViewController.
// Handles the creation of InputViewController, wiring to the document view,
// and gesture setup for stroke-based part switching.
protocol PDFInkInputWiring: AnyObject {
  // The input view controller managing ink capture.
  // Nil before setupInkInput() is called or after teardownInkInput().
  var inkInputViewController: InputViewController? { get }

  // Sets up the complete ink input pipeline.
  // Creates InputViewModel and InputViewController.
  // Adds InputViewController as child view controller.
  // Positions input view over PDF background in inkOverlayContainer.
  // Wires part switching gesture recognizer.
  //
  // Must be called after documentView is set up.
  //
  // Throws: PDFDocumentError.engineNotAvailable if MyScript engine not initialized.
  // Throws: PDFInputError.inkOverlayNotConfigured if documentView is nil.
  func setupInkInput() async throws

  // Wires the gesture recognizer for stroke-based part switching.
  // Uses UILongPressGestureRecognizer with minimumPressDuration=0 to detect
  // touch-down before the stroke is processed by MyScript.
  // The gesture triggers handleTouchDown(at:) to switch parts if needed.
  //
  // Called internally by setupInkInput(). Can be called separately to rewire
  // if the input view is recreated.
  func wirePartSwitchingGesture()

  // Tears down the ink input pipeline.
  // Removes InputViewController from parent.
  // Removes ink overlay from view hierarchy.
  // Clears activeBlockIndex to -1.
  // Called when view controller is dismissed or document is closed.
  func teardownInkInput()
}

/*
 ACCEPTANCE CRITERIA: PDFInkInputWiring.setupInkInput

 SCENARIO: Successful ink input setup
 GIVEN: PDFDocumentViewController with valid documentView
  AND: PDFDocumentHandle is configured
  AND: MyScript engine is initialized via EngineProvider.sharedInstance
 WHEN: setupInkInput() is called
 THEN: InputViewModel is created with engine and self as EditorDelegate
  AND: InputViewController is created with the InputViewModel
  AND: InputViewController is added as child view controller
  AND: InputViewController.view is added to inkOverlayContainer via addInkOverlay()
  AND: Part switching gesture is wired via wirePartSwitchingGesture()
  AND: inkInputViewController property is non-nil
  AND: No error is thrown

 SCENARIO: Setup when engine unavailable
 GIVEN: MyScript engine is not initialized (EngineProvider.engineInstance is nil)
 WHEN: setupInkInput() is called
 THEN: Throws PDFDocumentError.engineNotAvailable
  AND: inkInputViewController remains nil
  AND: No child view controller is added

 SCENARIO: Setup when document view not configured
 GIVEN: PDFDocumentViewController with documentView = nil
 WHEN: setupInkInput() is called
 THEN: Throws PDFInputError.inkOverlayNotConfigured
  AND: inkInputViewController remains nil

 SCENARIO: Setup called multiple times
 GIVEN: Ink input has already been set up
 WHEN: setupInkInput() is called again
 THEN: Previous InputViewController is removed and released
  AND: New InputViewController is created and added
  AND: Only one ink input exists in the view hierarchy
*/

/*
 ACCEPTANCE CRITERIA: PDFInkInputWiring.wirePartSwitchingGesture

 SCENARIO: Gesture recognizer added to input view
 GIVEN: InputViewController has been created
  AND: InputViewController.view exists
 WHEN: wirePartSwitchingGesture() is called
 THEN: UILongPressGestureRecognizer is added to the input view
  AND: Gesture minimumPressDuration is 0 (fires immediately on touch-down)
  AND: Gesture cancelsTouchesInView is false (allows stroke to continue)
  AND: Gesture delegate is set to PDFDocumentViewController

 SCENARIO: Gesture fires before stroke processing
 GIVEN: Part switching gesture is wired
  AND: activeBlockIndex is 0
  AND: User touches block 1
 WHEN: Touch begins on the input view
 THEN: Gesture recognizer fires with state .began
  AND: handleTouchDown(at:) is called with the touch point
  AND: Part switch to block 1 completes
  AND: Stroke data is then sent to the correct part in MyScript

 SCENARIO: Gesture handles zoom-adjusted coordinates
 GIVEN: currentZoomScale is 2.0
  AND: User touches at screen point (200, 1000)
 WHEN: Gesture fires and handleTouchDown is called
 THEN: Touch point is converted to content coordinates (100, 500)
  AND: blockIndex(for: 500) determines the target block
*/

/*
 ACCEPTANCE CRITERIA: PDFInkInputWiring.teardownInkInput

 SCENARIO: Teardown releases all resources
 GIVEN: Ink input has been set up
  AND: inkInputViewController is non-nil
 WHEN: teardownInkInput() is called
 THEN: InputViewController is removed from parent (removeFromParent())
  AND: InputViewController.view is removed from superview
  AND: inkInputViewController becomes nil
  AND: activeBlockIndex resets to -1
  AND: activeEditor reference is cleared

 SCENARIO: Teardown when not set up
 GIVEN: setupInkInput() has never been called
  AND: inkInputViewController is nil
 WHEN: teardownInkInput() is called
 THEN: No crash occurs
  AND: No action is taken
*/

// MARK: - PDFEditorLifecycle Protocol

// Protocol for managing editor lifecycle events in PDF annotation context.
// Handles loading the initial part when the editor is created and
// scheduling auto-save when content changes.
protocol PDFEditorLifecycle: AnyObject {
  // Loads the first block's MyScript part when the editor is ready.
  // Called from didCreateEditor() after the editor is initialized.
  // Sets activeBlockIndex to 0 after successful load.
  //
  // Throws: PDFInputError.partSwitchFailed if the part cannot be loaded.
  // Throws: PDFDocumentHandleError.handleClosed if handle is closed.
  func loadInitialPart() async throws

  // Schedules an auto-save after content changes.
  // Uses debouncing to avoid excessive saves during rapid drawing.
  // Called from contentChanged() delegate method.
  //
  // The save is delayed by a short interval (e.g., 2 seconds) and
  // resets if more content changes occur within that interval.
  func scheduleAutoSave()
}

/*
 ACCEPTANCE CRITERIA: PDFEditorLifecycle.loadInitialPart

 SCENARIO: Load first block's part successfully
 GIVEN: NoteDocument has 3 blocks
  AND: Block 0 has myScriptPartID "part-0"
  AND: PDFDocumentHandle is open and has part "part-0"
 WHEN: loadInitialPart() is called
 THEN: part(for: "part-0") is called on documentHandle
  AND: Retrieved part is set on the editor via editor.setEditorPart()
  AND: activeBlockIndex becomes 0
  AND: partSwitchingDelegate.didSwitchToBlock(at: 0) is called
  AND: No error is thrown

 SCENARIO: Load initial part when document has single block
 GIVEN: NoteDocument has exactly 1 block
  AND: Block 0 has myScriptPartID "only-part"
 WHEN: loadInitialPart() is called
 THEN: The single part is loaded successfully
  AND: activeBlockIndex becomes 0

 SCENARIO: Load initial part fails - part not found
 GIVEN: NoteDocument block 0 references non-existent part
 WHEN: loadInitialPart() is called
 THEN: Throws PDFInputError.partSwitchFailed
  AND: activeBlockIndex remains -1
  AND: partSwitchingDelegate.partSwitchFailed() is called with error

 SCENARIO: Load initial part fails - handle closed
 GIVEN: PDFDocumentHandle has been closed
 WHEN: loadInitialPart() is called
 THEN: Throws PDFDocumentHandleError.handleClosed
  AND: activeBlockIndex remains -1
*/

/*
 ACCEPTANCE CRITERIA: PDFEditorLifecycle.scheduleAutoSave

 SCENARIO: Auto-save triggered after content change
 GIVEN: Content has been modified (stroke added)
 WHEN: contentChanged() is called and scheduleAutoSave() is invoked
 THEN: A save timer is scheduled for 2 seconds in the future
  AND: If no more changes occur, savePackage() is called after 2 seconds

 SCENARIO: Auto-save debouncing
 GIVEN: scheduleAutoSave() was called 1 second ago
  AND: Save timer is pending
 WHEN: scheduleAutoSave() is called again (new content change)
 THEN: Previous timer is invalidated
  AND: New timer is scheduled for 2 seconds from now
  AND: savePackage() is called only once after changes stop

 SCENARIO: Auto-save when view controller dismissed
 GIVEN: Auto-save timer is pending
 WHEN: View controller is dismissed (prepareForExit called)
 THEN: Pending timer is cancelled
  AND: Immediate save is triggered via documentHandle.savePackage()
  AND: Data is not lost
*/

/*
 EDGE CASES: PDFEditorLifecycle

 EDGE CASE: loadInitialPart on empty document
 GIVEN: NoteDocument.blocks is empty
 WHEN: loadInitialPart() is called
 THEN: No part is loaded
  AND: activeBlockIndex remains -1
  AND: No error is thrown (graceful handling)

 EDGE CASE: Multiple rapid content changes
 GIVEN: User draws 10 strokes in 1 second
 WHEN: contentChanged() is called 10 times
 THEN: scheduleAutoSave() is called 10 times
  AND: Only one save occurs (2 seconds after last stroke)
  AND: No excessive disk I/O
*/

// MARK: - PDFZoomCoordination Protocol

// Protocol for coordinating zoom between UIScrollView and MyScript.
// The scroll view handles all zooming while MyScript stays at scale 1.0.
// This allows PDF background and ink to zoom together via the scroll view,
// while MyScript renders ink at native resolution.
protocol PDFZoomCoordination: UIScrollViewDelegate {
  // Returns the view to use for zooming.
  // For PDFDocumentView, returns the content view containing
  // the background layer and ink overlay.
  func viewForZooming(in scrollView: UIScrollView) -> UIView?

  // Called when the scroll view's zoom scale changes.
  // Updates any dependent state that needs to know the current zoom.
  // MyScript stays at scale 1.0 - only the view transform changes.
  func scrollViewDidZoom(_ scrollView: UIScrollView)
}

/*
 ACCEPTANCE CRITERIA: PDFZoomCoordination.viewForZooming

 SCENARIO: Return content view for zooming
 GIVEN: PDFDocumentView is set up with content view
  AND: Content view contains backgroundLayer and inkOverlayContainer
 WHEN: viewForZooming(in:) is called
 THEN: Returns the content view
  AND: The view is non-nil

 SCENARIO: Zoom gesture recognized
 GIVEN: User performs pinch gesture on the document
 WHEN: UIScrollView requests viewForZooming
 THEN: Content view is returned
  AND: UIScrollView applies scale transform to content view
  AND: Both PDF background and ink overlay scale together
*/

/*
 ACCEPTANCE CRITERIA: PDFZoomCoordination.scrollViewDidZoom

 SCENARIO: Update state after zoom
 GIVEN: User zooms from 1.0 to 2.0
 WHEN: scrollViewDidZoom() is called
 THEN: currentZoomScale is updated to 2.0
  AND: inkOverlayContainer frame is updated if needed
  AND: MyScript editor viewScale remains 1.0 (view transform only)

 SCENARIO: Zoom does not affect MyScript rendering
 GIVEN: User zooms to 3.0
 WHEN: scrollViewDidZoom() is called
 THEN: MyScript IINKEditor.editorRenderer.viewScale is still 1.0
  AND: Ink appears larger because the view is scaled
  AND: Ink stroke coordinates are still in original content space
*/

// MARK: - EditorDelegate Integration for Phase 4B

/*
 EDITORDEL EGATE CONFORMANCE:

 PDFDocumentViewController must conform to EditorDelegate from InputViewModel.swift.
 The required methods and their behavior in PDF context:

 func didCreateEditor(editor: IINKEditor)
   1. Store reference to editor (activeEditor = editor)
   2. Configure editor for Raw Content if needed
   3. Call loadInitialPart() to load first block's part
   4. Apply current tool state to editor
   5. Wire part switching gesture if not already done

 func partChanged(editor: IINKEditor)
   - Called when the active part changes
   - No action needed for PDF (we control part switching)

 func contentChanged(editor: IINKEditor, blockIds: [String])
   - Called when ink content changes
   - Call scheduleAutoSave() to persist changes

 func onError(editor: IINKEditor, blockId: String, message: String)
   - Called when MyScript encounters an error
   - Log the error for debugging
*/

/*
 ACCEPTANCE CRITERIA: EditorDelegate in PDFDocumentViewController

 SCENARIO: didCreateEditor triggers initial setup
 GIVEN: InputViewModel creates the IINKEditor
 WHEN: didCreateEditor(editor:) is called
 THEN: activeEditor is set to the editor
  AND: loadInitialPart() is called
  AND: First block's part is loaded
  AND: Current tool state is applied
  AND: Delegate notifications are sent for part switch

 SCENARIO: contentChanged triggers auto-save
 GIVEN: User draws a stroke on the document
 WHEN: contentChanged(editor:blockIds:) is called
 THEN: scheduleAutoSave() is invoked
  AND: Changes will be persisted after debounce interval

 SCENARIO: onError logs and handles gracefully
 GIVEN: MyScript encounters a recognition error
 WHEN: onError(editor:blockId:message:) is called
 THEN: Error is logged for debugging
  AND: User is not disrupted
  AND: Drawing can continue normally
*/

// MARK: - Touch Handling Sequence for Phase 4B

/*
 TOUCH-BASED PART SWITCHING SEQUENCE:

 1. User touches the screen
    |
    v
 2. UILongPressGestureRecognizer fires (minimumPressDuration=0)
    |
    v
 3. Gesture handler is called with .began state
    |
    v
 4. Convert touch point to content coordinates
    - Account for scroll offset (contentOffset)
    - Account for zoom scale (currentZoomScale)
    |
    v
 5. Determine target block: blockIndex(for: contentY)
    |
    v
 6. Check if part switch needed: targetBlock != activeBlockIndex
    |
    +--(no)-> Continue, stroke goes to current part
    |
    +--(yes)-> 7. Switch to new part
                  |
                  v
               8. await switchToBlock(at: targetBlock)
                  - Notify delegate: willSwitchToBlock
                  - Get part: documentHandle.part(for:)
                  - Set part on editor: editor.setEditorPart()
                  - Update activeBlockIndex
                  - Notify delegate: didSwitchToBlock
                  - Apply tool state
                  |
                  v
               9. Stroke is now captured in correct part

 GESTURE RECOGNIZER CONFIGURATION:

 let partSwitchGesture = UILongPressGestureRecognizer(
   target: self,
   action: #selector(handlePartSwitchGesture(_:))
 )
 partSwitchGesture.minimumPressDuration = 0
 partSwitchGesture.cancelsTouchesInView = false
 partSwitchGesture.delegate = self
*/
