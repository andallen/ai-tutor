//
// LessonStorage.swift
// InkOS
//
// Sets up the directory where lesson bundles are stored on disk.
// Creates the parent folder inside the app's Documents directory if it doesn't exist.
//

import Foundation

// Manages the directory structure for lesson bundle storage.
enum LessonStorage {
  // The name of the parent folder where all lesson bundles are stored.
  private static let lessonsFolderName = "Lessons"

  // Returns the URL to the folder where lesson bundles are stored.
  // Creates the folder if it doesn't exist.
  // Throws if the Documents directory cannot be accessed or the folder cannot be created.
  static func lessonsDirectory() async throws -> URL {
    // Get the app's Documents directory.
    let documentsURL = try FileManager.default.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    // Build the path to the Lessons folder.
    let lessonsURL = documentsURL.appendingPathComponent(lessonsFolderName, isDirectory: true)

    // Check if the directory already exists before creating it.
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: lessonsURL.path, isDirectory: &isDirectory)

    // Only create the directory if it doesn't exist or isn't a directory.
    if !exists || !isDirectory.boolValue {
      try FileManager.default.createDirectory(
        at: lessonsURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    return lessonsURL
  }

  // Synchronous version of lessonsDirectory for use in non-async contexts.
  // Returns the URL to the folder where lesson bundles are stored without creating it.
  // Throws if the Documents directory cannot be accessed.
  static func lessonsDirectorySync() throws -> URL {
    let documentsURL = try FileManager.default.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )
    return documentsURL.appendingPathComponent(lessonsFolderName, isDirectory: true)
  }

  // Returns the URL for a specific lesson bundle directory.
  // Does not check if the directory exists.
  static func lessonDirectory(lessonID: String) async throws -> URL {
    let lessonsURL = try await lessonsDirectory()
    return lessonsURL.appendingPathComponent(lessonID, isDirectory: true)
  }

  // Returns the URL for the lesson manifest file within a lesson bundle.
  static func manifestURL(lessonID: String) async throws -> URL {
    let lessonDir = try await lessonDirectory(lessonID: lessonID)
    return lessonDir.appendingPathComponent(LessonConstants.manifestFileName)
  }

  // Returns the URL for the lesson content file within a lesson bundle.
  static func contentURL(lessonID: String) async throws -> URL {
    let lessonDir = try await lessonDirectory(lessonID: lessonID)
    return lessonDir.appendingPathComponent(LessonConstants.contentFileName)
  }

  // Returns the URL for the lesson progress file within a lesson bundle.
  static func progressURL(lessonID: String) async throws -> URL {
    let lessonDir = try await lessonDirectory(lessonID: lessonID)
    return lessonDir.appendingPathComponent(LessonConstants.progressFileName)
  }

  // Returns the URL for the lesson thumbnail image within a lesson bundle.
  static func thumbnailURL(lessonID: String) async throws -> URL {
    let lessonDir = try await lessonDirectory(lessonID: lessonID)
    return lessonDir.appendingPathComponent(LessonConstants.previewFileName)
  }

  // Returns the URL for the assets directory within a lesson bundle.
  static func assetsDirectory(lessonID: String) async throws -> URL {
    let lessonDir = try await lessonDirectory(lessonID: lessonID)
    return lessonDir.appendingPathComponent(LessonConstants.assetsDirectoryName, isDirectory: true)
  }
}
