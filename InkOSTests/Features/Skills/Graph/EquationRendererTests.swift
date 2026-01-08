// EquationRendererTests.swift
// Tests for EquationRenderer covering equation rendering to paths, axis rendering,
// grid rendering, tick calculation, point and annotation rendering.
// These tests validate the contract defined in EquationRendererContract.swift.

import SwiftUI
import XCTest

@testable import InkOS


// MARK: - EquationRenderResult Tests

final class EquationRenderResultTests: XCTestCase {

  // MARK: - Success Factory Tests

  func testSuccess_createsValidResult() {
    // Arrange
    let strokePath = SwiftUI.Path { path in
      path.move(to: CGPoint(x: 0, y: 0))
      path.addLine(to: CGPoint(x: 100, y: 100))
    }
    let style = EquationStyle(
      color: "#FF0000",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )

    // Act
    let result = EquationRenderResult.success(
      equationID: "eq1",
      strokePaths: [strokePath],
      fillPath: nil,
      style: style
    )

    // Assert
    XCTAssertTrue(result.isValid)
    XCTAssertEqual(result.equationID, "eq1")
    XCTAssertEqual(result.strokePaths.count, 1)
    XCTAssertNil(result.fillPath)
    XCTAssertNil(result.errorMessage)
    XCTAssertEqual(result.style.color, "#FF0000")
  }

  func testSuccess_withFillPath_includesFill() {
    // Arrange
    let strokePath = SwiftUI.Path()
    let fillPath = SwiftUI.Path { path in
      path.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    let style = EquationStyle(
      color: "#0000FF",
      lineWidth: 1.0,
      lineStyle: .dashed,
      fillBelow: true,
      fillAbove: nil,
      fillColor: "#FF0000",
      fillOpacity: 0.3
    )

    // Act
    let result = EquationRenderResult.success(
      equationID: "inequality1",
      strokePaths: [strokePath],
      fillPath: fillPath,
      style: style
    )

    // Assert
    XCTAssertNotNil(result.fillPath)
    XCTAssertEqual(result.style.fillBelow, true)
    XCTAssertEqual(result.style.fillOpacity, 0.3)
  }

  // MARK: - Failure Factory Tests

  func testFailure_createsInvalidResult() {
    // Arrange
    let style = EquationStyle(
      color: "#FF0000",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )

    // Act
    let result = EquationRenderResult.failure(
      equationID: "eq-error",
      error: "Syntax error in expression",
      style: style
    )

    // Assert
    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.equationID, "eq-error")
    XCTAssertTrue(result.strokePaths.isEmpty)
    XCTAssertNil(result.fillPath)
    XCTAssertEqual(result.errorMessage, "Syntax error in expression")
  }

  // MARK: - Multiple Paths Tests

  func testSuccess_withMultiplePaths_handlesDiscontinuities() {
    // Arrange - Simulating y = 1/x with two segments
    let path1 = SwiftUI.Path { path in
      path.move(to: CGPoint(x: 0, y: 100))
      path.addLine(to: CGPoint(x: 95, y: 1))
    }
    let path2 = SwiftUI.Path { path in
      path.move(to: CGPoint(x: 105, y: -1))
      path.addLine(to: CGPoint(x: 200, y: -100))
    }
    let style = EquationStyle(
      color: "#00FF00",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )

    // Act
    let result = EquationRenderResult.success(
      equationID: "reciprocal",
      strokePaths: [path1, path2],
      fillPath: nil,
      style: style
    )

    // Assert
    XCTAssertEqual(result.strokePaths.count, 2)
    XCTAssertTrue(result.isValid)
  }

  // MARK: - Equatable Tests

  func testEquatable_sameValues_areEqual() {
    // Arrange
    let style = EquationStyle(
      color: "#FF0000",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )
    let result1 = EquationRenderResult.failure(
      equationID: "eq1",
      error: "Error",
      style: style
    )
    let result2 = EquationRenderResult.failure(
      equationID: "eq1",
      error: "Error",
      style: style
    )

    // Act & Assert
    XCTAssertEqual(result1, result2)
  }
}

// MARK: - RenderedPoint Tests

final class RenderedPointTests: XCTestCase {

  func testRenderedPoint_storesAllValues() {
    // Arrange & Act
    let style = PointStyle(color: "#FF5722", size: 8.0, shape: .circle)
    let point = RenderedPoint(
      pointID: "p1",
      screenPosition: CGPoint(x: 200, y: 150),
      style: style,
      label: "Vertex"
    )

    // Assert
    XCTAssertEqual(point.pointID, "p1")
    XCTAssertEqual(point.screenPosition.x, 200)
    XCTAssertEqual(point.screenPosition.y, 150)
    XCTAssertEqual(point.style.color, "#FF5722")
    XCTAssertEqual(point.style.size, 8.0)
    XCTAssertEqual(point.style.shape, .circle)
    XCTAssertEqual(point.label, "Vertex")
  }

