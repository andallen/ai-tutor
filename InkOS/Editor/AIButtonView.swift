import UIKit

// Circular glass button with a black circle icon in the center.
// Matches the glass styling used by HomeButtonView for visual consistency.
// Slides down off-screen when yielded to make room for the AI overlay.
final class AIButtonView: UIView {
  // Notifies the host when the button is tapped.
  var tapped: (() -> Void)?

  // Tracks whether the button is currently yielded (slid off-screen).
  // Use setYielded(_:animated:) to change this value with proper animation coordination.
  private(set) var isYielded: Bool = false

  // Duration for the return animation.
  var returnAnimationDuration: TimeInterval = 0.44

  // Size of the circular button.
  private let buttonSize: CGFloat = 48
  // Size of the black circle icon inside the button.
  private let iconSize: CGFloat = 24
  // Holds the glass background for the button.
  private let glassView = UIVisualEffectView()
  // The actual button control.
  private let button = UIButton(type: .system)
  // The black circle icon view.
  private let iconView = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureView()
  }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)
    configureIcon()
    configureButton()

    // Lock the size to a fixed circle.
    heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
    widthAnchor.constraint(equalToConstant: buttonSize).isActive = true

    // Pin the glass background to the view bounds.
    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
  }

  // Configures the glass material background for the circular button.
  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.layer.cornerRadius = buttonSize / 2
    glassView.layer.cornerCurve = .continuous
    glassView.clipsToBounds = true
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = false
      glassView.effect = effect
    } else {
      glassView.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  // Configures the black circle icon in the center.
  private func configureIcon() {
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.backgroundColor = .black
    iconView.layer.cornerRadius = iconSize / 2
    iconView.isUserInteractionEnabled = false
    glassView.contentView.addSubview(iconView)

    // Center the icon in the button.
    iconView.centerXAnchor.constraint(equalTo: glassView.contentView.centerXAnchor).isActive = true
    iconView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor).isActive = true
    iconView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
    iconView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
  }

  // Configures the button for tap handling.
  private func configureButton() {
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = UIColor.clear
    button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
    button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
    button.addTarget(
      self,
      action: #selector(buttonTouchUp),
      for: [.touchUpInside, .touchUpOutside, .touchCancel]
    )
    button.accessibilityLabel = "AI"
    button.accessibilityIdentifier = "aiButton"

    glassView.contentView.addSubview(button)

    // Pin the button to fill the glass background.
    button.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor).isActive = true
    button.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor).isActive = true
    button.topAnchor.constraint(equalTo: glassView.contentView.topAnchor).isActive = true
    button.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor).isActive = true
  }

  // Handles button taps.
  @objc private func buttonPressed() {
    tapped?()
  }

  // Touch down handler - no visual feedback.
  @objc private func buttonTouchDown() {
    // No action needed.
  }

  // Touch up handler - no visual feedback.
  @objc private func buttonTouchUp() {
    // No action needed.
  }

  // Distance to slide when yielding (button size + padding).
  private var yieldSlideDistance: CGFloat { buttonSize + 60 }

  // Sets the yielded state with optional animation.
  // When animated is true, the transform change is applied immediately
  // so the caller can wrap it in their own animation block for coordination.
  // When animated is false, the transform is set immediately without animation.
  func setYielded(_ yielded: Bool, animated: Bool) {
    guard yielded != isYielded else { return }
    isYielded = yielded

    let targetTransform = yielded
      ? CGAffineTransform(translationX: 0, y: yieldSlideDistance)
      : .identity

    if animated {
      // Apply transform directly - caller wraps this in UIView.animate block.
      transform = targetTransform
    } else {
      // Immediate change without animation.
      transform = targetTransform
    }
  }

  // Animates the button to yielded state with spring physics.
  // Use this when the button needs to animate independently.
  func animateYield() {
    guard !isYielded else { return }
    isYielded = true
    UIView.animate(
      withDuration: 0.35,
      delay: 0,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      self.transform = CGAffineTransform(translationX: 0, y: self.yieldSlideDistance)
    }
  }

  // Animates the button back to its original position with spring physics.
  // Use this when the button needs to animate independently.
  func animateReturn() {
    guard isYielded else { return }
    isYielded = false
    UIView.animate(
      withDuration: returnAnimationDuration,
      delay: 0,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      self.transform = .identity
    }
  }
}
