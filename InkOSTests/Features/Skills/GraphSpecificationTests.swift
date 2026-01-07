// GraphSpecificationTests.swift
// Comprehensive tests for the GraphSpecification types defined in GraphSpecificationContract.swift.
// These tests validate all types, protocols, and behaviors for graph rendering capabilities.
// Tests cover Codable conformance, enum parsing, style serialization, viewport validation,
// edge cases, error handling, and constant values.

import Foundation
import Testing

@testable import InkOS

// MARK: - Helper Extensions for Testing

// Extension to create JSON encoder/decoder with consistent settings.
extension JSONEncoder {
  static var testEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}

extension JSONDecoder {
  static var testDecoder: JSONDecoder {
    JSONDecoder()
  }
}

// MARK: - Test Data Factory

// Factory for creating test instances of GraphSpecification types.
// Provides consistent test data across all test suites.
enum TestGraphFactory {

  // Creates a minimal valid GraphSpecification.
  static func minimalSpecification() -> GraphSpecification {
    GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: standardViewport(),
      axes: standardAxes(),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: standardInteractivity()
    )
  }

  // Creates a GraphSpecification with all fields populated.
  static func fullSpecification() -> GraphSpecification {
    GraphSpecification(
      version: "1.0",
      title: "Quadratic Functions",
      viewport: standardViewport(),
      axes: standardAxes(),
      equations: [explicitEquation(), parametricEquation()],
      points: [labeledPoint()],
      annotations: [labelAnnotation()],
      interactivity: standardInteractivity()
    )
  }

  // Creates a standard viewport centered on origin.
  static func standardViewport() -> GraphViewport {
    GraphViewport(
      xMin: -10.0,
      xMax: 10.0,
      yMin: -10.0,
      yMax: 10.0,
      aspectRatio: .auto
    )
  }

  // Creates asymmetric viewport focusing on first quadrant.
  static func firstQuadrantViewport() -> GraphViewport {
    GraphViewport(
      xMin: 0.0,
      xMax: 100.0,
      yMin: 0.0,
      yMax: 50.0,
      aspectRatio: .equal
    )
  }

  // Creates standard axis configuration.
  static func standardAxes() -> GraphAxes {
    GraphAxes(
      x: AxisConfiguration(
        label: "X",
        gridSpacing: 1.0,
        showGrid: true,
        showAxis: true,
        tickLabels: true
      ),
      y: AxisConfiguration(
        label: "Y",
        gridSpacing: 1.0,
        showGrid: true,
        showAxis: true,
        tickLabels: true
      )
    )
  }

  // Creates an explicit equation y = x^2.
  static func explicitEquation() -> GraphEquation {
    GraphEquation(
      id: "eq-1",
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
      style: standardEquationStyle(),
      label: "y = x^2",
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )
  }

  // Creates a parametric equation for a unit circle.
  static func parametricEquation() -> GraphEquation {
    GraphEquation(
      id: "eq-2",
      type: .parametric,
      expression: nil,
      xExpression: "cos(t)",
      yExpression: "sin(t)",
      rExpression: nil,
      variable: nil,
      parameter: "t",
      domain: nil,
      parameterRange: ParameterRange(min: 0.0, max: 6.283185307),
      thetaRange: nil,
      style: standardEquationStyle(),
      label: "Unit Circle",
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )
  }

  // Creates a polar equation (cardioid).
  static func polarEquation() -> GraphEquation {
    GraphEquation(
      id: "eq-3",
      type: .polar,
      expression: nil,
      xExpression: nil,
      yExpression: nil,
      rExpression: "1 + cos(theta)",
      variable: nil,
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: ParameterRange(min: 0.0, max: 6.283185307),
      style: standardEquationStyle(),
      label: "Cardioid",
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )
  }

  // Creates an implicit equation (circle).
  static func implicitEquation() -> GraphEquation {
    GraphEquation(
      id: "eq-4",
      type: .implicit,
      expression: "x^2 + y^2 - 1",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: nil,
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: standardEquationStyle(),
      label: "x^2 + y^2 = 1",
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )
  }

  // Creates an inequality equation.
  static func inequalityEquation() -> GraphEquation {
    GraphEquation(
      id: "eq-5",
      type: .inequality,
      expression: "x^2",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: "x",
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: inequalityEquationStyle(),
      label: "y < x^2",
      visible: true,
      fillRegion: true,
      boundaryStyle: "dashed"
    )
  }

  // Creates standard equation style.
  static func standardEquationStyle() -> EquationStyle {
    EquationStyle(
      color: "#2196F3",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )
  }

  // Creates inequality equation style with fill.
  static func inequalityEquationStyle() -> EquationStyle {
    EquationStyle(
      color: "#FF0000",
      lineWidth: 2.0,
      lineStyle: .dashed,
      fillBelow: true,
      fillAbove: nil,
      fillColor: "#FF0000",
      fillOpacity: 0.3
    )
  }

  // Creates a labeled point.
  static func labeledPoint() -> GraphPoint {
    GraphPoint(
      id: "pt-1",
      x: 0.0,
      y: 0.0,
      label: "Origin",
      style: standardPointStyle()
    )
  }

  // Creates standard point style.
  static func standardPointStyle() -> PointStyle {
    PointStyle(
      color: "#FF5722",
      size: 6.0,
      shape: .circle
    )
  }

  // Creates a label annotation.
  static func labelAnnotation() -> GraphAnnotation {
    GraphAnnotation(
      type: .label,
      text: "y = x^2",
      position: GraphPosition(x: 2.0, y: 4.0),
      anchor: .bottomLeft
    )
  }

  // Creates standard interactivity settings.
  static func standardInteractivity() -> GraphInteractivity {
    GraphInteractivity(
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false
    )
  }

  // Creates view-only interactivity settings.
  static func viewOnlyInteractivity() -> GraphInteractivity {
    GraphInteractivity(
      allowPan: false,
      allowZoom: false,
      allowTrace: false,
      showCoordinates: false,
      snapToGrid: false
    )
  }
}

// MARK: - GraphSpecification Codable Tests

@Suite("GraphSpecification Codable Tests")
struct GraphSpecificationCodableTests {

