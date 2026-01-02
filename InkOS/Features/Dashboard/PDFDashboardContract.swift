// PDFDashboardContract.swift
// API Contract for PDF Dashboard Integration
//
// This file defines the complete specification for displaying PDF documents
// in the Dashboard grid alongside notebooks and folders. It serves as the bridge
// between requirements and tests, enabling test-driven development.
// Test writers can implement tests from this contract without ambiguity.

import Foundation
import SwiftUI

// MARK: - PDFDocumentMetadata

// Implemented in DashboardComponents.swift
// Lightweight struct for displaying PDF documents in the Dashboard grid.
// Contains only the information needed for listing and sorting, not editing.
// Mirrors NotebookMetadata and FolderMetadata patterns for consistency.
// Identifiable for use in SwiftUI Lists and ForEach.
// Sendable for safe passing across actor boundaries.
// Equatable for testing assertions and comparison.
//
// Properties:
//   id: String - Unique identifier for this PDF document (documentID.uuidString)
//   displayName: String - Display name shown to the user
//   sourceFileName: String - Original filename of the imported PDF
//   createdAt: Date - Timestamp when the document was created
//   modifiedAt: Date - Timestamp when the document was last modified
//   pageCount: Int - Total number of pages (counting only pdfPage blocks)
//   previewImageData: Data? - Cached preview image data for first page

/*
 ACCEPTANCE CRITERIA: PDFDocumentMetadata

 SCENARIO: Create metadata from NoteDocument
 GIVEN: A NoteDocument with documentID, displayName, sourceFileName, dates, and 5 pdfPage blocks
 WHEN: PDFDocumentMetadata is created from this document
 THEN: id equals documentID.uuidString
  AND: displayName matches the document's displayName
  AND: sourceFileName matches the document's sourceFileName
  AND: createdAt matches the document's createdAt
  AND: modifiedAt matches the document's modifiedAt
  AND: pageCount equals 5

 SCENARIO: Page count excludes writing spacers
 GIVEN: A NoteDocument with 3 pdfPage blocks and 2 writingSpacer blocks
 WHEN: PDFDocumentMetadata is created
 THEN: pageCount equals 3
  AND: writingSpacer blocks are not counted

 SCENARIO: Equatable comparison
 GIVEN: Two PDFDocumentMetadata with identical values
 WHEN: Compared for equality
 THEN: They are equal

 GIVEN: Two PDFDocumentMetadata with different id values
 WHEN: Compared for equality
 THEN: They are not equal

 SCENARIO: Identifiable conformance
 GIVEN: A PDFDocumentMetadata instance
 WHEN: id property is accessed
 THEN: Returns the document ID string
*/

/*
 EDGE CASES: PDFDocumentMetadata

 EDGE CASE: Empty blocks array
 GIVEN: A NoteDocument with empty blocks array
 WHEN: PDFDocumentMetadata is created
 THEN: pageCount equals 0

 EDGE CASE: Only writing spacers
 GIVEN: A NoteDocument with only writingSpacer blocks
 WHEN: PDFDocumentMetadata is created
 THEN: pageCount equals 0

 EDGE CASE: Nil preview image
 GIVEN: A PDF document without a generated preview
 WHEN: PDFDocumentMetadata is created with previewImageData nil
 THEN: previewImageData is nil
  AND: Dashboard card shows placeholder icon

 EDGE CASE: Very long displayName
 GIVEN: A displayName with 500 characters
 WHEN: PDFDocumentMetadata is created
 THEN: displayName is stored without truncation
  AND: UI layer handles display truncation

 EDGE CASE: Special characters in displayName
 GIVEN: A displayName like "Report (2024) [Final]"
 WHEN: PDFDocumentMetadata is created
 THEN: Special characters are preserved
*/


// MARK: - DashboardItem Extension

// Extends DashboardItem enum to include PDF documents.
// The existing enum has cases for notebook and folder.
// This contract defines the pdfDocument case to be added.

