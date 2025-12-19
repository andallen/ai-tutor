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

  // The height of the scrollable canvas area in points.
  private let canvasHeight: CGFloat = 5000

  // Width reserved for the scroll bar area on the right side.
  private let scrollBarAreaWidth: CGFloat = 24

  var body: some View {
    HStack(spacing: 0) {
      // The canvas fills the available space, leaving room for the scroll bar.
      PKCanvasViewRepresentable(
        canvasHeight: canvasHeight,
        scrollPosition: $scrollPosition,
        showScrollBar: $showScrollBar
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.white)

      // Scroll bar area on the right side, outside the canvas touch area.
      if showScrollBar {
        ScrollBar(
          scrollPosition: scrollPosition,
          canvasHeight: canvasHeight,
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
  // The height of the scrollable canvas area in points.
  // This allows the user to scroll and draw on a long vertical surface.
  let canvasHeight: CGFloat

  // Binding to track the current scroll position (0.0 to 1.0).
  @Binding var scrollPosition: CGFloat

  // Binding to control scroll bar visibility.
  @Binding var showScrollBar: Bool

  func makeUIView(context: Context) -> PKCanvasView {
    let canvasView = PKCanvasView()
    canvasView.drawingPolicy = .anyInput
    canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
    canvasView.backgroundColor = .white
    canvasView.isOpaque = true
    canvasView.isUserInteractionEnabled = true
    canvasView.isScrollEnabled = true

    // Find the scroll view inside PKCanvasView and set up scroll tracking.
    context.coordinator.setupScrollTracking(for: canvasView)

    return canvasView
  }

  func updateUIView(_ canvasView: PKCanvasView, context: Context) {
    // Set content size for vertical scrolling once the view has a valid width.
    if canvasView.bounds.width > 0 {
      let scrollView = context.coordinator.findScrollView(in: canvasView)
      scrollView?.contentSize = CGSize(width: canvasView.bounds.width, height: canvasHeight)

      // Update scroll position if it was changed externally (e.g., by dragging the scroll bar).
      if context.coordinator.lastExternalScrollPosition != scrollPosition {
        let maxOffset = max(0, canvasHeight - canvasView.bounds.height)
        let targetOffset = scrollPosition * maxOffset
        scrollView?.contentOffset = CGPoint(x: 0, y: targetOffset)
        context.coordinator.lastExternalScrollPosition = scrollPosition
      }
    }

    // Ensure the canvas can receive pencil input.
    if canvasView.window != nil, !canvasView.isFirstResponder {
      DispatchQueue.main.async { canvasView.becomeFirstResponder() }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      scrollPosition: $scrollPosition, showScrollBar: $showScrollBar, canvasHeight: canvasHeight)
  }

  // Coordinator that tracks scroll position and manages scroll view interactions.
  class Coordinator: NSObject {
    @Binding var scrollPosition: CGFloat
    @Binding var showScrollBar: Bool
    let canvasHeight: CGFloat
    var scrollView: UIScrollView?
    var lastExternalScrollPosition: CGFloat = 0.0

    init(scrollPosition: Binding<CGFloat>, showScrollBar: Binding<Bool>, canvasHeight: CGFloat) {
      _scrollPosition = scrollPosition
      _showScrollBar = showScrollBar
      self.canvasHeight = canvasHeight
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

// UIScrollViewDelegate extension to track scroll position changes.
extension PKCanvasViewRepresentable.Coordinator: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let maxOffset = max(0, canvasHeight - scrollView.bounds.height)
    if maxOffset > 0 {
      scrollPosition = scrollView.contentOffset.y / maxOffset
      scrollPosition = max(0, min(1, scrollPosition))
    } else {
      scrollPosition = 0
    }
    lastExternalScrollPosition = scrollPosition
  }
}

// Custom scroll bar component displayed on the right side of the canvas.
// Placed in its own area outside the canvas to avoid touch conflicts.
private struct ScrollBar: View {
  // Current scroll position (0.0 to 1.0).
  let scrollPosition: CGFloat

  // Total height of the scrollable canvas content.
  let canvasHeight: CGFloat

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
      let visibleRatio = min(1.0, (geometry.size.height) / canvasHeight)
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
