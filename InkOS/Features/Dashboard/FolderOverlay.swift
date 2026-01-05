import SwiftUI
import UIKit

// swiftlint:disable file_length type_body_length
// File length exception justified: Cohesive folder overlay view with tightly coupled animation logic.
// Type body length exception justified: SwiftUI view with many computed subview properties for organization.

// MARK: - Animated Blur View

// UIViewRepresentable that wraps a UIVisualEffectView for smooth blur animation.
// Uses UIViewPropertyAnimator with CADisplayLink for smooth interpolation.
// Animates smoothly between clear (0) and fully blurred (1).
struct AnimatedBlurView: UIViewRepresentable {
  // Target blur intensity from 0 (clear) to 1 (full blur).
  let blurFraction: CGFloat
  // Duration for blur animation.
  let animationDuration: TimeInterval
  // Style of blur effect to use.
  let style: UIBlurEffect.Style

  init(
    blurFraction: CGFloat,
    animationDuration: TimeInterval = 0.35,
    style: UIBlurEffect.Style = .regular
  ) {
    self.blurFraction = blurFraction
    self.animationDuration = animationDuration
    self.style = style
  }

  func makeUIView(context: Context) -> UIVisualEffectView {
    let blurView = UIVisualEffectView(effect: nil)
    // Create an animator that applies blur when its fractionComplete increases.
    let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
      blurView.effect = UIBlurEffect(style: self.style)
    }
    animator.pausesOnCompletion = true
    animator.fractionComplete = 0
    context.coordinator.animator = animator
    context.coordinator.currentFraction = 0
    // Start animation to target if not zero.
    if blurFraction > 0 {
      context.coordinator.animateTo(blurFraction, duration: animationDuration)
    }
    return blurView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
    // Animate to new target fraction if different from current target.
    let target = blurFraction
    if abs(context.coordinator.targetFraction - target) > 0.001 {
      context.coordinator.animateTo(target, duration: animationDuration)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator {
    var animator: UIViewPropertyAnimator?
    var displayLink: CADisplayLink?
    var currentFraction: CGFloat = 0
    var targetFraction: CGFloat = 0
    var animationStartTime: CFTimeInterval = 0
    var animationStartFraction: CGFloat = 0
    var animationDuration: TimeInterval = 0.35

    // Starts a smooth animation from current fraction to target.
    func animateTo(_ target: CGFloat, duration: TimeInterval) {
      targetFraction = target
      animationStartFraction = currentFraction
      animationDuration = duration
      animationStartTime = CACurrentMediaTime()

      // Cancel existing display link.
      displayLink?.invalidate()

      // Create new display link for animation.
      let link = CADisplayLink(target: self, selector: #selector(updateAnimation))
      link.add(to: .main, forMode: .common)
      displayLink = link
    }

    @objc func updateAnimation() {
      let elapsed = CACurrentMediaTime() - animationStartTime
      var progress = min(1.0, elapsed / animationDuration)

      // Apply ease-out cubic for smooth deceleration.
      progress = easeOutCubic(progress)

      // Interpolate between start and target.
      let newFraction = animationStartFraction + (targetFraction - animationStartFraction) * progress
      currentFraction = newFraction
      animator?.fractionComplete = newFraction

      // Stop animation when complete.
      if progress >= 1.0 {
        displayLink?.invalidate()
        displayLink = nil
      }
    }

    // Ease out cubic for a smooth deceleration.
    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
      let adjusted = t - 1
      return adjusted * adjusted * adjusted + 1
    }

    deinit {
      displayLink?.invalidate()
      animator?.stopAnimation(true)
    }
  }
}

// Displays an expanded folder overlay with notebooks and PDFs inside.
// Uses scale-based animation: renders at full size but scales down to match source position.
// Content is always visible and scales naturally with the container.
struct FolderOverlay: View {
  let folder: FolderMetadata
  let notebooks: [NotebookMetadata]
  let pdfDocuments: [PDFDocumentMetadata]
  // The source card's frame in global coordinates (card portion only, no title).
  let sourceFrame: CGRect
  // Controls scale animation. When true, overlay is at full scale (1.0).
  let isExpanded: Bool
  let onNotebookTap: (NotebookMetadata) -> Void
  let onMoveToRoot: (NotebookMetadata) -> Void
  let onRenameNotebook: (NotebookMetadata, String) -> Void
  let onDeleteNotebook: (NotebookMetadata) -> Void
  let onPDFTap: (PDFDocumentMetadata) -> Void
  let onMovePDFToRoot: (PDFDocumentMetadata) -> Void
  let onRenamePDF: (PDFDocumentMetadata, String) -> Void
  let onDeletePDF: (PDFDocumentMetadata) -> Void
  let onDismiss: () -> Void

