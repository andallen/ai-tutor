// GraphInsertionServiceContract.swift
// Defines the API contract for inserting graph images into notes.
// Takes a UIImage and position, uses EditorViewModel's addImage capability.
// Stores GraphSpecification JSON in placeholder userData for future "edit graph".
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation
import UIKit

// MARK: - API Contract

// MARK: - GraphInsertionRequest Struct

// Contains all information needed to insert a graph into a note.
struct GraphInsertionRequest: Sendable {
  // The rendered graph image to insert.
  let image: UIImage

  // Position in the note where the graph should be inserted (in editor coordinates).
  let position: CGPoint

  // The original specification used to generate this graph.
  // Stored as userData for future editing capabilities.
  let specification: GraphSpecification

  // Optional unique identifier for this insertion (auto-generated if nil).
  let insertionID: String?

  // Size to display the image in the note (in points).
  // If nil, uses the image's natural size.
  let displaySize: CGSize?

  // Creates a request with required parameters and optional ID.
  init(
    image: UIImage,
    position: CGPoint,
    specification: GraphSpecification,
    insertionID: String? = nil,
    displaySize: CGSize? = nil
  ) {
    self.image = image
    self.position = position
    self.specification = specification
    self.insertionID = insertionID
    self.displaySize = displaySize
  }
}

/*
 ACCEPTANCE CRITERIA: GraphInsertionRequest

 SCENARIO: Create basic insertion request
 GIVEN: A UIImage and position
 WHEN: GraphInsertionRequest is created
 THEN: image is set
  AND: position is set
  AND: specification is set
  AND: insertionID is nil (will be auto-generated)

 SCENARIO: Create request with custom ID
 GIVEN: GraphInsertionRequest with insertionID = "graph-123"
 WHEN: Request is processed
 THEN: Inserted placeholder uses "graph-123" as identifier
  AND: ID can be used to locate graph later

 SCENARIO: Create request with display size
 GIVEN: GraphInsertionRequest with displaySize = CGSize(300, 300)
 WHEN: Request is processed
 THEN: Image is displayed at 300x300 points
  AND: Original image data is preserved
  AND: Display size differs from image pixel size

 SCENARIO: Specification is preserved
 GIVEN: GraphInsertionRequest with complex specification
 WHEN: Request is serialized or inspected
 THEN: specification contains full GraphSpecification
  AND: Can be encoded to JSON for userData
*/

// MARK: - GraphInsertionResult Struct

// Contains the result of a graph insertion operation.
struct GraphInsertionResult: Sendable, Equatable {
  // Whether the insertion succeeded.
  let success: Bool

  // Unique identifier of the inserted placeholder.
  let placeholderID: String

  // Position where the graph was actually inserted (may differ from requested).
  let actualPosition: CGPoint

  // Size of the inserted image in the note.
  let insertedSize: CGSize

  // Error message if insertion failed.
  let errorMessage: String?

  // Creates a successful result.
  static func success(
    placeholderID: String,
    position: CGPoint,
    size: CGSize
  ) -> GraphInsertionResult {
    GraphInsertionResult(
      success: true,
      placeholderID: placeholderID,
      actualPosition: position,
      insertedSize: size,
      errorMessage: nil
    )
  }

  // Creates a failed result.
  static func failure(
    placeholderID: String,
    error: String
  ) -> GraphInsertionResult {
    GraphInsertionResult(
      success: false,
      placeholderID: placeholderID,
      actualPosition: .zero,
      insertedSize: .zero,
      errorMessage: error
    )
  }
}

/*
 ACCEPTANCE CRITERIA: GraphInsertionResult

 SCENARIO: Successful insertion result
 GIVEN: Graph image inserted successfully
 WHEN: GraphInsertionResult.success is created
 THEN: success is true
  AND: placeholderID identifies the inserted element
  AND: actualPosition reflects where it was placed
  AND: insertedSize reflects display dimensions
  AND: errorMessage is nil

 SCENARIO: Failed insertion result
 GIVEN: Graph image insertion failed
 WHEN: GraphInsertionResult.failure is created
 THEN: success is false
  AND: placeholderID may be empty or partial
  AND: errorMessage describes the failure

 SCENARIO: Position adjustment
 GIVEN: Requested position outside valid area
 WHEN: System adjusts position
 THEN: actualPosition differs from requested
  AND: Graph is still inserted successfully
*/

// MARK: - GraphPlaceholderUserData Struct

