# InkOS — Digital Paper for Claude Code

## Project Overview

InkOS is an iPad app that acts as digital paper. You write with Apple Pencil, tap send, and a raw image of your handwriting appears in Claude Code on your Mac via Universal Clipboard. A Mac menu bar companion (InkOSRelay) auto-pastes incoming images into the terminal.

## Module Organization

```
InkOS/
├── InkOS/                                  # iPad app source
│   ├── InkOSApp.swift                      # App entry point
│   ├── App/AppRootView.swift               # Root navigation, sidebar, note switching
│   └── Features/
│       ├── Notebook/
│       │   ├── Core/NoteModel.swift         # NoteMetadata, NoteData (PKDrawing storage)
│       │   ├── Design/NotebookDesignTokens.swift  # Colors, typography, spacing
│       │   ├── Services/NoteService.swift   # Note CRUD, JSON persistence
│       │   ├── ViewModels/NoteViewModel.swift     # Drawing state, auto-save
│       │   └── Views/
│       │       ├── NoteCanvasView.swift     # Full-screen PencilKit canvas + send
│       │       ├── CanvasView.swift         # PKCanvasView UIViewRepresentable wrapper
│       │       ├── PencilKitToolbarView.swift     # PKToolPicker wrapper
│       │       ├── SidebarView.swift        # Note list, search, rename, delete
│       │       └── SettingsView.swift       # User preferences
│       └── Shared/
│           ├── PNGMetadata.swift            # PNG marker (InkOS-v1) embed/detect
│           ├── UIComponents.swift           # Reusable UI components
│           ├── FileLogger.swift             # Debug file logging
│           └── ContextMenuView.swift        # Context menu UI
│
├── InkOSRelay/                             # Mac menu bar companion
│   ├── main.swift                          # App entry point
│   ├── AppDelegate.swift                   # Menu bar setup, accessibility check
│   ├── ClipboardMonitor.swift              # Polls clipboard, detects marker, simulates Ctrl+V
│   └── PNGMetadata.swift                   # PNG marker detection (shared logic)
│
├── InkOSUITests/                           # UI tests
├── Scripts/                                # buildapp, testapp, test-ui, buildrelay
└── apple-hig/                              # Apple HIG reference
```

## Architecture

### iPad App
- **PencilKit canvas** — full-screen drawing with Apple Pencil
- **Send button** — captures drawing as PNG with embedded `InkOS-v1` metadata marker, copies to system clipboard
- **Universal Clipboard** — Apple syncs to Mac via BLE + AWDL (works on restricted networks)
- **Note persistence** — PKDrawing serialized to JSON files in Documents/notes/

### Mac Companion (InkOSRelay)
- **Clipboard monitor** — polls NSPasteboard.changeCount every 0.5s
- **Marker check** — reads PNG metadata, only acts on InkOS-v1 marked images
- **Terminal check** — only pastes when Terminal.app, iTerm2, Ghostty, Kitty, or Warp is frontmost
- **Ctrl+V simulation** — AppleScript keystroke, Claude Code intercepts for image paste

### PNG Metadata Marker
Images are marked by embedding `"InkOS-v1"` in the PNG tEXt description chunk via `CGImageDestination`. The Mac companion reads this via `CGImageSource` to distinguish InkOS images from regular clipboard copies.

## Project Rules

### 1. Comments
- Comment frequently with simple and direct language
- Concisely spell out what every part of the code is doing
- Be impersonal; no first/second/third person

### 2. Quality Assurance
- Make errors explicit. No force unwraps (`!`), `try!`, or `fatalError`
- Use `throws` and pass error messages back to the UI

## Build Commands

- **Build iOS**: `Scripts/buildapp`
- **Test iOS**: `Scripts/testapp`
- **UI Test iOS**: `Scripts/test-ui`
- **Build Mac Relay**: `Scripts/buildrelay`
