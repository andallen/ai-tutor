//
// BlockContract.swift
// InkOS
//
// Core Block primitive types for the Alan educational content system.
// A Block is the fundamental unit of content rendered on the canvas.
// There are 6 primitive block types: text, image, graphics, table, embed, input.
//

import Foundation

// MARK: - BlockID

// Type-safe identifier for blocks.
struct BlockID: Hashable, Sendable, Codable, Equatable, CustomStringConvertible {
  let rawValue: String

  init() {
    self.rawValue = UUID().uuidString
  }

  init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  var description: String { rawValue }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

// MARK: - BlockType

// The 7 primitive block types available in the system.
// Each type maps to a specific content schema and renderer.
enum BlockType: String, Sendable, Codable, Equatable, CaseIterable {
  // Rich text with LaTeX, code, and kinetic typography. Rendered natively.
  case text

  // Static images from any source. Rendered natively.
  case image

  // Runtime-rendered visualizations via WebView (Chart.js, p5.js, Three.js, etc.).
  case graphics

  // Rows and columns of data. Rendered natively.
  case table

  // Embedded web content (PhET, GeoGebra, YouTube, Desmos, etc.). Rendered via WebView.
  case embed

  // User input collection (text, handwriting, multiple choice, etc.). Rendered natively.
  case input

  // Pause point requiring user interaction to continue. Rendered natively.
  case checkpoint
}

// MARK: - BlockStatus

// Rendering status of a block.
enum BlockStatus: String, Sendable, Codable, Equatable {
  // Still being generated (e.g., AI image being created).
  case pending

  // Ready to be rendered.
  case ready

  // Currently rendered on screen.
  case rendered

  // Hidden from view.
  case hidden
}

// MARK: - Block

// The fundamental unit of content in the notebook document.
// Each block has a type that determines how its content is structured and rendered.
struct Block: Identifiable, Sendable, Equatable {
  // Unique block identifier.
  let id: BlockID

  // Block type (text, image, graphics, table, embed, input).
  let type: BlockType

  // Timestamp when block was created.
  let createdAt: Date

  // Rendering status.
  var status: BlockStatus

  // Type-specific content. Structure defined by BlockContent per block type.
  let content: BlockContent

  private enum CodingKeys: String, CodingKey {
    case id
    case type
    case createdAt = "created_at"
    case status
    case content
  }

  init(
    id: BlockID = BlockID(),
    type: BlockType,
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: BlockContent
  ) {
    self.id = id
    self.type = type
    self.createdAt = createdAt
    self.status = status
    self.content = content
  }

  // Convenience initializers for each block type.

  // Creates a text block.
  static func text(
    id: BlockID = BlockID(),
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: TextContent
  ) -> Block {
    Block(id: id, type: .text, createdAt: createdAt, status: status, content: .text(content))
  }

  // Creates an image block.
  static func image(
    id: BlockID = BlockID(),
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: ImageContent
  ) -> Block {
    Block(id: id, type: .image, createdAt: createdAt, status: status, content: .image(content))
  }

  // Creates a graphics block.
  static func graphics(
    id: BlockID = BlockID(),
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: GraphicsContent
  ) -> Block {
    Block(id: id, type: .graphics, createdAt: createdAt, status: status, content: .graphics(content))
  }

  // Creates a table block.
  static func table(
    id: BlockID = BlockID(),
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: TableContent
  ) -> Block {
    Block(id: id, type: .table, createdAt: createdAt, status: status, content: .table(content))
  }

  // Creates an embed block.
  static func embed(
    id: BlockID = BlockID(),
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: EmbedContent
  ) -> Block {
    Block(id: id, type: .embed, createdAt: createdAt, status: status, content: .embed(content))
  }

  // Creates an input block.
  static func input(
    id: BlockID = BlockID(),
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: InputContent
  ) -> Block {
    Block(id: id, type: .input, createdAt: createdAt, status: status, content: .input(content))
  }

  // Creates a checkpoint block.
  static func checkpoint(
    id: BlockID = BlockID(),
    createdAt: Date = Date(),
    status: BlockStatus = .ready,
    content: CheckpointContent = CheckpointContent()
  ) -> Block {
    Block(id: id, type: .checkpoint, createdAt: createdAt, status: status, content: .checkpoint(content))
  }
}

// MARK: - Block Codable

extension Block: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(BlockID.self, forKey: .id)
    self.type = try container.decode(BlockType.self, forKey: .type)
    self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    self.status = try container.decodeIfPresent(BlockStatus.self, forKey: .status) ?? .ready

    // Decode content based on type.
    let contentDecoder = try container.superDecoder(forKey: .content)
    self.content = try BlockContent.decode(for: type, from: contentDecoder)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(type, forKey: .type)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(status, forKey: .status)

    // Encode content to nested container.
    let contentEncoder = container.superEncoder(forKey: .content)
    try content.encode(to: contentEncoder)
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
