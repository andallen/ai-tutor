// PDFDocumentHandle.swift
// Actor managing the lifecycle of an opened PDF note document.
// Provides access to MyScript parts by myScriptPartID lookup.

import Foundation

// Protocol for PDF document handles.
protocol PDFDocumentHandleProtocol: Actor {
  var documentID: UUID { get }
  var noteDocument: NoteDocument { get }
  func part(for myScriptPartID: String) async throws -> any ContentPartProtocol
  func savePackage() async throws
  func close() async
}

// Errors specific to PDF documents.
enum PDFDocumentError: LocalizedError {
  case emptyDocument
  case pageIndexOutOfBounds(blockIndex: Int, pageIndex: Int, pdfPageCount: Int)
  case engineNotAvailable
  case partNotFound(myScriptPartID: String)

  var errorDescription: String? {
    switch self {
    case .emptyDocument:
      return "Document has no pages."
    case .pageIndexOutOfBounds(let blockIndex, let pageIndex, let pdfPageCount):
      return "Block \(blockIndex) references page \(pageIndex) but PDF has only \(pdfPageCount) pages."
    case .engineNotAvailable:
      return "MyScript engine is not available."
    case .partNotFound(let myScriptPartID):
      return "Part not found: \(myScriptPartID)"
    }
  }
}

// Actor managing an opened PDF note document with MyScript annotation support.
// Follows the DocumentHandle pattern but adapted for multi-part PDF documents.
// Each block in the NoteDocument has its own MyScript part for annotations.
actor PDFDocumentHandle: PDFDocumentHandleProtocol {

  // Unique identifier for this document.
  let documentID: UUID

  // The loaded NoteDocument metadata.
  let noteDocument: NoteDocument

  // The document directory URL.
  private let documentDirectory: URL

  // Path to the iink package file.
  private let packagePath: String

  // The opened content package.
  private var package: (any ContentPackageProtocol)?

  // Cache of parts by their identifier for fast lookup.
  private var partCache: [String: any ContentPartProtocol] = [:]

  // Flag indicating whether the handle has been closed.
  private var isClosed = false

  // File name constants.
  private static let iinkFileName = "annotations.iink"

  // Creates a handle and opens the iink package.
  // documentDirectory: The directory containing the PDF note document.
  // noteDocument: The loaded NoteDocument metadata.
  // engineProvider: Optional engine provider for dependency injection. Defaults to shared instance.
  init(
    documentDirectory: URL,
    noteDocument: NoteDocument,
    engineProvider: (any EngineProviderProtocol)? = nil
  ) async throws {
    self.documentID = noteDocument.documentID
    self.noteDocument = noteDocument
    self.documentDirectory = documentDirectory
    self.packagePath = documentDirectory.appendingPathComponent(Self.iinkFileName).path

    // Open the package on MainActor because the engine is not thread-safe.
    self.package = try await MainActor.run {
      let provider = engineProvider ?? EngineProvider.sharedInstance
      guard let engine = provider.engineInstance else {
        throw PDFDocumentError.engineNotAvailable
      }
      do {
        // Open existing package for reading and writing.
        let openedPackage = try engine.openContentPackage(packagePath, openOption: .existing)
        return openedPackage
      } catch {
        throw PDFDocumentHandleError.packageOpenFailed(underlyingError: error)
      }
    }

    // Build the part cache from the package.
    try await buildPartCache()
  }

  // Builds the part cache by iterating through all parts in the package.
  private func buildPartCache() async throws {
    guard let capturedPackage = package else { return }

    let partCount = await MainActor.run {
      capturedPackage.getPartCount()
    }

    for index in 0..<partCount {
      let partResult: (identifier: String, part: any ContentPartProtocol)? = await MainActor.run {
        do {
          let part = try capturedPackage.getPart(at: index)
          return (part.identifier, part)
        } catch {
          return nil
        }
      }

      if let result = partResult {
        partCache[result.identifier] = result.part
      }
    }
  }

  // Retrieves the MyScript content part for a specific part identifier.
  // myScriptPartID: The identifier stored in NoteBlock.
  // Returns the ContentPartProtocol for that part.
  // Throws PDFDocumentError.partNotFound if not found.
  func part(for myScriptPartID: String) async throws -> any ContentPartProtocol {
    guard !isClosed else {
      throw PDFDocumentHandleError.handleClosed
    }

    // Check cache first.
    if let cachedPart = partCache[myScriptPartID] {
      return cachedPart
    }

    // Part not found in cache.
    throw PDFDocumentError.partNotFound(myScriptPartID: myScriptPartID)
  }

  // Saves the MyScript package to persistent storage.
  // Should be called after ink modifications.
  func savePackage() async throws {
    guard !isClosed else {
      throw PDFDocumentHandleError.handleClosed
    }

    guard let capturedPackage = package else {
      throw PDFDocumentHandleError.packageNotAvailable
    }

    try await MainActor.run {
      try capturedPackage.savePackage()
    }
  }

  // Closes the document handle and releases resources.
  // Package is saved before closing if there are unsaved changes.
  func close() async {
    guard !isClosed else { return }

    // Try to save before closing.
    do {
      try await savePackage()
    } catch {
      // Ignore save errors during close.
    }

    // Clear the package reference.
    package = nil
    partCache.removeAll()
    isClosed = true
  }
}

// Errors specific to PDFDocumentHandle operations.
enum PDFDocumentHandleError: LocalizedError {
  case packageOpenFailed(underlyingError: Error)
  case packageNotAvailable
  case handleClosed

  var errorDescription: String? {
    switch self {
    case .packageOpenFailed(let error):
      return "Failed to open annotation package: \(error.localizedDescription)"
    case .packageNotAvailable:
      return "Annotation package is not available."
    case .handleClosed:
      return "Document handle has been closed."
    }
  }
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentHandle

 SCENARIO: Retrieve part by identifier
 GIVEN: A PDF document with 3 pages
  AND: Each page has a corresponding MyScript part
 WHEN: part(for: "validPartID") is called
 THEN: Returns the correct ContentPartProtocol

 SCENARIO: Part not found
 GIVEN: A PDF document handle
 WHEN: part(for: "nonexistentID") is called
 THEN: Throws PDFDocumentError.partNotFound("nonexistentID")

 SCENARIO: Save package
 GIVEN: A PDF document with ink modifications
 WHEN: savePackage() is called
 THEN: Changes are persisted to the .iink file

 SCENARIO: Close document
 GIVEN: An open PDF document handle
 WHEN: close() is called
 THEN: Resources are released
  AND: Subsequent calls to part() throw an error
*/
