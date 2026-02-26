//
// SessionService.swift
// InkOS
//
// Manages session lifecycle: create, list, resume, archive.
// Sessions are persisted locally using JSON files in the app's documents directory.
// Each session contains a NotebookDocument and session metadata.
//

import Foundation

// MARK: - SessionMetadata

// Lightweight session info for dashboard display.
struct SessionMetadata: Identifiable, Codable, Sendable {
  let id: String
  var title: String
  var updatedAt: Date
  let createdAt: Date
  var goalDescription: String?
  var goalProgress: Int
  var blockCount: Int
  var userRenamed: Bool

  init(
    id: String = UUID().uuidString,
    title: String,
    updatedAt: Date = Date(),
    createdAt: Date = Date(),
    goalDescription: String? = nil,
    goalProgress: Int = 0,
    blockCount: Int = 0,
    userRenamed: Bool = false
  ) {
    self.id = id
    self.title = title
    self.updatedAt = updatedAt
    self.createdAt = createdAt
    self.goalDescription = goalDescription
    self.goalProgress = goalProgress
    self.blockCount = blockCount
    self.userRenamed = userRenamed
  }
}

// MARK: - SessionData

// Full session data including the notebook document and session model.
struct SessionData: Codable, Sendable {
  var metadata: SessionMetadata
  var document: NotebookDocument
  var sessionModel: SessionModel?
  var conversationHistory: [ChatMessage]

  init(
    metadata: SessionMetadata,
    document: NotebookDocument,
    sessionModel: SessionModel? = nil,
    conversationHistory: [ChatMessage] = []
  ) {
    self.metadata = metadata
    self.document = document
    self.sessionModel = sessionModel
    self.conversationHistory = conversationHistory
  }
}

// MARK: - SessionService

// Manages session persistence using local JSON files.
@MainActor
@Observable
final class SessionService {
  // All session metadata for dashboard display.
  var sessions: [SessionMetadata] = []

  // Directory for session storage.
  private let storageDirectory: URL

  // JSON encoder/decoder.
  private let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.prettyPrinted]
    return e
  }()

  private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()

  init() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    storageDirectory = docs.appendingPathComponent("sessions", isDirectory: true)

    // Create directory if needed.
    try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

    // Load sessions on init.
    loadSessionList()
  }

  // MARK: - Session CRUD

  // Creates a new session and returns its data.
  func createSession(title: String) -> SessionData {
    let sessionId = UUID().uuidString
    let document = NotebookDocument(
      id: NotebookDocumentID(sessionId),
      sessionId: sessionId,
      title: title,
      blocks: []
    )
    let metadata = SessionMetadata(
      id: sessionId,
      title: title
    )
    let sessionModel = SessionModel.new(sessionId: sessionId)
    let sessionData = SessionData(
      metadata: metadata,
      document: document,
      sessionModel: sessionModel
    )

    // Save to disk.
    saveSession(sessionData)

    // Update session list.
    sessions.insert(metadata, at: 0)

    return sessionData
  }

  // Loads full session data for a given session ID.
  func loadSession(id: String) -> SessionData? {
    let fileURL = storageDirectory.appendingPathComponent("\(id).json")
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    return try? decoder.decode(SessionData.self, from: data)
  }

  // Saves session data to disk and updates the session list.
  func saveSession(_ session: SessionData) {
    let fileURL = storageDirectory.appendingPathComponent("\(session.metadata.id).json")
    guard let data = try? encoder.encode(session) else { return }
    try? data.write(to: fileURL)

    // Update metadata in list.
    if let index = sessions.firstIndex(where: { $0.id == session.metadata.id }) {
      sessions[index] = session.metadata
    }
  }

  // Renames a session by updating its title in metadata and document.
  func renameSession(id: String, newTitle: String) {
    guard var sessionData = loadSession(id: id) else { return }
    sessionData.metadata.title = newTitle
    sessionData.metadata.userRenamed = true
    sessionData.document.title = newTitle
    saveSession(sessionData)
  }

  // Deletes a session.
  func deleteSession(id: String) {
    let fileURL = storageDirectory.appendingPathComponent("\(id).json")
    try? FileManager.default.removeItem(at: fileURL)
    sessions.removeAll { $0.id == id }
  }

  // MARK: - Session List

  // Loads the session list from disk.
  private func loadSessionList() {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: storageDirectory,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else { return }

    var loaded: [SessionMetadata] = []
    for file in files where file.pathExtension == "json" {
      guard let data = try? Data(contentsOf: file),
            let session = try? decoder.decode(SessionData.self, from: data) else { continue }
      loaded.append(session.metadata)
    }

    // Sort by most recently updated.
    sessions = loaded.sorted { $0.updatedAt > $1.updatedAt }
  }

  // Refreshes the session list from disk.
  func refreshSessions() {
    loadSessionList()
  }
}
