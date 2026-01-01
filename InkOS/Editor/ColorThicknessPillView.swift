import UIKit

// Describes a preset color shown in the palette menu.
struct ColorOption {
  let name: String
  let hex: String
  let color: UIColor
}

// Presents color options and a thickness slider in a single glass pill.
// Combines the color palette and thickness slider into one unified control.
// This view contains extensive UI layout logic for the combined color and thickness control.
// Refactoring into smaller components would require significant architectural changes.
// swiftlint:disable type_body_length file_length
final class ColorThicknessPillView: UIView {

  // Notifies when the user picks a color.
  var colorSelectionChanged: ((ColorOption) -> Void)?
  // Notifies when the slider value changes.
  var thicknessChanged: ((CGFloat) -> Void)?

  // Holds the glass background for the combined pill.
  private let glassView = UIVisualEffectView()
  // Stacks the color row and slider row vertically.
  private let mainStackView = UIStackView()
  // Holds the color buttons in a horizontal row.
  private let colorStackView = UIStackView()
  // Holds the slider elements in a horizontal row.
  private let sliderStackView = UIStackView()

  // Shows a thin stroke sample on the left of the slider.
  private let leftSampleView = StrokeSampleView()
  // Shows a thick stroke sample on the right of the slider.
  private let rightSampleView = StrokeSampleView()
  // Holds the track and thumb.
  private let trackContainer = UIView()
  // Draws the track line.
  private let trackView = UIView()
  // Provides the liquid glass thumb.
  private let thumbView = UIVisualEffectView()
  // Adds a solid overlay to boost thumb visibility.
  private let thumbOverlayView = UIView()

  // Defines the pill height for each row.
  private let rowHeight: CGFloat = 36
  // Sets the base size for the color circles.
  private let circleSize: CGFloat = 18
  // Enlarges the selected circle for clarity.
  private let selectedCircleSize: CGFloat = 24
  // Controls spacing between the color circles.
  private let colorSpacing: CGFloat = 8
  // Adds horizontal padding inside the glass pill.
  private let horizontalPadding: CGFloat = 12
  // Sets the vertical padding between rows and edges.
  private let verticalPadding: CGFloat = 8
  // Sets the size of the slider thumb.
  private let thumbSize: CGFloat = 22
  // Sets the width of the sample views.
  private let sampleWidth: CGFloat = 16
  // Adds spacing between samples and the track.
  private let sampleSpacing: CGFloat = 12

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

  // Stores the minimum slider value.
  private var minValue: CGFloat = 0
  // Stores the maximum slider value.
  private var maxValue: CGFloat = 1
  // Stores the current slider value.
  private var sliderValue: CGFloat = 0.5
  // Stores the display width for the thin sample.
  private var displayMinWidth: CGFloat = 2
  // Stores the display width for the thick sample.
  private var displayMaxWidth: CGFloat = 8
  // Stores the active color for the samples.
  private var sampleColor: UIColor = .black
  // Stores the thumb position constraint.
  private var thumbCenterXConstraint: NSLayoutConstraint?

  init(maxOptionCount: Int) {
    self.maxOptionCount = maxOptionCount
    super.init(frame: .zero)
    configureView()
  }

  required init?(coder: NSCoder) {
    self.maxOptionCount = 5
    super.init(coder: coder)
    configureView()
  }

  // Exposes the total height for the combined pill.
  var pillHeight: CGFloat {
    // Includes two rows plus spacing between them and padding at top/bottom.
    (rowHeight * 2) + verticalPadding + (verticalPadding * 2)
  }

  // Exposes the widest size needed for the pill.
  var maximumWidth: CGFloat {
    width(for: maxOptionCount, selectedCount: 1)
  }

  // Exposes the current width applied to the pill.
  var currentWidth: CGFloat {
    widthConstraint?.constant ?? 0
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateThumbConstraint()
  }

  // Updates the color options and selection state.
  func updateColorOptions(_ options: [ColorOption], selectedHex: String, animated: Bool) {
    self.selectedHex = selectedHex
    rebuildColorButtons(with: options)
    updateColorSelection(for: selectedHex, animated: animated)
    updateWidthConstraint(for: options.count, animated: animated)
  }

  // Updates the slider visuals and range.
  // This method requires multiple parameters to configure the slider state in a single call.
  // swiftlint:disable:next function_parameter_count
  func updateSliderAppearance(
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
    setSliderValue(value, animated: animated, notify: false)
  }

  // Builds the layout for the combined pill.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)

    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

    heightAnchor.constraint(equalToConstant: pillHeight).isActive = true
    widthConstraint = widthAnchor.constraint(equalToConstant: maximumWidth)
    widthConstraint?.isActive = true

