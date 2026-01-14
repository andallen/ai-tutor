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
│   │   ├── AIChat/                       # AI chat and messaging feature
│   │   │   ├── Models/                   # Chat data models
│   │   │   │   ├── AttachmentContract.swift     # Attachment handling contract
│   │   │   │   ├── ChatContract.swift           # Chat message contracts
│   │   │   │   └── MultimodalMessageContract.swift  # Multimodal message support
│   │   │   └── Services/                 # Chat services and clients
│   │   │       ├── ChatService.swift            # Core chat service
│   │   │       ├── ChatStorage.swift            # Chat persistence
│   │   │       ├── ContextGatherer.swift        # Context extraction for AI
│   │   │       └── FirebaseChatClient.swift     # Firebase integration
│   │   │
│   │   ├── Block/                        # Block primitive system (Alan content model)
│   │   │   ├── Core/                     # Core block types and contracts
│   │   │   │   ├── BlockContract.swift          # Block, BlockID, BlockMetadata, BlockSource
│   │   │   │   ├── BlockKind.swift              # BlockKind enum (20 types) + BlockTrait
│   │   │   │   ├── BlockProperties.swift        # Type-safe property structs per kind
│   │   │   │   ├── BlockParameter.swift         # Parameter system (sliders, toggles, etc.)
│   │   │   │   ├── BlockAction.swift            # Actions blocks can trigger
│   │   │   │   ├── BlockState.swift             # State enum + valid transitions
│   │   │   │   └── BlockValidation.swift        # BlockError + DefaultBlockValidator
│   │   │   └── Extensions/               # Codable and utility extensions
│   │   │       └── Block+Codable.swift          # Manual Codable conformance
│   │   │
│   │   ├── Dashboard/                    # Notebook library and management UI (UIKit-based)
│   │   │   ├── CardFoundation.swift      # Card layout constants and base styles
│   │   │   ├── CardUIComponents.swift    # Shared card UI components
│   │   │   ├── DashboardCardRepresentable.swift  # UIViewRepresentable for card cells
│   │   │   ├── DashboardCardView.swift   # Card view wrapper for dashboard items
│   │   │   ├── DashboardItem.swift       # Dashboard item model (enum for notebooks/folders/PDFs/lessons)
│   │   │   ├── DashboardModels.swift     # Centralized model definitions
│   │   │   ├── NotebookLibrary.swift     # Notebook data source and state management
│   │   │   ├── SearchOverlayRootView.swift  # Search overlay UI
│   │   │   ├── SearchOverlayState.swift  # Search state management
│   │   │   └── UIKit/                    # UIKit dashboard implementation
│   │   │       ├── DashboardHostView.swift      # SwiftUI bridge for UIKit dashboard
│   │   │       ├── DashboardLayout.swift        # Collection view layout configuration
│   │   │       ├── DashboardViewController.swift # Main UIKit collection view controller
│   │   │       ├── Cells/                       # Collection view cells
│   │   │       │   ├── FolderCell.swift         # Folder card cell
│   │   │       │   ├── LessonCell.swift         # Lesson card cell
│   │   │       │   ├── NotebookCell.swift       # Notebook card cell
│   │   │       │   └── PDFDocumentCell.swift    # PDF document card cell
│   │   │       └── Overlays/                    # Folder overlay system
│   │   │           ├── FolderOverlayCell.swift  # Cell for items inside folder overlay
│   │   │           ├── FolderOverlayViewController.swift  # Folder contents overlay controller
│   │   │           ├── FolderPresentationController.swift # Custom presentation for folder overlay
│   │   │           └── FolderTransitionAnimator.swift     # Folder open/close animations
│   │   │
│   │   ├── Lesson/                       # Lesson generation and display
│   │   │   ├── Components/               # Lesson UI components
│   │   │   │   └── LessonCardView.swift         # Lesson card for dashboard
│   │   │   ├── Generation/               # Lesson content generation
│   │   │   │   ├── AnswerComparisonService.swift  # Answer evaluation
│   │   │   │   ├── LessonGenerationService.swift  # Lesson generation API
│   │   │   │   ├── LessonGenerator.swift          # Core lesson generator
│   │   │   │   └── LessonPreviewGenerator.swift   # Preview generation
│   │   │   ├── Models/                   # Lesson data models
│   │   │   │   ├── LessonModel.swift            # Core lesson model
│   │   │   │   └── LessonProgress.swift         # Progress tracking
│   │   │   ├── ViewModels/               # Lesson view models
│   │   │   │   └── LessonViewModel.swift        # Lesson state management
│   │   │   ├── Views/                    # SwiftUI lesson views
│   │   │   │   ├── LessonView.swift             # Main lesson view
│   │   │   │   ├── ContentSectionView.swift     # Content display
│   │   │   │   ├── QuestionSectionView.swift    # Question display
│   │   │   │   ├── SummarySectionView.swift     # Summary display
│   │   │   │   └── VisualPlaceholderView.swift  # Visual placeholders
│   │   │   └── UIKit/                    # UIKit lesson implementation
│   │   │       ├── LessonViewController.swift   # Main UIKit controller
│   │   │       ├── NotesOverlayCoordinator.swift # Notes overlay logic
│   │   │       ├── QuestionCanvasManager.swift  # Handwriting input
│   │   │       └── Cells/                       # Section cells
│   │   │           ├── ContentSectionCell.swift
│   │   │           ├── QuestionSectionCell.swift
│   │   │           ├── SummarySectionCell.swift
│   │   │           └── VisualSectionCell.swift
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
│   │   │   ├── Service/                  # Search service layer
│   │   │   │   ├── SearchService.swift   # Search service implementation
│   │   │   │   └── SearchServiceContract.swift  # Service contract/interface
│   │   │   └── UI/                       # Search UI components
│   │   │       └── Dashboard/            # Dashboard search integration
│   │   │           ├── DashboardSearchBar.swift     # Search bar component
│   │   │           └── DashboardSearchResults.swift # Search results view
│   │   │
│   │   ├── Skills/                       # AI-powered skills system
│   │   │   ├── Core/                     # Skill infrastructure
│   │   │   │   ├── SkillExecutor.swift          # Skill execution engine
│   │   │   │   ├── SkillRegistry.swift          # Skill registration
│   │   │   │   └── SkillsContract.swift         # Core contracts
│   │   │   ├── Graph/                    # Graphing calculator skill
│   │   │   │   ├── EquationRenderer.swift       # Equation rendering
│   │   │   │   ├── GraphImageRenderer.swift     # Graph image generation
│   │   │   │   ├── GraphInsertionService.swift  # Graph insertion to canvas
│   │   │   │   ├── GraphView.swift              # Graph SwiftUI view
│   │   │   │   ├── GraphViewModel.swift         # Graph state management
│   │   │   │   └── MathExpressionParser.swift   # Math expression parsing
│   │   │   ├── Invocation/               # Skill invocation system
│   │   │   │   ├── AISkillInvocationService.swift  # AI-triggered invocation
│   │   │   │   ├── InvocationContract.swift        # Invocation contracts
│   │   │   │   └── SkillCloudClient.swift          # Cloud function client
│   │   │   └── Skills/                   # Skill implementations
│   │   │       └── GraphingCalculatorSkill.swift   # Graphing calculator
│   │   │
│   │   └── Shared/                       # Shared UI components & utilities
│   │       ├── ContextMenuView.swift     # Reusable context menu component
│   │       ├── FileLogger.swift          # Debug logging utility
│   │       ├── NotebookNotifications.swift # Notification names for notebook events
│   │       └── UIComponents.swift        # Color extensions and shared UI modifiers
│   │
│   ├── Storage/                          # Persistence Layer (Actors)
│   │   ├── BundleManager.swift           # Central actor for file system operations
│   │   ├── BundleManager+Lessons.swift   # Lesson-specific bundle operations
│   │   ├── BundleStorage.swift           # Helper for directory paths
│   │   ├── DocumentHandle.swift          # Safe handle for open notebook operations
│   │   ├── PDFDocumentHandle.swift       # Handle for PDF document operations
│   │   ├── Manifest.swift                # JSON metadata structure
│   │   ├── FolderManifest.swift          # Folder metadata structure
│   │   ├── LessonManifest.swift          # Lesson bundle metadata structure
│   │   ├── LessonStorage.swift           # Lesson-specific storage operations
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
│   │   ├── AIChat/                       # AI chat tests
│   │   │   ├── AttachmentContractTests.swift
│   │   │   ├── ChatServiceTests.swift
│   │   │   ├── ChatStorageTests.swift
│   │   │   ├── ContextGathererTests.swift
│   │   │   └── FirebaseChatClientTests.swift
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
│   │   ├── Block/                        # Block primitive tests (planned)
│   │   │   ├── BlockContractTests.swift
│   │   │   ├── BlockKindTests.swift
│   │   │   ├── BlockPropertiesTests.swift
│   │   │   ├── BlockParameterTests.swift
│   │   │   ├── BlockActionTests.swift
│   │   │   ├── BlockStateTests.swift
│   │   │   ├── BlockValidationTests.swift
│   │   │   └── BlockCodableTests.swift
│   │   ├── Search/
│   │   │   ├── SearchIndexTests.swift
│   │   │   └── SearchServiceTests.swift
│   │   └── Skills/                       # Skills tests
│   │       ├── Graph/
│   │       │   ├── EquationRendererTests.swift
│   │       │   ├── GraphImageRendererTests.swift
│   │       │   ├── GraphInsertionServiceTests.swift
│   │       │   ├── GraphViewModelTests.swift
│   │       │   └── MathExpressionParserTests.swift
│   │       ├── GraphingCalculatorSkillTests.swift
│   │       ├── SkillInvocationTests.swift
│   │       └── SkillsCoreTests.swift
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
│   ├── test-ui                           # UI test runner script
│   ├── run-ui-tests                      # Extended UI test runner with options
│   ├── grablogs                          # Grab logs script
│   └── retrieve_recognition-assets.sh    # Download recognition assets
│
├── Docs/                                 # Reference documentation
│   ├── myscript_docs.md
│   ├── myscript_headers.txt
│   └── myscript-reference.txt
│
├── apple-hig/                            # Apple Human Interface Guidelines reference
│   └── [various topic directories]       # HIG documentation by topic (buttons, colors, etc.)
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
