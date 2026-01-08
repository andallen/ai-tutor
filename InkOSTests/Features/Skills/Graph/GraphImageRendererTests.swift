// GraphImageRendererTests.swift
// Tests for GraphImageRenderer covering image rendering from specifications,
// view rendering, PNG file creation, configuration handling, and cleanup operations.
// These tests validate the contract defined in GraphImageRendererContract.swift.

import SwiftUI
import UIKit
import XCTest

@testable import InkOS

// MARK: - GraphImageOutput Tests

final class GraphImageOutputTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_withAllParameters_storesValues() {
    // Arrange
    let image = UIImage()
    let fileURL = URL(fileURLWithPath: "/tmp/test.png")
    let pixelSize = CGSize(width: 800, height: 600)
    let specID = "spec-123"

    // Act
    let output = GraphImageOutput(
      image: image,
      fileURL: fileURL,
      pixelSize: pixelSize,
      specificationID: specID
    )

    // Assert
    XCTAssertNotNil(output.image)
    XCTAssertEqual(output.fileURL, fileURL)
    XCTAssertEqual(output.pixelSize.width, 800)
    XCTAssertEqual(output.pixelSize.height, 600)
    XCTAssertEqual(output.specificationID, "spec-123")
  }

  func testInit_withNilSpecificationID_storesNil() {
    // Arrange
    let image = UIImage()
    let fileURL = URL(fileURLWithPath: "/tmp/test.png")
    let pixelSize = CGSize(width: 400, height: 400)

    // Act
    let output = GraphImageOutput(
      image: image,
      fileURL: fileURL,
      pixelSize: pixelSize,
      specificationID: nil
    )

    // Assert
    XCTAssertNil(output.specificationID)
  }
}

// MARK: - GraphImageRendererConfiguration Tests

final class GraphImageRendererConfigurationTests: XCTestCase {

  // MARK: - Default Configuration Tests

  func testDefault_size_is400x400() {
    // Arrange & Act
    let config = GraphImageRendererConfiguration.default

    // Assert
    XCTAssertEqual(config.size.width, 400)
    XCTAssertEqual(config.size.height, 400)
  }

  func testDefault_displayScale_isNil() {
    // Arrange & Act
    let config = GraphImageRendererConfiguration.default

    // Assert
    XCTAssertNil(config.displayScale)
  }

  func testDefault_includeBackground_isTrue() {
    // Arrange & Act
    let config = GraphImageRendererConfiguration.default

    // Assert
    XCTAssertTrue(config.includeBackground)
  }

  func testDefault_highQuality_isTrue() {
    // Arrange & Act
    let config = GraphImageRendererConfiguration.default

    // Assert
    XCTAssertTrue(config.highQuality)
  }

  func testDefault_outputDirectory_isNil() {
    // Arrange & Act
    let config = GraphImageRendererConfiguration.default

    // Assert
    XCTAssertNil(config.outputDirectory)
  }

  // MARK: - Custom Size Configuration Tests

  func testWithSize_createsConfigurationWithCustomSize() {
    // Arrange
    let customSize = CGSize(width: 800, height: 600)

    // Act
    let config = GraphImageRendererConfiguration.withSize(customSize)

    // Assert
    XCTAssertEqual(config.size.width, 800)
    XCTAssertEqual(config.size.height, 600)
  }

  func testWithSize_usesDefaultsForOtherProperties() {
    // Arrange
    let customSize = CGSize(width: 800, height: 600)

    // Act
    let config = GraphImageRendererConfiguration.withSize(customSize)

    // Assert
    XCTAssertNil(config.displayScale)
    XCTAssertTrue(config.includeBackground)
    XCTAssertTrue(config.highQuality)
    XCTAssertNil(config.outputDirectory)
  }

  // MARK: - Custom Configuration Tests

