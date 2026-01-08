// Reusable UI components for dashboard cards.
// These components are shared across notebook, PDF, and folder cards.

import SwiftUI
import UIKit

// MARK: - Sweep Animation Overlay

// Animated sweep highlight that plays on long press.
// Shows a white gradient that sweeps across the card.
struct SweepAnimationOverlay: View {
  // Whether the sweep animation is currently active.
  let isActive: Bool
  // Current sweep position (-1.2 to 1.2, where 0 is center).
  let sweepOffset: CGFloat
  // Corner radius to match the card shape.
  var cornerRadius: CGFloat = CardConstants.cornerRadius

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      let sweepDistance = width * 1.2

      ZStack {
        // Flash highlight that appears briefly.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.white.opacity(isActive ? CardConstants.Sweep.highlightOpacity : 0.0))
          .blendMode(.screen)
          .animation(.easeOut(duration: CardConstants.Sweep.highlightFlashDuration), value: isActive)

        // Sweep gradient that moves across the card.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(
            LinearGradient(
              stops: CardConstants.Sweep.gradientStops,
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .blendMode(.screen)
          .offset(x: sweepOffset * sweepDistance)
          .opacity(isActive ? 1.0 : 0.0)
      }
      .frame(width: width, height: height)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .allowsHitTesting(false)
    }
  }
}

// MARK: - Card Title

// Displays the card title and subtitle.
// Used below the card preview, outside the context menu scope.
struct CardTitle: View {
  // Title text (e.g., notebook name).
  let title: String
  // Subtitle text (e.g., date or page count). Nil hides the subtitle.
  let subtitle: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.ink)
        .lineLimit(1)
        .truncationMode(.tail)

      if let subtitle {
        Text(subtitle)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.inkSubtle)
          .lineLimit(1)
          .truncationMode(.tail)
      }
    }
    .padding(.horizontal, 2)
  }
}

// Convenience initializer for CardPresentable items.
extension CardTitle {
  init<Item: CardPresentable>(item: Item) {
    self.title = item.displayName
    self.subtitle = item.subtitle
  }
}

// MARK: - Card Preview Image

// Displays the card preview image with optional placeholder and dim overlay.
// Handles both notebooks (no placeholder) and PDFs (document icon placeholder).
struct CardPreviewImage<Item: CardPresentable>: View {
  let item: Item
  // Opacity of darkening overlay for press feedback.
  var dimOpacity: Double = 0

  var body: some View {
    let previewImage = item.previewImageData.flatMap { UIImage(data: $0) }

    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height

      ZStack {
        // Background color.
        item.cardBackgroundColor

        // Preview image or placeholder.
        if let previewImage {
          // For notebooks, apply edge inset to crop canvas artifact.
          // For PDFs, no inset needed.
          let needsInset = item.placeholderIcon == nil
          let inset = needsInset ? CardConstants.previewEdgeInset : 0

          Image(uiImage: previewImage)
            .resizable()
            .scaledToFill()
            .frame(width: width + inset, height: height)
            .frame(width: width, height: height, alignment: .topLeading)
            .clipped()
        } else if let iconName = item.placeholderIcon {
          // Placeholder icon for items without preview (e.g., PDFs).
          Image(systemName: iconName)
            .font(.system(size: 32))
            .foregroundColor(.accentColor)
        }
        // Items without preview and no placeholder show solid background color.

        // Darkening overlay for press feedback.
        Color.black.opacity(dimOpacity)
          .allowsHitTesting(false)
      }
    }
  }
}

// MARK: - Card Context Menu Preview

// Standalone preview view for context menus.
// Shows just the card portion without the title.
struct CardContextMenuPreview<Item: CardPresentable>: View {
  let item: Item

  var body: some View {
    let previewImage = item.previewImageData.flatMap { UIImage(data: $0) }
    let width = CardConstants.contextMenuPreviewWidth
    let height = CardConstants.contextMenuPreviewHeight
    let needsInset = item.placeholderIcon == nil
    let inset = needsInset ? CardConstants.previewEdgeInset : 0

    ZStack {
      item.cardBackgroundColor

      if let previewImage {
        Image(uiImage: previewImage)
          .resizable()
          .scaledToFill()
          .frame(width: width + inset, height: height)
          .frame(width: width, height: height, alignment: needsInset ? .leading : .center)
          .clipped()
      } else if let iconName = item.placeholderIcon {
        Image(systemName: iconName)
          .font(.system(size: 48))
          .foregroundColor(.accentColor)
      }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: CardConstants.cornerRadius, style: .continuous))
    .shadow(
      color: CardConstants.Shadow.color,
      radius: CardConstants.Shadow.radius,
      x: CardConstants.Shadow.xOffset,
      y: CardConstants.Shadow.yOffset
    )
  }
}

// MARK: - Card Shadow Modifier

// View modifier for applying consistent card shadow styling.
struct CardShadowModifier: ViewModifier {
  func body(content: Content) -> some View {
    content.shadow(
      color: CardConstants.Shadow.color,
      radius: CardConstants.Shadow.radius,
      x: CardConstants.Shadow.xOffset,
      y: CardConstants.Shadow.yOffset
    )
  }
}

extension View {
  // Applies the standard card shadow.
  func cardShadow() -> some View {
    modifier(CardShadowModifier())
  }
}

// MARK: - Card Shape

// Returns the standard card shape with correct corner radius.
func cardShape() -> RoundedRectangle {
  RoundedRectangle(cornerRadius: CardConstants.cornerRadius, style: .continuous)
}
