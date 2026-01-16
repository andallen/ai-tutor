//
// NotebookCanvasView.swift
// InkOS
//
// Pure white canvas that renders the notebook document.
// User taps anywhere on content to advance to the next block.
// Alan's presence indicator (metaball) tracks the currently animating block.
// Uses ScrollView with LazyVStack for performance.
// Follows Apple HIG for iPad with proper touch targets and safe areas.
//

import SwiftUI

// MARK: - NotebookCanvasView

// Pure white canvas for rendering notebook blocks.
// User controls pacing by tapping to reveal the next block.
struct NotebookCanvasView: View {
  @Bindable var viewModel: NotebookViewModel
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // Animated Y position for smooth blob movement.
  // Updated with spring animation when anchor position changes.
  // Initial position near top of content area.
  @State private var animatedBlobY: CGFloat = 60

  var body: some View {
    // Main scrollable content with tap-to-advance.
    ScrollView {
      // Content with blob positioned relative to anchor.
      // Blob is inside ScrollView so it scrolls naturally with content.
      LazyVStack(spacing: 0) {
        ForEach(viewModel.document.blocks) { block in
          BlockContainerView(
            block: block,
            animationState: viewModel.animationState[block.id] ?? .waiting,
            isMetaballTarget: block.id == viewModel.metaballTargetBlockId
          )
        }
      }
      .padding(.horizontal, horizontalPadding)
      .padding(.top, 100)
      .padding(.bottom, 80)
      // Position blob inside content using background preference reader.
      // This makes the blob scroll with the content naturally.
      .backgroundPreferenceValue(FirstLineAnchor.self) { anchor in
        GeometryReader { geometry in
          // Calculate target position from anchor.
          // Only use anchor when a block is actually animating (not just waiting).
          let targetY: CGFloat? = {
            guard viewModel.hasAnimatingBlock, let anchor = anchor else { return nil }
            let frame = geometry[anchor]
            return frame.maxY + NotebookSpacing.lg
          }()

          // X position: align leftmost orbiting dot with text's left edge.
          // Frame is 100x100. Orbit radius is 0.55 in UV (-1 to 1), so ~55px diameter.
          // Leftmost dot = frame_left + 22.5. To align with text: blobX = padding + 27.5.
          let blobX: CGFloat = horizontalPadding + 28

          AlanPresenceView(state: viewModel.alanState)
            .position(
              x: blobX,
              y: animatedBlobY
            )
            .accessibilityIdentifier("alan_presence_blob")
            .onChange(of: targetY) { _, newY in
              // Only animate when we have a valid anchor position.
              // Prevents jumping to default when anchor is briefly nil during transitions.
              guard let newY = newY else { return }
              withAnimation(.spring(response: 0.15, dampingFraction: 0.85)) {
                animatedBlobY = newY
              }
            }
        }
      }
    }
    .background(NotebookPalette.paper)
    .contentShape(Rectangle())
    .accessibilityIdentifier("notebook_canvas")
    .onTapGesture {
      viewModel.advanceToNextBlock()
    }
    .onAppear {
      viewModel.prepareFirstBlock()
    }
  }

  // Responsive horizontal padding based on size class.
  private var horizontalPadding: CGFloat {
    horizontalSizeClass == .regular
      ? NotebookLayout.horizontalPaddingRegular
      : NotebookLayout.horizontalPaddingCompact
  }
}

// MARK: - Preview

#Preview {
  NotebookCanvasView(viewModel: NotebookViewModel(document: .preview))
}
