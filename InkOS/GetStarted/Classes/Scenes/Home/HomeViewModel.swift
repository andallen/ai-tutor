// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

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
    guard let editor = editor else {
      return
    }
    let styleString = String(format: "color:%@;-myscript-pen-width:%.3f", colorHex, width)
    do {
      try editor.toolController.set(style: styleString, forTool: tool)
    } catch {
      appLog(
        "❌ HomeViewModel.applyInkStyle failed color=\(colorHex) width=\(width) tool=\(tool) error=\(error)"
      )
    }
  }

  // Applies the eraser radius across supported part types.
  private func applyEraserRadius(width: CGFloat) {
    guard let editor = editor else {
      return
    }
    let configuration = editor.configuration
    do {
      // Shows the eraser halo and keeps the radius consistent across strokes.
      try configuration.set(boolean: true, forKey: "raw-content.eraser.show")
      try configuration.set(boolean: false, forKey: "raw-content.eraser.dynamic-radius")
      try configuration.set(boolean: true, forKey: "raw-content.eraser.erase-precisely")
      try configuration.set(number: width, forKey: "raw-content.eraser.radius")
      try configuration.set(boolean: true, forKey: "text.eraser.show")
      try configuration.set(boolean: false, forKey: "text.eraser.dynamic-radius")
      try configuration.set(boolean: true, forKey: "text.eraser.erase-precisely")
      try configuration.set(number: width, forKey: "text.eraser.radius")
      try configuration.set(boolean: true, forKey: "math.eraser.show")
      try configuration.set(boolean: false, forKey: "math.eraser.dynamic-radius")
      try configuration.set(boolean: true, forKey: "math.eraser.erase-precisely")
      try configuration.set(number: width, forKey: "math.eraser.radius")
      try configuration.set(boolean: true, forKey: "diagram.eraser.show")
      try configuration.set(boolean: false, forKey: "diagram.eraser.dynamic-radius")
      try configuration.set(boolean: true, forKey: "diagram.eraser.erase-precisely")
      try configuration.set(number: width, forKey: "diagram.eraser.radius")
      try configuration.set(boolean: true, forKey: "text-document.eraser.show")
      try configuration.set(boolean: false, forKey: "text-document.eraser.dynamic-radius")
      try configuration.set(boolean: true, forKey: "text-document.eraser.erase-precisely")
      try configuration.set(number: width, forKey: "text-document.eraser.radius")
    } catch {
      appLog("❌ HomeViewModel.applyEraserRadius failed width=\(width) error=\(error)")
    }
  }

  // Sets the active tool on the editor for pen input and updates touch to follow the current mode.
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
