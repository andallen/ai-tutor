// PDFDocumentLifecycleContract.swift
// API Contract for PDF Document Lifecycle Integration
//
// This file defines the complete specification for integrating PDF documents
// into the app's navigation flow. It enables opening imported PDF documents
// from the Dashboard through to the PDFDocumentViewController.
//
// Architecture:
//   DashboardView
//     |
//     +-- NotebookLibrary.openPDFDocument()
//           |
//           +-- Loads NoteDocument manifest
//           +-- Loads PDFDocument from source.pdf
//           +-- Creates PDFDocumentHandle
//           |
//           v
//   PDFDocumentSession (returned to DashboardView)
//     |
//     v
//   PDFEditorHostView (UIViewControllerRepresentable)
//     |
//     +-- Creates PDFDocumentViewController
//     +-- Configures with documentHandle
//     +-- Wraps in UINavigationController
//
// Test writers can implement tests from this contract without ambiguity.

import CoreGraphics
import Foundation
import PDFKit
import SwiftUI
import UIKit

// MARK: - PDF Document Opening Result

// Result of opening a PDF document.
// Contains all components needed to create a PDFDocumentSession.
struct PDFDocumentOpenResult {
  // Actor handle managing the opened PDF document and MyScript annotations.
  let handle: PDFDocumentHandle

  // The loaded NoteDocument metadata.
  let noteDocument: NoteDocument

  // The loaded PDFDocument for rendering pages.
  let pdfDocument: PDFDocument

  // The MyScript package containing annotation parts for all pages.
  let package: any ContentPackageProtocol
}

// MARK: - PDFDocumentSession

// Represents an open PDF document editing session.
// Identifiable for use with SwiftUI fullScreenCover.
// Contains all data needed to present PDFDocumentViewController.
// Mirrors the NotebookSession pattern for consistency.
struct PDFDocumentSession: Identifiable {
  // Unique identifier for the session, matches the document ID.
  let id: String

  // Actor handle managing the opened PDF document and MyScript annotations.
  // Provides access to MyScript parts for ink input.
  let handle: PDFDocumentHandle

  // The loaded NoteDocument metadata.
  // Included separately because PDFDocumentHandle is an actor and
  // accessing its noteDocument property requires async.
  let noteDocument: NoteDocument

  // The loaded PDFDocument for rendering pages.
  // Included separately to avoid async access requirements.
  let pdfDocument: PDFDocument
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentSession

 SCENARIO: Create session from opened PDF document
 GIVEN: A valid PDFDocumentHandle, NoteDocument, and PDFDocument
 WHEN: PDFDocumentSession is created
 THEN: id matches noteDocument.documentID
  AND: handle is stored for MyScript operations
  AND: noteDocument is stored for UI display
  AND: pdfDocument is stored for page rendering
  AND: Session is Identifiable for SwiftUI binding

 SCENARIO: Session used with fullScreenCover
 GIVEN: An optional PDFDocumentSession binding
 WHEN: The session is non-nil
 THEN: fullScreenCover presents PDFEditorHostView
  AND: Session's id is used for view identity
*/

/*
 EDGE CASES: PDFDocumentSession

 EDGE CASE: Empty document ID
 GIVEN: A NoteDocument with empty string documentID
 WHEN: PDFDocumentSession is created
 THEN: Session id is empty string (invalid state, caller responsibility to validate)

 EDGE CASE: Session equality
 GIVEN: Two PDFDocumentSession instances with the same id
 WHEN: Compared via Identifiable
 THEN: They are considered the same for SwiftUI diffing purposes
*/

// MARK: - PDFDocumentLifecycleError

// Errors that can occur when opening or managing PDF documents.
// Provides specific information about each failure mode.
// Equatable for testing assertions.
enum PDFDocumentLifecycleError: LocalizedError, Equatable {
  // The manifest file (document.json) was not found in the document directory.
  case manifestNotFound(documentID: UUID)

  // The manifest file could not be decoded as valid JSON.
  case manifestDecodingFailed(documentID: UUID, reason: String)

  // The PDF file (source.pdf) was not found in the document directory.
  case pdfNotFound(documentID: UUID)

