// GraphViewModelContract.swift
// Defines the API contract for the GraphViewModel that manages graph state and coordinate transforms.
// This view model bridges GraphSpecification data with SwiftUI rendering and user interactions.
// Handles pan, zoom, and trace gestures while maintaining viewport state.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation
import SwiftUI

// MARK: - API Contract

// MARK: - CoordinatePoint Struct

// Represents a point in graph coordinates (mathematical space).
// Distinct from CGPoint which represents screen coordinates.
struct CoordinatePoint: Sendable, Equatable {
  // X coordinate in graph space.
  let x: Double

  // Y coordinate in graph space.
  let y: Double

  // Creates a coordinate point at the origin.
  static let origin = CoordinatePoint(x: 0.0, y: 0.0)

  // Creates a coordinate point from a CGPoint (for convenience).
  init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  // Convenience initializer from CGFloat values.
  init(x: CGFloat, y: CGFloat) {
    self.x = Double(x)
    self.y = Double(y)
  }
}

/*
 ACCEPTANCE CRITERIA: CoordinatePoint

 SCENARIO: Create point at origin
 GIVEN: CoordinatePoint.origin
 WHEN: Accessed
 THEN: x is 0.0 and y is 0.0

 SCENARIO: Create point with coordinates
 GIVEN: CoordinatePoint(x: 3.5, y: -2.0)
 WHEN: Created
 THEN: x is 3.5 and y is -2.0

 SCENARIO: Equatable comparison
 GIVEN: Two CoordinatePoint values
 WHEN: Compared for equality
 THEN: Returns true only if both x and y match
*/

// MARK: - MutableGraphViewport Struct

// Mutable version of GraphViewport for runtime viewport changes.
// Created from specification's viewport and modified by pan/zoom.
struct MutableGraphViewport: Sendable, Equatable {
  // Minimum X coordinate visible.
  var xMin: Double

  // Maximum X coordinate visible.
  var xMax: Double

  // Minimum Y coordinate visible.
  var yMin: Double

  // Maximum Y coordinate visible.
  var yMax: Double

  // Aspect ratio mode (preserved from original).
  let aspectRatio: AspectRatioMode

  // Creates a mutable viewport from an immutable GraphViewport.
  init(from viewport: GraphViewport) {
    self.xMin = viewport.xMin
    self.xMax = viewport.xMax
    self.yMin = viewport.yMin
    self.yMax = viewport.yMax
    self.aspectRatio = viewport.aspectRatio
  }

  // Width of viewport in graph units.
  var width: Double { xMax - xMin }

  // Height of viewport in graph units.
  var height: Double { yMax - yMin }

  // Center point of viewport.
  var center: CoordinatePoint {
    CoordinatePoint(x: (xMin + xMax) / 2, y: (yMin + yMax) / 2)
  }

  // Converts to immutable GraphViewport.
  func toGraphViewport() -> GraphViewport {
    GraphViewport(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      aspectRatio: aspectRatio
    )
  }
}

/*
 ACCEPTANCE CRITERIA: MutableGraphViewport

 SCENARIO: Create from GraphViewport
 GIVEN: GraphViewport with xMin: -10, xMax: 10, yMin: -5, yMax: 5
 WHEN: MutableGraphViewport(from:) is called
 THEN: All values are copied
  AND: aspectRatio is preserved

 SCENARIO: Compute width and height
 GIVEN: MutableGraphViewport with xMin: -10, xMax: 10, yMin: -5, yMax: 5
 WHEN: width and height are accessed
 THEN: width is 20.0
  AND: height is 10.0

 SCENARIO: Compute center
 GIVEN: MutableGraphViewport with xMin: 0, xMax: 10, yMin: 0, yMax: 10
 WHEN: center is accessed
 THEN: Returns CoordinatePoint(x: 5, y: 5)

 SCENARIO: Modify viewport values
 GIVEN: A MutableGraphViewport
 WHEN: xMin is changed from -10 to -20
 THEN: Value is updated
  AND: width reflects new value

 SCENARIO: Convert back to GraphViewport
 GIVEN: A modified MutableGraphViewport
 WHEN: toGraphViewport() is called
 THEN: Returns GraphViewport with current values
  AND: Can be serialized or passed to renderer
*/