/*
 API EXTENSION: DashboardItem

 New case to add:
   case pdfDocument(PDFDocumentMetadata)

 New computed properties to add:

   var isPDFDocument: Bool
   // Returns true if this item is a PDF document, false otherwise.

   var pdfDocumentMetadata: PDFDocumentMetadata?
   // Returns the PDF document metadata if this is a pdfDocument case, nil otherwise.

 Updated computed properties:

   var id: String
   // Extended to handle pdfDocument case.
   // Returns "pdf-\(metadata.id)" for pdfDocument case.
   // Prefix ensures no collision with notebook or folder IDs.

   var displayName: String
   // Extended to return metadata.displayName for pdfDocument case.

   var sortDate: Date?
   // Extended to return metadata.modifiedAt for pdfDocument case.
*/

/*
 ACCEPTANCE CRITERIA: DashboardItem.pdfDocument

 SCENARIO: Create PDF document item
 GIVEN: A PDFDocumentMetadata instance
 WHEN: DashboardItem.pdfDocument is created with this metadata
 THEN: The item wraps the metadata correctly

 SCENARIO: ID uniqueness with prefix
 GIVEN: A PDFDocumentMetadata with id "abc123"
 WHEN: DashboardItem.pdfDocument is created
 THEN: item.id equals "pdf-abc123"
  AND: Does not collide with notebook "notebook-abc123" or folder "folder-abc123"

 SCENARIO: Display name access
 GIVEN: A DashboardItem.pdfDocument with displayName "Q4 Report"
 WHEN: displayName is accessed
 THEN: Returns "Q4 Report"

 SCENARIO: Sort date access
 GIVEN: A DashboardItem.pdfDocument with modifiedAt of 2024-01-15
 WHEN: sortDate is accessed
 THEN: Returns the Date representing 2024-01-15

 SCENARIO: isPDFDocument returns true
 GIVEN: A DashboardItem.pdfDocument
 WHEN: isPDFDocument is accessed
 THEN: Returns true
  AND: isNotebook returns false
  AND: isFolder returns false

 SCENARIO: pdfDocumentMetadata extraction
 GIVEN: A DashboardItem.pdfDocument with specific metadata
 WHEN: pdfDocumentMetadata is accessed
 THEN: Returns the original PDFDocumentMetadata
  AND: All properties match the original

 SCENARIO: pdfDocumentMetadata on notebook
 GIVEN: A DashboardItem.notebook
 WHEN: pdfDocumentMetadata is accessed
 THEN: Returns nil

 SCENARIO: pdfDocumentMetadata on folder
 GIVEN: A DashboardItem.folder
 WHEN: pdfDocumentMetadata is accessed
 THEN: Returns nil
*/

/*
 EDGE CASES: DashboardItem.pdfDocument

 EDGE CASE: Sorting mixed item types
 GIVEN: Items including notebooks, folders, and PDF documents
 WHEN: Sorted by sortDate
 THEN: PDF documents sort correctly by modifiedAt
  AND: PDF documents with same date as folders sort after folders

 EDGE CASE: All type checks on pdfDocument
 GIVEN: A DashboardItem.pdfDocument
 WHEN: isFolder is checked
 THEN: Returns false
 WHEN: isNotebook is checked
 THEN: Returns false
 WHEN: isPDFDocument is checked
 THEN: Returns true

 EDGE CASE: Metadata extraction on wrong type
 GIVEN: A DashboardItem.notebook
 WHEN: pdfDocumentMetadata is accessed
 THEN: Returns nil (not crash)
 WHEN: notebookMetadata is accessed
 THEN: Returns the notebook metadata
*/


// MARK: - NotebookLibrary PDF Loading Extension

// Extends NotebookLibrary to load and manage PDF documents.
// PDF documents appear alongside notebooks and folders in the Dashboard.

