import SwiftUI
import UIKit

// Displays an expanded folder overlay with notebooks inside.
// Uses scale-based animation: renders at full size but scales down to match source position.
// Content is always visible and scales naturally with the container.
struct FolderOverlay: View {
  let folder: FolderMetadata
  let notebooks: [NotebookMetadata]
  // The source card's frame in global coordinates (card portion only, no title).
  let sourceFrame: CGRect
  // Controls scale animation. When true, overlay is at full scale (1.0).
  let isExpanded: Bool
  let onNotebookTap: (NotebookMetadata) -> Void
  let onMoveToRoot: (NotebookMetadata) -> Void
  let onRenameNotebook: (NotebookMetadata, String) -> Void
  let onDeleteNotebook: (NotebookMetadata) -> Void
  let onDismiss: () -> Void

  // State for rename alert.
  @State private var renamingNotebook: NotebookMetadata?
  @State private var renameText: String = ""

  // State for delete confirmation alert.
  @State private var deletingNotebook: NotebookMetadata?

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

      ZStack {
        // Dim background: fades based on expansion state.
        dismissBackground
          .opacity(isExpanded ? 1 : 0)

        // The folder container always rendered at full expanded size.
        // Uses separate X/Y scales to morph from source shape to overlay shape.
        // Fades out as it contracts so it crossfades with the folder card underneath.
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
          .opacity(isExpanded ? 1 : 0)
      }
      .frame(width: screenBounds.width, height: screenBounds.height)
    }
    .ignoresSafeArea()
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
  }

  // Calculates the expanded overlay frame centered on screen.
  private func calculateExpandedFrame(in screenBounds: CGRect) -> CGRect {
    let gridSpacing: CGFloat = 10
    let cardAspectRatio: CGFloat = 0.72
    let columns = 2

    // Calculate card dimensions matching notebooksGrid calculations.
    let availableWidth = overlayWidth - contentPadding * 2 - gridSpacing * CGFloat(columns - 1)
    let cardWidth = availableWidth / CGFloat(columns)
    let cardHeight = cardWidth / cardAspectRatio

    // Calculate number of rows.
    let rows = max(1, (notebooks.count + columns - 1) / columns)

    // Calculate total grid height: rows of cards plus spacing between rows.
    let gridHeight = CGFloat(rows) * cardHeight + CGFloat(rows - 1) * gridSpacing

    // Total content height: header + top padding + grid + bottom padding.
    let contentHeight = headerHeight + 8 + gridHeight + contentPadding

    // Minimum height for empty state.
    let minHeight: CGFloat = headerHeight + 160 + contentPadding
    let totalHeight = notebooks.isEmpty ? minHeight : contentHeight

    return CGRect(
      x: (screenBounds.width - overlayWidth) / 2,
      y: (screenBounds.height - totalHeight) / 2,
      width: overlayWidth,
      height: totalHeight
    )
  }

  // Dim background that dismisses the overlay when tapped.
  private var dismissBackground: some View {
    Color.black.opacity(0.15)
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

        // Content area containing snapshot (during animation) and notebooks (after).
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

  // Content area below the header containing notebooks.
  // Always renders notebooks - they scale naturally with the container.
  // No snapshot needed since scale animation doesn't clip content.
  private var contentArea: some View {
    GeometryReader { geo in
      if notebooks.isEmpty {
        emptyState
      } else {
        notebooksGrid(in: geo.size)
      }
    }
  }

  // Empty state when folder has no notebooks.
  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(Color.inkFaint)

      Text("No notebooks")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
    }
    .frame(height: 160)
    .frame(maxWidth: .infinity)
    .padding(.bottom, contentPadding)
  }

  // Grid of notebook cards inside the folder.
  // Calculates explicit card dimensions to prevent compression.
  private func notebooksGrid(in size: CGSize) -> some View {
    let columns = 2
    let rows = (notebooks.count + columns - 1) / columns
    let gridSpacing: CGFloat = 10
    let cardAspectRatio: CGFloat = 0.72

    // Calculate card width based on available space minus padding and spacing.
    let availableWidth = size.width - contentPadding * 2 - gridSpacing * CGFloat(columns - 1)
    let cardWidth = availableWidth / CGFloat(columns)
    // Card height from aspect ratio (includes title area).
    let cardHeight = cardWidth / cardAspectRatio

    return VStack(alignment: .leading, spacing: gridSpacing) {
      ForEach(0..<rows, id: \.self) { row in
        HStack(spacing: gridSpacing) {
          ForEach(0..<columns, id: \.self) { col in
            let index = row * columns + col
            if index < notebooks.count {
              NotebookCardButton(
                notebook: notebooks[index],
                action: {
                  onNotebookTap(notebooks[index])
                },
                onRename: {
                  renameText = notebooks[index].displayName
                  renamingNotebook = notebooks[index]
                },
                onMoveOutOfFolder: {
                  onMoveToRoot(notebooks[index])
                },
                onDelete: {
                  deletingNotebook = notebooks[index]
                }
              )
              .frame(width: cardWidth, height: cardHeight)
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
