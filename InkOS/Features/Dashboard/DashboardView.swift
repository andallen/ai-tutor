import SwiftUI
import UIKit

// MARK: - Card Frame Store

// Reference type for storing card frames so UIKit can read current values during transitions.
// SwiftUI updates this via preferences, and UIKit queries it at dismiss time.
// Uses a class (reference type) so the same instance is accessible from both SwiftUI and UIKit.
final class CardFrameStore {
  var frames: [String: CGRect] = [:]
}

// The Dashboard shows a list of Notebooks and Folders, providing create, rename, delete, and open actions.
// It does not contain storage logic. It forwards user actions to the Notebook Library.
// swiftlint:disable file_length type_body_length
// File length exception justified: Main dashboard view with tightly coupled helper view modifiers.
// Type body length exception justified: SwiftUI view with many computed subview properties for organization.
struct DashboardView: View {
  // The Notebook Library manages the list of notebooks, folders, and operations on them.
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

  // Tracks whether the dashboard is loading items.
  @State private var isLoadingItems = true

  // MARK: - Folder State

  // Tracks which folder is being renamed.
  @State private var renamingFolder: FolderMetadata?

  // Tracks which folder is being confirmed for deletion.
  @State private var deletingFolder: FolderMetadata?

  // Tracks which notebook is being moved to a folder.
  @State private var movingNotebook: NotebookMetadata?

  // Tracks whether the create folder alert is shown.
  @State private var showCreateFolderAlert = false

  // The name being typed when creating a new folder.
  @State private var newFolderName: String = ""

  // Cache of folder thumbnail images for display.
  @State private var folderThumbnails: [String: [UIImage]] = [:]

  // Tracks which folder ID is currently being targeted for drop.
  @State private var dropTargetFolderID: String?

  // MARK: - Folder Expansion State

  // Namespace for matchedGeometryEffect animations between folder card and overlay.
  @Namespace private var folderAnimationNamespace

  // Tracks which folder is currently expanded (nil when no folder is open).
  @State private var expandedFolder: FolderMetadata?

  // Notebooks loaded for the currently expanded folder.
  @State private var expandedFolderNotebooks: [NotebookMetadata] = []

  // Controls the visibility state of the folder overlay for animation timing.
  @State private var isFolderOverlayVisible = false

  // MARK: - Notebook Hero Transition State

  // Holds the transition coordinator for the currently open notebook.
  // Strong reference prevents deallocation during the transition.
  @State private var transitionCoordinator: NotebookTransitionCoordinator?

  // Reference type for card frames so UIKit can query current values during dismiss.
  // Using @State with a class preserves the reference across view updates.
  @State private var cardFrameStore = CardFrameStore()

  var body: some View {
    mainContent
      .modifier(
        DashboardViewModifiers(
          library: library,
          renamingNotebook: $renamingNotebook,
          renameText: $renameText,
          deletingNotebook: $deletingNotebook,
          renamingFolder: $renamingFolder,
          deletingFolder: $deletingFolder,
          showCreateFolderAlert: $showCreateFolderAlert,
          newFolderName: $newFolderName,
          openErrorMessage: $openErrorMessage,
          isLoadingItems: $isLoadingItems,
          activeSession: $activeSession,
          movingNotebook: $movingNotebook,
          expandedFolder: $expandedFolder,
          expandedFolderNotebooks: $expandedFolderNotebooks,
          loadFolderThumbnails: loadFolderThumbnails
        )
      )
      .toolbar {
        toolbarContent
      }
  }

  // MARK: - Main Content

