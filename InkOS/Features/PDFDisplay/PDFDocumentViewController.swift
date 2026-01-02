// PDFDocumentViewController.swift
// Main view controller for displaying and annotating PDF documents.
// Uses unified scroll view canvas with single IINKEditor overlay.
// swiftlint:disable file_length
// File length exceeded due to comprehensive protocol implementations and tool management.
// Splitting this file would reduce cohesion of the view controller's responsibilities.

import Combine
import PDFKit
import UIKit

// Main view controller managing PDF document display and annotation.
// Coordinates between the scroll view, background layer, and ink input controller.
// Follows EditorViewController patterns for tool management.
// Implements PDFPartSwitching and PDFToolApplication for ink input integration.
// Implements PDFInkInputWiring for setting up the ink input layer.
// Implements PDFEditorLifecycle for managing editor lifecycle events.
// Implements EditorDelegate for receiving editor callbacks.
class PDFDocumentViewController: UIViewController, PDFDocumentViewControllerProtocol,
  PDFPartSwitching, PDFToolApplication, PDFInkInputWiring, PDFEditorLifecycle, EditorDelegate {

  // MARK: - Properties

  // The NoteDocument being displayed.
  let noteDocument: NoteDocument

  // The PDFDocument containing page content.
  let pdfDocument: PDFDocument

  // Current zoom scale.
  var currentZoomScale: CGFloat {
    return documentView?.currentZoomScale ?? 1.0
  }

  // The main document view (UIScrollView subclass).
  private(set) var documentView: (any PDFDocumentViewProtocol)?

  // Handle for managing the opened document.
  private var documentHandle: PDFDocumentHandle?

  // The input view controller managing ink capture.
  // Exposed for PDFInkInputWiring protocol.
  private(set) var inkInputViewController: InputViewController?

  // Auto-save work item for debounced saving.
  private var autoSaveWorkItem: DispatchWorkItem?

  // Auto-save delay in seconds.
  private let autoSaveDelay: TimeInterval = 2.0

  // The gesture recognizer for part switching.
  private var partSwitchGesture: UILongPressGestureRecognizer?

  // View model for ink input.
  private var inputViewModel: InputViewModel?

  // Combine cancellables for data binding.
  private var cancellables: Set<AnyCancellable> = []

  // Accent color for UI elements.
  private let offBlack = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)

  // Stores the floating tool palette.
  private var toolPaletteView: ToolPaletteView?

  // Stores the editing toolbar.
  private var editingToolbarView: EditingToolbarView?

  // Tracks editing toolbar visibility.
  private var isEditingToolbarVisible = true

  // Tracks touch mode state.
  private var isTouchModeEnabled = false

  // Tap gesture for dismissing palette.
  private var outsideTapRecognizer: UITapGestureRecognizer?

  // Segmented control for pen/touch mode.
  private var inputTypeSegmentedControl: UISegmentedControl?

  // Flag to prevent duplicate exit preparation.
  private var hasPreparedForExit = false

  // Current tool selection state.
  private var currentToolSelection: ToolPaletteView.ToolSelection = .pen

  // Current ink color.
  private var currentInkColorHex = "#000000"

  // Current ink width.
  private var currentInkWidth: CGFloat = 0.65

  // Active editor reference.
  // Exposed as a weak var for PDFToolApplication protocol.
  weak var activeEditor: IINKEditor?

  // MARK: - PDFPartSwitching Properties

  // The currently active block index. -1 indicates no block is active.
  private(set) var activeBlockIndex: Int = -1

  // Delegate receiving part switching notifications.
  weak var partSwitchingDelegate: PDFPartSwitchingDelegate?

  // The currently active MyScript part ID.
  private var currentPartID: String?

  // MARK: - Initialization

  // Creates a controller with the documents to display.
  // Throws PDFDocumentError if validation fails.
  init(noteDocument: NoteDocument, pdfDocument: PDFDocument) throws {
    // Validate inputs.
    guard !noteDocument.blocks.isEmpty else {
      throw PDFDocumentError.emptyDocument
    }

    // Validate all page indices are valid.
    for (index, block) in noteDocument.blocks.enumerated() {
      if case .pdfPage(let pageIndex, _, _) = block {
        guard pageIndex >= 0 && pageIndex < pdfDocument.pageCount else {
          throw PDFDocumentError.pageIndexOutOfBounds(
            blockIndex: index,
            pageIndex: pageIndex,
            pdfPageCount: pdfDocument.pageCount
          )
        }
      }
    }

    self.noteDocument = noteDocument
    self.pdfDocument = pdfDocument
    super.init(nibName: nil, bundle: nil)
  }

  // Not supported.
  required init?(coder: NSCoder) {
    fatalError("PDFDocumentViewController does not support Interface Builder")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    setupDocumentView()
    configureNavigationItems()
    configureToolPalette()
    configureEditingToolbar()
    configureTapToDismissPalette()

    // Register for app lifecycle notifications.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if isBeingDismissed || isMovingFromParent {
      prepareForExit()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  // MARK: - Setup

  private func setupDocumentView() {
    // Create the document view.
    let docView = PDFDocumentView(noteDocument: noteDocument, pdfDocument: pdfDocument)
    docView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(docView)

    // Pin to view edges.
    NSLayoutConstraint.activate([
      docView.topAnchor.constraint(equalTo: view.topAnchor),
      docView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      docView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      docView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    documentView = docView
  }

  // Configures the document handle for MyScript integration.
  func configure(documentHandle: PDFDocumentHandle) {
    self.documentHandle = documentHandle
  }

  // MARK: - PDFDocumentViewControllerProtocol

  // Scrolls to make the specified block visible.
  func scrollTo(blockIndex: Int, animated: Bool) {
    documentView?.scrollTo(blockIndex: blockIndex, animated: animated)
  }

  // MARK: - Navigation

  private func configureNavigationItems() {
    configureNavigationBarAppearance()

    // Home button on the left.
    let backImage = UIImage(systemName: "house")?.withRenderingMode(.alwaysTemplate)
    let backItem = UIBarButtonItem(
      image: backImage,
      style: .plain,
      target: self,
      action: #selector(backButtonTapped)
    )
    backItem.accessibilityLabel = "Home"
    backItem.tintColor = offBlack
    if backImage == nil {
      backItem.title = "Home"
    }
    navigationItem.leftBarButtonItem = backItem

    // Pen/Touch toggle in center.
    let segmentedControl = UISegmentedControl(items: ["Pen", "Touch"])
    segmentedControl.selectedSegmentIndex = 0
    segmentedControl.addTarget(
      self,
      action: #selector(inputTypeSegmentedControlValueChanged(_:)),
      for: .valueChanged
    )
    isTouchModeEnabled = false
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .foregroundColor: offBlack
    ]
    segmentedControl.setTitleTextAttributes(titleAttributes, for: .normal)
    segmentedControl.setTitleTextAttributes(titleAttributes, for: .selected)
    segmentedControl.selectedSegmentTintColor = offBlack.withAlphaComponent(0.12)
    inputTypeSegmentedControl = segmentedControl
    navigationItem.titleView = segmentedControl
    navigationItem.rightBarButtonItem = nil
  }

  private func configureNavigationBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = .clear
    appearance.shadowColor = .clear
    let buttonAppearance = appearance.buttonAppearance
    clearBarButtonItemBackground(buttonAppearance)
    appearance.buttonAppearance = buttonAppearance
    navigationController?.navigationBar.isTranslucent = true
    navigationItem.standardAppearance = appearance
    navigationItem.scrollEdgeAppearance = appearance
    navigationItem.compactAppearance = appearance
  }

  private func clearBarButtonItemBackground(_ appearance: UIBarButtonItemAppearance) {
    appearance.normal.backgroundImage = UIImage()
    appearance.highlighted.backgroundImage = UIImage()
    appearance.disabled.backgroundImage = UIImage()
  }

  // MARK: - Actions

  @objc private func inputTypeSegmentedControlValueChanged(_ sender: UISegmentedControl) {
    guard let inputMode = InputMode(rawValue: sender.selectedSegmentIndex) else { return }
    isTouchModeEnabled = inputMode == .forceTouch
    inkInputViewController?.updateInputMode(newInputMode: inputMode)
  }

  @objc private func handleOutsideTap(_ recognizer: UITapGestureRecognizer) {
    guard isTouchModeEnabled else { return }
    guard let toolPaletteView = toolPaletteView, toolPaletteView.isExpanded else { return }
    toolPaletteView.setToolbarVisible(false, animated: true)
  }

  @objc private func backButtonTapped() {
    prepareForExit()
    dismiss(animated: true)
  }

  @objc private func handleWillResignActive() {
    // Save document when app goes to background.
    Task {
      try? await documentHandle?.savePackage()
    }
  }

  private func prepareForExit() {
    guard hasPreparedForExit == false else { return }
    hasPreparedForExit = true

    // Close the document handle.
    Task {
      await documentHandle?.close()
    }
  }
}