/*
 API EXTENSION: NotebookLibrary

 New published property to add:
   @Published var pdfDocuments: [PDFDocumentMetadata]
   // List of PDF documents currently available.
   // Updated when loadPDFDocuments is called.

 New method to add:
   func loadPDFDocuments() async
   // Enumerates the PDFNotes/ directory and builds metadata for each document.
   // Reads document.json manifest from each subdirectory.
   // Populates the pdfDocuments array with results.
   // Errors are silently ignored to keep the app usable.

 Updated method:
   private func combineItems()
   // Extended to include PDF documents in the combined items array.
   // PDF documents appear alongside notebooks and folders.
   // Sorted by date with folders first, then by recency.

 Updated method:
   func loadBundles() async
   // Extended to also call loadPDFDocuments().
   // PDF documents are loaded in parallel with notebooks and folders.
*/

/*
 ACCEPTANCE CRITERIA: NotebookLibrary.loadPDFDocuments

 SCENARIO: Load PDF documents from empty directory
 GIVEN: PDFNotes/ directory exists but is empty
 WHEN: loadPDFDocuments is called
 THEN: pdfDocuments array is empty
  AND: No error is thrown

 SCENARIO: Load PDF documents from populated directory
 GIVEN: PDFNotes/ contains 3 document directories with valid manifests
 WHEN: loadPDFDocuments is called
 THEN: pdfDocuments contains 3 PDFDocumentMetadata items
  AND: Each metadata has correct id, displayName, pageCount

 SCENARIO: Skip invalid directories
 GIVEN: PDFNotes/ contains 2 valid documents and 1 directory without manifest
 WHEN: loadPDFDocuments is called
 THEN: pdfDocuments contains 2 items
  AND: Invalid directory is silently skipped
  AND: No error is thrown

 SCENARIO: Handle missing PDFNotes directory
 GIVEN: PDFNotes/ directory does not exist
 WHEN: loadPDFDocuments is called
 THEN: pdfDocuments array is empty
  AND: No error is thrown

 SCENARIO: Page count calculation
 GIVEN: A document with manifest containing 5 pdfPage blocks and 2 writingSpacer blocks
 WHEN: loadPDFDocuments reads this manifest
 THEN: The resulting metadata has pageCount 5

 SCENARIO: Preview image loading
 GIVEN: A document directory containing preview.png
 WHEN: loadPDFDocuments reads this directory
 THEN: The resulting metadata has non-nil previewImageData

 SCENARIO: Missing preview image
 GIVEN: A document directory without preview.png
 WHEN: loadPDFDocuments reads this directory
 THEN: The resulting metadata has nil previewImageData
*/

/*
 ACCEPTANCE CRITERIA: NotebookLibrary.combineItems (extended)

 SCENARIO: Combine all item types
 GIVEN: 2 notebooks, 1 folder, and 2 PDF documents
 WHEN: combineItems is called
 THEN: items array contains 5 DashboardItems
  AND: Items are sorted by date, most recent first
  AND: Folders appear before other types with same date

 SCENARIO: PDF documents in sorted order
 GIVEN: A PDF document modified today and a notebook accessed yesterday
 WHEN: combineItems is called
 THEN: PDF document appears before notebook in items array

 SCENARIO: Empty PDF documents array
 GIVEN: 2 notebooks and 0 PDF documents
 WHEN: combineItems is called
 THEN: items array contains only notebooks
  AND: No errors occur
*/

/*
 EDGE CASES: NotebookLibrary PDF Loading

 EDGE CASE: Corrupted manifest JSON
 GIVEN: A document directory with invalid JSON in document.json
 WHEN: loadPDFDocuments is called
 THEN: That document is skipped
  AND: Other valid documents are still loaded
  AND: No error is thrown to caller

 EDGE CASE: Manifest missing required fields
 GIVEN: A document.json missing the documentID field
 WHEN: loadPDFDocuments is called
 THEN: That document is skipped
  AND: Other valid documents are still loaded

 EDGE CASE: Very large preview image
 GIVEN: A preview.png file that is 50MB
 WHEN: loadPDFDocuments is called
 THEN: The image data is loaded (no size limit at this layer)
  AND: UI layer may choose to handle large images

 EDGE CASE: Concurrent loadBundles calls
 GIVEN: loadBundles is called twice in quick succession
 WHEN: Both calls complete
 THEN: pdfDocuments contains correct items
  AND: No duplicate items appear
  AND: No race conditions cause crashes

 EDGE CASE: Directory enumeration permission denied
 GIVEN: PDFNotes/ directory exists but is not readable
 WHEN: loadPDFDocuments is called
 THEN: pdfDocuments array is empty
  AND: No error is thrown to caller

 EDGE CASE: Non-directory file in PDFNotes/
 GIVEN: PDFNotes/ contains a regular file named "stray.txt"
 WHEN: loadPDFDocuments is called
 THEN: The file is ignored
  AND: Only valid document directories are processed
*/


