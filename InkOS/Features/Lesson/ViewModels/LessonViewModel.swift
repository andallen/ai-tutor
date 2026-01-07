//
// LessonViewModel.swift
// InkOS
//
// Manages lesson viewing state including progress tracking,
// section completion, and answer checking.
//

import Combine
import Foundation
import SwiftUI

// Represents the state of a single question answer.
enum AnswerState: Equatable {
  case unanswered
  case selected(String)
  case checking
  case correct(feedback: String)
  case incorrect(feedback: String)
  case revealed
}

// Observable state for lesson viewing.
@MainActor
final class LessonViewModel: ObservableObject {
  // The lesson being viewed.
  @Published private(set) var lesson: Lesson?

  // The lesson metadata from the manifest.
  @Published private(set) var metadata: LessonMetadata?

  // Progress tracking for each section.
  @Published private(set) var progress: LessonProgress?

  // Answer states for question sections keyed by section ID.
  @Published var answerStates: [String: AnswerState] = [:]

  // Selected answers for multiple choice questions keyed by section ID.
  @Published var selectedAnswers: [String: String] = [:]

  // Loading state for the lesson.
  @Published private(set) var isLoading = false

  // Error message if loading failed.
  @Published private(set) var errorMessage: String?

  // The bundle manager for storage operations.
  private let bundleManager: BundleManager

  // The answer comparison service for checking answers.
  private let answerComparisonService: any AnswerComparisonServiceProtocol

  // The lesson ID being viewed.
  private var lessonID: String?

  init(
    bundleManager: BundleManager = .shared,
    answerComparisonService: (any AnswerComparisonServiceProtocol)? = nil
  ) {
    self.bundleManager = bundleManager
    // Use mock service if none provided (for previews and testing).
    self.answerComparisonService = answerComparisonService ?? MockAnswerComparisonService()
  }

  // Computed property for completion percentage.
  var completionPercentage: Double {
    guard let lesson else { return 0 }
    let totalSections = lesson.sections.count
    guard totalSections > 0 else { return 0 }

    let completedCount = lesson.sections.filter { section in
      isSectionCompleted(section.id)
    }.count

    return Double(completedCount) / Double(totalSections)
  }

  // Number of completed sections.
  var completedSectionCount: Int {
    guard let lesson else { return 0 }
    return lesson.sections.filter { isSectionCompleted($0.id) }.count
  }

  // Total number of sections.
  var totalSectionCount: Int {
    lesson?.sections.count ?? 0
  }

  // Loads a lesson by ID.
  func loadLesson(lessonID: String) async {
    self.lessonID = lessonID
    isLoading = true
    errorMessage = nil

    do {
      // Load the lesson content.
      let loadedLesson = try await bundleManager.loadLesson(lessonID: lessonID)
      self.lesson = loadedLesson

      // Load existing progress or create new.
      if let existingProgress = try? await bundleManager.loadLessonProgress(lessonID: lessonID) {
        self.progress = existingProgress
        // Restore answer states from progress.
        restoreAnswerStates(from: existingProgress)
      } else {
        self.progress = LessonProgress(lessonID: lessonID)
      }

      // Update last accessed time.
      var updatedProgress = self.progress ?? LessonProgress(lessonID: lessonID)
      updatedProgress.lastOpenedAt = Date()
      self.progress = updatedProgress
      try? await bundleManager.saveLessonProgress(lessonID: lessonID, progress: updatedProgress)

      isLoading = false
    } catch {
      errorMessage = error.localizedDescription
      isLoading = false
    }
  }

  // Checks if a section is completed.
  func isSectionCompleted(_ sectionID: String) -> Bool {
    progress?.sections[sectionID]?.completed ?? false
  }

  // Checks if a section is unlocked (previous section completed or first section).
  func isSectionUnlocked(_ sectionID: String) -> Bool {
    guard let lesson else { return false }
    guard let index = lesson.sections.firstIndex(where: { $0.id == sectionID }) else {
      return false
    }

    // First section is always unlocked.
    if index == 0 { return true }

    // Check if previous section is completed.
    let previousSection = lesson.sections[index - 1]
    return isSectionCompleted(previousSection.id)
  }

