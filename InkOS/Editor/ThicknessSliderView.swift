import UIKit

// Presents a glass pill with a draggable thickness slider.
final class ThicknessSliderView: UIView {

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
