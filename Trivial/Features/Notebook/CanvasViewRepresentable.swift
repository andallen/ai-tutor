import PencilKit
import SwiftUI

// UIViewRepresentable wrapper for PKCanvasView.
// This bridges PencilKit (UIKit) to SwiftUI and tracks scroll position.
struct PKCanvasViewRepresentable: UIViewRepresentable {
  // Binding to the current PKDrawing.
  @Binding var drawing: PKDrawing

  // Callback when the drawing changes (for persistence).
  var onDrawingChanged: (PKDrawing) -> Void

  // Callback when scroll or zoom changes the visible region.
  var onScroll: (CGRect) -> Void

  // The current height of the scrollable canvas area in points.
  // This grows dynamically as the user scrolls near the bottom.
  @Binding var canvasHeight: CGFloat

  // Amount to extend the canvas when the user reaches near the bottom.
  let canvasExtensionAmount: CGFloat

  // Binding to track the current scroll position (0.0 to 1.0).
  @Binding var scrollPosition: CGFloat

  // Binding to control scroll bar visibility.
  @Binding var showScrollBar: Bool

  // Binding to track the current zoom scale.
  @Binding var zoomScale: CGFloat

  // Minimum zoom scale (zoomed out).
  private let minZoom: CGFloat = 0.5

  // Maximum zoom scale (zoomed in).
  private let maxZoom: CGFloat = 3.0

  func makeUIView(context: Context) -> PKCanvasView {
    let canvasView = PKCanvasView()
    canvasView.drawingPolicy = .anyInput
    canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
    canvasView.backgroundColor = .white
    canvasView.isOpaque = true
    canvasView.isUserInteractionEnabled = true
    canvasView.isScrollEnabled = true

    // Enable pinch-to-zoom with two fingers.
    canvasView.minimumZoomScale = minZoom
    canvasView.maximumZoomScale = maxZoom
    canvasView.bouncesZoom = true

    // Set up the drawing delegate to track changes.
    canvasView.delegate = context.coordinator

    // Store the canvas view reference in the coordinator for zooming.
    context.coordinator.canvasView = canvasView

    // Set up scroll and zoom tracking.
    context.coordinator.setupScrollTracking(for: canvasView)

    return canvasView
  }

  func updateUIView(_ canvasView: PKCanvasView, context: Context) {
    guard canvasView.bounds.width > 0 else { return }

    // Update drawing if it changed externally (e.g., loaded from disk).
    // Only update if the drawing is different to avoid unnecessary redraws.
    if !context.coordinator.isUpdatingDrawing && canvasView.drawing != drawing {
      context.coordinator.isUpdatingDrawing = true
      canvasView.drawing = drawing
      context.coordinator.isUpdatingDrawing = false
    }

    // Resolve and cache the internal scroll view.
    let scrollView: UIScrollView
    if let cached = context.coordinator.scrollView {
      scrollView = cached
    } else if let found = context.coordinator.findScrollView(in: canvasView) {
      context.coordinator.scrollView = found
      scrollView = found
      scrollView.delegate = context.coordinator
    } else {
      return
    }

    // Update content size using the actual scroll view.
    let currentZoom = scrollView.zoomScale
    scrollView.contentSize = CGSize(
      width: scrollView.bounds.width, height: canvasHeight * currentZoom)

    // Update scroll position if it was changed externally (e.g., by dragging the scroll bar).
    if context.coordinator.lastExternalScrollPosition != scrollPosition {
      let initialTargetOffset = context.coordinator.targetOffset(
        for: scrollPosition, in: scrollView, zoomScale: currentZoom)

      // Extend the canvas if the target is near the bottom.
      let adjustedOffset = context.coordinator.extendCanvasIfNeeded(
        scrollView: scrollView, proposedOffset: initialTargetOffset, zoomScale: currentZoom)

      // Apply the final offset (clamped after any extension).
      scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: adjustedOffset)
      context.coordinator.lastExternalScrollPosition = scrollPosition
    }

