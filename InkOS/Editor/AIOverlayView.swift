import SwiftUI
import UIKit

// Floating liquid glass overlay that expands from the AI button.
// Uses UIGlassEffect on iOS 26+ with UIBlurEffect fallback.
// Animates with spring physics for fluid motion.
final class AIOverlayView: UIView {

  // Size of the expanded overlay.
  private let expandedWidth: CGFloat = 468
  private let expandedHeight: CGFloat = 520
  // Corner radius for the rounded rectangle shape.
  private let overlayCornerRadius: CGFloat = 24
  // Size of the AI button circle (used for scale calculations).
  private let buttonSize: CGFloat = 36
  // Distance from the button center to the edge of the overlay.
  // Button radius (18) + small padding (12) = 30.
  private let buttonEdgeInset: CGFloat = 30
  // Padding between overlay bottom and keyboard top.
  private let keyboardPadding: CGFloat = 12

  // Glass container providing the liquid glass visual.
  private let glassView = UIVisualEffectView()
  // Tracks whether the overlay is currently expanded.
  private(set) var isExpanded = false

  // Original anchor point before expansion (restored on collapse).
  private let defaultAnchorPoint = CGPoint(x: 0.5, y: 0.5)

  // Stores the current keyboard height when visible.
  private var keyboardHeight: CGFloat = 0
  // Stores the host bounds for positioning calculations.
  private var currentHostBounds: CGRect = .zero
  // Stores the button frame for collapse animations.
  private var currentButtonFrame: CGRect = .zero

