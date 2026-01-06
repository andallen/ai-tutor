// Contract.swift
// Defines the API contract for the local SQLite FTS5-based search index.
// This index enables keyword search across notebooks, PDFs, and folders.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation

// MARK: - API Contract

// MARK: DocumentType Enum

// Types of documents that can be indexed for search.
// Reuses the existing DocumentType from AIIndexing for consistency.
// Note: Implementation should import from ExtractionModels.swift rather than redefining.

/*
 DocumentType (defined in ExtractionModels.swift):
 - .notebook: Regular handwriting note stored as iink bundle
 - .pdf: PDF document with annotations
*/

// MARK: - SearchScope Enum

// Defines the scope of a search operation.
// Allows searching all content, within a folder, or within a specific document.
enum SearchScope: Sendable, Equatable {
  // Search across all indexed documents (notebooks and PDFs).
  case all

  // Search within documents contained in a specific folder.
  // Useful for filtering results to a project or category.
  case folder(id: String)

  // Search within a specific document (for in-note search).
  // Useful for finding text within the currently open notebook.
  case document(id: String)
}

/*
 ACCEPTANCE CRITERIA: SearchScope

 SCENARIO: Search scope all
 GIVEN: A search index with documents in multiple folders
 WHEN: search() is called with scope .all
 THEN: All indexed documents are searched
  AND: Results from any folder or root level are included

 SCENARIO: Search scope folder
 GIVEN: A search index with documents in folder "abc123"
 WHEN: search() is called with scope .folder(id: "abc123")
 THEN: Only documents with folderID "abc123" are searched
  AND: Documents at root level are excluded
  AND: Documents in other folders are excluded

 SCENARIO: Search scope document
 GIVEN: A search index with document "doc456"
 WHEN: search() is called with scope .document(id: "doc456")
 THEN: Only the specified document is searched
  AND: Results from other documents are excluded
*/

// MARK: - SearchIndexEntry Struct

// Represents a document entry to be indexed.
// Contains all metadata needed for full-text search and result display.
// Sendable for safe passage across actor boundaries.
// Codable for potential persistence or debugging.
struct SearchIndexEntry: Sendable, Codable, Equatable {
  // Unique identifier for this document (UUID as string).
  let documentID: String

  // Type of document (notebook or pdf).
  let documentType: DocumentType

  // Folder containing this document, nil if at root level.
  let folderID: String?

  // Display name shown to the user in search results.
  let title: String

  // Full text content for FTS5 indexing.
  // For notebooks: recognized handwriting text from JIIX.
  // For PDFs: extracted text plus any annotation text.
  let contentText: String

  // Timestamp when the document was last modified.
  // Used to determine if reindexing is needed.
  let modifiedAt: Date
}

/*
 ACCEPTANCE CRITERIA: SearchIndexEntry

 SCENARIO: Index entry for notebook at root
 GIVEN: A notebook with recognized text "Meeting notes from Monday"
 WHEN: A SearchIndexEntry is created
 THEN: documentID matches the notebook ID
  AND: documentType is .notebook
  AND: folderID is nil
  AND: title is the notebook display name
  AND: contentText contains the recognized text
  AND: modifiedAt reflects the notebook modification timestamp

 SCENARIO: Index entry for PDF in folder
 GIVEN: A PDF document inside folder "projects"
 WHEN: A SearchIndexEntry is created
 THEN: documentID matches the PDF document ID
  AND: documentType is .pdf
  AND: folderID is "projects"
  AND: contentText contains extracted PDF text

 SCENARIO: Index entry with empty content
 GIVEN: A notebook with no handwriting (blank pages)
 WHEN: A SearchIndexEntry is created
 THEN: contentText is an empty string
  AND: The entry is still valid and can be indexed
*/

// MARK: - IndexedMatch Struct

// Represents a single search result with relevance information.
// Returned from search operations with context around the match.
struct IndexedMatch: Sendable, Equatable, Identifiable {
  // Unique identifier for the matched document.
  let documentID: String

