import SwiftUI

// The Dashboard shows a list of Notebooks and provides create, rename, delete, and open actions.
// It does not contain storage logic. It forwards user actions to the Notebook Library.
struct DashboardView: View {
  // The Notebook Library manages the list of notebooks and operations on them.
  @StateObject private var library = NotebookLibrary(bundleManager: BundleManager())

  // Tracks which notebook is being renamed.
  @State private var renamingNotebook: NotebookMetadata?

  // The new name being typed during rename.
  @State private var renameText: String = ""

  // Tracks which notebook is being confirmed for deletion.
  @State private var deletingNotebook: NotebookMetadata?

  // Opens a notebook session when a notebook is tapped.
  @State private var activeSession: NotebookSession?

  // Tracks an error message when opening a notebook fails.
  @State private var openErrorMessage: String?

  // Animation namespace for matched geometry transitions.
  @Namespace private var animation

  var body: some View {
    ZStack {
      BackgroundWhite()
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Notebook grid or empty state
        if library.notebooks.isEmpty {
          emptyState
        } else {
          notebookGrid
        }

        Spacer(minLength: 0)
      }
    }
    .fontDesign(.rounded)
    .navigationTitle("Notes")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          Task {
            await library.createNotebook()
          }
        } label: {
          Image(systemName: "plus")
        }
      }
    }
    .toolbarBackground(.hidden, for: .navigationBar)
    .tint(Color.offBlack)
    .task {
      await library.loadBundles()
    }
    .alert(
      "Rename Notebook",
      isPresented: .init(
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
          Task {
            await library.renameNotebook(notebookID: notebook.id, newDisplayName: trimmedName)
          }
        }
        renamingNotebook = nil
      }
    } message: {
      Text("Enter a new name for this notebook.")
    }
    .alert(
      "Delete Notebook?",
      isPresented: .init(
        get: { deletingNotebook != nil },
        set: { if !$0 { deletingNotebook = nil } }
      )
    ) {
      Button("Cancel", role: .cancel) {
        deletingNotebook = nil
      }
      Button("Delete", role: .destructive) {
        if let notebook = deletingNotebook {
          Task {
            await library.deleteNotebook(notebookID: notebook.id)
          }
        }
        deletingNotebook = nil
      }
    } message: {
      if let notebook = deletingNotebook {
        Text("\"\(notebook.displayName)\" will be permanently deleted. This cannot be undone.")
      }
    }
    .alert(
      "Unable to Open Notebook",
      isPresented: .init(
        get: { openErrorMessage != nil },
        set: { if !$0 { openErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {
        openErrorMessage = nil
      }
    } message: {
      Text(openErrorMessage ?? "Unknown error.")
    }
    .fullScreenCover(
      item: $activeSession,
      onDismiss: {
        activeSession = nil
      },
      content: { session in
        GetStartedHostView(documentHandle: session.handle)
      }
    )
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "book.closed")
        .font(.system(size: 56, weight: .light))
        .foregroundStyle(Color.inkFaint)

      Text("No notebooks yet")
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(Color.inkSubtle)

      Button {
        Task {
          await library.createNotebook()
        }
      } label: {
        Text("Create Notebook")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.ink)
          .padding(.horizontal, 24)
          .padding(.vertical, 14)
          .glassBackground(cornerRadius: 14)
      }
      .buttonStyle(.plain)
      .padding(.top, 8)

      Spacer()
      Spacer()
    }
  }

  // MARK: - Notebook Grid

  private var notebookGrid: some View {
    ScrollView {
      LazyVGrid(
        columns: [
          GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
        ],
        spacing: 16
      ) {
        ForEach(library.notebooks) { notebook in
          NotebookCard(notebook: notebook)
            .contentShape(Rectangle())
            .onTapGesture {
              Task {
                do {
                  let handle = try await library.openNotebook(notebookID: notebook.id)
                  activeSession = NotebookSession(
                    id: notebook.id,
                    handle: handle
                  )
                } catch {
                  openErrorMessage = error.localizedDescription
                }
              }
            }
            .contextMenu {
              Button {
                renameText = notebook.displayName
                renamingNotebook = notebook
              } label: {
                Label("Rename", systemImage: "pencil")
              }

              Button(role: .destructive) {
                deletingNotebook = notebook
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
  }

  // MARK: - Actions
}

// MARK: - Notebook Session

private struct NotebookSession: Identifiable {
  let id: String
  let handle: DocumentHandle
}

// MARK: - Notebook Card

private struct NotebookCard: View {
  let notebook: NotebookMetadata

  var body: some View {
    let coverHighlight = Color(hue: 0.08, saturation: 0.06, brightness: 0.98)
    let coverShadow = Color(hue: 0.08, saturation: 0.04, brightness: 0.94)

    VStack(alignment: .leading, spacing: 12) {
      // Notebook icon
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(
            LinearGradient(
              colors: [coverHighlight, coverShadow],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(height: 100)

        Image(systemName: "book.closed.fill")
          .font(.system(size: 32, weight: .light))
          .foregroundStyle(Color.inkFaint)
      }

      // Notebook name
      Text(notebook.displayName)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color.ink)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .glassBackground(cornerRadius: 16)
  }
}

#if DEBUG
  struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationStack {
        DashboardView()
      }
    }
  }
#endif
