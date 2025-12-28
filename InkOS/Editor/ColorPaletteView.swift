import UIKit

// Describes a preset color shown in the palette menu.
struct ColorOption {
  let name: String
  let hex: String
  let color: UIColor
}

// Presents a horizontal list of color choices in a glass pill.
final class ColorPaletteView: UIView {

  // Notifies when the user picks a color.
  var selectionChanged: ((ColorOption) -> Void)?

  // Holds the glass background for the palette.
  private let glassView = UIVisualEffectView()
  // Builds the horizontal stack of color buttons.
  private let stackView = UIStackView()
  // Defines the pill height to match the toolbar.
  let paletteHeight: CGFloat = 36
  // Sets the base size for the color circles.
  private let circleSize: CGFloat = 18
  // Enlarges the selected circle for clarity.
  private let selectedCircleSize: CGFloat = 24
  // Controls spacing between the circles.
  private let spacing: CGFloat = 8
  // Adds horizontal padding inside the glass pill.
  private let horizontalPadding: CGFloat = 12
  // Stores the maximum options to size the container.
  private let maxOptionCount: Int
  // Stores the width constraint so it can be updated.
  private var widthConstraint: NSLayoutConstraint?
  // Tracks the chosen color hex value.
  private var selectedHex: String = ""
  // Associates buttons with their colors for updates.
  private var buttonOptions: [UIButton: ColorOption] = [:]
  // Tracks sizing constraints so the selected circle can expand.
  private var buttonConstraints:
    [UIButton: (width: NSLayoutConstraint, height: NSLayoutConstraint)] = [:]

  init(maxOptionCount: Int) {
    self.maxOptionCount = maxOptionCount
    super.init(frame: .zero)
    configureView()
  }

  required init?(coder: NSCoder) {
    self.maxOptionCount = 0
    super.init(coder: coder)
    configureView()
  }

  // Exposes the widest size needed for the palette.
  var maximumWidth: CGFloat {
    width(for: maxOptionCount, selectedCount: 1)
  }

  // Exposes the current width applied to the palette.
  var currentWidth: CGFloat {
    widthConstraint?.constant ?? 0
  }

  // Updates the option list and selection state.
  func updateOptions(_ options: [ColorOption], selectedHex: String, animated: Bool) {
    self.selectedHex = selectedHex
    rebuildButtons(with: options)
    updateSelection(for: selectedHex, animated: animated)
    updateWidthConstraint(for: options.count, animated: animated)
  }

  // Builds the layout for the palette pill.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)

    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    heightAnchor.constraint(equalToConstant: paletteHeight).isActive = true
    widthConstraint = widthAnchor.constraint(equalToConstant: maximumWidth)
    widthConstraint?.isActive = true

    configureStackView()
  }

  // Configures the glass material background for the pill.
  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.layer.cornerRadius = paletteHeight / 2
    glassView.layer.cornerCurve = .continuous
    glassView.clipsToBounds = true
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = false
      effect.tintColor = UIColor.white.withAlphaComponent(0.35)
      glassView.effect = effect
    } else {
      glassView.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  // Builds the layout for the color buttons.
  private func configureStackView() {
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.spacing = spacing
    stackView.translatesAutoresizingMaskIntoConstraints = false
    glassView.contentView.addSubview(stackView)

    stackView.leadingAnchor.constraint(
      equalTo: glassView.contentView.leadingAnchor,
      constant: horizontalPadding
    )
    .isActive = true
    stackView.trailingAnchor.constraint(
      equalTo: glassView.contentView.trailingAnchor,
      constant: -horizontalPadding
    )
    .isActive = true
    stackView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor).isActive = true
    stackView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor).isActive = true
  }

  // Rebuilds the stack to show the current options.
  private func rebuildButtons(with options: [ColorOption]) {
    stackView.arrangedSubviews.forEach { view in
      view.removeFromSuperview()
    }
    buttonOptions.removeAll()
    buttonConstraints.removeAll()

    options.forEach { option in
      let button = makeColorButton(for: option)
      stackView.addArrangedSubview(button)
      buttonOptions[button] = option
    }
    widthConstraint?.constant = width(for: options.count, selectedCount: 1)
  }

  // Updates the selection state for the palette buttons.
  private func updateSelection(for hex: String, animated: Bool) {
    let applySizing = { [weak self] in
      guard let self = self else { return }
      self.buttonConstraints.forEach { button, constraints in
        let isSelected = self.buttonOptions[button]?.hex == hex
        constraints.width.constant = isSelected ? self.selectedCircleSize : self.circleSize
        constraints.height.constant = isSelected ? self.selectedCircleSize : self.circleSize
        button.layer.cornerRadius = constraints.width.constant / 2
      }
      self.layoutIfNeeded()
    }
    if animated {
      layoutIfNeeded()
      UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
        applySizing()
      }
    } else {
      applySizing()
    }
  }

  // Creates a small circular button for a color.
  private func makeColorButton(for option: ColorOption) -> UIButton {
    let button = UIButton(type: .system)
    button.backgroundColor = option.color
    button.layer.cornerRadius = circleSize / 2
    button.layer.masksToBounds = true
    button.accessibilityLabel = option.name
    button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    let widthConstraint = button.widthAnchor.constraint(equalToConstant: circleSize)
    let heightConstraint = button.heightAnchor.constraint(equalToConstant: circleSize)
    NSLayoutConstraint.activate([widthConstraint, heightConstraint])
    buttonConstraints[button] = (width: widthConstraint, height: heightConstraint)
    return button
  }

  // Handles taps on a color choice.
  @objc private func colorTapped(_ sender: UIButton) {
    guard let option = buttonOptions[sender] else { return }
    updateSelection(for: option.hex, animated: true)
    selectionChanged?(option)
  }

  // Computes the target width for the given option count.
  private func width(for count: Int, selectedCount: Int) -> CGFloat {
    guard count > 0 else { return 0 }
    let clampedSelectedCount = min(max(selectedCount, 0), count)
    let unselectedCount = count - clampedSelectedCount
    let spacingTotal = spacing * CGFloat(count - 1)
    let circlesWidth =
      (CGFloat(clampedSelectedCount) * selectedCircleSize)
      + (CGFloat(unselectedCount) * circleSize)
    return circlesWidth + spacingTotal + (horizontalPadding * 2)
  }

  // Keeps the palette width aligned to the selected circle sizing.
  private func updateWidthConstraint(for count: Int, animated: Bool) {
    let targetWidth = width(for: count, selectedCount: count > 0 ? 1 : 0)
    if animated {
      layoutIfNeeded()
      UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
        self.widthConstraint?.constant = targetWidth
        self.layoutIfNeeded()
      }
    } else {
      widthConstraint?.constant = targetWidth
    }
  }
}
