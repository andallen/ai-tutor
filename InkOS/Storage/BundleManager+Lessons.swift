//
// BundleManager+Lessons.swift
// InkOS
//
// Extension to BundleManager for lesson bundle CRUD operations.
// Follows the same patterns as notebook bundle management.
//

import Foundation

// MARK: - Lesson Operations

extension BundleManager {
  // Lists all existing lessons in the Lessons directory.
  // Returns an array of LessonMetadata for each lesson that has a valid manifest.
  // Skips lessons that don't have a manifest or have invalid manifests.
  func listLessons() async throws -> [LessonMetadata] {
    // Get the directory where lessons are stored.
    let lessonsDirectory = try await LessonStorage.lessonsDirectory()

    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(
      at: lessonsDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var lessons: [LessonMetadata] = []

    for url in contents {
      // Check if this is a directory.
      let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
      guard resourceValues.isDirectory == true else {
        continue
      }

      // Try to read the lesson manifest.
      let manifestURL = url.appendingPathComponent(LessonConstants.manifestFileName)
      guard fileManager.fileExists(atPath: manifestURL.path) else {
        continue
      }

      // Read and decode the manifest.
      do {
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LessonManifest.self, from: data)

        // Load preview image if it exists.
        let previewURL = url.appendingPathComponent(LessonConstants.previewFileName)
        let previewData: Data?
        if fileManager.fileExists(atPath: previewURL.path) {
          previewData = try? Data(contentsOf: previewURL)
        } else {
          previewData = nil
        }

        // Calculate completion percentage.
        let completionPercentage: Double
        if manifest.sectionCount > 0 {
          completionPercentage =
            Double(manifest.completedSectionCount) / Double(manifest.sectionCount)
        } else {
          completionPercentage = 0
        }

        lessons.append(
          LessonMetadata(
            id: manifest.lessonID,
            displayName: manifest.displayName,
            subject: manifest.subject,
            estimatedMinutes: manifest.estimatedMinutes,
            createdAt: manifest.createdAt,
            modifiedAt: manifest.modifiedAt,
            lastAccessedAt: manifest.lastAccessedAt,
            previewImage: previewData,
            completionPercentage: completionPercentage
          ))
      } catch {
        // Skip lessons with invalid manifests.
        continue
      }
    }

    return lessons
  }