// MARK: - UIGestureRecognizerDelegate

extension PDFDocumentViewController: UIGestureRecognizerDelegate {

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldReceive touch: UITouch
  ) -> Bool {
    guard isTouchModeEnabled else { return false }
    guard let toolPaletteView = toolPaletteView, toolPaletteView.isExpanded else { return false }
    let location = touch.location(in: view)
    if toolPaletteView.containsInteraction(at: location, in: view) {
      return false
    }
    return true
  }
}

// MARK: - Tool Palette Configuration

extension PDFDocumentViewController {

  fileprivate func configureToolPalette() {
    let paletteView = ToolPaletteView(accentColor: offBlack)
    paletteView.translatesAutoresizingMaskIntoConstraints = false
    paletteView.selectionChanged = { [weak self] selection in
      self?.handleToolSelection(selection)
    }
    paletteView.colorSelectionChanged = { [weak self] tool, hex in
      self?.handleColorChange(hex: hex, for: tool)
    }
    paletteView.thicknessChanged = { [weak self] tool, width in
      self?.handleThicknessChange(width: width, for: tool)
    }
    paletteView.expansionChanged = { [weak self] isExpanded in
      self?.setEditingToolbarVisible(isExpanded == false, animated: true)
    }
    view.addSubview(paletteView)

    paletteView.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    paletteView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    paletteView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -8
    ).isActive = true
    toolPaletteView = paletteView
  }

  fileprivate func configureEditingToolbar() {
    let toolbarView = EditingToolbarView(accentColor: offBlack)
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.undoTapped = { [weak self] in
      self?.handleUndo()
    }
    toolbarView.redoTapped = { [weak self] in
      self?.handleRedo()
    }
    toolbarView.clearTapped = { [weak self] in
      self?.handleClear()
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

  fileprivate func setEditingToolbarVisible(_ visible: Bool, animated: Bool) {
    guard let toolbarView = editingToolbarView else { return }
    guard visible != isEditingToolbarVisible else { return }
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

  fileprivate func configureTapToDismissPalette() {
    let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
    recognizer.cancelsTouchesInView = false
    recognizer.delegate = self
    view.addGestureRecognizer(recognizer)
    outsideTapRecognizer = recognizer
  }
}

// MARK: - Tool Actions

extension PDFDocumentViewController {

  fileprivate func handleToolSelection(_ selection: ToolPaletteView.ToolSelection) {
    currentToolSelection = selection
    applyCurrentTool()
  }

  fileprivate func handleColorChange(hex: String, for tool: ToolPaletteView.ToolSelection) {
    if tool == currentToolSelection {
      currentInkColorHex = hex
      applyCurrentTool()
    }
  }

  fileprivate func handleThicknessChange(width: CGFloat, for tool: ToolPaletteView.ToolSelection) {
    if tool == currentToolSelection {
      currentInkWidth = width
      applyCurrentTool()
    }
  }

  fileprivate func applyCurrentTool() {
    // Apply tool to active editor if available.
    guard activeEditor != nil else { return }

    do {
      try applyTool(
        selection: currentToolSelection,
        colorHex: currentInkColorHex,
        width: currentInkWidth
      )
    } catch {
      // Silently ignore tool application errors.
    }
  }

  fileprivate func handleUndo() {
    activeEditor?.performUndo()
  }

  fileprivate func handleRedo() {
    activeEditor?.performRedo()
  }

  fileprivate func handleClear() {
    do {
      try activeEditor?.performClear()
    } catch {
      // Ignore clear errors.
    }
  }
}

// MARK: - PDFPartSwitching Implementation

extension PDFDocumentViewController {

  // Handles a touch down event and switches to the appropriate block part.
  // touchPoint: The touch location in content coordinates (already zoom-adjusted).
  // Returns the block index touched, or nil if touch is outside all blocks.
  func handleTouchDown(at touchPoint: CGPoint) async throws -> Int? {
    // Get the document view as a PDFBlockLocator.
    guard let locator = documentView as? PDFBlockLocator else {
      return nil
    }

    // Find which block the touch is in.
    guard let blockIndex = locator.blockIndex(for: touchPoint.y) else {
      return nil
    }

    // If touching a different block, switch parts.
    if blockIndex != activeBlockIndex {
      try await switchToBlock(at: blockIndex)
    }

    return blockIndex
  }

  // Switches the editor to the MyScript part for the specified block.
  // blockIndex: Zero-based index of the block to switch to.
  // Throws PDFInputError if switch fails.
  func switchToBlock(at blockIndex: Int) async throws {
    // Validate block index.
    guard blockIndex >= 0 && blockIndex < noteDocument.blocks.count else {
      let error = PDFInputError.partSwitchFailed(
        partID: "invalid-index-\(blockIndex)",
        underlyingError: "Block index out of bounds"
      )
      partSwitchingDelegate?.partSwitchFailed(with: error)
      throw error
    }

    let block = noteDocument.blocks[blockIndex]
    let partID = block.myScriptPartID

    // Notify delegate of upcoming switch.
    partSwitchingDelegate?.willSwitchToBlock(at: blockIndex, partID: partID)

    // Get the part from the document handle.
    guard let handle = documentHandle else {
      let error = PDFInputError.partSwitchFailed(
        partID: partID,
        underlyingError: "Document handle not available"
      )
      partSwitchingDelegate?.partSwitchFailed(with: error)
      throw error
    }

    do {
      let part = try await handle.part(for: partID)

      // Switch to the part on the main actor.
      try await MainActor.run {
        try activeEditor?.setEditorPart(part as? IINKContentPart)
      }

      // Update active block index.
      activeBlockIndex = blockIndex
      currentPartID = partID

      // Notify delegate of successful switch.
      partSwitchingDelegate?.didSwitchToBlock(at: blockIndex)
    } catch {
      let switchError = PDFInputError.partSwitchFailed(
        partID: partID,
        underlyingError: error.localizedDescription
      )
      partSwitchingDelegate?.partSwitchFailed(with: switchError)
      throw switchError
    }
  }
}

// MARK: - PDFToolApplication Implementation

extension PDFDocumentViewController {

  // Applies the specified tool with color and width to the editor.
  // selection: The tool to apply (pen, highlighter, eraser).
  // colorHex: The color in hex format (e.g., "#FF0000").
  // width: The stroke width.
  // Throws PDFInputError if editor is not available.
  func applyTool(
    selection: ToolPaletteView.ToolSelection,
    colorHex: String,
    width: CGFloat
  ) throws {
    guard let editor = activeEditor else {
      throw PDFInputError.editorNotAvailable
    }

    // Map selection to tool.
    let tool: IINKPointerTool
    switch selection {
    case .pen:
      tool = .toolPen
    case .highlighter:
      tool = .toolHighlighter
    case .eraser:
      tool = .eraser
    }

    // Set tool for pen pointer type.
    try editor.editorToolController.setToolForPointerType(tool: tool, pointerType: .pen)

    // Apply ink style for pen and highlighter (not eraser).
    if selection != .eraser {
      try applyInkStyle(colorHex: colorHex, width: width, tool: tool)
    }
  }

  // Applies ink style to a specific tool.
  // colorHex: The color in hex format.
  // width: The stroke width.
  // tool: The tool to apply style to.
  // Throws PDFInputError if editor is not available.
  func applyInkStyle(colorHex: String, width: CGFloat, tool: IINKPointerTool) throws {
    guard let editor = activeEditor else {
      throw PDFInputError.editorNotAvailable
    }

    let style = "color:\(colorHex);-myscript-pen-width:\(String(format: "%.3f", width))"
    try editor.editorToolController.setStyleForTool(style: style, tool: tool)
  }

  // Applies the tool for the specified input mode.
  // tool: The tool to apply.
  // inputMode: The input mode (forcePen, forceTouch, auto).
  // Throws PDFInputError if editor is not available.
  func applyToolForInputMode(tool: IINKPointerTool, inputMode: InputMode) throws {
    guard let editor = activeEditor else {
      throw PDFInputError.editorNotAvailable
    }

    // Set tool for pen pointer type.
    try editor.editorToolController.setToolForPointerType(tool: tool, pointerType: .pen)

    // Set touch pointer type based on input mode.
    let touchTool: IINKPointerTool
    switch inputMode {
    case .forcePen:
      // In pen mode, touch follows the same tool as pen.
      touchTool = tool
    case .forceTouch:
      // In touch mode, touch is set to hand (pan) tool.
      touchTool = .hand
    case .auto:
      // In auto mode, touch is set to hand (pan) tool.
      touchTool = .hand
    }
    try editor.editorToolController.setToolForPointerType(tool: touchTool, pointerType: .touch)
  }
}

// MARK: - PDFInkInputWiring Implementation

extension PDFDocumentViewController {

  // Sets up the complete ink input pipeline.
  // Creates InputViewModel and InputViewController.
  // Adds InputViewController as child view controller.
  // Positions input view over PDF background.
  // Wires part switching gesture.
  func setupInkInput() async throws {
    // Validate engine is available.
    guard let engine = EngineProvider.sharedInstance.engine else {
      throw PDFDocumentError.engineNotAvailable
    }

    // Validate document view is configured.
    guard let docView = documentView as? PDFDocumentView else {
      throw PDFInputError.inkOverlayNotConfigured
    }

    // Remove previous input controller if exists.
    teardownInkInput()

    // Create InputViewModel with engine and self as EditorDelegate.
    let viewModel = InputViewModel(
      engine: engine,
      inputMode: .forcePen,
      editorDelegate: self,
      smartGuideDelegate: nil,
      smartGuideDisabled: true
    )
    inputViewModel = viewModel

    // Create InputViewController.
    let inputVC = InputViewController(viewModel: viewModel)
    inkInputViewController = inputVC

    // Add as child view controller on main thread.
    await MainActor.run {
      addChild(inputVC)
      docView.addInkOverlay(inputVC.view)
      inputVC.didMove(toParent: self)
    }

    // Wire part switching gesture.
    wirePartSwitchingGesture()
  }

  // Wires the gesture recognizer for stroke-based part switching.
  // Uses UILongPressGestureRecognizer with minimumPressDuration=0.
  func wirePartSwitchingGesture() {
    guard let inputView = inkInputViewController?.view else { return }

    // Remove existing gesture if present.
    if let existingGesture = partSwitchGesture {
      inputView.removeGestureRecognizer(existingGesture)
    }

    // Create gesture recognizer that fires at touch began.
    let gesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(handlePartSwitchGesture(_:))
    )
    gesture.minimumPressDuration = 0
    gesture.cancelsTouchesInView = false
    gesture.delegate = self
    inputView.addGestureRecognizer(gesture)
    partSwitchGesture = gesture
  }

  // Tears down the ink input pipeline.
  // Removes InputViewController and clears state.
  func teardownInkInput() {
    // Remove gesture recognizer.
    if let gesture = partSwitchGesture, let inputView = inkInputViewController?.view {
      inputView.removeGestureRecognizer(gesture)
    }
    partSwitchGesture = nil

    // Remove input view controller.
    inkInputViewController?.willMove(toParent: nil)
    inkInputViewController?.view.removeFromSuperview()
    inkInputViewController?.removeFromParent()
    inkInputViewController = nil
    inputViewModel = nil

    // Reset state.
    activeBlockIndex = -1
    currentPartID = nil
    activeEditor = nil

    // Cancel pending auto-save.
    autoSaveWorkItem?.cancel()
    autoSaveWorkItem = nil
  }

  // Gesture handler for part switching.
  @objc private func handlePartSwitchGesture(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }

    // Get touch point in document view coordinates.
    guard let docView = documentView as? PDFDocumentView else { return }
    let touchPoint = gesture.location(in: docView)

    // Convert to content coordinates.
    let contentPoint = docView.convertToContentCoordinates(touchPoint)

    // Switch part asynchronously.
    Task { @MainActor in
      do {
        _ = try await handleTouchDown(at: contentPoint)
      } catch {
        // Log error but don't block stroke.
        print("Part switch error: \(error.localizedDescription)")
      }
    }
  }
}

