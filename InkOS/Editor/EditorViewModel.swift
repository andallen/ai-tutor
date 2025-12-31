// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

// File length exceeds default limit due to comprehensive editor state management,
// viewport restoration logic, save coordination, and tool configuration.
// This centralization is intentional to maintain clear ownership of editor lifecycle.
// swiftlint:disable file_length

/// This class is the ViewModel of the EditorViewController. It handles all its business logic.
@MainActor
class EditorViewModel {  // swiftlint:disable:this type_body_length

  // MARK: Published Properties

  // Uses protocol type to allow dependency injection for testing.
  @Published var editorViewController: (any InputViewControllerProtocol)?
  @Published var title: String? = ""
  @Published var alert: UIAlertController?

  // MARK: Properties

  private let defaultPartType: String = "Raw Content"
  // Provides the default Raw Content configuration.
  private let configurationProvider = DefaultRawContentConfigurationProvider()
  // Applies configuration to the engine.
  private let configurationApplier = RawContentConfigurationApplier()
  // Uses concrete IINKEditor for production, protocol for test injection.
  weak var editor: IINKEditor?
  // Uses protocol type to allow dependency injection for testing.
  private var documentHandle: (any DocumentHandleProtocol)?
  // Holds a reference to the protocol-based editor for test injection.
  private var testEditor: (any EditorProtocol)?
  private var autoSaveTask: Task<Void, Never>?
  private var fullSaveTask: Task<Void, Never>?
  private var hasPendingFullSave = false
  private var isLoadingPart = false
  private var hasPresentedSaveError = false
  private let autoSaveDelayNanoseconds: UInt64 = 2_000_000_000
  private let fullSaveDelayNanoseconds: UInt64 = 20_000_000_000
  // Manages periodic JIIX export for search indexing and LLM consumption.
  private var jiixPersistenceService: JIIXPersistenceService?
  // Tracks the selected pen color so it can be applied when the editor is ready.
  private var selectedPenColorHex = "#000000"
  // Tracks the selected highlighter color so it can be applied when the editor is ready.
  private var selectedHighlighterColorHex = "#FFF176"
  // Tracks the selected pen width so it can be applied when the editor is ready.
  private var selectedPenWidth: CGFloat = 0.65
  // Tracks the selected highlighter width so it can be applied when the editor is ready.
  private var selectedHighlighterWidth: CGFloat = 5.0
  // Tracks the selected tool so it can be re-applied when the editor is available.
  private var selectedTool: ToolPaletteView.ToolSelection = .pen
  // Tracks the active input mode so touch tools can follow the toggle state.
  private var inputMode: InputMode = .forcePen

  func setupModel(engineProvider: EngineProvider, documentHandle: DocumentHandle) {
    // Set documentHandle BEFORE creating the editor so it's available in didCreateEditor.
    self.documentHandle = documentHandle
    self.title = documentHandle.initialManifest.displayName

    // We want the Pen mode for this GetStarted sample code. It lets the user use either its mouse or fingers to draw.
    // If you have got an iPad Pro with an Apple Pencil, please set this value to InputModeAuto for a better experience.
    let inputViewModel: InputViewModel = InputViewModel(
      engine: engineProvider.engine, inputMode: .forcePen, editorDelegate: self,
      smartGuideDelegate: nil, smartGuideDisabled: true)
    self.editorViewController = InputViewController(viewModel: inputViewModel)
    self.loadNotebookPartIfReady()
  }

  // MARK: UI Logic

