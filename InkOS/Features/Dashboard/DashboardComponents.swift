// swiftlint:disable file_length
// This file contains all dashboard card components (notebook and PDF) to maintain UI consistency.
// Keeping these components together ensures unified styling, animations, and behavior across the dashboard.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - PDF Dashboard Error

// Errors specific to PDF dashboard operations.
// Provides specific cases for different failure modes.
enum PDFDashboardError: LocalizedError, Equatable {
  // The PDFNotes directory could not be accessed.
  case pdfNotesDirectoryNotAccessible(underlyingError: String)

  // A specific document manifest could not be read.
  case manifestReadFailed(documentID: String, reason: String)

  // A specific document manifest could not be decoded.
  case manifestDecodeFailed(documentID: String, reason: String)

  var errorDescription: String? {
    switch self {
    case .pdfNotesDirectoryNotAccessible(let underlyingError):
      return "Could not access PDF documents directory: \(underlyingError)"
    case .manifestReadFailed(let documentID, let reason):
      return "Could not read document \(documentID): \(reason)"
    case .manifestDecodeFailed(let documentID, let reason):
      return "Could not decode document \(documentID): \(reason)"
    }
  }
}

// MARK: - PDF Document Metadata

// Lightweight struct for displaying PDF documents in the Dashboard grid.
// Contains only the information needed for listing and sorting, not editing.
// Mirrors NotebookMetadata pattern for consistency.
struct PDFDocumentMetadata: Identifiable, Sendable, Equatable {
  // Unique identifier for this PDF document.
  let id: String

  // Display name shown to the user.
  let displayName: String

  // Original filename of the imported PDF including extension.
  let sourceFileName: String

  // Timestamp when the document was created from the PDF.
  let createdAt: Date

  // Timestamp when the document was last modified.
  let modifiedAt: Date

  // Total number of pages in the PDF document.
  let pageCount: Int

  // Cached preview image data for the first page of the PDF.
  let previewImageData: Data?

  // Optional folder ID if the document is inside a folder.
  // Nil means the document is at the root level.
  let folderID: String?
}

// Utility for building PDFDocumentMetadata from NoteDocument.
enum PDFDocumentMetadataBuilder {
  // Builds PDFDocumentMetadata from a NoteDocument and optional preview data.
  static func build(
    from document: NoteDocument,
    previewImageData: Data?
  ) -> PDFDocumentMetadata {
    let pageCount = document.blocks.filter { block in
      if case .pdfPage = block { return true }
      return false
    }.count

    return PDFDocumentMetadata(
      id: document.documentID.uuidString,
      displayName: document.displayName,
      sourceFileName: document.sourceFileName,
      createdAt: document.createdAt,
      modifiedAt: document.modifiedAt,
      pageCount: pageCount,
      previewImageData: previewImageData,
      folderID: document.folderID
    )
  }
}

// MARK: - Notebook Session

// Represents an open notebook editing session.
struct NotebookSession: Identifiable {
  let id: String
  let handle: DocumentHandle
}

// MARK: - Notebook Card Button

// Interactive container for a notebook card with tactile press effects.
// The card portion has drag behavior; the title is a sibling
// that animates together but stays outside the context menu highlight.
struct NotebookCardButton: View {
  let notebook: NotebookMetadata
  let action: () -> Void
  // Context menu actions passed in from the parent view.
  let onRename: () -> Void
  let onMoveToFolder: (() -> Void)?
  let onMoveOutOfFolder: (() -> Void)?
  let onDelete: () -> Void
  // Long press callback for custom context menu. Passes the card frame and card height.
  let onLongPress: ((CGRect, CGFloat) -> Void)?
  // Callback when drag starts after long press. Passes notebook, card frame, and initial touch position.
  let onDragStart: ((NotebookMetadata, CGRect, CGPoint) -> Void)?
  // Callback during drag. Passes current touch position.
  let onDragMove: ((CGPoint) -> Void)?
  // Callback when drag ends. Passes final touch position.
  let onDragEnd: ((CGPoint) -> Void)?
  // Opacity for the title/date label. Allows parent to fade the title when targeted.
  var titleOpacity: Double = 1.0

