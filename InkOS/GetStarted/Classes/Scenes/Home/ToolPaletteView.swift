import UIKit

final class ToolPaletteView: UIView {
  enum ToolSelection {
    case pen
    case eraser
    case highlighter
  }

  // Notifies the host when a new tool selection is made.
  var selectionChanged: ((ToolSelection) -> Void)?
  // Notifies the host when a color is chosen.
  var colorSelectionChanged: ((String) -> Void)?
  // Notifies the host when the palette expands or collapses.
  var expansionChanged: ((Bool) -> Void)?

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
  // Hosts the palette inside a real toolbar.
  private let toolbar = UIToolbar()
  // Holds the tool buttons in a single bar-style group.
  private let stackView = UIStackView()
  // Stores the width constraint so it can be animated.
  private var widthConstraint: NSLayoutConstraint?
  // Tracks whether the palette is expanded or collapsed.
  private var isExpanded = false
  // Tracks which tool is currently selected.
  private var selectedTool: ToolSelection = .pen
  // Tracks which hex color is currently selected.
  private var selectedColorHex = "#000000"
  // Defines the list of preset colors shown in the palette menu.
  private let colorOptions: [ColorOption] = [
    ColorOption(name: "Black", hex: "#000000", color: .black),
    ColorOption(
      name: "Blue", hex: "#0096FF", color: UIColor(red: 0, green: 0.59, blue: 1, alpha: 1)),
    ColorOption(
      name: "Red", hex: "#FF3232", color: UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)),
    ColorOption(
      name: "Green", hex: "#00B26F", color: UIColor(red: 0, green: 0.7, blue: 0.44, alpha: 1)),
    ColorOption(
      name: "Golden", hex: "#F5A623", color: UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)),
  ]
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
    configureColorMenu()
    applySelection(.pen)
    setExpanded(false, animated: false)
  }

  // Attaches the color menu to the palette button.
  private func configureColorMenu() {
    colorButton.menu = buildColorMenu()
    colorButton.showsMenuAsPrimaryAction = true
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

    // Pins the tool group to the leading edge of the toolbar.
    stackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor).isActive = true
    stackView.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor).isActive = true

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
    updateToggleIcon(isExpanded: expanded)
    expansionChanged?(expanded)
    animateExpansion(expanded: expanded, animated: animated)
  }

  // Updates the width constraint to match the expanded or collapsed state.
  private func updateWidthForState(expanded: Bool) {
    widthConstraint?.constant = expanded ? expandedWidth : collapsedWidth
  }

  // Updates the toggle icon without removing the leftmost button.
  private func updateToggleIcon(isExpanded: Bool) {
    let toggleName = isExpanded ? "xmark" : "pencil"
    let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
    toggleButton.setImage(
      UIImage(systemName: toggleName, withConfiguration: configuration), for: .normal)
    toggleButton.accessibilityLabel = isExpanded ? "Hide tools" : "Show tools"
  }

  // Makes tool buttons available before the expand animation starts.
  private func prepareToolButtonsForExpansion() {
    toolButtons.forEach { $0.isHidden = false }
    toolButtons.forEach { $0.alpha = 0 }
    toolButtons.forEach { $0.isUserInteractionEnabled = true }
    toolButtons.forEach { $0.isAccessibilityElement = true }
  }

  // Prevents taps and accessibility focus while collapsing.
  private func prepareToolButtonsForCollapse() {
    toolButtons.forEach { $0.isUserInteractionEnabled = false }
    toolButtons.forEach { $0.isAccessibilityElement = false }
  }

  // Animates the palette width and tool button alpha in a single pass.
  private func animateExpansion(expanded: Bool, animated: Bool) {
    superview?.layoutIfNeeded()
    if expanded {
      prepareToolButtonsForExpansion()
    } else {
      prepareToolButtonsForCollapse()
    }
    updateWidthForState(expanded: expanded)

    let targetAlpha: CGFloat = expanded ? 1 : 0
    let animations = { [weak self] in
      guard let self = self else { return }
      self.superview?.layoutIfNeeded()
      self.toolButtons.forEach { $0.alpha = targetAlpha }
    }

    let completion: (Bool) -> Void = { [weak self] _ in
      guard let self = self, !expanded else { return }
      self.toolButtons.forEach { $0.isHidden = true }
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
  @objc private func colorTapped() {
    colorButton.menu = buildColorMenu()
    colorButton.showsMenuAsPrimaryAction = true
  }

  // Creates the menu used to pick a preset ink color.
  private func buildColorMenu() -> UIMenu {
    let actions = colorOptions.map { option -> UIAction in
      let action = UIAction(
        title: option.name,
        image: colorImage(for: option)
      ) { [weak self] _ in
        self?.handleColorSelection(option)
      }
      action.state = option.hex == selectedColorHex ? .on : .off
      return action
    }
    return UIMenu(title: "Ink Color", children: actions)
  }

  // Builds the colored circle symbol for the menu entry.
  private func colorImage(for option: ColorOption) -> UIImage? {
    let image = UIImage(systemName: "circle.fill")?.withRenderingMode(.alwaysOriginal)
    return image?.withTintColor(option.color)
  }

  // Updates palette state when a color is chosen.
  private func handleColorSelection(_ option: ColorOption) {
    selectedColorHex = option.hex
    colorSelectionChanged?(option.hex)
    colorButton.menu = buildColorMenu()
  }
}

// Describes a preset color shown in the palette menu.
private struct ColorOption {
  let name: String
  let hex: String
  let color: UIColor
}
