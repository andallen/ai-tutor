// Contract.swift
// Defines the API contract for the Search Service layer.
// The SearchService transforms raw IndexedMatch results from the SearchIndex into
// UI-ready SearchResult objects by enriching with folder display names and
// determining match sources (title vs handwriting vs pdfText).
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation

// MARK: - API Contract

// MARK: - MatchSource Enum

// Identifies where within a document the search match was found.
// Used to display appropriate icons and context in the search results UI.
enum MatchSource: String, Sendable, Equatable, Codable {
  // Match was found in the document title.
  case title

  // Match was found in notebook handwriting content (JIIX text).
  case handwriting

  // Match was found in PDF extracted text.
  case pdfText

  // Match was found in lesson content (questions, answers, sections).
  case lessonContent

  // Match was found in folder name.
  case folderName
}

/*
 ACCEPTANCE CRITERIA: MatchSource

 SCENARIO: Determine match source for title match
 GIVEN: A document with title "Budget Notes"
  AND: A search query "budget"
 WHEN: MatchSource is determined
 THEN: matchSource is .title
  AND: Case-insensitive comparison is used

 SCENARIO: Determine match source for notebook content match
 GIVEN: A notebook with title "Meeting Notes"
  AND: Content containing "budget analysis"
  AND: A search query "budget"
 WHEN: MatchSource is determined
 THEN: matchSource is .handwriting
  AND: Title does not contain query term

 SCENARIO: Determine match source for PDF content match
 GIVEN: A PDF with title "Annual Report"
  AND: Content containing "revenue growth"
  AND: A search query "revenue"
 WHEN: MatchSource is determined
 THEN: matchSource is .pdfText
  AND: Title does not contain query term
*/

// MARK: - SearchResult Struct

// UI-ready search result with enriched metadata.
// Transforms IndexedMatch by resolving folder IDs to display names.
// Identifiable for use in SwiftUI lists.
struct SearchResult: Sendable, Equatable, Identifiable {
  // Unique identifier for the matched document.
  let documentID: String

  // Type of document (notebook or pdf).
  // Imported from ExtractionModels.swift via the Index layer.
  let documentType: DocumentType

  // Display name of the document (the title).
  let displayName: String

  // Context snippet around the match (~100 characters).
  // Includes ellipsis at boundaries if truncated.
  let matchSnippet: String

  // Where the match was found within the document.
  let matchSource: MatchSource

  // Folder display name for the document.
  // Nil if the document is at root level (not in a folder).
  let folderPath: String?

  // Timestamp when the document was last modified.
  let modifiedAt: Date

  // Preview thumbnail image data for displaying in search results.
  // This is the same preview data used in the dashboard cards.
  // Nil if no preview is available.
  var previewImageData: Data?

  // Identifiable conformance using documentID.
  var id: String { documentID }
}

/*
 ACCEPTANCE CRITERIA: SearchResult

 SCENARIO: SearchResult from IndexedMatch with folder
 GIVEN: An IndexedMatch with folderID "folder-123"
  AND: Folder "folder-123" has displayName "Work Projects"
 WHEN: SearchResult is created
 THEN: folderPath is "Work Projects"
  AND: All other fields are populated from IndexedMatch

 SCENARIO: SearchResult from IndexedMatch without folder
 GIVEN: An IndexedMatch with folderID nil
 WHEN: SearchResult is created
 THEN: folderPath is nil
  AND: Document is considered at root level

 SCENARIO: SearchResult identifiable in lists
 GIVEN: Multiple SearchResult instances
 WHEN: Used in a SwiftUI List
 THEN: Each result is uniquely identified by documentID
  AND: No duplicate IDs cause rendering issues
*/

// MARK: - InNoteSearchMatch Struct

// Represents a match found within a specific document during in-note search.
// Stub for Phase 5 implementation.
// Will eventually include bounding box for highlighting matches in the editor.
struct InNoteSearchMatch: Sendable, Equatable, Identifiable {
  // Zero-based index of this match within the document.
  // Used for "match N of M" navigation.
  let matchIndex: Int