  // Convenience initializer for dashboard use (move to folder).
  init(
    notebook: NotebookMetadata,
    action: @escaping () -> Void,
    onRename: @escaping () -> Void,
    onMoveToFolder: (() -> Void)?,
    onDelete: @escaping () -> Void,
    onLongPress: ((CGRect, CGFloat) -> Void)? = nil,
    onDragStart: ((NotebookMetadata, CGRect, CGPoint) -> Void)? = nil,
    onDragMove: ((CGPoint) -> Void)? = nil,
    onDragEnd: ((CGPoint) -> Void)? = nil,
    titleOpacity: Double = 1.0
  ) {
    self.notebook = notebook
    self.action = action
    self.onRename = onRename
    self.onMoveToFolder = onMoveToFolder
    self.onMoveOutOfFolder = nil
    self.onDelete = onDelete
    self.onLongPress = onLongPress
    self.onDragStart = onDragStart
    self.onDragMove = onDragMove
    self.onDragEnd = onDragEnd
    self.titleOpacity = titleOpacity
  }

  // Convenience initializer for folder overlay use (move out of folder).
  init(
    notebook: NotebookMetadata,
    action: @escaping () -> Void,
    onRename: @escaping () -> Void,
    onMoveOutOfFolder: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    onLongPress: ((CGRect, CGFloat) -> Void)? = nil,
    onDragStart: ((NotebookMetadata, CGRect, CGPoint) -> Void)? = nil,
    onDragMove: ((CGPoint) -> Void)? = nil,
    onDragEnd: ((CGPoint) -> Void)? = nil,
    titleOpacity: Double = 1.0
  ) {
    self.notebook = notebook
    self.action = action
    self.onRename = onRename
    self.onMoveToFolder = nil
    self.onMoveOutOfFolder = onMoveOutOfFolder
    self.onDelete = onDelete
    self.onLongPress = onLongPress
    self.onDragStart = onDragStart
    self.onDragMove = onDragMove
    self.onDragEnd = onDragEnd
    self.titleOpacity = titleOpacity
  }

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
  // Tracks whether the gesture has transitioned to drag mode.
  @State private var isDragging = false
  // Tracks the starting position of the touch for drag threshold detection.
  @State private var touchStartPosition: CGPoint = .zero
  // Stores the global position when drag started. Used with translation to calculate
  // current position, which is immune to parent scale transforms.
  @State private var dragStartGlobalPosition: CGPoint = .zero

  private let cardCornerRadius: CGFloat = 10
  private let titleAreaHeight: CGFloat = 36
  // Keeps a paper-like portrait ratio for the overall container.
  private let cardAspectRatio: CGFloat = 0.72
  // Minimum distance to move after long press to start drag mode.
  private let dragThreshold: CGFloat = 10

