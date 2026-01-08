// GraphInsertionServiceTests.swift
// Tests for GraphInsertionService covering graph image insertion into notes,
// specification storage in userData, update operations, and placeholder management.
// These tests validate the contract defined in GraphInsertionServiceContract.swift.

import UIKit
import XCTest

@testable import InkOS

// MARK: - GraphInsertionRequest Tests

final class GraphInsertionRequestTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_withRequiredParameters_storesValues() {
    // Arrange
    let image = UIImage()
    let position = CGPoint(x: 100, y: 200)
    let spec = createTestSpecification()

    // Act
    let request = GraphInsertionRequest(
      image: image,
      position: position,
      specification: spec
    )

    // Assert
    XCTAssertNotNil(request.image)
    XCTAssertEqual(request.position.x, 100)
    XCTAssertEqual(request.position.y, 200)
    XCTAssertEqual(request.specification.version, "1.0")
    XCTAssertNil(request.insertionID)
    XCTAssertNil(request.displaySize)
  }

  func testInit_withCustomInsertionID_storesID() {
    // Arrange
    let image = UIImage()
    let position = CGPoint(x: 100, y: 200)
    let spec = createTestSpecification()

    // Act
    let request = GraphInsertionRequest(
      image: image,
      position: position,
      specification: spec,
      insertionID: "custom-graph-123"
    )

    // Assert
    XCTAssertEqual(request.insertionID, "custom-graph-123")
  }

  func testInit_withDisplaySize_storesSize() {
    // Arrange
    let image = UIImage()
    let position = CGPoint(x: 100, y: 200)
    let spec = createTestSpecification()
    let displaySize = CGSize(width: 300, height: 300)

    // Act
    let request = GraphInsertionRequest(
      image: image,
      position: position,
      specification: spec,
      displaySize: displaySize
    )

    // Assert
    XCTAssertEqual(request.displaySize?.width, 300)
    XCTAssertEqual(request.displaySize?.height, 300)
  }

  func testInit_withAllParameters_storesAll() {
    // Arrange
    let image = UIImage()
    let position = CGPoint(x: 50, y: 75)
    let spec = createTestSpecification()
    let insertionID = "my-graph"
    let displaySize = CGSize(width: 400, height: 400)

    // Act
    let request = GraphInsertionRequest(
      image: image,
      position: position,
      specification: spec,
      insertionID: insertionID,
      displaySize: displaySize
    )

    // Assert
    XCTAssertEqual(request.position.x, 50)
    XCTAssertEqual(request.insertionID, "my-graph")
    XCTAssertEqual(request.displaySize?.width, 400)
  }

  // MARK: - Helper Methods

  private func createTestSpecification() -> GraphSpecification {
    let viewport = GraphViewport(
      xMin: -10,
      xMax: 10,
      yMin: -10,
      yMax: 10,
      aspectRatio: .auto
    )
    let axes = GraphAxes(
      x: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true),
      y: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true)
    )
    let interactivity = GraphInteractivity(
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false
    )

    return GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: viewport,
      axes: axes,
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: interactivity
    )
  }
}

// MARK: - GraphInsertionResult Tests

final class GraphInsertionResultTests: XCTestCase {

  // MARK: - Success Factory Tests

  func testSuccess_createsSuccessfulResult() {
    // Arrange & Act
    let result = GraphInsertionResult.success(
      placeholderID: "graph-abc",
      position: CGPoint(x: 100, y: 200),
      size: CGSize(width: 300, height: 300)
    )

    // Assert
    XCTAssertTrue(result.success)
    XCTAssertEqual(result.placeholderID, "graph-abc")
    XCTAssertEqual(result.actualPosition.x, 100)
    XCTAssertEqual(result.actualPosition.y, 200)
    XCTAssertEqual(result.insertedSize.width, 300)
    XCTAssertEqual(result.insertedSize.height, 300)
    XCTAssertNil(result.errorMessage)
  }

  // MARK: - Failure Factory Tests

  func testFailure_createsFailedResult() {
    // Arrange & Act
    let result = GraphInsertionResult.failure(
      placeholderID: "graph-fail",
      error: "Editor not available"
    )

    // Assert
    XCTAssertFalse(result.success)
    XCTAssertEqual(result.placeholderID, "graph-fail")
    XCTAssertEqual(result.actualPosition, .zero)
    XCTAssertEqual(result.insertedSize, .zero)
    XCTAssertEqual(result.errorMessage, "Editor not available")
  }

