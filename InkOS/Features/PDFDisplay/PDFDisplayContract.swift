// PDFDisplayContract.swift
// API Contract for PDF Display Feature
//
// This file defines the complete specification for displaying PDF pages in a vertical
// UICollectionView with interleaved spacer cells. It serves as the bridge between
// requirements and tests, enabling test-driven development.
// Test writers can implement tests from this contract without ambiguity.
//
// NOTE: This file contains only protocols, data structures, and acceptance criteria.
// Class implementations are in separate files (DottedGridView.swift, SpacerCell.swift, etc.)

import CoreGraphics
import PDFKit
import UIKit

// MARK: - DottedGridConfiguration

// Configuration parameters for the dotted grid pattern drawn in spacer cells.
// All values are in points.
// Uses sensible defaults that can be overridden for customization.
struct DottedGridConfiguration: Equatable, Sendable {
  // Horizontal and vertical spacing between dots in points.
  var spacing: CGFloat

  // Diameter of each dot in points.
  var dotSize: CGFloat

  // Color used to fill each dot.
  var color: UIColor

  // Default configuration with 20pt spacing, 2pt dots, light gray color.
  static let `default` = DottedGridConfiguration(
    spacing: 20.0,
    dotSize: 2.0,
    color: .lightGray
  )

  init(spacing: CGFloat = 20.0, dotSize: CGFloat = 2.0, color: UIColor = .lightGray) {
    self.spacing = spacing
    self.dotSize = dotSize
    self.color = color
  }
}

/*
 ACCEPTANCE CRITERIA: DottedGridConfiguration

 SCENARIO: Create default configuration
 GIVEN: No parameters
 WHEN: DottedGridConfiguration.default is accessed
 THEN: spacing is 20.0
  AND: dotSize is 2.0
  AND: color is UIColor.lightGray

 SCENARIO: Create custom configuration
 GIVEN: Custom spacing, dotSize, and color values
 WHEN: DottedGridConfiguration is initialized with those values
 THEN: All properties match the provided values

 SCENARIO: Configuration equality
 GIVEN: Two configurations with identical values
 WHEN: Compared for equality
 THEN: They are equal
*/

/*
 EDGE CASES: DottedGridConfiguration

 EDGE CASE: Zero spacing
 GIVEN: A configuration with spacing 0
 THEN: The configuration is created
  AND: Drawing behavior is undefined (caller responsibility to validate)

 EDGE CASE: Negative spacing
 GIVEN: A configuration with negative spacing
 THEN: The configuration is created
  AND: This represents invalid state that should not occur in practice

 EDGE CASE: Zero dot size
 GIVEN: A configuration with dotSize 0
 THEN: The configuration is created
  AND: Dots will not be visible

 EDGE CASE: Very large dot size
 GIVEN: A configuration with dotSize larger than spacing
 THEN: The configuration is created
  AND: Dots may overlap (visual artifact, not an error)
*/

// MARK: - DottedGridViewProtocol

// Protocol for the dotted grid view component.
// Abstraction enables testing without requiring actual UIView rendering.
protocol DottedGridViewProtocol: AnyObject {
  // The configuration used to draw the dotted grid pattern.
  var configuration: DottedGridConfiguration { get set }

  // Updates the configuration and triggers a redraw.
  func updateConfiguration(_ configuration: DottedGridConfiguration)
}

/*
 ACCEPTANCE CRITERIA: DottedGridViewProtocol

 SCENARIO: Initialize with default configuration
 GIVEN: A new DottedGridView instance
 WHEN: configuration is accessed
 THEN: Returns DottedGridConfiguration.default

 SCENARIO: Update configuration triggers redraw
 GIVEN: A DottedGridView instance
 WHEN: updateConfiguration is called with new values
 THEN: The configuration property is updated
  AND: The view is marked for redraw (setNeedsDisplay called)

 SCENARIO: Draw dotted pattern
 GIVEN: A DottedGridView with default configuration
 WHEN: The view draws itself
 THEN: Dots are rendered at regular intervals matching spacing
  AND: Each dot has diameter matching dotSize
  AND: Dots use the configured color
  AND: Dots tile across the entire bounds using CGPattern
*/