  var body: some View {
    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - titleAreaHeight

      VStack(alignment: .leading, spacing: 4) {
        // The card portion wrapped in a button.
        cardButton(width: totalWidth, height: cardHeight)

        // Title and date below the card. Opacity controlled by parent for fade effects.
        NotebookCardTitle(notebook: notebook)
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
  private func cardButton(width: CGFloat, height: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

    NotebookCardPreview(notebook: notebook, dimOpacity: dimOpacity)
      .frame(width: width, height: height)
      .background(Color.white)
      .clipShape(shape)
      .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
      .overlay(
        sweepOverlay(width: width, height: height)
      )
      .contentShape(shape)
      // Scale up slightly when pressed (before drag starts).
      .scaleEffect(dimOpacity > 0 && !isDragging ? 1.04 : 1.0)
      .animation(.spring(response: 0.15, dampingFraction: 0.75), value: dimOpacity > 0 && !isDragging)
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
    let currentPosition = value.location

    // First touch: initialize state.
    if touchStartPosition == .zero {
      touchStartPosition = value.startLocation
      didTriggerContextMenu = false
      isDragging = false

      // Dim immediately on touch down.
      withAnimation(.easeOut(duration: 0.06)) {
        dimOpacity = 0.12
      }

      // Schedule context menu and sweep animation after a delay.
      let currentFrame = cardFrame
      let cardHeight = currentFrame.height - titleAreaHeight
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
      return
    }

    // After context menu has triggered, check for drag initiation.
    if didTriggerContextMenu && !isDragging {
      let distance = hypot(
        currentPosition.x - touchStartPosition.x,
        currentPosition.y - touchStartPosition.y
      )
      if distance > dragThreshold {
        // Transition to drag mode.
        isDragging = true
        // Convert local position to global position for drag start.
        // This position is captured when the parent (e.g., folder overlay) is at scale 1.0.
        let globalPosition = CGPoint(
          x: cardFrame.minX + currentPosition.x,
          y: cardFrame.minY + currentPosition.y
        )
        dragStartGlobalPosition = globalPosition
        onDragStart?(notebook, cardFrame, globalPosition)
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
    withAnimation(.easeOut(duration: 0.25)) {
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

// MARK: - Notebook Card Preview

// Displays only the notebook preview image. No title, no shadow.
// Shadow is applied at the button level to work correctly with iOS context menu transitions.
struct NotebookCardPreview: View {
  let notebook: NotebookMetadata
  // Opacity of darkening overlay. Animated externally for press effects.
  var dimOpacity: Double = 0

  // Inset to crop out the thin black line on the right edge of the canvas capture.
  private let previewEdgeInset: CGFloat = 2

  var body: some View {
    let previewImage = notebook.previewImageData.flatMap { UIImage(data: $0) }

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
        }

        // Darkening overlay for press feedback.
        Color.black.opacity(dimOpacity)
          .allowsHitTesting(false)
      }
    }
  }
}

// MARK: - Notebook Card Title

// Displays the notebook title and last accessed date.
// Rendered as a sibling to the card preview, outside the context menu scope.
struct NotebookCardTitle: View {
  let notebook: NotebookMetadata

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(notebook.displayName)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color.ink)
        .lineLimit(1)
        .truncationMode(.tail)

      if let subtitle = formattedAccessDate {
        Text(subtitle)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(Color.inkSubtle)
          .lineLimit(1)
          .truncationMode(.tail)
      }
    }
    .padding(.horizontal, 2)
  }

  // Formats a short date string for the last access label.
  private var formattedAccessDate: String? {
    guard let lastAccessedAt = notebook.lastAccessedAt else {
      return nil
    }
    return Self.dateFormatter.string(from: lastAccessedAt)
  }

  // Reuses a single formatter for performance.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a  MM/dd/yy"
    return formatter
  }()
}

// MARK: - Notebook Card Context Menu Preview

// Standalone preview view for context menus that shows only the card without title.
// Used with .contextMenu(menuItems:preview:) as the lifted preview.
struct NotebookCardContextMenuPreview: View {
  let notebook: NotebookMetadata

  // Inset to crop out the thin black line on the right edge of the canvas capture.
  private let previewEdgeInset: CGFloat = 2

  var body: some View {
    let previewImage = notebook.previewImageData.flatMap { UIImage(data: $0) }
    let cardCornerRadius: CGFloat = 10
    let previewWidth: CGFloat = 160
    let previewHeight: CGFloat = 200

    ZStack {
      Color.white
      if let previewImage {
        Image(uiImage: previewImage)
          .resizable()
          .scaledToFill()
          .frame(width: previewWidth + previewEdgeInset, height: previewHeight)
          .frame(width: previewWidth, height: previewHeight, alignment: .leading)
          .clipped()
      }
    }
    .frame(width: previewWidth, height: previewHeight)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    // Matches the shadow on the actual card for smooth context menu dismiss transition.
    .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
  }
}

// MARK: - PDF Document Card Button

// Interactive container for a PDF document card with tactile press effects.
// Mirrors NotebookCardButton behavior exactly for consistent user experience.
// The card portion has drag behavior; the title is a sibling
// that animates together but stays outside the context menu highlight.
struct PDFDocumentCardButton: View {
  let metadata: PDFDocumentMetadata
  let action: () -> Void
  // Context menu actions passed in from the parent view.
  let onRename: () -> Void
  let onMoveToFolder: (() -> Void)?
  let onMoveOutOfFolder: (() -> Void)?
  let onDelete: () -> Void
  // Long press callback for custom context menu. Passes the card frame and card height.
  let onLongPress: ((CGRect, CGFloat) -> Void)?
  // Callback when drag starts after long press. Passes metadata, card frame, and initial touch position.
  let onDragStart: ((PDFDocumentMetadata, CGRect, CGPoint) -> Void)?
  // Callback during drag. Passes current touch position.
  let onDragMove: ((CGPoint) -> Void)?
  // Callback when drag ends. Passes final touch position.
  let onDragEnd: ((CGPoint) -> Void)?
  // Opacity for the title/date label. Allows parent to fade the title when targeted.
  var titleOpacity: Double = 1.0

