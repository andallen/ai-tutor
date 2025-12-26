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
  // Sets the toolbar height to match the reference stack view layout.
  private let toolbarHeight: CGFloat = 31
  // Stores the measured width for the expanded toolbar so the constraint can be applied reliably.
  private var expandedWidth: CGFloat = 0
  // Holds the icon-only buttons inside the bar.
  private let stackView = UIStackView()
  // Stores the width constraint so it can animate in and out.
  private var widthConstraint: NSLayoutConstraint?
  // Tracks whether the toolbar is collapsed.
  private var isCollapsed = false
  // Stores the undo button.
  private lazy var undoButton = makeIconButton(
    imageName: "Undo",
    systemImageName: "arrow.uturn.backward",
    accessibilityLabel: "Undo",
    action: #selector(undoPressed)
  )
  // Stores the redo button.
  private lazy var redoButton = makeIconButton(
    imageName: "Redo",
    systemImageName: "arrow.uturn.forward",
    accessibilityLabel: "Redo",
    action: #selector(redoPressed)
  )
  // Stores the clear button.
  private lazy var clearButton = makeIconButton(
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

  // The fully collapsed width hides the toolbar entirely.
  private var collapsedWidth: CGFloat { 0 }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .center
    stackView.distribution = .fillEqually
    stackView.addArrangedSubview(undoButton)
    stackView.addArrangedSubview(redoButton)
    stackView.addArrangedSubview(clearButton)
    expandedWidth = measuredToolbarWidth()

    addSubview(stackView)

    // Anchors the stack to fill the container.
    stackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    stackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    stackView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    stackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    // Locks the size to prevent clipping inside the navigation layout.
    heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
    let widthConstraint = widthAnchor.constraint(equalToConstant: expandedWidth)
    widthConstraint.isActive = true
    self.widthConstraint = widthConstraint

    setCollapsed(false, animated: false)
  }

  // Creates icon-only buttons that mirror the reference stack view styling.
  private func makeIconButton(
    imageName: String,
    systemImageName: String,
    accessibilityLabel: String,
    action: Selector
  ) -> UIButton {
    let namedImage = UIImage(named: imageName)
    let systemImage = UIImage(systemName: systemImageName)
    let image = namedImage ?? systemImage
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
    button.tintColor = accentColor
    button.accessibilityLabel = accessibilityLabel
    button.backgroundColor = .clear
    button.contentEdgeInsets = .zero
    button.addTarget(self, action: action, for: .touchUpInside)
    button.adjustsImageWhenHighlighted = false
    button.heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
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
      self.alpha = targetAlpha
    }

    let completion: (Bool) -> Void = { [weak self] _ in
      guard let self = self else { return }
      if collapsed {
        self.isHidden = true
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
    isHidden = false
    alpha = 0
    stackView.isUserInteractionEnabled = true
    stackView.arrangedSubviews.forEach { $0.isUserInteractionEnabled = true }
  }

  // Disables taps and accessibility for the toolbar buttons when collapsing.
  private func prepareForCollapse() {
    stackView.arrangedSubviews.forEach { $0.isUserInteractionEnabled = false }
    stackView.isUserInteractionEnabled = false
  }

  // Updates the width constraint to match the collapsed or expanded state.
  private func updateWidthForState(collapsed: Bool) {
    if collapsed {
      widthConstraint?.constant = collapsedWidth
      return
    }
    expandedWidth = measuredToolbarWidth()
    widthConstraint?.constant = expandedWidth
  }

  // Measures the toolbar width based on its intrinsic content size while guarding against invalid results.
  private func measuredToolbarWidth() -> CGFloat {
    let buttonCount = CGFloat(stackView.arrangedSubviews.count)
    guard buttonCount > 0 else { return toolbarHeight }
    let widestButton = stackView.arrangedSubviews.reduce(into: CGFloat(0)) { widest, view in
      widest = max(widest, max(view.intrinsicContentSize.width, toolbarHeight))
    }
    let spacingWidth = stackView.spacing * CGFloat(max(stackView.arrangedSubviews.count - 1, 0))
    let measuredWidth = (widestButton * buttonCount) + spacingWidth
    return max(measuredWidth, toolbarHeight * buttonCount)
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
