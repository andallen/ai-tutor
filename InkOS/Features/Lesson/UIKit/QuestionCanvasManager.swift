// QuestionCanvasManager.swift
// Manages MyScript canvas instances for question cells in lessons.
// Handles lifecycle, persistence, and tool forwarding for embedded answer canvases.

import UIKit

// Delegate for question canvas manager events.
protocol QuestionCanvasManagerDelegate: AnyObject {
  // Called when a canvas becomes active (receives focus).
  func questionCanvasDidBecomeActive(sectionID: String)

  // Called when a canvas becomes inactive (loses focus).
  func questionCanvasDidBecomeInactive(sectionID: String)
}

// Manages InputViewControllers for question answer canvases.
// Creates canvases on demand when question cells need them.
@MainActor
final class QuestionCanvasManager {

  // MARK: - Properties

  weak var delegate: QuestionCanvasManagerDelegate?

  // Parent view controller for embedding child view controllers.
  private weak var parentViewController: UIViewController?

  // Lesson ID for persistence paths.
  private let lessonID: String

  // Active canvas data indexed by section ID.
  private var canvases: [String: CanvasEntry] = [:]

  // Currently active canvas section ID.
  private(set) var activeCanvasID: String?

  // MARK: - Canvas Entry

  // Stores canvas components for a question.
  private struct CanvasEntry {
    let sectionID: String
    let inputViewController: InputViewController
    let inputViewModel: InputViewModel
    var package: IINKContentPackage?
  }

  // MARK: - Initialization

  init(lessonID: String) {
    self.lessonID = lessonID
  }

  // MARK: - Setup

  // Attaches the manager to a parent view controller.
  func attach(to viewController: UIViewController) {
    parentViewController = viewController
  }

  // Detaches and cleans up all canvases.
  func detach() {
    // Save all canvases before detaching.
    Task {
      await saveAllInk()
    }

    // Remove all canvases.
    for (_, entry) in canvases {
      entry.inputViewModel.releasePart()
      entry.inputViewController.willMove(toParent: nil)
      entry.inputViewController.view.removeFromSuperview()
      entry.inputViewController.removeFromParent()
    }

    canvases.removeAll()
    activeCanvasID = nil
    parentViewController = nil
  }

  // MARK: - Canvas Lifecycle

  // Embeds a canvas in the given container view for a question section.
  // Returns true if successful.
  func embedCanvas(in container: UIView, for sectionID: String, questionType: QuestionType) -> Bool {
    guard let parent = parentViewController,
          let engine = EngineProvider.sharedInstance.engineInstance as? IINKEngine else {
      return false
    }

    // Check if canvas already exists.
    if let existingEntry = canvases[sectionID] {
      // Re-parent the existing canvas view.
      existingEntry.inputViewController.view.removeFromSuperview()
      container.addSubview(existingEntry.inputViewController.view)
      constrainCanvas(existingEntry.inputViewController.view, to: container)
      return true
    }

    // Create new canvas components.
    let inputVM = InputViewModel(
      engine: engine,
      inputMode: .auto,
      editorDelegate: nil,
      smartGuideDelegate: nil,
      smartGuideDisabled: true
    )

    let inputVC = InputViewController(viewModel: inputVM)

    // Add as child view controller.
    parent.addChild(inputVC)
    container.addSubview(inputVC.view)
    constrainCanvas(inputVC.view, to: container)
    inputVC.didMove(toParent: parent)

    // Create entry and store.
    var entry = CanvasEntry(
      sectionID: sectionID,
      inputViewController: inputVC,
      inputViewModel: inputVM,
      package: nil
    )

    // Load existing ink for this question.
    Task {
      let package = await loadQuestionInk(sectionID: sectionID, engine: engine, inputVM: inputVM)
      entry.package = package
      canvases[sectionID] = entry
    }

    canvases[sectionID] = entry
    return true
  }

  // Removes a canvas from its container when a cell is recycled.
  func removeCanvas(for sectionID: String) {
    guard let entry = canvases[sectionID] else { return }

    // Save ink before removing.
    Task {
      await saveQuestionInk(sectionID: sectionID)
    }

    // Remove from view hierarchy but keep in memory.
    entry.inputViewController.view.removeFromSuperview()

    // Clear active state if this was the active canvas.
    if activeCanvasID == sectionID {
      activeCanvasID = nil
      delegate?.questionCanvasDidBecomeInactive(sectionID: sectionID)
    }
  }

  // Fully releases a canvas and its resources.
  func releaseCanvas(for sectionID: String) {
    guard let entry = canvases.removeValue(forKey: sectionID) else { return }

    // Save ink before releasing.
    Task {
      try? entry.package?.save()
    }

    entry.inputViewModel.releasePart()
    entry.inputViewController.willMove(toParent: nil)
    entry.inputViewController.view.removeFromSuperview()
    entry.inputViewController.removeFromParent()

    if activeCanvasID == sectionID {
      activeCanvasID = nil
      delegate?.questionCanvasDidBecomeInactive(sectionID: sectionID)
    }
  }