// Data stored in the placeholder's userData for graph elements.
// Enables future "edit graph" functionality by preserving the specification.
struct GraphPlaceholderUserData: Sendable, Codable, Equatable {
  // Type identifier for this userData.
  static let typeIdentifier = "com.inkos.graph-placeholder"

  // Version of the userData format.
  let version: String

  // The GraphSpecification JSON as a string.
  let specificationJSON: String

  // Timestamp when the graph was inserted.
  let insertedAt: Date

  // ID of the notebook containing this graph.
  let notebookID: UUID?

  // Optional display preferences.
  let displayPreferences: GraphDisplayPreferences?

  // Creates userData from a GraphSpecification.
  init(
    specification: GraphSpecification,
    notebookID: UUID?,
    displayPreferences: GraphDisplayPreferences? = nil
  ) throws {
    self.version = "1.0"
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(specification)
    guard let json = String(data: data, encoding: .utf8) else {
      throw GraphInsertionError.serializationFailed(reason: "UTF-8 encoding failed")
    }
    self.specificationJSON = json
    self.insertedAt = Date()
    self.notebookID = notebookID
    self.displayPreferences = displayPreferences
  }

  // Retrieves the GraphSpecification from stored JSON.
  func getSpecification() throws -> GraphSpecification {
    guard let data = specificationJSON.data(using: .utf8) else {
      throw GraphInsertionError.deserializationFailed(reason: "Invalid UTF-8 data")
    }
    return try JSONDecoder().decode(GraphSpecification.self, from: data)
  }
}

/*
 ACCEPTANCE CRITERIA: GraphPlaceholderUserData

 SCENARIO: Create userData from specification
 GIVEN: A valid GraphSpecification
 WHEN: GraphPlaceholderUserData is initialized
 THEN: specificationJSON contains valid JSON
  AND: version is "1.0"
  AND: insertedAt is current time
  AND: Can be encoded and decoded

 SCENARIO: Retrieve specification from userData
 GIVEN: GraphPlaceholderUserData with stored JSON
 WHEN: getSpecification() is called
 THEN: Returns equivalent GraphSpecification
  AND: All equations, points, annotations are preserved
  AND: Viewport and interactivity settings match

 SCENARIO: Encode and decode userData
 GIVEN: GraphPlaceholderUserData instance
 WHEN: Encoded to JSON and decoded back
 THEN: All fields are preserved
  AND: specificationJSON is identical
  AND: insertedAt timestamp is preserved

 SCENARIO: Invalid specification JSON
 GIVEN: GraphPlaceholderUserData with corrupted specificationJSON
 WHEN: getSpecification() is called
 THEN: Throws GraphInsertionError.deserializationFailed
  AND: reason describes JSON parse error

 EDGE CASE: Very large specification
 GIVEN: Specification with 100 equations
 WHEN: Stored as userData
 THEN: JSON is complete but may be large
  AND: Consider compression for very large specs
*/

// MARK: - GraphDisplayPreferences Struct

// Optional preferences for how the graph is displayed in the note.
struct GraphDisplayPreferences: Sendable, Codable, Equatable {
  // Whether the graph should have a visible border.
  let showBorder: Bool

  // Corner radius for the graph display.
  let cornerRadius: CGFloat

  // Padding around the graph image.
  let padding: CGFloat

  // Whether the graph can be interactively edited.
  let allowEditing: Bool

  // Default display preferences.
  static let `default` = GraphDisplayPreferences(
    showBorder: true,
    cornerRadius: 8.0,
    padding: 4.0,
    allowEditing: true
  )
}

/*
 ACCEPTANCE CRITERIA: GraphDisplayPreferences

 SCENARIO: Default preferences
 GIVEN: GraphDisplayPreferences.default
 WHEN: Applied to inserted graph
 THEN: showBorder is true
  AND: cornerRadius is 8.0
  AND: padding is 4.0
  AND: allowEditing is true

 SCENARIO: Custom preferences
 GIVEN: Custom GraphDisplayPreferences
 WHEN: Stored in userData
 THEN: Preferences are preserved
  AND: Applied when graph is rendered in note
*/

// MARK: - GraphInsertionServiceProtocol

// Protocol for inserting graph images into notes.
// Uses actor isolation for thread-safe async operations.
protocol GraphInsertionServiceProtocol: Sendable {
  // Inserts a graph image into the current note.
  // request: Contains image, position, and specification.
  // editorViewModel: The editor to insert into.
  // Returns GraphInsertionResult indicating success or failure.
  // Throws GraphInsertionError if insertion cannot be attempted.
  @MainActor
  func insert(
    _ request: GraphInsertionRequest,
    into editorViewModel: EditorViewModel
  ) async throws -> GraphInsertionResult

