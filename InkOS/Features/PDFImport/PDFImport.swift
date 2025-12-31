// PDFImport.swift
// Implementation for PDF Data Model & Ingestion Pipeline.
// This file contains the working implementations for types defined in Contract.swift.

import Foundation
import PDFKit

// MARK: - PDFNoteStorage Implementation

extension PDFNoteStorage {
  // Returns the URL to the folder where PDF note documents are stored.
  // Creates the folder if it does not exist.
  static func pdfNotesDirectoryImpl() async throws -> URL {
    let fileManager = FileManager.default

    // Get the Documents directory.
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw ImportError.destinationDirectoryCreationFailed(underlyingError: "Could not access Documents directory")
    }

    // Build path to PDFNotes folder.
    let pdfNotesURL = documentsURL.appendingPathComponent(pdfNotesFolderName)

    // Create directory if it doesn't exist.
    if !fileManager.fileExists(atPath: pdfNotesURL.path) {
      do {
        try fileManager.createDirectory(at: pdfNotesURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        throw ImportError.destinationDirectoryCreationFailed(underlyingError: error.localizedDescription)
      }
    }

    return pdfNotesURL
  }

  // Returns the URL to a specific document's directory.
  // Does not create the directory; caller must create it.
  static func documentDirectoryImpl(for documentID: UUID) async throws -> URL {
    let pdfNotesURL = try await pdfNotesDirectoryImpl()
    return pdfNotesURL.appendingPathComponent(documentID.uuidString)
  }
}

// MARK: - PDFDocumentWrapper

// Wrapper that makes PDFKit's PDFDocument conform to PDFDocumentProtocol.
// Marked @unchecked Sendable because PDFDocument is thread-safe for reading.
final class PDFDocumentWrapper: PDFDocumentProtocol, @unchecked Sendable {
  private let pdfDocument: PDFDocument

  init(_ pdfDocument: PDFDocument) {
    self.pdfDocument = pdfDocument
  }

  var pageCount: Int {
    return pdfDocument.pageCount
  }

  var isLocked: Bool {
    return pdfDocument.isLocked
  }

  var isEncrypted: Bool {
    return pdfDocument.isEncrypted
  }

  func unlock(withPassword password: String) -> Bool {
    return pdfDocument.unlock(withPassword: password)
  }
}

// MARK: - PDFDocumentFactory Implementation

extension PDFDocumentFactory {
  // Creates a PDFDocument from the given URL using PDFKit.
  func createPDFDocumentImpl(from url: URL) -> (any PDFDocumentProtocol)? {
    guard let pdfDocument = PDFDocument(url: url) else {
      return nil
    }
    return PDFDocumentWrapper(pdfDocument)
  }
}