/*
 ACCEPTANCE CRITERIA: DottedGridView

 SCENARIO: Draw pattern covers entire bounds
 GIVEN: A DottedGridView with bounds 100x100
 WHEN: draw(_ rect:) is called
 THEN: The entire rect is covered with the dot pattern
  AND: Pattern tiles seamlessly

 SCENARIO: Pattern uses CGPattern for efficiency
 GIVEN: A DottedGridView with large bounds (e.g., 1000x1000)
 WHEN: draw(_ rect:) is called
 THEN: CGPattern is used for tiling (not manual dot drawing)
  AND: Performance remains acceptable

 SCENARIO: Background is transparent
 GIVEN: A DottedGridView
 WHEN: Rendered on screen
 THEN: Areas between dots are transparent
  AND: The view's backgroundColor can show through if set
*/

/*
 EDGE CASES: DottedGridView

 EDGE CASE: Zero-sized bounds
 GIVEN: A DottedGridView with bounds CGRect.zero
 WHEN: draw(_ rect:) is called
 THEN: No crash occurs
  AND: Nothing is drawn

 EDGE CASE: Very small bounds
 GIVEN: A DottedGridView with bounds 5x5 (smaller than spacing)
 WHEN: draw(_ rect:) is called
 THEN: A partial pattern is drawn (whatever fits)

 EDGE CASE: Configuration change while not in view hierarchy
 GIVEN: A DottedGridView not added to any superview
 WHEN: updateConfiguration is called
 THEN: No crash occurs
  AND: Configuration is updated
  AND: setNeedsDisplay is called (will draw when added to hierarchy)
*/

// MARK: - SpacerCellProtocol

// Protocol for the spacer cell used between PDF pages.
// Provides configure method for setting up the cell with spacer block data.
protocol SpacerCellProtocol: AnyObject {
  // Configures the cell for a specific spacer block.
  // height: The height of the spacer in points.
  // uuid: The unique identifier of the NoteBlock.writingSpacer block.
  func configure(height: CGFloat, uuid: UUID)
}

/*
 ACCEPTANCE CRITERIA: SpacerCellProtocol

 SCENARIO: Configure spacer cell
 GIVEN: A SpacerCell instance
 WHEN: configure(height:uuid:) is called
 THEN: The cell stores the uuid for identification
  AND: The cell's height is determined by layout (not directly set here)

 SCENARIO: Cell contains DottedGridView
 GIVEN: A configured SpacerCell
 WHEN: The cell is rendered
 THEN: A DottedGridView fills the contentView bounds
  AND: The dotted pattern is visible
*/

/*
 ACCEPTANCE CRITERIA: SpacerCell

 SCENARIO: Initialize cell
 GIVEN: A new SpacerCell is created
 WHEN: Initialization completes
 THEN: dottedGridView is non-nil
  AND: dottedGridView is a subview of contentView
  AND: dottedGridView has constraints to fill contentView

 SCENARIO: Configure with valid UUID
 GIVEN: A SpacerCell instance
 WHEN: configure(height: 500, uuid: someUUID) is called
 THEN: blockUUID equals someUUID

 SCENARIO: Prepare for reuse clears state
 GIVEN: A SpacerCell that was configured
 WHEN: prepareForReuse() is called
 THEN: blockUUID is nil
*/

/*
 EDGE CASES: SpacerCell

 EDGE CASE: Configure with zero height
 GIVEN: A SpacerCell instance
 WHEN: configure(height: 0, uuid: someUUID) is called
 THEN: Cell is configured (height 0 is valid but unusual)

 EDGE CASE: Configure called multiple times
 GIVEN: A SpacerCell configured with uuid1
 WHEN: configure is called again with uuid2
 THEN: blockUUID is updated to uuid2
  AND: No crash or memory leak occurs

 EDGE CASE: Cell reused without prepareForReuse
 GIVEN: Implementation does not call prepareForReuse before reuse
 THEN: Previous blockUUID may persist (collection view should always call it)
*/

// MARK: - PDFPageCellProtocol

