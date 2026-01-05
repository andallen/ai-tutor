import UIKit

// Floating liquid glass overlay that expands from the AI button.
// Uses UIGlassEffect on iOS 26+ with UIBlurEffect fallback.
// Animates with spring physics for fluid motion.
final class AIOverlayView: UIView {

  // Size of the expanded overlay.
  private let expandedWidth: CGFloat = 360
  private let expandedHeight: CGFloat = 400
  // Corner radius for the rounded rectangle shape.
  private let overlayCornerRadius: CGFloat = 24
  // Size of the AI button (used for scale calculations).
  private let buttonSize: CGFloat = 48
  // Distance from the button center to the edge of the overlay.
  // Button radius (24) + small padding (12) = 36.
  private let buttonEdgeInset: CGFloat = 36

  // Glass container providing the liquid glass visual.
  private let glassView = UIVisualEffectView()
  // Tracks whether the overlay is currently expanded.
  private(set) var isExpanded = false

  // Original anchor point before expansion (restored on collapse).
  private let defaultAnchorPoint = CGPoint(x: 0.5, y: 0.5)

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
  func expand(from buttonFrame: CGRect, in hostBounds: CGRect, animated: Bool) {
    guard isExpanded == false else { return }
    isExpanded = true

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

    let animations = {
      self.transform = .identity
      self.alpha = 1
    }

    if animated {
      UIView.animate(
        withDuration: 0.38,
        delay: 0,
        usingSpringWithDamping: 0.86,
        initialSpringVelocity: 0,
        options: [],
        animations: animations
      )
    } else {
      animations()
    }
  }

  // Collapses the overlay back to the button frame with spring animation.
  func collapse(to buttonFrame: CGRect, animated: Bool) {
    guard isExpanded else { return }
    isExpanded = false

    let scaleX = buttonFrame.width / expandedWidth
    let scaleY = buttonFrame.height / expandedHeight

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
        withDuration: 0.32,
        delay: 0,
        usingSpringWithDamping: 0.88,
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
