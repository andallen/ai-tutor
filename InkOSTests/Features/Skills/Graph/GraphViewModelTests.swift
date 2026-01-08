// GraphViewModelTests.swift
// Tests for GraphViewModel covering coordinate transforms, pan/zoom operations,
// viewport manipulation, equation sampling, and tracing functionality.
// These tests validate the contract defined in GraphViewModelContract.swift.

import Combine
import XCTest

@testable import InkOS

// MARK: - CoordinatePoint Tests

final class CoordinatePointTests: XCTestCase {

  func testOrigin_createsPointAtZeroZero() {
    // Arrange & Act
    let origin = CoordinatePoint.origin

    // Assert
    XCTAssertEqual(origin.x, 0.0, accuracy: 1e-15)
    XCTAssertEqual(origin.y, 0.0, accuracy: 1e-15)
  }

  func testInit_withDoubleCoordinates_createsPoint() {
    // Arrange & Act
    let point = CoordinatePoint(x: 3.5, y: -2.0)

    // Assert
    XCTAssertEqual(point.x, 3.5, accuracy: 1e-15)
    XCTAssertEqual(point.y, -2.0, accuracy: 1e-15)
  }

  func testInit_withCGFloatCoordinates_createsPoint() {
    // Arrange
    let cgX: CGFloat = 5.5
    let cgY: CGFloat = 7.25

    // Act
    let point = CoordinatePoint(x: cgX, y: cgY)

    // Assert
    XCTAssertEqual(point.x, 5.5, accuracy: 1e-15)
    XCTAssertEqual(point.y, 7.25, accuracy: 1e-15)
  }

  func testEquatable_sameCoordinates_returnsTrue() {
    // Arrange
    let point1 = CoordinatePoint(x: 3.0, y: 4.0)
    let point2 = CoordinatePoint(x: 3.0, y: 4.0)

    // Act & Assert
    XCTAssertEqual(point1, point2)
  }

  func testEquatable_differentCoordinates_returnsFalse() {
    // Arrange
    let point1 = CoordinatePoint(x: 3.0, y: 4.0)
    let point2 = CoordinatePoint(x: 3.0, y: 5.0)

    // Act & Assert
    XCTAssertNotEqual(point1, point2)
  }
}

// MARK: - MutableGraphViewport Tests

final class MutableGraphViewportTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_fromGraphViewport_copiesAllValues() {
    // Arrange
    let original = GraphViewport(
      xMin: -10,
      xMax: 10,
      yMin: -5,
      yMax: 5,
      aspectRatio: .equal
    )

    // Act
    let mutable = MutableGraphViewport(from: original)

    // Assert
    XCTAssertEqual(mutable.xMin, -10, accuracy: 1e-15)
    XCTAssertEqual(mutable.xMax, 10, accuracy: 1e-15)
    XCTAssertEqual(mutable.yMin, -5, accuracy: 1e-15)
    XCTAssertEqual(mutable.yMax, 5, accuracy: 1e-15)
    XCTAssertEqual(mutable.aspectRatio, .equal)
  }

  // MARK: - Computed Properties Tests

  func testWidth_returnsXRange() {
    // Arrange
    let viewport = MutableGraphViewport(
      from: GraphViewport(xMin: -10, xMax: 10, yMin: -5, yMax: 5, aspectRatio: .auto)
    )

    // Act & Assert
    XCTAssertEqual(viewport.width, 20.0, accuracy: 1e-15)
  }

  func testHeight_returnsYRange() {
    // Arrange
    let viewport = MutableGraphViewport(
      from: GraphViewport(xMin: -10, xMax: 10, yMin: -5, yMax: 5, aspectRatio: .auto)
    )

    // Act & Assert
    XCTAssertEqual(viewport.height, 10.0, accuracy: 1e-15)
  }

  func testCenter_returnsMidpoint() {
    // Arrange
    let viewport = MutableGraphViewport(
      from: GraphViewport(xMin: 0, xMax: 10, yMin: 0, yMax: 10, aspectRatio: .auto)
    )

    // Act
    let center = viewport.center

    // Assert
    XCTAssertEqual(center.x, 5.0, accuracy: 1e-15)
    XCTAssertEqual(center.y, 5.0, accuracy: 1e-15)
  }

  func testCenter_asymmetricViewport_returnsCorrectMidpoint() {
    // Arrange
    let viewport = MutableGraphViewport(
      from: GraphViewport(xMin: -20, xMax: 10, yMin: -5, yMax: 15, aspectRatio: .auto)
    )

    // Act
    let center = viewport.center

    // Assert
    XCTAssertEqual(center.x, -5.0, accuracy: 1e-15)
    XCTAssertEqual(center.y, 5.0, accuracy: 1e-15)
  }

  // MARK: - Mutation Tests

  func testMutation_modifyXMin_updatesWidth() {
    // Arrange
    var viewport = MutableGraphViewport(
      from: GraphViewport(xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto)
    )
    XCTAssertEqual(viewport.width, 20.0, accuracy: 1e-15)

    // Act
    viewport.xMin = -20

    // Assert
    XCTAssertEqual(viewport.width, 30.0, accuracy: 1e-15)
  }

  func testMutation_modifyYMax_updatesHeight() {
    // Arrange
    var viewport = MutableGraphViewport(
      from: GraphViewport(xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto)
    )
    XCTAssertEqual(viewport.height, 20.0, accuracy: 1e-15)

    // Act
    viewport.yMax = 20

    // Assert
    XCTAssertEqual(viewport.height, 30.0, accuracy: 1e-15)
  }

  // MARK: - Conversion Tests

  func testToGraphViewport_returnsCurrentValues() {
    // Arrange
    var viewport = MutableGraphViewport(
      from: GraphViewport(xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .equal)
    )
    viewport.xMin = -5
    viewport.xMax = 15

    // Act
    let graphViewport = viewport.toGraphViewport()

    // Assert
    XCTAssertEqual(graphViewport.xMin, -5, accuracy: 1e-15)
    XCTAssertEqual(graphViewport.xMax, 15, accuracy: 1e-15)
    XCTAssertEqual(graphViewport.yMin, -10, accuracy: 1e-15)
    XCTAssertEqual(graphViewport.yMax, 10, accuracy: 1e-15)
    XCTAssertEqual(graphViewport.aspectRatio, .equal)
  }
}

