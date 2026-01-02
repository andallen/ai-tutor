// PDFPageLayout.swift
// Calculates page positions for vertical stacking of PDF pages.

import CoreGraphics
import PDFKit

// Spacing between consecutive PDF pages in points.
private let pageSpacing: CGFloat = 20

// Layout information for vertically stacked PDF pages.
// Calculates frames for each page based on aspect ratios and target width.
struct PDFPageLayout {

  // Frame for each page in content coordinates.
  // Origin is relative to the top of the content area.
  let pageFrames: [CGRect]

  // Total height of all pages plus spacing.
  let totalContentHeight: CGFloat

  // Uniform width used for all pages.
  let pageWidth: CGFloat

  // Number of pages in the layout.
  var pageCount: Int {
    return pageFrames.count
  }

  // Creates a layout from a PDF document.
  // pdfDocument: The PDF document to calculate layout for.
  // targetWidth: The width to scale all pages to (typically screen width).
  init(pdfDocument: PDFDocument, targetWidth: CGFloat) {
    self.pageWidth = targetWidth

    var frames: [CGRect] = []
    var currentY: CGFloat = 0

    for pageIndex in 0..<pdfDocument.pageCount {
      guard let page = pdfDocument.page(at: pageIndex) else { continue }

      // Get the page bounds in PDF coordinates.
      let pageBounds = page.bounds(for: .mediaBox)

      // Calculate scaled height maintaining aspect ratio.
      let aspectRatio = pageBounds.height / pageBounds.width
      let scaledHeight = targetWidth * aspectRatio

      // Create frame at current Y position.
      let frame = CGRect(x: 0, y: currentY, width: targetWidth, height: scaledHeight)
      frames.append(frame)

      // Move Y position for next page.
      currentY += scaledHeight + pageSpacing
    }

    self.pageFrames = frames

    // Total height is final Y minus the last spacing (no spacing after last page).
    if frames.isEmpty {
      self.totalContentHeight = 0
    } else {
      self.totalContentHeight = currentY - pageSpacing
    }
  }

  // Creates a layout with explicit frames (for testing).
  init(pageFrames: [CGRect], pageWidth: CGFloat) {
    self.pageFrames = pageFrames
    self.pageWidth = pageWidth

    if let lastFrame = pageFrames.last {
      self.totalContentHeight = lastFrame.maxY
    } else {
      self.totalContentHeight = 0
    }
  }

  // Returns the page index containing the given point.
  // Returns nil if point is outside all page frames (e.g., in spacing).
  func pageIndex(at point: CGPoint) -> Int? {
    for (index, frame) in pageFrames.enumerated() {
      if frame.contains(point) {
        return index
      }
    }
    return nil
  }

  // Returns indices of pages that intersect the given viewport rect.
  func visiblePageIndices(in viewportRect: CGRect) -> [Int] {
    var indices: [Int] = []
    for (index, frame) in pageFrames.enumerated() {
      if frame.intersects(viewportRect) {
        indices.append(index)
      }
    }
    return indices
  }

  // Returns page indices and their frames for pages visible in the viewport.
  func visiblePages(in viewportRect: CGRect) -> [(pageIndex: Int, frame: CGRect)] {
    var result: [(pageIndex: Int, frame: CGRect)] = []
    for (index, frame) in pageFrames.enumerated() {
      if frame.intersects(viewportRect) {
        result.append((pageIndex: index, frame: frame))
      }
    }
    return result
  }

  // Returns the frame for a specific page index.
  // Returns nil if index is out of bounds.
  func frame(for pageIndex: Int) -> CGRect? {
    guard pageIndex >= 0 && pageIndex < pageFrames.count else {
      return nil
    }
    return pageFrames[pageIndex]
  }
}