  // Type of document that was matched.
  let documentType: DocumentType

  // Display name of the matched document.
  let title: String

  // Context snippet around the match (~100 characters).
  // Includes ellipsis at boundaries if truncated.
  let snippet: String

  // Folder containing the matched document, nil if at root.
  let folderID: String?

  // FTS5 relevance rank score.
  // Higher values indicate better matches.
  // Title matches typically score higher than content matches.
  let relevanceRank: Double

  // Identifiable conformance using documentID.
  var id: String { documentID }
}

/*
 ACCEPTANCE CRITERIA: IndexedMatch

 SCENARIO: Match with snippet context
 GIVEN: A search for "budget" in a document containing "The annual budget report shows..."
 WHEN: The search returns a match
 THEN: snippet contains surrounding context
  AND: snippet is approximately 100 characters
  AND: snippet shows "...The annual budget report shows..."

 SCENARIO: Match at document start
 GIVEN: A search for "Introduction" at the beginning of a document
 WHEN: The search returns a match
 THEN: snippet does not have leading ellipsis
  AND: snippet has trailing ellipsis if content continues

 SCENARIO: Multiple matches in same document
 GIVEN: A search for "meeting" appearing 5 times in one document
 WHEN: The search returns matches
 THEN: Only one IndexedMatch per document is returned
  AND: snippet shows the best/first match context
  AND: relevanceRank reflects multiple occurrences
*/

// MARK: - SearchIndexProtocol

// Protocol defining the interface for the search index actor.
// All methods are async due to actor isolation and database operations.
// The SearchIndex actor must conform to this protocol.
protocol SearchIndexProtocol: Actor {
  // Initializes the database and creates tables if needed.
  // Must be called before any other operations.
  // Safe to call multiple times (idempotent).
  func initialize() async throws

  // Indexes a single document.
  // Inserts or updates the document in the FTS5 table.
  // If a document with the same ID exists, it is replaced.
  func indexDocument(_ entry: SearchIndexEntry) async throws

  // Indexes multiple documents in a batch.
  // More efficient than calling indexDocument() repeatedly.
  // Uses a single transaction for atomicity.
  func indexDocuments(_ entries: [SearchIndexEntry]) async throws

  // Removes a document from the index.
  // No-op if document is not in the index (does not throw).
  func removeDocument(documentID: String) async throws

  // Searches the index and returns matching documents.
  // query: The search terms (FTS5 query syntax).
  // scope: The scope to search within.
  // limit: Maximum number of results to return.
  // Returns matches sorted by relevance (highest first).
  func search(query: String, scope: SearchScope, limit: Int) async throws -> [IndexedMatch]

  // Checks if a document is currently in the index.
  func isDocumentIndexed(documentID: String) async -> Bool

  // Checks if a document needs reindexing based on modification timestamp.
  // Returns true if the document is not indexed or the indexed version is older.
  func documentNeedsReindex(documentID: String, modifiedAt: Date) async -> Bool