  // Marks a section as completed.
  func markSectionCompleted(_ sectionID: String) async {
    guard let lessonID else { return }

    var updatedProgress = progress ?? LessonProgress(lessonID: lessonID)
    var sectionProgress = updatedProgress.sections[sectionID] ?? SectionProgress(sectionID: sectionID)
    sectionProgress.completed = true
    sectionProgress.completedAt = Date()
    updatedProgress.sections[sectionID] = sectionProgress
    progress = updatedProgress

    // Save progress.
    try? await bundleManager.saveLessonProgress(lessonID: lessonID, progress: updatedProgress)
  }

  // Marks content/visual sections as viewed when scrolled into view.
  func markSectionViewed(_ sectionID: String) async {
    guard let lesson else { return }
    guard let section = lesson.sections.first(where: { $0.id == sectionID }) else { return }

    // Only auto-complete content, visual, and summary sections.
    switch section {
    case .content, .visual, .summary:
      if !isSectionCompleted(sectionID) {
        await markSectionCompleted(sectionID)
      }
    case .question:
      // Questions require explicit answer check.
      break
    }
  }

  // Selects an answer for a multiple choice question.
  func selectAnswer(_ answer: String, for sectionID: String) {
    selectedAnswers[sectionID] = answer
    answerStates[sectionID] = .selected(answer)
  }

  // Checks the selected answer for a question section.
  func checkAnswer(for sectionID: String) async {
    guard let lesson else { return }
    guard let section = lesson.sections.first(where: { $0.id == sectionID }) else { return }

    guard case .question(let questionSection) = section else { return }

    // Get the selected answer.
    guard let selectedAnswer = selectedAnswers[sectionID] else { return }

    answerStates[sectionID] = .checking

    do {
      let result = try await answerComparisonService.compareAnswer(
        userAnswer: selectedAnswer,
        correctAnswer: questionSection.answer,
        questionType: questionSection.questionType,
        questionPrompt: questionSection.prompt,
        explanation: questionSection.explanation
      )

      if result.isCorrect {
        answerStates[sectionID] = .correct(feedback: result.feedback)
      } else {
        answerStates[sectionID] = .incorrect(feedback: result.feedback)
      }

      // Save the answer to progress.
      await saveAnswerToProgress(
        sectionID: sectionID,
        answer: selectedAnswer,
        feedback: result.feedback,
        isCorrect: result.isCorrect
      )

      // Mark section as completed (regardless of correctness).
      await markSectionCompleted(sectionID)
    } catch {
      // On error, show a generic message.
      answerStates[sectionID] = .incorrect(feedback: "Unable to check answer. Please try again.")
    }
  }

  // Reveals the correct answer for a question.
  func revealAnswer(for sectionID: String) {
    answerStates[sectionID] = .revealed
  }

  // Gets the correct answer for a question section.
  func correctAnswer(for sectionID: String) -> String? {
    guard let lesson else { return nil }
    guard let section = lesson.sections.first(where: { $0.id == sectionID }) else { return nil }

    guard case .question(let questionSection) = section else { return nil }
    return questionSection.answer
  }

  // MARK: - Private Methods

  // Saves an answer to progress.
  private func saveAnswerToProgress(
    sectionID: String,
    answer: String,
    feedback: String,
    isCorrect: Bool
  ) async {
    guard let lessonID else { return }

    var updatedProgress = progress ?? LessonProgress(lessonID: lessonID)
    var sectionProgress = updatedProgress.sections[sectionID] ?? SectionProgress(sectionID: sectionID)
    sectionProgress.userAnswer = answer
    sectionProgress.feedback = feedback
    sectionProgress.wasCorrect = isCorrect
    updatedProgress.sections[sectionID] = sectionProgress
    progress = updatedProgress

    try? await bundleManager.saveLessonProgress(lessonID: lessonID, progress: updatedProgress)
  }

  // Restores answer states from saved progress.
  private func restoreAnswerStates(from progress: LessonProgress) {
    for (sectionID, sectionProgress) in progress.sections {
      if let answer = sectionProgress.userAnswer {
        selectedAnswers[sectionID] = answer

        if let wasCorrect = sectionProgress.wasCorrect, let feedback = sectionProgress.feedback {
          if wasCorrect {
            answerStates[sectionID] = .correct(feedback: feedback)
          } else {
            answerStates[sectionID] = .incorrect(feedback: feedback)
          }
        } else {
          answerStates[sectionID] = .selected(answer)
        }
      }
    }
  }
}
