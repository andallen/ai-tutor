// Contract.swift
// API Contract for PDF Data Model & Ingestion Pipeline
//
// This file defines the complete specification for PDF import functionality.
// It serves as the bridge between requirements and tests, enabling test-driven development.
// Test writers can implement tests from this contract without ambiguity.

import CoreGraphics
import Foundation
import PDFKit
import UIKit

// MARK: - NoteBlock

// The atomic unit representing content in a PDF-based note document.
// Each block is either a PDF page or an inserted blank writing space.
// Equatable for testing assertions and comparison.
// Codable for persistence to disk as part of NoteDocument.
// Sendable for safe passing across actor boundaries.
enum NoteBlock: Equatable, Hashable, Codable, Sendable {
  // A page from the imported PDF file.
  // pageIndex is the zero-based index in the original PDF.
  // uuid uniquely identifies this block instance.
  // myScriptPartID links to the corresponding IINKContentPart for annotations.
  case pdfPage(pageIndex: Int, uuid: UUID, myScriptPartID: String)

  // A blank writing space inserted between PDF pages.
  // height is the vertical extent in points.
  // uuid uniquely identifies this block instance.
  // myScriptPartID links to the corresponding IINKContentPart for ink content.
  case writingSpacer(height: CGFloat, uuid: UUID, myScriptPartID: String)
}

/*
 ACCEPTANCE CRITERIA: NoteBlock

 SCENARIO: Create PDF page block
 GIVEN: A valid page index, UUID, and MyScript part ID
 WHEN: NoteBlock.pdfPage is created
 THEN: The block stores all three values correctly
  AND: Two blocks with identical values are equal

 SCENARIO: Create writing spacer block
 GIVEN: A valid height, UUID, and MyScript part ID
 WHEN: NoteBlock.writingSpacer is created
 THEN: The block stores all three values correctly
  AND: Two blocks with identical values are equal

 SCENARIO: Encode and decode PDF page block
 GIVEN: A NoteBlock.pdfPage instance
 WHEN: The block is encoded to JSON then decoded
 THEN: The decoded block equals the original

 SCENARIO: Encode and decode writing spacer block
 GIVEN: A NoteBlock.writingSpacer instance
 WHEN: The block is encoded to JSON then decoded
 THEN: The decoded block equals the original
*/

/*
 EDGE CASES: NoteBlock

 EDGE CASE: Negative page index
 GIVEN: A NoteBlock.pdfPage with pageIndex -1
 THEN: The block is created (validation happens at import time, not construction)
  AND: This represents invalid state that should not occur in practice

 EDGE CASE: Zero height spacer
 GIVEN: A NoteBlock.writingSpacer with height 0
 THEN: The block is created (validation is caller responsibility)
  AND: This represents a spacer with no visual height

 EDGE CASE: Negative height spacer
 GIVEN: A NoteBlock.writingSpacer with height -100
 THEN: The block is created (validation is caller responsibility)
  AND: This represents invalid state that should not occur in practice

 EDGE CASE: Empty myScriptPartID
 GIVEN: A NoteBlock with empty myScriptPartID string
 THEN: The block is created (validation is caller responsibility)
  AND: This represents invalid state that should not occur in practice

 EDGE CASE: Maximum CGFloat height
 GIVEN: A NoteBlock.writingSpacer with height CGFloat.greatestFiniteMagnitude
 THEN: The block is created without overflow
  AND: JSON encoding preserves the value
*/

// MARK: - NoteDocument

// Root object representing a PDF-based note document saved to disk.
// Contains metadata about the source PDF and an ordered array of NoteBlock.
// Each block references a MyScript part for ink annotations.
// Codable for persistence as JSON manifest.
// Sendable for safe passing across actor boundaries.
struct NoteDocument: Codable, Sendable, Equatable {
  // Unique identifier for this document.
  let documentID: UUID

  // Display name shown to the user in the document list.
  var displayName: String

  // Original filename of the imported PDF including extension.
  // Used for reference and potential re-import scenarios.
  let sourceFileName: String

  // Timestamp when the document was created from the PDF.
  let createdAt: Date

  // Timestamp when the document was last modified.
  // Updated when blocks are added, removed, or reordered.
  var modifiedAt: Date

  // Ordered array of content blocks.
  // Initial import creates one pdfPage block per PDF page.
  // Users can insert writingSpacer blocks between pages.
  var blocks: [NoteBlock]
}