  // MARK: - Equatable Tests

  func testEquatable_sameSuccessResults_areEqual() {
    // Arrange
    let result1 = GraphInsertionResult.success(
      placeholderID: "graph-1",
      position: CGPoint(x: 100, y: 100),
      size: CGSize(width: 200, height: 200)
    )
    let result2 = GraphInsertionResult.success(
      placeholderID: "graph-1",
      position: CGPoint(x: 100, y: 100),
      size: CGSize(width: 200, height: 200)
    )

    // Act & Assert
    XCTAssertEqual(result1, result2)
  }

  func testEquatable_sameFailureResults_areEqual() {
    // Arrange
    let result1 = GraphInsertionResult.failure(
      placeholderID: "fail-1",
      error: "Error message"
    )
    let result2 = GraphInsertionResult.failure(
      placeholderID: "fail-1",
      error: "Error message"
    )

    // Act & Assert
    XCTAssertEqual(result1, result2)
  }

  func testEquatable_differentResults_areNotEqual() {
    // Arrange
    let success = GraphInsertionResult.success(
      placeholderID: "graph-1",
      position: CGPoint(x: 100, y: 100),
      size: CGSize(width: 200, height: 200)
    )
    let failure = GraphInsertionResult.failure(
      placeholderID: "graph-1",
      error: "Error"
    )

    // Act & Assert
    XCTAssertNotEqual(success, failure)
  }
}

// MARK: - GraphPlaceholderUserData Tests

final class GraphPlaceholderUserDataTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_withValidSpecification_createsUserData() throws {
    // Arrange
    let spec = createTestSpecificationWithEquation()

    // Act
    let userData = try GraphPlaceholderUserData(
      specification: spec,
      notebookID: UUID()
    )