// Protocol for the PDF page cell that displays a single PDF page.
// Contains a PDFView for rendering and an overlay container for future annotations.
protocol PDFPageCellProtocol: AnyObject {
  // Configures the cell to display a specific PDF page.
  // Accepts the shared PDFDocument and navigates to the specified page.
  // document: The shared PDFDocument containing all pages.
  // pageIndex: The zero-based index in the original PDF.
  // uuid: The unique identifier of the NoteBlock.pdfPage block.
  // myScriptPartID: The MyScript part identifier for annotations.
  func configure(
    document: PDFDocument,
    pageIndex: Int,
    uuid: UUID,
    myScriptPartID: String
  )
}

/*
 ACCEPTANCE CRITERIA: PDFPageCellProtocol

 SCENARIO: Configure PDF page cell
 GIVEN: A PDFPageCell instance
 WHEN: configure(page:pageIndex:uuid:) is called with valid page
 THEN: The PDFView displays the provided page
  AND: The cell stores the pageIndex and uuid for identification

 SCENARIO: PDFView is non-interactive
 GIVEN: A configured PDFPageCell
 WHEN: The user attempts to scroll or zoom the PDFView
 THEN: No interaction occurs (isUserInteractionEnabled = false)
  AND: Scrolling happens at the collection view level, not PDFView level
*/

/*
 ACCEPTANCE CRITERIA: PDFPageCell

 SCENARIO: Initialize cell
 GIVEN: A new PDFPageCell is created
 WHEN: Initialization completes
 THEN: pdfView is non-nil
  AND: pdfView.displayMode is .singlePage
  AND: pdfView.autoScales is true
  AND: pdfView.isUserInteractionEnabled is false
  AND: overlayContainer is non-nil
  AND: overlayContainer is layered above pdfView
  AND: overlayContainer.isUserInteractionEnabled is false

 SCENARIO: Configure with valid PDF page
 GIVEN: A PDFPageCell instance
 WHEN: configure(page:pageIndex:uuid:) is called
 THEN: pdfView.document contains only the provided page
  AND: pageIndex property equals the provided pageIndex
  AND: blockUUID property equals the provided uuid

 SCENARIO: PDF page is rendered at correct aspect ratio
 GIVEN: A configured PDFPageCell with a page that is 612x792 (US Letter)
 WHEN: The cell is rendered
 THEN: The page fills the cell width
  AND: The page height maintains the original aspect ratio

 SCENARIO: Prepare for reuse clears state
 GIVEN: A PDFPageCell that was configured
 WHEN: prepareForReuse() is called
 THEN: pdfView.document is nil
  AND: pageIndex is nil
  AND: blockUUID is nil
*/

/*
 EDGE CASES: PDFPageCell

 EDGE CASE: Configure with landscape page
 GIVEN: A PDFPageCell instance
 WHEN: configure is called with a landscape-oriented page
 THEN: Page is displayed correctly (aspect ratio preserved)
  AND: autoScales ensures it fits cell width

 EDGE CASE: Configure called multiple times
 GIVEN: A PDFPageCell configured with page1
 WHEN: configure is called with page2
 THEN: pdfView displays page2
  AND: No memory leak from previous page

 EDGE CASE: Overlay container does not block touches
 GIVEN: A configured PDFPageCell in a collection view
 WHEN: User scrolls over the cell
 THEN: Collection view receives the scroll events
  AND: overlayContainer does not intercept touches
*/

// MARK: - PDFCollectionViewControllerError

// Errors that can occur when creating or operating the PDF collection view.
// Each case provides specific information about the failure.
enum PDFCollectionViewControllerError: LocalizedError, Equatable {
  // The NoteDocument contains no blocks to display.
  case emptyDocument

  // PDFDocument reference is nil or invalid.
  case invalidPDFDocument

  // A NoteBlock.pdfPage references a page index not in the PDFDocument.
  case pageIndexOutOfBounds(blockIndex: Int, pageIndex: Int, pdfPageCount: Int)

  // Failed to get a page from PDFDocument at the specified index.
  case pdfPageUnavailable(pageIndex: Int)

  var errorDescription: String? {
    switch self {
    case .emptyDocument:
      return "The document contains no pages to display."
    case .invalidPDFDocument:
      return "The PDF document is invalid or could not be loaded."
    case .pageIndexOutOfBounds(let blockIndex, let pageIndex, let pdfPageCount):
      return
        "Block \(blockIndex) references page \(pageIndex), but PDF only has \(pdfPageCount) pages."
    case .pdfPageUnavailable(let pageIndex):
      return "Could not load page \(pageIndex) from the PDF document."
    }
  }
}

