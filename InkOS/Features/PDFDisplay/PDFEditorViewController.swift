// PDFEditorViewController.swift
// UIViewController hosting the MyScript canvas for PDF annotation.
// Reuses existing InputViewController for pen/touch input and rendering.

import Combine
import UIKit

// View controller for annotating PDF documents.
// Hosts the MyScript canvas with PDF pages rendered as background.
final class PDFEditorViewController: UIViewController {

  // MARK: - Properties

  private let viewModel: PDFEditorViewModel
  // Named to avoid conflict with UIViewController.inputViewController.
  private var editorInputVC: InputViewController?
  private var inputVM: InputViewModel?
  private var toolPalette: ToolPaletteView?
  private var cancellables: Set<AnyCancellable> = []
  private let offBlack = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
  // Provides the default Raw Content configuration for recognition.
  private let configurationProvider = DefaultRawContentConfigurationProvider()
  // Applies configuration to the engine.
  private let configurationApplier = RawContentConfigurationApplier()
  // Tracks the current pen color hex string.
  private var selectedPenColorHex = "#000000"
  // Tracks the current highlighter color hex string.
  private var selectedHighlighterColorHex = "#FFF176"
  // Tracks the current pen width in mm.
  private var selectedPenWidth: CGFloat = 0.65
  // Tracks the current highlighter width in mm.
  private var selectedHighlighterWidth: CGFloat = 5.0
  // Tracks the currently selected tool.
  private var selectedTool: ToolPaletteView.ToolSelection = .pen
  // Stores the editing toolbar for undo/redo/clear actions.
  private var editingToolbarView: EditingToolbarView?
  // Tracks visibility state of the editing toolbar.
  private var isEditingToolbarVisible = true
  // Tap gesture recognizer to dismiss the tool palette when tapping outside with a finger.
  private var paletteDismissTapRecognizer: UITapGestureRecognizer?

  // Handler called when the editor requests dismissal.
  var dismissHandler: (() -> Void)?

  // MARK: - Initialization

  init(viewModel: PDFEditorViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    configureNavigationBar()
    setupInputViewController()
    configureToolPalette()
    configurePaletteDismissTap()
    configureEditingToolbar()
    loadDocument()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    inputVM?.setEditorViewSize(size: view.bounds.size)
  }

  // MARK: - Setup

  private func configureNavigationBar() {
    // Back/home button.
    let backImage = UIImage(systemName: "house")?.withRenderingMode(.alwaysTemplate)
    let backItem = UIBarButtonItem(
      image: backImage,
      style: .plain,
      target: self,
      action: #selector(backButtonTapped)
    )
    backItem.accessibilityLabel = "Home"
    backItem.tintColor = offBlack
    navigationItem.leftBarButtonItem = backItem

    // Document title.
    title = viewModel.session.noteDocument.displayName
  }

  private func setupInputViewController() {
    // Cast to IINKEngine since InputViewModel expects concrete SDK type.
    guard let engine = EngineProvider.sharedInstance.engineInstance as? IINKEngine else {
      showError("Annotation engine not available")
      return
    }

    // Create InputViewModel with the background renderer for PDF pages.
    // Pass self as editorDelegate to receive didCreateEditor callback for configuration.
    // Auto mode: stylus writes with the selected tool, finger navigates with HAND tool.
    let inputViewModel = InputViewModel(
      engine: engine,
      inputMode: .auto,
      editorDelegate: self,
      smartGuideDelegate: nil,
      smartGuideDisabled: true
    )
    inputViewModel.backgroundRenderer = viewModel.backgroundRenderer
    // Set total content height for proper vertical scroll bounds across all PDF pages.
    inputViewModel.totalContentHeight = viewModel.totalContentSize.height
    self.inputVM = inputViewModel

    // Create InputViewController.
    let inputVC = InputViewController(viewModel: inputViewModel)
    self.editorInputVC = inputVC

    // Add as child view controller.
    addChild(inputVC)
    view.addSubview(inputVC.view)
    inputVC.view.frame = view.bounds
    inputVC.view.autoresizingMask = [
      UIView.AutoresizingMask.flexibleWidth,
      UIView.AutoresizingMask.flexibleHeight
    ]
    inputVC.didMove(toParent: self)
  }

  private func configureToolPalette() {
    let palette = ToolPaletteView(accentColor: offBlack)
    palette.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(palette)

    // Position at bottom of screen spanning full width with margins.
    // Matches the layout used in EditorViewController.
    palette.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    palette.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    palette.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -8
    ).isActive = true

