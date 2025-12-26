import UIKit

final class ToolPaletteView: UIView {
  enum ToolSelection {
    case pen
    case eraser
    case highlighter
  }

  // Notifies the host when a new tool selection is made.
  var selectionChanged: ((ToolSelection) -> Void)?
  // Notifies the host when a color is chosen for a specific tool.
  var colorSelectionChanged: ((ToolSelection, String) -> Void)?
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
  // Tracks which pen color is currently selected.
  private var selectedPenColor = ColorOption(name: "Black", hex: "#000000", color: .black)
  // Tracks which highlighter color is currently selected.
  private var selectedHighlighterColor =
    ColorOption(
      name: "Lemon", hex: "#FFF176", color: UIColor(red: 1, green: 0.95, blue: 0.46, alpha: 1))
  // Defines the list of preset pen colors shown in the selector.
  private let penColorOptions: [ColorOption] = [
    ColorOption(name: "Black", hex: "#000000", color: .black),
    ColorOption(
      name: "Blue", hex: "#1976D2", color: UIColor(red: 0.1, green: 0.46, blue: 0.82, alpha: 1)),
    ColorOption(
      name: "Green", hex: "#2E7D32", color: UIColor(red: 0.18, green: 0.49, blue: 0.2, alpha: 1)),
    ColorOption(
      name: "Red", hex: "#C62828", color: UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1)),
    ColorOption(
      name: "Yellow", hex: "#FBC02D", color: UIColor(red: 0.98, green: 0.75, blue: 0.18, alpha: 1)),
  ]
  // Defines the list of preset highlighter colors shown in the selector.
  private let highlighterColorOptions: [ColorOption] = [
    ColorOption(
      name: "Lemon", hex: "#FFF176", color: UIColor(red: 1, green: 0.95, blue: 0.46, alpha: 1)),
    ColorOption(
      name: "Sky", hex: "#80D8FF", color: UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 1)),
    ColorOption(
      name: "Mint", hex: "#B9F6CA", color: UIColor(red: 0.73, green: 0.96, blue: 0.79, alpha: 1)),
    ColorOption(
      name: "Coral", hex: "#FFAB91", color: UIColor(red: 1, green: 0.67, blue: 0.57, alpha: 1)),
    ColorOption(
      name: "Lavender", hex: "#E1BEE7", color: UIColor(red: 0.88, green: 0.75, blue: 0.91, alpha: 1)
    ),
  ]
  // Stores the pen color selector.
  private lazy var penColorSelector = ColorSelectorView(
    options: penColorOptions,
    selectedHex: selectedPenColor.hex
  )
  // Stores the highlighter color selector.
  private lazy var highlighterColorSelector = ColorSelectorView(
    options: highlighterColorOptions,
    selectedHex: selectedHighlighterColor.hex
  )
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
    (buttonSize * 4) + (spacing * 3) + (horizontalPadding * 2)
  }

  // Collects the buttons that hide when collapsed.
  private var toolButtons: [UIButton] {
    [penButton, eraserButton, highlighterButton]
  }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear
    layer.cornerRadius = toolbarHeight / 2
    layer.masksToBounds = false

    toolbar.translatesAutoresizingMaskIntoConstraints = false
    toolbar.isTranslucent = true
    toolbar.tintColor = accentColor
    toolbar.clipsToBounds = false

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
    configureColorSelectors()
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
    stackView.translatesAutoresizingMaskIntoConstraints = false
    toolbar.addSubview(stackView)

    // Pins the tool group to the leading edge of the toolbar.
    stackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor).isActive = true
    stackView.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor).isActive = true

    stackView.addArrangedSubview(toggleButton)
    stackView.addArrangedSubview(penButton)
    stackView.addArrangedSubview(eraserButton)
    stackView.addArrangedSubview(highlighterButton)
  }

  // Attaches the vertical color selectors above their tools.
  private func configureColorSelectors() {
    penColorSelector.selectionChanged = { [weak self] option in
      self?.handleColorSelection(option, for: .pen)
    }
    highlighterColorSelector.selectionChanged = { [weak self] option in
      self?.handleColorSelection(option, for: .highlighter)
    }

    addSubview(penColorSelector)
    addSubview(highlighterColorSelector)

    penColorSelector.centerXAnchor.constraint(equalTo: penButton.centerXAnchor).isActive = true
    penColorSelector.bottomAnchor.constraint(equalTo: penButton.topAnchor, constant: -6).isActive =
      true

    highlighterColorSelector.centerXAnchor.constraint(equalTo: highlighterButton.centerXAnchor)
      .isActive = true
    highlighterColorSelector.bottomAnchor.constraint(
      equalTo: highlighterButton.topAnchor, constant: -6
    )
    .isActive = true
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
    updateColorSelectors(for: selection, animated: true)
    updateItemAppearance()
    selectionChanged?(selection)
  }

  // Applies the shared tint so the tools match the top bar buttons.
  private func updateItemAppearance() {
    let unselectedColor = accentColor.withAlphaComponent(0.45)
    toggleButton.tintColor = accentColor
    penButton.tintColor = tint(for: selectedPenColor.color, isSelected: selectedTool == .pen)
    eraserButton.tintColor = selectedTool == .eraser ? accentColor : unselectedColor
    highlighterButton.tintColor =
      tint(for: selectedHighlighterColor.color, isSelected: selectedTool == .highlighter)
  }

  // Adjusts the tint based on the selection state.
  private func tint(for color: UIColor, isSelected: Bool) -> UIColor {
    let fadedColor = color.withAlphaComponent(0.45)
    return isSelected ? color : fadedColor
  }

  // Expands or collapses the toolbar with optional animation.
  private func setExpanded(_ expanded: Bool, animated: Bool) {
    isExpanded = expanded
    if expanded {
      updateColorSelectors(for: selectedTool, animated: animated)
    } else {
      collapseColorSelectors(animated: animated)
    }
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

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let expandedSelectorFrames = [penColorSelector, highlighterColorSelector]
      .compactMap { selector in
        selector.isHidden ? nil : selector.frame
      }
    let extendedBounds = expandedSelectorFrames.reduce(bounds) { current, frame in
      current.union(frame)
    }
    return extendedBounds.contains(point)
  }

  // Handles selection of the pen tool.
  @objc private func penTapped() {
    if selectedTool == .pen, penColorSelector.isExpandedForTool {
      collapseColorSelectors(animated: true)
    } else {
      applySelection(.pen)
    }
  }

  // Handles selection of the eraser tool.
  @objc private func eraserTapped() {
    applySelection(.eraser)
  }

  // Handles selection of the highlighter tool.
  @objc private func highlighterTapped() {
    if selectedTool == .highlighter, highlighterColorSelector.isExpandedForTool {
      collapseColorSelectors(animated: true)
    } else {
      applySelection(.highlighter)
    }
  }

  // Shows the matching color selector for the current tool.
  private func updateColorSelectors(for selection: ToolSelection, animated: Bool) {
    guard isExpanded else { return }
    switch selection {
    case .pen:
      showColorSelector(penColorSelector, hiding: highlighterColorSelector, animated: animated)
    case .highlighter:
      showColorSelector(highlighterColorSelector, hiding: penColorSelector, animated: animated)
    case .eraser:
      collapseColorSelectors(animated: animated)
    }
  }

  // Expands the requested selector and hides the other one.
  private func showColorSelector(
    _ selector: ColorSelectorView,
    hiding otherSelector: ColorSelectorView,
    animated: Bool
  ) {
    otherSelector.setExpanded(false, animated: animated)
    selector.setExpanded(true, animated: animated)
  }

  // Collapses both color selectors.
  private func collapseColorSelectors(animated: Bool) {
    penColorSelector.setExpanded(false, animated: animated)
    highlighterColorSelector.setExpanded(false, animated: animated)
  }

  // Updates palette state when a color is chosen.
  private func handleColorSelection(_ option: ColorOption, for tool: ToolSelection) {
    switch tool {
    case .pen:
      selectedPenColor = option
    case .highlighter:
      selectedHighlighterColor = option
    case .eraser:
      break
    }
    updateItemAppearance()
    colorSelectionChanged?(tool, option.hex)
  }
}