  private var mainContent: some View {
    GeometryReader { screenGeometry in
      ZStack(alignment: .topLeading) {
        // Keeps the background uniform and bright.
        Color.white
          .ignoresSafeArea()

        VStack(spacing: 0) {
          // Item grid or empty state.
          if isLoadingItems {
            loadingState
          } else if library.items.isEmpty {
            emptyState
          } else {
            itemGrid
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Shows the title as a separate overlay above the transparent navigation bar.
        Text("Notes")
          .font(.system(size: 32, weight: .semibold))
          .foregroundStyle(Color.offBlack)
          .accessibilityAddTraits(.isHeader)
          .padding(.leading, 16)
          .padding(.top, 8)
          .offset(y: -60)
          .allowsHitTesting(false)

        // Folder expansion overlay.
        if let folder = expandedFolder {
          FolderOverlay(
            folder: folder,
            notebooks: expandedFolderNotebooks,
            namespace: folderAnimationNamespace,
            isContentVisible: isFolderOverlayVisible,
            onNotebookTap: { notebook in
              openNotebookFromFolder(notebook)
            },
            onMoveToRoot: { notebook in
              moveNotebookToRoot(notebook)
            },
            onRenameNotebook: { notebook, newName in
              renameNotebookInFolder(notebook, newName: newName)
            },
            onDeleteNotebook: { notebook in
              deleteNotebookInFolder(notebook)
            },
            onDismiss: {
              closeFolder()
            }
          )
          .zIndex(100)
        }
      }
      // Collect card frame preferences for hero transitions.
      // Updates the reference-type store so UIKit can query current frames at dismiss time.
      .onPreferenceChange(CardFramePreferenceKey.self) { frames in
        cardFrameStore.frames.merge(frames) { _, new in new }
      }
    }
  }

  // MARK: - Toolbar Content

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    // When folder is open: direct notebook creation (no menu).
    // When no folder is open: shows menu with notebook and folder options.
    ToolbarItem(placement: .navigationBarTrailing) {
      if let folder = expandedFolder {
        // Direct create button when folder is open.
        Button {
          createNotebookInExpandedFolder(folder)
        } label: {
          Image(systemName: "plus")
        }
      } else {
        // Menu with options when no folder is open.
        Menu {
          Button {
            Task {
              await library.createNotebook()
            }
          } label: {
            Label("New Note", systemImage: "doc.badge.plus")
          }

          Button {
            newFolderName = ""
            showCreateFolderAlert = true
          } label: {
            Label("New Folder", systemImage: "folder.badge.plus")
          }
        } label: {
          Image(systemName: "plus")
        }
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

  // MARK: - Item Grid

  private var itemGrid: some View {
    ScrollView {
      LazyVGrid(
        columns: [
          GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 12)
        ],
        spacing: 12
      ) {
        ForEach(library.items) { item in
          switch item {
          case .notebook(let notebook):
            notebookCardView(notebook: notebook)
          case .folder(let folder):
            folderCardView(folder: folder)
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
    .padding(.top, 24)
  }

  // MARK: - Notebook Card View

  @ViewBuilder
  private func notebookCardView(notebook: NotebookMetadata) -> some View {
    NotebookCardButton(notebook: notebook) {
      openNotebook(notebook)
    }
    // Capture the card's frame for hero animation positioning.
    .background(
      GeometryReader { geometry in
        Color.clear
          .preference(
            key: CardFramePreferenceKey.self,
            value: [notebook.id: geometry.frame(in: .global)]
          )
      }
    )
    .draggable(notebook)
    .contextMenu {
      Button {
        renameText = notebook.displayName
        renamingNotebook = notebook
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      if !library.folders.isEmpty {
        Button {
          movingNotebook = notebook
        } label: {
          Label("Move to Folder", systemImage: "folder")
        }
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

  // MARK: - Folder Card View

  @ViewBuilder
  private func folderCardView(folder: FolderMetadata) -> some View {
    let isTargeted = dropTargetFolderID == folder.id
    let thumbnails = folderThumbnails[folder.id] ?? []
    let isExpanded = expandedFolder?.id == folder.id

    FolderCardButton(folder: folder, thumbnails: thumbnails) {
      // Opens the folder overlay with animation.
      openFolder(folder)
    }
    // Apply matchedGeometryEffect for position animation.
    // The overlay takes over the matched ID when expanded.
    .matchedGeometryEffect(
      id: "folder-\(folder.id)",
      in: folderAnimationNamespace,
      isSource: !isExpanded
    )
    // Hide the source card when its folder is expanded.
    .opacity(isExpanded ? 0 : 1)
    .scaleEffect(isTargeted ? 1.08 : 1.0)
    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isTargeted)
    .onDrop(
      of: [.notebookID],
      delegate: createFolderDropDelegate(for: folder)
    )
    .contextMenu {
      Button {
        renameText = folder.displayName
        renamingFolder = folder
      } label: {
        Label("Rename Folder", systemImage: "pencil")
      }

      Button(role: .destructive) {
        deletingFolder = folder
      } label: {
        Label("Delete Folder", systemImage: "trash")
      }
    } preview: {
      // Shows only the folder card in the preview, keeping the title visible in place.
      FolderCardContextMenuPreview(folder: folder, thumbnails: thumbnails)
    }
  }

  // Creates a drop delegate for folder drag-and-drop operations.
  private func createFolderDropDelegate(for folder: FolderMetadata) -> FolderDropDelegate {
    FolderDropDelegate(
      folderID: folder.id,
      onNotebookDropped: { notebookID in
        Task {
          await library.moveNotebookToFolder(notebookID: notebookID, folderID: folder.id)
          await loadFolderThumbnails()
        }
      },
      isTargeted: Binding(
        get: { dropTargetFolderID == folder.id },
        set: { newValue in
          if newValue {
            dropTargetFolderID = folder.id
          } else if dropTargetFolderID == folder.id {
            dropTargetFolderID = nil
          }
        }
      )
    )
  }

  // MARK: - Actions

  // Opens a notebook from the main grid with a custom UIKit hero transition.
  private func openNotebook(_ notebook: NotebookMetadata) {
    // Capture the card's current frame before starting animation.
    guard let sourceFrame = cardFrameStore.frames[notebook.id], sourceFrame.width > 0 else {
      // Fallback: open without animation if frame not available.
      Task {
        do {
          let handle = try await library.openNotebook(notebookID: notebook.id)
          activeSession = NotebookSession(id: notebook.id, handle: handle)
        } catch {
          openErrorMessage = error.localizedDescription
        }
      }
      return
    }

    // Capture reference to frame store for dismiss-time frame lookup.
    let frameStore = cardFrameStore
    let notebookID = notebook.id

    Task {
      do {
        // Load the document handle.
        let handle = try await library.openNotebook(notebookID: notebook.id)
        let previewImage = notebook.previewImageData.flatMap { UIImage(data: $0) }

        // Create and configure the transition coordinator.
        let coordinator = NotebookTransitionCoordinator()
        coordinator.sourceFrame = sourceFrame
        coordinator.previewImage = previewImage
        coordinator.documentHandle = handle
        // Provide a closure to look up the top-left card's frame at dismiss time.
        // The notebook will move to position 0 (most recent) after loadBundles,
        // so animate to where position 0 is, not where the notebook currently sits.
        coordinator.frameProvider = { [weak frameStore] in
          guard let frames = frameStore?.frames, !frames.isEmpty else { return nil }
          // Find the frame with minimum x, then minimum y (top-left position).
          return frames.values.min { frame1, frame2 in
            if frame1.minY != frame2.minY {
              return frame1.minY < frame2.minY
            }
            return frame1.minX < frame2.minX
          }
        }
        coordinator.onDismiss = { [weak library] _ in
          // Refresh the dashboard after dismissal to show updated previews.
          Task {
            await library?.loadBundles()
          }
        }

        // Get the root view controller and present.
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
          coordinator.present(from: rootVC)
        }

        // Hold a strong reference to prevent deallocation during transition.
        transitionCoordinator = coordinator
      } catch {
        openErrorMessage = error.localizedDescription
      }
    }
  }

  // MARK: - Folder Expansion Actions

  // Opens a folder and loads its notebooks for display in the overlay.
  private func openFolder(_ folder: FolderMetadata) {
    Task {
      // Load notebooks before showing overlay.
      let notebooks = await library.notebooksInFolder(folderID: folder.id)
      expandedFolderNotebooks = notebooks

      // Animate the folder expansion.
      withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
        expandedFolder = folder
      }

      // Slight delay for content to fade in after position animation starts.
      try? await Task.sleep(nanoseconds: 50_000_000)
      withAnimation(.easeOut(duration: 0.2)) {
        isFolderOverlayVisible = true
      }
    }
  }

  // Closes the expanded folder with reverse animation.
  private func closeFolder() {
    // Fade out content first.
    withAnimation(.easeIn(duration: 0.15)) {
      isFolderOverlayVisible = false
    }

    // Then animate back to source position.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
        expandedFolder = nil
      }
      expandedFolderNotebooks = []
    }
  }

  // Opens a notebook from within the expanded folder overlay.
  // Uses a simpler transition since the hero animation is designed for main grid cards.
  private func openNotebookFromFolder(_ notebook: NotebookMetadata) {
    // Close the folder first, then open the notebook directly.
    closeFolder()

    // Small delay to allow folder close animation to complete.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      Task {
        do {
          let handle = try await library.openNotebook(notebookID: notebook.id)
          activeSession = NotebookSession(id: notebook.id, handle: handle)
        } catch {
          openErrorMessage = error.localizedDescription
        }
      }
    }
  }

  // Creates a notebook directly inside the currently expanded folder.
  private func createNotebookInExpandedFolder(_ folder: FolderMetadata) {
    Task { @MainActor in
      _ = await library.createNotebookInFolder(
        folderID: folder.id,
        displayName: "Untitled Notebook"
      )
      await library.loadBundles()
      await loadFolderThumbnails()
      let updatedNotebooks = await library.notebooksInFolder(folderID: folder.id)
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedFolderNotebooks = updatedNotebooks
      }
    }
  }

  // Renames a notebook inside the expanded folder and refreshes the display.
  private func renameNotebookInFolder(_ notebook: NotebookMetadata, newName: String) {
    guard let folder = expandedFolder else { return }
    Task { @MainActor in
      await library.renameNotebook(notebookID: notebook.id, newDisplayName: newName)
      await library.loadBundles()
      await loadFolderThumbnails()
      let updatedNotebooks = await library.notebooksInFolder(folderID: folder.id)
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedFolderNotebooks = updatedNotebooks
      }
    }
  }

  // Moves a notebook out of the expanded folder to the root level.
  private func moveNotebookToRoot(_ notebook: NotebookMetadata) {
    guard let folder = expandedFolder else { return }
    Task { @MainActor in
      await library.moveNotebookToRoot(notebookID: notebook.id, fromFolderID: folder.id)
      await library.loadBundles()
      await loadFolderThumbnails()
      let updatedNotebooks = await library.notebooksInFolder(folderID: folder.id)
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedFolderNotebooks = updatedNotebooks
      }
    }
  }

  // Deletes a notebook inside the expanded folder and refreshes the display.
  private func deleteNotebookInFolder(_ notebook: NotebookMetadata) {
    guard let folder = expandedFolder else { return }
    Task { @MainActor in
      await library.deleteNotebook(notebookID: notebook.id)
      await library.loadBundles()
      await loadFolderThumbnails()
      let updatedNotebooks = await library.notebooksInFolder(folderID: folder.id)
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedFolderNotebooks = updatedNotebooks
      }
    }
  }

