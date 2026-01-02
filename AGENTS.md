## Project Structure & Module Organization

InkOS/
├── InkOS/                                # App source root
│   ├── InkOSApp.swift                    # App entry point
│   ├── InkOS-Bridging-Header.h           # Exposes MyScript Obj-C headers to Swift
│   ├── Info.plist                        # App configuration
│   ├── theme.css                         # Styling for text rendering
│   │
│   ├── App/                              # High-level navigation & integration
│   │   ├── AppRootView.swift             # Root view (Loading -> Dashboard)
│   │   └── EditorHostView.swift          # SwiftUI bridge for EditorViewController
│   │
│   ├── Features/                         # SwiftUI Feature Modules
│   │   ├── Dashboard/                    # Notebook library and management UI
│   │   │   ├── DashboardView.swift       # Main dashboard view
│   │   │   ├── DashboardItem.swift       # Dashboard item model
│   │   │   ├── DashboardComponents.swift # Reusable dashboard UI components
│   │   │   ├── DashboardAlerts.swift     # Alert dialogs for dashboard actions
│   │   │   ├── NotebookLibrary.swift     # Notebook data source
│   │   │   ├── FolderCard.swift          # Folder display card
│   │   │   ├── FolderOverlay.swift       # Folder contents overlay
│   │   │   ├── FolderDropDelegate.swift  # Drag-and-drop folder handling
│   │   │   └── MoveToFolderSheet.swift   # Move notebook to folder UI
│   │   │
│   │   ├── Notebook/                     # Notebook metadata models
│   │   │   └── NotebookModel.swift
│   │   │
│   │   ├── PDFImport/                    # PDF import functionality
│   │   │   ├── PDFImport.swift           # PDF import logic
│   │   │   └── Contract.swift            # Import contract definitions
│   │   │
│   │   ├── PDFDisplay/                   # PDF viewing and annotation
│   │   │   ├── PDFCollectionViewController.swift  # Collection view controller
│   │   │   ├── PDFCollectionLayout.swift # Custom collection layout
│   │   │   ├── PDFPageCell.swift         # PDF page cell
│   │   │   ├── SpacerCell.swift          # Spacer between pages
│   │   │   ├── DottedGridView.swift      # Grid overlay for annotation
│   │   │   └── PDFDisplayContract.swift  # Display contract definitions
│   │   │
│   │   └── Shared/                       # Shared UI components & utilities
│   │       ├── NotebookNotifications.swift
│   │       └── UIComponents.swift
│   │
│   ├── Storage/                          # Persistence Layer (Actors)
│   │   ├── BundleManager.swift           # Central actor for file system operations
│   │   ├── BundleStorage.swift           # Helper for directory paths
│   │   ├── DocumentHandle.swift          # Safe handle for open notebook operations
│   │   ├── Manifest.swift                # JSON metadata structure
│   │   ├── FolderManifest.swift          # Folder metadata structure
│   │   ├── SDKProtocols.swift            # SDK protocol definitions
│   │   │
│   │   └── JIIXPersistence/              # JIIX format persistence
│   │       ├── JIIXPersistenceService.swift       # Persistence service
│   │       ├── JIIXPersistenceContract.swift      # Persistence contract
│   │       └── IINKEditorExportExtension.swift    # Editor export extension
│   │
│   ├── Editor/                           # EDITOR IMPLEMENTATION (Core Logic)
│   │   ├── EditorViewController.swift    # The main Editor Canvas UI
│   │   ├── EditorViewModel.swift         # Editor state & tool logic
│   │   ├── EngineProvider.swift          # Singleton managing IINKEngine lifecycle
│   │   ├── ToolPaletteView.swift         # Floating custom toolbar
│   │   ├── EditingToolbarView.swift      # Undo/Redo/Clear toolbar
│   │   ├── ColorPaletteView.swift        # Color selection UI
│   │   ├── ThicknessSliderView.swift     # Brush thickness control
│   │   │
│   │   └── RawContentConfiguration/      # Raw content data structures
│   │       └── RawContentContract.swift
│   │
│   └── Frameworks/
│       └── Ink/                          # Low-level MyScript Wrappers
│           ├── IInkUIReferenceImplementation-Bridging-Header.h
│           │
│           ├── Input/                    # Touch/Pen input handling
│           │   ├── InputViewController.swift
│           │   └── InputViewModel.swift
│           │
│           ├── Rendering/                # Display & rendering logic
│           │   ├── DisplayViewController.swift
│           │   └── DisplayViewModel.swift
│           │
│           ├── UIObjects/                # Core UI rendering components
│           │   ├── Canvas.swift
│           │   ├── InputView.swift
│           │   ├── RenderView.swift
│           │   └── OffscreenRenderSurfaces.swift
│           │
│           ├── SmartGuide/               # Text conversion guide UI
│           │   ├── SmartGuideViewController.h
│           │   └── SmartGuideViewController.mm
│           │
│           └── Utils/                    # Utility helpers
│               ├── FontMetricsProvider.swift
│               ├── ImageLoader.swift
│               ├── ImagePainter.swift
│               ├── TextFormatHelper.swift
│               ├── IInkUIRefImplUtils.swift
│               ├── ContextualActionsHelper.swift
│               ├── Helper.swift
│               ├── Path.swift
│               ├── SynchronizedSwift.swift
│               ├── UIFont+Helper.swift
│               ├── NSFileManager+Additions.swift
│               ├── NSAttributedString+Helper.swift
│               └── CTRun+Metrics.swift
│
├── InkOSTests/                           # Unit test suite
│   ├── Editor/
│   │   ├── EditorViewModelTests.swift
│   │   ├── EngineProviderTests.swift
│   │   ├── InputViewModelTests.swift
│   │   └── RawContentConfigurationTests.swift
│   │
│   ├── Features/
│   │   ├── NotebookModelTests.swift
│   │   ├── PDFImport/
│   │   │   └── PDFImportTests.swift
│   │   └── PDFDisplay/
│   │       └── PDFDisplayTests.swift
│   │
│   ├── Rendering/
│   │   ├── DisplayViewModelTests.swift
│   │   └── OffscreenRenderSurfacesTests.swift
│   │
│   └── Storage/
│       ├── BundleManagerTests.swift
│       ├── BundleStorageTests.swift
│       ├── DocumentHandleTests.swift
│       ├── FolderSupportTests.swift
│       ├── JIIXPersistenceTests.swift
│       └── ManifestTests.swift
│
├── InkOSUITests/                         # UI test suite
│   └── InkOSUITests.swift
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
└── Logs/                                 # Build artifacts & logs

## PROJECT RULES:

## 1. COMMENTS
- Comment frequently with simple and direct language.
- Concisely spell out what every part of the code is doing, making the logic easy to follow.
- Use clear grammar and avoid special headers, decorative markers, or section labels.
- Be impersonal; no first/second/third person.

## 2. ARCHITECTURAL DECOUPLING
- The UI must remain replaceable. SwiftUI views should only handle presentation and layout.
- Data and storage code must live outside the UI. Centralize all file-system access in the **BundleManager** and the **EngineProvider**.

## 3. QUALITY ASSURANCE
- Make errors explicit. Do not use force unwraps (`!`), `try!`, or `fatalError` for expected runtime issues like a missing MyScript certificate or a failed file save.
- Use `throws` and pass error messages back to the UI so the user can be notified.

## 4: Security & Configuration
- Do not commit private keys or license material beyond the checked-in certificate files.
- Treat `recognition-assets/` as large binary dependencies; avoid editing by hand.