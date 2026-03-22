//
// NoteCanvasView.swift
// InkOS
//
// Full-screen PencilKit canvas for drawing.
// Minimal toolbar at the bottom with send and clear actions.
// Follows Apple HIG for iPad with proper touch targets and safe areas.
//

import PencilKit
import SwiftUI

// MARK: - NoteCanvasView

// Full-screen drawing canvas with a bottom toolbar.
struct NoteCanvasView: View {
  @Bindable var viewModel: NoteViewModel

  // Reference to the PKCanvasView for toolbar integration.
  @State private var canvasView: PKCanvasView?

  // Whether the PencilKit tool picker is visible.
  @State private var showToolPicker = true

  // Captured viewport height for sizing the drawing canvas.
  @State private var viewportHeight: CGFloat = 800

  var body: some View {
    ZStack(alignment: .bottom) {
      // Full-screen drawing surface.
      GeometryReader { geometry in
        ScrollView {
          CanvasView(
            drawing: $viewModel.drawing,
            onDrawingBegan: {
              showToolPicker = false
            },
            onDrawingChanged: {
              viewModel.drawingDidChange()
            },
            onCanvasViewCreated: { canvas in
              canvasView = canvas
            }
          )
          // Canvas is at least the screen height, expands with content.
          .frame(
            width: geometry.size.width,
            height: max(geometry.size.height, canvasHeight)
          )
        }
        .onAppear { viewportHeight = geometry.size.height }
        .onChange(of: geometry.size.height) { _, h in viewportHeight = h }
      }
      .background(NotebookPalette.paper)

      // Bottom toolbar.
      bottomToolbar

      // Sent toast overlay.
      if viewModel.showSentToast {
        sentToast
          .transition(.opacity)
      }
    }
    .accessibilityIdentifier("note_canvas")
  }

  // Canvas height: at least the viewport, plus extra space as content grows.
  private var canvasHeight: CGFloat {
    let drawingHeight = viewModel.drawing.bounds.maxY + 200
    return max(viewportHeight, drawingHeight)
  }

  // MARK: - Bottom Toolbar

  private var bottomToolbar: some View {
    HStack(spacing: 20) {
      // Toggle PencilKit tool picker.
      Button(action: {
        showToolPicker.toggle()
        if showToolPicker, let canvas = canvasView {
          canvas.becomeFirstResponder()
        }
      }) {
        Image(systemName: "pencil.tip")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(NotebookPalette.ink)
      }
      .accessibilityIdentifier("pencil_tool_button")

      // Clear canvas.
      Button(action: { viewModel.clearCanvas() }) {
        Image(systemName: "trash")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(NotebookPalette.ink)
      }
      .accessibilityIdentifier("clear_canvas_button")

      Spacer()

      // Send to clipboard.
      Button(action: sendToClipboard) {
        HStack(spacing: 6) {
          Image(systemName: "paperplane.fill")
            .font(.system(size: 16, weight: .medium))
          Text("Send")
            .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
          Capsule()
            .fill(viewModel.drawing.strokes.isEmpty
                  ? Color.gray.opacity(0.3)
                  : NotebookPalette.ink)
        )
      }
      .disabled(viewModel.drawing.strokes.isEmpty)
      .accessibilityIdentifier("send_button")
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .background(
      Rectangle()
        .fill(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    )
  }

  // MARK: - Send to Clipboard

  private func sendToClipboard() {
    let drawing = viewModel.drawing
    guard !drawing.strokes.isEmpty else { return }

    let bounds = drawing.bounds
    let image = drawing.image(from: bounds, scale: 2.0)

    guard let cgImage = image.cgImage,
          let pngData = PNGMetadata.buildMarkedPNG(from: cgImage)
    else { return }

    UIPasteboard.general.setData(pngData, forPasteboardType: "public.png")

    // Haptic feedback.
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    // Show toast.
    withAnimation { viewModel.showSentToast = true }
    Task {
      try? await Task.sleep(for: .seconds(1.5))
      withAnimation { viewModel.showSentToast = false }
    }
  }

  // MARK: - Toast

  private var sentToast: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.green)
      Text("Sent")
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(NotebookPalette.ink)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(
      Capsule()
        .fill(.ultraThinMaterial)
    )
    .padding(.bottom, 80)
  }
}
