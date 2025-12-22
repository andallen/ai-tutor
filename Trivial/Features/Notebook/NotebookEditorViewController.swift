import UIKit

// Owns the MyScript editor, renderer, display, and input plumbing.
final class NotebookEditorViewController: UIViewController {
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
        let scale = view.contentScaleFactor
        let sizePx = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        displayViewModel.editor?.viewSize = sizePx
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
        do {
            try documentHandle.save()
        } catch {
        }
    }

    private func setupMyScript() {
        do {
            // Creates or reuses a shared engine instance.
            let provider = try EngineProvider.shared()
            engineProvider = provider

            // Creates a renderer bound to the display view model render target.
            let dpi = Helper.scaledDpi()
            let renderer = try provider.engine.createRenderer(dpiX: dpi, dpiY: dpi, target: displayViewModel)
            displayViewModel.renderer = renderer

            // Creates an editor linked to the renderer.
            let editor = try provider.engine.createEditor(renderer: renderer)
            displayViewModel.editor = editor

            // Assigns a font metrics provider for text layout.
            editor.textFontMetricsProvider = provider.fontMetricsProvider

            // Connects touch input to the editor.
            inputViewOverlay.editor = editor

            // Creates a tool controller for gesture and tool behavior.
            // Stores it for later extensions even if unused for raw input.
            let toolController = try provider.engine.createToolController(editor: editor)
            inputViewOverlay.toolController = toolController

            // Forces an initial redraw after wiring core objects.
            displayViewModel.refreshDisplay()
        } catch {
            // Leaves the screen empty if engine setup fails.
        }
    }

    private func loadDocument() {
        guard let provider = engineProvider, let editor = displayViewModel.editor else {
            return
        }

        do {
            // Opens or creates the backing package file.
            let package = try documentHandle.openOrCreatePackage(with: provider.engine)

            // Opens the first part or creates one if the package is empty.
            let part = try documentHandle.openOrCreateFirstPart(in: package)

            // Connects the editor to the loaded part.
            editor.part = part

            // Requests a full redraw after part assignment.
            displayViewModel.refreshDisplay()
        } catch {
            // Leaves the screen empty if the package cannot be opened.
        }
    }
}