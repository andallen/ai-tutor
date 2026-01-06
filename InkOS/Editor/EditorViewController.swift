// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import SwiftUI
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
  // Tap gesture recognizer to dismiss the tool palette when tapping outside with a finger.
  private var paletteDismissTapRecognizer: UITapGestureRecognizer?

  // Stores the AI button at bottom right.
  private var aiButtonView: AIButtonView?
  // Stores the AI glass overlay panel.
  private var aiOverlayView: UIVisualEffectView?
  // Stores the chat input hosting controller embedded in the overlay.
  private var aiChatHostingController: UIHostingController<AIChatInputBar>?
  // Tracks whether the AI overlay is currently expanded.
  private var isAIOverlayExpanded = false
  // Text entered in the AI chat input bar.
  private var aiChatText: String = ""
  // Tap catcher view for dismissing the overlay.
  private var aiOverlayTapCatcher: UIView?

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
    self.configureAIOverlay()
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

  // Adds the AI button as a floating circular glass button at bottom right.
  // Position matches the Dashboard: 24pt from right edge, 24pt from bottom.
  private func configureAIButton() {
    let buttonView = AIButtonView()
    buttonView.translatesAutoresizingMaskIntoConstraints = false
    buttonView.tapped = { [weak self] in
      self?.toggleAIOverlay()
    }
    view.addSubview(buttonView)

    // Position at bottom right, aligned with safe area.
    buttonView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -24
    ).isActive = true
    buttonView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -24
    ).isActive = true
    aiButtonView = buttonView
  }

  // Configures the AI overlay panel that slides up from the bottom.
  // The overlay is a glass panel with a chat input bar at the bottom.
  private func configureAIOverlay() {
    let overlayWidth: CGFloat = 400
    let overlayHeight: CGFloat = 560
    let cornerRadius: CGFloat = 24

    // Create tap catcher to dismiss overlay when tapping outside.
    let tapCatcher = UIView()
    tapCatcher.backgroundColor = .clear
    tapCatcher.isHidden = true
    tapCatcher.translatesAutoresizingMaskIntoConstraints = false
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleAIOverlayDismissTap))
    tapCatcher.addGestureRecognizer(tapGesture)
    view.addSubview(tapCatcher)
    NSLayoutConstraint.activate([
      tapCatcher.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tapCatcher.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tapCatcher.topAnchor.constraint(equalTo: view.topAnchor),
      tapCatcher.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    aiOverlayTapCatcher = tapCatcher

    // Create the glass overlay view.
    let overlayView = UIVisualEffectView()
    overlayView.translatesAutoresizingMaskIntoConstraints = false
    overlayView.layer.cornerRadius = cornerRadius
    overlayView.layer.cornerCurve = .continuous
    overlayView.clipsToBounds = true

    // Apply glass effect on iOS 26+, blur fallback otherwise.
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = false
      overlayView.effect = effect
    } else {
      overlayView.effect = UIBlurEffect(style: .systemMaterial)
    }

    view.addSubview(overlayView)

    // Position overlay at bottom-right, trailing and bottom edges aligned with button edges.
    // This matches the Dashboard positioning where overlay's corner aligns with button's corner.
    NSLayoutConstraint.activate([
      overlayView.widthAnchor.constraint(equalToConstant: overlayWidth),
      overlayView.heightAnchor.constraint(equalToConstant: overlayHeight),
      overlayView.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -24
      ),
      overlayView.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -24
      )
    ])

    // Start hidden below screen.
    overlayView.transform = CGAffineTransform(translationX: 0, y: overlayHeight + 100)
    overlayView.isHidden = true
    aiOverlayView = overlayView

    // Add chat input bar at the bottom of the overlay.
    configureChatInputBar(in: overlayView, overlayHeight: overlayHeight)

    // Bring AI button to front so it's above the overlay.
    if let buttonView = aiButtonView {
      view.bringSubviewToFront(buttonView)
    }
  }

  // Embeds the SwiftUI chat input bar at the bottom of the overlay.
  private func configureChatInputBar(in overlayView: UIVisualEffectView, overlayHeight: CGFloat) {
    let chatBar = AIChatInputBar(
      text: Binding(
        get: { [weak self] in self?.aiChatText ?? "" },
        set: { [weak self] in self?.aiChatText = $0 }
      ),
      onSend: { [weak self] in
        self?.handleAIChatSend()
      }
    )

    let hostingController = UIHostingController(rootView: chatBar)
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    overlayView.contentView.addSubview(hostingController.view)

    // Pin chat bar to bottom with horizontal padding.
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(
        equalTo: overlayView.contentView.leadingAnchor,
        constant: 16
      ),
      hostingController.view.trailingAnchor.constraint(
        equalTo: overlayView.contentView.trailingAnchor,
        constant: -16
      ),
      hostingController.view.bottomAnchor.constraint(
        equalTo: overlayView.contentView.bottomAnchor,
        constant: -16
      ),
      hostingController.view.heightAnchor.constraint(equalToConstant: 52)
    ])

    aiChatHostingController = hostingController
  }

  // Toggles the AI overlay visibility with slide animation.
  private func toggleAIOverlay() {
    isAIOverlayExpanded.toggle()
    updateAIOverlayVisibility(animated: true)
  }

  // Updates the overlay and button state based on isAIOverlayExpanded.
  private func updateAIOverlayVisibility(animated: Bool) {
    guard let overlayView = aiOverlayView,
          let buttonView = aiButtonView,
          let tapCatcher = aiOverlayTapCatcher else { return }

    let overlayHeight: CGFloat = 560
    let slideDistance: CGFloat = overlayHeight + 100

    if isAIOverlayExpanded {
      overlayView.isHidden = false
      tapCatcher.isHidden = false
    }

    let animations = {
      // Slide overlay up/down.
      overlayView.transform = self.isAIOverlayExpanded
        ? .identity
        : CGAffineTransform(translationX: 0, y: slideDistance)

      // Yield the button (slides down when overlay is open).
      buttonView.isYielded = self.isAIOverlayExpanded
    }

    let completion: (Bool) -> Void = { _ in
      if !self.isAIOverlayExpanded {
        overlayView.isHidden = true
        tapCatcher.isHidden = true
      }
    }

    if animated {
      UIView.animate(
        withDuration: 0.35,
        delay: 0,
        usingSpringWithDamping: 0.85,
        initialSpringVelocity: 0,
        options: [],
        animations: animations,
        completion: completion
      )
    } else {
      animations()
      completion(true)
    }
  }

  // Handles tap outside the overlay to dismiss it.
  @objc private func handleAIOverlayDismissTap() {
    if isAIOverlayExpanded {
      isAIOverlayExpanded = false
      updateAIOverlayVisibility(animated: true)
    }
  }

  // Handles the send action from the AI chat input bar.
  private func handleAIChatSend() {
    let message = aiChatText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }
    // Clear the text field after sending.
    aiChatText = ""
  }

  // Controls the visibility of the AI button for hero transitions.
  // Uses transform to slide the button down (positive offset) since it is at bottom right.
  func setAIButtonVisible(_ visible: Bool, animated: Bool) {
    guard let buttonView = aiButtonView else {
      return
    }
    let offset: CGFloat = visible ? 0 : 80
    if animated {
      UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
        buttonView.transform = CGAffineTransform(translationX: 0, y: offset)
        buttonView.alpha = visible ? 1 : 0
      }
    } else {
      buttonView.transform = CGAffineTransform(translationX: 0, y: offset)
      buttonView.alpha = visible ? 1 : 0
    }

    // Collapse overlay when hiding button.
    if !visible && isAIOverlayExpanded {
      isAIOverlayExpanded = false
      updateAIOverlayVisibility(animated: false)
    }
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