  // Removes all documents from the index.
  // Useful for rebuilding the index from scratch.
  func clearIndex() async throws
}

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.initialize()

 SCENARIO: First run initialization
 GIVEN: No existing search database
 WHEN: initialize() is called
 THEN: Database file is created at Application Support/SearchIndex/search.sqlite
  AND: FTS5 table is created with porter stemmer tokenizer
  AND: No error is thrown
  AND: Subsequent operations can proceed

 SCENARIO: Existing database initialization
 GIVEN: A search database from a previous session
 WHEN: initialize() is called
 THEN: Existing data is preserved
  AND: Schema is validated/upgraded if needed
  AND: No error is thrown

 SCENARIO: Database directory creation
 GIVEN: The SearchIndex directory does not exist
 WHEN: initialize() is called
 THEN: The directory is created with intermediate directories
  AND: Database file is created inside the directory

 SCENARIO: Concurrent initialization
 GIVEN: Multiple tasks call initialize() simultaneously
 WHEN: Actor serializes the calls
 THEN: Only one database creation occurs
  AND: All callers receive success after initialization
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.indexDocument()

 SCENARIO: Index new document
 GIVEN: An empty search index
 WHEN: indexDocument() is called with a valid entry
 THEN: The document is added to the FTS5 table
  AND: isDocumentIndexed() returns true
  AND: The document is searchable

 SCENARIO: Update existing document
 GIVEN: A document "doc1" already in the index with content "old text"
 WHEN: indexDocument() is called with "doc1" having content "new text"
 THEN: The document is replaced (not duplicated)
  AND: Search for "old text" returns no results
  AND: Search for "new text" returns "doc1"

 SCENARIO: Index document with empty content
 GIVEN: A search index
 WHEN: indexDocument() is called with empty contentText
 THEN: The document is indexed
  AND: The document can still be found by title
  AND: Content searches return no match for this document

 SCENARIO: Index document with special characters
 GIVEN: A search index
 WHEN: indexDocument() is called with content containing "'s, --, quotes"
 THEN: The document is indexed successfully
  AND: Searches handle special characters correctly
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.indexDocuments()

 SCENARIO: Bulk index multiple documents
 GIVEN: An empty search index
 WHEN: indexDocuments() is called with 100 entries
 THEN: All documents are indexed in a single transaction
  AND: isDocumentIndexed() returns true for all entries
  AND: Operation is faster than 100 individual indexDocument() calls

 SCENARIO: Bulk index with empty array
 GIVEN: A search index
 WHEN: indexDocuments() is called with empty array
 THEN: No error is thrown
  AND: Index state is unchanged

 SCENARIO: Bulk index atomic failure
 GIVEN: A search index with document "existing"
 WHEN: indexDocuments() is called and fails mid-transaction
 THEN: Transaction is rolled back
  AND: Index state is unchanged from before the call
  AND: Error is propagated to caller
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.removeDocument()

 SCENARIO: Remove existing document
 GIVEN: A document "doc1" in the search index
 WHEN: removeDocument(documentID: "doc1") is called
 THEN: The document is removed from the FTS5 table
  AND: isDocumentIndexed("doc1") returns false
  AND: Searches no longer return this document

 SCENARIO: Remove non-existent document
 GIVEN: A search index without document "missing"
 WHEN: removeDocument(documentID: "missing") is called
 THEN: No error is thrown
  AND: Index state is unchanged

 SCENARIO: Remove and re-index document
 GIVEN: Document "doc1" was removed from the index
 WHEN: indexDocument() is called with "doc1" again
 THEN: Document is successfully added back
  AND: Document is searchable
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.search()

 SCENARIO: Basic keyword search
 GIVEN: Documents containing "meeting", "budget", "project"
 WHEN: search(query: "budget", scope: .all, limit: 10) is called
 THEN: Documents containing "budget" are returned
  AND: Results are sorted by relevance
  AND: Each result has a snippet with context

 SCENARIO: Search with multiple terms
 GIVEN: Documents in the index
 WHEN: search(query: "project meeting", scope: .all, limit: 10) is called
 THEN: Documents containing both terms are ranked higher
  AND: Documents containing either term are also returned

 SCENARIO: Search with folder scope
 GIVEN: Documents in folder "work" and folder "personal"
 WHEN: search(query: "notes", scope: .folder(id: "work"), limit: 10) is called
 THEN: Only documents from folder "work" are returned
  AND: Documents from "personal" folder are excluded
  AND: Documents at root level are excluded

 SCENARIO: Search with document scope
 GIVEN: Multiple documents in the index
 WHEN: search(query: "chapter", scope: .document(id: "book1"), limit: 10) is called
 THEN: Only matches within document "book1" are returned
  AND: Results from other documents are excluded

 SCENARIO: Search with no results
 GIVEN: Documents in the index
 WHEN: search(query: "xyznonexistent", scope: .all, limit: 10) is called
 THEN: Empty array is returned
  AND: No error is thrown

 SCENARIO: Search respects limit
 GIVEN: 50 documents matching query "common"
 WHEN: search(query: "common", scope: .all, limit: 10) is called
 THEN: Exactly 10 results are returned
  AND: Results are the top 10 by relevance

 SCENARIO: Title matches ranked higher than content
 GIVEN: Document A with title "Budget Report" and content "quarterly review"
  AND: Document B with title "Review" and content "budget analysis"
 WHEN: search(query: "budget", scope: .all, limit: 10) is called
 THEN: Document A appears before Document B
  AND: Document A has higher relevanceRank

 SCENARIO: Search with stemming
 GIVEN: Document with content "running runners ran"
 WHEN: search(query: "run", scope: .all, limit: 10) is called
 THEN: The document is returned (porter stemmer matches variations)

 SCENARIO: Case-insensitive search
 GIVEN: Document with content "PROJECT Budget"
 WHEN: search(query: "project budget", scope: .all, limit: 10) is called
 THEN: The document is returned
  AND: Case does not affect matching
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.isDocumentIndexed()

 SCENARIO: Check indexed document
 GIVEN: Document "doc1" is in the index
 WHEN: isDocumentIndexed(documentID: "doc1") is called
 THEN: Returns true

 SCENARIO: Check non-indexed document
 GIVEN: Document "missing" is not in the index
 WHEN: isDocumentIndexed(documentID: "missing") is called
 THEN: Returns false

 SCENARIO: Check after removal
 GIVEN: Document "doc1" was removed from the index
 WHEN: isDocumentIndexed(documentID: "doc1") is called
 THEN: Returns false
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.documentNeedsReindex()

 SCENARIO: Document not in index
 GIVEN: Document "new" is not in the index
 WHEN: documentNeedsReindex(documentID: "new", modifiedAt: Date()) is called
 THEN: Returns true

 SCENARIO: Document outdated
 GIVEN: Document "doc1" indexed with modifiedAt 2024-01-01
 WHEN: documentNeedsReindex(documentID: "doc1", modifiedAt: 2024-06-15) is called
 THEN: Returns true (indexed version is older)

 SCENARIO: Document up to date
 GIVEN: Document "doc1" indexed with modifiedAt 2024-06-15
 WHEN: documentNeedsReindex(documentID: "doc1", modifiedAt: 2024-06-15) is called
 THEN: Returns false (timestamps match)

 SCENARIO: Document newer in index
 GIVEN: Document "doc1" indexed with modifiedAt 2024-06-15
 WHEN: documentNeedsReindex(documentID: "doc1", modifiedAt: 2024-01-01) is called
 THEN: Returns false (indexed version is newer or same)
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexProtocol.clearIndex()

 SCENARIO: Clear populated index
 GIVEN: An index with 100 documents
 WHEN: clearIndex() is called
 THEN: All documents are removed
  AND: isDocumentIndexed() returns false for all documents
  AND: search() returns empty results

 SCENARIO: Clear empty index
 GIVEN: An empty index
 WHEN: clearIndex() is called
 THEN: No error is thrown
  AND: Index remains empty

 SCENARIO: Index usable after clear
 GIVEN: clearIndex() was called
 WHEN: indexDocument() is called with a new entry
 THEN: Document is successfully indexed
  AND: Document is searchable
