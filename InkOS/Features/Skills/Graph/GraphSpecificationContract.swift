// GraphSpecificationContract.swift
// Defines the API contract for the GraphingCalculator skill's GraphSpecification types.
// This skill provides Desmos/MATLAB-level graphing capabilities.
// Takes handwritten math content (JIIX) or direct specification and returns a rich
// GraphSpecification that can be rendered interactively with pan, zoom, trace, and
// coordinate inspection.
// This contract specifies all type definitions, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation

// MARK: - API Contract

// MARK: - GraphSpecification Struct

// Main container for an entire graph specification.
// Returned by the GraphingCalculator skill after AI interpretation.
// Contains all data needed to render an interactive mathematical graph.
struct GraphSpecification: Sendable, Equatable, Codable {
  // Schema version for forward compatibility (e.g., "1.0").
  let version: String

  // Optional title displayed above the graph.
  let title: String?

  // Visible region of the coordinate plane.
  let viewport: GraphViewport

  // Configuration for X and Y axes.
  let axes: GraphAxes

  // Equations/functions to plot on the graph.
  let equations: [GraphEquation]

  // Individual points to plot (optional).
  let points: [GraphPoint]?

  // Labels and arrows on the graph (optional).
  let annotations: [GraphAnnotation]?

  // User interaction settings.
  let interactivity: GraphInteractivity
}

/*
 ACCEPTANCE CRITERIA: GraphSpecification

 SCENARIO: Create basic graph specification
 GIVEN: A simple linear equation y = 2x + 1
 WHEN: GraphSpecification is created
 THEN: version is "1.0"
  AND: equations contains one explicit equation
  AND: viewport has reasonable default bounds
  AND: interactivity allows pan and zoom

 SCENARIO: Create graph with title
 GIVEN: A graph specification with title "Quadratic Functions"
 WHEN: GraphSpecification is serialized and deserialized
 THEN: title is preserved as "Quadratic Functions"
  AND: Title can be displayed in UI

 SCENARIO: Create graph with multiple equations
 GIVEN: Three equations: y = x^2, y = sin(x), y = 1/x
 WHEN: GraphSpecification is created
 THEN: equations array contains all three
  AND: Each equation has unique id
  AND: Each can be styled independently

 SCENARIO: Create graph with points and annotations
 GIVEN: A parabola with vertex labeled
 WHEN: GraphSpecification is created
 THEN: points contains the vertex point
  AND: annotations contains a label at the vertex
  AND: Both can be rendered on top of equations

 SCENARIO: Decode graph specification from JSON
 GIVEN: Valid JSON from AI/cloud response
 WHEN: Decoded to GraphSpecification
 THEN: All fields are populated correctly
  AND: Nested structures are preserved
  AND: Optional fields may be nil

 SCENARIO: Encode graph specification to JSON
 GIVEN: A GraphSpecification instance
 WHEN: Encoded to JSON
 THEN: Valid JSON is produced
  AND: Can be transmitted to rendering engine
  AND: Nil optionals are omitted

 EDGE CASE: Empty equations array
 GIVEN: A GraphSpecification with no equations
 WHEN: Specification is validated
 THEN: Specification is valid (might show axes only)
  AND: Rendering succeeds with empty graph

 EDGE CASE: Unknown version
 GIVEN: A specification with version "2.0"
 WHEN: Parsed by version "1.0" renderer
 THEN: Renderer should handle gracefully
  AND: May ignore unknown fields
*/

// MARK: - GraphViewport Struct

// Defines the visible region of the coordinate plane.
// Controls what portion of the graph is initially visible.
struct GraphViewport: Sendable, Equatable, Codable {
  // Minimum X coordinate visible.
  let xMin: Double

  // Maximum X coordinate visible.
  let xMax: Double

  // Minimum Y coordinate visible.
  let yMin: Double

  // Maximum Y coordinate visible.
  let yMax: Double

  // How aspect ratio is handled during pan/zoom.
  let aspectRatio: AspectRatioMode
}

/*
 ACCEPTANCE CRITERIA: GraphViewport

 SCENARIO: Standard viewport bounds
 GIVEN: A typical math graph
 WHEN: GraphViewport is created with xMin: -10, xMax: 10, yMin: -10, yMax: 10
 THEN: Center of viewport is at origin (0, 0)
  AND: Width is 20 units, height is 20 units

 SCENARIO: Asymmetric viewport
 GIVEN: A graph focusing on first quadrant
 WHEN: GraphViewport is created with xMin: 0, xMax: 100, yMin: 0, yMax: 50
 THEN: Only positive values are visible
  AND: Origin is at bottom-left corner

 SCENARIO: Viewport with equal aspect ratio
 GIVEN: A viewport with aspectRatio = .equal
 WHEN: Rendered on non-square screen
 THEN: One unit in X equals one unit in Y visually
  AND: Circles appear circular, not elliptical

 SCENARIO: Viewport with auto aspect ratio
 GIVEN: A viewport with aspectRatio = .auto
 WHEN: Rendered
 THEN: Viewport fills available space
  AND: Axes may have different visual scales

 EDGE CASE: Inverted viewport (xMax < xMin)
 GIVEN: GraphViewport with xMin: 10, xMax: -10
 WHEN: Specification is used
 THEN: Renderer should handle by swapping values
  AND: Or throw validation error during creation

 EDGE CASE: Zero-width viewport
 GIVEN: GraphViewport with xMin: 5, xMax: 5
 WHEN: Specification is validated
 THEN: Invalid viewport (division by zero risk)
  AND: Should be rejected or auto-expanded

 EDGE CASE: Extremely large viewport
 GIVEN: GraphViewport with xMin: -1e15, xMax: 1e15
 WHEN: Rendered
 THEN: May have precision issues at extreme zoom
  AND: Grid lines may not render at reasonable intervals
*/

// MARK: - AspectRatioMode Enum

// Controls how the aspect ratio is maintained during rendering and interaction.
enum AspectRatioMode: String, Sendable, Equatable, Codable {
  // Renderer automatically determines aspect ratio based on viewport and screen.
  case auto

  // Forces 1:1 aspect ratio so circles appear circular.
  // One unit in X equals one unit in Y visually.
  case equal

  // Allows free stretching to fill available space.
  // X and Y may have different visual scales.
  case free
}

/*
 ACCEPTANCE CRITERIA: AspectRatioMode

 SCENARIO: Auto aspect ratio
 GIVEN: aspectRatio = .auto
 WHEN: Viewport is rendered
 THEN: System chooses appropriate ratio
  AND: Viewport fills available space reasonably

 SCENARIO: Equal aspect ratio for geometry
 GIVEN: aspectRatio = .equal
 WHEN: A circle equation is rendered
 THEN: Circle appears as circle, not ellipse
  AND: 45-degree lines appear at 45 degrees

 SCENARIO: Free aspect ratio for data
 GIVEN: aspectRatio = .free with data over vastly different X/Y ranges
 WHEN: Rendered
 THEN: Both axes fill available space
  AND: Visual scale differs between axes

 SCENARIO: Encode/decode aspect ratio
 GIVEN: Any AspectRatioMode value
 WHEN: Encoded to JSON and decoded
 THEN: Original value is preserved
  AND: Raw string value used ("auto", "equal", "free")
*/