// MARK: - TraceState Struct

// Represents the current state of curve tracing.
// Tracks which equation is being traced and at what position.
struct TraceState: Sendable, Equatable {
  // The equation being traced (by ID).
  let equationID: String

  // Current position in graph coordinates.
  let position: CoordinatePoint

  // Parameter value (t for parametric, theta for polar, x for explicit).
  let parameterValue: Double

  // Y value at the traced point (for explicit equations).
  // May be nil for parametric/polar where position is the result.
  let yValue: Double?
}

/*
 ACCEPTANCE CRITERIA: TraceState

 SCENARIO: Trace explicit equation
 GIVEN: Equation y = x^2 being traced at x = 2
 WHEN: TraceState is created
 THEN: equationID identifies the equation
  AND: position is (2, 4) in graph coordinates
  AND: parameterValue is 2 (the x value)
  AND: yValue is 4

 SCENARIO: Trace parametric equation
 GIVEN: Parametric equation traced at t = pi
 WHEN: TraceState is created
 THEN: position contains (x(pi), y(pi))
  AND: parameterValue is pi
  AND: yValue is nil (use position.y)

 SCENARIO: Trace polar equation
 GIVEN: Polar equation traced at theta = pi/4
 WHEN: TraceState is created
 THEN: position contains Cartesian (x, y) from (r, theta)
  AND: parameterValue is pi/4
  AND: yValue is nil
*/

// MARK: - SampledCurve Struct

// Represents a sampled curve ready for rendering.
// Contains arrays of points and handles discontinuities.
struct SampledCurve: Sendable, Equatable {
  // Continuous segments of the curve (separated by discontinuities).
  let segments: [[CGPoint]]

  // The equation this curve represents (by ID).
  let equationID: String

  // Whether this curve has any valid points.
  var isEmpty: Bool { segments.allSatisfy { $0.isEmpty } }

  // Total number of points across all segments.
  var totalPointCount: Int { segments.reduce(0) { $0 + $1.count } }
}

/*
 ACCEPTANCE CRITERIA: SampledCurve

 SCENARIO: Continuous curve
 GIVEN: Equation y = x^2 sampled over [-5, 5]
 WHEN: SampledCurve is created
 THEN: segments contains single array with all points
  AND: No discontinuities means one segment

 SCENARIO: Curve with asymptote
 GIVEN: Equation y = 1/x sampled over [-5, 5]
 WHEN: SampledCurve is created
 THEN: segments contains two arrays
  AND: One for x < 0, one for x > 0
  AND: Discontinuity at x = 0 separates segments

 SCENARIO: Multiple discontinuities
 GIVEN: Equation y = tan(x) sampled over [-2pi, 2pi]
 WHEN: SampledCurve is created
 THEN: segments contains multiple arrays
  AND: Each asymptote creates a segment break

 SCENARIO: Empty curve check
 GIVEN: An equation that produces no valid points
 WHEN: isEmpty is checked
 THEN: Returns true
  AND: All segments are empty

 SCENARIO: Total point count
 GIVEN: SampledCurve with segments [[p1, p2, p3], [p4, p5]]
 WHEN: totalPointCount is accessed
 THEN: Returns 5
*/

// MARK: - GraphViewModelProtocol

// Protocol for the graph view model.
// Manages state, coordinate transforms, and user interactions.
// ObservableObject for SwiftUI integration.
protocol GraphViewModelProtocol: ObservableObject, AnyObject {
  // The graph specification being displayed.
  var specification: GraphSpecification { get set }

  // Current viewport state (mutable, may differ from specification.viewport).
  var currentViewport: MutableGraphViewport { get set }

