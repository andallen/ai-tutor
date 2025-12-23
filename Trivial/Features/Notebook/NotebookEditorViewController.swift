import UIKit

// Owns the MyScript editor, renderer, display, and input plumbing.
final class NotebookEditorViewController: UIViewController, UIGestureRecognizerDelegate {
    // Identifies which notebook package should be opened.
    private let documentHandle: DocumentHandle

    // Owns the engine and shared providers needed by the editor.
    private var engineProvider: EngineProvider?

    // Receives invalidation callbacks and routes them into the render views.
    private let displayViewModel = DisplayViewModel()

    // Installs the render views.
    private let displayVC: DisplayViewController

    // Converts touches into pointer events for the editor.
    private let inputViewOverlay = InputView(frame: .zero)

    // Tracks whether the package and part have been loaded.
    private var didLoadDocument = false

    // Restores the previous navigation controller swipe-back behavior on exit.
    private var previousInteractivePopEnabled: Bool?
    private weak var previousInteractivePopDelegate: UIGestureRecognizerDelegate?

    private final class EditorDelegateProxy: NSObject, IINKEditorDelegate {
        private let onContentChanged: @MainActor () -> Void

        init(onContentChanged: @escaping @MainActor () -> Void) {
            self.onContentChanged = onContentChanged
        }

        func onError(_ editor: IINKEditor, blockId: String, message: String) {
            print("❌ MyScript Editor Error [BlockId: \(blockId)]: \(message)")
        }

        func partChanged(_ editor: IINKEditor) {}

        func contentChanged(_ editor: IINKEditor, blockIds: [String]) {
            Task { @MainActor in
                onContentChanged()
            }
        }
    }

    private var pendingSaveTask: Task<Void, Never>?

    private lazy var editorDelegateProxy = EditorDelegateProxy { [weak self] in
        guard let self else { return }
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [documentHandle] in
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
            await MainActor.run { [weak self] in
                self?.displayViewModel.editor?.waitForIdle()
            }

            do {
                try await documentHandle.savePackage()
            } catch {
                print("❌ NotebookEditorViewController: Failed to save package: \(error)")
            }
        }
    }

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
        do {
            try displayViewModel.editor?.set(viewSize: sizePx)
        } catch {
            print("❌ NotebookEditorViewController: Failed to set view size: \(error)")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Prevent interactive swipe-back from stealing/cancelling input on the canvas.
        if let popGesture = navigationController?.interactivePopGestureRecognizer {
            if previousInteractivePopEnabled == nil {
                previousInteractivePopEnabled = popGesture.isEnabled
                previousInteractivePopDelegate = popGesture.delegate
            }
            popGesture.delegate = self
            popGesture.isEnabled = false
        }

        // Loads the package and part once when the screen becomes visible.
        guard !didLoadDocument else { return }
        didLoadDocument = true
        loadDocument()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Restore swipe-back for other screens.
        if let popGesture = navigationController?.interactivePopGestureRecognizer,
           let previousInteractivePopEnabled
        {
            popGesture.delegate = previousInteractivePopDelegate
            popGesture.isEnabled = previousInteractivePopEnabled
        }

        // Attempts to persist the package on exit.
        // Ignores errors here to keep navigation responsive.
        Task { [weak self, documentHandle] in
            // Ensure there is no active pointer sequence and wait for pending edits to complete.
            await MainActor.run {
                guard let editor = self?.displayViewModel.editor else { return }
                do {
                    try editor.pointerCancel(-1)
                } catch {
                    // Ignore cancel errors; still try to persist.
                }
                editor.waitForIdle()
            }

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

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Block the interactive pop gesture while editing.
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            return false
        }
        return true
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
                
                // Sets the editor view size if the view has valid bounds.
                await MainActor.run {
                    let scale = view.window?.screen.scale ?? UIScreen.main.scale
                    view.contentScaleFactor = scale
                    let sizePx = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
                    if sizePx.width > 0 && sizePx.height > 0 {
                        do {
                            try editor.set(viewSize: sizePx)
                        } catch {
                            print("❌ NotebookEditorViewController: Failed to set view size: \(error)")
                        }
                    }
                }

                // Creates a font metrics provider for text layout.
                let fontProvider = FontMetricsProvider()
                editor.set(fontMetricsProvider: fontProvider)

                // Connects touch input to the editor.
                inputViewOverlay.editor = editor

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
                    // Creates a new text part if the package is empty.
                    part = try package.createPart(with: "Text Document")
                }

                // Connects the editor to the loaded part.
                await MainActor.run {
                    editor.part = part
                    // Requests a full redraw after part assignment.
                    displayViewModel.refreshDisplay()
                }
            } catch {
                print("❌ NotebookEditorViewController.loadDocument failed: \(error)")
            }
        }
    }
}
