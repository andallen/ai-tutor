import SwiftUI
import UIKit

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

  // Tracks whether the dashboard is loading notebooks.
  @State private var isLoadingNotebooks = true

  var body: some View {
    ZStack(alignment: .topLeading) {
      // Keeps the background uniform and bright.
      Color.white
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Notebook grid or empty state
        if isLoadingNotebooks {
          loadingState
        } else if library.notebooks.isEmpty {
          emptyState
        } else {
          notebookGrid
        }

        Spacer(minLength: 0)
      }

      // Shows the title as a separate overlay above the transparent navigation bar.
      Text("Notes")
        .font(.system(size: 32, weight: .semibold))
        .foregroundStyle(Color.offBlack)
        .accessibilityAddTraits(.isHeader)
        .padding(.leading, 16)
        .padding(.top, 8)
        .offset(y: -60)
        .allowsHitTesting(false)
    }
    .fontDesign(.rounded)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      // Adds a new notebook from the trailing navigation bar button.
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
      isLoadingNotebooks = true
      await library.loadBundles()
      isLoadingNotebooks = false
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
    .onReceive(NotificationCenter.default.publisher(for: .notebookPreviewUpdated)) { _ in
      addLog("🧪 DashboardView previewUpdated reload")
      Task {
        isLoadingNotebooks = true
        await library.loadBundles()
        isLoadingNotebooks = false
      }
    }
  }

  // MARK: - Loading State

  private var loadingState: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Loading notes...")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "doc.text")
        .font(.system(size: 56, weight: .light))
        .foregroundStyle(Color.inkFaint)

      Text("No notes yet")
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
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  // MARK: - Notebook Grid

  private var notebookGrid: some View {
    ScrollView {
      LazyVGrid(
        columns: [
          GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
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
    .padding(.top, 24)
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
    let previewImage = notebook.previewImageData.flatMap { UIImage(data: $0) }
    let cardCornerRadius: CGFloat = 12
    // Keeps a paper-like portrait ratio.
    let cardAspectRatio: CGFloat = 0.72

    GeometryReader { proxy in
      let size = proxy.size
      let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

      let previewLayer =
        ZStack {
          // Ensures a clean base behind the preview.
          Color.white

          // Draws the preview or placeholder cover.
          if let previewImage {
            Image(uiImage: previewImage)
              .resizable()
              .scaledToFill()
              .frame(width: size.width, height: size.height)
              // Keeps the preview a touch softer and less bright.
              .brightness(0.02)
              .contrast(1.0)
          } else {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
              .fill(Color.white)
          }
        }
        .frame(width: size.width, height: size.height)

      ZStack(alignment: .bottomLeading) {
        previewLayer

        // Adds a feathered title band for readability.
        NotebookTitleBand(
          title: notebook.displayName,
          lastAccessedAt: notebook.lastAccessedAt,
          cornerRadius: cardCornerRadius
        )
      }
      .frame(width: size.width, height: size.height)
      .clipShape(shape)
      // Adds a soft shadow for card lift.
      .shadow(color: Color.black.opacity(0.16), radius: 9, x: 0, y: 6)
    }
    .aspectRatio(cardAspectRatio, contentMode: .fit)
  }
}

private struct NotebookTitleBand: View {
  let title: String
  let lastAccessedAt: Date?
  let cornerRadius: CGFloat

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      // Feathers the white backing into the preview.
      Rectangle()
        .fill(
          LinearGradient(
            stops: [
              .init(color: Color.white.opacity(1.0), location: 0.0),
              .init(color: Color.white.opacity(1.0), location: 0.25),
              .init(color: Color.white.opacity(0.7), location: 0.42),
              .init(color: Color.white.opacity(0.35), location: 0.55),
              .init(color: Color.white.opacity(0.0), location: 0.7),
            ],
            startPoint: .bottom,
            endPoint: .top
          )
        )
      // Keeps the title readable on top of the preview.
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.black)
          .lineLimit(1)
          .truncationMode(.tail)

        if let subtitle = formattedAccessDate {
          Text(subtitle)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.55))
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 10)
      .padding(.top, 8)
    }
    .clipShape(
      RoundedCornerShape(
        radius: cornerRadius,
        corners: [.bottomLeft, .bottomRight]
      )
    )
  }

  // Formats a short date string for the last access label.
  private var formattedAccessDate: String? {
    guard let lastAccessedAt else {
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

#if DEBUG
  struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationStack {
        DashboardView()
      }
    }
  }
#endif
