//
// NotebookCanvasView.swift
// InkOS
//
// Pure white canvas that renders the notebook document.
// User taps anywhere on content to advance to the next block.
// Fixed input bar at the bottom of the screen for messaging Alan.
// Uses ScrollView with LazyVStack for performance.
// Follows Apple HIG for iPad with proper touch targets and safe areas.
//
// The canvas has three main zones:
// 1. Content Zone - Alan's blocks rendered in a scrollable area
// 2. User Input Zone - Drawing/typing area below content
// 3. Fixed Input Bar - Liquid glass pill at bottom of screen
//

import PhotosUI
import SwiftUI

// MARK: - NotebookCanvasView

// Pure white canvas for rendering notebook blocks.
// User controls pacing by tapping to reveal the next block.
// Fixed input bar at the bottom allows user to message Alan at any time.
struct NotebookCanvasView: View {
  @Bindable var viewModel: NotebookViewModel
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // Shared input view model for user input zone.
  @State private var inputViewModel = CanvasInputViewModel()

  var body: some View {
    ZStack(alignment: .bottom) {
      // Main scrollable content with tap-to-advance.
      ScrollViewReader { scrollProxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            // Alan's content blocks.
            ForEach(viewModel.document.blocks, id: \.id) { block in
              BlockContainerView(
                block: block,
                animationState: viewModel.animationState[block.id] ?? .waiting
              )
            }

            // User input preview blocks (submitted content).
            ForEach(viewModel.inputPreviews) { preview in
              InputPreviewBlockView(
                response: preview.response,
                timestamp: preview.timestamp
              )
              .padding(.top, NotebookSpacing.lg)
              .id("preview_\(preview.id)")
            }

            // User input zone - drawing and text area below content.
            userInputZone
              .padding(.top, NotebookSpacing.xl)
              .id("input_zone")
          }
          .padding(.horizontal, horizontalPadding)
          .padding(.top, 100)
          .padding(.bottom, 160)  // Extra padding for fixed input bar
        }
        .background(NotebookPalette.paper)
        .contentShape(Rectangle())
        .onTapGesture {
          viewModel.handleContentTap()
        }
        .onChange(of: viewModel.inputPreviews.count) { oldCount, newCount in
          // Scroll to new preview when added.
          if newCount > oldCount, let lastPreview = viewModel.inputPreviews.last {
            withAnimation(.easeOut(duration: 0.3)) {
              scrollProxy.scrollTo("preview_\(lastPreview.id)", anchor: .bottom)
            }
          }
        }
      }
      .accessibilityIdentifier("notebook_canvas")

      // Error banner (if any). Auto-dismisses after 8 seconds.
      if let error = viewModel.errorMessage {
        errorBanner(error)
          .padding(.horizontal, 20)
          .padding(.bottom, 8)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .task(id: error) {
            // Task is automatically cancelled when the error changes or view disappears.
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            withAnimation {
              viewModel.errorMessage = nil
            }
          }
      }

      // Glass pill toolbar centered at bottom of screen.
      canvasInputBar
        .padding(.bottom, 30)
    }
    .background(NotebookPalette.paper)
  }

  // MARK: - User Input Zone

  // The drawing and text input area positioned below all content.
  private var userInputZone: some View {
    UserInputZoneView(viewModel: inputViewModel)
      .frame(minHeight: 200)
  }

  // MARK: - Canvas Input Bar

  // The fixed liquid glass pill toolbar at bottom of screen.
  private var canvasInputBar: some View {
    CanvasInputBar(viewModel: inputViewModel) { response in
      viewModel.submitCanvasInput(response)
    }
  }

  // Error banner shown when Alan encounters an error.
  private func errorBanner(_ message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundColor(.red)
      Text(message)
        .font(NotebookTypography.caption)
        .foregroundColor(NotebookPalette.ink)
        .lineLimit(2)

      Spacer()

      Button(action: { viewModel.errorMessage = nil }) {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(NotebookPalette.inkSubtle)
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.red.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.red.opacity(0.2), lineWidth: 1)
    )
  }

  // Responsive horizontal padding based on size class.
  private var horizontalPadding: CGFloat {
    horizontalSizeClass == .regular
      ? NotebookLayout.horizontalPaddingRegular
      : NotebookLayout.horizontalPaddingCompact
  }
}

// MARK: - CanvasInputBar

// The liquid glass pill toolbar that stays fixed at the bottom.
// Separated from CanvasInputView for layout purposes.
struct CanvasInputBar: View {
  // Shared input view model.
  @Bindable var viewModel: CanvasInputViewModel

  // Callback when user submits.
  var onSubmit: ((InputResponse) -> Void)?

  // Photo picker selection.
  @State private var selectedPhotos: [PhotosPickerItem] = []

  // Sequential fade-in animation state.
  @State private var pencilIconVisible = false
  @State private var keyboardIconVisible = false
  @State private var paperclipIconVisible = false
  @State private var sendButtonVisible = false