    // Assert
    XCTAssertEqual(userData.version, "1.0")
    XCTAssertFalse(userData.specificationJSON.isEmpty)
    XCTAssertNotNil(userData.insertedAt)
    XCTAssertNotNil(userData.notebookID)
  }

  func testInit_withNilNotebookID_allowsNil() throws {
    // Arrange
    let spec = createTestSpecificationWithEquation()

    // Act
    let userData = try GraphPlaceholderUserData(
      specification: spec,
      notebookID: nil
    )

    // Assert
    XCTAssertNil(userData.notebookID)
  }

  func testInit_withDisplayPreferences_storesPreferences() throws {
    // Arrange
    let spec = createTestSpecificationWithEquation()
    let preferences = GraphDisplayPreferences(
      showBorder: false,
      cornerRadius: 12.0,
      padding: 8.0,
      allowEditing: false
    )

    // Act
    let userData = try GraphPlaceholderUserData(
      specification: spec,
      notebookID: nil,
      displayPreferences: preferences
    )

    // Assert
    XCTAssertNotNil(userData.displayPreferences)
    XCTAssertFalse(userData.displayPreferences!.showBorder)
    XCTAssertEqual(userData.displayPreferences!.cornerRadius, 12.0)
  }

  // MARK: - Get Specification Tests

  func testGetSpecification_returnsEquivalentSpec() throws {
    // Arrange
    let originalSpec = createTestSpecificationWithEquation()
    let userData = try GraphPlaceholderUserData(
      specification: originalSpec,
      notebookID: nil
    )

    // Act
    let retrievedSpec = try userData.getSpecification()

    // Assert
    XCTAssertEqual(retrievedSpec.version, originalSpec.version)
    XCTAssertEqual(retrievedSpec.equations.count, originalSpec.equations.count)
    XCTAssertEqual(retrievedSpec.equations.first?.id, originalSpec.equations.first?.id)
    XCTAssertEqual(retrievedSpec.equations.first?.expression, originalSpec.equations.first?.expression)
  }

  func testGetSpecification_preservesViewport() throws {
    // Arrange
    let spec = createTestSpecificationWithEquation()
    let userData = try GraphPlaceholderUserData(specification: spec, notebookID: nil)

    // Act
    let retrievedSpec = try userData.getSpecification()

    // Assert
    XCTAssertEqual(retrievedSpec.viewport.xMin, spec.viewport.xMin)
    XCTAssertEqual(retrievedSpec.viewport.xMax, spec.viewport.xMax)
    XCTAssertEqual(retrievedSpec.viewport.yMin, spec.viewport.yMin)
    XCTAssertEqual(retrievedSpec.viewport.yMax, spec.viewport.yMax)
  }

  // MARK: - Codable Tests

  func testCodable_encodeAndDecode_preservesData() throws {
    // Arrange
    let spec = createTestSpecificationWithEquation()
    let notebookID = UUID()
    let userData = try GraphPlaceholderUserData(
      specification: spec,
      notebookID: notebookID,
      displayPreferences: .default
    )

    // Act
    let encoder = JSONEncoder()
    let data = try encoder.encode(userData)
    let decoder = JSONDecoder()
    let decodedUserData = try decoder.decode(GraphPlaceholderUserData.self, from: data)

    // Assert
    XCTAssertEqual(decodedUserData.version, userData.version)
    XCTAssertEqual(decodedUserData.specificationJSON, userData.specificationJSON)
    XCTAssertEqual(decodedUserData.notebookID, notebookID)
  }

  func testCodable_insertedAt_isPreserved() throws {
    // Arrange
    let spec = createTestSpecificationWithEquation()
    let userData = try GraphPlaceholderUserData(specification: spec, notebookID: nil)
    let originalDate = userData.insertedAt

    // Act
    let encoder = JSONEncoder()
    let data = try encoder.encode(userData)
    let decoder = JSONDecoder()
    let decodedUserData = try decoder.decode(GraphPlaceholderUserData.self, from: data)

    // Assert - Dates should be very close (within a second due to encoding).
    XCTAssertEqual(
      decodedUserData.insertedAt.timeIntervalSince1970,
      originalDate.timeIntervalSince1970,
      accuracy: 1.0
    )
  }

  // MARK: - Type Identifier Tests

  func testTypeIdentifier_hasCorrectValue() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphPlaceholderUserData.typeIdentifier, "com.inkos.graph-placeholder")
  }

  // MARK: - Helper Methods

  private func createTestSpecificationWithEquation() -> GraphSpecification {
    let equation = GraphEquation(
      id: "eq1",
      type: .explicit,
      expression: "x^2",
      xExpression: nil,
      yExpression: nil,
      rExpression: nil,
      variable: "x",
      parameter: nil,
      domain: nil,
      parameterRange: nil,
      thetaRange: nil,
      style: EquationStyle(
        color: "#0000FF",
        lineWidth: 2.0,
        lineStyle: .solid,
        fillBelow: nil,
        fillAbove: nil,
        fillColor: nil,
        fillOpacity: nil
      ),
      label: nil,
      visible: true,
      fillRegion: nil,
      boundaryStyle: nil
    )

    let viewport = GraphViewport(
      xMin: -10,
      xMax: 10,
      yMin: -10,
      yMax: 10,
      aspectRatio: .auto
    )

    let axes = GraphAxes(
      x: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true),
      y: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true)
    )

    let interactivity = GraphInteractivity(
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false
    )

    return GraphSpecification(
      version: "1.0",
      title: "Test Graph",
      viewport: viewport,
      axes: axes,
      equations: [equation],
      points: nil,
      annotations: nil,
      interactivity: interactivity
    )
  }
}

// MARK: - GraphDisplayPreferences Tests

final class GraphDisplayPreferencesTests: XCTestCase {

  // MARK: - Default Preferences Tests

  func testDefault_showBorder_isTrue() {
    // Arrange & Act
    let preferences = GraphDisplayPreferences.default

    // Assert
    XCTAssertTrue(preferences.showBorder)
  }

  func testDefault_cornerRadius_is8() {
    // Arrange & Act
    let preferences = GraphDisplayPreferences.default

    // Assert
    XCTAssertEqual(preferences.cornerRadius, 8.0)
  }

  func testDefault_padding_is4() {
    // Arrange & Act
    let preferences = GraphDisplayPreferences.default

    // Assert
    XCTAssertEqual(preferences.padding, 4.0)
  }

  func testDefault_allowEditing_isTrue() {
    // Arrange & Act
    let preferences = GraphDisplayPreferences.default

    // Assert
    XCTAssertTrue(preferences.allowEditing)
  }

  // MARK: - Custom Preferences Tests

  func testInit_withCustomValues_storesValues() {
    // Arrange & Act
    let preferences = GraphDisplayPreferences(
      showBorder: false,
      cornerRadius: 16.0,
      padding: 10.0,
      allowEditing: false
    )

    // Assert
    XCTAssertFalse(preferences.showBorder)
    XCTAssertEqual(preferences.cornerRadius, 16.0)
    XCTAssertEqual(preferences.padding, 10.0)
    XCTAssertFalse(preferences.allowEditing)
  }

