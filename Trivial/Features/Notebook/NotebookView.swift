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
    // Use VStack as the main container to avoid ZStack touch-handling issues.
    VStack(spacing: 0) {
      // Display the notebook name at the top.
      Text(model.displayName)
        .font(.system(size: 32, weight: .semibold))
        .foregroundStyle(Color.ink)
        .padding(.top, 24)
        .padding(.bottom, 16)

      // Drawing canvas fills the remaining space.
      PKCanvasViewRepresentable()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // Apply background behind the entire view hierarchy.
    .background(
      BackgroundWhite()
        .ignoresSafeArea()
    )
    .fontDesign(.rounded)
    .navigationBarTitleDisplayMode(.inline)
  }
}

// UIViewRepresentable wrapper for PKCanvasView.
// This bridges PencilKit (UIKit) to SwiftUI.
private struct PKCanvasViewRepresentable: UIViewRepresentable {
  // The height of the scrollable canvas area in points.
  // This allows the user to scroll and draw on a long vertical surface.
  private let canvasHeight: CGFloat = 5000

  func makeUIView(context: Context) -> PKCanvasView {
    let canvasView = PKCanvasView()
    // Enable drawing with both Apple Pencil and finger.
    canvasView.drawingPolicy = .anyInput
    // Set up the default drawing tool (black ink pen).
    canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
    // Configure the canvas appearance.
    canvasView.backgroundColor = .white
    canvasView.isOpaque = true
    // Ensure touch events are received.
    canvasView.isUserInteractionEnabled = true
    // Enable vertical scrolling on the canvas.
    canvasView.isScrollEnabled = true
    return canvasView
  }

  func updateUIView(_ canvasView: PKCanvasView, context: Context) {
    // Set the content size for vertical scrolling once bounds are available.
    if canvasView.bounds.width > 0 {
      canvasView.contentSize = CGSize(width: canvasView.bounds.width, height: canvasHeight)
    }
    // Ensure the canvas can receive pencil input by becoming first responder.
    if canvasView.window != nil, !canvasView.isFirstResponder {
      DispatchQueue.main.async { canvasView.becomeFirstResponder() }
    }
  }
}
