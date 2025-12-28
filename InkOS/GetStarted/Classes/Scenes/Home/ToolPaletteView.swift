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
  // Notifies the host when a thickness value changes.
  var thicknessChanged: ((ToolSelection, CGFloat) -> Void)?
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
  // Sets the gap between the color palette and the thickness pill.
  private let thicknessSpacing: CGFloat = 8
  // Adds extra width so the thickness pill is longer than the color picker.
  private let thicknessExtraWidth: CGFloat = 70
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
  // Stores the highlighter toolbar button.
  private lazy var highlighterButton = makeToolbarButton(
    systemName: "highlighter",
    accessibilityLabel: "Highlighter",
    action: #selector(highlighterTapped)
  )
  // Stores the eraser toolbar button.
  private lazy var eraserButton = makeToolbarButton(
    systemName: "eraser",
    accessibilityLabel: "Eraser",
    action: #selector(eraserTapped)
  )

  // Stores the pen color selector.
  private let penColorOptions: [ColorOption]
  // Stores the highlighter color selector.
  private let highlighterColorOptions: [ColorOption]
  // Shows the active color options in a pill.
  private let colorPaletteView: ColorPaletteView
  // Shows the thickness slider in a pill.
  private let thicknessSliderView = ThicknessSliderView()

  // Tracks whether the toolbar is currently visible.
  private var isToolbarVisible = false
  // Tracks whether the color palette is currently visible.
  private var isColorPaletteVisible = false
  // Tracks whether the thickness slider is currently visible.
  private var isThicknessVisible = false
  // Tracks which tool is currently selected.
  private var selectedTool: ToolSelection = .pen
  // Tracks which pen color is currently selected.
  private var selectedPenColor: ColorOption
  // Tracks which highlighter color is currently selected.
  private var selectedHighlighterColor: ColorOption
  // Tracks the selected pen width in mm.
  private var selectedPenWidth: CGFloat = 0.65
  // Tracks the selected highlighter width in mm.
  private var selectedHighlighterWidth: CGFloat = 5.0
  // Defines the width range for the pen tool in mm.
  private let penWidthRange: ClosedRange<CGFloat> = 0.25...2.2
  // Defines the width range for the highlighter tool in mm.
  private let highlighterWidthRange: ClosedRange<CGFloat> = 1.67...15.0

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
      setThicknessVisible(false, animated: animated)
      animateToolbarVisibility(visible, animated: animated, completion: nil)
      return
    }
    updateColorPaletteOptions(animated: false)
    updateThicknessAppearance(animated: false)
    if animated {
      showAccessoryPillsAfterToolbar(animated: true)
    } else {
      updateAccessoryVisibilityForSelection(animated: false)
    }
    animateToolbarVisibility(visible, animated: animated, completion: nil)
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
    if thicknessSliderView.isHidden == false {
      hitFrames.append(thicknessSliderView.frame)
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
    (toolbarButtonWidth * 3) + (toolbarSpacing * 2) + (toolbarHorizontalPadding * 2)
  }

  // Computes the maximum size for the palette container.
  private var containerHeight: CGFloat {
    toolbarHeight + paletteSpacing + colorPaletteView.paletteHeight
      + thicknessSpacing + thicknessSliderView.sliderHeight
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
    configureThicknessSlider()
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
      effect.tintColor = UIColor.white.withAlphaComponent(0.35)
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

    // Orders the tools to match the updated toolbar layout.
    toolbarStackView.addArrangedSubview(penButton)
    toolbarStackView.addArrangedSubview(highlighterButton)
    toolbarStackView.addArrangedSubview(eraserButton)
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

  // Configures the thickness slider pill shown above the color palette.
  private func configureThicknessSlider() {
    thicknessSliderView.translatesAutoresizingMaskIntoConstraints = false
    thicknessSliderView.isHidden = true
    thicknessSliderView.valueChanged = { [weak self] value in
      self?.handleThicknessChange(value)
    }
    addSubview(thicknessSliderView)

    thicknessSliderView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    thicknessSliderView.bottomAnchor.constraint(
      equalTo: colorPaletteView.topAnchor,
      constant: -thicknessSpacing
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
    updateThicknessAppearance(animated: isThicknessVisible)
    if isToolbarVisible {
      switch selection {
      case .pen, .highlighter:
        // Keeps the palette fixed when switching between pen tools.
        setColorPaletteVisible(true, animated: false)
        setThicknessVisible(true, animated: false)
      case .eraser:
        setColorPaletteVisible(false, animated: true)
        setThicknessVisible(false, animated: true)
      }
    }
    selectionChanged?(selection)
  }

  // Applies the shared tint so the tools match the top bar buttons.
  private func updateItemAppearance() {
    let unselectedColor = accentColor.withAlphaComponent(0.45)
    penButton.tintColor = tint(for: selectedPenColor.color, isSelected: selectedTool == .pen)
    highlighterButton.tintColor =
      tint(for: selectedHighlighterColor.color, isSelected: selectedTool == .highlighter)
    eraserButton.tintColor = selectedTool == .eraser ? accentColor : unselectedColor
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
      break
    }
    updateThicknessWidth(animated: animated)
  }

  // Updates the thickness slider styling based on the active tool.
  private func updateThicknessAppearance(animated: Bool) {
    switch selectedTool {
    case .pen:
      thicknessSliderView.updateAppearance(
        color: selectedPenColor.color,
        minValue: penWidthRange.lowerBound,
        maxValue: penWidthRange.upperBound,
        value: selectedPenWidth,
        displayMinWidth: 2,
        displayMaxWidth: 10,
        animated: animated
      )
    case .highlighter:
      thicknessSliderView.updateAppearance(
        color: selectedHighlighterColor.color,
        minValue: highlighterWidthRange.lowerBound,
        maxValue: highlighterWidthRange.upperBound,
        value: selectedHighlighterWidth,
        displayMinWidth: 4,
        displayMaxWidth: 14,
        animated: animated
      )
    case .eraser:
      break
    }
  }

  // Updates the thickness pill width to stay slightly longer than the color picker.
  private func updateThicknessWidth(animated: Bool) {
    let baseWidth = max(colorPaletteView.currentWidth, colorPaletteView.maximumWidth)
    let targetWidth = max(0, baseWidth + thicknessExtraWidth)
    thicknessSliderView.updateWidth(targetWidth, animated: animated)
  }

  // Animates the toolbar in or out of view.
  private func animateToolbarVisibility(
    _ visible: Bool,
    animated: Bool,
    completion: (() -> Void)?
  ) {
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

    let animationCompletion: (Bool) -> Void = { [weak self] _ in
      guard let self = self else { return }
      self.toolbarView.isHidden = visible == false
      self.pencilToolbar.isHidden = visible
      completion?()
    }

    if animated {
      UIView.animate(
        withDuration: 0.22,
        delay: 0,
        options: [.curveEaseInOut],
        animations: animations,
        completion: animationCompletion
      )
    } else {
      animations()
      animationCompletion(true)
    }
  }

  // Staggers the accessory pills so they slide out just after the toolbar appears.
  private func showAccessoryPillsAfterToolbar(animated: Bool) {
    if animated {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
        self?.updateAccessoryVisibilityForSelection(animated: animated)
      }
    } else {
      updateAccessoryVisibilityForSelection(animated: false)
    }
  }

  // Keeps the accessory pill visibility aligned to the active tool.
  private func updateAccessoryVisibilityForSelection(animated: Bool) {
    switch selectedTool {
    case .pen, .highlighter:
      setColorPaletteVisible(true, animated: animated)
      setThicknessVisible(true, animated: animated)
    case .eraser:
      setColorPaletteVisible(false, animated: animated)
      setThicknessVisible(false, animated: animated)
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

  // Shows or hides the thickness slider pill.
  private func setThicknessVisible(_ visible: Bool, animated: Bool) {
    guard visible != isThicknessVisible else { return }
    isThicknessVisible = visible
    if visible {
      thicknessSliderView.isHidden = false
      thicknessSliderView.alpha = 0
      thicknessSliderView.transform = CGAffineTransform(translationX: 0, y: thicknessSpacing)
    }

    let animations = { [weak self] in
      guard let self = self else { return }
      self.thicknessSliderView.alpha = visible ? 1 : 0
      self.thicknessSliderView.transform =
        visible ? .identity : CGAffineTransform(translationX: 0, y: self.thicknessSpacing)
    }

    let completion: (Bool) -> Void = { [weak self] _ in
      guard let self = self else { return }
      if visible == false {
        self.thicknessSliderView.isHidden = true
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
    updateThicknessAppearance(animated: false)
  }

  // Updates the current thickness and notifies the host.
  private func handleThicknessChange(_ value: CGFloat) {
    switch selectedTool {
    case .pen:
      selectedPenWidth = value
      thicknessChanged?(.pen, value)
    case .highlighter:
      selectedHighlighterWidth = value
      thicknessChanged?(.highlighter, value)
    case .eraser:
      break
    }
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

// Presents a glass pill with a draggable thickness slider.
private final class ThicknessSliderView: UIView {

  // Notifies when the slider value changes.
  var valueChanged: ((CGFloat) -> Void)?

  // Defines the pill height to match the toolbar.
  let sliderHeight: CGFloat = 36

  // Holds the glass background for the pill.
  private let glassView = UIVisualEffectView()
  // Shows a thin stroke sample on the left.
  private let leftSampleView = StrokeSampleView()
  // Shows a thick stroke sample on the right.
  private let rightSampleView = StrokeSampleView()
  // Holds the track and thumb.
  private let trackContainer = UIView()
  // Draws the track line.
  private let trackView = UIView()
  // Provides the liquid glass thumb.
  private let thumbView = UIVisualEffectView()
  // Adds a solid overlay to boost thumb visibility.
  private let thumbOverlayView = UIView()

  // Sets the size of the thumb.
  private let thumbSize: CGFloat = 22
  // Sets the width of the sample views.
  private let sampleWidth: CGFloat = 4
  // Adds horizontal padding inside the pill.
  private let horizontalPadding: CGFloat = 14
  // Adds spacing between samples and the track.
  private let sampleSpacing: CGFloat = 12

  // Stores the minimum slider value.
  private var minValue: CGFloat = 0
  // Stores the maximum slider value.
  private var maxValue: CGFloat = 1
  // Stores the current slider value.
  private var value: CGFloat = 0.5
  // Stores the display width for the thin sample.
  private var displayMinWidth: CGFloat = 2
  // Stores the display width for the thick sample.
  private var displayMaxWidth: CGFloat = 8
  // Stores the active color for the samples.
  private var sampleColor: UIColor = .black

  // Stores the width constraint so it can be updated.
  private var widthConstraint: NSLayoutConstraint?
  // Stores the thumb position constraint.
  private var thumbCenterXConstraint: NSLayoutConstraint?

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureView()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateThumbConstraint()
  }

  // Updates the slider visuals and range.
  func updateAppearance(
    color: UIColor,
    minValue: CGFloat,
    maxValue: CGFloat,
    value: CGFloat,
    displayMinWidth: CGFloat,
    displayMaxWidth: CGFloat,
    animated: Bool
  ) {
    sampleColor = color
    self.minValue = minValue
    self.maxValue = maxValue
    self.displayMinWidth = displayMinWidth
    self.displayMaxWidth = displayMaxWidth
    leftSampleView.update(color: color, lineWidth: displayMinWidth)
    rightSampleView.update(color: color, lineWidth: displayMaxWidth)
    setValue(value, animated: animated, notify: false)
  }

  // Updates the width constraint for the pill.
  func updateWidth(_ width: CGFloat, animated: Bool) {
    let clampedWidth = max(width, sliderHeight)
    if animated {
      layoutIfNeeded()
      UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
        self.widthConstraint?.constant = clampedWidth
        self.layoutIfNeeded()
      }
    } else {
      widthConstraint?.constant = clampedWidth
    }
  }

  // Sets the slider value and updates the thumb position.
  private func setValue(_ value: CGFloat, animated: Bool, notify: Bool) {
    self.value = clampValue(value)
    updateThumbPosition(animated: animated)
    if notify {
      valueChanged?(self.value)
    }
  }

  // Builds the view hierarchy and layout.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)

    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    heightAnchor.constraint(equalToConstant: sliderHeight).isActive = true
    widthConstraint = widthAnchor.constraint(equalToConstant: sliderHeight)
    widthConstraint?.isActive = true

    configureSamplesAndTrack()
  }

  // Configures the glass background for the pill.
  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.layer.cornerRadius = sliderHeight / 2
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

  // Builds the slider layout inside the pill.
  private func configureSamplesAndTrack() {
    leftSampleView.translatesAutoresizingMaskIntoConstraints = false
    rightSampleView.translatesAutoresizingMaskIntoConstraints = false
    trackContainer.translatesAutoresizingMaskIntoConstraints = false
    glassView.contentView.addSubview(leftSampleView)
    glassView.contentView.addSubview(rightSampleView)
    glassView.contentView.addSubview(trackContainer)

    leftSampleView.leadingAnchor.constraint(
      equalTo: glassView.contentView.leadingAnchor,
      constant: horizontalPadding
    )
    .isActive = true
    leftSampleView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor).isActive =
      true
    leftSampleView.widthAnchor.constraint(equalToConstant: sampleWidth).isActive = true
    leftSampleView.heightAnchor.constraint(equalTo: glassView.contentView.heightAnchor).isActive =
      true

    rightSampleView.trailingAnchor.constraint(
      equalTo: glassView.contentView.trailingAnchor,
      constant: -horizontalPadding
    )
    .isActive = true
    rightSampleView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor)
      .isActive = true
    rightSampleView.widthAnchor.constraint(equalToConstant: sampleWidth).isActive = true
    rightSampleView.heightAnchor.constraint(equalTo: glassView.contentView.heightAnchor).isActive =
      true

    trackContainer.leadingAnchor.constraint(
      equalTo: leftSampleView.trailingAnchor,
      constant: sampleSpacing
    )
    .isActive = true
    trackContainer.trailingAnchor.constraint(
      equalTo: rightSampleView.leadingAnchor,
      constant: -sampleSpacing
    )
    .isActive = true
    trackContainer.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor).isActive =
      true
    trackContainer.heightAnchor.constraint(equalTo: glassView.contentView.heightAnchor).isActive =
      true

    configureTrack()
    configureThumb()
  }

  // Configures the slider track line.
  private func configureTrack() {
    trackView.translatesAutoresizingMaskIntoConstraints = false
    trackView.backgroundColor = UIColor.clear
    trackView.layer.cornerRadius = 1
    trackContainer.addSubview(trackView)

    trackView.leadingAnchor.constraint(equalTo: trackContainer.leadingAnchor).isActive = true
    trackView.trailingAnchor.constraint(equalTo: trackContainer.trailingAnchor).isActive = true
    trackView.centerYAnchor.constraint(equalTo: trackContainer.centerYAnchor).isActive = true
    trackView.heightAnchor.constraint(equalToConstant: 2).isActive = true

    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(trackTapped(_:)))
    trackContainer.addGestureRecognizer(tapRecognizer)
  }

  // Configures the draggable thumb.
  private func configureThumb() {
    thumbView.translatesAutoresizingMaskIntoConstraints = false
    thumbView.layer.cornerRadius = thumbSize / 2
    thumbView.layer.cornerCurve = .continuous
    thumbView.clipsToBounds = false
    thumbView.layer.shadowColor = UIColor.black.cgColor
    thumbView.layer.shadowOpacity = 0.2
    thumbView.layer.shadowRadius = 4
    thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = true
      effect.tintColor = UIColor.white.withAlphaComponent(0.9)
      thumbView.effect = effect
    } else {
      thumbView.effect = UIBlurEffect(style: .systemMaterial)
    }
    trackContainer.addSubview(thumbView)

    thumbCenterXConstraint = thumbView.centerXAnchor.constraint(equalTo: trackContainer.leadingAnchor)
    thumbCenterXConstraint?.isActive = true
    thumbView.centerYAnchor.constraint(equalTo: trackContainer.centerYAnchor).isActive = true
    thumbView.widthAnchor.constraint(equalToConstant: thumbSize).isActive = true
    thumbView.heightAnchor.constraint(equalToConstant: thumbSize).isActive = true

    thumbOverlayView.translatesAutoresizingMaskIntoConstraints = false
    thumbOverlayView.backgroundColor = UIColor.white.withAlphaComponent(0.98)
    thumbOverlayView.layer.cornerRadius = (thumbSize + 2) / 2
    thumbOverlayView.layer.cornerCurve = .continuous
    thumbOverlayView.layer.shadowColor = UIColor.black.cgColor
    thumbOverlayView.layer.shadowOpacity = 0.4
    thumbOverlayView.layer.shadowRadius = 7
    thumbOverlayView.layer.shadowOffset = CGSize(width: 0, height: 3)
    thumbOverlayView.isUserInteractionEnabled = false
    thumbView.contentView.addSubview(thumbOverlayView)

    thumbOverlayView.centerXAnchor.constraint(equalTo: thumbView.contentView.centerXAnchor)
      .isActive = true
    thumbOverlayView.centerYAnchor.constraint(equalTo: thumbView.contentView.centerYAnchor)
      .isActive = true
    thumbOverlayView.widthAnchor.constraint(equalToConstant: thumbSize + 2).isActive = true
    thumbOverlayView.heightAnchor.constraint(equalToConstant: thumbSize + 2).isActive = true

    let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(thumbPanned(_:)))
    thumbView.addGestureRecognizer(panRecognizer)
    thumbView.isUserInteractionEnabled = true
  }

  // Handles taps on the track.
  @objc private func trackTapped(_ recognizer: UITapGestureRecognizer) {
    let location = recognizer.location(in: trackContainer)
    updateValue(for: location.x, animated: true)
  }

  // Handles drag updates on the thumb.
  @objc private func thumbPanned(_ recognizer: UIPanGestureRecognizer) {
    let location = recognizer.location(in: trackContainer)
    updateValue(for: location.x, animated: false)
    updateThumbDragAppearance(state: recognizer.state)
  }

  // Updates the value based on a horizontal position.
  private func updateValue(for xPosition: CGFloat, animated: Bool) {
    let clampedProgress = normalizedProgress(forPosition: xPosition)
    let newValue = minValue + (maxValue - minValue) * clampedProgress
    setValue(newValue, animated: animated, notify: true)
  }

  // Converts an x position into a normalized progress value.
  private func normalizedProgress(forPosition xPosition: CGFloat) -> CGFloat {
    let inset = thumbSize / 2
    let availableWidth = max(trackContainer.bounds.width - inset * 2, 1)
    let clampedX = min(max(xPosition, inset), trackContainer.bounds.width - inset)
    return (clampedX - inset) / availableWidth
  }

  // Updates the thumb constraint without animation.
  private func updateThumbConstraint() {
    thumbCenterXConstraint?.constant = thumbOffset(for: value)
  }

  // Animates the thumb to the current value.
  private func updateThumbPosition(animated: Bool) {
    updateThumbConstraint()
    if animated {
      UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
        self.layoutIfNeeded()
      }
    } else {
      layoutIfNeeded()
    }
  }

  // Computes the thumb offset for the current value.
  private func thumbOffset(for value: CGFloat) -> CGFloat {
    let inset = thumbSize / 2
    let availableWidth = max(trackContainer.bounds.width - inset * 2, 1)
    let progress = normalizedProgress(forValue: value)
    return inset + (availableWidth * progress)
  }

  // Converts a value into a normalized progress value.
  private func normalizedProgress(forValue value: CGFloat) -> CGFloat {
    let range = max(maxValue - minValue, 0.0001)
    return min(max((value - minValue) / range, 0), 1)
  }

  // Clamps a value to the current range.
  private func clampValue(_ value: CGFloat) -> CGFloat {
    min(max(value, minValue), maxValue)
  }

  // Keeps the drag feedback subtle for the thumb.
  private func updateThumbDragAppearance(state: UIGestureRecognizer.State) {
    let scale: CGFloat
    let shadowOpacity: Float
    switch state {
    case .began, .changed:
      scale = 1.03
      shadowOpacity = 0
    default:
      scale = 1.0
      shadowOpacity = 0.4
    }
    UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseInOut]) {
      self.thumbView.transform = CGAffineTransform(scaleX: scale, y: scale)
      self.thumbOverlayView.layer.shadowOpacity = shadowOpacity
    }
  }
}

