import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Card Frame Store

// Reference type for storing card frames so UIKit can read current values during transitions.
// SwiftUI updates this via preferences, and UIKit queries it at dismiss time.
// Uses a class (reference type) so the same instance is accessible from both SwiftUI and UIKit.
final class CardFrameStore {
  var frames: [String: CGRect] = [:]
}

// MARK: - AI Button Wrapper

// Wraps AIButtonView for use in SwiftUI. The button appears at the bottom-right
// of the dashboard and notebook editor views.
struct AIButtonRepresentable: UIViewRepresentable {
  // Callback invoked when the button is tapped.
  var tapped: (() -> Void)?
  // When true, hides the glass background so only the black circle is visible.
  var isGlassHidden: Bool = false

  func makeUIView(context: Context) -> AIButtonView {
    let button = AIButtonView()
    button.tapped = tapped
    button.isGlassHidden = isGlassHidden
    return button
  }

  func updateUIView(_ uiView: AIButtonView, context: Context) {
    uiView.tapped = tapped
    uiView.isGlassHidden = isGlassHidden
  }
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

  // Opens a PDF document session when a PDF document is tapped.
  @State private var activePDFSession: PDFDocumentSession?

  // Tracks an error message when opening a notebook fails.
  @State private var openErrorMessage: String?

  // Tracks whether the dashboard is loading items.
  @State private var isLoadingItems = true

  // MARK: - PDF State

  // Tracks which PDF document is being renamed.
  @State private var renamingPDF: PDFDocumentMetadata?

  // Tracks which PDF document is being confirmed for deletion.
  @State private var deletingPDF: PDFDocumentMetadata?

  // Tracks which PDF document is being moved to a folder.
  @State private var movingPDF: PDFDocumentMetadata?

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

  // MARK: - Custom Drag State

  // The notebook currently being dragged (nil when not dragging).
  @State private var draggedNotebook: NotebookMetadata?

  // The source frame of the card being dragged (for sizing the overlay).
  @State private var dragSourceFrame: CGRect = .zero

  // The current position of the drag (finger position in global coordinates).
  @State private var dragPosition: CGPoint = .zero

  // Tracks which folder the drag is currently over (for drop targeting).
  @State private var dragTargetFolderID: String?

  // Tracks which notebook the drag is currently over (for folder creation).
  @State private var dragTargetNotebookID: String?

  // Stores folder frames for hit testing during drag.
  @State private var folderFrames: [String: CGRect] = [:]

  // MARK: - Folder Expansion State

  // Tracks which folder is currently expanded (nil when no folder is open).
  @State private var expandedFolder: FolderMetadata?

  // Notebooks loaded for the currently expanded folder.
  @State private var expandedFolderNotebooks: [NotebookMetadata] = []

  // PDFs loaded for the currently expanded folder.
  @State private var expandedFolderPDFs: [PDFDocumentMetadata] = []

  // The source frame of the folder card when expansion started.
  // Used to animate the overlay from the card's position.
  @State private var expandedFolderSourceFrame: CGRect = .zero

  // Controls the overlay's expansion animation state.
  // Separate from expandedFolder so the overlay stays in hierarchy during close animation.
  @State private var isOverlayExpanded: Bool = false

  // Controls when the folder card is hidden during overlay expansion.
  // Separate from isOverlayExpanded so the card can start appearing before overlay contracts.
  @State private var isFolderCardHidden: Bool = false

  // MARK: - PDF Import State

  // Controls whether the PDF file picker is shown.
  @State private var showPDFPicker = false

  // Indicates whether a PDF import is in progress.
  @State private var isImportingPDF = false

  // MARK: - Notebook Hero Transition State

  // Holds the transition coordinator for the currently open notebook.
  // Strong reference prevents deallocation during the transition.
  @State private var transitionCoordinator: NotebookTransitionCoordinator?

  // Reference type for card frames so UIKit can query current values during dismiss.
  // Using @State with a class preserves the reference across view updates.
  @State private var cardFrameStore = CardFrameStore()

