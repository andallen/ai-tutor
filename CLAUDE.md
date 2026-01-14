# Alan Project Structure

## Project Overview

Alan is an iPad app built with SwiftUI and the MyScript iink SDK for handwriting recognition.

## Module Organization

```
Alan/
├── InkOS/                                # App source root
│   ├── InkOSApp.swift                    # App entry point
│   ├── InkOS-Bridging-Header.h           # Exposes MyScript Obj-C headers to Swift
│   ├── Info.plist                        # App configuration
│   ├── theme.css                         # Styling for text rendering
│   │
│   ├── App/                              # High-level navigation
│   │   └── AppRootView.swift             # Root view
│   │
│   ├── Features/                         # Feature Modules
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
│   │   ├── Notebook/                     # Notebook data models
│   │   │   ├── Core/                     # Core notebook contracts
│   │   │   │   └── NotebookContract.swift       # Notebook, Page, NotebookID
│   │   │   ├── Extensions/               # Notebook extensions
│   │   │   │   └── Notebook+Codable.swift       # Codable conformance
│   │   │   └── Validation/               # Notebook validation
│   │   │       └── NotebookValidation.swift     # Validation logic
│   │   │
│   │   └── Shared/                       # Shared utilities
│   │       ├── UIComponents.swift        # Color extensions, UI modifiers
│   │       ├── FileLogger.swift          # Debug logging utility
│   │       └── ContextMenuView.swift     # Reusable context menu
│   │
│   ├── Editor/                           # Editor canvas components
│   │   ├── BaseEditorViewController.swift       # Base editor controller
│   │   ├── EditorViewController.swift           # Main editor controller
│   │   └── HomeButtonView.swift                 # Home navigation button
│   │
│   ├── Storage/                          # Persistence Layer
│   │   ├── BundleStorage.swift           # Directory path helpers
│   │   ├── SDKProtocols.swift            # SDK protocol definitions
│   │   └── JIIXPersistence/              # JIIX format persistence
│   │       └── JIIXPersistenceService.swift     # Persistence service
│   │
│   ├── Frameworks/
│   │   └── Ink/                          # MyScript SDK Wrappers
│   │       ├── EngineProvider.swift      # MyScript engine singleton
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
│   ├── Features/
│   │   ├── Block/                        # Block tests
│   │   │   ├── BlockActionTests.swift
│   │   │   ├── BlockCodableTests.swift
│   │   │   ├── BlockContractTests.swift
│   │   │   ├── BlockKindTests.swift
│   │   │   ├── BlockParameterTests.swift
│   │   │   ├── BlockPropertiesTests.swift
│   │   │   ├── BlockStateTests.swift
│   │   │   └── BlockValidationTests.swift
│   │   └── Notebook/                     # Notebook tests
│   │       ├── NotebookCodableTests.swift
│   │       ├── NotebookContractTests.swift
│   │       └── NotebookValidationTests.swift
│   │
│   └── Rendering/
│       ├── DisplayViewModelTests.swift
│       └── OffscreenRenderSurfacesTests.swift
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
│   ├── test-ui                           # UI test runner
│   ├── run-ui-tests                      # Extended UI test runner
│   ├── html-preview                      # HTML preview script
│   └── retrieve_recognition-assets.sh    # Download recognition assets
│
├── Docs/                                 # Reference documentation
│   ├── myscript_docs.md
│   ├── myscript_headers.txt
│   └── myscript-reference.txt
│
├── apple-hig/                            # Apple Human Interface Guidelines reference
│
├── recognition-assets/                   # MyScript recognition data (binary)
│   └── resources/
│       ├── en_US/                        # English language resources
│       ├── math/                         # Math recognition
│       └── shape/                        # Shape recognition
│
├── Podfile                               # CocoaPods dependency specification
├── Podfile.lock                          # Locked dependency versions
└── Pods/                                 # CocoaPods dependencies (generated)
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