// MARK: - TraceState Tests

final class TraceStateTests: XCTestCase {

  func testTraceState_explicitEquation_storesAllValues() {
    // Arrange & Act
    let state = TraceState(
      equationID: "eq1",
      position: CoordinatePoint(x: 2.0, y: 4.0),
      parameterValue: 2.0,
      yValue: 4.0
    )

    // Assert
    XCTAssertEqual(state.equationID, "eq1")
    XCTAssertEqual(state.position.x, 2.0, accuracy: 1e-15)
    XCTAssertEqual(state.position.y, 4.0, accuracy: 1e-15)
    XCTAssertEqual(state.parameterValue, 2.0, accuracy: 1e-15)
    XCTAssertEqual(state.yValue!, 4.0, accuracy: 1e-15)
  }

  func testTraceState_parametricEquation_yValueIsNil() {
    // Arrange & Act
    let state = TraceState(
      equationID: "param1",
      position: CoordinatePoint(x: 0.0, y: 1.0),
      parameterValue: Double.pi / 2,
      yValue: nil
    )

    // Assert
    XCTAssertEqual(state.equationID, "param1")
    XCTAssertNil(state.yValue)
  }

  func testTraceState_equatable_sameValuesAreEqual() {
    // Arrange
    let state1 = TraceState(
      equationID: "eq1",
      position: CoordinatePoint(x: 2.0, y: 4.0),
      parameterValue: 2.0,
      yValue: 4.0
    )
    let state2 = TraceState(
      equationID: "eq1",
      position: CoordinatePoint(x: 2.0, y: 4.0),
      parameterValue: 2.0,
      yValue: 4.0
    )

    // Act & Assert
    XCTAssertEqual(state1, state2)
  }
}

// MARK: - SampledCurve Tests

final class SampledCurveTests: XCTestCase {

  func testIsEmpty_allSegmentsEmpty_returnsTrue() {
    // Arrange
    let curve = SampledCurve(segments: [[], []], equationID: "eq1")

    // Act & Assert
    XCTAssertTrue(curve.isEmpty)
  }

  func testIsEmpty_oneSegmentHasPoints_returnsFalse() {
    // Arrange
    let curve = SampledCurve(
      segments: [[], [CGPoint(x: 1, y: 1)]],
      equationID: "eq1"
    )

    // Act & Assert
    XCTAssertFalse(curve.isEmpty)
  }

  func testTotalPointCount_multipleSegments_returnsSumOfAllPoints() {
    // Arrange
    let segment1 = [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2), CGPoint(x: 3, y: 3)]
    let segment2 = [CGPoint(x: 4, y: 4), CGPoint(x: 5, y: 5)]
    let curve = SampledCurve(segments: [segment1, segment2], equationID: "eq1")

    // Act & Assert
    XCTAssertEqual(curve.totalPointCount, 5)
  }

  func testEquationID_isPreserved() {
    // Arrange
    let curve = SampledCurve(segments: [], equationID: "myEquation")

    // Act & Assert
    XCTAssertEqual(curve.equationID, "myEquation")
  }
}

// MARK: - GraphViewModelError Tests

final class GraphViewModelErrorTests: XCTestCase {

