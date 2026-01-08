// NotesOverlayCoordinator.swift
// Manages the notes button and overlay lifecycle for lessons.
// Follows the AIOverlayCoordinator pattern.

import UIKit

// Delegate for notes overlay coordinator events.
protocol NotesOverlayCoordinatorDelegate: AnyObject {
  func notesOverlayDidExpand(_ coordinator: NotesOverlayCoordinator)
  func notesOverlayDidCollapse(_ coordinator: NotesOverlayCoordinator)
}

// Coordinates the notes button and overlay for a LessonViewController.
// Owns the InputViewController for the notes canvas.
final class NotesOverlayCoordinator: NSObject {

  // MARK: - Properties

  weak var delegate: NotesOverlayCoordinatorDelegate?

  // The view controller this coordinator is attached to.
  private weak var viewController: UIViewController?

  // Lesson ID for persistence.
  private let lessonID: String

  // UI components.
  private var buttonView: NotesButtonView?
  private var overlayView: NotesOverlayView?
  private var tapCatcher: UIView?

  // MyScript canvas components.
  private var inputViewController: InputViewController?
  private var inputViewModel: InputViewModel?
  private var notesPackage: IINKContentPackage?

  // State.
  private(set) var isExpanded: Bool = false
  private(set) var isButtonVisible: Bool = false

  // Animation configuration.
  private let expandDuration: TimeInterval = 0.35
  private let collapseDuration: TimeInterval = 0.25
  private let springDamping: CGFloat = 0.85

  // MARK: - Initialization

  init(lessonID: String) {
    self.lessonID = lessonID
    super.init()
  }

  // MARK: - Attachment

  // Attaches the coordinator to a view controller.
  @MainActor
  func attach(to viewController: UIViewController) {
    self.viewController = viewController
    setupButton()
    setupOverlay()
    setupTapCatcher()
    setupCanvas()
  }

  // Detaches the coordinator and cleans up.
  func detach() {
    // Save notes before detaching.
    Task {
      await saveNotes()
    }

    // Remove UI.
    buttonView?.removeFromSuperview()
    overlayView?.removeFromSuperview()
    tapCatcher?.removeFromSuperview()

    // Release canvas.
    inputViewModel?.releasePart()
    inputViewController?.willMove(toParent: nil)
    inputViewController?.view.removeFromSuperview()
    inputViewController?.removeFromParent()

    buttonView = nil
    overlayView = nil
    tapCatcher = nil
    inputViewController = nil
    inputViewModel = nil
    notesPackage = nil
    viewController = nil
  }

  // MARK: - Setup

