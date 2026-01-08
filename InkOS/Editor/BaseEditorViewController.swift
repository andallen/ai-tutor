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

  // AI button at bottom right.
  private var aiButtonView: AIButtonView?

  // AI overlay panel.
  private var aiOverlayView: UIVisualEffectView?

  // Chat input hosting controller in the overlay.
  private var aiChatHostingController: UIHostingController<AIChatInputBar>?

  // Tap catcher for dismissing the overlay.
  private var aiOverlayTapCatcher: UIView?

  // Tap gesture for dismissing the tool palette.
  private var paletteDismissTapRecognizer: UITapGestureRecognizer?

  // MARK: - State

  // Handler called when the editor requests dismissal.
  var dismissHandler: (() -> Void)?

  // Tracks whether the AI overlay is currently expanded.
  private var isAIOverlayExpanded = false

  // Text entered in the AI chat input bar.
  private var aiChatText: String = ""

  // Standard off-black accent color for UI elements.
  let offBlack = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)

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
    configureAIButton()
    configureAIOverlay()
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

  // Called when a message is sent from the AI chat.
  func handleAIChatSend(message: String) {
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

  // MARK: - AI Button

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

  // MARK: - AI Overlay

  private func configureAIOverlay() {
    let overlayWidth: CGFloat = 400
    let overlayHeight: CGFloat = 560
    let cornerRadius: CGFloat = 24

    // Create tap catcher to dismiss overlay when tapping outside.
    let tapCatcher = UIView()
    tapCatcher.backgroundColor = .clear
    tapCatcher.isHidden = true
    tapCatcher.translatesAutoresizingMaskIntoConstraints = false
    let tapGesture = UITapGestureRecognizer(
      target: self,
      action: #selector(handleAIOverlayDismissTap)
    )
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

    // Position overlay at bottom-right.
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
    configureChatInputBar(in: overlayView)

    // Bring AI button to front so it's above the overlay.
    if let buttonView = aiButtonView {
      view.bringSubviewToFront(buttonView)
    }
  }

  // Embeds the SwiftUI chat input bar at the bottom of the overlay.
  private func configureChatInputBar(in overlayView: UIVisualEffectView) {
    let chatBar = AIChatInputBar(
      text: Binding(
        get: { [weak self] in self?.aiChatText ?? "" },
        set: { [weak self] in self?.aiChatText = $0 }
      ),
      onSend: { [weak self] in
        guard let self else { return }
        let message = self.aiChatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        self.aiChatText = ""
        self.handleAIChatSend(message: message)
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
      // Use animated: false since we're inside an animation block.
      buttonView.setYielded(self.isAIOverlayExpanded, animated: false)
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
    guard let buttonView = aiButtonView else { return }
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
