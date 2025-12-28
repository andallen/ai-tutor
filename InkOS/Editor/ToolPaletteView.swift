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
