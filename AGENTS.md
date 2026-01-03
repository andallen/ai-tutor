## Project Structure & Module Organization

InkOS/
├── InkOS/                                # App source root
│   ├── InkOSApp.swift                    # App Entry Point
│   ├── InkOS-Bridging-Header.h           # Exposes MyScript Obj-C headers to Swift
│   │
│   ├── App/                              # High-level navigation & integration
│   │   ├── AppRootView.swift             # Root view (Loading -> Dashboard)
│   │   └── EditorHostView.swift          # SwiftUI bridge for the Editor (EditorViewController)
│   │
│   ├── Features/                         # SwiftUI Feature Modules
│   │   ├── Dashboard/                    # Notebook management UI
│   │   │   ├── DashboardView.swift
│   │   │   └── NotebookLibrary.swift
│   │   ├── Notebook/                     # Notebook metadata models
│   │   │   └── NotebookModel.swift
│   │   └── Shared/                       # Shared UI components & utilities
│   │       ├── NotebookNotifications.swift
│   │       └── UIComponents.swift
│   │
│   ├── Storage/                          # Persistence Layer (Actors)
│   │   ├── BundleManager.swift           # Central actor for file system operations
│   │   ├── BundleStorage.swift           # Helper for directory paths
│   │   ├── DocumentHandle.swift          # Safe handle for open notebook operations
│   │   └── Manifest.swift                # JSON metadata structure
│   │
│   ├── Editor/                           # EDITOR IMPLEMENTATION (Core Logic)
│   │   ├── EditorViewController.swift    # The main Editor Canvas UI
│   │   ├── EditorViewModel.swift         # Editor state & tool logic
│   │   ├── EngineProvider.swift          # Singleton managing IINKEngine lifecycle
│   │   ├── ToolPaletteView.swift         # Floating custom toolbar
│   │   ├── EditingToolbarView.swift      # Undo/Redo/Clear toolbar
│   │   ├── ColorPaletteView.swift        # Color selection UI
│   │   └── ThicknessSliderView.swift     # Brush thickness control
│   │
│   └── Frameworks/
│       └── Ink/                          # Low-level MyScript Wrappers
│           ├── Input/                    # Touch/Pen input handling
│           │   ├── InputViewController.swift
│           │   └── InputViewModel.swift
│           ├── Rendering/                # Display & rendering logic
│           │   ├── DisplayViewController.swift
│           │   └── DisplayViewModel.swift
│           ├── SmartGuide/               # Text conversion guide UI
│           │   ├── SmartGuideViewController.h
│           │   └── SmartGuideViewController.mm
│           ├── UIObjects/                # Core UI rendering components
│           │   ├── Canvas.swift
│           │   ├── InputView.swift
│           │   ├── RenderView.swift
│           │   └── OffscreenRenderSurfaces.swift
│           └── Utils/                    # Utility helpers
│               ├── FontMetricsProvider.swift
│               ├── ImageLoader.swift
│               ├── ImagePainter.swift
│               ├── TextFormatHelper.swift
│               └── [other utilities]
│
├── MyScriptCertificate/                  # License Key
│   ├── MyCertificate.h
│   └── MyCertificate.c
│
├── Scripts/                              # Build & Utility Scripts
│   ├── buildapp
│   ├── testapp
│   └── retrieve_recognition-assets.sh
│
└── Logs/                                 # Build artifacts & logs
    └── build_logs.txt

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
- IMPORTANT: Whenever implementing anything using a third-party library or framework which is NOT MyScript, access relevant documentation using the Context7 MCP server

## 4: Security & Configuration
- Do not commit private keys or license material beyond the checked-in certificate files.
- Treat `recognition-assets/` as large binary dependencies; avoid editing by hand.