  // Updates an existing graph placeholder with a new image and specification.
  // placeholderID: ID of the existing placeholder to update.
  // newImage: Updated graph image.
  // newSpecification: Updated specification.
  // editorViewModel: The editor containing the placeholder.
  // Returns GraphInsertionResult indicating success or failure.
  @MainActor
  func update(
    placeholderID: String,
    newImage: UIImage,
    newSpecification: GraphSpecification,
    in editorViewModel: EditorViewModel
  ) async throws -> GraphInsertionResult

  // Removes a graph from the note.
  // placeholderID: ID of the placeholder to remove.
  // editorViewModel: The editor containing the placeholder.
  // Returns true if removal succeeded.
  @MainActor
  func remove(
    placeholderID: String,
    from editorViewModel: EditorViewModel
  ) async throws -> Bool

  // Retrieves the specification from an existing graph placeholder.
  // placeholderID: ID of the placeholder to query.
  // editorViewModel: The editor containing the placeholder.
  // Returns the stored GraphSpecification, or nil if not found.
  @MainActor
  func getSpecification(
    forPlaceholderID placeholderID: String,
    in editorViewModel: EditorViewModel
  ) async throws -> GraphSpecification?

  // Lists all graph placeholders in the current note.
  // editorViewModel: The editor to query.
  // Returns array of placeholder IDs.
  @MainActor
  func listGraphPlaceholders(
    in editorViewModel: EditorViewModel
  ) async -> [String]
}

/*
 ACCEPTANCE CRITERIA: GraphInsertionServiceProtocol - insert()

 SCENARIO: Insert graph at specified position
 GIVEN: GraphInsertionRequest with valid image and position
 WHEN: insert(request, into: editorViewModel) is called
 THEN: Image is added to the note at position
  AND: Returns GraphInsertionResult with success = true
  AND: placeholderID is valid identifier
  AND: GraphSpecification is stored in userData

 SCENARIO: Insert graph with auto-generated ID
 GIVEN: GraphInsertionRequest with insertionID = nil
 WHEN: insert() is called
 THEN: Unique ID is auto-generated
  AND: ID follows pattern "graph-{uuid}"
  AND: placeholderID in result matches generated ID

 SCENARIO: Insert graph with custom ID
 GIVEN: GraphInsertionRequest with insertionID = "my-graph-1"
 WHEN: insert() is called
 THEN: placeholderID is "my-graph-1"
  AND: Can be used to retrieve specification later

 SCENARIO: Insert graph with display size
 GIVEN: GraphInsertionRequest with displaySize set
 WHEN: insert() is called
 THEN: Image is displayed at specified size
  AND: insertedSize in result matches displaySize

 SCENARIO: Insert when editor is nil
 GIVEN: EditorViewModel with nil editor
 WHEN: insert() is called
 THEN: Throws GraphInsertionError.editorNotAvailable

 SCENARIO: Insert stores specification for editing
 GIVEN: GraphInsertionRequest with complex specification
 WHEN: insert() is called and graph is inserted
 THEN: userData contains GraphPlaceholderUserData
  AND: specificationJSON is valid JSON
  AND: getSpecification() returns equivalent spec

 EDGE CASE: Duplicate insertion ID
 GIVEN: insert() called twice with same insertionID
 WHEN: Second insert executes
 THEN: First placeholder is replaced or error thrown
  AND: Behavior is deterministic

 EDGE CASE: Position outside document bounds
 GIVEN: Position at CGPoint(x: -100, y: -100)
 WHEN: insert() is called
 THEN: Position is clamped to valid area
  AND: actualPosition in result shows adjusted position

 EDGE CASE: Very large image
 GIVEN: UIImage of size 4000x4000 pixels
 WHEN: insert() is called
 THEN: Image may be scaled down for display
  AND: Original quality preserved in storage
  AND: displaySize limits visible dimensions

 EDGE CASE: Nil or empty image
 GIVEN: UIImage with zero dimensions
 WHEN: insert() is called
 THEN: Throws GraphInsertionError.invalidImage
  AND: reason indicates empty image

 EDGE CASE: Insertion during save operation
 GIVEN: Editor is performing auto-save
 WHEN: insert() is called
 THEN: Insertion waits or is queued
  AND: No data corruption occurs
*/

