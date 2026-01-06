// SearchIndex.swift
// SQLite FTS5-based search index actor for keyword search.

import Foundation
import SQLite3

// MARK: - SearchIndex Actor

// Actor that manages the SQLite FTS5 search index.
// Thread-safe through actor isolation.
actor SearchIndex: SearchIndexProtocol {
  // SQLite database connection handle.
  private var db: OpaquePointer?

  // Configuration for database paths and settings.
  private let configuration: SearchIndexConfiguration

  // Whether the database has been initialized.
  private var isInitialized = false

  // Date formatter for ISO8601 timestamps in SQLite.
  private let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  // Creates a search index with the given configuration.
  init(configuration: SearchIndexConfiguration = .default) {
    self.configuration = configuration
  }

  deinit {
    if let db = db {
      sqlite3_close(db)
    }
  }

  // MARK: - Initialization

  func initialize() async throws {
    // Idempotent: skip if already initialized.
    guard !isInitialized else { return }

    // Create database directory if needed.
    let databaseURL = try getDatabaseURL()
    let directoryURL = databaseURL.deletingLastPathComponent()

    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: directoryURL.path) {
      do {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      } catch {
        throw SearchIndexError.fileSystemError(reason: "Failed to create directory: \(error.localizedDescription)")
      }
    }

    // Open or create the database.
    let result = sqlite3_open(databaseURL.path, &db)
    guard result == SQLITE_OK else {
      let errorMessage = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
      throw SearchIndexError.initializationFailed(reason: "Failed to open database: \(errorMessage)")
    }

    // Create FTS5 virtual table if it doesn't exist.
    try createFTSTable()

    // Create metadata table for tracking indexed documents.
    try createMetadataTable()

    isInitialized = true
  }

  // MARK: - Document Indexing

  func indexDocument(_ entry: SearchIndexEntry) async throws {
    try ensureInitialized()

    // Use INSERT OR REPLACE to handle both insert and update.
    let sql = """
      INSERT OR REPLACE INTO \(SearchIndexConstants.ftsTableName)
      (documentID, documentType, folderID, title, contentText, modifiedAt)
      VALUES (?, ?, ?, ?, ?, ?)
      """

    try executeSQL(sql, parameters: [
      entry.documentID,
      entry.documentType.rawValue,
      entry.folderID as Any,
      entry.title,
      sanitizeContent(entry.contentText),
      dateFormatter.string(from: entry.modifiedAt),
    ])

    // Update metadata table.
    try updateMetadata(for: entry)
  }

  func indexDocuments(_ entries: [SearchIndexEntry]) async throws {
    try ensureInitialized()

    // Empty array is a no-op.
    guard !entries.isEmpty else { return }

    // Use transaction for atomicity and performance.
    try executeSQL("BEGIN TRANSACTION")

    do {
      for entry in entries {
        let sql = """
          INSERT OR REPLACE INTO \(SearchIndexConstants.ftsTableName)
          (documentID, documentType, folderID, title, contentText, modifiedAt)
          VALUES (?, ?, ?, ?, ?, ?)
          """

        try executeSQL(sql, parameters: [
          entry.documentID,
          entry.documentType.rawValue,
          entry.folderID as Any,
          entry.title,
          sanitizeContent(entry.contentText),
          dateFormatter.string(from: entry.modifiedAt),
        ])

        try updateMetadata(for: entry)
      }

      try executeSQL("COMMIT")
    } catch {
      // Rollback on any failure.
      try? executeSQL("ROLLBACK")
      throw error
    }
  }

  // MARK: - Document Removal

  func removeDocument(documentID: String) async throws {
    try ensureInitialized()

    // Delete from FTS table.
    let sql = "DELETE FROM \(SearchIndexConstants.ftsTableName) WHERE documentID = ?"
    try executeSQL(sql, parameters: [documentID])

    // Delete from metadata table.
    let metaSql = "DELETE FROM search_metadata WHERE documentID = ?"
    try executeSQL(metaSql, parameters: [documentID])
  }

  // MARK: - Search

  func search(query: String, scope: SearchScope, limit: Int) async throws -> [IndexedMatch] {
    try ensureInitialized()

    // Validate query.
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      throw SearchIndexError.invalidQuery(query: query)
    }

    // Handle invalid limit.
    guard limit > 0 else {
      return []
    }

    // Escape query for FTS5.
    let escapedQuery = escapeFTSQuery(trimmedQuery)

    // Build WHERE clause based on scope.
    var whereClause = ""
    var parameters: [Any] = []

    switch scope {
    case .all:
      break
    case .folder(let folderID):
      whereClause = "AND folderID = ?"
      parameters.append(folderID)
    case .document(let documentID):
      whereClause = "AND documentID = ?"
      parameters.append(documentID)
    }

    // Build search query with ranking.
    // Use bm25 with title weighted higher than content.
    let sql = """
      SELECT documentID, documentType, folderID, title,
             snippet(\(SearchIndexConstants.ftsTableName), 4, '...', '...', '', \(configuration.snippetLength)) as snippet,
             bm25(\(SearchIndexConstants.ftsTableName), \(SearchIndexConstants.titleWeight), 1.0, 1.0, \(SearchIndexConstants.titleWeight), \(SearchIndexConstants.contentWeight), 1.0) as rank
      FROM \(SearchIndexConstants.ftsTableName)
      WHERE \(SearchIndexConstants.ftsTableName) MATCH ?
      \(whereClause)
      ORDER BY rank
      LIMIT ?
      """

    parameters.insert(escapedQuery, at: 0)
    parameters.append(limit)

    return try executeQuery(sql, parameters: parameters)
  }

  // MARK: - Index State

  func isDocumentIndexed(documentID: String) async -> Bool {
    guard isInitialized else { return false }

    let sql = "SELECT COUNT(*) FROM \(SearchIndexConstants.ftsTableName) WHERE documentID = ?"
    do {
      let count = try executeCountQuery(sql, parameters: [documentID])
      return count > 0
    } catch {
      return false
    }
  }

  func documentNeedsReindex(documentID: String, modifiedAt: Date) async -> Bool {
    guard isInitialized else { return true }

    let sql = "SELECT modifiedAt FROM search_metadata WHERE documentID = ?"
    do {
      guard let storedDateString = try executeScalarQuery(sql, parameters: [documentID]) as? String,
        let storedDate = dateFormatter.date(from: storedDateString)
      else {
        // Document not in index.
        return true
      }

      // Needs reindex if stored date is older than provided date.
      return storedDate < modifiedAt
    } catch {
      return true
    }
  }

  func clearIndex() async throws {
    try ensureInitialized()

    // Delete all from FTS table.
    try executeSQL("DELETE FROM \(SearchIndexConstants.ftsTableName)")

    // Delete all from metadata table.
    try executeSQL("DELETE FROM search_metadata")
  }

  // MARK: - Private Helpers

  private func ensureInitialized() throws {
    guard isInitialized else {
      throw SearchIndexError.initializationFailed(reason: "Database not initialized. Call initialize() first.")
    }
  }

  private func getDatabaseURL() throws -> URL {
    guard
      let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first
    else {
      throw SearchIndexError.fileSystemError(reason: "Could not locate Application Support directory")
    }

    return appSupport
      .appendingPathComponent(configuration.databaseDirectory)
      .appendingPathComponent(configuration.databaseFileName)
  }

  private func createFTSTable() throws {
    // Create FTS5 virtual table with porter stemmer.
    let sql = """
      CREATE VIRTUAL TABLE IF NOT EXISTS \(SearchIndexConstants.ftsTableName) USING fts5(
        documentID,
        documentType,
        folderID,
        title,
        contentText,
        modifiedAt,
        tokenize = '\(SearchIndexConstants.tokenizerConfig)'
      )
      """
    try executeSQL(sql)
  }

  private func createMetadataTable() throws {
    // Create metadata table for tracking document state.
    let sql = """
      CREATE TABLE IF NOT EXISTS search_metadata (
        documentID TEXT PRIMARY KEY,
        modifiedAt TEXT NOT NULL,
        contentHash TEXT
      )
      """
    try executeSQL(sql)
  }

  private func updateMetadata(for entry: SearchIndexEntry) throws {
    let sql = """
      INSERT OR REPLACE INTO search_metadata (documentID, modifiedAt, contentHash)
      VALUES (?, ?, ?)
      """
    let hash = String(entry.contentText.hashValue)
    try executeSQL(sql, parameters: [
      entry.documentID,
      dateFormatter.string(from: entry.modifiedAt),
      hash,
    ])
  }

  private func sanitizeContent(_ content: String) -> String {
    // Remove null bytes that could cause issues.
    return content.replacingOccurrences(of: "\0", with: "")
  }

  private func escapeFTSQuery(_ query: String) -> String {
    // For basic queries, wrap each word in quotes to treat as literal.
    // This prevents FTS5 syntax errors from user input.
    let words = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

    // Check if query already uses FTS5 operators (advanced user).
    let ftsOperators = ["AND", "OR", "NOT", "NEAR"]
    let hasOperators = words.contains { ftsOperators.contains($0.uppercased()) }

    if hasOperators {
      // Let advanced queries through as-is.
      return query
    }

    // Escape special characters and create search pattern.
    let escaped = words.map { word -> String in
      // Escape double quotes in words.
      let escapedWord = word.replacingOccurrences(of: "\"", with: "\"\"")
      return "\"\(escapedWord)\""
    }

    return escaped.joined(separator: " ")
  }

  // MARK: - SQL Execution

  private func executeSQL(_ sql: String, parameters: [Any] = []) throws {
    guard let db = db else {
      throw SearchIndexError.databaseError(reason: "Database connection not available")
    }

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      let errorMessage = String(cString: sqlite3_errmsg(db))
      throw SearchIndexError.databaseError(reason: "Failed to prepare statement: \(errorMessage)")
    }

    // Bind parameters.
    for (index, param) in parameters.enumerated() {
      let sqlIndex = Int32(index + 1)
      try bindParameter(statement: statement, index: sqlIndex, value: param)
    }

    let result = sqlite3_step(statement)
    guard result == SQLITE_DONE || result == SQLITE_ROW else {
      let errorMessage = String(cString: sqlite3_errmsg(db))
      throw SearchIndexError.databaseError(reason: "Failed to execute statement: \(errorMessage)")
    }
  }

  private func executeQuery(_ sql: String, parameters: [Any]) throws -> [IndexedMatch] {
    guard let db = db else {
      throw SearchIndexError.databaseError(reason: "Database connection not available")
    }

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      let errorMessage = String(cString: sqlite3_errmsg(db))
      throw SearchIndexError.databaseError(reason: "Failed to prepare query: \(errorMessage)")
    }

    // Bind parameters.
    for (index, param) in parameters.enumerated() {
      let sqlIndex = Int32(index + 1)
      try bindParameter(statement: statement, index: sqlIndex, value: param)
    }

    var results: [IndexedMatch] = []

    while sqlite3_step(statement) == SQLITE_ROW {
      let documentID = String(cString: sqlite3_column_text(statement, 0))
      let documentTypeRaw = String(cString: sqlite3_column_text(statement, 1))
      let documentType = DocumentType(rawValue: documentTypeRaw) ?? .notebook

      var folderID: String?
      if sqlite3_column_type(statement, 2) != SQLITE_NULL {
        folderID = String(cString: sqlite3_column_text(statement, 2))
      }

      let title = String(cString: sqlite3_column_text(statement, 3))
      let snippet = String(cString: sqlite3_column_text(statement, 4))
      let rank = sqlite3_column_double(statement, 5)

      let match = IndexedMatch(
        documentID: documentID,
        documentType: documentType,
        title: title,
        snippet: snippet,
        folderID: folderID,
        relevanceRank: rank
      )
      results.append(match)
    }

    return results
  }

  private func executeCountQuery(_ sql: String, parameters: [Any]) throws -> Int {
    guard let db = db else {
      throw SearchIndexError.databaseError(reason: "Database connection not available")
    }

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      let errorMessage = String(cString: sqlite3_errmsg(db))
      throw SearchIndexError.databaseError(reason: "Failed to prepare count query: \(errorMessage)")
    }

    for (index, param) in parameters.enumerated() {
      let sqlIndex = Int32(index + 1)
      try bindParameter(statement: statement, index: sqlIndex, value: param)
    }

    guard sqlite3_step(statement) == SQLITE_ROW else {
      return 0
    }

    return Int(sqlite3_column_int(statement, 0))
  }

  private func executeScalarQuery(_ sql: String, parameters: [Any]) throws -> Any? {
    guard let db = db else {
      throw SearchIndexError.databaseError(reason: "Database connection not available")
    }

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      let errorMessage = String(cString: sqlite3_errmsg(db))
      throw SearchIndexError.databaseError(reason: "Failed to prepare scalar query: \(errorMessage)")
    }

    for (index, param) in parameters.enumerated() {
      let sqlIndex = Int32(index + 1)
      try bindParameter(statement: statement, index: sqlIndex, value: param)
    }

    guard sqlite3_step(statement) == SQLITE_ROW else {
      return nil
    }

    let columnType = sqlite3_column_type(statement, 0)
    switch columnType {
    case SQLITE_TEXT:
      return String(cString: sqlite3_column_text(statement, 0))
    case SQLITE_INTEGER:
      return Int(sqlite3_column_int64(statement, 0))
    case SQLITE_FLOAT:
      return sqlite3_column_double(statement, 0)
    case SQLITE_NULL:
      return nil
    default:
      return nil
    }
  }

  private func bindParameter(statement: OpaquePointer?, index: Int32, value: Any) throws {
    switch value {
    case let string as String:
      sqlite3_bind_text(statement, index, string, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    case let int as Int:
      sqlite3_bind_int64(statement, index, Int64(int))
    case let double as Double:
      sqlite3_bind_double(statement, index, double)
    case is NSNull:
      sqlite3_bind_null(statement, index)
    case Optional<Any>.none:
      sqlite3_bind_null(statement, index)
    default:
      // Try to convert to string as fallback.
      let string = String(describing: value)
      sqlite3_bind_text(statement, index, string, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
  }
}