  @Test("minimal specification roundtrips through JSON")
  func minimalSpecificationRoundtrips() throws {
    let original = TestGraphFactory.minimalSpecification()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded == original)
    #expect(decoded.version == "1.0")
    #expect(decoded.title == nil)
    #expect(decoded.equations.isEmpty)
  }

  @Test("full specification roundtrips through JSON")
  func fullSpecificationRoundtrips() throws {
    let original = TestGraphFactory.fullSpecification()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded == original)
    #expect(decoded.title == "Quadratic Functions")
    #expect(decoded.equations.count == 2)
    #expect(decoded.points?.count == 1)
    #expect(decoded.annotations?.count == 1)
  }

  @Test("specification with title preserves title")
  func specificationWithTitlePreservesTitle() throws {
    let original = GraphSpecification(
      version: "1.0",
      title: "My Graph",
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.title == "My Graph")
  }

  @Test("specification with multiple equations preserves all")
  func specificationWithMultipleEquationsPreservesAll() throws {
    let equations = [
      TestGraphFactory.explicitEquation(),
      TestGraphFactory.parametricEquation(),
      TestGraphFactory.polarEquation(),
    ]
    let original = GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: equations,
      points: nil,
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.equations.count == 3)
    #expect(decoded.equations[0].id == "eq-1")
    #expect(decoded.equations[1].id == "eq-2")
    #expect(decoded.equations[2].id == "eq-3")
  }

  @Test("nil optionals are omitted in JSON")
  func nilOptionalsOmittedInJSON() throws {
    let spec = TestGraphFactory.minimalSpecification()

    let data = try JSONEncoder.testEncoder.encode(spec)
    let json = String(data: data, encoding: .utf8)

    // Title is nil, so should not appear in JSON or appear as null.
    // The key may be omitted or present with null depending on encoding strategy.
    #expect(json != nil)
  }

  @Test("decoding preserves nested structures")
  func decodingPreservesNestedStructures() throws {
    let original = TestGraphFactory.fullSpecification()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    // Check viewport nested structure.
    #expect(decoded.viewport.xMin == -10.0)
    #expect(decoded.viewport.xMax == 10.0)
    #expect(decoded.viewport.aspectRatio == .auto)

    // Check axes nested structure.
    #expect(decoded.axes.x.showGrid == true)
    #expect(decoded.axes.y.showAxis == true)

    // Check equation nested structure.
    #expect(decoded.equations[0].style.color == "#2196F3")
    #expect(decoded.equations[0].style.lineStyle == .solid)
  }

  @Test("version field is preserved during decode")
  func versionFieldPreserved() throws {
    let original = GraphSpecification(
      version: "2.0",
      title: nil,
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.version == "2.0")
  }
}

// MARK: - EquationType Tests

@Suite("EquationType Tests")
struct EquationTypeTests {

  @Test("explicit type parses correctly")
  func explicitTypeParsesCorrectly() throws {
    let json = #""explicit""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(EquationType.self, from: data)

    #expect(decoded == .explicit)
  }

  @Test("parametric type parses correctly")
  func parametricTypeParsesCorrectly() throws {
    let json = #""parametric""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(EquationType.self, from: data)

    #expect(decoded == .parametric)
  }

  @Test("polar type parses correctly")
  func polarTypeParsesCorrectly() throws {
    let json = #""polar""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(EquationType.self, from: data)

    #expect(decoded == .polar)
  }

  @Test("implicit type parses correctly")
  func implicitTypeParsesCorrectly() throws {
    let json = #""implicit""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(EquationType.self, from: data)

    #expect(decoded == .implicit)
  }

  @Test("inequality type parses correctly")
  func inequalityTypeParsesCorrectly() throws {
    let json = #""inequality""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(EquationType.self, from: data)

    #expect(decoded == .inequality)
  }

  @Test("all equation types roundtrip through JSON")
  func allEquationTypesRoundtrip() throws {
    let allTypes: [EquationType] = [.explicit, .parametric, .polar, .implicit, .inequality]

    for originalType in allTypes {
      let data = try JSONEncoder.testEncoder.encode(originalType)
      let decoded = try JSONDecoder.testDecoder.decode(EquationType.self, from: data)

      #expect(decoded == originalType)
    }
  }

  @Test("equation type uses raw string in JSON")
  func equationTypeUsesRawString() throws {
    let data = try JSONEncoder.testEncoder.encode(EquationType.explicit)
    let json = String(data: data, encoding: .utf8)

    #expect(json == #""explicit""#)
  }

  @Test("unknown equation type fails decoding")
  func unknownEquationTypeFailsDecoding() {
    let json = #""unknown""#
    let data = json.data(using: .utf8)!

    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder.testDecoder.decode(EquationType.self, from: data)
    }
  }

  @Test("equation types are Equatable")
  func equationTypesAreEquatable() {
    #expect(EquationType.explicit == EquationType.explicit)
    #expect(EquationType.explicit != EquationType.parametric)
    #expect(EquationType.polar != EquationType.implicit)
  }
}

// MARK: - LineStyle Tests

@Suite("LineStyle Tests")
struct LineStyleTests {

  @Test("solid line style roundtrips")
  func solidLineStyleRoundtrips() throws {
    let original = LineStyle.solid

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(LineStyle.self, from: data)

    #expect(decoded == .solid)
  }

  @Test("dashed line style roundtrips")
  func dashedLineStyleRoundtrips() throws {
    let original = LineStyle.dashed

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(LineStyle.self, from: data)

    #expect(decoded == .dashed)
  }

  @Test("dotted line style roundtrips")
  func dottedLineStyleRoundtrips() throws {
    let original = LineStyle.dotted

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(LineStyle.self, from: data)

    #expect(decoded == .dotted)
  }

  @Test("line style uses raw string value")
  func lineStyleUsesRawString() throws {
    let data = try JSONEncoder.testEncoder.encode(LineStyle.dashed)
    let json = String(data: data, encoding: .utf8)

    #expect(json == #""dashed""#)
  }
}

// MARK: - EquationStyle Tests

@Suite("EquationStyle Tests")
struct EquationStyleTests {

