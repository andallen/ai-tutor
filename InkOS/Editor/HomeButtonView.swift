import UIKit

// Circular button with a house icon in the center.
final class HomeButtonView: UIView {
  // Notifies the host when the button is tapped.
  var tapped: (() -> Void)?

  // Size of the circular button.
  private let buttonSize: CGFloat = 48
  // Defines the tint color for the house icon.
  private let accentColor: UIColor
  // Holds the glass background for the button.
  private let glassView = UIVisualEffectView()
  // The actual button control.
  private let button = UIButton(type: .system)

  init(accentColor: UIColor) {
    self.accentColor = accentColor
    super.init(frame: .zero)
    configureView()
  }

  required init?(coder: NSCoder) {
    self.accentColor = UIColor.label
    super.init(coder: coder)
    configureView()
  }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)
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

  // Configures the button with the house icon.
  private func configureButton() {
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = UIColor.clear
    button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
    button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
    button.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    button.accessibilityLabel = "Home"
    button.tintColor = accentColor

    // Set the house icon.
    let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    let image = UIImage(systemName: "house", withConfiguration: configuration)
    button.setImage(image, for: .normal)

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

  // Handles touch down for tactile feedback - scales down with white highlight.
  @objc private func buttonTouchDown() {
    UIView.animate(
      withDuration: 0.1,
      delay: 0,
      options: [.curveEaseOut, .allowUserInteraction]
    ) {
      self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
      self.glassView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
    }
  }

  // Handles touch up for tactile feedback - bounces back with spring animation.
  @objc private func buttonTouchUp() {
    UIView.animate(
      withDuration: 0.35,
      delay: 0,
      usingSpringWithDamping: 0.5,
      initialSpringVelocity: 0.3,
      options: [.allowUserInteraction]
    ) {
      self.transform = .identity
      self.glassView.backgroundColor = UIColor.clear
    }
  }
}
