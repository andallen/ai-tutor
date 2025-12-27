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
  // Stores the width constraint so it can animate in and out.
  private var widthConstraint: NSLayoutConstraint?
  // Tracks whether the toolbar is collapsed.
  private var isCollapsed = false
  // Stores the undo button.
  private lazy var undoButton = makeToolButton(
    imageName: "Undo",
    systemImageName: "arrow.uturn.backward",
    accessibilityLabel: "Undo",
    action: #selector(undoPressed)
  )
  // Stores the redo button.
  private lazy var redoButton = makeToolButton(
    imageName: "Redo",
    systemImageName: "arrow.uturn.forward",
    accessibilityLabel: "Redo",
    action: #selector(redoPressed)
  )
  // Stores the clear button.
  private lazy var clearButton = makeToolButton(
    imageName: "Clear",
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
    (buttonSize * 3) + (spacing * 2) + (horizontalPadding * 2)
  }

  // The fully collapsed width hides the toolbar entirely.
  private var collapsedWidth: CGFloat { 0 }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear
    layer.cornerRadius = toolbarHeight / 2
    layer.masksToBounds = true

    toolbar.translatesAutoresizingMaskIntoConstraints = false
    toolbar.isTranslucent = true
    toolbar.tintColor = accentColor
    toolbar.clipsToBounds = true
    configureToolbarAppearance()

    addSubview(toolbar)

    // Anchors the toolbar to fill the container.
    toolbar.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    toolbar.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    toolbar.topAnchor.constraint(equalTo: topAnchor).isActive = true
    toolbar.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    // Locks the size to prevent clipping inside the navigation layout.
    heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
    let widthConstraint = widthAnchor.constraint(equalToConstant: toolbarWidth)
    widthConstraint.isActive = true
    self.widthConstraint = widthConstraint

    configureStackView()
    setCollapsed(false, animated: false)
  }

  // Applies the default pill toolbar appearance behind the icons.
  private func configureToolbarAppearance() {
    let appearance = UIToolbarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.shadowColor = .clear
    toolbar.standardAppearance = appearance
    toolbar.compactAppearance = appearance
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
    systemImageName: String,
    accessibilityLabel: String,
    action: Selector
  ) -> UIButton {
    let button = UIButton(type: .system)
    let namedImage = UIImage(named: imageName)
    let systemImage = UIImage(systemName: systemImageName)
    // Falls back to SF Symbols when the bundled image is missing.
    if let image = namedImage ?? systemImage {
      button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
    } else {
      button.setTitle(accessibilityLabel, for: .normal)
    }
    button.tintColor = accentColor
    button.accessibilityLabel = accessibilityLabel
    button.addTarget(self, action: action, for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
    button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
    return button
  }

  // Expands or collapses the toolbar with optional animation.
  func setCollapsed(_ collapsed: Bool, animated: Bool) {
    guard collapsed != isCollapsed else { return }
    isCollapsed = collapsed
    superview?.layoutIfNeeded()
    if collapsed {
      prepareForCollapse()
    } else {
      prepareForExpand()
    }
    updateWidthForState(collapsed: collapsed)

    let targetAlpha: CGFloat = collapsed ? 0 : 1
    let animations = { [weak self] in
      guard let self = self else { return }
      self.superview?.layoutIfNeeded()
      self.toolbar.alpha = targetAlpha
    }

    let completion: (Bool) -> Void = { [weak self] _ in
      guard let self = self else { return }
      if collapsed {
        self.toolbar.isHidden = true
      }
    }

    if animated {
      UIView.animate(
        withDuration: 0.22,
        delay: 0,
        options: [.curveEaseInOut],
        animations: animations,
        completion: completion
      )
    } else {
      animations()
      completion(true)
    }
  }

  // Enables taps and accessibility for the toolbar buttons when expanding.
  private func prepareForExpand() {
    toolbar.isHidden = false
    toolbar.alpha = 0
    [undoButton, redoButton, clearButton].forEach { button in
      button.isUserInteractionEnabled = true
      button.isAccessibilityElement = true
    }
  }

  // Disables taps and accessibility for the toolbar buttons when collapsing.
  private func prepareForCollapse() {
    [undoButton, redoButton, clearButton].forEach { button in
      button.isUserInteractionEnabled = false
      button.isAccessibilityElement = false
    }
  }

  // Updates the width constraint to match the collapsed or expanded state.
  private func updateWidthForState(collapsed: Bool) {
    widthConstraint?.constant = collapsed ? collapsedWidth : toolbarWidth
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