  func testInit_withCustomDisplayScale_storesScale() {
    // Arrange & Act
    let config = GraphImageRendererConfiguration(
      size: CGSize(width: 400, height: 400),
      displayScale: 3.0,
      includeBackground: true,
      backgroundColor: .white,
      highQuality: true,
      outputDirectory: nil
    )

    // Assert
    XCTAssertEqual(config.displayScale, 3.0)
  }

  func testInit_withTransparentBackground_hasIncludeBackgroundFalse() {
    // Arrange & Act
    let config = GraphImageRendererConfiguration(
      size: CGSize(width: 400, height: 400),
      displayScale: nil,
      includeBackground: false,
      backgroundColor: .clear,
      highQuality: true,
      outputDirectory: nil
    )

    // Assert
    XCTAssertFalse(config.includeBackground)
  }

  func testInit_withCustomOutputDirectory_storesDirectory() {
    // Arrange
    let customDir = URL(fileURLWithPath: "/tmp/graphs")

    // Act
    let config = GraphImageRendererConfiguration(
      size: CGSize(width: 400, height: 400),
      displayScale: nil,
      includeBackground: true,
      backgroundColor: .white,
      highQuality: true,
      outputDirectory: customDir
    )

    // Assert
    XCTAssertEqual(config.outputDirectory, customDir)
  }

  // MARK: - Equatable Tests

  func testEquatable_sameConfigurations_areEqual() {
    // Arrange
    let config1 = GraphImageRendererConfiguration(
      size: CGSize(width: 400, height: 400),
      displayScale: 2.0,
      includeBackground: true,
      backgroundColor: .white,
      highQuality: true,
      outputDirectory: nil
    )
    let config2 = GraphImageRendererConfiguration(
      size: CGSize(width: 400, height: 400),
      displayScale: 2.0,
      includeBackground: true,
      backgroundColor: .white,
      highQuality: true,
      outputDirectory: nil
    )

    // Act & Assert
    XCTAssertEqual(config1, config2)
  }

  func testEquatable_differentConfigurations_areNotEqual() {
    // Arrange
    let config1 = GraphImageRendererConfiguration.default
    let config2 = GraphImageRendererConfiguration.withSize(CGSize(width: 800, height: 600))

    // Act & Assert
    XCTAssertNotEqual(config1, config2)
  }
}

// MARK: - GraphImageRendererError Tests

final class GraphImageRendererErrorTests: XCTestCase {

  // MARK: - Error Description Tests

  func testRenderingFailed_description_includesReason() {
    // Arrange
    let error = GraphImageRendererError.renderingFailed(reason: "ImageRenderer returned nil")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("ImageRenderer returned nil"))
    XCTAssertTrue(description!.contains("rendering failed"))
  }

  func testPngEncodingFailed_description_indicatesEncodingError() {
    // Arrange
    let error = GraphImageRendererError.pngEncodingFailed

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("PNG"))
  }

  func testFileWriteFailed_description_includesPathAndReason() {
    // Arrange
    let error = GraphImageRendererError.fileWriteFailed(
      path: "/tmp/graph.png",
      reason: "Disk full"
    )

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("/tmp/graph.png"))
    XCTAssertTrue(description!.contains("Disk full"))
  }

  func testInvalidOutputDirectory_description_includesPath() {
    // Arrange
    let error = GraphImageRendererError.invalidOutputDirectory(path: "/nonexistent/path")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("/nonexistent/path"))
  }

  func testMemoryLimitExceeded_description_includesPixelCount() {
    // Arrange
    let error = GraphImageRendererError.memoryLimitExceeded(requestedPixels: 50_000_000)

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("50000000"))
  }

  func testInvalidConfiguration_description_includesReason() {
    // Arrange
    let error = GraphImageRendererError.invalidConfiguration(reason: "Size cannot be zero")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("Size cannot be zero"))
  }

  func testSpecificationRenderFailed_description_includesReason() {
    // Arrange
    let error = GraphImageRendererError.specificationRenderFailed(
      reason: "All equations have parsing errors"
    )

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("All equations have parsing errors"))
  }

  // MARK: - Equatable Tests

  func testEquatable_sameErrors_areEqual() {
    // Arrange
    let error1 = GraphImageRendererError.pngEncodingFailed
    let error2 = GraphImageRendererError.pngEncodingFailed

    // Act & Assert
    XCTAssertEqual(error1, error2)
  }

  func testEquatable_sameErrorCaseWithSameValues_areEqual() {
    // Arrange
    let error1 = GraphImageRendererError.renderingFailed(reason: "Test error")
    let error2 = GraphImageRendererError.renderingFailed(reason: "Test error")

    // Act & Assert
    XCTAssertEqual(error1, error2)
  }

  func testEquatable_differentErrorCases_areNotEqual() {
    // Arrange
    let error1 = GraphImageRendererError.pngEncodingFailed
    let error2 = GraphImageRendererError.renderingFailed(reason: "Test")

    // Act & Assert
    XCTAssertNotEqual(error1, error2)
  }

  func testEquatable_sameErrorCaseWithDifferentValues_areNotEqual() {
    // Arrange
    let error1 = GraphImageRendererError.renderingFailed(reason: "Error A")
    let error2 = GraphImageRendererError.renderingFailed(reason: "Error B")

    // Act & Assert
    XCTAssertNotEqual(error1, error2)
  }
}