  // MARK: - Custom Context Menu State

  // Tracks the active context menu state (nil when no menu is shown).
  @State private var contextMenuState: ContextMenuState?

  // MARK: - AI Button State

  // Controls visibility of the AI button. Fades out during notebook transitions.
  @State private var isAIButtonVisible = true
  // Tracks whether the AI overlay is expanded.
  @State private var isAIOverlayExpanded = false

  var body: some View {
    mainContent
      .modifier(
        DashboardViewModifiers(
          library: library,
          renamingNotebook: $renamingNotebook,
          renameText: $renameText,
          deletingNotebook: $deletingNotebook,
          renamingPDF: $renamingPDF,
          deletingPDF: $deletingPDF,
          movingPDF: $movingPDF,
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
    GeometryReader { _ in
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

        // Folder expansion overlay - single expanding view that animates from card position.
        // Uses scale-based animation for smooth expand/collapse transitions.
        if let folder = expandedFolder {
          FolderOverlay(
            folder: folder,
            notebooks: expandedFolderNotebooks,
            pdfDocuments: expandedFolderPDFs,
            sourceFrame: expandedFolderSourceFrame,
            isExpanded: isOverlayExpanded,
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
            onPDFTap: { pdf in
              openPDFFromFolder(pdf)
            },
            onMovePDFToRoot: { pdf in
              movePDFToRoot(pdf)
            },
            onRenamePDF: { pdf, newName in
              renamePDFInFolder(pdf, newName: newName)
            },
            onDeletePDF: { pdf in
              deletePDFInFolder(pdf)
            },
            onDismiss: {
              closeFolder()
            }
          )
          .zIndex(100)
        }

        // Custom context menu overlay.
        if let menuState = contextMenuState {
          ContextMenuOverlay(
            state: menuState,
            actions: buildContextMenuActions(for: menuState),
            onDismiss: {
              contextMenuState = nil
            }
          )
          .zIndex(200)
        }

        // Drag overlay showing the notebook card following the finger.
        if let notebook = draggedNotebook {
          dragOverlay(for: notebook)
            .zIndex(400)
        }

        // AI overlay, dim background, and button at bottom-right corner.
        // The overlay expands from the button with liquid glass animation.
        // Tapping outside or tapping the button again dismisses the overlay.
        aiOverlaySection
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

  // MARK: - AI Overlay Section

  // Combines the AI button and liquid glass overlay.
  // The overlay expands from the button's bottom-right corner, always covering the button.
  // The button glass fades in sync with the overlay animation; the black circle stays visible.
  private var aiOverlaySection: some View {
    GeometryReader { geometry in
      let buttonSize: CGFloat = 48
      let buttonRadius: CGFloat = buttonSize / 2

      // Button center position.
      let buttonX = geometry.size.width - geometry.safeAreaInsets.trailing - 20 - buttonRadius
      let buttonY = geometry.size.height - geometry.safeAreaInsets.bottom - buttonSize

      // Button's bottom-right corner (anchor point for overlay animation).
      let buttonBottomRightX = buttonX + buttonRadius
      let buttonBottomRightY = buttonY + buttonRadius

      ZStack {
        // Tap catcher to dismiss overlay (no visible dimming).
        if isAIOverlayExpanded {
          Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
              withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                isAIOverlayExpanded = false
              }
            }
            .zIndex(0)
        }

        // Liquid glass overlay anchored to button's bottom-right corner.
        // Always in hierarchy so animation is smooth (no transition).
        aiOverlayGlass(
          buttonBottomRightX: buttonBottomRightX,
          buttonBottomRightY: buttonBottomRightY
        )
        .zIndex(1)

        // AI button stays fully visible at all times - no changes during overlay animation.
        AIButtonRepresentable(
          tapped: {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
              isAIOverlayExpanded.toggle()
            }
          },
          isGlassHidden: false
        )
        .frame(width: buttonSize, height: buttonSize)
        .position(x: buttonX, y: buttonY)
        .zIndex(2)
      }
    }
    .ignoresSafeArea()
    .opacity(isAIButtonVisible ? 1 : 0)
    .animation(.easeInOut(duration: 0.22), value: isAIButtonVisible)
    .zIndex(150)
    .allowsHitTesting(isAIButtonVisible)
    .onChange(of: isAIButtonVisible) { _, visible in
      // Collapse overlay when AI button is hidden (during notebook transitions).
      if visible == false && isAIOverlayExpanded {
        isAIOverlayExpanded = false
      }
    }
  }

  // The liquid glass overlay panel that expands from the button's bottom-right corner.
  // Scales from bottom-trailing so the corner stays fixed during animation.
  @ViewBuilder
  private func aiOverlayGlass(
    buttonBottomRightX: CGFloat,
    buttonBottomRightY: CGFloat
  ) -> some View {
    let overlayWidth: CGFloat = 360
    let overlayHeight: CGFloat = 400
    let cornerRadius: CGFloat = 24
    let buttonSize: CGFloat = 48

    // Position overlay so its bottom-right corner aligns with button's bottom-right corner.
    let overlayCenterX = buttonBottomRightX - overlayWidth / 2
    let overlayCenterY = buttonBottomRightY - overlayHeight / 2

    // Collapsed scale (overlay shrinks to button size).
    let collapsedScale = buttonSize / overlayWidth

    Group {
      if #available(iOS 26.0, *) {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.clear)
          .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
          .frame(width: overlayWidth, height: overlayHeight)
      } else {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(.ultraThinMaterial)
          .frame(width: overlayWidth, height: overlayHeight)
      }
    }
    .position(x: overlayCenterX, y: overlayCenterY)
    .scaleEffect(isAIOverlayExpanded ? 1.0 : collapsedScale, anchor: .bottomTrailing)
    .opacity(isAIOverlayExpanded ? 1 : 0)
    .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isAIOverlayExpanded)
    .allowsHitTesting(isAIOverlayExpanded)
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
    // Check if this notebook's context menu is currently shown.
    let isContextMenuActive = contextMenuState?.matchesNotebook(notebook) == true
    // Check if this notebook is currently being dragged.
    let isBeingDragged = draggedNotebook?.id == notebook.id
    // Check if another notebook is being dragged over this one.
    let isDragTarget = dragTargetNotebookID == notebook.id && draggedNotebook?.id != notebook.id