  // Loads thumbnail images for all folders.
  private func loadFolderThumbnails() async {
    var thumbnails: [String: [UIImage]] = [:]
    for folder in library.folders {
      var images: [UIImage] = []
      for imageData in folder.previewImages.prefix(4) {
        if let image = UIImage(data: imageData) {
          images.append(image)
        }
      }
      thumbnails[folder.id] = images
    }
    folderThumbnails = thumbnails
  }
}
// swiftlint:enable type_body_length

// View modifier that encapsulates all the modifiers applied to the dashboard main content.
// Breaks complex modifier chains into manageable pieces to help Swift compiler type-check.
struct DashboardViewModifiers: ViewModifier {
  let library: NotebookLibrary
  @Binding var renamingNotebook: NotebookMetadata?
  @Binding var renameText: String
  @Binding var deletingNotebook: NotebookMetadata?
  @Binding var renamingFolder: FolderMetadata?
  @Binding var deletingFolder: FolderMetadata?
  @Binding var showCreateFolderAlert: Bool
  @Binding var newFolderName: String
  @Binding var openErrorMessage: String?
  @Binding var isLoadingItems: Bool
  @Binding var activeSession: NotebookSession?
  @Binding var movingNotebook: NotebookMetadata?
  @Binding var expandedFolder: FolderMetadata?
  @Binding var expandedFolderNotebooks: [NotebookMetadata]
  let loadFolderThumbnails: () async -> Void