  private func createAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    self.alert = alert
  }

  private func createNonFatalAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    self.alert = alert
  }

  func setEditorViewSize(bounds: CGRect) {
    self.editorViewController?.view.frame = bounds
  }

  // MARK: Editor Business Logic

  private func loadNotebookPartIfReady() {
    guard isLoadingPart == false, documentHandle != nil, activeEditor != nil else {
      return
    }
    isLoadingPart = true
    Task { [weak self] in
      await self?.loadNotebookPart()
    }
  }

  private func loadNotebookPart() async {
    guard let documentHandle = documentHandle, let editor = activeEditor else {
      isLoadingPart = false
      return
    }
    do {
      let part = try await documentHandle.ensureInitialPart(type: defaultPartType)
      // Cast from protocol type to SDK type for editor compatibility.
      try editor.setEditorPart(part as? IINKContentPart)

      // Restore viewport after part is loaded.
      let manifest = await documentHandle.manifest
      if let viewportState = manifest.viewportState {
        restoreViewportState(viewportState)
      } else {
        // No saved state exists, so explicitly initialize viewport to document top.
        // This ensures consistent behavior instead of relying on undefined MyScript defaults.
        initializeDefaultViewport()
      }

    } catch {
      createNonFatalAlert(title: "Error", message: error.localizedDescription)
    }
    isLoadingPart = false
  }

  // Restores the viewport to a previously saved state.
  // Must be called on MainActor after the part is loaded.
  // Clamps the offset to valid document bounds to handle content size changes.
  @MainActor
  private func restoreViewportState(_ state: ViewportState) {
    guard let editor = activeEditor else {
      return
    }

    let renderer = editor.editorRenderer

    // Validate state before applying.
    guard state.isValid() else {
      initializeDefaultViewport()
      return
    }

    // Set the zoom scale first.
    renderer.viewScale = state.scale

    // Set the offset, clamping to valid document bounds.
    var requestedOffset = CGPoint(x: CGFloat(state.offsetX), y: CGFloat(state.offsetY))
    editor.clampEditorViewOffset(&requestedOffset)
    renderer.viewOffset = requestedOffset

    // Force a display refresh to show the new viewport.
    NotificationCenter.default.post(
      name: DisplayViewController.refreshNotification,
      object: nil
    )
  }

  // Initializes the viewport to the default position at the document origin.
  // Must be called on MainActor after the part is loaded.
  // Used when no saved viewport state exists for the notebook.
  @MainActor
  private func initializeDefaultViewport() {
    guard let editor = activeEditor else {
      return
    }

    let renderer = editor.editorRenderer

    // Set scale to 1.0 for 100 percent zoom.
    renderer.viewScale = 1.0

    // Set offset to origin, then clamp to ensure it is within valid bounds.
    // This accounts for any document constraints while still starting at the top.
    var initialOffset = CGPoint.zero
    editor.clampEditorViewOffset(&initialOffset)
    renderer.viewOffset = initialOffset

    // Force a display refresh to show the initialized viewport.
    NotificationCenter.default.post(
      name: DisplayViewController.refreshNotification,
      object: nil
    )
  }

  // MARK: Actions

  // Returns the active editor protocol, preferring testEditor if set.
  private var activeEditor: (any EditorProtocol)? {
    return testEditor ?? editor
  }

  func clear() {
    do {
      try activeEditor?.performClear()
    } catch {
      createAlert(title: "Error", message: "An error occurred while clearing the page")
    }
  }

  func undo() {
    activeEditor?.performUndo()
  }

  func redo() {
    activeEditor?.performRedo()
  }

  // Applies the requested tool selection to the editor.
  func selectTool(_ selection: ToolPaletteView.ToolSelection) {
    switch selection {
    case .pen:
      selectPenTool()
    case .eraser:
      selectEraserTool()
    case .highlighter:
      selectHighlighterTool()
    }
  }

  // Switches the Notebook to pen mode.
  func selectPenTool() {
    editorViewController?.selectPenTool()
  }

  // Switches the Notebook to eraser mode.
  func selectEraserTool() {
    editorViewController?.selectEraserTool()
  }

  // Switches the Notebook to highlighter mode.
  func selectHighlighterTool() {
    editorViewController?.selectHighlighterTool()
  }

  func updateInputMode(newInputMode: InputMode) {
    inputMode = newInputMode
    self.editorViewController?.updateInputMode(newInputMode: newInputMode)
    applyToolSelectionIfPossible()
  }

  // Switches the active tool to match the palette selection.
  func updateTool(selection: ToolPaletteView.ToolSelection) {
    selectedTool = selection
    guard let editor = activeEditor else {
      return
    }
    applyTool(selection: selection, editor: editor)
  }

  // Updates the selected color for the requested tool.
  func updateInkColor(hex: String, for tool: ToolPaletteView.ToolSelection) {
    switch tool {
    case .pen:
      selectedPenColorHex = hex
      applyInkStyle(colorHex: hex, width: selectedPenWidth, tool: .toolPen)
    case .highlighter:
      selectedHighlighterColorHex = hex
      applyInkStyle(colorHex: hex, width: selectedHighlighterWidth, tool: .toolHighlighter)
    case .eraser:
      break
    }
  }

  // Updates the selected thickness for the requested tool.
  func updateInkWidth(width: CGFloat, for tool: ToolPaletteView.ToolSelection) {
    switch tool {
    case .pen:
      selectedPenWidth = width
      applyInkStyle(colorHex: selectedPenColorHex, width: width, tool: .toolPen)
    case .highlighter:
      selectedHighlighterWidth = width
      applyInkStyle(colorHex: selectedHighlighterColorHex, width: width, tool: .toolHighlighter)
    case .eraser:
      break
    }
  }

  // Applies the selected ink style to the requested tool.
  private func applyInkStyle(colorHex: String, width: CGFloat, tool: IINKPointerTool) {
    guard let editor = activeEditor else {
      return
    }
    let styleString = String(format: "color:%@;-myscript-pen-width:%.3f", colorHex, width)
    do {
      try editor.editorToolController.setStyleForTool(style: styleString, tool: tool)
    } catch {
      // Silently ignore style setting errors.
    }
  }

  // Applies the eraser radius across supported part types.
  private func applyEraserRadius(width: CGFloat) {
    guard let editor = activeEditor else {
      return
    }
    let configuration = editor.editorConfiguration
    do {
      // Shows the eraser halo and keeps the radius consistent across strokes.
      try configuration.setConfigBoolean(true, forKey: "raw-content.eraser.show")
      try configuration.setConfigBoolean(false, forKey: "raw-content.eraser.dynamic-radius")
      try configuration.setConfigBoolean(true, forKey: "raw-content.eraser.erase-precisely")
      try configuration.setConfigNumber(width, forKey: "raw-content.eraser.radius")
      try configuration.setConfigBoolean(true, forKey: "text.eraser.show")
      try configuration.setConfigBoolean(false, forKey: "text.eraser.dynamic-radius")
      try configuration.setConfigBoolean(true, forKey: "text.eraser.erase-precisely")
      try configuration.setConfigNumber(width, forKey: "text.eraser.radius")
      try configuration.setConfigBoolean(true, forKey: "math.eraser.show")
      try configuration.setConfigBoolean(false, forKey: "math.eraser.dynamic-radius")
      try configuration.setConfigBoolean(true, forKey: "math.eraser.erase-precisely")
      try configuration.setConfigNumber(width, forKey: "math.eraser.radius")
      try configuration.setConfigBoolean(true, forKey: "diagram.eraser.show")
      try configuration.setConfigBoolean(false, forKey: "diagram.eraser.dynamic-radius")
      try configuration.setConfigBoolean(true, forKey: "diagram.eraser.erase-precisely")
      try configuration.setConfigNumber(width, forKey: "diagram.eraser.radius")
      try configuration.setConfigBoolean(true, forKey: "text-document.eraser.show")
      try configuration.setConfigBoolean(false, forKey: "text-document.eraser.dynamic-radius")
      try configuration.setConfigBoolean(true, forKey: "text-document.eraser.erase-precisely")
      try configuration.setConfigNumber(width, forKey: "text-document.eraser.radius")
    } catch {
      // Silently ignore eraser radius configuration errors.
    }
  }

  // Sets the active tool on the editor for pen input and updates touch to follow the current mode.
  private func applyTool(selection: ToolPaletteView.ToolSelection, editor: any EditorProtocol) {
    let tool = tool(for: selection)
    do {
      try editor.editorToolController.setToolForPointerType(tool: tool, pointerType: .pen)
      try applyTouchTool(tool: tool, editor: editor)
    } catch {
      // Silently ignore tool setting errors.
    }
  }

  // Captures the current viewport configuration from the editor.
  // Must be called on MainActor since it accesses IINKRenderer.
  // Returns nil if editor is not available.
  @MainActor
  private func captureViewportState() -> ViewportState? {
    guard let editor = activeEditor else {
      return nil
    }

    let renderer = editor.editorRenderer
    let offset = renderer.viewOffset
    let scale = renderer.viewScale

    let state = ViewportState(
      offsetX: Float(offset.x),
      offsetY: Float(offset.y),
      scale: scale
    )

    // Only return valid states to prevent persisting corrupted data.
    return state.isValid() ? state : nil
  }

  // Releases the editor binding to avoid keeping the part locked.
  // Returns a Task that completes when all cleanup is done.
  @discardableResult
  func releaseEditor(previewImage: UIImage? = nil) -> Task<Void, Never> {
    // Capture viewport state before releasing editor.
    let viewportState = captureViewportState()

    autoSaveTask?.cancel()
    fullSaveTask?.cancel()

    // Cancel any pending JIIX debounce operations.
    let jiixService = jiixPersistenceService
    jiixPersistenceService = nil

    do {
      try activeEditor?.setEditorPart(nil)
    } catch {
      // Silently ignore errors when releasing the part binding.
    }
    let handle = documentHandle
    let previewData = previewImage?.pngData()
    documentHandle = nil
    return Task { [weak self] in
      // Cancel JIIX persistence debounce timer.
      await jiixService?.cancelPendingSave()
      guard let handle = handle else {
        return
      }

      // Save viewport state if captured.
      if let state = viewportState {
        await handle.updateViewportState(state)
      }

      if let previewData {
        do {
          try await handle.savePreviewImageData(previewData)
          await MainActor.run {
            NotificationCenter.default.post(
              name: .notebookPreviewUpdated,
              object: handle.notebookID
            )
          }
        } catch {
          // Silently ignore preview save errors.
        }
      }
      do {
        try await handle.savePackage()
      } catch {
        self?.presentSaveError(message: error.localizedDescription)
      }
      await handle.close(saveBeforeClose: false)
    }
  }

  func handleAppBackground() {
    Task { [weak self] in
      // Save JIIX content immediately when app enters background.
      await self?.jiixPersistenceService?.handleAppBackground()
      await self?.performFullSave(reason: "background")
    }
  }

  func presentMissingNotebookError() {
    createNonFatalAlert(title: "Error", message: "Notebook details are missing.")
  }

  private func scheduleAutoSave() {
    autoSaveTask?.cancel()
    autoSaveTask = Task { [weak self] in
      guard let self = self else {
        return
      }
      try? await Task.sleep(nanoseconds: self.autoSaveDelayNanoseconds)
      await self.performAutoSave()
    }
  }

  private func scheduleFullSave() {
    fullSaveTask?.cancel()
    fullSaveTask = Task { [weak self] in
      guard let self = self else {
        return
      }
      try? await Task.sleep(nanoseconds: self.fullSaveDelayNanoseconds)
      await self.performFullSave(reason: "idle")
    }
  }

  private func performAutoSave() async {
    guard let documentHandle = documentHandle else {
      return
    }
    do {
      try await documentHandle.savePackageToTemp()
    } catch {
      presentSaveError(message: error.localizedDescription)
    }
  }

  private func performFullSave(reason: String) async {
    guard let documentHandle = documentHandle else {
      return
    }
    guard hasPendingFullSave || reason == "background" else {
      return
    }
    do {
      try await documentHandle.savePackage()
      hasPendingFullSave = false
      hasPresentedSaveError = false
    } catch {
      presentSaveError(message: error.localizedDescription)
    }
  }

  private func presentSaveError(message: String) {
    guard hasPresentedSaveError == false else {
      return
    }
    hasPresentedSaveError = true
    createNonFatalAlert(title: "Save Failed", message: message)
  }

  // MARK: Test Injection

  // Internal method for test injection of mock dependencies.
  // Allows tests to inject mock editor, view controller, and document handle.
  func setTestDependencies(
    editor: (any EditorProtocol)?,
    viewController: (any InputViewControllerProtocol)?,
    documentHandle: (any DocumentHandleProtocol)?
  ) {
    self.testEditor = editor
    self.editorViewController = viewController
    self.documentHandle = documentHandle
    if let manifest = documentHandle?.initialManifest {
      self.title = manifest.displayName
    }
  }

}

