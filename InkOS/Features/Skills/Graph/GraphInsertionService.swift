// GraphInsertionService.swift
// Implementation of the graph insertion service that inserts graph images into notes.
// Uses EditorViewModel's image insertion capability.
// Stores GraphSpecification JSON in placeholder userData for future editing.

import Foundation
import UIKit

// MARK: - EditorImageInsertionCapable Protocol

// Protocol defining the image insertion capability required from EditorViewModel.
// This abstraction allows the service to work with mocks in tests.
@MainActor
protocol EditorImageInsertionCapable: AnyObject {
  // Inserts an image at the specified position.
  // Returns the placeholder ID for the inserted image.
  func insertImage(
    _ image: UIImage,
    at position: CGPoint,
    size: CGSize?,
    userData: [String: Any]?
  ) throws -> String

  // Updates an existing image placeholder.
  func updateImagePlaceholder(
    id: String,
    newImage: UIImage,
    userData: [String: Any]?
  ) throws

  // Removes an image placeholder.
  func removeImagePlaceholder(id: String) throws

  // Retrieves userData from a placeholder.
  func getUserData(forPlaceholderID id: String) -> [String: Any]?

  // Lists all placeholder IDs of a given type.
  func listPlaceholders(withTypeIdentifier typeIdentifier: String) -> [String]

  // Whether the editor is available for modifications.
  var isEditorAvailable: Bool { get }

  // The current notebook ID (for userData storage).
  var currentNotebookID: UUID? { get }
}

// MARK: - GraphInsertionService