*/

// MARK: - SearchIndexTriggersProtocol

// Protocol for the notification observer that triggers reindexing.
// Listens to content save and import notifications.
// Not an actor because it uses NotificationCenter (MainActor).
protocol SearchIndexTriggersProtocol {
  // Starts observing notifications for content changes.
  // Registers observers for notebookContentSaved and pdfDocumentImported.
  func startObserving()

  // Stops observing notifications.
  // Removes all registered observers.
  func stopObserving()
}

/*
 ACCEPTANCE CRITERIA: SearchIndexTriggersProtocol.startObserving()

 SCENARIO: Observe notebook content saved
 GIVEN: SearchIndexTriggers is observing
 WHEN: notebookContentSaved notification is posted with documentID "nb1"
 THEN: The notebook "nb1" is queued for reindexing
  AND: IndexDocument is eventually called with updated content

 SCENARIO: Observe PDF document imported
 GIVEN: SearchIndexTriggers is observing
 WHEN: pdfDocumentImported notification is posted
 THEN: The PDF is queued for indexing
  AND: IndexDocument is called with extracted PDF text

 SCENARIO: Multiple notifications coalesced
 GIVEN: SearchIndexTriggers is observing
 WHEN: notebookContentSaved is posted 5 times for "nb1" within 1 second
 THEN: Only one reindex operation occurs for "nb1"
  AND: Debouncing prevents excessive database operations
*/