    configureMainStackView()
    configureColorRow()
    configureSliderRow()
  }

  // Configures the glass material background for the pill.
  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    // Uses a moderate corner radius for sharper corners while maintaining some curve.
    glassView.layer.cornerRadius = 18
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

  // Configures the main vertical stack that holds color and slider rows.
  private func configureMainStackView() {
    mainStackView.axis = .vertical
    mainStackView.alignment = .center
    mainStackView.spacing = verticalPadding
    mainStackView.translatesAutoresizingMaskIntoConstraints = false
    glassView.contentView.addSubview(mainStackView)

    mainStackView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor)
      .isActive = true
    mainStackView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor)
      .isActive = true
    // Adds vertical padding at top and bottom of the stack.
    mainStackView.topAnchor.constraint(
      equalTo: glassView.contentView.topAnchor,
      constant: verticalPadding
    ).isActive = true
    mainStackView.bottomAnchor.constraint(
      equalTo: glassView.contentView.bottomAnchor,
      constant: -verticalPadding
    ).isActive = true
  }

  // Configures the horizontal stack for color buttons.
  private func configureColorRow() {
    colorStackView.axis = .horizontal
    colorStackView.alignment = .center
    colorStackView.spacing = colorSpacing
    colorStackView.translatesAutoresizingMaskIntoConstraints = false
    mainStackView.addArrangedSubview(colorStackView)

    colorStackView.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
  }

  // Configures the horizontal layout for the slider elements.
  private func configureSliderRow() {
    sliderStackView.axis = .horizontal
    sliderStackView.alignment = .center
    sliderStackView.spacing = sampleSpacing
    sliderStackView.translatesAutoresizingMaskIntoConstraints = false
    mainStackView.addArrangedSubview(sliderStackView)

    sliderStackView.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
    // Stretches the slider row to fill the available width with padding.
    sliderStackView.leadingAnchor.constraint(
      equalTo: mainStackView.leadingAnchor,
      constant: horizontalPadding
    ).isActive = true
    sliderStackView.trailingAnchor.constraint(
      equalTo: mainStackView.trailingAnchor,
      constant: -horizontalPadding
    ).isActive = true

    configureSamplesAndTrack()
  }

  // Builds the slider layout inside the row.
  private func configureSamplesAndTrack() {
    leftSampleView.translatesAutoresizingMaskIntoConstraints = false
    rightSampleView.translatesAutoresizingMaskIntoConstraints = false
    trackContainer.translatesAutoresizingMaskIntoConstraints = false

    sliderStackView.addArrangedSubview(leftSampleView)
    sliderStackView.addArrangedSubview(trackContainer)
    sliderStackView.addArrangedSubview(rightSampleView)

    leftSampleView.widthAnchor.constraint(equalToConstant: sampleWidth).isActive = true
    leftSampleView.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

    rightSampleView.widthAnchor.constraint(equalToConstant: sampleWidth).isActive = true
    rightSampleView.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

    trackContainer.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
    // Allows the track container to fill remaining space with lower priority.
    trackContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    trackContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    configureTrack()
    configureThumb()
  }

  // Configures the slider track line.
  private func configureTrack() {
    trackView.translatesAutoresizingMaskIntoConstraints = false
    // Uses a faint grey line to indicate that this is a slider track.
    trackView.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.5)
    trackView.layer.cornerRadius = 1
    trackContainer.addSubview(trackView)

    // Insets the track line slightly on both sides while the thumb still uses the full container width.
    trackView.leadingAnchor.constraint(equalTo: trackContainer.leadingAnchor, constant: 6)
      .isActive = true
    trackView.trailingAnchor.constraint(equalTo: trackContainer.trailingAnchor, constant: -6)
      .isActive = true
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

    thumbCenterXConstraint = thumbView.centerXAnchor.constraint(
      equalTo: trackContainer.leadingAnchor)
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

  // Rebuilds the color button stack for the current options.
  private func rebuildColorButtons(with options: [ColorOption]) {
    colorStackView.arrangedSubviews.forEach { view in
      view.removeFromSuperview()
    }
    buttonOptions.removeAll()
    buttonConstraints.removeAll()

    options.forEach { option in
      let button = makeColorButton(for: option)
      colorStackView.addArrangedSubview(button)
      buttonOptions[button] = option
    }
    widthConstraint?.constant = width(for: options.count, selectedCount: 1)
  }

  // Updates the selection state for the color buttons.
  private func updateColorSelection(for hex: String, animated: Bool) {
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
    updateColorSelection(for: option.hex, animated: true)
    colorSelectionChanged?(option)
  }

  // Handles taps on the track.
  @objc private func trackTapped(_ recognizer: UITapGestureRecognizer) {
    let location = recognizer.location(in: trackContainer)
    updateSliderValue(for: location.x, animated: true)
  }

  // Handles drag updates on the thumb.
  @objc private func thumbPanned(_ recognizer: UIPanGestureRecognizer) {
    let location = recognizer.location(in: trackContainer)
    updateSliderValue(for: location.x, animated: false)
    updateThumbDragAppearance(state: recognizer.state)
  }

  // Updates the slider value based on a horizontal position.
  private func updateSliderValue(for xPosition: CGFloat, animated: Bool) {
    let clampedProgress = normalizedProgress(forPosition: xPosition)
    let newValue = minValue + (maxValue - minValue) * clampedProgress
    setSliderValue(newValue, animated: animated, notify: true)
  }

  // Sets the slider value and updates the thumb position.
  private func setSliderValue(_ value: CGFloat, animated: Bool, notify: Bool) {
    self.sliderValue = clampValue(value)
    updateThumbPosition(animated: animated)
    if notify {
      thicknessChanged?(self.sliderValue)
    }
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
    thumbCenterXConstraint?.constant = thumbOffset(for: sliderValue)
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

  // Computes the target width for the given option count.
  private func width(for count: Int, selectedCount: Int) -> CGFloat {
    guard count > 0 else { return 0 }
    let clampedSelectedCount = min(max(selectedCount, 0), count)
    let unselectedCount = count - clampedSelectedCount
    let spacingTotal = colorSpacing * CGFloat(count - 1)
    let circlesWidth =
      (CGFloat(clampedSelectedCount) * selectedCircleSize)
      + (CGFloat(unselectedCount) * circleSize)
    // Adds extra width for the slider row padding.
    let sliderPadding: CGFloat = 40
    return max(circlesWidth + spacingTotal + (horizontalPadding * 2), sliderPadding * 2)
  }

  // Keeps the pill width aligned to the content.
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
// swiftlint:enable type_body_length file_length