/*
 ACCEPTANCE CRITERIA: GraphInsertionServiceProtocol - update()

 SCENARIO: Update existing graph
 GIVEN: Existing placeholder with ID "graph-123"
 WHEN: update(placeholderID: "graph-123", newImage:, newSpecification:) is called
 THEN: Placeholder image is replaced
  AND: userData is updated with new specification
  AND: Returns GraphInsertionResult with success = true

 SCENARIO: Update preserves position
 GIVEN: Existing placeholder at position (100, 200)
 WHEN: update() is called with new image
 THEN: Graph remains at position (100, 200)
  AND: Only image and specification change

 SCENARIO: Update non-existent placeholder
 GIVEN: placeholderID that does not exist
 WHEN: update() is called
 THEN: Throws GraphInsertionError.placeholderNotFound
  AND: No changes to document

 SCENARIO: Update with incompatible specification
 GIVEN: New specification with different equation count
 WHEN: update() is called
 THEN: Update succeeds
  AND: User's edits replace previous specification
  AND: History may track the change
*/

/*
 ACCEPTANCE CRITERIA: GraphInsertionServiceProtocol - remove()

 SCENARIO: Remove existing graph
 GIVEN: Placeholder with ID "graph-123" exists
 WHEN: remove(placeholderID: "graph-123") is called
 THEN: Placeholder is deleted from note
  AND: Returns true
  AND: Content reflows appropriately

 SCENARIO: Remove non-existent graph
 GIVEN: placeholderID that does not exist
 WHEN: remove() is called
 THEN: Returns false or throws error
  AND: Document is unchanged

 SCENARIO: Undo after remove
 GIVEN: Graph was removed
 WHEN: User triggers undo
 THEN: Graph is restored
  AND: userData including specification is restored
  AND: Position is same as before removal
*/

/*
 ACCEPTANCE CRITERIA: GraphInsertionServiceProtocol - getSpecification()

 SCENARIO: Get specification from placeholder
 GIVEN: Placeholder with stored GraphSpecification
 WHEN: getSpecification(forPlaceholderID:) is called
 THEN: Returns the stored GraphSpecification
  AND: All fields match original specification

 SCENARIO: Get specification for non-existent placeholder
 GIVEN: placeholderID that does not exist
 WHEN: getSpecification() is called
 THEN: Returns nil
  AND: No error thrown

 SCENARIO: Get specification with corrupted userData
 GIVEN: Placeholder with invalid JSON in userData
 WHEN: getSpecification() is called
 THEN: Throws GraphInsertionError.deserializationFailed
  AND: reason describes parse error

 SCENARIO: Edit graph workflow
 GIVEN: User taps "Edit" on existing graph
 WHEN: getSpecification() is called
 THEN: Specification is retrieved
  AND: Can be passed to GraphingCalculator UI for editing
  AND: After editing, update() is called with new spec
*/

/*
 ACCEPTANCE CRITERIA: GraphInsertionServiceProtocol - listGraphPlaceholders()

 SCENARIO: List graphs in note with multiple graphs
 GIVEN: Note containing three graph placeholders
 WHEN: listGraphPlaceholders() is called
 THEN: Returns array with three placeholder IDs
  AND: IDs can be used with getSpecification()

 SCENARIO: List graphs in note with no graphs
 GIVEN: Note containing no graph placeholders
 WHEN: listGraphPlaceholders() is called
 THEN: Returns empty array

 SCENARIO: List graphs identifies only graph placeholders
 GIVEN: Note containing graphs and other images
 WHEN: listGraphPlaceholders() is called
 THEN: Only returns IDs of graph placeholders
  AND: Other images are not included
  AND: Type identified by userData.typeIdentifier
*/

// MARK: - GraphInsertionError Enum

// Errors that can occur during graph insertion operations.
enum GraphInsertionError: Error, LocalizedError, Equatable, Sendable {
  // Editor is not available or not ready.
  case editorNotAvailable

  // The provided image is invalid (nil, empty, or corrupted).
  case invalidImage(reason: String)

  // Position is not valid for insertion.
  case invalidPosition(reason: String)

  // Failed to serialize specification to JSON.
  case serializationFailed(reason: String)

  // Failed to deserialize specification from JSON.
  case deserializationFailed(reason: String)

  // The specified placeholder was not found.
  case placeholderNotFound(placeholderID: String)

