import UIKit

// Owns the MyScript editor, renderer, display, and input plumbing.
final class NotebookEditorViewController: UIViewController {
    // Identifies which notebook package should be opened.
    private let documentHandle: DocumentHandle

    // Owns the engine and shared providers needed by the editor.
    private var engineProvider: EngineProvider?

    // Receives invalidation callbacks and routes them into the render views.
    private let displayViewModel = DisplayViewModel()

    // Installs the render views.
    private let displayVC: DisplayViewController

    // Converts touches into pointer events for the editor.
    private let inputViewOverlay = InputView(frame: .zero)

    // Tracks whether the package and part have been loaded.
    private var didLoadDocument = false

    private final class EditorDelegateProxy: NSObject, IINKEditorDelegate {
        private let onContentChanged: @MainActor () -> Void
        private let onFirstContentChange: @MainActor (IINKEditor, [String]) -> Void
        private var didLogStyle = false

        init(
            onContentChanged: @escaping @MainActor () -> Void,
            onFirstContentChange: @escaping @MainActor (IINKEditor, [String]) -> Void
        ) {
            self.onContentChanged = onContentChanged
            self.onFirstContentChange = onFirstContentChange
        }

        func onError(_ editor: IINKEditor, blockId: String, message: String) {
            print("❌ MyScript Editor Error [BlockId: \(blockId)]: \(message)")
        }

        func partChanged(_ editor: IINKEditor) {}

        func contentChanged(_ editor: IINKEditor, blockIds: [String]) {
            Task { @MainActor in
                print("📈 NotebookEditorViewController.contentChanged blockIds=\(blockIds)")
                if !didLogStyle {
                    didLogStyle = true
                    onFirstContentChange(editor, blockIds)
                }
                onContentChanged()
            }
        }
    }

    private var pendingSaveTask: Task<Void, Never>?