// MARK: - PDFDocumentCard

// SwiftUI view for displaying a PDF document in the Dashboard grid.
// Mirrors NotebookCard design for visual consistency.
// Shows PDF icon, displayName, and page count.

/*
 API DEFINITION: PDFDocumentCard

 struct PDFDocumentCard: View {
   let metadata: PDFDocumentMetadata

   var body: some View
   // Renders a card with:
   // - Preview image or PDF placeholder icon
   // - Display name text
   // - Page count subtitle (e.g., "5 pages")
 }
*/

/*
 ACCEPTANCE CRITERIA: PDFDocumentCard

 SCENARIO: Display card with preview
 GIVEN: PDFDocumentMetadata with non-nil previewImageData
 WHEN: PDFDocumentCard is rendered
 THEN: Preview image is displayed in the card area
  AND: Display name appears below the card
  AND: Page count subtitle appears below the name

 SCENARIO: Display card without preview
 GIVEN: PDFDocumentMetadata with nil previewImageData
 WHEN: PDFDocumentCard is rendered
 THEN: PDF placeholder icon is displayed
  AND: Display name appears below the card
  AND: Page count subtitle appears below the name

 SCENARIO: Page count formatting - singular
 GIVEN: PDFDocumentMetadata with pageCount 1
 WHEN: PDFDocumentCard is rendered
 THEN: Subtitle shows "1 page" (singular)

 SCENARIO: Page count formatting - plural
 GIVEN: PDFDocumentMetadata with pageCount 5
 WHEN: PDFDocumentCard is rendered
 THEN: Subtitle shows "5 pages" (plural)

 SCENARIO: Page count formatting - zero
 GIVEN: PDFDocumentMetadata with pageCount 0
 WHEN: PDFDocumentCard is rendered
 THEN: Subtitle shows "0 pages"

 SCENARIO: Display name truncation
 GIVEN: PDFDocumentMetadata with a very long displayName
 WHEN: PDFDocumentCard is rendered
 THEN: Display name is truncated with ellipsis
  AND: Card does not expand beyond normal size

 SCENARIO: Card aspect ratio
 GIVEN: Any PDFDocumentMetadata
 WHEN: PDFDocumentCard is rendered
 THEN: Card maintains portrait aspect ratio matching NotebookCard
  AND: Aspect ratio is approximately 0.72 (width/height)
*/

/*
 EDGE CASES: PDFDocumentCard

 EDGE CASE: Large page count
 GIVEN: PDFDocumentMetadata with pageCount 1000
 WHEN: PDFDocumentCard is rendered
 THEN: Subtitle shows "1000 pages"
  AND: Text fits within subtitle area

 EDGE CASE: Empty displayName
 GIVEN: PDFDocumentMetadata with empty displayName
 WHEN: PDFDocumentCard is rendered
 THEN: Empty text area is shown
  AND: Layout does not break

 EDGE CASE: Invalid preview image data
 GIVEN: PDFDocumentMetadata with previewImageData that is not a valid image
 WHEN: PDFDocumentCard is rendered
 THEN: PDF placeholder icon is displayed
  AND: No crash occurs
*/


// MARK: - PDFDocumentCardButton

// Interactive button wrapper for PDFDocumentCard.
// Provides press feedback and tap action.
// Mirrors NotebookCardButton pattern.