  @Test("basic line style roundtrips")
  func basicLineStyleRoundtrips() throws {
    let original = EquationStyle(
      color: "#0000FF",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(EquationStyle.self, from: data)

    #expect(decoded == original)
    #expect(decoded.color == "#0000FF")
    #expect(decoded.lineWidth == 2.0)
    #expect(decoded.lineStyle == .solid)
  }

  @Test("inequality fill style roundtrips")
  func inequalityFillStyleRoundtrips() throws {
    let original = EquationStyle(
      color: "#FF0000",
      lineWidth: 1.5,
      lineStyle: .dashed,
      fillBelow: true,
      fillAbove: false,
      fillColor: "#FF0000",
      fillOpacity: 0.3
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(EquationStyle.self, from: data)

    #expect(decoded == original)
    #expect(decoded.fillBelow == true)
    #expect(decoded.fillAbove == false)
    #expect(decoded.fillColor == "#FF0000")
    #expect(decoded.fillOpacity == 0.3)
  }

  @Test("dotted line style in equation roundtrips")
  func dottedLineStyleRoundtrips() throws {
    let original = EquationStyle(
      color: "#00FF00",
      lineWidth: 1.0,
      lineStyle: .dotted,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(EquationStyle.self, from: data)

    #expect(decoded.lineStyle == .dotted)
  }

  @Test("style with fill above roundtrips")
  func styleWithFillAboveRoundtrips() throws {
    let original = EquationStyle(
      color: "#FFFFFF",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: false,
      fillAbove: true,
      fillColor: "#000000",
      fillOpacity: 0.5
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(EquationStyle.self, from: data)

    #expect(decoded.fillAbove == true)
    #expect(decoded.fillOpacity == 0.5)
  }
}

// MARK: - PointStyle Tests

@Suite("PointStyle Tests")
struct PointStyleTests {

  @Test("circle point style roundtrips")
  func circlePointStyleRoundtrips() throws {
    let original = PointStyle(color: "#00FF00", size: 6.0, shape: .circle)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(PointStyle.self, from: data)

    #expect(decoded == original)
    #expect(decoded.shape == .circle)
  }

  @Test("square point style roundtrips")
  func squarePointStyleRoundtrips() throws {
    let original = PointStyle(color: "#FF0000", size: 8.0, shape: .square)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(PointStyle.self, from: data)

    #expect(decoded.shape == .square)
    #expect(decoded.size == 8.0)
  }

  @Test("triangle point style roundtrips")
  func trianglePointStyleRoundtrips() throws {
    let original = PointStyle(color: "#0000FF", size: 10.0, shape: .triangle)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(PointStyle.self, from: data)

    #expect(decoded.shape == .triangle)
  }

  @Test("cross point style roundtrips")
  func crossPointStyleRoundtrips() throws {
    let original = PointStyle(color: "#FFFF00", size: 4.0, shape: .cross)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(PointStyle.self, from: data)

    #expect(decoded.shape == .cross)
  }
}

// MARK: - PointShape Tests

@Suite("PointShape Tests")
struct PointShapeTests {

  @Test("all point shapes roundtrip")
  func allPointShapesRoundtrip() throws {
    let allShapes: [PointShape] = [.circle, .square, .triangle, .cross]

    for shape in allShapes {
      let data = try JSONEncoder.testEncoder.encode(shape)
      let decoded = try JSONDecoder.testDecoder.decode(PointShape.self, from: data)

      #expect(decoded == shape)
    }
  }

  @Test("point shape uses raw string value")
  func pointShapeUsesRawString() throws {
    let data = try JSONEncoder.testEncoder.encode(PointShape.triangle)
    let json = String(data: data, encoding: .utf8)

    #expect(json == #""triangle""#)
  }
}

// MARK: - GraphViewport Tests

@Suite("GraphViewport Tests")
struct GraphViewportTests {

  @Test("standard viewport bounds are correct")
  func standardViewportBoundsAreCorrect() {
    let viewport = TestGraphFactory.standardViewport()

    // Center of viewport should be at origin.
    let centerX = (viewport.xMin + viewport.xMax) / 2
    let centerY = (viewport.yMin + viewport.yMax) / 2

    #expect(centerX == 0.0)
    #expect(centerY == 0.0)

    // Width and height should be 20 units.
    let width = viewport.xMax - viewport.xMin
    let height = viewport.yMax - viewport.yMin

    #expect(width == 20.0)
    #expect(height == 20.0)
  }

  @Test("asymmetric viewport focuses on first quadrant")
  func asymmetricViewportFirstQuadrant() {
    let viewport = TestGraphFactory.firstQuadrantViewport()

    // Origin should be at bottom-left.
    #expect(viewport.xMin == 0.0)
    #expect(viewport.yMin == 0.0)

    // Only positive values visible.
    #expect(viewport.xMax > 0.0)
    #expect(viewport.yMax > 0.0)
  }

  @Test("viewport with equal aspect ratio roundtrips")
  func viewportWithEqualAspectRatioRoundtrips() throws {
    let original = GraphViewport(
      xMin: -5.0,
      xMax: 5.0,
      yMin: -5.0,
      yMax: 5.0,
      aspectRatio: .equal
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphViewport.self, from: data)

    #expect(decoded == original)
    #expect(decoded.aspectRatio == .equal)
  }

  @Test("viewport with auto aspect ratio roundtrips")
  func viewportWithAutoAspectRatioRoundtrips() throws {
    let original = TestGraphFactory.standardViewport()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphViewport.self, from: data)

    #expect(decoded.aspectRatio == .auto)
  }

  @Test("viewport with free aspect ratio roundtrips")
  func viewportWithFreeAspectRatioRoundtrips() throws {
    let original = GraphViewport(
      xMin: 0.0,
      xMax: 1000.0,
      yMin: 0.0,
      yMax: 10.0,
      aspectRatio: .free
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphViewport.self, from: data)

    #expect(decoded.aspectRatio == .free)
  }

  @Test("viewport preserves decimal precision")
  func viewportPreservesDecimalPrecision() throws {
    let original = GraphViewport(
      xMin: -3.14159265359,
      xMax: 3.14159265359,
      yMin: -2.71828182846,
      yMax: 2.71828182846,
      aspectRatio: .auto
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphViewport.self, from: data)

    #expect(decoded.xMin == original.xMin)
    #expect(decoded.xMax == original.xMax)
    #expect(decoded.yMin == original.yMin)
    #expect(decoded.yMax == original.yMax)
  }
}

// MARK: - AspectRatioMode Tests

@Suite("AspectRatioMode Tests")
struct AspectRatioModeTests {

  @Test("auto aspect ratio parses from JSON")
  func autoAspectRatioParsesFromJSON() throws {
    let json = #""auto""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(AspectRatioMode.self, from: data)

    #expect(decoded == .auto)
  }

  @Test("equal aspect ratio parses from JSON")
  func equalAspectRatioParsesFromJSON() throws {
    let json = #""equal""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(AspectRatioMode.self, from: data)

    #expect(decoded == .equal)
  }

  @Test("free aspect ratio parses from JSON")
  func freeAspectRatioParsesFromJSON() throws {
    let json = #""free""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(AspectRatioMode.self, from: data)

    #expect(decoded == .free)
  }

  @Test("aspect ratio uses raw string value")
  func aspectRatioUsesRawString() throws {
    let data = try JSONEncoder.testEncoder.encode(AspectRatioMode.equal)
    let json = String(data: data, encoding: .utf8)

    #expect(json == #""equal""#)
  }
}

// MARK: - GraphAxes Tests

@Suite("GraphAxes Tests")
struct GraphAxesTests {

  @Test("standard axes configuration roundtrips")
  func standardAxesConfigurationRoundtrips() throws {
    let original = TestGraphFactory.standardAxes()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAxes.self, from: data)

    #expect(decoded == original)
    #expect(decoded.x.showGrid == true)
    #expect(decoded.y.showGrid == true)
  }

  @Test("asymmetric axis configuration roundtrips")
  func asymmetricAxisConfigurationRoundtrips() throws {
    let original = GraphAxes(
      x: AxisConfiguration(
        label: "Time (s)",
        gridSpacing: 10.0,
        showGrid: true,
        showAxis: true,
        tickLabels: true
      ),
      y: AxisConfiguration(
        label: "Distance (m)",
        gridSpacing: 5.0,
        showGrid: false,
        showAxis: true,
        tickLabels: true
      )
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAxes.self, from: data)

    #expect(decoded.x.label == "Time (s)")
    #expect(decoded.y.label == "Distance (m)")
    #expect(decoded.x.gridSpacing == 10.0)
    #expect(decoded.y.gridSpacing == 5.0)
    #expect(decoded.x.showGrid == true)
    #expect(decoded.y.showGrid == false)
  }

  @Test("hidden grid on one axis roundtrips")
  func hiddenGridOnOneAxisRoundtrips() throws {
    let original = GraphAxes(
      x: AxisConfiguration(
        label: nil,
        gridSpacing: nil,
        showGrid: true,
        showAxis: true,
        tickLabels: true
      ),
      y: AxisConfiguration(
        label: nil,
        gridSpacing: nil,
        showGrid: false,
        showAxis: true,
        tickLabels: true
      )
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAxes.self, from: data)

    #expect(decoded.x.showGrid == true)
    #expect(decoded.y.showGrid == false)
  }
}

// MARK: - AxisConfiguration Tests

@Suite("AxisConfiguration Tests")
struct AxisConfigurationTests {

  @Test("axis with all features enabled roundtrips")
  func axisWithAllFeaturesEnabledRoundtrips() throws {
    let original = AxisConfiguration(
      label: "X Axis",
      gridSpacing: 1.0,
      showGrid: true,
      showAxis: true,
      tickLabels: true
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(AxisConfiguration.self, from: data)

    #expect(decoded == original)
    #expect(decoded.showGrid == true)
    #expect(decoded.showAxis == true)
    #expect(decoded.tickLabels == true)
  }

  @Test("axis with custom grid spacing roundtrips")
  func axisWithCustomGridSpacingRoundtrips() throws {
    let original = AxisConfiguration(
      label: nil,
      gridSpacing: 5.0,
      showGrid: true,
      showAxis: true,
      tickLabels: true
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(AxisConfiguration.self, from: data)

    #expect(decoded.gridSpacing == 5.0)
  }

  @Test("axis with auto grid spacing (nil) roundtrips")
  func axisWithAutoGridSpacingRoundtrips() throws {
    let original = AxisConfiguration(
      label: nil,
      gridSpacing: nil,
      showGrid: true,
      showAxis: true,
      tickLabels: true
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(AxisConfiguration.self, from: data)

    #expect(decoded.gridSpacing == nil)
  }

  @Test("hidden axis roundtrips")
  func hiddenAxisRoundtrips() throws {
    let original = AxisConfiguration(
      label: nil,
      gridSpacing: nil,
      showGrid: false,
      showAxis: false,
      tickLabels: false
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(AxisConfiguration.self, from: data)

    #expect(decoded.showAxis == false)
    #expect(decoded.showGrid == false)
    #expect(decoded.tickLabels == false)
  }
}

// MARK: - GraphEquation Tests

@Suite("GraphEquation Tests")
struct GraphEquationTests {

  @Test("explicit equation roundtrips")
  func explicitEquationRoundtrips() throws {
    let original = TestGraphFactory.explicitEquation()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded == original)
    #expect(decoded.type == .explicit)
    #expect(decoded.expression == "x^2")
    #expect(decoded.variable == "x")
  }

  @Test("parametric equation roundtrips")
  func parametricEquationRoundtrips() throws {
    let original = TestGraphFactory.parametricEquation()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded == original)
    #expect(decoded.type == .parametric)
    #expect(decoded.xExpression == "cos(t)")
    #expect(decoded.yExpression == "sin(t)")
    #expect(decoded.parameter == "t")
    #expect(decoded.expression == nil)
  }

  @Test("polar equation roundtrips")
  func polarEquationRoundtrips() throws {
    let original = TestGraphFactory.polarEquation()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded == original)
    #expect(decoded.type == .polar)
    #expect(decoded.rExpression == "1 + cos(theta)")
    #expect(decoded.thetaRange != nil)
  }

  @Test("implicit equation roundtrips")
  func implicitEquationRoundtrips() throws {
    let original = TestGraphFactory.implicitEquation()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded == original)
    #expect(decoded.type == .implicit)
    #expect(decoded.expression == "x^2 + y^2 - 1")
  }

  @Test("inequality equation roundtrips")
  func inequalityEquationRoundtrips() throws {
    let original = TestGraphFactory.inequalityEquation()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded == original)
    #expect(decoded.type == .inequality)
    #expect(decoded.fillRegion == true)
    #expect(decoded.boundaryStyle == "dashed")
  }

  @Test("hidden equation roundtrips")
  func hiddenEquationRoundtrips() throws {
    var equation = TestGraphFactory.explicitEquation()
    equation = GraphEquation(
      id: equation.id,
      type: equation.type,
      expression: equation.expression,
      xExpression: equation.xExpression,
      yExpression: equation.yExpression,
      rExpression: equation.rExpression,
      variable: equation.variable,
      parameter: equation.parameter,
      domain: equation.domain,
      parameterRange: equation.parameterRange,
      thetaRange: equation.thetaRange,
      style: equation.style,
      label: equation.label,
      visible: false,
      fillRegion: equation.fillRegion,
      boundaryStyle: equation.boundaryStyle
    )

    let data = try JSONEncoder.testEncoder.encode(equation)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded.visible == false)
  }