// MARK: - GraphAxes Struct

// Configuration for both X and Y axes.
struct GraphAxes: Sendable, Equatable, Codable {
  // Configuration for the X axis.
  let x: AxisConfiguration

  // Configuration for the Y axis.
  let y: AxisConfiguration
}

/*
 ACCEPTANCE CRITERIA: GraphAxes

 SCENARIO: Standard axes configuration
 GIVEN: A typical mathematical graph
 WHEN: GraphAxes is created with default configurations
 THEN: Both axes are visible
  AND: Grid lines are shown
  AND: Tick labels are displayed

 SCENARIO: Asymmetric axis configuration
 GIVEN: X axis with label "Time (s)" and Y axis with label "Distance (m)"
 WHEN: GraphAxes is created
 THEN: Each axis can have different labels
  AND: Each axis can have different grid spacing

 SCENARIO: Hide grid on one axis
 GIVEN: X axis with showGrid: true, Y axis with showGrid: false
 WHEN: Rendered
 THEN: Only vertical grid lines appear
  AND: Horizontal grid lines are hidden
*/

// MARK: - AxisConfiguration Struct

// Configuration for a single axis (X or Y).
struct AxisConfiguration: Sendable, Equatable, Codable {
  // Optional label for the axis (e.g., "Time (seconds)").
  let label: String?

  // Spacing between grid lines in axis units.
  // If nil, auto-calculated based on viewport.
  let gridSpacing: Double?

  // Whether to show grid lines perpendicular to this axis.
  let showGrid: Bool

  // Whether to show the axis line itself.
  let showAxis: Bool

  // Whether to show numeric labels at tick marks.
  let tickLabels: Bool
}

/*
 ACCEPTANCE CRITERIA: AxisConfiguration

 SCENARIO: Axis with all features enabled
 GIVEN: An axis configuration with all options true
 WHEN: AxisConfiguration is created
 THEN: showGrid, showAxis, tickLabels are all true
  AND: Grid lines, axis line, and labels are all rendered

 SCENARIO: Axis with custom grid spacing
 GIVEN: An axis with gridSpacing: 5.0
 WHEN: Rendered
 THEN: Grid lines appear at multiples of 5
  AND: Tick marks align with grid

 SCENARIO: Axis with auto grid spacing
 GIVEN: An axis with gridSpacing: nil
 WHEN: Viewport changes during zoom
 THEN: Grid spacing auto-adjusts for readability
  AND: Appropriate density of lines maintained

 SCENARIO: Hidden axis
 GIVEN: An axis with showAxis: false and showGrid: false
 WHEN: Rendered
 THEN: No axis line appears
  AND: No grid lines for this axis
  AND: Other axis still visible if configured

 EDGE CASE: Negative grid spacing
 GIVEN: An axis with gridSpacing: -1.0
 WHEN: Specification is validated
 THEN: Should be rejected or use absolute value
  AND: Negative spacing is nonsensical

 EDGE CASE: Very small grid spacing
 GIVEN: An axis with gridSpacing: 0.0001 over viewport width 100
 WHEN: Rendered
 THEN: May have millions of grid lines
  AND: Performance protection needed
*/

// MARK: - GraphEquation Struct

// Represents a single equation/function to plot on the graph.
// Supports explicit, parametric, polar, implicit, and inequality forms.
struct GraphEquation: Sendable, Equatable, Codable, Identifiable {
  // Unique identifier for this equation.
  let id: String

  // The type/form of the equation.
  let type: EquationType

  // Expression for explicit equations (e.g., "x^2 + 2*x + 1").
  // Used when type is .explicit.
  let expression: String?

  // X component for parametric equations (e.g., "cos(t)").
  // Used when type is .parametric.
  let xExpression: String?

  // Y component for parametric equations (e.g., "sin(t)").
  // Used when type is .parametric.
  let yExpression: String?

  // Expression for polar equations (e.g., "1 + cos(theta)").
  // Used when type is .polar.
  let rExpression: String?

  // Independent variable name for explicit equations (default "x").
  let variable: String?

  // Parameter variable name for parametric equations (default "t").
  let parameter: String?

  // Domain restriction for explicit equations (x range).
  let domain: ParameterRange?

  // Range for parametric parameter t.
  let parameterRange: ParameterRange?

  // Range for polar angle theta.
  let thetaRange: ParameterRange?

  // Visual styling for this equation.
  let style: EquationStyle

  // Optional display label for legend.
  let label: String?

  // Whether this equation is visible (can be toggled).
  let visible: Bool

  // For inequalities: whether to fill the satisfied region.
  let fillRegion: Bool?

  // For inequalities: style of boundary ("solid", "dashed").
  let boundaryStyle: String?
}

/*
 ACCEPTANCE CRITERIA: GraphEquation

 SCENARIO: Create explicit equation y = f(x)
 GIVEN: A quadratic function y = x^2
 WHEN: GraphEquation is created with type .explicit
 THEN: expression is "x^2"
  AND: variable defaults to "x" if nil
  AND: xExpression, yExpression, rExpression are nil

 SCENARIO: Create parametric equation
 GIVEN: A unit circle x = cos(t), y = sin(t)
 WHEN: GraphEquation is created with type .parametric
 THEN: xExpression is "cos(t)"
  AND: yExpression is "sin(t)"
  AND: parameterRange defines t from 0 to 2*pi
  AND: expression is nil

 SCENARIO: Create polar equation
 GIVEN: A cardioid r = 1 + cos(theta)
 WHEN: GraphEquation is created with type .polar
 THEN: rExpression is "1 + cos(theta)"
  AND: thetaRange defines theta from 0 to 2*pi
  AND: expression, xExpression, yExpression are nil

 SCENARIO: Create implicit equation
 GIVEN: A circle x^2 + y^2 = 1
 WHEN: GraphEquation is created with type .implicit
 THEN: expression is "x^2 + y^2 - 1" (rearranged to F(x,y) = 0)
  AND: Requires special rendering algorithm

 SCENARIO: Create inequality with fill
 GIVEN: An inequality y < x^2
 WHEN: GraphEquation is created with type .inequality
 THEN: expression is "x^2"
  AND: fillRegion is true
  AND: style.fillBelow is true (region below curve)
  AND: boundaryStyle may be "dashed"

 SCENARIO: Hidden equation
 GIVEN: An equation with visible: false
 WHEN: Graph is rendered
 THEN: Equation is not drawn
  AND: Can be toggled visible by user
  AND: Still present in specification

 SCENARIO: Equation with domain restriction
 GIVEN: y = sqrt(x) with domain x >= 0
 WHEN: GraphEquation is created with domain { min: 0, max: nil }
 THEN: Curve only plotted for x >= 0
  AND: Negative x values not evaluated

 SCENARIO: Equation with custom variable name
 GIVEN: An equation using variable "n" instead of "x"
 WHEN: GraphEquation is created with variable: "n"
 THEN: Expression parser uses "n" as independent variable
  AND: Works with expression like "2*n + 1"

 EDGE CASE: Missing required expression for type
 GIVEN: type .explicit but expression is nil
 WHEN: Specification is validated
 THEN: Validation error: explicit requires expression

 EDGE CASE: Conflicting expressions
 GIVEN: type .explicit but both expression and rExpression set
 WHEN: Specification is validated
 THEN: Only expression is used for .explicit
  AND: rExpression is ignored (or validation error)

 EDGE CASE: Empty expression string
 GIVEN: expression is ""
 WHEN: Specification is validated
 THEN: Validation error: expression cannot be empty

 EDGE CASE: Malformed expression
 GIVEN: expression is "x^2 + + 3" (syntax error)
 WHEN: Parsed for rendering
 THEN: Parsing fails with clear error
  AND: Other equations still render
*/

