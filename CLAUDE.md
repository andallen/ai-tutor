# InkOS Project Structure

## Project Overview

InkOS is an iPad note-taking app built with SwiftUI and the MyScript iink SDK for handwriting recognition. The app uses a bundle-based storage system for notebooks and supports PDF annotation.

## Module Organization

```
InkOS/
├── InkOS/                                # App source root
│   ├── InkOSApp.swift                    # App entry point
│   ├── InkOS-Bridging-Header.h           # Exposes MyScript Obj-C headers to Swift
│   ├── Info.plist                        # App configuration
│   ├── theme.css                         # Styling for text rendering
│   │
│   ├── App/                              # High-level navigation & integration
│   │   ├── AppRootView.swift             # Root view (Loading -> Dashboard)
│   │   ├── EditorHostView.swift          # SwiftUI bridge for EditorViewController
│   │   └── NotebookTransition/           # Custom notebook open/close animations
│   │       ├── EditorNavigationController.swift
│   │       ├── NotebookPresentAnimator.swift
│   │       ├── NotebookDismissAnimator.swift
│   │       └── NotebookTransitionCoordinator.swift
│   │
│   ├── Features/                         # SwiftUI Feature Modules
│   │   ├── AIIndexing/                   # AI-powered content indexing for semantic search
│   │   │   ├── Extraction/               # Content extraction from notebooks
│   │   │   │   ├── ChunkingService.swift      # Splits content into chunks for embedding
│   │   │   │   ├── ContentExtractor.swift     # Extracts text content from notebooks
│   │   │   │   └── ExtractionModels.swift     # Data models for extraction
│   │   │   │
│   │   │   ├── Indexing/                 # Indexing coordination and queue management
│   │   │   │   ├── IndexingCoordinator.swift  # Orchestrates the indexing pipeline
│   │   │   │   ├── IndexingModels.swift       # Data models for indexing
│   │   │   │   └── IndexingQueue.swift        # Queue for processing indexing jobs
│   │   │   │
│   │   │   └── VectorStore/              # Vector storage and embedding services
│   │   │       ├── EmbeddingService.swift     # Generates embeddings via API
│   │   │       ├── VectorStoreClient.swift    # Client for vector database operations
│   │   │       └── VectorStoreModels.swift    # Data models for vector storage
│   │   │
│   │   ├── Dashboard/                    # Notebook library and management UI
│   │   │   ├── DashboardView.swift       # Main dashboard view
│   │   │   ├── DashboardItem.swift       # Dashboard item model
│   │   │   ├── DashboardComponents.swift # Reusable dashboard UI components
│   │   │   ├── DashboardAlerts.swift     # Alert dialogs for dashboard actions
│   │   │   ├── NotebookLibrary.swift     # Notebook data source
│   │   │   ├── FolderCard.swift          # Folder display card
│   │   │   ├── FolderOverlay.swift       # Folder contents overlay
│   │   │   ├── FolderDropDelegate.swift  # Drag-and-drop folder handling
│   │   │   ├── FolderDraggableCards.swift # Draggable card components for folders
│   │   │   ├── MoveToFolderSheet.swift   # Move notebook to folder UI
│   │   │   ├── ContextMenuOverlay.swift  # Context menu presentation overlay
│   │   │   └── UIKitDragWrapper.swift    # UIKit drag-and-drop bridge for SwiftUI
│   │   │
│   │   ├── Notebook/                     # Notebook metadata models
│   │   │   └── NotebookModel.swift
│   │   │
│   │   ├── PDFImport/                    # PDF import functionality
│   │   │   ├── PDFDataModel.swift        # NoteDocument, NoteBlock, ImportCoordinator
│   │   │   └── PDFImport.swift           # PDFDocumentWrapper implementation
│   │   │
│   │   ├── PDFDisplay/                   # PDF viewing and annotation
│   │   │   ├── PDFEditorHostView.swift   # SwiftUI bridge for PDF editor
│   │   │   ├── PDFEditorViewController.swift  # PDF editor controller
│   │   │   ├── PDFEditorViewModel.swift  # PDF editor state management
│   │   │   ├── PDFPageLayout.swift       # PDF page layout calculations
│   │   │   ├── PDFBackgroundRenderer.swift    # PDF background rendering
│   │   │   ├── DottedGridView.swift      # Grid overlay for annotation
│   │   │   └── PDFStubs.swift            # PDF-related stub implementations
│   │   │
│   │   ├── Search/                       # Search and indexing system
│   │   │   ├── Index/                    # Search index components
│   │   │   │   ├── Contract.swift        # Search index contract/interface
│   │   │   │   ├── SearchIndex.swift     # Core search index implementation
│   │   │   │   └── SearchIndexTriggers.swift  # Event triggers for indexing
│   │   │   └── Service/                  # Search service layer
│   │   │       ├── SearchService.swift   # Search service implementation
│   │   │       └── SearchServiceContract.swift  # Service contract/interface
│   │   │
│   │   └── Shared/                       # Shared UI components & utilities
│   │       ├── ContextMenuView.swift     # Reusable context menu component
│   │       ├── NotebookNotifications.swift
│   │       └── UIComponents.swift
│   │
│   ├── Storage/                          # Persistence Layer (Actors)
│   │   ├── BundleManager.swift           # Central actor for file system operations
│   │   ├── BundleStorage.swift           # Helper for directory paths
│   │   ├── DocumentHandle.swift          # Safe handle for open notebook operations
│   │   ├── PDFDocumentHandle.swift       # Handle for PDF document operations
│   │   ├── Manifest.swift                # JSON metadata structure
│   │   ├── FolderManifest.swift          # Folder metadata structure
│   │   ├── SDKProtocols.swift            # SDK protocol definitions
│   │   │
│   │   └── JIIXPersistence/              # JIIX format persistence
│   │       ├── JIIXPersistenceTypes.swift         # Error types, protocols, configuration
│   │       ├── JIIXPersistenceService.swift       # Persistence service
│   │       └── IINKEditorExportExtension.swift    # Editor export extension
│   │
│   ├── Editor/                           # EDITOR IMPLEMENTATION (Core Logic)
│   │   ├── EditorViewController.swift    # The main Editor Canvas UI
│   │   ├── EditorViewModel.swift         # Editor state & tool logic
│   │   ├── EngineProvider.swift          # Singleton managing IINKEngine lifecycle
│   │   ├── ToolPaletteView.swift         # Floating custom toolbar
│   │   ├── EditingToolbarView.swift      # Undo/Redo/Clear toolbar
│   │   ├── ColorThicknessPillView.swift  # Color and thickness selection UI
│   │   ├── HomeButtonView.swift          # Home navigation button
│   │   ├── AIButtonView.swift            # AI assistant button component
│   │   ├── AIOverlayView.swift           # AI assistant overlay interface
│   │   ├── AIChatInputBar.swift          # AI chat input component
│   │   │
│   │   └── RawContentConfiguration/      # MyScript Raw Content mode settings
│   │       └── RawContentConfiguration.swift  # Configuration applier for recognition
│   │
│   ├── Frameworks/
│   │   └── Ink/                          # Low-level MyScript Wrappers
│   │       ├── IInkUIReferenceImplementation-Bridging-Header.h
│   │       │
│   │       ├── Input/                    # Touch/Pen input handling
│   │       │   ├── InputViewController.swift
│   │       │   └── InputViewModel.swift
│   │       │
│   │       ├── Rendering/                # Display & rendering logic
│   │       │   ├── DisplayViewController.swift
│   │       │   └── DisplayViewModel.swift
│   │       │
│   │       ├── UIObjects/                # Core UI rendering components
│   │       │   ├── Canvas.swift
│   │       │   ├── InputView.swift
│   │       │   ├── RenderView.swift
│   │       │   └── OffscreenRenderSurfaces.swift
│   │       │
│   │       ├── SmartGuide/               # Text conversion guide UI
│   │       │   ├── SmartGuideViewController.h
│   │       │   └── SmartGuideViewController.mm
│   │       │
│   │       └── Utils/                    # Utility helpers
│   │           ├── FontMetricsProvider.swift
│   │           ├── ImageLoader.swift
│   │           ├── ImagePainter.swift
│   │           ├── TextFormatHelper.swift
│   │           ├── IInkUIRefImplUtils.swift
│   │           ├── ContextualActionsHelper.swift
│   │           ├── Helper.swift
│   │           ├── Path.swift
│   │           ├── SynchronizedSwift.swift
│   │           ├── UIFont+Helper.swift
│   │           ├── NSFileManager+Additions.swift
│   │           ├── NSAttributedString+Helper.swift
│   │           └── CTRun+Metrics.swift
│   │
│   └── Assets.xcassets                   # App assets
│
├── InkOSTests/                           # Unit test suite
│   ├── Editor/
│   │   ├── EditorViewModelTests.swift
│   │   ├── EngineProviderTests.swift
│   │   └── InputViewModelTests.swift
│   │
│   ├── Features/
│   │   ├── NotebookModelTests.swift
│   │   ├── AIIndexing/                   # AI indexing tests
│   │   │   ├── ChunkingServiceTests.swift
│   │   │   ├── ContentExtractorTests.swift
│   │   │   ├── EmbeddingServiceTests.swift
│   │   │   ├── IndexingCoordinatorTests.swift
│   │   │   ├── IndexingIntegrationTests.swift
│   │   │   ├── IndexingModelsTests.swift
│   │   │   ├── IndexingQueueTests.swift
│   │   │   ├── VectorStoreClientTests.swift
│   │   │   └── VectorStoreModelsTests.swift
│   │   └── Search/
│   │       ├── SearchIndexTests.swift
│   │       └── SearchServiceTests.swift
│   │
│   ├── Rendering/
│   │   ├── DisplayViewModelTests.swift
│   │   └── OffscreenRenderSurfacesTests.swift
│   │
│   └── Storage/
│       ├── BundleManagerTests.swift
│       ├── BundleStorageTests.swift
│       ├── DocumentHandleTests.swift
│       └── ManifestTests.swift
│
├── InkOSUITests/                         # UI test suite
│   └── InkOSUITests.swift
│
├── Firebase/                             # Firebase backend services
│   ├── firebase.json                     # Firebase configuration
│   └── functions/                        # Cloud Functions
│       ├── src/                          # TypeScript source files
│       ├── package.json                  # Node.js dependencies
│       └── tsconfig.json                 # TypeScript configuration
│
├── MyScriptCertificate/                  # License Key
│   ├── MyCertificate.h
│   └── me.andy.allen.Trivial.c
│
├── Scripts/                              # Build & Utility Scripts
│   ├── buildapp                          # Build executable
│   ├── testapp                           # Test executable
│   ├── grablogs                          # Grab logs script
│   └── retrieve_recognition-assets.sh    # Download recognition assets
│
├── Docs/                                 # Reference documentation
│   ├── myscript_docs.md
│   ├── myscript_headers.txt
│   └── myscript-reference.txt
│
├── recognition-assets/                   # MyScript recognition data (binary)
│   └── resources/
│       ├── en_US/                        # English language resources
│       ├── math/                         # Math recognition
│       └── shape/                        # Shape recognition
│
├── Podfile                               # CocoaPods dependency specification
├── Podfile.lock                          # Locked dependency versions
├── Pods/                                 # CocoaPods dependencies (generated)
│
└── Logs/                                 # Build artifacts & logs
```

## Project Rules



### 1. Comments
- Comment frequently with simple and direct language
- Concisely spell out what every part of the code is doing, making the logic easy to follow
- Use clear grammar and avoid special headers, decorative markers, or section labels
- Be impersonal; no first/second/third person

### 2. Quality Assurance
- Make errors explicit. Do not use force unwraps (`!`), `try!`, or `fatalError` for expected runtime issues
- Use `throws` and pass error messages back to the UI so the user can be notified

### 3. Security & Configuration
- Do not commit private keys or license material beyond the checked-in certificate files
- Treat `recognition-assets/` as large binary dependencies; avoid editing by hand

## Build Commands

- **Build**: `Scripts/buildapp`
- **Test**: `Scripts/testapp`

## Key Architecture Notes
See subdirectory CLAUDE.md files for layer-specific rules:
- `InkOS/Editor/CLAUDE.md` - MainActor isolation and thread safety for MyScript SDK
- `InkOS/Storage/CLAUDE.md` - Actor isolation for BundleManager and DocumentHandle
- `InkOS/Features/Dashboard/CLAUDE.md` - Dashboard UI consistency guidelines
