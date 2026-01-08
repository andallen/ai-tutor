//
// LessonProgress.swift
// InkOS
//
// Tracks user progress through lesson sections.
// Stored as progress.json inside each lesson bundle.
//

import Foundation

// Root progress container for a lesson.
// Persists user answers and completion state across sessions.
struct LessonProgress: Codable, Sendable, Equatable {
  // Lesson ID this progress belongs to.
  let lessonID: String

  // Last time the lesson was opened.
  var lastOpenedAt: Date

  // Progress for each section, keyed by section ID.
  var sections: [String: SectionProgress]

  // Creates empty progress for a new lesson.
  init(lessonID: String) {
    self.lessonID = lessonID
    self.lastOpenedAt = Date()
    self.sections = [:]
  }

  // Returns the completion status for a given section ID.
  func isCompleted(sectionID: String) -> Bool {
    sections[sectionID]?.completed ?? false
  }

  // Returns the count of completed sections.
  var completedCount: Int {
    sections.values.filter { $0.completed }.count
  }

  // Returns completion percentage as a value between 0 and 1.
  func completionPercentage(totalSections: Int) -> Double {
    guard totalSections > 0 else { return 0 }
    return Double(completedCount) / Double(totalSections)
  }

  // Marks a section as completed.
  mutating func markCompleted(sectionID: String) {
    if sections[sectionID] == nil {
      sections[sectionID] = SectionProgress(sectionID: sectionID)
    }
    sections[sectionID]?.completed = true
    sections[sectionID]?.completedAt = Date()
  }

  // Records a user answer for a question section.
  mutating func recordAnswer(
    sectionID: String,
    userAnswer: String,
    feedback: String?,
    wasCorrect: Bool
  ) {
    if sections[sectionID] == nil {
      sections[sectionID] = SectionProgress(sectionID: sectionID)
    }
    sections[sectionID]?.userAnswer = userAnswer
    sections[sectionID]?.feedback = feedback
    sections[sectionID]?.wasCorrect = wasCorrect
    sections[sectionID]?.completed = true
    sections[sectionID]?.completedAt = Date()
  }
}

// Progress state for an individual section.
struct SectionProgress: Codable, Sendable, Equatable {
  // Section ID this progress belongs to.
  let sectionID: String

  // Whether the user has completed this section.
  var completed: Bool

  // Timestamp when the section was completed.
  var completedAt: Date?

  // User's submitted answer (for question sections).
  var userAnswer: String?

  // AI feedback on the user's answer.
  var feedback: String?

  // Whether the answer was marked correct.
  var wasCorrect: Bool?

  // Creates empty progress for a section.
  init(sectionID: String) {
    self.sectionID = sectionID
    self.completed = false
    self.completedAt = nil
    self.userAnswer = nil
    self.feedback = nil
    self.wasCorrect = nil
  }
}

// Explicit Codable conformance for LessonProgress.
extension LessonProgress {
  private enum CodingKeys: String, CodingKey {
    case lessonID = "lessonId"
    case lastOpenedAt
    case sections
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.lessonID = try container.decode(String.self, forKey: .lessonID)
    self.lastOpenedAt = try container.decode(Date.self, forKey: .lastOpenedAt)
    self.sections = try container.decode([String: SectionProgress].self, forKey: .sections)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(lessonID, forKey: .lessonID)
    try container.encode(lastOpenedAt, forKey: .lastOpenedAt)
    try container.encode(sections, forKey: .sections)
  }
}

// Explicit Codable conformance for SectionProgress.
extension SectionProgress {
  private enum CodingKeys: String, CodingKey {
    case sectionID
    case completed
    case completedAt
    case userAnswer
    case feedback
    case wasCorrect
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.sectionID = try container.decode(String.self, forKey: .sectionID)
    self.completed = try container.decode(Bool.self, forKey: .completed)
    self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    self.userAnswer = try container.decodeIfPresent(String.self, forKey: .userAnswer)
    self.feedback = try container.decodeIfPresent(String.self, forKey: .feedback)
    self.wasCorrect = try container.decodeIfPresent(Bool.self, forKey: .wasCorrect)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(sectionID, forKey: .sectionID)
    try container.encode(completed, forKey: .completed)
    try container.encodeIfPresent(completedAt, forKey: .completedAt)
    try container.encodeIfPresent(userAnswer, forKey: .userAnswer)
    try container.encodeIfPresent(feedback, forKey: .feedback)
    try container.encodeIfPresent(wasCorrect, forKey: .wasCorrect)
  }
}