  private func constrainCanvas(_ canvasView: UIView, to container: UIView) {
    canvasView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      canvasView.topAnchor.constraint(equalTo: container.topAnchor),
      canvasView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      canvasView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      canvasView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
  }

  // MARK: - Active Canvas

  // Sets the active canvas for tool forwarding.
  func setActiveCanvas(_ sectionID: String?) {
    let previousID = activeCanvasID

    if let previousID = previousID, previousID != sectionID {
      delegate?.questionCanvasDidBecomeInactive(sectionID: previousID)
    }

    activeCanvasID = sectionID

    if let newID = sectionID, newID != previousID {
      delegate?.questionCanvasDidBecomeActive(sectionID: newID)
    }
  }

  // Returns the IDs of all visible canvases.
  func visibleCanvasIDs() -> Set<String> {
    return Set(canvases.compactMap { (sectionID, entry) in
      entry.inputViewController.view.superview != nil ? sectionID : nil
    })
  }

  // MARK: - Tool Forwarding

  // Forwards tool selection to the active canvas.
  func setTool(_ tool: ToolPaletteView.ToolSelection) {
    guard let activeID = activeCanvasID,
          let entry = canvases[activeID] else {
      return
    }

    switch tool {
    case .pen:
      entry.inputViewModel.selectPenTool()
    case .eraser:
      entry.inputViewModel.selectEraserTool()
    case .highlighter:
      entry.inputViewModel.selectHighlighterTool()
    }
  }

  // Forwards color change to the active canvas.
  func setToolColor(hex: String, tool: ToolPaletteView.ToolSelection) {
    guard let activeID = activeCanvasID,
          let entry = canvases[activeID] else {
      return
    }

    let iinkTool: IINKPointerTool
    switch tool {
    case .pen:
      iinkTool = .toolPen
    case .highlighter:
      iinkTool = .toolHighlighter
    case .eraser:
      return
    }

    entry.inputViewModel.setToolStyle(colorHex: hex, width: 0.65, tool: iinkTool)
  }

  // Forwards thickness change to the active canvas.
  func setToolThickness(width: CGFloat, tool: ToolPaletteView.ToolSelection) {
    guard let activeID = activeCanvasID,
          let entry = canvases[activeID] else {
      return
    }

    let iinkTool: IINKPointerTool
    switch tool {
    case .pen:
      iinkTool = .toolPen
    case .highlighter:
      iinkTool = .toolHighlighter
    case .eraser:
      return
    }

    entry.inputViewModel.setToolStyle(colorHex: "#000000", width: width, tool: iinkTool)
  }

  // Forwards undo to the active canvas.
  func undo() {
    guard let activeID = activeCanvasID,
          let entry = canvases[activeID] else {
      return
    }
    entry.inputViewModel.undo()
  }

  // Forwards redo to the active canvas.
  func redo() {
    guard let activeID = activeCanvasID,
          let entry = canvases[activeID] else {
      return
    }
    entry.inputViewModel.redo()
  }

  // Clears the active canvas.
  func clear() {
    guard let activeID = activeCanvasID,
          let entry = canvases[activeID] else {
      return
    }
    entry.inputViewModel.clear()
  }

  // MARK: - Persistence

  // Loads ink for a question section.
  private func loadQuestionInk(
    sectionID: String,
    engine: IINKEngine,
    inputVM: InputViewModel
  ) async -> IINKContentPackage? {
    do {
      // Create path for question ink storage.
      let inkDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("lesson-ink")
        .appendingPathComponent(lessonID)

      // Create directory if needed.
      try FileManager.default.createDirectory(at: inkDir, withIntermediateDirectories: true)

      let packagePath = inkDir.appendingPathComponent("\(sectionID).iink").path

      // Create or open the package.
      let package: IINKContentPackage
      if FileManager.default.fileExists(atPath: packagePath) {
        package = try engine.openPackage(packagePath)
      } else {
        package = try engine.createPackage(packagePath)
      }

      // Get or create the Raw Content part.
      let part: IINKContentPart
      if package.partCount() > 0 {
        part = try package.part(at: 0)
      } else {
        part = try package.createPart(with: "Raw Content")
      }

      // Set the part on the editor.
      try inputVM.editor?.setEditorPart(part)

      return package
    } catch {
      // Silently fail - user can still write, it just won't persist.
      return nil
    }
  }

  // Saves ink for a specific question section.
  func saveQuestionInk(sectionID: String) async {
    guard let entry = canvases[sectionID] else { return }
    try? entry.package?.save()
  }

  // Saves all ink data.
  func saveAllInk() async {
    for (_, entry) in canvases {
      try? entry.package?.save()
    }
  }

  // MARK: - Content Export

  // Exports the handwritten content as recognized text (JIIX) for AI checking.
  func exportRecognizedText(for sectionID: String) async -> String? {
    guard let entry = canvases[sectionID],
          let editor = entry.inputViewModel.editor as? IINKEditor else {
      return nil
    }

    do {
      // Export as JIIX for text recognition.
      let jiix = try editor.export(selection: nil, mimeType: .JIIX)
      return jiix
    } catch {
      return nil
    }
  }
}