/*
 ACCEPTANCE CRITERIA: SearchIndexTriggersProtocol.stopObserving()

 SCENARIO: Stop observing removes listeners
 GIVEN: SearchIndexTriggers was observing
 WHEN: stopObserving() is called
 THEN: All notification observers are removed
  AND: Subsequent notifications do not trigger indexing

 SCENARIO: Stop observing when not started
 GIVEN: startObserving() was never called
 WHEN: stopObserving() is called
 THEN: No error occurs
  AND: State is unchanged
*/

// MARK: - Error Definitions

// Errors that can occur during search index operations.
// Provides clear error messages for debugging and user feedback.
enum SearchIndexError: Error, LocalizedError, Equatable {
  // Database initialization failed.
  case initializationFailed(reason: String)

  // Database operation failed (insert, update, delete).
  case databaseError(reason: String)

  // Invalid search query syntax.
  case invalidQuery(query: String)

  // Document not found during operation.
  case documentNotFound(documentID: String)

  // File system error (directory creation, permissions).
  case fileSystemError(reason: String)

  var errorDescription: String? {
    switch self {
    case .initializationFailed(let reason):
      return "Search index initialization failed: \(reason)"
    case .databaseError(let reason):
      return "Search index database error: \(reason)"
    case .invalidQuery(let query):
      return "Invalid search query: \(query)"
    case .documentNotFound(let documentID):
      return "Document not found in search index: \(documentID)"
    case .fileSystemError(let reason):
      return "Search index file system error: \(reason)"
    }
  }

  static func == (lhs: SearchIndexError, rhs: SearchIndexError) -> Bool {
    switch (lhs, rhs) {
    case (.initializationFailed, .initializationFailed):
      return true
    case (.databaseError, .databaseError):
      return true
    case (.invalidQuery(let lhsQuery), .invalidQuery(let rhsQuery)):
      return lhsQuery == rhsQuery
    case (.documentNotFound(let lhsID), .documentNotFound(let rhsID)):
      return lhsID == rhsID
    case (.fileSystemError, .fileSystemError):
      return true
    default:
      return false
    }
  }
}

// MARK: - Configuration

// Configuration for the search index.
// Allows customization of paths and behavior.
struct SearchIndexConfiguration: Sendable {
  // Directory where the search database is stored.
  // Default: Application Support/SearchIndex/
  let databaseDirectory: String

  // Name of the SQLite database file.
  // Default: search.sqlite
  let databaseFileName: String

  // Maximum number of search results to return.
  // Default: 50
  let defaultSearchLimit: Int

  // Length of snippet context in characters.
  // Default: 100
  let snippetLength: Int

  // Default configuration for production use.
  static let `default` = SearchIndexConfiguration(
    databaseDirectory: "SearchIndex",
    databaseFileName: "search.sqlite",
    defaultSearchLimit: 50,
    snippetLength: 100
  )

  // Configuration for testing with in-memory database.
  static let testing = SearchIndexConfiguration(
    databaseDirectory: ":memory:",
    databaseFileName: "",
    defaultSearchLimit: 10,
    snippetLength: 50
  )
}

// MARK: - Constants

// Constants for search index configuration.
enum SearchIndexConstants {
  // Name of the FTS5 virtual table.
  static let ftsTableName = "document_search"

  // FTS5 tokenizer configuration.
  static let tokenizerConfig = "porter unicode61"

  // Column weights for ranking (title matches higher than content).
  static let titleWeight: Double = 2.0
  static let contentWeight: Double = 1.0