// Actor that inserts graph images into notes.
// Thread-safe with @MainActor requirements for editor interaction.
actor GraphInsertionService: GraphInsertionServiceProtocol {
  // Tracks active insertions for cancellation support.
  private var activeInsertions: Set<String> = []

  // MARK: - Insert

  @MainActor
  func insert(
    _ request: GraphInsertionRequest,
    into editorViewModel: EditorViewModel
  ) async throws -> GraphInsertionResult {
    // Validate editor is available.
    guard let editor = editorViewModel as? EditorImageInsertionCapable,
      editor.isEditorAvailable
    else {
      throw GraphInsertionError.editorNotAvailable
    }

    // Validate image.
    try validateImage(request.image)

    // Validate position.
    let validatedPosition = validatePosition(request.position)

    // Generate placeholder ID if not provided.
    let placeholderID =
      request.insertionID ?? "\(GraphInsertionConstants.placeholderIDPrefix)\(UUID().uuidString)"

    // Create userData with specification.
    let userData = try createUserData(
      specification: request.specification,
      notebookID: editor.currentNotebookID
    )

    // Determine display size.
    let displaySize = request.displaySize ?? CGSize(
      width: GraphInsertionConstants.defaultDisplayWidth,
      height: GraphInsertionConstants.defaultDisplayHeight
    )

    // Insert the image.
    do {
      let insertedID = try editor.insertImage(
        request.image,
        at: validatedPosition,
        size: displaySize,
        userData: userData
      )

      return GraphInsertionResult.success(
        placeholderID: insertedID,
        position: validatedPosition,
        size: displaySize
      )
    } catch {
      return GraphInsertionResult.failure(
        placeholderID: placeholderID,
        error: error.localizedDescription
      )
    }
  }

  // MARK: - Update

  @MainActor
  func update(
    placeholderID: String,
    newImage: UIImage,
    newSpecification: GraphSpecification,
    in editorViewModel: EditorViewModel
  ) async throws -> GraphInsertionResult {
    // Validate editor is available.
    guard let editor = editorViewModel as? EditorImageInsertionCapable,
      editor.isEditorAvailable
    else {
      throw GraphInsertionError.editorNotAvailable
    }

    // Validate image.
    try validateImage(newImage)

    // Verify placeholder exists.
    guard editor.getUserData(forPlaceholderID: placeholderID) != nil else {
      throw GraphInsertionError.placeholderNotFound(placeholderID: placeholderID)
    }

    // Create new userData.
    let userData = try createUserData(
      specification: newSpecification,
      notebookID: editor.currentNotebookID
    )

    // Update the placeholder.
    do {
      try editor.updateImagePlaceholder(
        id: placeholderID,
        newImage: newImage,
        userData: userData
      )

      // Return success with previous position (unchanged).
      return GraphInsertionResult.success(
        placeholderID: placeholderID,
        position: .zero,  // Position not available from update.
        size: CGSize(width: newImage.size.width, height: newImage.size.height)
      )
    } catch {
      return GraphInsertionResult.failure(
        placeholderID: placeholderID,
        error: error.localizedDescription
      )
    }
  }

  // MARK: - Remove

  @MainActor
  func remove(
    placeholderID: String,
    from editorViewModel: EditorViewModel
  ) async throws -> Bool {
    // Validate editor is available.
    guard let editor = editorViewModel as? EditorImageInsertionCapable,
      editor.isEditorAvailable
    else {
      throw GraphInsertionError.editorNotAvailable
    }

    // Verify placeholder exists.
    guard editor.getUserData(forPlaceholderID: placeholderID) != nil else {
      return false
    }

    // Remove the placeholder.
    do {
      try editor.removeImagePlaceholder(id: placeholderID)
      return true
    } catch {
      return false
    }
  }

  // MARK: - Get Specification

  @MainActor
  func getSpecification(
    forPlaceholderID placeholderID: String,
    in editorViewModel: EditorViewModel
  ) async throws -> GraphSpecification? {
    // Validate editor is available.
    guard let editor = editorViewModel as? EditorImageInsertionCapable,
      editor.isEditorAvailable
    else {
      throw GraphInsertionError.editorNotAvailable
    }

    // Get userData from placeholder.
    guard let userData = editor.getUserData(forPlaceholderID: placeholderID) else {
      return nil
    }

    // Extract specification JSON.
    guard let jsonString = userData[GraphInsertionConstants.userDataKey] as? String else {
      return nil
    }

    // Decode and return specification.
    guard let data = jsonString.data(using: .utf8) else {
      throw GraphInsertionError.deserializationFailed(reason: "Invalid UTF-8 data")
    }

    do {
      let placeholderData = try JSONDecoder().decode(GraphPlaceholderUserData.self, from: data)
      return try placeholderData.getSpecification()
    } catch {
      throw GraphInsertionError.deserializationFailed(reason: error.localizedDescription)
    }
  }

  // MARK: - List Placeholders

  @MainActor
  func listGraphPlaceholders(
    in editorViewModel: EditorViewModel
  ) async -> [String] {
    // Validate editor is available.
    guard let editor = editorViewModel as? EditorImageInsertionCapable,
      editor.isEditorAvailable
    else {
      return []
    }

    return editor.listPlaceholders(withTypeIdentifier: GraphPlaceholderUserData.typeIdentifier)
  }

  // MARK: - Validation Helpers

  // Nonisolated helpers for pure computation (no actor state access).
  nonisolated private func validateImage(_ image: UIImage) throws {
    // Check for zero dimensions.
    if image.size.width <= 0 || image.size.height <= 0 {
      throw GraphInsertionError.invalidImage(reason: "Image has zero dimensions")
    }

    // Check for maximum dimensions.
    if image.size.width > GraphInsertionConstants.maxImageDimension
      || image.size.height > GraphInsertionConstants.maxImageDimension
    {
      throw GraphInsertionError.invalidImage(
        reason:
          "Image exceeds maximum dimension of \(GraphInsertionConstants.maxImageDimension)"
      )
    }
  }

  nonisolated private func validatePosition(_ position: CGPoint) -> CGPoint {
    // Clamp negative positions to minimum padding.
    var validPosition = position
    if validPosition.x < GraphInsertionConstants.minimumEdgePadding {
      validPosition.x = GraphInsertionConstants.minimumEdgePadding
    }
    if validPosition.y < GraphInsertionConstants.minimumEdgePadding {
      validPosition.y = GraphInsertionConstants.minimumEdgePadding
    }
    return validPosition
  }

  // MARK: - UserData Helpers

  nonisolated private func createUserData(
    specification: GraphSpecification,
    notebookID: UUID?
  ) throws -> [String: Any] {
    // Create placeholder user data.
    let placeholderData = try GraphPlaceholderUserData(
      specification: specification,
      notebookID: notebookID,
      displayPreferences: .default
    )

    // Encode to JSON string.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(placeholderData)
    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw GraphInsertionError.serializationFailed(reason: "UTF-8 encoding failed")
    }

    return [
      GraphInsertionConstants.userDataKey: jsonString,
      "typeIdentifier": GraphPlaceholderUserData.typeIdentifier,
    ]
  }
}
