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

// MARK: - Window Reader

// Captures a reference to the UIWindow for adding animated views during drop operations.
// Uses UIViewRepresentable to access the UIKit view hierarchy from SwiftUI.
struct WindowReader: UIViewRepresentable {
  let onWindow: (UIWindow?) -> Void

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    DispatchQueue.main.async { onWindow(view.window) }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async { onWindow(uiView.window) }
  }
}

// MARK: - AI Button Wrapper

// Wraps AIButtonView for use in SwiftUI. The button appears at the bottom-right
// of the dashboard and notebook editor views.
struct AIButtonRepresentable: UIViewRepresentable {
  // Callback invoked when the button is tapped.
  var tapped: (() -> Void)?
  // When true, the circle yields toward upper-left. When false, it returns to center.
  var isYielded: Bool = false
  // Duration for the return animation. Defaults to standard timing.
  var returnAnimationDuration: TimeInterval = 0.44

  func makeUIView(context: Context) -> AIButtonView {
    let button = AIButtonView()
    button.tapped = tapped
    button.isYielded = isYielded
    button.returnAnimationDuration = returnAnimationDuration
    return button
  }

  func updateUIView(_ uiView: AIButtonView, context: Context) {
    uiView.tapped = tapped
    uiView.returnAnimationDuration = returnAnimationDuration
    uiView.isYielded = isYielded
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

  // MARK: - PDF Drag State

  // The PDF currently being dragged (nil when not dragging).
  @State private var draggedPDF: PDFDocumentMetadata?

  // The source frame of the PDF card being dragged.
  @State private var pdfDragSourceFrame: CGRect = .zero

  // The current position of the PDF drag.
  @State private var pdfDragPosition: CGPoint = .zero

  // Tracks which PDF the drag is currently over (for future folder creation with PDFs).
  @State private var dragTargetPDFID: String?

  // Stores PDF card frames for hit testing during drag.
  @State private var pdfCardFrames: [String: CGRect] = [:]

  // MARK: - Folder Drag Source Tracking

  // Tracks the source folder ID when dragging a notebook out of a folder.
  // Used to call moveNotebookToRoot when the drag ends.
  @State private var dragSourceFolderID: String?

  // Tracks the source folder ID when dragging a PDF out of a folder.
  @State private var pdfDragSourceFolderID: String?

  // Tracks whether a drag from the folder overlay has exited the overlay bounds.
  // Used to trigger overlay dismiss animation only when drag crosses the boundary.
  @State private var hasDragExitedOverlayBounds: Bool = false

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
  // Tracks whether the AI overlay is expanded (slides up when true).
  @State private var isAIOverlayExpanded = false
  // Text entered in the AI chat input bar.
  @State private var aiChatText: String = ""

  // MARK: - Search State

  // Controls whether the search overlay is expanded.
  @State private var isSearchOverlayExpanded = false
  // Text entered in the search bar.
  @State private var searchText: String = ""
  // Search results from SearchService.
  @State private var searchResults: [SearchResult] = []
  // Whether a search is currently in progress.
  @State private var isSearching = false
  // Task for debounced search.
  @State private var searchDebounceTask: Task<Void, Never>?
  // Focus state for the search text field.
  @State private var isSearchFieldFocused: Bool = false

  // Screen bounds for layout calculations.
  // Updated from GeometryReader to avoid deprecated UIScreen.main usage.
  @State private var screenBounds: CGRect = .zero

  // Namespace for matched geometry effects when cards move between dashboard and folder overlay.
  @Namespace private var cardNamespace

  // Reference to the UIWindow for adding animated snapshots during drop.
  @State private var windowRef: UIWindow?

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
    GeometryReader { geometry in
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
            },
            // Notebook drag callbacks for dragging out of folder.
            onNotebookDragStart: { notebook, frame, position in
              handleFolderNotebookDragStart(notebook: notebook, frame: frame, position: position)
            },
            onNotebookDragMove: { position in
              handleDragMove(position: position)
            },
            onNotebookDragEnd: { position in
              handleFolderNotebookDragEnd(position: position)
            },
            // PDF drag callbacks for dragging out of folder.
            onPDFDragStart: { pdf, frame, position in
              handleFolderPDFDragStart(pdf: pdf, frame: frame, position: position)
            },
            onPDFDragMove: { position in
              handlePDFDragMove(position: position)
            },
            onPDFDragEnd: { position in
              handleFolderPDFDragEnd(position: position)
            },
            // Called when drag crosses overlay bounds.
            onDragExitedBounds: {
              hasDragExitedOverlayBounds = true
              // Update folder thumbnails to exclude the dragged item before showing the folder card.
              updateFolderThumbnailsForDragExit()
              closeFolder(keepingDrag: true)
            },
            // True when a drag has exited the overlay bounds.
            // Only hides the overlay after drag crosses the boundary, not on drag start.
            isDragActiveFromOverlay: hasDragExitedOverlayBounds,
            // IDs of items being dragged from this folder.
            // Used to hide the original cards while dragging (so they appear to move, not duplicate).
            draggedNotebookID: dragSourceFolderID != nil ? draggedNotebook?.id : nil,
            draggedPDFID: pdfDragSourceFolderID != nil ? draggedPDF?.id : nil,
            // Namespace for matched geometry effects when cards move between dashboard and folder.
            cardNamespace: cardNamespace
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

        // Drag overlay showing the PDF card following the finger.
        if let pdf = draggedPDF {
          pdfDragOverlay(for: pdf)
            .zIndex(400)
        }

        // AI overlay, dim background, and button at bottom-right corner.
        // The overlay expands from the button with liquid glass animation.
        // Tapping outside or tapping the button again dismisses the overlay.
        aiOverlaySection

        // Search overlay with blur background and glass panel.
        // Slides down from top when search icon is tapped.
        searchOverlaySection
      }
      // Collect card frame preferences for hero transitions.
      // Updates the reference-type store so UIKit can query current frames at dismiss time.
      .onPreferenceChange(CardFramePreferenceKey.self) { frames in
        cardFrameStore.frames.merge(frames) { _, new in new }
      }
      // Update screen bounds from geometry for folder appearance animation calculations.
      .onChange(of: geometry.frame(in: .global)) { _, newFrame in
        screenBounds = newFrame
      }
      // Collect PDF card frame preferences for drag hit testing.
      .onPreferenceChange(PDFCardFramePreferenceKey.self) { frames in
        pdfCardFrames.merge(frames) { _, new in new }
      }
      // Capture window reference for adding animated snapshots during drop.
      .background(WindowReader { window in
        windowRef = window
      })
    }
  }

  // MARK: - Toolbar Content

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    // Search button and create menu in toolbar.
    ToolbarItem(placement: .navigationBarTrailing) {
      HStack(spacing: 16) {
        // Search button opens search overlay.
        Button {
          isSearchOverlayExpanded = true
          // Set focus immediately - SearchTextField handles delayed focus if view isn't ready.
          isSearchFieldFocused = true
        } label: {
          Image(systemName: "magnifyingglass")
        }
        .tint(Color.offBlack)

        // Create menu with options based on folder state.
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
  }

  // MARK: - AI Overlay Section

  // Combines the AI button and liquid glass overlay.
  // The overlay expands from the button's bottom-right corner, always covering the button.
  // The AI circle button and overlay section.
  private var aiOverlaySection: some View {
    GeometryReader { geometry in
      let buttonSize: CGFloat = 36
      let buttonRadius: CGFloat = buttonSize / 2

      // Button center position - bottom right, horizontally aligned with plus button column.
      let buttonX = geometry.size.width - geometry.safeAreaInsets.trailing - 24 - buttonRadius
      let buttonY = geometry.size.height - geometry.safeAreaInsets.bottom - buttonRadius - 24

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
              isAIOverlayExpanded = false
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

        // AI button triggers overlay slide.
        AIButtonRepresentable(
          tapped: {
            isAIOverlayExpanded.toggle()
          },
          isYielded: isAIOverlayExpanded
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
  // Contains the chat input bar at the bottom.
  @ViewBuilder
  private func aiOverlayGlass(
    buttonBottomRightX: CGFloat,
    buttonBottomRightY: CGFloat
  ) -> some View {
    let overlayWidth: CGFloat = 400
    let overlayHeight: CGFloat = 560
    let cornerRadius: CGFloat = 24

    // Position overlay so its bottom-right corner aligns with button's bottom-right corner.
    let overlayCenterX = buttonBottomRightX - overlayWidth / 2
    let overlayCenterY = buttonBottomRightY - overlayHeight / 2

    // Slide distance (off screen when collapsed).
    let slideDistance: CGFloat = overlayHeight + 100

    ZStack {
      // Glass background.
      Group {
        if #available(iOS 26.0, *) {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
        }
      }

      // Overlay content with chat bar at bottom.
      VStack {
        Spacer()

        // Chat input bar.
        AIChatInputBar(text: $aiChatText) {
          // Handle send action.
          handleAIChatSend()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
      }
    }
    .frame(width: overlayWidth, height: overlayHeight)
    .position(x: overlayCenterX, y: overlayCenterY)
    .offset(y: isAIOverlayExpanded ? 0 : slideDistance)
    .animation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0), value: isAIOverlayExpanded)
    .allowsHitTesting(isAIOverlayExpanded)
  }

  // Handles the send action from the AI chat input bar.
  private func handleAIChatSend() {
    // Placeholder for send functionality.
    // Will be implemented when AI backend is connected.
    let message = aiChatText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }

    // Clear the text field after sending.
    aiChatText = ""
  }

  // MARK: - Search Overlay Section

  // The search overlay with blur background and glass panel.
  // Slides down from top when expanded.
  @ViewBuilder
  private var searchOverlaySection: some View {
    GeometryReader { geometry in
      let safeAreaTop = geometry.safeAreaInsets.top
      let screenWidth = geometry.size.width
      let screenHeight = geometry.size.height

      // Overlay dimensions (clamped to non-negative to avoid invalid frame warnings).
      let overlayWidth = max(0, min(screenWidth - 48, 500))
      let overlayHeight = max(0, min(screenHeight * 0.6, 480))
      let cornerRadius: CGFloat = 24
      let slideDistance = overlayHeight + safeAreaTop + 50

      ZStack {
        // Blur background (tap to dismiss).
        // Always present so it can smoothly fade in/out.
        AnimatedBlurView(
          blurFraction: isSearchOverlayExpanded ? 1 : 0,
          animationDuration: isSearchOverlayExpanded ? 0.35 : 0.2
        )
        .ignoresSafeArea()
        .onTapGesture {
          print("[DashboardView] Blur background tapped - dismissing search")
          dismissSearch()
        }
        .allowsHitTesting(isSearchOverlayExpanded)

        // Glass panel with search bar and results.
        VStack(spacing: 0) {
          // Search bar at top.
          DashboardSearchBar(
            text: $searchText,
            isFocused: $isSearchFieldFocused
          )
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .padding(.bottom, 12)

          // Results list.
          DashboardSearchResults(
            results: searchResults,
            query: searchText,
            isLoading: isSearching,
            onResultTapped: { result in
              handleSearchResultTapped(result)
            }
          )
          .padding(.bottom, 16)
        }
        .frame(width: overlayWidth, height: overlayHeight)
        .background(
          Group {
            if #available(iOS 26.0, *) {
              RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            } else {
              RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            }
          }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .position(x: screenWidth / 2, y: safeAreaTop + 16 + overlayHeight / 2)
        .offset(y: isSearchOverlayExpanded ? 0 : -slideDistance)
        .animation(
          .spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0),
          value: isSearchOverlayExpanded
        )
        .allowsHitTesting(isSearchOverlayExpanded)
      }
    }
    .ignoresSafeArea()
    .zIndex(160)
    .allowsHitTesting(isSearchOverlayExpanded)
    .onChange(of: searchText) { _, newValue in
      print("[DashboardView] searchText changed to: '\(newValue)'")
      handleSearchTextChanged(newValue)
    }
  }

  // Dismisses the search overlay and resets state.
  private func dismissSearch() {
    isSearchFieldFocused = false
    isSearchOverlayExpanded = false
    // Clear search after animation completes.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      if !isSearchOverlayExpanded {
        searchText = ""
        searchResults = []
        isSearching = false
      }
    }
  }

  // Handles search text changes with debouncing.
  private func handleSearchTextChanged(_ newValue: String) {
    searchDebounceTask?.cancel()
    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
      searchResults = []
      isSearching = false
      return
    }

    isSearching = true
    searchDebounceTask = Task {
      try? await Task.sleep(nanoseconds: 250_000_000)
      guard !Task.isCancelled else { return }
      await performSearch(query: trimmed)
    }
  }

  // Performs the actual search using SearchService.
  private func performSearch(query: String) async {
    // Search service integration will be added here.
    // For now, return empty results to test the UI.
    await MainActor.run {
      isSearching = false
      // Results will be populated when SearchService is integrated.
    }
  }

  // Handles tapping on a search result.
  private func handleSearchResultTapped(_ result: SearchResult) {
    // Dismiss the search overlay first.
    dismissSearch()

    // Navigate to the document after a brief delay for animation.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      switch result.documentType {
      case .notebook:
        // Find the notebook metadata and open it.
        if let notebook = library.notebooks.first(where: { $0.id == result.documentID }) {
          openNotebook(notebook)
        }
      case .pdf:
        // Find the PDF metadata and open it.
        if let pdf = library.pdfDocuments.first(where: { $0.id == result.documentID }),
           let uuid = UUID(uuidString: pdf.id) {
          openPDFDocument(documentID: uuid)
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
          GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 24)
        ],
        spacing: 24
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
      .animation(.spring(response: 0.4, dampingFraction: 0.75), value: library.items.map { $0.id })
      .transaction { transaction in
        // Disable animation during drag operations to prevent conflicts.
        if draggedNotebook != nil || draggedPDF != nil {
          transaction.animation = nil
        }
      }
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
    // Check if another item (notebook or PDF) is being dragged over this notebook.
    let isNotebookDragTarget =
      dragTargetNotebookID == notebook.id && draggedNotebook?.id != notebook.id
    let isPDFDragTarget = dragTargetNotebookID == notebook.id && draggedPDF != nil
    let isDragTarget = isNotebookDragTarget || isPDFDragTarget

    // ZStack to layer the underlay behind the card without scaling it.
    ZStack {
      // Grey underlay that stays at full size when the card contracts.
      dropTargetUnderlay(isActive: isDragTarget)

      // The notebook card that scales down when targeted.
      notebookCardButton(for: notebook, isDragTarget: isDragTarget)
        // Always act as geometry source. The drag overlay doesn't use matchedGeometryEffect,
        // so there's no conflict. Making isSource dynamic caused geometry animation glitches
        // when transitioning between drag and non-drag states.
        .matchedGeometryEffect(
          id: DashboardItem.notebook(notebook).id,
          in: cardNamespace,
          isSource: true
        )
        .transition(.scale.combined(with: .opacity))
        .scaleEffect(
          isContextMenuActive ? 1.08 : (isDragTarget ? 0.82 : 1.0),
          anchor: .center
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isContextMenuActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragTarget)
    }
    .background(notebookCardFrameCapture(for: notebook))
    .opacity(isBeingDragged ? 0 : 1)
    // Prevent animation on visibility change to avoid ghost card effect.
    .animation(nil, value: isBeingDragged)
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

    // Check if an item is being dragged out of this folder.
    // Only count as dragged out after the drag has exited the overlay bounds.
    let isDraggingFromThisFolder = hasDragExitedOverlayBounds && (
      dragSourceFolderID == folder.id || pdfDragSourceFolderID == folder.id
    )
    let draggedOutCount = isDraggingFromThisFolder ? 1 : 0

    let config = FolderCardConfiguration(
      folder: folder,
      thumbnails: thumbnails,
      isExpanded: isExpanded,
      isContextMenuActive: isContextMenuActive,
      isTargeted: isTargeted,
      appearanceOffset: appearanceOffset,
      draggedOutCount: draggedOutCount
    )

    folderCardButton(config: config)
  }

  // Calculates the offset for folder card appearance animation.
  // Makes the card appear to move FROM the overlay center TO its actual position.
  private func calculateFolderAppearanceOffset(folder: FolderMetadata, isExpanded: Bool) -> CGSize {
    guard isExpanded, let cardFrame = folderFrames[folder.id] else {
      return .zero
    }
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
    // Number of items being dragged out of this folder.
    // Used to reduce displayed item count while drag is in progress.
    let draggedOutCount: Int
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
      appearanceOffset: config.appearanceOffset,
      draggedOutCount: config.draggedOutCount
    )
    .matchedGeometryEffect(id: DashboardItem.folder(config.folder).id, in: cardNamespace)
    .transition(.scale.combined(with: .opacity))
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
    // Check if this PDF's context menu is currently shown.
    let isContextMenuActive = contextMenuState?.matchesPDFDocument(pdfDocument) == true
    // Check if this PDF is currently being dragged.
    let isBeingDragged = draggedPDF?.id == pdfDocument.id
    // Check if another item (PDF or notebook) is being dragged over this PDF (for folder creation).
    let isPDFDragTarget = dragTargetPDFID == pdfDocument.id && draggedPDF?.id != pdfDocument.id
    let isNotebookDragTarget = dragTargetPDFID == pdfDocument.id && draggedNotebook != nil
    let isDragTarget = isPDFDragTarget || isNotebookDragTarget

    // ZStack to layer the underlay behind the card without scaling it.
    ZStack {
      // Grey underlay that stays at full size when the card contracts.
      dropTargetUnderlay(isActive: isDragTarget)

      // The PDF card that scales down when targeted.
      pdfCardButton(for: pdfDocument, isDragTarget: isDragTarget)
        // Always act as geometry source. The drag overlay doesn't use matchedGeometryEffect,
        // so there's no conflict. Making isSource dynamic caused geometry animation glitches
        // when transitioning between drag and non-drag states.
        .matchedGeometryEffect(
          id: DashboardItem.pdfDocument(pdfDocument).id,
          in: cardNamespace,
          isSource: true
        )
        .transition(.scale.combined(with: .opacity))
        .scaleEffect(
          isContextMenuActive ? 1.08 : (isDragTarget ? 0.82 : 1.0),
          anchor: .center
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isContextMenuActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragTarget)
    }
    .background(pdfCardFrameCapture(for: pdfDocument))
    .opacity(isBeingDragged ? 0 : 1)
    // Prevent animation on visibility change to avoid ghost card effect.
    .animation(nil, value: isBeingDragged)
    .zIndex(isContextMenuActive ? 300 : 0)
  }

  // Builds the PDF card button with all its handlers.
  @ViewBuilder
  private func pdfCardButton(for pdfDocument: PDFDocumentMetadata, isDragTarget: Bool) -> some View {
    PDFDocumentCardButton(
      metadata: pdfDocument,
      action: {
        guard let uuid = UUID(uuidString: pdfDocument.id) else { return }
        openPDFDocument(documentID: uuid)
      },
      onRename: {
        renameText = pdfDocument.displayName
        renamingPDF = pdfDocument
      },
      onMoveToFolder: library.folders.isEmpty
        ? nil
        : {
          movingPDF = pdfDocument
        },
      onDelete: {
        deletingPDF = pdfDocument
      },
      onLongPress: { frame, cardHeight in
        contextMenuState = ContextMenuState(
          item: .pdfDocument(pdfDocument),
          sourceFrame: frame,
          cardHeight: cardHeight
        )
      },
      onDragStart: { pdf, frame, position in
        handlePDFDragStart(pdf: pdf, frame: frame, position: position)
      },
      onDragMove: { position in
        handlePDFDragMove(position: position)
      },
      onDragEnd: { position in
        handlePDFDragEnd(position: position)
      },
      titleOpacity: isDragTarget ? 0 : 1
    )
  }

  // Captures the PDF card's frame for drag hit testing.
  @ViewBuilder
  private func pdfCardFrameCapture(for pdfDocument: PDFDocumentMetadata) -> some View {
    GeometryReader { geometry in
      Color.clear
        .preference(
          key: PDFCardFramePreferenceKey.self,
          value: [pdfDocument.id: geometry.frame(in: .global)]
        )
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

  // Closes the folder overlay with animation.
  // When keepingDrag is true, the folder closes visually but stays in the hierarchy
  // until the drag completes, so the gesture can still receive end events.
  private func closeFolder(keepingDrag: Bool = false) {
    // Card animation (opacity + movement) is handled in FolderCard.swift.
    // Setting isFolderCardHidden triggers the card's internal animations.
    isFolderCardHidden = false

    // Overlay contraction animation.
    // When keepingDrag is true, the overlay fades to opacity 0.001 via isDragActiveFromOverlay,
    // but we still animate the collapse so the visual transition looks natural.
    // The drag continues to work because we use translation-based positioning.
    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
      isOverlayExpanded = false
    }

    // When keeping drag, don't remove from hierarchy - cleanupFolderOverlay handles that.
    // The overlay stays in hierarchy (invisible) so gestures keep receiving events.
    if keepingDrag {
      return
    }

    // Remove overlay from hierarchy after animation completes.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      expandedFolder = nil
      expandedFolderNotebooks = []
      expandedFolderPDFs = []
      expandedFolderSourceFrame = .zero
    }
  }

  // Cleans up the folder overlay state after a drag that exited bounds completes.
  // Removes the overlay from the hierarchy without animation since it's already invisible.
  private func cleanupFolderOverlay() {
    isOverlayExpanded = false
    hasDragExitedOverlayBounds = false
    expandedFolder = nil
    expandedFolderNotebooks = []
    expandedFolderPDFs = []
    expandedFolderSourceFrame = .zero
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

  // Updates folder thumbnails to exclude the dragged item (notebook or PDF).
  // Called when a drag exits the folder overlay bounds to immediately reflect
  // the removal in the folder card's thumbnail preview.
  // Thumbnail order: notebooks with previews first (up to 4), then PDFs fill remaining slots.
  private func updateFolderThumbnailsForDragExit() {
    // Determine the source folder ID (could be from notebook or PDF drag).
    let folderID = dragSourceFolderID ?? pdfDragSourceFolderID
    guard let folderID = folderID else {
      return
    }

    var thumbnails = folderThumbnails[folderID] ?? []
    guard !thumbnails.isEmpty else {
      return
    }

    // Get notebooks that have actual preview images (matching compactMap in BundleManager).
    // Only these contribute to the thumbnails array.
    let notebooksWithPreviews = expandedFolderNotebooks.prefix(4).filter { $0.previewImageData != nil }
    let notebookThumbnailCount = notebooksWithPreviews.count

    if let notebook = draggedNotebook {
      // Dragging a notebook - find its index among notebooks that have previews.
      // This matches the thumbnail array order since only notebooks with previews are included.
      if let thumbnailIndex = notebooksWithPreviews.firstIndex(where: { $0.id == notebook.id }) {
        if thumbnailIndex < thumbnails.count {
          thumbnails.remove(at: thumbnailIndex)
          folderThumbnails[folderID] = thumbnails
        }
      }
    } else if let pdf = draggedPDF {
      // Dragging a PDF - find its index among PDFs that have previews.
      // PDF thumbnails come after notebook thumbnails, filling remaining slots.
      let remainingSlots = 4 - notebookThumbnailCount
      let pdfsWithPreviews = expandedFolderPDFs.prefix(remainingSlots).filter {
        $0.previewImageData != nil
      }
      if let pdfThumbnailIndex = pdfsWithPreviews.firstIndex(where: { $0.id == pdf.id }) {
        let combinedIndex = notebookThumbnailCount + pdfThumbnailIndex
        if combinedIndex < thumbnails.count {
          thumbnails.remove(at: combinedIndex)
          folderThumbnails[folderID] = thumbnails
        }
      }
    }
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
      // Note: Do NOT use matchedGeometryEffect here. The .position() modifier places the view
      // at an absolute position, but matchedGeometryEffect tracks geometry BEFORE position
      // adjustment. This mismatch corrupts the namespace and causes all cards to become jittery.
      .position(x: dragPosition.x, y: dragPosition.y - cardHeight / 2 - 20)
      .allowsHitTesting(false)
  }

  // MARK: - Drop Animation Snapshots

  // Creates a UIView snapshot of the notebook card for drop animation.
  // Uses UIHostingController to render the SwiftUI preview content.
  private func createNotebookDragSnapshot(for notebook: NotebookMetadata) -> UIView {
    let cardWidth = dragSourceFrame.width
    let cardHeight = dragSourceFrame.height - 36

    // Create SwiftUI preview matching the drag overlay appearance.
    let preview = NotebookCardPreview(notebook: notebook, dimOpacity: 0)
      .frame(width: cardWidth, height: cardHeight)
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

    // Host the SwiftUI view in a UIView.
    let hostingController = UIHostingController(rootView: preview)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
    hostingController.view.backgroundColor = .clear

    // Add shadow matching the drag overlay.
    hostingController.view.layer.shadowColor = UIColor.black.cgColor
    hostingController.view.layer.shadowOpacity = 0.25
    hostingController.view.layer.shadowRadius = 12
    hostingController.view.layer.shadowOffset = CGSize(width: 0, height: 8)

    return hostingController.view
  }

  // Creates a UIView snapshot of the PDF card for drop animation.
  private func createPDFDragSnapshot(for pdf: PDFDocumentMetadata) -> UIView {
    let cardWidth = pdfDragSourceFrame.width
    let cardHeight = pdfDragSourceFrame.height - 36

    // Create SwiftUI preview matching the drag overlay appearance.
    let preview = PDFDocumentCardPreview(metadata: pdf, dimOpacity: 0)
      .frame(width: cardWidth, height: cardHeight)
      .background(Color(.systemGray5))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

    // Host the SwiftUI view in a UIView.
    let hostingController = UIHostingController(rootView: preview)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
    hostingController.view.backgroundColor = .clear

    // Add shadow matching the drag overlay.
    hostingController.view.layer.shadowColor = UIColor.black.cgColor
    hostingController.view.layer.shadowOpacity = 0.25
    hostingController.view.layer.shadowRadius = 12
    hostingController.view.layer.shadowOffset = CGSize(width: 0, height: 8)

    return hostingController.view
  }

  // Animates a notebook card snapshot from the drag position to a destination frame.
  // Uses spring animation for natural movement with slight overshoot.
  private func animateNotebookDropToDestination(
    notebook: NotebookMetadata,
    fromPosition: CGPoint,
    toFrame: CGRect,
    in window: UIWindow,
    completion: (() -> Void)? = nil
  ) {
    let cardHeight = dragSourceFrame.height - 36

    // Create snapshot at current drag position.
    let snapshot = createNotebookDragSnapshot(for: notebook)
    snapshot.center = CGPoint(x: fromPosition.x, y: fromPosition.y - cardHeight / 2 - 20)
    snapshot.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
    window.addSubview(snapshot)

    // Animate to destination with spring physics.
    UIView.animate(
      withDuration: 0.4,
      delay: 0,
      usingSpringWithDamping: 0.75,
      initialSpringVelocity: 0,
      options: []
    ) {
      snapshot.center = CGPoint(x: toFrame.midX, y: toFrame.midY)
      snapshot.transform = .identity
    } completion: { _ in
      snapshot.removeFromSuperview()
      completion?()
    }
  }

  // Animates a PDF card snapshot from the drag position to a destination frame.
  private func animatePDFDropToDestination(
    pdf: PDFDocumentMetadata,
    fromPosition: CGPoint,
    toFrame: CGRect,
    in window: UIWindow,
    completion: (() -> Void)? = nil
  ) {
    let cardHeight = pdfDragSourceFrame.height - 36

    // Create snapshot at current drag position.
    let snapshot = createPDFDragSnapshot(for: pdf)
    snapshot.center = CGPoint(x: fromPosition.x, y: fromPosition.y - cardHeight / 2 - 20)
    snapshot.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
    window.addSubview(snapshot)

    // Animate to destination with spring physics.
    UIView.animate(
      withDuration: 0.4,
      delay: 0,
      usingSpringWithDamping: 0.75,
      initialSpringVelocity: 0,
      options: []
    ) {
      snapshot.center = CGPoint(x: toFrame.midX, y: toFrame.midY)
      snapshot.transform = .identity
    } completion: { _ in
      snapshot.removeFromSuperview()
      completion?()
    }
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

    // Check which PDF (if any) the finger is over.
    // Uses pdfCardFrames (populated via preferences) for PDF positions.
    var foundPDFTarget: String?
    if foundFolderTarget == nil && foundNotebookTarget == nil {
      let existingPDFIDs = Set(library.pdfDocuments.map { $0.id })
      for (pdfID, frame) in pdfCardFrames {
        if existingPDFIDs.contains(pdfID) && frame.contains(position) {
          foundPDFTarget = pdfID
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

    // Update PDF target with animation if changed.
    if dragTargetPDFID != foundPDFTarget {
      withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
        dragTargetPDFID = foundPDFTarget
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
      // No animation when merging into folder - the card just disappears into it.
      // Move notebook to the existing folder.
      // Reset drag state only after library reloads to avoid ghost card appearing.
      Task {
        await library.moveNotebookToFolder(notebookID: notebook.id, folderID: targetFolderID)
        await library.loadBundles()
        await loadFolderThumbnails()
        resetDragState()
      }
      return
    }

    // Check if we're over another notebook to create a folder.
    if let targetNotebookID = dragTargetNotebookID,
      let targetNotebook = library.notebooks.first(where: { $0.id == targetNotebookID })
    {
      // No animation when merging with another card - the cards just combine into a folder.
      // Create folder from the two notebooks.
      createFolderFromNotebooks(
        draggedNotebook: notebook,
        targetNotebook: targetNotebook
      )
      return
    }

    // Check if we're over a PDF to create a folder.
    if let targetPDFID = dragTargetPDFID,
      let targetPDF = library.pdfDocuments.first(where: { $0.id == targetPDFID }) {
      // No animation when merging with a PDF - they just combine into a folder.
      // Create folder from the notebook and PDF.
      createFolderFromNotebookAndPDF(
        draggedNotebook: notebook,
        targetPDF: targetPDF
      )
      return
    }

    // No valid target - released over empty space.
    // Animate card back to its original position, then reset state after animation completes.
    if let window = windowRef {
      // Hide drag overlay immediately so only the snapshot is visible during animation.
      draggedNotebook = nil

      animateNotebookDropToDestination(
        notebook: notebook,
        fromPosition: position,
        toFrame: dragSourceFrame,
        in: window
      ) {
        // Reset remaining drag state after animation completes.
        self.resetDragState()
      }
    } else {
      // No window available, just reset immediately.
      resetDragState()
    }
  }

  // Resets all drag-related state.
  private func resetDragState() {
    // Clear dragged item WITHOUT animation to avoid matchedGeometryEffect confusion.
    // Animating this causes isSource to transition with animation, and SwiftUI
    // interpolates from an undefined position, creating a "jump up then slide down" ghost.
    draggedNotebook = nil

    // Animate target state for smooth scale-back on target cards.
    withAnimation(.easeOut(duration: 0.2)) {
      dragTargetFolderID = nil
      dragTargetNotebookID = nil
      dragTargetPDFID = nil
    }
    dragSourceFrame = .zero
    dragPosition = .zero
    dragSourceFolderID = nil
    hasDragExitedOverlayBounds = false
  }

  // MARK: - Folder Drag Handlers

  // Called when a notebook drag starts from within the folder overlay.
  private func handleFolderNotebookDragStart(
    notebook: NotebookMetadata, frame: CGRect, position: CGPoint
  ) {
    // Dismiss context menu when drag starts.
    withAnimation(.easeOut(duration: 0.15)) {
      contextMenuState = nil
    }

    // Set up drag state, including the source folder ID.
    draggedNotebook = notebook
    dragSourceFrame = frame
    dragPosition = position
    dragSourceFolderID = expandedFolder?.id
  }

  // Called when a notebook drag from a folder ends.
  private func handleFolderNotebookDragEnd(position: CGPoint) {
    guard let notebook = draggedNotebook,
      let sourceFolderID = dragSourceFolderID
    else {
      resetDragState()
      cleanupFolderOverlay()
      return
    }

    // If drag never exited overlay bounds, just reset state (card snaps back).
    // The folder overlay is still open, so no move happens.
    guard hasDragExitedOverlayBounds else {
      resetDragState()
      return
    }

    // No animations for merge operations (folder, notebook, PDF).
    // For empty space drops that move to root, the destination grid position
    // depends on sort order and is unknown until loadBundles() completes.
    // Skip animation for this case - the card just disappears from folder.

    Task { @MainActor in
      if let targetFolderID = dragTargetFolderID {
        // Move to target folder (via root since no direct folder-to-folder API).
        await library.moveNotebookToRoot(notebookID: notebook.id, fromFolderID: sourceFolderID)
        await library.moveNotebookToFolder(notebookID: notebook.id, folderID: targetFolderID)
      } else if let targetNotebookID = dragTargetNotebookID,
        let targetNotebook = library.notebooks.first(where: { $0.id == targetNotebookID }) {
        // Move to root, then create folder with target notebook.
        await library.moveNotebookToRoot(notebookID: notebook.id, fromFolderID: sourceFolderID)
        await createFolderFromNotebooksAsync(
          draggedNotebook: notebook, targetNotebook: targetNotebook)
      } else if let targetPDFID = dragTargetPDFID,
        let targetPDF = library.pdfDocuments.first(where: { $0.id == targetPDFID }) {
        // Move to root, then create folder with target PDF.
        await library.moveNotebookToRoot(notebookID: notebook.id, fromFolderID: sourceFolderID)
        await createFolderFromNotebookAndPDFAsync(notebook: notebook, pdf: targetPDF)
      } else {
        // Drop on empty space - move to root.
        await library.moveNotebookToRoot(notebookID: notebook.id, fromFolderID: sourceFolderID)
      }
      await library.loadBundles()
      // Close folder overlay BEFORE resetting drag state to avoid matched geometry conflict.
      // If we reset first, both folder card and grid card have isSource: true simultaneously.
      cleanupFolderOverlay()
      resetDragState()
    }
  }

  // Called when a PDF drag starts from within the folder overlay.
  private func handleFolderPDFDragStart(pdf: PDFDocumentMetadata, frame: CGRect, position: CGPoint) {
    // Dismiss context menu when drag starts.
    withAnimation(.easeOut(duration: 0.15)) {
      contextMenuState = nil
    }

    // Set up drag state, including the source folder ID.
    draggedPDF = pdf
    pdfDragSourceFrame = frame
    pdfDragPosition = position
    pdfDragSourceFolderID = expandedFolder?.id
  }

  // Called when a PDF drag from a folder ends.
  private func handleFolderPDFDragEnd(position: CGPoint) {
    guard let pdf = draggedPDF,
      pdfDragSourceFolderID != nil
    else {
      resetPDFDragState()
      cleanupFolderOverlay()
      return
    }

    // If drag never exited overlay bounds, just reset state (card snaps back).
    // The folder overlay is still open, so no move happens.
    guard hasDragExitedOverlayBounds else {
      resetPDFDragState()
      return
    }

    // No animations for merge operations (folder, notebook, PDF).
    // For empty space drops that move to root, the destination grid position
    // depends on sort order and is unknown until loadBundles() completes.
    // Skip animation for this case - the card just disappears from folder.

    Task { @MainActor in
      if let targetFolderID = dragTargetFolderID {
        // Move to target folder (via root since no direct folder-to-folder API).
        await library.movePDFDocumentToRoot(documentID: pdf.id)
        await library.movePDFDocumentToFolder(documentID: pdf.id, folderID: targetFolderID)
      } else if let targetNotebookID = dragTargetNotebookID,
        let targetNotebook = library.notebooks.first(where: { $0.id == targetNotebookID }) {
        // Move to root, then create folder with target notebook.
        await library.movePDFDocumentToRoot(documentID: pdf.id)
        await createFolderFromPDFAndNotebookAsync(pdf: pdf, notebook: targetNotebook)
      } else if let targetPDFID = dragTargetPDFID,
        let targetPDF = library.pdfDocuments.first(where: { $0.id == targetPDFID }) {
        // Move to root, then create folder with target PDF.
        await library.movePDFDocumentToRoot(documentID: pdf.id)
        await createFolderFromTwoPDFsAsync(draggedPDF: pdf, targetPDF: targetPDF)
      } else {
        // Drop on empty space - move to root.
        await library.movePDFDocumentToRoot(documentID: pdf.id)
      }
      await library.loadBundles()
      // Close folder overlay BEFORE resetting drag state to avoid matched geometry conflict.
      // If we reset first, both folder card and grid card have isSource: true simultaneously.
      cleanupFolderOverlay()
      resetPDFDragState()
    }
  }

  // Async helper to create folder from two notebooks.
  private func createFolderFromNotebooksAsync(
    draggedNotebook: NotebookMetadata,
    targetNotebook: NotebookMetadata
  ) async {
    let folderID = await library.createFolder(displayName: "Untitled Folder")
    if let folderID {
      await library.moveNotebookToFolder(notebookID: draggedNotebook.id, folderID: folderID)
      await library.moveNotebookToFolder(notebookID: targetNotebook.id, folderID: folderID)
    }
  }

  // Async helper to create folder from notebook and PDF.
  private func createFolderFromNotebookAndPDFAsync(
    notebook: NotebookMetadata,
    pdf: PDFDocumentMetadata
  ) async {
    let folderID = await library.createFolder(displayName: "Untitled Folder")
    if let folderID {
      await library.moveNotebookToFolder(notebookID: notebook.id, folderID: folderID)
      await library.movePDFDocumentToFolder(documentID: pdf.id, folderID: folderID)
    }
  }

  // Async helper to create folder from PDF and notebook.
  private func createFolderFromPDFAndNotebookAsync(
    pdf: PDFDocumentMetadata,
    notebook: NotebookMetadata
  ) async {
    let folderID = await library.createFolder(displayName: "Untitled Folder")
    if let folderID {
      await library.movePDFDocumentToFolder(documentID: pdf.id, folderID: folderID)
      await library.moveNotebookToFolder(notebookID: notebook.id, folderID: folderID)
    }
  }

  // Async helper to create folder from two PDFs.
  private func createFolderFromTwoPDFsAsync(
    draggedPDF: PDFDocumentMetadata,
    targetPDF: PDFDocumentMetadata
  ) async {
    let folderID = await library.createFolder(displayName: "Untitled Folder")
    if let folderID {
      await library.movePDFDocumentToFolder(documentID: draggedPDF.id, folderID: folderID)
      await library.movePDFDocumentToFolder(documentID: targetPDF.id, folderID: folderID)
    }
  }

  // Creates a new folder from two notebooks.
  private func createFolderFromNotebooks(
    draggedNotebook: NotebookMetadata,
    targetNotebook: NotebookMetadata
  ) {
    // Create the folder and move notebooks.
    // Reset drag state only after library reloads to avoid ghost card appearing.
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

      // Clear dragged item WITHOUT animation to avoid matchedGeometryEffect ghost.
      self.draggedNotebook = nil

      // Animate target state for smooth scale-back on target card.
      withAnimation(.easeOut(duration: 0.2)) {
        dragTargetNotebookID = nil
      }
      dragSourceFrame = .zero
      dragPosition = .zero
      dragTargetFolderID = nil
    }
  }

  // Creates a new folder from a notebook and a PDF.
  private func createFolderFromNotebookAndPDF(
    draggedNotebook: NotebookMetadata,
    targetPDF: PDFDocumentMetadata
  ) {
    // Create the folder and move items.
    // Reset drag state only after library reloads to avoid ghost card appearing.
    Task { @MainActor in
      // Create an untitled folder.
      let folderID = await library.createFolder(displayName: "Untitled Folder")

      // Move both items to the new folder.
      if let folderID {
        await library.moveNotebookToFolder(notebookID: draggedNotebook.id, folderID: folderID)
        await library.movePDFDocumentToFolder(documentID: targetPDF.id, folderID: folderID)
      }

      // Reload to show the new folder.
      await library.loadBundles()
      await loadFolderThumbnails()

      // Clear dragged item WITHOUT animation to avoid matchedGeometryEffect ghost.
      self.draggedNotebook = nil

      // Animate target state for smooth scale-back on target card.
      withAnimation(.easeOut(duration: 0.2)) {
        dragTargetPDFID = nil
      }
      dragSourceFrame = .zero
      dragPosition = .zero
      dragTargetFolderID = nil
    }
  }

  // MARK: - PDF Drag Overlay

  // Builds the floating PDF card overlay that follows the finger during drag.
  @ViewBuilder
  private func pdfDragOverlay(for pdf: PDFDocumentMetadata) -> some View {
    let cardWidth = pdfDragSourceFrame.width
    let cardHeight = pdfDragSourceFrame.height - 36  // Subtract title area height.

    PDFDocumentCardPreview(metadata: pdf, dimOpacity: 0)
      .frame(width: cardWidth, height: cardHeight)
      .background(Color(.systemGray5))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
      .scaleEffect(1.05)
      // Position the card centered under the finger.
      // Note: Do NOT use matchedGeometryEffect here. The .position() modifier places the view
      // at an absolute position, but matchedGeometryEffect tracks geometry BEFORE position
      // adjustment. This mismatch corrupts the namespace and causes all cards to become jittery.
      .position(x: pdfDragPosition.x, y: pdfDragPosition.y - cardHeight / 2 - 20)
      .allowsHitTesting(false)
  }

  // MARK: - PDF Drag Handlers

  // Called when a drag starts after long press on a PDF card.
  private func handlePDFDragStart(pdf: PDFDocumentMetadata, frame: CGRect, position: CGPoint) {
    // Dismiss context menu when drag starts.
    withAnimation(.easeOut(duration: 0.15)) {
      contextMenuState = nil
    }

    // Set up drag state.
    draggedPDF = pdf
    pdfDragSourceFrame = frame
    pdfDragPosition = position
  }

  // Called during PDF drag as the finger moves.
  private func handlePDFDragMove(position: CGPoint) {
    pdfDragPosition = position

    // Check which folder (if any) the finger is over.
    var foundFolderTarget: String?
    for (folderID, frame) in folderFrames where frame.contains(position) {
      foundFolderTarget = folderID
      break
    }

    // Check which notebook (if any) the finger is over.
    // Uses cardFrameStore.frames (populated via preferences) for notebook positions.
    var foundNotebookTarget: String?
    if foundFolderTarget == nil {
      let existingNotebookIDs = Set(library.notebooks.map { $0.id })
      for (notebookID, frame) in cardFrameStore.frames {
        if existingNotebookIDs.contains(notebookID) && frame.contains(position) {
          foundNotebookTarget = notebookID
          break
        }
      }
    }

    // Check which PDF (if any) the finger is over (excluding the dragged one).
    // Uses pdfCardFrames (populated via preferences) for PDF positions.
    var foundPDFTarget: String?
    if foundFolderTarget == nil && foundNotebookTarget == nil, let draggedID = draggedPDF?.id {
      let existingPDFIDs = Set(library.pdfDocuments.map { $0.id })
      for (pdfID, frame) in pdfCardFrames {
        if pdfID != draggedID
          && existingPDFIDs.contains(pdfID)
          && frame.contains(position) {
          foundPDFTarget = pdfID
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

    // Update PDF target with animation if changed.
    if dragTargetPDFID != foundPDFTarget {
      withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
        dragTargetPDFID = foundPDFTarget
      }
    }
  }

  // Called when PDF drag ends (finger released).
  private func handlePDFDragEnd(position: CGPoint) {
    guard let pdf = draggedPDF else {
      resetPDFDragState()
      return
    }

    // Check if we're over a folder.
    if let targetFolderID = dragTargetFolderID {
      // No animation when merging into folder - the card just disappears into it.
      // Move PDF to the existing folder.
      // Reset drag state only after library reloads to avoid ghost card appearing.
      Task {
        await library.movePDFDocumentToFolder(documentID: pdf.id, folderID: targetFolderID)
        await library.loadBundles()
        await loadFolderThumbnails()
        resetPDFDragState()
      }
      return
    }

    // Check if we're over a notebook to create a folder.
    if let targetNotebookID = dragTargetNotebookID,
      let targetNotebook = library.notebooks.first(where: { $0.id == targetNotebookID }) {
      // No animation when merging with a notebook - they just combine into a folder.
      // Create folder from the PDF and notebook.
      createFolderFromPDFAndNotebook(
        draggedPDF: pdf,
        targetNotebook: targetNotebook
      )
      return
    }

    // Check if we're over another PDF to create a folder.
    if let targetPDFID = dragTargetPDFID,
      let targetPDF = library.pdfDocuments.first(where: { $0.id == targetPDFID }) {
      // No animation when merging with another PDF - they just combine into a folder.
      // Create folder from the two PDFs.
      createFolderFromTwoPDFs(
        draggedPDF: pdf,
        targetPDF: targetPDF
      )
      return
    }

    // No valid target - released over empty space.
    // Animate card back to its original position, then reset state after animation completes.
    if let window = windowRef {
      // Hide drag overlay immediately so only the snapshot is visible during animation.
      draggedPDF = nil

      animatePDFDropToDestination(
        pdf: pdf,
        fromPosition: position,
        toFrame: pdfDragSourceFrame,
        in: window
      ) {
        // Reset remaining drag state after animation completes.
        self.resetPDFDragState()
      }
    } else {
      // No window available, just reset immediately.
      resetPDFDragState()
    }
  }

  // Resets all PDF drag-related state.
  private func resetPDFDragState() {
    // Clear dragged item WITHOUT animation to avoid matchedGeometryEffect confusion.
    // Animating this causes isSource to transition with animation, and SwiftUI
    // interpolates from an undefined position, creating a "jump up then slide down" ghost.
    draggedPDF = nil

    // Animate target state for smooth scale-back on target cards.
    withAnimation(.easeOut(duration: 0.2)) {
      dragTargetFolderID = nil
      dragTargetPDFID = nil
      dragTargetNotebookID = nil
    }
    pdfDragSourceFrame = .zero
    pdfDragPosition = .zero
    pdfDragSourceFolderID = nil
    hasDragExitedOverlayBounds = false
  }

  // Creates a new folder from a PDF and a notebook.
  private func createFolderFromPDFAndNotebook(
    draggedPDF: PDFDocumentMetadata,
    targetNotebook: NotebookMetadata
  ) {
    // Create the folder and move items.
    // Reset drag state only after library reloads to avoid ghost card appearing.
    Task { @MainActor in
      // Create an untitled folder.
      let folderID = await library.createFolder(displayName: "Untitled Folder")

      // Move both items to the new folder.
      if let folderID {
        await library.movePDFDocumentToFolder(documentID: draggedPDF.id, folderID: folderID)
        await library.moveNotebookToFolder(notebookID: targetNotebook.id, folderID: folderID)
      }

      // Reload to show the new folder.
      await library.loadBundles()
      await loadFolderThumbnails()

      // Clear dragged item WITHOUT animation to avoid matchedGeometryEffect ghost.
      self.draggedPDF = nil

      // Animate target state for smooth scale-back on target card.
      withAnimation(.easeOut(duration: 0.2)) {
        dragTargetNotebookID = nil
      }
      pdfDragSourceFrame = .zero
      pdfDragPosition = .zero
      dragTargetFolderID = nil
    }
  }

  // Creates a new folder from two PDFs.
  private func createFolderFromTwoPDFs(
    draggedPDF: PDFDocumentMetadata,
    targetPDF: PDFDocumentMetadata
  ) {
    // Create the folder and move both PDFs.
    // Reset drag state only after library reloads to avoid ghost card appearing.
    Task { @MainActor in
      // Create an untitled folder.
      let folderID = await library.createFolder(displayName: "Untitled Folder")

      // Move both PDFs to the new folder.
      if let folderID {
        await library.movePDFDocumentToFolder(documentID: draggedPDF.id, folderID: folderID)
        await library.movePDFDocumentToFolder(documentID: targetPDF.id, folderID: folderID)
      }

      // Reload to show the new folder.
      await library.loadBundles()
      await loadFolderThumbnails()

      // Clear dragged item WITHOUT animation to avoid matchedGeometryEffect ghost.
      self.draggedPDF = nil

      // Animate target state for smooth scale-back on target card.
      withAnimation(.easeOut(duration: 0.2)) {
        dragTargetPDFID = nil
      }
      pdfDragSourceFrame = .zero
      pdfDragPosition = .zero
      dragTargetFolderID = nil
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
    case .pdfDocument(let pdfDocument):
      return buildPDFContextMenuActions(for: pdfDocument)
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

  // Builds context menu actions for a PDF document.
  private func buildPDFContextMenuActions(for pdfDocument: PDFDocumentMetadata)
    -> [ContextMenuAction] {
    var actions: [ContextMenuAction] = [
      ContextMenuAction(title: "Rename", systemImage: "pencil") {
        renameText = pdfDocument.displayName
        renamingPDF = pdfDocument
      }
    ]

    // Add "Move to Folder" if folders exist.
    if !library.folders.isEmpty {
      actions.append(
        ContextMenuAction(title: "Move to Folder", systemImage: "folder") {
          movingPDF = pdfDocument
        })
    }

    actions.append(
      ContextMenuAction(
        title: "Delete",
        systemImage: "trash",
        isDestructive: true
      ) {
        deletingPDF = pdfDocument
      }
    )

    return actions
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
            .ignoresSafeArea()
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

// MARK: - PDF Card Frame Preference Key

// Preference key for collecting PDF card frames for drag hit testing.
struct PDFCardFramePreferenceKey: PreferenceKey {
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
