import SwiftUI
import UIKit

// MARK: - Context Menu State

// Represents the active context menu state managed at the DashboardView level.
// Contains the item being context-menued and its source frame for positioning.
struct ContextMenuState {
  // The type of item being context-menued.
  enum ItemType {
    case notebook(NotebookMetadata)
    case folder(FolderMetadata, thumbnails: [UIImage])
    case pdfDocument(PDFDocumentMetadata)
    case lesson(LessonMetadata)
  }

  let item: ItemType
  // The source card's frame in global coordinates for positioning the lifted card.
  let sourceFrame: CGRect
  // The height of the card portion (without title area).
  let cardHeight: CGFloat

  // Checks if this state matches a specific notebook.
  func matchesNotebook(_ notebook: NotebookMetadata) -> Bool {
    if case .notebook(let notebookItem) = item {
      return notebookItem.id == notebook.id
    }
    return false
  }

  // Checks if this state matches a specific folder.
  func matchesFolder(_ folder: FolderMetadata) -> Bool {
    if case .folder(let folderItem, _) = item {
      return folderItem.id == folder.id
    }
    return false
  }

  // Checks if this state matches a specific PDF document.
  func matchesPDFDocument(_ pdfDocument: PDFDocumentMetadata) -> Bool {
    if case .pdfDocument(let pdfItem) = item {
      return pdfItem.id == pdfDocument.id
    }
    return false
  }

  // Checks if this state matches a specific lesson.
  func matchesLesson(_ lesson: LessonMetadata) -> Bool {
    if case .lesson(let lessonItem) = item {
      return lessonItem.id == lesson.id
    }
    return false
  }
}

// MARK: - Context Menu Overlay

// Custom context menu overlay that provides full control over animations.
// Replaces the UIKit-based context menu to avoid shadow snapping on dismiss.
struct ContextMenuOverlay: View {
  let state: ContextMenuState
  let actions: [ContextMenuAction]
  let onDismiss: () -> Void

  // Controls the animation state for all overlay components.
  @State private var isPresented = false

  // Menu panel styling.
  private let menuCornerRadius: CGFloat = 14
  private let menuWidth: CGFloat = 200

  var body: some View {
    GeometryReader { geometry in
      let safeAreaTop = geometry.safeAreaInsets.top

      ZStack {
        // Dismissal background - tap to close.
        // The original card is lifted above this via zIndex.
        dismissBackground

        // Floating menu panel positioned near the source card.
        menuPanel(safeAreaTop: safeAreaTop)
      }
    }
    .ignoresSafeArea()
    .onAppear {
      // Trigger haptic feedback when menu appears.
      let generator = UIImpactFeedbackGenerator(style: .medium)
      generator.impactOccurred()

      // Animate menu panel in.
      withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
        isPresented = true
      }
    }
  }

  // MARK: - Dismiss Background

  // Transparent tap target that dismisses the menu when tapped outside.
  // No dim effect to avoid dimming the card which can't escape its container's z-order.
  private var dismissBackground: some View {
    Color.clear
      .contentShape(Rectangle())
      .ignoresSafeArea()
      .onTapGesture {
        dismiss()
      }
  }

  // MARK: - Menu Panel

  // Floating menu positioned near the lifted card.
  // The safeAreaTop offset accounts for global frame coordinates in the safe-area-ignoring overlay.
  private func menuPanel(safeAreaTop: CGFloat) -> some View {
    let screenBounds = UIScreen.main.bounds
    let estimatedMenuHeight = CGFloat(actions.count) * 44 + 16

    // Calculate position: prefer below card, but above if near bottom.
    let spaceBelow = screenBounds.maxY - state.sourceFrame.maxY - 40
    let preferBelow = spaceBelow > estimatedMenuHeight + 20

    // Adjust Y positions by subtracting safe area offset.
    let menuY: CGFloat
    if preferBelow {
      menuY = state.sourceFrame.maxY + 16 + estimatedMenuHeight / 2 - safeAreaTop
    } else {
      menuY = state.sourceFrame.minY - 16 - estimatedMenuHeight / 2 - safeAreaTop
    }

    // Horizontal: align with card center but stay within bounds.
    let menuX = min(
      max(menuWidth / 2 + 16, state.sourceFrame.midX),
      screenBounds.maxX - menuWidth / 2 - 16
    )

    return ContextMenuPanel(actions: actions, onAction: handleAction)
      .frame(width: menuWidth)
      .position(x: menuX, y: menuY)
      .opacity(isPresented ? 1 : 0)
      .scaleEffect(isPresented ? 1 : 0.85)
      .animation(
        .spring(response: 0.22, dampingFraction: 0.78).delay(0.03),
        value: isPresented
      )
  }

  // MARK: - Actions

  // Handles menu item selection.
  private func handleAction(_ action: ContextMenuAction) {
    // Animate menu out.
    withAnimation(.easeOut(duration: 0.2)) {
      isPresented = false
    }

    // Execute action and dismiss immediately.
    action.handler()
    onDismiss()
  }

  // Dismisses the overlay without executing an action.
  private func dismiss() {
    withAnimation(.easeOut(duration: 0.2)) {
      isPresented = false
    }

    // Dismiss immediately - the card animates via its own animation modifier.
    onDismiss()
  }
}

// MARK: - Context Menu Panel

// The floating menu panel containing action buttons.
struct ContextMenuPanel: View {
  let actions: [ContextMenuAction]
  let onAction: (ContextMenuAction) -> Void

  private let cornerRadius: CGFloat = 14

  var body: some View {
    VStack(spacing: 0) {
      ForEach(actions) { action in
        Button {
          onAction(action)
        } label: {
          HStack(spacing: 12) {
            Image(systemName: action.systemImage)
              .font(.system(size: 16, weight: .medium))
              .frame(width: 20)

            Text(action.title)
              .font(.system(size: 15, weight: .medium))

            Spacer()
          }
          .foregroundStyle(action.isDestructive ? Color.red : Color.ink)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .glassOverlayBackground(cornerRadius: cornerRadius)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
  }
}
