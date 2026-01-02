// PDFAnnotationCoordinator.swift
// Coordinates MyScript annotation across all visible PDF cells.
// Manages a shared IINKEditor that swaps parts as cells scroll.

import Foundation
import UIKit

// Coordinates MyScript annotation across visible PDF page cells.
// Manages a shared IINKEditor instance that swaps parts based on cell visibility.
// Must be MainActor since MyScript components are not thread-safe.
@MainActor
class PDFAnnotationCoordinator {

  // The shared MyScript editor instance.
  private var editor: (any EditorProtocol)?

  // The renderer for drawing ink strokes.
  private var renderer: (any RendererProtocol)?

  // Tool controller for pen/eraser selection.
  private var toolController: (any ToolControllerProtocol)?

  // Input view model managing gestures and editor lifecycle.
  private var inputViewModel: InputViewModel?

  // Display view model for rendering callbacks.
  private var displayViewModel: DisplayViewModel?

  // The currently active part identifier (which cell's annotation is loaded).
  private var currentActivePart: String?

  // The MyScript content package containing all annotation parts.
  private weak var package: (any ContentPackageProtocol)?

  // Weak references to currently visible cells.
  // Key: IndexPath, Value: PDFPageCell reference.
  private var visibleCells: [IndexPath: WeakCellRef] = [:]

  // The cell that currently has the active MyScript views attached.
  private weak var activeCellContainer: UIView?

  // Input and render views (created once, moved between cells).
  private var inputView: InputView?
  private var renderView: RenderView?

  // Reference to engine provider.
  private weak var engineProvider: EngineProvider?

  // Delegate for editor events.
  private weak var editorDelegate: (any EditorDelegate)?

  // Creates a new annotation coordinator.
  // engineProvider: Provides access to IINKEngine.
  // package: The MyScript package containing annotation parts.
  // editorDelegate: Receives editor event callbacks.
  init(
    engineProvider: EngineProvider,
    package: any ContentPackageProtocol,
    editorDelegate: (any EditorDelegate)?
  ) {
    self.engineProvider = engineProvider
    self.package = package
    self.editorDelegate = editorDelegate
    setupEditor()
  }

  // Sets up the MyScript editor and supporting components.
  private func setupEditor() {
    guard let engine = engineProvider?.engine else { return }

    // Create display view model and renderer.
    guard let (renderer, displayViewModel) = createRenderer(engine: engine) else { return }
    self.renderer = renderer
    self.displayViewModel = displayViewModel

    // Create tool controller and editor.
    guard let (editor, toolController) = createEditor(engine: engine, renderer: renderer) else { return }
    self.editor = editor
    self.toolController = toolController

    // Apply theme to editor.
    applyTheme(to: editor)

    // Set font metrics provider.
    editor.setEditorFontMetricsProvider(FontMetricsProvider())

    // Create and configure views.
    setupViews(editor: editor, renderer: renderer, displayViewModel: displayViewModel)

    // Initialize input view model.
    setupInputViewModel(engine: engine)
  }

  // Creates the renderer and display view model.
  private func createRenderer(engine: any EngineProtocol) -> (any RendererProtocol, DisplayViewModel)? {
    let displayViewModel = DisplayViewModel()
    guard
      let renderer = try? engine.createRenderer(
        dpiX: Helper.scaledDpi(),
        dpiY: Helper.scaledDpi(),
        target: displayViewModel
      )
    else {
      return nil
    }
    return (renderer, displayViewModel)
  }

  // Creates the editor and tool controller.
  private func createEditor(
    engine: any EngineProtocol,
    renderer: any RendererProtocol
  ) -> (any EditorProtocol, any ToolControllerProtocol)? {
    let toolController = engine.createToolController()
    guard
      let editor = try? engine.createEditor(
        renderer: renderer,
        toolController: toolController
      )
    else {
      return nil
    }
    return (editor, toolController)
  }

  // Applies the CSS theme to the editor.
  private func applyTheme(to editor: any EditorProtocol) {
    if let path = Bundle.main.path(forResource: "theme", ofType: "css"),
      let cssString = try? String(contentsOfFile: path, encoding: .utf8) {
      try? editor.setEditorTheme(cssString)
    }
  }

  // Creates and configures input and render views.
  private func setupViews(
    editor: any EditorProtocol,
    renderer: any RendererProtocol,
    displayViewModel: DisplayViewModel
  ) {
    // Create input view (captures touches).
    let inputView = InputView(frame: .zero)
    inputView.editor = editor as? IINKEditor
    inputView.inputMode = .forcePen
    inputView.backgroundColor = .clear
    inputView.translatesAutoresizingMaskIntoConstraints = false
    self.inputView = inputView

    // Create render view (draws ink).
    let renderView = RenderView(frame: .zero)
    renderView.renderer = renderer as? IINKRenderer
    renderView.backgroundColor = .clear
    renderView.translatesAutoresizingMaskIntoConstraints = false
    self.renderView = renderView

    // Configure display view model.
    displayViewModel.renderer = renderer as? IINKRenderer
    displayViewModel.imageLoader = ImageLoader()
  }

  // Initializes the input view model for gesture handling.
  private func setupInputViewModel(engine: any EngineProtocol) {
    // Note: We disable smart guide for PDF annotation.
    let inputViewModel = InputViewModel(
      engine: engine,
      inputMode: .forcePen,
      editorDelegate: editorDelegate,
      smartGuideDelegate: nil,
      smartGuideDisabled: true
    )
    inputViewModel.setupModel(panGesture: nil, pinchGesture: nil)
    self.inputViewModel = inputViewModel
  }

