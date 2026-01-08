//
// AIOverlayCoordinator.swift
// InkOS
//
// Manages the AI button and overlay lifecycle for any view controller.
// Handles button placement, overlay expand/collapse animations, keyboard handling,
// and message sending through ChatService.
//

import SwiftUI
import UIKit

// MARK: - AIOverlayCoordinator

// Manages the AI button and overlay for any view controller.
// The coordinator owns the button, overlay, and tap catcher views.
// Context is queried dynamically from the context provider when needed.
final class AIOverlayCoordinator {

  // MARK: - Configuration

  // Configuration for button and overlay positioning.
  struct Configuration {
    // Button insets from safe area.
    let buttonTrailingInset: CGFloat
    let buttonBottomInset: CGFloat

    // Overlay dimensions.
    let overlayWidth: CGFloat
    let overlayHeight: CGFloat
    let overlayCornerRadius: CGFloat

    // Default configuration for most view controllers.
    static let `default` = Configuration(
      buttonTrailingInset: 24,
      buttonBottomInset: 24,
      overlayWidth: 468,
      overlayHeight: 560,
      overlayCornerRadius: 24
    )

    // Dashboard-specific configuration (same dimensions, may diverge later).
    static let dashboard = Configuration(
      buttonTrailingInset: 24,
      buttonBottomInset: 24,
      overlayWidth: 468,
      overlayHeight: 560,
      overlayCornerRadius: 24
    )
  }

  // MARK: - Properties

  // The view controller this coordinator is attached to.
  private weak var viewController: UIViewController?

  // Context provider (usually the same as viewController).
  private weak var contextProvider: AIOverlayContextProvider?

  // Optional delegate for state change notifications.
  weak var delegate: AIOverlayCoordinatorDelegate?

  // Configuration for layout.
  private let configuration: Configuration

  // MARK: - UI Components (owned by coordinator)

  private var aiButtonView: AIButtonView?
  private var aiOverlayView: UIVisualEffectView?
  private var tapCatcher: UIView?
  private var overlayHostingController: UIHostingController<AIChatOverlayContent>?

  // MARK: - State

  // Whether the overlay is currently expanded.
  private(set) var isExpanded: Bool = false

  // Text entered in the chat overlay.
  private var chatText: String = ""

  // Keyboard height for overlay repositioning.
  private var keyboardHeight: CGFloat = 0

  // Bottom constraint for keyboard-aware positioning.
  private var overlayBottomConstraint: NSLayoutConstraint?

  // MARK: - Initialization

  init(configuration: Configuration = .default) {
    self.configuration = configuration
  }

  deinit {
    removeKeyboardObservers()
  }

  // MARK: - Attachment / Detachment

  // Attaches the coordinator to a view controller.
  // Sets up the button and overlay views.
  func attach(to viewController: UIViewController, contextProvider: AIOverlayContextProvider) {
    self.viewController = viewController
    self.contextProvider = contextProvider

    setupTapCatcher()
    setupOverlay()
    setupButton()
    setupKeyboardObservers()
  }

  // Detaches and cleans up all views.
  func detach() {
    removeKeyboardObservers()

    overlayHostingController?.willMove(toParent: nil)
    overlayHostingController?.view.removeFromSuperview()
    overlayHostingController?.removeFromParent()
    overlayHostingController = nil

    tapCatcher?.removeFromSuperview()
    tapCatcher = nil

    aiOverlayView?.removeFromSuperview()
    aiOverlayView = nil

    aiButtonView?.removeFromSuperview()
    aiButtonView = nil

    viewController = nil
    contextProvider = nil
  }

  // MARK: - Public API