    // ZStack to layer the underlay behind the card without scaling it.
    ZStack {
      // Grey underlay that stays at full size when the card contracts.
      dropTargetUnderlay(isActive: isDragTarget)

      // The notebook card that scales down when targeted.
      notebookCardButton(for: notebook, isDragTarget: isDragTarget)
        .scaleEffect(
          isContextMenuActive ? 1.08 : (isDragTarget ? 0.82 : 1.0),
          anchor: .center
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isContextMenuActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragTarget)
    }
    .background(notebookCardFrameCapture(for: notebook))
    .opacity(isBeingDragged ? 0 : 1)
    .zIndex(isContextMenuActive ? 300 : 0)
  }

  // Builds the notebook card button with all its handlers.
  @ViewBuilder
  private func notebookCardButton(for notebook: NotebookMetadata, isDragTarget: Bool) -> some View {
    NotebookCardButton(
      notebook: notebook,
      action: {
        openNotebook(notebook)
      },
      onRename: {
        renameText = notebook.displayName
        renamingNotebook = notebook
      },
      onMoveToFolder: library.folders.isEmpty
        ? nil
        : {
          movingNotebook = notebook
        },
      onDelete: {
        deletingNotebook = notebook
      },
      onLongPress: { frame, cardHeight in
        contextMenuState = ContextMenuState(
          item: .notebook(notebook),
          sourceFrame: frame,
          cardHeight: cardHeight
        )
      },
      onDragStart: { notebook, frame, position in
        handleDragStart(notebook: notebook, frame: frame, position: position)
      },
      onDragMove: { position in
        handleDragMove(position: position)
      },
      onDragEnd: { position in
        handleDragEnd(position: position)
      },
      titleOpacity: isDragTarget ? 0 : 1
    )
  }

  // Captures the card's frame for hero animation and drag hit testing.
  @ViewBuilder
  private func notebookCardFrameCapture(for notebook: NotebookMetadata) -> some View {
    GeometryReader { geometry in
      Color.clear
        .preference(
          key: CardFramePreferenceKey.self,
          value: [notebook.id: geometry.frame(in: .global)]
        )
    }
  }

  // Builds the grey underlay shown when a notebook is targeted for folder creation.
  // The underlay stays at full size while the card scales down, creating a visible background.
  @ViewBuilder
  private func dropTargetUnderlay(isActive: Bool) -> some View {
    GeometryReader { geometry in
      let cardHeight = geometry.size.height - 36  // Subtract title area.

      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color(white: 0.88))
        .frame(width: geometry.size.width, height: cardHeight)
        .opacity(isActive ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
  }

  // MARK: - Folder Card View

  @ViewBuilder
  private func folderCardView(folder: FolderMetadata) -> some View {
    // Check if this folder is targeted by system drag-drop or custom drag.
    let isTargeted = dropTargetFolderID == folder.id || dragTargetFolderID == folder.id
    let thumbnails = folderThumbnails[folder.id] ?? []
    let isExpanded = expandedFolder?.id == folder.id
    // Check if this folder's context menu is currently shown.
    let isContextMenuActive = contextMenuState?.matchesFolder(folder) == true

    // Calculate offset from card center to screen center for the appearance animation.
    let appearanceOffset = calculateFolderAppearanceOffset(
      folder: folder,
      isExpanded: isExpanded
    )

    let config = FolderCardConfiguration(
      folder: folder,
      thumbnails: thumbnails,
      isExpanded: isExpanded,
      isContextMenuActive: isContextMenuActive,
      isTargeted: isTargeted,
      appearanceOffset: appearanceOffset
    )

    folderCardButton(config: config)
  }

  // Calculates the offset for folder card appearance animation.
  // Makes the card appear to move FROM the overlay center TO its actual position.
  private func calculateFolderAppearanceOffset(folder: FolderMetadata, isExpanded: Bool) -> CGSize {
    guard isExpanded, let cardFrame = folderFrames[folder.id] else {
      return .zero
    }
    let screenBounds = UIScreen.main.bounds
    let screenCenter = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
    let cardCenter = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
    let fullOffset = CGSize(
      width: screenCenter.x - cardCenter.x,
      height: screenCenter.y - cardCenter.y
    )
    // Reduce the offset during contraction so the card starts closer to its position.
    let multiplier: CGFloat = isFolderCardHidden ? 1.0 : 0.35
    return CGSize(
      width: fullOffset.width * multiplier,
      height: fullOffset.height * multiplier
    )
  }

  // Configuration for folder card rendering.
  private struct FolderCardConfiguration {
    let folder: FolderMetadata
    let thumbnails: [UIImage]
    let isExpanded: Bool
    let isContextMenuActive: Bool
    let isTargeted: Bool
    let appearanceOffset: CGSize
  }

  // Builds the folder card button with all its handlers and modifiers.
  @ViewBuilder
  private func folderCardButton(config: FolderCardConfiguration) -> some View {
    FolderCardButton(
      folder: config.folder,
      thumbnails: config.thumbnails,
      action: {
        openFolder(config.folder)
      },
      onRename: {
        renameText = config.folder.displayName
        renamingFolder = config.folder
      },
      onDelete: {
        deletingFolder = config.folder
      },
      onLongPress: { frame, cardHeight in
        contextMenuState = ContextMenuState(
          item: .folder(config.folder, thumbnails: config.thumbnails),
          sourceFrame: frame,
          cardHeight: cardHeight
        )
      },
      previewOpacity: (config.isExpanded && isFolderCardHidden) ? 0 : 1,
      appearanceOffset: config.appearanceOffset
    )
    .background(folderFrameCapture(for: config.folder))
    .zIndex(config.isContextMenuActive ? 300 : 0)
    .scaleEffect(
      config.isContextMenuActive ? 1.08 : (config.isTargeted ? 1.08 : 1.0),
      anchor: .top
    )
    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: config.isContextMenuActive)
    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: config.isTargeted)
    .onDrop(
      of: [.notebookID],
      delegate: createFolderDropDelegate(for: config.folder)
    )
  }

  // Captures the folder's frame for expansion animation and drag hit testing.
  @ViewBuilder
  private func folderFrameCapture(for folder: FolderMetadata) -> some View {
    GeometryReader { geometry in
      Color.clear
        .onAppear {
          folderFrames[folder.id] = geometry.frame(in: .global)
        }
        .onChange(of: geometry.frame(in: .global)) { _, newFrame in
          folderFrames[folder.id] = newFrame
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
    .contextMenu {
      Button {
        renameText = pdfDocument.displayName
        renamingPDF = pdfDocument
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      if !library.folders.isEmpty {
        Button {
          movingPDF = pdfDocument
        } label: {
          Label("Move to Folder", systemImage: "folder")
        }
      }

      Button(role: .destructive) {
        deletingPDF = pdfDocument
      } label: {
        Label("Delete", systemImage: "trash")
      }
    } preview: {
      // Shows only the card in the preview, keeping the title visible in place.
      PDFDocumentCardContextMenuPreview(pdfDocument: pdfDocument)
    }
  }

  // Creates a drop delegate for folder drag-and-drop operations.
  // Used for system drag-and-drop (if notebooks are dragged from elsewhere).
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
          // Fade the AI button back in when the notebook closes.
          isAIButtonVisible = true
          // Refresh the dashboard after dismissal to show updated previews.
          Task {
            await library?.loadBundles()
          }
        }

        // Fade the AI button out as the notebook opens.
        isAIButtonVisible = false

        // Get the root view controller and present.
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController
        {
          coordinator.present(from: rootVC)
        }

        // Hold a strong reference to prevent deallocation during transition.
        transitionCoordinator = coordinator
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

  // Opens a folder and loads its notebooks and PDFs for display in the overlay.
  // Uses scale-based animation from the folder card's position.
  private func openFolder(_ folder: FolderMetadata) {
    // Capture the folder card's current frame for the expansion animation.
    // The frame includes the title area, so subtract 36pt for just the card portion.
    guard let fullFrame = folderFrames[folder.id] else { return }
    let cardFrame = CGRect(
      x: fullFrame.minX,
      y: fullFrame.minY,
      width: fullFrame.width,
      height: fullFrame.height - 36
    )
    expandedFolderSourceFrame = cardFrame

    Task {
      // Load notebooks and PDFs before showing overlay.
      let notebooks = await library.notebooksInFolder(folderID: folder.id)
      let pdfs = await library.pdfDocumentsInFolder(folderID: folder.id)
      expandedFolderNotebooks = notebooks
      expandedFolderPDFs = pdfs

      // Show overlay at source position (collapsed state).
      expandedFolder = folder

      // Hide the folder card and animate expansion to center.
      DispatchQueue.main.async {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
          isFolderCardHidden = true
          isOverlayExpanded = true
        }
      }
    }
  }

  // Closes the expanded folder with reverse animation back to the source card.
  private func closeFolder() {
    // Card animation (opacity + movement) is handled in FolderCard.swift.
    // Setting isFolderCardHidden triggers the card's internal animations.
    isFolderCardHidden = false

    // Overlay contraction animation.
    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
      isOverlayExpanded = false
    }

    // Remove overlay from hierarchy after animation completes.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      expandedFolder = nil
      expandedFolderNotebooks = []
      expandedFolderPDFs = []
      expandedFolderSourceFrame = .zero
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

  // MARK: - PDF Folder Operations

  // Opens a PDF document from the expanded folder.
  private func openPDFFromFolder(_ pdf: PDFDocumentMetadata) {
    guard let uuid = UUID(uuidString: pdf.id) else { return }
    openPDFDocument(documentID: uuid)
  }

  // Renames a PDF inside the expanded folder and refreshes the display.
  private func renamePDFInFolder(_ pdf: PDFDocumentMetadata, newName: String) {
    guard let folder = expandedFolder else { return }
    Task { @MainActor in
      await library.renamePDFDocument(documentID: pdf.id, newDisplayName: newName)
      await library.loadBundles()
      await loadFolderThumbnails()
      let updatedPDFs = await library.pdfDocumentsInFolder(folderID: folder.id)
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedFolderPDFs = updatedPDFs
      }
    }
  }

  // Moves a PDF out of the expanded folder to the root level.
  private func movePDFToRoot(_ pdf: PDFDocumentMetadata) {
    guard let folder = expandedFolder else { return }
    Task { @MainActor in
      await library.movePDFDocumentToRoot(documentID: pdf.id)
      await library.loadBundles()
      await loadFolderThumbnails()
      let updatedPDFs = await library.pdfDocumentsInFolder(folderID: folder.id)
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedFolderPDFs = updatedPDFs
      }
    }
  }

  // Deletes a PDF inside the expanded folder and refreshes the display.
  private func deletePDFInFolder(_ pdf: PDFDocumentMetadata) {
    guard let folder = expandedFolder else { return }
    Task { @MainActor in
      await library.deletePDFDocument(documentID: pdf.id)
      await library.loadBundles()
      await loadFolderThumbnails()
      let updatedPDFs = await library.pdfDocumentsInFolder(folderID: folder.id)
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedFolderPDFs = updatedPDFs
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

  // MARK: - Drag Overlay

  // Builds the floating card overlay that follows the finger during drag.
  @ViewBuilder
  private func dragOverlay(for notebook: NotebookMetadata) -> some View {
    let cardWidth = dragSourceFrame.width
    let cardHeight = dragSourceFrame.height - 36  // Subtract title area height.

    NotebookCardPreview(notebook: notebook, dimOpacity: 0)
      .frame(width: cardWidth, height: cardHeight)
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
      .scaleEffect(1.05)
      // Position the card centered under the finger.
      .position(x: dragPosition.x, y: dragPosition.y - cardHeight / 2 - 20)
      .allowsHitTesting(false)
  }

  // MARK: - Drag Handlers

  // Called when a drag starts after long press on a notebook card.
  private func handleDragStart(notebook: NotebookMetadata, frame: CGRect, position: CGPoint) {
    // Dismiss context menu when drag starts.
    withAnimation(.easeOut(duration: 0.15)) {
      contextMenuState = nil
    }

    // Set up drag state.
    draggedNotebook = notebook
    dragSourceFrame = frame
    dragPosition = position
  }

  // Called during drag as the finger moves.
  private func handleDragMove(position: CGPoint) {
    dragPosition = position

    // Check which folder (if any) the finger is over.
    var foundFolderTarget: String?
    for (folderID, frame) in folderFrames where frame.contains(position) {
      foundFolderTarget = folderID
      break
    }

    // Check which notebook (if any) the finger is over (excluding the dragged one).
    // Uses cardFrameStore.frames (populated via preferences) which is more reliable than onAppear.
    // Only consider notebooks that still exist in the library (not moved to folders).
    var foundNotebookTarget: String?
    if foundFolderTarget == nil, let draggedID = draggedNotebook?.id {
      let existingNotebookIDs = Set(library.notebooks.map { $0.id })
      for (notebookID, frame) in cardFrameStore.frames {
        if notebookID != draggedID
          && existingNotebookIDs.contains(notebookID)
          && frame.contains(position)
        {
          foundNotebookTarget = notebookID
          break
        }
      }
    }

    // Update folder target with animation if changed.
    if dragTargetFolderID != foundFolderTarget {
      withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
        dragTargetFolderID = foundFolderTarget
      }
    }

    // Update notebook target with animation if changed.
    if dragTargetNotebookID != foundNotebookTarget {
      withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
        dragTargetNotebookID = foundNotebookTarget
      }
    }
  }

  // Called when drag ends (finger released).
  private func handleDragEnd(position: CGPoint) {
    guard let notebook = draggedNotebook else {
      resetDragState()
      return
    }

    // Check if we're over a folder.
    if let targetFolderID = dragTargetFolderID {
      // Move notebook to the existing folder.
      Task {
        await library.moveNotebookToFolder(notebookID: notebook.id, folderID: targetFolderID)
        await library.loadBundles()
        await loadFolderThumbnails()
      }
      resetDragState()
      return
    }

    // Check if we're over another notebook to create a folder.
    if let targetNotebookID = dragTargetNotebookID,
      let targetNotebook = library.notebooks.first(where: { $0.id == targetNotebookID })
    {
      // Create folder from the two notebooks.
      createFolderFromNotebooks(
        draggedNotebook: notebook,
        targetNotebook: targetNotebook
      )
      return
    }

    // No valid target, just reset.
    resetDragState()
  }

  // Resets all drag-related state.
  private func resetDragState() {
    withAnimation(.easeOut(duration: 0.2)) {
      draggedNotebook = nil
      dragTargetFolderID = nil
      dragTargetNotebookID = nil
    }
    dragSourceFrame = .zero
    dragPosition = .zero
  }

  // Creates a new folder from two notebooks.
  private func createFolderFromNotebooks(
    draggedNotebook: NotebookMetadata,
    targetNotebook: NotebookMetadata
  ) {
    // Reset drag state immediately.
    withAnimation(.easeOut(duration: 0.2)) {
      self.draggedNotebook = nil
      dragTargetNotebookID = nil
    }
    dragSourceFrame = .zero
    dragPosition = .zero
    dragTargetFolderID = nil

    // Create the folder and move notebooks.
    Task { @MainActor in
      // Create an untitled folder.
      let folderID = await library.createFolder(displayName: "Untitled Folder")

      // Move both notebooks to the new folder.
      if let folderID {
        await library.moveNotebookToFolder(notebookID: draggedNotebook.id, folderID: folderID)
        await library.moveNotebookToFolder(notebookID: targetNotebook.id, folderID: folderID)
      }

      // Reload to show the new folder.
      await library.loadBundles()
      await loadFolderThumbnails()
    }
  }

  // MARK: - Context Menu Actions

  // Builds the context menu actions for the given menu state.
  private func buildContextMenuActions(for state: ContextMenuState) -> [ContextMenuAction] {
    switch state.item {
    case .notebook(let notebook):
      return buildNotebookContextMenuActions(for: notebook)
    case .folder(let folder, _):
      return buildFolderContextMenuActions(for: folder)
    }
  }

  // Builds context menu actions for a notebook.
  private func buildNotebookContextMenuActions(for notebook: NotebookMetadata)
    -> [ContextMenuAction]
  {
    var actions: [ContextMenuAction] = [
      ContextMenuAction(title: "Rename", systemImage: "pencil") {
        renameText = notebook.displayName
        renamingNotebook = notebook
      }
    ]

    // Add "Move to Folder" if folders exist.
    if !library.folders.isEmpty {
      actions.append(
        ContextMenuAction(title: "Move to Folder", systemImage: "folder") {
          movingNotebook = notebook
        })
    }

    actions.append(
      ContextMenuAction(
        title: "Delete",
        systemImage: "trash",
        isDestructive: true
      ) {
        deletingNotebook = notebook
      })

    return actions
  }

  // Builds context menu actions for a folder.
  private func buildFolderContextMenuActions(for folder: FolderMetadata) -> [ContextMenuAction] {
    [
      ContextMenuAction(title: "Rename Folder", systemImage: "pencil") {
        renameText = folder.displayName
        renamingFolder = folder
      },
      ContextMenuAction(
        title: "Delete Folder",
        systemImage: "trash",
        isDestructive: true
      ) {
        deletingFolder = folder
      },
    ]
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
  @Binding var renamingPDF: PDFDocumentMetadata?
  @Binding var deletingPDF: PDFDocumentMetadata?
  @Binding var movingPDF: PDFDocumentMetadata?
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
        await loadInitialData()
      }
      .modifier(alertModifiers)
      .modifier(sheetModifiers)
      .modifier(pdfImportModifier)
  }

  // Loads initial dashboard data on appearance.
  private func loadInitialData() async {
    isLoadingItems = true
    await library.loadBundles()
    await loadFolderThumbnails()
    isLoadingItems = false
  }

  // Alert modifiers for rename, delete, and create operations.
  private var alertModifiers: AlertModifiers {
    AlertModifiers(
      renamingNotebook: $renamingNotebook,
      renameText: $renameText,
      deletingNotebook: $deletingNotebook,
      renamingPDF: $renamingPDF,
      deletingPDF: $deletingPDF,
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
  }

  // Sheet modifiers for sessions and move operations.
  private var sheetModifiers: DashboardSheetModifiers {
    DashboardSheetModifiers(
      activeSession: $activeSession,
      activePDFSession: $activePDFSession,
      movingNotebook: $movingNotebook,
      movingPDF: $movingPDF,
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
  }

  // PDF import modifier for file picker and import coordination.
  private var pdfImportModifier: PDFImportModifier {
    PDFImportModifier(
      showPDFPicker: $showPDFPicker,
      isImportingPDF: $isImportingPDF,
      openErrorMessage: $openErrorMessage,
      library: library
    )
  }
}

// Encapsulates sheet and fullScreenCover modifiers for the dashboard.
struct DashboardSheetModifiers: ViewModifier {
  @Binding var activeSession: NotebookSession?
  @Binding var activePDFSession: PDFDocumentSession?
  @Binding var movingNotebook: NotebookMetadata?
  @Binding var movingPDF: PDFDocumentMetadata?
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
        onDismiss: { activeSession = nil },
        content: { session in
          EditorHostView(documentHandle: session.handle)
            .ignoresSafeArea()
        }
      )
      .fullScreenCover(
        item: $activePDFSession,
        onDismiss: { activePDFSession = nil },
        content: { session in
          PDFEditorHostView(session: session)
        }
      )
      .sheet(item: $movingNotebook) { notebook in
        moveNotebookSheet(for: notebook)
      }
      .sheet(item: $movingPDF) { pdf in
        movePDFSheet(for: pdf)
      }
      .modifier(notificationModifiers)
  }

  // Builds the move-to-folder sheet for a notebook.
  private func moveNotebookSheet(for notebook: NotebookMetadata) -> some View {
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

  // Builds the move-to-folder sheet for a PDF document.
  private func movePDFSheet(for pdf: PDFDocumentMetadata) -> some View {
    PDFMoveToFolderSheet(
      pdfDocument: pdf,
      folders: library.folders,
      onSelectFolder: { folder in
        Task {
          await library.movePDFDocumentToFolder(documentID: pdf.id, folderID: folder.id)
          await loadFolderThumbnails()
        }
        movingPDF = nil
      },
      onCreateNewFolder: {
        movingPDF = nil
        newFolderName = ""
        showCreateFolderAlert = true
      },
      onDismiss: {
        movingPDF = nil
      }
    )
  }

  // Notification modifiers for dashboard updates.
  private var notificationModifiers: DashboardNotificationModifiers {
    DashboardNotificationModifiers(
      expandedFolder: $expandedFolder,
      expandedFolderNotebooks: $expandedFolderNotebooks,
      renamingNotebook: $renamingNotebook,
      deletingNotebook: $deletingNotebook,
      isLoadingItems: $isLoadingItems,
      library: library,
      loadFolderThumbnails: loadFolderThumbnails
    )
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
