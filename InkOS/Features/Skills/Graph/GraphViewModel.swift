// GraphViewModel.swift
// Implementation of the GraphViewModel that manages graph state and coordinate transforms.
// Bridges GraphSpecification data with SwiftUI rendering and user interactions.

import Combine
import Foundation
import SwiftUI

// MARK: - GraphViewModel

// Manages state for a GraphView including viewport, coordinate transforms, and user interactions.
@MainActor
final class GraphViewModel: GraphViewModelProtocol, ObservableObject {
  @Published var specification: GraphSpecification {
    didSet {
      // If specification changes, check if traced equation still exists.
      if let state = traceState {
        if !specification.equations.contains(where: { $0.id == state.equationID }) {
          traceState = nil
        }
      }
      // Store original viewport for reset.
      originalViewport = specification.viewport
      // Update current viewport if specification changed externally.
      currentViewport = MutableGraphViewport(from: specification.viewport)
    }
  }

  @Published var currentViewport: MutableGraphViewport
  @Published var viewSize: CGSize = CGSize(width: 400, height: 400)
  @Published var traceState: TraceState?

  // The original viewport from specification (for reset).
  private var originalViewport: GraphViewport

  // Parser for evaluating expressions.
  private let parser: MathExpressionParser

  // Cache for parsed expressions (keyed by expression string).
  private var parsedExpressionCache: [String: any ParsedExpressionProtocol] = [:]

  var isTracing: Bool {
    return traceState != nil
  }

  var sampleResolution: Int {
    // Calculate based on view width and samples per pixel.
    let baseSamples = Int(Double(viewSize.width) * GraphViewModelConstants.samplesPerPixel)
    return min(
      GraphViewModelConstants.maximumSampleResolution,
      max(GraphViewModelConstants.minimumSampleResolution, baseSamples)
    )
  }

  // Creates a graph view model with the given specification.
  init(specification: GraphSpecification, configuration: MathExpressionParserConfiguration = .default) {
    self.specification = specification
    self.originalViewport = specification.viewport
    self.currentViewport = MutableGraphViewport(from: specification.viewport)
    self.parser = MathExpressionParser(configuration: configuration)
  }

  // MARK: - Coordinate Transforms

  func graphToScreen(_ point: CoordinatePoint) -> CGPoint {
    let screenX = graphToScreenX(point.x)
    let screenY = graphToScreenY(point.y)
    return CGPoint(x: screenX, y: screenY)
  }

  func screenToGraph(_ point: CGPoint) -> CoordinatePoint {
    let graphX = screenToGraphX(point.x)
    let graphY = screenToGraphY(point.y)
    return CoordinatePoint(x: graphX, y: graphY)
  }

  func graphToScreenX(_ graphX: Double) -> CGFloat {
    guard currentViewport.width > 0 && viewSize.width > 0 else { return 0 }
    // Map graphX from [xMin, xMax] to [0, viewSize.width].
    let normalized = (graphX - currentViewport.xMin) / currentViewport.width
    return CGFloat(normalized) * viewSize.width
  }

  func graphToScreenY(_ graphY: Double) -> CGFloat {
    guard currentViewport.height > 0 && viewSize.height > 0 else { return 0 }
    // Map graphY from [yMin, yMax] to [viewSize.height, 0] (inverted).
    // Screen Y = 0 is top, graph Y increases upward.
    let normalized = (graphY - currentViewport.yMin) / currentViewport.height
    return viewSize.height - CGFloat(normalized) * viewSize.height
  }

  // Converts screen X coordinate to graph X coordinate.
  private func screenToGraphX(_ screenX: CGFloat) -> Double {
    guard viewSize.width > 0 else { return currentViewport.xMin }
    let normalized = Double(screenX) / Double(viewSize.width)
    return currentViewport.xMin + normalized * currentViewport.width
  }

  // Converts screen Y coordinate to graph Y coordinate.
  private func screenToGraphY(_ screenY: CGFloat) -> Double {
    guard viewSize.height > 0 else { return currentViewport.yMax }
    // Invert Y axis: screen Y = 0 is graph yMax, screen Y = height is graph yMin.
    let normalized = 1.0 - Double(screenY) / Double(viewSize.height)
    return currentViewport.yMin + normalized * currentViewport.height
  }

  // MARK: - Viewport Manipulation

  func pan(by delta: CGSize) {
    guard specification.interactivity.allowPan else { return }

    // Convert screen delta to graph delta.
    // Panning right (positive delta.width) shows more of the right side,
    // meaning viewport shifts left (xMin/xMax decrease).
    let graphDeltaX = -Double(delta.width) / Double(viewSize.width) * currentViewport.width
    // Panning up (negative delta.height in screen coords) shows more of top,
    // meaning viewport shifts up (yMin/yMax increase).
    let graphDeltaY = -Double(delta.height) / Double(viewSize.height) * currentViewport.height

    currentViewport.xMin += graphDeltaX
    currentViewport.xMax += graphDeltaX
    currentViewport.yMin += graphDeltaY
    currentViewport.yMax += graphDeltaY
  }