// MARK: - EquationType Enum

// Defines the form/type of a mathematical equation.
enum EquationType: String, Sendable, Equatable, Codable {
  // Explicit function: y = f(x).
  case explicit

  // Parametric equations: x = f(t), y = g(t).
  case parametric

  // Polar equation: r = f(theta).
  case polar

  // Implicit equation: F(x, y) = 0.
  case implicit

  // Inequality: y < f(x), y > f(x), etc.
  case inequality
}

/*
 ACCEPTANCE CRITERIA: EquationType

 SCENARIO: Explicit function type
 GIVEN: EquationType.explicit
 WHEN: Renderer processes equation
 THEN: Uses expression field
  AND: Evaluates y for each x in domain

 SCENARIO: Parametric type
 GIVEN: EquationType.parametric
 WHEN: Renderer processes equation
 THEN: Uses xExpression and yExpression
  AND: Evaluates both for t in parameterRange

 SCENARIO: Polar type
 GIVEN: EquationType.polar
 WHEN: Renderer processes equation
 THEN: Uses rExpression
  AND: Converts (r, theta) to (x, y) for plotting

 SCENARIO: Implicit type
 GIVEN: EquationType.implicit
 WHEN: Renderer processes equation
 THEN: Uses marching squares or similar algorithm
  AND: Finds points where F(x,y) = 0

 SCENARIO: Inequality type
 GIVEN: EquationType.inequality
 WHEN: Renderer processes equation
 THEN: Plots boundary curve
  AND: Fills satisfied region if fillRegion is true
  AND: Boundary may be dashed per boundaryStyle

 SCENARIO: Encode/decode equation type
 GIVEN: Any EquationType value
 WHEN: Encoded to JSON and decoded
 THEN: Original value is preserved
  AND: Raw string used in JSON
*/

// MARK: - ParameterRange Struct

// Defines a range for parameters (domain, parameter range, theta range).
// Either bound may be nil for unbounded ranges.
struct ParameterRange: Sendable, Equatable, Codable {
  // Minimum value (inclusive). Nil means no lower bound.
  let min: Double?

  // Maximum value (inclusive). Nil means no upper bound.
  let max: Double?
}

/*
 ACCEPTANCE CRITERIA: ParameterRange

 SCENARIO: Bounded range
 GIVEN: ParameterRange with min: 0, max: 2*pi
 WHEN: Used as thetaRange for polar equation
 THEN: Theta varies from 0 to 2*pi
  AND: Full polar curve is plotted

 SCENARIO: Left-unbounded range
 GIVEN: ParameterRange with min: nil, max: 0
 WHEN: Used as domain for y = sqrt(-x)
 THEN: Function evaluated for x <= 0
  AND: No lower bound on x

 SCENARIO: Right-unbounded range
 GIVEN: ParameterRange with min: 0, max: nil
 WHEN: Used as domain for y = sqrt(x)
 THEN: Function evaluated for x >= 0
  AND: Extends to viewport's right edge

 SCENARIO: Fully unbounded range
 GIVEN: ParameterRange with min: nil, max: nil
 WHEN: Used as domain
 THEN: No domain restriction
  AND: Evaluated across entire viewport

 EDGE CASE: Inverted range (min > max)
 GIVEN: ParameterRange with min: 10, max: 0
 WHEN: Specification is validated
 THEN: Should swap values or reject
  AND: Consistent behavior defined

 EDGE CASE: Single point range (min == max)
 GIVEN: ParameterRange with min: 5, max: 5
 WHEN: Used for parametric t
 THEN: Only one point plotted
  AND: Valid but degenerate case

 EDGE CASE: Infinite bounds
 GIVEN: ParameterRange with min: -.infinity, max: .infinity
 WHEN: Encoded to JSON
 THEN: Special handling for infinity values
  AND: May use null or string representation
*/

// MARK: - EquationStyle Struct

// Visual styling for an equation's curve.
struct EquationStyle: Sendable, Equatable, Codable {
  // Color as hex string (e.g., "#FF0000" for red).
  let color: String

  // Width of the line in points.
  let lineWidth: Double

  // Style of the line (solid, dashed, dotted).
  let lineStyle: LineStyle

  // For inequalities: whether to fill below the curve.
  let fillBelow: Bool?

  // For inequalities: whether to fill above the curve.
  let fillAbove: Bool?

  // Fill color as hex string for inequality regions.
  let fillColor: String?

  // Opacity of fill region (0.0 to 1.0).
  let fillOpacity: Double?
}

/*
 ACCEPTANCE CRITERIA: EquationStyle

 SCENARIO: Basic line style
 GIVEN: EquationStyle with color "#0000FF", lineWidth: 2.0, lineStyle: .solid
 WHEN: Equation is rendered
 THEN: Blue solid line of width 2 is drawn
  AND: No fill regions

 SCENARIO: Dashed line style
 GIVEN: EquationStyle with lineStyle: .dashed
 WHEN: Equation is rendered
 THEN: Dashed line pattern is used
  AND: Dash length and gap are renderer-defined

 SCENARIO: Dotted line style
 GIVEN: EquationStyle with lineStyle: .dotted
 WHEN: Equation is rendered
 THEN: Dotted line pattern is used
  AND: Dots are evenly spaced

 SCENARIO: Inequality fill below
 GIVEN: EquationStyle with fillBelow: true, fillColor: "#FF0000", fillOpacity: 0.3
 WHEN: Inequality y > f(x) is rendered
 THEN: Region below curve is filled
  AND: Fill is red at 30% opacity
  AND: Curve boundary is still drawn

 SCENARIO: Inequality fill above
 GIVEN: EquationStyle with fillAbove: true
 WHEN: Inequality y < f(x) is rendered
 THEN: Region above curve is filled
  AND: Extends to viewport boundary

 EDGE CASE: Invalid hex color
 GIVEN: color: "not-a-color"
 WHEN: Specification is parsed
 THEN: Validation error or default color used
  AND: Behavior is defined

 EDGE CASE: Negative line width
 GIVEN: lineWidth: -1.0
 WHEN: Specification is validated
 THEN: Should reject or use absolute value
  AND: Zero width makes line invisible

 EDGE CASE: Fill opacity out of range
 GIVEN: fillOpacity: 1.5 (greater than 1.0)
 WHEN: Specification is validated
 THEN: Should clamp to 1.0 or reject
  AND: Valid range is 0.0 to 1.0
*/

// MARK: - LineStyle Enum

// Style of line used for drawing curves.
enum LineStyle: String, Sendable, Equatable, Codable {
  // Continuous solid line.
  case solid

  // Dashed line with gaps.
  case dashed

  // Dotted line.
  case dotted
}