  // Failed to store userData in placeholder.
  case userDataStorageFailed(reason: String)

  // The editor rejected the insertion.
  case insertionRejected(reason: String)

  // Operation was cancelled.
  case cancelled

  var errorDescription: String? {
    switch self {
    case .editorNotAvailable:
      return "Editor is not available for insertion"
    case .invalidImage(let reason):
      return "Invalid image: \(reason)"
    case .invalidPosition(let reason):
      return "Invalid position: \(reason)"
    case .serializationFailed(let reason):
      return "Failed to serialize specification: \(reason)"
    case .deserializationFailed(let reason):
      return "Failed to deserialize specification: \(reason)"
    case .placeholderNotFound(let placeholderID):
      return "Placeholder '\(placeholderID)' not found"
    case .userDataStorageFailed(let reason):
      return "Failed to store graph data: \(reason)"
    case .insertionRejected(let reason):
      return "Editor rejected insertion: \(reason)"
    case .cancelled:
      return "Operation was cancelled"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: GraphInsertionError

 SCENARIO: Editor not available error
 GIVEN: EditorViewModel.editor is nil
 WHEN: insert() is called
 THEN: GraphInsertionError.editorNotAvailable is thrown

 SCENARIO: Invalid image error
 GIVEN: UIImage with size.width = 0
 WHEN: insert() is called
 THEN: GraphInsertionError.invalidImage is thrown
  AND: reason indicates zero dimensions

 SCENARIO: Serialization failed error
 GIVEN: GraphSpecification that cannot be encoded
 WHEN: GraphPlaceholderUserData is created
 THEN: GraphInsertionError.serializationFailed is thrown

 SCENARIO: Placeholder not found error
 GIVEN: update() called with non-existent ID
 WHEN: Error is thrown
 THEN: placeholderID is included in error
  AND: User can identify which graph was not found

 SCENARIO: Equatable comparison
 GIVEN: Two GraphInsertionError values
 WHEN: Compared for equality
 THEN: Returns true if same case with same values
*/

// MARK: - Constants

// Constants for graph insertion operations.
enum GraphInsertionConstants {
  // Prefix for auto-generated placeholder IDs.
  static let placeholderIDPrefix: String = "graph-"

  // Maximum image dimension (width or height) for insertion.
  static let maxImageDimension: CGFloat = 2048.0

  // Default display width if not specified.
  static let defaultDisplayWidth: CGFloat = 300.0

  // Default display height if not specified.
  static let defaultDisplayHeight: CGFloat = 300.0

  // Minimum padding from document edges.
  static let minimumEdgePadding: CGFloat = 20.0

  // userData key for storing graph placeholder data.
  static let userDataKey: String = "inkos.graph.specification"

  // Version identifier for userData format.
  static let userDataVersion: String = "1.0"
}

/*
 ACCEPTANCE CRITERIA: GraphInsertionConstants

 SCENARIO: Auto-generated ID format
 GIVEN: New graph insertion without custom ID
 WHEN: ID is generated
 THEN: ID starts with placeholderIDPrefix
  AND: Followed by unique identifier

 SCENARIO: Image dimension validation
 GIVEN: Image larger than maxImageDimension
 WHEN: Validation occurs
 THEN: Image is scaled down or error thrown
  AND: Prevents memory issues with huge images

 SCENARIO: Default display size
 GIVEN: Insertion without displaySize
 WHEN: Default is applied
 THEN: Uses defaultDisplayWidth x defaultDisplayHeight
  AND: Reasonable default appearance
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Insert into locked document
 GIVEN: Document is in read-only state
 WHEN: insert() is called
 THEN: GraphInsertionError.insertionRejected is thrown
  AND: reason indicates document is locked

 EDGE CASE: Insert during undo operation
 GIVEN: Editor is processing undo
 WHEN: insert() is called
 THEN: Insertion is queued or deferred
  AND: No corruption of undo history

 EDGE CASE: Concurrent insert operations
 GIVEN: Multiple insert() calls in parallel
 WHEN: All execute
 THEN: Each insertion completes
  AND: Placeholder IDs are unique
  AND: No conflicts or overwrites

 EDGE CASE: Insert with extremely long specification
 GIVEN: Specification with very long expression strings
 WHEN: Stored as userData
 THEN: userData may be large
  AND: Should not cause performance issues
  AND: Consider userData size limits

 EDGE CASE: Get specification after document close
 GIVEN: Document was closed after insert
 WHEN: getSpecification() is called
 THEN: GraphInsertionError.editorNotAvailable is thrown
  AND: No crash or undefined behavior

 EDGE CASE: Update during content export
 GIVEN: Editor is exporting content
 WHEN: update() is called
 THEN: Update waits for export completion
  AND: Or throws appropriate error

 EDGE CASE: Memory warning during insert
 GIVEN: System under memory pressure
 WHEN: insert() is called with large image
 THEN: May fail gracefully
  AND: Error indicates memory constraint
  AND: Editor state remains valid

 EDGE CASE: Placeholder ID collision
 GIVEN: Custom ID matches existing non-graph placeholder
 WHEN: insert() is called with that ID
 THEN: Behavior is defined (replace, error, or rename)
  AND: Consistent and predictable

 EDGE CASE: Specification with unsupported equation types
 GIVEN: Specification contains future equation types
 WHEN: Stored and later retrieved
 THEN: Unknown types are preserved in JSON
  AND: Can be decoded by future app versions

 EDGE CASE: Insert into PDF page
 GIVEN: EditorViewModel displaying PDF
 WHEN: insert() is called
 THEN: Insertion may work differently than Raw Content
  AND: Position is relative to PDF page
  AND: Or error if PDF doesn't support images

 EDGE CASE: Update with nil new image
 GIVEN: update() called with nil or invalid newImage
 WHEN: Validation runs
 THEN: GraphInsertionError.invalidImage is thrown
  AND: Existing placeholder unchanged

 EDGE CASE: Remove last graph in note
 GIVEN: Note contains one graph
 WHEN: remove() is called
 THEN: Graph is removed
  AND: Note is not deleted
  AND: Note may now be empty
*/

// MARK: - Integration Points

/*
 INTEGRATION: EditorViewModel
 GraphInsertionService calls EditorViewModel methods to modify content.
 Uses existing addImage or equivalent API for insertion.
 Respects editor's undo/redo stack.
 Works within editor's save coordination.

 INTEGRATION: IINKEditor (MyScript)
 Actual content modification goes through IINKEditor.
 Placeholder creation uses editor's block or image APIs.
 userData storage uses editor's metadata facilities.

 INTEGRATION: BundleManager
 Graph images may be stored in notebook bundle.
 Large images could be stored as separate bundle resources.
 userData references bundle content if needed.

 INTEGRATION: GraphImageRenderer
 GraphInsertionService receives images from GraphImageRenderer.
 GraphImageOutput.specificationID links to insertion.
 Temporary files from renderer may be cleaned up after insertion.

 INTEGRATION: GraphingCalculatorSkill
 Full workflow: Skill -> Render -> Insert.
 Skill produces specification.
 Renderer produces image from specification.
 Service inserts image with specification userData.

 INTEGRATION: Future Edit Graph Feature
 When user taps graph, getSpecification() retrieves spec.
 Spec is passed to editing UI (GraphView with edit mode).
 After editing, update() saves changes.
 Full round-trip editing capability enabled by userData storage.
*/

// MARK: - Threading Requirements

/*
 THREADING: MainActor requirement
 All protocol methods require @MainActor.
 EditorViewModel is @MainActor isolated.
 IINKEditor must be accessed from main thread.

 THREADING: Async operations
 Methods are async to avoid blocking main thread.
 File I/O or heavy operations dispatch to background.
 Results are delivered on MainActor.

 THREADING: Actor isolation
 GraphInsertionService is an actor for internal state.
 Active insertions are tracked for cleanup.
 Concurrent requests are serialized within actor.

 THREADING: Editor synchronization
 Editor may have internal locks.
 Service respects editor's state.
 No re-entrancy issues with editor callbacks.
*/

// MARK: - MyScript Integration Notes

/*
 MYSCRIPT: Image insertion mechanism
 MyScript IINKEditor supports image blocks in Raw Content.
 Images are inserted at specified positions.
 Image blocks can have associated metadata.

 MYSCRIPT: userData storage
 IINKEditor blocks may support userData dictionary.
 GraphPlaceholderUserData encoded to JSON string.
 Stored as block metadata for retrieval.

 MYSCRIPT: Position coordinate system
 Positions are in editor coordinate space.
 May need conversion from screen coordinates.
 clampEditorViewOffset validates position bounds.

 MYSCRIPT: Block identification
 Each image block has unique identifier.
 Used as placeholderID for graph tracking.
 Must be stable across save/load cycles.
*/