  // Debounce interval for indexing triggers (seconds).
  static let indexingDebounceInterval: TimeInterval = 2.0
}

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Empty search query
 GIVEN: A search index with documents
 WHEN: search(query: "", scope: .all, limit: 10) is called
 THEN: Throws SearchIndexError.invalidQuery
  AND: No database query is executed

 EDGE CASE: Query with only whitespace
 GIVEN: A search index with documents
 WHEN: search(query: "   ", scope: .all, limit: 10) is called
 THEN: Throws SearchIndexError.invalidQuery
  AND: Query is trimmed and detected as empty

 EDGE CASE: Query with FTS5 special syntax
 GIVEN: A search index with documents
 WHEN: search(query: "NEAR(budget, meeting)", scope: .all, limit: 10) is called
 THEN: FTS5 proximity search is executed
  AND: Results respect NEAR operator semantics

 EDGE CASE: Very long query string
 GIVEN: A search index with documents
 WHEN: search() is called with a 10000 character query
 THEN: Query is executed (may be slow)
  AND: No crash occurs

 EDGE CASE: Query with SQL injection attempt
 GIVEN: A search index
 WHEN: search(query: "'; DROP TABLE documents; --", ...) is called
 THEN: Query is safely escaped
  AND: No SQL injection occurs
  AND: Treated as literal search for that string

 EDGE CASE: Unicode in search query
 GIVEN: Documents containing Japanese text
 WHEN: search(query: "meeting note", scope: .all, ...) is called
 THEN: Unicode tokenization works correctly
  AND: CJK characters are properly segmented

 EDGE CASE: Index document with very long content
 GIVEN: A search index
 WHEN: indexDocument() is called with 1MB of contentText
 THEN: Document is indexed (may be slow)
  AND: No crash or truncation occurs

 EDGE CASE: Concurrent index and search operations
 GIVEN: A search index being populated
 WHEN: search() is called while indexDocuments() is running
 THEN: Actor serialization ensures consistency
  AND: Search may return partial results (documents indexed so far)
  AND: No deadlock occurs

 EDGE CASE: Database file locked by another process
 GIVEN: The SQLite database file is locked
 WHEN: initialize() or any operation is called
 THEN: Throws SearchIndexError.databaseError with lock information
  AND: Retry logic can be implemented by caller

 EDGE CASE: Disk full during indexing
 GIVEN: A nearly-full disk
 WHEN: indexDocument() is called
 THEN: Throws SearchIndexError.fileSystemError
  AND: Existing index data is preserved

 EDGE CASE: Database corruption
 GIVEN: A corrupted search database file
 WHEN: initialize() is called
 THEN: Throws SearchIndexError.initializationFailed
  AND: Error message indicates corruption
  AND: Caller should delete database and rebuild

 EDGE CASE: Document with null bytes in content
 GIVEN: PDF text extraction includes null bytes
 WHEN: indexDocument() is called with content containing \0
 THEN: Null bytes are stripped or handled
  AND: Document is indexed successfully

 EDGE CASE: Search scope with non-existent folder
 GIVEN: Folder "deleted-folder" does not exist
 WHEN: search(query: "test", scope: .folder(id: "deleted-folder"), ...) is called
 THEN: Returns empty results
  AND: No error is thrown (folder just has no documents)

 EDGE CASE: Search scope with non-existent document
 GIVEN: Document "deleted-doc" was removed
 WHEN: search(query: "test", scope: .document(id: "deleted-doc"), ...) is called
 THEN: Returns empty results
  AND: No error is thrown

 EDGE CASE: Negative limit value
 GIVEN: A search index with documents
 WHEN: search(query: "test", scope: .all, limit: -5) is called
 THEN: Throws SearchIndexError.invalidQuery or uses absolute value
  AND: Behavior is defined and consistent

 EDGE CASE: Zero limit value
 GIVEN: A search index with documents
 WHEN: search(query: "test", scope: .all, limit: 0) is called
 THEN: Returns empty array
  AND: No database query is executed (optimization)

 EDGE CASE: Index same document twice simultaneously
 GIVEN: Two tasks call indexDocument() for "doc1" at the same time
 WHEN: Actor serializes the calls
 THEN: One operation completes, then the other
  AND: Final state reflects the second call
  AND: No database errors occur

 EDGE CASE: Application Support directory not writable
 GIVEN: Application Support directory has no write permission
 WHEN: initialize() is called
 THEN: Throws SearchIndexError.fileSystemError
  AND: Error message indicates permission issue

 EDGE CASE: clearIndex during search
 GIVEN: A search is in progress
 WHEN: clearIndex() is called
 THEN: Actor serialization ensures search completes first
  AND: clearIndex() runs after search returns
  AND: Search results may be from pre-clear state

 EDGE CASE: documentNeedsReindex with nil modifiedAt
 GIVEN: A document where modifiedAt cannot be determined
 WHEN: The caller passes Date.distantPast as fallback
 THEN: Returns true (always reindex if timestamp unknown)

 EDGE CASE: FTS5 match syntax in content
 GIVEN: A document contains literal text "MATCH" or "AND"
 WHEN: The document is indexed
 THEN: FTS5 keywords in content do not cause parsing errors
  AND: Content is treated as literal text

 EDGE CASE: Snippet extraction at exact content length
 GIVEN: Document content is exactly 100 characters
 WHEN: Snippet is generated
 THEN: No truncation ellipsis is added
  AND: Snippet contains full content
