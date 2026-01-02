import SwiftUI
import UIKit

// Displays an expanded folder overlay with notebooks inside.
// Uses matchedGeometryEffect to animate from the source folder card position.
// Tapping outside the overlay dismisses it.
struct FolderOverlay: View {
  let folder: FolderMetadata
  let notebooks: [NotebookMetadata]
  let namespace: Namespace.ID
  let isContentVisible: Bool
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
  private let contentPadding: CGFloat = 16

  var body: some View {
    ZStack {
      // Dismissal background: tap to close.
      dismissBackground

      // The expanded folder content.
      folderContent
        .matchedGeometryEffect(
          id: "folder-\(folder.id)",
          in: namespace,
          isSource: true
        )
    }
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

  // Transparent background that dismisses the overlay when tapped.
  private var dismissBackground: some View {
    Color.clear
      .contentShape(Rectangle())
      .ignoresSafeArea()
      .onTapGesture {
        onDismiss()
      }
  }

  // The main folder content area with glass styling.
  private var folderContent: some View {
    VStack(spacing: 0) {
      // Folder title header.
      folderHeader

      // Notebooks grid or empty state.
      if notebooks.isEmpty {
        emptyState
      } else {
        notebooksGrid
      }
    }
    .frame(width: overlayWidth)
    .glassOverlayBackground(cornerRadius: overlayCornerRadius)
    .opacity(isContentVisible ? 1 : 0)
  }

  // Folder name displayed at the top of the overlay.
  private var folderHeader: some View {
    Text(folder.displayName)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(Color.ink)
      .lineLimit(1)
      .padding(.horizontal, contentPadding)
      .padding(.top, contentPadding)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
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
  private var notebooksGrid: some View {
    let columns = [
      GridItem(.flexible(), spacing: 10),
      GridItem(.flexible(), spacing: 10)
    ]

    return ScrollView {
      LazyVGrid(columns: columns, spacing: 10) {
        ForEach(notebooks) { notebook in
          NotebookCardButton(notebook: notebook) {
            onNotebookTap(notebook)
          }
          .contextMenu {
            Button {
              renameText = notebook.displayName
              renamingNotebook = notebook
            } label: {
              Label("Rename", systemImage: "pencil")
            }

            Button {
              onMoveToRoot(notebook)
            } label: {
              Label("Move Out of Folder", systemImage: "arrow.up.doc")
            }

            Button(role: .destructive) {
              deletingNotebook = notebook
            } label: {
              Label("Delete", systemImage: "trash")
            }
          } preview: {
            // Shows only the card in the preview, keeping the title visible in place.
            NotebookCardContextMenuPreview(notebook: notebook)
          }
        }
      }
      .padding(.horizontal, contentPadding)
      .padding(.bottom, contentPadding)
    }
    .frame(maxHeight: 400)
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
