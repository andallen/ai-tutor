//
// LessonManifest.swift
// InkOS
//
// JSON metadata for lesson bundles, analogous to Manifest for notebooks.
// Stored as lesson-manifest.json inside each lesson bundle directory.
//

import Foundation

// Version constants for the LessonManifest format.
enum LessonManifestVersion: Sendable {
  static let current = 1
  static let supported: Set<Int> = [1]
}

// The LessonManifest is a JSON file inside a lesson bundle that describes the lesson metadata.
// The actual lesson content (sections) is stored separately in lesson.json.
// @unchecked Sendable bypasses strict checking that conflicts with actor isolation inference.
struct LessonManifest: Codable, @unchecked Sendable {
  // Unique identifier for this lesson.
  let lessonID: String

  // Display name shown to the user.
  var displayName: String

  // Subject area for the lesson (e.g., "Biology", "Math").
  var subject: String?

  // Estimated time to complete the lesson in minutes.
  var estimatedMinutes: Int?

  // How the lesson was generated.
  var sourceType: LessonSourceType?

  // Reference to the original source (PDF filename or prompt).
  var sourceReference: String?

  // Format version for backward compatibility.
  let version: Int

  // Timestamp when the lesson was created.
  let createdAt: Date

  // Timestamp when the lesson was last modified.
  var modifiedAt: Date

  // Timestamp when the lesson was last accessed.
  var lastAccessedAt: Date?

  // Total number of sections in the lesson.
  var sectionCount: Int

  // Number of sections the user has completed.
  var completedSectionCount: Int

  // Optional folder ID if lesson is inside a folder.
  var folderID: String?

  // Creates a new LessonManifest with the given lesson ID and display name.
  // Sets version and records creation timestamp.
  init(
    lessonID: String,
    displayName: String,
    subject: String? = nil,
    estimatedMinutes: Int? = nil,
    sourceType: LessonSourceType? = nil,
    sourceReference: String? = nil,
    sectionCount: Int = 0,
    folderID: String? = nil
  ) {
    self.lessonID = lessonID
    self.displayName = displayName
    self.subject = subject
    self.estimatedMinutes = estimatedMinutes
    self.sourceType = sourceType
    self.sourceReference = sourceReference
    self.version = LessonManifestVersion.current
    let now = Date()
    self.createdAt = now
    self.modifiedAt = now
    self.lastAccessedAt = now
    self.sectionCount = sectionCount
    self.completedSectionCount = 0
    self.folderID = folderID
  }
}

// Explicit Codable conformance methods.
extension LessonManifest {
  private enum CodingKeys: String, CodingKey {
    case lessonID
    case displayName
    case subject
    case estimatedMinutes
    case sourceType
    case sourceReference
    case version
    case createdAt
    case modifiedAt
    case lastAccessedAt
    case sectionCount
    case completedSectionCount
    case folderID
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.lessonID = try container.decode(String.self, forKey: .lessonID)
    self.displayName = try container.decode(String.self, forKey: .displayName)
    self.subject = try container.decodeIfPresent(String.self, forKey: .subject)
    self.estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
    self.sourceType = try container.decodeIfPresent(LessonSourceType.self, forKey: .sourceType)
    self.sourceReference = try container.decodeIfPresent(String.self, forKey: .sourceReference)
    self.version = try container.decode(Int.self, forKey: .version)
    self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    self.modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    self.lastAccessedAt = try container.decodeIfPresent(Date.self, forKey: .lastAccessedAt)
    self.sectionCount = try container.decode(Int.self, forKey: .sectionCount)
    self.completedSectionCount = try container.decode(Int.self, forKey: .completedSectionCount)
    self.folderID = try container.decodeIfPresent(String.self, forKey: .folderID)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(lessonID, forKey: .lessonID)
    try container.encode(displayName, forKey: .displayName)
    try container.encodeIfPresent(subject, forKey: .subject)
    try container.encodeIfPresent(estimatedMinutes, forKey: .estimatedMinutes)
    try container.encodeIfPresent(sourceType, forKey: .sourceType)
    try container.encodeIfPresent(sourceReference, forKey: .sourceReference)
    try container.encode(version, forKey: .version)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(modifiedAt, forKey: .modifiedAt)
    try container.encodeIfPresent(lastAccessedAt, forKey: .lastAccessedAt)
    try container.encode(sectionCount, forKey: .sectionCount)
    try container.encode(completedSectionCount, forKey: .completedSectionCount)
    try container.encodeIfPresent(folderID, forKey: .folderID)
  }
}

// Constants for lesson bundle file names.
enum LessonConstants {
  static let manifestFileName = "lesson-manifest.json"
  static let contentFileName = "lesson.json"
  static let progressFileName = "progress.json"
  static let previewFileName = "thumbnail.png"
  static let assetsDirectoryName = "assets"
}

// Errors that can occur when working with lesson bundles.
enum LessonBundleError: LocalizedError, Equatable {
  case lessonNotFound(lessonID: String)
  case manifestNotFound(lessonID: String)
  case manifestDecodingFailed(lessonID: String)
  case unsupportedManifestVersion(lessonID: String, version: Int)
  case invalidManifest(lessonID: String, reason: String)
  case contentNotFound(lessonID: String)
  case contentDecodingFailed(lessonID: String)
  case progressDecodingFailed(lessonID: String)
  case saveFailed(lessonID: String, reason: String)

  var errorDescription: String? {
    switch self {
    case .lessonNotFound(let id):
      return "Lesson not found: \(id)"
    case .manifestNotFound(let id):
      return "Lesson manifest not found: \(id)"
    case .manifestDecodingFailed(let id):
      return "Failed to decode lesson manifest: \(id)"
    case .unsupportedManifestVersion(let id, let version):
      return "Unsupported lesson manifest version \(version) for lesson: \(id)"
    case .invalidManifest(let id, let reason):
      return "Invalid lesson manifest for \(id): \(reason)"
    case .contentNotFound(let id):
      return "Lesson content not found: \(id)"
    case .contentDecodingFailed(let id):
      return "Failed to decode lesson content: \(id)"
    case .progressDecodingFailed(let id):
      return "Failed to decode lesson progress: \(id)"
    case .saveFailed(let id, let reason):
      return "Failed to save lesson \(id): \(reason)"
    }
  }
}