  func testExpressionParsingFailed_description_includesDetails() {
    // Arrange
    let error = GraphViewModelError.expressionParsingFailed(
      equationID: "eq1",
      reason: "Syntax error"
    )

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("eq1"))
    XCTAssertTrue(description!.contains("Syntax error"))
  }

  func testUnsupportedEquationType_description_includesType() {
    // Arrange
    let error = GraphViewModelError.unsupportedEquationType(
      equationID: "eq2",
      type: .implicit
    )

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("eq2"))
    XCTAssertTrue(description!.contains("implicit"))
  }

  func testNoValidPoints_description_includesEquationID() {
    // Arrange
    let error = GraphViewModelError.noValidPoints(equationID: "eq3")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("eq3"))
  }

  func testInvalidViewport_description_includesReason() {
    // Arrange
    let error = GraphViewModelError.invalidViewport(reason: "Width cannot be zero")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("Width cannot be zero"))
  }

  func testError_equatable_sameErrorsAreEqual() {
    // Arrange
    let error1 = GraphViewModelError.noValidPoints(equationID: "eq1")
    let error2 = GraphViewModelError.noValidPoints(equationID: "eq1")

    // Act & Assert
    XCTAssertEqual(error1, error2)
  }

  func testError_equatable_differentErrorsAreNotEqual() {
    // Arrange
    let error1 = GraphViewModelError.noValidPoints(equationID: "eq1")
    let error2 = GraphViewModelError.noValidPoints(equationID: "eq2")

    // Act & Assert
    XCTAssertNotEqual(error1, error2)
  }
}

// MARK: - GraphViewModelConstants Tests

final class GraphViewModelConstantsTests: XCTestCase {

  func testMinimumViewportSize_isPositive() {
    // Arrange & Act & Assert
    XCTAssertGreaterThan(GraphViewModelConstants.minimumViewportSize, 0)
  }

  func testMaximumViewportSize_isLargerThanMinimum() {
    // Arrange & Act & Assert
    XCTAssertGreaterThan(
      GraphViewModelConstants.maximumViewportSize,
      GraphViewModelConstants.minimumViewportSize
    )
  }

  func testDefaultSampleResolution_isReasonable() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphViewModelConstants.defaultSampleResolution, 500)
    XCTAssertGreaterThanOrEqual(
      GraphViewModelConstants.defaultSampleResolution,
      GraphViewModelConstants.minimumSampleResolution
    )
    XCTAssertLessThanOrEqual(
      GraphViewModelConstants.defaultSampleResolution,
      GraphViewModelConstants.maximumSampleResolution
    )
  }

  func testTraceSnapDistance_isPositive() {
    // Arrange & Act & Assert
    XCTAssertGreaterThan(GraphViewModelConstants.traceSnapDistance, 0)
  }
}

// MARK: - Mock GraphViewModel for Protocol Testing

// Mock implementation of GraphViewModelProtocol for testing protocol behavior.
// Allows tracking method calls and returning pre-configured values.
final class MockGraphViewModel: GraphViewModelProtocol, ObservableObject {
  @Published var specification: GraphSpecification
  @Published var currentViewport: MutableGraphViewport
  @Published var viewSize: CGSize = CGSize(width: 400, height: 400)
  @Published var traceState: TraceState?

  // Tracking properties for method calls
  var graphToScreenCallCount = 0
  var screenToGraphCallCount = 0
  var panCallCount = 0
  var zoomCallCount = 0
  var resetViewportCallCount = 0
  var sampleEquationCallCount = 0
  var startTraceCallCount = 0
  var updateTraceCallCount = 0
  var endTraceCallCount = 0
  var closestEquationCallCount = 0

  // Captured parameters
  var lastPanDelta: CGSize?
  var lastZoomScale: CGFloat?
  var lastZoomScreenPoint: CGPoint?
  var lastSampledEquation: GraphEquation?
  var lastTracePoint: CGPoint?

  // Configurable return values
  var isTracingOverride: Bool?
  var sampleResolutionOverride: Int?
  var closestEquationResult: (equationID: String, distance: CGFloat)?
  var sampledCurveResult: SampledCurve?

  var isTracing: Bool {
    return isTracingOverride ?? (traceState != nil)
  }

  var sampleResolution: Int {
    return sampleResolutionOverride ?? GraphViewModelConstants.defaultSampleResolution
  }

