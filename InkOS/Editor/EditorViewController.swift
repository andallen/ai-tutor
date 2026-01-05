// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

// This is the Main ViewController of the project.
// It Encapsulates the InputViewController, and permits editing actions (such as undo/redo)
// EditorViewController is large due to MyScript SDK integration and comprehensive editing features
// swiftlint:disable type_body_length
class EditorViewController: UIViewController {

  // MARK: Properties

  private var editorContainerView: UIView!

  private var viewModel: EditorViewModel = EditorViewModel()
  private var editorViewController: InputViewController?
  private var cancellables: Set<AnyCancellable> = []
  private var documentHandle: DocumentHandle?
  private let offBlack: UIColor = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
  private let previewMaxPixelDimension: CGFloat = 1200
  private var hasPreparedForExit = false
  // Stores the floating tool palette attached to the canvas view.
  private var toolPaletteView: ToolPaletteView?
  // Stores the home button at top left.
  private var homeButtonView: HomeButtonView?
  // Stores the editing toolbar anchored to the top right.
  private var editingToolbarView: EditingToolbarView?
  // Stores the AI button at bottom right.
  private var aiButtonView: AIButtonView?
  // Stores the AI overlay that expands from the AI button.
  private var aiOverlayView: AIOverlayView?
  // Stores the dim background behind the AI overlay.
  private var aiOverlayDimView: UIView?
  // Tap gesture recognizer to dismiss the tool palette when tapping outside with a finger.
  private var paletteDismissTapRecognizer: UITapGestureRecognizer?

  // Handler called when the editor requests dismissal.
  // When set, this replaces the default dismiss behavior to allow SwiftUI to control the transition.
  var dismissHandler: (() -> Void)?

  // MARK: - Life cycle

