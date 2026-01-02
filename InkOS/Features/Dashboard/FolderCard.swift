import SwiftUI
import UIKit

// Displays a folder in the Dashboard grid with a glass pill appearance.
// Shows up to 4 notebook previews in a 2x2 thumbnail grid.
// Title and notebook count appear below the card.
struct FolderCard: View {
  let folder: FolderMetadata
  let thumbnails: [UIImage]

  // Height reserved for the external title area below the card.
  private let titleAreaHeight: CGFloat = 36

  var body: some View {
    let cardCornerRadius: CGFloat = 10
    // Keeps the same portrait ratio as notebook cards for the overall container.
    let cardAspectRatio: CGFloat = 0.72

    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - titleAreaHeight

      VStack(alignment: .leading, spacing: 4) {
        // The folder card with glass background and thumbnail grid.
        ZStack {
          glassContent(cornerRadius: cardCornerRadius)
          thumbnailGrid(
            size: CGSize(width: totalWidth, height: cardHeight),
            cornerRadius: cardCornerRadius
          )
        }
        .frame(width: totalWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)

        // Title and notebook count below the card.
        VStack(alignment: .leading, spacing: 1) {
          Text(folder.displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .truncationMode(.tail)

          Text(notebookCountLabel)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.inkSubtle)
            .lineLimit(1)
        }
        .padding(.horizontal, 2)
      }
    }
    .aspectRatio(cardAspectRatio, contentMode: .fit)
  }

  // Formats the notebook count label.
  private var notebookCountLabel: String {
    if folder.notebookCount == 1 {
      return "1 notebook"
    } else {
      return "\(folder.notebookCount) notebooks"
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

  // Draws a 2x2 grid of notebook thumbnails inside the folder card.
  @ViewBuilder
  private func thumbnailGrid(size: CGSize, cornerRadius: CGFloat) -> some View {
    let padding: CGFloat = 6
    let spacing: CGFloat = 3
    let thumbnailCornerRadius: CGFloat = 4

    // Calculates the size of each thumbnail cell.
    // Uses the smaller dimension to make cells more square.
    let maxCellWidth = (size.width - padding * 2 - spacing) / 2
    let maxCellHeight = (size.height - padding * 2 - spacing) / 2
    let cellSize = min(maxCellWidth, maxCellHeight)

    // Limits displayed cells to actual notebook count (max 4).
    let displayCount = min(folder.notebookCount, 4)

    // Grid of notebook thumbnails. Always maintains 2x2 structure with invisible
    // spacers for empty positions to keep cells anchored in their corners.
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
  // Shows the actual preview image if available, a notebook icon placeholder
  // for notebooks without preview images, or an invisible spacer if not visible.
  @ViewBuilder
  private func thumbnailCell(
    index: Int, size: CGFloat, cornerRadius: CGFloat, visible: Bool
  ) -> some View {
    if !visible {
      // Invisible spacer to maintain grid structure.
      Color.clear
        .frame(width: size, height: size)
    } else if index < thumbnails.count {
      // Shows the notebook preview image with stronger shadow for depth.
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

// Button wrapper for folder cards with press effects matching notebook cards.
struct FolderCardButton: View {
  let folder: FolderMetadata
  let thumbnails: [UIImage]
  let action: () -> Void

  // Drives a highlight flash on long press.
  @State private var showHighlight = false
  // Moves a bright sweep across the card on long press.
  @State private var sweepOffset: CGFloat = -1.2
  // Tracks the pending sweep animation work item so it can be cancelled on tap.
  @State private var sweepWorkItem: DispatchWorkItem?

  var body: some View {
    let cardCornerRadius: CGFloat = 10

    Button(action: action) {
      FolderCard(folder: folder, thumbnails: thumbnails)
        .contentShape(Rectangle())
    }
    // Uses custom button style for scale effect. This allows ScrollView to properly
    // intercept scroll gestures, unlike DragGesture which blocks scrolling.
    .buttonStyle(ScalingCardButtonStyle())
    // Adds a highlight sweep on long press.
    .overlay(
      GeometryReader { proxy in
        let sweepDistance = proxy.size.width * 1.2
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
        // Keeps the sweep confined to this card only.
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        // Allows touch events to pass through to the button underneath.
        .allowsHitTesting(false)
      }
    )
    // Triggers sweep animation on long press. Uses pressing callback with a delay
    // so taps don't trigger the sweep - only sustained presses do.
    .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
      if pressing {
        // Schedule sweep animation after a delay. If user lifts finger before
        // the delay (a tap), the work item is cancelled and sweep doesn't play.
        let workItem = DispatchWorkItem {
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
      } else {
        // User lifted finger - cancel pending sweep if it hasn't fired yet.
        sweepWorkItem?.cancel()
        sweepWorkItem = nil
      }
    }, perform: {
      // Empty perform - context menu handles the actual action.
    })
  }
}

// MARK: - Folder Card Context Menu Preview

// Standalone preview view for context menus that shows only the folder card without title.
// Used with .contextMenu(menuItems:preview:) to keep the title visible in place
// while lifting just the card as the preview.
struct FolderCardContextMenuPreview: View {
  let folder: FolderMetadata
  let thumbnails: [UIImage]

  var body: some View {
    let cardCornerRadius: CGFloat = 10
    let cardSize = CGSize(width: 160, height: 200)

    ZStack {
      glassContent(cornerRadius: cardCornerRadius)
      thumbnailGrid(size: cardSize, cornerRadius: cardCornerRadius)
    }
    .frame(width: cardSize.width, height: cardSize.height)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
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

  // Draws a 2x2 grid of notebook thumbnails.
  @ViewBuilder
  private func thumbnailGrid(size: CGSize, cornerRadius: CGFloat) -> some View {
    let padding: CGFloat = 6
    let spacing: CGFloat = 3
    let thumbnailCornerRadius: CGFloat = 4

    let maxCellWidth = (size.width - padding * 2 - spacing) / 2
    let maxCellHeight = (size.height - padding * 2 - spacing) / 2
    let cellSize = min(maxCellWidth, maxCellHeight)

    let displayCount = min(folder.notebookCount, 4)

    VStack(alignment: .leading, spacing: spacing) {
      HStack(spacing: spacing) {
        thumbnailCell(index: 0, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 0)
        thumbnailCell(index: 1, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 1)
      }
      HStack(spacing: spacing) {
        thumbnailCell(index: 2, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 2)
        thumbnailCell(index: 3, size: cellSize, cornerRadius: thumbnailCornerRadius, visible: displayCount > 3)
      }
    }
    .padding(padding)
  }

  // Draws a single thumbnail cell.
  @ViewBuilder
  private func thumbnailCell(index: Int, size: CGFloat, cornerRadius: CGFloat, visible: Bool) -> some View {
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