*/

// MARK: - Integration Points

/*
 INTEGRATION: NotebookNotifications
 The SearchIndexTriggers should observe these existing notifications:
 - .notebookContentSaved: Posted after JIIX is saved to disk
 - .pdfDocumentImported: Posted after PDF import completes

 INTEGRATION: BundleManager
 For retrieving document metadata and folder information:
 - listBundles() to get all notebooks
 - listFolders() to get all folders
 - listBundlesInFolder(folderID:) to get notebooks in a folder

 INTEGRATION: ContentExtractor (AIIndexing)
 Reuse the existing ContentExtractor for text extraction:
 - extractContent(from documentID:) for notebooks
 - Uses JIIX parsing for handwriting text

 INTEGRATION: Application Lifecycle
 SearchIndex should be initialized in AppDelegate/SceneDelegate:
 - Call initialize() during app launch
 - Call clearIndex() if user requests index rebuild
 - Index is persisted across app launches

 INTEGRATION: Future UI
 The SearchIndex provides data for search UI:
 - Search bar triggers search(query:scope:limit:)
 - Results displayed in list with snippets
 - Tapping result navigates to document
*/

// MARK: - Threading Requirements

/*
 THREADING: Actor isolation for database operations
 All SearchIndex methods run within the actor.
 Database operations are serialized to prevent corruption.
 No external synchronization is needed by callers.

 THREADING: MainActor for UI updates
 SearchIndexTriggers observes NotificationCenter on main thread.
 Search results should be received on caller's context.
 Use Task { @MainActor } for UI updates after search.

 THREADING: Background indexing
 Large batch indexing should not block UI.
 Use Task.detached for background indexing work.
 Progress can be reported via callback or notification.

 THREADING: Cancellation support
 Long-running search or index operations should check cancellation.
 Use Task.checkCancellation() at operation boundaries.
*/

// MARK: - Database Schema

/*
 SCHEMA: FTS5 Virtual Table

 CREATE VIRTUAL TABLE document_search USING fts5(
   documentID,
   documentType,
   folderID,
   title,
   contentText,
   modifiedAt,
   tokenize = 'porter unicode61'
 );

 Note: FTS5 stores modifiedAt as TEXT (ISO8601).
 Conversion to/from Date happens in Swift code.

 SCHEMA: Ranking Configuration

 Search results are ranked using:
 - bm25(document_search, titleWeight, contentWeight)
 - Title matches receive 2x weight vs content matches
 - Porter stemmer enables matching word variations
*/