  // Alert state for errors.
  @State private var showingError = false

  var body: some View {
    VStack(spacing: 0) {
      // Attachment preview grid (if any attachments).
      if !viewModel.attachments.isEmpty {
        AttachmentPreviewGrid(attachments: viewModel.attachments) { attachment in
          viewModel.removeAttachment(attachment)
        }
        .padding(.horizontal, NotebookSpacing.md)
        .padding(.bottom, NotebookSpacing.xs)
      }

      // Glass pill toolbar.
      glassPillToolbar
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("canvas_input_bar")
    .onChange(of: selectedPhotos) { _, newItems in
      Task {
        await loadSelectedPhotos(newItems)
      }
    }
    .onAppear {
      // Sequential fade-in animation.
      withAnimation(.easeOut(duration: 0.2).delay(0.0)) {
        pencilIconVisible = true
      }
      withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
        keyboardIconVisible = true
      }
      withAnimation(.easeOut(duration: 0.2).delay(0.2)) {
        paperclipIconVisible = true
      }
      withAnimation(.easeOut(duration: 0.2).delay(0.3)) {
        sendButtonVisible = true
      }
    }
    .alert(
      "Attachment Error",
      isPresented: $showingError,
      presenting: viewModel.currentError
    ) { _ in
      Button("OK", role: .cancel) {
        viewModel.currentError = nil
      }
    } message: { error in
      Text(error.localizedDescription)
    }
  }

  private var glassPillToolbar: some View {
    HStack(spacing: 24) {
      // Pencil mode button.
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          viewModel.switchToPencilMode()
        }
      } label: {
        Image(systemName: "pencil.tip")
          .font(.system(size: 22, weight: .medium))
          .foregroundColor(
            viewModel.mode == .pencil ? NotebookPalette.ink : NotebookPalette.inkSubtle)
      }
      .opacity(pencilIconVisible ? 1 : 0)
      .accessibilityLabel("Pencil mode")
      .accessibilityValue(viewModel.mode == .pencil ? "selected" : "")
      .accessibilityIdentifier("pencil_mode_button")

      // Keyboard mode button.
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          viewModel.switchToKeyboardMode()
        }
      } label: {
        Image(systemName: "keyboard")
          .font(.system(size: 22, weight: .medium))
          .foregroundColor(
            viewModel.mode == .keyboard ? NotebookPalette.ink : NotebookPalette.inkSubtle)
      }
      .opacity(keyboardIconVisible ? 1 : 0)
      .accessibilityLabel("Keyboard mode")
      .accessibilityValue(viewModel.mode == .keyboard ? "selected" : "")
      .accessibilityIdentifier("keyboard_mode_button")

      // Paperclip attachment picker.
      PhotosPicker(
        selection: $selectedPhotos,
        maxSelectionCount: max(1, AttachmentLimits.maxFileCount - viewModel.attachments.count),
        matching: .any(of: [.images, .screenshots])
      ) {
        Image(systemName: "paperclip")
          .font(.system(size: 22, weight: .medium))
          .foregroundColor(NotebookPalette.inkSubtle)
      }
      .opacity(paperclipIconVisible ? 1 : 0)
      .accessibilityLabel("Attach image")
      .accessibilityIdentifier("paperclip_button")

      // Send button.
      Button {
        submitInput()
      } label: {
        ZStack {
          Circle()
            .fill(viewModel.canSubmit ? Color.black : NotebookPalette.inkFaint)
            .frame(width: 36, height: 36)
          Image(systemName: "arrow.up")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
        }
      }
      .disabled(!viewModel.canSubmit)
      .opacity(sendButtonVisible ? 1 : 0)
      .accessibilityLabel("Send")
      .accessibilityIdentifier("send_button")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .glassEffect(.regular.interactive(), in: .capsule)
  }

  private func submitInput() {
    guard viewModel.canSubmit else { return }

    viewModel.isSubmitting = true

    let response = viewModel.buildResponse()
    viewModel.clearAllInput()
    selectedPhotos = []

    onSubmit?(response)
  }

  private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
    var newAttachments: [CanvasInputViewModel.AttachmentData] = []

    for item in items {
      if viewModel.attachments.contains(where: { $0.id == item.itemIdentifier ?? "" }) {
        continue
      }

      guard let data = try? await item.loadTransferable(type: Data.self) else {
        viewModel.currentError = .loadFailed(filename: "image")
        showingError = true
        continue
      }

      newAttachments.append(
        CanvasInputViewModel.AttachmentData(
          data: data,
          filename: "image_\(Date().timeIntervalSince1970).png",
          mimeType: "image/png"
        ))
    }

    if let error = viewModel.addAttachments(newAttachments) {
      viewModel.currentError = error
      showingError = true
    }

    selectedPhotos = []
  }
}

// MARK: - Preview

#Preview {
  NotebookCanvasView(
    viewModel: NotebookViewModel(document: .preview)
  )
}