  func zoom(scale: CGFloat, around screenPoint: CGPoint) {
    guard specification.interactivity.allowZoom else { return }
    guard scale > 0 && scale != 1.0 else { return }

    // Clamp scale to reasonable bounds.
    let clampedScale = min(max(Double(scale), 0.01), 100.0)

    // Get the graph point that should stay fixed.
    let fixedPoint = screenToGraph(screenPoint)

    // Calculate new dimensions.
    let newWidth = currentViewport.width / clampedScale
    let newHeight = currentViewport.height / clampedScale

    // Enforce viewport size limits.
    let clampedWidth = min(
      max(newWidth, GraphViewModelConstants.minimumViewportSize),
      GraphViewModelConstants.maximumViewportSize
    )
    let clampedHeight = min(
      max(newHeight, GraphViewModelConstants.minimumViewportSize),
      GraphViewModelConstants.maximumViewportSize
    )

    // Calculate the fraction of the fixed point's position within old viewport.
    let fractionX = (fixedPoint.x - currentViewport.xMin) / currentViewport.width
    let fractionY = (fixedPoint.y - currentViewport.yMin) / currentViewport.height

    // Set new viewport bounds keeping the fixed point in the same relative position.
    currentViewport.xMin = fixedPoint.x - fractionX * clampedWidth
    currentViewport.xMax = currentViewport.xMin + clampedWidth
    currentViewport.yMin = fixedPoint.y - fractionY * clampedHeight
    currentViewport.yMax = currentViewport.yMin + clampedHeight
  }

  func resetViewport() {
    currentViewport = MutableGraphViewport(from: originalViewport)
  }

  // MARK: - Equation Sampling

  func sampleEquation(_ equation: GraphEquation) -> SampledCurve {
    // Return empty curve for hidden equations.
    guard equation.visible else {
      return SampledCurve(segments: [], equationID: equation.id)
    }

    switch equation.type {
    case .explicit:
      return sampleExplicitEquation(equation)
    case .parametric:
      return sampleParametricEquation(equation)
    case .polar:
      return samplePolarEquation(equation)
    case .implicit, .inequality:
      // Not implemented yet.
      return SampledCurve(segments: [], equationID: equation.id)
    }
  }

  // Samples an explicit equation (y = f(x)).
  private func sampleExplicitEquation(_ equation: GraphEquation) -> SampledCurve {
    guard let expression = equation.expression else {
      return SampledCurve(segments: [], equationID: equation.id)
    }

    // Parse expression.
    let parsedExpression: any ParsedExpressionProtocol
    do {
      parsedExpression = try getCachedExpression(expression)
    } catch {
      return SampledCurve(segments: [], equationID: equation.id)
    }

    // Determine x range.
    let xMin = equation.domain?.min ?? currentViewport.xMin
    let xMax = equation.domain?.max ?? currentViewport.xMax
    let step = (xMax - xMin) / Double(sampleResolution)

    var segments: [[CGPoint]] = []
    var currentSegment: [CGPoint] = []
    var lastY: Double?

    // Sample points.
    for i in 0...sampleResolution {
      let x = xMin + Double(i) * step
      let y = parsedExpression.evaluate(with: ["x": x])

      // Check for discontinuity.
      if let prevY = lastY {
        if isDiscontinuity(from: prevY, to: y) {
          // End current segment and start new one.
          if !currentSegment.isEmpty {
            segments.append(currentSegment)
            currentSegment = []
          }
        }
      }

      // Add point if valid.
      if y.isFinite {
        let screenPoint = graphToScreen(CoordinatePoint(x: x, y: y))
        currentSegment.append(screenPoint)
      } else if !currentSegment.isEmpty {
        // End segment at invalid point.
        segments.append(currentSegment)
        currentSegment = []
      }

      lastY = y
    }

    // Add final segment.
    if !currentSegment.isEmpty {
      segments.append(currentSegment)
    }

    return SampledCurve(segments: segments, equationID: equation.id)
  }