/*
 ACCEPTANCE CRITERIA: LineStyle

 SCENARIO: Solid line rendering
 GIVEN: LineStyle.solid
 WHEN: Curve is rendered
 THEN: Continuous line is drawn
  AND: No gaps in the line

 SCENARIO: Dashed line rendering
 GIVEN: LineStyle.dashed
 WHEN: Curve is rendered
 THEN: Line has dash-gap pattern
  AND: Pattern repeats along curve

 SCENARIO: Dotted line rendering
 GIVEN: LineStyle.dotted
 WHEN: Curve is rendered
 THEN: Line is series of dots
  AND: Dots evenly spaced along curve

 SCENARIO: Encode/decode line style
 GIVEN: Any LineStyle value
 WHEN: Encoded to JSON and decoded
 THEN: Original value is preserved
*/

// MARK: - GraphPoint Struct

// An individual point to plot on the graph.
struct GraphPoint: Sendable, Equatable, Codable, Identifiable {
  // Unique identifier for this point.
  let id: String

  // X coordinate of the point.
  let x: Double

  // Y coordinate of the point.
  let y: Double

  // Optional label displayed near the point.
  let label: String?

  // Visual styling for this point.
  let style: PointStyle
}

/*
 ACCEPTANCE CRITERIA: GraphPoint

 SCENARIO: Create labeled point
 GIVEN: A critical point at (0, 1) labeled "Maximum"
 WHEN: GraphPoint is created
 THEN: id is unique
  AND: x is 0, y is 1
  AND: label is "Maximum"
  AND: Point and label are rendered

 SCENARIO: Create unlabeled point
 GIVEN: A data point at (3.5, 2.7) with no label
 WHEN: GraphPoint is created
 THEN: label is nil
  AND: Point is rendered without text

 SCENARIO: Point with custom style
 GIVEN: A red square point of size 8
 WHEN: GraphPoint is created with appropriate style
 THEN: style.color is "#FF0000"
  AND: style.shape is .square
  AND: style.size is 8.0

 EDGE CASE: Point at infinity
 GIVEN: GraphPoint with x: .infinity, y: 0
 WHEN: Specification is used
 THEN: Point is not rendered (off viewport)
  AND: No crash occurs

 EDGE CASE: NaN coordinates
 GIVEN: GraphPoint with x: .nan, y: 5
 WHEN: Specification is validated
 THEN: Should reject NaN values
  AND: Or skip point during rendering
*/

// MARK: - PointStyle Struct

// Visual styling for a graph point.
struct PointStyle: Sendable, Equatable, Codable {
  // Color as hex string (e.g., "#FF0000").
  let color: String

  // Size of the point in points.
  let size: Double

  // Shape of the point marker.
  let shape: PointShape
}

/*
 ACCEPTANCE CRITERIA: PointStyle

 SCENARIO: Circle point style
 GIVEN: PointStyle with shape: .circle, size: 6, color: "#00FF00"
 WHEN: Point is rendered
 THEN: Green circle of diameter 6 is drawn
  AND: Point is filled solid

 SCENARIO: Square point style
 GIVEN: PointStyle with shape: .square
 WHEN: Point is rendered
 THEN: Square marker is drawn
  AND: Size defines width/height

 SCENARIO: Triangle point style
 GIVEN: PointStyle with shape: .triangle
 WHEN: Point is rendered
 THEN: Triangle marker is drawn
  AND: Point is at center of triangle

 SCENARIO: Cross point style
 GIVEN: PointStyle with shape: .cross
 WHEN: Point is rendered
 THEN: Cross/X marker is drawn
  AND: Useful for scatter plots
*/

// MARK: - PointShape Enum

// Shape of a point marker.
enum PointShape: String, Sendable, Equatable, Codable {
  // Circular point.
  case circle

  // Square point.
  case square

  // Triangular point (pointing up).
  case triangle

  // Cross/X shaped point.
  case cross
}

/*
 ACCEPTANCE CRITERIA: PointShape

 SCENARIO: Encode/decode point shape
 GIVEN: Any PointShape value
 WHEN: Encoded to JSON and decoded
 THEN: Original value is preserved
  AND: Raw string used in JSON

 SCENARIO: All shapes distinguishable
 GIVEN: Multiple points with different shapes
 WHEN: Rendered on same graph
 THEN: Each shape is visually distinct
  AND: Legend can use shapes for differentiation
*/

// MARK: - GraphAnnotation Struct

// Labels, arrows, or lines overlaid on the graph.
struct GraphAnnotation: Sendable, Equatable, Codable {
  // Type of annotation (label, arrow, line).
  let type: AnnotationType

  // Text content for labels.
  let text: String?

  // Position of the annotation in graph coordinates.
  let position: GraphPosition

  // Anchor point for positioning (where text attaches).
  let anchor: AnchorPosition?
}

/*
 ACCEPTANCE CRITERIA: GraphAnnotation

 SCENARIO: Create text label annotation
 GIVEN: A label "y = x^2" at position (2, 4)
 WHEN: GraphAnnotation is created with type .label
 THEN: text is "y = x^2"
  AND: position is (2, 4)
  AND: Rendered as text at that location

 SCENARIO: Create annotation with anchor
 GIVEN: A label anchored at bottom-left of its position
 WHEN: GraphAnnotation is created with anchor: .bottomLeft
 THEN: Text's bottom-left corner is at position
  AND: Text extends up and to the right

 SCENARIO: Arrow annotation
 GIVEN: An arrow pointing to feature of interest
 WHEN: GraphAnnotation is created with type .arrow
 THEN: Arrow is drawn at position
  AND: Direction may be inferred or specified

 SCENARIO: Line annotation
 GIVEN: A horizontal reference line
 WHEN: GraphAnnotation is created with type .line
 THEN: Line is drawn at position
  AND: May span viewport width

 EDGE CASE: Label with nil text
 GIVEN: type .label but text is nil
 WHEN: Annotation is rendered
 THEN: Nothing drawn (or validation error)
  AND: Label requires text

 EDGE CASE: Position outside viewport
 GIVEN: Annotation at position (1000, 1000) but viewport is -10 to 10
 WHEN: Graph is rendered
 THEN: Annotation not visible initially
  AND: Becomes visible if user pans to that area
*/

// MARK: - AnnotationType Enum

// Type of annotation overlaid on the graph.
enum AnnotationType: String, Sendable, Equatable, Codable {
  // Text label at a position.
  case label

  // Arrow pointing to a location.
  case arrow

  // Reference line (horizontal or vertical).
  case line
}

/*
 ACCEPTANCE CRITERIA: AnnotationType

 SCENARIO: Label annotation type
 GIVEN: AnnotationType.label
 WHEN: Processed by renderer
 THEN: Text is rendered at position
  AND: Uses text field for content

 SCENARIO: Arrow annotation type
 GIVEN: AnnotationType.arrow
 WHEN: Processed by renderer
 THEN: Arrow graphic is drawn
  AND: Points toward position

 SCENARIO: Line annotation type
 GIVEN: AnnotationType.line
 WHEN: Processed by renderer
 THEN: Reference line is drawn
  AND: Typically spans axis
*/

// MARK: - AnchorPosition Enum

// Anchor point for positioning annotations relative to their position.
enum AnchorPosition: String, Sendable, Equatable, Codable {
  // Anchor at top (text below position).
  case top

  // Anchor at bottom (text above position).
  case bottom

  // Anchor at left (text to right of position).
  case left

