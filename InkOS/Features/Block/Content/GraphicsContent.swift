//
// GraphicsContent.swift
// InkOS
//
// Runtime-rendered visualizations via WebView.
// Supports Chart.js, Plotly, p5.js, Three.js, JSXGraph, and custom HTML/JS.
//

import Foundation

// MARK: - GraphicsContent

// Runtime-rendered visualizations via WebView.
struct GraphicsContent: Sendable, Codable, Equatable {
  // Rendering engine to use.
  let engine: GraphicsEngine

  // Engine-specific specification.
  let spec: GraphicsSpec

  // Sizing options.
  let sizing: GraphicsSizing?

  // Whether user can interact with the visualization.
  let interactive: Bool

  // Optional caption.
  let caption: String?

  private enum CodingKeys: String, CodingKey {
    case engine
    case spec
    case sizing
    case interactive
    case caption
  }

  init(
    engine: GraphicsEngine,
    spec: GraphicsSpec,
    sizing: GraphicsSizing? = nil,
    interactive: Bool = true,
    caption: String? = nil
  ) {
    self.engine = engine
    self.spec = spec
    self.sizing = sizing
    self.interactive = interactive
    self.caption = caption
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.engine = try container.decode(GraphicsEngine.self, forKey: .engine)

    // Decode spec based on engine type.
    let specDecoder = try container.superDecoder(forKey: .spec)
    self.spec = try GraphicsSpec.decode(for: engine, from: specDecoder)

    self.sizing = try container.decodeIfPresent(GraphicsSizing.self, forKey: .sizing)
    self.interactive = try container.decodeIfPresent(Bool.self, forKey: .interactive) ?? true
    self.caption = try container.decodeIfPresent(String.self, forKey: .caption)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(engine, forKey: .engine)

    let specEncoder = container.superEncoder(forKey: .spec)
    try spec.encode(to: specEncoder)

    try container.encodeIfPresent(sizing, forKey: .sizing)
    if !interactive { try container.encode(interactive, forKey: .interactive) }
    try container.encodeIfPresent(caption, forKey: .caption)
  }
}

// MARK: - GraphicsEngine

// Supported rendering engines.
enum GraphicsEngine: String, Sendable, Codable, Equatable {
  case chartjs
  case plotly
  case p5
  case three
  case jsxgraph
  case custom
}

// MARK: - GraphicsSizing

// Sizing options for graphics blocks.
struct GraphicsSizing: Sendable, Codable, Equatable {
  // CSS width value.
  let width: String

  // Height in points.
  let height: Double?

  // If set, height is calculated from width.
  let aspectRatio: Double?

  private enum CodingKeys: String, CodingKey {
    case width
    case height
    case aspectRatio = "aspect_ratio"
  }

  init(width: String = "100%", height: Double? = 300, aspectRatio: Double? = nil) {
    self.width = width
    self.height = height
    self.aspectRatio = aspectRatio
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.width = try container.decodeIfPresent(String.self, forKey: .width) ?? "100%"
    self.height = try container.decodeIfPresent(Double.self, forKey: .height)
    self.aspectRatio = try container.decodeIfPresent(Double.self, forKey: .aspectRatio)
  }
}

// MARK: - GraphicsSpec

// Engine-specific specification.
enum GraphicsSpec: Sendable, Equatable {
  case chartjs(ChartJSSpec)
  case plotly(PlotlySpec)
  case p5(P5Spec)
  case three(ThreeJSSpec)
  case jsxgraph(JSXGraphSpec)
  case custom(CustomGraphicsSpec)

  static func decode(for engine: GraphicsEngine, from decoder: Decoder) throws -> GraphicsSpec {
    switch engine {
    case .chartjs:
      return .chartjs(try ChartJSSpec(from: decoder))
    case .plotly:
      return .plotly(try PlotlySpec(from: decoder))
    case .p5:
      return .p5(try P5Spec(from: decoder))
    case .three:
      return .three(try ThreeJSSpec(from: decoder))
    case .jsxgraph:
      return .jsxgraph(try JSXGraphSpec(from: decoder))
    case .custom:
      return .custom(try CustomGraphicsSpec(from: decoder))
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .chartjs(let spec):
      try spec.encode(to: encoder)
    case .plotly(let spec):
      try spec.encode(to: encoder)
    case .p5(let spec):
      try spec.encode(to: encoder)
    case .three(let spec):
      try spec.encode(to: encoder)
    case .jsxgraph(let spec):
      try spec.encode(to: encoder)
    case .custom(let spec):
      try spec.encode(to: encoder)
    }
  }
}

// MARK: - ChartJSSpec

// Chart.js configuration.
struct ChartJSSpec: Sendable, Codable, Equatable {
  let chartType: ChartJSChartType
  let data: ChartJSData
  let options: [String: AnyCodable]?

  private enum CodingKeys: String, CodingKey {
    case chartType = "chart_type"
    case data
    case options
  }

