//
// LessonCardView.swift
// InkOS
//
// Dashboard card for lessons with progress indicator.
// Matches the styling and interactions of NotebookCardButton and PDFDocumentCardButton.
//

import SwiftUI

// MARK: - Lesson Card Button

// Interactive container for a lesson card with tactile press effects.
// Mirrors NotebookCardButton behavior exactly for consistent user experience.
struct LessonCardButton: View {
  let lesson: LessonMetadata
  let action: () -> Void
  let onRename: () -> Void
  let onDelete: () -> Void
  // Long press callback for custom context menu. Passes the card frame and card height.
  let onLongPress: ((CGRect, CGFloat) -> Void)?
  // Opacity for the title/date label. Allows parent to fade the title when targeted.
  var titleOpacity: Double = 1.0

  // Controls the darkening overlay opacity on the card.
  @State private var dimOpacity: Double = 0
  // Drives a highlight flash on long press.
  @State private var showHighlight = false
  // Moves a bright sweep across the card on long press.
  @State private var sweepOffset: CGFloat = -1.2
  // Tracks the pending sweep animation work item so it can be cancelled on tap.
  @State private var sweepWorkItem: DispatchWorkItem?
  // Tracks the card's global frame for context menu positioning.
  @State private var cardFrame: CGRect = .zero
  // Tracks whether the context menu was triggered to prevent button action on release.
  @State private var didTriggerContextMenu = false
  // Tracks the starting position of the touch for drag threshold detection.
  @State private var touchStartPosition: CGPoint = .zero

  // CONSISTENCY: These values must match NotebookCardButton, PDFDocumentCardButton, FolderCardButton
  private let cardCornerRadius: CGFloat = 10
  private let titleAreaHeight: CGFloat = 36
  // Keeps a paper-like portrait ratio for the overall container.
  private let cardAspectRatio: CGFloat = 0.72