    // Wire up tool selection.
    palette.selectionChanged = { [weak self] tool in
      self?.handleToolSelection(tool)
    }

    // Wire up color selection.
    palette.colorSelectionChanged = { [weak self] tool, hex in
      self?.handleColorSelection(tool: tool, hex: hex)
    }

    // Wire up thickness changes.
    palette.thicknessChanged = { [weak self] tool, width in
      self?.handleThicknessChange(tool: tool, width: width)
    }

    // Hide editing toolbar when palette expands, show when it collapses.
    palette.expansionChanged = { [weak self] isExpanded in
      self?.updateEditingToolbarVisibility(isExpanded == false, animated: true)
    }

    self.toolPalette = palette
  }

  // Configures tap gesture to collapse the tool palette when tapping outside with a finger.
  private func configurePaletteDismissTap() {
    let tapRecognizer = UITapGestureRecognizer(
      target: self,
      action: #selector(handlePaletteDismissTap(_:))
    )
    // Only respond to finger touches, not Apple Pencil.
    tapRecognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
    // Allow simultaneous recognition so it doesn't interfere with drawing.
    tapRecognizer.cancelsTouchesInView = false
    tapRecognizer.delegate = self
    view.addGestureRecognizer(tapRecognizer)
    paletteDismissTapRecognizer = tapRecognizer
  }

  // Handles taps outside the tool palette to collapse it.
  @objc private func handlePaletteDismissTap(_ recognizer: UITapGestureRecognizer) {
    guard let palette = toolPalette, palette.isExpanded else {
      return
    }
    // Only collapse if the tap is outside the palette.
    let location = recognizer.location(in: view)
    if palette.containsInteraction(at: location, in: view) == false {
      palette.setToolbarVisible(false, animated: true)
    }
  }

  // Adds the editing toolbar (undo/redo/clear) to the bottom right of the screen.
  private func configureEditingToolbar() {
    let toolbarView = EditingToolbarView(accentColor: offBlack)
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.undoTapped = { [weak self] in
      self?.inputVM?.undo()
    }
    toolbarView.redoTapped = { [weak self] in
      self?.inputVM?.redo()
    }
    toolbarView.clearTapped = { [weak self] in
      self?.inputVM?.clear()
    }
    view.addSubview(toolbarView)

    toolbarView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    toolbarView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -4
    ).isActive = true
    editingToolbarView = toolbarView
  }

  // Shows or hides the editing toolbar with animation.
  private func updateEditingToolbarVisibility(_ visible: Bool, animated: Bool) {
    guard let toolbarView = editingToolbarView else {
      return
    }
    guard visible != isEditingToolbarVisible else {
      return
    }
    isEditingToolbarVisible = visible
    let offset = max(toolbarView.bounds.height, 36) + 12
    if visible {
      toolbarView.isHidden = false
      toolbarView.alpha = 0
      toolbarView.transform = CGAffineTransform(translationX: 0, y: offset)
    }

    let animations = {
      toolbarView.alpha = visible ? 1 : 0
      toolbarView.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: offset)
    }

    let completion: (Bool) -> Void = { _ in
      if visible == false {
        toolbarView.isHidden = true
      }
    }

    if animated {
      UIView.animate(
        withDuration: 0.22,
        delay: 0,
        options: [.curveEaseInOut],
        animations: animations,
        completion: completion
      )
    } else {
      animations()
      completion(true)
    }
  }

  private func loadDocument() {
    Task {
      do {
        try await viewModel.loadPart()

        // Set the part on the editor.
        guard let part = viewModel.part else {
          showError("Failed to load annotations")
          return
        }

        // Configure the editor with the part.
        if let iinkPart = part as? IINKContentPart {
          try inputVM?.editor?.setEditorPart(iinkPart)
        }

      } catch {
        showError(error.localizedDescription)
      }
    }
  }

  // MARK: - Actions

  @objc private func backButtonTapped() {
    Task {
      // Save before dismissing.
      try? await viewModel.save()

      // Release the part from the editor to avoid "Part is already being edited" errors.
      inputVM?.releasePart()

      await viewModel.close()

      if let handler = dismissHandler {
        handler()
      } else {
        dismiss(animated: true)
      }
    }
  }
}

// MARK: - Tool Handling

extension PDFEditorViewController {

  fileprivate func handleToolSelection(_ tool: ToolPaletteView.ToolSelection) {
    selectedTool = tool
    switch tool {
    case .pen:
      inputVM?.selectPenTool()
    case .eraser:
      inputVM?.selectEraserTool()
    case .highlighter:
      inputVM?.selectHighlighterTool()
    }
  }