  // Size of the view in screen coordinates.
  var viewSize: CGSize { get set }

  // Current trace state, if user is tracing a curve.
  var traceState: TraceState? { get set }

  // Whether the view is currently in trace mode.
  var isTracing: Bool { get }

  // MARK: - Coordinate Transforms

  // Converts a point from graph coordinates to screen coordinates.
  func graphToScreen(_ point: CoordinatePoint) -> CGPoint

  // Converts a point from screen coordinates to graph coordinates.
  func screenToGraph(_ point: CGPoint) -> CoordinatePoint

  // Converts a horizontal distance from graph units to screen points.
  func graphToScreenX(_ graphX: Double) -> CGFloat

  // Converts a vertical distance from graph units to screen points.
  func graphToScreenY(_ graphY: Double) -> CGFloat

  // MARK: - Viewport Manipulation

  // Pans the viewport by a delta in screen coordinates.
  func pan(by delta: CGSize)

  // Zooms the viewport by a scale factor around a screen point.
  func zoom(scale: CGFloat, around screenPoint: CGPoint)

  // Resets viewport to the original specification viewport.
  func resetViewport()

  // MARK: - Equation Sampling

  // Samples points for an equation within the current viewport.
  // Returns a SampledCurve with screen coordinates.
  func sampleEquation(_ equation: GraphEquation) -> SampledCurve

  // Returns the sample resolution (number of points) based on viewport and screen size.
  var sampleResolution: Int { get }

  // MARK: - Tracing

  // Starts tracing the equation nearest to the given screen point.
  func startTrace(at screenPoint: CGPoint)

  // Updates trace position to nearest point on traced equation.
  func updateTrace(to screenPoint: CGPoint)

  // Ends trace mode.
  func endTrace()

  // Finds the closest equation to a screen point.
  // Returns equation ID and distance, or nil if no equations.
  func closestEquation(to screenPoint: CGPoint) -> (equationID: String, distance: CGFloat)?
}

/*
 ACCEPTANCE CRITERIA: GraphViewModelProtocol - Initialization

 SCENARIO: Create view model with specification
 GIVEN: A GraphSpecification with viewport -10 to 10
 WHEN: GraphViewModel is created
 THEN: specification is set
  AND: currentViewport matches specification.viewport
  AND: traceState is nil

 SCENARIO: Update view size
 GIVEN: A GraphViewModel
 WHEN: viewSize is set to CGSize(width: 400, height: 300)
 THEN: Coordinate transforms use new size
  AND: Sample resolution may change
*/

/*
 ACCEPTANCE CRITERIA: GraphViewModelProtocol - Coordinate Transforms

 SCENARIO: Graph to screen at center
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: graphToScreen(CoordinatePoint(x: 0, y: 0)) is called
 THEN: Returns CGPoint(x: 200, y: 200) (center of view)

 SCENARIO: Graph to screen at corner
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: graphToScreen(CoordinatePoint(x: -10, y: 10)) is called
 THEN: Returns CGPoint(x: 0, y: 0) (top-left)
  AND: Y is inverted (graph up is screen up/negative)

 SCENARIO: Screen to graph at center
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: screenToGraph(CGPoint(x: 200, y: 200)) is called
 THEN: Returns CoordinatePoint(x: 0, y: 0) (origin)

 SCENARIO: Screen to graph at edge
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: screenToGraph(CGPoint(x: 400, y: 400)) is called
 THEN: Returns CoordinatePoint(x: 10, y: -10) (bottom-right in graph)

 SCENARIO: Asymmetric viewport
 GIVEN: Viewport x: 0 to 100, y: 0 to 50, viewSize 200x100
 WHEN: graphToScreen(CoordinatePoint(x: 50, y: 25)) is called
 THEN: Returns CGPoint(x: 100, y: 50) (center)

 SCENARIO: Non-square view size
 GIVEN: Viewport -10 to 10 (square), viewSize 800x400
 WHEN: Coordinate transforms are used
 THEN: Aspect ratio differences are handled
  AND: Circles may appear as ellipses (depending on aspectRatio mode)

 EDGE CASE: Zero view size
 GIVEN: viewSize is CGSize.zero
 WHEN: graphToScreen is called
 THEN: Returns CGPoint.zero or handles gracefully
  AND: No division by zero crash

 EDGE CASE: Zero-width viewport
 GIVEN: Viewport with xMin = xMax = 5
 WHEN: screenToGraph is called
 THEN: Handles gracefully (returns fixed x value)
  AND: No division by zero crash
*/