  func testRenderedPoint_withoutLabel_hasNilLabel() {
    // Arrange & Act
    let style = PointStyle(color: "#000000", size: 6.0, shape: .square)
    let point = RenderedPoint(
      pointID: "p2",
      screenPosition: CGPoint(x: 100, y: 100),
      style: style,
      label: nil
    )

    // Assert
    XCTAssertNil(point.label)
  }
}

// MARK: - RenderedAnnotation Tests

final class RenderedAnnotationTests: XCTestCase {

  func testRenderedAnnotation_label_storesTextAndPosition() {
    // Arrange & Act
    let annotation = RenderedAnnotation(
      type: .label,
      screenPosition: CGPoint(x: 150, y: 200),
      text: "y = x^2",
      anchor: .bottomLeft
    )

    // Assert
    XCTAssertEqual(annotation.type, .label)
    XCTAssertEqual(annotation.screenPosition.x, 150)
    XCTAssertEqual(annotation.screenPosition.y, 200)
    XCTAssertEqual(annotation.text, "y = x^2")
    XCTAssertEqual(annotation.anchor, .bottomLeft)
  }

  func testRenderedAnnotation_arrow_hasNilText() {
    // Arrange & Act
    let annotation = RenderedAnnotation(
      type: .arrow,
      screenPosition: CGPoint(x: 100, y: 100),
      text: nil,
      anchor: .center
    )

    // Assert
    XCTAssertEqual(annotation.type, .arrow)
    XCTAssertNil(annotation.text)
  }
}

// MARK: - AxisTick Tests

final class AxisTickTests: XCTestCase {

  func testAxisTick_storesValuePositionAndLabel() {
    // Arrange & Act
    let tick = AxisTick(
      value: 5.0,
      screenPosition: 200,
      label: "5"
    )

    // Assert
    XCTAssertEqual(tick.value, 5.0, accuracy: 1e-15)
    XCTAssertEqual(tick.screenPosition, 200)
    XCTAssertEqual(tick.label, "5")
  }

  func testAxisTick_formattedLabel_canIncludeDecimals() {
    // Arrange & Act
    let tick = AxisTick(
      value: 3.14,
      screenPosition: 157,
      label: "3.14"
    )

    // Assert
    XCTAssertEqual(tick.label, "3.14")
  }

  func testAxisTick_equatable_sameValuesAreEqual() {
    // Arrange
    let tick1 = AxisTick(value: 5.0, screenPosition: 200, label: "5")
    let tick2 = AxisTick(value: 5.0, screenPosition: 200, label: "5")

    // Act & Assert
    XCTAssertEqual(tick1, tick2)
  }

  func testAxisTick_equatable_differentValuesAreNotEqual() {
    // Arrange
    let tick1 = AxisTick(value: 5.0, screenPosition: 200, label: "5")
    let tick2 = AxisTick(value: 10.0, screenPosition: 300, label: "10")

    // Act & Assert
    XCTAssertNotEqual(tick1, tick2)
  }
}

// MARK: - LineDashPattern Tests

final class LineDashPatternTests: XCTestCase {

  func testSolid_hasEmptyPattern() {
    // Arrange & Act
    let pattern = LineDashPattern.solid

    // Assert
    XCTAssertTrue(pattern.pattern.isEmpty)
    XCTAssertEqual(pattern.phase, 0)
  }

  func testDashed_hasDashGapPattern() {
    // Arrange & Act
    let pattern = LineDashPattern.dashed

    // Assert
    XCTAssertEqual(pattern.pattern, [8, 4])
    XCTAssertEqual(pattern.phase, 0)
  }

  func testDotted_hasDotGapPattern() {
    // Arrange & Act
    let pattern = LineDashPattern.dotted

    // Assert
    XCTAssertEqual(pattern.pattern, [2, 4])
    XCTAssertEqual(pattern.phase, 0)
  }

  func testFromLineStyle_solid_returnsSolid() {
    // Arrange & Act
    let pattern = LineDashPattern.from(.solid)

    // Assert
    XCTAssertEqual(pattern, .solid)
  }

  func testFromLineStyle_dashed_returnsDashed() {
    // Arrange & Act
    let pattern = LineDashPattern.from(.dashed)

    // Assert
    XCTAssertEqual(pattern, .dashed)
  }

  func testFromLineStyle_dotted_returnsDotted() {
    // Arrange & Act
    let pattern = LineDashPattern.from(.dotted)

    // Assert
    XCTAssertEqual(pattern, .dotted)
  }

  func testEquatable_samePatterns_areEqual() {
    // Arrange
    let pattern1 = LineDashPattern(pattern: [5, 3], phase: 0)
    let pattern2 = LineDashPattern(pattern: [5, 3], phase: 0)

    // Act & Assert
    XCTAssertEqual(pattern1, pattern2)
  }

