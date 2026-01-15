//
// EmbedContent.swift
// InkOS
//
// Embedded web content (PhET, GeoGebra, YouTube, Desmos, CircuitJS, etc.).
// Rendered via WKWebView.
//

import Foundation

// MARK: - EmbedContent

// Embedded web content.
struct EmbedContent: Sendable, Codable, Equatable {
  // Embed provider type.
  let provider: EmbedProvider

  // Provider-specific configuration.
  let config: EmbedConfig

  // Sizing options.
  let sizing: EmbedSizing?

  // Optional caption.
  let caption: String?

  // Whether to allow fullscreen.
  let allowFullscreen: Bool

  private enum CodingKeys: String, CodingKey {
    case provider
    case sizing
    case caption
    case allowFullscreen = "allow_fullscreen"
    // Provider-specific keys.
    case phet
    case geogebra
    case circuitjs
    case desmos
    case youtube
    case url
  }

  init(
    provider: EmbedProvider,
    config: EmbedConfig,
    sizing: EmbedSizing? = nil,
    caption: String? = nil,
    allowFullscreen: Bool = true
  ) {
    self.provider = provider
    self.config = config
    self.sizing = sizing
    self.caption = caption
    self.allowFullscreen = allowFullscreen
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.provider = try container.decode(EmbedProvider.self, forKey: .provider)
    self.sizing = try container.decodeIfPresent(EmbedSizing.self, forKey: .sizing)
    self.caption = try container.decodeIfPresent(String.self, forKey: .caption)
    self.allowFullscreen = try container.decodeIfPresent(Bool.self, forKey: .allowFullscreen) ?? true

    // Decode config based on provider.
    switch provider {
    case .phet:
      let config = try container.decode(PhETConfig.self, forKey: .phet)
      self.config = .phet(config)
    case .geogebra:
      let config = try container.decode(GeoGebraConfig.self, forKey: .geogebra)
      self.config = .geogebra(config)
    case .circuitjs:
      let config = try container.decode(CircuitJSConfig.self, forKey: .circuitjs)
      self.config = .circuitjs(config)
    case .desmos:
      let config = try container.decode(DesmosConfig.self, forKey: .desmos)
      self.config = .desmos(config)
    case .youtube:
      let config = try container.decode(YouTubeConfig.self, forKey: .youtube)
      self.config = .youtube(config)
    case .url:
      let config = try container.decode(URLConfig.self, forKey: .url)
      self.config = .url(config)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(provider, forKey: .provider)
    try container.encodeIfPresent(sizing, forKey: .sizing)
    try container.encodeIfPresent(caption, forKey: .caption)
    if !allowFullscreen { try container.encode(allowFullscreen, forKey: .allowFullscreen) }

    // Encode config based on provider.
    switch config {
    case .phet(let config):
      try container.encode(config, forKey: .phet)
    case .geogebra(let config):
      try container.encode(config, forKey: .geogebra)
    case .circuitjs(let config):
      try container.encode(config, forKey: .circuitjs)
    case .desmos(let config):
      try container.encode(config, forKey: .desmos)
    case .youtube(let config):
      try container.encode(config, forKey: .youtube)
    case .url(let config):
      try container.encode(config, forKey: .url)
    }
  }

  // Convenience initializers.

  static func phet(
    simulationId: String,
    locale: String = "en",
    initialState: [String: AnyCodable]? = nil
  ) -> EmbedContent {
    EmbedContent(
      provider: .phet,
      config: .phet(PhETConfig(simulationId: simulationId, locale: locale, initialState: initialState))
    )
  }

  static func youtube(videoId: String, startTime: Int? = nil, endTime: Int? = nil) -> EmbedContent {
    EmbedContent(
      provider: .youtube,
      config: .youtube(YouTubeConfig(videoId: videoId, startTime: startTime, endTime: endTime))
    )
  }

  static func geogebra(materialId: String? = nil, appType: GeoGebraAppType = .classic) -> EmbedContent {
    EmbedContent(
      provider: .geogebra,
      config: .geogebra(GeoGebraConfig(materialId: materialId, appType: appType))
    )
  }

  static func desmos(expressions: [DesmosExpression]) -> EmbedContent {
    EmbedContent(
      provider: .desmos,
      config: .desmos(DesmosConfig(expressions: expressions))
    )
  }

  static func url(_ src: String, sandbox: [SandboxPermission]? = nil) -> EmbedContent {
    EmbedContent(
      provider: .url,
      config: .url(URLConfig(src: src, sandbox: sandbox))
    )
  }
}

// MARK: - EmbedProvider

// Embed provider types.
enum EmbedProvider: String, Sendable, Codable, Equatable {
  case phet
  case geogebra
  case circuitjs
  case desmos
  case youtube
  case url
}

// MARK: - EmbedConfig

// Provider-specific configuration.
enum EmbedConfig: Sendable, Equatable {
  case phet(PhETConfig)
  case geogebra(GeoGebraConfig)
  case circuitjs(CircuitJSConfig)
  case desmos(DesmosConfig)
  case youtube(YouTubeConfig)
  case url(URLConfig)
}

// MARK: - EmbedSizing

// Sizing options for embed blocks.
struct EmbedSizing: Sendable, Codable, Equatable {
  let width: String
  let height: Double?
  let aspectRatio: Double?