  // Called when cells become visible.
  // Tracks visible cells and activates the topmost cell's part.
  func cellDidBecomeVisible(
    _ cell: PDFPageCell,
    at indexPath: IndexPath,
    myScriptPartID: String
  ) {
    visibleCells[indexPath] = WeakCellRef(cell: cell)

    // Activate this cell if it's the topmost visible cell.
    if shouldActivateCell(at: indexPath) {
      activateCell(cell, myScriptPartID: myScriptPartID)
    }
  }

  // Called when cells are no longer visible.
  // Cleans up tracking and deactivates if necessary.
  func cellDidEndDisplay(_ cell: PDFPageCell, at indexPath: IndexPath) {
    visibleCells.removeValue(forKey: indexPath)

    // If this was the active cell, deactivate and find next.
    if activeCellContainer === cell.overlayContainer {
      deactivateCurrentCell()
      activateNextVisibleCell()
    }
  }

  // Determines if a cell should be activated.
  // Strategy: Activate the topmost visible cell.
  private func shouldActivateCell(at indexPath: IndexPath) -> Bool {
    // If no active cell, activate this one.
    guard activeCellContainer != nil else { return true }

    // Find the topmost visible index path.
    let sortedIndexPaths = visibleCells.keys.sorted()
    return sortedIndexPaths.first == indexPath
  }

  // Activates a cell's annotation layer.
  // Loads the MyScript part and attaches input/render views.
  private func activateCell(_ cell: PDFPageCell, myScriptPartID: String) {
    // Don't reactivate if already active.
    guard activeCellContainer !== cell.overlayContainer else { return }

    // Deactivate current cell first.
    deactivateCurrentCell()

    // Load the part into the editor.
    // Find the part with matching identifier.
    guard let package = package else { return }

    let partCount = package.getPartCount()
    var foundPart: IINKContentPart?

    for index in 0..<partCount {
      if let part = try? package.getPart(at: index) as? IINKContentPart,
        part.identifier == myScriptPartID {
        foundPart = part
        break
      }
    }

    guard let part = foundPart else { return }

    do {
      try editor?.setEditorPart(part)
      currentActivePart = myScriptPartID
    } catch {
      print("Failed to set editor part: \(error.localizedDescription)")
      return
    }

    // Attach render view to overlay container.
    if let renderView = renderView {
      cell.overlayContainer.addSubview(renderView)
      NSLayoutConstraint.activate([
        renderView.topAnchor.constraint(equalTo: cell.overlayContainer.topAnchor),
        renderView.leadingAnchor.constraint(equalTo: cell.overlayContainer.leadingAnchor),
        renderView.trailingAnchor.constraint(equalTo: cell.overlayContainer.trailingAnchor),
        renderView.bottomAnchor.constraint(equalTo: cell.overlayContainer.bottomAnchor)
      ])
    }

    // Attach input view on top of render view.
    if let inputView = inputView {
      cell.overlayContainer.addSubview(inputView)
      NSLayoutConstraint.activate([
        inputView.topAnchor.constraint(equalTo: cell.overlayContainer.topAnchor),
        inputView.leadingAnchor.constraint(equalTo: cell.overlayContainer.leadingAnchor),
        inputView.trailingAnchor.constraint(equalTo: cell.overlayContainer.trailingAnchor),
        inputView.bottomAnchor.constraint(equalTo: cell.overlayContainer.bottomAnchor)
      ])
    }

    // Update editor view size to match cell.
    try? editor?.setEditorViewSize(cell.overlayContainer.bounds.size)

    // Mark as active.
    activeCellContainer = cell.overlayContainer

    // Enable user interaction on overlay.
    cell.overlayContainer.isUserInteractionEnabled = true
  }

  // Deactivates the current cell's annotation layer.
  // Removes input/render views and clears editor part.
  private func deactivateCurrentCell() {
    guard let activeContainer = activeCellContainer else { return }

    // Remove views from container.
    inputView?.removeFromSuperview()
    renderView?.removeFromSuperview()

    // Clear editor part.
    try? editor?.setEditorPart(nil)
    currentActivePart = nil

    // Disable interaction.
    activeContainer.isUserInteractionEnabled = false

    // Clear reference.
    activeCellContainer = nil
  }

  // Activates the next visible cell after deactivation.
  private func activateNextVisibleCell() {
    // Find topmost visible cell.
    let sortedIndexPaths = visibleCells.keys.sorted()
    guard let firstIndexPath = sortedIndexPaths.first,
      let cellRef = visibleCells[firstIndexPath],
      let cell = cellRef.cell,
      let partID = cell.myScriptPartID
    else {
      return
    }

    // Activate the topmost visible cell.
    activateCell(cell, myScriptPartID: partID)
  }

  // Selects the pen tool.
  func selectPenTool() {
    try? toolController?.setToolForPointerType(tool: .toolPen, pointerType: .pen)
  }

  // Selects the eraser tool.
  func selectEraserTool() {
    try? toolController?.setToolForPointerType(tool: .eraser, pointerType: .pen)
  }

  // Selects the highlighter tool.
  func selectHighlighterTool() {
    try? toolController?.setToolForPointerType(tool: .toolHighlighter, pointerType: .pen)
  }

  // Saves all annotation parts.
  func save() throws {
    try package?.savePackage()
  }
}

// Weak reference wrapper for cells.
class WeakCellRef {
  weak var cell: PDFPageCell?

  init(cell: PDFPageCell) {
    self.cell = cell
  }
}