  // MARK: - Codable Tests

  func testCodable_encodeAndDecode_preservesData() throws {
    // Arrange
    let preferences = GraphDisplayPreferences(
      showBorder: true,
      cornerRadius: 12.0,
      padding: 6.0,
      allowEditing: true
    )

    // Act
    let encoder = JSONEncoder()
    let data = try encoder.encode(preferences)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(GraphDisplayPreferences.self, from: data)

    // Assert
    XCTAssertEqual(decoded.showBorder, preferences.showBorder)
    XCTAssertEqual(decoded.cornerRadius, preferences.cornerRadius)
    XCTAssertEqual(decoded.padding, preferences.padding)
    XCTAssertEqual(decoded.allowEditing, preferences.allowEditing)
  }

  // MARK: - Equatable Tests

  func testEquatable_samePreferences_areEqual() {
    // Arrange
    let pref1 = GraphDisplayPreferences.default
    let pref2 = GraphDisplayPreferences.default

    // Act & Assert
    XCTAssertEqual(pref1, pref2)
  }

  func testEquatable_differentPreferences_areNotEqual() {
    // Arrange
    let pref1 = GraphDisplayPreferences.default
    let pref2 = GraphDisplayPreferences(
      showBorder: false,
      cornerRadius: 0,
      padding: 0,
      allowEditing: false
    )

    // Act & Assert
    XCTAssertNotEqual(pref1, pref2)
  }
}

// MARK: - GraphInsertionError Tests

final class GraphInsertionErrorTests: XCTestCase {

  // MARK: - Error Description Tests

  func testEditorNotAvailable_description() {
    // Arrange
    let error = GraphInsertionError.editorNotAvailable

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("Editor"))
    XCTAssertTrue(description!.lowercased().contains("not available"))
  }

  func testInvalidImage_description_includesReason() {
    // Arrange
    let error = GraphInsertionError.invalidImage(reason: "Image has zero dimensions")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("zero dimensions"))
  }

  func testInvalidPosition_description_includesReason() {
    // Arrange
    let error = GraphInsertionError.invalidPosition(reason: "Position is outside document bounds")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("outside document bounds"))
  }

  func testSerializationFailed_description_includesReason() {
    // Arrange
    let error = GraphInsertionError.serializationFailed(reason: "UTF-8 encoding failed")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("UTF-8"))
  }

  func testDeserializationFailed_description_includesReason() {
    // Arrange
    let error = GraphInsertionError.deserializationFailed(reason: "Invalid JSON structure")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("Invalid JSON"))
  }

  func testPlaceholderNotFound_description_includesID() {
    // Arrange
    let error = GraphInsertionError.placeholderNotFound(placeholderID: "graph-missing-123")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("graph-missing-123"))
  }

  func testUserDataStorageFailed_description_includesReason() {
    // Arrange
    let error = GraphInsertionError.userDataStorageFailed(reason: "Metadata limit exceeded")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("Metadata limit"))
  }

  func testInsertionRejected_description_includesReason() {
    // Arrange
    let error = GraphInsertionError.insertionRejected(reason: "Document is read-only")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("read-only"))
  }

  func testCancelled_description() {
    // Arrange
    let error = GraphInsertionError.cancelled

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.lowercased().contains("cancelled"))
  }

  // MARK: - Equatable Tests

  func testEquatable_sameErrors_areEqual() {
    // Arrange
    let error1 = GraphInsertionError.editorNotAvailable
    let error2 = GraphInsertionError.editorNotAvailable

    // Act & Assert
    XCTAssertEqual(error1, error2)
  }

  func testEquatable_sameErrorCaseWithSameValues_areEqual() {
    // Arrange
    let error1 = GraphInsertionError.placeholderNotFound(placeholderID: "graph-123")
    let error2 = GraphInsertionError.placeholderNotFound(placeholderID: "graph-123")

    // Act & Assert
    XCTAssertEqual(error1, error2)
  }

  func testEquatable_differentErrorCases_areNotEqual() {
    // Arrange
    let error1 = GraphInsertionError.editorNotAvailable
    let error2 = GraphInsertionError.cancelled

    // Act & Assert
    XCTAssertNotEqual(error1, error2)
  }

  func testEquatable_sameErrorCaseWithDifferentValues_areNotEqual() {
    // Arrange
    let error1 = GraphInsertionError.placeholderNotFound(placeholderID: "graph-1")
    let error2 = GraphInsertionError.placeholderNotFound(placeholderID: "graph-2")

    // Act & Assert
    XCTAssertNotEqual(error1, error2)
  }
}