  init() {
    let defaultViewport = GraphViewport(
      xMin: -10,
      xMax: 10,
      yMin: -10,
      yMax: 10,
      aspectRatio: .auto
    )
    let defaultAxes = GraphAxes(
      x: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true),
      y: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true)
    )
    let defaultInteractivity = GraphInteractivity(
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false
    )

    self.specification = GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: defaultViewport,
      axes: defaultAxes,
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: defaultInteractivity
    )
    self.currentViewport = MutableGraphViewport(from: defaultViewport)
  }

  func graphToScreen(_ point: CoordinatePoint) -> CGPoint {
    graphToScreenCallCount += 1

    // Standard linear transformation from graph to screen coordinates.
    // Screen Y is inverted (0 at top, increases downward).
    let screenX = (point.x - currentViewport.xMin) / currentViewport.width * viewSize.width
    let screenY =
      (currentViewport.yMax - point.y) / currentViewport.height * viewSize.height
    return CGPoint(x: screenX, y: screenY)
  }

  func screenToGraph(_ point: CGPoint) -> CoordinatePoint {
    screenToGraphCallCount += 1

    // Standard linear transformation from screen to graph coordinates.
    let graphX = point.x / viewSize.width * currentViewport.width + currentViewport.xMin
    let graphY = currentViewport.yMax - point.y / viewSize.height * currentViewport.height
    return CoordinatePoint(x: graphX, y: graphY)
  }

  func graphToScreenX(_ graphX: Double) -> CGFloat {
    return CGFloat(graphX / currentViewport.width * Double(viewSize.width))
  }

  func graphToScreenY(_ graphY: Double) -> CGFloat {
    return CGFloat(graphY / currentViewport.height * Double(viewSize.height))
  }

  func pan(by delta: CGSize) {
    panCallCount += 1
    lastPanDelta = delta

    guard specification.interactivity.allowPan else { return }

    // Convert screen delta to graph delta.
    // Negative X delta because panning right shows more of the right side (viewport shifts left).
    // Negative Y delta because screen Y is inverted (down is positive in screen coords),
    // so panning up (negative screen delta) should increase graph Y (viewport shifts up).
    let graphDeltaX = -Double(delta.width) / Double(viewSize.width) * currentViewport.width
    let graphDeltaY = -Double(delta.height) / Double(viewSize.height) * currentViewport.height

    currentViewport.xMin += graphDeltaX
    currentViewport.xMax += graphDeltaX
    currentViewport.yMin += graphDeltaY
    currentViewport.yMax += graphDeltaY
  }

  func zoom(scale: CGFloat, around screenPoint: CGPoint) {
    zoomCallCount += 1
    lastZoomScale = scale
    lastZoomScreenPoint = screenPoint

    guard specification.interactivity.allowZoom else { return }
    guard scale > 0, scale != 1.0 else { return }

    // Convert screen point to graph coordinates.
    let graphPoint = screenToGraph(screenPoint)

    // Scale factors.
    let newWidth = currentViewport.width / Double(scale)
    let newHeight = currentViewport.height / Double(scale)

    // Calculate how far the point is from edges (as fraction).
    let xFraction = (graphPoint.x - currentViewport.xMin) / currentViewport.width
    let yFraction = (graphPoint.y - currentViewport.yMin) / currentViewport.height

    // New bounds keeping the graph point at the same fraction.
    currentViewport.xMin = graphPoint.x - xFraction * newWidth
    currentViewport.xMax = currentViewport.xMin + newWidth
    currentViewport.yMin = graphPoint.y - yFraction * newHeight
    currentViewport.yMax = currentViewport.yMin + newHeight
  }

  func resetViewport() {
    resetViewportCallCount += 1
    currentViewport = MutableGraphViewport(from: specification.viewport)
  }

  func sampleEquation(_ equation: GraphEquation) -> SampledCurve {
    sampleEquationCallCount += 1
    lastSampledEquation = equation

    if let result = sampledCurveResult {
      return result
    }

    return SampledCurve(segments: [], equationID: equation.id)
  }

  func startTrace(at screenPoint: CGPoint) {
    startTraceCallCount += 1
    lastTracePoint = screenPoint

    guard specification.interactivity.allowTrace else { return }

    // Create a simple trace state for testing.
    let graphPoint = screenToGraph(screenPoint)
    traceState = TraceState(
      equationID: "test-eq",
      position: graphPoint,
      parameterValue: graphPoint.x,
      yValue: graphPoint.y
    )
  }

  func updateTrace(to screenPoint: CGPoint) {
    updateTraceCallCount += 1
    lastTracePoint = screenPoint

    guard traceState != nil else { return }

    let graphPoint = screenToGraph(screenPoint)
    traceState = TraceState(
      equationID: traceState!.equationID,
      position: graphPoint,
      parameterValue: graphPoint.x,
      yValue: graphPoint.y
    )
  }

  func endTrace() {
    endTraceCallCount += 1
    traceState = nil
  }

  func closestEquation(to screenPoint: CGPoint) -> (equationID: String, distance: CGFloat)? {
    closestEquationCallCount += 1
    return closestEquationResult
  }
}

// MARK: - GraphViewModel Coordinate Transform Tests

final class GraphViewModelCoordinateTransformTests: XCTestCase {

  var viewModel: MockGraphViewModel!

