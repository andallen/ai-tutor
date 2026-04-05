//
// NoteCanvasView.swift
// PaperClip
//
// Full-screen PencilKit canvas for drawing.
// Two send modes: crop (rectangle drag) and viewport (current screen).
// Floating send button + mode picker pill in the bottom-right corner.
// Canvas is capped at 4000pt (8000px at 2x) to fit Claude Code's image limit.
// Shows an end-of-canvas indicator when the user scrolls near the bottom.
//

import PencilKit
import SwiftUI

// MARK: - SendMode

// Which region of the canvas to capture when the user taps Send.
enum SendMode: String {
  case crop      // User drags a rectangle to select a region.
  case viewport  // Captures strokes visible in the current scroll position.
}

// MARK: - NoteCanvasView

// Full-screen drawing canvas with a floating send button and mode picker.
struct NoteCanvasView: View {
  @Bindable var viewModel: NoteViewModel

  // Whether the PencilKit tool picker is visible (bound from parent).
  @Binding var showToolPicker: Bool

  // Peer-to-peer transfer service for sending PNGs to Mac.
  var transferService: TransferService

  // Whether the ruler overlay is active.
  @State private var isRulerActive = false

  // How far the user has scrolled (contentOffset.y), reported by the canvas.
  @State private var scrollOffset: CGFloat = 0

  // Viewport dimensions for computing capture rects.
  @State private var viewportHeight: CGFloat = 800
  @State private var viewportWidth: CGFloat = 0

  // Whether the end-of-canvas indicator is currently visible.
  // Shown when the user hits the bottom, then auto-dismissed after a delay.
  @State private var showEndIndicator = false

  // Task handle for the auto-dismiss timer so it can be cancelled on re-trigger.
  @State private var endIndicatorDismissTask: Task<Void, Never>?

  // Active send mode. Default is viewport (send what you see).
  @State private var sendMode: SendMode = .viewport

  // Fade-out mode label state.
  @State private var showModeLabel = false
  @State private var modeLabelDismissTask: Task<Void, Never>?

  // Crop mode state: the rectangle the user dragged (in canvas content coordinates).
  @State private var cropRect: CGRect? = nil

  // Live drag tracking for crop overlay (in viewport coordinates).
  @State private var cropDragStart: CGPoint? = nil
  @State private var cropDragCurrent: CGPoint? = nil

  // Whether the troubleshooting help card is expanded.
  @State private var showConnectionHelp = false