    private lazy var editorDelegateProxy = EditorDelegateProxy(
        onContentChanged: { [weak self] in
        guard let self else { return }
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [documentHandle, weak self] in
            guard let self else { return }
            // Save quickly to the temp folder for crash resilience.
            do {
                try await documentHandle.savePackageToTemp()
            } catch {
                print("❌ NotebookEditorViewController: Failed to save package to temp: \(error)")
            }

            // Debounce archive saves to avoid writing on every small change.
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            // Ensure pending editor work is complete before persisting.
            await self.waitForEditorIdle(context: "autosave")

            do {
                try await documentHandle.savePackage()
            } catch {
                print("❌ NotebookEditorViewController: Failed to save package: \(error)")
            }
        }
        },
        onFirstContentChange: { [weak self] editor, blockIds in
            self?.logEditorContentState(editor, context: "contentChanged")
        }
    )

    init(documentHandle: DocumentHandle) {
        self.documentHandle = documentHandle
        self.displayVC = DisplayViewController(viewModel: displayViewModel)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Sets a clean background for the writing surface.
        view.backgroundColor = .systemBackground

        // Installs the display controller so rendering can start early.
        addChild(displayVC)
        view.addSubview(displayVC.view)
        displayVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            displayVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            displayVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            displayVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            displayVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        displayVC.didMove(toParent: self)

        // Installs the input overlay on top of the render views.
        view.addSubview(inputViewOverlay)
        inputViewOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inputViewOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputViewOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputViewOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            inputViewOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Builds the engine, editor, renderer, and tool controller.
        setupMyScript()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Sets the editor view size in pixels.
        // Treats invalidation rectangles as pixel rectangles.
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        view.contentScaleFactor = scale
        let sizePx = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        print("🧭 NotebookEditorViewController.viewDidLayoutSubviews sizePx=\(sizePx)")
        do {
            try displayViewModel.editor?.set(viewSize: sizePx)
            if let renderer = displayViewModel.renderer {
                let beforeScale = renderer.viewScale
                let beforeOffset = renderer.viewOffset
                renderer.viewScale = 1
                renderer.viewOffset = .zero
                print("🧭 NotebookEditorViewController.viewDidLayoutSubviews renderer viewScale \(beforeScale)→\(renderer.viewScale) viewOffset \(beforeOffset)→\(renderer.viewOffset)")
            }
        } catch {
            print("❌ NotebookEditorViewController: Failed to set view size: \(error)")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Loads the package and part once when the screen becomes visible.
        guard !didLoadDocument else { return }
        didLoadDocument = true
        loadDocument()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Attempts to persist the package on exit.
        // Ignores errors here to keep navigation responsive.
        Task { [weak self, documentHandle] in
            guard let self else { return }
            // Ensure there is no active pointer sequence and wait for pending edits to complete.
            await MainActor.run {
                guard let editor = self.displayViewModel.editor else { return }
                do {
                    try editor.pointerCancel(-1)
                } catch {
                    // Ignore cancel errors; still try to persist.
                }
            }
            await self.waitForEditorIdle(context: "viewWillDisappear")

            do {
                try await documentHandle.savePackage()
            } catch {
                // Ignore save errors during navigation.
            }
        }
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        // Defers all system edge gestures to the app so touch events are delivered immediately.
        // This prevents iOS from holding touches at the gesture gate, which causes invisible ink
        // when the initial touchesBegan events arrive too late for stroke construction.
        return .all
    }


    private func setupMyScript() {
        Task {
            do {
                // Creates or reuses a shared engine instance.
                let provider = EngineProvider.shared
                if provider.engine == nil {
                    try await provider.initializeEngine()
                }
                engineProvider = provider

                guard let engine = provider.engine else {
                    print("❌ NotebookEditorViewController: Engine is nil after initialization")
                    return
                }
                print("🧭 NotebookEditorViewController.setupMyScript engine ready")

                // Creates a renderer bound to the display view model render target.
                let dpi = Helper.scaledDpi()
                let renderer = try engine.createRenderer(dpiX: dpi, dpiY: dpi, target: displayViewModel)
                displayViewModel.renderer = renderer
                // Updates renderer on existing RenderViews if model already exists.
                await MainActor.run {
                    displayViewModel.updateRenderer()
                }

                // Creates a tool controller for gesture and tool behavior.
                // Must be created before the editor.
                let toolController = engine.createToolController()
                inputViewOverlay.toolController = toolController

                // Creates an editor linked to the renderer and tool controller.
                guard let editor = engine.createEditor(renderer: renderer, toolController: toolController) else {
                    print("❌ NotebookEditorViewController: Failed to create editor")
                    return
                }
                displayViewModel.editor = editor
                editor.addDelegate(editorDelegateProxy)
                print("🧭 NotebookEditorViewController.setupMyScript editor ready")

                // Configure default ink behavior and style.
                // If tool style is not set, the renderer may legitimately request fully transparent strokes (0x00000000).
                do {
                    // Reference implementation uses 6-digit hex colors (#RRGGBB), alpha handled internally.
                    try editor.set(theme: ".ink { color: #000000; -myscript-pen-width: 1.5; }")
                } catch {
                    print("❌ NotebookEditorViewController: Failed to set theme: \(error)")
                }
                do {
                    try editor.toolController.set(tool: IINKPointerTool.toolPen, forType: IINKPointerType.touch)
                    try editor.toolController.set(tool: IINKPointerTool.toolPen, forType: IINKPointerType.pen)
                } catch {
                    print("❌ NotebookEditorViewController: Failed to map tools: \(error)")
                }
                do {
                    try editor.toolController.set(style: "color:#000000;-myscript-pen-width:1.5", forTool: IINKPointerTool.toolPen)
                } catch {
                    print("❌ NotebookEditorViewController: Failed to set pen style: \(error)")
                }
                logEditorStyle(editor, context: "setupMyScript")
                
                // Sets the editor view size if the view has valid bounds.
                await MainActor.run {
                    let scale = view.window?.screen.scale ?? UIScreen.main.scale
                    view.contentScaleFactor = scale
                    let sizePx = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
                    if sizePx.width > 0 && sizePx.height > 0 {
                        do {
                            try editor.set(viewSize: sizePx)
                            let beforeScale = renderer.viewScale
                            let beforeOffset = renderer.viewOffset
                            renderer.viewScale = 1
                            renderer.viewOffset = .zero
                            print("🧭 NotebookEditorViewController.setupMyScript renderer viewScale \(beforeScale)→\(renderer.viewScale) viewOffset \(beforeOffset)→\(renderer.viewOffset)")
                        } catch {
                            print("❌ NotebookEditorViewController: Failed to set view size: \(error)")
                        }
                    }
                }
                print("🧭 NotebookEditorViewController.setupMyScript viewSize set")

                // Creates a font metrics provider for text layout.
                let fontProvider = FontMetricsProvider()
                editor.set(fontMetricsProvider: fontProvider)

                // Connects touch input to the editor.
                inputViewOverlay.editor = editor
                // Treat finger input as pen to avoid transparent touch strokes.
                inputViewOverlay.inputMode = .forcePen
                print("🧭 NotebookEditorViewController.setupMyScript inputViewOverlay connected")

                // Forces an initial redraw after wiring core objects.
                displayViewModel.refreshDisplay()
            } catch {
                print("❌ NotebookEditorViewController.setupMyScript failed: \(error)")
            }
        }
    }

    private func loadDocument() {
        guard let editor = displayViewModel.editor else {
            // Retries after a short delay if editor is not yet available.
            print("🧭 NotebookEditorViewController.loadDocument editor not ready, retrying")
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                loadDocument()
            }
            return
        }

        Task {
            do {
                // Gets the package from the document handle.
                guard let package = await documentHandle.getPackage() else {
                    print("❌ NotebookEditorViewController.loadDocument: No package available")
                    return
                }

                // Gets the first part or creates one if the package is empty.
                let partCount = await documentHandle.getPartCount()
                let part: IINKContentPart?
                if partCount > 0 {
                    part = await documentHandle.getPart(at: 0)
                } else {
                    // Creates a new drawing part to keep raw ink visible.
                    part = try package.createPart(with: "Drawing")
                }
                let partType = part?.type ?? "nil"
                let partId = part?.identifier ?? "nil"
                print("🧭 NotebookEditorViewController.loadDocument partCount=\(partCount) partReady=\(part != nil) partType=\(partType) partId=\(partId)")

                // Connects the editor to the loaded part.
                await MainActor.run {
                    editor.part = part
                    // Re-apply theme/tool style after part assignment to avoid transparent ink.
                    do {
                        try editor.set(theme: ".ink { color: #000000; -myscript-pen-width: 1.5; }")
                    } catch {
                        print("❌ NotebookEditorViewController: Failed to set theme after part: \(error)")
                    }
                    do {
                        try editor.toolController.set(style: "color:#000000;-myscript-pen-width:1.5", forTool: IINKPointerTool.toolPen)
                    } catch {
                        print("❌ NotebookEditorViewController: Failed to set pen style after part: \(error)")
                    }
                    logEditorStyle(editor, context: "afterPart")
                    // Requests a full redraw after part assignment.
                    displayViewModel.refreshDisplay()
                    print("🧭 NotebookEditorViewController.loadDocument assigned part and refreshed")
                }
            } catch {
                print("❌ NotebookEditorViewController.loadDocument failed: \(error)")
            }
        }
    }

    private func logEditorStyle(_ editor: IINKEditor, context: String) {
        let themePreview = editor.theme.replacingOccurrences(of: "\n", with: " ")
        let preview = String(themePreview.prefix(120))
        print("🧭 EditorStyle \(context) themeLen=\(editor.theme.count) themePreview=\"\(preview)\"")

        do {
            let penStyle = try editor.toolController.style(forTool: IINKPointerTool.toolPen)
            print("🧭 EditorStyle \(context) penStyle=\(penStyle)")
        } catch {
            print("❌ EditorStyle \(context) penStyle failed: \(error)")
        }

    }

    private func logEditorContentState(_ editor: IINKEditor, context: String) {
        let isEmpty = editor.isEmpty(nil)
        let rootId = editor.rootBlock?.identifier ?? "nil"
        let childCount = editor.rootBlock?.children.count ?? 0
        print("🧭 EditorContent \(context) empty=\(isEmpty) rootId=\(rootId) children=\(childCount)")
    }


    private func waitForEditorIdle(context: String) async {
        let editor = await MainActor.run { displayViewModel.editor }
        guard let editor else {
            return
        }

        final class EditorBox: @unchecked Sendable {
            let editor: IINKEditor

            init(_ editor: IINKEditor) {
                self.editor = editor
            }
        }

        let start = Date()

        let box = EditorBox(editor)
        let watchdog = Task.detached { [start] in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let elapsed = Date().timeIntervalSince(start)
            print("⚠️ NotebookEditorViewController.waitForIdle still running context=\(context) elapsed=\(String(format: "%.2f", elapsed))")
        }

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                box.editor.waitForIdle()
                continuation.resume()
            }
        }

        watchdog.cancel()
        let elapsed = Date().timeIntervalSince(start)
    }
}
