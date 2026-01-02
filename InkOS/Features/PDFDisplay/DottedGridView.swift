// DottedGridView.swift
// UIView subclass that draws a tiled dotted grid pattern using CGPattern.

import UIKit

// UIView subclass that draws a tiled dotted grid pattern.
// Uses CGPattern for efficient drawing regardless of view size.
// The pattern is drawn in draw(_ rect:) method.
class DottedGridView: UIView, DottedGridViewProtocol {

  // Current grid configuration.
  // Changing this property triggers a redraw.
  var configuration: DottedGridConfiguration = .default {
    didSet {
      setNeedsDisplay()
    }
  }

  // Standard initializer for frame-based initialization.
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }

  // Required initializer for Interface Builder.
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  // Common setup for all initializers.
  private func setupView() {
    // Make the view's background transparent so the pattern draws cleanly.
    backgroundColor = .clear
    // Mark as opaque for performance since we fill the entire view.
    isOpaque = false
  }

  // Updates configuration and redraws.
  func updateConfiguration(_ configuration: DottedGridConfiguration) {
    self.configuration = configuration
  }

  // Override to draw the dotted grid pattern using CGPattern.
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }

    // Skip drawing if bounds have no area.
    guard bounds.width > 0 && bounds.height > 0 else { return }

    // Skip drawing if spacing is invalid.
    guard configuration.spacing > 0 else { return }

    // Draw dots using CGPattern for efficiency.
    drawDottedPattern(in: context, rect: rect)
  }

  // Draws the dotted pattern using CGPattern for efficient tiling.
  private func drawDottedPattern(in context: CGContext, rect: CGRect) {
    let spacing = configuration.spacing
    let dotSize = configuration.dotSize
    let color = configuration.color

    // Extract RGBA components from the color.
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    // Create the pattern cell callback info.
    // We pass the dot size and color components.
    var info = PatternInfo(dotSize: dotSize, red: red, green: green, blue: blue, alpha: alpha)

    // Define callbacks for pattern drawing.
    var callbacks = CGPatternCallbacks(
      version: 0,
      drawPattern: { infoPointer, cgContext in
        guard let infoPointer = infoPointer else { return }
        let patternInfo = infoPointer.assumingMemoryBound(to: PatternInfo.self).pointee
        let dotSize = patternInfo.dotSize

        // Set the fill color.
        cgContext.setFillColor(
          red: patternInfo.red,
          green: patternInfo.green,
          blue: patternInfo.blue,
          alpha: patternInfo.alpha
        )

        // Draw a dot centered in the pattern cell.
        // Offset by half the spacing so dots align to a grid.
        let dotRect = CGRect(
          x: 0,
          y: 0,
          width: dotSize,
          height: dotSize
        )
        cgContext.fillEllipse(in: dotRect)
      },
      releaseInfo: nil
    )

    // Create the pattern.
    // Pattern cell is spacing x spacing with one dot.
    guard let pattern = CGPattern(
      info: &info,
      bounds: CGRect(x: 0, y: 0, width: spacing, height: spacing),
      matrix: .identity,
      xStep: spacing,
      yStep: spacing,
      tiling: .constantSpacing,
      isColored: true,
      callbacks: &callbacks
    ) else { return }

    // Create pattern color space.
    guard let patternSpace = CGColorSpace(patternBaseSpace: nil) else { return }
    context.setFillColorSpace(patternSpace)

    // Set the pattern as fill color.
    var patternAlpha: CGFloat = 1.0
    context.setFillPattern(pattern, colorComponents: &patternAlpha)

    // Fill the entire rect with the pattern.
    context.fill(rect)
  }
}

// Helper struct to pass pattern drawing info through callbacks.
private struct PatternInfo {
  let dotSize: CGFloat
  let red: CGFloat
  let green: CGFloat
  let blue: CGFloat
  let alpha: CGFloat
}

// MARK: - Static Drawing Method

extension DottedGridView {