/*
 ACCEPTANCE CRITERIA: NoteDocument

 SCENARIO: Create document from imported PDF
 GIVEN: A PDF with 3 pages
 WHEN: NoteDocument is created after successful import
 THEN: documentID is a valid UUID
  AND: displayName is derived from sourceFileName without extension
  AND: sourceFileName matches the original PDF filename
  AND: createdAt is approximately the current time
  AND: modifiedAt equals createdAt
  AND: blocks contains exactly 3 NoteBlock.pdfPage items
  AND: blocks are ordered by pageIndex 0, 1, 2

 SCENARIO: Insert writing spacer between pages
 GIVEN: A NoteDocument with 3 PDF page blocks
 WHEN: A writingSpacer is inserted at index 1
 THEN: blocks.count equals 4
  AND: blocks[0] is pdfPage with pageIndex 0
  AND: blocks[1] is writingSpacer
  AND: blocks[2] is pdfPage with pageIndex 1
  AND: blocks[3] is pdfPage with pageIndex 2
  AND: modifiedAt is updated to current time

 SCENARIO: Encode and decode NoteDocument
 GIVEN: A NoteDocument with mixed block types
 WHEN: The document is encoded to JSON then decoded
 THEN: All fields match the original
  AND: blocks array order is preserved
  AND: Date precision is maintained to at least milliseconds
*/

/*
 EDGE CASES: NoteDocument

 EDGE CASE: Empty displayName
 GIVEN: A NoteDocument with displayName as empty string
 THEN: The document is created (UI layer should validate display names)

 EDGE CASE: Empty blocks array
 GIVEN: A NoteDocument with empty blocks array
 THEN: The document is created
  AND: This represents an empty document (unusual but valid state)

 EDGE CASE: Duplicate UUIDs in blocks
 GIVEN: Two blocks with the same uuid
 THEN: The document is created (uniqueness enforced at creation time, not struct level)
  AND: This represents invalid state that should not occur in practice

 EDGE CASE: Very long sourceFileName
 GIVEN: A sourceFileName with 1000 characters
 THEN: The document is created and encodes correctly
  AND: No truncation occurs

 EDGE CASE: sourceFileName with special characters
 GIVEN: A sourceFileName like "My PDF (2024) [Final].pdf"
 THEN: The document is created
  AND: JSON encoding handles special characters correctly
*/

// MARK: - NoteDocumentVersion

// Version constants for the NoteDocument manifest format.
// Used for backward compatibility when the format evolves.
enum NoteDocumentVersion {
  // Current version written by this implementation.
  static let current = 1

  // Set of versions this implementation can read.
  static let supported: Set<Int> = [1]
}

// MARK: - ImportError

// Errors that can occur during PDF import.
// Each case provides specific information about the failure.
// Conforms to LocalizedError for user-facing error messages.
// Equatable for testing assertions.
enum ImportError: LocalizedError, Equatable {
  // PDF is password protected and cannot be imported.
  // User must unlock the PDF before importing.
  case pdfLocked

  // PDF contains zero pages.
  // At least one page is required for import.
  case emptyDocument

  // Could not create PDFDocument from the provided URL.
  // File may be corrupted or not a valid PDF.
  case invalidPDF(reason: String)

  // MyScript engine is not initialized.
  // Engine must be available before importing PDFs.
  case engineNotAvailable

  // Failed to create IINKContentPackage for storing annotations.
  // Underlying error provides details.
  case packageCreationFailed(underlyingError: String)

  // Failed to copy PDF file to app sandbox.
  // Underlying error provides details.
  case fileCopyFailed(underlyingError: String)

  // Failed to create a MyScript content part for a page.
  // partIndex indicates which part failed.
  case partCreationFailed(partIndex: Int, underlyingError: String)

  // Source URL is not accessible or does not exist.
  case sourceFileNotAccessible

  // Destination directory could not be created.
  case destinationDirectoryCreationFailed(underlyingError: String)

