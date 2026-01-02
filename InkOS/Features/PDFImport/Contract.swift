// Contract.swift
// Data models and import logic for PDF documents.

import CoreGraphics
import Foundation
import PDFKit
import UIKit

// MARK: - NoteBlock

// Represents a unit of content in a PDF note document.
// Either a PDF page or an inserted blank writing space.
enum NoteBlock: Equatable, Hashable, Codable, Sendable {
  // A page from the imported PDF file.
  case pdfPage(pageIndex: Int, uuid: UUID, myScriptPartID: String)

  // A blank writing space inserted between PDF pages.
  case writingSpacer(height: CGFloat, uuid: UUID, myScriptPartID: String)

  // The MyScript part identifier for this block.
  var myScriptPartID: String {
    switch self {
    case .pdfPage(_, _, let id): return id
    case .writingSpacer(_, _, let id): return id
    }
  }

  // Calculates the unscaled height of this block.
  func baseHeight(pageHeightProvider: (Int) -> CGFloat?) -> CGFloat? {
    switch self {
    case .pdfPage(let pageIndex, _, _):
      return pageHeightProvider(pageIndex)
    case .writingSpacer(let height, _, _):
      return height
    }
  }
}

// MARK: - NoteDocument

// Root object representing a PDF-based note document.
struct NoteDocument: Codable, Sendable, Equatable {
  let documentID: UUID
  var displayName: String
  let sourceFileName: String
  let createdAt: Date
  var modifiedAt: Date
  var blocks: [NoteBlock]
  var folderID: String?
}

// MARK: - NoteDocumentVersion

enum NoteDocumentVersion {
  static let current = 1
  static let supported: Set<Int> = [1]
}

// MARK: - ImportError

enum ImportError: LocalizedError, Equatable {
  case pdfLocked
  case emptyDocument
  case invalidPDF(reason: String)
  case engineNotAvailable
  case packageCreationFailed(underlyingError: String)
  case fileCopyFailed(underlyingError: String)
  case partCreationFailed(partIndex: Int, underlyingError: String)
  case sourceFileNotAccessible
  case destinationDirectoryCreationFailed(underlyingError: String)

  var errorDescription: String? {
    switch self {
    case .pdfLocked:
      return "The PDF is password protected."
    case .emptyDocument:
      return "The PDF contains no pages."
    case .invalidPDF(let reason):
      return "Could not open the PDF: \(reason)"
    case .engineNotAvailable:
      return "The annotation engine is not available."
    case .packageCreationFailed(let error):
      return "Failed to create annotation storage: \(error)"
    case .fileCopyFailed(let error):
      return "Failed to copy the PDF: \(error)"
    case .partCreationFailed(let index, let error):
      return "Failed to create annotation layer for page \(index + 1): \(error)"
    case .sourceFileNotAccessible:
      return "The selected file is not accessible."
    case .destinationDirectoryCreationFailed(let error):
      return "Failed to create storage directory: \(error)"
    }
  }
}

// MARK: - PDFDocumentProtocol

protocol PDFDocumentProtocol: Sendable {
  var pageCount: Int { get }
  var isLocked: Bool { get }
  var isEncrypted: Bool { get }
  func unlock(withPassword password: String) -> Bool
  func getPage(at index: Int) -> PDFPage?
}

// MARK: - PDFDocumentFactoryProtocol

protocol PDFDocumentFactoryProtocol: Sendable {
  func createPDFDocument(from url: URL) -> (any PDFDocumentProtocol)?
}

// MARK: - PDFDocumentFactory

final class PDFDocumentFactory: PDFDocumentFactoryProtocol, @unchecked Sendable {
  func createPDFDocument(from url: URL) -> (any PDFDocumentProtocol)? {
    return createPDFDocumentImpl(from: url)
  }
}

// MARK: - ImportCoordinatorProtocol

protocol ImportCoordinatorProtocol: Actor {
  func importPDF(from sourceURL: URL, displayName: String?) async throws -> NoteDocument
}

// MARK: - ImportCoordinator

