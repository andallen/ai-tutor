import SwiftUI
import UIKit

// MARK: - Folder Card Button

// Interactive container for a folder card with tactile press effects.
// The card portion has drag behavior; the title is a sibling
// that animates together but stays outside the context menu highlight.
struct FolderCardButton: View {
  let folder: FolderMetadata
  let thumbnails: [UIImage]
  let action: () -> Void
  // Context menu actions passed in from the parent view.
  let onRename: () -> Void
  let onDelete: () -> Void
  // Long press callback for custom context menu. Passes the card frame and card height.
  let onLongPress: ((CGRect, CGFloat) -> Void)?
  // Controls the opacity of just the card preview (not the title).
  // Used during folder expansion so the title stays visible.
  var previewOpacity: Double = 1.0
  // Offset to move the card from when appearing (e.g., from overlay center).
  // Applied proportionally to (1 - previewOpacity) so card moves from offset to zero.
  var appearanceOffset: CGSize = .zero
  // Number of items being dragged out of this folder.
  // Used to reduce displayed item count while drag is in progress.
  var draggedOutCount: Int = 0

  // Convenience initializer with default nil for onLongPress.
  init(
    folder: FolderMetadata,
    thumbnails: [UIImage],
    action: @escaping () -> Void,
    onRename: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    onLongPress: ((CGRect, CGFloat) -> Void)? = nil,
    previewOpacity: Double = 1.0,
    appearanceOffset: CGSize = .zero,
    draggedOutCount: Int = 0
  ) {
    self.folder = folder
    self.thumbnails = thumbnails
    self.action = action
    self.onRename = onRename
    self.onDelete = onDelete
    self.onLongPress = onLongPress
    self.previewOpacity = previewOpacity
    self.appearanceOffset = appearanceOffset
    self.draggedOutCount = draggedOutCount
  }

  // Tracks press state via gesture. Automatically resets when gesture ends or cancels.
  @GestureState private var isPressed = false
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

  // Uses shared constants from CardConstants for consistency across all card types.

  var body: some View {
    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - CardConstants.titleAreaHeight

      VStack(alignment: .leading, spacing: 4) {
        // The card portion wrapped in a button.
        // Uses a white overlay that fades OUT instead of fading the card in,
        // to avoid the blurry grey appearance from the glass material at low opacity.
        ZStack {
          cardButton(width: totalWidth, height: cardHeight)
          // White overlay that fades out as previewOpacity approaches 1.
          // This covers the glass material so it fades in from clean white.
          RoundedRectangle(cornerRadius: CardConstants.cornerRadius, style: .continuous)
            .fill(Color.white)
            .frame(width: totalWidth, height: cardHeight)
            .opacity(1 - previewOpacity)
            .allowsHitTesting(false)
        }
        // Offset toward the overlay center when hidden.
        // Uses a moderate multiplier so the card visibly returns from the overlay direction
        // while still staying close enough to avoid harsh animation jumps.
        .offset(
          x: appearanceOffset.width * (1 - previewOpacity) * 0.35,
          y: appearanceOffset.height * (1 - previewOpacity) * 0.35
        )
        .animation(.spring(response: 0.26, dampingFraction: 0.80), value: previewOpacity)
        // Scale increase when hidden to match the overlay's expanded size.
        .scaleEffect(1.0 + (1 - previewOpacity) * 0.25)
        // Fade out the card when the folder is expanded.
        .opacity(previewOpacity)
        .animation(.spring(response: 0.22, dampingFraction: 0.9), value: previewOpacity)

        // Title and notebook count below the card.
        // Fades with a fast animation so the name appears quickly on contraction.
        FolderCardTitle(folder: folder, draggedOutCount: draggedOutCount)
          .opacity(previewOpacity)
          .animation(.spring(response: 0.05, dampingFraction: 0.9), value: previewOpacity)
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
    .aspectRatio(CardConstants.aspectRatio, contentMode: .fit)
    // Scale animation applies to both card and title together.
    .scaleEffect(isPressed ? CardConstants.Press.scale : 1.0)
    .animation(
      .spring(response: CardConstants.Press.springResponse, dampingFraction: CardConstants.Press.springDamping),
      value: isPressed
    )
    // Detects touch down/up for scale and sweep animations.
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .updating($isPressed) { _, state, _ in
          state = true
        }
    )
    // Responds to press state changes to schedule sweep.
    .onChange(of: isPressed) { _, pressed in
      handlePressChange(pressed)
    }
  }

