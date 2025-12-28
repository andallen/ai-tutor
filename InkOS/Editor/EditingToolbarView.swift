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
  // Matches the bar button height so the pill aligns with the pencil button.
  private let toolbarHeight: CGFloat = 44
  // Sets the button width to mirror the reference icon width.
  private let buttonWidth: CGFloat = 24
  // Adds pill padding so the background reads as one bar.
  private let horizontalPadding: CGFloat = 10
  // Matches the spacing used in the reference toolbar stack.
  private let spacing: CGFloat = 12
  // Defines the point size for the SF Symbols used by the toolbar.
  private let symbolPointSize: CGFloat = 18
  // Holds the glass background for the icon group.
  private let glassView = UIVisualEffectView()
  // Holds the undo, redo, and clear buttons in one line.
  private let stackView = UIStackView()
  // Stores the undo button.
  private lazy var undoButton = makeToolButton(
    systemImageName: "arrow.uturn.backward",
    accessibilityLabel: "Undo",
    action: #selector(undoPressed)
  )
  // Stores the redo button.
  private lazy var redoButton = makeToolButton(
    systemImageName: "arrow.uturn.forward",
    accessibilityLabel: "Redo",
    action: #selector(redoPressed)
  )
  // Stores the clear button.
  private lazy var clearButton = makeToolButton(
    systemImageName: "trash",
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
    (buttonWidth * 3) + (spacing * 2) + (horizontalPadding * 2)
  }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)

    // Locks the size to prevent clipping inside the navigation layout.
    heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
    widthAnchor.constraint(equalToConstant: toolbarWidth).isActive = true

    // Pins the glass background to the view bounds.
    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    configureStackView()
  }

  // Configures the glass material background for the pill.
  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.layer.cornerRadius = toolbarHeight / 2
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

  // Builds the stack view so the tools read as one bar.
  private func configureStackView() {
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.distribution = .fillEqually
    stackView.spacing = spacing
    stackView.translatesAutoresizingMaskIntoConstraints = false
    glassView.contentView.addSubview(stackView)

    // Pins the icon group inside the glass background.
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

    stackView.addArrangedSubview(undoButton)
    stackView.addArrangedSubview(redoButton)
    stackView.addArrangedSubview(clearButton)
  }

  // Creates a toolbar button with configured sizing and image.
  private func makeToolButton(
    systemImageName: String,
    accessibilityLabel: String,
    action: Selector
  ) -> UIButton {
    let button = UIButton(type: .system)
    let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
    let image = UIImage(systemName: systemImageName, withConfiguration: configuration)
    // Uses SF Symbols so the icons match the navigation bar style.
    if let image = image {
      button.setImage(image, for: .normal)
    } else {
      button.setTitle(accessibilityLabel, for: .normal)
    }
    button.tintColor = accentColor
    button.accessibilityLabel = accessibilityLabel
    button.backgroundColor = .clear
    button.addTarget(self, action: action, for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
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