actor ImportCoordinator: ImportCoordinatorProtocol {
  private let engineProvider: any EngineProviderProtocol
  private let pdfDocumentFactory: any PDFDocumentFactoryProtocol

  static let pdfFileName = "source.pdf"
  static let manifestFileName = "document.json"
  static let iinkFileName = "annotations.iink"
  // Use "Raw Content" to enable recognition, conversion, and gestures.
  static let annotationPartType = "Raw Content"

  init(
    engineProvider: (any EngineProviderProtocol)?,
    pdfDocumentFactory: (any PDFDocumentFactoryProtocol)?
  ) {
    guard let engineProvider = engineProvider else {
      preconditionFailure("engineProvider must not be nil")
    }
    self.engineProvider = engineProvider
    self.pdfDocumentFactory = pdfDocumentFactory ?? PDFDocumentFactory()
  }

  @MainActor
  static func createDefault() -> ImportCoordinator {
    return ImportCoordinator(
      engineProvider: EngineProvider.sharedInstance,
      pdfDocumentFactory: PDFDocumentFactory()
    )
  }

  func importPDF(from sourceURL: URL, displayName: String?) async throws -> NoteDocument {
    let fileManager = FileManager.default

    // Validate source and PDF.
    let (pdfDocument, pageCount) = try validatePDFSource(sourceURL, fileManager: fileManager)

    // Get engine.
    let engine = try await getEngine()

    // Create document directory.
    let documentID = UUID()
    let documentDirectoryURL = try await createDocumentDirectory(documentID, fileManager: fileManager)

    // Import with cleanup on failure.
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

  private func validatePDFSource(
    _ sourceURL: URL,
    fileManager: FileManager
  ) throws -> (any PDFDocumentProtocol, Int) {
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw ImportError.sourceFileNotAccessible
    }

    guard let pdfDocument = pdfDocumentFactory.createPDFDocument(from: sourceURL) else {
      throw ImportError.invalidPDF(reason: "Could not read PDF file")
    }

    if pdfDocument.isLocked {
      throw ImportError.pdfLocked
    }

    let pageCount = pdfDocument.pageCount
    if pageCount == 0 {
      throw ImportError.emptyDocument
    }

    return (pdfDocument, pageCount)
  }

  private func getEngine() async throws -> any EngineProtocol {
    return try await MainActor.run {
      guard let engine = engineProvider.engineInstance else {
        throw ImportError.engineNotAvailable
      }
      return engine
    }
  }

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
      throw ImportError.destinationDirectoryCreationFailed(underlyingError: error.localizedDescription)
    }

    return documentDirectoryURL
  }

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
    var cleanupRequired = true
    defer {
      if cleanupRequired {
        try? fileManager.removeItem(at: documentDirectoryURL)
      }
    }

    // Copy PDF.
    let destinationPDFURL = documentDirectoryURL.appendingPathComponent(Self.pdfFileName)
    do {
      try fileManager.copyItem(at: sourceURL, to: destinationPDFURL)
    } catch {
      throw ImportError.fileCopyFailed(underlyingError: error.localizedDescription)
    }

    // Create MyScript package.
    let blocks = try await createMyScriptPackage(
      engine: engine,
      documentDirectoryURL: documentDirectoryURL,
      pdfDocument: pdfDocument,
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

    // Generate preview.
    generatePreview(pdfDocument: pdfDocument, to: documentDirectoryURL)

    cleanupRequired = false
    return noteDocument
  }

  private func createMyScriptPackage(
    engine: any EngineProtocol,
    documentDirectoryURL: URL,
    pdfDocument: any PDFDocumentProtocol,
    pageCount: Int
  ) async throws -> [NoteBlock] {
    let iinkPath = documentDirectoryURL.appendingPathComponent(Self.iinkFileName).path
    let package: any ContentPackageProtocol
    do {
      package = try await MainActor.run {
        try engine.createContentPackage(iinkPath)
      }
    } catch {
      throw ImportError.packageCreationFailed(underlyingError: error.localizedDescription)
    }

    // Calculate document size in millimeters for fixed-size part creation.
    // This enables scrolling to all pages without needing anchor strokes.
    let documentSizeMM = calculateDocumentSizeInMM(pdfDocument: pdfDocument, pageCount: pageCount)

    // Create a single Raw Content part for the entire document with fixed size.
    // All pages share this one part - ink Y coordinates are offset by page positions.
    let part: any ContentPartProtocol
    do {
      part = try await MainActor.run {
        try package.createNewPart(with: Self.annotationPartType, fixedSize: documentSizeMM)
      }
    } catch {
      throw ImportError.partCreationFailed(
        partIndex: 0,
        underlyingError: error.localizedDescription
      )
    }

    let partIdentifier: String = await MainActor.run {
      return part.identifier
    }

    // Create blocks for each page, all referencing the same part.
    var blocks: [NoteBlock] = []
    for pageIndex in 0..<pageCount {
      let block = NoteBlock.pdfPage(
        pageIndex: pageIndex,
        uuid: UUID(),
        myScriptPartID: partIdentifier
      )
      blocks.append(block)
    }

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

  private func generatePreview(pdfDocument: any PDFDocumentProtocol, to directoryURL: URL) {
    guard let page = pdfDocument.getPage(at: 0) else { return }

    let pageBounds = page.bounds(for: .mediaBox)
    guard pageBounds.width > 0, pageBounds.height > 0 else { return }

    let maxDimension = max(pageBounds.width, pageBounds.height)
    let scale = min(3.0, 1200 / maxDimension)

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

    let previewURL = directoryURL.appendingPathComponent("preview.png")
    if let pngData = image.pngData() {
      try? pngData.write(to: previewURL, options: .atomic)
    }
  }

  // Calculates the total document size in millimeters for the MyScript SDK.
  // Uses PDF native dimensions converted from points to mm.
  // Matches the layout logic in PDFPageLayout but in mm instead of screen pixels.
  private func calculateDocumentSizeInMM(
    pdfDocument: any PDFDocumentProtocol,
    pageCount: Int
  ) -> CGSize {
    // Conversion: 1 PDF point = 1/72 inch = 25.4/72 mm ≈ 0.3528 mm
    let pointsToMM: CGFloat = 25.4 / 72.0
    // Page spacing in mm (matching PDFPageLayout's 20pt spacing)
    let pageSpacingMM: CGFloat = 20.0 * pointsToMM

    // Use a reference width based on typical PDF page width (A4 = 595pt ≈ 210mm)
    // We'll use the first page's width as reference.
    var referenceWidthMM: CGFloat = 210.0  // Default to A4 width
    if let firstPage = pdfDocument.getPage(at: 0) {
      let bounds = firstPage.bounds(for: .mediaBox)
      referenceWidthMM = bounds.width * pointsToMM
    }

    // Calculate total height by stacking pages with spacing.
    var totalHeightMM: CGFloat = 0
    for pageIndex in 0..<pageCount {
      guard let page = pdfDocument.getPage(at: pageIndex) else { continue }
      let bounds = page.bounds(for: .mediaBox)
      // Scale height to match reference width (maintaining aspect ratio)
      let pageWidthMM = bounds.width * pointsToMM
      let pageHeightMM = bounds.height * pointsToMM
      let scaledHeightMM = (referenceWidthMM / pageWidthMM) * pageHeightMM
      totalHeightMM += scaledHeightMM
      if pageIndex < pageCount - 1 {
        totalHeightMM += pageSpacingMM
      }
    }

    // Ensure minimum size of 1mm as required by SDK.
    let width = max(referenceWidthMM, 1.0)
    let height = max(totalHeightMM, 1.0)

    return CGSize(width: width, height: height)
  }

  private func deriveDisplayName(from sourceFileName: String) -> String {
    let lowercased = sourceFileName.lowercased()
    if lowercased.hasSuffix(".pdf") {
      return String(sourceFileName.dropLast(4))
    }
    return sourceFileName
  }
}

// MARK: - PDFNoteStorage

enum PDFNoteStorage {
  static let pdfNotesFolderName = "PDFNotes"

  static func pdfNotesDirectory() async throws -> URL {
    return try await pdfNotesDirectoryImpl()
  }

  static func documentDirectory(for documentID: UUID) async throws -> URL {
    return try await documentDirectoryImpl(for: documentID)
  }
}