// MARK: - PDFEditorLifecycle Implementation

extension PDFDocumentViewController {

  // Loads the first block's MyScript part when the editor is ready.
  func loadInitialPart() async throws {
    // Check for empty document.
    guard !noteDocument.blocks.isEmpty else {
      return
    }

    // Load first block's part.
    try await switchToBlock(at: 0)
  }

  // Schedules an auto-save after content changes.
  // Uses debouncing to avoid excessive saves.
  func scheduleAutoSave() {
    // Cancel existing work item.
    autoSaveWorkItem?.cancel()

    // Create new work item.
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      Task {
        try? await self.documentHandle?.savePackage()
      }
    }
    autoSaveWorkItem = workItem

    // Schedule with delay.
    DispatchQueue.main.asyncAfter(deadline: .now() + autoSaveDelay, execute: workItem)
  }
}

// MARK: - EditorDelegate Implementation

extension PDFDocumentViewController {

  // Called when the IINKEditor is created.
  func didCreateEditor(editor: IINKEditor) {
    // Store editor reference.
    activeEditor = editor

    // Reset configuration.
    editor.configuration.reset()

    // Load initial part.
    Task { @MainActor in
      do {
        try await loadInitialPart()
      } catch {
        print("Failed to load initial part: \(error.localizedDescription)")
      }

      // Apply current tool state.
      applyCurrentTool()
    }
  }