/*
 ACCEPTANCE CRITERIA: GraphViewModelProtocol - Pan

 SCENARIO: Pan right
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: pan(by: CGSize(width: 40, height: 0)) is called
 THEN: Viewport shifts left (panning right shows more right side)
  AND: xMin and xMax both decrease by 1 (40px = 1 unit at 20px/unit)

 SCENARIO: Pan up
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: pan(by: CGSize(width: 0, height: -40)) is called
 THEN: Viewport shifts up (panning up shows more top)
  AND: yMin and yMax both increase

 SCENARIO: Pan diagonal
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: pan(by: CGSize(width: 20, height: 20)) is called
 THEN: Viewport shifts in both axes
  AND: Both x and y ranges change

 SCENARIO: Pan disabled
 GIVEN: specification.interactivity.allowPan is false
 WHEN: pan(by:) is called
 THEN: Viewport does not change
  AND: Gesture has no effect

 EDGE CASE: Pan beyond reasonable limits
 GIVEN: Very large pan delta (1000000 pixels)
 WHEN: pan(by:) is called
 THEN: Viewport may be clamped to reasonable bounds
  AND: No overflow or crash
*/

/*
 ACCEPTANCE CRITERIA: GraphViewModelProtocol - Zoom

 SCENARIO: Zoom in at center
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: zoom(scale: 2.0, around: CGPoint(x: 200, y: 200)) is called
 THEN: Viewport becomes -5 to 5
  AND: Center remains at origin
  AND: Width and height halved

 SCENARIO: Zoom out at center
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: zoom(scale: 0.5, around: CGPoint(x: 200, y: 200)) is called
 THEN: Viewport becomes -20 to 20
  AND: Center remains at origin
  AND: Width and height doubled

 SCENARIO: Zoom at off-center point
 GIVEN: Viewport -10 to 10, viewSize 400x400
 WHEN: zoom(scale: 2.0, around: CGPoint(x: 100, y: 100)) is called
 THEN: The point under (100, 100) stays fixed
  AND: Other parts of viewport move toward/away from that point
  AND: Center of viewport shifts

 SCENARIO: Zoom disabled
 GIVEN: specification.interactivity.allowZoom is false
 WHEN: zoom(scale:around:) is called
 THEN: Viewport does not change
  AND: Gesture has no effect

 EDGE CASE: Scale factor of 1.0
 GIVEN: Any viewport
 WHEN: zoom(scale: 1.0, around: anyPoint) is called
 THEN: Viewport is unchanged

 EDGE CASE: Scale factor of 0
 GIVEN: Any viewport
 WHEN: zoom(scale: 0, around: anyPoint) is called
 THEN: Zoom is ignored or clamped to minimum
  AND: No division by zero or degenerate viewport

 EDGE CASE: Very large scale factor
 GIVEN: Viewport -10 to 10
 WHEN: zoom(scale: 1e10, around: center) is called
 THEN: Viewport may be clamped to minimum size
  AND: Prevents numerical precision issues

 EDGE CASE: Very small scale factor
 GIVEN: Viewport -10 to 10
 WHEN: zoom(scale: 1e-10, around: center) is called
 THEN: Viewport may be clamped to maximum size
  AND: Prevents unusably large viewports
*/

