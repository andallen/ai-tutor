// GraphImageRendererContract.swift
// Defines the API contract for rendering a GraphView to a static PNG image.
// Uses SwiftUI ImageRenderer (iOS 16+) to capture GraphView as UIImage.
// Writes PNG data to a temporary file and returns both UIImage and file URL.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation
import SwiftUI
import UIKit

// MARK: - API Contract

// MARK: - GraphImageOutput Struct

// Contains the result of rendering a graph to an image.
// Includes the UIImage for immediate use and file URL for persistence.
struct GraphImageOutput: Sendable {
  // The rendered image as UIImage.
  let image: UIImage

  // URL to the temporary PNG file containing the image.
  let fileURL: URL

  // Size of the rendered image in pixels.
  let pixelSize: CGSize

  // Original specification used for rendering (for reference).
  let specificationID: String?
}

/*
 ACCEPTANCE CRITERIA: GraphImageOutput

 SCENARIO: Successful render output
 GIVEN: A GraphView rendered to image successfully
 WHEN: GraphImageOutput is created
 THEN: image is non-nil UIImage
  AND: fileURL points to existing PNG file
  AND: pixelSize reflects actual rendered dimensions
  AND: specificationID matches input if provided

 SCENARIO: Access rendered image
 GIVEN: A GraphImageOutput instance
 WHEN: image property is accessed
 THEN: Returns valid UIImage
  AND: Image dimensions match pixelSize
  AND: Image can be displayed in UIImageView

 SCENARIO: Access file URL
 GIVEN: A GraphImageOutput instance
 WHEN: fileURL is accessed
 THEN: URL points to readable file
  AND: File contains valid PNG data
  AND: File is in temporary directory
*/

// MARK: - GraphImageRendererConfiguration Struct

// Configuration options for graph image rendering.
struct GraphImageRendererConfiguration: Sendable, Equatable {
  // Size of the output image in points (will be scaled by displayScale).
  let size: CGSize

  // Display scale for rendering (e.g., 2.0 for @2x, 3.0 for @3x).
  // If nil, uses default device scale.
  let displayScale: CGFloat?

  // Whether to include a background in the rendered image.
  let includeBackground: Bool

  // Background color if includeBackground is true.
  let backgroundColor: UIColor

  // Whether to render at high quality (affects anti-aliasing).
  let highQuality: Bool

  // Directory for temporary file output (nil uses system temp directory).
  let outputDirectory: URL?

  // Creates a configuration with default values.
  static let `default` = GraphImageRendererConfiguration(
    size: CGSize(width: 400, height: 400),
    displayScale: nil,
    includeBackground: true,
    backgroundColor: .systemBackground,
    highQuality: true,
    outputDirectory: nil
  )

  // Creates a configuration for a specific size with defaults.
  static func withSize(_ size: CGSize) -> GraphImageRendererConfiguration {
    GraphImageRendererConfiguration(
      size: size,
      displayScale: nil,
      includeBackground: true,
      backgroundColor: .systemBackground,
      highQuality: true,
      outputDirectory: nil
    )
  }
}

/*
 ACCEPTANCE CRITERIA: GraphImageRendererConfiguration

 SCENARIO: Default configuration
 GIVEN: GraphImageRendererConfiguration.default
 WHEN: Accessed
 THEN: size is 400x400
  AND: displayScale is nil (use device default)
  AND: includeBackground is true
  AND: highQuality is true

 SCENARIO: Custom size configuration
 GIVEN: GraphImageRendererConfiguration.withSize(CGSize(width: 800, height: 600))
 WHEN: Used for rendering
 THEN: Rendered image has dimensions 800x600 points
  AND: Pixel size is scaled by displayScale

 SCENARIO: Custom display scale
 GIVEN: Configuration with displayScale = 3.0
 WHEN: Rendering a 400x400 point image
 THEN: Pixel size is 1200x1200

 SCENARIO: Transparent background
 GIVEN: Configuration with includeBackground = false
 WHEN: Image is rendered
 THEN: Background is transparent
  AND: PNG supports alpha channel

 SCENARIO: Custom output directory
 GIVEN: Configuration with custom outputDirectory
 WHEN: Image is rendered
 THEN: PNG file is written to specified directory
  AND: Directory must exist and be writable
*/

// MARK: - GraphImageRendererProtocol

// Protocol for rendering graph specifications to static images.
// Uses actor isolation for thread-safe async operations.
protocol GraphImageRendererProtocol: Sendable {
  // Renders a GraphSpecification to a static image.
  // spec: The specification defining the graph to render.
  // configuration: Options controlling output size and quality.
  // Returns GraphImageOutput with image and file URL.
  // Throws GraphImageRendererError if rendering fails.
  func render(
    _ spec: GraphSpecification,
    configuration: GraphImageRendererConfiguration
  ) async throws -> GraphImageOutput