    // Ensure the canvas can receive pencil input.
    if canvasView.window != nil, !canvasView.isFirstResponder {
      DispatchQueue.main.async { canvasView.becomeFirstResponder() }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      drawing: $drawing,
      onDrawingChanged: onDrawingChanged,
      onScroll: onScroll,
      scrollPosition: $scrollPosition,
      showScrollBar: $showScrollBar,
      zoomScale: $zoomScale,
      canvasHeight: $canvasHeight,
      canvasExtensionAmount: canvasExtensionAmount
    )
  }

  // Coordinator that tracks scroll position, zoom, and drawing changes.
  @MainActor
  class Coordinator: NSObject {
    @Binding var drawing: PKDrawing
    var onDrawingChanged: (PKDrawing) -> Void
    var onScroll: (CGRect) -> Void
    @Binding var scrollPosition: CGFloat
    @Binding var showScrollBar: Bool
    @Binding var zoomScale: CGFloat
    @Binding var canvasHeight: CGFloat
    let canvasExtensionAmount: CGFloat
    var scrollView: UIScrollView?
    var lastExternalScrollPosition: CGFloat = 0.0

    // Reference to the canvas view, used for zooming delegate method.
    weak var canvasView: PKCanvasView?

    // Flag to prevent feedback loops when updating the drawing.
    var isUpdatingDrawing: Bool = false

    init(
      drawing: Binding<PKDrawing>,
      onDrawingChanged: @escaping (PKDrawing) -> Void,
      onScroll: @escaping (CGRect) -> Void,
      scrollPosition: Binding<CGFloat>,
      showScrollBar: Binding<Bool>,
      zoomScale: Binding<CGFloat>,
      canvasHeight: Binding<CGFloat>,
      canvasExtensionAmount: CGFloat
    ) {
      _drawing = drawing
      self.onDrawingChanged = onDrawingChanged
      self.onScroll = onScroll
      _scrollPosition = scrollPosition
      _showScrollBar = showScrollBar
      _zoomScale = zoomScale
      _canvasHeight = canvasHeight
      self.canvasExtensionAmount = canvasExtensionAmount
    }

    // Calculates the maximum vertical offset based on current canvas height and zoom.
    func maxOffset(in scrollView: UIScrollView, zoomScale: CGFloat) -> CGFloat {
      let scaledHeight = canvasHeight * zoomScale
      return max(0, scaledHeight - scrollView.bounds.height)
    }

    // Calculates the content offset for a given normalized scroll position.
    func targetOffset(
      for position: CGFloat, in scrollView: UIScrollView, zoomScale: CGFloat
    ) -> CGFloat {
      let maxOffset = maxOffset(in: scrollView, zoomScale: zoomScale)
      return position * maxOffset
    }

    // Extends the canvas if the user is near the bottom. Returns a clamped offset to apply.
    func extendCanvasIfNeeded(
      scrollView: UIScrollView, proposedOffset: CGFloat, zoomScale: CGFloat
    ) -> CGFloat {
      let scaledHeight = canvasHeight * zoomScale
      let visibleHeight = scrollView.bounds.height
      let distanceFromBottom = scaledHeight - (proposedOffset + visibleHeight)
      let extensionThreshold = visibleHeight

      var adjustedOffset = proposedOffset

      if distanceFromBottom < extensionThreshold {
        canvasHeight += canvasExtensionAmount
        scrollView.contentSize = CGSize(
          width: scrollView.contentSize.width, height: canvasHeight * zoomScale)
      }

      let newMaxOffset = maxOffset(in: scrollView, zoomScale: zoomScale)
      adjustedOffset = min(adjustedOffset, newMaxOffset)

      // Update scroll bar visibility based on new height.
      showScrollBar = canvasHeight > visibleHeight

      return adjustedOffset
    }

    // Finds the UIScrollView inside the PKCanvasView hierarchy.
    func findScrollView(in view: UIView) -> UIScrollView? {
      if let scrollView = view as? UIScrollView {
        return scrollView
      }
      for subview in view.subviews {
        if let scrollView = findScrollView(in: subview) {
          return scrollView
        }
      }
      return nil
    }

    // Sets up scroll position tracking by observing the scroll view's content offset.
    func setupScrollTracking(for canvasView: PKCanvasView) {
      // Wait for the view to be laid out before finding the scroll view.
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        if let scrollView = self.findScrollView(in: canvasView) {
          self.scrollView = scrollView
          scrollView.delegate = self

          // Determine if scroll bar should be visible based on content height.
          let visibleHeight = canvasView.bounds.height
          self.showScrollBar = self.canvasHeight > visibleHeight
          
          // Initial scroll report
          self.notifyScroll(scrollView)
        }
      }
    }
    
    // Notifies the parent of scroll changes.
    func notifyScroll(_ scrollView: UIScrollView) {
      let zoom = scrollView.zoomScale
      let unscaledRect = CGRect(
        x: scrollView.contentOffset.x / zoom,
        y: scrollView.contentOffset.y / zoom,
        width: scrollView.bounds.width / zoom,
        height: scrollView.bounds.height / zoom
      )
      onScroll(unscaledRect)
    }
  }
}

// UIScrollViewDelegate extension to track scroll position and zoom changes.
extension PKCanvasViewRepresentable.Coordinator: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Account for zoom when calculating scroll position.
    let currentZoom = scrollView.zoomScale
    let maxOffset = maxOffset(in: scrollView, zoomScale: currentZoom)

    // Extend canvas if user is near the bottom based on current offset.
    let adjustedOffset = extendCanvasIfNeeded(
      scrollView: scrollView,
      proposedOffset: scrollView.contentOffset.y,
      zoomScale: currentZoom
    )
    if adjustedOffset != scrollView.contentOffset.y {
      scrollView.contentOffset.y = adjustedOffset
    }

    // Update normalized scroll position.
    if maxOffset > 0 {
      scrollPosition = scrollView.contentOffset.y / maxOffset
      scrollPosition = max(0, min(1, scrollPosition))
    } else {
      scrollPosition = 0
    }
    lastExternalScrollPosition = scrollPosition
    
    // Notify visible rect change
    notifyScroll(scrollView)
  }

  // Returns the view that should be zoomed when pinching.
  // PKCanvasView uses its first subview as the zoomable content.
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    guard let canvas = canvasView else { return nil }
    // The drawing content is in the first subview of PKCanvasView.
    return canvas.subviews.first
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    // Update zoom scale binding.
    zoomScale = scrollView.zoomScale
    // Update scroll position after zoom changes.
    scrollViewDidScroll(scrollView)
  }
}

// PKCanvasViewDelegate extension to track drawing changes.
extension PKCanvasViewRepresentable.Coordinator: PKCanvasViewDelegate {
  func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    // Avoid feedback loops when we programmatically set the drawing.
    guard !isUpdatingDrawing else { return }

    // Update the binding and notify the persistence controller.
    drawing = canvasView.drawing
    onDrawingChanged(canvasView.drawing)
  }
}