// MARK: - GraphImageRendererConstants Tests

final class GraphImageRendererConstantsTests: XCTestCase {

  func testDefaultWidth_is400() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.defaultWidth, 400.0)
  }

  func testDefaultHeight_is400() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.defaultHeight, 400.0)
  }

  func testMaxWidth_is4096() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.maxWidth, 4096.0)
  }

  func testMaxHeight_is4096() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.maxHeight, 4096.0)
  }

  func testMaxTotalPixels_is16Million() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.maxTotalPixels, 16_777_216)
  }

  func testDefaultDisplayScale_is2() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.defaultDisplayScale, 2.0)
  }

  func testPngCompressionQuality_is1() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.pngCompressionQuality, 1.0)
  }

  func testTempFilePrefix_isInkosGraph() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.tempFilePrefix, "inkos_graph_")
  }

  func testTempFileExtension_isPng() {
    // Arrange & Act & Assert
    XCTAssertEqual(GraphImageRendererConstants.tempFileExtension, "png")
  }
}

// MARK: - Mock GraphImageRenderer for Protocol Testing

// Mock implementation of GraphImageRendererProtocol for testing protocol behavior.
// Allows tracking method calls and returning pre-configured values.
// Uses a final class instead of actor to handle @MainActor method requirements.
final class MockGraphImageRenderer: GraphImageRendererProtocol, @unchecked Sendable {

  // Use a lock for thread-safe access.
  private let lock = NSLock()

  // Tracking properties for method calls.
  private var _renderSpecCallCount = 0
  private var _renderViewCallCount = 0
  private var _cleanupCallCount = 0

  // Captured parameters.
  private var _lastRenderedSpec: GraphSpecification?
  private var _lastRenderConfiguration: GraphImageRendererConfiguration?
  private var _temporaryFileURLs: [URL] = []

  // Configurable return values and errors.
  private var _renderSpecResult: GraphImageOutput?
  private var _renderSpecError: GraphImageRendererError?
  private var _renderViewResult: GraphImageOutput?
  private var _renderViewError: GraphImageRendererError?

