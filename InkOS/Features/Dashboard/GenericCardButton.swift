// Generic interactive card button for dashboard items.
// Consolidates gesture handling, press feedback, and drag behavior
// shared between notebook and PDF cards.

import SwiftUI

// MARK: - Generic Card Button

// Interactive container for a card with tactile press effects.
// The card portion has drag behavior; the title is a sibling
// that animates together but stays outside the context menu highlight.
struct GenericCardButton<Item: CardPresentable>: View {
  let item: Item
  let action: () -> Void
  // Long press callback for custom context menu. Passes the card frame and card height.
  let onLongPress: ((CGRect, CGFloat) -> Void)?
  // Callback when drag starts after long press. Passes item, card frame, and initial touch position.
  let onDragStart: ((Item, CGRect, CGPoint) -> Void)?
  // Callback during drag. Passes current touch position.
  let onDragMove: ((CGPoint) -> Void)?
  // Callback when drag ends. Passes final touch position.
  let onDragEnd: ((CGPoint) -> Void)?
  // Opacity for the title/date label. Allows parent to fade the title when targeted.
  var titleOpacity: Double = 1.0

  // Controls the darkening overlay opacity on the card.
  @State private var dimOpacity: Double = 0
  // Drives a highlight flash on long press.
  @State private var showHighlight = false
  // Moves a bright sweep across the card on long press.
  @State private var sweepOffset: CGFloat = CardConstants.Sweep.offsetStart
  // Tracks the pending sweep animation work item so it can be cancelled on tap.
  @State private var sweepWorkItem: DispatchWorkItem?
  // Tracks the card's global frame for context menu positioning.
  @State private var cardFrame: CGRect = .zero
  // Tracks whether the context menu was triggered to prevent button action on release.
  @State private var didTriggerContextMenu = false
  // Tracks whether the gesture has transitioned to drag mode.
  @State private var isDragging = false
  // Tracks the starting position of the touch for drag threshold detection.
  @State private var touchStartPosition: CGPoint = .zero
  // Stores the global position when drag started. Used with translation to calculate
  // current position, which is immune to parent scale transforms.
  @State private var dragStartGlobalPosition: CGPoint = .zero

  var body: some View {
    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - CardConstants.titleAreaHeight

      VStack(alignment: .leading, spacing: 4) {
        // The card portion.
        cardView(width: totalWidth, height: cardHeight)

        // Title and subtitle below the card. Opacity controlled by parent for fade effects.
        CardTitle(item: item)
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
    .aspectRatio(CardConstants.aspectRatio, contentMode: .fit)
    // Combined gesture for press, long press, and drag after long press.
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

  // Builds the card view (no separate tap gesture, handled by the main gesture).
  @ViewBuilder
  private func cardView(width: CGFloat, height: CGFloat) -> some View {
    let shape = cardShape()

    CardPreviewImage(item: item, dimOpacity: dimOpacity)
      .frame(width: width, height: height)
      .clipShape(shape)
      .cardShadow()
      .overlay(
        SweepAnimationOverlay(isActive: showHighlight, sweepOffset: sweepOffset)
          .frame(width: width, height: height)
      )
      .contentShape(shape)
      // Scale up slightly when pressed (before drag starts).
      .scaleEffect(dimOpacity > 0 && !isDragging ? CardConstants.Press.scale : 1.0)
      .animation(
        .spring(response: CardConstants.Press.springResponse, dampingFraction: CardConstants.Press.springDamping),
        value: dimOpacity > 0 && !isDragging
      )
  }

  // Handles gesture changes (touch down, movement).
  private func handleGestureChange(_ value: DragGesture.Value) {
    let currentPosition = value.location

    // First touch: initialize state.
    if touchStartPosition == .zero {
      touchStartPosition = value.startLocation
      didTriggerContextMenu = false
      isDragging = false

      // Dim immediately on touch down.
      withAnimation(.easeOut(duration: CardConstants.Press.dimDuration)) {
        dimOpacity = CardConstants.Press.dimOpacity
      }

      // Schedule context menu and sweep animation after a delay.
      let currentFrame = cardFrame
      let cardHeight = currentFrame.height - CardConstants.titleAreaHeight
      let workItem = DispatchWorkItem { [onLongPress] in
        // Mark that context menu was triggered to prevent button action on release.
        didTriggerContextMenu = true

        // Fade out the dim overlay now that context menu is triggering.
        withAnimation(.easeOut(duration: 0.2)) {
          dimOpacity = 0
        }

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
      return
    }

    // After context menu has triggered, check for drag initiation.
    if didTriggerContextMenu && !isDragging {
      let distance = hypot(
        currentPosition.x - touchStartPosition.x,
        currentPosition.y - touchStartPosition.y
      )
      if distance > CardConstants.dragThreshold {
        // Transition to drag mode.
        isDragging = true
        // Convert local position to global position for drag start.
        // This position is captured when the parent (e.g., folder overlay) is at scale 1.0.
        let globalPosition = CGPoint(
          x: cardFrame.minX + currentPosition.x,
          y: cardFrame.minY + currentPosition.y
        )
        dragStartGlobalPosition = globalPosition
        onDragStart?(item, cardFrame, globalPosition)
      }
    }

    // During drag, report position updates using initial position + translation.
    // This approach is immune to parent scale transforms (e.g., folder overlay collapsing).
    if isDragging {
      let globalPosition = CGPoint(
        x: dragStartGlobalPosition.x + value.translation.width,
        y: dragStartGlobalPosition.y + value.translation.height
      )
      onDragMove?(globalPosition)
    }
  }

  // Handles gesture end (touch up).
  private func handleGestureEnd(_ value: DragGesture.Value) {
    // Cancel pending sweep if it hasn't fired yet.
    sweepWorkItem?.cancel()
    sweepWorkItem = nil

    if isDragging {
      // End drag mode and report final position using initial position + translation.
      let globalPosition = CGPoint(
        x: dragStartGlobalPosition.x + value.translation.width,
        y: dragStartGlobalPosition.y + value.translation.height
      )
      onDragEnd?(globalPosition)
    } else if !didTriggerContextMenu {
      // Short tap without context menu: trigger action.
      action()
    }

    // Reset state.
    withAnimation(.easeOut(duration: CardConstants.Press.dimFadeOutDuration)) {
      dimOpacity = 0
    }
    touchStartPosition = .zero
    dragStartGlobalPosition = .zero
    isDragging = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      didTriggerContextMenu = false
    }
  }
}

// MARK: - Type Aliases for Backward Compatibility

// These type aliases allow existing code to continue using the original type names.
// They also provide a migration path if we need to add type-specific behavior later.

// Notebook card button using the generic implementation.
typealias NotebookCardButtonGeneric = GenericCardButton<NotebookMetadata>

// PDF document card button using the generic implementation.
typealias PDFDocumentCardButtonGeneric = GenericCardButton<PDFDocumentMetadata>