  override func setUp() {
    super.setUp()
    viewModel = MockGraphViewModel()
    viewModel.viewSize = CGSize(width: 400, height: 400)

    // Set up viewport: -10 to 10 in both dimensions
    let viewport = GraphViewport(
      xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto
    )
    viewModel.currentViewport = MutableGraphViewport(from: viewport)
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  // MARK: - Graph to Screen Tests

  func testGraphToScreen_atOrigin_returnsCenterOfView() {
    // Arrange
    let graphPoint = CoordinatePoint(x: 0.0, y: 0.0)

    // Act
    let screenPoint = viewModel.graphToScreen(graphPoint)

    // Assert
    XCTAssertEqual(screenPoint.x, 200, accuracy: 1e-10)
    XCTAssertEqual(screenPoint.y, 200, accuracy: 1e-10)
  }

  func testGraphToScreen_atTopLeftCorner_returnsScreenTopLeft() {
    // Arrange - Graph top-left is (-10, 10)
    let graphPoint = CoordinatePoint(x: -10.0, y: 10.0)

    // Act
    let screenPoint = viewModel.graphToScreen(graphPoint)

    // Assert - Screen top-left is (0, 0)
    XCTAssertEqual(screenPoint.x, 0, accuracy: 1e-10)
    XCTAssertEqual(screenPoint.y, 0, accuracy: 1e-10)
  }

  func testGraphToScreen_atBottomRightCorner_returnsScreenBottomRight() {
    // Arrange - Graph bottom-right is (10, -10)
    let graphPoint = CoordinatePoint(x: 10.0, y: -10.0)

    // Act
    let screenPoint = viewModel.graphToScreen(graphPoint)

    // Assert - Screen bottom-right is (400, 400)
    XCTAssertEqual(screenPoint.x, 400, accuracy: 1e-10)
    XCTAssertEqual(screenPoint.y, 400, accuracy: 1e-10)
  }

  func testGraphToScreen_incrementsCallCount() {
    // Arrange
    let graphPoint = CoordinatePoint(x: 0.0, y: 0.0)

    // Act
    _ = viewModel.graphToScreen(graphPoint)
    _ = viewModel.graphToScreen(graphPoint)

    // Assert
    XCTAssertEqual(viewModel.graphToScreenCallCount, 2)
  }

  // MARK: - Screen to Graph Tests

  func testScreenToGraph_atCenter_returnsOrigin() {
    // Arrange
    let screenPoint = CGPoint(x: 200, y: 200)

    // Act
    let graphPoint = viewModel.screenToGraph(screenPoint)

    // Assert
    XCTAssertEqual(graphPoint.x, 0, accuracy: 1e-10)
    XCTAssertEqual(graphPoint.y, 0, accuracy: 1e-10)
  }

  func testScreenToGraph_atTopLeft_returnsGraphTopLeft() {
    // Arrange - Screen top-left is (0, 0)
    let screenPoint = CGPoint(x: 0, y: 0)

    // Act
    let graphPoint = viewModel.screenToGraph(screenPoint)

    // Assert - Graph top-left is (-10, 10)
    XCTAssertEqual(graphPoint.x, -10, accuracy: 1e-10)
    XCTAssertEqual(graphPoint.y, 10, accuracy: 1e-10)
  }

  func testScreenToGraph_atBottomRight_returnsGraphBottomRight() {
    // Arrange - Screen bottom-right is (400, 400)
    let screenPoint = CGPoint(x: 400, y: 400)

    // Act
    let graphPoint = viewModel.screenToGraph(screenPoint)

    // Assert - Graph bottom-right is (10, -10)
    XCTAssertEqual(graphPoint.x, 10, accuracy: 1e-10)
    XCTAssertEqual(graphPoint.y, -10, accuracy: 1e-10)
  }

  // MARK: - Round Trip Tests

  func testCoordinateTransform_roundTrip_preservesPoint() {
    // Arrange
    let originalGraph = CoordinatePoint(x: 3.5, y: -2.7)

    // Act
    let screen = viewModel.graphToScreen(originalGraph)
    let roundTrip = viewModel.screenToGraph(screen)

    // Assert
    XCTAssertEqual(roundTrip.x, originalGraph.x, accuracy: 1e-10)
    XCTAssertEqual(roundTrip.y, originalGraph.y, accuracy: 1e-10)
  }

  // MARK: - Asymmetric Viewport Tests

  func testGraphToScreen_asymmetricViewport_returnsCorrectPoint() {
    // Arrange
    let viewport = GraphViewport(
      xMin: 0, xMax: 100, yMin: 0, yMax: 50, aspectRatio: .auto
    )
    viewModel.currentViewport = MutableGraphViewport(from: viewport)
    viewModel.viewSize = CGSize(width: 200, height: 100)

    let graphPoint = CoordinatePoint(x: 50.0, y: 25.0)

    // Act
    let screenPoint = viewModel.graphToScreen(graphPoint)

    // Assert - Center should be at center of screen
    XCTAssertEqual(screenPoint.x, 100, accuracy: 1e-10)
    XCTAssertEqual(screenPoint.y, 50, accuracy: 1e-10)
  }
}

// MARK: - GraphViewModel Pan Tests

final class GraphViewModelPanTests: XCTestCase {

  var viewModel: MockGraphViewModel!

