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
  // Tracks the last tool requested by the toolbar.
  private var activeToolSelection: ToolPaletteView.ToolSelection = .pen

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

  func updateInputMode(newInputMode: InputMode) {
    self.model?.editorViewController?.updateInputMode(newInputMode: newInputMode)
  }

  // Persists the selected tool so it can be applied once the editor is ready.
  func selectTool(_ selection: ToolPaletteView.ToolSelection) {
    activeToolSelection = selection
    applyToolSelectionIfPossible()
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
    applyToolSelectionIfPossible()
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
    let toolForSelection: IINKPointerTool
    switch activeToolSelection {
    case .pen:
      toolForSelection = .toolPen
    case .eraser:
      toolForSelection = .eraser
    case .highlighter:
      toolForSelection = .toolHighlighter
    }
    do {
      try editor.toolController.set(tool: toolForSelection, forType: .pen)
      try editor.toolController.set(tool: toolForSelection, forType: .touch)
    } catch {
      appLog("❌ HomeViewModel.applyToolSelectionIfPossible failed selection=\(activeToolSelection) error=\(error)")
    }
  }
}
