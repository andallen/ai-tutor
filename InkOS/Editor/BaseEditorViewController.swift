// Base view controller for editor screens (notebooks and PDFs).
// Provides common UI elements: home button, tool palette, editing toolbar, AI overlay.
// Subclasses override callback methods to connect to their specific view models.

import Combine
import SwiftUI
import UIKit

// Base editor that sets up shared UI components.
// EditorViewController and PDFEditorViewController inherit from this.
class BaseEditorViewController: UIViewController {

  // MARK: - UI Components

  // Container view that fills the entire screen.
  private(set) var editorContainerView: UIView!

  // Home button at top left.
  private var homeButtonView: HomeButtonView?

  // Tool palette at bottom.
  private(set) var toolPaletteView: ToolPaletteView?

  // Editing toolbar at top right.
  private var editingToolbarView: EditingToolbarView?

  // AI overlay coordinator (manages button and overlay).
  private(set) var aiOverlayCoordinator: AIOverlayCoordinator?

  // Tap gesture for dismissing the tool palette.
  private var paletteDismissTapRecognizer: UITapGestureRecognizer?

  // MARK: - State

  // Handler called when the editor requests dismissal.
  var dismissHandler: (() -> Void)?

  // Standard off-black accent color for UI elements.
  let offBlack = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)

  // MARK: - AIOverlayContextProvider (overridable)

  // Default location for editors is .note.
  var overlayLocation: AIOverlayLocation {
    .note
  }

  // Subclasses should override to return the current notebook ID.
  var currentNoteID: String? {
    nil
  }

  // Editors typically don't have a folder context.
  var currentFolderID: String? {
    nil
  }

  // MARK: - Lifecycle

  override func loadView() {
    super.loadView()
    // Creates the editor container view programmatically to fill entire screen.
    let containerView = UIView(frame: UIScreen.main.bounds)
    containerView.backgroundColor = UIColor.white
    containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.view.addSubview(containerView)
    self.editorContainerView = containerView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    hideNavigationBar()
    configureHomeButton()
    configureToolPalette()
    configurePaletteDismissTap()
    configureEditingToolbar()
    configureAIOverlayCoordinator()
  }

  // MARK: - Abstract Callbacks (Override in Subclasses)

  // Called when the back button is tapped. Subclasses should save and dismiss.
  func handleBackButtonTapped() {
    if let handler = dismissHandler {
      handler()
    } else {
      dismiss(animated: true)
    }
  }

  // Called when a tool is selected in the palette.
  func handleToolSelectionChanged(_ tool: ToolPaletteView.ToolSelection) {
    // Override in subclass.
  }

  // Called when a tool's color is changed.
  func handleToolColorChanged(tool: ToolPaletteView.ToolSelection, hex: String) {
    // Override in subclass.
  }

  // Called when a tool's thickness is changed.
  func handleToolThicknessChanged(tool: ToolPaletteView.ToolSelection, width: CGFloat) {
    // Override in subclass.
  }

  // Called when undo is tapped.
  func handleUndoTapped() {
    // Override in subclass.
  }

  // Called when redo is tapped.
  func handleRedoTapped() {
    // Override in subclass.
  }

  // Called when clear is tapped.
  func handleClearTapped() {
    // Override in subclass.
  }


  // MARK: - Navigation

  // Hides the navigation bar since all UI is now floating views.
  private func hideNavigationBar() {
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  // MARK: - Home Button

  private func configureHomeButton() {
    let buttonView = HomeButtonView(accentColor: offBlack)
    buttonView.translatesAutoresizingMaskIntoConstraints = false
    buttonView.tapped = { [weak self] in
      self?.handleBackButtonTapped()
    }
    view.addSubview(buttonView)

    // Position at top left, aligned with safe area.
    buttonView.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    buttonView.topAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.topAnchor,
      constant: 4
    ).isActive = true
    homeButtonView = buttonView
  }

  // MARK: - Tool Palette

  private func configureToolPalette() {
    let paletteView = ToolPaletteView(accentColor: offBlack)
    paletteView.translatesAutoresizingMaskIntoConstraints = false
    paletteView.selectionChanged = { [weak self] selection in
      self?.handleToolSelectionChanged(selection)
    }
    paletteView.colorSelectionChanged = { [weak self] tool, hex in
      self?.handleToolColorChanged(tool: tool, hex: hex)
    }
    paletteView.thicknessChanged = { [weak self] tool, width in
      self?.handleToolThicknessChanged(tool: tool, width: width)
    }
    view.addSubview(paletteView)

    paletteView.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    paletteView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    paletteView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: 0
    ).isActive = true
    toolPaletteView = paletteView
  }

  // Configures tap gesture to collapse the tool palette when tapping outside with a finger.
  private func configurePaletteDismissTap() {
    let tapRecognizer = UITapGestureRecognizer(
      target: self,
      action: #selector(handlePaletteDismissTap(_:))
    )
    // Only respond to finger touches, not Apple Pencil.
    tapRecognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
    // Allow simultaneous recognition so it doesn't interfere with drawing.
    tapRecognizer.cancelsTouchesInView = false
    tapRecognizer.delegate = self
    view.addGestureRecognizer(tapRecognizer)
    paletteDismissTapRecognizer = tapRecognizer
  }

  // Handles taps outside the tool palette to collapse it.
  @objc private func handlePaletteDismissTap(_ recognizer: UITapGestureRecognizer) {
    guard let paletteView = toolPaletteView, paletteView.isExpanded else {
      return
    }
    // Only collapse if the tap is outside the palette.
    let location = recognizer.location(in: view)
    if paletteView.containsInteraction(at: location, in: view) == false {
      paletteView.setToolbarVisible(false, animated: true)
    }
  }

  // MARK: - Editing Toolbar

  private func configureEditingToolbar() {
    let toolbarView = EditingToolbarView(accentColor: offBlack)
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.undoTapped = { [weak self] in
      self?.handleUndoTapped()
    }
    toolbarView.redoTapped = { [weak self] in
      self?.handleRedoTapped()
    }
    toolbarView.clearTapped = { [weak self] in
      self?.handleClearTapped()
    }
    view.addSubview(toolbarView)

    // Position at top right, aligned with safe area.
    toolbarView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    toolbarView.topAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.topAnchor,
      constant: 4
    ).isActive = true
    editingToolbarView = toolbarView
  }

  // MARK: - AI Overlay Coordinator

  // Sets up the AI overlay coordinator.
  // The coordinator manages the AI button and overlay lifecycle.
  private func configureAIOverlayCoordinator() {
    let coordinator = AIOverlayCoordinator()
    coordinator.attach(to: self, contextProvider: self)
    aiOverlayCoordinator = coordinator
  }

  // MARK: - Transition UI Control (for hero animations)

  // Controls the visibility of the home button for hero transitions.
  func setHomeButtonVisible(_ visible: Bool, animated: Bool) {
    guard let buttonView = homeButtonView else { return }
    let offset: CGFloat = visible ? 0 : -60
    if animated {
      UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
        buttonView.transform = CGAffineTransform(translationX: 0, y: offset)
        buttonView.alpha = visible ? 1 : 0
      }
    } else {
      buttonView.transform = CGAffineTransform(translationX: 0, y: offset)
      buttonView.alpha = visible ? 1 : 0
    }
  }

  // Controls the visibility of the tool palette for hero transitions.
  func setToolPaletteVisible(_ visible: Bool, animated: Bool) {
    guard let paletteView = toolPaletteView else { return }
    let offset: CGFloat = visible ? 0 : 60
    if animated {
      UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
        paletteView.transform = CGAffineTransform(translationX: 0, y: offset)
        paletteView.alpha = visible ? 1 : 0
      }
    } else {
      paletteView.transform = CGAffineTransform(translationX: 0, y: offset)
      paletteView.alpha = visible ? 1 : 0
    }
  }

  // Controls the visibility of the editing toolbar for hero transitions.
  func setEditingToolbarVisible(_ visible: Bool, animated: Bool) {
    guard let toolbarView = editingToolbarView else { return }
    let offset: CGFloat = visible ? 0 : -60
    if animated {
      UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
        toolbarView.transform = CGAffineTransform(translationX: 0, y: offset)
        toolbarView.alpha = visible ? 1 : 0
      }
    } else {
      toolbarView.transform = CGAffineTransform(translationX: 0, y: offset)
      toolbarView.alpha = visible ? 1 : 0
    }
  }

  // Controls the visibility of the AI button for hero transitions.
  func setAIButtonVisible(_ visible: Bool, animated: Bool) {
    if visible {
      aiOverlayCoordinator?.showButton(animated: animated)
    } else {
      aiOverlayCoordinator?.hideButton(animated: animated)
    }
  }

  // Hides all UI elements for the hero transition animation.
  func hideAllUIForTransition() {
    setHomeButtonVisible(false, animated: false)
    setToolPaletteVisible(false, animated: false)
    setEditingToolbarVisible(false, animated: false)
    setAIButtonVisible(false, animated: false)
  }

  // Shows all UI elements after the hero transition completes.
  func showAllUIAfterTransition(animated: Bool) {
    setHomeButtonVisible(true, animated: animated)
    setToolPaletteVisible(true, animated: animated)
    setEditingToolbarVisible(true, animated: animated)
    setAIButtonVisible(true, animated: animated)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension BaseEditorViewController: UIGestureRecognizerDelegate {
  // Allows the palette dismiss tap gesture to work simultaneously with other gestures.
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    // Allow simultaneous recognition for the palette dismiss tap.
    return gestureRecognizer == paletteDismissTapRecognizer
  }
}

// MARK: - AIOverlayContextProvider

extension BaseEditorViewController: AIOverlayContextProvider {}