  // Thread-safe accessors.
  var renderSpecCallCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _renderSpecCallCount
  }

  var renderViewCallCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _renderViewCallCount
  }

  var cleanupCallCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _cleanupCallCount
  }

  var lastRenderedSpec: GraphSpecification? {
    lock.lock()
    defer { lock.unlock() }
    return _lastRenderedSpec
  }

  var lastRenderConfiguration: GraphImageRendererConfiguration? {
    lock.lock()
    defer { lock.unlock() }
    return _lastRenderConfiguration
  }

  var temporaryFileURLs: [URL] {
    lock.lock()
    defer { lock.unlock() }
    return _temporaryFileURLs
  }

  func render(
    _ spec: GraphSpecification,
    configuration: GraphImageRendererConfiguration
  ) async throws -> GraphImageOutput {
    lock.lock()
    _renderSpecCallCount += 1
    _lastRenderedSpec = spec
    _lastRenderConfiguration = configuration
    let error = _renderSpecError
    let result = _renderSpecResult
    lock.unlock()

    if let error = error {
      throw error
    }

    if let result = result {
      return result
    }

    // Default: return a basic output.
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(GraphImageRendererConstants.tempFilePrefix)\(UUID().uuidString)")
      .appendingPathExtension(GraphImageRendererConstants.tempFileExtension)

    lock.lock()
    _temporaryFileURLs.append(tempURL)
    lock.unlock()

    return GraphImageOutput(
      image: UIImage(),
      fileURL: tempURL,
      pixelSize: CGSize(
        width: configuration.size.width * (configuration.displayScale ?? 2.0),
        height: configuration.size.height * (configuration.displayScale ?? 2.0)
      ),
      specificationID: spec.equations.first?.id
    )
  }

  @MainActor
  func render<V: View>(
    view: V,
    configuration: GraphImageRendererConfiguration
  ) async throws -> GraphImageOutput {
    lock.lock()
    _renderViewCallCount += 1
    _lastRenderConfiguration = configuration
    let error = _renderViewError
    let result = _renderViewResult
    lock.unlock()

    if let error = error {
      throw error
    }

    if let result = result {
      return result
    }

    // Default: return a basic output.
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(GraphImageRendererConstants.tempFilePrefix)\(UUID().uuidString)")
      .appendingPathExtension(GraphImageRendererConstants.tempFileExtension)

    lock.lock()
    _temporaryFileURLs.append(tempURL)
    lock.unlock()

    return GraphImageOutput(
      image: UIImage(),
      fileURL: tempURL,
      pixelSize: CGSize(
        width: configuration.size.width * (configuration.displayScale ?? 2.0),
        height: configuration.size.height * (configuration.displayScale ?? 2.0)
      ),
      specificationID: nil
    )
  }

  func cleanupTemporaryFiles() async {
    lock.lock()
    _cleanupCallCount += 1
    _temporaryFileURLs.removeAll()
    lock.unlock()
  }

  // MARK: - Configuration Methods

  func setRenderSpecResult(_ result: GraphImageOutput) {
    lock.lock()
    _renderSpecResult = result
    lock.unlock()
  }

  func setRenderSpecError(_ error: GraphImageRendererError) {
    lock.lock()
    _renderSpecError = error
    lock.unlock()
  }

  func setRenderViewResult(_ result: GraphImageOutput) {
    lock.lock()
    _renderViewResult = result
    lock.unlock()
  }

  func setRenderViewError(_ error: GraphImageRendererError) {
    lock.lock()
    _renderViewError = error
    lock.unlock()
  }
}

// MARK: - GraphImageRenderer Protocol Tests

final class GraphImageRendererProtocolTests: XCTestCase {

  var mockRenderer: MockGraphImageRenderer!

  override func setUp() {
    super.setUp()
    mockRenderer = MockGraphImageRenderer()
  }

  override func tearDown() {
    mockRenderer = nil
    super.tearDown()
  }

  // MARK: - Render Specification Tests

  func testRenderSpec_recordsCallAndSpec() async throws {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.default

    // Act
    _ = try await mockRenderer.render(spec, configuration: config)

    // Assert
    XCTAssertEqual(mockRenderer.renderSpecCallCount, 1)
    XCTAssertEqual(mockRenderer.lastRenderedSpec?.equations.count, 1)
  }