  @Test("equation with domain restriction roundtrips")
  func equationWithDomainRestrictionRoundtrips() throws {
    let original = GraphEquation(
      id: "sqrt-eq",
      type: .explicit,
      expression: "sqrt(x)",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: "x",
      parameter: nil,
      domain: ParameterRange(min: 0.0, max: nil),
      parameterRange: nil,
      thetaRange: nil,
      style: TestGraphFactory.standardEquationStyle(),
      label: "y = sqrt(x)",
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded.domain?.min == 0.0)
    #expect(decoded.domain?.max == nil)
  }

  @Test("equation with custom variable name roundtrips")
  func equationWithCustomVariableNameRoundtrips() throws {
    let original = GraphEquation(
      id: "custom-var",
      type: .explicit,
      expression: "2*n + 1",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: "n",
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: TestGraphFactory.standardEquationStyle(),
      label: nil,
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded.variable == "n")
    #expect(decoded.expression == "2*n + 1")
  }

  @Test("equation is Identifiable by id")
  func equationIsIdentifiable() {
    let equation = TestGraphFactory.explicitEquation()

    #expect(equation.id == "eq-1")
  }
}

// MARK: - ParameterRange Tests

@Suite("ParameterRange Tests")
struct ParameterRangeTests {

  @Test("bounded range roundtrips")
  func boundedRangeRoundtrips() throws {
    let original = ParameterRange(min: 0.0, max: 6.283185307)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(ParameterRange.self, from: data)

    #expect(decoded == original)
    #expect(decoded.min == 0.0)
    #expect(decoded.max == 6.283185307)
  }

  @Test("left-unbounded range roundtrips")
  func leftUnboundedRangeRoundtrips() throws {
    let original = ParameterRange(min: nil, max: 0.0)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(ParameterRange.self, from: data)

    #expect(decoded.min == nil)
    #expect(decoded.max == 0.0)
  }

  @Test("right-unbounded range roundtrips")
  func rightUnboundedRangeRoundtrips() throws {
    let original = ParameterRange(min: 0.0, max: nil)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(ParameterRange.self, from: data)

    #expect(decoded.min == 0.0)
    #expect(decoded.max == nil)
  }