  // Convenience initializer for dashboard use (move to folder).
  init(
    metadata: PDFDocumentMetadata,
    action: @escaping () -> Void,
    onRename: @escaping () -> Void,
    onMoveToFolder: (() -> Void)?,
    onDelete: @escaping () -> Void,
    onLongPress: ((CGRect, CGFloat) -> Void)? = nil,
    onDragStart: ((PDFDocumentMetadata, CGRect, CGPoint) -> Void)? = nil,
    onDragMove: ((CGPoint) -> Void)? = nil,
    onDragEnd: ((CGPoint) -> Void)? = nil,
    titleOpacity: Double = 1.0
  ) {
    self.metadata = metadata
    self.action = action
    self.onRename = onRename
    self.onMoveToFolder = onMoveToFolder
    self.onMoveOutOfFolder = nil
    self.onDelete = onDelete
    self.onLongPress = onLongPress
    self.onDragStart = onDragStart
    self.onDragMove = onDragMove
    self.onDragEnd = onDragEnd
    self.titleOpacity = titleOpacity
  }

  // Convenience initializer for folder overlay use (move out of folder).
  init(
    metadata: PDFDocumentMetadata,
    action: @escaping () -> Void,
    onRename: @escaping () -> Void,
    onMoveOutOfFolder: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    onLongPress: ((CGRect, CGFloat) -> Void)? = nil,
    onDragStart: ((PDFDocumentMetadata, CGRect, CGPoint) -> Void)? = nil,
    onDragMove: ((CGPoint) -> Void)? = nil,
    onDragEnd: ((CGPoint) -> Void)? = nil,
    titleOpacity: Double = 1.0
  ) {
    self.metadata = metadata
    self.action = action
    self.onRename = onRename
    self.onMoveToFolder = nil
    self.onMoveOutOfFolder = onMoveOutOfFolder
    self.onDelete = onDelete
    self.onLongPress = onLongPress
    self.onDragStart = onDragStart
    self.onDragMove = onDragMove
    self.onDragEnd = onDragEnd
    self.titleOpacity = titleOpacity
  }

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
  // Tracks whether the gesture has transitioned to drag mode.
  @State private var isDragging = false
  // Tracks the starting position of the touch for drag threshold detection.
  @State private var touchStartPosition: CGPoint = .zero
  // Stores the global position when drag started. Used with translation to calculate
  // current position, which is immune to parent scale transforms.
  @State private var dragStartGlobalPosition: CGPoint = .zero

  private let cardCornerRadius: CGFloat = 10
  private let titleAreaHeight: CGFloat = 36
  // Keeps a paper-like portrait ratio for the overall container.
  private let cardAspectRatio: CGFloat = 0.72
  // Minimum distance to move after long press to start drag mode.
  private let dragThreshold: CGFloat = 10

