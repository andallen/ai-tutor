// PDFBackgroundRenderer.swift
// Renders PDF pages to CGImage for display as background in the canvas.
// Implements viewport culling and caching for performance.

import CoreGraphics
import PDFKit
import UIKit

// Protocol for PDF background rendering.
// Allows injection for testing.
protocol PDFBackgroundRendererProtocol: AnyObject {
  var pdfDocument: PDFDocument? { get set }
  var pageLayout: PDFPageLayout? { get set }

  // Returns pages visible in the given viewport along with their frames.
  func visiblePages(in viewportRect: CGRect) -> [(pageIndex: Int, frame: CGRect)]

  // Renders or retrieves cached image for a page at the given scale.
  func renderPage(at index: Int, scale: CGFloat) -> CGImage?

  // Clears the image cache.
  func clearCache()
}

// Wrapper class for CGImage to use with NSCache.
// NSCache requires reference types as values.
private final class CGImageWrapper {
  let image: CGImage

  init(_ image: CGImage) {
    self.image = image
  }
}

// Cache key combining page index and scale for resolution-aware caching.
private struct CacheKey: Hashable {
  let pageIndex: Int
  let scale: CGFloat

  // Quantize scale to avoid excessive cache entries.
  // Rounds to nearest 0.5 increment.
  var quantizedScale: CGFloat {
    return (scale * 2).rounded() / 2
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(pageIndex)
    hasher.combine(quantizedScale)
  }

  static func == (lhs: CacheKey, rhs: CacheKey) -> Bool {
    return lhs.pageIndex == rhs.pageIndex && lhs.quantizedScale == rhs.quantizedScale
  }
}

// Renders PDF pages to images with caching and viewport culling.
final class PDFBackgroundRenderer: PDFBackgroundRendererProtocol {

  // The PDF document to render pages from.
  weak var pdfDocument: PDFDocument?

  // Layout information for page positions.
  var pageLayout: PDFPageLayout?

  // Image cache with automatic eviction under memory pressure.
  private let cache = NSCache<NSString, CGImageWrapper>()

  // Serial queue for cache operations to ensure thread safety.
  private let cacheQueue = DispatchQueue(label: "pdf.cache", qos: .userInitiated)

  // Concurrent queue for rendering operations.
  private let renderQueue = DispatchQueue(label: "pdf.render", qos: .userInitiated, attributes: .concurrent)

  // Maximum cache cost in bytes (approximately 150MB).
  private static let maxCacheCost = 150 * 1024 * 1024

  init() {
    cache.totalCostLimit = Self.maxCacheCost
  }

  // Returns pages visible in the viewport along with their content frames.
  func visiblePages(in viewportRect: CGRect) -> [(pageIndex: Int, frame: CGRect)] {
    guard let layout = pageLayout else { return [] }
    return layout.visiblePages(in: viewportRect)
  }

  // Renders or retrieves a cached image for the given page.
  // index: Zero-based page index.
  // scale: Viewport zoom scale (e.g., 1.0 for no zoom, 2.0 for 2x zoom).
  // Returns the rendered CGImage or nil if rendering fails.
  func renderPage(at index: Int, scale: CGFloat) -> CGImage? {
    guard let pdf = pdfDocument,
          let layout = pageLayout,
          let frame = layout.frame(for: index),
          let page = pdf.page(at: index) else {
      return nil
    }

    // Multiply viewport zoom by screen density for crisp rendering on retina displays.
    // At 1x zoom on a 3x retina device, renderScale = 3.0 for proper resolution.
    let screenScale = UIScreen.main.scale
    let renderScale = scale * screenScale

    // Create cache key with quantized scale (uses renderScale for proper resolution caching).
    let key = CacheKey(pageIndex: index, scale: renderScale)
    let cacheKeyString = "\(key.pageIndex)-\(key.quantizedScale)" as NSString

    // Check cache first.
    if let cached = cache.object(forKey: cacheKeyString) {
      return cached.image
    }

    // Render the page synchronously for now.
    // TODO: Consider async rendering with placeholder for better scrolling.
    let image = renderPageImage(page: page, frame: frame, scale: key.quantizedScale)

    // Cache the result if rendering succeeded.
    if let image = image {
      let wrapper = CGImageWrapper(image)
      // Estimate cost as actual pixel dimensions * 4 bytes per pixel.
      let cost = image.width * image.height * 4
      cache.setObject(wrapper, forKey: cacheKeyString, cost: cost)
    }

    return image
  }

  // Clears all cached images.
  func clearCache() {
    cache.removeAllObjects()
  }

  // Renders a PDF page to a CGImage.
  private func renderPageImage(page: PDFPage, frame: CGRect, scale: CGFloat) -> CGImage? {
    // Calculate pixel dimensions.
    let pixelWidth = Int(frame.width * scale)
    let pixelHeight = Int(frame.height * scale)

    guard pixelWidth > 0, pixelHeight > 0 else { return nil }

    // Use UIGraphicsImageRenderer for efficient rendering.
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(size: frame.size, format: format)

    let uiImage = renderer.image { context in
      // Fill with white background.
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: frame.size))

      let cgContext = context.cgContext

      // PDF pages are drawn with origin at bottom-left.
      // Flip the coordinate system for correct orientation.
      cgContext.translateBy(x: 0, y: frame.height)
      cgContext.scaleBy(x: 1.0, y: -1.0)

      // Get the page bounds and calculate transform to fit frame.
      let pageBounds = page.bounds(for: .mediaBox)
      let scaleX = frame.width / pageBounds.width
      let scaleY = frame.height / pageBounds.height

      // Apply scaling to fit the frame.
      cgContext.scaleBy(x: scaleX, y: scaleY)

      // Draw the PDF page.
      page.draw(with: .mediaBox, to: cgContext)
    }

    return uiImage.cgImage
  }
}
