// GraphImageRenderer.swift
// Implementation of the graph image renderer that captures GraphView to PNG images.
// Uses SwiftUI ImageRenderer for high-quality rendering.

import Foundation
import SwiftUI
import UIKit

// MARK: - GraphImageRenderer

// Actor that renders GraphSpecification to static PNG images.
// Thread-safe with automatic temporary file management.
actor GraphImageRenderer: GraphImageRendererProtocol {
  // Tracks temporary files created by this renderer for cleanup.
  private var temporaryFileURLs: [URL] = []

  // MARK: - Render Specification

  func render(
    _ spec: GraphSpecification,
    configuration: GraphImageRendererConfiguration
  ) async throws -> GraphImageOutput {
    // Validate configuration before MainActor work.
    try validateConfiguration(configuration)

    // Capture configuration values for MainActor closure.
    let size = configuration.size
    let displayScale = configuration.displayScale ?? GraphImageRendererConstants.defaultDisplayScale
    let includeBackground = configuration.includeBackground
    let outputDir = configuration.outputDirectory ?? FileManager.default.temporaryDirectory

    // Create view model and view on main actor.
    let output = try await MainActor.run {
      let viewModel = GraphViewModel(specification: spec)
      viewModel.viewSize = size

      let graphView = GraphView(viewModel: viewModel)
        .frame(width: size.width, height: size.height)

      return try renderViewToOutputOnMainActor(
        view: graphView,
        size: size,
        displayScale: displayScale,
        includeBackground: includeBackground,
        outputDir: outputDir,
        specificationID: spec.title
      )
    }

    // Track temporary file for cleanup.
    temporaryFileURLs.append(output.fileURL)

    return output
  }

  // MARK: - Render View

  @MainActor
  func render<V: View>(
    view: V,
    configuration: GraphImageRendererConfiguration
  ) async throws -> GraphImageOutput {
    // Validate configuration before rendering.
    try await validateConfigurationAsync(configuration)

    let size = configuration.size
    let displayScale = configuration.displayScale ?? GraphImageRendererConstants.defaultDisplayScale
    let includeBackground = configuration.includeBackground
    let outputDir = configuration.outputDirectory ?? FileManager.default.temporaryDirectory

    let framedView = view
      .frame(width: size.width, height: size.height)

    let output = try renderViewToOutputOnMainActor(
      view: framedView,
      size: size,
      displayScale: displayScale,
      includeBackground: includeBackground,
      outputDir: outputDir,
      specificationID: nil
    )

    // Track on actor.
    await trackTemporaryFile(output.fileURL)

    return output
  }

  // Helper to track files in actor context.
  private func trackTemporaryFile(_ url: URL) {
    temporaryFileURLs.append(url)
  }

  // Async validation wrapper for MainActor context.
  private func validateConfigurationAsync(_ configuration: GraphImageRendererConfiguration) async throws {
    // Hop to actor context for validation.
    try await self.validateConfiguration(configuration)
  }

  // MARK: - Core Rendering

  @MainActor
  private func renderViewToOutputOnMainActor<V: View>(
    view: V,
    size: CGSize,
    displayScale: CGFloat,
    includeBackground: Bool,
    outputDir: URL,
    specificationID: String?
  ) throws -> GraphImageOutput {
    // Create the renderer.
    let renderer = ImageRenderer(content: view)
    renderer.scale = displayScale
    renderer.isOpaque = includeBackground

    // Render to CGImage.
    guard let cgImage = renderer.cgImage else {
      throw GraphImageRendererError.renderingFailed(reason: "ImageRenderer returned nil")
    }

    // Create UIImage.
    let image = UIImage(cgImage: cgImage)

    // Encode to PNG data.
    guard let pngData = image.pngData() else {
      throw GraphImageRendererError.pngEncodingFailed
    }

    // Verify output directory exists.
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: outputDir.path, isDirectory: &isDirectory)
    if !exists || !isDirectory.boolValue {
      throw GraphImageRendererError.invalidOutputDirectory(path: outputDir.path)
    }

    // Generate unique filename.
    let filename =
      "\(GraphImageRendererConstants.tempFilePrefix)\(UUID().uuidString).\(GraphImageRendererConstants.tempFileExtension)"
    let fileURL = outputDir.appendingPathComponent(filename)

    // Write PNG to file.
    do {
      try pngData.write(to: fileURL)
    } catch {
      throw GraphImageRendererError.fileWriteFailed(
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }

    // Calculate pixel size.
    let pixelSize = CGSize(
      width: size.width * displayScale,
      height: size.height * displayScale
    )

    return GraphImageOutput(
      image: image,
      fileURL: fileURL,
      pixelSize: pixelSize,
      specificationID: specificationID
    )
  }

  // MARK: - Validation

  private func validateConfiguration(_ configuration: GraphImageRendererConfiguration) throws {
    // Check for non-positive dimensions.
    if configuration.size.width <= 0 || configuration.size.height <= 0 {
      throw GraphImageRendererError.invalidConfiguration(
        reason: "Dimensions must be positive"
      )
    }

    // Check for maximum dimensions.
    if configuration.size.width > GraphImageRendererConstants.maxWidth
      || configuration.size.height > GraphImageRendererConstants.maxHeight
    {
      throw GraphImageRendererError.invalidConfiguration(
        reason: "Dimensions exceed maximum of \(GraphImageRendererConstants.maxWidth)x\(GraphImageRendererConstants.maxHeight)"
      )
    }

    // Check total pixel count.
    let scale = configuration.displayScale ?? GraphImageRendererConstants.defaultDisplayScale
    let totalPixels = Int(configuration.size.width * scale * configuration.size.height * scale)
    if totalPixels > GraphImageRendererConstants.maxTotalPixels {
      throw GraphImageRendererError.memoryLimitExceeded(requestedPixels: totalPixels)
    }
  }

  // MARK: - Cleanup

  func cleanupTemporaryFiles() async {
    let fileManager = FileManager.default

    for url in temporaryFileURLs {
      try? fileManager.removeItem(at: url)
    }

    temporaryFileURLs.removeAll()
  }

  // Cleanup on deinitialization.
  deinit {
    // Create task to clean up files asynchronously.
    let filesToClean = temporaryFileURLs
    Task {
      let fileManager = FileManager.default
      for url in filesToClean {
        try? fileManager.removeItem(at: url)
      }
    }
  }
}