  private enum CodingKeys: String, CodingKey {
    case width
    case height
    case aspectRatio = "aspect_ratio"
  }

  init(width: String = "100%", height: Double? = 400, aspectRatio: Double? = nil) {
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

// MARK: - PhETConfig

// PhET simulation configuration.
struct PhETConfig: Sendable, Codable, Equatable {
  // PhET simulation identifier (e.g., "projectile-motion").
  let simulationId: String

  // Locale code.
  let locale: String

  // Simulation-specific initial parameters.
  let initialState: [String: AnyCodable]?

  private enum CodingKeys: String, CodingKey {
    case simulationId = "simulation_id"
    case locale
    case initialState = "initial_state"
  }

  init(simulationId: String, locale: String = "en", initialState: [String: AnyCodable]? = nil) {
    self.simulationId = simulationId
    self.locale = locale
    self.initialState = initialState
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.simulationId = try container.decode(String.self, forKey: .simulationId)
    self.locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "en"
    self.initialState = try container.decodeIfPresent([String: AnyCodable].self, forKey: .initialState)
  }
}

// MARK: - GeoGebraConfig

// GeoGebra configuration.
struct GeoGebraConfig: Sendable, Codable, Equatable {
  // GeoGebra material ID from geogebra.org.
  let materialId: String?

  // App type.
  let appType: GeoGebraAppType

  // GeoGebra commands to execute on load.
  let commands: [String]?

  // Whether to show toolbar.
  let showToolbar: Bool

  // Whether to show menu bar.
  let showMenuBar: Bool

  // Whether to enable shift+drag zoom.
  let enableShiftDragZoom: Bool

  private enum CodingKeys: String, CodingKey {
    case materialId = "material_id"
    case appType = "app_type"
    case commands
    case showToolbar = "show_toolbar"
    case showMenuBar = "show_menu_bar"
    case enableShiftDragZoom = "enable_shift_drag_zoom"
  }

  init(
    materialId: String? = nil,
    appType: GeoGebraAppType = .classic,
    commands: [String]? = nil,
    showToolbar: Bool = false,
    showMenuBar: Bool = false,
    enableShiftDragZoom: Bool = true
  ) {
    self.materialId = materialId
    self.appType = appType
    self.commands = commands
    self.showToolbar = showToolbar
    self.showMenuBar = showMenuBar
    self.enableShiftDragZoom = enableShiftDragZoom
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.materialId = try container.decodeIfPresent(String.self, forKey: .materialId)
    self.appType = try container.decodeIfPresent(GeoGebraAppType.self, forKey: .appType) ?? .classic
    self.commands = try container.decodeIfPresent([String].self, forKey: .commands)
    self.showToolbar = try container.decodeIfPresent(Bool.self, forKey: .showToolbar) ?? false
    self.showMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showMenuBar) ?? false
    self.enableShiftDragZoom = try container.decodeIfPresent(Bool.self, forKey: .enableShiftDragZoom) ?? true
  }
}

// MARK: - GeoGebraAppType

enum GeoGebraAppType: String, Sendable, Codable, Equatable {
  case graphing
  case geometry
  case threeD = "3d"
  case classic
  case suite
}

// MARK: - CircuitJSConfig

// CircuitJS configuration.
struct CircuitJSConfig: Sendable, Codable, Equatable {
  // CircuitJS circuit export string.
  let circuitData: String?

  // Name of a preset circuit to load.
  let preset: String?

  // Whether simulation is running.
  let running: Bool

  // Whether to show values.
  let showValues: Bool

  private enum CodingKeys: String, CodingKey {
    case circuitData = "circuit_data"
    case preset
    case running
    case showValues = "show_values"
  }

  init(circuitData: String? = nil, preset: String? = nil, running: Bool = true, showValues: Bool = true) {
    self.circuitData = circuitData
    self.preset = preset
    self.running = running
    self.showValues = showValues
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.circuitData = try container.decodeIfPresent(String.self, forKey: .circuitData)
    self.preset = try container.decodeIfPresent(String.self, forKey: .preset)
    self.running = try container.decodeIfPresent(Bool.self, forKey: .running) ?? true
    self.showValues = try container.decodeIfPresent(Bool.self, forKey: .showValues) ?? true
  }
}

// MARK: - DesmosConfig

// Desmos calculator configuration.
struct DesmosConfig: Sendable, Codable, Equatable {
  // Calculator type.
  let calculatorType: DesmosCalculatorType

