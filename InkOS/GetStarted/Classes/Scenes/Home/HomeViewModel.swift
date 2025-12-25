// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation

/// This class is the ViewModel of the HomeViewController. It handles all its business logic.

@MainActor
class HomeViewModel {

  // MARK: Published Properties

  @Published var model: HomeModel?
  @Published var alert: UIAlertController?

  // MARK: Properties

  private let defaultPartType: String = "Drawing"
  weak var editor: IINKEditor?
  private var documentHandle: DocumentHandle?
  private var autoSaveTask: Task<Void, Never>?
  private var fullSaveTask: Task<Void, Never>?
  private var hasPendingFullSave = false
  private var isLoadingPart = false
  private var hasPresentedSaveError = false
  private let autoSaveDelayNanoseconds: UInt64 = 2_000_000_000
  private let fullSaveDelayNanoseconds: UInt64 = 20_000_000_000
  // Tracks the selected ink color so it can be applied when the editor is ready.
  private var selectedInkColorHex = "#000000"
  // Tracks the selected tool so it can be re-applied when the editor is available.
  private var selectedTool: ToolPaletteView.ToolSelection = .pen
  // Tracks the active input mode so touch tools can follow the toggle state.
  private var inputMode: InputMode = .forcePen

  func setupModel(engineProvider: EngineProvider, documentHandle: DocumentHandle) {
    let model = HomeModel()
    // We want the Pen mode for this GetStarted sample code. It lets the user use either its mouse or fingers to draw.
    // If you have got an iPad Pro with an Apple Pencil, please set this value to InputModeAuto for a better experience.
    let editorViewModel: EditorViewModel = EditorViewModel(
      engine: engineProvider.engine, inputMode: .forcePen, editorDelegate: self,
      smartGuideDelegate: nil)
    model.editorViewController = EditorViewController(viewModel: editorViewModel)
    model.title = documentHandle.initialManifest.displayName
    self.documentHandle = documentHandle
    self.model = model
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
    self.model?.editorViewController?.view.frame = bounds
  }

  // MARK: Editor Business Logic

  private func loadNotebookPartIfReady() {
    guard isLoadingPart == false, documentHandle != nil, editor != nil else {
      return
    }
    isLoadingPart = true
    Task { [weak self] in
      await self?.loadNotebookPart()
    }
  }

  private func loadNotebookPart() async {
    guard let documentHandle = documentHandle, let editor = editor else {
      isLoadingPart = false
      return
    }
    do {
      let part = try await documentHandle.ensureInitialPart(type: defaultPartType)
      try editor.set(part: part)
    } catch {
      createNonFatalAlert(title: "Error", message: error.localizedDescription)
      appLog("❌ HomeViewModel.loadNotebookPart failed error=\(error)")
    }
    isLoadingPart = false
  }

  // MARK: Actions

  func clear() {
    do {
      try self.editor?.clear()
    } catch {
      createAlert(title: "Error", message: "An error occurred while clearing the page")
      print("Error while clearing : " + error.localizedDescription)
    }
  }

  func undo() {
    self.editor?.undo()
  }

  func redo() {
    self.editor?.redo()
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
    model?.editorViewController?.selectPenTool()
  }

  // Switches the Notebook to eraser mode.
  func selectEraserTool() {
    model?.editorViewController?.selectEraserTool()
  }

  // Switches the Notebook to highlighter mode.
  func selectHighlighterTool() {
    model?.editorViewController?.selectHighlighterTool()
  }

  func updateInputMode(newInputMode: InputMode) {
    inputMode = newInputMode
    self.model?.editorViewController?.updateInputMode(newInputMode: newInputMode)
    applyToolSelectionIfPossible()
  }

  // Switches the active tool to match the palette selection.
  func updateTool(selection: ToolPaletteView.ToolSelection) {
    selectedTool = selection
    guard let editor = editor else {
      return
    }
    applyTool(selection: selection, editor: editor)
  }

  // Updates the pen style to match the selected color.
  func updateInkColor(hex: String) {
    selectedInkColorHex = hex
    guard let editor = editor else {
      return
    }
    applyInkColor(hex: hex, editor: editor)
  }

  // Applies the selected ink color to the supported tools.
  private func applyInkColor(hex: String, editor: IINKEditor) {
    do {
      try editor.toolController.set(style: "color:\(hex)", forTool: .toolPen)
      try editor.toolController.set(style: "color:\(hex)", forTool: .toolHighlighter)
    } catch {
      appLog("❌ HomeViewModel.applyInkColor failed color=\(hex) error=\(error)")
    }
  }

  // Sets the active tool on the editor for both pen and touch inputs.
  private func applyTool(selection: ToolPaletteView.ToolSelection, editor: IINKEditor) {
    let tool = tool(for: selection)
    do {
      try editor.toolController.set(tool: tool, forType: .pen)
      try applyTouchTool(tool: tool, editor: editor)
    } catch {
      appLog("❌ HomeViewModel.applyTool failed tool=\(tool) error=\(error)")
    }
  }

  // Releases the editor binding to avoid keeping the part locked.
  func releaseEditor() {
    autoSaveTask?.cancel()
    fullSaveTask?.cancel()
    do {
      try self.editor?.set(part: nil)
    } catch {
      appLog("❌ HomeViewModel.releaseEditor failed error=\(error.localizedDescription)")
    }
    let handle = documentHandle
    documentHandle = nil
    Task { [weak self] in
      guard let handle = handle else {
        return
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
      appLog("✅ HomeViewModel.performAutoSave saved temp")
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
      appLog("✅ HomeViewModel.performFullSave saved full reason=\(reason)")
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

}

extension HomeViewModel: EditorDelegate {

  func didCreateEditor(editor: IINKEditor) {
    self.editor = editor
    applyTool(selection: selectedTool, editor: editor)
    applyInkColor(hex: selectedInkColorHex, editor: editor)
    self.loadNotebookPartIfReady()
  }

  func partChanged(editor: IINKEditor) {

  }

  func contentChanged(editor: IINKEditor, blockIds: [String]) {
    hasPendingFullSave = true
    scheduleAutoSave()
    scheduleFullSave()
  }

  func onError(editor: IINKEditor, blockId: String, message: String) {
    createAlert(title: "Error", message: message)
  }

  // Applies the selected tool to the editor once the editor is available.
  private func applyToolSelectionIfPossible() {
    guard let editor = editor else {
      return
    }
    do {
      let tool = tool(for: selectedTool)
      try editor.toolController.set(tool: tool, forType: .pen)
      try applyTouchTool(tool: tool, editor: editor)
    } catch {
      appLog(
        "❌ HomeViewModel.applyToolSelectionIfPossible failed selection=\(selectedTool) error=\(error)"
      )
    }
  }

  // Applies the correct touch tool based on the current input mode.
  private func applyTouchTool(tool: IINKPointerTool, editor: IINKEditor) throws {
    if inputMode == .forcePen {
      try editor.toolController.set(tool: tool, forType: .touch)
    } else {
      try editor.toolController.set(tool: .hand, forType: .touch)
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