  // The PDF file could not be opened or is corrupted.
  case pdfLoadFailed(documentID: UUID, reason: String)

  // Failed to create the PDFDocumentHandle.
  case handleCreationFailed(documentID: UUID, reason: String)

  // The document directory does not exist.
  case documentDirectoryNotFound(documentID: UUID)

  // The MyScript package file (annotations.iink) was not found.
  case packageNotFound(documentID: UUID)

  // The MyScript package could not be loaded.
  case packageLoadFailed(documentID: UUID, reason: String)

  // The MyScript engine is not available.
  case engineNotAvailable(documentID: UUID)

  var errorDescription: String? {
    switch self {
    case .manifestNotFound(let documentID):
      return "Document manifest not found for \(documentID.uuidString)."
    case .manifestDecodingFailed(let documentID, let reason):
      return "Failed to read document manifest for \(documentID.uuidString): \(reason)"
    case .pdfNotFound(let documentID):
      return "PDF file not found for document \(documentID.uuidString)."
    case .pdfLoadFailed(let documentID, let reason):
      return "Failed to load PDF for \(documentID.uuidString): \(reason)"
    case .handleCreationFailed(let documentID, let reason):
      return "Failed to open document \(documentID.uuidString): \(reason)"
    case .documentDirectoryNotFound(let documentID):
      return "Document directory not found for \(documentID.uuidString)."
    case .packageNotFound(let documentID):
      return "MyScript package not found for document \(documentID.uuidString)."
    case .packageLoadFailed(let documentID, let reason):
      return "Failed to load MyScript package for \(documentID.uuidString): \(reason)"
    case .engineNotAvailable(let documentID):
      return "MyScript engine not available for document \(documentID.uuidString)."
    }
  }