/*
 API DEFINITION: PDFDocumentCardButton

 struct PDFDocumentCardButton: View {
   let metadata: PDFDocumentMetadata
   let action: () -> Void

   var body: some View
   // Wraps PDFDocumentCard in a Button with:
   // - Scale effect on press (ScalingCardButtonStyle)
   // - Highlight sweep animation on long press
   // - Tap action callback
 }
*/

/*
 ACCEPTANCE CRITERIA: PDFDocumentCardButton

 SCENARIO: Tap to open
 GIVEN: A PDFDocumentCardButton with an action closure
 WHEN: User taps the button
 THEN: The action closure is called
  AND: Scale animation plays during press

 SCENARIO: Press feedback
 GIVEN: A PDFDocumentCardButton
 WHEN: User presses and holds
 THEN: Card scales up slightly (1.07x)
 WHEN: User releases
 THEN: Card returns to normal size (1.0x)
  AND: Animation is smooth spring animation

 SCENARIO: Long press highlight
 GIVEN: A PDFDocumentCardButton
 WHEN: User long presses for 0.5 seconds
 THEN: Highlight sweep animation plays
  AND: White gradient sweeps across card

 SCENARIO: ScrollView interaction
 GIVEN: PDFDocumentCardButton inside a ScrollView
 WHEN: User swipes to scroll
 THEN: Scroll gesture is not blocked by button
  AND: No tap action is triggered
*/

/*
 EDGE CASES: PDFDocumentCardButton

 EDGE CASE: Rapid taps
 GIVEN: A PDFDocumentCardButton
 WHEN: User taps rapidly multiple times
 THEN: Action is called for each tap
  AND: Animations do not get stuck

 EDGE CASE: Press and drag away
 GIVEN: A PDFDocumentCardButton
 WHEN: User presses, drags finger off button, then releases
 THEN: Action is not called
  AND: Card returns to normal scale
*/


// MARK: - PDFDashboardError

// Note: PDFDashboardError is not currently implemented.
// Errors are silently handled in loadPDFDocuments() to keep the app usable.
// This section documents the error types for future reference.
//
// Planned cases:
//   pdfNotesDirectoryNotAccessible(underlyingError: String)
//   manifestReadFailed(documentID: String, reason: String)
//   manifestDecodeFailed(documentID: String, reason: String)

/*
 ACCEPTANCE CRITERIA: PDFDashboardError

 SCENARIO: Error provides localized description
 GIVEN: Any PDFDashboardError case
 WHEN: errorDescription is accessed
 THEN: A non-nil user-facing message is returned

 SCENARIO: Equatable comparison
 GIVEN: Two PDFDashboardError.pdfNotesDirectoryNotAccessible with same message
 WHEN: Compared for equality
 THEN: They are equal

 GIVEN: Two PDFDashboardError with different cases
 WHEN: Compared for equality
 THEN: They are not equal
*/


// MARK: - PDFDocumentMetadataBuilder

// Implemented in DashboardComponents.swift
// Utility for building PDFDocumentMetadata from NoteDocument.
// Encapsulates the logic for counting pages and extracting fields.
//
// API:
//   static func build(from document: NoteDocument, previewImageData: Data?) -> PDFDocumentMetadata
//   - Counts only pdfPage blocks for pageCount (excludes writingSpacer)
//   - Maps all NoteDocument fields to PDFDocumentMetadata properties