  func testEquatable_differentPatterns_areNotEqual() {
    // Arrange
    let pattern1 = LineDashPattern(pattern: [5, 3], phase: 0)
    let pattern2 = LineDashPattern(pattern: [10, 5], phase: 0)

    // Act & Assert
    XCTAssertNotEqual(pattern1, pattern2)
  }
}

// MARK: - EquationRendererError Tests

final class EquationRendererErrorTests: XCTestCase {

  func testExpressionParsingFailed_description_includesDetails() {
    // Arrange
    let error = EquationRendererError.expressionParsingFailed(
      equationID: "eq1",
      expression: "x^^2",
      reason: "Consecutive operators"
    )

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("eq1"))
    XCTAssertTrue(description!.contains("x^^2"))
    XCTAssertTrue(description!.contains("Consecutive operators"))
  }

  func testUnsupportedEquationType_description_includesType() {
    // Arrange
    let error = EquationRendererError.unsupportedEquationType(
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

  func testNoValidSamples_description_includesEquationID() {
    // Arrange
    let error = EquationRendererError.noValidSamples(equationID: "eq3")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("eq3"))
  }

  func testMissingExpression_description_includesField() {
    // Arrange
    let error = EquationRendererError.missingExpression(
      equationID: "param1",
      field: "yExpression"
    )

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("param1"))
    XCTAssertTrue(description!.contains("yExpression"))
  }

  func testError_equatable_sameErrorsAreEqual() {
    // Arrange
    let error1 = EquationRendererError.noValidSamples(equationID: "eq1")
    let error2 = EquationRendererError.noValidSamples(equationID: "eq1")

    // Act & Assert
    XCTAssertEqual(error1, error2)
  }
}

// MARK: - EquationRendererConstants Tests

final class EquationRendererConstantsTests: XCTestCase {

  func testDefaultSamplesPerViewportWidth_isReasonable() {
    // Arrange & Act & Assert
    XCTAssertEqual(EquationRendererConstants.defaultSamplesPerViewportWidth, 500)
  }

  func testMinimumSamples_isPositive() {
    // Arrange & Act & Assert
    XCTAssertGreaterThan(EquationRendererConstants.minimumSamples, 0)
    XCTAssertEqual(EquationRendererConstants.minimumSamples, 50)
  }

  func testMaximumSamples_isLargerThanMinimum() {
    // Arrange & Act & Assert
    XCTAssertGreaterThan(
      EquationRendererConstants.maximumSamples,
      EquationRendererConstants.minimumSamples
    )
  }

  func testDiscontinuityThreshold_isReasonable() {
    // Arrange & Act & Assert
    XCTAssertEqual(EquationRendererConstants.discontinuityThreshold, 100.0)
  }

  func testMaxGridLines_limitsGridDensity() {
    // Arrange & Act & Assert
    XCTAssertEqual(EquationRendererConstants.maxGridLines, 100)
  }

  func testMinTickSpacing_isPositive() {
    // Arrange & Act & Assert
    XCTAssertGreaterThan(EquationRendererConstants.minTickSpacing, 0)
  }
}

// MARK: - Mock EquationRenderer for Protocol Testing

// Mock implementation of EquationRendererProtocol for testing protocol behavior.
final class MockEquationRenderer: EquationRendererProtocol, @unchecked Sendable {

  // Tracking properties
  var renderEquationCallCount = 0
  var renderAxesCallCount = 0
  var renderGridCallCount = 0
  var calculateTicksCallCount = 0
  var renderPointCallCount = 0
  var renderAnnotationCallCount = 0
  var renderGraphCallCount = 0

  // Captured parameters
  var lastRenderedEquation: GraphEquation?
  var lastRenderedAxes: GraphAxes?
  var lastRenderedPoint: GraphPoint?
  var lastRenderedAnnotation: GraphAnnotation?
  var lastRenderedSpecification: GraphSpecification?

  // Configurable return values
  var equationRenderResult: EquationRenderResult?
  var axesResult: (xAxis: SwiftUI.Path?, yAxis: SwiftUI.Path?) = (nil, nil)
  var gridResult: (vertical: [SwiftUI.Path], horizontal: [SwiftUI.Path]) = ([], [])
  var ticksResult: [AxisTick] = []
  var renderedPointResult: RenderedPoint?
  var renderedAnnotationResult: RenderedAnnotation?
  var renderedGraphResult: RenderedGraph?

