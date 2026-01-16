// View model for the notebook editor.
// Manages editor lifecycle, tool state, and ink style updates.

import Combine
import UIKit

// MARK: - DocumentHandle

// Reference to an open document for the editor.
// Wraps the content package and part for MyScript SDK operations.
struct DocumentHandle {
  // URL to the iink package file.
  let packageURL: URL

  // Content part being edited.
  var part: IINKContentPart?

  // Creates a document handle with the given package URL.
  init(packageURL: URL, part: IINKContentPart? = nil) {
    self.packageURL = packageURL
    self.part = part
  }
}

// MARK: - EditorViewModel

// Manages state and business logic for the notebook editor.
// Publishes changes to the view controller via Combine.
@MainActor
class EditorViewModel {

  // MARK: - Published Properties

  // The editor view controller managed by the MyScript SDK.
  @Published var editorViewController: UIViewController?

  // Alert to present to the user.
  @Published var alert: UIAlertController?

  // MARK: - Private Properties

  // Reference to the MyScript engine provider.
  private var engineProvider: EngineProvider?

  // Handle to the document being edited.
  private var documentHandle: DocumentHandle?

  // The input view model that manages ink input and gestures.
  private var inputViewModel: InputViewModel?

  // The input view controller that hosts the MyScript editor.
  private var inputViewController: InputViewController?

  // Default ink colors for each tool.
  private var penColor: String = "#000000"
  private var highlighterColor: String = "#FFFF0080"

  // Default ink widths for each tool (in mm).
  private var penWidth: CGFloat = 1.5
  private var highlighterWidth: CGFloat = 8.0

  // MARK: - Lifecycle

  init() {}

  // Sets up the editor with the given engine provider and document.
  func setupModel(engineProvider: EngineProvider, documentHandle: DocumentHandle) {
    self.engineProvider = engineProvider
    self.documentHandle = documentHandle

    // Create the input view model with the engine.
    let inputVM = InputViewModel(
      engine: engineProvider.engine,
      inputMode: .auto,
      editorDelegate: nil,
      smartGuideDelegate: nil,
      smartGuideDisabled: true
    )

    self.inputViewModel = inputVM

    // Create the input view controller.
    let inputVC = InputViewController(viewModel: inputVM)
    self.inputViewController = inputVC

    // Open the document part if available.
    if let part = documentHandle.part {
      do {
        try inputVM.editor?.setEditorPart(part)
      } catch {
        presentError(message: "Failed to open document: \(error.localizedDescription)")
      }
    }

    // Publish the editor view controller.
    self.editorViewController = inputVC
  }

  // Updates the editor view size when the container bounds change.
  func setEditorViewSize(bounds: CGRect) {
    inputViewModel?.setEditorViewSize(size: bounds.size)
  }

  // MARK: - Tool Management

  // Updates the active tool based on the palette selection.
  func updateTool(selection: ToolPaletteView.ToolSelection) {
    switch selection {
    case .pen:
      inputViewModel?.selectPenTool()
      applyToolStyle(tool: .toolPen, color: penColor, width: penWidth)
    case .eraser:
      inputViewModel?.selectEraserTool()
    case .highlighter:
      inputViewModel?.selectHighlighterTool()
      applyToolStyle(tool: .toolHighlighter, color: highlighterColor, width: highlighterWidth)
    }
  }

  // Updates the ink color for a specific tool.
  func updateInkColor(hex: String, for tool: ToolPaletteView.ToolSelection) {
    switch tool {
    case .pen:
      penColor = hex
      applyToolStyle(tool: .toolPen, color: penColor, width: penWidth)
    case .highlighter:
      highlighterColor = hex
      applyToolStyle(tool: .toolHighlighter, color: highlighterColor, width: highlighterWidth)
    case .eraser:
      // Eraser has no color.
      break
    }
  }

  // Updates the ink width for a specific tool.
  func updateInkWidth(width: CGFloat, for tool: ToolPaletteView.ToolSelection) {
    switch tool {
    case .pen:
      penWidth = width
      applyToolStyle(tool: .toolPen, color: penColor, width: penWidth)
    case .highlighter:
      highlighterWidth = width
      applyToolStyle(tool: .toolHighlighter, color: highlighterColor, width: highlighterWidth)
    case .eraser:
      // Eraser width is managed by the SDK.
      break
    }
  }

  // Applies the style (color and width) to a MyScript tool.
  private func applyToolStyle(tool: IINKPointerTool, color: String, width: CGFloat) {
    inputViewModel?.setToolStyle(colorHex: color, width: width, tool: tool)
  }

  // MARK: - Edit Operations

  // Performs an undo operation.
  func undo() {
    inputViewModel?.undo()
  }

  // Performs a redo operation.
  func redo() {
    inputViewModel?.redo()
  }

  // Clears all content from the editor.
  func clear() {
    inputViewModel?.clear()
  }

  // MARK: - App Lifecycle

  // Handles the app entering background state.
  // Saves content and releases resources as needed.
  func handleAppBackground() {
    // Save content when going to background.
    // Implementation would trigger JIIX persistence here.
  }

  // Releases the editor and captures a preview image.
  func releaseEditor(previewImage: UIImage?) {
    // Release the part to allow re-editing later.
    inputViewModel?.releasePart()

    // Save the preview image to the document handle if needed.
    // Implementation would save the preview here.
  }

  // MARK: - Error Handling

  // Presents an error alert for a missing notebook.
  func presentMissingNotebookError() {
    presentError(message: "No notebook selected. Please select a notebook to edit.")
  }

  // Creates and publishes an alert for the given error message.
  private func presentError(message: String) {
    let alert = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    self.alert = alert
  }
}
