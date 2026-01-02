// PDFEditorViewModel.swift
// Manages the PDF editing session with single-part architecture.
// Coordinates between the PDF document, MyScript engine, and UI components.

import Combine
import PDFKit
import UIKit

// Manages PDF editor state and coordinates document lifecycle.
@MainActor
final class PDFEditorViewModel: ObservableObject {

  // The active PDF session containing document and handle.
  let session: PDFDocumentSession

  // Layout information for stacked PDF pages.
  let pageLayout: PDFPageLayout

  // Background renderer for PDF page images.
  let backgroundRenderer: PDFBackgroundRenderer

  // The loaded MyScript content part for annotations.
  private(set) var part: (any ContentPartProtocol)?

  // Engine provider for MyScript integration.
  private let engineProvider: any EngineProviderProtocol

  // Error message to display to user.
  @Published var errorMessage: String?

  // Whether the document is currently loading.
  @Published var isLoading: Bool = true

  // Creates a view model for the given PDF session.
  // session: The PDF document session from the dashboard.
  // engineProvider: Provider for MyScript engine. Defaults to shared instance.
  init(
    session: PDFDocumentSession,
    engineProvider: (any EngineProviderProtocol)? = nil
  ) {
    self.session = session
    self.engineProvider = engineProvider ?? EngineProvider.sharedInstance

    // Calculate page layout based on screen width.
    let screenWidth = UIScreen.main.bounds.width
    self.pageLayout = PDFPageLayout(pdfDocument: session.pdfDocument, targetWidth: screenWidth)

    // Set up background renderer with document and layout.
    self.backgroundRenderer = PDFBackgroundRenderer()
    self.backgroundRenderer.pdfDocument = session.pdfDocument
    self.backgroundRenderer.pageLayout = pageLayout
  }

  // Total content size for the scrollable area.
  // Height includes all pages stacked vertically.
  var totalContentSize: CGSize {
    CGSize(width: pageLayout.pageWidth, height: pageLayout.totalContentHeight)
  }

  // Number of pages in the PDF document.
  var pageCount: Int {
    return pageLayout.pageCount
  }

  // Loads the MyScript part for annotations.
  // Should be called after the editor is ready.
  func loadPart() async throws {
    isLoading = true
    defer { isLoading = false }

    do {
      // Get the single part from the handle.
      // All pages share this one part.
      guard let firstBlock = session.noteDocument.blocks.first else {
        throw PDFEditorError.noBlocksInDocument
      }

      let partID = firstBlock.myScriptPartID
      part = try await session.handle.part(for: partID)
    } catch {
      errorMessage = error.localizedDescription
      throw error
    }
  }

  // Saves the current annotations.
  func save() async throws {
    do {
      try await session.handle.savePackage()
    } catch {
      errorMessage = "Failed to save: \(error.localizedDescription)"
      throw error
    }
  }

  // Closes the document and releases resources.
  func close() async {
    await session.handle.close()
  }
}

// Errors specific to the PDF editor.
enum PDFEditorError: LocalizedError {
  case noBlocksInDocument
  case engineNotAvailable
  case partLoadFailed(reason: String)

  var errorDescription: String? {
    switch self {
    case .noBlocksInDocument:
      return "The PDF document has no annotation blocks."
    case .engineNotAvailable:
      return "The annotation engine is not available."
    case .partLoadFailed(let reason):
      return "Failed to load annotations: \(reason)"
    }
  }
}