  func testRenderSpec_recordsConfiguration() async throws {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.withSize(CGSize(width: 800, height: 600))

    // Act
    _ = try await mockRenderer.render(spec, configuration: config)

    // Assert
    XCTAssertEqual(mockRenderer.lastRenderConfiguration?.size.width, 800)
    XCTAssertEqual(mockRenderer.lastRenderConfiguration?.size.height, 600)
  }

  func testRenderSpec_returnsConfiguredResult() async throws {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.default
    let expectedOutput = GraphImageOutput(
      image: UIImage(),
      fileURL: URL(fileURLWithPath: "/tmp/expected.png"),
      pixelSize: CGSize(width: 800, height: 800),
      specificationID: "expected-id"
    )
    mockRenderer.setRenderSpecResult(expectedOutput)

    // Act
    let result = try await mockRenderer.render(spec, configuration: config)

    // Assert
    XCTAssertEqual(result.specificationID, "expected-id")
    XCTAssertEqual(result.pixelSize.width, 800)
  }

  func testRenderSpec_throwsConfiguredError() async {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.default
    mockRenderer.setRenderSpecError(.pngEncodingFailed)

    // Act & Assert
    do {
      _ = try await mockRenderer.render(spec, configuration: config)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphImageRendererError {
      XCTAssertEqual(error, .pngEncodingFailed)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testRenderSpec_withEmptyEquations_succeeds() async throws {
    // Arrange
    let spec = createTestSpecification(equationCount: 0)
    let config = GraphImageRendererConfiguration.default

    // Act
    let result = try await mockRenderer.render(spec, configuration: config)

    // Assert - Empty specification renders (axes only).
    XCTAssertNotNil(result.image)
  }

  func testRenderSpec_withCustomScale_scaledPixelSize() async throws {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration(
      size: CGSize(width: 400, height: 400),
      displayScale: 3.0,
      includeBackground: true,
      backgroundColor: .white,
      highQuality: true,
      outputDirectory: nil
    )

    // Act
    let result = try await mockRenderer.render(spec, configuration: config)

    // Assert - Pixel size should be 400 * 3.0 = 1200.
    XCTAssertEqual(result.pixelSize.width, 1200)
    XCTAssertEqual(result.pixelSize.height, 1200)
  }

  // MARK: - Render View Tests

  @MainActor
  func testRenderView_recordsCall() async throws {
    // Arrange
    let view = Text("Test")
    let config = GraphImageRendererConfiguration.default

    // Act
    _ = try await mockRenderer.render(view: view, configuration: config)

    // Assert
    XCTAssertEqual(mockRenderer.renderViewCallCount, 1)
  }

  @MainActor
  func testRenderView_returnsConfiguredResult() async throws {
    // Arrange
    let view = Text("Test")
    let config = GraphImageRendererConfiguration.default
    let expectedOutput = GraphImageOutput(
      image: UIImage(),
      fileURL: URL(fileURLWithPath: "/tmp/view.png"),
      pixelSize: CGSize(width: 600, height: 600),
      specificationID: nil
    )
    mockRenderer.setRenderViewResult(expectedOutput)

    // Act
    let result = try await mockRenderer.render(view: view, configuration: config)

    // Assert
    XCTAssertEqual(result.pixelSize.width, 600)
    XCTAssertNil(result.specificationID)
  }

  @MainActor
  func testRenderView_throwsConfiguredError() async {
    // Arrange
    let view = Text("Test")
    let config = GraphImageRendererConfiguration.default
    mockRenderer.setRenderViewError(.renderingFailed(reason: "View is empty"))

    // Act & Assert
    do {
      _ = try await mockRenderer.render(view: view, configuration: config)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphImageRendererError {
      if case .renderingFailed(let reason) = error {
        XCTAssertEqual(reason, "View is empty")
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Cleanup Tests

  func testCleanup_recordsCall() async {
    // Arrange & Act
    await mockRenderer.cleanupTemporaryFiles()

    // Assert
    XCTAssertEqual(mockRenderer.cleanupCallCount, 1)
  }

  func testCleanup_afterRendering_clearsTemporaryFiles() async throws {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    _ = try await mockRenderer.render(spec, configuration: .default)

    XCTAssertEqual(mockRenderer.temporaryFileURLs.count, 1)

    // Act
    await mockRenderer.cleanupTemporaryFiles()

    // Assert
    XCTAssertEqual(mockRenderer.temporaryFileURLs.count, 0)
  }

  func testCleanup_multipleCallsAreSafe() async {
    // Arrange & Act
    await mockRenderer.cleanupTemporaryFiles()
    await mockRenderer.cleanupTemporaryFiles()

    // Assert - No crash or error.
    XCTAssertEqual(mockRenderer.cleanupCallCount, 2)
  }

  // MARK: - Edge Case Tests

  func testRenderSpec_withVerySmallSize_succeeds() async throws {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.withSize(CGSize(width: 10, height: 10))

    // Act
    let result = try await mockRenderer.render(spec, configuration: config)

    // Assert - Small but valid.
    XCTAssertNotNil(result.image)
  }

  func testRenderSpec_invalidConfiguration_throwsError() async {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.default
    mockRenderer.setRenderSpecError(
      .invalidConfiguration(reason: "Negative dimensions not allowed")
    )

    // Act & Assert
    do {
      _ = try await mockRenderer.render(spec, configuration: config)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphImageRendererError {
      if case .invalidConfiguration(let reason) = error {
        XCTAssertTrue(reason.contains("Negative"))
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testRenderSpec_memoryLimitExceeded_throwsError() async {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.default
    mockRenderer.setRenderSpecError(.memoryLimitExceeded(requestedPixels: 100_000_000))

    // Act & Assert
    do {
      _ = try await mockRenderer.render(spec, configuration: config)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphImageRendererError {
      if case .memoryLimitExceeded(let pixels) = error {
        XCTAssertEqual(pixels, 100_000_000)
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testRenderSpec_fileWriteFailed_throwsError() async {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.default
    mockRenderer.setRenderSpecError(
      .fileWriteFailed(path: "/invalid/path.png", reason: "Permission denied")
    )

    // Act & Assert
    do {
      _ = try await mockRenderer.render(spec, configuration: config)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphImageRendererError {
      if case .fileWriteFailed(let path, let reason) = error {
        XCTAssertEqual(path, "/invalid/path.png")
        XCTAssertEqual(reason, "Permission denied")
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testRenderSpec_invalidOutputDirectory_throwsError() async {
    // Arrange
    let spec = createTestSpecification(equationCount: 1)
    let config = GraphImageRendererConfiguration.default
    mockRenderer.setRenderSpecError(.invalidOutputDirectory(path: "/nonexistent"))

    // Act & Assert
    do {
      _ = try await mockRenderer.render(spec, configuration: config)
      XCTFail("Expected error to be thrown")
    } catch let error as GraphImageRendererError {
      if case .invalidOutputDirectory(let path) = error {
        XCTAssertEqual(path, "/nonexistent")
      } else {
        XCTFail("Wrong error case")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Helper Methods

  private func createTestSpecification(equationCount: Int) -> GraphSpecification {
    let equations = (0..<equationCount).map { i in
      GraphEquation(
        id: "eq\(i)",
        type: .explicit,
        expression: "x^\(i+1)",
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
    }

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
      allowPan: false,
      allowZoom: false,
      allowTrace: false,
      showCoordinates: false,
      snapToGrid: false
    )

    return GraphSpecification(
      version: "1.0",
      title: nil,
      viewport: viewport,
      axes: axes,
      equations: equations,
      points: nil,
      annotations: nil,
      interactivity: interactivity
    )
  }
}

