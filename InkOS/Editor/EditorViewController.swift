// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import SwiftUI
import UIKit

// Main view controller for notebook editing.
// Extends BaseEditorViewController with notebook-specific functionality.
class EditorViewController: BaseEditorViewController {

  // MARK: - Properties

  private var viewModel: EditorViewModel = EditorViewModel()
  private var editorViewController: InputViewController?
  private var cancellables: Set<AnyCancellable> = []
  private var documentHandle: DocumentHandle?
  private let previewMaxPixelDimension: CGFloat = 1200
  private var hasPreparedForExit = false

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    bindViewModel()
    guard let documentHandle else {
      viewModel.presentMissingNotebookError()
      return
    }
    viewModel.setupModel(
      engineProvider: EngineProvider.sharedInstance,
      documentHandle: documentHandle
    )
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

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    viewModel.setEditorViewSize(bounds: view.bounds)
  }

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  // MARK: - Configuration

  func configure(documentHandle: DocumentHandle) {
    self.documentHandle = documentHandle
  }

  // MARK: - Data Binding

  private func bindViewModel() {
    viewModel.$editorViewController.sink { [weak self] editorViewController in
      // Cast to InputViewController since child VC management requires concrete type.
      if let editorViewController = editorViewController as? InputViewController {
        self?.injectEditor(editor: editorViewController)
      }
    }.store(in: &cancellables)
    viewModel.$alert.sink { [weak self] alert in
      guard let unwrappedAlert = alert else { return }
      self?.present(unwrappedAlert, animated: true, completion: nil)
    }.store(in: &cancellables)
  }

  // Injects the MyScript editor as a child view controller.
  private func injectEditor(editor: InputViewController) {
    self.editorViewController = editor
    addChild(editor)
    editorContainerView.addSubview(editor.view)
    editor.view.frame = view.bounds
    editor.didMove(toParent: self)
  }

  // MARK: - Callback Overrides

  override func handleBackButtonTapped() {
    prepareForExit()
    // Check for custom UIKit transition coordinator first.
    if let navController = navigationController as? EditorNavigationController,
       let coordinator = navController.notebookTransitionCoordinator {
      coordinator.dismiss()
      return
    }
    // Fallback to SwiftUI dismiss handler or standard dismiss.
    super.handleBackButtonTapped()
  }

  override func handleToolSelectionChanged(_ tool: ToolPaletteView.ToolSelection) {
    viewModel.updateTool(selection: tool)
  }

  override func handleToolColorChanged(tool: ToolPaletteView.ToolSelection, hex: String) {
    viewModel.updateInkColor(hex: hex, for: tool)
  }

  override func handleToolThicknessChanged(tool: ToolPaletteView.ToolSelection, width: CGFloat) {
    viewModel.updateInkWidth(width: width, for: tool)
  }

  override func handleUndoTapped() {
    viewModel.undo()
  }

  override func handleRedoTapped() {
    viewModel.redo()
  }

  override func handleClearTapped() {
    viewModel.clear()
  }

  // MARK: - AIOverlayContextProvider

  override var currentNoteID: String? {
    documentHandle?.notebookID
  }

  // MARK: - Exit Handling

  @objc private func handleWillResignActive() {
    viewModel.handleAppBackground()
  }

  // Captures a preview and releases the editor once per exit.
  private func prepareForExit() {
    guard hasPreparedForExit == false else { return }
    hasPreparedForExit = true
    let previewImage = editorViewController?.capturePreviewImage(
      maxPixelDimension: previewMaxPixelDimension
    )
    viewModel.releaseEditor(previewImage: previewImage)
  }

  // MARK: - Preview Capture

  // Captures the current editor content as a preview image.
  // Used during dismiss to update the card thumbnail.
  func capturePreviewImage(maxPixelDimension: CGFloat) -> UIImage? {
    return editorViewController?.capturePreviewImage(maxPixelDimension: maxPixelDimension)
  }
}
