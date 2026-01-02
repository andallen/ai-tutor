import SwiftUI
import UIKit
import UniformTypeIdentifiers

// swiftlint:disable file_length
// File length exception justified: Complex SwiftUI dashboard view with PDF document lifecycle,
// folder management, and notebook operations. Splitting would reduce cohesion and readability.

// The Dashboard shows a list of Notebooks and Folders, providing create, rename, delete, and open actions.
// It does not contain storage logic. It forwards user actions to the Notebook Library.
// swiftlint:disable type_body_length
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

  // Opens a PDF document session when a PDF document is tapped.
  @State private var activePDFSession: PDFDocumentSession?

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

  // MARK: - PDF Import State

  // Controls whether the PDF file picker is shown.
  @State private var showPDFPicker = false

  // Indicates whether a PDF import is in progress.
  @State private var isImportingPDF = false

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
          activePDFSession: $activePDFSession,
          movingNotebook: $movingNotebook,
          expandedFolder: $expandedFolder,
          expandedFolderNotebooks: $expandedFolderNotebooks,
          showPDFPicker: $showPDFPicker,
          isImportingPDF: $isImportingPDF,
          loadFolderThumbnails: loadFolderThumbnails
        )
      )
      .toolbar {
        toolbarContent
      }
  }

  // MARK: - Main Content

  private var mainContent: some View {
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
  }

  // MARK: - Toolbar Content

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    // Shows menu with create options. When folder is open: New Note, Import PDF.
    // When no folder is open: New Note, New Folder, Import PDF.
    ToolbarItem(placement: .navigationBarTrailing) {
      if let folder = expandedFolder {
        // Menu with notebook and PDF import options when folder is open.
        Menu {
          Button {
            createNotebookInExpandedFolder(folder)
          } label: {
            Label("New Note", systemImage: "doc.badge.plus")
          }

          Button {
            showPDFPicker = true
          } label: {
            Label("Import PDF", systemImage: "doc.richtext")
          }
        } label: {
          Image(systemName: "plus")
        }
      } else {
        // Menu with all options when no folder is open.
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

          Button {
            showPDFPicker = true
          } label: {
            Label("Import PDF", systemImage: "doc.richtext")
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
          case .pdfDocument(let pdfDocument):
            pdfDocumentCardView(pdfDocument: pdfDocument)
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
      delegate: FolderDropDelegate(
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
    }
  }

  // MARK: - PDF Document Card View

  @ViewBuilder
  private func pdfDocumentCardView(pdfDocument: PDFDocumentMetadata) -> some View {
    PDFDocumentCardButton(metadata: pdfDocument) {
      guard let uuid = UUID(uuidString: pdfDocument.id) else { return }
      openPDFDocument(documentID: uuid)
    }
    // Context menu for future actions (rename, delete, share).
  }

  // MARK: - Actions

  // Opens a notebook from the main grid.
  private func openNotebook(_ notebook: NotebookMetadata) {
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

  // Opens a PDF document for editing.
  // Loads the document data and creates a session for the PDF editor.
  private func openPDFDocument(documentID: UUID) {
    Task {
      do {
        let result = try await library.openPDFDocument(documentID: documentID)
        activePDFSession = PDFDocumentSession(
          id: documentID.uuidString,
          handle: result.handle,
          noteDocument: result.noteDocument,
          pdfDocument: result.pdfDocument
        )
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
  private func openNotebookFromFolder(_ notebook: NotebookMetadata) {
    // Close the folder first, then open the notebook.
    closeFolder()

    // Small delay to allow folder close animation to start.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      openNotebook(notebook)
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
  @Binding var activePDFSession: PDFDocumentSession?
  @Binding var movingNotebook: NotebookMetadata?
  @Binding var expandedFolder: FolderMetadata?
  @Binding var expandedFolderNotebooks: [NotebookMetadata]
  @Binding var showPDFPicker: Bool
  @Binding var isImportingPDF: Bool
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
          activePDFSession: $activePDFSession,
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
        )
      )
      .modifier(
        PDFImportModifier(
          showPDFPicker: $showPDFPicker,
          isImportingPDF: $isImportingPDF,
          openErrorMessage: $openErrorMessage,
          library: library
        ))
  }
}

// Encapsulates sheet and fullScreenCover modifiers for the dashboard.
struct DashboardSheetModifiers: ViewModifier {
  @Binding var activeSession: NotebookSession?
  @Binding var activePDFSession: PDFDocumentSession?
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
      .fullScreenCover(
        item: $activeSession,
        onDismiss: {
          activeSession = nil
        },
        content: { session in
          EditorHostView(documentHandle: session.handle)
        }
      )
      .fullScreenCover(
        item: $activePDFSession,
        onDismiss: {
          activePDFSession = nil
        },
        content: { session in
          PDFEditorHostView(session: session)
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

// Encapsulates the PDF file importer modifier for the dashboard.
// Handles file selection and import coordination.
struct PDFImportModifier: ViewModifier {
  @Binding var showPDFPicker: Bool
  @Binding var isImportingPDF: Bool
  @Binding var openErrorMessage: String?
  let library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .fileImporter(
        isPresented: $showPDFPicker,
        allowedContentTypes: [.pdf],
        allowsMultipleSelection: false
      ) { result in
        handleFileImportResult(result)
      }
      .overlay {
        if isImportingPDF {
          importingOverlay
        }
      }
  }

  // Overlay shown while a PDF import is in progress.
  private var importingOverlay: some View {
    ZStack {
      Color.black.opacity(0.3)
        .ignoresSafeArea()

      VStack(spacing: 12) {
        ProgressView()
          .tint(.white)
        Text("Importing PDF...")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.white)
      }
      .padding(24)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
  }

  // Handles the result from the file importer.
  private func handleFileImportResult(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }
      importPDF(from: url)
    case .failure(let error):
      openErrorMessage = error.localizedDescription
    }
  }

  // Imports a PDF from the selected URL.
  private func importPDF(from url: URL) {
    Task { @MainActor in
      isImportingPDF = true
      defer { isImportingPDF = false }

      // Start security-scoped access for the file.
      let didStartAccess = url.startAccessingSecurityScopedResource()
      defer {
        if didStartAccess {
          url.stopAccessingSecurityScopedResource()
        }
      }

      do {
        let coordinator = ImportCoordinator.createDefault()
        _ = try await coordinator.importPDF(from: url, displayName: nil)
        // Refresh the library to show the new document.
        await library.loadBundles()
      } catch {
        openErrorMessage = error.localizedDescription
      }
    }
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