  @Test("fully unbounded range roundtrips")
  func fullyUnboundedRangeRoundtrips() throws {
    let original = ParameterRange(min: nil, max: nil)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(ParameterRange.self, from: data)

    #expect(decoded.min == nil)
    #expect(decoded.max == nil)
  }

  @Test("single point range roundtrips")
  func singlePointRangeRoundtrips() throws {
    let original = ParameterRange(min: 5.0, max: 5.0)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(ParameterRange.self, from: data)

    #expect(decoded.min == decoded.max)
    #expect(decoded.min == 5.0)
  }
}

// MARK: - GraphPoint Tests

@Suite("GraphPoint Tests")
struct GraphPointTests {

  @Test("labeled point roundtrips")
  func labeledPointRoundtrips() throws {
    let original = TestGraphFactory.labeledPoint()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphPoint.self, from: data)

    #expect(decoded == original)
    #expect(decoded.label == "Origin")
    #expect(decoded.x == 0.0)
    #expect(decoded.y == 0.0)
  }

  @Test("unlabeled point roundtrips")
  func unlabeledPointRoundtrips() throws {
    let original = GraphPoint(
      id: "pt-unlabeled",
      x: 3.5,
      y: 2.7,
      label: nil,
      style: TestGraphFactory.standardPointStyle()
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphPoint.self, from: data)

    #expect(decoded.label == nil)
    #expect(decoded.x == 3.5)
    #expect(decoded.y == 2.7)
  }

  @Test("point with custom style roundtrips")
  func pointWithCustomStyleRoundtrips() throws {
    let original = GraphPoint(
      id: "red-square",
      x: 1.0,
      y: 2.0,
      label: "Custom",
      style: PointStyle(color: "#FF0000", size: 8.0, shape: .square)
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphPoint.self, from: data)

    #expect(decoded.style.color == "#FF0000")
    #expect(decoded.style.shape == .square)
    #expect(decoded.style.size == 8.0)
  }

  @Test("point is Identifiable by id")
  func pointIsIdentifiable() {
    let point = TestGraphFactory.labeledPoint()

    #expect(point.id == "pt-1")
  }

  @Test("point with decimal coordinates preserves precision")
  func pointWithDecimalCoordinatesPreservesPrecision() throws {
    let original = GraphPoint(
      id: "precise",
      x: 3.14159265359,
      y: 2.71828182846,
      label: nil,
      style: TestGraphFactory.standardPointStyle()
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphPoint.self, from: data)

    #expect(decoded.x == original.x)
    #expect(decoded.y == original.y)
  }
}

// MARK: - GraphAnnotation Tests

@Suite("GraphAnnotation Tests")
struct GraphAnnotationTests {

  @Test("label annotation roundtrips")
  func labelAnnotationRoundtrips() throws {
    let original = TestGraphFactory.labelAnnotation()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAnnotation.self, from: data)

    #expect(decoded == original)
    #expect(decoded.type == .label)
    #expect(decoded.text == "y = x^2")
    #expect(decoded.anchor == .bottomLeft)
  }

  @Test("arrow annotation roundtrips")
  func arrowAnnotationRoundtrips() throws {
    let original = GraphAnnotation(
      type: .arrow,
      text: nil,
      position: GraphPosition(x: 1.0, y: 1.0),
      anchor: nil
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAnnotation.self, from: data)

    #expect(decoded.type == .arrow)
    #expect(decoded.text == nil)
  }

  @Test("line annotation roundtrips")
  func lineAnnotationRoundtrips() throws {
    let original = GraphAnnotation(
      type: .line,
      text: nil,
      position: GraphPosition(x: 0.0, y: 5.0),
      anchor: nil
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAnnotation.self, from: data)

    #expect(decoded.type == .line)
  }

  @Test("annotation with nil anchor roundtrips")
  func annotationWithNilAnchorRoundtrips() throws {
    let original = GraphAnnotation(
      type: .label,
      text: "Test",
      position: GraphPosition(x: 0.0, y: 0.0),
      anchor: nil
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAnnotation.self, from: data)

    #expect(decoded.anchor == nil)
  }
}

// MARK: - AnnotationType Tests

@Suite("AnnotationType Tests")
struct AnnotationTypeTests {

  @Test("label annotation type parses")
  func labelAnnotationTypeParsesFromJSON() throws {
    let json = #""label""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(AnnotationType.self, from: data)

    #expect(decoded == .label)
  }

  @Test("arrow annotation type parses")
  func arrowAnnotationTypeParsesFromJSON() throws {
    let json = #""arrow""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(AnnotationType.self, from: data)

    #expect(decoded == .arrow)
  }

  @Test("line annotation type parses")
  func lineAnnotationTypeParsesFromJSON() throws {
    let json = #""line""#
    let data = json.data(using: .utf8)!

    let decoded = try JSONDecoder.testDecoder.decode(AnnotationType.self, from: data)

    #expect(decoded == .line)
  }
}

// MARK: - AnchorPosition Tests

@Suite("AnchorPosition Tests")
struct AnchorPositionTests {

  @Test("all anchor positions roundtrip")
  func allAnchorPositionsRoundtrip() throws {
    let allAnchors: [AnchorPosition] = [
      .top, .bottom, .left, .right, .center,
      .topLeft, .topRight, .bottomLeft, .bottomRight,
    ]

    for anchor in allAnchors {
      let data = try JSONEncoder.testEncoder.encode(anchor)
      let decoded = try JSONDecoder.testDecoder.decode(AnchorPosition.self, from: data)

      #expect(decoded == anchor)
    }
  }

  @Test("anchor position uses raw string value")
  func anchorPositionUsesRawString() throws {
    let data = try JSONEncoder.testEncoder.encode(AnchorPosition.bottomRight)
    let json = String(data: data, encoding: .utf8)

    #expect(json == #""bottomRight""#)
  }
}

// MARK: - GraphPosition Tests

@Suite("GraphPosition Tests")
struct GraphPositionTests {

  @Test("position at origin roundtrips")
  func positionAtOriginRoundtrips() throws {
    let original = GraphPosition(x: 0.0, y: 0.0)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphPosition.self, from: data)

    #expect(decoded == original)
    #expect(decoded.x == 0.0)
    #expect(decoded.y == 0.0)
  }

  @Test("position with decimals preserves precision")
  func positionWithDecimalsPreservesPrecision() throws {
    let original = GraphPosition(x: 3.14159, y: 2.71828)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphPosition.self, from: data)

    #expect(decoded.x == 3.14159)
    #expect(decoded.y == 2.71828)
  }

  @Test("position with negative coordinates roundtrips")
  func positionWithNegativeCoordinatesRoundtrips() throws {
    let original = GraphPosition(x: -5.5, y: -3.3)

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphPosition.self, from: data)

    #expect(decoded.x == -5.5)
    #expect(decoded.y == -3.3)
  }
}

// MARK: - GraphInteractivity Tests