// MARK: - GraphInsertionConstants Tests

final class GraphInsertionConstantsTests: XCTestCase {

  func testPlaceholderIDPrefix_isGraph() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphInsertionConstants.placeholderIDPrefix, "graph-")
  }

  func testMaxImageDimension_is2048() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphInsertionConstants.maxImageDimension, 2048.0)
  }

  func testDefaultDisplayWidth_is300() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphInsertionConstants.defaultDisplayWidth, 300.0)
  }

  func testDefaultDisplayHeight_is300() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphInsertionConstants.defaultDisplayHeight, 300.0)
  }

  func testMinimumEdgePadding_is20() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphInsertionConstants.minimumEdgePadding, 20.0)
  }

  func testUserDataKey_isCorrect() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphInsertionConstants.userDataKey, "inkos.graph.specification")
  }

  func testUserDataVersion_is1Point0() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphInsertionConstants.userDataVersion, "1.0")
  }
}

// MARK: - Mock EditorViewModel for Testing

// Mock implementation of EditorViewModel for testing insertion service.
// Tracks method calls and simulates editor behavior.
@MainActor
final class MockEditorViewModelForInsertion {

  // Tracking properties.
  var addImageCallCount = 0
  var updateImageCallCount = 0
  var removeImageCallCount = 0

  // Captured parameters.
  var lastAddedImage: UIImage?
  var lastAddedPosition: CGPoint?
  var lastAddedSize: CGSize?
  var lastUpdatedPlaceholderID: String?
  var lastRemovedPlaceholderID: String?

  // Configurable behavior.
  var isEditorAvailable = true
  var addImageResult: String?
  var addImageError: Error?
  var updateImageError: Error?
  var removeImageError: Error?
  var existingPlaceholders: [String: GraphPlaceholderUserData] = [:]

  // Simulates whether the editor is ready.
  var isReady: Bool {
    return isEditorAvailable
  }
}

// MARK: - Mock GraphInsertionService for Protocol Testing

// Mock implementation of GraphInsertionServiceProtocol for testing.
@MainActor
final class MockGraphInsertionService: GraphInsertionServiceProtocol {
  nonisolated init() {}

  // Tracking properties.
  var insertCallCount = 0
  var updateCallCount = 0
  var removeCallCount = 0
  var getSpecificationCallCount = 0
  var listPlaceholdersCallCount = 0

  // Captured parameters.
  var lastInsertRequest: GraphInsertionRequest?
  var lastUpdatePlaceholderID: String?
  var lastUpdateImage: UIImage?
  var lastUpdateSpecification: GraphSpecification?
  var lastRemovePlaceholderID: String?
  var lastGetSpecificationPlaceholderID: String?

  // Configurable return values.
  var insertResult: GraphInsertionResult?
  var insertError: GraphInsertionError?
  var updateResult: GraphInsertionResult?
  var updateError: GraphInsertionError?
  var removeResult: Bool = true
  var removeError: GraphInsertionError?
  var getSpecificationResult: GraphSpecification?
  var getSpecificationError: GraphInsertionError?
  var listPlaceholdersResult: [String] = []

  func insert(
    _ request: GraphInsertionRequest,
    into editorViewModel: EditorViewModel
  ) async throws -> GraphInsertionResult {
    insertCallCount += 1
    lastInsertRequest = request

    if let error = insertError {
      throw error
    }

    if let result = insertResult {
      return result
    }

    // Default: return success with auto-generated ID.
    let placeholderID =
      request.insertionID ?? "\(GraphInsertionConstants.placeholderIDPrefix)\(UUID().uuidString)"
    return GraphInsertionResult.success(
      placeholderID: placeholderID,
      position: request.position,
      size: request.displaySize ?? CGSize(
        width: GraphInsertionConstants.defaultDisplayWidth,
        height: GraphInsertionConstants.defaultDisplayHeight
      )
    )
  }

