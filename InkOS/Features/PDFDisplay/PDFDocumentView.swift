// PDFDocumentView.swift
// UIScrollView subclass that manages the unified PDF canvas.
// Contains PDFBackgroundLayer for PDF rendering and ink overlay for annotations.

import PDFKit
import UIKit

// UIScrollView subclass managing the unified PDF document canvas.
// Calculates layout from NoteBlock array and manages scrolling/zooming.
// Provides block lookup for touch-to-block mapping.
// Conforms to PDFInkOverlayProvider and PDFBlockLocator for ink input integration.
// Conforms to PDFZoomCoordination for UIScrollView-based zooming.
class PDFDocumentView: UIScrollView, PDFDocumentViewProtocol, PDFBackgroundLayerDataSource,
  PDFInkOverlayProvider, PDFBlockLocator, PDFZoomCoordination {

  // The NoteDocument defining the document structure.
  let noteDocument: NoteDocument

  // The PDFDocument containing page content.
  let pdfDocument: PDFDocument

  // Current zoom scale. 1.0 is no zoom.
  private(set) var currentZoomScale: CGFloat = 1.0

  // Precomputed Y offsets for each block (unscaled).
  // blockYOffsets[i] is the Y position where block i starts.
  private(set) var blockYOffsets: [CGFloat] = []

  // Cached block heights for performance.
  private var blockHeights: [CGFloat] = []

  // The background layer that draws PDF pages and spacer grids.
  private(set) var backgroundLayer: PDFBackgroundLayer!

  // The container view for the ink overlay.
  // InputViewController will be added as a child here.
  private(set) var inkOverlayContainer: UIView!

  // The content view that holds background and ink layers.
  // This is the view used for zooming.
  private(set) var contentView: UIView!

  // The current ink overlay view (InputViewController's view).
  private weak var currentInkOverlay: UIView?

  // Width used for layout calculations.
  private var containerWidth: CGFloat {
    return bounds.width
  }

  // MARK: - PDFInkOverlayProvider

  // Returns the current bounds of the ink overlay in content coordinates.
  var inkOverlayBounds: CGRect {
    return currentInkOverlay?.frame ?? .zero
  }

  // Adds the ink overlay view to the document's content area.
  // The overlay is positioned on top of the PDF background layer.
  // The overlay's frame matches the scroll view's contentSize.
  func addInkOverlay(_ overlay: UIView) {
    // Remove previous overlay if any.
    currentInkOverlay?.removeFromSuperview()

    // Add new overlay to the ink overlay container.
    overlay.translatesAutoresizingMaskIntoConstraints = false
    inkOverlayContainer.addSubview(overlay)

    // Pin overlay to container bounds.
    NSLayoutConstraint.activate([
      overlay.topAnchor.constraint(equalTo: inkOverlayContainer.topAnchor),
      overlay.leadingAnchor.constraint(equalTo: inkOverlayContainer.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: inkOverlayContainer.trailingAnchor),
      overlay.bottomAnchor.constraint(equalTo: inkOverlayContainer.bottomAnchor)
    ])

    // Store reference to current overlay.
    currentInkOverlay = overlay
  }

  // Updates the ink overlay frame when content size changes.
  // Called when zoom or layout changes affect contentSize.
  func updateInkOverlayFrame(to newSize: CGSize) {
    // Update the ink overlay container frame.
    inkOverlayContainer.frame = CGRect(origin: .zero, size: newSize)
    // The overlay will resize via constraints.
  }

  // Initializes with the documents to display.
  init(noteDocument: NoteDocument, pdfDocument: PDFDocument) {
    self.noteDocument = noteDocument
    self.pdfDocument = pdfDocument
    super.init(frame: .zero)
    setupView()
  }

  // Required initializer for Interface Builder (not supported for this view).
  required init?(coder: NSCoder) {
    fatalError("PDFDocumentView does not support Interface Builder initialization")
  }

  // Common setup.
  private func setupView() {
    // Configure scroll view properties.
    backgroundColor = .systemBackground
    showsVerticalScrollIndicator = true
    showsHorizontalScrollIndicator = false
    alwaysBounceVertical = true
    bouncesZoom = true

    // Configure zoom properties.
    minimumZoomScale = 1.0
    maximumZoomScale = 4.0
    delegate = self

    // Create content view that holds background and ink layers.
    contentView = UIView(frame: .zero)
    contentView.backgroundColor = .clear
    addSubview(contentView)

    // Create background layer for PDF rendering.
    backgroundLayer = PDFBackgroundLayer(frame: .zero)
    backgroundLayer.dataSource = self
    contentView.addSubview(backgroundLayer)

    // Create ink overlay container.
    // The InputViewController's view will be added here.
    inkOverlayContainer = UIView(frame: .zero)
    inkOverlayContainer.backgroundColor = .clear
    inkOverlayContainer.isUserInteractionEnabled = true
    contentView.addSubview(inkOverlayContainer)

    // Calculate initial layout.
    recalculateLayout()
  }

  // Recalculates layout when bounds change.
  override func layoutSubviews() {
    super.layoutSubviews()

    // Recalculate if width changed.
    let width = bounds.width
    if width > 0 {
      recalculateLayout()
      updateContentSize()
      layoutContentViews()
    }
  }

  // MARK: - Layout Calculations

  // Recalculates block Y offsets and heights based on current width.
  private func recalculateLayout() {
    guard containerWidth > 0 else { return }

    blockYOffsets = calculateBlockYOffsets()
    blockHeights = noteDocument.blocks.map { block in
      block.baseHeight { pageIndex in
        pageHeight(for: pageIndex, at: containerWidth)
      } ?? 0
    }
  }

  // Updates the content size based on total height and zoom.
  private func updateContentSize() {
    let totalHeight = calculateTotalContentHeight()
    contentSize = CGSize(width: containerWidth, height: totalHeight)
  }

  // Lays out the content views to match content size.
  private func layoutContentViews() {
    guard contentView != nil else { return }

    let size = contentSize
    contentView.frame = CGRect(origin: .zero, size: size)
    backgroundLayer.frame = contentView.bounds
    inkOverlayContainer.frame = contentView.bounds

    // Trigger redraw of background.
    backgroundLayer.setNeedsDisplay()
  }

  // MARK: - PDFDocumentViewProtocol

  // Calculates the Y offset for each block based on block heights.
  // Returns array where element i is the cumulative height of blocks 0..<i.
  // First element is always 0 (if there are blocks).
  // Uses unscaled heights (zoom not applied).
  func calculateBlockYOffsets() -> [CGFloat] {
    guard !noteDocument.blocks.isEmpty else { return [] }

    var offsets: [CGFloat] = []
    var cumulativeY: CGFloat = 0

    for block in noteDocument.blocks {
      offsets.append(cumulativeY)
      let height =
        block.baseHeight { pageIndex in
          pageHeight(for: pageIndex, at: containerWidth)
        } ?? 0
      cumulativeY += height
    }

    return offsets
  }

  // Calculates the total content height of the document.
  // Returns the sum of all block heights at the current zoom scale.
  func calculateTotalContentHeight() -> CGFloat {
    guard !noteDocument.blocks.isEmpty else { return 0 }

    var totalHeight: CGFloat = 0
    for block in noteDocument.blocks {
      let height =
        block.baseHeight { pageIndex in
          pageHeight(for: pageIndex, at: containerWidth)
        } ?? 0
      totalHeight += height
    }

    return totalHeight * currentZoomScale
  }

  // Finds the block containing the given Y offset.
  // yOffset: Position in unscaled content coordinates.
  // Returns the block index and block data, or nil if yOffset is beyond content.
  func blockContaining(yOffset: CGFloat) -> (blockIndex: Int, block: NoteBlock)? {
    guard !noteDocument.blocks.isEmpty else { return nil }
    guard !blockYOffsets.isEmpty else { return nil }
    guard yOffset >= 0 else { return nil }

    // Binary search for the block.
    var low = 0
    var high = blockYOffsets.count - 1

    while low < high {
      let mid = (low + high + 1) / 2
      if blockYOffsets[mid] <= yOffset {
        low = mid
      } else {
        high = mid - 1
      }
    }

    // Check if yOffset is within the found block's bounds.
    let blockIndex = low
    let blockStartY = blockYOffsets[blockIndex]
    let blockHeight = blockHeights[blockIndex]
    let blockEndY = blockStartY + blockHeight

    if yOffset >= blockStartY && yOffset < blockEndY {
      return (blockIndex, noteDocument.blocks[blockIndex])
    }

    return nil
  }

  // Scrolls to make the specified block visible.
  // blockIndex: Zero-based index of the block to scroll to.
  // animated: Whether to animate the scroll.
  func scrollTo(blockIndex: Int, animated: Bool) {
    guard blockIndex >= 0 else { return }
    guard blockIndex < blockYOffsets.count else { return }

    let targetY = blockYOffsets[blockIndex] * currentZoomScale
    let targetOffset = CGPoint(x: 0, y: targetY)
    setContentOffset(targetOffset, animated: animated)
  }

  // MARK: - PDFBackgroundLayerDataSource

  // Returns the unscaled height for a PDF page at the given index.
  // The height is calculated for the specified container width.
  func pageHeight(for pageIndex: Int, at width: CGFloat) -> CGFloat? {
    guard pageIndex >= 0 else { return nil }
    guard pageIndex < pdfDocument.pageCount else { return nil }
    guard width > 0 else { return 0 }

    guard let page = pdfDocument.page(at: pageIndex) else { return nil }
    let pageBounds = page.bounds(for: .mediaBox)

    // Handle zero-width page.
    guard pageBounds.width > 0 else { return width }

    // Calculate height maintaining aspect ratio.
    let aspectRatio = pageBounds.height / pageBounds.width
    return width * aspectRatio
  }

  // MARK: - PDFBlockLocator

  // Finds the block index for a given Y offset in unscaled content coordinates.
  // Uses binary search through blockYOffsets for O(log n) performance.
  // Returns the zero-based block index, or nil if outside all blocks.
  func blockIndex(for yOffset: CGFloat) -> Int? {
    guard !noteDocument.blocks.isEmpty else { return nil }
    guard !blockYOffsets.isEmpty else { return nil }
    guard yOffset >= 0 else { return nil }

    // Calculate total height.
    var totalHeight: CGFloat = 0
    for height in blockHeights {
      totalHeight += height
    }

    // Return nil if beyond total content.
    guard yOffset < totalHeight else { return nil }

    // Binary search for the block.
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

  // Converts a point from the overlay's coordinate space to unscaled content coordinates.
  // Accounts for current zoom scale.
  func convertToContentCoordinates(_ point: CGPoint) -> CGPoint {
    return CGPoint(
      x: point.x / currentZoomScale,
      y: point.y / currentZoomScale
    )
  }

  // Returns the Y offset range for a specific block.
  // blockIndex: Zero-based index of the block.
  // Returns tuple of (startY, endY) in unscaled coordinates, or nil if invalid index.
  func blockYRange(for blockIndex: Int) -> (startY: CGFloat, endY: CGFloat)? {
    guard blockIndex >= 0 && blockIndex < blockYOffsets.count else {
      return nil
    }
    guard blockIndex < blockHeights.count else {
      return nil
    }

    let startY = blockYOffsets[blockIndex]
    let endY: CGFloat
    if blockIndex + 1 < blockYOffsets.count {
      endY = blockYOffsets[blockIndex + 1]
    } else {
      endY = startY + blockHeights[blockIndex]
    }

    return (startY: startY, endY: endY)
  }

  // MARK: - Zoom Support

  // Updates the zoom scale and recalculates layout.
  func setZoomScale(_ scale: CGFloat) {
    currentZoomScale = max(1.0, min(scale, 4.0))
    updateContentSize()
    layoutContentViews()
  }

  // MARK: - PDFZoomCoordination

  // Returns the content view for zooming.
  // The content view contains both the PDF background layer and ink overlay.
  // When UIScrollView zooms, it applies a transform to this view,
  // scaling both PDF and ink together.
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return contentView
  }

  // Called when the scroll view's zoom scale changes.
  // Updates the currentZoomScale property and refreshes the background layer.
  // MyScript renderer stays at scale 1.0 - only the view transform changes.
  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    // Update internal zoom scale to match scroll view.
    currentZoomScale = scrollView.zoomScale

    // Trigger redraw of background layer with new scale.
    backgroundLayer.setNeedsDisplay()
  }
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentView

 SCENARIO: Calculate offsets for PDF pages only
 GIVEN: A document with 3 PDF pages (heights 792, 792, 792)
 WHEN: calculateBlockYOffsets() is called
 THEN: Returns [0, 792, 1584]

 SCENARIO: Calculate offsets with interleaved spacer
 GIVEN: A document with [pdfPage(792), writingSpacer(200), pdfPage(792)]
 WHEN: calculateBlockYOffsets() is called
 THEN: Returns [0, 792, 992]

 SCENARIO: Total height without zoom
 GIVEN: A document with 3 PDF pages (each 792 points)
 WHEN: calculateTotalContentHeight() is called with zoom 1.0
 THEN: Returns 2376

 SCENARIO: Total height with zoom
 GIVEN: A document with 3 PDF pages
 WHEN: calculateTotalContentHeight() is called with zoom 2.0
 THEN: Returns 4752

 SCENARIO: Block lookup
 GIVEN: blockYOffsets = [0, 792, 1584]
 WHEN: blockContaining(yOffset: 400) is called
 THEN: Returns (blockIndex: 0, block: first page)
*/