  // Samples a parametric equation (x = f(t), y = g(t)).
  private func sampleParametricEquation(_ equation: GraphEquation) -> SampledCurve {
    guard let xExpr = equation.xExpression,
          let yExpr = equation.yExpression
    else {
      return SampledCurve(segments: [], equationID: equation.id)
    }

    // Parse expressions.
    let parsedX: any ParsedExpressionProtocol
    let parsedY: any ParsedExpressionProtocol
    do {
      parsedX = try getCachedExpression(xExpr)
      parsedY = try getCachedExpression(yExpr)
    } catch {
      return SampledCurve(segments: [], equationID: equation.id)
    }

    // Determine t range.
    let tMin = equation.parameterRange?.min ?? 0
    let tMax = equation.parameterRange?.max ?? (2 * Double.pi)
    let step = (tMax - tMin) / Double(sampleResolution)

    var segments: [[CGPoint]] = []
    var currentSegment: [CGPoint] = []
    var lastX: Double?
    var lastY: Double?

    // Sample points.
    for i in 0...sampleResolution {
      let t = tMin + Double(i) * step
      let x = parsedX.evaluate(with: ["t": t])
      let y = parsedY.evaluate(with: ["t": t])

      // Check for discontinuity.
      if let prevX = lastX, let prevY = lastY {
        if isDiscontinuity(from: prevX, to: x) || isDiscontinuity(from: prevY, to: y) {
          if !currentSegment.isEmpty {
            segments.append(currentSegment)
            currentSegment = []
          }
        }
      }

      // Add point if valid.
      if x.isFinite && y.isFinite {
        let screenPoint = graphToScreen(CoordinatePoint(x: x, y: y))
        currentSegment.append(screenPoint)
      } else if !currentSegment.isEmpty {
        segments.append(currentSegment)
        currentSegment = []
      }

      lastX = x
      lastY = y
    }

    // Add final segment.
    if !currentSegment.isEmpty {
      segments.append(currentSegment)
    }

    return SampledCurve(segments: segments, equationID: equation.id)
  }

  // Samples a polar equation (r = f(theta)).
  private func samplePolarEquation(_ equation: GraphEquation) -> SampledCurve {
    guard let rExpr = equation.rExpression else {
      return SampledCurve(segments: [], equationID: equation.id)
    }

    // Parse expression.
    let parsedR: any ParsedExpressionProtocol
    do {
      parsedR = try getCachedExpression(rExpr)
    } catch {
      return SampledCurve(segments: [], equationID: equation.id)
    }

    // Determine theta range.
    let thetaMin = equation.parameterRange?.min ?? 0
    let thetaMax = equation.parameterRange?.max ?? (2 * Double.pi)
    let step = (thetaMax - thetaMin) / Double(sampleResolution)

    var segments: [[CGPoint]] = []
    var currentSegment: [CGPoint] = []
    var lastR: Double?

    // Sample points.
    for i in 0...sampleResolution {
      let theta = thetaMin + Double(i) * step
      let r = parsedR.evaluate(with: ["theta": theta])

      // Check for discontinuity.
      if let prevR = lastR {
        if isDiscontinuity(from: prevR, to: r) {
          if !currentSegment.isEmpty {
            segments.append(currentSegment)
            currentSegment = []
          }
        }
      }

      // Convert polar to Cartesian.
      if r.isFinite {
        let x = r * cos(theta)
        let y = r * sin(theta)
        let screenPoint = graphToScreen(CoordinatePoint(x: x, y: y))
        currentSegment.append(screenPoint)
      } else if !currentSegment.isEmpty {
        segments.append(currentSegment)
        currentSegment = []
      }

      lastR = r
    }

    // Add final segment.
    if !currentSegment.isEmpty {
      segments.append(currentSegment)
    }

    return SampledCurve(segments: segments, equationID: equation.id)
  }

  // Returns a cached parsed expression or parses it.
  private func getCachedExpression(_ expression: String) throws -> any ParsedExpressionProtocol {
    if let cached = parsedExpressionCache[expression] {
      return cached
    }
    let parsed = try parser.parse(expression)
    parsedExpressionCache[expression] = parsed
    return parsed
  }

  // Checks if there's a discontinuity between two consecutive y values.
  private func isDiscontinuity(from y1: Double, to y2: Double) -> Bool {
    // Check for sign change with large magnitude (asymptote).
    if (y1 > 0 && y2 < 0) || (y1 < 0 && y2 > 0) {
      let ratio = abs(y1 / y2)
      if ratio > GraphViewModelConstants.discontinuityThreshold
        || ratio < 1.0 / GraphViewModelConstants.discontinuityThreshold
      {
        return true
      }
    }

    // Check for sudden large jump.
    let delta = abs(y2 - y1)
    let avgMag = (abs(y1) + abs(y2)) / 2
    if avgMag > 1 && delta > avgMag * GraphViewModelConstants.discontinuityThreshold {
      return true
    }

    return false
  }

  // MARK: - Tracing

  func startTrace(at screenPoint: CGPoint) {
    guard specification.interactivity.allowTrace else { return }

    guard let (equationID, _) = closestEquation(to: screenPoint) else {
      return
    }

    // Find the equation and calculate trace position.
    guard let equation = specification.equations.first(where: { $0.id == equationID }) else {
      return
    }

    let graphPoint = screenToGraph(screenPoint)
    let traceResult = findTracePoint(for: equation, nearX: graphPoint.x)

    if let (position, paramValue, yVal) = traceResult {
      traceState = TraceState(
        equationID: equationID,
        position: position,
        parameterValue: paramValue,
        yValue: yVal
      )
    }
  }