  init(chartType: ChartJSChartType, data: ChartJSData, options: [String: AnyCodable]? = nil) {
    self.chartType = chartType
    self.data = data
    self.options = options
  }
}

// MARK: - ChartJSChartType

enum ChartJSChartType: String, Sendable, Codable, Equatable {
  case line
  case bar
  case pie
  case doughnut
  case scatter
  case bubble
  case radar
  case polarArea
}

// MARK: - ChartJSData

struct ChartJSData: Sendable, Codable, Equatable {
  let labels: [String]?
  let datasets: [ChartJSDataset]

  init(labels: [String]? = nil, datasets: [ChartJSDataset]) {
    self.labels = labels
    self.datasets = datasets
  }
}

// MARK: - ChartJSDataset

struct ChartJSDataset: Sendable, Codable, Equatable {
  let label: String?
  let data: [Double]
  let backgroundColor: AnyCodable?
  let borderColor: AnyCodable?
  let borderWidth: Double?

  init(
    label: String? = nil,
    data: [Double],
    backgroundColor: AnyCodable? = nil,
    borderColor: AnyCodable? = nil,
    borderWidth: Double? = nil
  ) {
    self.label = label
    self.data = data
    self.backgroundColor = backgroundColor
    self.borderColor = borderColor
    self.borderWidth = borderWidth
  }
}

// MARK: - PlotlySpec

// Plotly.js configuration for advanced/3D charts.
struct PlotlySpec: Sendable, Codable, Equatable {
  let data: [[String: AnyCodable]]
  let layout: [String: AnyCodable]?
  let config: [String: AnyCodable]?

  init(data: [[String: AnyCodable]], layout: [String: AnyCodable]? = nil, config: [String: AnyCodable]? = nil) {
    self.data = data
    self.layout = layout
    self.config = config
  }
}

// MARK: - P5Spec

// p5.js sketch for custom animations and physics diagrams.
struct P5Spec: Sendable, Codable, Equatable {
  let sketchType: P5SketchType
  let parameters: [String: AnyCodable]?
  let customCode: String?
  let katexAnnotations: [KaTeXAnnotation]?

  private enum CodingKeys: String, CodingKey {
    case sketchType = "sketch_type"
    case parameters
    case customCode = "custom_code"
    case katexAnnotations = "katex_annotations"
  }

  init(
    sketchType: P5SketchType,
    parameters: [String: AnyCodable]? = nil,
    customCode: String? = nil,
    katexAnnotations: [KaTeXAnnotation]? = nil
  ) {
    self.sketchType = sketchType
    self.parameters = parameters
    self.customCode = customCode
    self.katexAnnotations = katexAnnotations
  }
}

// MARK: - KaTeXAnnotation

// Math equation overlay rendered via KaTeX.
struct KaTeXAnnotation: Sendable, Codable, Equatable {
  let latex: String
  let x: Double // 0-1 relative X position
  let y: Double // 0-1 relative Y position
  let anchor: TextAnchor

  private enum CodingKeys: String, CodingKey {
    case latex
    case x
    case y
    case anchor
  }

  init(latex: String, x: Double, y: Double, anchor: TextAnchor = .center) {
    self.latex = latex
    self.x = x
    self.y = y
    self.anchor = anchor
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.latex = try container.decode(String.self, forKey: .latex)
    self.x = try container.decode(Double.self, forKey: .x)
    self.y = try container.decode(Double.self, forKey: .y)
    self.anchor = try container.decodeIfPresent(TextAnchor.self, forKey: .anchor) ?? .center
  }
}

// MARK: - TextAnchor

// Text alignment anchor for KaTeX annotations.
enum TextAnchor: String, Sendable, Codable, Equatable {
  case left
  case center
  case right
}

// MARK: - P5SketchType

enum P5SketchType: String, Sendable, Codable, Equatable {
  case forceDiagram = "force_diagram"
  case wave
  case projectile
  case pendulum
  case field
  case custom
}

// MARK: - ThreeJSSpec

// Three.js 3D visualization.
struct ThreeJSSpec: Sendable, Codable, Equatable {
  let sceneType: ThreeJSSceneType
  let parameters: [String: AnyCodable]?
  let camera: ThreeJSCamera?
  let customCode: String?

  private enum CodingKeys: String, CodingKey {
    case sceneType = "scene_type"
    case parameters
    case camera
    case customCode = "custom_code"
  }

  init(
    sceneType: ThreeJSSceneType,
    parameters: [String: AnyCodable]? = nil,
    camera: ThreeJSCamera? = nil,
    customCode: String? = nil
  ) {
    self.sceneType = sceneType
    self.parameters = parameters
    self.camera = camera
    self.customCode = customCode
  }
}

// MARK: - ThreeJSSceneType

enum ThreeJSSceneType: String, Sendable, Codable, Equatable {
  case molecule
  case geometry
  case vectorField = "vector_field"
  case surface
  case custom
}

// MARK: - ThreeJSCamera