extension EditorViewModel: EditorDelegate {

  func didCreateEditor(editor: IINKEditor) {
    self.editor = editor

    // Reset configuration to defaults before applying Raw Content settings.
    // This is required by MyScript SDK to clear any cached configuration values.
    editor.configuration.reset()

    // Apply Raw Content configuration before loading the part.
    do {
      let configuration = configurationProvider.provideConfiguration()
      try configurationApplier.applyConfiguration(configuration, to: editor.configuration)
    } catch {
      createNonFatalAlert(
        title: "Configuration Warning",
        message: "Failed to apply some Raw Content settings: \(error.localizedDescription)"
      )
    }

    // Initialize JIIX persistence service for search indexing and LLM consumption.
    // Requires both editor and documentHandle to be available.
    if let handle = documentHandle {
      jiixPersistenceService = JIIXPersistenceService(
        editor: editor,
        documentHandle: handle,
        debounceDelaySeconds: JIIXPersistenceConfiguration.default.debounceDelaySeconds
      )
    }

    applyTool(selection: selectedTool, editor: editor)
    applyInkStyle(colorHex: selectedPenColorHex, width: selectedPenWidth, tool: .toolPen)
    applyInkStyle(
      colorHex: selectedHighlighterColorHex,
      width: selectedHighlighterWidth,
      tool: .toolHighlighter
    )
    self.loadNotebookPartIfReady()
  }

