import CoreGraphics
import Foundation

// Logic for determining which Ink Items should be loaded based on the viewport.
struct ViewportController {
  // Ratio of the viewport height to use as a buffer above and below.
  // e.g., 0.5 means load 0.5 screens above and 0.5 screens below.
  private let bufferRatio: CGFloat = 1.0

  // Determines which ink items overlap with the visible area (+ buffer).
  func itemsToLoad(
    visibleRect: CGRect,
    inkItems: [InkItem]
  ) -> Set<String> {
    // Calculate the load region (visible + buffer).
    let bufferHeight = visibleRect.height * bufferRatio
    let loadRect = visibleRect.insetBy(dx: 0, dy: -bufferHeight)

    // Find items that intersect the load region.
    let visibleItems = inkItems.filter { item in
      let itemRect = item.rectangle.cgRect
      return loadRect.intersects(itemRect)
    }

    return Set(visibleItems.map { $0.id })
  }
}

