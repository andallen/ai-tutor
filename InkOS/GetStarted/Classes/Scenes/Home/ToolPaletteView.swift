import UIKit

final class ToolPaletteView: UIView {
  enum ToolSelection {
    case pen
    case eraser
    case highlighter
  }

  // Notifies the host when a new tool selection is made.
  var selectionChanged: ((ToolSelection) -> Void)?

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
  // Defines the point size for the SF Symbols used by the palette.
  private let symbolPointSize: CGFloat = 18
  // Hosts the bar button items in a real toolbar.
  private let toolbar = UIToolbar()
  // Holds the tool buttons in a single bar-style group.
  private let stackView = UIStackView()
  // Stores the width constraint so it can be animated.
  private var widthConstraint: NSLayoutConstraint?
  // Tracks whether the palette is expanded or collapsed.
  private var isExpanded = false
  // Tracks which tool is currently selected.
  private var selectedTool: ToolSelection = .pen
  // Stores the toggle toolbar button.
  private lazy var toggleButton = makeToolButton(
    systemName: "pencil",
    accessibilityLabel: "Show tools",
    action: #selector(togglePalette)
  )
  // Stores the pen toolbar button.
  private lazy var penButton = makeToolButton(
    systemName: "pencil.tip",
    accessibilityLabel: "Pen",
    action: #selector(penTapped)
  )
  // Stores the eraser toolbar button.
  private lazy var eraserButton = makeToolButton(
    systemName: "eraser",
    accessibilityLabel: "Eraser",
    action: #selector(eraserTapped)
  )
  // Stores the highlighter toolbar button.
  private lazy var highlighterButton = makeToolButton(
    systemName: "highlighter",
    accessibilityLabel: "Highlighter",
    action: #selector(highlighterTapped)
  )
  // Stores the color toolbar button.
  private lazy var colorButton = makeToolButton(
    systemName: "paintpalette",
    accessibilityLabel: "Color",
    action: #selector(colorTapped)
  )
  // Wraps the stack view in a bar button item.
  private lazy var stackItem = UIBarButtonItem(customView: stackView)

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

  // Computes the width for the collapsed circular state.
  private var collapsedWidth: CGFloat {
    toolbarHeight
  }

  // Computes the width for the expanded toolbar state.
  private var expandedWidth: CGFloat {
    (buttonSize * 5) + (spacing * 4) + (horizontalPadding * 2)
  }

  // Collects the buttons that hide when collapsed.
  private var toolButtons: [UIButton] {
    [penButton, eraserButton, highlighterButton, colorButton]
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
    toolbar.setItems([stackItem], animated: false)

    addSubview(toolbar)

    // Anchors the toolbar to fill the palette container.
    toolbar.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    toolbar.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    toolbar.topAnchor.constraint(equalTo: topAnchor).isActive = true
    toolbar.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    // Locks the palette height to match the toolbar height.
    heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true

    // Keeps the width updated when the palette expands or collapses.
    let widthConstraint = widthAnchor.constraint(equalToConstant: collapsedWidth)
    widthConstraint.isActive = true
    self.widthConstraint = widthConstraint

    configureStackView()
    applySelection(.pen)
    setExpanded(false, animated: false)
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
    stackView.addArrangedSubview(toggleButton)
    stackView.addArrangedSubview(penButton)
    stackView.addArrangedSubview(eraserButton)
    stackView.addArrangedSubview(highlighterButton)
    stackView.addArrangedSubview(colorButton)
  }

  // Creates a toolbar button with configured sizing and image.
  private func makeToolButton(
    systemName: String,
    accessibilityLabel: String,
    action: Selector
  ) -> UIButton {
    let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
    let image = UIImage(systemName: systemName, withConfiguration: configuration)
    let button = UIButton(type: .system)
    button.setImage(image, for: .normal)
    button.tintColor = accentColor
    button.accessibilityLabel = accessibilityLabel
    button.addTarget(self, action: action, for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
    button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
    return button
  }

  // Updates the selection state and notifies observers.
  private func applySelection(_ selection: ToolSelection) {
    selectedTool = selection
    updateItemAppearance()
    selectionChanged?(selection)
  }

  // Applies the shared tint so the tools match the top bar buttons.
  private func updateItemAppearance() {
    let unselectedColor = accentColor.withAlphaComponent(0.45)
    toggleButton.tintColor = accentColor
    penButton.tintColor = selectedTool == .pen ? accentColor : unselectedColor
    eraserButton.tintColor = selectedTool == .eraser ? accentColor : unselectedColor
    highlighterButton.tintColor = selectedTool == .highlighter ? accentColor : unselectedColor
    colorButton.tintColor = accentColor
  }

  // Expands or collapses the toolbar with optional animation.
  private func setExpanded(_ expanded: Bool, animated: Bool) {
    let toggleName = expanded ? "xmark" : "pencil"
    let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
    toggleButton.setImage(
      UIImage(systemName: toggleName, withConfiguration: configuration), for: .normal)
    toggleButton.accessibilityLabel = expanded ? "Hide tools" : "Show tools"

    updateVisibility(expanded: expanded, animated: animated)
    updateWidthForState(expanded: expanded)

    if animated {
      UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) { [weak self] in
        self?.layoutIfNeeded()
      }
    } else {
      layoutIfNeeded()
    }
  }

  // Updates the width constraint to match the expanded or collapsed state.
  private func updateWidthForState(expanded: Bool) {
    widthConstraint?.constant = expanded ? expandedWidth : collapsedWidth
  }

  // Toggles tool button visibility when expanding or collapsing.
  private func updateVisibility(expanded: Bool, animated: Bool) {
    if expanded {
      toolButtons.forEach { $0.isHidden = false }
      toolButtons.forEach { $0.alpha = 0 }
      if animated {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
          self.toolButtons.forEach { $0.alpha = 1 }
        }
      } else {
        toolButtons.forEach { $0.alpha = 1 }
      }
    } else {
      if animated {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn]) {
          self.toolButtons.forEach { $0.alpha = 0 }
        } completion: { _ in
          self.toolButtons.forEach { $0.isHidden = true }
          self.toolButtons.forEach { $0.alpha = 1 }
        }
      } else {
        toolButtons.forEach { $0.isHidden = true }
        toolButtons.forEach { $0.alpha = 1 }
      }
    }
  }

  // Handles the expand and collapse toggle.
  @objc private func togglePalette() {
    isExpanded.toggle()
    setExpanded(isExpanded, animated: true)
  }

  // Handles selection of the pen tool.
  @objc private func penTapped() {
    applySelection(.pen)
  }

  // Handles selection of the eraser tool.
  @objc private func eraserTapped() {
    applySelection(.eraser)
  }

  // Handles selection of the highlighter tool.
  @objc private func highlighterTapped() {
    applySelection(.highlighter)
  }

  // Handles selection of the color button.
  @objc private func colorTapped() {}
}