// Describes a preset color shown in the palette menu.
private struct ColorOption {
  let name: String
  let hex: String
  let color: UIColor
}

// Presents a vertical list of color choices that expands from bottom to top.
private final class ColorSelectorView: UIView {

  // Notifies when the user picks a color.
  var selectionChanged: ((ColorOption) -> Void)?

  // Holds the available color options.
  private let options: [ColorOption]
  // Sets the base size for the color circles.
  private let circleSize: CGFloat = 18
  // Enlarges the selected circle for clarity.
  private let selectedCircleSize: CGFloat = 24
  // Controls spacing between the circles.
  private let spacing: CGFloat = 8
  // Builds the vertical stack of color buttons.
  private let stackView = UIStackView()
  // Stores the height constraint so it can animate open and closed.
  private var heightConstraint: NSLayoutConstraint?
  // Tracks whether the selector is visible.
  private var isExpanded = false
  // Tracks the chosen color hex value.
  private var selectedHex: String
  // Associates buttons with their colors for updates.
  private var buttonOptions: [UIButton: ColorOption] = [:]
  // Tracks sizing constraints so the selected circle can expand.
  private var buttonConstraints:
    [UIButton: (width: NSLayoutConstraint, height: NSLayoutConstraint)] = [:]

  init(options: [ColorOption], selectedHex: String) {
    self.options = options
    self.selectedHex = selectedHex
    super.init(frame: .zero)
    configureView()
    updateSelection(for: selectedHex, animated: false)
  }