  override func setUp() {
    super.setUp()
    viewModel = MockGraphViewModel()
    viewModel.viewSize = CGSize(width: 400, height: 400)

    let viewport = GraphViewport(
      xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto
    )
    viewModel.currentViewport = MutableGraphViewport(from: viewport)
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  func testPan_right_shiftsViewportLeft() {
    // Arrange
    // 20 pixels = 1 graph unit (400 pixels / 20 units)
    let delta = CGSize(width: 20, height: 0)

    // Act
    viewModel.pan(by: delta)

    // Assert - Panning right shows more of the right side, so viewport shifts left
    XCTAssertEqual(viewModel.currentViewport.xMin, -11, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.xMax, 9, accuracy: 1e-10)
  }

  func testPan_up_shiftsViewportUp() {
    // Arrange
    // 20 pixels = 1 graph unit. Negative Y means panning up in screen coordinates.
    let delta = CGSize(width: 0, height: -20)

    // Act
    viewModel.pan(by: delta)

    // Assert - Panning up shows more of the top, so viewport Y increases
    XCTAssertEqual(viewModel.currentViewport.yMin, -9, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.yMax, 11, accuracy: 1e-10)
  }

  func testPan_diagonal_shiftsBothAxes() {
    // Arrange
    let delta = CGSize(width: 20, height: 20)

    // Act
    viewModel.pan(by: delta)

    // Assert
    XCTAssertNotEqual(viewModel.currentViewport.xMin, -10)
    XCTAssertNotEqual(viewModel.currentViewport.yMin, -10)
  }

  func testPan_recordsCallAndDelta() {
    // Arrange
    let delta = CGSize(width: 100, height: 50)

    // Act
    viewModel.pan(by: delta)

    // Assert
    XCTAssertEqual(viewModel.panCallCount, 1)
    XCTAssertEqual(viewModel.lastPanDelta?.width, 100)
    XCTAssertEqual(viewModel.lastPanDelta?.height, 50)
  }

  func testPan_whenDisabled_doesNotChangeViewport() {
    // Arrange
    let noInteractionSpec = GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: viewModel.specification.viewport,
      axes: viewModel.specification.axes,
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: GraphInteractivity(
        allowPan: false,
        allowZoom: true,
        allowTrace: true,
        showCoordinates: true,
        snapToGrid: false
      )
    )
    viewModel.specification = noInteractionSpec

    let originalXMin = viewModel.currentViewport.xMin

    // Act
    viewModel.pan(by: CGSize(width: 100, height: 100))

    // Assert
    XCTAssertEqual(viewModel.currentViewport.xMin, originalXMin, accuracy: 1e-15)
  }
}

// MARK: - GraphViewModel Zoom Tests

final class GraphViewModelZoomTests: XCTestCase {

  var viewModel: MockGraphViewModel!