  func body(content: Content) -> some View {
    content
      .fontDesign(.rounded)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.hidden, for: .navigationBar)
      .tint(Color.offBlack)
      .task {
        isLoadingItems = true
        await library.loadBundles()
        await loadFolderThumbnails()
        isLoadingItems = false
      }
      .modifier(
        AlertModifiers(
          renamingNotebook: $renamingNotebook,
          renameText: $renameText,
          deletingNotebook: $deletingNotebook,
          renamingFolder: $renamingFolder,
          deletingFolder: $deletingFolder,
          showCreateFolderAlert: $showCreateFolderAlert,
          newFolderName: $newFolderName,
          openErrorMessage: $openErrorMessage,
          library: library,
          onCreateFolder: {
            await loadFolderThumbnails()
          }
        )
      )
      .modifier(
        DashboardSheetModifiers(
          activeSession: $activeSession,
          movingNotebook: $movingNotebook,
          expandedFolder: $expandedFolder,
          expandedFolderNotebooks: $expandedFolderNotebooks,
          renamingNotebook: $renamingNotebook,
          deletingNotebook: $deletingNotebook,
          library: library,
          showCreateFolderAlert: $showCreateFolderAlert,
          newFolderName: $newFolderName,
          isLoadingItems: $isLoadingItems,
          loadFolderThumbnails: loadFolderThumbnails
        ))
  }
}

