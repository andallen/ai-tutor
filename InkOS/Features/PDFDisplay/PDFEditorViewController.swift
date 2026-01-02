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
  // Tracks whether touch mode is active for tap-to-dismiss behavior.
  private var isTouchModeEnabled = false
  // Stores the tap gesture that dismisses the tool palette.
  private var outsideTapRecognizer: UITapGestureRecognizer?
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
    configureEditingToolbar()
    configureTapToDismissPalette()
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

    // Pen/Touch toggle.
    let segmentedControl = UISegmentedControl(items: ["Pen", "Touch"])
    segmentedControl.selectedSegmentIndex = 0
    segmentedControl.addTarget(
      self,
      action: #selector(inputModeChanged),
      for: .valueChanged
    )
    navigationItem.titleView = segmentedControl

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
    let inputViewModel = InputViewModel(
      engine: engine,
      inputMode: .forcePen,
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

  @objc private func inputModeChanged(_ sender: UISegmentedControl) {
    let mode: InputMode = sender.selectedSegmentIndex == 0 ? .forcePen : .forceTouch
    isTouchModeEnabled = mode == .forceTouch
    inputVM?.updateInputMode(newInputMode: mode)
    // Reapply touch tool based on new input mode.
    applyTouchToolForCurrentMode()
  }

  private func handleToolSelection(_ tool: ToolPaletteView.ToolSelection) {
    selectedTool = tool
    switch tool {
    case .pen:
      inputVM?.selectPenTool()
    case .eraser:
      inputVM?.selectEraserTool()
    case .highlighter:
      inputVM?.selectHighlighterTool()
    }
    // Also apply the tool to touch pointer type based on current mode.
    applyTouchToolForCurrentMode()
  }

  // Applies the correct tool to the touch pointer type based on input mode.
  // In forcePen mode, touch uses the same tool as pen.
  // In forceTouch mode, touch uses the hand tool for panning.
  private func applyTouchToolForCurrentMode() {
    guard let editor = inputVM?.editor else { return }
    let tool = mapToolSelectionToPointerTool(selectedTool)
    do {
      if isTouchModeEnabled {
        try editor.editorToolController.setToolForPointerType(tool: .hand, pointerType: .touch)
      } else {
        try editor.editorToolController.setToolForPointerType(tool: tool, pointerType: .touch)
      }
    } catch {
      // Silently ignore tool setting errors.
    }
  }

  // Handles color selection changes from the tool palette.
  private func handleColorSelection(tool: ToolPaletteView.ToolSelection, hex: String) {
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
  private func handleThicknessChange(tool: ToolPaletteView.ToolSelection, width: CGFloat) {
    switch tool {
    case .pen:
      selectedPenWidth = width
      inputVM?.setToolStyle(colorHex: selectedPenColorHex, width: width, tool: .toolPen)
    case .highlighter:
      selectedHighlighterWidth = width
      inputVM?.setToolStyle(colorHex: selectedHighlighterColorHex, width: width, tool: .toolHighlighter)
    case .eraser:
      break
    }
  }

  private func showError(_ message: String) {
    let alert = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
      self?.backButtonTapped()
    })
    present(alert, animated: true)
  }

  // Adds a tap gesture that dismisses the tool palette in touch mode.
  private func configureTapToDismissPalette() {
    let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
    recognizer.cancelsTouchesInView = false
    recognizer.delegate = self
    view.addGestureRecognizer(recognizer)
    outsideTapRecognizer = recognizer
  }

  // Handles taps outside the tool palette when touch mode is enabled.
  @objc private func handleOutsideTap(_ recognizer: UITapGestureRecognizer) {
    guard isTouchModeEnabled else {
      return
    }
    guard let toolPalette = toolPalette, toolPalette.isExpanded else {
      return
    }
    toolPalette.setToolbarVisible(false, animated: true)
  }
}

extension PDFEditorViewController: UIGestureRecognizerDelegate {

  // Allows the tap recognizer only when the palette is open and the touch is outside it.
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch)
    -> Bool {
    guard isTouchModeEnabled else {
      return false
    }
    guard let toolPalette = toolPalette, toolPalette.isExpanded else {
      return false
    }
    let location = touch.location(in: view)
    if toolPalette.containsInteraction(at: location, in: view) {
      return false
    }
    return true
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
    // This ensures the pen works immediately without requiring toolbar interaction.
    let tool = mapToolSelectionToPointerTool(selectedTool)
    do {
      try editor.toolController.setToolForPointerType(tool: tool, pointerType: .pen)
      // In forcePen mode, touch also uses the same tool; in forceTouch, touch uses hand.
      if isTouchModeEnabled {
        try editor.toolController.setToolForPointerType(tool: .hand, pointerType: .touch)
      } else {
        try editor.toolController.setToolForPointerType(tool: tool, pointerType: .touch)
      }
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
