// PDFBackgroundLayer.swift
// UIView that draws PDF pages at calculated Y offsets with dotted grids for spacers.
// Part of the unified PDF canvas architecture.

import PDFKit
import UIKit

// UIView that renders the background content of a PDF document.
// Draws PDF pages at their calculated Y offsets using PDFPage.draw() for vector quality.
// Draws dotted grid patterns for writingSpacer blocks.
// Only renders content within the visible rect for efficiency.
class PDFBackgroundLayer: UIView, PDFBackgroundLayerProtocol {

  // Context for drawing a block, grouping related parameters.
  private struct DrawContext {
    let blockYOffsets: [CGFloat]
    let zoomScale: CGFloat
    let containerWidth: CGFloat
    let visibleRect: CGRect
    let context: CGContext
    let pdfDocument: PDFDocument
  }

  // Weak reference to the data source providing PDF and layout information.
  // Must be weak to prevent retain cycles with the view hierarchy.
  weak var dataSource: PDFBackgroundLayerDataSource?

  // Configuration for the dotted grid pattern drawn in spacer areas.
  // Changing this triggers a redraw of the view.
  var dottedGridConfiguration: DottedGridConfiguration = .default {
    didSet {
      setNeedsDisplay()
    }
  }

  // Standard initializer for frame-based initialization.
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }

  // Required initializer for Interface Builder.
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  // Common setup for all initializers.
  private func setupView() {
    // Make background white to show a clean canvas behind PDF pages.
    backgroundColor = .white
    // Content mode doesn't apply since we override draw().
    contentMode = .redraw
    // Enable layer drawing for smooth scrolling.
    layer.drawsAsynchronously = true
  }

  // Marks a specific rect as needing redraw.
  // Used when scrolling reveals new content.
  func markRectNeedsDisplay(_ rect: CGRect) {
    setNeedsDisplay(rect)
  }

  // Updates tile management for the visible rect.
  // Currently triggers a full redraw. Future optimization could use CATiledLayer.
  func updateForVisibleRect(_ visibleRect: CGRect) {
    // For now, mark the visible area as needing display.
    setNeedsDisplay(visibleRect)
  }

  // Main drawing method that renders PDF pages and spacer grids.
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    guard let dataSource = dataSource else { return }

    // Get layout information from data source.
    let noteDocument = dataSource.noteDocument
    let pdfDocument = dataSource.pdfDocument
    let blockYOffsets = dataSource.blockYOffsets
    let zoomScale = dataSource.currentZoomScale
    let containerWidth = bounds.width

    // Skip if no blocks to draw.
    guard !noteDocument.blocks.isEmpty else { return }
    guard blockYOffsets.count == noteDocument.blocks.count else { return }

    // Create drawing context.
    let drawContext = DrawContext(
      blockYOffsets: blockYOffsets,
      zoomScale: zoomScale,
      containerWidth: containerWidth,
      visibleRect: rect,
      context: context,
      pdfDocument: pdfDocument
    )

    // Iterate through blocks and draw those that intersect the visible rect.
    for (index, block) in noteDocument.blocks.enumerated() {
      drawBlock(at: index, block: block, drawContext: drawContext)
    }
  }

  // Draws a single block if it intersects the visible rect.
  private func drawBlock(at index: Int, block: NoteBlock, drawContext: DrawContext) {
    let blockYOffset = drawContext.blockYOffsets[index] * drawContext.zoomScale

    // Get the block height.
    guard
      let blockHeight = calculateBlockHeight(
        for: block,
        zoomScale: drawContext.zoomScale,
        containerWidth: drawContext.containerWidth
      )
    else { return }

    // Calculate block rect.
    let blockRect = CGRect(
      x: 0,
      y: blockYOffset,
      width: drawContext.containerWidth,
      height: blockHeight
    )

    // Skip blocks that don't intersect the visible rect.
    guard blockRect.intersects(drawContext.visibleRect) else { return }

    // Draw the block content.
    switch block {
    case .pdfPage(let pageIndex, _, _):
      drawPDFPage(
        at: pageIndex,
        in: blockRect,
        context: drawContext.context,
        pdfDocument: drawContext.pdfDocument,
        zoomScale: drawContext.zoomScale
      )
    case .writingSpacer:
      drawSpacerGrid(in: blockRect, context: drawContext.context)
    }
  }

  // Calculates the height of a block at the current zoom scale.
  // Returns nil if the block references an invalid page index.
  private func calculateBlockHeight(
    for block: NoteBlock,
    zoomScale: CGFloat,
    containerWidth: CGFloat
  ) -> CGFloat? {
    switch block {
    case .pdfPage(let pageIndex, _, _):
      guard let height = dataSource?.pageHeight(for: pageIndex, at: containerWidth / zoomScale)
      else {
        return nil
      }
      return height * zoomScale
    case .writingSpacer(let height, _, _):
      return height * zoomScale
    }
  }

  // Draws a PDF page at the specified rect.
  private func drawPDFPage(
    at pageIndex: Int,
    in rect: CGRect,
    context: CGContext,
    pdfDocument: PDFDocument,
    zoomScale: CGFloat
  ) {
    // Get the PDF page.
    guard let page = pdfDocument.page(at: pageIndex) else { return }

    // Get page bounds in PDF coordinates.
    let pageBounds = page.bounds(for: .mediaBox)

    // Save graphics state before transform.
    context.saveGState()

    // PDF coordinate system has origin at bottom-left.
    // UIKit has origin at top-left.
    // We need to flip the coordinate system for the page.

    // Translate to the page position.
    context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.height)

    // Flip vertically.
    context.scaleBy(x: 1.0, y: -1.0)

    // Scale to fit the container width while maintaining aspect ratio.
    let scaleX = rect.width / pageBounds.width
    let scaleY = rect.height / pageBounds.height
    context.scaleBy(x: scaleX, y: scaleY)

    // Draw the page.
    page.draw(with: .mediaBox, to: context)

    // Restore graphics state.
    context.restoreGState()
  }

  // Draws a dotted grid pattern for a spacer block.
  private func drawSpacerGrid(in rect: CGRect, context: CGContext) {
    DottedGridView.drawDottedPattern(
      in: context,
      rect: rect,
      configuration: dottedGridConfiguration,
      scale: contentScaleFactor
    )
  }
}

/*
 ACCEPTANCE CRITERIA: PDFBackgroundLayer

 SCENARIO: Initialize with default configuration
 GIVEN: A new PDFBackgroundLayer instance
 WHEN: dottedGridConfiguration is accessed
 THEN: Returns DottedGridConfiguration.default

 SCENARIO: Draw visible PDF page
 GIVEN: A visible rect that covers only page 1
 WHEN: draw(_:) is called
 THEN: Only page 1 is rendered

 SCENARIO: Draw across page boundary
 GIVEN: A visible rect spanning from page 1 to page 2
 WHEN: draw(_:) is called
 THEN: Both pages are rendered at correct Y offsets

 SCENARIO: Draw spacer with dotted grid
 GIVEN: A visible rect covering a writingSpacer block
 WHEN: draw(_:) is called
 THEN: A dotted grid pattern is drawn

 SCENARIO: No data source
 GIVEN: dataSource is nil
 WHEN: draw(_:) is called
 THEN: Nothing is drawn and no crash occurs
*/
