// EquationRenderer.swift
// Implementation of the equation renderer that converts equations to SwiftUI paths.
// Handles sampling, discontinuity detection, and path building.

import Foundation
import SwiftUI

// MARK: - EquationRenderer

// Renders equations and graph elements to SwiftUI paths.
struct EquationRenderer: EquationRendererProtocol {

  // MARK: - renderEquation

  func renderEquation(
    _ equation: GraphEquation,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> EquationRenderResult {
    // Hidden equations return empty result (not an error).
    guard equation.visible else {
      return EquationRenderResult.success(
        equationID: equation.id,
        strokePaths: [],
        fillPath: nil,
        style: equation.style
      )
    }

    switch equation.type {
    case .explicit:
      return renderExplicitEquation(equation, viewport: viewport, viewSize: viewSize, parser: parser)
    case .parametric:
      return renderParametricEquation(equation, viewport: viewport, viewSize: viewSize, parser: parser)
    case .polar:
      return renderPolarEquation(equation, viewport: viewport, viewSize: viewSize, parser: parser)
    case .implicit:
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Implicit equations not yet supported",
        style: equation.style
      )
    case .inequality:
      return renderInequalityEquation(equation, viewport: viewport, viewSize: viewSize, parser: parser)
    }
  }

  // MARK: - Explicit Equation Rendering

  private func renderExplicitEquation(
    _ equation: GraphEquation,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> EquationRenderResult {
    guard let expression = equation.expression else {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Missing expression for explicit equation",
        style: equation.style
      )
    }

    // Parse the expression.
    let parsedExpression: any ParsedExpressionProtocol
    do {
      parsedExpression = try parser.parse(expression)
    } catch {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Parse error: \(error.localizedDescription)",
        style: equation.style
      )
    }

    // Sample points.
    let samples = sampleExplicitExpression(
      parsedExpression,
      domain: equation.domain,
      viewport: viewport,
      viewSize: viewSize
    )

    // Build paths from samples.
    let paths = buildPathsFromSamples(samples)

