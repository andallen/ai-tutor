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
  // Notifies the host when the toolbar expands or collapses.
  var expansionChanged: ((Bool) -> Void)?

  // Defines the shared tint used for the toolbar icons.
  private let accentColor: UIColor
  // Matches the compact height used by the editing toolbar pill.
  private let toolbarHeight: CGFloat = 36
  // Sets the button width to reduce the compressed icon look.
  private let toolbarButtonWidth: CGFloat = 28
  // Adds pill padding so the background reads as one bar.
  private let toolbarHorizontalPadding: CGFloat = 10
  // Matches the spacing used in the reference toolbar stack.
  private let toolbarSpacing: CGFloat = 12
  // Defines the point size for the SF Symbols used by the toolbar.
  private let symbolPointSize: CGFloat = 18
  // Sets the gap between the toolbar and the color palette pill.
  private let paletteSpacing: CGFloat = 8
  // Sets the size of the standalone pencil toolbar container.
  private let pencilButtonSize: CGFloat = 36

  // Holds the glass background for the toolbar pill.
  private let toolbarView = UIVisualEffectView()
  // Holds the tool icons in one line.
  private let toolbarStackView = UIStackView()
  // Hosts the standalone pencil bar button to match the navigation bar styling.
  private let pencilToolbar = UIToolbar()
  // Stores the standalone pencil bar button item.
  private lazy var pencilBarButton = UIBarButtonItem(
    image: UIImage(systemName: "pencil"),
    style: .plain,
    target: self,
    action: #selector(pencilTapped)
  )
  // Stores the pen toolbar button.
  private lazy var penButton = makeToolbarButton(
    systemName: "pencil.tip",
    accessibilityLabel: "Pen",
    action: #selector(penTapped)
  )
  // Stores the eraser toolbar button.
  private lazy var eraserButton = makeToolbarButton(
    systemName: "eraser",
    accessibilityLabel: "Eraser",
    action: #selector(eraserTapped)
  )
  // Stores the highlighter toolbar button.
  private lazy var highlighterButton = makeToolbarButton(
    systemName: "highlighter",
    accessibilityLabel: "Highlighter",
    action: #selector(highlighterTapped)
  )
  // Stores the palette toolbar button.
  private lazy var paletteButton = makeToolbarButton(
    systemName: "paintpalette",
    accessibilityLabel: "Colors",
    action: #selector(paletteTapped)
  )

  // Stores the pen color selector.
  private let penColorOptions: [ColorOption]
  // Stores the highlighter color selector.
  private let highlighterColorOptions: [ColorOption]
  // Shows the active color options in a pill.
  private let colorPaletteView: ColorPaletteView

  // Tracks whether the toolbar is currently visible.
  private var isToolbarVisible = false
  // Tracks whether the color palette is currently visible.
  private var isColorPaletteVisible = false
  // Tracks which tool is currently selected.
  private var selectedTool: ToolSelection = .pen
  // Tracks which pen color is currently selected.
  private var selectedPenColor: ColorOption
  // Tracks which highlighter color is currently selected.
  private var selectedHighlighterColor: ColorOption

  init(accentColor: UIColor) {
    self.accentColor = accentColor
    let penOptions = ToolPaletteView.makePenColorOptions()
    let highlighterOptions = ToolPaletteView.makeHighlighterColorOptions()
    self.penColorOptions = penOptions
    self.highlighterColorOptions = highlighterOptions
    self.selectedPenColor = penOptions.first ?? ColorOption(name: "Black", hex: "#000000", color: .black)
    self.selectedHighlighterColor = highlighterOptions.first
      ?? ColorOption(name: "Lemon", hex: "#FFF176", color: UIColor(red: 1, green: 0.95, blue: 0.46, alpha: 1))
    let maxOptionCount = max(penOptions.count, highlighterOptions.count)
    self.colorPaletteView = ColorPaletteView(maxOptionCount: maxOptionCount)
    super.init(frame: .zero)
    configureView()
  }

  required init?(coder: NSCoder) {
    self.accentColor = UIColor.label
    let penOptions = ToolPaletteView.makePenColorOptions()
    let highlighterOptions = ToolPaletteView.makeHighlighterColorOptions()
    self.penColorOptions = penOptions
    self.highlighterColorOptions = highlighterOptions
    self.selectedPenColor = penOptions.first ?? ColorOption(name: "Black", hex: "#000000", color: .black)
    self.selectedHighlighterColor = highlighterOptions.first
      ?? ColorOption(name: "Lemon", hex: "#FFF176", color: UIColor(red: 1, green: 0.95, blue: 0.46, alpha: 1))
    let maxOptionCount = max(penOptions.count, highlighterOptions.count)
    self.colorPaletteView = ColorPaletteView(maxOptionCount: maxOptionCount)
    super.init(coder: coder)
    configureView()
  }

  // Exposes whether the toolbar is expanded.
  var isExpanded: Bool {
    isToolbarVisible
  }

  // Updates the toolbar visibility with optional animation.
  func setToolbarVisible(_ visible: Bool, animated: Bool) {
    guard visible != isToolbarVisible else { return }
    isToolbarVisible = visible
    expansionChanged?(visible)
    if visible == false {
      setColorPaletteVisible(false, animated: animated)
    }
    animateToolbarVisibility(visible, animated: animated)
  }

  // Checks if a point in a host view is inside any visible palette element.
  func containsInteraction(at location: CGPoint, in hostView: UIView) -> Bool {
    let localPoint = convert(location, from: hostView)
    return self.point(inside: localPoint, with: nil)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    var hitFrames: [CGRect] = []
    if pencilToolbar.isHidden == false {
      hitFrames.append(pencilToolbar.frame)
    }
    if toolbarView.isHidden == false {
      hitFrames.append(toolbarView.frame)
    }
    if colorPaletteView.isHidden == false {
      hitFrames.append(colorPaletteView.frame)
    }
    let unionFrame = hitFrames.reduce(CGRect.null) { current, frame in
      current.union(frame)
    }
    if unionFrame.isNull {
      return false
    }
    return unionFrame.contains(point)
  }

  // Computes the width for the expanded toolbar state.
  private var toolbarWidth: CGFloat {
    (toolbarButtonWidth * 4) + (toolbarSpacing * 3) + (toolbarHorizontalPadding * 2)
  }

  // Computes the maximum size for the palette container.
  private var containerHeight: CGFloat {
    toolbarHeight + paletteSpacing + colorPaletteView.paletteHeight
  }

  // Builds the view hierarchy and initial layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear
    // Keeps the container tall enough for the toolbar and palette.
    configureSizingConstraints()
    configurePencilButton()
    configureToolbar()
    configureColorPalette()
    applySelection(.pen)
    // Forces the initial hidden state for the toolbar even when default state matches.
    isToolbarVisible = true
    setToolbarVisible(false, animated: false)
  }

  // Sets the fixed size used to cover the toolbar and palette states.
  private func configureSizingConstraints() {
    heightAnchor.constraint(equalToConstant: containerHeight).isActive = true
  }

  // Configures the standalone pencil toggle button.
  private func configurePencilButton() {
    // Matches the navigation bar bar button styling by using a toolbar container.
    let appearance = UIToolbarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = .clear
    appearance.shadowColor = .clear
    pencilBarButton.accessibilityLabel = "Show tools"
    // Increases the pencil symbol so it reads clearly in the bar button.
    let pencilSymbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
    pencilBarButton.image = UIImage(systemName: "pencil", withConfiguration: pencilSymbolConfig)
    pencilToolbar.standardAppearance = appearance
    if #available(iOS 15.0, *) {
      pencilToolbar.scrollEdgeAppearance = appearance
    }
    pencilToolbar.isTranslucent = true
    pencilToolbar.tintColor = accentColor
    pencilToolbar.setItems([pencilBarButton], animated: false)
    pencilToolbar.translatesAutoresizingMaskIntoConstraints = false
    addSubview(pencilToolbar)

    pencilToolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8).isActive = true
    pencilToolbar.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    pencilToolbar.widthAnchor.constraint(equalToConstant: pencilButtonSize).isActive = true
    pencilToolbar.heightAnchor.constraint(equalToConstant: pencilButtonSize).isActive = true
  }

  // Configures the glass toolbar pill that holds the tool icons.
  private func configureToolbar() {
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.layer.cornerRadius = toolbarHeight / 2
    toolbarView.layer.cornerCurve = .continuous
    toolbarView.clipsToBounds = true
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = false
      toolbarView.effect = effect
    } else {
      toolbarView.effect = UIBlurEffect(style: .systemMaterial)
    }
    addSubview(toolbarView)

    // Centers the toolbar so it rises into the bottom-middle of the screen.
    toolbarView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    toolbarView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    toolbarView.heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
    toolbarView.widthAnchor.constraint(equalToConstant: toolbarWidth).isActive = true

    toolbarStackView.axis = .horizontal
    toolbarStackView.alignment = .center
    toolbarStackView.distribution = .fillEqually
    toolbarStackView.spacing = toolbarSpacing
    toolbarStackView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.contentView.addSubview(toolbarStackView)

    toolbarStackView.leadingAnchor.constraint(
      equalTo: toolbarView.contentView.leadingAnchor,
      constant: toolbarHorizontalPadding
    )
    .isActive = true
    toolbarStackView.trailingAnchor.constraint(
      equalTo: toolbarView.contentView.trailingAnchor,
      constant: -toolbarHorizontalPadding
    )
    .isActive = true
    toolbarStackView.topAnchor.constraint(equalTo: toolbarView.contentView.topAnchor).isActive = true
    toolbarStackView.bottomAnchor.constraint(equalTo: toolbarView.contentView.bottomAnchor).isActive =
      true

    toolbarStackView.addArrangedSubview(penButton)
    toolbarStackView.addArrangedSubview(eraserButton)
    toolbarStackView.addArrangedSubview(highlighterButton)
    toolbarStackView.addArrangedSubview(paletteButton)
  }

  // Configures the color palette pill shown above the toolbar.
  private func configureColorPalette() {
    colorPaletteView.translatesAutoresizingMaskIntoConstraints = false
    colorPaletteView.isHidden = true
    colorPaletteView.selectionChanged = { [weak self] option in
      self?.handleColorSelection(option)
    }
    addSubview(colorPaletteView)

    // Aligns the palette with the centered toolbar.
    colorPaletteView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    colorPaletteView.bottomAnchor.constraint(
      equalTo: toolbarView.topAnchor,
      constant: -paletteSpacing
    )
    .isActive = true
  }

  // Creates a toolbar button with configured sizing and image.
  private func makeToolbarButton(
    systemName: String,
    accessibilityLabel: String,
    action: Selector
  ) -> UIButton {
    let button = UIButton(type: .system)
    let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
    let image = UIImage(systemName: systemName, withConfiguration: configuration)
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

  // Updates the selection state and notifies observers.
  private func applySelection(_ selection: ToolSelection) {
    selectedTool = selection
    updateItemAppearance()
    updateColorPaletteOptions(animated: isColorPaletteVisible)
    selectionChanged?(selection)
  }

  // Applies the shared tint so the tools match the top bar buttons.
  private func updateItemAppearance() {
    let unselectedColor = accentColor.withAlphaComponent(0.45)
    penButton.tintColor = tint(for: selectedPenColor.color, isSelected: selectedTool == .pen)
    eraserButton.tintColor = selectedTool == .eraser ? accentColor : unselectedColor
    highlighterButton.tintColor =
      tint(for: selectedHighlighterColor.color, isSelected: selectedTool == .highlighter)
    paletteButton.tintColor = selectedTool == .eraser ? unselectedColor : accentColor
    paletteButton.isEnabled = selectedTool != .eraser
  }

  // Adjusts the tint based on the selection state.
  private func tint(for color: UIColor, isSelected: Bool) -> UIColor {
    let fadedColor = color.withAlphaComponent(0.45)
    return isSelected ? color : fadedColor
  }

  // Updates the color palette options based on the active tool.
  private func updateColorPaletteOptions(animated: Bool) {
    switch selectedTool {
    case .pen:
      colorPaletteView.updateOptions(
        penColorOptions,
        selectedHex: selectedPenColor.hex,
        animated: animated
      )
    case .highlighter:
      colorPaletteView.updateOptions(
        highlighterColorOptions,
        selectedHex: selectedHighlighterColor.hex,
        animated: animated
      )
    case .eraser:
      setColorPaletteVisible(false, animated: animated)
    }
  }

  // Animates the toolbar in or out of view.
  private func animateToolbarVisibility(_ visible: Bool, animated: Bool) {
    // Pushes the toolbar below the safe area so it reads as sliding from under the screen.
    let offset = toolbarHeight + 24
    // Pushes the pencil button below the safe area when the toolbar expands.
    let pencilOffset = pencilButtonSize + 12
    if visible {
      toolbarView.isHidden = false
      toolbarView.alpha = 0
      toolbarView.transform = CGAffineTransform(translationX: 0, y: offset)
      pencilToolbar.isHidden = false
      pencilToolbar.alpha = 1
      pencilToolbar.transform = .identity
    } else {
      pencilToolbar.isHidden = false
      pencilToolbar.alpha = 1
      pencilToolbar.transform = CGAffineTransform(translationX: 0, y: pencilOffset)
    }

    let animations = { [weak self] in
      guard let self = self else { return }
      self.toolbarView.alpha = visible ? 1 : 0
      self.toolbarView.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: offset)
      self.pencilToolbar.transform =
        visible ? CGAffineTransform(translationX: 0, y: pencilOffset) : .identity
    }

    let completion: (Bool) -> Void = { [weak self] _ in
      guard let self = self else { return }
      self.toolbarView.isHidden = visible == false
      self.pencilToolbar.isHidden = visible
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

  // Shows or hides the color palette pill.
  private func setColorPaletteVisible(_ visible: Bool, animated: Bool) {
    guard visible != isColorPaletteVisible else { return }
    isColorPaletteVisible = visible
    if visible {
      colorPaletteView.isHidden = false
      colorPaletteView.alpha = 0
      colorPaletteView.transform = CGAffineTransform(translationX: 0, y: paletteSpacing)
    }

    let animations = { [weak self] in
      guard let self = self else { return }
      self.colorPaletteView.alpha = visible ? 1 : 0
      self.colorPaletteView.transform =
        visible ? .identity : CGAffineTransform(translationX: 0, y: self.paletteSpacing)
    }

    let completion: (Bool) -> Void = { [weak self] _ in
      guard let self = self else { return }
      if visible == false {
        self.colorPaletteView.isHidden = true
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

  // Handles taps on the pencil toggle button.
  @objc private func pencilTapped() {
    setToolbarVisible(true, animated: true)
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

  // Toggles the color palette when the palette button is tapped.
  @objc private func paletteTapped() {
    guard selectedTool != .eraser else { return }
    setColorPaletteVisible(!isColorPaletteVisible, animated: true)
  }

  // Updates palette state when a color is chosen.
  private func handleColorSelection(_ option: ColorOption) {
    switch selectedTool {
    case .pen:
      selectedPenColor = option
      colorSelectionChanged?(.pen, option.hex)
    case .highlighter:
      selectedHighlighterColor = option
      colorSelectionChanged?(.highlighter, option.hex)
    case .eraser:
      break
    }
    updateItemAppearance()
  }

  // Defines the list of preset pen colors shown in the selector.
  private static func makePenColorOptions() -> [ColorOption] {
    [
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
  }

  // Defines the list of preset highlighter colors shown in the selector.
  private static func makeHighlighterColorOptions() -> [ColorOption] {
    [
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
  }
}

// Describes a preset color shown in the palette menu.
private struct ColorOption {
  let name: String
  let hex: String
  let color: UIColor
}

// Presents a horizontal list of color choices in a glass pill.
private final class ColorPaletteView: UIView {

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
    width(for: maxOptionCount)
  }

  // Updates the option list and selection state.
  func updateOptions(_ options: [ColorOption], selectedHex: String, animated: Bool) {
    self.selectedHex = selectedHex
    rebuildButtons(with: options)
    updateSelection(for: selectedHex, animated: animated)
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
    widthConstraint?.constant = width(for: options.count)
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
  private func width(for count: Int) -> CGFloat {
    guard count > 0 else { return 0 }
    let countValue = CGFloat(count)
    let spacingTotal = spacing * (countValue - 1)
    return (countValue * selectedCircleSize) + spacingTotal + (horizontalPadding * 2)
  }
}