  // Shows the AI button (used during transitions).
  func showButton(animated: Bool = true) {
    guard let button = aiButtonView else { return }

    if animated {
      UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
        button.transform = .identity
        button.alpha = 1
      }
    } else {
      button.transform = .identity
      button.alpha = 1
    }
  }

  // Hides the AI button (used during transitions).
  // Also collapses the overlay if expanded.
  func hideButton(animated: Bool = true) {
    guard let button = aiButtonView else { return }

    // Collapse overlay first if expanded.
    if isExpanded {
      collapseOverlay(animated: false)
    }

    let offset: CGFloat = 80
    if animated {
      UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
        button.transform = CGAffineTransform(translationX: 0, y: offset)
        button.alpha = 0
      }
    } else {
      button.transform = CGAffineTransform(translationX: 0, y: offset)
      button.alpha = 0
    }
  }

  // Expands the overlay programmatically.
  func expandOverlay(animated: Bool = true) {
    guard !isExpanded else { return }
    toggleOverlay(animated: animated)
  }

  // Collapses the overlay programmatically.
  func collapseOverlay(animated: Bool = true) {
    guard isExpanded else { return }
    toggleOverlay(animated: animated)
  }

  // MARK: - Private Setup

  private func setupButton() {
    guard let vc = viewController else { return }

    let button = AIButtonView()
    button.translatesAutoresizingMaskIntoConstraints = false
    button.tapped = { [weak self] in
      self?.toggleOverlay(animated: true)
    }

    vc.view.addSubview(button)

    NSLayoutConstraint.activate([
      button.trailingAnchor.constraint(
        equalTo: vc.view.safeAreaLayoutGuide.trailingAnchor,
        constant: -configuration.buttonTrailingInset
      ),
      button.bottomAnchor.constraint(
        equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor,
        constant: -configuration.buttonBottomInset
      )
    ])

    aiButtonView = button
  }

  private func setupTapCatcher() {
    guard let vc = viewController else { return }

    let catcher = UIView()
    catcher.backgroundColor = .clear
    catcher.isHidden = true
    catcher.translatesAutoresizingMaskIntoConstraints = false

    let tapGesture = UITapGestureRecognizer(
      target: self,
      action: #selector(handleDismissTap)
    )
    catcher.addGestureRecognizer(tapGesture)

    vc.view.addSubview(catcher)
    NSLayoutConstraint.activate([
      catcher.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
      catcher.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
      catcher.topAnchor.constraint(equalTo: vc.view.topAnchor),
      catcher.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
    ])

    tapCatcher = catcher
  }

  private func setupOverlay() {
    guard let vc = viewController, let provider = contextProvider else { return }

    // Create the glass overlay view.
    let overlayView = UIVisualEffectView()
    overlayView.translatesAutoresizingMaskIntoConstraints = false
    overlayView.layer.cornerRadius = configuration.overlayCornerRadius
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

    vc.view.addSubview(overlayView)

    // Position overlay at bottom-right.
    let bottomConstraint = overlayView.bottomAnchor.constraint(
      equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor,
      constant: -configuration.buttonBottomInset
    )

    NSLayoutConstraint.activate([
      overlayView.widthAnchor.constraint(equalToConstant: configuration.overlayWidth),
      overlayView.heightAnchor.constraint(equalToConstant: configuration.overlayHeight),
      overlayView.trailingAnchor.constraint(
        equalTo: vc.view.safeAreaLayoutGuide.trailingAnchor,
        constant: -configuration.buttonTrailingInset
      ),
      bottomConstraint
    ])

    overlayBottomConstraint = bottomConstraint

    // Start hidden below screen.
    let slideDistance = configuration.overlayHeight + 100
    overlayView.transform = CGAffineTransform(translationX: 0, y: slideDistance)
    overlayView.isHidden = true

    aiOverlayView = overlayView

    // Embed the full AIChatOverlayContent SwiftUI view.
    embedOverlayContent(in: overlayView, location: provider.overlayLocation)
  }

  private func embedOverlayContent(in overlayView: UIVisualEffectView, location: AIOverlayLocation) {
    guard let vc = viewController else { return }

    let content = AIChatOverlayContent(
      text: Binding(
        get: { [weak self] in self?.chatText ?? "" },
        set: { [weak self] in self?.chatText = $0 }
      ),
      location: location,
      onSend: { [weak self] in
        self?.handleSend()
      }
    )

    let hosting = UIHostingController(rootView: content)
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false

    vc.addChild(hosting)
    overlayView.contentView.addSubview(hosting.view)
    hosting.didMove(toParent: vc)

    // Pin hosting view to overlay content.
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: overlayView.contentView.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: overlayView.contentView.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: overlayView.contentView.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: overlayView.contentView.bottomAnchor)
    ])

    overlayHostingController = hosting
  }

  // MARK: - Toggle Logic

  private func toggleOverlay(animated: Bool) {
    isExpanded.toggle()

    if isExpanded {
      delegate?.overlayWillExpand(self)
    }

    updateOverlayVisibility(animated: animated)

    if !isExpanded {
      delegate?.overlayDidCollapse(self)
    }
  }

  private func updateOverlayVisibility(animated: Bool) {
    guard let overlay = aiOverlayView,
          let button = aiButtonView,
          let catcher = tapCatcher else { return }

    let slideDistance = configuration.overlayHeight + 100

    if isExpanded {
      overlay.isHidden = false
      catcher.isHidden = false
    }

    let animations = {
      // Slide overlay up/down.
      overlay.transform = self.isExpanded
        ? .identity
        : CGAffineTransform(translationX: 0, y: slideDistance)

      // Yield the button (slides off when overlay is open).
      button.setYielded(self.isExpanded, animated: false)
    }

    let completion: (Bool) -> Void = { _ in
      if !self.isExpanded {
        overlay.isHidden = true
        catcher.isHidden = true
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

  // MARK: - Message Handling

  private func handleSend() {
    guard let provider = contextProvider else { return }

    let message = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }

    chatText = ""

    // Query context from provider at send time (will be used for ChatService).
    _ = provider.currentNoteID
    _ = provider.currentFolderID

    // Notify delegate.
    delegate?.overlay(self, didSendMessage: message)

    // TODO: Integrate with ChatService for actual message sending.
    // Task {
    //   do {
    //     let _ = try await ChatService.shared.sendMessage(
    //       text: message,
    //       attachment: nil,
    //       scope: .auto,
    //       conversationID: nil,
    //       currentNoteID: noteID,
    //       currentFolderID: folderID
    //     )
    //   } catch {
    //     // Handle error.
    //   }
    // }
  }

  // MARK: - Actions

  @objc private func handleDismissTap() {
    if isExpanded {
      toggleOverlay(animated: true)
    }
  }

  // MARK: - Keyboard Handling

  private func setupKeyboardObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow(_:)),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide(_:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  private func removeKeyboardObservers() {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func keyboardWillShow(_ notification: Notification) {
    guard isExpanded,
          let userInfo = notification.userInfo,
          let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
          let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
          let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    keyboardHeight = keyboardFrame.height

    // Move overlay above keyboard.
    let keyboardPadding: CGFloat = 12
    overlayBottomConstraint?.constant = -(keyboardHeight + keyboardPadding)

    let options = UIView.AnimationOptions(rawValue: curveValue << 16)
    UIView.animate(withDuration: duration, delay: 0, options: options) {
      self.viewController?.view.layoutIfNeeded()
    }
  }

  @objc private func keyboardWillHide(_ notification: Notification) {
    guard isExpanded,
          let userInfo = notification.userInfo,
          let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
          let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    keyboardHeight = 0

    // Return overlay to original position.
    overlayBottomConstraint?.constant = -configuration.buttonBottomInset

    let options = UIView.AnimationOptions(rawValue: curveValue << 16)
    UIView.animate(withDuration: duration, delay: 0, options: options) {
      self.viewController?.view.layoutIfNeeded()
    }
  }
}