  // Builds the card with tap gesture.
  // Uses onTapGesture instead of Button to avoid conflicts with gesture handling.
  @ViewBuilder
  private func cardButton(width: CGFloat, height: CGFloat) -> some View {
    let shape = cardShape()

    FolderCardPreview(folder: folder, thumbnails: thumbnails, draggedOutCount: draggedOutCount)
      .frame(width: width, height: height)
      .background(Color.white.opacity(0.01))
      .clipShape(shape)
      .cardShadow()
      .overlay(
        SweepAnimationOverlay(isActive: showHighlight, sweepOffset: sweepOffset)
          .frame(width: width, height: height)
      )
      .contentShape(shape)
      .onTapGesture {
        // Only execute action if context menu wasn't triggered by long press.
        guard !didTriggerContextMenu else { return }
        action()
      }
  }

  // Handles press state changes to schedule sweep/context menu.
  private func handlePressChange(_ pressed: Bool) {
    if pressed {
      // Reset context menu flag at start of new press to ensure taps work after menu dismissal.
      didTriggerContextMenu = false

      // Schedule context menu and sweep animation after a delay.
      // If gesture ends before the delay (a tap or cancel), the work item is cancelled.
      let currentFrame = cardFrame
      let cardHeight = currentFrame.height - CardConstants.titleAreaHeight
      let workItem = DispatchWorkItem { [onLongPress] in
        // Mark that context menu was triggered to prevent button action on release.
        didTriggerContextMenu = true

        // Trigger custom context menu if callback is provided.
        if let onLongPress {
          onLongPress(currentFrame, cardHeight)
        }

        // Continue with sweep animation.
        guard !showHighlight else { return }
        showHighlight = true
        sweepOffset = CardConstants.Sweep.offsetStart
        withAnimation(.easeOut(duration: CardConstants.Sweep.duration)) {
          sweepOffset = CardConstants.Sweep.offsetEnd
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + CardConstants.Sweep.duration) {
          showHighlight = false
        }
      }
      sweepWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + CardConstants.longPressDelay, execute: workItem)
    } else {
      // Cancel pending sweep if it hasn't fired yet.
      sweepWorkItem?.cancel()
      sweepWorkItem = nil
      // Reset context menu flag after a brief delay to allow button action check.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        didTriggerContextMenu = false
      }
    }
  }
}

// MARK: - Folder Card Preview

// Displays only the folder card glass background and thumbnail grid. No title, no shadow.
// Shadow is applied at the button level to work correctly with iOS context menu transitions.
struct FolderCardPreview: View {
  let folder: FolderMetadata
  let thumbnails: [UIImage]
  // Number of items being dragged out of this folder.
  // Reduces the displayed item count to reflect the pending removal.
  var draggedOutCount: Int = 0

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height

      ZStack {
        glassContent(cornerRadius: CardConstants.cornerRadius)
        thumbnailGrid(
          size: CGSize(width: width, height: height),
          cornerRadius: CardConstants.cornerRadius
        )
      }
    }
  }

  // Draws the liquid glass background effect.
  @ViewBuilder
  private func glassContent(cornerRadius: CGFloat) -> some View {
    if #available(iOS 26.0, *) {
      // Uses the liquid glass effect on iOS 26+.
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color.clear)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    } else {
      // Falls back to a blurred material background on older iOS.
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
    }
  }

  // Draws a 2x2 grid of item thumbnails (notebooks and PDFs) inside the folder card.
  @ViewBuilder
  private func thumbnailGrid(size: CGSize, cornerRadius: CGFloat) -> some View {
    let padding: CGFloat = 6
    let spacing: CGFloat = 3
    let thumbnailCornerRadius: CGFloat = 4

    // Calculates the size of each thumbnail cell.
    let maxCellWidth = (size.width - padding * 2 - spacing) / 2
    let maxCellHeight = (size.height - padding * 2 - spacing) / 2
    let cellSize = min(maxCellWidth, maxCellHeight)

    // Limits displayed cells to actual item count (notebooks + PDFs, max 4).
    // Subtract dragged out count to reflect items being removed.
    let displayCount = max(0, min(folder.itemCount, 4) - draggedOutCount)

    // Grid of notebook thumbnails with invisible spacers for empty positions.
    VStack(alignment: .leading, spacing: spacing) {
      HStack(spacing: spacing) {
        thumbnailCell(
          index: 0, size: cellSize, cornerRadius: thumbnailCornerRadius,
          visible: displayCount > 0)
        thumbnailCell(
          index: 1, size: cellSize, cornerRadius: thumbnailCornerRadius,
          visible: displayCount > 1)
      }
      HStack(spacing: spacing) {
        thumbnailCell(
          index: 2, size: cellSize, cornerRadius: thumbnailCornerRadius,
          visible: displayCount > 2)
        thumbnailCell(
          index: 3, size: cellSize, cornerRadius: thumbnailCornerRadius,
          visible: displayCount > 3)
      }
    }
    .padding(padding)
  }

  // Draws a single thumbnail cell in the 2x2 grid.
  @ViewBuilder
  private func thumbnailCell(
    index: Int, size: CGFloat, cornerRadius: CGFloat, visible: Bool
  ) -> some View {
    if !visible {
      // Invisible spacer to maintain grid structure.
      Color.clear
        .frame(width: size, height: size)
    } else if index < thumbnails.count {
      // Shows the notebook preview image.
      Image(uiImage: thumbnails[index])
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    } else {
      // Shows a notebook icon placeholder for notebooks without preview images.
      ZStack {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.white)
        Image(systemName: "doc.text")
          .font(.system(size: size * 0.35, weight: .light))
          .foregroundStyle(Color.black.opacity(0.2))
      }
      .frame(width: size, height: size)
      .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
  }
}