  // Draws a dotted grid pattern in the specified rect using the given context.
  // This static method can be called from any layer or view that needs the pattern.
  // Useful for PDFBackgroundLayer to draw spacer regions without instantiating a view.
  //
  // context: The CGContext to draw into.
  // rect: The area to fill with the pattern.
  // configuration: The dotted grid configuration (spacing, dot size, color).
  // scale: The current display scale (for retina rendering, typically UIScreen.main.scale).
  static func drawDottedPattern(
    in context: CGContext,
    rect: CGRect,
    configuration: DottedGridConfiguration,
    scale: CGFloat
  ) {
    // Skip drawing if rect has no area.
    guard rect.width > 0 && rect.height > 0 else { return }

    // Skip drawing if spacing is invalid.
    guard configuration.spacing > 0 else { return }

    let spacing = configuration.spacing
    let dotSize = configuration.dotSize
    let color = configuration.color

    // Extract RGBA components from the color.
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    // Create the pattern cell callback info.
    var info = PatternInfo(dotSize: dotSize, red: red, green: green, blue: blue, alpha: alpha)

    // Define callbacks for pattern drawing.
    var callbacks = CGPatternCallbacks(
      version: 0,
      drawPattern: { infoPointer, cgContext in
        guard let infoPointer = infoPointer else { return }
        let patternInfo = infoPointer.assumingMemoryBound(to: PatternInfo.self).pointee
        let dotSize = patternInfo.dotSize

        // Set the fill color.
        cgContext.setFillColor(
          red: patternInfo.red,
          green: patternInfo.green,
          blue: patternInfo.blue,
          alpha: patternInfo.alpha
        )

        // Draw a dot at the origin of the pattern cell.
        let dotRect = CGRect(
          x: 0,
          y: 0,
          width: dotSize,
          height: dotSize
        )
        cgContext.fillEllipse(in: dotRect)
      },
      releaseInfo: nil
    )

    // Create the pattern.
    // Pattern cell is spacing x spacing with one dot.
    guard let pattern = CGPattern(
      info: &info,
      bounds: CGRect(x: 0, y: 0, width: spacing, height: spacing),
      matrix: .identity,
      xStep: spacing,
      yStep: spacing,
      tiling: .constantSpacing,
      isColored: true,
      callbacks: &callbacks
    ) else { return }

    // Create pattern color space.
    guard let patternSpace = CGColorSpace(patternBaseSpace: nil) else { return }
    context.setFillColorSpace(patternSpace)

    // Set the pattern as fill color.
    var patternAlpha: CGFloat = 1.0
    context.setFillPattern(pattern, colorComponents: &patternAlpha)

    // Fill the specified rect with the pattern.
    context.fill(rect)
  }
}

/*
 ACCEPTANCE CRITERIA: DottedGridView.drawDottedPattern (static)

 SCENARIO: Draw pattern in standard rect
 GIVEN: A CGContext and rect of 100x100
  AND: Default configuration (spacing: 20, dotSize: 2)
 WHEN: drawDottedPattern is called
 THEN: Dots are drawn at 20pt intervals
  AND: Each dot has diameter 2
  AND: Pattern fills entire rect

 SCENARIO: Pattern respects configuration
 GIVEN: A custom configuration (spacing: 40, dotSize: 4, color: .blue)
 WHEN: drawDottedPattern is called
 THEN: Dots are spaced 40pt apart
  AND: Each dot has diameter 4
  AND: Dots are blue

 SCENARIO: Scale parameter available for retina
 GIVEN: scale = 2.0 (retina display)
 WHEN: drawDottedPattern is called
 THEN: Pattern can be rendered appropriately for the scale
  AND: (Scale is currently unused but available for future optimization)
*/

/*
 EDGE CASES: DottedGridView.drawDottedPattern (static)

 EDGE CASE: Zero-sized rect
 GIVEN: rect = CGRect.zero
 WHEN: drawDottedPattern is called
 THEN: Nothing is drawn
  AND: No crash occurs

 EDGE CASE: Zero spacing
 GIVEN: configuration with spacing = 0
 WHEN: drawDottedPattern is called
 THEN: Nothing is drawn (avoid division by zero)
  AND: No crash occurs

 EDGE CASE: Very large rect
 GIVEN: A rect of 10000x10000
 WHEN: drawDottedPattern is called
 THEN: CGPattern efficiently tiles the area
  AND: Performance is acceptable

 EDGE CASE: Negative spacing
 GIVEN: configuration with spacing = -10
 WHEN: drawDottedPattern is called
 THEN: Nothing is drawn (guard catches this)
  AND: No crash occurs
*/