  func partChanged(editor: IINKEditor) {

  }

  func contentChanged(editor: IINKEditor, blockIds: [String]) {
    hasPendingFullSave = true
    scheduleAutoSave()
    scheduleFullSave()

    // Notify JIIX persistence service of content changes.
    // Service handles debouncing to avoid excessive exports.
    Task { [weak self] in
      await self?.jiixPersistenceService?.contentDidChange()
    }
  }

  func onError(editor: IINKEditor, blockId: String, message: String) {
    createAlert(title: "Error", message: message)
  }

  // Applies the selected tool to the editor once the editor is available.
  private func applyToolSelectionIfPossible() {
    guard let editor = activeEditor else {
      return
    }
    do {
      let tool = tool(for: selectedTool)
      try editor.editorToolController.setToolForPointerType(tool: tool, pointerType: .pen)
      try applyTouchTool(tool: tool, editor: editor)
    } catch {
      // Silently ignore tool setting errors.
    }
  }

  // Applies the correct touch tool based on the current input mode.
  private func applyTouchTool(tool: IINKPointerTool, editor: any EditorProtocol) throws {
    if inputMode == .forcePen {
      try editor.editorToolController.setToolForPointerType(tool: tool, pointerType: .touch)
    } else {
      try editor.editorToolController.setToolForPointerType(tool: .hand, pointerType: .touch)
    }
  }

  // Maps palette selection to the SDK tool enum.
  private func tool(for selection: ToolPaletteView.ToolSelection) -> IINKPointerTool {
    switch selection {
    case .pen:
      return .toolPen
    case .eraser:
      return .eraser
    case .highlighter:
      return .toolHighlighter
    }
  }
}