/*
 ACCEPTANCE CRITERIA: GraphViewModelProtocol - Reset Viewport

 SCENARIO: Reset after pan
 GIVEN: Viewport panned from -10,10 to -5,15
 WHEN: resetViewport() is called
 THEN: Viewport returns to -10,10
  AND: Original specification viewport is restored

 SCENARIO: Reset after zoom
 GIVEN: Viewport zoomed from -10,10 to -5,5
 WHEN: resetViewport() is called
 THEN: Viewport returns to -10,10

 SCENARIO: Reset after pan and zoom
 GIVEN: Viewport modified by multiple operations
 WHEN: resetViewport() is called
 THEN: Viewport returns to original specification values
  AND: All modifications are discarded
*/

/*
 ACCEPTANCE CRITERIA: GraphViewModelProtocol - Equation Sampling

 SCENARIO: Sample explicit equation
 GIVEN: Equation y = x^2 and viewport -10 to 10
 WHEN: sampleEquation(equation) is called
 THEN: Returns SampledCurve with points in screen coordinates
  AND: Points form parabola shape
  AND: Sufficient density for smooth curve

 SCENARIO: Sample parametric equation
 GIVEN: Parametric x = cos(t), y = sin(t) with t in [0, 2pi]
 WHEN: sampleEquation(equation) is called
 THEN: Returns SampledCurve forming circle
  AND: Points are in screen coordinates

 SCENARIO: Sample polar equation
 GIVEN: Polar r = 1 + cos(theta)
 WHEN: sampleEquation(equation) is called
 THEN: Returns SampledCurve forming cardioid
  AND: Points converted from (r, theta) to Cartesian to screen

 SCENARIO: Sample equation with discontinuity
 GIVEN: Equation y = 1/x
 WHEN: sampleEquation(equation) is called
 THEN: Returns SampledCurve with multiple segments
  AND: Discontinuity at x = 0 separates segments
  AND: No line drawn across asymptote

 SCENARIO: Sample hidden equation
 GIVEN: Equation with visible = false
 WHEN: sampleEquation(equation) is called
 THEN: Returns empty SampledCurve
  AND: No points generated

 SCENARIO: Sample resolution adapts to view size
 GIVEN: Small viewSize (100x100) vs large viewSize (1000x1000)
 WHEN: sampleResolution is accessed
 THEN: Larger view has higher resolution
  AND: Maintains visual quality

 EDGE CASE: Equation with domain restriction outside viewport
 GIVEN: Equation with domain x in [100, 200] but viewport -10 to 10
 WHEN: sampleEquation(equation) is called
 THEN: Returns empty SampledCurve
  AND: No points in visible range

 EDGE CASE: Invalid expression
 GIVEN: Equation with malformed expression
 WHEN: sampleEquation(equation) is called
 THEN: Returns empty SampledCurve or error state
  AND: Does not crash
*/

/*
 ACCEPTANCE CRITERIA: GraphViewModelProtocol - Tracing

 SCENARIO: Start trace on equation
 GIVEN: Equation y = x^2 visible in viewport
 WHEN: startTrace(at: screenPointNearCurve) is called
 THEN: traceState is set
  AND: equationID matches nearest equation
  AND: position is on the curve

 SCENARIO: Update trace position
 GIVEN: Tracing equation y = x^2
 WHEN: updateTrace(to: newScreenPoint) is called
 THEN: traceState.position updates to nearest point on curve
  AND: parameterValue (x) updates accordingly
  AND: yValue reflects f(x)

 SCENARIO: End trace
 GIVEN: Currently tracing
 WHEN: endTrace() is called
 THEN: traceState becomes nil
  AND: isTracing returns false

 SCENARIO: Trace disabled
 GIVEN: specification.interactivity.allowTrace is false
 WHEN: startTrace(at:) is called
 THEN: traceState remains nil
  AND: No trace mode activated

 SCENARIO: Find closest equation
 GIVEN: Multiple equations in viewport
 WHEN: closestEquation(to: screenPoint) is called
 THEN: Returns ID of nearest equation
  AND: Returns distance in screen points
  AND: Hidden equations are excluded

 EDGE CASE: No equations to trace
 GIVEN: Empty equations array
 WHEN: startTrace(at:) is called
 THEN: traceState remains nil
  AND: closestEquation returns nil

 EDGE CASE: Trace at discontinuity
 GIVEN: Tracing y = 1/x near x = 0
 WHEN: updateTrace moves toward x = 0
 THEN: Trace snaps to nearest valid point on curve
  AND: Does not report position at discontinuity
*/