  // Drag callbacks for notebooks being dragged out of the folder.
  let onNotebookDragStart: ((NotebookMetadata, CGRect, CGPoint) -> Void)?
  let onNotebookDragMove: ((CGPoint) -> Void)?
  let onNotebookDragEnd: ((CGPoint) -> Void)?

  // Drag callbacks for PDFs being dragged out of the folder.
  let onPDFDragStart: ((PDFDocumentMetadata, CGRect, CGPoint) -> Void)?
  let onPDFDragMove: ((CGPoint) -> Void)?
  let onPDFDragEnd: ((CGPoint) -> Void)?

  // Called when a drag crosses outside the overlay bounds.
  let onDragExitedBounds: (() -> Void)?

  // When true, a drag from this overlay is active at the dashboard level.
  // Used to keep a tiny opacity during collapse so gestures continue receiving events.
  let isDragActiveFromOverlay: Bool

  // ID of the notebook currently being dragged from this overlay.
  // Used to hide the original card while dragging (so it appears to move, not duplicate).
  let draggedNotebookID: String?

  // ID of the PDF currently being dragged from this overlay.
  // Used to hide the original card while dragging (so it appears to move, not duplicate).
  let draggedPDFID: String?

  // State for notebook rename alert.
  @State private var renamingNotebook: NotebookMetadata?
  @State private var renameText: String = ""

  // State for notebook delete confirmation alert.
  @State private var deletingNotebook: NotebookMetadata?

  // State for PDF rename alert.
  @State private var renamingPDF: PDFDocumentMetadata?

  // State for PDF delete confirmation alert.
  @State private var deletingPDF: PDFDocumentMetadata?

  // State for context menu overlay.
  @State private var contextMenuState: ContextMenuState?

  // Tracks whether onDragExitedBounds has been fired for the current drag.
  // Prevents multiple firings during a single drag gesture.
  @State private var hasFiredBoundsExit = false

  // Stores the current overlay frame for bounds checking during drag.
  @State private var currentOverlayFrame: CGRect = .zero

  // Work item for delayed bounds exit callback.
  // When drag exits bounds, this schedules a callback after a short delay.
  // If the drag re-enters bounds before the delay, the work item is cancelled.
  @State private var boundsExitWorkItem: DispatchWorkItem?

  // Duration to wait before contracting the overlay after drag exits bounds.
  // Matches iOS behavior where there's a slight delay before UI collapses.
  private let boundsExitDelay: TimeInterval = 0.25

  // Animated blur fraction for smooth background blur transitions.
  // Driven by isExpanded state changes with spring animation.
  @State private var animatedBlurFraction: CGFloat = 0

  // Tracks whether the blur is expanding (true) or contracting (false).
  // Used to select appropriate animation duration.
  @State private var isBlurExpanding: Bool = false

  // Separate opacity state for the folder container.
  // Animates independently from scale/position with faster timing during contraction.
  @State private var containerOpacity: CGFloat = 0

  // Overlay sizing constants.
  private let overlayWidth: CGFloat = 280
  private let overlayCornerRadius: CGFloat = 24
  private let sourceCornerRadius: CGFloat = 10
  private let contentPadding: CGFloat = 16
  // Header height for animation. Matches padding + text + padding.
  private let headerHeight: CGFloat = 50