  func update(
    placeholderID: String,
    newImage: UIImage,
    newSpecification: GraphSpecification,
    in editorViewModel: EditorViewModel
  ) async throws -> GraphInsertionResult {
    updateCallCount += 1
    lastUpdatePlaceholderID = placeholderID
    lastUpdateImage = newImage
    lastUpdateSpecification = newSpecification

    if let error = updateError {
      throw error
    }

    if let result = updateResult {
      return result
    }

    // Default: return success.
    return GraphInsertionResult.success(
      placeholderID: placeholderID,
      position: CGPoint(x: 100, y: 100),
      size: CGSize(width: 300, height: 300)
    )
  }

  func remove(
    placeholderID: String,
    from editorViewModel: EditorViewModel
  ) async throws -> Bool {
    removeCallCount += 1
    lastRemovePlaceholderID = placeholderID

    if let error = removeError {
      throw error
    }

    return removeResult
  }

  func getSpecification(
    forPlaceholderID placeholderID: String,
    in editorViewModel: EditorViewModel
  ) async throws -> GraphSpecification? {
    getSpecificationCallCount += 1
    lastGetSpecificationPlaceholderID = placeholderID

    if let error = getSpecificationError {
      throw error
    }

    return getSpecificationResult
  }

  func listGraphPlaceholders(
    in editorViewModel: EditorViewModel
  ) async -> [String] {
    listPlaceholdersCallCount += 1
    return listPlaceholdersResult
  }
}

// MARK: - GraphInsertionService Protocol Tests

final class GraphInsertionServiceProtocolTests: XCTestCase {

  var mockService: MockGraphInsertionService!

  @MainActor
  override func setUp() {
    super.setUp()
    mockService = MockGraphInsertionService()
  }

  @MainActor
  override func tearDown() {
    mockService = nil
    super.tearDown()
  }

  // MARK: - Insert Tests

  @MainActor
  func testInsert_recordsCallAndRequest() async throws {
    // Arrange
    let request = createTestInsertionRequest()
    let mockEditor = await createMockEditorViewModel()

    // Act
    _ = try await mockService.insert(request, into: mockEditor)

    // Assert
    XCTAssertEqual(mockService.insertCallCount, 1)
    XCTAssertNotNil(mockService.lastInsertRequest)
    XCTAssertEqual(mockService.lastInsertRequest?.position, request.position)
  }

  @MainActor
  func testInsert_withCustomID_usesProvidedID() async throws {
    // Arrange
    let request = GraphInsertionRequest(
      image: UIImage(),
      position: CGPoint(x: 100, y: 100),
      specification: createTestSpecification(),
      insertionID: "custom-id-123"
    )
    let mockEditor = await createMockEditorViewModel()

    // Act
    let result = try await mockService.insert(request, into: mockEditor)

    // Assert
    XCTAssertEqual(result.placeholderID, "custom-id-123")
  }

  @MainActor
  func testInsert_withoutID_generatesID() async throws {
    // Arrange
    let request = GraphInsertionRequest(
      image: UIImage(),
      position: CGPoint(x: 100, y: 100),
      specification: createTestSpecification(),
      insertionID: nil
    )
    let mockEditor = await createMockEditorViewModel()

    // Act
    let result = try await mockService.insert(request, into: mockEditor)

    // Assert
    XCTAssertTrue(result.placeholderID.hasPrefix(GraphInsertionConstants.placeholderIDPrefix))
  }

  @MainActor
  func testInsert_returnsConfiguredResult() async throws {
    // Arrange
    let request = createTestInsertionRequest()
    let mockEditor = await createMockEditorViewModel()
    let expectedResult = GraphInsertionResult.success(
      placeholderID: "expected-id",
      position: CGPoint(x: 50, y: 50),
      size: CGSize(width: 400, height: 400)
    )
    mockService.insertResult = expectedResult

    // Act
    let result = try await mockService.insert(request, into: mockEditor)

    // Assert
    XCTAssertEqual(result.placeholderID, "expected-id")
    XCTAssertEqual(result.actualPosition.x, 50)
  }