  func renderEquation(
    _ equation: GraphEquation,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> EquationRenderResult {
    renderEquationCallCount += 1
    lastRenderedEquation = equation

    if let result = equationRenderResult {
      return result
    }

    // Default: return success with empty paths
    return EquationRenderResult.success(
      equationID: equation.id,
      strokePaths: [],
      fillPath: nil,
      style: equation.style
    )
  }

  func renderAxes(
    _ axes: GraphAxes,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> (xAxis: SwiftUI.Path?, yAxis: SwiftUI.Path?) {
    renderAxesCallCount += 1
    lastRenderedAxes = axes
    return axesResult
  }

  func renderGrid(
    _ axes: GraphAxes,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> (vertical: [SwiftUI.Path], horizontal: [SwiftUI.Path]) {
    renderGridCallCount += 1
    return gridResult
  }

  func calculateTicks(
    _ axis: AxisConfiguration,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    isXAxis: Bool
  ) -> [AxisTick] {
    calculateTicksCallCount += 1
    return ticksResult
  }

  func renderPoint(
    _ point: GraphPoint,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> RenderedPoint {
    renderPointCallCount += 1
    lastRenderedPoint = point

    if let result = renderedPointResult {
      return result
    }

    return RenderedPoint(
      pointID: point.id,
      screenPosition: CGPoint(x: 100, y: 100),
      style: point.style,
      label: point.label
    )
  }

  func renderAnnotation(
    _ annotation: GraphAnnotation,
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> RenderedAnnotation {
    renderAnnotationCallCount += 1
    lastRenderedAnnotation = annotation

    if let result = renderedAnnotationResult {
      return result
    }

    return RenderedAnnotation(
      type: annotation.type,
      screenPosition: CGPoint(x: 100, y: 100),
      text: annotation.text,
      anchor: annotation.anchor ?? .center
    )
  }

  func renderGraph(
    _ specification: GraphSpecification,
    viewport: MutableGraphViewport,
    viewSize: CGSize,
    parser: any MathExpressionParserProtocol
  ) -> RenderedGraph {
    renderGraphCallCount += 1
    lastRenderedSpecification = specification

    if let result = renderedGraphResult {
      return result
    }

    return RenderedGraph(
      equations: [:],
      xAxisPath: nil,
      yAxisPath: nil,
      verticalGridPaths: [],
      horizontalGridPaths: [],
      pointPositions: [],
      annotations: [],
      xAxisTicks: [],
      yAxisTicks: []
    )
  }
}

// MARK: - EquationRenderer Protocol Tests

final class EquationRendererProtocolTests: XCTestCase {

  var mockRenderer: MockEquationRenderer!
  var mockParser: MockMathExpressionParser!
  var defaultViewport: MutableGraphViewport!
  var defaultViewSize: CGSize!

  override func setUp() {
    super.setUp()
    mockRenderer = MockEquationRenderer()
    mockParser = MockMathExpressionParser()
    defaultViewport = MutableGraphViewport(
      from: GraphViewport(xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto)
    )
    defaultViewSize = CGSize(width: 400, height: 400)
  }

  override func tearDown() {
    mockRenderer = nil
    mockParser = nil
    defaultViewport = nil
    defaultViewSize = nil
    super.tearDown()
  }

  // MARK: - Render Equation Tests

  func testRenderEquation_explicit_recordsCallAndEquation() {
    // Arrange
    let equation = createExplicitEquation(id: "eq1", expression: "x^2")

    // Act
    _ = mockRenderer.renderEquation(
      equation,
      viewport: defaultViewport,
      viewSize: defaultViewSize,
      parser: mockParser
    )

    // Assert
    XCTAssertEqual(mockRenderer.renderEquationCallCount, 1)
    XCTAssertEqual(mockRenderer.lastRenderedEquation?.id, "eq1")
    XCTAssertEqual(mockRenderer.lastRenderedEquation?.expression, "x^2")
  }

  func testRenderEquation_returnsConfiguredResult() {
    // Arrange
    let equation = createExplicitEquation(id: "eq1", expression: "x^2")
    let expectedResult = EquationRenderResult.success(
      equationID: "eq1",
      strokePaths: [SwiftUI.Path()],
      fillPath: nil,
      style: equation.style
    )
    mockRenderer.equationRenderResult = expectedResult

    // Act
    let result = mockRenderer.renderEquation(
      equation,
      viewport: defaultViewport,
      viewSize: defaultViewSize,
      parser: mockParser
    )

    // Assert
    XCTAssertEqual(result.equationID, "eq1")
    XCTAssertTrue(result.isValid)
  }

  func testRenderEquation_hidden_returnsEmptyResult() {
    // Arrange
    let equation = createExplicitEquation(id: "hidden", expression: "x^2", visible: false)
    let emptyResult = EquationRenderResult.success(
      equationID: "hidden",
      strokePaths: [],
      fillPath: nil,
      style: equation.style
    )
    mockRenderer.equationRenderResult = emptyResult

    // Act
    let result = mockRenderer.renderEquation(
      equation,
      viewport: defaultViewport,
      viewSize: defaultViewSize,
      parser: mockParser
    )

    // Assert
    XCTAssertTrue(result.strokePaths.isEmpty)
    XCTAssertTrue(result.isValid)
  }

  // MARK: - Render Axes Tests

  func testRenderAxes_recordsCallAndAxes() {
    // Arrange
    let axes = createDefaultAxes(showXAxis: true, showYAxis: true)

    // Act
    _ = mockRenderer.renderAxes(axes, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertEqual(mockRenderer.renderAxesCallCount, 1)
    XCTAssertTrue(mockRenderer.lastRenderedAxes?.x.showAxis ?? false)
    XCTAssertTrue(mockRenderer.lastRenderedAxes?.y.showAxis ?? false)
  }

  func testRenderAxes_returnsConfiguredPaths() {
    // Arrange
    let axes = createDefaultAxes(showXAxis: true, showYAxis: true)
    let xPath = SwiftUI.Path { p in
      p.move(to: CGPoint(x: 0, y: 200))
      p.addLine(to: CGPoint(x: 400, y: 200))
    }
    let yPath = SwiftUI.Path { p in
      p.move(to: CGPoint(x: 200, y: 0))
      p.addLine(to: CGPoint(x: 200, y: 400))
    }
    mockRenderer.axesResult = (xAxis: xPath, yAxis: yPath)

    // Act
    let result = mockRenderer.renderAxes(axes, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertNotNil(result.xAxis)
    XCTAssertNotNil(result.yAxis)
  }

  func testRenderAxes_onlyXVisible_returnsOnlyXPath() {
    // Arrange
    let axes = createDefaultAxes(showXAxis: true, showYAxis: false)
    let xPath = SwiftUI.Path()
    mockRenderer.axesResult = (xAxis: xPath, yAxis: nil)

    // Act
    let result = mockRenderer.renderAxes(axes, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertNotNil(result.xAxis)
    XCTAssertNil(result.yAxis)
  }

  // MARK: - Render Grid Tests

  func testRenderGrid_recordsCall() {
    // Arrange
    let axes = createDefaultAxes(showGrid: true)

    // Act
    _ = mockRenderer.renderGrid(axes, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertEqual(mockRenderer.renderGridCallCount, 1)
  }

  func testRenderGrid_returnsConfiguredPaths() {
    // Arrange
    let axes = createDefaultAxes(showGrid: true)
    let verticalPaths = [SwiftUI.Path(), SwiftUI.Path(), SwiftUI.Path()]
    let horizontalPaths = [SwiftUI.Path(), SwiftUI.Path()]
    mockRenderer.gridResult = (vertical: verticalPaths, horizontal: horizontalPaths)

    // Act
    let result = mockRenderer.renderGrid(axes, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertEqual(result.vertical.count, 3)
    XCTAssertEqual(result.horizontal.count, 2)
  }

  func testRenderGrid_noGrid_returnsEmptyArrays() {
    // Arrange
    let axes = createDefaultAxes(showGrid: false)
    mockRenderer.gridResult = (vertical: [], horizontal: [])

    // Act
    let result = mockRenderer.renderGrid(axes, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertTrue(result.vertical.isEmpty)
    XCTAssertTrue(result.horizontal.isEmpty)
  }

  // MARK: - Calculate Ticks Tests

  func testCalculateTicks_recordsCall() {
    // Arrange
    let axis = AxisConfiguration(
      label: "X",
      gridSpacing: nil,
      showGrid: true,
      showAxis: true,
      tickLabels: true
    )

    // Act
    _ = mockRenderer.calculateTicks(
      axis, viewport: defaultViewport, viewSize: defaultViewSize, isXAxis: true)

    // Assert
    XCTAssertEqual(mockRenderer.calculateTicksCallCount, 1)
  }

  func testCalculateTicks_returnsConfiguredTicks() {
    // Arrange
    let axis = AxisConfiguration(
      label: nil,
      gridSpacing: 5.0,
      showGrid: true,
      showAxis: true,
      tickLabels: true
    )
    mockRenderer.ticksResult = [
      AxisTick(value: -10, screenPosition: 0, label: "-10"),
      AxisTick(value: -5, screenPosition: 100, label: "-5"),
      AxisTick(value: 0, screenPosition: 200, label: "0"),
      AxisTick(value: 5, screenPosition: 300, label: "5"),
      AxisTick(value: 10, screenPosition: 400, label: "10"),
    ]

    // Act
    let result = mockRenderer.calculateTicks(
      axis, viewport: defaultViewport, viewSize: defaultViewSize, isXAxis: true)

    // Assert
    XCTAssertEqual(result.count, 5)
    XCTAssertEqual(result[2].value, 0)
    XCTAssertEqual(result[2].label, "0")
  }

  func testCalculateTicks_tickLabelsDisabled_returnsEmptyArray() {
    // Arrange
    let axis = AxisConfiguration(
      label: nil,
      gridSpacing: nil,
      showGrid: true,
      showAxis: true,
      tickLabels: false
    )
    mockRenderer.ticksResult = []

    // Act
    let result = mockRenderer.calculateTicks(
      axis, viewport: defaultViewport, viewSize: defaultViewSize, isXAxis: true)

    // Assert
    XCTAssertTrue(result.isEmpty)
  }

  // MARK: - Render Point Tests

  func testRenderPoint_recordsCallAndPoint() {
    // Arrange
    let point = createGraphPoint(id: "p1", x: 2, y: 4, label: "Vertex")

    // Act
    _ = mockRenderer.renderPoint(point, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertEqual(mockRenderer.renderPointCallCount, 1)
    XCTAssertEqual(mockRenderer.lastRenderedPoint?.id, "p1")
    XCTAssertEqual(mockRenderer.lastRenderedPoint?.label, "Vertex")
  }

  func testRenderPoint_returnsRenderedPoint() {
    // Arrange
    let point = createGraphPoint(id: "p1", x: 2, y: 4)
    let expectedResult = RenderedPoint(
      pointID: "p1",
      screenPosition: CGPoint(x: 240, y: 160),
      style: point.style,
      label: nil
    )
    mockRenderer.renderedPointResult = expectedResult

    // Act
    let result = mockRenderer.renderPoint(
      point, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertEqual(result.pointID, "p1")
    XCTAssertEqual(result.screenPosition.x, 240)
    XCTAssertEqual(result.screenPosition.y, 160)
  }

  // MARK: - Render Annotation Tests

  func testRenderAnnotation_recordsCallAndAnnotation() {
    // Arrange
    let annotation = createAnnotation(type: .label, text: "Test Label")

    // Act
    _ = mockRenderer.renderAnnotation(
      annotation, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertEqual(mockRenderer.renderAnnotationCallCount, 1)
    XCTAssertEqual(mockRenderer.lastRenderedAnnotation?.text, "Test Label")
  }

  func testRenderAnnotation_preservesAnchor() {
    // Arrange
    let annotation = createAnnotation(type: .label, text: "Test", anchor: .bottomLeft)
    let expectedResult = RenderedAnnotation(
      type: .label,
      screenPosition: CGPoint(x: 100, y: 100),
      text: "Test",
      anchor: .bottomLeft
    )
    mockRenderer.renderedAnnotationResult = expectedResult

    // Act
    let result = mockRenderer.renderAnnotation(
      annotation, viewport: defaultViewport, viewSize: defaultViewSize)

    // Assert
    XCTAssertEqual(result.anchor, .bottomLeft)
  }

  // MARK: - Render Graph Tests

  func testRenderGraph_recordsCallAndSpecification() {
    // Arrange
    let spec = createGraphSpecification(equationCount: 2)

    // Act
    _ = mockRenderer.renderGraph(
      spec, viewport: defaultViewport, viewSize: defaultViewSize, parser: mockParser)

    // Assert
    XCTAssertEqual(mockRenderer.renderGraphCallCount, 1)
    XCTAssertEqual(mockRenderer.lastRenderedSpecification?.equations.count, 2)
  }

  func testRenderGraph_returnsRenderedGraph() {
    // Arrange
    let spec = createGraphSpecification(equationCount: 1)
    let eqResult = EquationRenderResult.success(
      equationID: "eq0",
      strokePaths: [SwiftUI.Path()],
      fillPath: nil,
      style: spec.equations[0].style
    )
    let expectedGraph = RenderedGraph(
      equations: ["eq0": eqResult],
      xAxisPath: SwiftUI.Path(),
      yAxisPath: SwiftUI.Path(),
      verticalGridPaths: [],
      horizontalGridPaths: [],
      pointPositions: [],
      annotations: [],
      xAxisTicks: [],
      yAxisTicks: []
    )
    mockRenderer.renderedGraphResult = expectedGraph

    // Act
    let result = mockRenderer.renderGraph(
      spec, viewport: defaultViewport, viewSize: defaultViewSize, parser: mockParser)

    // Assert
    XCTAssertEqual(result.equations.count, 1)
    XCTAssertNotNil(result.xAxisPath)
    XCTAssertNotNil(result.yAxisPath)
  }

  func testRenderGraph_emptySpecification_rendersAxesOnly() {
    // Arrange
    let spec = createGraphSpecification(equationCount: 0)
    let expectedGraph = RenderedGraph(
      equations: [:],
      xAxisPath: SwiftUI.Path(),
      yAxisPath: SwiftUI.Path(),
      verticalGridPaths: [SwiftUI.Path()],
      horizontalGridPaths: [SwiftUI.Path()],
      pointPositions: [],
      annotations: [],
      xAxisTicks: [AxisTick(value: 0, screenPosition: 200, label: "0")],
      yAxisTicks: [AxisTick(value: 0, screenPosition: 200, label: "0")]
    )
    mockRenderer.renderedGraphResult = expectedGraph

    // Act
    let result = mockRenderer.renderGraph(
      spec, viewport: defaultViewport, viewSize: defaultViewSize, parser: mockParser)

    // Assert
    XCTAssertTrue(result.equations.isEmpty)
    XCTAssertNotNil(result.xAxisPath)
    XCTAssertNotNil(result.yAxisPath)
  }

  // MARK: - Helper Methods

  private func createExplicitEquation(
    id: String, expression: String, visible: Bool = true
  ) -> GraphEquation {
    return GraphEquation(
      id: id,
      type: .explicit,
      expression: expression,
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
      visible: visible,
      fillRegion: nil,
      boundaryStyle: nil
    )
  }

  private func createDefaultAxes(
    showXAxis: Bool = true,
    showYAxis: Bool = true,
    showGrid: Bool = true
  ) -> GraphAxes {
    return GraphAxes(
      x: AxisConfiguration(
        label: nil,
        gridSpacing: nil,
        showGrid: showGrid,
        showAxis: showXAxis,
        tickLabels: true
      ),
      y: AxisConfiguration(
        label: nil,
        gridSpacing: nil,
        showGrid: showGrid,
        showAxis: showYAxis,
        tickLabels: true
      )
    )
  }

  private func createGraphPoint(id: String, x: Double, y: Double, label: String? = nil)
    -> GraphPoint
  {
    return GraphPoint(
      id: id,
      x: x,
      y: y,
      label: label,
      style: PointStyle(color: "#FF5722", size: 6.0, shape: .circle)
    )
  }

  private func createAnnotation(
    type: AnnotationType,
    text: String? = nil,
    anchor: AnchorPosition = .center
  ) -> GraphAnnotation {
    return GraphAnnotation(
      type: type,
      text: text,
      position: GraphPosition(x: 0, y: 0),
      anchor: anchor
    )
  }

  private func createGraphSpecification(equationCount: Int) -> GraphSpecification {
    let equations = (0..<equationCount).map { i in
      createExplicitEquation(id: "eq\(i)", expression: "x^\(i+1)")
    }

    return GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: defaultViewport.toGraphViewport(),
      axes: createDefaultAxes(),
      equations: equations,
      points: nil,
      annotations: nil,
      interactivity: GraphInteractivity(
        allowPan: true,
        allowZoom: true,
        allowTrace: true,
        showCoordinates: true,
        snapToGrid: false
      )
    )
  }
}

// MARK: - RenderedGraph Tests

final class RenderedGraphTests: XCTestCase {

  func testRenderedGraph_storesAllComponents() {
    // Arrange
    let style = EquationStyle(
      color: "#FF0000",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )
    let eqResult = EquationRenderResult.success(
      equationID: "eq1",
      strokePaths: [SwiftUI.Path()],
      fillPath: nil,
      style: style
    )
    let pointStyle = PointStyle(color: "#00FF00", size: 6.0, shape: .circle)
    let renderedPoint = RenderedPoint(
      pointID: "p1",
      screenPosition: CGPoint(x: 100, y: 100),
      style: pointStyle,
      label: "Origin"
    )
    let annotation = RenderedAnnotation(
      type: .label,
      screenPosition: CGPoint(x: 50, y: 50),
      text: "Label",
      anchor: .center
    )

    // Act
    let graph = RenderedGraph(
      equations: ["eq1": eqResult],
      xAxisPath: SwiftUI.Path(),
      yAxisPath: SwiftUI.Path(),
      verticalGridPaths: [SwiftUI.Path(), SwiftUI.Path()],
      horizontalGridPaths: [SwiftUI.Path()],
      pointPositions: [renderedPoint],
      annotations: [annotation],
      xAxisTicks: [AxisTick(value: 0, screenPosition: 200, label: "0")],
      yAxisTicks: [AxisTick(value: 0, screenPosition: 200, label: "0")]
    )

    // Assert
    XCTAssertEqual(graph.equations.count, 1)
    XCTAssertNotNil(graph.xAxisPath)
    XCTAssertNotNil(graph.yAxisPath)
    XCTAssertEqual(graph.verticalGridPaths.count, 2)
    XCTAssertEqual(graph.horizontalGridPaths.count, 1)
    XCTAssertEqual(graph.pointPositions.count, 1)
    XCTAssertEqual(graph.annotations.count, 1)
    XCTAssertEqual(graph.xAxisTicks.count, 1)
    XCTAssertEqual(graph.yAxisTicks.count, 1)
  }

  func testRenderedGraph_hiddenAxes_hasNilPaths() {
    // Arrange & Act
    let graph = RenderedGraph(
      equations: [:],
      xAxisPath: nil,
      yAxisPath: nil,
      verticalGridPaths: [],
      horizontalGridPaths: [],
      pointPositions: [],
      annotations: [],
      xAxisTicks: [],
      yAxisTicks: []
    )

    // Assert
    XCTAssertNil(graph.xAxisPath)
    XCTAssertNil(graph.yAxisPath)
  }
}

// MARK: - Path Builder Protocol Tests

// Tests for the PathBuilderProtocol interface behavior using mock implementation.
final class MockPathBuilder: PathBuilderProtocol, @unchecked Sendable {
  var buildPathsCallCount = 0
  var buildAdaptivePathsCallCount = 0
  var lastPointsInput: [CGPoint]?
  var pathsResult: [SwiftUI.Path] = []

  func buildPaths(from points: [CGPoint]) -> [SwiftUI.Path] {
    buildPathsCallCount += 1
    lastPointsInput = points
    return pathsResult
  }

  func buildAdaptivePaths(
    from points: [CGPoint],
    evaluator: @Sendable (CGFloat) -> CGPoint?
  ) -> [SwiftUI.Path] {
    buildAdaptivePathsCallCount += 1
    lastPointsInput = points
    return pathsResult
  }
}

final class PathBuilderProtocolTests: XCTestCase {

  var mockBuilder: MockPathBuilder!

  override func setUp() {
    super.setUp()
    mockBuilder = MockPathBuilder()
  }

  override func tearDown() {
    mockBuilder = nil
    super.tearDown()
  }

  func testBuildPaths_continuousPoints_returnsSinglePath() {
    // Arrange
    let points = [
      CGPoint(x: 0, y: 0),
      CGPoint(x: 50, y: 25),
      CGPoint(x: 100, y: 100),
    ]
    mockBuilder.pathsResult = [SwiftUI.Path()]

    // Act
    let result = mockBuilder.buildPaths(from: points)

    // Assert
    XCTAssertEqual(mockBuilder.buildPathsCallCount, 1)
    XCTAssertEqual(mockBuilder.lastPointsInput?.count, 3)
    XCTAssertEqual(result.count, 1)
  }

  func testBuildPaths_withDiscontinuity_returnsMultiplePaths() {
    // Arrange
    let points = [
      CGPoint(x: 0, y: 10),
      CGPoint(x: 50, y: 1000),  // Discontinuity
      CGPoint(x: 51, y: -1000),
      CGPoint(x: 100, y: -10),
    ]
    mockBuilder.pathsResult = [SwiftUI.Path(), SwiftUI.Path()]

    // Act
    let result = mockBuilder.buildPaths(from: points)

    // Assert
    XCTAssertEqual(result.count, 2)
  }

  func testBuildAdaptivePaths_callsEvaluator() {
    // Arrange
    let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]
    mockBuilder.pathsResult = [SwiftUI.Path()]

    // Act
    let result = mockBuilder.buildAdaptivePaths(from: points) { x in
      return CGPoint(x: x, y: x * x)
    }

    // Assert
    XCTAssertEqual(mockBuilder.buildAdaptivePathsCallCount, 1)
    XCTAssertEqual(result.count, 1)
  }
}

// MARK: - Fill Region Builder Protocol Tests

final class MockFillRegionBuilder: FillRegionBuilderProtocol, @unchecked Sendable {
  var buildFillBelowCallCount = 0
  var buildFillAboveCallCount = 0
  var fillBelowResult: SwiftUI.Path = SwiftUI.Path()
  var fillAboveResult: SwiftUI.Path = SwiftUI.Path()

  func buildFillBelow(
    curvePaths: [SwiftUI.Path],
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> SwiftUI.Path {
    buildFillBelowCallCount += 1
    return fillBelowResult
  }

  func buildFillAbove(
    curvePaths: [SwiftUI.Path],
    viewport: MutableGraphViewport,
    viewSize: CGSize
  ) -> SwiftUI.Path {
    buildFillAboveCallCount += 1
    return fillAboveResult
  }
}

final class FillRegionBuilderProtocolTests: XCTestCase {

  var mockBuilder: MockFillRegionBuilder!
  var defaultViewport: MutableGraphViewport!
  var defaultViewSize: CGSize!

  override func setUp() {
    super.setUp()
    mockBuilder = MockFillRegionBuilder()
    defaultViewport = MutableGraphViewport(
      from: GraphViewport(xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto)
    )
    defaultViewSize = CGSize(width: 400, height: 400)
  }

  override func tearDown() {
    mockBuilder = nil
    defaultViewport = nil
    defaultViewSize = nil
    super.tearDown()
  }

  func testBuildFillBelow_recordsCall() {
    // Arrange
    let curvePaths = [SwiftUI.Path()]

    // Act
    _ = mockBuilder.buildFillBelow(
      curvePaths: curvePaths,
      viewport: defaultViewport,
      viewSize: defaultViewSize
    )

    // Assert
    XCTAssertEqual(mockBuilder.buildFillBelowCallCount, 1)
  }

  func testBuildFillAbove_recordsCall() {
    // Arrange
    let curvePaths = [SwiftUI.Path()]

    // Act
    _ = mockBuilder.buildFillAbove(
      curvePaths: curvePaths,
      viewport: defaultViewport,
      viewSize: defaultViewSize
    )

    // Assert
    XCTAssertEqual(mockBuilder.buildFillAboveCallCount, 1)
  }

  func testBuildFillBelow_returnsConfiguredPath() {
    // Arrange
    mockBuilder.fillBelowResult = SwiftUI.Path { p in
      p.addRect(CGRect(x: 0, y: 200, width: 400, height: 200))
    }

    // Act
    let result = mockBuilder.buildFillBelow(
      curvePaths: [],
      viewport: defaultViewport,
      viewSize: defaultViewSize
    )

    // Assert - Path is returned (non-empty check)
    XCTAssertFalse(result.isEmpty)
  }
}