  required init?(coder: NSCoder) {
    self.options = []
    self.selectedHex = ""
    super.init(coder: coder)
  }

  // Opens or closes the selector with a shared animation curve.
  func setExpanded(_ expanded: Bool, animated: Bool) {
    guard expanded != isExpanded else { return }
    isExpanded = expanded
    superview?.layoutIfNeeded()
    if expanded {
      isHidden = false
      alpha = 0
    }
    heightConstraint?.constant = expanded ? expandedHeight : 0
    let animations = { [weak self] in
      guard let self = self else { return }
      self.superview?.layoutIfNeeded()
      self.alpha = expanded ? 1 : 0
    }
    let completion: (Bool) -> Void = { [weak self] _ in
      guard let self = self else { return }
      if expanded == false {
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

  // Exposes whether the selector is currently open.
  var isExpandedForTool: Bool {
    isExpanded
  }

  // Marks the matching button as selected.
  private func updateSelection(for hex: String, animated: Bool) {
    selectedHex = hex
    let applySizing = { [weak self] in
      guard let self = self else { return }
      self.buttonConstraints.forEach { button, constraints in
        let isSelected = self.buttonOptions[button]?.hex == hex
        constraints.width.constant = isSelected ? self.selectedCircleSize : self.circleSize
        constraints.height.constant = isSelected ? self.selectedCircleSize : self.circleSize
        button.layer.cornerRadius = (constraints.width.constant) / 2
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

  // Builds the layout for the color list.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = true
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.spacing = spacing
    stackView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stackView)

    stackView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    stackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    stackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    stackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

    options.reversed().forEach { option in
      let button = makeColorButton(for: option)
      stackView.addArrangedSubview(button)
      buttonOptions[button] = option
    }

    heightConstraint = heightAnchor.constraint(equalToConstant: 0)
    heightConstraint?.isActive = true
    isHidden = true
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

  // Computes the target height for the expanded state.
  private var expandedHeight: CGFloat {
    let count = CGFloat(options.count)
    let spacingTotal = spacing * (count - 1)
    return (count * selectedCircleSize) + spacingTotal
  }
}