  private func setupButton() {
    guard let vc = viewController else { return }

    let button = NotesButtonView()
    button.tapped = { [weak self] in
      self?.toggleOverlay()
    }

    vc.view.addSubview(button)

    // Position at bottom-left (opposite of AI button which is bottom-right).
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
      button.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -70)
    ])

    // Start hidden.
    button.alpha = 0
    button.transform = CGAffineTransform(translationX: 0, y: 60)

    buttonView = button
  }

  private func setupOverlay() {
    guard let vc = viewController else { return }

    let overlay = NotesOverlayView()
    overlay.delegate = self
    overlay.onClearTapped = { [weak self] in
      self?.clearNotes()
    }

    vc.view.addSubview(overlay)

    // Position at bottom-left, above the button.
    NSLayoutConstraint.activate([
      overlay.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
      overlay.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
    ])

    // Start hidden and offset.
    overlay.alpha = 0
    overlay.transform = CGAffineTransform(translationX: -20, y: 100)

    overlayView = overlay
  }

  private func setupTapCatcher() {
    guard let vc = viewController else { return }

    let catcher = UIView()
    catcher.translatesAutoresizingMaskIntoConstraints = false
    catcher.backgroundColor = .clear
    catcher.isUserInteractionEnabled = false

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapCatcherTapped))
    catcher.addGestureRecognizer(tapGesture)

    vc.view.insertSubview(catcher, belowSubview: overlayView ?? vc.view)

    NSLayoutConstraint.activate([
      catcher.topAnchor.constraint(equalTo: vc.view.topAnchor),
      catcher.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
      catcher.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
      catcher.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
    ])

    tapCatcher = catcher
  }

  @MainActor
  private func setupCanvas() {
    guard let vc = viewController,
          let overlay = overlayView,
          let engine = EngineProvider.sharedInstance.engineInstance as? IINKEngine else {
      return
    }

    // Create InputViewModel for notes canvas.
    let inputVM = InputViewModel(
      engine: engine,
      inputMode: .auto,
      editorDelegate: nil,
      smartGuideDelegate: nil,
      smartGuideDisabled: true
    )
    inputViewModel = inputVM

    // Create InputViewController.
    let inputVC = InputViewController(viewModel: inputVM)
    inputViewController = inputVC

    // Add as child view controller.
    vc.addChild(inputVC)
    overlay.canvasContainer.addSubview(inputVC.view)
    inputVC.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      inputVC.view.topAnchor.constraint(equalTo: overlay.canvasContainer.topAnchor),
      inputVC.view.leadingAnchor.constraint(equalTo: overlay.canvasContainer.leadingAnchor),
      inputVC.view.trailingAnchor.constraint(equalTo: overlay.canvasContainer.trailingAnchor),
      inputVC.view.bottomAnchor.constraint(equalTo: overlay.canvasContainer.bottomAnchor)
    ])

    inputVC.didMove(toParent: vc)

    // Load existing notes.
    Task {
      await loadNotes()
    }
  }

  // MARK: - Button Visibility

  // Shows the notes button with animation.
  func showButton(animated: Bool) {
    guard let button = buttonView, !isButtonVisible else { return }
    isButtonVisible = true

    if animated {
      UIView.animate(
        withDuration: 0.25,
        delay: 0,
        usingSpringWithDamping: 0.8,
        initialSpringVelocity: 0,
        options: []
      ) {
        button.alpha = 1
        button.transform = .identity
      }
    } else {
      button.alpha = 1
      button.transform = .identity
    }
  }

  // Hides the notes button with animation.
  func hideButton(animated: Bool) {
    guard let button = buttonView, isButtonVisible else { return }
    isButtonVisible = false

    if animated {
      UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
        button.alpha = 0
        button.transform = CGAffineTransform(translationX: 0, y: 60)
      }
    } else {
      button.alpha = 0
      button.transform = CGAffineTransform(translationX: 0, y: 60)
    }
  }

  // MARK: - Overlay Toggle

  private func toggleOverlay() {
    if isExpanded {
      collapseOverlay()
    } else {
      expandOverlay()
    }
  }

  // Expands the notes overlay.
  func expandOverlay() {
    guard let overlay = overlayView, !isExpanded else { return }
    isExpanded = true

    // Enable tap catcher.
    tapCatcher?.isUserInteractionEnabled = true

    // Yield the button.
    buttonView?.animateYield()

    // Animate overlay in.
    UIView.animate(
      withDuration: expandDuration,
      delay: 0,
      usingSpringWithDamping: springDamping,
      initialSpringVelocity: 0,
      options: []
    ) {
      overlay.alpha = 1
      overlay.transform = .identity
    }

    delegate?.notesOverlayDidExpand(self)
  }

  // Collapses the notes overlay.
  func collapseOverlay() {
    guard let overlay = overlayView, isExpanded else { return }
    isExpanded = false

    // Disable tap catcher.
    tapCatcher?.isUserInteractionEnabled = false

    // Return the button.
    buttonView?.animateReturn()

    // Animate overlay out.
    UIView.animate(
      withDuration: collapseDuration,
      delay: 0,
      options: .curveEaseIn
    ) {
      overlay.alpha = 0
      overlay.transform = CGAffineTransform(translationX: -20, y: 100)
    }

    // Save notes when collapsing.
    Task {
      await saveNotes()
    }

    delegate?.notesOverlayDidCollapse(self)
  }

  @objc private func tapCatcherTapped() {
    collapseOverlay()
  }

  // MARK: - Tool Forwarding

  // Forwards tool selection to the notes canvas.
  func setTool(_ tool: ToolPaletteView.ToolSelection) {
    switch tool {
    case .pen:
      inputViewModel?.selectPenTool()
    case .eraser:
      inputViewModel?.selectEraserTool()
    case .highlighter:
      inputViewModel?.selectHighlighterTool()
    }
  }

  // Forwards color change to the notes canvas.
  func setToolColor(hex: String, tool: ToolPaletteView.ToolSelection) {
    let iinkTool: IINKPointerTool
    switch tool {
    case .pen:
      iinkTool = .toolPen
    case .highlighter:
      iinkTool = .toolHighlighter
    case .eraser:
      return
    }
    // Default width - could be tracked per tool.
    inputViewModel?.setToolStyle(colorHex: hex, width: 0.65, tool: iinkTool)
  }

  // Forwards thickness change to the notes canvas.
  func setToolThickness(width: CGFloat, tool: ToolPaletteView.ToolSelection) {
    let iinkTool: IINKPointerTool
    switch tool {
    case .pen:
      iinkTool = .toolPen
    case .highlighter:
      iinkTool = .toolHighlighter
    case .eraser:
      return
    }
    // Default color - could be tracked per tool.
    inputViewModel?.setToolStyle(colorHex: "#000000", width: width, tool: iinkTool)
  }

  // Forwards undo to the notes canvas.
  func undo() {
    inputViewModel?.undo()
  }

  // Forwards redo to the notes canvas.
  func redo() {
    inputViewModel?.redo()
  }

  // Clears the notes canvas.
  func clearNotes() {
    inputViewModel?.clear()
  }

  // MARK: - Persistence

  // Loads notes from storage.
  @MainActor
  private func loadNotes() async {
    // TODO: Implement loading from LessonInkStorage.
    // For now, create a new Raw Content part.
    guard let engine = EngineProvider.sharedInstance.engineInstance as? IINKEngine else {
      return
    }

    do {
      // Create a temporary package for the notes.
      let tempDir = FileManager.default.temporaryDirectory
      let packagePath = tempDir.appendingPathComponent("lesson-notes-\(lessonID).iink").path

      // Create or open the package.
      let package: IINKContentPackage
      if FileManager.default.fileExists(atPath: packagePath) {
        package = try engine.openPackage(packagePath)
      } else {
        package = try engine.createPackage(packagePath)
      }

      // Store package reference for saving.
      notesPackage = package

      // Get or create the Raw Content part.
      let part: IINKContentPart
      if package.partCount() > 0 {
        part = try package.part(at: 0)
      } else {
        part = try package.createPart(with: "Raw Content")
      }

      // Set the part on the editor.
      try inputViewModel?.editor?.setEditorPart(part)
    } catch {
      // Silently fail - user can still use notes, they just won't persist.
    }
  }

  // Saves notes to storage.
  func saveNotes() async {
    // TODO: Implement saving to LessonInkStorage.
    // For now, the package auto-saves.
    try? notesPackage?.save()
  }
}

// MARK: - NotesOverlayViewDelegate

extension NotesOverlayCoordinator: NotesOverlayViewDelegate {
  func notesOverlayDidRequestDismiss(_ overlay: NotesOverlayView) {
    collapseOverlay()
  }
}