  // Context snippet around the match.
  let snippet: String

  // Bounding box for highlighting the match in the editor.
  // Nil until Phase 5 adds spatial positioning.
  let boundingBox: CGRect?

  // Identifiable conformance using matchIndex.
  var id: Int { matchIndex }
}

/*
 ACCEPTANCE CRITERIA: InNoteSearchMatch

 SCENARIO: Phase 5 stub returns empty array
 GIVEN: A valid query and documentID
 WHEN: searchInNote is called
 THEN: Returns empty array []
  AND: No error is thrown

 SCENARIO: InNoteSearchMatch identifiable for navigation
 GIVEN: Multiple matches within a document
 WHEN: Used in match navigation UI
 THEN: Each match is uniquely identified by matchIndex
  AND: Matches are ordered by their position in the document
*/

// MARK: - SearchServiceError Enum

// Errors that can occur during search service operations.
// Wraps underlying SearchIndexError and adds service-specific errors.
enum SearchServiceError: Error, LocalizedError, Equatable {
  // The search index has not been initialized.
  case indexNotInitialized

  // The search query was empty or contained only whitespace.
  case emptyQuery

  // Failed to resolve folder ID to display name.
  case folderLookupFailed(reason: String)

  // Wraps an error from the underlying SearchIndex.
  case indexError(SearchIndexError)

  var errorDescription: String? {
    switch self {
    case .indexNotInitialized:
      return "Search index has not been initialized"
    case .emptyQuery:
      return "Search query cannot be empty"
    case .folderLookupFailed(let reason):
      return "Failed to look up folder: \(reason)"
    case .indexError(let indexError):
      return "Search index error: \(indexError.localizedDescription)"
    }
  }

  static func == (lhs: SearchServiceError, rhs: SearchServiceError) -> Bool {
    switch (lhs, rhs) {
    case (.indexNotInitialized, .indexNotInitialized):
      return true
    case (.emptyQuery, .emptyQuery):
      return true
    case (.folderLookupFailed(let lhsReason), .folderLookupFailed(let rhsReason)):
      return lhsReason == rhsReason
    case (.indexError(let lhsError), .indexError(let rhsError)):
      return lhsError == rhsError
    default:
      return false
    }
  }
}

/*
 ACCEPTANCE CRITERIA: SearchServiceError

 SCENARIO: Index not initialized error
 GIVEN: SearchService with uninitialized index
 WHEN: searchAll is called
 THEN: Throws SearchServiceError.indexNotInitialized
  AND: Error message indicates initialization required

 SCENARIO: Empty query error
 GIVEN: An empty string query ""
 WHEN: searchAll is called
 THEN: Throws SearchServiceError.emptyQuery
  AND: Error message indicates query cannot be empty

 SCENARIO: Whitespace-only query error
 GIVEN: A whitespace-only query "   "
 WHEN: searchAll is called
 THEN: Throws SearchServiceError.emptyQuery
  AND: Query is trimmed and detected as empty

 SCENARIO: Folder lookup failure error
 GIVEN: A match with folderID that cannot be resolved
 WHEN: SearchService attempts to enrich the result
 THEN: Throws SearchServiceError.folderLookupFailed with reason
  AND: Reason describes the specific failure

 SCENARIO: Wrapped index error
 GIVEN: The underlying SearchIndex throws an error
 WHEN: SearchService propagates the error
 THEN: Error is wrapped as SearchServiceError.indexError
  AND: Original error details are preserved
*/

// MARK: - SearchServiceConstants Enum

// Configuration constants for the SearchService.
enum SearchServiceConstants {
  // Default maximum number of results returned from search operations.
  static let defaultResultLimit = 25
}

// MARK: - SearchServiceProtocol

// Protocol defining the interface for the search service actor.
// Transforms raw index results into UI-ready SearchResult objects.
// Actor isolation ensures thread-safe access to shared state.
protocol SearchServiceProtocol: Actor {
  // Searches all indexed documents and returns enriched results.
  // query: The search terms to find.
  // Returns results sorted by relevance, limited to defaultResultLimit.
  // Throws emptyQuery if query is empty or whitespace-only.
  func searchAll(query: String) async throws -> [SearchResult]