// MARK: - GraphViewModelError Enum

// Errors that can occur in graph view model operations.
enum GraphViewModelError: Error, LocalizedError, Equatable, Sendable {
  // Failed to parse equation expression.
  case expressionParsingFailed(equationID: String, reason: String)

  // Equation type not supported for operation.
  case unsupportedEquationType(equationID: String, type: EquationType)

  // No valid points could be generated.
  case noValidPoints(equationID: String)

  // Viewport configuration is invalid.
  case invalidViewport(reason: String)

  var errorDescription: String? {
    switch self {
    case .expressionParsingFailed(let id, let reason):
      return "Failed to parse equation '\(id)': \(reason)"
    case .unsupportedEquationType(let id, let type):
      return "Unsupported equation type '\(type.rawValue)' for equation '\(id)'"
    case .noValidPoints(let id):
      return "No valid points could be generated for equation '\(id)'"
    case .invalidViewport(let reason):
      return "Invalid viewport: \(reason)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: GraphViewModelError

 SCENARIO: Expression parsing failed
 GIVEN: Equation with invalid expression "x^^2"
 WHEN: Sampling is attempted
 THEN: GraphViewModelError.expressionParsingFailed is generated
  AND: equationID identifies the problematic equation
  AND: reason describes the parsing error

 SCENARIO: Unsupported equation type
 GIVEN: Implicit equation (not yet implemented)
 WHEN: Rendering is attempted
 THEN: GraphViewModelError.unsupportedEquationType is generated
  AND: Indicates what type is not supported

 SCENARIO: No valid points
 GIVEN: Equation that produces only NaN values in viewport
 WHEN: Sampling completes
 THEN: GraphViewModelError.noValidPoints may be reported
  AND: UI can show appropriate feedback
*/

// MARK: - Constants

// Constants for graph view model behavior.
enum GraphViewModelConstants {
  // Minimum viewport width/height in graph units.
  static let minimumViewportSize: Double = 1e-10

  // Maximum viewport width/height in graph units.
  static let maximumViewportSize: Double = 1e15

  // Default sample resolution (points per viewport width).
  static let defaultSampleResolution: Int = 500

  // Minimum sample resolution.
  static let minimumSampleResolution: Int = 50

  // Maximum sample resolution.
  static let maximumSampleResolution: Int = 5000

  // Threshold for discontinuity detection (ratio of y-values).
  static let discontinuityThreshold: Double = 1000.0

  // Maximum distance (in screen points) to consider for trace snap.
  static let traceSnapDistance: CGFloat = 50.0

  // Samples per screen pixel for high-quality rendering.
  static let samplesPerPixel: Double = 0.5
}

/*
 ACCEPTANCE CRITERIA: GraphViewModelConstants

 SCENARIO: Viewport size limits
 GIVEN: User attempts to zoom very far in
 WHEN: Viewport would become smaller than minimumViewportSize
 THEN: Zoom is limited
  AND: Viewport width/height stays above minimum

 SCENARIO: Sample resolution calculation
 GIVEN: viewSize.width = 800
 WHEN: sampleResolution is calculated
 THEN: Uses samplesPerPixel to determine count
  AND: Clamped between minimum and maximum
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Empty specification
 GIVEN: GraphSpecification with no equations
 WHEN: GraphViewModel is created
 THEN: Viewport and axes still render
  AND: No equations to sample

 EDGE CASE: All equations hidden
 GIVEN: GraphSpecification where all equations have visible = false
 WHEN: Rendered
 THEN: Only axes and grid are shown
  AND: Trace cannot find any equations

 EDGE CASE: Specification update while tracing
 GIVEN: User is tracing equation "eq1"
 WHEN: specification is updated with new equations (without "eq1")
 THEN: Trace is ended
  AND: traceState becomes nil

 EDGE CASE: View size changes during trace
 GIVEN: User is tracing
 WHEN: viewSize changes (rotation, resize)
 THEN: Trace position recalculates for new size
  AND: Same graph point is shown

 EDGE CASE: Viewport with negative width
 GIVEN: Attempt to set xMin > xMax
 WHEN: Validation runs
 THEN: Values are swapped or error is thrown
  AND: Viewport always has positive width

 EDGE CASE: Concurrent viewport modifications
 GIVEN: Pan and zoom happening simultaneously
 WHEN: Both modify viewport
 THEN: Final state is consistent
  AND: No viewport corruption

 EDGE CASE: Very large number of equations
 GIVEN: Specification with 100 equations
 WHEN: All are sampled
 THEN: Performance remains acceptable
  AND: May use progressive rendering

 EDGE CASE: Equation at exact viewport boundary
 GIVEN: Horizontal line y = 10, viewport yMax = 10
 WHEN: Rendered
 THEN: Line is visible at top edge
  AND: Not clipped out

 EDGE CASE: Pan gesture momentum
 GIVEN: User performs quick pan gesture
 WHEN: Gesture ends
 THEN: Viewport position is stable
  AND: No momentum animation (unless explicitly added)

 EDGE CASE: Pinch zoom with scale going through 1.0
 GIVEN: User pinches then reverse direction
 WHEN: Scale crosses 1.0
 THEN: Zoom direction reverses smoothly
  AND: No jump or discontinuity

 EDGE CASE: Screen to graph with equal aspect mode
 GIVEN: aspectRatio = .equal with non-square view
 WHEN: Coordinate transforms are used
 THEN: Additional padding is accounted for
  AND: Equal scaling in both dimensions

 EDGE CASE: Trace on overlapping equations
 GIVEN: Two equations that cross (y = x and y = -x + 2)
 WHEN: User traces at intersection point
 THEN: One equation is selected consistently
  AND: Can switch between equations near intersection
*/

// MARK: - Integration Points

/*
 INTEGRATION: GraphView (SwiftUI)
 GraphViewModel is an @ObservedObject in GraphView.
 Published properties trigger view updates.
 Gesture handlers call pan, zoom, trace methods.

 INTEGRATION: EquationRenderer
 GraphViewModel provides sampled points to EquationRenderer.
 EquationRenderer converts SampledCurve to SwiftUI Path.
 Coordinate transforms are used by both.

 INTEGRATION: MathExpressionParser
 GraphViewModel uses parser for equation evaluation during sampling.
 Parsing errors are caught and reported via GraphViewModelError.

 INTEGRATION: GraphSpecification
 GraphViewModel wraps GraphSpecification.
 Specification can be updated (e.g., when new graph is generated).
 Viewport reset uses original specification.viewport.

 INTEGRATION: UIKit Gestures (via UIViewRepresentable)
 Complex gestures may need UIKit for better handling.
 GraphViewModel provides gesture handling methods.
 State changes trigger SwiftUI view updates.
*/

// MARK: - Threading Requirements

/*
 THREADING: MainActor for observable properties
 GraphViewModel is @MainActor for SwiftUI compatibility.
 All published properties modified on main thread.
 Gesture handlers run on main thread.

 THREADING: Background sampling
 Heavy sampling calculations can run on background.
 Results dispatched to main thread.
 Sampling cancellation supported.

 THREADING: Specification updates
 Specification can be updated from any thread.
 View model handles thread-safe property updates.
*/