  override func loadView() {
    super.loadView()
    // Creates the editor container view programmatically.
    let containerView = UIView(frame: UIScreen.main.bounds)
    containerView.backgroundColor = UIColor.white
    containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.view.addSubview(containerView)
    self.editorContainerView = containerView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.hideNavigationBar()
    self.configureHomeButton()
    self.configureToolPalette()
    self.configurePaletteDismissTap()
    self.configureEditingToolbar()
    self.configureAIButton()
    self.bindViewModel()
    guard let documentHandle = documentHandle else {
      self.viewModel.presentMissingNotebookError()
      return
    }
    self.viewModel.setupModel(
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
    if self.isBeingDismissed || self.isMovingFromParent {
      prepareForExit()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  // MARK: - Data Binding

  private func bindViewModel() {
    self.viewModel.$editorViewController.sink { [weak self] editorViewController in
      // Cast to InputViewController since child VC management requires concrete type.
      if let editorViewController = editorViewController as? InputViewController {
        self?.injectEditor(editor: editorViewController)
      }
    }.store(in: &cancellables)
    self.viewModel.$alert.sink { [weak self] alert in
      guard let unwrappedAlert = alert else { return }
      self?.present(unwrappedAlert, animated: true, completion: nil)
    }.store(in: &cancellables)
  }

  // MARK: - EditorViewController UI config

  private func injectEditor(editor: InputViewController) {
    self.editorViewController = editor
    self.addChild(editor)
    self.editorContainerView.addSubview(editor.view)
    editor.view.frame = self.view.bounds
    editor.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.viewModel.setEditorViewSize(bounds: self.view.bounds)
  }

  // MARK: - Navigation

  // Hides the navigation bar since all UI is now floating views.
  private func hideNavigationBar() {
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  // Adds the home button as a floating circular glass button at top left.
  private func configureHomeButton() {
    let buttonView = HomeButtonView(accentColor: offBlack)
    buttonView.translatesAutoresizingMaskIntoConstraints = false
    buttonView.tapped = { [weak self] in
      self?.backButtonTapped()
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

  private func configureToolPalette() {
    let paletteView = ToolPaletteView(accentColor: offBlack)
    paletteView.translatesAutoresizingMaskIntoConstraints = false
    paletteView.selectionChanged = { [weak self] selection in
      self?.viewModel.updateTool(selection: selection)
    }
    paletteView.colorSelectionChanged = { [weak self] tool, hex in
      self?.viewModel.updateInkColor(hex: hex, for: tool)
    }
    paletteView.thicknessChanged = { [weak self] tool, width in
      self?.viewModel.updateInkWidth(width: width, for: tool)
    }
    paletteView.expansionChanged = { [weak self] isExpanded in
      // AI button slides down when palette expands.
      self?.setAIButtonVisible(isExpanded == false, animated: true)
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

  // Adds the editing toolbar as a floating view at top right.
  // Positioned directly in the view hierarchy for full control over rendering.
  private func configureEditingToolbar() {
    let toolbarView = EditingToolbarView(accentColor: offBlack)
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.undoTapped = { [weak self] in
      self?.viewModel.undo()
    }
    toolbarView.redoTapped = { [weak self] in
      self?.viewModel.redo()
    }
    toolbarView.clearTapped = { [weak self] in
      self?.viewModel.clear()
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

  // Adds the AI button to the bottom right of the screen.
  private func configureAIButton() {
    let buttonView = AIButtonView()
    buttonView.translatesAutoresizingMaskIntoConstraints = false
    buttonView.tapped = { [weak self] in
      self?.toggleAIOverlay()
    }
    view.addSubview(buttonView)

    buttonView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    buttonView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: 0
    ).isActive = true
    aiButtonView = buttonView

    // Configure the overlay after the button is set up.
    configureAIOverlay()
  }

  // Configures the AI overlay and tap-to-dismiss layer.
  private func configureAIOverlay() {
    guard let buttonView = aiButtonView else { return }

    // Create invisible tap catcher that covers the entire view (no dimming).
    let dimView = UIView()
    dimView.backgroundColor = UIColor.clear
    dimView.isHidden = true
    dimView.frame = view.bounds
    dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // Insert below the AI button so the button stays on top.
    view.insertSubview(dimView, belowSubview: buttonView)
    aiOverlayDimView = dimView

    // Add tap gesture for dismissal.
    let tapRecognizer = UITapGestureRecognizer(
      target: self,
      action: #selector(handleOverlayDismissTap(_:))
    )
    dimView.addGestureRecognizer(tapRecognizer)

    // Create overlay view.
    let overlayView = AIOverlayView()
    // Insert below the AI button so the button appears embedded.
    view.insertSubview(overlayView, belowSubview: buttonView)
    aiOverlayView = overlayView
  }

  // Toggles the AI overlay visibility.
  private func toggleAIOverlay() {
    guard let overlayView = aiOverlayView,
      let buttonView = aiButtonView,
      let dimView = aiOverlayDimView
    else { return }

    let buttonFrame = buttonView.convert(buttonView.bounds, to: view)

    if overlayView.isExpanded {
      // Collapse the overlay.
      dimView.isHidden = true
      UIView.animate(
        withDuration: 0.32,
        delay: 0,
        usingSpringWithDamping: 0.88,
        initialSpringVelocity: 0
      ) {
        // Show button glass as overlay collapses.
        buttonView.isGlassHidden = false
      }
      overlayView.collapse(to: buttonFrame, animated: true)
    } else {
      // Expand the overlay.
      dimView.isHidden = false
      UIView.animate(
        withDuration: 0.38,
        delay: 0,
        usingSpringWithDamping: 0.86,
        initialSpringVelocity: 0
      ) {
        // Hide button glass so it appears embedded in overlay.
        buttonView.isGlassHidden = true
      }
      overlayView.expand(from: buttonFrame, in: self.view.bounds, animated: true)
    }
  }

  // Handles taps on the dim background to dismiss the overlay.
  @objc private func handleOverlayDismissTap(_ recognizer: UITapGestureRecognizer) {
    guard let overlayView = aiOverlayView, overlayView.isExpanded else { return }
    toggleAIOverlay()
  }

  // MARK: - Transition UI Control

  // Controls the visibility of the home button for hero transitions.
  // Uses transform to slide the button up (negative offset) since it is at top left.
  func setHomeButtonVisible(_ visible: Bool, animated: Bool) {
    guard let buttonView = homeButtonView else {
      return
    }
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
  // Uses transform to slide the palette up/down without affecting layout.
  func setToolPaletteVisible(_ visible: Bool, animated: Bool) {
    guard let paletteView = toolPaletteView else {
      return
    }
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
  // Uses transform to slide the toolbar up (negative offset) since it is at top right.
  func setEditingToolbarVisible(_ visible: Bool, animated: Bool) {
    guard let toolbarView = editingToolbarView else {
      return
    }
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

  // Controls the visibility of the AI button.
  // Sets visibility directly without animation.
  // Also collapses the AI overlay when hiding the button.
  func setAIButtonVisible(_ visible: Bool, animated: Bool) {
    guard let buttonView = aiButtonView else {
      return
    }
    // Collapse the AI overlay if it's expanded and the button is being hidden.
    if visible == false, let overlayView = aiOverlayView, overlayView.isExpanded {
      let buttonFrame = buttonView.convert(buttonView.bounds, to: view)
      overlayView.collapse(to: buttonFrame, animated: false)
      if let dimView = aiOverlayDimView {
        dimView.alpha = 0
        dimView.isHidden = true
      }
    }
    buttonView.alpha = visible ? 1 : 0
  }

  // Hides all UI elements for the hero transition animation.
  // Called at the start of the present animation.
  func hideAllUIForTransition() {
    setHomeButtonVisible(false, animated: false)
    setToolPaletteVisible(false, animated: false)
    setEditingToolbarVisible(false, animated: false)
    setAIButtonVisible(false, animated: false)
  }

  // Shows all UI elements after the hero transition completes.
  // Ensures everything is visible and in the correct position.
  func showAllUIAfterTransition(animated: Bool) {
    setHomeButtonVisible(true, animated: animated)
    setToolPaletteVisible(true, animated: animated)
    setEditingToolbarVisible(true, animated: animated)
    setAIButtonVisible(true, animated: animated)
  }

  // Captures the current editor content as a preview image.
  // Used during dismiss to update the card thumbnail.
  func capturePreviewImage(maxPixelDimension: CGFloat) -> UIImage? {
    return editorViewController?.capturePreviewImage(maxPixelDimension: maxPixelDimension)
  }

  @objc private func backButtonTapped() {
    prepareForExit()
    // Check for custom UIKit transition coordinator first.
    if let navController = navigationController as? EditorNavigationController,
      let coordinator = navController.notebookTransitionCoordinator {
      coordinator.dismiss()
      return
    }
    // Fallback to SwiftUI dismiss handler if provided.
    if let dismissHandler = dismissHandler {
      dismissHandler()
    } else {
      self.dismiss(animated: true)
    }
  }

  @objc private func handleWillResignActive() {
    self.viewModel.handleAppBackground()
  }

  // Captures a preview and releases the editor once per exit.
  private func prepareForExit() {
    guard hasPreparedForExit == false else {
      return
    }
    hasPreparedForExit = true
    let previewImage = editorViewController?.capturePreviewImage(
      maxPixelDimension: previewMaxPixelDimension)
    viewModel.releaseEditor(previewImage: previewImage)
  }

  func configure(documentHandle: DocumentHandle) {
    self.documentHandle = documentHandle
  }
}
// swiftlint:enable type_body_length

// MARK: - UIGestureRecognizerDelegate

extension EditorViewController: UIGestureRecognizerDelegate {
  // Allows the palette dismiss tap gesture to work simultaneously with other gestures.
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    // Allow simultaneous recognition for the palette dismiss tap.
    return gestureRecognizer == paletteDismissTapRecognizer
  }
}