  @MainActor
  func testInsert_throwsConfiguredError() async {
    // Arrange
    let request = createTestInsertionRequest()
    let mockEditor = await createMockEditorViewModel()
    mockService.insertError = .editorNotAvailable

    // Act & Assert
    do {
      _ = try await mockService.insert(request, into: mockEditor)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      XCTAssertEqual(error, .editorNotAvailable)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  @MainActor
  func testInsert_withDisplaySize_usesProvidedSize() async throws {
    // Arrange
    let displaySize = CGSize(width: 500, height: 400)
    let request = GraphInsertionRequest(
      image: UIImage(),
      position: CGPoint(x: 100, y: 100),
      specification: createTestSpecification(),
      displaySize: displaySize
    )
    let mockEditor = await createMockEditorViewModel()

    // Act
    let result = try await mockService.insert(request, into: mockEditor)

    // Assert
    XCTAssertEqual(result.insertedSize.width, 500)
    XCTAssertEqual(result.insertedSize.height, 400)
  }

  // MARK: - Update Tests

  @MainActor
  func testUpdate_recordsCallAndParameters() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    let newImage = UIImage()
    let newSpec = createTestSpecification()

    // Act
    _ = try await mockService.update(
      placeholderID: "graph-update-test",
      newImage: newImage,
      newSpecification: newSpec,
      in: mockEditor
    )

    // Assert
    XCTAssertEqual(mockService.updateCallCount, 1)
    XCTAssertEqual(mockService.lastUpdatePlaceholderID, "graph-update-test")
    XCTAssertNotNil(mockService.lastUpdateImage)
    XCTAssertNotNil(mockService.lastUpdateSpecification)
  }

  @MainActor
  func testUpdate_returnsConfiguredResult() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    let expectedResult = GraphInsertionResult.success(
      placeholderID: "graph-updated",
      position: CGPoint(x: 200, y: 200),
      size: CGSize(width: 350, height: 350)
    )
    mockService.updateResult = expectedResult

    // Act
    let result = try await mockService.update(
      placeholderID: "graph-updated",
      newImage: UIImage(),
      newSpecification: createTestSpecification(),
      in: mockEditor
    )

    // Assert
    XCTAssertEqual(result.placeholderID, "graph-updated")
  }

  @MainActor
  func testUpdate_placeholderNotFound_throwsError() async {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.updateError = .placeholderNotFound(placeholderID: "nonexistent")

    // Act & Assert
    do {
      _ = try await mockService.update(
        placeholderID: "nonexistent",
        newImage: UIImage(),
        newSpecification: createTestSpecification(),
        in: mockEditor
      )
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      if case .placeholderNotFound(let id) = error {
        XCTAssertEqual(id, "nonexistent")
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Remove Tests

  @MainActor
  func testRemove_recordsCallAndID() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()

    // Act
    _ = try await mockService.remove(placeholderID: "graph-to-remove", from: mockEditor)

    // Assert
    XCTAssertEqual(mockService.removeCallCount, 1)
    XCTAssertEqual(mockService.lastRemovePlaceholderID, "graph-to-remove")
  }

  @MainActor
  func testRemove_success_returnsTrue() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.removeResult = true

    // Act
    let result = try await mockService.remove(placeholderID: "graph-123", from: mockEditor)

    // Assert
    XCTAssertTrue(result)
  }

  @MainActor
  func testRemove_notFound_returnsFalse() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.removeResult = false

    // Act
    let result = try await mockService.remove(placeholderID: "nonexistent", from: mockEditor)

    // Assert
    XCTAssertFalse(result)
  }