// Draws an angled stroke sample with soft edges.
private final class StrokeSampleView: UIView {

  // Renders the stroke path.
  private let lineLayer = CAShapeLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureView()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updatePath()
  }

  // Updates the sample color and thickness.
  func update(color: UIColor, lineWidth: CGFloat) {
    lineLayer.strokeColor = color.cgColor
    lineLayer.lineWidth = lineWidth
  }

  // Prepares the stroke layer.
  private func configureView() {
    backgroundColor = .clear
    lineLayer.fillColor = UIColor.clear.cgColor
    lineLayer.strokeColor = UIColor.black.cgColor
    lineLayer.lineCap = .round
    lineLayer.lineJoin = .round
    layer.addSublayer(lineLayer)
  }

  // Builds the angled stroke path.
  private func updatePath() {
    lineLayer.frame = bounds
    let minSide = min(bounds.width, bounds.height)
    let length = minSide * 0.9
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let angle = CGFloat.pi * 0.15
    let dx = cos(angle) * length / 2
    let dy = sin(angle) * length / 2
    let path = UIBezierPath()
    path.move(to: CGPoint(x: center.x - dx, y: center.y + dy))
    path.addLine(to: CGPoint(x: center.x + dx, y: center.y - dy))
    lineLayer.path = path.cgPath
  }
}