  // Searches within a specific folder and returns enriched results.
  // query: The search terms to find.
  // folderID: The folder to search within.
  // Returns results sorted by relevance, limited to defaultResultLimit.
  // Throws emptyQuery if query is empty or whitespace-only.
  func searchInFolder(query: String, folderID: String) async throws -> [SearchResult]

  // Searches within a specific document for in-note search.
  // query: The search terms to find.
  // documentID: The document to search within.
  // Returns matches with position information for highlighting.
  // Throws emptyQuery if query is empty or whitespace-only.
  // Note: Returns empty array until Phase 5 implementation.
  func searchInNote(query: String, documentID: String) async throws -> [InNoteSearchMatch]
}

/*
 ACCEPTANCE CRITERIA: SearchServiceProtocol.searchAll()

 SCENARIO: Search all with valid query
 GIVEN: A search index with multiple documents
  AND: Documents containing "meeting"
 WHEN: searchAll(query: "meeting") is called
 THEN: Returns [SearchResult] transformed from IndexedMatch
  AND: Results are sorted by relevance
  AND: Each result has displayName, matchSnippet, matchSource populated

 SCENARIO: Search all with empty query
 GIVEN: A search index with documents
 WHEN: searchAll(query: "") is called
 THEN: Throws SearchServiceError.emptyQuery
  AND: No index search is performed

 SCENARIO: Search all with whitespace-only query
 GIVEN: A search index with documents
 WHEN: searchAll(query: "   ") is called
 THEN: Throws SearchServiceError.emptyQuery
  AND: Query is trimmed before validation

 SCENARIO: Search all with match in folder
 GIVEN: A document with folderID "folder-abc"
  AND: Folder "folder-abc" has displayName "Projects"
 WHEN: searchAll returns this document
 THEN: SearchResult.folderPath is "Projects"
  AND: FolderID is resolved to display name

 SCENARIO: Search all with match at root
 GIVEN: A document with folderID nil
 WHEN: searchAll returns this document
 THEN: SearchResult.folderPath is nil
  AND: Document is shown at root level

 SCENARIO: Search all title match source
 GIVEN: A document with title "Budget Report"
  AND: A search query "budget"
 WHEN: searchAll returns this document
 THEN: SearchResult.matchSource is .title
  AND: Case-insensitive title match detected

 SCENARIO: Search all handwriting match source
 GIVEN: A notebook with title "Meeting Notes"
  AND: Content containing "budget discussion"
  AND: A search query "budget"
 WHEN: searchAll returns this document
 THEN: SearchResult.matchSource is .handwriting
  AND: Match not found in title, document is notebook

 SCENARIO: Search all PDF text match source
 GIVEN: A PDF with title "Quarterly Report"
  AND: Content containing "revenue analysis"
  AND: A search query "revenue"
 WHEN: searchAll returns this document
 THEN: SearchResult.matchSource is .pdfText
  AND: Match not found in title, document is PDF

 SCENARIO: Search all respects default limit
 GIVEN: 50 documents matching "notes"
 WHEN: searchAll(query: "notes") is called
 THEN: Returns at most 25 results
  AND: Results are the top 25 by relevance
*/

/*
 ACCEPTANCE CRITERIA: SearchServiceProtocol.searchInFolder()

 SCENARIO: Search in folder with valid query
 GIVEN: Documents in folder "work-folder"
  AND: Documents containing "project"
 WHEN: searchInFolder(query: "project", folderID: "work-folder") is called
 THEN: Returns [SearchResult] only from that folder
  AND: Passes scope .folder(id:) to the underlying index

 SCENARIO: Search in folder with empty query
 GIVEN: A folder with documents
 WHEN: searchInFolder(query: "", folderID: "any-folder") is called
 THEN: Throws SearchServiceError.emptyQuery
  AND: No index search is performed

 SCENARIO: Search in folder with no matches
 GIVEN: A folder with documents not containing "xyz"
 WHEN: searchInFolder(query: "xyz", folderID: "folder-id") is called
 THEN: Returns empty array []
  AND: No error is thrown
*/