/*
 ACCEPTANCE CRITERIA: PDFCollectionViewControllerError

 SCENARIO: Error provides localized description
 GIVEN: Any PDFCollectionViewControllerError case
 WHEN: errorDescription is accessed
 THEN: A non-nil user-facing message is returned

 SCENARIO: Error equality
 GIVEN: Two identical error cases
 WHEN: Compared for equality
 THEN: They are equal

 SCENARIO: Error with different associated values
 GIVEN: Two pageIndexOutOfBounds errors with different values
 WHEN: Compared for equality
 THEN: They are not equal
*/

// MARK: - PDFCollectionViewControllerProtocol

// Protocol for the PDF collection view controller.
// Displays NoteDocument blocks in a vertical scrolling collection view.
// Maps NoteBlock.pdfPage to PDFPageCell and NoteBlock.writingSpacer to SpacerCell.
protocol PDFCollectionViewControllerProtocol: AnyObject {
  // The NoteDocument being displayed.
  var noteDocument: NoteDocument { get }

  // The PDFDocument containing the pages referenced by NoteDocument blocks.
  var pdfDocument: PDFDocument { get }

  // The collection view displaying the blocks.
  var collectionView: UICollectionView! { get }

  // Returns the height for a cell at the given block index.
  // For pdfPage: containerWidth * (pageHeight / pageWidth).
  // For writingSpacer: the stored height value.
  func cellHeight(at blockIndex: Int, containerWidth: CGFloat) throws -> CGFloat
}

/*
 ACCEPTANCE CRITERIA: PDFCollectionViewControllerProtocol

 SCENARIO: Initialize with NoteDocument and PDFDocument
 GIVEN: A valid NoteDocument and PDFDocument
 WHEN: PDFCollectionViewController is initialized
 THEN: noteDocument property matches the provided document
  AND: pdfDocument property matches the provided PDF

 SCENARIO: Collection view uses compositional layout
 GIVEN: A PDFCollectionViewController instance
 WHEN: collectionView.collectionViewLayout is accessed
 THEN: It is a UICollectionViewCompositionalLayout

 SCENARIO: Calculate cell height for PDF page
 GIVEN: A PDFCollectionViewController with a pdfPage block
  AND: The page dimensions are 612x792 (US Letter portrait)
  AND: Container width is 612
 WHEN: cellHeight(at: blockIndex, containerWidth: 612) is called
 THEN: Returns 792 (612 * 792/612)

 SCENARIO: Calculate cell height for spacer
 GIVEN: A PDFCollectionViewController with a writingSpacer block of height 500
 WHEN: cellHeight(at: blockIndex, containerWidth: any) is called
 THEN: Returns 500

 SCENARIO: Collection view maps blocks to cells
 GIVEN: A NoteDocument with [pdfPage, writingSpacer, pdfPage]
 WHEN: The collection view is displayed
 THEN: Cell 0 is PDFPageCell showing page 0
  AND: Cell 1 is SpacerCell
  AND: Cell 2 is PDFPageCell showing page 1
*/

/*
 EDGE CASES: PDFCollectionViewControllerProtocol

 EDGE CASE: Empty NoteDocument
 GIVEN: A NoteDocument with empty blocks array
 WHEN: PDFCollectionViewController is initialized
 THEN: Throws PDFCollectionViewControllerError.emptyDocument

 EDGE CASE: Single page document
 GIVEN: A NoteDocument with exactly one pdfPage block
 WHEN: The collection view is displayed
 THEN: One PDFPageCell is shown
  AND: No spacers (unless explicitly in blocks array)

 EDGE CASE: Many pages (100+)
 GIVEN: A NoteDocument with 100 pdfPage blocks
 WHEN: The collection view is scrolled
 THEN: Cells are reused efficiently
  AND: Memory usage remains bounded
  AND: Scrolling remains smooth

 EDGE CASE: Page index out of bounds
 GIVEN: A NoteDocument with a pdfPage block referencing pageIndex 10
  AND: PDFDocument only has 5 pages
 WHEN: cellHeight is called for that block
 THEN: Throws PDFCollectionViewControllerError.pageIndexOutOfBounds

 EDGE CASE: Landscape page in portrait container
 GIVEN: A page with dimensions 792x612 (landscape)
  AND: Container width is 400
 WHEN: cellHeight is called
 THEN: Returns 400 * (612/792) = approximately 309

 EDGE CASE: Container width is zero
 GIVEN: Any block
 WHEN: cellHeight(at: index, containerWidth: 0) is called
 THEN: Returns 0 for pdfPage (0 * aspectRatio = 0)
  AND: Returns stored height for writingSpacer (independent of containerWidth)
*/

