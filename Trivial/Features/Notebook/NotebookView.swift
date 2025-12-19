import PencilKit
import SwiftUI

// The Notebook Editor displays a single Notebook and lets the user write ink.
// It is responsible for the editing experience (drawing, scrolling, zooming, and showing ink on screen).
struct NotebookView: View {
  // The in-memory representation of the Notebook.
  let model: NotebookModel

  // The handle for safe file operations. Stored for future save/load operations.
  let documentHandle: DocumentHandle

  var body: some View {
    ZStack {
      BackgroundWhite()
        .ignoresSafeArea()
        .allowsHitTesting(false)

      VStack(spacing: 0) {
        Text(model.displayName)
          .font(.system(size: 32, weight: .semibold))
          .foregroundStyle(Color.ink)
          .padding(.top, 24)
          .padding(.bottom, 16)

        DrawingCanvasWithScrollBar()
      }
    }
    .fontDesign(.rounded)
    .navigationBarTitleDisplayMode(.inline)
  }
}

// Drawing canvas with a visible scroll bar on the right side.
// Wraps PencilKit for ink input and provides a custom scroll indicator.
private struct DrawingCanvasWithScrollBar: View {
  // Tracks the current scroll position (0.0 to 1.0).
  @State private var scrollPosition: CGFloat = 0.0

  // Tracks whether the scroll bar should be visible.
  @State private var showScrollBar: Bool = false

  // Tracks the current zoom scale for scroll bar calculations.
  @State private var zoomScale: CGFloat = 1.0

  // The current height of the scrollable canvas area in points.
  // This grows dynamically as the user scrolls near the bottom.
  @State private var canvasHeight: CGFloat = 5000

  // Initial canvas height when the view first loads.
  private let initialCanvasHeight: CGFloat = 5000

  // Amount to extend the canvas when the user reaches near the bottom.
  private let canvasExtensionAmount: CGFloat = 2000

  // Width reserved for the scroll bar area on the right side.
  private let scrollBarAreaWidth: CGFloat = 24

  var body: some View {
    HStack(spacing: 0) {
      // The canvas fills the available space, leaving room for the scroll bar.
      PKCanvasViewRepresentable(
        canvasHeight: $canvasHeight,
        canvasExtensionAmount: canvasExtensionAmount,
        scrollPosition: $scrollPosition,
        showScrollBar: $showScrollBar,
        zoomScale: $zoomScale
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.white)

      // Scroll bar area on the right side, outside the canvas touch area.
      if showScrollBar {
        ScrollBar(
          scrollPosition: scrollPosition,
          canvasHeight: canvasHeight,
          zoomScale: zoomScale,
          onDrag: { newPosition in
            scrollPosition = newPosition
          }
        )
        .frame(width: scrollBarAreaWidth)
        .background(Color.white)
      }
    }
  }
}

// UIViewRepresentable wrapper for PKCanvasView.
// This bridges PencilKit (UIKit) to SwiftUI and tracks scroll position.
private struct PKCanvasViewRepresentable: UIViewRepresentable {
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

    // Store the canvas view reference in the coordinator for zooming.
    context.coordinator.canvasView = canvasView

    // Set up scroll and zoom tracking.
    context.coordinator.setupScrollTracking(for: canvasView)

    return canvasView
  }

  func updateUIView(_ canvasView: PKCanvasView, context: Context) {
    guard canvasView.bounds.width > 0 else { return }

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
      scrollPosition: $scrollPosition,
      showScrollBar: $showScrollBar,
      zoomScale: $zoomScale,
      canvasHeight: $canvasHeight,
      canvasExtensionAmount: canvasExtensionAmount
    )
  }

  // Coordinator that tracks scroll position and manages scroll view interactions.
  class Coordinator: NSObject {
    @Binding var scrollPosition: CGFloat
    @Binding var showScrollBar: Bool
    @Binding var zoomScale: CGFloat
    @Binding var canvasHeight: CGFloat
    let canvasExtensionAmount: CGFloat
    var scrollView: UIScrollView?
    var lastExternalScrollPosition: CGFloat = 0.0

    // Reference to the canvas view, used for zooming delegate method.
    weak var canvasView: PKCanvasView?

    init(
      scrollPosition: Binding<CGFloat>,
      showScrollBar: Binding<Bool>,
      zoomScale: Binding<CGFloat>,
      canvasHeight: Binding<CGFloat>,
      canvasExtensionAmount: CGFloat
    ) {
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
        }
      }
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

// Custom scroll bar component displayed on the right side of the canvas.
// Placed in its own area outside the canvas to avoid touch conflicts.
private struct ScrollBar: View {
  // Current scroll position (0.0 to 1.0).
  let scrollPosition: CGFloat

  // Total height of the scrollable canvas content.
  let canvasHeight: CGFloat

  // Current zoom scale of the canvas.
  let zoomScale: CGFloat

  // Callback when the user drags the scroll bar.
  let onDrag: (CGFloat) -> Void

  // State for tracking drag gesture.
  @State private var isDragging: Bool = false

  // Minimum height for the scroll bar thumb.
  private let minThumbHeight: CGFloat = 44

  // Width of the scroll bar track visual.
  private let trackWidth: CGFloat = 8

  var body: some View {
    GeometryReader { geometry in
      let trackHeight = geometry.size.height - 16
      // Account for zoom when calculating visible ratio.
      // When zoomed in, less content is visible so thumb should be smaller.
      let scaledCanvasHeight = canvasHeight * zoomScale
      let visibleRatio = min(1.0, geometry.size.height / scaledCanvasHeight)
      let thumbHeight = max(minThumbHeight, trackHeight * visibleRatio)
      let maxThumbOffset = trackHeight - thumbHeight
      let thumbOffset = scrollPosition * maxThumbOffset

      ZStack(alignment: .top) {
        // Scroll bar track (background).
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.rule.opacity(0.3))
          .frame(width: trackWidth, height: trackHeight)

        // Scroll bar thumb (draggable indicator).
        RoundedRectangle(cornerRadius: 4)
          .fill(isDragging ? Color.ink.opacity(0.6) : Color.ink.opacity(0.4))
          .frame(width: trackWidth, height: thumbHeight)
          .offset(y: thumbOffset)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .padding(.vertical, 8)
      // The entire scroll bar area is draggable for easy scrolling.
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            isDragging = true
            // Calculate position relative to the track area.
            let trackTop: CGFloat = 8
            let dragY = value.location.y - trackTop - thumbHeight / 2
            let dragPosition = dragY / maxThumbOffset
            let clampedPosition = max(0, min(1, dragPosition))
            onDrag(clampedPosition)
          }
          .onEnded { _ in
            isDragging = false
          }
      )
    }
  }
}