  @MainActor
  func testRemove_throwsConfiguredError() async {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.removeError = .editorNotAvailable

    // Act & Assert
    do {
      _ = try await mockService.remove(placeholderID: "graph-123", from: mockEditor)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      XCTAssertEqual(error, .editorNotAvailable)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Get Specification Tests

  @MainActor
  func testGetSpecification_recordsCallAndID() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()

    // Act
    _ = try await mockService.getSpecification(forPlaceholderID: "graph-query", in: mockEditor)

    // Assert
    XCTAssertEqual(mockService.getSpecificationCallCount, 1)
    XCTAssertEqual(mockService.lastGetSpecificationPlaceholderID, "graph-query")
  }

  @MainActor
  func testGetSpecification_returnsConfiguredSpec() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    let expectedSpec = createTestSpecification()
    mockService.getSpecificationResult = expectedSpec

    // Act
    let result = try await mockService.getSpecification(
      forPlaceholderID: "graph-123",
      in: mockEditor
    )

    // Assert
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.version, expectedSpec.version)
  }

  @MainActor
  func testGetSpecification_notFound_returnsNil() async throws {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.getSpecificationResult = nil

    // Act
    let result = try await mockService.getSpecification(
      forPlaceholderID: "nonexistent",
      in: mockEditor
    )

    // Assert
    XCTAssertNil(result)
  }

  @MainActor
  func testGetSpecification_corruptedData_throwsError() async {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.getSpecificationError = .deserializationFailed(reason: "Invalid JSON")

    // Act & Assert
    do {
      _ = try await mockService.getSpecification(
        forPlaceholderID: "graph-corrupted",
        in: mockEditor
      )
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      if case .deserializationFailed(let reason) = error {
        XCTAssertEqual(reason, "Invalid JSON")
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - List Placeholders Tests

  @MainActor
  func testListPlaceholders_recordsCall() async {
    // Arrange
    let mockEditor = await createMockEditorViewModel()

    // Act
    _ = await mockService.listGraphPlaceholders(in: mockEditor)

    // Assert
    XCTAssertEqual(mockService.listPlaceholdersCallCount, 1)
  }

  @MainActor
  func testListPlaceholders_returnsConfiguredList() async {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.listPlaceholdersResult = ["graph-1", "graph-2", "graph-3"]

    // Act
    let result = await mockService.listGraphPlaceholders(in: mockEditor)

    // Assert
    XCTAssertEqual(result.count, 3)
    XCTAssertTrue(result.contains("graph-1"))
    XCTAssertTrue(result.contains("graph-2"))
    XCTAssertTrue(result.contains("graph-3"))
  }

  @MainActor
  func testListPlaceholders_empty_returnsEmptyArray() async {
    // Arrange
    let mockEditor = await createMockEditorViewModel()
    mockService.listPlaceholdersResult = []

    // Act
    let result = await mockService.listGraphPlaceholders(in: mockEditor)

    // Assert
    XCTAssertTrue(result.isEmpty)
  }

  // MARK: - Edge Case Tests

  @MainActor
  func testInsert_invalidImage_throwsError() async {
    // Arrange
    let request = createTestInsertionRequest()
    let mockEditor = await createMockEditorViewModel()
    mockService.insertError = .invalidImage(reason: "Image has zero dimensions")

    // Act & Assert
    do {
      _ = try await mockService.insert(request, into: mockEditor)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      if case .invalidImage(let reason) = error {
        XCTAssertTrue(reason.contains("zero dimensions"))
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  @MainActor
  func testInsert_invalidPosition_throwsError() async {
    // Arrange
    let request = GraphInsertionRequest(
      image: UIImage(),
      position: CGPoint(x: -100, y: -100),
      specification: createTestSpecification()
    )
    let mockEditor = await createMockEditorViewModel()
    mockService.insertError = .invalidPosition(reason: "Position is outside document bounds")

    // Act & Assert
    do {
      _ = try await mockService.insert(request, into: mockEditor)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      if case .invalidPosition(let reason) = error {
        XCTAssertTrue(reason.contains("outside"))
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  @MainActor
  func testInsert_insertionRejected_throwsError() async {
    // Arrange
    let request = createTestInsertionRequest()
    let mockEditor = await createMockEditorViewModel()
    mockService.insertError = .insertionRejected(reason: "Document is locked")

    // Act & Assert
    do {
      _ = try await mockService.insert(request, into: mockEditor)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      if case .insertionRejected(let reason) = error {
        XCTAssertEqual(reason, "Document is locked")
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  @MainActor
  func testInsert_cancelled_throwsError() async {
    // Arrange
    let request = createTestInsertionRequest()
    let mockEditor = await createMockEditorViewModel()
    mockService.insertError = .cancelled

    // Act & Assert
    do {
      _ = try await mockService.insert(request, into: mockEditor)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphInsertionError {
      XCTAssertEqual(error, .cancelled)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Helper Methods

  private func createTestInsertionRequest() -> GraphInsertionRequest {
    return GraphInsertionRequest(
      image: UIImage(),
      position: CGPoint(x: 100, y: 200),
      specification: createTestSpecification()
    )
  }

  private func createTestSpecification() -> GraphSpecification {
    let viewport = GraphViewport(
      xMin: -10,
      xMax: 10,
      yMin: -10,
      yMax: 10,
      aspectRatio: .auto
    )
    let axes = GraphAxes(
      x: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true),
      y: AxisConfiguration(
        label: nil, gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true)
    )
    let interactivity = GraphInteractivity(
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false
    )

    return GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: viewport,
      axes: axes,
      equations: [],
      points: nil,
      annotations: nil,
      interactivity: interactivity
    )
  }

  private func createMockEditorViewModel() async -> EditorViewModel {
    // Creates a minimal EditorViewModel for testing.
    // The mock service does not actually interact with the editor.
    return await EditorViewModel()
  }
}