/*
 ACCEPTANCE CRITERIA: PDFCollectionViewController

 SCENARIO: View loads successfully
 GIVEN: A valid PDFCollectionViewController
 WHEN: viewDidLoad is called
 THEN: collectionView is non-nil
  AND: collectionView is added as a subview
  AND: collectionView fills the view bounds

 SCENARIO: Collection view registers cell types
 GIVEN: A PDFCollectionViewController after viewDidLoad
 WHEN: Cells are dequeued
 THEN: PDFPageCell can be dequeued with reuseIdentifier "PDFPageCell"
  AND: SpacerCell can be dequeued with reuseIdentifier "SpacerCell"

 SCENARIO: Data source provides correct cells
 GIVEN: A NoteDocument with blocks [pdfPage(0), writingSpacer(500), pdfPage(1)]
 WHEN: collectionView requests cells
 THEN: Cell at index 0 is configured PDFPageCell with page 0
  AND: Cell at index 1 is configured SpacerCell
  AND: Cell at index 2 is configured PDFPageCell with page 1

 SCENARIO: Layout uses full-width items
 GIVEN: A PDFCollectionViewController with view width 400
 WHEN: Layout is calculated
 THEN: Each item's width equals 400 (full width)

 SCENARIO: Layout uses estimated heights
 GIVEN: A PDFCollectionViewController
 WHEN: Layout is created
 THEN: Item height dimension is .estimated
  AND: Actual height is determined by content (cellHeight calculation)
*/

/*
 EDGE CASES: PDFCollectionViewController

 EDGE CASE: View resizing
 GIVEN: A displayed PDFCollectionViewController
 WHEN: The view is resized (e.g., rotation)
 THEN: Collection view layout is invalidated
  AND: Cell heights are recalculated
  AND: PDF pages scale to new width while maintaining aspect ratio

 EDGE CASE: Memory warning
 GIVEN: A PDFCollectionViewController displaying many pages
 WHEN: The system issues a memory warning
 THEN: Off-screen cells may be released
  AND: Scrolling back recreates cells from reuse pool

 EDGE CASE: Scrolling performance
 GIVEN: A NoteDocument with 50 pages
 WHEN: User scrolls rapidly
 THEN: Cell reuse prevents memory exhaustion
  AND: Frame rate remains acceptable
*/

/*
 ACCEPTANCE CRITERIA: PDFCollectionLayout

 SCENARIO: Create layout with height provider
 GIVEN: A height provider closure
 WHEN: createLayout(heightProvider:) is called
 THEN: Returns a non-nil UICollectionViewCompositionalLayout

 SCENARIO: Layout items span full width
 GIVEN: A layout created by createLayout
  AND: Collection view width is 500
 WHEN: Layout calculates item sizes
 THEN: Each item's width is 500

 SCENARIO: Layout calls height provider
 GIVEN: A layout created with a heightProvider closure
 WHEN: Layout calculates cell sizes
 THEN: heightProvider is called for each index path
  AND: Returned height is used for cell sizing

 SCENARIO: No inter-item spacing
 GIVEN: A layout created by createLayout
 WHEN: Cells are displayed
 THEN: No vertical gap exists between cells
  AND: Cells are flush against each other
*/

/*
 EDGE CASES: PDFCollectionLayout

 EDGE CASE: Height provider returns zero
 GIVEN: A heightProvider that returns 0
 WHEN: Layout calculates sizes
 THEN: Cell has zero height (may not be visible)

 EDGE CASE: Height provider returns very large value
 GIVEN: A heightProvider that returns 10000
 WHEN: Layout calculates sizes
 THEN: Cell has height 10000
  AND: Collection view content size increases accordingly

 EDGE CASE: Environment container size is zero
 GIVEN: A layout in an environment with zero container size
 WHEN: Layout calculates
 THEN: Items have zero width
  AND: No crash occurs
*/