  var errorDescription: String? {
    switch self {
    case .pdfLocked:
      return "The PDF is password protected. Please unlock it before importing."
    case .emptyDocument:
      return "The PDF contains no pages."
    case .invalidPDF(let reason):
      return "Could not open the PDF file: \(reason)"
    case .engineNotAvailable:
      return "The annotation engine is not available. Please restart the app."
    case .packageCreationFailed(let underlyingError):
      return "Failed to create annotation storage: \(underlyingError)"
    case .fileCopyFailed(let underlyingError):
      return "Failed to copy the PDF file: \(underlyingError)"
    case .partCreationFailed(let partIndex, let underlyingError):
      return "Failed to create annotation layer for page \(partIndex + 1): \(underlyingError)"
    case .sourceFileNotAccessible:
      return "The selected file is not accessible."
    case .destinationDirectoryCreationFailed(let underlyingError):
      return "Failed to create storage directory: \(underlyingError)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: ImportError

 SCENARIO: Error provides localized description
 GIVEN: Any ImportError case
 WHEN: errorDescription is accessed
 THEN: A non-nil user-facing message is returned

 SCENARIO: ImportError equality
 GIVEN: Two ImportError.pdfLocked values
 WHEN: Compared for equality
 THEN: They are equal

 SCENARIO: ImportError with associated values equality
 GIVEN: Two ImportError.invalidPDF with same reason
 WHEN: Compared for equality
 THEN: They are equal

 GIVEN: Two ImportError.invalidPDF with different reasons
 WHEN: Compared for equality
 THEN: They are not equal
*/

// MARK: - ImportCoordinator Protocol

// Service responsible for validating PDF files and importing them into the app.
// Implemented as an actor to serialize import operations and file system access.
// Uses protocol for testability via dependency injection.
protocol ImportCoordinatorProtocol: Actor {
  // Imports a PDF from the given URL into the app sandbox.
  // Creates a NoteDocument with MyScript parts for each page.
  // Returns the created NoteDocument on success.
  // Throws ImportError on failure.
  //
  // Parameters:
  //   sourceURL: URL from UIDocumentPickerViewController or other file source.
  //              Must be a file URL pointing to a PDF document.
  //   displayName: Optional custom display name. If nil, derived from filename.
  //
  // The source URL must be accessible (security-scoped if from document picker).
  // Caller is responsible for starting/stopping security-scoped access if needed.
  func importPDF(from sourceURL: URL, displayName: String?) async throws -> NoteDocument
}

/*
 ACCEPTANCE CRITERIA: ImportCoordinator.importPDF

 SCENARIO: Successfully import a valid PDF
 GIVEN: A valid unlocked PDF with 5 pages
  AND: MyScript engine is initialized
 WHEN: importPDF is called with the PDF URL
 THEN: The PDF is copied to the app sandbox
  AND: An IINKContentPackage is created
  AND: 5 Drawing parts are created in the package
  AND: A NoteDocument is returned with 5 pdfPage blocks
  AND: Each block's myScriptPartID matches the corresponding part
  AND: The document's sourceFileName matches the original filename
  AND: No error is thrown

 SCENARIO: Import PDF with custom display name
 GIVEN: A valid PDF named "report.pdf"
 WHEN: importPDF is called with displayName "Q4 Report"
 THEN: The returned NoteDocument has displayName "Q4 Report"
  AND: sourceFileName is still "report.pdf"

 SCENARIO: Import PDF with nil display name
 GIVEN: A valid PDF named "Annual Report 2024.pdf"
 WHEN: importPDF is called with displayName nil
 THEN: The returned NoteDocument has displayName "Annual Report 2024"
  AND: The .pdf extension is stripped from the display name

 SCENARIO: Import password-protected PDF
 GIVEN: A PDF that is password protected
 WHEN: importPDF is called
 THEN: ImportError.pdfLocked is thrown
  AND: No files are created in the sandbox
  AND: No MyScript package is created

 SCENARIO: Import empty PDF
 GIVEN: A PDF with zero pages
 WHEN: importPDF is called
 THEN: ImportError.emptyDocument is thrown
  AND: No files are created in the sandbox

 SCENARIO: Import corrupted file
 GIVEN: A file that is not a valid PDF
 WHEN: importPDF is called
 THEN: ImportError.invalidPDF is thrown with descriptive reason
  AND: No files are created in the sandbox

 SCENARIO: Import when engine unavailable
 GIVEN: MyScript engine is not initialized
 WHEN: importPDF is called
 THEN: ImportError.engineNotAvailable is thrown
  AND: PDF validation still occurs first
  AND: No files are copied to sandbox

 SCENARIO: Import with inaccessible source
 GIVEN: A URL that cannot be accessed (no permissions or file deleted)
 WHEN: importPDF is called
 THEN: ImportError.sourceFileNotAccessible is thrown

 SCENARIO: Package creation failure
 GIVEN: A valid PDF
  AND: MyScript engine fails to create package
 WHEN: importPDF is called
 THEN: ImportError.packageCreationFailed is thrown
  AND: The copied PDF file is cleaned up
  AND: No partial state remains

 SCENARIO: Part creation failure mid-import
 GIVEN: A valid PDF with 5 pages
  AND: MyScript fails to create part for page 3
 WHEN: importPDF is called
 THEN: ImportError.partCreationFailed is thrown with partIndex 2
  AND: All created resources are cleaned up
  AND: No partial state remains
*/

/*
 EDGE CASES: ImportCoordinator.importPDF

 EDGE CASE: PDF with single page
 GIVEN: A valid PDF with exactly 1 page
 WHEN: importPDF is called
 THEN: NoteDocument is created with 1 pdfPage block
  AND: The block has pageIndex 0

 EDGE CASE: PDF with many pages
 GIVEN: A valid PDF with 500 pages
 WHEN: importPDF is called
 THEN: NoteDocument is created with 500 pdfPage blocks
  AND: Blocks are ordered by pageIndex 0 through 499
  AND: 500 MyScript parts are created

 EDGE CASE: Filename with no extension
 GIVEN: A valid PDF file named "document" (no .pdf extension)
 WHEN: importPDF is called with nil displayName
 THEN: displayName is "document"
  AND: sourceFileName is "document"

 EDGE CASE: Filename with multiple dots
 GIVEN: A valid PDF named "report.v2.final.pdf"
 WHEN: importPDF is called with nil displayName
 THEN: displayName is "report.v2.final"
  AND: Only the last .pdf extension is removed

 EDGE CASE: Filename with uppercase PDF extension
 GIVEN: A valid PDF named "Report.PDF"
 WHEN: importPDF is called with nil displayName
 THEN: displayName is "Report"
  AND: Extension stripping is case-insensitive

 EDGE CASE: Unicode filename
 GIVEN: A valid PDF named "reportka_2024.pdf"
 WHEN: importPDF is called
 THEN: Unicode characters are preserved in sourceFileName and displayName

 EDGE CASE: Very long filename
 GIVEN: A PDF with filename of 255 characters
 WHEN: importPDF is called
 THEN: Import succeeds without truncation

 EDGE CASE: Concurrent imports
 GIVEN: Two import operations started simultaneously
 WHEN: Both importPDF calls are awaited
 THEN: Both complete without data corruption
  AND: Each creates its own document directory
  AND: Document IDs are unique

 EDGE CASE: Import same PDF twice
 GIVEN: A PDF that was previously imported
 WHEN: importPDF is called again with the same source
 THEN: A new NoteDocument is created with a new documentID
  AND: Both imports exist independently
  AND: No overwriting occurs

 EDGE CASE: Source URL is a directory
 GIVEN: A URL pointing to a directory instead of a file
 WHEN: importPDF is called
 THEN: ImportError.invalidPDF is thrown

 EDGE CASE: Disk full during copy
 GIVEN: A valid PDF
  AND: Insufficient disk space
 WHEN: importPDF is called
 THEN: ImportError.fileCopyFailed is thrown
  AND: Partial files are cleaned up

 EDGE CASE: PDF unlocked but requires password to modify
 GIVEN: A PDF that can be viewed but not modified without password
 WHEN: importPDF is called
 THEN: Import succeeds (viewing is sufficient for import)
  AND: Annotations are stored separately in MyScript package

 EDGE CASE: Zero-byte PDF file
 GIVEN: A file with .pdf extension but zero bytes
 WHEN: importPDF is called
 THEN: ImportError.invalidPDF is thrown
*/

// MARK: - ImportCoordinator Implementation Signature

// Actor that coordinates PDF import operations.
// Serializes file system access and MyScript package creation.
// Uses BundleStorage for directory management.
// Uses EngineProvider for MyScript package creation.
// swiftlint:disable:next type_body_length
actor ImportCoordinator: ImportCoordinatorProtocol {
  // Dependency for engine access. Allows injection for testing.
  private let engineProvider: any EngineProviderProtocol

  // Dependency for PDF document operations. Allows injection for testing.
  private let pdfDocumentFactory: any PDFDocumentFactoryProtocol

  // File name for the PDF copy stored in the document bundle.
  static let pdfFileName = "source.pdf"

  // File name for the NoteDocument manifest.
  static let manifestFileName = "document.json"

  // File name for the MyScript iink package.
  static let iinkFileName = "annotations.iink"

  // Part type used for PDF page annotations.
  static let annotationPartType = "Drawing"

  // Creates an ImportCoordinator with the given dependencies.
  // Pass nil for engineProvider to use the default EngineProvider.sharedInstance.
  // For production use, call this initializer from MainActor context to get the shared engine.
  init(
    engineProvider: (any EngineProviderProtocol)?,
    pdfDocumentFactory: (any PDFDocumentFactoryProtocol)?
  ) {
    // Store provided dependencies.
    // engineProvider is required and must be non-nil at runtime.
    // This will be caught during initialization if violated.
    guard let engineProvider = engineProvider else {
      preconditionFailure("engineProvider must not be nil")
    }
    self.engineProvider = engineProvider
    self.pdfDocumentFactory = pdfDocumentFactory ?? PDFDocumentFactory()
  }

  // Convenience initializer for production use that gets the shared engine provider.
  @MainActor
  static func createDefault() -> ImportCoordinator {
    return ImportCoordinator(
      engineProvider: EngineProvider.sharedInstance,
      pdfDocumentFactory: PDFDocumentFactory()
    )
  }

  func importPDF(from sourceURL: URL, displayName: String?) async throws -> NoteDocument {
    let fileManager = FileManager.default

    // 1. Validate source and PDF document.
    let (pdfDocument, pageCount) = try validatePDFSource(sourceURL, fileManager: fileManager)

    // 2. Get MyScript engine.
    let engine = try await getEngine()

    // 3. Set up document directory.
    let documentID = UUID()
    let documentDirectoryURL = try await createDocumentDirectory(
      documentID, fileManager: fileManager)

    // 4. Import with cleanup on failure.
    return try await performImport(
      sourceURL: sourceURL,
      displayName: displayName,
      pdfDocument: pdfDocument,
      pageCount: pageCount,
      engine: engine,
      documentID: documentID,
      documentDirectoryURL: documentDirectoryURL,
      fileManager: fileManager
    )
  }

  // Validates the source URL and PDF document.
  // Returns the PDF document and page count.
  private func validatePDFSource(
    _ sourceURL: URL,
    fileManager: FileManager
  ) throws -> (any PDFDocumentProtocol, Int) {
    // Validate source URL is accessible.
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw ImportError.sourceFileNotAccessible
    }

    // Create PDFDocument and validate it.
    guard let pdfDocument = pdfDocumentFactory.createPDFDocument(from: sourceURL) else {
      throw ImportError.invalidPDF(reason: "Could not read PDF file")
    }

    // Check PDF is not locked.
    if pdfDocument.isLocked {
      throw ImportError.pdfLocked
    }

    // Check PDF has at least 1 page.
    let pageCount = pdfDocument.pageCount
    if pageCount == 0 {
      throw ImportError.emptyDocument
    }

    return (pdfDocument, pageCount)
  }

  // Gets the MyScript engine instance.
  // Throws if engine is not available.
  private func getEngine() async throws -> any EngineProtocol {
    return try await MainActor.run {
      guard let engine = engineProvider.engineInstance else {
        throw ImportError.engineNotAvailable
      }
      return engine
    }
  }

  // Creates the document directory in the sandbox.
  // Returns the directory URL.
  private func createDocumentDirectory(
    _ documentID: UUID,
    fileManager: FileManager
  ) async throws -> URL {
    let documentDirectoryURL = try await PDFNoteStorage.documentDirectory(for: documentID)

    do {
      try fileManager.createDirectory(
        at: documentDirectoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      throw ImportError.destinationDirectoryCreationFailed(
        underlyingError: error.localizedDescription)
    }

    return documentDirectoryURL
  }

  // Performs the import operation with cleanup on failure.
  // swiftlint:disable:next function_parameter_count
  private func performImport(
    sourceURL: URL,
    displayName: String?,
    pdfDocument: any PDFDocumentProtocol,
    pageCount: Int,
    engine: any EngineProtocol,
    documentID: UUID,
    documentDirectoryURL: URL,
    fileManager: FileManager
  ) async throws -> NoteDocument {
    // Track whether we need to clean up on failure.
    var cleanupRequired = true
    defer {
      if cleanupRequired {
        try? fileManager.removeItem(at: documentDirectoryURL)
      }
    }

    // Copy PDF to document directory.
    let destinationPDFURL = documentDirectoryURL.appendingPathComponent(Self.pdfFileName)
    do {
      try fileManager.copyItem(at: sourceURL, to: destinationPDFURL)
    } catch {
      throw ImportError.fileCopyFailed(underlyingError: error.localizedDescription)
    }

    // Create and save MyScript package with parts.
    let blocks = try await createMyScriptPackage(
      engine: engine,
      documentDirectoryURL: documentDirectoryURL,
      pageCount: pageCount
    )

    // Build NoteDocument.
    let noteDocument = buildNoteDocument(
      documentID: documentID,
      sourceURL: sourceURL,
      displayName: displayName,
      blocks: blocks
    )

    // Save manifest.
    try saveManifest(noteDocument, to: documentDirectoryURL)

    // Generate preview (non-blocking).
    generatePreview(pdfDocument: pdfDocument, to: documentDirectoryURL)

    // Success - disable cleanup.
    cleanupRequired = false

    return noteDocument
  }

  // Creates MyScript package and parts for each page.
  // Returns array of NoteBlock for each page.
  private func createMyScriptPackage(
    engine: any EngineProtocol,
    documentDirectoryURL: URL,
    pageCount: Int
  ) async throws -> [NoteBlock] {
    // Create MyScript package.
    let iinkPath = documentDirectoryURL.appendingPathComponent(Self.iinkFileName).path
    let package: any ContentPackageProtocol
    do {
      package = try await MainActor.run {
        try engine.createContentPackage(iinkPath)
      }
    } catch {
      throw ImportError.packageCreationFailed(underlyingError: error.localizedDescription)
    }

    // Create Drawing part for each PDF page.
    var blocks: [NoteBlock] = []
    for pageIndex in 0..<pageCount {
      let part: any ContentPartProtocol
      do {
        part = try await MainActor.run {
          try package.createNewPart(with: Self.annotationPartType)
        }
      } catch {
        throw ImportError.partCreationFailed(
          partIndex: pageIndex,
          underlyingError: error.localizedDescription
        )
      }

      // Get the part identifier from the protocol.
      let partIdentifier: String = await MainActor.run {
        return part.identifier
      }

      // Create block linking PDF page to MyScript part.
      let block = NoteBlock.pdfPage(
        pageIndex: pageIndex,
        uuid: UUID(),
        myScriptPartID: partIdentifier
      )
      blocks.append(block)
    }

    // Save the package.
    do {
      try await MainActor.run {
        try package.savePackage()
      }
    } catch {
      throw ImportError.packageCreationFailed(
        underlyingError: "Failed to save package: \(error.localizedDescription)"
      )
    }

    return blocks
  }

  // Builds a NoteDocument from the imported data.
  private func buildNoteDocument(
    documentID: UUID,
    sourceURL: URL,
    displayName: String?,
    blocks: [NoteBlock]
  ) -> NoteDocument {
    let sourceFileName = sourceURL.lastPathComponent
    let derivedDisplayName = deriveDisplayName(from: sourceFileName)
    let now = Date()

    return NoteDocument(
      documentID: documentID,
      displayName: displayName ?? derivedDisplayName,
      sourceFileName: sourceFileName,
      createdAt: now,
      modifiedAt: now,
      blocks: blocks
    )
  }

  // Saves the NoteDocument manifest to disk.
  private func saveManifest(_ noteDocument: NoteDocument, to directoryURL: URL) throws {
    let manifestURL = directoryURL.appendingPathComponent(Self.manifestFileName)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted

    do {
      let manifestData = try encoder.encode(noteDocument)
      try manifestData.write(to: manifestURL, options: .atomic)
    } catch {
      throw ImportError.fileCopyFailed(
        underlyingError: "Failed to save manifest: \(error.localizedDescription)"
      )
    }
  }

  // Generates a preview image from the first PDF page.
  // Non-blocking: import succeeds even if preview fails.
  private func generatePreview(pdfDocument: any PDFDocumentProtocol, to directoryURL: URL) {
    do {
      let previewImage = try generatePreviewImage(
        pdfDocument: pdfDocument,
        pageIndex: 0,
        maxPixelDimension: 1200
      )
      let previewURL = directoryURL.appendingPathComponent("preview.png")
      if let pngData = previewImage.pngData() {
        try pngData.write(to: previewURL, options: .atomic)
      }
    } catch {
      // Log error but don't fail import.
      print("Preview generation failed: \(error.localizedDescription)")
    }
  }

  // Derives display name from source filename by removing the PDF extension.
  private func deriveDisplayName(from sourceFileName: String) -> String {
    let lowercased = sourceFileName.lowercased()
    if lowercased.hasSuffix(".pdf") {
      return String(sourceFileName.dropLast(4))
    }
    return sourceFileName
  }

  // Generates a preview image from a PDF page.
  // Renders the page to a UIImage scaled to maxPixelDimension.
  // Throws if rendering fails.
  private func generatePreviewImage(
    pdfDocument: any PDFDocumentProtocol,
    pageIndex: Int,
    maxPixelDimension: CGFloat
  ) throws -> UIImage {
    // Cast to access underlying PDFDocument.
    guard let wrapper = pdfDocument as? PDFDocumentWrapper else {
      throw ImportError.invalidPDF(reason: "Cannot extract PDF page for preview")
    }

    // Get first page.
    guard let page = wrapper.getPage(at: pageIndex) else {
      throw ImportError.invalidPDF(reason: "First page unavailable")
    }

    let pageBounds = page.bounds(for: .mediaBox)
    guard pageBounds.width > 0, pageBounds.height > 0 else {
      throw ImportError.invalidPDF(reason: "Invalid page dimensions")
    }

    // Calculate scale to fit maxPixelDimension.
    // Use fixed 3.0 scale for retina displays (standard for modern iOS devices).
    let maxDimension = max(pageBounds.width, pageBounds.height)
    let scale = min(3.0, maxPixelDimension / maxDimension)

    // Render page to image.
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(size: pageBounds.size, format: format)
    let image = renderer.image { context in
      UIColor.white.setFill()
      context.fill(pageBounds)
      context.cgContext.translateBy(x: 0, y: pageBounds.height)
      context.cgContext.scaleBy(x: 1.0, y: -1.0)
      page.draw(with: .mediaBox, to: context.cgContext)
    }

    return image
  }
}

// MARK: - PDFDocumentFactoryProtocol

// Protocol for creating PDFDocument instances.
// Abstraction enables testing without real PDF files.
protocol PDFDocumentFactoryProtocol: Sendable {
  // Creates a PDFDocument from the given URL.
  // Returns nil if the file is not a valid PDF.
  func createPDFDocument(from url: URL) -> (any PDFDocumentProtocol)?
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentFactoryProtocol

 SCENARIO: Create PDFDocument from valid PDF
 GIVEN: A URL pointing to a valid PDF file
 WHEN: createPDFDocument is called
 THEN: A non-nil PDFDocument is returned

 SCENARIO: Create PDFDocument from invalid file
 GIVEN: A URL pointing to a non-PDF file
 WHEN: createPDFDocument is called
 THEN: nil is returned
*/

// MARK: - PDFDocumentProtocol

// Protocol abstracting PDFDocument for testability.
// Covers the properties needed for import validation.
protocol PDFDocumentProtocol: Sendable {
  // Number of pages in the PDF.
  var pageCount: Int { get }

  // Whether the PDF is locked (password protected for viewing).
  var isLocked: Bool { get }

  // Whether the PDF is encrypted (may allow viewing but restrict operations).
  var isEncrypted: Bool { get }

  // Attempts to unlock the PDF with the given password.
  // Returns true if unlock succeeded or PDF was not locked.
  func unlock(withPassword password: String) -> Bool
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentProtocol

 SCENARIO: Check page count
 GIVEN: A PDFDocument with 10 pages
 WHEN: pageCount is accessed
 THEN: Returns 10

 SCENARIO: Check unlocked PDF
 GIVEN: An unlocked PDFDocument
 WHEN: isLocked is accessed
 THEN: Returns false

 SCENARIO: Check locked PDF
 GIVEN: A password-protected PDFDocument
 WHEN: isLocked is accessed
 THEN: Returns true

 SCENARIO: Unlock with correct password
 GIVEN: A locked PDFDocument
 WHEN: unlock is called with the correct password
 THEN: Returns true
  AND: isLocked returns false
*/

// MARK: - PDFDocumentFactory (Production Implementation Signature)

// Production implementation of PDFDocumentFactoryProtocol.
// Uses PDFKit's PDFDocument.
final class PDFDocumentFactory: PDFDocumentFactoryProtocol, @unchecked Sendable {
  func createPDFDocument(from url: URL) -> (any PDFDocumentProtocol)? {
    return createPDFDocumentImpl(from: url)
  }
}

// MARK: - Storage Directory Structure

/*
 STORAGE LAYOUT:

 Documents/
   PDFNotes/                              <- Root directory for PDF-based documents
     {documentID}/                        <- One directory per imported PDF
       source.pdf                         <- Copy of the original PDF
       document.json                      <- NoteDocument manifest
       annotations.iink                   <- MyScript package for ink annotations
       preview.png                        <- Optional thumbnail (future feature)

 NOTES:
 - Each document lives in its own UUID-named directory.
 - The original PDF is preserved for rendering.
 - Annotations are stored separately in the MyScript package.
 - This structure mirrors the existing Notebooks/ structure for consistency.
 - PDFNotes/ is separate from Notebooks/ to distinguish document types.
*/

// MARK: - PDFNoteStorage

// Provides directory paths for PDF note document storage.
// Mirrors BundleStorage pattern for consistency.
enum PDFNoteStorage {
  // The name of the parent folder where all PDF note documents are stored.
  static let pdfNotesFolderName = "PDFNotes"

  // Returns the URL to the folder where PDF note documents are stored.
  // Creates the folder if it does not exist.
  // Throws if the Documents directory cannot be accessed or folder cannot be created.
  static func pdfNotesDirectory() async throws -> URL {
    return try await pdfNotesDirectoryImpl()
  }

  // Returns the URL to a specific document's directory.
  // Does not create the directory; caller must create it.
  static func documentDirectory(for documentID: UUID) async throws -> URL {
    return try await documentDirectoryImpl(for: documentID)
  }
}

/*
 ACCEPTANCE CRITERIA: PDFNoteStorage

 SCENARIO: Get PDF notes directory (first access)
 GIVEN: The PDFNotes directory does not exist
 WHEN: pdfNotesDirectory() is called
 THEN: The directory is created
  AND: The returned URL points to Documents/PDFNotes/

 SCENARIO: Get PDF notes directory (subsequent access)
 GIVEN: The PDFNotes directory already exists
 WHEN: pdfNotesDirectory() is called
 THEN: The existing directory URL is returned
  AND: No error is thrown

 SCENARIO: Get document directory
 GIVEN: A document UUID
 WHEN: documentDirectory(for:) is called
 THEN: Returns Documents/PDFNotes/{uuid}/
  AND: The directory is not created by this call
*/

/*
 EDGE CASES: PDFNoteStorage

 EDGE CASE: Documents directory inaccessible
 GIVEN: The app cannot access the Documents directory
 WHEN: pdfNotesDirectory() is called
 THEN: An error is thrown

 EDGE CASE: PDFNotes exists as a file
 GIVEN: A file (not directory) exists at Documents/PDFNotes
 WHEN: pdfNotesDirectory() is called
 THEN: An error is thrown (cannot create directory)
*/

// MARK: - Integration with Existing Storage

/*
 INTEGRATION NOTES:

 This feature introduces a parallel storage structure for PDF-based documents.
 The existing BundleManager handles notebook bundles in Documents/Notebooks/.
 PDF notes use a similar pattern in Documents/PDFNotes/.

 Key differences from notebook bundles:
 - NoteDocument replaces Manifest as the metadata container
 - source.pdf stores the original PDF (notebooks have no source file)
 - blocks array tracks document structure (notebooks are single-part)

 The ImportCoordinator is the write path for creating PDF note documents.
 A separate PDFNoteManager (future) will handle listing, opening, and deleting.

 MyScript integration:
 - One IINKContentPackage per document (same as notebooks)
 - One Drawing part per PDF page (notebooks typically have one part)
 - Part indices align with block indices for pdfPage blocks
 - writingSpacer blocks also have parts but no PDF page backing

 The myScriptPartID in NoteBlock stores the part identifier for lookup.
 This decouples block order from part order, allowing block reordering.
*/

// MARK: - NoteBlock Height Extension

// Extension on NoteBlock to calculate base height without zoom.
// Used by PDFDocumentView for layout calculations.

extension NoteBlock {
  // Extracts the MyScript part identifier from the block.
  // Both pdfPage and writingSpacer blocks store a myScriptPartID.
  // This computed property provides convenient access without pattern matching.
  var myScriptPartID: String {
    switch self {
    case .pdfPage(_, _, let myScriptPartID):
      return myScriptPartID
    case .writingSpacer(_, _, let myScriptPartID):
      return myScriptPartID
    }
  }

  // Calculates the unscaled height of this block.
  // For pdfPage: Queries the page height from the provider.
  // For writingSpacer: Returns the stored height value.
  //
  // pageHeightProvider: Closure that returns page height for a given page index.
  //                     Returns nil if the page index is invalid.
  //
  // Returns: The height in points, or nil if the page index is invalid.
  func baseHeight(pageHeightProvider: (Int) -> CGFloat?) -> CGFloat? {
    switch self {
    case .pdfPage(let pageIndex, _, _):
      return pageHeightProvider(pageIndex)
    case .writingSpacer(let height, _, _):
      return height
    }
  }
}

/*
 ACCEPTANCE CRITERIA: NoteBlock.baseHeight

 SCENARIO: PDF page height
 GIVEN: A NoteBlock.pdfPage with pageIndex 0
  AND: pageHeightProvider returns 792 for index 0
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns 792

 SCENARIO: PDF page with different aspect ratio
 GIVEN: A NoteBlock.pdfPage with pageIndex 2
  AND: pageHeightProvider returns 500 for index 2
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns 500

 SCENARIO: Writing spacer height
 GIVEN: A NoteBlock.writingSpacer with height 200
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns 200
  AND: pageHeightProvider is not called

 SCENARIO: Invalid page index
 GIVEN: A NoteBlock.pdfPage with pageIndex 10
  AND: pageHeightProvider returns nil for index 10
 WHEN: baseHeight(pageHeightProvider:) is called
 THEN: Returns nil
*/

/*
 EDGE CASES: NoteBlock.baseHeight

 EDGE CASE: Zero height spacer
 GIVEN: A NoteBlock.writingSpacer with height 0
 WHEN: baseHeight is called
 THEN: Returns 0

 EDGE CASE: Negative height spacer
 GIVEN: A NoteBlock.writingSpacer with height -100
 WHEN: baseHeight is called
 THEN: Returns -100 (invalid state, but extension does not validate)

 EDGE CASE: Very large height
 GIVEN: A NoteBlock.writingSpacer with height CGFloat.greatestFiniteMagnitude
 WHEN: baseHeight is called
 THEN: Returns CGFloat.greatestFiniteMagnitude
*/

// MARK: - Future Extensions (Not Part of Current Contract)

/*
 FUTURE FEATURES (documented for context, not implemented now):

 1. PDFNoteManager - CRUD operations for PDF note documents
    - List all documents
    - Open document for editing
    - Delete document
    - Rename document

 2. Block Manipulation - Insert/remove writing spacers
    - Insert spacer at index
    - Remove spacer
    - Resize spacer height

 3. Page Operations - Rearrange document structure
    - Move block to new position
    - Delete PDF page (hide, not remove from source)
    - Split document

 4. Export - Generate annotated PDF
    - Render annotations onto PDF pages
    - Export to new PDF file
    - Share via system share sheet

 These features will have their own contracts when implemented.
*/