  var body: some View {
    GeometryReader { geometry in
      let screenBounds = geometry.frame(in: .global)
      // Calculate the expanded overlay frame (centered on screen).
      let expandedFrame = calculateExpandedFrame(in: screenBounds)

      // Calculate separate X and Y scale factors.
      // This allows the overlay to match the source's exact dimensions when collapsed,
      // then smoothly morph to rectangular shape while expanding.
      let scaleX = isExpanded ? 1.0 : sourceFrame.width / expandedFrame.width
      let scaleY = isExpanded ? 1.0 : sourceFrame.height / expandedFrame.height

      // Position: source center when collapsed, screen center when expanded.
      let positionX = isExpanded ? expandedFrame.midX : sourceFrame.midX
      let positionY = isExpanded ? expandedFrame.midY : sourceFrame.midY

      // Corner radius interpolation for visual effect.
      let currentCornerRadius = isExpanded ? overlayCornerRadius : sourceCornerRadius

      // Duration for blur animation: longer for expand, shorter for contract.
      let blurDuration: TimeInterval = isBlurExpanding ? 0.35 : 0.2

      ZStack {
        // Background blur: intensity animates with expansion state.
        // Hidden when drag is active so user can see dashboard drop targets.
        dismissBackground(blurFraction: animatedBlurFraction, animationDuration: blurDuration)

        // The folder container always rendered at full expanded size.
        // Uses separate X/Y scales to morph from source shape to overlay shape.
        // Fades out as it contracts so it crossfades with the folder card underneath.
        // Opacity uses a faster animation than scale during contraction for cleaner visual.
        folderContainer(cornerRadius: currentCornerRadius)
          .frame(width: expandedFrame.width, height: expandedFrame.height)
          .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
          .scaleEffect(x: scaleX, y: scaleY)
          .position(x: positionX, y: positionY)
          .shadow(
            color: Color.black.opacity(isExpanded ? 0.2 : 0.14),
            radius: isExpanded ? 16 : 7,
            x: 0,
            y: isExpanded ? 8 : 4
          )
          // When drag is active from this overlay, make it invisible but keep gestures working.
          // This allows the overlay to stay at scale 1.0 (valid coordinates) while hidden.
          // Opacity is driven by separate containerOpacity state for independent animation timing.
          .opacity(isDragActiveFromOverlay ? 0.001 : containerOpacity)
          // Scale and position animate with spring/easeOut timing.
          // Opacity is animated separately via withAnimation in onChange handlers
          // to avoid conflicting animation layers that cause ghost artifacts.
          .animation(
            isExpanded
              ? .spring(response: 0.38, dampingFraction: 0.86)
              : .easeOut(duration: 0.18),
            value: isExpanded
          )

        // Context menu overlay for long-pressed items.
        if let menuState = contextMenuState {
          ContextMenuOverlay(
            state: menuState,
            actions: buildContextMenuActions(for: menuState),
            onDismiss: {
              withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                contextMenuState = nil
              }
            }
          )
          .zIndex(200)
        }
      }
      .frame(width: screenBounds.width, height: screenBounds.height)
      .onAppear {
        // Initialize overlay frame for bounds checking during drag.
        currentOverlayFrame = expandedFrame
      }
      .onChange(of: expandedFrame) { _, newFrame in
        // Update stored frame for bounds checking during drag.
        currentOverlayFrame = newFrame
      }
      .onChange(of: isExpanded) { _, expanded in
        // Update blur fraction when expansion state changes.
        // AnimatedBlurView handles smooth animation internally.
        isBlurExpanding = expanded
        animatedBlurFraction = expanded ? 1 : 0
        // Animate container opacity in a separate transaction to avoid ghost artifacts.
        // Slower fade-in during expansion, smooth fade-out during contraction to match scale timing.
        withAnimation(expanded ? .easeOut(duration: 0.25) : .easeIn(duration: 0.18)) {
          containerOpacity = expanded ? 1 : 0
        }
      }
      .onChange(of: isDragActiveFromOverlay) { _, dragActive in
        // Hide blur and container when drag becomes active (fast contract animation).
        if dragActive {
          isBlurExpanding = false
          animatedBlurFraction = 0
          withAnimation(.linear(duration: 0.08)) {
            containerOpacity = 0
          }
        }
      }
    }
    .ignoresSafeArea()
    // Notebook rename alert.
    .alert(
      "Rename Notebook",
      isPresented: Binding(
        get: { renamingNotebook != nil },
        set: { if !$0 { renamingNotebook = nil } }
      )
    ) {
      TextField("Notebook name", text: $renameText)
      Button("Cancel", role: .cancel) {
        renamingNotebook = nil
      }
      Button("Rename") {
        let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
        if let notebook = renamingNotebook, !trimmedName.isEmpty {
          onRenameNotebook(notebook, trimmedName)
        }
        renamingNotebook = nil
      }
    } message: {
      Text("Enter a new name for this notebook.")
    }
    // Notebook delete confirmation alert.
    .alert(
      "Delete Notebook?",
      isPresented: Binding(
        get: { deletingNotebook != nil },
        set: { if !$0 { deletingNotebook = nil } }
      )
    ) {
      Button("Cancel", role: .cancel) {
        deletingNotebook = nil
      }
      Button("Delete", role: .destructive) {
        if let notebook = deletingNotebook {
          onDeleteNotebook(notebook)
        }
        deletingNotebook = nil
      }
    } message: {
      if let notebook = deletingNotebook {
        Text("\"\(notebook.displayName)\" will be permanently deleted. This cannot be undone.")
      }
    }
    // PDF rename alert.
    .alert(
      "Rename PDF",
      isPresented: Binding(
        get: { renamingPDF != nil },
        set: { if !$0 { renamingPDF = nil } }
      )
    ) {
      TextField("PDF name", text: $renameText)
      Button("Cancel", role: .cancel) {
        renamingPDF = nil
      }
      Button("Rename") {
        let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
        if let pdf = renamingPDF, !trimmedName.isEmpty {
          onRenamePDF(pdf, trimmedName)
        }
        renamingPDF = nil
      }
    } message: {
      Text("Enter a new name for this PDF.")
    }
    // PDF delete confirmation alert.
    .alert(
      "Delete PDF?",
      isPresented: Binding(
        get: { deletingPDF != nil },
        set: { if !$0 { deletingPDF = nil } }
      )
    ) {
      Button("Cancel", role: .cancel) {
        deletingPDF = nil
      }
      Button("Delete", role: .destructive) {
        if let pdf = deletingPDF {
          onDeletePDF(pdf)
        }
        deletingPDF = nil
      }
    } message: {
      if let pdf = deletingPDF {
        Text("\"\(pdf.displayName)\" will be permanently deleted. This cannot be undone.")
      }
    }
  }