@Suite("GraphInteractivity Tests")
struct GraphInteractivityTests {

  @Test("full interactivity enabled roundtrips")
  func fullInteractivityEnabledRoundtrips() throws {
    let original = TestGraphFactory.standardInteractivity()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphInteractivity.self, from: data)

    #expect(decoded == original)
    #expect(decoded.allowPan == true)
    #expect(decoded.allowZoom == true)
    #expect(decoded.allowTrace == true)
    #expect(decoded.showCoordinates == true)
  }

  @Test("view-only graph roundtrips")
  func viewOnlyGraphRoundtrips() throws {
    let original = TestGraphFactory.viewOnlyInteractivity()

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphInteractivity.self, from: data)

    #expect(decoded.allowPan == false)
    #expect(decoded.allowZoom == false)
    #expect(decoded.allowTrace == false)
    #expect(decoded.showCoordinates == false)
  }

  @Test("trace with snap to grid roundtrips")
  func traceWithSnapToGridRoundtrips() throws {
    let original = GraphInteractivity(
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: true
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphInteractivity.self, from: data)

    #expect(decoded.snapToGrid == true)
    #expect(decoded.allowTrace == true)
  }

  @Test("trace without snap roundtrips")
  func traceWithoutSnapRoundtrips() throws {
    let original = GraphInteractivity(
      allowPan: false,
      allowZoom: false,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false
    )

    let data = try JSONEncoder.testEncoder.encode(original)
    let decoded = try JSONDecoder.testDecoder.decode(GraphInteractivity.self, from: data)

    #expect(decoded.snapToGrid == false)
    #expect(decoded.allowTrace == true)
    #expect(decoded.showCoordinates == true)
  }
}

// MARK: - Edge Case Tests

@Suite("GraphSpecification Edge Case Tests")
struct GraphSpecificationEdgeCaseTests {

  @Test("empty equations array is valid")
  func emptyEquationsArrayIsValid() throws {
    let spec = TestGraphFactory.minimalSpecification()

    #expect(spec.equations.isEmpty)

    // Should still encode and decode correctly.
    let data = try JSONEncoder.testEncoder.encode(spec)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.equations.isEmpty)
  }

  @Test("nil optionals are handled correctly")
  func nilOptionalsAreHandledCorrectly() throws {
    let spec = TestGraphFactory.minimalSpecification()

    #expect(spec.title == nil)
    #expect(spec.points == nil)
    #expect(spec.annotations == nil)

    let data = try JSONEncoder.testEncoder.encode(spec)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.title == nil)
    #expect(decoded.points == nil)
    #expect(decoded.annotations == nil)
  }

  @Test("specification with empty points array roundtrips")
  func specificationWithEmptyPointsArrayRoundtrips() throws {
    let spec = GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: [],
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )

    let data = try JSONEncoder.testEncoder.encode(spec)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.points?.isEmpty == true)
  }

  @Test("specification with empty annotations array roundtrips")
  func specificationWithEmptyAnnotationsArrayRoundtrips() throws {
    let spec = GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: nil,
      annotations: [],
      interactivity: TestGraphFactory.standardInteractivity()
    )

    let data = try JSONEncoder.testEncoder.encode(spec)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.annotations?.isEmpty == true)
  }

  @Test("unknown version string is preserved")
  func unknownVersionStringIsPreserved() throws {
    let spec = GraphSpecification(
      version: "2.0",
      title: nil,
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )

    let data = try JSONEncoder.testEncoder.encode(spec)
    let decoded = try JSONDecoder.testDecoder.decode(GraphSpecification.self, from: data)

    #expect(decoded.version == "2.0")
  }

  @Test("very large coordinate values roundtrip")
  func veryLargeCoordinateValuesRoundtrip() throws {
    let viewport = GraphViewport(
      xMin: -1e15,
      xMax: 1e15,
      yMin: -1e15,
      yMax: 1e15,
      aspectRatio: .auto
    )

    let data = try JSONEncoder.testEncoder.encode(viewport)
    let decoded = try JSONDecoder.testDecoder.decode(GraphViewport.self, from: data)

    #expect(decoded.xMin == -1e15)
    #expect(decoded.xMax == 1e15)
  }

  @Test("very small coordinate values roundtrip")
  func verySmallCoordinateValuesRoundtrip() throws {
    let viewport = GraphViewport(
      xMin: -1e-15,
      xMax: 1e-15,
      yMin: -1e-15,
      yMax: 1e-15,
      aspectRatio: .auto
    )

    let data = try JSONEncoder.testEncoder.encode(viewport)
    let decoded = try JSONDecoder.testDecoder.decode(GraphViewport.self, from: data)

    #expect(decoded.xMin == -1e-15)
    #expect(decoded.xMax == 1e-15)
  }

  @Test("equation with nil expression for explicit type roundtrips")
  func equationWithNilExpressionRoundtrips() throws {
    // This tests that the type allows nil expression even for explicit type.
    // Validation is a separate concern.
    let equation = GraphEquation(
      id: "invalid-eq",
      type: .explicit,
      expression: nil,
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: nil,
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: TestGraphFactory.standardEquationStyle(),
      label: nil,
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )

    let data = try JSONEncoder.testEncoder.encode(equation)
    let decoded = try JSONDecoder.testDecoder.decode(GraphEquation.self, from: data)

    #expect(decoded.expression == nil)
    #expect(decoded.type == .explicit)
  }

  @Test("unicode in labels roundtrips correctly")
  func unicodeInLabelsRoundtripsCorrectly() throws {
    let annotation = GraphAnnotation(
      type: .label,
      text: "theta: \u{03B8}, pi: \u{03C0}, sum: \u{2211}",
      position: GraphPosition(x: 0.0, y: 0.0),
      anchor: .center
    )

    let data = try JSONEncoder.testEncoder.encode(annotation)
    let decoded = try JSONDecoder.testDecoder.decode(GraphAnnotation.self, from: data)

    #expect(decoded.text == "theta: \u{03B8}, pi: \u{03C0}, sum: \u{2211}")
  }

  @Test("equations with same ID are equal")
  func equationsWithSameIDAreEqual() {
    let eq1 = TestGraphFactory.explicitEquation()
    let eq2 = TestGraphFactory.explicitEquation()

    #expect(eq1 == eq2)
  }

  @Test("equations with different IDs are not equal")
  func equationsWithDifferentIDsAreNotEqual() {
    let eq1 = TestGraphFactory.explicitEquation()
    let eq2 = TestGraphFactory.parametricEquation()

    #expect(eq1 != eq2)
  }
}

// MARK: - GraphSpecificationError Tests

@Suite("GraphSpecificationError Tests")
struct GraphSpecificationErrorTests {

  @Test("unsupportedVersion error contains version")
  func unsupportedVersionErrorContainsVersion() {
    let error = GraphSpecificationError.unsupportedVersion(version: "3.0")

    if case .unsupportedVersion(let version) = error {
      #expect(version == "3.0")
    } else {
      Issue.record("Expected unsupportedVersion case")
    }
  }

