// PDFEditorViewController.swift
// UIViewController hosting the MyScript canvas for PDF annotation.
// Extends BaseEditorViewController with PDF-specific functionality.

import Combine
import SwiftUI
import UIKit

// View controller for annotating PDF documents.
// Hosts the MyScript canvas with PDF pages rendered as background.
final class PDFEditorViewController: BaseEditorViewController {

  // MARK: - Properties

  private let viewModel: PDFEditorViewModel
  // Named to avoid conflict with UIViewController.inputViewController.
  private var editorInputVC: InputViewController?
  private var inputVM: InputViewModel?

  // Provides the default Raw Content configuration for recognition.
  private let configurationProvider = DefaultRawContentConfigurationProvider()
  // Applies configuration to the engine.
  private let configurationApplier = RawContentConfigurationApplier()

  // Tool state tracking.
  private var selectedPenColorHex = "#000000"
  private var selectedHighlighterColorHex = "#FFF176"
  private var selectedPenWidth: CGFloat = 0.65
  private var selectedHighlighterWidth: CGFloat = 5.0
  private var selectedTool: ToolPaletteView.ToolSelection = .pen

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
    setupInputViewController()
    loadDocument()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    inputVM?.setEditorViewSize(size: view.bounds.size)
  }

  // MARK: - Setup

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

    // Add as child view controller to the container view.
    addChild(inputVC)
    editorContainerView.addSubview(inputVC.view)
    inputVC.view.frame = view.bounds
    inputVC.didMove(toParent: self)
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

  // MARK: - Callback Overrides

  override func handleBackButtonTapped() {
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

  override func handleToolSelectionChanged(_ tool: ToolPaletteView.ToolSelection) {
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

  override func handleToolColorChanged(tool: ToolPaletteView.ToolSelection, hex: String) {
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

  override func handleToolThicknessChanged(tool: ToolPaletteView.ToolSelection, width: CGFloat) {
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

  override func handleUndoTapped() {
    inputVM?.undo()
  }

  override func handleRedoTapped() {
    inputVM?.redo()
  }

  override func handleClearTapped() {
    inputVM?.clear()
  }

  // MARK: - AIOverlayContextProvider

  override var currentNoteID: String? {
    viewModel.session.id
  }

  // MARK: - Error Handling

  private func showError(_ message: String) {
    let alert = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(
      UIAlertAction(title: "OK", style: .default) { [weak self] _ in
        self?.handleBackButtonTapped()
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