  // Calculates the expanded overlay frame centered on screen.
  private func calculateExpandedFrame(in screenBounds: CGRect) -> CGRect {
    let gridSpacing: CGFloat = 10
    let cardAspectRatio: CGFloat = 0.72
    let columns = 2

    // Calculate card dimensions matching contentGrid calculations.
    let availableWidth = overlayWidth - contentPadding * 2 - gridSpacing * CGFloat(columns - 1)
    let cardWidth = availableWidth / CGFloat(columns)
    let cardHeight = cardWidth / cardAspectRatio

    // Calculate number of rows based on total items (notebooks + PDFs).
    let totalItems = notebooks.count + pdfDocuments.count
    let rows = max(1, (totalItems + columns - 1) / columns)

    // Calculate total grid height: rows of cards plus spacing between rows.
    let gridHeight = CGFloat(rows) * cardHeight + CGFloat(rows - 1) * gridSpacing

    // Total content height: header + top padding + grid + bottom padding.
    let contentHeight = headerHeight + 8 + gridHeight + contentPadding

    // Minimum height for empty state.
    let minHeight: CGFloat = headerHeight + 160 + contentPadding
    let isEmpty = notebooks.isEmpty && pdfDocuments.isEmpty
    let totalHeight = isEmpty ? minHeight : contentHeight

    return CGRect(
      x: (screenBounds.width - overlayWidth) / 2,
      y: (screenBounds.height - totalHeight) / 2,
      width: overlayWidth,
      height: totalHeight
    )
  }

