//
// LessonGenerator.swift
// InkOS
//
// Orchestrates the full lesson generation workflow.
// Coordinates between generation service, content extraction, and storage.
//

import Foundation

// MARK: - Generation State

// Represents the current state of lesson generation.
enum LessonGenerationState: Sendable, Equatable {
  case idle
  case extractingPDF
  case generating(progress: Int)
  case saving
  case completed(lessonID: String)
  case failed(error: String)
}

// MARK: - Generation Request

// Parameters for generating a lesson.
struct LessonGenerationRequest: Sendable {
  // Topic or prompt for the lesson.
  let prompt: String

  // Display name for the lesson (defaults to prompt if not provided).
  let displayName: String?

  // URL to PDF file for hybrid lessons (optional).
  let pdfURL: URL?

  // Estimated time for the lesson in minutes.
  let estimatedMinutes: Int

  // Folder ID to place the lesson in (optional).
  let folderID: String?

  init(
    prompt: String,
    displayName: String? = nil,
    pdfURL: URL? = nil,
    estimatedMinutes: Int = 15,
    folderID: String? = nil
  ) {
    self.prompt = prompt
    self.displayName = displayName
    self.pdfURL = pdfURL
    self.estimatedMinutes = estimatedMinutes
    self.folderID = folderID
  }
}

// MARK: - Lesson Generator Protocol

// Protocol for lesson generation orchestration.
protocol LessonGeneratorProtocol: Actor {
  // Current generation state.
  var state: LessonGenerationState { get }

  // Generates a lesson from the given request.
  // Returns the metadata for the created lesson.
  func generate(request: LessonGenerationRequest) async throws -> LessonMetadata

  // Cancels any ongoing generation.
  func cancel()
}

// MARK: - Lesson Generator

// Actor that orchestrates the full lesson generation workflow.
// Coordinates PDF extraction, AI generation, and storage.
actor LessonGenerator: LessonGeneratorProtocol {

  // Current generation state.
  private(set) var state: LessonGenerationState = .idle

  // Service for AI lesson generation.
  private let generationService: any LessonGenerationServiceProtocol

  // Content extractor for PDF text extraction.
  private let contentExtractor: ContentExtractor

  // Bundle manager for storage operations.
  private let bundleManager: BundleManager

  // Current generation task (for cancellation).
  private var currentTask: Task<LessonMetadata, Error>?

  // Callback for state changes.
  private var onStateChange: (@Sendable (LessonGenerationState) -> Void)?

  // Creates a lesson generator with the specified dependencies.
  init(
    generationService: any LessonGenerationServiceProtocol,
    contentExtractor: ContentExtractor = ContentExtractor(),
    bundleManager: BundleManager = .shared
  ) {
    self.generationService = generationService
    self.contentExtractor = contentExtractor
    self.bundleManager = bundleManager
  }

  // Sets a callback for state changes.
  func setOnStateChange(_ callback: @escaping @Sendable (LessonGenerationState) -> Void) {
    self.onStateChange = callback
  }

  // Generates a lesson from the given request.
  func generate(request: LessonGenerationRequest) async throws -> LessonMetadata {
    // Cancel any existing generation.
    currentTask?.cancel()

    // Update state.
    updateState(.idle)

    // Create the generation task.
    let task = Task<LessonMetadata, Error> {
      try await performGeneration(request: request)
    }

    currentTask = task

    do {
      let result = try await task.value
      return result
    } catch {
      if Task.isCancelled {
        updateState(.failed(error: "Generation cancelled"))
        throw LessonGenerationError.generationCancelled
      }
      updateState(.failed(error: error.localizedDescription))
      throw error
    }
  }

  // Cancels any ongoing generation.
  func cancel() {
    currentTask?.cancel()
    currentTask = nil
    updateState(.idle)
  }

  // MARK: - Private Methods

  // Performs the actual generation workflow.
  private func performGeneration(request: LessonGenerationRequest) async throws -> LessonMetadata {
    // Step 1: Extract PDF text if provided.
    var sourceText: String?

    if let pdfURL = request.pdfURL {
      updateState(.extractingPDF)

      let extractedContent = try await contentExtractor.extractFromPDF(
        url: pdfURL,
        documentID: UUID().uuidString,
        displayName: request.displayName ?? request.prompt,
        modifiedAt: Date()
      )

      if !extractedContent.text.isEmpty {
        sourceText = extractedContent.text
      }
    }

    // Check for cancellation.
    try Task.checkCancellation()

    // Step 2: Generate the lesson via AI.
    updateState(.generating(progress: 0))

    let lesson: Lesson

    if let sourceText = sourceText {
      lesson = try await generationService.generateLessonFromPDF(
        prompt: request.prompt,
        pdfText: sourceText,
        estimatedMinutes: request.estimatedMinutes,
        onProgress: { progress in
          Task {
            await self.updateState(.generating(progress: progress))
          }
        }
      )
    } else {
      lesson = try await generationService.generateLesson(
        prompt: request.prompt,
        estimatedMinutes: request.estimatedMinutes,
        onProgress: { progress in
          Task {
            await self.updateState(.generating(progress: progress))
          }
        }
      )
    }

    // Check for cancellation.
    try Task.checkCancellation()

    // Step 3: Save the lesson to storage.
    updateState(.saving)

    let displayName = request.displayName ?? lesson.title
    let metadata = try await bundleManager.createLesson(
      displayName: displayName,
      lesson: lesson
    )

    // Step 4: Update state to completed.
    updateState(.completed(lessonID: metadata.id))

    return metadata
  }

  // Updates the current state and notifies callback.
  private func updateState(_ newState: LessonGenerationState) {
    state = newState
    onStateChange?(newState)
  }
}

// MARK: - Convenience Factory

extension LessonGenerator {
  // Creates a lesson generator with default Firebase configuration.
  // projectID: Firebase project ID for Cloud Functions.
  static func createDefault(projectID: String) -> LessonGenerator {
    let generationService = LessonGenerationService(projectID: projectID)
    return LessonGenerator(generationService: generationService)
  }
}