// Encapsulates sheet and fullScreenCover modifiers for the dashboard.
struct DashboardSheetModifiers: ViewModifier {
  @Binding var activeSession: NotebookSession?
  @Binding var movingNotebook: NotebookMetadata?
  @Binding var expandedFolder: FolderMetadata?
  @Binding var expandedFolderNotebooks: [NotebookMetadata]
  @Binding var renamingNotebook: NotebookMetadata?
  @Binding var deletingNotebook: NotebookMetadata?
  let library: NotebookLibrary
  @Binding var showCreateFolderAlert: Bool
  @Binding var newFolderName: String
  @Binding var isLoadingItems: Bool
  let loadFolderThumbnails: () async -> Void

  func body(content: Content) -> some View {
    content
      // Used only for notebooks opened from folders (not the main grid).
      .fullScreenCover(
        item: $activeSession,
        onDismiss: {
          activeSession = nil
        },
        content: { session in
          EditorHostView(documentHandle: session.handle)
        }
      )
      .sheet(item: $movingNotebook) { notebook in
        MoveToFolderSheet(
          notebook: notebook,
          folders: library.folders,
          onSelectFolder: { folder in
            Task {
              await library.moveNotebookToFolder(notebookID: notebook.id, folderID: folder.id)
              await loadFolderThumbnails()
            }
            movingNotebook = nil
          },
          onCreateNewFolder: {
            movingNotebook = nil
            newFolderName = ""
            showCreateFolderAlert = true
          },
          onDismiss: {
            movingNotebook = nil
          }
        )
      }
      .modifier(
        DashboardNotificationModifiers(
          expandedFolder: $expandedFolder,
          expandedFolderNotebooks: $expandedFolderNotebooks,
          renamingNotebook: $renamingNotebook,
          deletingNotebook: $deletingNotebook,
          isLoadingItems: $isLoadingItems,
          library: library,
          loadFolderThumbnails: loadFolderThumbnails
        ))
  }
}

// Encapsulates notification and onChange modifiers for the dashboard.
struct DashboardNotificationModifiers: ViewModifier {
  @Binding var expandedFolder: FolderMetadata?
  @Binding var expandedFolderNotebooks: [NotebookMetadata]
  @Binding var renamingNotebook: NotebookMetadata?
  @Binding var deletingNotebook: NotebookMetadata?
  @Binding var isLoadingItems: Bool
  let library: NotebookLibrary
  let loadFolderThumbnails: () async -> Void

  func body(content: Content) -> some View {
    content
      .onReceive(NotificationCenter.default.publisher(for: .notebookPreviewUpdated)) { _ in
        Task {
          isLoadingItems = true
          await library.loadBundles()
          await loadFolderThumbnails()
          isLoadingItems = false

          // Refresh expanded folder contents if a folder is open.
          if let folder = expandedFolder {
            expandedFolderNotebooks = await library.notebooksInFolder(folderID: folder.id)
          }
        }
      }
      // Refresh folder contents when rename or delete dialogs are dismissed.
      .onChange(of: renamingNotebook) { _, newValue in
        if newValue == nil, let folder = expandedFolder {
          Task {
            expandedFolderNotebooks = await library.notebooksInFolder(folderID: folder.id)
          }
        }
      }
      .onChange(of: deletingNotebook) { _, newValue in
        if newValue == nil, let folder = expandedFolder {
          Task {
            expandedFolderNotebooks = await library.notebooksInFolder(folderID: folder.id)
          }
        }
      }
  }
}

// MARK: - Card Frame Preference Key

// Preference key for collecting notebook card frames for hero animation.
struct CardFramePreferenceKey: PreferenceKey {
  static var defaultValue: [String: CGRect] = [:]

  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue()) { _, new in new }
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