  // Checks if a drag position is outside the overlay bounds.
  // If so, schedules the onDragExitedBounds callback after a short delay.
  // If the drag re-enters bounds before the delay, the callback is cancelled.
  private func checkDragBounds(position: CGPoint) {
    // Only check bounds if overlay is expanded, we haven't already exited,
    // and the frame has been properly initialized (not zero-sized).
    guard isExpanded,
          !hasFiredBoundsExit,
          currentOverlayFrame.width > 0,
          currentOverlayFrame.height > 0 else {
      return
    }
    let isOutside = !currentOverlayFrame.contains(position)
    if isOutside {
      // Schedule the bounds exit callback if not already scheduled.
      if boundsExitWorkItem == nil {
        let workItem = DispatchWorkItem { [onDragExitedBounds] in
          hasFiredBoundsExit = true
          onDragExitedBounds?()
        }
        boundsExitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + boundsExitDelay, execute: workItem)
      }
    } else {
      // Drag re-entered bounds, cancel the pending exit callback.
      boundsExitWorkItem?.cancel()
      boundsExitWorkItem = nil
    }
  }

  // Resets bounds tracking state when a new drag starts.
  private func resetBoundsTracking() {
    hasFiredBoundsExit = false
    boundsExitWorkItem?.cancel()
    boundsExitWorkItem = nil
  }

  // Background blur that dismisses the overlay when tapped.
  // Blur intensity animates smoothly with the overlay expansion/contraction.
  @ViewBuilder
  private func dismissBackground(blurFraction: CGFloat, animationDuration: TimeInterval) -> some View {
    AnimatedBlurView(
      blurFraction: blurFraction,
      animationDuration: animationDuration,
      style: .regular
    )
    .contentShape(Rectangle())
    .onTapGesture {
      onDismiss()
    }
  }

  // MARK: - Folder Container

  // The main folder container rendered at full expanded size.
  // Uses scale transform for animation, so layout remains constant throughout.
  // Shows snapshot during scale animation, then crossfades to actual content.
  @ViewBuilder
  private func folderContainer(cornerRadius: CGFloat) -> some View {
    ZStack(alignment: .top) {
      // Glass background.
      glassBackground(cornerRadius: cornerRadius)

      VStack(spacing: 0) {
        // Header with folder name.
        folderHeader

        // Content area containing snapshot (during animation) and content (after).
        contentArea
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }

  // Glass background that works with the current corner radius.
  @ViewBuilder
  private func glassBackground(cornerRadius: CGFloat) -> some View {
    if #available(iOS 26.0, *) {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color.clear)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    } else {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
    }
  }

  // MARK: - Folder Content

  // Folder header displayed above the notebook grid.
  // Always visible - scales naturally with the container during animation.
  private var folderHeader: some View {
    Text(folder.displayName)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(Color.ink)
      .lineLimit(1)
      .padding(.horizontal, contentPadding)
      .padding(.top, contentPadding)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: headerHeight, alignment: .top)
  }

  // Content area below the header containing notebooks and PDFs.
  // Always renders content - they scale naturally with the container.
  // No snapshot needed since scale animation doesn't clip content.
  private var contentArea: some View {
    GeometryReader { geo in
      if notebooks.isEmpty && pdfDocuments.isEmpty {
        emptyState
      } else {
        contentGrid(in: geo.size)
      }
    }
  }

  // Empty state when folder has no content.
  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(Color.inkFaint)

      Text("No items")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
    }
    .frame(height: 160)
    .frame(maxWidth: .infinity)
    .padding(.bottom, contentPadding)
  }

  // Grid of notebooks and PDFs inside the folder.
  // Calculates explicit card dimensions to prevent compression.
  private func contentGrid(in size: CGSize) -> some View {
    let columns = 2
    let totalItems = notebooks.count + pdfDocuments.count
    let rows = (totalItems + columns - 1) / columns
    let gridSpacing: CGFloat = 10
    let cardAspectRatio: CGFloat = 0.72

    // Calculate card width based on available space minus padding and spacing.
    let availableWidth = size.width - contentPadding * 2 - gridSpacing * CGFloat(columns - 1)
    let cardWidth = availableWidth / CGFloat(columns)
    // Card height from aspect ratio (includes title area).
    let cardHeight = cardWidth / cardAspectRatio

    // Combined items for unified grid layout.
    let allItems: [FolderItem] = notebooks.map { .notebook($0) } + pdfDocuments.map { .pdf($0) }

    return VStack(alignment: .leading, spacing: gridSpacing) {
      ForEach(0..<rows, id: \.self) { row in
        HStack(spacing: gridSpacing) {
          ForEach(0..<columns, id: \.self) { col in
            let index = row * columns + col
            if index < allItems.count {
              folderItemCard(allItems[index], cardWidth: cardWidth, cardHeight: cardHeight)
            } else {
              // Empty spacer for incomplete rows.
              Color.clear
                .frame(width: cardWidth, height: cardHeight)
            }
          }
        }
      }
    }
    .padding(.horizontal, contentPadding)
    .padding(.top, 8)
    .padding(.bottom, contentPadding)
  }

  // Renders a single item card (notebook or PDF) in the folder grid.
  @ViewBuilder
  private func folderItemCard(_ item: FolderItem, cardWidth: CGFloat, cardHeight: CGFloat)
    -> some View {
    switch item {
    case .notebook(let notebook):
      notebookItemCard(notebook: notebook, cardWidth: cardWidth, cardHeight: cardHeight)
    case .pdf(let pdf):
      pdfItemCard(pdf: pdf, cardWidth: cardWidth, cardHeight: cardHeight)
    }
  }

  // Renders a notebook card in the folder grid.
  // Uses FolderDraggableNotebookCard which leverages UIKit's UIDragInteraction
  // for accurate position tracking that's immune to parent view transforms.
  @ViewBuilder
  private func notebookItemCard(notebook: NotebookMetadata, cardWidth: CGFloat, cardHeight: CGFloat)
    -> some View {
    let isContextMenuActive = contextMenuState?.matchesNotebook(notebook) == true
    let isBeingDragged = draggedNotebookID == notebook.id

    FolderDraggableNotebookCard(
      notebook: notebook,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      onTap: {
        onNotebookTap(notebook)
      },
      onLongPress: { frame, previewHeight in
        // Dismiss any existing context menu and show new one.
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
          contextMenuState = ContextMenuState(
            item: .notebook(notebook),
            sourceFrame: frame,
            cardHeight: previewHeight
          )
        }
      },
      onDragStart: { draggedNotebook, frame, position in
        // Dismiss context menu when drag starts.
        withAnimation(.easeOut(duration: 0.15)) {
          contextMenuState = nil
        }
        // Reset bounds tracking for new drag and forward to parent.
        resetBoundsTracking()
        onNotebookDragStart?(draggedNotebook, frame, position)
      },
      onDragMove: { position in
        // Forward position and check if drag crossed overlay bounds.
        onNotebookDragMove?(position)
        checkDragBounds(position: position)
      },
      onDragEnd: { position in
        // Always call parent drag end so DashboardView can reset drag state.
        // DashboardView will check hasDragExitedOverlayBounds to decide whether to move.
        onNotebookDragEnd?(position)
      }
    )
    .scaleEffect(isContextMenuActive ? 1.08 : 1.0, anchor: .center)
    // Hide the card while it's being dragged (drag overlay shows the moving card).
    .opacity(isBeingDragged ? 0 : 1)
  }

  // Renders a PDF card in the folder grid.
  // Uses FolderDraggablePDFCard which leverages UIKit's UIDragInteraction
  // for accurate position tracking that's immune to parent view transforms.
  @ViewBuilder
  private func pdfItemCard(pdf: PDFDocumentMetadata, cardWidth: CGFloat, cardHeight: CGFloat)
    -> some View {
    let isContextMenuActive = contextMenuState?.matchesPDFDocument(pdf) == true
    let isBeingDragged = draggedPDFID == pdf.id

    FolderDraggablePDFCard(
      pdf: pdf,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      onTap: {
        onPDFTap(pdf)
      },
      onLongPress: { frame, previewHeight in
        // Dismiss any existing context menu and show new one.
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
          contextMenuState = ContextMenuState(
            item: .pdfDocument(pdf),
            sourceFrame: frame,
            cardHeight: previewHeight
          )
        }
      },
      onDragStart: { draggedPDF, frame, position in
        // Dismiss context menu when drag starts.
        withAnimation(.easeOut(duration: 0.15)) {
          contextMenuState = nil
        }
        // Reset bounds tracking for new drag and forward to parent.
        resetBoundsTracking()
        onPDFDragStart?(draggedPDF, frame, position)
      },
      onDragMove: { position in
        // Forward position and check if drag crossed overlay bounds.
        onPDFDragMove?(position)
        checkDragBounds(position: position)
      },
      onDragEnd: { position in
        // Always call parent drag end so DashboardView can reset drag state.
        // DashboardView will check hasDragExitedOverlayBounds to decide whether to move.
        onPDFDragEnd?(position)
      }
    )
    .scaleEffect(isContextMenuActive ? 1.08 : 1.0, anchor: .center)
    // Hide the card while it's being dragged (drag overlay shows the moving card).
    .opacity(isBeingDragged ? 0 : 1)
  }

  // MARK: - Context Menu Actions

  // Builds context menu actions for items inside the folder.
  private func buildContextMenuActions(for state: ContextMenuState) -> [ContextMenuAction] {
    switch state.item {
    case .notebook(let notebook):
      return [
        ContextMenuAction(title: "Rename", systemImage: "pencil") {
          renameText = notebook.displayName
          renamingNotebook = notebook
        },
        ContextMenuAction(title: "Move Out of Folder", systemImage: "folder.badge.minus") {
          onMoveToRoot(notebook)
        },
        ContextMenuAction(title: "Delete", systemImage: "trash", isDestructive: true) {
          deletingNotebook = notebook
        }
      ]

    case .pdfDocument(let pdf):
      return [
        ContextMenuAction(title: "Rename", systemImage: "pencil") {
          renameText = pdf.displayName
          renamingPDF = pdf
        },
        ContextMenuAction(title: "Move Out of Folder", systemImage: "folder.badge.minus") {
          onMovePDFToRoot(pdf)
        },
        ContextMenuAction(title: "Delete", systemImage: "trash", isDestructive: true) {
          deletingPDF = pdf
        }
      ]

    case .folder:
      // Folders inside folders not supported.
      return []
    }
  }
}

// Helper enum for unified folder item representation.
private enum FolderItem {
  case notebook(NotebookMetadata)
  case pdf(PDFDocumentMetadata)
}

// MARK: - Glass Overlay Background

// View modifier for the folder overlay glass effect.
extension View {
  func glassOverlayBackground(cornerRadius: CGFloat) -> some View {
    Group {
      if #available(iOS 26.0, *) {
        self
          .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(Color.clear)
              .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
          )
      } else {
        // Fallback for older iOS versions.
        self
          .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          )
      }
    }
  }
}