  func updateTrace(to screenPoint: CGPoint) {
    guard let currentState = traceState else { return }

    guard let equation = specification.equations.first(where: { $0.id == currentState.equationID })
    else {
      endTrace()
      return
    }

    let graphPoint = screenToGraph(screenPoint)
    let traceResult = findTracePoint(for: equation, nearX: graphPoint.x)

    if let (position, paramValue, yVal) = traceResult {
      traceState = TraceState(
        equationID: currentState.equationID,
        position: position,
        parameterValue: paramValue,
        yValue: yVal
      )
    }
  }

  func endTrace() {
    traceState = nil
  }

  func closestEquation(to screenPoint: CGPoint) -> (equationID: String, distance: CGFloat)? {
    var closestID: String?
    var closestDistance: CGFloat = .infinity

    for equation in specification.equations where equation.visible {
      let sampledCurve = sampleEquation(equation)

      for segment in sampledCurve.segments {
        for point in segment {
          let distance = hypot(point.x - screenPoint.x, point.y - screenPoint.y)
          if distance < closestDistance {
            closestDistance = distance
            closestID = equation.id
          }
        }
      }
    }

    guard let id = closestID, closestDistance <= GraphViewModelConstants.traceSnapDistance else {
      return nil
    }

    return (id, closestDistance)
  }

  // Finds the trace point on an equation nearest to the given X coordinate.
  private func findTracePoint(for equation: GraphEquation, nearX: Double)
    -> (position: CoordinatePoint, parameterValue: Double, yValue: Double?)?
  {
    switch equation.type {
    case .explicit:
      guard let expression = equation.expression else { return nil }
      guard let parsed = try? getCachedExpression(expression) else { return nil }

      // Clamp x to domain.
      let xClamped = clampToDomain(nearX, domain: equation.domain)
      let y = parsed.evaluate(with: ["x": xClamped])

      guard y.isFinite else { return nil }
      return (CoordinatePoint(x: xClamped, y: y), xClamped, y)

    case .parametric:
      guard let xExpr = equation.xExpression,
            let yExpr = equation.yExpression
      else { return nil }
      guard let parsedX = try? getCachedExpression(xExpr),
            let parsedY = try? getCachedExpression(yExpr)
      else { return nil }

      // Find t that gives x closest to nearX.
      let tMin = equation.parameterRange?.min ?? 0
      let tMax = equation.parameterRange?.max ?? (2 * Double.pi)

      var bestT = tMin
      var bestDist = Double.infinity

      let searchResolution = 100
      let step = (tMax - tMin) / Double(searchResolution)
      for i in 0...searchResolution {
        let t = tMin + Double(i) * step
        let x = parsedX.evaluate(with: ["t": t])
        let dist = abs(x - nearX)
        if dist < bestDist {
          bestDist = dist
          bestT = t
        }
      }

      let x = parsedX.evaluate(with: ["t": bestT])
      let y = parsedY.evaluate(with: ["t": bestT])

      guard x.isFinite && y.isFinite else { return nil }
      return (CoordinatePoint(x: x, y: y), bestT, nil)

    case .polar:
      guard let rExpr = equation.rExpression else { return nil }
      guard let parsedR = try? getCachedExpression(rExpr) else { return nil }

      // Find theta that gives x closest to nearX.
      let thetaMin = equation.parameterRange?.min ?? 0
      let thetaMax = equation.parameterRange?.max ?? (2 * Double.pi)

      var bestTheta = thetaMin
      var bestDist = Double.infinity

      let searchResolution = 100
      let step = (thetaMax - thetaMin) / Double(searchResolution)
      for i in 0...searchResolution {
        let theta = thetaMin + Double(i) * step
        let r = parsedR.evaluate(with: ["theta": theta])
        let x = r * cos(theta)
        let dist = abs(x - nearX)
        if dist < bestDist {
          bestDist = dist
          bestTheta = theta
        }
      }

      let r = parsedR.evaluate(with: ["theta": bestTheta])
      let x = r * cos(bestTheta)
      let y = r * sin(bestTheta)

      guard r.isFinite else { return nil }
      return (CoordinatePoint(x: x, y: y), bestTheta, nil)

    case .implicit, .inequality:
      return nil
    }
  }

  // Clamps an x value to the equation's domain.
  private func clampToDomain(_ x: Double, domain: ParameterRange?) -> Double {
    guard let domain = domain else { return x }
    var result = x
    if let minX = domain.min { result = max(result, minX) }
    if let maxX = domain.max { result = min(result, maxX) }
    return result
  }
}