struct ThreeJSCamera: Sendable, Codable, Equatable {
  let position: [Double]?
  let target: [Double]?
  let autoRotate: Bool

  private enum CodingKeys: String, CodingKey {
    case position
    case target
    case autoRotate = "auto_rotate"
  }

  init(position: [Double]? = nil, target: [Double]? = nil, autoRotate: Bool = false) {
    self.position = position
    self.target = target
    self.autoRotate = autoRotate
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.position = try container.decodeIfPresent([Double].self, forKey: .position)
    self.target = try container.decodeIfPresent([Double].self, forKey: .target)
    self.autoRotate = try container.decodeIfPresent(Bool.self, forKey: .autoRotate) ?? false
  }
}

// MARK: - JSXGraphSpec

// JSXGraph interactive geometry.
struct JSXGraphSpec: Sendable, Codable, Equatable {
  let boundingBox: [Double]?
  let axis: Bool
  let grid: Bool
  let elements: [JSXGraphElement]

  private enum CodingKeys: String, CodingKey {
    case boundingBox = "bounding_box"
    case axis
    case grid
    case elements
  }

  init(boundingBox: [Double]? = nil, axis: Bool = true, grid: Bool = true, elements: [JSXGraphElement]) {
    self.boundingBox = boundingBox
    self.axis = axis
    self.grid = grid
    self.elements = elements
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.boundingBox = try container.decodeIfPresent([Double].self, forKey: .boundingBox)
    self.axis = try container.decodeIfPresent(Bool.self, forKey: .axis) ?? true
    self.grid = try container.decodeIfPresent(Bool.self, forKey: .grid) ?? true
    self.elements = try container.decode([JSXGraphElement].self, forKey: .elements)
  }
}

// MARK: - JSXGraphElement

struct JSXGraphElement: Sendable, Codable, Equatable {
  let elementType: JSXGraphElementType
  let id: String?
  let params: [AnyCodable]?
  let attributes: [String: AnyCodable]?

  private enum CodingKeys: String, CodingKey {
    case elementType = "element_type"
    case id
    case params
    case attributes
  }

  init(
    elementType: JSXGraphElementType,
    id: String? = nil,
    params: [AnyCodable]? = nil,
    attributes: [String: AnyCodable]? = nil
  ) {
    self.elementType = elementType
    self.id = id
    self.params = params
    self.attributes = attributes
  }
}

// MARK: - JSXGraphElementType

enum JSXGraphElementType: String, Sendable, Codable, Equatable {
  case point
  case line
  case segment
  case circle
  case polygon
  case function
  case angle
  case text
}

// MARK: - CustomGraphicsSpec

// Custom HTML/JS visualization.
struct CustomGraphicsSpec: Sendable, Codable, Equatable {
  let html: String
  let scripts: [String]?
  let styles: [String]?

  init(html: String, scripts: [String]? = nil, styles: [String]? = nil) {
    self.html = html
    self.scripts = scripts
    self.styles = styles
  }
}

// MARK: - AnyCodable

// Type-erased Codable wrapper for arbitrary JSON values.
struct AnyCodable: Sendable, Codable, Equatable {
  let value: Any

  init(_ value: Any) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self.value = NSNull()
    } else if let bool = try? container.decode(Bool.self) {
      self.value = bool
    } else if let int = try? container.decode(Int.self) {
      self.value = int
    } else if let double = try? container.decode(Double.self) {
      self.value = double
    } else if let string = try? container.decode(String.self) {
      self.value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      self.value = array.map { $0.value }
    } else if let dictionary = try? container.decode([String: AnyCodable].self) {
      self.value = dictionary.mapValues { $0.value }
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch value {
    case is NSNull:
      try container.encodeNil()
    case let bool as Bool:
      try container.encode(bool)
    case let int as Int:
      try container.encode(int)
    case let double as Double:
      try container.encode(double)
    case let string as String:
      try container.encode(string)
    case let array as [Any]:
      try container.encode(array.map { AnyCodable($0) })
    case let dictionary as [String: Any]:
      try container.encode(dictionary.mapValues { AnyCodable($0) })
    default:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to encode value")
      )
    }
  }

  static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
    // Simple equality check for common types.
    switch (lhs.value, rhs.value) {
    case (is NSNull, is NSNull):
      return true
    case (let lhsBool as Bool, let rhsBool as Bool):
      return lhsBool == rhsBool
    case (let lhsInt as Int, let rhsInt as Int):
      return lhsInt == rhsInt
    case (let lhsDouble as Double, let rhsDouble as Double):
      return lhsDouble == rhsDouble
    case (let lhsString as String, let rhsString as String):
      return lhsString == rhsString
    default:
      // For complex types, compare JSON representations.
      guard let lhsData = try? JSONEncoder().encode(lhs),
            let rhsData = try? JSONEncoder().encode(rhs)
      else {
        return false
      }
      return lhsData == rhsData
    }
  }
}