/*
 ACCEPTANCE CRITERIA: SearchServiceProtocol.searchInNote()

 SCENARIO: Search in note stub returns empty
 GIVEN: A valid query and documentID
 WHEN: searchInNote(query: "term", documentID: "doc-id") is called
 THEN: Returns empty array []
  AND: This is a stub for Phase 5 implementation

 SCENARIO: Search in note with empty query
 GIVEN: Any document
 WHEN: searchInNote(query: "", documentID: "doc-id") is called
 THEN: Throws SearchServiceError.emptyQuery
  AND: Query validation happens before stub logic
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Query with leading/trailing whitespace
 GIVEN: A valid query with whitespace "  meeting  "
 WHEN: searchAll is called
 THEN: Query is trimmed to "meeting"
  AND: Search proceeds normally
  AND: Results match "meeting"

 EDGE CASE: Query that appears in both title and content
 GIVEN: A document with title "Budget Report" and content "budget analysis"
  AND: A search query "budget"
 WHEN: matchSource is determined
 THEN: matchSource is .title (title takes precedence)
  AND: Only one result is returned for the document

 EDGE CASE: Case-insensitive title matching
 GIVEN: A document with title "BUDGET Report"
  AND: A search query "budget" (lowercase)
 WHEN: matchSource is determined
 THEN: matchSource is .title
  AND: Case-insensitive comparison used

 EDGE CASE: Folder deleted after indexing
 GIVEN: A document with folderID "deleted-folder"
  AND: The folder no longer exists in BundleManager
 WHEN: SearchService attempts to resolve folder name
 THEN: Behavior is defined (either throw error or return nil folderPath)
  AND: Document should still be returnable with nil folderPath

 EDGE CASE: Document moved to different folder
 GIVEN: A document was indexed with folderID "old-folder"
  AND: Document was moved to "new-folder" but not reindexed
 WHEN: searchAll returns this document
 THEN: folderPath reflects the indexed folderID
  AND: May be stale until reindexing occurs

 EDGE CASE: Unicode in search query
 GIVEN: Documents containing Japanese text
 WHEN: searchAll(query: "meeting") is called
 THEN: Search operates correctly
  AND: Unicode characters in results are preserved

 EDGE CASE: Special characters in query
 GIVEN: A search query containing "project's notes"
 WHEN: searchAll is called
 THEN: Apostrophe is handled correctly
  AND: Search finds documents with "project's"

 EDGE CASE: Very long query string
 GIVEN: A search query with 1000 characters
 WHEN: searchAll is called
 THEN: Query is passed to underlying index
  AND: Performance may be impacted but no error

 EDGE CASE: Index returns empty results
 GIVEN: No documents match the query
 WHEN: searchAll(query: "nonexistent") is called
 THEN: Returns empty array []
  AND: No error is thrown
  AND: Folder lookups are not performed

 EDGE CASE: Concurrent search requests
 GIVEN: Multiple tasks call searchAll simultaneously
 WHEN: Actor serializes the calls
 THEN: Each caller receives correct results
  AND: No race conditions occur
  AND: Results may differ if index is modified between calls

 EDGE CASE: Tab and newline in query
 GIVEN: A query containing tabs or newlines "meeting\tnotes\n"
 WHEN: searchAll is called
 THEN: Whitespace is normalized or handled
  AND: Search finds relevant documents

 EDGE CASE: Partial word match
 GIVEN: A document with "budgeting" in content
  AND: A search query "budget"
 WHEN: searchAll is called
 THEN: Document may or may not match (depends on FTS5 stemming)
  AND: Behavior is consistent with underlying index
*/

// MARK: - MatchSource Determination Logic

/*
 MATCH SOURCE ALGORITHM:

 1. Normalize the query to lowercase
 2. Normalize the document title to lowercase
 3. If the normalized title contains the normalized query:
    - Return .title
 4. Else if documentType is .notebook:
    - Return .handwriting
 5. Else if documentType is .pdf:
    - Return .pdfText

 NOTE: This is a simple heuristic. The actual match could be in content even
 if the title contains a partial match. For Phase 2, title presence is sufficient.
*/