  var body: some View {
    ZStack {
      // Full-screen drawing surface with native PKToolPicker.
      CanvasView(
        drawing: $viewModel.drawing,
        showToolPicker: $showToolPicker,
        isRulerActive: $isRulerActive,
        isScrollEnabled: sendMode != .crop,
        onDrawingChanged: {
          viewModel.drawingDidChange()
        },
        onCanvasViewCreated: { canvas in
          canvas.isScrollEnabled = true

          // Standard Apple scroll feel: momentum, bounce at edges.
          canvas.bounces = true
          canvas.alwaysBounceVertical = true
          canvas.alwaysBounceHorizontal = false
        },
        onScrollOffsetChanged: { offset in
          scrollOffset = offset
          handleScrollNearBottom()
        },
        onViewportSizeChanged: { size in
          // Use UIKit-reported bounds for pixel-accurate viewport capture.
          if size.width > 0, size.height > 0 {
            viewportWidth = size.width
            viewportHeight = size.height
          }
        },
        onUserScrolled: {
          // Dismiss the help card when the user scrolls the canvas.
          if showConnectionHelp {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
              showConnectionHelp = false
            }
          }
        }
      )
      .ignoresSafeArea()
      .background(
        // Measure actual viewport dimensions and fill with paper color.
        // ignoresSafeArea ensures the background extends into all safe area regions.
        GeometryReader { geo in
          NotebookPalette.paper
            .ignoresSafeArea()
            .onAppear {
              viewportHeight = geo.size.height
              viewportWidth = geo.size.width
            }
            .onChange(of: geo.size) { _, newSize in
              viewportHeight = newSize.height
              viewportWidth = newSize.width
            }
        }
      )

      // Crop overlay (only active in crop mode).
      // Must ignore safe area so its coordinate space matches the canvas,
      // which also ignores safe area. Without this, the crop rectangle is
      // offset from the actual content by the safe-area top inset.
      if sendMode == .crop {
        cropOverlay
          .ignoresSafeArea()
      }

      // Invisible full-screen tap target to dismiss the help card.
      if showConnectionHelp {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
              showConnectionHelp = false
            }
          }
          .ignoresSafeArea()
      }

      // Bottom send controls: mode picker pill + send button.
      VStack {
        Spacer()

        // Troubleshooting card (expanded from the help button).
        if showConnectionHelp {
          connectionHelpCard
            .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
        }

        // "No Mac found" status when disconnected.
        if !isConnected {
          disconnectedLabel
        }

        // Mode label that fades out after switching.
        modeLabelView

        // Mode picker and send button on same row.
        sendControls
      }

      // End-of-canvas indicator (fades in near the bottom).
      VStack {
        Spacer()
        endOfCanvasIndicator
      }

      // Sent toast overlay.
      if viewModel.showSentToast {
        sentToast
          .transition(.opacity)
      }
    }
    .accessibilityIdentifier("note_canvas")
    // Dismiss help card when a Mac connects.
    .onChange(of: transferService.connectionState) { _, newState in
      if newState == .connected, showConnectionHelp {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
          showConnectionHelp = false
        }
      }
    }
    // Reset ruler when switching to a different note.
    .onChange(of: viewModel.noteData?.metadata.id) {
      isRulerActive = false
    }
  }

  // MARK: - Send Mode Helpers

  // Display name shown in the fade-out label when the user switches modes.
  private var modeDisplayName: String {
    switch sendMode {
    case .crop:     return "Crop"
    case .viewport: return "This screen"
    }
  }

  // Whether the send button should be enabled for the current mode.
  // Requires both content to send and an active Mac connection.
  private var canSend: Bool {
    guard transferService.connectionState == .connected else { return false }
    switch sendMode {
    case .crop:     return cropContentRect() != nil
    case .viewport: return viewportContentRect() != nil
    }
  }

  // Whether the Mac is reachable.
  private var isConnected: Bool {
    transferService.connectionState == .connected
  }

  // MARK: - Capture Rect Helpers

  // Returns the full viewport rect (exactly what is visible on screen).
  // Captures edge-to-edge so the image is a 1:1 match of the display.
  // Returns nil only when no strokes are visible (Send stays disabled).
  private func viewportContentRect() -> CGRect? {
    guard viewportWidth > 0, viewportHeight > 0 else { return nil }
    let viewport = CGRect(
      x: 0, y: scrollOffset,
      width: viewportWidth, height: viewportHeight
    )
    let hasVisible = viewModel.drawing.strokes.contains {
      $0.renderBounds.intersects(viewport)
    }
    guard hasVisible else { return nil }
    return viewport
  }

  // Returns the crop rectangle if it contains at least one stroke.
  private func cropContentRect() -> CGRect? {
    guard let rect = cropRect else { return nil }
    let hasContent = viewModel.drawing.strokes.contains {
      $0.renderBounds.intersects(rect)
    }
    return hasContent ? rect : nil
  }

  // MARK: - End of Canvas Indicator

  // How close (in points) the viewport bottom must be to the canvas cap
  // before the indicator triggers.
  private let bottomThreshold: CGFloat = 40

  // Whether the user is currently scrolled to the bottom of the canvas.
  private var isAtBottom: Bool {
    let maxOffset = OverlayPassthroughCanvasView.maxCanvasHeight - viewportHeight
    guard maxOffset > 0 else { return false }
    return scrollOffset >= maxOffset - bottomThreshold
  }

  // Shows the indicator when the user hits the bottom, then auto-dismisses
  // after 2 seconds. Re-triggering (scrolling down again) cancels the
  // pending dismiss and restarts the timer.
  private func handleScrollNearBottom() {
    if isAtBottom {
      // Cancel any pending dismiss.
      endIndicatorDismissTask?.cancel()

      // Show the indicator.
      if !showEndIndicator {
        withAnimation(.easeOut(duration: 0.2)) { showEndIndicator = true }
      }

      // Auto-dismiss after 2 seconds.
      endIndicatorDismissTask = Task {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.4)) { showEndIndicator = false }
      }
    } else if showEndIndicator {
      // User scrolled away from the bottom — dismiss immediately.
      endIndicatorDismissTask?.cancel()
      withAnimation(.easeIn(duration: 0.15)) { showEndIndicator = false }
    }
  }

  // Subtle indicator shown near the very bottom of the screen when the
  // user scrolls to the canvas limit.
  private var endOfCanvasIndicator: some View {
    VStack(spacing: 6) {
      // Thin horizontal rule.
      Rectangle()
        .fill(NotebookPalette.inkFaint.opacity(0.3))
        .frame(width: 120, height: 1)

      Text("End of canvas")
        .font(NotebookTypography.caption)
        .foregroundColor(NotebookPalette.inkFaint)
    }
    .padding(.bottom, 32)
    .opacity(showEndIndicator ? 1 : 0)
    .allowsHitTesting(false)
  }

  // MARK: - Mode Label

  // Small grey text above the send controls indicating the active mode.
  // Fades in on mode switch, auto-dismisses after 2 seconds.
  private var modeLabelView: some View {
    Text(modeDisplayName)
      .font(NotebookTypography.caption)
      .foregroundColor(NotebookPalette.inkFaint)
      .opacity(showModeLabel ? 1 : 0)
      .padding(.bottom, 4)
      .allowsHitTesting(false)
  }

  // Triggers the mode label to appear and auto-dismiss.
  private func flashModeLabel() {
    modeLabelDismissTask?.cancel()
    withAnimation(.easeOut(duration: 0.15)) { showModeLabel = true }
    modeLabelDismissTask = Task {
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      withAnimation(.easeIn(duration: 0.4)) { showModeLabel = false }
    }
  }

  // MARK: - Send Controls

  // Bottom row: mode picker pill on the left, send capsule on the right.
  private var sendControls: some View {
    HStack {
      Spacer()

      // Cancel crop button (only in crop mode).
      if sendMode == .crop {
        Button {
          cancelCrop()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(NotebookPalette.inkSubtle)
            .frame(width: 32, height: 32)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Cancel crop")
        .transition(.opacity)
      }

      // Mode picker pill (just left of send button).
      modePickerPill

      // Connection status indicator (green dot when connected to Mac).
      connectionIndicator

      // Send drawing to Mac.
      Button(action: sendDrawing) {
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
            .fill(canSend ? NotebookPalette.ink : Color.gray.opacity(0.3))
        )
      }
      .disabled(!canSend)
      .accessibilityIdentifier("send_button")
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 20)
  }

  // MARK: - Mode Picker Pill

  // Glass pill with three mode icons, matching the tools pill style.
  private var modePickerPill: some View {
    HStack(spacing: 0) {
      // Crop mode.
      Button {
        switchMode(to: .crop)
      } label: {
        Image(systemName: sendMode == .crop ? "crop" : "crop")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(sendMode == .crop
                           ? NotebookPalette.ink
                           : NotebookPalette.inkFaint)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Crop mode")

      // Viewport mode.
      Button {
        switchMode(to: .viewport)
      } label: {
        Image(systemName: "rectangle.dashed")
          .font(.system(size: 18, weight: .medium))
          .rotationEffect(.degrees(90))
          .foregroundColor(sendMode == .viewport
                           ? NotebookPalette.ink
                           : NotebookPalette.inkFaint)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Viewport mode")

    }
    .liquidGlassBackground(cornerRadius: 22)
  }

  // Exits crop mode and returns to viewport mode.
  private func cancelCrop() {
    cropRect = nil
    cropDragStart = nil
    cropDragCurrent = nil
    sendMode = .viewport
    flashModeLabel()
  }

  // Switches to a new send mode. Clears crop state if leaving crop mode.
  private func switchMode(to mode: SendMode) {
    guard mode != sendMode else { return }

    // Clear crop selection when leaving crop mode.
    if sendMode == .crop {
      cropRect = nil
      cropDragStart = nil
      cropDragCurrent = nil
    }

    sendMode = mode
    flashModeLabel()
  }

  // MARK: - Crop Overlay

  // Height reserved at the top for the toolbar buttons (hamburger + tools pill).
  private let topSafeZone: CGFloat = 80

  // Height reserved at the bottom for the send controls.
  private let bottomSafeZone: CGFloat = 80

  // Transparent overlay that captures finger drags to define a crop rectangle.
  // Only shown when sendMode == .crop. Excludes top and bottom control areas
  // so buttons remain tappable.
  private var cropOverlay: some View {
    ZStack {
      // Dim the full canvas to indicate selection mode.
      Color.black.opacity(0.04)
        .ignoresSafeArea()
        .allowsHitTesting(false)

      // Gesture surface: fills the middle zone between top and bottom controls.
      // A clear Color provides a concrete hit-test target for the drag gesture.
      Color.clear
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
              if cropDragStart == nil {
                cropDragStart = value.startLocation
              }
              cropDragCurrent = value.location
            }
            .onEnded { _ in
              guard let start = cropDragStart, let end = cropDragCurrent else { return }
              let viewportRect = dragRect(from: start, to: end)

              // Translate from gesture coordinates to canvas content coordinates.
              // Add topSafeZone since this view starts below the top safe zone.
              let contentRect = CGRect(
                x: viewportRect.minX,
                y: viewportRect.minY + scrollOffset + topSafeZone,
                width: viewportRect.width,
                height: viewportRect.height
              )

              // Only store if the rectangle is large enough to be intentional.
              if contentRect.width > 10, contentRect.height > 10 {
                cropRect = contentRect
              }

              cropDragStart = nil
              cropDragCurrent = nil
            }
        )
        .padding(.top, topSafeZone)
        .padding(.bottom, bottomSafeZone)

      // Live drag rectangle preview (in full-screen coordinate space).
      if let start = cropDragStart, let current = cropDragCurrent {
        let rect = dragRect(
          from: CGPoint(x: start.x, y: start.y + topSafeZone),
          to: CGPoint(x: current.x, y: current.y + topSafeZone)
        )
        Rectangle()
          .stroke(NotebookPalette.ink.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
          .background(Rectangle().fill(NotebookPalette.ink.opacity(0.04)))
          .frame(width: rect.width, height: rect.height)
          .position(x: rect.midX, y: rect.midY)
          .allowsHitTesting(false)
      }

      // Stored crop rect outline (after drag completes).
      if let stored = cropRect, cropDragStart == nil {
        // Convert from canvas content coords to screen coords for display.
        let displayRect = CGRect(
          x: stored.minX,
          y: stored.minY - scrollOffset,
          width: stored.width,
          height: stored.height
        )
        Rectangle()
          .stroke(NotebookPalette.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
          .background(Rectangle().fill(NotebookPalette.ink.opacity(0.06)))
          .frame(width: displayRect.width, height: displayRect.height)
          .position(x: displayRect.midX, y: displayRect.midY)
          .allowsHitTesting(false)
      }
    }
  }

  // Builds a normalized rect from two arbitrary drag points.
  private func dragRect(from start: CGPoint, to end: CGPoint) -> CGRect {
    let minX = min(start.x, end.x)
    let minY = min(start.y, end.y)
    let width = abs(end.x - start.x)
    let height = abs(end.y - start.y)
    return CGRect(x: minX, y: minY, width: width, height: height)
  }

  // MARK: - Send Drawing

  // Renders the capture region as a single PNG and sends it to the connected
  // Mac via peer-to-peer transfer.
  private func sendDrawing() {
    let rect: CGRect?
    switch sendMode {
    case .crop:     rect = cropContentRect()
    case .viewport: rect = viewportContentRect()
    }
    guard let captureRect = rect else { return }

    // Render the drawing at 2x scale with a white background so the PNG is
    // opaque. PencilKit produces transparent backgrounds by default, which
    // causes black ink to be invisible in apps that composite on dark surfaces.
    let scale: CGFloat = 2.0
    let drawingImage = viewModel.drawing.image(from: captureRect, scale: scale)
    let pixelSize = CGSize(
      width: captureRect.width * scale,
      height: captureRect.height * scale
    )
    // Use scale=1.0 because pixelSize is already in pixels (captureRect * scale).
    // Use opaque=true to strip the alpha channel entirely — this produces a PNG
    // with no transparency, so every app renders a white background instead of
    // transparent (which many apps composite as black).
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
    let composited = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: pixelSize))
      drawingImage.draw(in: CGRect(origin: .zero, size: pixelSize))
    }
    // Map SendMode to CaptureMode for PNG metadata.
    let captureMode: CaptureMode
    switch sendMode {
    case .crop:     captureMode = .crop
    case .viewport: captureMode = .viewport
    }

    guard let cgImage = composited.cgImage,
          let pngData = PNGMetadata.buildMarkedPNG(from: cgImage, mode: captureMode)
    else { return }

    // Haptic feedback.
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    // Exit crop mode after sending, as if the user tapped the X button.
    if sendMode == .crop { cancelCrop() }

    // Send to Mac via peer-to-peer transfer.
    Task {
      do {
        try await transferService.send(pngData)
        // Success — show toast with Mac name.
        viewModel.sentToastMessage = "Sent to \(transferService.connectedMacName ?? "Mac")"
      } catch {
        // Transfer failed — show error in toast.
        viewModel.sentToastMessage = error.localizedDescription
      }
      withAnimation { viewModel.showSentToast = true }
      try? await Task.sleep(for: .seconds(1.5))
      withAnimation { viewModel.showSentToast = false }
    }
  }

  // MARK: - Toast

  private var sentToast: some View {
    let message = viewModel.sentToastMessage ?? "Sent"
    let isError = transferService.connectionState != .connected
    return HStack(spacing: 8) {
      Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        .foregroundColor(isError ? .orange : .green)
      Text(message)
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

  // MARK: - Connection Indicator

  // Small dot showing peer-to-peer connection status. Green when connected,
  // grey when searching, hidden when unavailable.
  private var connectionIndicator: some View {
    Group {
      switch transferService.connectionState {
      case .connected:
        Circle()
          .fill(.green)
          .frame(width: 8, height: 8)
      case .searching:
        Circle()
          .fill(NotebookPalette.inkSubtle.opacity(0.5))
          .frame(width: 8, height: 8)
      case .unavailable:
        EmptyView()
      }
    }
  }

  // MARK: - Disconnected State

  // "No Mac found" label with a tappable help button, shown above the send
  // controls when no Mac connection is active.
  private var disconnectedLabel: some View {
    VStack(spacing: 0) {
      Text("No Mac found")
        .font(NotebookTypography.caption)
        .foregroundColor(NotebookPalette.inkFaint)

      // Help button — expands the troubleshooting card.
      // Uses a generous content shape so the tap target is large enough
      // to intercept finger touches before PencilKit's canvas does.
      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
          showConnectionHelp.toggle()
        }
      } label: {
        Image(systemName: "questionmark.circle.fill")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(NotebookPalette.inkFaint)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 4)
    .liquidGlassBackground(cornerRadius: 22)
  }

  // Compact troubleshooting card that drops down above the send controls.
  // Lists the three most common fixes for connection issues.
  private var connectionHelpCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Card header with dismiss button.
      HStack {
        Text("Setup")
          .font(NotebookTypography.headline)
          .foregroundColor(NotebookPalette.ink)

        Spacer()

        Button {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showConnectionHelp = false
          }
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(NotebookPalette.inkFaint)
            .frame(width: 24, height: 24)
        }
      }

      // Troubleshooting steps.
      helpStep(
        number: "1",
        text: "Install **PaperClip Receiver** on your Mac. It's a free companion app that lives in your menu bar"
      )

      helpStep(
        number: "2",
        text: "Launch it. If you see the paperclip in your menu bar, it's ready. Nothing else to do"
      )

      helpStep(
        number: "3",
        text: "Make sure both devices are on the same Wi-Fi"
      )

      helpStep(
        number: "💡",
        text: "Still not connecting? Quit and reopen the PaperClip app on your Mac"
      )
    }
    .padding(16)
    .frame(maxWidth: 320, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    )
    .padding(.horizontal, 24)
    .padding(.bottom, 8)
  }

  // Single numbered step within the help card.
  private func helpStep(number: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      // Number badge — small ink circle.
      Text(number)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundColor(NotebookPalette.paper)
        .frame(width: 22, height: 22)
        .background(Circle().fill(NotebookPalette.ink))

      // Step text with inline bold support via Markdown.
      Text(LocalizedStringKey(text))
        .font(NotebookTypography.caption)
        .foregroundColor(NotebookPalette.inkSubtle)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