  // Anchor at right (text to left of position).
  case right

  // Anchor at center (text centered on position).
  case center

  // Anchor at top-left corner.
  case topLeft

  // Anchor at top-right corner.
  case topRight

  // Anchor at bottom-left corner.
  case bottomLeft

  // Anchor at bottom-right corner.
  case bottomRight
}

/*
 ACCEPTANCE CRITERIA: AnchorPosition

 SCENARIO: Center anchor
 GIVEN: AnchorPosition.center
 WHEN: Label is positioned
 THEN: Text is centered on position coordinates
  AND: Text extends equally in all directions

 SCENARIO: Top anchor
 GIVEN: AnchorPosition.top
 WHEN: Label is positioned at (x, y)
 THEN: Top-center of text is at (x, y)
  AND: Text extends downward

 SCENARIO: Bottom-right anchor
 GIVEN: AnchorPosition.bottomRight
 WHEN: Label is positioned
 THEN: Bottom-right corner of text is at position
  AND: Text extends up and to the left

 SCENARIO: Nil anchor defaults
 GIVEN: Annotation with anchor: nil
 WHEN: Rendered
 THEN: Uses default anchor (e.g., center or bottom-left)
  AND: Behavior is consistent
*/

// MARK: - GraphPosition Struct

// A position in graph coordinates.
struct GraphPosition: Sendable, Equatable, Codable {
  // X coordinate.
  let x: Double

  // Y coordinate.
  let y: Double
}

/*
 ACCEPTANCE CRITERIA: GraphPosition

 SCENARIO: Create position at origin
 GIVEN: GraphPosition with x: 0, y: 0
 WHEN: Used for annotation
 THEN: Annotation is at graph origin
  AND: Coordinates are in graph space (not screen pixels)

 SCENARIO: Create position with decimals
 GIVEN: GraphPosition with x: 3.14159, y: 2.71828
 WHEN: Used for annotation
 THEN: Position is precisely at those coordinates
  AND: Decimal precision is preserved

 EDGE CASE: Position with infinite coordinates
 GIVEN: GraphPosition with x: .infinity
 WHEN: Used for annotation
 THEN: Annotation is off-screen
  AND: No rendering error occurs
*/

// MARK: - GraphInteractivity Struct

// Settings for user interaction with the graph.
struct GraphInteractivity: Sendable, Equatable, Codable {
  // Whether user can pan the viewport.
  let allowPan: Bool

  // Whether user can zoom in/out.
  let allowZoom: Bool

  // Whether user can trace along curves.
  let allowTrace: Bool

  // Whether to show coordinates at cursor/touch position.
  let showCoordinates: Bool

  // Whether tracing snaps to grid lines.
  let snapToGrid: Bool
}

/*
 ACCEPTANCE CRITERIA: GraphInteractivity

 SCENARIO: Full interactivity enabled
 GIVEN: GraphInteractivity with all options true
 WHEN: User interacts with graph
 THEN: Can pan by dragging
  AND: Can zoom by pinching
  AND: Can trace curves by long-press and drag
  AND: Coordinates shown at touch point
  AND: Trace position snaps to grid

 SCENARIO: View-only graph
 GIVEN: GraphInteractivity with allowPan: false, allowZoom: false
 WHEN: User attempts to interact
 THEN: Viewport does not change
  AND: Graph is static
  AND: Trace may still work if enabled

 SCENARIO: Trace without snap
 GIVEN: allowTrace: true, snapToGrid: false
 WHEN: User traces along curve
 THEN: Exact curve coordinates shown
  AND: No snapping to grid values

 SCENARIO: Trace with snap
 GIVEN: allowTrace: true, snapToGrid: true
 WHEN: User traces along curve
 THEN: Coordinates snap to nearest grid intersection
  AND: Useful for reading integer values

 SCENARIO: Show coordinates on hover/touch
 GIVEN: showCoordinates: true
 WHEN: User touches graph area
 THEN: (x, y) coordinates displayed
  AND: Updates in real-time during drag

 SCENARIO: Hide coordinates
 GIVEN: showCoordinates: false
 WHEN: User touches graph area
 THEN: No coordinate display
  AND: Cleaner visual experience
*/

// MARK: - GraphSpecificationError Enum

// Errors that can occur during graph specification validation or parsing.
enum GraphSpecificationError: Error, LocalizedError, Equatable, Sendable {
  // Version string is not supported.
  case unsupportedVersion(version: String)

  // Viewport dimensions are invalid.
  case invalidViewport(reason: String)

  // Equation is missing required fields for its type.
  case incompleteEquation(equationID: String, reason: String)

  // Expression syntax is invalid.
  case invalidExpression(equationID: String, expression: String, reason: String)

  // Parameter range is invalid (min > max).
  case invalidParameterRange(equationID: String, reason: String)

  // Color hex string is malformed.
  case invalidColor(value: String)

  // Duplicate equation IDs found.
  case duplicateEquationID(equationID: String)

  // Duplicate point IDs found.
  case duplicatePointID(pointID: String)

  // JSON decoding failed.
  case decodingFailed(reason: String)

