//
// Block+Codable.swift
// InkOS
//
// Manual Codable conformance for Block and BlockProperties.
// Uses the block kind as a discriminator to decode the correct properties type.
//

import Foundation

// MARK: - Block Codable

extension Block: Codable {
  private enum CodingKeys: String, CodingKey {
    case id
    case kind
    case properties
    case parameters
    case children
    case state
    case metadata
    case actions
    case layer
    case source
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(BlockID.self, forKey: .id)
    self.kind = try container.decode(BlockKind.self, forKey: .kind)

    // Decode properties based on kind using nested container.
    let propertiesDecoder = try container.superDecoder(forKey: .properties)
    self.properties = try BlockProperties.decode(for: kind, from: propertiesDecoder)

    self.parameters = try container.decodeIfPresent([Parameter].self, forKey: .parameters)
    self.children = try container.decodeIfPresent([Block].self, forKey: .children)
    self.state = try container.decode(BlockState.self, forKey: .state)
    self.metadata = try container.decode(BlockMetadata.self, forKey: .metadata)
    self.actions = try container.decodeIfPresent([BlockAction].self, forKey: .actions)
    self.layer = try container.decode(Int.self, forKey: .layer)
    self.source = try container.decode(BlockSource.self, forKey: .source)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(kind, forKey: .kind)

    // Encode properties to nested container.
    let propertiesEncoder = container.superEncoder(forKey: .properties)
    try properties.encode(to: propertiesEncoder)

    try container.encodeIfPresent(parameters, forKey: .parameters)
    try container.encodeIfPresent(children, forKey: .children)
    try container.encode(state, forKey: .state)
    try container.encode(metadata, forKey: .metadata)
    try container.encodeIfPresent(actions, forKey: .actions)
    try container.encode(layer, forKey: .layer)
    try container.encode(source, forKey: .source)
  }
}

// MARK: - BlockProperties Codable

extension BlockProperties: Codable {
  // Decode properties based on block kind.
  // Called from Block.init(from:) with the kind already known.
  static func decode(for kind: BlockKind, from decoder: Decoder) throws -> BlockProperties {
    switch kind {
    case .textOutput:
      let props = try TextOutputProperties(from: decoder)
      return .textOutput(props)
    case .textInput:
      let props = try TextInputProperties(from: decoder)
      return .textInput(props)
    case .handwritingInput:
      let props = try HandwritingInputProperties(from: decoder)
      return .handwritingInput(props)
    case .plot:
      let props = try PlotProperties(from: decoder)
      return .plot(props)
    case .table:
      let props = try TableProperties(from: decoder)
      return .table(props)
    case .diagramOutput:
      let props = try DiagramOutputProperties(from: decoder)
      return .diagramOutput(props)
    case .cardDeck:
      let props = try CardDeckProperties(from: decoder)
      return .cardDeck(props)
    case .quiz:
      let props = try QuizProperties(from: decoder)
      return .quiz(props)
    case .geometry:
      let props = try GeometryProperties(from: decoder)
      return .geometry(props)
    case .codeCell:
      let props = try CodeCellProperties(from: decoder)
      return .codeCell(props)
    case .codeOutput:
      let props = try CodeOutputProperties(from: decoder)
      return .codeOutput(props)
    case .calloutOutput:
      let props = try CalloutOutputProperties(from: decoder)
      return .calloutOutput(props)
    case .imageOutput:
      let props = try ImageOutputProperties(from: decoder)
      return .imageOutput(props)
    case .buttonInput:
      let props = try ButtonInputProperties(from: decoder)
      return .buttonInput(props)
    case .timerOutput:
      let props = try TimerOutputProperties(from: decoder)
      return .timerOutput(props)
    case .progressOutput:
      let props = try ProgressOutputProperties(from: decoder)
      return .progressOutput(props)
    case .audio:
      let props = try AudioProperties(from: decoder)
      return .audio(props)
    case .videoOutput:
      let props = try VideoOutputProperties(from: decoder)
      return .videoOutput(props)
    }
  }

  // Standard Codable init - requires kind to be known externally.
  // This is called when decoding BlockProperties directly (not through Block).
  init(from decoder: Decoder) throws {
    // When decoded directly, we cannot determine the kind.
    // Use decode(for:from:) instead when decoding through Block.
    throw BlockError.decodingRequiresKind
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .textOutput(let props):
      try props.encode(to: encoder)
    case .textInput(let props):
      try props.encode(to: encoder)
    case .handwritingInput(let props):
      try props.encode(to: encoder)
    case .plot(let props):
      try props.encode(to: encoder)
    case .table(let props):
      try props.encode(to: encoder)
    case .diagramOutput(let props):
      try props.encode(to: encoder)
    case .cardDeck(let props):
      try props.encode(to: encoder)
    case .quiz(let props):
      try props.encode(to: encoder)
    case .geometry(let props):
      try props.encode(to: encoder)
    case .codeCell(let props):
      try props.encode(to: encoder)
    case .codeOutput(let props):
      try props.encode(to: encoder)
    case .calloutOutput(let props):
      try props.encode(to: encoder)
    case .imageOutput(let props):
      try props.encode(to: encoder)
    case .buttonInput(let props):
      try props.encode(to: encoder)
    case .timerOutput(let props):
      try props.encode(to: encoder)
    case .progressOutput(let props):
      try props.encode(to: encoder)
    case .audio(let props):
      try props.encode(to: encoder)
    case .videoOutput(let props):
      try props.encode(to: encoder)
    }
  }
}

// MARK: - JSON Encoding Helpers

extension Block {
  // Encodes block to JSON data with standard date formatting.
  func toJSONData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  // Decodes block from JSON data with standard date formatting.
  static func fromJSONData(_ data: Data) throws -> Block {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Block.self, from: data)
  }

  // Encodes block to JSON string.
  func toJSONString() throws -> String {
    let data = try toJSONData()
    guard let string = String(data: data, encoding: .utf8) else {
      throw EncodingError.invalidValue(
        self,
        EncodingError.Context(codingPath: [], debugDescription: "Failed to convert JSON data to string")
      )
    }
    return string
  }

  // Decodes block from JSON string.
  static func fromJSONString(_ string: String) throws -> Block {
    guard let data = string.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: [], debugDescription: "Failed to convert string to data")
      )
    }
    return try fromJSONData(data)
  }
}

// MARK: - Array Extension

extension Array where Element == Block {
  // Encodes array of blocks to JSON data.
  func toJSONData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  // Decodes array of blocks from JSON data.
  static func fromJSONData(_ data: Data) throws -> [Block] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([Block].self, from: data)
  }
}