  // Called when the active part changes.
  func partChanged(editor: IINKEditor) {
    // No action needed. Part switching is controlled by handleTouchDown.
  }

  // Called when content changes.
  func contentChanged(editor: IINKEditor, blockIds: [String]) {
    // Schedule auto-save.
    scheduleAutoSave()
  }

  // Called when an error occurs.
  func onError(editor: IINKEditor, blockId: String, message: String) {
    print("Editor error in block \(blockId): \(message)")
  }
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentViewController

 SCENARIO: Initialize with valid documents
 GIVEN: A valid NoteDocument with 3 pdfPage blocks
  AND: A valid PDFDocument with 3 pages
 WHEN: PDFDocumentViewController is initialized
 THEN: noteDocument matches the provided document
  AND: pdfDocument matches the provided PDF
  AND: No error is thrown

 SCENARIO: Initialize with empty NoteDocument
 GIVEN: A NoteDocument with empty blocks array
 WHEN: PDFDocumentViewController is initialized
 THEN: Initialization fails with PDFDocumentError.emptyDocument

 SCENARIO: Initialize with mismatched page indices
 GIVEN: A NoteDocument with pdfPage block referencing pageIndex 5
  AND: A PDFDocument with only 3 pages
 WHEN: PDFDocumentViewController validates blocks
 THEN: Throws PDFDocumentError.pageIndexOutOfBounds
*/