  var errorDescription: String? {
    switch self {
    case .unsupportedVersion(let version):
      return "Unsupported graph specification version: \(version)"
    case .invalidViewport(let reason):
      return "Invalid viewport: \(reason)"
    case .incompleteEquation(let equationID, let reason):
      return "Incomplete equation '\(equationID)': \(reason)"
    case .invalidExpression(let equationID, let expression, let reason):
      return "Invalid expression in equation '\(equationID)': '\(expression)' - \(reason)"
    case .invalidParameterRange(let equationID, let reason):
      return "Invalid parameter range in equation '\(equationID)': \(reason)"
    case .invalidColor(let value):
      return "Invalid color value: '\(value)'"
    case .duplicateEquationID(let equationID):
      return "Duplicate equation ID: '\(equationID)'"
    case .duplicatePointID(let pointID):
      return "Duplicate point ID: '\(pointID)'"
    case .decodingFailed(let reason):
      return "Failed to decode graph specification: \(reason)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: GraphSpecificationError

 SCENARIO: Unsupported version error
 GIVEN: A specification with version "3.0"
 WHEN: Parsed by version "1.0" implementation
 THEN: GraphSpecificationError.unsupportedVersion is thrown
  AND: Version string is included in error

 SCENARIO: Invalid viewport error
 GIVEN: Viewport with xMin > xMax
 WHEN: Specification is validated
 THEN: GraphSpecificationError.invalidViewport is thrown
  AND: Reason explains the issue

 SCENARIO: Incomplete equation error
 GIVEN: Parametric equation missing yExpression
 WHEN: Specification is validated
 THEN: GraphSpecificationError.incompleteEquation is thrown
  AND: equationID identifies the problematic equation
  AND: reason explains missing field

 SCENARIO: Invalid expression error
 GIVEN: Expression with syntax error "x^2 + + 3"
 WHEN: Expression is parsed
 THEN: GraphSpecificationError.invalidExpression is thrown
  AND: Original expression is included
  AND: reason describes syntax error

 SCENARIO: Duplicate ID error
 GIVEN: Two equations with same ID "eq1"
 WHEN: Specification is validated
 THEN: GraphSpecificationError.duplicateEquationID is thrown
  AND: Duplicate ID is reported

 SCENARIO: Decoding failure
 GIVEN: Malformed JSON for specification
 WHEN: Decoding is attempted
 THEN: GraphSpecificationError.decodingFailed is thrown
  AND: reason includes underlying decode error
*/

// MARK: - GraphingCalculatorSkillProtocol

// Protocol for the GraphingCalculator skill.
// Extends base Skill protocol with graph-specific functionality.
// Implementation generates GraphSpecification from input.
protocol GraphingCalculatorSkillProtocol: Skill {
  // Executes the skill and returns a graph specification.
  // Parameters may include:
  //   - jiixContent: String (JIIX JSON from handwritten math)
  //   - specification: String (direct JSON specification)
  //   - prompt: String (natural language description)
  // Context provides current notebook/document state.
  // Returns SkillResult with .graphSpecification in data field (via .json).
  // Throws if input cannot be interpreted or cloud request fails.

  // Note: The execute() method is inherited from Skill protocol.
  // This protocol documents the expected parameter handling.
}

/*
 ACCEPTANCE CRITERIA: GraphingCalculatorSkillProtocol

 SCENARIO: Execute with JIIX content
 GIVEN: JIIX content containing handwritten "y = x^2"
 WHEN: execute() is called with parameters ["jiixContent": ...]
 THEN: JIIX is sent to AI for interpretation
  AND: AI extracts mathematical meaning
  AND: GraphSpecification is generated and returned
  AND: result.data is .json containing GraphSpecification

 SCENARIO: Execute with direct specification
 GIVEN: JSON string containing GraphSpecification
 WHEN: execute() is called with parameters ["specification": ...]
 THEN: JSON is parsed directly
  AND: Validation is performed
  AND: GraphSpecification is returned if valid

 SCENARIO: Execute with natural language prompt
 GIVEN: Prompt "graph sine and cosine from -2pi to 2pi"
 WHEN: execute() is called with parameters ["prompt": ...]
 THEN: AI interprets the natural language
  AND: Generates appropriate GraphSpecification
  AND: Multiple equations may be created

 SCENARIO: Cloud execution for AI interpretation
 GIVEN: Skill has executionMode = .cloud
 WHEN: JIIX content requires AI interpretation
 THEN: Request is sent to cloud function
  AND: Gemini AI processes the input
  AND: Structured specification is returned

 SCENARIO: Execute with invalid JIIX
 GIVEN: JIIX content with no mathematical content
 WHEN: execute() is called
 THEN: SkillError.executionFailed is thrown
  AND: reason indicates no math found

 SCENARIO: Execute with malformed specification JSON
 GIVEN: Invalid JSON string for specification
 WHEN: execute() is called
 THEN: SkillError.executionFailed is thrown
  AND: reason includes parsing error

 EDGE CASE: Empty parameters
 GIVEN: No jiixContent, specification, or prompt provided
 WHEN: execute() is called with empty parameters
 THEN: SkillError.missingRequiredParameter is thrown
  AND: At least one input type is required

 EDGE CASE: Multiple input types provided
 GIVEN: Both jiixContent and prompt provided
 WHEN: execute() is called
 THEN: Priority order: specification > jiixContent > prompt
  AND: Highest priority input is used

 EDGE CASE: Network failure during cloud execution
 GIVEN: Device is offline
 WHEN: execute() is called requiring cloud AI
 THEN: SkillError.networkError is thrown
  AND: reason indicates connectivity issue
*/

// MARK: - SkillResultData Extension (Conceptual)

// Note: To properly integrate with the Skills system, SkillResultData enum
// in SkillsContract.swift should include a case for graph specifications:
//
// case graphSpecification(GraphSpecification)
//
// Alternatively, the GraphSpecification can be encoded to JSON and returned
// as .json(Data), with the caller knowing to decode it as GraphSpecification.

/*
 INTEGRATION: SkillResultData

 SCENARIO: Return graph specification as JSON
 GIVEN: GraphingCalculator skill completes successfully
 WHEN: SkillResult is created
 THEN: data is .json containing encoded GraphSpecification
  AND: Caller decodes to GraphSpecification for rendering

 SCENARIO: Alternative: dedicated result case
 GIVEN: SkillResultData extended with .graphSpecification case
 WHEN: GraphingCalculator skill completes
 THEN: data is .graphSpecification(spec)
  AND: Type-safe access to specification
  AND: UI layer can pattern match on result type
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Empty equations and points
 GIVEN: GraphSpecification with equations: [], points: []
 WHEN: Rendered
 THEN: Only axes and grid are shown
  AND: Valid but empty graph

 EDGE CASE: Thousands of equations
 GIVEN: GraphSpecification with 1000 equations
 WHEN: Rendered
 THEN: Performance may degrade
  AND: Consider limit or pagination
  AND: Warning for excessive equations

 EDGE CASE: Very complex expression
 GIVEN: Expression with deeply nested functions
 WHEN: Parsed and evaluated
 THEN: May hit recursion/stack limits
  AND: Timeout protection needed

 EDGE CASE: Division by zero in expression
 GIVEN: Expression "1/x" evaluated at x = 0
 WHEN: Point is evaluated
 THEN: Produces infinity or NaN
  AND: Curve has asymptote at x = 0
  AND: Renderer handles discontinuity

 EDGE CASE: Overlapping equations
 GIVEN: Multiple equations with same curve
 WHEN: Rendered
 THEN: All are drawn (may overlap visually)
  AND: Different styles make them distinguishable

 EDGE CASE: Extreme zoom in
 GIVEN: User zooms to very small viewport (1e-10 range)
 WHEN: Grid and curves are rendered
 THEN: Floating point precision issues may appear
  AND: Grid spacing adapts or grid is hidden

 EDGE CASE: Extreme zoom out
 GIVEN: User zooms to very large viewport (1e10 range)
 WHEN: Grid and curves are rendered
 THEN: Curves may appear as single points
  AND: Grid spacing adapts

 EDGE CASE: Unicode in labels and expressions
 GIVEN: Label contains Greek letters or special symbols
 WHEN: Rendered
 THEN: Unicode is displayed correctly
  AND: theta, pi, etc. render as symbols

 EDGE CASE: RTL text in labels
 GIVEN: Label contains Arabic or Hebrew text
 WHEN: Rendered
 THEN: RTL text renders correctly
  AND: Anchor positions work with RTL

 EDGE CASE: Concurrent modification during pan
 GIVEN: User panning while new specification arrives
 WHEN: New specification is applied
 THEN: Transition is smooth or specification is queued
  AND: No visual glitches

 EDGE CASE: Specification version migration
 GIVEN: Saved specification from version "1.0"
 WHEN: Loaded by version "1.1" renderer
 THEN: Backward compatible parsing
  AND: Missing new fields use defaults
  AND: No data loss
*/

// MARK: - GraphingCalculatorSkill (Acceptance Criteria)

// Implementation is in Skills/GraphingCalculatorSkill.swift
// The following acceptance criteria document expected behavior.

/*
 ACCEPTANCE CRITERIA: GraphingCalculatorSkill

 SCENARIO: Skill metadata is correctly defined
 GIVEN: GraphingCalculatorSkill type
 WHEN: metadata static property is accessed
 THEN: id is "graphing-calculator"
  AND: displayName is "Graphing Calculator"
  AND: executionMode is .cloud
  AND: hasCustomUI is true
  AND: parameters contains three optional string parameters

 SCENARIO: Create skill instance via registry
 GIVEN: SkillRegistry with GraphingCalculatorSkill registered
 WHEN: createSkill(withID: "graphing-calculator") is called
 THEN: A new GraphingCalculatorSkill instance is returned
  AND: Instance is ready for execution

 SCENARIO: Execute with direct specification JSON
 GIVEN: A valid GraphSpecification JSON string
 WHEN: execute() is called with parameters ["specification": .string(jsonString)]
 THEN: JSON is parsed to GraphSpecification
  AND: Validation is performed on parsed specification
  AND: SkillResult.success with .graphSpecification(spec) is returned
  AND: No cloud request is made (local parsing only)

 SCENARIO: Execute with valid JIIX content
 GIVEN: JIIX content containing handwritten "y = x^2 + 2x - 1"
 WHEN: execute() is called with parameters ["jiixContent": .string(jiixString)]
 THEN: JIIX is sent to cloud (Gemini) for interpretation
  AND: AI extracts mathematical equations from handwriting
  AND: AI generates appropriate GraphSpecification
  AND: SkillResult.success with .graphSpecification is returned

 SCENARIO: Execute with natural language prompt
 GIVEN: Prompt "graph sine and cosine from -2pi to 2pi"
 WHEN: execute() is called with parameters ["prompt": .string(prompt)]
 THEN: Prompt is sent to cloud (Gemini) for generation
  AND: AI interprets the natural language request
  AND: AI generates GraphSpecification with sin(x) and cos(x) equations
  AND: SkillResult.success with .graphSpecification is returned

 SCENARIO: Priority order when multiple inputs provided
 GIVEN: Both specification and jiixContent are provided
 WHEN: execute() is called with both parameters
 THEN: specification takes priority
  AND: jiixContent is ignored
  AND: No cloud request is made

 SCENARIO: Priority order with jiixContent and prompt
 GIVEN: Both jiixContent and prompt are provided
 WHEN: execute() is called with both parameters
 THEN: jiixContent takes priority
  AND: prompt is ignored
  AND: Cloud request uses jiixContent

 SCENARIO: Execute with JIIX containing multiple equations
 GIVEN: JIIX content with "y = x^2" and "y = sin(x)" and "y = 1/x"
 WHEN: execute() is called
 THEN: AI extracts all three equations
  AND: GraphSpecification contains three GraphEquation entries
  AND: Each equation has unique id and appropriate styling

 SCENARIO: Execute with JIIX containing parametric equations
 GIVEN: JIIX content with "x = cos(t), y = sin(t)"
 WHEN: execute() is called
 THEN: AI recognizes parametric form
  AND: GraphEquation has type .parametric
  AND: xExpression and yExpression are populated
  AND: parameterRange defaults to 0 to 2*pi

 SCENARIO: Execute with JIIX containing polar equation
 GIVEN: JIIX content with "r = 1 + cos(theta)"
 WHEN: execute() is called
 THEN: AI recognizes polar form
  AND: GraphEquation has type .polar
  AND: rExpression is populated
  AND: thetaRange defaults to 0 to 2*pi

 SCENARIO: Execute with JIIX containing inequality
 GIVEN: JIIX content with "y < x^2"
 WHEN: execute() is called
 THEN: AI recognizes inequality
  AND: GraphEquation has type .inequality
  AND: fillRegion is true
  AND: boundaryStyle may be "dashed"

 SCENARIO: Execute returns appropriate viewport
 GIVEN: JIIX or prompt describing specific domain
 WHEN: execute() is called
 THEN: AI determines appropriate viewport bounds
  AND: Viewport shows interesting region of the graph
  AND: If no domain specified, defaults are used

 SCENARIO: Execute generates unique equation IDs
 GIVEN: Multiple equations to graph
 WHEN: execute() returns GraphSpecification
 THEN: Each equation has unique id
  AND: IDs are stable for the same input
  AND: No duplicate IDs exist

 EDGE CASE: No input parameters provided
 GIVEN: Empty parameters dictionary
 WHEN: execute(parameters: [:], context:) is called
 THEN: SkillError.missingRequiredParameter is thrown
  AND: Error message indicates at least one of specification/jiixContent/prompt required

 EDGE CASE: All input parameters are empty strings
 GIVEN: parameters = ["specification": .string(""), "jiixContent": .string(""), "prompt": .string("")]
 WHEN: execute() is called
 THEN: SkillError.invalidParameterValue is thrown
  AND: Error indicates empty input is not valid

 EDGE CASE: Invalid specification JSON
 GIVEN: specification parameter with malformed JSON "{ invalid json }"
 WHEN: execute() is called
 THEN: SkillError.executionFailed is thrown
  AND: reason includes JSON parsing error details

 EDGE CASE: Valid JSON but invalid GraphSpecification
 GIVEN: specification parameter with valid JSON but wrong structure
 WHEN: execute() is called
 THEN: SkillError.executionFailed is thrown
  AND: reason indicates missing required fields or type mismatch

 EDGE CASE: JIIX content with no mathematical content
 GIVEN: JIIX content containing only plain text "Hello World"
 WHEN: execute() is called
 THEN: SkillError.executionFailed is thrown
  AND: reason indicates no mathematical expressions found

 EDGE CASE: JIIX content with unsupported math notation
 GIVEN: JIIX content with advanced notation AI cannot interpret
 WHEN: execute() is called
 THEN: AI returns best-effort interpretation or error
  AND: SkillResult reflects partial success or failure

 EDGE CASE: Prompt with ambiguous mathematical description
 GIVEN: Prompt "graph the function"
 WHEN: execute() is called
 THEN: AI may request clarification or generate default
  AND: Result is deterministic for same input

 EDGE CASE: Prompt requesting impossible graph
 GIVEN: Prompt "graph x = x + 1" (no solution)
 WHEN: execute() is called
 THEN: AI handles gracefully
  AND: May return empty equations array or explanation

 EDGE CASE: Network failure during cloud execution
 GIVEN: Device is offline
 WHEN: execute() is called with jiixContent or prompt
 THEN: SkillError.networkError is thrown
  AND: reason indicates connectivity issue
  AND: No partial result returned

 EDGE CASE: Cloud service timeout
 GIVEN: Cloud AI takes too long to respond
 WHEN: timeout threshold is exceeded
 THEN: SkillError.timeout is thrown
  AND: skillID is "graphing-calculator"
  AND: durationSeconds indicates elapsed time

 EDGE CASE: Cloud service returns invalid response
 GIVEN: Cloud AI returns malformed GraphSpecification JSON
 WHEN: Response is parsed
 THEN: SkillError.executionFailed is thrown
  AND: reason indicates parse failure from cloud response

 EDGE CASE: Very long expression in JIIX
 GIVEN: JIIX with expression exceeding maxExpressionLength (1000 chars)
 WHEN: execute() is called
 THEN: AI handles or truncates appropriately
  AND: GraphSpecification respects length limits
  AND: Error or warning if expression is unusable

 EDGE CASE: JIIX with Unicode mathematical symbols
 GIVEN: JIIX containing theta, pi, summation symbols
 WHEN: execute() is called
 THEN: AI interprets Unicode correctly
  AND: Expressions use appropriate representations

 EDGE CASE: JIIX with subscripts and superscripts
 GIVEN: JIIX with x_1, x^2, a_n notation
 WHEN: execute() is called
 THEN: AI extracts subscripts and superscripts correctly
  AND: Expression strings represent notation accurately

 EDGE CASE: Concurrent executions of same skill
 GIVEN: Multiple execute() calls simultaneously
 WHEN: All calls process
 THEN: Each execution is independent
  AND: Results are returned to correct callers
  AND: No state leakage between executions

 EDGE CASE: Context with nil notebook ID
 GIVEN: SkillContext.currentNotebookID is nil
 WHEN: execute() is called
 THEN: Execution proceeds normally
  AND: Context not strictly required for graphing

 EDGE CASE: Parameter with wrong type
 GIVEN: parameters["specification"] is .number(42) instead of .string
 WHEN: execute() is called
 THEN: SkillError.invalidParameterType is thrown
  AND: Error specifies expected string, received number

 EDGE CASE: Specification with unsupported version
 GIVEN: specification JSON with version "2.0"
 WHEN: execute() parses the specification
 THEN: GraphSpecificationError.unsupportedVersion is thrown
  AND: Wrapped in SkillError.executionFailed

 EDGE CASE: Specification with invalid viewport
 GIVEN: specification JSON with xMin > xMax
 WHEN: execute() validates the specification
 THEN: GraphSpecificationError.invalidViewport is thrown
  AND: Wrapped in SkillError.executionFailed

 EDGE CASE: Specification with duplicate equation IDs
 GIVEN: specification JSON with two equations having same ID
 WHEN: execute() validates the specification
 THEN: GraphSpecificationError.duplicateEquationID is thrown
  AND: Wrapped in SkillError.executionFailed

 EDGE CASE: Cancellation during cloud request
 GIVEN: Cloud request in progress
 WHEN: Task is cancelled
 THEN: SkillError.cancelled is thrown
  AND: Cloud request is terminated
  AND: Resources are cleaned up
*/

// MARK: - GraphingCalculatorSkillError Enum

// Errors specific to GraphingCalculator skill execution.
// Provides detailed error cases beyond generic SkillError.
enum GraphingCalculatorSkillError: Error, LocalizedError, Equatable, Sendable {
  // No input was provided (no specification, jiixContent, or prompt).
  case noInputProvided

  // The provided input was empty or whitespace-only.
  case emptyInput(parameterName: String)

  // JIIX content did not contain recognizable mathematical expressions.
  case noMathematicalContent

  // AI could not interpret the mathematical content.
  case interpretationFailed(reason: String)

  // AI response did not contain a valid GraphSpecification.
  case invalidAIResponse(reason: String)

  // Specification validation failed.
  case validationFailed(underlying: GraphSpecificationError)

  var errorDescription: String? {
    switch self {
    case .noInputProvided:
      return "No input provided. Provide specification, jiixContent, or prompt."
    case .emptyInput(let parameterName):
      return "Parameter '\(parameterName)' cannot be empty."
    case .noMathematicalContent:
      return "No mathematical expressions found in the provided content."
    case .interpretationFailed(let reason):
      return "Failed to interpret mathematical content: \(reason)"
    case .invalidAIResponse(let reason):
      return "Invalid response from AI: \(reason)"
    case .validationFailed(let underlying):
      return "Graph specification validation failed: \(underlying.localizedDescription)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: GraphingCalculatorSkillError

 SCENARIO: No input provided error
 GIVEN: execute() called with no valid parameters
 WHEN: Input validation runs
 THEN: GraphingCalculatorSkillError.noInputProvided is thrown
  AND: errorDescription lists required parameters

 SCENARIO: Empty input error
 GIVEN: execute() called with empty jiixContent string
 WHEN: Input validation runs
 THEN: GraphingCalculatorSkillError.emptyInput(parameterName: "jiixContent") is thrown
  AND: errorDescription names the empty parameter

 SCENARIO: No mathematical content error
 GIVEN: JIIX with only non-math handwriting
 WHEN: AI processes content
 THEN: GraphingCalculatorSkillError.noMathematicalContent is thrown
  AND: User understands to provide math content

 SCENARIO: Interpretation failed error
 GIVEN: Complex math AI cannot interpret
 WHEN: AI returns failure
 THEN: GraphingCalculatorSkillError.interpretationFailed is thrown
  AND: reason contains AI's explanation

 SCENARIO: Invalid AI response error
 GIVEN: AI returns malformed JSON
 WHEN: Response parsing fails
 THEN: GraphingCalculatorSkillError.invalidAIResponse is thrown
  AND: reason describes parsing failure

 SCENARIO: Validation failed error
 GIVEN: AI returns spec with invalid viewport
 WHEN: Validation runs
 THEN: GraphingCalculatorSkillError.validationFailed is thrown
  AND: underlying contains GraphSpecificationError.invalidViewport

 SCENARIO: Error equatable comparison
 GIVEN: Two GraphingCalculatorSkillError values
 WHEN: Compared for equality
 THEN: Same case with same values returns true
  AND: Different cases return false
*/

// MARK: - Constants

// Constants for graph specification defaults and limits.
enum GraphSpecificationConstants {
  // Current schema version.
  static let currentVersion: String = "1.0"

  // Default viewport bounds.
  static let defaultXMin: Double = -10.0
  static let defaultXMax: Double = 10.0
  static let defaultYMin: Double = -10.0
  static let defaultYMax: Double = 10.0

  // Default styling.
  static let defaultLineColor: String = "#2196F3"
  static let defaultLineWidth: Double = 2.0
  static let defaultPointColor: String = "#FF5722"
  static let defaultPointSize: Double = 6.0

  // Default fill opacity for inequalities.
  static let defaultFillOpacity: Double = 0.3

  // Default parameter ranges.
  static let defaultParametricTMin: Double = 0.0
  static let defaultParametricTMax: Double = 6.283185307  // 2 * pi
  static let defaultPolarThetaMin: Double = 0.0
  static let defaultPolarThetaMax: Double = 6.283185307  // 2 * pi

  // Limits for validation.
  static let maxEquations: Int = 100
  static let maxPoints: Int = 1000
  static let maxAnnotations: Int = 100
  static let maxExpressionLength: Int = 1000

  // Sampling resolution for curve plotting.
  static let defaultSampleCount: Int = 500
  static let maxSampleCount: Int = 10000
}

/*
 ACCEPTANCE CRITERIA: GraphSpecificationConstants

 SCENARIO: Use default viewport
 GIVEN: No viewport specified
 WHEN: Defaults are applied
 THEN: Viewport is -10 to 10 in both dimensions
  AND: Centered on origin

 SCENARIO: Use default styling
 GIVEN: Equation without style specified
 WHEN: Defaults are applied
 THEN: Blue line (#2196F3) of width 2
  AND: Visible and consistent default appearance

 SCENARIO: Validate equation count
 GIVEN: Specification with 150 equations
 WHEN: Validated against maxEquations
 THEN: Warning or error for exceeding 100
  AND: Prevents performance issues

 SCENARIO: Validate expression length
 GIVEN: Expression of 2000 characters
 WHEN: Validated against maxExpressionLength
 THEN: Rejected or truncated at 1000
  AND: Prevents denial-of-service via complex expressions
*/