  override func setUp() {
    super.setUp()
    viewModel = MockGraphViewModel()
    viewModel.viewSize = CGSize(width: 400, height: 400)

    let viewport = GraphViewport(
      xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto
    )
    viewModel.currentViewport = MutableGraphViewport(from: viewport)
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  func testZoom_inAtCenter_halvesViewportSize() {
    // Arrange
    let centerPoint = CGPoint(x: 200, y: 200)

    // Act
    viewModel.zoom(scale: 2.0, around: centerPoint)

    // Assert - Zoom in by 2x should halve the viewport dimensions
    XCTAssertEqual(viewModel.currentViewport.width, 10, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.height, 10, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.xMin, -5, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.xMax, 5, accuracy: 1e-10)
  }

  func testZoom_outAtCenter_doublesViewportSize() {
    // Arrange
    let centerPoint = CGPoint(x: 200, y: 200)

    // Act
    viewModel.zoom(scale: 0.5, around: centerPoint)

    // Assert - Zoom out by 0.5x should double the viewport dimensions
    XCTAssertEqual(viewModel.currentViewport.width, 40, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.height, 40, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.xMin, -20, accuracy: 1e-10)
    XCTAssertEqual(viewModel.currentViewport.xMax, 20, accuracy: 1e-10)
  }

  func testZoom_atOffCenterPoint_keepsPointFixed() {
    // Arrange
    let offCenterPoint = CGPoint(x: 100, y: 100)  // Graph point (-5, 5)
    let graphPointBefore = viewModel.screenToGraph(offCenterPoint)

    // Act
    viewModel.zoom(scale: 2.0, around: offCenterPoint)

    // Assert - The point under the zoom should stay at the same screen position
    let graphPointAfter = viewModel.screenToGraph(offCenterPoint)
    XCTAssertEqual(graphPointAfter.x, graphPointBefore.x, accuracy: 1e-10)
    XCTAssertEqual(graphPointAfter.y, graphPointBefore.y, accuracy: 1e-10)
  }

  func testZoom_scaleOfOne_doesNotChangeViewport() {
    // Arrange
    let originalXMin = viewModel.currentViewport.xMin
    let originalXMax = viewModel.currentViewport.xMax

    // Act
    viewModel.zoom(scale: 1.0, around: CGPoint(x: 200, y: 200))

    // Assert
    XCTAssertEqual(viewModel.currentViewport.xMin, originalXMin, accuracy: 1e-15)
    XCTAssertEqual(viewModel.currentViewport.xMax, originalXMax, accuracy: 1e-15)
  }

  func testZoom_scaleOfZero_doesNotChangeViewport() {
    // Arrange
    let originalWidth = viewModel.currentViewport.width

    // Act
    viewModel.zoom(scale: 0, around: CGPoint(x: 200, y: 200))

    // Assert - Zero scale should be ignored
    XCTAssertEqual(viewModel.currentViewport.width, originalWidth, accuracy: 1e-15)
  }

  func testZoom_recordsCallAndParameters() {
    // Arrange
    let point = CGPoint(x: 150, y: 250)

    // Act
    viewModel.zoom(scale: 1.5, around: point)

    // Assert
    XCTAssertEqual(viewModel.zoomCallCount, 1)
    XCTAssertEqual(viewModel.lastZoomScale, 1.5)
    XCTAssertEqual(viewModel.lastZoomScreenPoint?.x, 150)
    XCTAssertEqual(viewModel.lastZoomScreenPoint?.y, 250)
  }

  func testZoom_whenDisabled_doesNotChangeViewport() {
    // Arrange
    let noZoomSpec = GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: viewModel.specification.viewport,
      axes: viewModel.specification.axes,
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: GraphInteractivity(
        allowPan: true,
        allowZoom: false,
        allowTrace: true,
        showCoordinates: true,
        snapToGrid: false
      )
    )
    viewModel.specification = noZoomSpec

    let originalWidth = viewModel.currentViewport.width

    // Act
    viewModel.zoom(scale: 2.0, around: CGPoint(x: 200, y: 200))

    // Assert
    XCTAssertEqual(viewModel.currentViewport.width, originalWidth, accuracy: 1e-15)
  }
}

// MARK: - GraphViewModel Reset Tests

final class GraphViewModelResetTests: XCTestCase {

  var viewModel: MockGraphViewModel!

  override func setUp() {
    super.setUp()
    viewModel = MockGraphViewModel()
    viewModel.viewSize = CGSize(width: 400, height: 400)

    let viewport = GraphViewport(
      xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto
    )
    viewModel.currentViewport = MutableGraphViewport(from: viewport)
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  func testResetViewport_afterPan_restoresOriginal() {
    // Arrange
    viewModel.pan(by: CGSize(width: 100, height: 100))
    XCTAssertNotEqual(viewModel.currentViewport.xMin, -10)

    // Act
    viewModel.resetViewport()

    // Assert
    XCTAssertEqual(viewModel.currentViewport.xMin, -10, accuracy: 1e-15)
    XCTAssertEqual(viewModel.currentViewport.xMax, 10, accuracy: 1e-15)
    XCTAssertEqual(viewModel.currentViewport.yMin, -10, accuracy: 1e-15)
    XCTAssertEqual(viewModel.currentViewport.yMax, 10, accuracy: 1e-15)
  }

  func testResetViewport_afterZoom_restoresOriginal() {
    // Arrange
    viewModel.zoom(scale: 2.0, around: CGPoint(x: 200, y: 200))
    XCTAssertEqual(viewModel.currentViewport.width, 10, accuracy: 1e-10)

    // Act
    viewModel.resetViewport()

    // Assert
    XCTAssertEqual(viewModel.currentViewport.width, 20, accuracy: 1e-15)
  }

  func testResetViewport_incrementsCallCount() {
    // Arrange & Act
    viewModel.resetViewport()
    viewModel.resetViewport()

    // Assert
    XCTAssertEqual(viewModel.resetViewportCallCount, 2)
  }
}

// MARK: - GraphViewModel Tracing Tests

final class GraphViewModelTracingTests: XCTestCase {

  var viewModel: MockGraphViewModel!

