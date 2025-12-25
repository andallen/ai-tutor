import UIKit

final class EditingToolbarView: UIView {
  // Notifies the host when undo is tapped.
  var undoTapped: (() -> Void)?
  // Notifies the host when redo is tapped.
  var redoTapped: (() -> Void)?
  // Notifies the host when clear is tapped.
  var clearTapped: (() -> Void)?

  // Defines the shared tint used for the toolbar icons.
  private let accentColor: UIColor
  // Sets the toolbar height to align with navigation bar sizing.
  private let toolbarHeight: CGFloat = 44
  // Sets the button size to match the top bar buttons.
  private let buttonSize: CGFloat = 28
  // Adds horizontal padding so the toolbar looks balanced.
  private let horizontalPadding: CGFloat = 8
  // Matches the spacing used in the top bar stack of buttons.
  private let spacing: CGFloat = 12
  // Hosts the icons inside a real toolbar.
  private let toolbar = UIToolbar()
  // Holds the undo, redo, and clear buttons in one line.
  private let stackView = UIStackView()
  // Stores the undo button.
  private lazy var undoButton = makeToolButton(
    imageName: "Undo",
    accessibilityLabel: "Undo",
    action: #selector(undoPressed)
  )
  // Stores the redo button.
  private lazy var redoButton = makeToolButton(
    imageName: "Redo",
    accessibilityLabel: "Redo",
    action: #selector(redoPressed)
  )
  // Stores the clear button.
  private lazy var clearButton = makeToolButton(
    imageName: "Clear",
    accessibilityLabel: "Clear",
    action: #selector(clearPressed)
  )

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

  // Computes the width for the fixed toolbar size.
  private var toolbarWidth: CGFloat {
    (buttonSize * 3) + (spacing * 2) + (horizontalPadding * 2)
  }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear
    layer.cornerRadius = toolbarHeight / 2
    layer.masksToBounds = true

    toolbar.translatesAutoresizingMaskIntoConstraints = false
    toolbar.isTranslucent = true
    toolbar.tintColor = accentColor
    toolbar.backgroundColor = .clear
    toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
    toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .compact)
    toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)

    addSubview(toolbar)

    // Anchors the toolbar to fill the container.
    toolbar.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    toolbar.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    toolbar.topAnchor.constraint(equalTo: topAnchor).isActive = true
    toolbar.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    // Locks the size to prevent clipping inside the navigation layout.
    heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
    widthAnchor.constraint(equalToConstant: toolbarWidth).isActive = true

    configureStackView()
  }

  // Builds the stack view so the tools read as one bar.
  private func configureStackView() {
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.spacing = spacing
    stackView.layoutMargins = UIEdgeInsets(
      top: 0,
      left: horizontalPadding,
      bottom: 0,
      right: horizontalPadding
    )
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.translatesAutoresizingMaskIntoConstraints = false
    toolbar.addSubview(stackView)

    // Pins the icon group to the leading edge of the toolbar.
    stackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor).isActive = true
    stackView.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor).isActive = true

    stackView.addArrangedSubview(undoButton)
    stackView.addArrangedSubview(redoButton)
    stackView.addArrangedSubview(clearButton)
  }

  // Creates a toolbar button with configured sizing and image.
  private func makeToolButton(
    imageName: String,
    accessibilityLabel: String,
    action: Selector
  ) -> UIButton {
    let button = UIButton(type: .system)
    if let image = UIImage(named: imageName) {
      button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
    } else {
      button.setTitle(imageName, for: .normal)
    }
    button.tintColor = accentColor
    button.accessibilityLabel = accessibilityLabel
    button.addTarget(self, action: action, for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
    button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
    return button
  }

  // Handles undo taps.
  @objc private func undoPressed() {
    undoTapped?()
  }

  // Handles redo taps.
  @objc private func redoPressed() {
    redoTapped?()
  }

  // Handles clear taps.
  @objc private func clearPressed() {
    clearTapped?()
  }
}