  // Chat input bar hosted view controller.
  private var chatInputHostingController: UIHostingController<AIChatInputBar>?
  // The chat input view model for managing text state.
  private let chatInputViewModel = AIChatInputViewModel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureView()
  }

  // Sets up the view hierarchy and glass effect.
  private func configureView() {
    backgroundColor = UIColor.clear
    isUserInteractionEnabled = true
    isHidden = true
    alpha = 0

    // Disable any shadow on this view and clip to bounds.
    layer.shadowOpacity = 0
    layer.shadowRadius = 0
    layer.shadowColor = nil
    layer.masksToBounds = true
    clipsToBounds = true

    configureGlassView()
    addSubview(glassView)

    // Pin glass view to fill the overlay bounds.
    glassView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
      glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
      glassView.topAnchor.constraint(equalTo: topAnchor),
      glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    configureChatInputBar()
    configureKeyboardObservers()
  }

  // Embeds the SwiftUI chat input bar at the bottom of the overlay.
  private func configureChatInputBar() {
    let chatBar = AIChatInputBar(
      text: Binding(
        get: { [weak self] in self?.chatInputViewModel.text ?? "" },
        set: { [weak self] in self?.chatInputViewModel.text = $0 }
      ),
      onSend: { [weak self] in
        self?.handleSend()
      }
    )

    let hostingController = UIHostingController(rootView: chatBar)
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    // Allow the hosting controller to size based on SwiftUI content.
    hostingController.sizingOptions = .intrinsicContentSize
    glassView.contentView.addSubview(hostingController.view)

    // Pin chat bar to bottom with horizontal padding.
    // No height constraint - the SwiftUI view determines its own height.
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(
        equalTo: glassView.contentView.leadingAnchor,
        constant: 12
      ),
      hostingController.view.trailingAnchor.constraint(
        equalTo: glassView.contentView.trailingAnchor,
        constant: -12
      ),
      hostingController.view.bottomAnchor.constraint(
        equalTo: glassView.contentView.bottomAnchor,
        constant: -12
      )
    ])

    chatInputHostingController = hostingController
  }

  // Registers for keyboard show/hide notifications.
  private func configureKeyboardObservers() {
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

  // Handles keyboard appearance by sliding the overlay above the keyboard.
  @objc private func keyboardWillShow(_ notification: Notification) {
    guard isExpanded else { return }
    guard let userInfo = notification.userInfo,
      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
      let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    keyboardHeight = keyboardFrame.height
    let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)
    animateToKeyboardPosition(duration: duration, options: animationOptions)
  }

  // Handles keyboard dismissal by returning the overlay to its original position.
  @objc private func keyboardWillHide(_ notification: Notification) {
    guard isExpanded else { return }
    guard let userInfo = notification.userInfo,
      let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
      let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    keyboardHeight = 0
    let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)
    animateToButtonPosition(duration: duration, options: animationOptions)
  }

  // Animates the overlay to be centered horizontally and positioned above the keyboard.
  private func animateToKeyboardPosition(duration: TimeInterval, options: UIView.AnimationOptions) {
    // Compensate for anchor point change to prevent visual jump.
    // Calculate where the view currently is in absolute terms.
    let currentAnchor = layer.anchorPoint
    let currentPosition = layer.position
    let currentOriginX = currentPosition.x - bounds.width * currentAnchor.x
    let currentOriginY = currentPosition.y - bounds.height * currentAnchor.y

    // Change anchor to center and adjust position to keep view in same place.
    layer.anchorPoint = defaultAnchorPoint
    layer.position = CGPoint(
      x: currentOriginX + bounds.width * defaultAnchorPoint.x,
      y: currentOriginY + bounds.height * defaultAnchorPoint.y
    )

    // Calculate centered position above keyboard.
    let centerX = currentHostBounds.width / 2
    let bottomY = currentHostBounds.height - keyboardHeight - keyboardPadding
    let targetY = bottomY - expandedHeight / 2

    UIView.animate(withDuration: duration, delay: 0, options: options) {
      self.layer.position = CGPoint(x: centerX, y: targetY)
      self.transform = .identity
    }
  }

  // Animates the overlay back to its original position near the button.
  private func animateToButtonPosition(duration: TimeInterval, options: UIView.AnimationOptions) {
    let targetFrame = expandedFrame(for: currentButtonFrame, in: currentHostBounds)

    // Calculate anchor point for button-relative positioning.
    let anchorX = (currentButtonFrame.midX - targetFrame.minX) / targetFrame.width
    let anchorY = (currentButtonFrame.midY - targetFrame.minY) / targetFrame.height

    // Compensate for anchor point change to prevent visual jump.
    let currentAnchor = layer.anchorPoint
    let currentPosition = layer.position
    let currentOriginX = currentPosition.x - bounds.width * currentAnchor.x
    let currentOriginY = currentPosition.y - bounds.height * currentAnchor.y

    // Change anchor and adjust position to keep view in same place.
    layer.anchorPoint = CGPoint(x: anchorX, y: anchorY)
    layer.position = CGPoint(
      x: currentOriginX + bounds.width * anchorX,
      y: currentOriginY + bounds.height * anchorY
    )

    // Calculate target position.
    let newX = targetFrame.minX + anchorX * targetFrame.width
    let newY = targetFrame.minY + anchorY * targetFrame.height

    UIView.animate(withDuration: duration, delay: 0, options: options) {
      self.layer.position = CGPoint(x: newX, y: newY)
      self.transform = .identity
    }
  }

  // Called when the send button is tapped.
  private func handleSend() {
    let message = chatInputViewModel.text.trimmingCharacters(in: .whitespaces)
    guard message.isEmpty == false else { return }
    // TODO: Send message to AI service.
    chatInputViewModel.text = ""
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // Configures the glass material effect.
  private func configureGlassView() {
    glassView.layer.cornerRadius = overlayCornerRadius
    glassView.layer.cornerCurve = .continuous
    glassView.clipsToBounds = true
    glassView.layer.masksToBounds = true
    // Disable any shadow on the glass view.
    glassView.layer.shadowOpacity = 0
    glassView.layer.shadowRadius = 0
    glassView.layer.shadowColor = nil

    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = false
      glassView.effect = effect
    } else {
      glassView.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  // Calculates the expanded frame so the button sits at the bottom-right corner.
  func expandedFrame(for buttonFrame: CGRect, in bounds: CGRect) -> CGRect {
    // Position overlay so the button center is buttonEdgeInset from the right and bottom edges.
    // Overlay right edge = button center X + buttonEdgeInset.
    // Overlay bottom edge = button center Y + buttonEdgeInset.
    let overlayRight = buttonFrame.midX + buttonEdgeInset
    let overlayBottom = buttonFrame.midY + buttonEdgeInset
    let x = overlayRight - expandedWidth
    let y = overlayBottom - expandedHeight

    // Clamp to keep overlay within screen bounds with margin.
    let margin: CGFloat = 16
    let clampedX = max(margin, min(x, bounds.width - expandedWidth - margin))
    let clampedY = max(margin, min(y, bounds.height - expandedHeight - margin))

    return CGRect(x: clampedX, y: clampedY, width: expandedWidth, height: expandedHeight)
  }

  // Expands the overlay from the button frame with spring animation.
  // The onWillAnimate closure fires right before the animation starts, after setup completes.
  func expand(
    from buttonFrame: CGRect,
    in hostBounds: CGRect,
    animated: Bool,
    onWillAnimate: (() -> Void)? = nil
  ) {
    guard isExpanded == false else { return }
    isExpanded = true

    // Store frames for keyboard positioning later.
    currentButtonFrame = buttonFrame
    currentHostBounds = hostBounds

    let targetFrame = expandedFrame(for: buttonFrame, in: hostBounds)

    // Calculate scale factors to shrink from expanded size to button size.
    let scaleX = buttonFrame.width / expandedWidth
    let scaleY = buttonFrame.height / expandedHeight

    // Set initial frame to target (expanded) position.
    frame = targetFrame

    // Calculate anchor point so scaling originates from button position.
    // Button should be at bottom-right of expanded overlay.
    let anchorX = (buttonFrame.midX - targetFrame.minX) / targetFrame.width
    let anchorY = (buttonFrame.midY - targetFrame.minY) / targetFrame.height
    layer.anchorPoint = CGPoint(x: anchorX, y: anchorY)

    // Recalculate position after anchor point change (anchor affects positioning).
    let newX = targetFrame.minX + anchorX * targetFrame.width
    let newY = targetFrame.minY + anchorY * targetFrame.height
    layer.position = CGPoint(x: newX, y: newY)

    // Start scaled down at button size.
    transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    isHidden = false
    alpha = 0

    // Trigger companion animations right before this animation starts.
    onWillAnimate?()

    if animated {
      // Fade in quickly so overlay is visible immediately.
      UIView.animate(withDuration: 0.08, delay: 0, options: .curveEaseOut) {
        self.alpha = 1
      }
      // Fast spring expansion.
      UIView.animate(
        withDuration: 0.22,
        delay: 0,
        usingSpringWithDamping: 0.82,
        initialSpringVelocity: 0.5,
        options: []
      ) {
        self.transform = .identity
      }
    } else {
      self.transform = .identity
      self.alpha = 1
    }
  }

  // Collapses the overlay back to the button frame with spring animation.
  // The onWillAnimate closure fires right before the animation starts.
  func collapse(
    to buttonFrame: CGRect,
    animated: Bool,
    onWillAnimate: (() -> Void)? = nil
  ) {
    guard isExpanded else { return }
    isExpanded = false

    // Dismiss keyboard before collapsing.
    endEditing(true)
    keyboardHeight = 0

    let scaleX = buttonFrame.width / expandedWidth
    let scaleY = buttonFrame.height / expandedHeight

    // Trigger companion animations right before this animation starts.
    onWillAnimate?()

    let animations = {
      self.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
      // Don't fade alpha during scale - let the scale animation be visible.
    }

    let completion: (Bool) -> Void = { _ in
      self.isHidden = true
      self.alpha = 0
      self.transform = .identity
      self.layer.anchorPoint = self.defaultAnchorPoint
    }

    if animated {
      UIView.animate(
        withDuration: 0.42,
        delay: 0,
        usingSpringWithDamping: 0.90,
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
}