  // Handles color selection changes from the tool palette.
  fileprivate func handleColorSelection(tool: ToolPaletteView.ToolSelection, hex: String) {
    switch tool {
    case .pen:
      selectedPenColorHex = hex
      inputVM?.setToolStyle(colorHex: hex, width: selectedPenWidth, tool: .toolPen)
    case .highlighter:
      selectedHighlighterColorHex = hex
      inputVM?.setToolStyle(colorHex: hex, width: selectedHighlighterWidth, tool: .toolHighlighter)
    case .eraser:
      break
    }
  }

  // Handles thickness changes from the tool palette.
  fileprivate func handleThicknessChange(tool: ToolPaletteView.ToolSelection, width: CGFloat) {
    switch tool {
    case .pen:
      selectedPenWidth = width
      inputVM?.setToolStyle(colorHex: selectedPenColorHex, width: width, tool: .toolPen)
    case .highlighter:
      selectedHighlighterWidth = width
      inputVM?.setToolStyle(
        colorHex: selectedHighlighterColorHex, width: width, tool: .toolHighlighter)
    case .eraser:
      break
    }
  }

  fileprivate func showError(_ message: String) {
    let alert = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(
      UIAlertAction(title: "OK", style: .default) { [weak self] _ in
        self?.backButtonTapped()
      })
    present(alert, animated: true)
  }
}

// MARK: - EditorDelegate

extension PDFEditorViewController: EditorDelegate {

  // Called when the IINKEditor is created. Applies Raw Content configuration
  // to enable handwriting recognition, gestures, and conversion features.
  func didCreateEditor(editor: IINKEditor) {
    // Reset configuration to defaults before applying Raw Content settings.
    // This is required by MyScript SDK to clear any cached configuration values.
    editor.configuration.reset()

    // Apply Raw Content configuration for recognition.
    do {
      let configuration = configurationProvider.provideConfiguration()
      try configurationApplier.applyConfiguration(configuration, to: editor.configuration)
    } catch {
      // Silently ignore configuration errors - recognition may still partially work.
    }

    // Apply initial tool selection for both pointer types.
    // Pen uses the selected tool, touch uses HAND for navigation (auto mode).
    let tool = mapToolSelectionToPointerTool(selectedTool)
    do {
      try editor.toolController.setToolForPointerType(tool: tool, pointerType: .pen)
      try editor.toolController.setToolForPointerType(tool: .hand, pointerType: .touch)
    } catch {
      // Silently ignore tool setting errors.
    }

    // Apply initial ink styles for pen and highlighter.
    let penStyle = String(
      format: "color:%@;-myscript-pen-width:%.3f",
      selectedPenColorHex,
      selectedPenWidth
    )
    let highlighterStyle = String(
      format: "color:%@;-myscript-pen-width:%.3f",
      selectedHighlighterColorHex,
      selectedHighlighterWidth
    )
    do {
      try editor.toolController.setStyleForTool(style: penStyle, tool: .toolPen)
      try editor.toolController.setStyleForTool(style: highlighterStyle, tool: .toolHighlighter)
    } catch {
      // Silently ignore style setting errors.
    }
  }

  // Maps palette selection to the SDK tool enum.
  private func mapToolSelectionToPointerTool(
    _ selection: ToolPaletteView.ToolSelection
  ) -> IINKPointerTool {
    switch selection {
    case .pen:
      return .toolPen
    case .eraser:
      return .eraser
    case .highlighter:
      return .toolHighlighter
    }
  }

  func partChanged(editor: IINKEditor) {
    // Not needed for PDF annotation mode.
  }

  func contentChanged(editor: IINKEditor, blockIds: [String]) {
    // Export and log JIIX for debugging recognition.
    if let jiix = try? editor.export(selection: nil, mimeType: .JIIX) {
      print("===== JIIX EXPORT =====")
      print(jiix)
      print("===== END JIIX =====")
    }
  }

  func onError(editor: IINKEditor, blockId: String, message: String) {
    // Log errors but don't interrupt the user.
  }
}

// MARK: - UIGestureRecognizerDelegate

extension PDFEditorViewController: UIGestureRecognizerDelegate {
  // Allows the palette dismiss tap gesture to work simultaneously with other gestures.
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    // Allow simultaneous recognition for the palette dismiss tap.
    return gestureRecognizer == paletteDismissTapRecognizer
  }
}
