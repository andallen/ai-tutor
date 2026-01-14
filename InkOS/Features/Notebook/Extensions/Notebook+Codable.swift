//
// Notebook+Codable.swift
// InkOS
//
// Codable conformance and JSON serialization helpers for Notebook.
//

import Foundation

// MARK: - Notebook Codable

extension Notebook: Codable {
  private enum CodingKeys: String, CodingKey {
    case id
    case topic
    case blocks
    case parentId
    case metadata
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(NotebookID.self, forKey: .id)
    self.topic = try container.decode(String.self, forKey: .topic)
    self.blocks = try container.decode([Block].self, forKey: .blocks)
    self.parentId = try container.decodeIfPresent(NotebookID.self, forKey: .parentId)
    self.metadata = try container.decode(NotebookMeta.self, forKey: .metadata)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(topic, forKey: .topic)
    try container.encode(blocks, forKey: .blocks)
    try container.encodeIfPresent(parentId, forKey: .parentId)
    try container.encode(metadata, forKey: .metadata)
  }
}

// MARK: - JSON Encoding Helpers

extension Notebook {
  // Encodes notebook to JSON data with standard date formatting.
  func toJSONData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  // Decodes notebook from JSON data with standard date formatting.
  static func fromJSONData(_ data: Data) throws -> Notebook {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Notebook.self, from: data)
  }

  // Encodes notebook to JSON string.
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

  // Decodes notebook from JSON string.
  static func fromJSONString(_ string: String) throws -> Notebook {
    guard let data = string.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: [], debugDescription: "Failed to convert string to data")
      )
    }
    return try fromJSONData(data)
  }
}

// MARK: - Array Extension

extension Array where Element == Notebook {
  // Encodes array of notebooks to JSON data.
  func toJSONData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  // Decodes array of notebooks from JSON data.
  static func fromJSONData(_ data: Data) throws -> [Notebook] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([Notebook].self, from: data)
  }
}