  // Renders a GraphView directly to an image.
  // This method is useful when a pre-configured GraphView is available.
  // view: The SwiftUI GraphView to render.
  // configuration: Options controlling output size and quality.
  // Returns GraphImageOutput with image and file URL.
  // Throws GraphImageRendererError if rendering fails.
  @MainActor
  func render<V: View>(
    view: V,
    configuration: GraphImageRendererConfiguration
  ) async throws -> GraphImageOutput

  // Cleans up temporary files created by this renderer.
  // Called automatically on deallocation, but can be invoked manually.
  func cleanupTemporaryFiles() async
}

/*
 ACCEPTANCE CRITERIA: GraphImageRendererProtocol - render(spec:configuration:)

 SCENARIO: Render simple graph specification
 GIVEN: GraphSpecification with single equation y = x^2
 WHEN: render(spec, configuration: .default) is called
 THEN: Returns GraphImageOutput
  AND: image contains rendered parabola
  AND: fileURL points to valid PNG file
  AND: Image dimensions match configuration.size

 SCENARIO: Render complex specification
 GIVEN: GraphSpecification with multiple equations, points, and annotations
 WHEN: render(spec, configuration:) is called
 THEN: All elements are rendered in correct layers
  AND: Equations have correct colors and styles
  AND: Points are positioned correctly
  AND: Annotations are readable

 SCENARIO: Render with custom size
 GIVEN: Configuration with size 800x600
 WHEN: render(spec, configuration:) is called
 THEN: Output image has point dimensions 800x600
  AND: Pixel dimensions scaled by displayScale

 SCENARIO: Render empty specification
 GIVEN: GraphSpecification with no equations
 WHEN: render(spec, configuration:) is called
 THEN: Returns GraphImageOutput
  AND: image shows only axes and grid (if enabled)
  AND: Valid PNG file is created

 SCENARIO: Render at high resolution
 GIVEN: Configuration with displayScale = 3.0 and size 400x400
 WHEN: render(spec, configuration:) is called
 THEN: Output pixelSize is 1200x1200
  AND: Image has high visual quality
  AND: File size is larger than @1x version

 EDGE CASE: Very small size
 GIVEN: Configuration with size 10x10
 WHEN: render(spec, configuration:) is called
 THEN: Rendering succeeds
  AND: Graph may not be legible but is valid

 EDGE CASE: Very large size
 GIVEN: Configuration with size 4000x4000
 WHEN: render(spec, configuration:) is called
 THEN: Rendering may succeed or fail based on memory
  AND: If fails, throws GraphImageRendererError.memorylimitExceeded

 EDGE CASE: Invalid specification
 GIVEN: GraphSpecification with parsing errors in equations
 WHEN: render(spec, configuration:) is called
 THEN: Rendering proceeds with valid equations
  AND: Invalid equations are skipped or shown as error
*/

/*
 ACCEPTANCE CRITERIA: GraphImageRendererProtocol - render(view:configuration:)

 SCENARIO: Render pre-configured GraphView
 GIVEN: A GraphView with custom ViewModel settings
 WHEN: render(view:, configuration:) is called
 THEN: Returns GraphImageOutput
  AND: Image reflects current ViewModel state
  AND: Viewport matches ViewModel's currentViewport

 SCENARIO: Render custom view composition
 GIVEN: A GraphView with overlaid custom SwiftUI views
 WHEN: render(view:, configuration:) is called
 THEN: All view content is captured
  AND: Overlay elements are included in image

 SCENARIO: Render view at different size than displayed
 GIVEN: GraphView displayed at 300x300
 WHEN: render(view:, configuration: .withSize(CGSize(800, 800))) is called
 THEN: Image is rendered at 800x800
  AND: View is re-laid out for new size
  AND: Curves and text scale appropriately
*/

/*
 ACCEPTANCE CRITERIA: GraphImageRendererProtocol - cleanupTemporaryFiles()

 SCENARIO: Cleanup removes temporary files
 GIVEN: Renderer has created multiple temporary PNG files
 WHEN: cleanupTemporaryFiles() is called
 THEN: All temporary files are deleted
  AND: No errors if files already deleted

 SCENARIO: Cleanup after renderer deallocation
 GIVEN: Renderer goes out of scope
 WHEN: Deinitializer runs
 THEN: Temporary files are cleaned up automatically
  AND: No file leaks occur

 SCENARIO: Multiple cleanup calls are safe
 GIVEN: cleanupTemporaryFiles() called twice
 WHEN: Second call executes
 THEN: No errors thrown
  AND: Idempotent behavior
*/

// MARK: - GraphImageRendererError Enum

// Errors that can occur during graph image rendering.
enum GraphImageRendererError: Error, LocalizedError, Equatable, Sendable {
  // ImageRenderer failed to produce an image.
  case renderingFailed(reason: String)

