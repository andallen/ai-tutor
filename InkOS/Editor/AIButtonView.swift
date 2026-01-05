import UIKit

// Circular button with a black dot in the center.
// Matches the glass styling used by toolbar buttons in the editor.
final class AIButtonView: UIView {
  // Notifies the host when the button is tapped.
  var tapped: (() -> Void)?

  // Controls whether the glass background is hidden.
  // When true, only the black circle icon is visible.
  var isGlassHidden: Bool = false {
    didSet {
      glassView.alpha = isGlassHidden ? 0 : 1
    }
  }

  // Size of the circular button.
  private let buttonSize: CGFloat = 48
  // Size of the black circle icon in the center.
  private let iconSize: CGFloat = 24
  // Holds the glass background for the button.
  private let glassView = UIVisualEffectView()
  // The actual button control (placed above glass, not inside it).
  private let button = UIButton(type: .system)
  // The black circle icon (placed above glass, not inside it).
  private let circleView = UIView()

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
    configureCircle()
    addSubview(circleView)
    configureButton()
    addSubview(button)

    // Lock the size to a fixed circle.
    heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
    widthAnchor.constraint(equalToConstant: buttonSize).isActive = true

    // Pin the glass background to the view bounds.
    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    // Pin the button to fill the view bounds (above glass).
    button.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    button.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    button.topAnchor.constraint(equalTo: topAnchor).isActive = true
    button.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    // Center the circle in the view (above glass).
    circleView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    circleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    circleView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
    circleView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
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

  // Configures the black circle icon.
  private func configureCircle() {
    circleView.translatesAutoresizingMaskIntoConstraints = false
    circleView.backgroundColor = UIColor.black
    circleView.layer.cornerRadius = iconSize / 2
    circleView.isUserInteractionEnabled = false
  }

  // Configures the invisible tap button.
  private func configureButton() {
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = UIColor.clear
    button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
    button.accessibilityLabel = "AI"
  }

  // Handles button taps.
  @objc private func buttonPressed() {
    tapped?()
  }
}