  var body: some View {
    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - titleAreaHeight

      VStack(alignment: .leading, spacing: 4) {
        // The card portion.
        cardContent(width: totalWidth, height: cardHeight)

        // Title and metadata below the card.
        LessonCardTitle(lesson: lesson)
          .opacity(titleOpacity)
          .animation(.easeOut(duration: 0.2), value: titleOpacity)
      }
      // Capture global frame for context menu positioning.
      .background(
        GeometryReader { geometry in
          Color.clear
            .onAppear {
              cardFrame = geometry.frame(in: .global)
            }
            .onChange(of: geometry.frame(in: .global)) { _, newFrame in
              cardFrame = newFrame
            }
        }
      )
    }
    .aspectRatio(cardAspectRatio, contentMode: .fit)
    // Combined gesture for press and long press.
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          handleGestureChange(value)
        }
        .onEnded { value in
          handleGestureEnd(value)
        }
    )
  }

  // Builds the card content view.
  @ViewBuilder
  private func cardContent(width: CGFloat, height: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

    LessonCardPreview(lesson: lesson, dimOpacity: dimOpacity)
      .frame(width: width, height: height)
      .background(Color.white)
      .clipShape(shape)
      .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
      .overlay(
        sweepOverlay(width: width, height: height)
      )
      .contentShape(shape)
      // Scale up slightly when pressed.
      // CONSISTENCY: Press scale (1.04) must match all card types
      .scaleEffect(dimOpacity > 0 ? 1.04 : 1.0)
      // CONSISTENCY: Press animation must match all card types
      .animation(.spring(response: 0.15, dampingFraction: 0.75), value: dimOpacity > 0)
  }

  // Builds the sweep highlight overlay that plays on long press.
  @ViewBuilder
  private func sweepOverlay(width: CGFloat, height: CGFloat) -> some View {
    let sweepDistance = width * 1.2
    ZStack {
      RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        .fill(Color.white.opacity(showHighlight ? 0.7 : 0.0))
        .blendMode(.screen)
        .animation(.easeOut(duration: 0.28), value: showHighlight)

      RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        .fill(
          LinearGradient(
            stops: [
              .init(color: Color.white.opacity(0.0), location: 0.0),
              .init(color: Color.white.opacity(0.45), location: 0.45),
              .init(color: Color.white.opacity(0.75), location: 0.55),
              .init(color: Color.white.opacity(0.0), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .blendMode(.screen)
        .offset(x: sweepOffset * sweepDistance)
        .opacity(showHighlight ? 1.0 : 0.0)
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    .allowsHitTesting(false)
  }

  // Handles gesture changes (touch down, movement).
  private func handleGestureChange(_ value: DragGesture.Value) {
    // First touch: initialize state.
    if touchStartPosition == .zero {
      touchStartPosition = value.startLocation
      didTriggerContextMenu = false

      // Dim immediately on touch down.
      // CONSISTENCY: Dim timing and opacity must match all card types
      withAnimation(.easeOut(duration: 0.06)) {
        dimOpacity = 0.12
      }

      // Schedule context menu and sweep animation after a delay.
      let currentFrame = cardFrame
      let cardHeight = currentFrame.height - titleAreaHeight
      let workItem = DispatchWorkItem { [onLongPress] in
        // Mark that context menu was triggered.
        didTriggerContextMenu = true

        // Fade out the dim overlay.
        withAnimation(.easeOut(duration: 0.2)) {
          dimOpacity = 0
        }

        // Trigger custom context menu if callback is provided.
        if let onLongPress {
          onLongPress(currentFrame, cardHeight)
        }

        // Play sweep animation.
        guard !showHighlight else { return }
        showHighlight = true
        sweepOffset = -1.2
        withAnimation(.easeOut(duration: 0.5)) {
          sweepOffset = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          showHighlight = false
        }
      }
      sweepWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
  }

  // Handles gesture end (touch up).
  private func handleGestureEnd(_ value: DragGesture.Value) {
    // Cancel pending sweep if it hasn't fired yet.
    sweepWorkItem?.cancel()
    sweepWorkItem = nil

    if !didTriggerContextMenu {
      // Short tap without context menu: trigger action.
      action()
    }

    // Reset state.
    withAnimation(.easeOut(duration: 0.25)) {
      dimOpacity = 0
    }
    touchStartPosition = .zero
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      didTriggerContextMenu = false
    }
  }
}

// MARK: - Lesson Card Preview

// Displays the lesson card content: preview image or placeholder.
struct LessonCardPreview: View {
  let lesson: LessonMetadata
  var dimOpacity: Double = 0

  // Inset to crop out the thin black line on the right edge of the canvas capture.
  private let previewEdgeInset: CGFloat = 2

  var body: some View {
    let previewImage = lesson.previewImage.flatMap { UIImage(data: $0) }

    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height

      ZStack {
        // Draws the preview or placeholder cover.
        // Uses topLeading alignment to anchor the image consistently,
        // preventing vertical shift during context menu transitions.
        if let previewImage {
          Image(uiImage: previewImage)
            .resizable()
            .scaledToFill()
            .frame(width: width + previewEdgeInset, height: height)
            .frame(width: width, height: height, alignment: .topLeading)
            .clipped()
        } else {
          // Placeholder when no preview image exists.
          VStack(spacing: 8) {
            Image(systemName: "book.pages")
              .font(.system(size: 32))
              .foregroundColor(Color.inkSubtle)
            Text("Lesson")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color.inkSubtle)
          }
          .frame(width: width, height: height)
        }

        // Darkening overlay for press feedback.
        Color.black.opacity(dimOpacity)
          .allowsHitTesting(false)
      }
    }
  }
}

// MARK: - Lesson Card Title

// Displays the lesson title and metadata.
struct LessonCardTitle: View {
  let lesson: LessonMetadata

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(lesson.displayName)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.ink)
        .lineLimit(1)
        .truncationMode(.tail)

      Text(subtitleText)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .padding(.horizontal, 2)
  }

  // Builds the subtitle text from metadata.
  private var subtitleText: String {
    // Always show "Lesson" for all lessons.
    return "Lesson"
  }
}

// MARK: - Lesson Card Context Menu Preview

// Standalone preview view for context menus.
struct LessonCardContextMenuPreview: View {
  let lesson: LessonMetadata

  private let cardCornerRadius: CGFloat = 10
  private let previewWidth: CGFloat = 160
  private let previewHeight: CGFloat = 200
  private let previewEdgeInset: CGFloat = 2

  var body: some View {
    let previewImage = lesson.previewImage.flatMap { UIImage(data: $0) }

    ZStack {
      Color.white

      // Show preview image if available.
      if let previewImage {
        Image(uiImage: previewImage)
          .resizable()
          .scaledToFill()
          .frame(width: previewWidth + previewEdgeInset, height: previewHeight)
          .frame(width: previewWidth, height: previewHeight, alignment: .topLeading)
          .clipped()
      } else {
        // Placeholder when no preview image exists.
        VStack(spacing: 8) {
          Image(systemName: "book.pages")
            .font(.system(size: 32))
            .foregroundColor(Color.inkSubtle)
          Text("Lesson")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color.inkSubtle)
        }
      }
    }
    .frame(width: previewWidth, height: previewHeight)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
  }
}

// MARK: - Preview

#Preview {
  let sampleLesson = LessonMetadata(
    id: "preview-1",
    displayName: "Photosynthesis Basics",
    subject: "Biology",
    estimatedMinutes: nil,
    createdAt: Date(),
    modifiedAt: Date(),
    completionPercentage: 0
  )

  return VStack(spacing: 24) {
    LessonCardButton(
      lesson: sampleLesson,
      action: { print("Tapped") },
      onRename: { print("Rename") },
      onDelete: { print("Delete") },
      onLongPress: nil
    )
    .frame(width: 160)

    LessonCardContextMenuPreview(lesson: sampleLesson)
  }
  .padding()
  .background(Color.white)
}
