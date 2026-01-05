import SwiftUI

// Sheet view for moving a notebook into a folder.
// Displays a list of available folders and a "New Folder" option.
// Invoked from the notebook context menu.
struct MoveToFolderSheet: View {
  let notebook: NotebookMetadata
  let folders: [FolderMetadata]
  let onSelectFolder: (FolderMetadata) -> Void
  let onCreateNewFolder: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Shows which notebook is being moved.
        notebookPreview
          .padding(.top, 8)
          .padding(.bottom, 16)

        Divider()

        // List of folders or empty state.
        if folders.isEmpty {
          emptyFolderState
        } else {
          folderList
        }
      }
      .navigationTitle("Move to Folder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onDismiss()
          }
        }

        ToolbarItem(placement: .primaryAction) {
          Button {
            onCreateNewFolder()
          } label: {
            Image(systemName: "folder.badge.plus")
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  // Preview of the notebook being moved.
  private var notebookPreview: some View {
    HStack(spacing: 12) {
      // Small thumbnail of the notebook.
      NotebookThumbnail(notebook: notebook)
        .frame(width: 48, height: 64)

      VStack(alignment: .leading, spacing: 2) {
        Text("Moving")
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(Color.inkSubtle)

        Text(notebook.displayName)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.ink)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(.horizontal, 20)
  }

  // Empty state when no folders exist.
  private var emptyFolderState: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "folder")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(Color.inkFaint)

      Text("No folders yet")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(Color.inkSubtle)

      Button {
        onCreateNewFolder()
      } label: {
        Text("Create Folder")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.ink)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .glassBackground(cornerRadius: 12)
      }
      .buttonStyle(.plain)

      Spacer()
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  // List of folders to select from.
  private var folderList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(folders) { folder in
          FolderRow(folder: folder) {
            onSelectFolder(folder)
          }
        }
      }
    }
  }
}

// Small thumbnail preview of a notebook.
private struct NotebookThumbnail: View {
  let notebook: NotebookMetadata

  var body: some View {
    let cornerRadius: CGFloat = 6

    Group {
      if let imageData = notebook.previewImageData,
        let image = UIImage(data: imageData) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Color.white
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
  }
}

// A single folder row in the folder selection list.
private struct FolderRow: View {
  let folder: FolderMetadata
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 14) {
        // Folder icon.
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black.opacity(0.05))
            .frame(width: 44, height: 44)

          Image(systemName: "folder.fill")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.inkSubtle)
        }

        // Folder name and count.
        VStack(alignment: .leading, spacing: 2) {
          Text(folder.displayName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.ink)
            .lineLimit(1)

          Text(countLabel)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(Color.inkSubtle)
        }

        Spacer()

        // Selection indicator.
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.inkFaint)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // Formats the item count label.
  // Shows "notebooks" if only notebooks, "PDFs" if only PDFs, or "items" if mixed.
  private var countLabel: String {
    let total = folder.itemCount
    if total == 0 {
      return "Empty"
    } else if folder.pdfCount == 0 {
      return total == 1 ? "1 notebook" : "\(total) notebooks"
    } else if folder.notebookCount == 0 {
      return total == 1 ? "1 PDF" : "\(total) PDFs"
    } else {
      return total == 1 ? "1 item" : "\(total) items"
    }
  }
}

// MARK: - PDF Move To Folder Sheet

// Sheet view for moving a PDF document into a folder.
// Displays a list of available folders and a "New Folder" option.
// Invoked from the PDF document context menu.
struct PDFMoveToFolderSheet: View {
  let pdfDocument: PDFDocumentMetadata
  let folders: [FolderMetadata]
  let onSelectFolder: (FolderMetadata) -> Void
  let onCreateNewFolder: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Shows which PDF is being moved.
        pdfPreview
          .padding(.top, 8)
          .padding(.bottom, 16)

        Divider()

        // List of folders or empty state.
        if folders.isEmpty {
          emptyFolderState
        } else {
          folderList
        }
      }
      .navigationTitle("Move to Folder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onDismiss()
          }
        }

        ToolbarItem(placement: .primaryAction) {
          Button {
            onCreateNewFolder()
          } label: {
            Image(systemName: "folder.badge.plus")
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  // Preview of the PDF being moved.
  private var pdfPreview: some View {
    HStack(spacing: 12) {
      // Small thumbnail of the PDF.
      PDFThumbnail(pdfDocument: pdfDocument)
        .frame(width: 48, height: 64)

      VStack(alignment: .leading, spacing: 2) {
        Text("Moving")
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(Color.inkSubtle)

        Text(pdfDocument.displayName)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.ink)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(.horizontal, 20)
  }

  // Empty state when no folders exist.
  private var emptyFolderState: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "folder")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(Color.inkFaint)

      Text("No folders yet")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(Color.inkSubtle)

      Button {
        onCreateNewFolder()
      } label: {
        Text("Create Folder")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.ink)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .glassBackground(cornerRadius: 12)
      }
      .buttonStyle(.plain)

      Spacer()
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  // List of folders to select from.
  private var folderList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(folders) { folder in
          FolderRow(folder: folder) {
            onSelectFolder(folder)
          }
        }
      }
    }
  }
}

// Small thumbnail preview of a PDF document.
private struct PDFThumbnail: View {
  let pdfDocument: PDFDocumentMetadata

  var body: some View {
    let cornerRadius: CGFloat = 6

    Group {
      if let imageData = pdfDocument.previewImageData,
        let image = UIImage(data: imageData) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          Color.gray.opacity(0.1)
          Image(systemName: "doc.richtext")
            .font(.system(size: 20, weight: .light))
            .foregroundStyle(Color.inkSubtle)
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
  }
}