/*
 EDGE CASE: Multiple query terms in matchSource determination
 GIVEN: A query "budget meeting"
  AND: A document with title "Budget Report" (contains "budget" but not "meeting")
 WHEN: matchSource is determined
 THEN: Consider if any query term appears in title
  AND: If partial match in title, may still be .title
  AND: Behavior should be documented and tested

 EDGE CASE: Empty title
 GIVEN: A document with empty title ""
 WHEN: matchSource is determined
 THEN: matchSource is .handwriting (for notebook) or .pdfText (for pdf)
  AND: Empty title cannot contain query
*/

// MARK: - Integration Points

/*
 INTEGRATION: SearchIndex (Phase 1)
 SearchService depends on SearchIndexProtocol:
 - Calls search(query:scope:limit:) to get IndexedMatch results
 - Uses SearchScope.all for searchAll
 - Uses SearchScope.folder(id:) for searchInFolder
 - Uses SearchScope.document(id:) for searchInNote (Phase 5)

 INTEGRATION: BundleManager
 SearchService depends on BundleManager for folder resolution:
 - Calls listFolders() or similar to get FolderMetadata
 - Looks up folder displayName by folderID
 - Caches folder mappings for performance

 INTEGRATION: Future UI (Phase 3-4)
 SearchService provides data for:
 - SearchView displaying results in a list
 - Each SearchResult maps to a row with icon, title, snippet, folder path
 - Tapping result navigates to document
*/

// MARK: - FolderLookup Protocol

// Protocol for resolving folder IDs to display names.
// Allows dependency injection for testing.
protocol FolderLookupProtocol: Sendable {
  // Resolves a folder ID to its display name.
  // Returns nil if folder does not exist.
  func getFolderDisplayName(folderID: String) async -> String?
}

// MARK: - PreviewLookup Protocol

// Protocol for resolving document IDs to preview image data.
// Allows dependency injection for testing.
// The preview data returned here is the same data used in dashboard cards,
// ensuring visual consistency between search results and the main dashboard.
protocol PreviewLookupProtocol: Sendable {
  // Resolves a document ID to its preview image data.
  // documentID: The unique identifier of the document.
  // documentType: The type of document (notebook, pdf, or lesson).
  // Returns the preview image PNG data, or nil if no preview exists.
  func getPreviewImageData(documentID: String, documentType: DocumentType) async -> Data?
}

/*
 ACCEPTANCE CRITERIA: FolderLookupProtocol

 SCENARIO: Lookup existing folder
 GIVEN: A folder with ID "folder-123" and displayName "Work"
 WHEN: getFolderDisplayName(folderID: "folder-123") is called
 THEN: Returns "Work"

 SCENARIO: Lookup non-existent folder
 GIVEN: No folder with ID "missing-folder"
 WHEN: getFolderDisplayName(folderID: "missing-folder") is called
 THEN: Returns nil
  AND: No error is thrown

 SCENARIO: Lookup with caching
 GIVEN: Multiple lookups for the same folderID
 WHEN: getFolderDisplayName is called repeatedly
 THEN: Subsequent calls may use cached value
  AND: Performance is improved for batch operations
*/

// MARK: - Threading Requirements

/*
 THREADING: Actor isolation for SearchService
 SearchService is an actor to ensure thread-safe:
 - Access to the underlying SearchIndex
 - Folder lookup caching (if implemented)
 - Concurrent request handling

 THREADING: Async operations
 All SearchServiceProtocol methods are async because:
 - SearchIndex operations are async (actor isolated)
 - BundleManager folder lookups are async (actor isolated)
 - Results may require multiple async operations to enrich

 THREADING: Sendable types
 All result types (SearchResult, InNoteSearchMatch) are Sendable:
 - Safe to pass across actor boundaries
 - Can be used directly in SwiftUI views (@MainActor)
*/