  // Failed to encode image as PNG data.
  case pngEncodingFailed

  // Failed to write PNG file to disk.
  case fileWriteFailed(path: String, reason: String)

  // Output directory does not exist or is not writable.
  case invalidOutputDirectory(path: String)

  // Rendering exceeds available memory.
  case memoryLimitExceeded(requestedPixels: Int)

  // Configuration has invalid parameters.
  case invalidConfiguration(reason: String)

  // The specification could not be rendered (all equations failed).
  case specificationRenderFailed(reason: String)

  var errorDescription: String? {
    switch self {
    case .renderingFailed(let reason):
      return "Image rendering failed: \(reason)"
    case .pngEncodingFailed:
      return "Failed to encode image as PNG"
    case .fileWriteFailed(let path, let reason):
      return "Failed to write PNG to '\(path)': \(reason)"
    case .invalidOutputDirectory(let path):
      return "Invalid output directory: '\(path)'"
    case .memoryLimitExceeded(let requestedPixels):
      return "Rendering size exceeds memory limit: \(requestedPixels) pixels requested"
    case .invalidConfiguration(let reason):
      return "Invalid renderer configuration: \(reason)"
    case .specificationRenderFailed(let reason):
      return "Specification could not be rendered: \(reason)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: GraphImageRendererError

 SCENARIO: Rendering failed error
 GIVEN: ImageRenderer returns nil
 WHEN: Error is created
 THEN: GraphImageRendererError.renderingFailed is thrown
  AND: reason describes the failure

 SCENARIO: PNG encoding failed error
 GIVEN: UIImage cannot be encoded to PNG
 WHEN: Error is created
 THEN: GraphImageRendererError.pngEncodingFailed is thrown
  AND: User understands PNG conversion failed

 SCENARIO: File write failed error
 GIVEN: Disk is full or path is invalid
 WHEN: Error is created
 THEN: GraphImageRendererError.fileWriteFailed is thrown
  AND: path identifies the target location
  AND: reason describes I/O error

 SCENARIO: Invalid output directory error
 GIVEN: Configuration specifies non-existent directory
 WHEN: Render is attempted
 THEN: GraphImageRendererError.invalidOutputDirectory is thrown
  AND: path shows the invalid directory

 SCENARIO: Memory limit exceeded error
 GIVEN: Configuration requests 10000x10000 image
 WHEN: Render is attempted
 THEN: GraphImageRendererError.memoryLimitExceeded may be thrown
  AND: requestedPixels shows total pixel count

 SCENARIO: Invalid configuration error
 GIVEN: Configuration with zero or negative size
 WHEN: render() is called
 THEN: GraphImageRendererError.invalidConfiguration is thrown
  AND: reason explains the invalid parameter

 SCENARIO: Equatable comparison
 GIVEN: Two GraphImageRendererError values
 WHEN: Compared for equality
 THEN: Returns true if same case with same values
*/

// MARK: - Constants

// Constants for graph image rendering.
enum GraphImageRendererConstants {
  // Default image size in points.
  static let defaultWidth: CGFloat = 400.0
  static let defaultHeight: CGFloat = 400.0

  // Maximum supported dimensions (to prevent memory issues).
  static let maxWidth: CGFloat = 4096.0
  static let maxHeight: CGFloat = 4096.0

  // Maximum total pixels (width * height * scale^2).
  static let maxTotalPixels: Int = 16_777_216  // 4096 * 4096

  // Default display scale if not specified.
  static let defaultDisplayScale: CGFloat = 2.0

  // PNG compression quality (0.0 to 1.0).
  static let pngCompressionQuality: CGFloat = 1.0

  // Temporary file prefix for cleanup identification.
  static let tempFilePrefix: String = "inkos_graph_"

  // Temporary file extension.
  static let tempFileExtension: String = "png"
}

/*
 ACCEPTANCE CRITERIA: GraphImageRendererConstants

 SCENARIO: Validate maximum dimensions
 GIVEN: Configuration with width > maxWidth
 WHEN: Validation is performed
 THEN: Configuration is rejected or clamped
  AND: maxWidth enforces reasonable limit

 SCENARIO: Validate total pixel count
 GIVEN: Configuration resulting in > maxTotalPixels
 WHEN: Validation is performed
 THEN: GraphImageRendererError.memoryLimitExceeded is thrown
  AND: Prevents out-of-memory crashes

 SCENARIO: Temporary file naming
 GIVEN: Renderer creates temporary file
 WHEN: File is written
 THEN: Filename starts with tempFilePrefix
  AND: Extension is tempFileExtension
  AND: Cleanup can identify files by prefix
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Specification with asymptotes
 GIVEN: GraphSpecification with y = 1/x (vertical asymptote)
 WHEN: Rendered to image
 THEN: Asymptote is handled correctly
  AND: No infinite lines drawn through viewport
  AND: Curve segments are separated at discontinuity

 EDGE CASE: Specification with many equations
 GIVEN: GraphSpecification with 50 equations
 WHEN: Rendered to image
 THEN: All equations are rendered
  AND: Performance is acceptable
  AND: Image quality is maintained

 EDGE CASE: Specification with large parameter ranges
 GIVEN: Parametric equation with t from 0 to 1000*pi
 WHEN: Rendered to image
 THEN: Reasonable sample count is used
  AND: Curve appears smooth without excessive detail

 EDGE CASE: Concurrent render calls
 GIVEN: Multiple render() calls in parallel
 WHEN: All execute simultaneously
 THEN: Each call completes independently
  AND: Temporary files are unique per call
  AND: No race conditions

 EDGE CASE: Render during low memory condition
 GIVEN: System under memory pressure
 WHEN: render() is called
 THEN: May throw memoryLimitExceeded
  AND: Does not crash application
  AND: Releases resources appropriately

 EDGE CASE: Output directory becomes unavailable
 GIVEN: Custom output directory on removable media
 WHEN: Media is ejected during render
 THEN: GraphImageRendererError.fileWriteFailed is thrown
  AND: Error message indicates I/O failure

 EDGE CASE: Zero-dimension configuration
 GIVEN: Configuration with size CGSize(0, 0)
 WHEN: render() is called
 THEN: GraphImageRendererError.invalidConfiguration is thrown
  AND: reason indicates invalid dimensions

 EDGE CASE: Negative dimension configuration
 GIVEN: Configuration with size CGSize(-100, 400)
 WHEN: render() is called
 THEN: GraphImageRendererError.invalidConfiguration is thrown
  AND: reason indicates negative dimensions not allowed

 EDGE CASE: Transparent background with fill regions
 GIVEN: Configuration with includeBackground = false
  AND: Specification with inequality fill regions
 WHEN: Rendered to image
 THEN: Fill regions are visible
  AND: Areas without fill are transparent
  AND: PNG alpha channel is correct

 EDGE CASE: Very high display scale
 GIVEN: Configuration with displayScale = 10.0
 WHEN: Validation is performed
 THEN: May be clamped to reasonable maximum
  AND: Or memoryLimitExceeded if total pixels too high

 EDGE CASE: Render specification with all hidden equations
 GIVEN: GraphSpecification where all equations have visible = false
 WHEN: Rendered to image
 THEN: Only axes and grid are shown
  AND: Valid image is produced
  AND: Not an error condition

 EDGE CASE: Dark mode background color
 GIVEN: Configuration with backgroundColor = .systemBackground in dark mode
 WHEN: Rendered to image
 THEN: Background uses dark mode color
  AND: Axes and curves contrast appropriately

 EDGE CASE: Renderer cleanup during active render
 GIVEN: Render in progress
 WHEN: cleanupTemporaryFiles() is called
 THEN: Active render completes normally
  AND: Only completed files are cleaned up
  AND: In-progress file is not deleted
*/

// MARK: - Integration Points

/*
 INTEGRATION: SwiftUI ImageRenderer
 GraphImageRenderer uses ImageRenderer<GraphView> for capture.
 ImageRenderer requires @MainActor for synchronous rendering.
 The render() method dispatches to main actor as needed.

 INTEGRATION: GraphView / GraphViewModel
 Renderer creates temporary GraphViewModel from specification.
 Configures viewSize to match configuration.size.
 GraphView renders using standard rendering pipeline.

 INTEGRATION: File System
 Temporary files are written to system temp directory by default.
 Files are named with prefix for identification during cleanup.
 FileManager is used for all file operations.

 INTEGRATION: GraphInsertionService
 GraphImageRenderer produces UIImage consumed by GraphInsertionService.
 File URL allows GraphInsertionService to persist or reference the image.
 GraphImageOutput.specificationID links image to source specification.

 INTEGRATION: EditorViewModel
 Rendered images are passed to EditorViewModel for insertion.
 EditorViewModel handles actual insertion into the note content.
 Image position is determined by GraphInsertionService.
*/

// MARK: - Threading Requirements

/*
 THREADING: Actor isolation
 GraphImageRenderer is an actor for thread-safe state management.
 Temporary file tracking is actor-isolated.
 Cleanup operations are serialized.

 THREADING: Main actor requirements
 ImageRenderer requires @MainActor for SwiftUI rendering.
 render() method uses MainActor.run for synchronous render portion.
 File I/O can occur off main actor.

 THREADING: Async/await pattern
 All public methods are async for non-blocking operation.
 Callers should not block main thread waiting for render.
 Progress callbacks could be added for long renders.
*/
