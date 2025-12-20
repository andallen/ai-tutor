import Combine
import PencilKit
import SwiftUI

// The Notebook Editor displays a single Notebook and lets the user write ink.
// It is responsible for the editing experience (drawing, scrolling, zooming, and showing ink on screen).
struct NotebookView: View {
  // The in-memory representation of the Notebook.
  let model: NotebookModel

  // The handle for safe file operations.
  let documentHandle: DocumentHandle

  // Controller that manages ink persistence (save/load).
  @StateObject private var persistenceController: InkPersistenceController

  // Custom initializer to set up the persistence controller with the document handle.
  init(model: NotebookModel, documentHandle: DocumentHandle) {
    self.model = model
    self.documentHandle = documentHandle
    // Create the persistence controller as a StateObject.
    _persistenceController = StateObject(
      wrappedValue: InkPersistenceController(documentHandle: documentHandle, model: model))
  }

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

        DrawingCanvasWithScrollBar(persistenceController: persistenceController)
      }
    }
    .fontDesign(.rounded)
    .navigationBarTitleDisplayMode(.inline)
  }
}

// Drawing canvas with a visible scroll bar on the right side.
// Wraps PencilKit for ink input and provides a custom scroll indicator.
private struct DrawingCanvasWithScrollBar: View {
  // Controller that manages ink persistence.
  @ObservedObject var persistenceController: InkPersistenceController

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
        drawing: $persistenceController.drawing,
        onDrawingChanged: { newDrawing in
          persistenceController.drawingDidChange(newDrawing)
        },
        onScroll: { visibleRect in
          persistenceController.updateViewport(visibleRect: visibleRect)
        },
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
