import SwiftUI
import UIKit

// MARK: - Folder Draggable Notebook Card

// A notebook card designed for use inside folder overlays.
// Uses UIKit touch handling for position tracking, which reports positions in
// window coordinates. This makes drag position immune to parent view transforms
// like the folder overlay's scale/position animations.
// Implements the same gesture flow as dashboard cards:
// - Touch down → dim feedback
// - 0.3s hold → context menu with sweep animation
// - Movement after context menu → drag mode
// - Short tap → open notebook
struct FolderDraggableNotebookCard: View {
  let notebook: NotebookMetadata
  let cardWidth: CGFloat
  let cardHeight: CGFloat
  let onTap: () -> Void
  let onLongPress: (CGRect, CGFloat) -> Void
  let onDragStart: (NotebookMetadata, CGRect, CGPoint) -> Void
  let onDragMove: (CGPoint) -> Void
  let onDragEnd: (CGPoint) -> Void

  @State private var dimOpacity: Double = 0
  @State private var showHighlight = false
  @State private var sweepOffset: CGFloat = -1.2
  @State private var cardFrame: CGRect = .zero
  @State private var isDragging = false

  // CONSISTENCY: These values must match all card types
  private let cardCornerRadius: CGFloat = 10
  private let titleAreaHeight: CGFloat = 36

  var body: some View {
    UIKitDragWrapper(
      content: cardContent,
      onTouchDown: {
        // Dim immediately on touch down.
        // CONSISTENCY: Dim timing and opacity must match all card types
        withAnimation(.easeOut(duration: 0.06)) {
          dimOpacity = 0.12
        }
      },
      onTouchUp: {
        // Touch ended without drag - reset dim.
        withAnimation(.easeOut(duration: 0.25)) {
          dimOpacity = 0
        }
      },
      onLongPress: { frame in
        // Long press triggered - show context menu and sweep animation.
        cardFrame = frame
        withAnimation(.easeOut(duration: 0.2)) {
          dimOpacity = 0
        }
        triggerContextMenu()
      },
      onDragStart: { frame, position in
        // Drag started after long press.
        isDragging = true
        cardFrame = frame
        onDragStart(notebook, frame, position)
      },
      onDragMove: { position in
        onDragMove(position)
      },
      onDragEnd: { position in
        isDragging = false
        withAnimation(.easeOut(duration: 0.25)) {
          dimOpacity = 0
        }
        onDragEnd(position)
      },
      onTap: {
        // Short tap - reset dim and trigger action.
        withAnimation(.easeOut(duration: 0.25)) {
          dimOpacity = 0
        }
        onTap()
      }
    )
    .frame(width: cardWidth, height: cardHeight)
  }

  // The visual card content.
  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Card preview with press feedback.
      cardPreview
        .frame(width: cardWidth, height: cardHeight - titleAreaHeight)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
        .overlay(sweepOverlay)
        // Scale up slightly when pressed (before drag starts).
        // CONSISTENCY: Press scale (1.04) must match all card types
        .scaleEffect(dimOpacity > 0 && !isDragging ? 1.04 : 1.0)
        // CONSISTENCY: Press animation must match all card types
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: dimOpacity > 0 && !isDragging)

      // Title below the card.
      NotebookCardTitle(notebook: notebook)
    }
  }

  // The notebook preview image with dim overlay.
  private var cardPreview: some View {
    NotebookCardPreview(notebook: notebook, dimOpacity: dimOpacity)
  }

  // Sweep highlight overlay for long press feedback.
  private var sweepOverlay: some View {
    let previewHeight = cardHeight - titleAreaHeight
    let sweepDistance = cardWidth * 1.2

    return ZStack {
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
    .frame(width: cardWidth, height: previewHeight)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    .allowsHitTesting(false)
  }

  // Triggers context menu display and sweep animation.
  private func triggerContextMenu() {
    let previewHeight = cardHeight - titleAreaHeight
    onLongPress(cardFrame, previewHeight)

    // Play sweep animation.
    showHighlight = true
    sweepOffset = -1.2
    withAnimation(.easeOut(duration: 0.5)) {
      sweepOffset = 1.2
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      showHighlight = false
    }
  }
}