/*
 ACCEPTANCE CRITERIA: PDFDocumentMetadataBuilder

 SCENARIO: Build from document with PDF pages only
 GIVEN: A NoteDocument with 5 pdfPage blocks
 WHEN: PDFDocumentMetadataBuilder.build is called
 THEN: Resulting metadata has pageCount 5
  AND: All other fields match the document

 SCENARIO: Build from document with mixed blocks
 GIVEN: A NoteDocument with 3 pdfPage blocks and 2 writingSpacer blocks
 WHEN: PDFDocumentMetadataBuilder.build is called
 THEN: Resulting metadata has pageCount 3

 SCENARIO: Build from document with no blocks
 GIVEN: A NoteDocument with empty blocks array
 WHEN: PDFDocumentMetadataBuilder.build is called
 THEN: Resulting metadata has pageCount 0

 SCENARIO: Include preview image data
 GIVEN: A NoteDocument and preview image Data
 WHEN: PDFDocumentMetadataBuilder.build is called with previewImageData
 THEN: Resulting metadata has non-nil previewImageData

 SCENARIO: Nil preview image data
 GIVEN: A NoteDocument and nil preview data
 WHEN: PDFDocumentMetadataBuilder.build is called with nil
 THEN: Resulting metadata has nil previewImageData
*/


// MARK: - Dashboard Integration Flow

/*
 INTEGRATION FLOW:

 1. DashboardView appears
    - NotebookLibrary.loadBundles() is called
    - loadBundles() calls loadPDFDocuments() in addition to existing loads
    - combineItems() builds items array with notebooks, folders, and PDF documents

 2. Dashboard grid renders items
    - ForEach iterates over items array
    - Switch on item type:
      - .notebook -> NotebookCardButton
      - .folder -> FolderCardButton
      - .pdfDocument -> PDFDocumentCardButton

 3. User taps PDF document
    - PDFDocumentCardButton action is triggered
    - NotebookLibrary.openPDFDocument(documentID:) is called
    - PDFDocumentOpenResult is returned
    - Navigation to PDF editor view

 4. User long-presses PDF document
    - Context menu appears with options:
      - Rename
      - Delete
      - Share
*/


// MARK: - File System Layout

/*
 PDF DOCUMENT STORAGE:

 Documents/
   PDFNotes/
     {uuid}/                    <- Document directory (UUID string)
       document.json            <- NoteDocument manifest
       source.pdf               <- Original PDF file
       annotations.iink         <- MyScript annotation package
       preview.png              <- First page thumbnail (optional)

 ENUMERATION LOGIC:

 To list PDF documents:
 1. Get PDFNotes directory URL from PDFNoteStorage.pdfNotesDirectory()
 2. Enumerate immediate subdirectories
 3. For each subdirectory:
    a. Check for document.json file
    b. Read and decode as NoteDocument
    c. Check for preview.png, load if present
    d. Build PDFDocumentMetadata
 4. Return array of metadata

 CONSTANTS:

 ImportCoordinator.manifestFileName = "document.json"
 ImportCoordinator.pdfFileName = "source.pdf"
 ImportCoordinator.iinkFileName = "annotations.iink"
 PreviewFileName = "preview.png" (to be defined)
*/


// MARK: - Preview Generation (Future Feature)

/*
 FUTURE: Preview Generation Contract

 Preview images are generated when:
 - A new PDF is imported
 - A document is opened (if preview missing)
 - User triggers manual refresh

 Preview specification:
 - Source: First page of PDF
 - Format: PNG
 - Size: Scaled to fit within 300x400 points
 - Quality: Standard compression
 - Location: {documentDirectory}/preview.png

 This contract does not include preview generation implementation.
 PDFDocumentMetadata.previewImageData may be nil until preview is generated.
*/


// MARK: - Testing Utilities

/*
 TEST HELPERS:

 For testing PDFDocumentMetadata:
 - Create mock NoteDocument with specified blocks
 - Use PDFDocumentMetadataBuilder to create metadata
 - Assert on pageCount and other properties

 For testing NotebookLibrary.loadPDFDocuments:
 - Create temporary PDFNotes/ directory
 - Add document subdirectories with manifest files
 - Verify pdfDocuments array after load

 For testing DashboardItem.pdfDocument:
 - Create PDFDocumentMetadata
 - Wrap in DashboardItem.pdfDocument
 - Assert id prefix, displayName, sortDate
 - Assert isPDFDocument returns true

 For testing combineItems:
 - Populate notebooks, folders, and pdfDocuments arrays
 - Call combineItems
 - Verify items array order and content
*/