  // Equatable conformance for associated values.
  static func == (lhs: PDFDocumentLifecycleError, rhs: PDFDocumentLifecycleError) -> Bool {
    switch (lhs, rhs) {
    case (.manifestNotFound(let lhsID), .manifestNotFound(let rhsID)):
      return lhsID == rhsID
    case (
      .manifestDecodingFailed(let lhsID, let lhsReason),
      .manifestDecodingFailed(let rhsID, let rhsReason)
    ):
      return lhsID == rhsID && lhsReason == rhsReason
    case (.pdfNotFound(let lhsID), .pdfNotFound(let rhsID)):
      return lhsID == rhsID
    case (.pdfLoadFailed(let lhsID, let lhsReason), .pdfLoadFailed(let rhsID, let rhsReason)):
      return lhsID == rhsID && lhsReason == rhsReason
    case (
      .handleCreationFailed(let lhsID, let lhsReason),
      .handleCreationFailed(let rhsID, let rhsReason)
    ):
      return lhsID == rhsID && lhsReason == rhsReason
    case (.documentDirectoryNotFound(let lhsID), .documentDirectoryNotFound(let rhsID)):
      return lhsID == rhsID
    case (.packageNotFound(let lhsID), .packageNotFound(let rhsID)):
      return lhsID == rhsID
    case (
      .packageLoadFailed(let lhsID, let lhsReason),
      .packageLoadFailed(let rhsID, let rhsReason)
    ):
      return lhsID == rhsID && lhsReason == rhsReason
    case (.engineNotAvailable(let lhsID), .engineNotAvailable(let rhsID)):
      return lhsID == rhsID
    default:
      return false
    }
  }
}

/*
 ACCEPTANCE CRITERIA: PDFDocumentLifecycleError

 SCENARIO: Error provides localized description
 GIVEN: Any PDFDocumentLifecycleError case
 WHEN: errorDescription is accessed
 THEN: A non-nil user-facing message is returned
  AND: The message includes the document ID for debugging

 SCENARIO: Error equality for same case
 GIVEN: Two manifestNotFound errors with the same documentID
 WHEN: Compared for equality
 THEN: They are equal

 SCENARIO: Error equality for different cases
 GIVEN: manifestNotFound and pdfNotFound with the same documentID
 WHEN: Compared for equality
 THEN: They are not equal
*/

// MARK: - PDFEditorHostView

// PDFEditorHostView is implemented in InkOS/App/PDFEditorHostView.swift.
// It follows the EditorHostView pattern for consistency.

/*
 ACCEPTANCE CRITERIA: PDFEditorHostView.makeUIViewController

 SCENARIO: Successfully create PDF editor
 GIVEN: A valid PDFDocumentSession with noteDocument and pdfDocument
 WHEN: makeUIViewController is called
 THEN: PDFDocumentViewController is created with noteDocument and pdfDocument
  AND: configure(documentHandle:) is called with session.handle
  AND: The controller is wrapped in UINavigationController
  AND: The navigation controller is returned

 SCENARIO: PDF editor with valid document
 GIVEN: A NoteDocument with 3 pdfPage blocks
  AND: A PDFDocument with 3 pages
 WHEN: makeUIViewController creates PDFDocumentViewController
 THEN: No error is thrown during initialization
  AND: The controller displays the PDF pages

 SCENARIO: PDF editor initialization fails
 GIVEN: A NoteDocument with empty blocks array
 WHEN: makeUIViewController attempts to create PDFDocumentViewController
 THEN: PDFDocumentError.emptyDocument is thrown
  AND: An error view controller is returned instead
  AND: The error message is displayed to the user

 SCENARIO: PDF editor initialization with mismatched data
 GIVEN: A NoteDocument referencing pageIndex 5
  AND: A PDFDocument with only 3 pages
 WHEN: makeUIViewController attempts to create PDFDocumentViewController
 THEN: PDFDocumentError.pageIndexOutOfBounds is thrown
  AND: An error view controller is returned instead
*/

/*
 EDGE CASES: PDFEditorHostView

 EDGE CASE: Document handle already closed
 GIVEN: A session where handle.close() was already called
 WHEN: makeUIViewController is called
 THEN: PDFDocumentViewController is created
  AND: Ink operations will fail when attempted
  AND: User sees appropriate error when trying to draw

 EDGE CASE: Memory pressure
 GIVEN: A very large PDF (100+ pages)
 WHEN: PDFEditorHostView is presented
 THEN: Controller is created without loading all pages
  AND: Pages are loaded on-demand as user scrolls
*/

/*
 ACCEPTANCE CRITERIA: PDFEditorHostView.updateUIViewController

 SCENARIO: Update called with same session
 GIVEN: PDFEditorHostView is displayed
 WHEN: SwiftUI calls updateUIViewController
 THEN: No changes are made to the view controller
  AND: Document state is preserved

 SCENARIO: Session is immutable
 GIVEN: A PDFEditorHostView with a session
 WHEN: The session property is accessed after creation
 THEN: The session values are unchanged
  AND: Document editing state is maintained by the controller
*/

// MARK: - NotebookLibrary.openPDFDocument API

// Extension on NotebookLibrary adding PDF document opening capability.
// Follows the openNotebook pattern for consistency.

/*
 API SIGNATURE: NotebookLibrary.openPDFDocument

 extension NotebookLibrary {
   // Opens a PDF document for editing.
   // Loads the manifest and PDF file from the document directory.
   // Creates a PDFDocumentHandle for MyScript annotation access.
   //
   // documentID: The UUID of the PDF document to open.
   //
   // Returns: PDFDocumentOpenResult containing:
   //   - handle: PDFDocumentHandle for ink operations
   //   - noteDocument: The loaded NoteDocument metadata
   //   - pdfDocument: The loaded PDFDocument for rendering
   //
   // Throws: PDFDocumentLifecycleError on failure.
   func openPDFDocument(documentID: UUID) async throws -> PDFDocumentOpenResult
 }
*/

/*
 ACCEPTANCE CRITERIA: NotebookLibrary.openPDFDocument

 SCENARIO: Successfully open PDF document
 GIVEN: A document directory at PDFNoteStorage.documentDirectory(for: documentID)
  AND: The directory contains document.json (valid NoteDocument)
  AND: The directory contains source.pdf (valid PDFDocument)
  AND: The directory contains annotations.iink (MyScript package)
 WHEN: openPDFDocument(documentID:) is called
 THEN: The manifest is loaded and decoded as NoteDocument
  AND: The PDF file is loaded as PDFDocument
  AND: A PDFDocumentHandle is created with the directory and noteDocument
  AND: PDFDocumentOpenResult containing handle, noteDocument, and pdfDocument is returned
  AND: No error is thrown

 SCENARIO: Document directory does not exist
 GIVEN: No directory exists at PDFNoteStorage.documentDirectory(for: documentID)
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.documentDirectoryNotFound is thrown
  AND: The error includes the documentID

 SCENARIO: Manifest file not found
 GIVEN: The document directory exists
  AND: document.json is missing
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.manifestNotFound is thrown
  AND: The error includes the documentID

 SCENARIO: Manifest file invalid JSON
 GIVEN: The document directory contains document.json
  AND: The file contains invalid JSON
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.manifestDecodingFailed is thrown
  AND: The error includes the documentID and reason

 SCENARIO: Manifest file wrong schema
 GIVEN: The document directory contains document.json
  AND: The file is valid JSON but wrong structure
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.manifestDecodingFailed is thrown
  AND: The error reason describes the decoding failure

 SCENARIO: PDF file not found
 GIVEN: The document directory contains valid document.json
  AND: source.pdf is missing
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.pdfNotFound is thrown
  AND: The error includes the documentID

 SCENARIO: PDF file corrupted
 GIVEN: The document directory contains valid document.json
  AND: source.pdf exists but is corrupted (not a valid PDF)
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.pdfLoadFailed is thrown
  AND: The error includes the documentID and reason

 SCENARIO: Handle creation fails
 GIVEN: The document directory contains valid document.json and source.pdf
  AND: annotations.iink is missing or corrupted
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.handleCreationFailed is thrown
  AND: The error includes the documentID and underlying reason

 SCENARIO: Engine not available during handle creation
 GIVEN: The document directory is valid
  AND: MyScript engine is not initialized
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.handleCreationFailed is thrown
  AND: The error reason indicates engine unavailability
*/

/*
 EDGE CASES: NotebookLibrary.openPDFDocument

 EDGE CASE: Open same document twice
 GIVEN: A PDF document that is already open (handle exists)
 WHEN: openPDFDocument(documentID:) is called again
 THEN: A new handle is created
  AND: Both handles reference the same file
  AND: No data corruption occurs
  NOTE: Caller responsibility to manage handle lifecycle

 EDGE CASE: Open immediately after import
 GIVEN: ImportCoordinator just created the document
 WHEN: openPDFDocument(documentID:) is called
 THEN: Document opens successfully
  AND: All files are present and valid

 EDGE CASE: Document directory exists but empty
 GIVEN: An empty directory at the document path
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.manifestNotFound is thrown

 EDGE CASE: PDF file is zero bytes
 GIVEN: source.pdf exists but has zero size
 WHEN: openPDFDocument(documentID:) is called
 THEN: PDFDocumentLifecycleError.pdfLoadFailed is thrown
  AND: The reason indicates the PDF is invalid

 EDGE CASE: Concurrent open operations
 GIVEN: Two openPDFDocument calls for different documents
 WHEN: Both are called concurrently
 THEN: Both complete successfully
  AND: No race conditions occur
  AND: Each returns the correct document data
*/

// MARK: - DashboardView Navigation State

// Additional state properties needed in DashboardView for PDF document navigation.
// Mirrors the activeSession pattern used for NotebookSession.

/*
 API SIGNATURE: DashboardView PDF Navigation State

 struct DashboardView: View {
   // Existing state...

   // Opens a PDF document session when a PDF document is tapped.
   @State private var activePDFSession: PDFDocumentSession?
 }
*/

/*
 ACCEPTANCE CRITERIA: DashboardView PDF Navigation

 SCENARIO: Open PDF document from dashboard
 GIVEN: DashboardView is displayed
  AND: A PDF document item is shown in the grid
 WHEN: User taps the PDF document item
 THEN: openPDFDocument(documentID:) is called
  AND: On success, activePDFSession is set with the returned data
  AND: fullScreenCover presents PDFEditorHostView

 SCENARIO: PDF document open failure
 GIVEN: DashboardView is displayed
  AND: User taps a PDF document
 WHEN: openPDFDocument(documentID:) throws an error
 THEN: activePDFSession remains nil
  AND: openErrorMessage is set with the error description
  AND: Error alert is displayed to the user

 SCENARIO: Dismiss PDF editor
 GIVEN: PDFEditorHostView is presented via fullScreenCover
 WHEN: User taps back/home button in the editor
 THEN: The editor calls prepareForExit
  AND: Document handle is closed
  AND: fullScreenCover is dismissed
  AND: activePDFSession becomes nil
  AND: Dashboard is visible again
*/

/*
 EDGE CASES: DashboardView PDF Navigation

 EDGE CASE: Open PDF while notebook is open
 GIVEN: activeSession is non-nil (notebook is open)
 WHEN: User somehow triggers openPDFDocument
 THEN: Operation proceeds
  AND: activePDFSession is set
  NOTE: UI should prevent this scenario

 EDGE CASE: Rapid tap on PDF document
 GIVEN: User taps PDF document quickly multiple times
 WHEN: openPDFDocument is called
 THEN: Only one open operation proceeds
  AND: No duplicate sessions are created

 EDGE CASE: PDF document deleted while opening
 GIVEN: User taps PDF document
  AND: Document is deleted by another process during load
 WHEN: openPDFDocument is executing
 THEN: Error is thrown
  AND: User sees error message
  AND: Dashboard refreshes to remove the deleted item
*/

// MARK: - DashboardSheetModifiers Extension

// Additional fullScreenCover modifier for PDF document sessions.
// Added to DashboardSheetModifiers alongside the existing notebook session cover.

/*
 API SIGNATURE: DashboardSheetModifiers PDF Cover

 struct DashboardSheetModifiers: ViewModifier {
   // Existing bindings...

   @Binding var activePDFSession: PDFDocumentSession?

   func body(content: Content) -> some View {
     content
       // Existing modifiers...
       .fullScreenCover(
         item: $activePDFSession,
         onDismiss: {
           activePDFSession = nil
         },
         content: { session in
           PDFEditorHostView(session: session)
         }
       )
   }
 }
*/

/*
 ACCEPTANCE CRITERIA: DashboardSheetModifiers PDF Cover

 SCENARIO: Present PDF editor when session is set
 GIVEN: activePDFSession is nil
 WHEN: activePDFSession is set to a valid session
 THEN: fullScreenCover animates in
  AND: PDFEditorHostView is displayed
  AND: Editor shows the PDF document

 SCENARIO: Dismiss PDF editor
 GIVEN: PDFEditorHostView is presented
 WHEN: The cover is dismissed (user action)
 THEN: onDismiss callback fires
  AND: activePDFSession is set to nil
  AND: Cover animates out
  AND: Dashboard is visible

 SCENARIO: Multiple sessions handling
 GIVEN: Both activeSession (notebook) and activePDFSession bindings exist
 WHEN: Only activePDFSession is non-nil
 THEN: PDF editor is presented
  AND: Notebook session cover is not triggered
*/

// MARK: - File Path Constants

// Constants for file names used in PDF document storage.
// Centralized for consistency with ImportCoordinator.

/*
 FILE PATH CONSTANTS (from ImportCoordinator):

 ImportCoordinator.manifestFileName = "document.json"
 ImportCoordinator.pdfFileName = "source.pdf"
 ImportCoordinator.iinkFileName = "annotations.iink"
*/

// MARK: - Integration Sequence

/*
 PDF DOCUMENT LIFECYCLE SEQUENCE:

 1. User imports PDF via ImportCoordinator
    - Creates document directory at PDFNoteStorage.documentDirectory(for: documentID)
    - Copies source.pdf
    - Creates document.json (NoteDocument)
    - Creates annotations.iink (MyScript package)

 2. Dashboard displays imported PDF
    - NotebookLibrary lists PDF documents (future: listPDFDocuments)
    - PDF document appears in dashboard grid (future: DashboardItem.pdfDocument)

 3. User taps PDF document in dashboard
    - DashboardView calls openPDFDocument(documentID:)
    - NotebookLibrary loads manifest, PDF, creates handle
    - Returns (handle, noteDocument, pdfDocument)

 4. DashboardView creates session and presents editor
    - Creates PDFDocumentSession with returned data
    - Sets activePDFSession state
    - fullScreenCover presents PDFEditorHostView

 5. PDFEditorHostView creates view controller
    - Creates PDFDocumentViewController(noteDocument:pdfDocument:)
    - Calls configure(documentHandle:)
    - Wraps in UINavigationController
    - User can draw on PDF pages

 6. User dismisses editor
    - Taps home/back button
    - PDFDocumentViewController.prepareForExit() called
    - Document handle closed (saves any changes)
    - fullScreenCover dismissed
    - activePDFSession set to nil
    - Dashboard visible again

 DEPENDENCIES:

 - PDFNoteStorage: Provides document directory paths
 - ImportCoordinator: File name constants (manifestFileName, pdfFileName)
 - PDFDocumentHandle: Actor managing opened document
 - PDFDocumentViewController: UIViewController for PDF editing
 - NoteDocument: Codable metadata struct
 - PDFDocument: PDFKit document for rendering
*/

// MARK: - Error View Controller Specification

/*
 ERROR VIEW CONTROLLER SPECIFICATION:

 When PDFDocumentViewController initialization fails in PDFEditorHostView,
 an error view controller should be returned instead of crashing.

 Requirements:
 1. Display error icon (system symbol "exclamationmark.triangle")
 2. Display error message (error.localizedDescription)
 3. Display "Go Back" button
 4. Button dismisses the fullScreenCover

 Appearance:
 - Centered content
 - Error icon: 48pt, red tint
 - Error message: 16pt, system font, gray, multiline, centered
 - Button: standard system style

 This follows the pattern of graceful error handling rather than crashing.
*/

// MARK: - Thread Safety

/*
 THREAD SAFETY REQUIREMENTS:

 Main Thread:
 - DashboardView state updates
 - PDFEditorHostView makeUIViewController
 - PDFDocumentViewController initialization
 - UI presentation/dismissal

 Actor Isolation:
 - NotebookLibrary.openPDFDocument runs on MainActor
 - PDFDocumentHandle is an actor for file operations
 - PDFNoteStorage methods are async

 Async Flow:
 1. User taps PDF document (main thread)
 2. Task created for openPDFDocument (MainActor)
 3. File loading happens in async context
 4. PDFDocumentHandle creation may involve MyScript (MainActor for engine)
 5. Result returned to MainActor
 6. State update triggers UI (main thread)
*/

// MARK: - Memory Management

/*
 MEMORY MANAGEMENT:

 PDFDocumentSession Lifecycle:
 - Created when user opens document
 - Held by DashboardView state
 - Released when fullScreenCover dismissed
 - handle.close() called on dismiss

 PDFDocumentHandle Lifecycle:
 - Created by openPDFDocument
 - Stored in PDFDocumentSession
 - Reference passed to PDFDocumentViewController
 - Closed when editor is dismissed
 - Package saved before close

 PDFDocument Lifecycle:
 - Loaded from file during openPDFDocument
 - Stored in PDFDocumentSession
 - Passed to PDFDocumentViewController
 - Released when session is released
 - PDFKit handles internal page caching
*/

// MARK: - Testing Considerations

/*
 TESTING CONSIDERATIONS:

 Unit Tests:
 - Test PDFDocumentLifecycleError equality
 - Test PDFDocumentLifecycleError error descriptions
 - Test NotebookLibrary.openPDFDocument with mock file system
 - Test all error conditions

 Integration Tests:
 - Import PDF then open it
 - Open PDF, draw, close, reopen
 - Handle concurrent open/close operations

 UI Tests:
 - Tap PDF document in dashboard
 - Verify editor is presented
 - Verify PDF pages are visible
 - Dismiss editor and verify dashboard returns

 Mock Dependencies:
 - Mock FileManager for file system operations
 - Mock PDFDocument for testing without real PDFs
 - Mock PDFDocumentHandle for testing without MyScript
*/