// MARK: - Integration with PDFImport Data Model

/*
 INTEGRATION NOTES:

 This feature displays documents created by the PDFImport module.
 It uses NoteDocument and NoteBlock types defined in PDFImport/Contract.swift.

 Data flow:
 1. User selects a previously imported PDF note from the library.
 2. PDFNoteStorage provides the document directory URL.
 3. NoteDocument is loaded from document.json manifest.
 4. PDFDocument is loaded from source.pdf.
 5. PDFCollectionViewController is created with both documents.
 6. Collection view displays blocks as cells.

 Cell mapping:
 - NoteBlock.pdfPage -> PDFPageCell
   - pageIndex is used to get PDFPage from PDFDocument.
   - uuid identifies the block for tracking.
   - myScriptPartID will be used for annotation layer (future feature).

 - NoteBlock.writingSpacer -> SpacerCell
   - height determines cell height.
   - uuid identifies the block for tracking.
   - myScriptPartID will be used for ink content (future feature).

 The PDFCollectionViewController is display-only in this version.
 Annotation drawing will be added in a future feature.
 The overlayContainer in PDFPageCell is a placeholder for that feature.
*/

// MARK: - Scrolling Behavior

/*
 SCROLLING BEHAVIOR:

 The collection view handles all scrolling. Individual PDFViews do not scroll.

 Key behaviors:
 1. Vertical scrolling only (collection view default).
 2. Bounce enabled at top and bottom.
 3. Scroll indicators visible on trailing edge.
 4. Deceleration rate is normal (not fast like paging).

 PDFView configuration:
 - isUserInteractionEnabled = false
 - No internal scroll view interaction
 - Page is scaled to fit cell width (autoScales = true)

 This ensures the entire document scrolls as a single unit,
 with PDF pages and spacers interleaved seamlessly.
*/

// MARK: - Cell Height Calculation

/*
 CELL HEIGHT FORMULAS:

 For NoteBlock.pdfPage:
   height = containerWidth * (pageHeight / pageWidth)

   Where:
   - containerWidth is the collection view width
   - pageHeight and pageWidth come from PDFPage.bounds(for: .mediaBox)

   Example: US Letter (612x792) in 400pt wide container:
   height = 400 * (792 / 612) = 517.65 points

 For NoteBlock.writingSpacer:
   height = storedHeight

   Where:
   - storedHeight is the height value from the NoteBlock.writingSpacer case

   Example: writingSpacer(height: 500, ...) results in height 500 points

 Edge cases:
 - Page width of 0: Division by zero, should be treated as error
 - Negative dimensions: Should not occur with valid PDF, treat as error
 - Very wide pages: May result in very short cells (acceptable)
*/

// MARK: - Accessibility

/*
 ACCESSIBILITY CONSIDERATIONS:

 PDFPageCell:
 - isAccessibilityElement = true
 - accessibilityLabel = "PDF page [pageIndex + 1]"
 - accessibilityTraits = .image

 SpacerCell:
 - isAccessibilityElement = true
 - accessibilityLabel = "Writing space"
 - accessibilityTraits = .none

 Collection view:
 - Supports VoiceOver navigation between cells
 - Adjustable scroll position via accessibility actions
*/

// MARK: - Future Extensions (Not Part of Current Contract)

/*
 FUTURE FEATURES (documented for context, not implemented now):

 1. Annotation Overlay
    - Add MyScript ink rendering to overlayContainer
    - Sync annotations with NoteBlock.myScriptPartID
    - Draw annotations on top of PDF content

 2. Spacer Editing
    - Allow users to resize spacers by dragging
    - Update NoteBlock.writingSpacer height
    - Persist changes to document.json

 3. Block Reordering
    - Drag and drop to reorder blocks
    - Update NoteDocument.blocks array
    - Maintain MyScript part associations

 4. Zoom Support
    - Pinch to zoom the entire document
    - Scale both PDF pages and spacers uniformly
    - Maintain scroll position during zoom

 5. Page Navigation
    - Thumbnail strip for quick navigation
    - Jump to page by number
    - Bookmarks

 These features will have their own contracts when implemented.
*/