// MARK: - Folder Draggable PDF Card

// A PDF card designed for use inside folder overlays.
// Uses UIKit touch handling for accurate position tracking during drag.
// Implements the same gesture flow as dashboard cards.
struct FolderDraggablePDFCard: View {
  let pdf: PDFDocumentMetadata
  let cardWidth: CGFloat
  let cardHeight: CGFloat
  let onTap: () -> Void
  let onLongPress: (CGRect, CGFloat) -> Void
  let onDragStart: (PDFDocumentMetadata, CGRect, CGPoint) -> Void
  let onDragMove: (CGPoint) -> Void
  let onDragEnd: (CGPoint) -> Void

  @State private var dimOpacity: Double = 0
  @State private var showHighlight = false
  @State private var sweepOffset: CGFloat = -1.2
  @State private var cardFrame: CGRect = .zero
  @State private var isDragging = false

  // CONSISTENCY: These values must match all card types
  private let cardCornerRadius: CGFloat = 10
  private let titleAreaHeight: CGFloat = 36

  var body: some View {
    UIKitDragWrapper(
      content: cardContent,
      onTouchDown: {
        // Dim immediately on touch down.
        // CONSISTENCY: Dim timing and opacity must match all card types
        withAnimation(.easeOut(duration: 0.06)) {
          dimOpacity = 0.12
        }
      },
      onTouchUp: {
        // Touch ended without drag - reset dim.
        withAnimation(.easeOut(duration: 0.25)) {
          dimOpacity = 0
        }
      },
      onLongPress: { frame in
        // Long press triggered - show context menu and sweep animation.
        cardFrame = frame
        withAnimation(.easeOut(duration: 0.2)) {
          dimOpacity = 0
        }
        triggerContextMenu()
      },
      onDragStart: { frame, position in
        // Drag started after long press.
        isDragging = true
        cardFrame = frame
        onDragStart(pdf, frame, position)
      },
      onDragMove: { position in
        onDragMove(position)
      },
      onDragEnd: { position in
        isDragging = false
        withAnimation(.easeOut(duration: 0.25)) {
          dimOpacity = 0
        }
        onDragEnd(position)
      },
      onTap: {
        // Short tap - reset dim and trigger action.
        withAnimation(.easeOut(duration: 0.25)) {
          dimOpacity = 0
        }
        onTap()
      }
    )
    .frame(width: cardWidth, height: cardHeight)
  }

  // The visual card content.
  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Card preview with press feedback.
      cardPreview
        .frame(width: cardWidth, height: cardHeight - titleAreaHeight)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
        .overlay(sweepOverlay)
        // Scale up slightly when pressed (before drag starts).
        // CONSISTENCY: Press scale (1.04) must match all card types
        .scaleEffect(dimOpacity > 0 && !isDragging ? 1.04 : 1.0)
        // CONSISTENCY: Press animation must match all card types
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: dimOpacity > 0 && !isDragging)

      // Title below the card.
      PDFDocumentCardTitle(metadata: pdf)
    }
  }

  // The PDF preview image with dim overlay.
  private var cardPreview: some View {
    PDFDocumentCardPreview(metadata: pdf, dimOpacity: dimOpacity)
  }

  // Sweep highlight overlay for long press feedback.
  private var sweepOverlay: some View {
    let previewHeight = cardHeight - titleAreaHeight
    let sweepDistance = cardWidth * 1.2

    return ZStack {
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
    .frame(width: cardWidth, height: previewHeight)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    .allowsHitTesting(false)
  }

  // Triggers context menu display and sweep animation.
  private func triggerContextMenu() {
    let previewHeight = cardHeight - titleAreaHeight
    onLongPress(cardFrame, previewHeight)

    // Play sweep animation.
    showHighlight = true
    sweepOffset = -1.2
    withAnimation(.easeOut(duration: 0.5)) {
      sweepOffset = 1.2
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      showHighlight = false
    }
  }
}