  // Creates a new lesson bundle with the given display name and lesson content.
  // Generates a UUID for the lesson ID.
  // Creates the manifest, content, and progress files.
  // Returns the LessonMetadata for the newly created lesson.
  func createLesson(displayName: String, lesson: Lesson) async throws -> LessonMetadata {
    let lessonID = lesson.lessonId
    let lessonsDirectory = try await LessonStorage.lessonsDirectory()

    // Create the lesson bundle directory.
    let lessonURL = lessonsDirectory.appendingPathComponent(lessonID, isDirectory: true)
    try FileManager.default.createDirectory(
      at: lessonURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    // Create the assets subdirectory.
    let assetsURL = lessonURL.appendingPathComponent(
      LessonConstants.assetsDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(
      at: assetsURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    // Create and write the lesson manifest.
    let manifest = LessonManifest(
      lessonID: lessonID,
      displayName: displayName,
      subject: lesson.metadata.subject,
      estimatedMinutes: lesson.metadata.estimatedMinutes,
      sourceType: lesson.metadata.sourceType,
      sourceReference: lesson.metadata.sourceReference,
      sectionCount: lesson.sections.count
    )

    let manifestURL = lessonURL.appendingPathComponent(LessonConstants.manifestFileName)
    try writeLessonManifest(manifest, to: manifestURL)

    // Write the lesson content.
    let contentURL = lessonURL.appendingPathComponent(LessonConstants.contentFileName)
    try writeLessonContent(lesson, to: contentURL)

    // Create initial empty progress.
    let progress = LessonProgress(lessonID: lessonID)
    let progressURL = lessonURL.appendingPathComponent(LessonConstants.progressFileName)
    try writeLessonProgress(progress, to: progressURL)

    return LessonMetadata(
      id: lessonID,
      displayName: displayName,
      subject: lesson.metadata.subject,
      estimatedMinutes: lesson.metadata.estimatedMinutes,
      createdAt: manifest.createdAt,
      modifiedAt: manifest.modifiedAt,
      lastAccessedAt: manifest.lastAccessedAt,
      previewImage: nil,
      completionPercentage: 0
    )
  }

  // Renames a lesson by updating the display name in its manifest.
  // Also updates the modifiedAt timestamp.
  func renameLesson(lessonID: String, newDisplayName: String) async throws {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let fileManager = FileManager.default
    let manifestURL = lessonURL.appendingPathComponent(LessonConstants.manifestFileName)
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw LessonBundleError.manifestNotFound(lessonID: lessonID)
    }

    let data = try Data(contentsOf: manifestURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var manifest = try decoder.decode(LessonManifest.self, from: data)
    manifest.displayName = newDisplayName
    manifest.modifiedAt = Date()

    try writeLessonManifest(manifest, to: manifestURL)
  }

  // Deletes a lesson bundle and all its contents.
  func deleteLesson(lessonID: String) async throws {
    guard !lessonID.isEmpty else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    // Delete the entire lesson bundle directory.
    try FileManager.default.removeItem(at: lessonURL)
  }

  // Loads a lesson's content from its bundle.
  // Validates that the bundle exists, the manifest can be decoded,
  // and the version is supported.
  func loadLesson(lessonID: String) async throws -> Lesson {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let fileManager = FileManager.default

    // Validate manifest exists and is supported.
    let manifestURL = lessonURL.appendingPathComponent(LessonConstants.manifestFileName)
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw LessonBundleError.manifestNotFound(lessonID: lessonID)
    }

    let manifestData = try Data(contentsOf: manifestURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let manifest: LessonManifest
    do {
      manifest = try decoder.decode(LessonManifest.self, from: manifestData)
    } catch {
      throw LessonBundleError.manifestDecodingFailed(lessonID: lessonID)
    }

    guard LessonManifestVersion.supported.contains(manifest.version) else {
      throw LessonBundleError.unsupportedManifestVersion(
        lessonID: lessonID, version: manifest.version)
    }

    // Update last accessed timestamp.
    var updatedManifest = manifest
    updatedManifest.lastAccessedAt = Date()
    do {
      try writeLessonManifest(updatedManifest, to: manifestURL)
    } catch {
      // Silently fail timestamp update but continue loading.
    }

    // Load the lesson content.
    let contentURL = lessonURL.appendingPathComponent(LessonConstants.contentFileName)
    guard fileManager.fileExists(atPath: contentURL.path) else {
      throw LessonBundleError.contentNotFound(lessonID: lessonID)
    }

    let contentData = try Data(contentsOf: contentURL)
    let lesson: Lesson
    do {
      lesson = try decoder.decode(Lesson.self, from: contentData)
    } catch {
      throw LessonBundleError.contentDecodingFailed(lessonID: lessonID)
    }

    return lesson
  }

  // Saves updated lesson content to a bundle.
  // Updates the manifest's modifiedAt timestamp.
  func saveLesson(lessonID: String, lesson: Lesson) async throws {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let fileManager = FileManager.default

    // Update and save the manifest.
    let manifestURL = lessonURL.appendingPathComponent(LessonConstants.manifestFileName)
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw LessonBundleError.manifestNotFound(lessonID: lessonID)
    }

    let manifestData = try Data(contentsOf: manifestURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var manifest = try decoder.decode(LessonManifest.self, from: manifestData)
    manifest.modifiedAt = Date()
    manifest.sectionCount = lesson.sections.count

    try writeLessonManifest(manifest, to: manifestURL)

    // Save the lesson content.
    let contentURL = lessonURL.appendingPathComponent(LessonConstants.contentFileName)
    try writeLessonContent(lesson, to: contentURL)
  }

  // Loads the progress for a lesson.
  // Returns empty progress if the file doesn't exist.
  func loadLessonProgress(lessonID: String) async throws -> LessonProgress {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let progressURL = lessonURL.appendingPathComponent(LessonConstants.progressFileName)
    let fileManager = FileManager.default

    // Return empty progress if file doesn't exist.
    guard fileManager.fileExists(atPath: progressURL.path) else {
      return LessonProgress(lessonID: lessonID)
    }

    let data = try Data(contentsOf: progressURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      return try decoder.decode(LessonProgress.self, from: data)
    } catch {
      throw LessonBundleError.progressDecodingFailed(lessonID: lessonID)
    }
  }

  // Saves progress for a lesson.
  // Also updates the manifest's completed section count.
  func saveLessonProgress(lessonID: String, progress: LessonProgress) async throws {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let fileManager = FileManager.default

    // Save the progress file.
    let progressURL = lessonURL.appendingPathComponent(LessonConstants.progressFileName)
    try writeLessonProgress(progress, to: progressURL)

    // Update the manifest's completed section count.
    let manifestURL = lessonURL.appendingPathComponent(LessonConstants.manifestFileName)
    if fileManager.fileExists(atPath: manifestURL.path) {
      let manifestData = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      var manifest = try decoder.decode(LessonManifest.self, from: manifestData)
      manifest.completedSectionCount = progress.completedCount
      manifest.modifiedAt = Date()
      try writeLessonManifest(manifest, to: manifestURL)
    }
  }

  // Saves a thumbnail image for a lesson.
  func saveLessonThumbnail(lessonID: String, imageData: Data) async throws {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let thumbnailURL = lessonURL.appendingPathComponent(LessonConstants.previewFileName)
    try imageData.write(to: thumbnailURL, options: [.atomic])
  }

  // Saves an asset (generated image) for a lesson.
  // Returns the URL where the asset was saved.
  func saveLessonAsset(lessonID: String, assetID: String, data: Data) async throws -> URL {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let assetsURL = lessonURL.appendingPathComponent(
      LessonConstants.assetsDirectoryName, isDirectory: true)

    // Ensure assets directory exists.
    if !FileManager.default.fileExists(atPath: assetsURL.path) {
      try FileManager.default.createDirectory(
        at: assetsURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    let assetURL = assetsURL.appendingPathComponent("\(assetID).png")
    try data.write(to: assetURL, options: [.atomic])
    return assetURL
  }

  // Loads an asset from a lesson bundle.
  func loadLessonAsset(lessonID: String, assetID: String) async throws -> Data? {
    guard let lessonURL = try findLessonURL(lessonID: lessonID) else {
      throw LessonBundleError.lessonNotFound(lessonID: lessonID)
    }

    let assetURL = lessonURL
      .appendingPathComponent(LessonConstants.assetsDirectoryName, isDirectory: true)
      .appendingPathComponent("\(assetID).png")

    guard FileManager.default.fileExists(atPath: assetURL.path) else {
      return nil
    }

    return try Data(contentsOf: assetURL)
  }

  // MARK: - Private Helpers

  // Finds the lesson bundle URL for a lesson ID.
  // Returns nil if the lesson is not found.
  private func findLessonURL(lessonID: String) throws -> URL? {
    let lessonsDirectory = try LessonStorage.lessonsDirectorySync()
    let fileManager = FileManager.default

    let lessonURL = lessonsDirectory.appendingPathComponent(lessonID, isDirectory: true)
    let manifestURL = lessonURL.appendingPathComponent(LessonConstants.manifestFileName)

    if fileManager.fileExists(atPath: manifestURL.path) {
      return lessonURL
    }

    return nil
  }

  // Writes a LessonManifest to disk using atomic write.
  private func writeLessonManifest(_ manifest: LessonManifest, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(manifest)

    let tempURL = url.deletingLastPathComponent().appendingPathComponent(
      ".\(url.lastPathComponent).tmp")
    try data.write(to: tempURL, options: [.atomic])

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      try fileManager.removeItem(at: url)
    }
    try fileManager.moveItem(at: tempURL, to: url)
  }

  // Writes lesson content to disk using atomic write.
  private func writeLessonContent(_ lesson: Lesson, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(lesson)

    let tempURL = url.deletingLastPathComponent().appendingPathComponent(
      ".\(url.lastPathComponent).tmp")
    try data.write(to: tempURL, options: [.atomic])

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      try fileManager.removeItem(at: url)
    }
    try fileManager.moveItem(at: tempURL, to: url)
  }

  // Writes lesson progress to disk using atomic write.
  private func writeLessonProgress(_ progress: LessonProgress, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(progress)

    let tempURL = url.deletingLastPathComponent().appendingPathComponent(
      ".\(url.lastPathComponent).tmp")
    try data.write(to: tempURL, options: [.atomic])

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: url.path) {
      try fileManager.removeItem(at: url)
    }
    try fileManager.moveItem(at: tempURL, to: url)
  }
}
