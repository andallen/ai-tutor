//
// BlockContent.swift
// InkOS
//
// Type-safe wrapper for block-specific content.
// Each case wraps a struct with content specific to that block type.
//

import Foundation

// MARK: - BlockContent

// Type-safe wrapper for block-specific content.
// Each case wraps a struct with content specific to that block type.
enum BlockContent: Sendable, Equatable {
  case text(TextContent)
  case image(ImageContent)
  case graphics(GraphicsContent)
  case table(TableContent)
  case embed(EmbedContent)
  case input(InputContent)
  case checkpoint(CheckpointContent)
}

// MARK: - BlockContent Codable

extension BlockContent: Codable {
  // Decode content based on block type.
  // Called from Block.init(from:) with the type already known.
  static func decode(for type: BlockType, from decoder: Decoder) throws -> BlockContent {
    switch type {
    case .text:
      let content = try TextContent(from: decoder)
      return .text(content)
    case .image:
      let content = try ImageContent(from: decoder)
      return .image(content)
    case .graphics:
      let content = try GraphicsContent(from: decoder)
      return .graphics(content)
    case .table:
      let content = try TableContent(from: decoder)
      return .table(content)
    case .embed:
      let content = try EmbedContent(from: decoder)
      return .embed(content)
    case .input:
      let content = try InputContent(from: decoder)
      return .input(content)
    case .checkpoint:
      let content = try CheckpointContent(from: decoder)
      return .checkpoint(content)
    }
  }

  // Standard Codable init - requires type to be known externally.
  // This is called when decoding BlockContent directly (not through Block).
  init(from decoder: Decoder) throws {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "BlockContent decoding requires the block type to be known. Use decode(for:from:) instead."
      )
    )
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .text(let content):
      try content.encode(to: encoder)
    case .image(let content):
      try content.encode(to: encoder)
    case .graphics(let content):
      try content.encode(to: encoder)
    case .table(let content):
      try content.encode(to: encoder)
    case .embed(let content):
      try content.encode(to: encoder)
    case .input(let content):
      try content.encode(to: encoder)
    case .checkpoint(let content):
      try content.encode(to: encoder)
    }
  }
}

// MARK: - Convenience Accessors

extension BlockContent {
  // Returns the text content if this is a text block.
  var textContent: TextContent? {
    if case .text(let content) = self { return content }
    return nil
  }

  // Returns the image content if this is an image block.
  var imageContent: ImageContent? {
    if case .image(let content) = self { return content }
    return nil
  }

  // Returns the graphics content if this is a graphics block.
  var graphicsContent: GraphicsContent? {
    if case .graphics(let content) = self { return content }
    return nil
  }

  // Returns the table content if this is a table block.
  var tableContent: TableContent? {
    if case .table(let content) = self { return content }
    return nil
  }

  // Returns the embed content if this is an embed block.
  var embedContent: EmbedContent? {
    if case .embed(let content) = self { return content }
    return nil
  }

  // Returns the input content if this is an input block.
  var inputContent: InputContent? {
    if case .input(let content) = self { return content }
    return nil
  }

  // Returns the checkpoint content if this is a checkpoint block.
  var checkpointContent: CheckpointContent? {
    if case .checkpoint(let content) = self { return content }
    return nil
  }

  // Returns the animation duration in milliseconds for this block.
  // Text blocks use streaming duration; others use a default reveal time.
  var animationDurationMs: Int {
    switch self {
    case .text(let content):
      return content.streamingDurationMs
    case .image, .graphics, .table, .embed, .input, .checkpoint:
      // Non-text blocks appear with a brief reveal animation.
      return 300
    }
  }
}
