//
// NotebookContract.swift
// InkOS
//
// Notebook Document Schema - the single source of truth for what appears
// on the canvas during a tutoring session. Contains an ordered list of blocks.
//

import Foundation

// MARK: - NotebookDocumentID

// Type-safe identifier for notebook documents.
struct NotebookDocumentID: Hashable, Sendable, Codable, Equatable, CustomStringConvertible {
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

// MARK: - NotebookDocument

// The single source of truth for a tutoring session's visual state.
// Contains an ordered list of primitive blocks to render.
struct NotebookDocument: Identifiable, Sendable, Equatable, Codable {
  // Unique identifier for this notebook document.
  let id: NotebookDocumentID

  // Increments on each update, enables optimistic concurrency.
  var version: Int

  // Timestamp when document was created.
  let createdAt: Date

  // Timestamp when document was last modified.
  var updatedAt: Date

  // Links to the tutoring session this document belongs to.
  let sessionId: String?

  // Optional title for this notebook.
  var title: String?

  // Ordered list of primitive blocks to render.
  var blocks: [Block]

  private enum CodingKeys: String, CodingKey {
    case id
    case version
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case sessionId = "session_id"
    case title
    case blocks
  }

  init(
    id: NotebookDocumentID = NotebookDocumentID(),
    version: Int = 1,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    sessionId: String? = nil,
    title: String? = nil,
    blocks: [Block] = []
  ) {
    self.id = id
    self.version = version
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.sessionId = sessionId
    self.title = title
    self.blocks = blocks
  }

  // Increments version and updates timestamp.
  mutating func incrementVersion() {
    version += 1
    updatedAt = Date()
  }

  // Appends a block and increments version.
  mutating func appendBlock(_ block: Block) {
    blocks.append(block)
    incrementVersion()
  }

  // Inserts a block at index and increments version.
  mutating func insertBlock(_ block: Block, at index: Int) {
    blocks.insert(block, at: index)
    incrementVersion()
  }

  // Removes block at index and increments version.
  @discardableResult
  mutating func removeBlock(at index: Int) -> Block {
    let block = blocks.remove(at: index)
    incrementVersion()
    return block
  }

  // Updates block at index and increments version.
  mutating func updateBlock(at index: Int, with block: Block) {
    blocks[index] = block
    incrementVersion()
  }

  // Finds block by ID.
  func block(withId id: BlockID) -> Block? {
    blocks.first { $0.id == id }
  }

  // Finds index of block by ID.
  func indexOfBlock(withId id: BlockID) -> Int? {
    blocks.firstIndex { $0.id == id }
  }
}

// MARK: - JSON Encoding Helpers

extension NotebookDocument {
  // Encodes notebook document to JSON data with standard date formatting.
  func toJSONData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  // Decodes notebook document from JSON data with standard date formatting.
  static func fromJSONData(_ data: Data) throws -> NotebookDocument {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(NotebookDocument.self, from: data)
  }

  // Encodes notebook document to JSON string.
  func toJSONString() throws -> String {
    let data = try toJSONData()
    guard let string = String(data: data, encoding: .utf8) else {
      throw EncodingError.invalidValue(
        self,
        EncodingError.Context(
          codingPath: [], debugDescription: "Failed to convert JSON data to string")
      )
    }
    return string
  }

  // Decodes notebook document from JSON string.
  static func fromJSONString(_ string: String) throws -> NotebookDocument {
    guard let data = string.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: [], debugDescription: "Failed to convert string to data")
      )
    }
    return try fromJSONData(data)
  }
}
