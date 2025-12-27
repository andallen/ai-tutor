# Repository Guidelines

## Project Structure & Module Organization
- `InkOS/`: App source root (App lifecycle, Assets, Bridging Header).
- `InkOS/App/`: High-level navigation and state flow (`AppRootView`, UIKit hosting bridges).
- `InkOS/Features/`: UI and logic for specific features (`Dashboard`, `Notebook` models, Shared components).
- `InkOS/Storage/`: Persistence layer (`BundleManager` actor, `DocumentHandle` actor, `Manifest`).
- `InkOS/Frameworks/IInkUIReferenceImplementation/`: Low-level MyScript integration (Renderer, Editor, Input pipeline).
- `InkOS/GetStarted/`: Engine initialization and legacy view controllers (`EngineProvider`, `HomeViewController`).
- `recognition-assets/`: MyScript recognition assets and configuration files.
- `MyScriptCertificate/`: Certificate material required by the iink SDK.
- `InkOS.xcworkspace`: Workspace for CocoaPods-managed dependencies.

## PROJECT RULES:
## 1. ACTOR ISOLATION & THREAD SAFETY

- The **BundleManager** and **DocumentHandle** must remain Actors to manage disk I/O and folder state without race conditions.
- The **EngineProvider**, **EditorWorker**, and **ToolingWorker** must be annotated with `@MainActor`. This is because the MyScript `IINKEditor` and `IINKRenderer` are not thread-safe and must be accessed from the main thread to sync with the UI.
- Perform heavy export operations (e.g., converting ink to PDF or high-resolution images) in detached tasks or background blocks provided by the SDK to avoid hanging the UI.

## 2. COMMENTS
- Comment frequently with simple and direct language.
- Concisely spell out what every part of the code is doing, making the logic easy to follow.
- Use clear grammar and avoid special headers, decorative markers, or section labels.
- Be impersonal; no first/second/third person.

## 3. ARCHITECTURAL DECOUPLING
- The UI must remain replaceable. SwiftUI views should only handle presentation and layout.
- Data and storage code must live outside the UI. Centralize all file-system access in the **BundleManager** and the **EngineProvider**.

## 5. QUALITY ASSURANCE

- Make errors explicit. Do not use force unwraps (`!`), `try!`, or `fatalError` for expected runtime issues like a missing MyScript certificate or a failed file save.
- Use `throws` and pass error messages back to the UI so the user can be notified.
- Build the code with Scripts/buildapp to ensure it builds successfully; review build logs in Logs/build_logs.txt and fix the errors if there are any.
- Whenever implementing something related to MyScript, refer to the Documentation in Docs/. myscript_docs.md contains the general overview and description of various MyScript features, along with implementation examples. myscript_headers.txt contains all the headers for the various MyScript features and should be treated as the ultimate source of truth, as it is the most up-to-date. Reference/ contains fully functioning example implementations of some of MyScript's features. Use these as your guide.
- Whenever implementing anything using a third-party library or framework which is NOT MyScript, access relevant documentation using the Context7 MCP server

## 6: Security & Configuration
- Do not commit private keys or license material beyond the checked-in certificate files.
- Treat `recognition-assets/` as large binary dependencies; avoid editing by hand.