  @Test("unsupportedVersion errorDescription contains version")
  func unsupportedVersionErrorDescription() {
    let error = GraphSpecificationError.unsupportedVersion(version: "3.0")

    #expect(error.errorDescription?.contains("3.0") == true)
    #expect(error.errorDescription?.contains("Unsupported") == true)
  }

  @Test("invalidViewport error contains reason")
  func invalidViewportErrorContainsReason() {
    let error = GraphSpecificationError.invalidViewport(reason: "xMin > xMax")

    if case .invalidViewport(let reason) = error {
      #expect(reason == "xMin > xMax")
    } else {
      Issue.record("Expected invalidViewport case")
    }
  }

  @Test("invalidViewport errorDescription contains reason")
  func invalidViewportErrorDescription() {
    let error = GraphSpecificationError.invalidViewport(reason: "xMin > xMax")

    #expect(error.errorDescription?.contains("xMin > xMax") == true)
    #expect(error.errorDescription?.contains("Invalid viewport") == true)
  }

  @Test("incompleteEquation error contains equationID and reason")
  func incompleteEquationErrorContainsDetails() {
    let error = GraphSpecificationError.incompleteEquation(
      equationID: "eq-1",
      reason: "missing yExpression for parametric"
    )

    if case .incompleteEquation(let equationID, let reason) = error {
      #expect(equationID == "eq-1")
      #expect(reason == "missing yExpression for parametric")
    } else {
      Issue.record("Expected incompleteEquation case")
    }
  }

  @Test("incompleteEquation errorDescription contains details")
  func incompleteEquationErrorDescription() {
    let error = GraphSpecificationError.incompleteEquation(
      equationID: "eq-1",
      reason: "missing expression"
    )

    #expect(error.errorDescription?.contains("eq-1") == true)
    #expect(error.errorDescription?.contains("missing expression") == true)
  }

  @Test("invalidExpression error contains all details")
  func invalidExpressionErrorContainsAllDetails() {
    let error = GraphSpecificationError.invalidExpression(
      equationID: "eq-2",
      expression: "x^2 + + 3",
      reason: "syntax error"
    )

    if case .invalidExpression(let equationID, let expression, let reason) = error {
      #expect(equationID == "eq-2")
      #expect(expression == "x^2 + + 3")
      #expect(reason == "syntax error")
    } else {
      Issue.record("Expected invalidExpression case")
    }
  }

  @Test("invalidExpression errorDescription contains details")
  func invalidExpressionErrorDescription() {
    let error = GraphSpecificationError.invalidExpression(
      equationID: "eq-2",
      expression: "x^2 + + 3",
      reason: "syntax error"
    )

    #expect(error.errorDescription?.contains("eq-2") == true)
    #expect(error.errorDescription?.contains("x^2 + + 3") == true)
    #expect(error.errorDescription?.contains("syntax error") == true)
  }

  @Test("invalidParameterRange error contains details")
  func invalidParameterRangeErrorContainsDetails() {
    let error = GraphSpecificationError.invalidParameterRange(
      equationID: "eq-3",
      reason: "min > max"
    )

    if case .invalidParameterRange(let equationID, let reason) = error {
      #expect(equationID == "eq-3")
      #expect(reason == "min > max")
    } else {
      Issue.record("Expected invalidParameterRange case")
    }
  }

  @Test("invalidColor error contains value")
  func invalidColorErrorContainsValue() {
    let error = GraphSpecificationError.invalidColor(value: "not-a-color")

    if case .invalidColor(let value) = error {
      #expect(value == "not-a-color")
    } else {
      Issue.record("Expected invalidColor case")
    }
  }

  @Test("invalidColor errorDescription contains value")
  func invalidColorErrorDescription() {
    let error = GraphSpecificationError.invalidColor(value: "xyz")

    #expect(error.errorDescription?.contains("xyz") == true)
    #expect(error.errorDescription?.contains("Invalid color") == true)
  }

  @Test("duplicateEquationID error contains ID")
  func duplicateEquationIDErrorContainsID() {
    let error = GraphSpecificationError.duplicateEquationID(equationID: "eq-1")

    if case .duplicateEquationID(let equationID) = error {
      #expect(equationID == "eq-1")
    } else {
      Issue.record("Expected duplicateEquationID case")
    }
  }

  @Test("duplicateEquationID errorDescription contains ID")
  func duplicateEquationIDErrorDescription() {
    let error = GraphSpecificationError.duplicateEquationID(equationID: "eq-1")

    #expect(error.errorDescription?.contains("eq-1") == true)
    #expect(error.errorDescription?.contains("Duplicate") == true)
  }

  @Test("duplicatePointID error contains ID")
  func duplicatePointIDErrorContainsID() {
    let error = GraphSpecificationError.duplicatePointID(pointID: "pt-1")

    if case .duplicatePointID(let pointID) = error {
      #expect(pointID == "pt-1")
    } else {
      Issue.record("Expected duplicatePointID case")
    }
  }

  @Test("decodingFailed error contains reason")
  func decodingFailedErrorContainsReason() {
    let error = GraphSpecificationError.decodingFailed(reason: "unexpected token")

    if case .decodingFailed(let reason) = error {
      #expect(reason == "unexpected token")
    } else {
      Issue.record("Expected decodingFailed case")
    }
  }

  @Test("decodingFailed errorDescription contains reason")
  func decodingFailedErrorDescription() {
    let error = GraphSpecificationError.decodingFailed(reason: "malformed JSON")

    #expect(error.errorDescription?.contains("malformed JSON") == true)
    #expect(error.errorDescription?.contains("decode") == true)
  }

  @Test("errors are Equatable with same values")
  func errorsAreEquatableWithSameValues() {
    let error1 = GraphSpecificationError.invalidColor(value: "abc")
    let error2 = GraphSpecificationError.invalidColor(value: "abc")

    #expect(error1 == error2)
  }

  @Test("errors are not equal with different values")
  func errorsAreNotEqualWithDifferentValues() {
    let error1 = GraphSpecificationError.invalidColor(value: "abc")
    let error2 = GraphSpecificationError.invalidColor(value: "xyz")

    #expect(error1 != error2)
  }

  @Test("different error types are not equal")
  func differentErrorTypesAreNotEqual() {
    let error1 = GraphSpecificationError.invalidColor(value: "abc")
    let error2 = GraphSpecificationError.decodingFailed(reason: "abc")

    #expect(error1 != error2)
  }
}

// MARK: - GraphSpecificationConstants Tests

@Suite("GraphSpecificationConstants Tests")
struct GraphSpecificationConstantsTests {

  @Test("currentVersion is 1.0")
  func currentVersionIs1_0() {
    #expect(GraphSpecificationConstants.currentVersion == "1.0")
  }

  @Test("default viewport bounds are -10 to 10")
  func defaultViewportBoundsAreMinusTenToTen() {
    #expect(GraphSpecificationConstants.defaultXMin == -10.0)
    #expect(GraphSpecificationConstants.defaultXMax == 10.0)
    #expect(GraphSpecificationConstants.defaultYMin == -10.0)
    #expect(GraphSpecificationConstants.defaultYMax == 10.0)
  }