    return EquationRenderResult.success(
      equationID: equation.id,
      strokePaths: paths,
      fillPath: nil,
      style: equation.style
    )
  }

  // MARK: - Parametric Equation Rendering

  private func renderParametricEquation(
    _ equation: GraphEquation,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> EquationRenderResult {
    guard let xExpr = equation.xExpression,
          let yExpr = equation.yExpression
    else {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Missing x or y expression for parametric equation",
        style: equation.style
      )
    }

    // Parse the expressions.
    let parsedX: any ParsedExpressionProtocol
    let parsedY: any ParsedExpressionProtocol
    do {
      parsedX = try parser.parse(xExpr)
      parsedY = try parser.parse(yExpr)
    } catch {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Parse error: \(error.localizedDescription)",
        style: equation.style
      )
    }

    // Sample points.
    let samples = sampleParametricExpression(
      parsedX,
      parsedY,
      parameterRange: equation.parameterRange,
      viewport: viewport,
      viewSize: viewSize
    )

    // Build paths from samples.
    let paths = buildPathsFromSamples(samples)

    return EquationRenderResult.success(
      equationID: equation.id,
      strokePaths: paths,
      fillPath: nil,
      style: equation.style
    )
  }

  // MARK: - Polar Equation Rendering

  private func renderPolarEquation(
    _ equation: GraphEquation,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> EquationRenderResult {
    guard let rExpr = equation.rExpression else {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Missing r expression for polar equation",
        style: equation.style
      )
    }

    // Parse the expression.
    let parsedR: any ParsedExpressionProtocol
    do {
      parsedR = try parser.parse(rExpr)
    } catch {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Parse error: \(error.localizedDescription)",
        style: equation.style
      )
    }

    // Sample points.
    let samples = samplePolarExpression(
      parsedR,
      parameterRange: equation.parameterRange,
      viewport: viewport,
      viewSize: viewSize
    )

    // Build paths from samples.
    let paths = buildPathsFromSamples(samples)

    return EquationRenderResult.success(
      equationID: equation.id,
      strokePaths: paths,
      fillPath: nil,
      style: equation.style
    )
  }

  // MARK: - Inequality Rendering

  private func renderInequalityEquation(
    _ equation: GraphEquation,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> EquationRenderResult {
    // Render the boundary curve first using explicit rendering.
    guard let expression = equation.expression else {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Missing expression for inequality",
        style: equation.style
      )
    }

    let parsedExpression: any ParsedExpressionProtocol
    do {
      parsedExpression = try parser.parse(expression)
    } catch {
      return EquationRenderResult.failure(
        equationID: equation.id,
        error: "Parse error: \(error.localizedDescription)",
        style: equation.style
      )
    }

    // Sample points for boundary.
    let samples = sampleExplicitExpression(
      parsedExpression,
      domain: equation.domain,
      viewport: viewport,
      viewSize: viewSize
    )

    // Build stroke paths.
    let strokePaths = buildPathsFromSamples(samples)

    // Build fill path if fillRegion is enabled.
    var fillPath: SwiftUI.Path?
    if equation.fillRegion == true && !samples.isEmpty {
      fillPath = buildFillPath(
        samples: samples,
        fillBelow: true,  // TODO: determine from inequality direction
        viewport: viewport,
        viewSize: viewSize
      )
    }

    return EquationRenderResult.success(
      equationID: equation.id,
      strokePaths: strokePaths,
      fillPath: fillPath,
      style: equation.style
    )
  }

  // MARK: - Sampling Methods

  private func sampleExplicitExpression(
    _ expression: any ParsedExpressionProtocol,
    domain: ParameterRange?,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> [[CGPoint]] {
    let sampleCount = calculateSampleCount(viewSize: viewSize)

    // Determine x range.
    let xMin = domain?.min ?? viewport.xMin
    let xMax = domain?.max ?? viewport.xMax
    let step = (xMax - xMin) / Double(sampleCount)

    var segments: [[CGPoint]] = []
    var currentSegment: [CGPoint] = []
    var lastY: Double?

    for i in 0...sampleCount {
      let x = xMin + Double(i) * step
      let y = expression.evaluate(with: ["x": x])

      // Check for discontinuity.
      if let prevY = lastY {
        if isDiscontinuity(from: prevY, to: y) {
          if !currentSegment.isEmpty {
            segments.append(currentSegment)
            currentSegment = []
          }
        }
      }

      // Add point if valid.
      if y.isFinite {
        let screenPoint = graphToScreen(
          x: x, y: y, viewport: viewport, viewSize: viewSize
        )
        currentSegment.append(screenPoint)
      } else if !currentSegment.isEmpty {
        segments.append(currentSegment)
        currentSegment = []
      }

      lastY = y
    }

    if !currentSegment.isEmpty {
      segments.append(currentSegment)
    }

    return segments
  }

  private func sampleParametricExpression(
    _ xExpr: any ParsedExpressionProtocol,
    _ yExpr: any ParsedExpressionProtocol,
    parameterRange: ParameterRange?,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> [[CGPoint]] {
    let sampleCount = calculateSampleCount(viewSize: viewSize)

    let tMin = parameterRange?.min ?? 0
    let tMax = parameterRange?.max ?? (2 * Double.pi)
    let step = (tMax - tMin) / Double(sampleCount)

    var segments: [[CGPoint]] = []
    var currentSegment: [CGPoint] = []
    var lastX: Double?
    var lastY: Double?

    for i in 0...sampleCount {
      let t = tMin + Double(i) * step
      let x = xExpr.evaluate(with: ["t": t])
      let y = yExpr.evaluate(with: ["t": t])

      // Check for discontinuity.
      if let prevX = lastX, let prevY = lastY {
        if isDiscontinuity(from: prevX, to: x) || isDiscontinuity(from: prevY, to: y) {
          if !currentSegment.isEmpty {
            segments.append(currentSegment)
            currentSegment = []
          }
        }
      }

      if x.isFinite && y.isFinite {
        let screenPoint = graphToScreen(
          x: x, y: y, viewport: viewport, viewSize: viewSize
        )
        currentSegment.append(screenPoint)
      } else if !currentSegment.isEmpty {
        segments.append(currentSegment)
        currentSegment = []
      }

      lastX = x
      lastY = y
    }

    if !currentSegment.isEmpty {
      segments.append(currentSegment)
    }

    return segments
  }

  private func samplePolarExpression(
    _ rExpr: any ParsedExpressionProtocol,
    parameterRange: ParameterRange?,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> [[CGPoint]] {
    let sampleCount = calculateSampleCount(viewSize: viewSize)

    let thetaMin = parameterRange?.min ?? 0
    let thetaMax = parameterRange?.max ?? (2 * Double.pi)
    let step = (thetaMax - thetaMin) / Double(sampleCount)

    var segments: [[CGPoint]] = []
    var currentSegment: [CGPoint] = []
    var lastR: Double?

    for i in 0...sampleCount {
      let theta = thetaMin + Double(i) * step
      let r = rExpr.evaluate(with: ["theta": theta])

      // Check for discontinuity.
      if let prevR = lastR {
        if isDiscontinuity(from: prevR, to: r) {
          if !currentSegment.isEmpty {
            segments.append(currentSegment)
            currentSegment = []
          }
        }
      }

      if r.isFinite {
        // Convert polar to Cartesian.
        let x = r * cos(theta)
        let y = r * sin(theta)
        let screenPoint = graphToScreen(
          x: x, y: y, viewport: viewport, viewSize: viewSize
        )
        currentSegment.append(screenPoint)
      } else if !currentSegment.isEmpty {
        segments.append(currentSegment)
        currentSegment = []
      }

      lastR = r
    }

    if !currentSegment.isEmpty {
      segments.append(currentSegment)
    }

    return segments
  }

  // MARK: - Path Building

  private func buildPathsFromSamples(_ samples: [[CGPoint]]) -> [SwiftUI.Path] {
    return samples.compactMap { segment -> SwiftUI.Path? in
      guard segment.count >= 2 else { return nil }

      var path = SwiftUI.Path()
      path.move(to: segment[0])
      for i in 1..<segment.count {
        path.addLine(to: segment[i])
      }
      return path
    }
  }

  private func buildFillPath(
    samples: [[CGPoint]],
    fillBelow: Bool,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> SwiftUI.Path {
    var fillPath = SwiftUI.Path()

    // Boundary Y (screen coords): bottom of view for fillBelow, top for fillAbove.
    let boundaryY = fillBelow ? viewSize.height : 0

    for segment in samples where segment.count >= 2 {
      // Start at bottom-left of segment.
      let firstPoint = segment[0]
      fillPath.move(to: CGPoint(x: firstPoint.x, y: boundaryY))

      // Go up to first curve point.
      fillPath.addLine(to: firstPoint)

      // Follow curve.
      for i in 1..<segment.count {
        fillPath.addLine(to: segment[i])
      }

      // Go down to bottom.
      let lastPoint = segment[segment.count - 1]
      fillPath.addLine(to: CGPoint(x: lastPoint.x, y: boundaryY))

      // Close path.
      fillPath.closeSubpath()
    }

    return fillPath
  }

  // MARK: - Axes Rendering

  func renderAxes(
    _ axes: GraphAxes,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> (xAxis: SwiftUI.Path?, yAxis: SwiftUI.Path?) {
    var xAxisPath: SwiftUI.Path?
    var yAxisPath: SwiftUI.Path?

    // Render X axis if y=0 is visible and axis is enabled.
    if axes.x.showAxis && viewport.yMin <= 0 && viewport.yMax >= 0 {
      let screenY = graphToScreenY(0, viewport: viewport, viewSize: viewSize)
      var path = SwiftUI.Path()
      path.move(to: CGPoint(x: 0, y: screenY))
      path.addLine(to: CGPoint(x: viewSize.width, y: screenY))
      xAxisPath = path
    }

    // Render Y axis if x=0 is visible and axis is enabled.
    if axes.y.showAxis && viewport.xMin <= 0 && viewport.xMax >= 0 {
      let screenX = graphToScreenX(0, viewport: viewport, viewSize: viewSize)
      var path = SwiftUI.Path()
      path.move(to: CGPoint(x: screenX, y: 0))
      path.addLine(to: CGPoint(x: screenX, y: viewSize.height))
      yAxisPath = path
    }

    return (xAxisPath, yAxisPath)
  }

  // MARK: - Grid Rendering

  func renderGrid(
    _ axes: GraphAxes,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> (vertical: [SwiftUI.Path], horizontal: [SwiftUI.Path]) {
    var verticalPaths: [SwiftUI.Path] = []
    var horizontalPaths: [SwiftUI.Path] = []

    // Render vertical grid lines (perpendicular to X axis).
    if axes.x.showGrid {
      let spacing = calculateGridSpacing(
        min: viewport.xMin,
        max: viewport.xMax,
        maxLines: EquationRendererConstants.maxGridLines
      )

      let startX = (viewport.xMin / spacing).rounded(.up) * spacing
      var x = startX
      while x <= viewport.xMax {
        let screenX = graphToScreenX(x, viewport: viewport, viewSize: viewSize)
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: screenX, y: 0))
        path.addLine(to: CGPoint(x: screenX, y: viewSize.height))
        verticalPaths.append(path)
        x += spacing
      }
    }

    // Render horizontal grid lines (perpendicular to Y axis).
    if axes.y.showGrid {
      let spacing = calculateGridSpacing(
        min: viewport.yMin,
        max: viewport.yMax,
        maxLines: EquationRendererConstants.maxGridLines
      )

      let startY = (viewport.yMin / spacing).rounded(.up) * spacing
      var y = startY
      while y <= viewport.yMax {
        let screenY = graphToScreenY(y, viewport: viewport, viewSize: viewSize)
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: screenY))
        path.addLine(to: CGPoint(x: viewSize.width, y: screenY))
        horizontalPaths.append(path)
        y += spacing
      }
    }

    return (verticalPaths, horizontalPaths)
  }

  // MARK: - Tick Calculation

  func calculateTicks(
    _ axis: AxisConfiguration,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    isXAxis: Bool
  ) -> [AxisTick] {
    guard axis.tickLabels else { return [] }

    let min = isXAxis ? viewport.xMin : viewport.yMin
    let max = isXAxis ? viewport.xMax : viewport.yMax
    let screenSize = isXAxis ? viewSize.width : viewSize.height

    let spacing = calculateTickSpacing(min: min, max: max, screenSize: screenSize)
    let startValue = (min / spacing).rounded(.up) * spacing

    var ticks: [AxisTick] = []
    var value = startValue

    while value <= max {
      let screenPos: CGFloat
      if isXAxis {
        screenPos = graphToScreenX(value, viewport: viewport, viewSize: viewSize)
      } else {
        screenPos = graphToScreenY(value, viewport: viewport, viewSize: viewSize)
      }

      let label = formatTickLabel(value)
      ticks.append(AxisTick(value: value, screenPosition: screenPos, label: label))
      value += spacing
    }

    return ticks
  }

  // MARK: - Point Rendering

  func renderPoint(
    _ point: GraphPoint,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> RenderedPoint {
    let screenPos = graphToScreen(
      x: point.x,
      y: point.y,
      viewport: viewport,
      viewSize: viewSize
    )

    return RenderedPoint(
      pointID: point.id,
      screenPosition: screenPos,
      style: point.style,
      label: point.label
    )
  }

  // MARK: - Annotation Rendering

  func renderAnnotation(
    _ annotation: GraphAnnotation,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> RenderedAnnotation {
    let screenPos = graphToScreen(
      x: annotation.position.x,
      y: annotation.position.y,
      viewport: viewport,
      viewSize: viewSize
    )

    return RenderedAnnotation(
      type: annotation.type,
      screenPosition: screenPos,
      text: annotation.text,
      anchor: annotation.anchor ?? .center
    )
  }

  // MARK: - Full Graph Rendering

  func renderGraph(
    _ specification: GraphSpecification,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> RenderedGraph {
    // Render equations.
    var equations: [String: EquationRenderResult] = [:]
    for equation in specification.equations {
      let result = renderEquation(equation, viewport: viewport, viewSize: viewSize, parser: parser)
      equations[equation.id] = result
    }

    // Render axes.
    let (xAxisPath, yAxisPath) = renderAxes(specification.axes, viewport: viewport, viewSize: viewSize)

    // Render grid.
    let (verticalGrid, horizontalGrid) = renderGrid(
      specification.axes,
      viewport: viewport,
      viewSize: viewSize
    )

    // Render points.
    let renderedPoints = (specification.points ?? []).map { point in
      renderPoint(point, viewport: viewport, viewSize: viewSize)
    }

    // Render annotations.
    let renderedAnnotations = (specification.annotations ?? []).map { annotation in
      renderAnnotation(annotation, viewport: viewport, viewSize: viewSize)
    }

    // Calculate ticks.
    let xTicks = calculateTicks(
      specification.axes.x,
      viewport: viewport,
      viewSize: viewSize,
      isXAxis: true
    )
    let yTicks = calculateTicks(
      specification.axes.y,
      viewport: viewport,
      viewSize: viewSize,
      isXAxis: false
    )

    return RenderedGraph(
      equations: equations,
      xAxisPath: xAxisPath,
      yAxisPath: yAxisPath,
      verticalGridPaths: verticalGrid,
      horizontalGridPaths: horizontalGrid,
      pointPositions: renderedPoints,
      annotations: renderedAnnotations,
      xAxisTicks: xTicks,
      yAxisTicks: yTicks
    )
  }

  // MARK: - Coordinate Transforms

  private func graphToScreen(
    x: Double,
    y: Double,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> CGPoint {
    let screenX = graphToScreenX(x, viewport: viewport, viewSize: viewSize)
    let screenY = graphToScreenY(y, viewport: viewport, viewSize: viewSize)
    return CGPoint(x: screenX, y: screenY)
  }

  private func graphToScreenX(
    _ graphX: Double,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> CGFloat {
    guard viewport.width > 0 && viewSize.width > 0 else { return 0 }
    let normalized = (graphX - viewport.xMin) / viewport.width
    return CGFloat(normalized) * viewSize.width
  }

  private func graphToScreenY(
    _ graphY: Double,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> CGFloat {
    guard viewport.height > 0 && viewSize.height > 0 else { return 0 }
    // Screen Y is inverted relative to graph Y.
    let normalized = (graphY - viewport.yMin) / viewport.height
    return viewSize.height - CGFloat(normalized) * viewSize.height
  }

  // MARK: - Helper Methods

  private func calculateSampleCount(viewSize: CGSize) -> Int {
    let baseSamples = Int(Double(viewSize.width) * 0.5)
    return min(
      EquationRendererConstants.maximumSamples,
      max(EquationRendererConstants.minimumSamples, baseSamples)
    )
  }

  private func isDiscontinuity(from y1: Double, to y2: Double) -> Bool {
    // Check for sign change with large magnitude.
    if (y1 > 0 && y2 < 0) || (y1 < 0 && y2 > 0) {
      let ratio = abs(y1 / y2)
      if ratio > EquationRendererConstants.discontinuityThreshold
        || ratio < 1.0 / EquationRendererConstants.discontinuityThreshold
      {
        return true
      }
    }

    // Check for sudden large jump.
    let delta = abs(y2 - y1)
    let avgMag = (abs(y1) + abs(y2)) / 2
    if avgMag > 1 && delta > avgMag * EquationRendererConstants.discontinuityThreshold {
      return true
    }

    return false
  }

  private func calculateGridSpacing(min: Double, max: Double, maxLines: Int) -> Double {
    let range = max - min
    let idealSpacing = range / Double(maxLines)

    // Round to nice number (1, 2, 5, 10, etc.).
    let magnitude = pow(10, floor(log10(idealSpacing)))
    let normalized = idealSpacing / magnitude

    let niceNumber: Double
    if normalized <= 1.5 {
      niceNumber = 1
    } else if normalized <= 3 {
      niceNumber = 2
    } else if normalized <= 7 {
      niceNumber = 5
    } else {
      niceNumber = 10
    }

    return niceNumber * magnitude
  }

  private func calculateTickSpacing(min: Double, max: Double, screenSize: CGFloat) -> Double {
    let maxTicks = Swift.max(1, Int(screenSize / EquationRendererConstants.minTickSpacing))
    return calculateGridSpacing(min: min, max: max, maxLines: maxTicks)
  }

  private func formatTickLabel(_ value: Double) -> String {
    // Use scientific notation for very large or very small numbers.
    if value != 0 && (abs(value) >= 1e6 || abs(value) < 1e-4) {
      return String(format: "%.2e", value)
    }

    // Remove trailing zeros.
    let formatted = String(format: "%.\(EquationRendererConstants.tickLabelPrecision)g", value)
    return formatted
  }
}

// MARK: - PathBuilder Implementation

struct PathBuilder: PathBuilderProtocol {
  func buildPaths(from points: [CGPoint]) -> [SwiftUI.Path] {
    // Split on invalid points.
    var segments: [[CGPoint]] = []
    var currentSegment: [CGPoint] = []

    for point in points {
      if point.x.isFinite && point.y.isFinite {
        currentSegment.append(point)
      } else if !currentSegment.isEmpty {
        segments.append(currentSegment)
        currentSegment = []
      }
    }

    if !currentSegment.isEmpty {
      segments.append(currentSegment)
    }

    // Build paths from segments.
    return segments.compactMap { segment -> SwiftUI.Path? in
      guard segment.count >= 2 else { return nil }
      var path = SwiftUI.Path()
      path.move(to: segment[0])
      for i in 1..<segment.count {
        path.addLine(to: segment[i])
      }
      return path
    }
  }

  func buildAdaptivePaths(
    from points: [CGPoint],
    evaluator: @Sendable (CGFloat) -> CGPoint?
  ) -> [SwiftUI.Path] {
    // For now, use basic path building.
    // Adaptive sampling could be added later for high-curvature regions.
    return buildPaths(from: points)
  }
}

// MARK: - FillRegionBuilder Implementation

struct FillRegionBuilder: FillRegionBuilderProtocol {
  func buildFillBelow(
    curvePaths: [SwiftUI.Path],
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> SwiftUI.Path {
    var fillPath = SwiftUI.Path()
    let boundaryY = viewSize.height

    for curvePath in curvePaths {
      // Get bounding box to determine x range.
      let bounds = curvePath.boundingRect
      guard !bounds.isEmpty else { continue }

      // Build fill region.
      fillPath.move(to: CGPoint(x: bounds.minX, y: boundaryY))
      fillPath.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
      fillPath.addPath(curvePath)
      fillPath.addLine(to: CGPoint(x: bounds.maxX, y: boundaryY))
      fillPath.closeSubpath()
    }

    return fillPath
  }

  func buildFillAbove(
    curvePaths: [SwiftUI.Path],
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> SwiftUI.Path {
    var fillPath = SwiftUI.Path()
    let boundaryY: CGFloat = 0

    for curvePath in curvePaths {
      let bounds = curvePath.boundingRect
      guard !bounds.isEmpty else { continue }

      fillPath.move(to: CGPoint(x: bounds.minX, y: boundaryY))
      fillPath.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY))
      fillPath.addPath(curvePath)
      fillPath.addLine(to: CGPoint(x: bounds.maxX, y: boundaryY))
      fillPath.closeSubpath()
    }

    return fillPath
  }
}