  var body: some View {
    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - titleAreaHeight

      VStack(alignment: .leading, spacing: 4) {
        // The card portion wrapped in gesture detection.
        cardButton(width: totalWidth, height: cardHeight)

        // Title and page count below the card. Opacity controlled by parent for fade effects.
        PDFDocumentCardTitle(metadata: metadata)
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
  private func cardButton(width: CGFloat, height: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

    PDFDocumentCardPreview(metadata: metadata, dimOpacity: dimOpacity)
      .frame(width: width, height: height)
      .background(Color(.systemGray5))
      .clipShape(shape)
      .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
      .overlay(
        sweepOverlay(width: width, height: height)
      )
      .contentShape(shape)
      // Scale up slightly when pressed (before drag starts).
      .scaleEffect(dimOpacity > 0 && !isDragging ? 1.04 : 1.0)
      .animation(.spring(response: 0.15, dampingFraction: 0.75), value: dimOpacity > 0 && !isDragging)
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
    let currentPosition = value.location

    // First touch: initialize state.
    if touchStartPosition == .zero {
      touchStartPosition = value.startLocation
      didTriggerContextMenu = false
      isDragging = false

      // Dim immediately on touch down.
      withAnimation(.easeOut(duration: 0.06)) {
        dimOpacity = 0.12
      }

      // Schedule context menu and sweep animation after a delay.
      let currentFrame = cardFrame
      let cardHeight = currentFrame.height - titleAreaHeight
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
      return
    }

    // After context menu has triggered, check for drag initiation.
    if didTriggerContextMenu && !isDragging {
      let distance = hypot(
        currentPosition.x - touchStartPosition.x,
        currentPosition.y - touchStartPosition.y
      )
      if distance > dragThreshold {
        // Transition to drag mode.
        isDragging = true
        // Convert local position to global position for drag start.
        // This position is captured when the parent (e.g., folder overlay) is at scale 1.0.
        let globalPosition = CGPoint(
          x: cardFrame.minX + currentPosition.x,
          y: cardFrame.minY + currentPosition.y
        )
        dragStartGlobalPosition = globalPosition
        onDragStart?(metadata, cardFrame, globalPosition)
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
    withAnimation(.easeOut(duration: 0.25)) {
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

// MARK: - PDF Document Card Preview

// Displays only the PDF preview image. No title, no shadow.
// Shadow is applied at the button level.
struct PDFDocumentCardPreview: View {
  let metadata: PDFDocumentMetadata
  // Opacity of darkening overlay. Animated externally for press effects.
  var dimOpacity: Double = 0

  var body: some View {
    let previewImage = metadata.previewImageData.flatMap { UIImage(data: $0) }

    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height

      ZStack {
        // Draws the preview or placeholder PDF icon.
        if let previewImage {
          Image(uiImage: previewImage)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
        } else {
          // Placeholder PDF icon when no preview is available.
          Image(systemName: "doc.richtext")
            .font(.system(size: 32))
            .foregroundColor(.accentColor)
        }

        // Darkening overlay for press feedback.
        Color.black.opacity(dimOpacity)
          .allowsHitTesting(false)
      }
    }
  }
}

// MARK: - PDF Document Card Title

// Displays the PDF title and page count.
// Rendered as a sibling to the card preview, outside the context menu scope.
struct PDFDocumentCardTitle: View {
  let metadata: PDFDocumentMetadata

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(metadata.displayName)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color.ink)
        .lineLimit(1)
        .truncationMode(.tail)

      Text(pageCountText)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
        .lineLimit(1)
    }
    .padding(.horizontal, 2)
  }

  // Formats the page count with correct singular/plural form.
  private var pageCountText: String {
    if metadata.pageCount == 1 {
      return "1 page"
    } else {
      return "\(metadata.pageCount) pages"
    }
  }
}

// MARK: - PDF Document Card Context Menu Preview

// Standalone preview view for context menus that shows only the card without title.
// Used with .contextMenu(menuItems:preview:) to keep the title visible in place
// while lifting just the card as the preview.
struct PDFDocumentCardContextMenuPreview: View {
  let pdfDocument: PDFDocumentMetadata

  var body: some View {
    let previewImage = pdfDocument.previewImageData.flatMap { UIImage(data: $0) }
    let cardCornerRadius: CGFloat = 10

    ZStack {
      Color(.systemGray5)
      if let previewImage {
        Image(uiImage: previewImage)
          .resizable()
          .scaledToFill()
          .frame(width: 160, height: 200)
          .clipped()
      } else {
        // Placeholder PDF icon when no preview is available.
        Image(systemName: "doc.richtext")
          .font(.system(size: 48))
          .foregroundColor(.accentColor)
      }
    }
    .frame(width: 160, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
  }
}

// MARK: - Card Preview Shape

// Custom shape for drag preview content shapes.
// Represents the card portion of a notebook/PDF card, excluding the title area.
struct CardPreviewShape: Shape {
  let cornerRadius: CGFloat
  let titleAreaHeight: CGFloat

  func path(in rect: CGRect) -> SwiftUI.Path {
    // Calculates the card height by subtracting the title area.
    let cardHeight = rect.height - titleAreaHeight
    let cardRect = CGRect(x: 0, y: 0, width: rect.width, height: cardHeight)
    return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .path(in: cardRect)
  }
}