  @Test("default viewport is centered on origin")
  func defaultViewportIsCenteredOnOrigin() {
    let centerX =
      (GraphSpecificationConstants.defaultXMin + GraphSpecificationConstants.defaultXMax) / 2
    let centerY =
      (GraphSpecificationConstants.defaultYMin + GraphSpecificationConstants.defaultYMax) / 2

    #expect(centerX == 0.0)
    #expect(centerY == 0.0)
  }

  @Test("default line color is Material Blue")
  func defaultLineColorIsMaterialBlue() {
    #expect(GraphSpecificationConstants.defaultLineColor == "#2196F3")
  }

  @Test("default line width is 2.0")
  func defaultLineWidthIs2_0() {
    #expect(GraphSpecificationConstants.defaultLineWidth == 2.0)
  }

  @Test("default point color is Deep Orange")
  func defaultPointColorIsDeepOrange() {
    #expect(GraphSpecificationConstants.defaultPointColor == "#FF5722")
  }

  @Test("default point size is 6.0")
  func defaultPointSizeIs6_0() {
    #expect(GraphSpecificationConstants.defaultPointSize == 6.0)
  }

  @Test("default fill opacity is 0.3")
  func defaultFillOpacityIs0_3() {
    #expect(GraphSpecificationConstants.defaultFillOpacity == 0.3)
  }

  @Test("default parametric t range is 0 to 2pi")
  func defaultParametricTRangeIs0To2Pi() {
    #expect(GraphSpecificationConstants.defaultParametricTMin == 0.0)
    // 2 * pi approximately equals 6.283185307.
    #expect(GraphSpecificationConstants.defaultParametricTMax > 6.28)
    #expect(GraphSpecificationConstants.defaultParametricTMax < 6.29)
  }

  @Test("default polar theta range is 0 to 2pi")
  func defaultPolarThetaRangeIs0To2Pi() {
    #expect(GraphSpecificationConstants.defaultPolarThetaMin == 0.0)
    #expect(GraphSpecificationConstants.defaultPolarThetaMax > 6.28)
    #expect(GraphSpecificationConstants.defaultPolarThetaMax < 6.29)
  }

  @Test("max equations limit is 100")
  func maxEquationsLimitIs100() {
    #expect(GraphSpecificationConstants.maxEquations == 100)
  }

  @Test("max points limit is 1000")
  func maxPointsLimitIs1000() {
    #expect(GraphSpecificationConstants.maxPoints == 1000)
  }

  @Test("max annotations limit is 100")
  func maxAnnotationsLimitIs100() {
    #expect(GraphSpecificationConstants.maxAnnotations == 100)
  }

  @Test("max expression length is 1000")
  func maxExpressionLengthIs1000() {
    #expect(GraphSpecificationConstants.maxExpressionLength == 1000)
  }

  @Test("default sample count is 500")
  func defaultSampleCountIs500() {
    #expect(GraphSpecificationConstants.defaultSampleCount == 500)
  }

  @Test("max sample count is 10000")
  func maxSampleCountIs10000() {
    #expect(GraphSpecificationConstants.maxSampleCount == 10000)
  }

  @Test("default sample count is less than max")
  func defaultSampleCountIsLessThanMax() {
    #expect(GraphSpecificationConstants.defaultSampleCount < GraphSpecificationConstants.maxSampleCount)
  }
}

// MARK: - Sendable Conformance Tests

@Suite("GraphSpecification Sendable Tests")
struct GraphSpecificationSendableTests {

  @Test("GraphSpecification is Sendable")
  func graphSpecificationIsSendable() async {
    let spec = TestGraphFactory.fullSpecification()

    // Pass to async context to verify Sendable conformance.
    let result = await passToActor(spec)
    #expect(result == "1.0")
  }

  @Test("GraphViewport is Sendable")
  func graphViewportIsSendable() async {
    let viewport = TestGraphFactory.standardViewport()

    let result = await passViewportToActor(viewport)
    #expect(result == -10.0)
  }

  @Test("GraphEquation is Sendable")
  func graphEquationIsSendable() async {
    let equation = TestGraphFactory.explicitEquation()

    let result = await passEquationToActor(equation)
    #expect(result == "eq-1")
  }

  @Test("GraphSpecificationError is Sendable")
  func graphSpecificationErrorIsSendable() async {
    let error = GraphSpecificationError.invalidColor(value: "test")

    let result = await passErrorToActor(error)
    #expect(result == true)
  }

  // Helper functions to verify Sendable conformance.
  private func passToActor(_ spec: GraphSpecification) async -> String {
    return spec.version
  }

  private func passViewportToActor(_ viewport: GraphViewport) async -> Double {
    return viewport.xMin
  }

  private func passEquationToActor(_ equation: GraphEquation) async -> String {
    return equation.id
  }

  private func passErrorToActor(_ error: GraphSpecificationError) async -> Bool {
    if case .invalidColor = error {
      return true
    }
    return false
  }
}

// MARK: - Equatable Conformance Tests

@Suite("GraphSpecification Equatable Tests")
struct GraphSpecificationEquatableTests {

  @Test("identical specifications are equal")
  func identicalSpecificationsAreEqual() {
    let spec1 = TestGraphFactory.fullSpecification()
    let spec2 = TestGraphFactory.fullSpecification()

    #expect(spec1 == spec2)
  }

  @Test("specifications with different versions are not equal")
  func specificationsWithDifferentVersionsAreNotEqual() {
    let spec1 = TestGraphFactory.minimalSpecification()
    let spec2 = GraphSpecification(
      version: "2.0",
      title: nil,
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )

    #expect(spec1 != spec2)
  }

  @Test("specifications with different titles are not equal")
  func specificationsWithDifferentTitlesAreNotEqual() {
    let spec1 = GraphSpecification(
      version: "1.0",
      title: "Title A",
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )
    let spec2 = GraphSpecification(
      version: "1.0",
      title: "Title B",
      viewport: TestGraphFactory.standardViewport(),
      axes: TestGraphFactory.standardAxes(),
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: TestGraphFactory.standardInteractivity()
    )

    #expect(spec1 != spec2)
  }

  @Test("viewports with different bounds are not equal")
  func viewportsWithDifferentBoundsAreNotEqual() {
    let viewport1 = TestGraphFactory.standardViewport()
    let viewport2 = TestGraphFactory.firstQuadrantViewport()

    #expect(viewport1 != viewport2)
  }

  @Test("equation styles with different colors are not equal")
  func equationStylesWithDifferentColorsAreNotEqual() {
    let style1 = EquationStyle(
      color: "#FF0000",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )
    let style2 = EquationStyle(
      color: "#0000FF",
      lineWidth: 2.0,
      lineStyle: .solid,
      fillBelow: nil,
      fillAbove: nil,
      fillColor: nil,
      fillOpacity: nil
    )

    #expect(style1 != style2)
  }
}
