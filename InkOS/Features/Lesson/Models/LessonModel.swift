//
// LessonModel.swift
// InkOS
//
// Codable data models for interactive lessons.
// Matches the lesson JSON schema for AI-generated lesson content.
//

import Foundation

// Main lesson container holding all sections and metadata.
struct Lesson: Codable, Sendable, Equatable {
  let lessonId: String
  let title: String
  let metadata: LessonContentMetadata
  let sections: [LessonSection]

  // Creates a new lesson with a generated UUID.
  init(
    lessonId: String = UUID().uuidString,
    title: String,
    metadata: LessonContentMetadata,
    sections: [LessonSection]
  ) {
    self.lessonId = lessonId
    self.title = title
    self.metadata = metadata
    self.sections = sections
  }
}

// Metadata embedded within the lesson JSON content.
// Distinct from LessonManifest which is the bundle's top-level metadata.
struct LessonContentMetadata: Codable, Sendable, Equatable {
  let subject: String?
  let estimatedMinutes: Int?
  let sourceType: LessonSourceType?
  let createdAt: Date?
  let sourceReference: String?

  enum CodingKeys: String, CodingKey {
    case subject
    case estimatedMinutes
    case sourceType
    case createdAt
    case sourceReference
  }

  init(
    subject: String? = nil,
    estimatedMinutes: Int? = nil,
    sourceType: LessonSourceType? = nil,
    createdAt: Date? = nil,
    sourceReference: String? = nil
  ) {
    self.subject = subject
    self.estimatedMinutes = estimatedMinutes
    self.sourceType = sourceType
    self.createdAt = createdAt
    self.sourceReference = sourceReference
  }
}

// Source type indicating how the lesson was generated.
enum LessonSourceType: String, Codable, Sendable {
  case pdf
  case prompt
  case hybrid
}

// A single section within a lesson.
// Uses associated values to hold type-specific data.
enum LessonSection: Codable, Sendable, Equatable {
  case content(ContentSection)
  case visual(VisualSection)
  case question(QuestionSection)
  case summary(SummarySection)

  // Section type identifier for encoding/decoding.
  private enum SectionType: String, Codable {
    case content
    case visual
    case question
    case summary
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case type
  }

  // Unique identifier for this section.
  var id: String {
    switch self {
    case .content(let section): return section.id
    case .visual(let section): return section.id
    case .question(let section): return section.id
    case .summary(let section): return section.id
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(SectionType.self, forKey: .type)

    switch type {
    case .content:
      let section = try ContentSection(from: decoder)
      self = .content(section)
    case .visual:
      let section = try VisualSection(from: decoder)
      self = .visual(section)
    case .question:
      let section = try QuestionSection(from: decoder)
      self = .question(section)
    case .summary:
      let section = try SummarySection(from: decoder)
      self = .summary(section)
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .content(let section):
      try section.encode(to: encoder)
    case .visual(let section):
      try section.encode(to: encoder)
    case .question(let section):
      try section.encode(to: encoder)
    case .summary(let section):
      try section.encode(to: encoder)
    }
  }
}

// Content section containing markdown text.
struct ContentSection: Codable, Sendable, Equatable {
  let id: String
  let type: String
  let content: String

  init(id: String = UUID().uuidString, content: String) {
    self.id = id
    self.type = "content"
    self.content = content
  }
}

// Visual section for images or interactive content.
struct VisualSection: Codable, Sendable, Equatable {
  let id: String
  let type: String
  let visualType: VisualType
  let imagePrompt: String?
  let code: String?
  let fallbackDescription: String?

  init(
    id: String = UUID().uuidString,
    visualType: VisualType,
    imagePrompt: String? = nil,
    code: String? = nil,
    fallbackDescription: String? = nil
  ) {
    self.id = id
    self.type = "visual"
    self.visualType = visualType
    self.imagePrompt = imagePrompt
    self.code = code
    self.fallbackDescription = fallbackDescription
  }
}

// Type of visual content in a visual section.
enum VisualType: String, Codable, Sendable {
  case generated
  case interactive
}

// Question section for user interaction and assessment.
struct QuestionSection: Codable, Sendable, Equatable {
  let id: String
  let type: String
  let questionType: QuestionType
  let prompt: String
  let options: [String]?
  let answer: String
  let explanation: String?

  init(
    id: String = UUID().uuidString,
    questionType: QuestionType,
    prompt: String,
    options: [String]? = nil,
    answer: String,
    explanation: String? = nil
  ) {
    self.id = id
    self.type = "question"
    self.questionType = questionType
    self.prompt = prompt
    self.options = options
    self.answer = answer
    self.explanation = explanation
  }
}

// Type of question determining input method and evaluation.
enum QuestionType: String, Codable, Sendable {
  case multipleChoice
  case freeResponse
  case math
}

// Summary section containing key takeaways.
struct SummarySection: Codable, Sendable, Equatable {
  let id: String
  let type: String
  let content: String

  init(id: String = UUID().uuidString, content: String) {
    self.id = id
    self.type = "summary"
    self.content = content
  }
}

// Metadata for displaying a lesson in the dashboard.
// Separate from Lesson to allow loading metadata without full content.
struct LessonMetadata: Identifiable, Sendable, Equatable {
  let id: String
  let displayName: String
  let subject: String?
  let estimatedMinutes: Int?
  let createdAt: Date
  let modifiedAt: Date
  let lastAccessedAt: Date?
  let previewImage: Data?
  let completionPercentage: Double

  init(
    id: String,
    displayName: String,
    subject: String? = nil,
    estimatedMinutes: Int? = nil,
    createdAt: Date,
    modifiedAt: Date,
    lastAccessedAt: Date? = nil,
    previewImage: Data? = nil,
    completionPercentage: Double = 0.0
  ) {
    self.id = id
    self.displayName = displayName
    self.subject = subject
    self.estimatedMinutes = estimatedMinutes
    self.createdAt = createdAt
    self.modifiedAt = modifiedAt
    self.lastAccessedAt = lastAccessedAt
    self.previewImage = previewImage
    self.completionPercentage = completionPercentage
  }
}
