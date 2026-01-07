// PDFEditorViewController.swift
// UIViewController hosting the MyScript canvas for PDF annotation.
// Reuses existing InputViewController for pen/touch input and rendering.

import Combine
import SwiftUI
import UIKit

// View controller for annotating PDF documents.
// Hosts the MyScript canvas with PDF pages rendered as background.
final class PDFEditorViewController: UIViewController {

  // MARK: - Properties

  // Container view that fills the entire screen, ignoring safe areas.
  private var editorContainerView: UIView!
  private let viewModel: PDFEditorViewModel
  // Named to avoid conflict with UIViewController.inputViewController.
  private var editorInputVC: InputViewController?
  private var inputVM: InputViewModel?
  private var toolPalette: ToolPaletteView?
  private var cancellables: Set<AnyCancellable> = []
  private let offBlack = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
  // Provides the default Raw Content configuration for recognition.
  private let configurationProvider = DefaultRawContentConfigurationProvider()
  // Applies configuration to the engine.
  private let configurationApplier = RawContentConfigurationApplier()
  // Tracks the current pen color hex string.
  private var selectedPenColorHex = "#000000"
  // Tracks the current highlighter color hex string.
  private var selectedHighlighterColorHex = "#FFF176"
  // Tracks the current pen width in mm.
  private var selectedPenWidth: CGFloat = 0.65
  // Tracks the current highlighter width in mm.
  private var selectedHighlighterWidth: CGFloat = 5.0
  // Tracks the currently selected tool.
  private var selectedTool: ToolPaletteView.ToolSelection = .pen
  // Stores the editing toolbar for undo/redo/clear actions.
  private var editingToolbarView: EditingToolbarView?
  // Tap gesture recognizer to dismiss the tool palette when tapping outside with a finger.
  private var paletteDismissTapRecognizer: UITapGestureRecognizer?
  // Tap gesture recognizer for dismissing the AI overlay.
  private var aiOverlayDismissTapRecognizer: UITapGestureRecognizer?
  // Stores the home button at top left.
  private var homeButtonView: HomeButtonView?

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
  var dismissHandler: (() -> Void)?

  // MARK: - Initialization

  init(viewModel: PDFEditorViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func loadView() {
    super.loadView()
    // Creates the editor container view programmatically to fill entire screen.
    // This ensures content extends under the home indicator like the normal note view.
    let containerView = UIView(frame: UIScreen.main.bounds)
    containerView.backgroundColor = UIColor.white
    containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.view.addSubview(containerView)
    self.editorContainerView = containerView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    hideNavigationBar()
    setupInputViewController()
    configureHomeButton()
    configureToolPalette()
    configurePaletteDismissTap()
    configureEditingToolbar()
    configureAIButton()
    configureAIOverlay()
    configureKeyboardObservers()
    loadDocument()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // Registers for keyboard show/hide notifications.
  private func configureKeyboardObservers() {
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

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    inputVM?.setEditorViewSize(size: view.bounds.size)
  }

  // MARK: - Setup

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

  private func configureToolPalette() {
    let palette = ToolPaletteView(accentColor: offBlack)
    palette.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(palette)

    // Position at bottom of screen spanning full width with margins.
    // Matches the layout used in EditorViewController.
    palette.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    palette.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    palette.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: 0
    ).isActive = true

    // Wire up tool selection.
    palette.selectionChanged = { [weak self] tool in
      self?.handleToolSelection(tool)
    }

    // Wire up color selection.
    palette.colorSelectionChanged = { [weak self] tool, hex in
      self?.handleColorSelection(tool: tool, hex: hex)
    }

    // Wire up thickness changes.
    palette.thicknessChanged = { [weak self] tool, width in
      self?.handleThicknessChange(tool: tool, width: width)
    }

    self.toolPalette = palette
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
    guard let palette = toolPalette, palette.isExpanded else {
      return
    }
    // Only collapse if the tap is outside the palette.
    let location = recognizer.location(in: view)
    if palette.containsInteraction(at: location, in: view) == false {
      palette.setToolbarVisible(false, animated: true)
    }
  }

  // Adds the editing toolbar as a floating view at top right.
  // Positioned directly in the view hierarchy for full control over rendering.
  private func configureEditingToolbar() {
    let toolbarView = EditingToolbarView(accentColor: offBlack)
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.undoTapped = { [weak self] in
      self?.inputVM?.undo()
    }
    toolbarView.redoTapped = { [weak self] in
      self?.inputVM?.redo()
    }
    toolbarView.clearTapped = { [weak self] in
      self?.inputVM?.clear()
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
    configureChatInputBar(in: overlayView)

    // Bring AI button to front so it's above the overlay.
    if let buttonView = aiButtonView {
      view.bringSubviewToFront(buttonView)
    }
  }

  // Embeds the SwiftUI overlay content (hamburger menu, chat history, chat input bar).
  private func configureChatInputBar(in overlayView: UIVisualEffectView) {
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

  // MARK: - Actions

  @objc private func backButtonTapped() {
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
}

// MARK: - Tool Handling

extension PDFEditorViewController {

  fileprivate func handleToolSelection(_ tool: ToolPaletteView.ToolSelection) {
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

  // Handles color selection changes from the tool palette.
  fileprivate func handleColorSelection(tool: ToolPaletteView.ToolSelection, hex: String) {
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

  // Handles thickness changes from the tool palette.
  fileprivate func handleThicknessChange(tool: ToolPaletteView.ToolSelection, width: CGFloat) {
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

  fileprivate func showError(_ message: String) {
    let alert = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(
      UIAlertAction(title: "OK", style: .default) { [weak self] _ in
        self?.backButtonTapped()
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

// MARK: - UIGestureRecognizerDelegate

extension PDFEditorViewController: UIGestureRecognizerDelegate {
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