// MARK: - Folder Card Title

// Displays the folder name and item count (notebooks + PDFs).
// Rendered as a sibling to the card preview, outside the context menu scope.
struct FolderCardTitle: View {
  let folder: FolderMetadata
  // Number of items being dragged out of this folder.
  // Reduces the displayed item count to reflect the pending removal.
  var draggedOutCount: Int = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(folder.displayName)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.ink)
        .lineLimit(1)
        .truncationMode(.tail)

      Text(itemCountLabel)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
        .lineLimit(1)
    }
    .padding(.horizontal, 2)
  }

  // Formats the item count label.
  // Shows "notebooks" if only notebooks, "PDFs" if only PDFs, or "items" if mixed.
  // Subtracts draggedOutCount to reflect items being removed during drag.
  private var itemCountLabel: String {
    let total = max(0, folder.itemCount - draggedOutCount)
    if total == 0 {
      return "Empty"
    } else if folder.pdfCount == 0 {
      // Only notebooks.
      return total == 1 ? "1 notebook" : "\(total) notebooks"
    } else if folder.notebookCount == 0 {
      // Only PDFs.
      return total == 1 ? "1 PDF" : "\(total) PDFs"
    } else {
      // Mixed content.
      return total == 1 ? "1 item" : "\(total) items"
    }
  }
}

// MARK: - Folder Card Context Menu Preview

// Standalone preview view for context menus that shows only the folder card without title.
// Used with .contextMenu(menuItems:preview:) as the lifted preview.
struct FolderCardContextMenuPreview: View {
  let folder: FolderMetadata
  let thumbnails: [UIImage]

  var body: some View {
    let cardSize = CGSize(
      width: CardConstants.contextMenuPreviewWidth,
      height: CardConstants.contextMenuPreviewHeight
    )

    ZStack {
      glassContent(cornerRadius: CardConstants.cornerRadius)
      thumbnailGrid(size: cardSize, cornerRadius: CardConstants.cornerRadius)
    }
    .frame(width: cardSize.width, height: cardSize.height)
    .clipShape(RoundedRectangle(cornerRadius: CardConstants.cornerRadius, style: .continuous))
    .cardShadow()
  }

  // Draws the liquid glass background effect.
  @ViewBuilder
  private func glassContent(cornerRadius: CGFloat) -> some View {
    if #available(iOS 26.0, *) {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color.clear)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    } else {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
    }
  }

  // Draws a 2x2 grid of item thumbnails (notebooks and PDFs).
  @ViewBuilder
  private func thumbnailGrid(size: CGSize, cornerRadius: CGFloat) -> some View {
    let padding: CGFloat = 6
    let spacing: CGFloat = 3
    let thumbnailCornerRadius: CGFloat = 4

    let maxCellWidth = (size.width - padding * 2 - spacing) / 2
    let maxCellHeight = (size.height - padding * 2 - spacing) / 2
    let cellSize = min(maxCellWidth, maxCellHeight)

    let displayCount = min(folder.itemCount, 4)

    VStack(alignment: .leading, spacing: spacing) {
      HStack(spacing: spacing) {
        thumbnailCell(
          index: 0, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 0)
        thumbnailCell(
          index: 1, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 1)
      }
      HStack(spacing: spacing) {
        thumbnailCell(
          index: 2, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 2)
        thumbnailCell(
          index: 3, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 3)
      }
    }
    .padding(padding)
  }

  // Draws a single thumbnail cell.
  @ViewBuilder
  private func thumbnailCell(
    index: Int, size: CGFloat, cornerRadius: CGFloat, visible: Bool
  ) -> some View {
    if !visible {
      Color.clear.frame(width: size, height: size)
    } else if index < thumbnails.count {
      Image(uiImage: thumbnails[index])
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.white)
        Image(systemName: "doc.text")
          .font(.system(size: size * 0.35, weight: .light))
          .foregroundStyle(Color.black.opacity(0.2))
      }
      .frame(width: size, height: size)
      .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
  }
}
