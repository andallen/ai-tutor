//
// NotebookContract.swift
// InkOS
//
// Core Notebook container types for the Alan educational content system.
// A Notebook holds Blocks and serves as the base type for both standalone
// notebooks and branches (notebooks with a parent).
//

import Foundation

// MARK: - NotebookID

// Type-safe identifier for notebooks.
// Uses String internally for JSON compatibility and easy debugging.
struct NotebookID: Hashable, Sendable, Codable, Equatable, CustomStringConvertible {
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

// MARK: - NotebookSchemaVersion

// Schema version for Notebook format migration.
enum NotebookSchemaVersion {
  static let current = 1
  static let supported: Set<Int> = [1]
}

// MARK: - NotebookMeta

// Metadata about a notebook's creation and modification.
// Named NotebookMeta to avoid conflict with storage layer's NotebookMetadata.
struct NotebookMeta: Sendable, Codable, Equatable {
  // Timestamp when notebook was created.
  let createdAt: Date

  // Timestamp when notebook was last modified.
  var modifiedAt: Date

  // Schema version for migration.
  let schemaVersion: Int

  private enum CodingKeys: String, CodingKey {
    case createdAt
    case modifiedAt
    case schemaVersion
  }

  init(
    createdAt: Date = Date(),
    modifiedAt: Date = Date(),
    schemaVersion: Int = NotebookSchemaVersion.current
  ) {
    self.createdAt = createdAt
    self.modifiedAt = modifiedAt
    self.schemaVersion = schemaVersion
  }
}

// MARK: - Notebook

// Container for blocks in InkOS.
// If parentId is nil, this is a standalone notebook.
// If parentId is set, this is a branch (child of another notebook).
struct Notebook: Identifiable, Sendable, Equatable {
  // Unique identifier for this notebook.
  let id: NotebookID

  // What this notebook is about.
  var topic: String

  // Linear sequence of blocks shown to user.
  var blocks: [Block]

  // Reference to parent notebook. Nil means standalone, set means branch.
  let parentId: NotebookID?

  // Metadata about creation and modification.
  let metadata: NotebookMeta

  // Returns true if this notebook has a parent (is a branch).
  var isBranch: Bool { parentId != nil }

  // Initializer with defaults for optional fields.
  init(
    id: NotebookID = NotebookID(),
    topic: String,
    blocks: [Block] = [],
    parentId: NotebookID? = nil,
    metadata: NotebookMeta = NotebookMeta()
  ) {
    self.id = id
    self.topic = topic
    self.blocks = blocks
    self.parentId = parentId
    self.metadata = metadata
  }
}
