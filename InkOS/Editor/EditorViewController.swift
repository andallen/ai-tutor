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
  // Tap gesture recognizer for dismissing the AI overlay.
  private var aiOverlayDismissTapRecognizer: UITapGestureRecognizer?

  // Three-state overlay model: collapsed → expandedAnchored → expandedCentered
  private enum AIOverlayState {
    case collapsed             // Overlay hidden, button visible
    case expandedAnchored      // Overlay visible at bottom-right, no keyboard
    case expandedCentered      // Overlay centered with keyboard visible
  }

  // Stores the AI button at bottom right.
  private var aiButtonView: AIButtonView?
  // Stores the AI glass overlay panel.
  private var aiOverlayView: UIVisualEffectView?
  // Stores the overlay content hosting controller embedded in the overlay.
  private var aiChatHostingController: UIHostingController<AIChatOverlayContent>?
  // Tracks the current state of the AI overlay.
  private var aiOverlayState: AIOverlayState = .collapsed
  // Text entered in the AI chat input bar.
  private var aiChatText: String = ""
  // Tap catcher view for dismissing the overlay.
  private var aiOverlayTapCatcher: UIView?
  // Tracks the current keyboard height for overlay positioning.
  private var keyboardHeight: CGFloat = 0
  // Constraint for overlay's trailing anchor (updated when keyboard is visible).
  private var aiOverlayTrailingConstraint: NSLayoutConstraint?
  // Constraint for overlay's centerX anchor (used when keyboard is visible).
  private var aiOverlayCenterXConstraint: NSLayoutConstraint?
  // Constraint for overlay's bottom anchor (updated when keyboard is visible).
  private var aiOverlayBottomConstraint: NSLayoutConstraint?
  // Fixed dimensions for the AI overlay.
  private let aiOverlayWidth: CGFloat = 400
  private let aiOverlayHeight: CGFloat = 560
  // Padding between overlay bottom and keyboard top.
  private let aiOverlayKeyboardPadding: CGFloat = 12

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
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleKeyboardWillShow(_:)),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleKeyboardWillHide(_:)),
      name: UIResponder.keyboardWillHideNotification,
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
    NotificationCenter.default.removeObserver(self)
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
  // Vertically aligned with the tool palette (pencil button).
  private func configureAIButton() {
    let buttonView = AIButtonView()
    buttonView.translatesAutoresizingMaskIntoConstraints = false
    buttonView.tapped = { [weak self] in
      self?.toggleAIOverlay()
    }
    view.addSubview(buttonView)

    // Position at bottom right, aligned with safe area.
    // Vertically aligned with tool palette (constant: 0 matches palette positioning).
    buttonView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -24
    ).isActive = true
    buttonView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: 0
    ).isActive = true
    aiButtonView = buttonView
  }

  // Configures the AI overlay panel that slides up from the bottom.
  // The overlay is a glass panel with a chat input bar at the bottom.
  // When the keyboard is visible, the overlay centers horizontally above the keyboard.
  private func configureAIOverlay() {
    let cornerRadius: CGFloat = 24

    // Create tap catcher to dismiss overlay when tapping outside.
    // Uses gesture delegate to ensure scrolls ending outside don't trigger dismissal.
    let tapCatcher = UIView()
    tapCatcher.backgroundColor = .clear
    tapCatcher.isHidden = true
    tapCatcher.translatesAutoresizingMaskIntoConstraints = false
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleAIOverlayDismissTap))
    tapGesture.delegate = self
    tapCatcher.addGestureRecognizer(tapGesture)
    aiOverlayDismissTapRecognizer = tapGesture
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

    // Create position constraints that can be toggled based on keyboard state.
    // Trailing constraint: used when keyboard is hidden (anchored to bottom-right).
    let trailingConstraint = overlayView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -24
    )
    // CenterX constraint: used when keyboard is visible (centered horizontally).
    let centerXConstraint = overlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    // Bottom constraint: adjusted based on keyboard height.
    // Default position (constant: 0) aligns with tool palette and AI button.
    let bottomConstraint = overlayView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: 0
    )

    // Store constraint references for keyboard handling.
    aiOverlayTrailingConstraint = trailingConstraint
    aiOverlayCenterXConstraint = centerXConstraint
    aiOverlayBottomConstraint = bottomConstraint

    // Initially use trailing constraint (keyboard hidden state).
    NSLayoutConstraint.activate([
      overlayView.widthAnchor.constraint(equalToConstant: aiOverlayWidth),
      overlayView.heightAnchor.constraint(equalToConstant: aiOverlayHeight),
      trailingConstraint,
      bottomConstraint
    ])

    // Start hidden off-screen to the right.
    overlayView.transform = CGAffineTransform(translationX: view.bounds.width, y: 0)
    overlayView.isHidden = true
    aiOverlayView = overlayView

    // Add chat input bar at the bottom of the overlay.
    configureChatInputBar(in: overlayView, overlayHeight: aiOverlayHeight)

    // Bring AI button to front so it's above the overlay.
    if let buttonView = aiButtonView {
      view.bringSubviewToFront(buttonView)
    }
  }

  // Embeds the SwiftUI overlay content (hamburger menu, chat history, chat input bar).
  private func configureChatInputBar(in overlayView: UIVisualEffectView, overlayHeight: CGFloat) {
    let overlayContent = AIChatOverlayContent(
      text: Binding(
        get: { [weak self] in self?.aiChatText ?? "" },
        set: { [weak self] in self?.aiChatText = $0 }
      ),
      location: .note,
      onSend: { [weak self] in
        self?.handleAIChatSend()
      }
    )

    let hostingController = UIHostingController(rootView: overlayContent)
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    overlayView.contentView.addSubview(hostingController.view)

    // Pin content to fill the entire overlay.
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(
        equalTo: overlayView.contentView.leadingAnchor
      ),
      hostingController.view.trailingAnchor.constraint(
        equalTo: overlayView.contentView.trailingAnchor
      ),
      hostingController.view.topAnchor.constraint(
        equalTo: overlayView.contentView.topAnchor
      ),
      hostingController.view.bottomAnchor.constraint(
        equalTo: overlayView.contentView.bottomAnchor
      )
    ])

    aiChatHostingController = hostingController
  }

  // Toggles the AI overlay visibility with slide animation.
  // Transitions from collapsed to expandedAnchored.
  private func toggleAIOverlay() {
    if aiOverlayState == .collapsed {
      aiOverlayState = .expandedAnchored
      updateAIOverlayVisibility(animated: true)
    }
  }

  // Updates the overlay and button state based on aiOverlayState.
  private func updateAIOverlayVisibility(animated: Bool) {
    guard let overlayView = aiOverlayView,
          let buttonView = aiButtonView,
          let tapCatcher = aiOverlayTapCatcher else { return }

    // Slide distance is screen width (slides off to the right).
    let slideDistance: CGFloat = view.bounds.width
    let isExpanded = aiOverlayState != .collapsed

    if isExpanded {
      overlayView.isHidden = false
      tapCatcher.isHidden = false
    } else {
      // Reset to default position when collapsing.
      keyboardHeight = 0
      aiOverlayCenterXConstraint?.isActive = false
      aiOverlayTrailingConstraint?.isActive = true
      aiOverlayBottomConstraint?.constant = 0
    }

    let animations = {
      // Slide overlay left/right (from right side of screen).
      overlayView.transform = isExpanded
        ? .identity
        : CGAffineTransform(translationX: slideDistance, y: 0)

      // Animate button yield/return together with overlay to prevent visual glitches.
      buttonView.setYielded(isExpanded, animated: true)

      // Apply constraint changes.
      if !isExpanded {
        self.view.layoutIfNeeded()
      }
    }

    let completion: (Bool) -> Void = { _ in
      if !isExpanded {
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

  // Handles tap outside the overlay to transition state backward.
  // expandedCentered → expandedAnchored (dismiss keyboard, keep overlay)
  // expandedAnchored → collapsed (fully collapse overlay)
  @objc private func handleAIOverlayDismissTap() {
    switch aiOverlayState {
    case .collapsed:
      // Already collapsed, no action needed.
      break
    case .expandedAnchored:
      // Transition to collapsed.
      aiOverlayView?.endEditing(true)
      aiOverlayState = .collapsed
      updateAIOverlayVisibility(animated: true)
    case .expandedCentered:
      // Dismiss keyboard first (will transition to expandedAnchored via keyboard hide handler).
      aiOverlayView?.endEditing(true)
    }
  }

  // Handles the send action from the AI chat input bar.
  private func handleAIChatSend() {
    let message = aiChatText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }
    // Clear the text field after sending.
    aiChatText = ""
  }

  // Handles keyboard appearance by centering overlay horizontally above keyboard.
  @objc private func handleKeyboardWillShow(_ notification: Notification) {
    guard aiOverlayState != .collapsed else { return }
    guard let userInfo = notification.userInfo,
          let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
          let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
          let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    keyboardHeight = keyboardFrame.height

    // Transition to centered state when keyboard appears and overlay is expanded.
    if aiOverlayState == .expandedAnchored {
      aiOverlayState = .expandedCentered
    }

    // Switch from trailing to centerX constraint for horizontal centering.
    aiOverlayTrailingConstraint?.isActive = false
    aiOverlayCenterXConstraint?.isActive = true

    // Update bottom constraint to position overlay above keyboard.
    // The overlay bottom should be keyboardHeight + padding from the view bottom.
    let safeAreaBottom = view.safeAreaInsets.bottom
    aiOverlayBottomConstraint?.constant = -(keyboardHeight - safeAreaBottom + aiOverlayKeyboardPadding)

    let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)
    UIView.animate(withDuration: duration, delay: 0, options: animationOptions) {
      self.view.layoutIfNeeded()
    }
  }

  // Handles keyboard dismissal by returning overlay to bottom-right position.
  @objc private func handleKeyboardWillHide(_ notification: Notification) {
    guard aiOverlayState != .collapsed else { return }
    guard let userInfo = notification.userInfo,
          let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
          let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    keyboardHeight = 0

    // Transition back to anchored state when keyboard hides (but keep overlay expanded).
    if aiOverlayState == .expandedCentered {
      aiOverlayState = .expandedAnchored
    }

    // Switch from centerX back to trailing constraint.
    aiOverlayCenterXConstraint?.isActive = false
    aiOverlayTrailingConstraint?.isActive = true

    // Reset bottom constraint to original position (aligned with tool palette).
    aiOverlayBottomConstraint?.constant = 0

    let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)
    UIView.animate(withDuration: duration, delay: 0, options: animationOptions) {
      self.view.layoutIfNeeded()
    }
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
    if !visible && aiOverlayState != .collapsed {
      aiOverlayState = .collapsed
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

  // Prevents the AI overlay dismiss tap from triggering when touch is inside the overlay.
  // This ensures that scrolling in the chat bar doesn't accidentally dismiss the overlay
  // when the scroll gesture ends outside the overlay bounds.
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldReceive touch: UITouch
  ) -> Bool {
    // Only apply special handling to the AI overlay dismiss tap.
    guard gestureRecognizer == aiOverlayDismissTapRecognizer else {
      return true
    }

    // If the touch is inside the overlay, don't recognize the tap.
    guard let overlayView = aiOverlayView else {
      return true
    }

    let touchLocation = touch.location(in: view)
    let overlayFrame = overlayView.frame

    // Don't recognize if touch is inside the overlay.
    if overlayFrame.contains(touchLocation) {
      return false
    }

    return true
  }
}