  // Expressions to graph.
  let expressions: [DesmosExpression]?

  // Calculator settings.
  let settings: DesmosSettings?

  private enum CodingKeys: String, CodingKey {
    case calculatorType = "calculator_type"
    case expressions
    case settings
  }

  init(
    calculatorType: DesmosCalculatorType = .graphing,
    expressions: [DesmosExpression]? = nil,
    settings: DesmosSettings? = nil
  ) {
    self.calculatorType = calculatorType
    self.expressions = expressions
    self.settings = settings
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.calculatorType = try container.decodeIfPresent(DesmosCalculatorType.self, forKey: .calculatorType) ?? .graphing
    self.expressions = try container.decodeIfPresent([DesmosExpression].self, forKey: .expressions)
    self.settings = try container.decodeIfPresent(DesmosSettings.self, forKey: .settings)
  }
}

// MARK: - DesmosCalculatorType

enum DesmosCalculatorType: String, Sendable, Codable, Equatable {
  case graphing
  case scientific
  case fourfunction
  case geometry
}

// MARK: - DesmosExpression

struct DesmosExpression: Sendable, Codable, Equatable {
  let id: String?
  let latex: String
  let color: String?
  let hidden: Bool?

  init(id: String? = nil, latex: String, color: String? = nil, hidden: Bool? = nil) {
    self.id = id
    self.latex = latex
    self.color = color
    self.hidden = hidden
  }
}

// MARK: - DesmosSettings

struct DesmosSettings: Sendable, Codable, Equatable {
  let showGrid: Bool?
  let showXAxis: Bool?
  let showYAxis: Bool?
  let xAxisLabel: String?
  let yAxisLabel: String?
  let xRange: [Double]?
  let yRange: [Double]?

  private enum CodingKeys: String, CodingKey {
    case showGrid = "show_grid"
    case showXAxis = "show_x_axis"
    case showYAxis = "show_y_axis"
    case xAxisLabel = "x_axis_label"
    case yAxisLabel = "y_axis_label"
    case xRange = "x_range"
    case yRange = "y_range"
  }

  init(
    showGrid: Bool? = nil,
    showXAxis: Bool? = nil,
    showYAxis: Bool? = nil,
    xAxisLabel: String? = nil,
    yAxisLabel: String? = nil,
    xRange: [Double]? = nil,
    yRange: [Double]? = nil
  ) {
    self.showGrid = showGrid
    self.showXAxis = showXAxis
    self.showYAxis = showYAxis
    self.xAxisLabel = xAxisLabel
    self.yAxisLabel = yAxisLabel
    self.xRange = xRange
    self.yRange = yRange
  }
}

// MARK: - YouTubeConfig

// YouTube video configuration.
struct YouTubeConfig: Sendable, Codable, Equatable {
  // YouTube video ID.
  let videoId: String

  // Start time in seconds.
  let startTime: Int?

  // End time in seconds.
  let endTime: Int?

  // Whether to autoplay.
  let autoplay: Bool

  // Whether to show controls.
  let controls: Bool

  private enum CodingKeys: String, CodingKey {
    case videoId = "video_id"
    case startTime = "start_time"
    case endTime = "end_time"
    case autoplay
    case controls
  }

  init(
    videoId: String,
    startTime: Int? = nil,
    endTime: Int? = nil,
    autoplay: Bool = false,
    controls: Bool = true
  ) {
    self.videoId = videoId
    self.startTime = startTime
    self.endTime = endTime
    self.autoplay = autoplay
    self.controls = controls
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.videoId = try container.decode(String.self, forKey: .videoId)
    self.startTime = try container.decodeIfPresent(Int.self, forKey: .startTime)
    self.endTime = try container.decodeIfPresent(Int.self, forKey: .endTime)
    self.autoplay = try container.decodeIfPresent(Bool.self, forKey: .autoplay) ?? false
    self.controls = try container.decodeIfPresent(Bool.self, forKey: .controls) ?? true
  }
}

// MARK: - URLConfig

// Generic URL embed configuration.
struct URLConfig: Sendable, Codable, Equatable {
  // URL to embed.
  let src: String

  // Sandbox permissions.
  let sandbox: [SandboxPermission]?

  init(src: String, sandbox: [SandboxPermission]? = nil) {
    self.src = src
    self.sandbox = sandbox
  }
}

// MARK: - SandboxPermission

enum SandboxPermission: String, Sendable, Codable, Equatable {
  case allowScripts = "allow-scripts"
  case allowSameOrigin = "allow-same-origin"
  case allowForms = "allow-forms"
  case allowPopups = "allow-popups"
  case allowModals = "allow-modals"
}