  override func setUp() {
    super.setUp()
    viewModel = MockGraphViewModel()
    viewModel.viewSize = CGSize(width: 400, height: 400)

    let viewport = GraphViewport(
      xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto
    )
    viewModel.currentViewport = MutableGraphViewport(from: viewport)
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  func testStartTrace_setsTraceState() {
    // Arrange
    XCTAssertNil(viewModel.traceState)

    // Act
    viewModel.startTrace(at: CGPoint(x: 200, y: 200))

    // Assert
    XCTAssertNotNil(viewModel.traceState)
    XCTAssertEqual(viewModel.startTraceCallCount, 1)
  }

  func testStartTrace_recordsScreenPoint() {
    // Arrange
    let point = CGPoint(x: 150, y: 250)

    // Act
    viewModel.startTrace(at: point)

    // Assert
    XCTAssertEqual(viewModel.lastTracePoint?.x, 150)
    XCTAssertEqual(viewModel.lastTracePoint?.y, 250)
  }

  func testIsTracing_afterStartTrace_returnsTrue() {
    // Arrange
    XCTAssertFalse(viewModel.isTracing)

    // Act
    viewModel.startTrace(at: CGPoint(x: 200, y: 200))

    // Assert
    XCTAssertTrue(viewModel.isTracing)
  }

  func testUpdateTrace_updatesTraceState() {
    // Arrange
    viewModel.startTrace(at: CGPoint(x: 200, y: 200))
    let initialPosition = viewModel.traceState?.position

    // Act
    viewModel.updateTrace(to: CGPoint(x: 300, y: 100))

    // Assert
    XCTAssertEqual(viewModel.updateTraceCallCount, 1)
    XCTAssertNotEqual(viewModel.traceState?.position, initialPosition)
  }

  func testEndTrace_clearsTraceState() {
    // Arrange
    viewModel.startTrace(at: CGPoint(x: 200, y: 200))
    XCTAssertNotNil(viewModel.traceState)

    // Act
    viewModel.endTrace()

    // Assert
    XCTAssertNil(viewModel.traceState)
    XCTAssertFalse(viewModel.isTracing)
    XCTAssertEqual(viewModel.endTraceCallCount, 1)
  }

  func testStartTrace_whenDisabled_doesNotSetTraceState() {
    // Arrange
    let noTraceSpec = GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: viewModel.specification.viewport,
      axes: viewModel.specification.axes,
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: GraphInteractivity(
        allowPan: true,
        allowZoom: true,
        allowTrace: false,
        showCoordinates: true,
        snapToGrid: false
      )
    )
    viewModel.specification = noTraceSpec

    // Act
    viewModel.startTrace(at: CGPoint(x: 200, y: 200))

    // Assert
    XCTAssertNil(viewModel.traceState)
  }

  func testClosestEquation_returnsConfiguredResult() {
    // Arrange
    viewModel.closestEquationResult = (equationID: "eq1", distance: 5.0)

    // Act
    let result = viewModel.closestEquation(to: CGPoint(x: 200, y: 200))

    // Assert
    XCTAssertEqual(result?.equationID, "eq1")
    XCTAssertEqual(result?.distance, 5.0)
    XCTAssertEqual(viewModel.closestEquationCallCount, 1)
  }

  func testClosestEquation_withNoResult_returnsNil() {
    // Arrange - No result configured

    // Act
    let result = viewModel.closestEquation(to: CGPoint(x: 200, y: 200))

    // Assert
    XCTAssertNil(result)
  }
}

// MARK: - GraphViewModel Sampling Tests

final class GraphViewModelSamplingTests: XCTestCase {

  var viewModel: MockGraphViewModel!

  override func setUp() {
    super.setUp()
    viewModel = MockGraphViewModel()
    viewModel.viewSize = CGSize(width: 400, height: 400)
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  func testSampleEquation_recordsEquationAndIncrementsCount() {
    // Arrange
    let equation = GraphEquation(
      id: "eq1",
      type: .explicit,
      expression: "x^2",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: "x",
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: EquationStyle(
        color: "#0000FF",
        lineWidth: 2.0,
        lineStyle: .solid,
        fillBelow: nil,
        fillAbove: nil,
        fillColor: nil,
        fillOpacity: nil
      ),
      label: nil,
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )

    // Act
    _ = viewModel.sampleEquation(equation)

    // Assert
    XCTAssertEqual(viewModel.sampleEquationCallCount, 1)
    XCTAssertEqual(viewModel.lastSampledEquation?.id, "eq1")
  }

  func testSampleEquation_returnsConfiguredResult() {
    // Arrange
    let expectedCurve = SampledCurve(
      segments: [[CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]],
      equationID: "eq1"
    )
    viewModel.sampledCurveResult = expectedCurve

    let equation = GraphEquation(
      id: "eq1",
      type: .explicit,
      expression: "x",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: "x",
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: EquationStyle(
        color: "#0000FF",
        lineWidth: 2.0,
        lineStyle: .solid,
        fillBelow: nil,
        fillAbove: nil,
        fillColor: nil,
        fillOpacity: nil
      ),
      label: nil,
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )

    // Act
    let result = viewModel.sampleEquation(equation)

    // Assert
    XCTAssertEqual(result.segments.count, 1)
    XCTAssertEqual(result.totalPointCount, 2)
  }

  func testSampleResolution_returnsConfiguredOrDefault() {
    // Arrange - Default
    XCTAssertEqual(
      viewModel.sampleResolution, GraphViewModelConstants.defaultSampleResolution)

    // Act - Override
    viewModel.sampleResolutionOverride = 1000

    // Assert
    XCTAssertEqual(viewModel.sampleResolution, 1000)
  }
}
