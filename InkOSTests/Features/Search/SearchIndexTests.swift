// SearchIndexTests.swift
// Comprehensive tests for the Search Index Infrastructure.
// These tests validate the SearchIndexProtocol, SearchIndexTriggersProtocol,
// and associated types defined in Contract.swift.

import Foundation
import Testing

@testable import InkOS

// MARK: - Test Fixtures

// Creates test SearchIndexEntry instances for use across tests.
enum SearchIndexTestFixtures {

  // Creates a basic notebook entry at root level.
  static func notebookEntry(
    id: String = "notebook-1",
    title: String = "Test Notebook",
    content: String = "Sample notebook content",
    folderID: String? = nil,
    modifiedAt: Date = Date()
  ) -> SearchIndexEntry {
    return SearchIndexEntry(
      documentID: id,
      documentType: .notebook,
      folderID: folderID,
      title: title,
      contentText: content,
      modifiedAt: modifiedAt
    )
  }

  // Creates a basic PDF entry.
  static func pdfEntry(
    id: String = "pdf-1",
    title: String = "Test PDF",
    content: String = "Sample PDF content",
    folderID: String? = nil,
    modifiedAt: Date = Date()
  ) -> SearchIndexEntry {
    return SearchIndexEntry(
      documentID: id,
      documentType: .pdf,
      folderID: folderID,
      title: title,
      contentText: content,
      modifiedAt: modifiedAt
    )
  }

  // Creates multiple entries for bulk testing.
  static func bulkEntries(count: Int) -> [SearchIndexEntry] {
    return (0..<count).map { index in
      notebookEntry(
        id: "bulk-doc-\(index)",
        title: "Bulk Document \(index)",
        content: "Content for bulk document \(index)"
      )
    }
  }

  // Entry with empty content for edge case testing.
  static let emptyContentEntry = SearchIndexEntry(
    documentID: "empty-content",
    documentType: .notebook,
    folderID: nil,
    title: "Empty Content Notebook",
    contentText: "",
    modifiedAt: Date()
  )

  // Entry with special characters for edge case testing.
  static let specialCharactersEntry = SearchIndexEntry(
    documentID: "special-chars",
    documentType: .notebook,
    folderID: nil,
    title: "It's a test",
    contentText: "This entry has 's, --, \"quotes\", and other special chars!",
    modifiedAt: Date()
  )

  // Entry with long content for edge case testing.
  static func longContentEntry() -> SearchIndexEntry {
    let longContent = String(repeating: "This is a repeated sentence for testing. ", count: 25000)
    return SearchIndexEntry(
      documentID: "long-content",
      documentType: .notebook,
      folderID: nil,
      title: "Long Content Notebook",
      contentText: longContent,
      modifiedAt: Date()
    )
  }
}

// MARK: - Mock SearchIndex

// Mock implementation of SearchIndexProtocol for testing triggers and other components.
actor MockSearchIndex: SearchIndexProtocol {

  // Tracks method invocations.
  private(set) var initializeCallCount = 0
  private(set) var indexDocumentCalls: [SearchIndexEntry] = []
  private(set) var indexDocumentsCalls: [[SearchIndexEntry]] = []
  private(set) var removeDocumentCalls: [String] = []
  private(set) var searchCalls: [(query: String, scope: SearchScope, limit: Int)] = []
  private(set) var isDocumentIndexedCalls: [String] = []
  private(set) var documentNeedsReindexCalls: [(documentID: String, modifiedAt: Date)] = []
  private(set) var clearIndexCallCount = 0

  // In-memory storage for simulating index behavior.
  private var indexedDocuments: [String: SearchIndexEntry] = [:]

  // Configurable error to throw.
  var errorToThrow: SearchIndexError?

  // Configurable search results.
  var searchResultsToReturn: [IndexedMatch] = []

  func initialize() async throws {
    initializeCallCount += 1
    if let error = errorToThrow {
      throw error
    }
  }

  func indexDocument(_ entry: SearchIndexEntry) async throws {
    indexDocumentCalls.append(entry)
    if let error = errorToThrow {
      throw error
    }
    indexedDocuments[entry.documentID] = entry
  }

  func indexDocuments(_ entries: [SearchIndexEntry]) async throws {
    indexDocumentsCalls.append(entries)
    if let error = errorToThrow {
      throw error
    }
    for entry in entries {
      indexedDocuments[entry.documentID] = entry
    }
  }

  func removeDocument(documentID: String) async throws {
    removeDocumentCalls.append(documentID)
    if let error = errorToThrow {
      throw error
    }
    indexedDocuments.removeValue(forKey: documentID)
  }

  func search(query: String, scope: SearchScope, limit: Int) async throws -> [IndexedMatch] {
    searchCalls.append((query: query, scope: scope, limit: limit))
    if let error = errorToThrow {
      throw error
    }
    // Respect the limit parameter like the real implementation.
    // Guard against negative limit values.
    let effectiveLimit = max(0, limit)
    return Array(searchResultsToReturn.prefix(effectiveLimit))
  }

  func isDocumentIndexed(documentID: String) async -> Bool {
    isDocumentIndexedCalls.append(documentID)
    return indexedDocuments[documentID] != nil
  }

  func documentNeedsReindex(documentID: String, modifiedAt: Date) async -> Bool {
    documentNeedsReindexCalls.append((documentID: documentID, modifiedAt: modifiedAt))
    guard let existing = indexedDocuments[documentID] else {
      return true
    }
    return modifiedAt > existing.modifiedAt
  }

  func clearIndex() async throws {
    clearIndexCallCount += 1
    if let error = errorToThrow {
      throw error
    }
    indexedDocuments.removeAll()
  }

  // Test helper to reset all tracking state.
  func reset() {
    initializeCallCount = 0
    indexDocumentCalls = []
    indexDocumentsCalls = []
    removeDocumentCalls = []
    searchCalls = []
    isDocumentIndexedCalls = []
    documentNeedsReindexCalls = []
    clearIndexCallCount = 0
    indexedDocuments = [:]
    errorToThrow = nil
    searchResultsToReturn = []
  }
}

// MARK: - SearchScope Tests

@Suite("SearchScope Tests")
struct SearchScopeTests {

  @Test("SearchScope.all is sendable and equatable")
  func allScopeConformance() {
    let scope1 = SearchScope.all
    let scope2 = SearchScope.all
    #expect(scope1 == scope2)
  }

  @Test("SearchScope.folder with same ID is equal")
  func folderScopeEquality() {
    let scope1 = SearchScope.folder(id: "folder-123")
    let scope2 = SearchScope.folder(id: "folder-123")
    #expect(scope1 == scope2)
  }

  @Test("SearchScope.folder with different IDs is not equal")
  func folderScopeInequality() {
    let scope1 = SearchScope.folder(id: "folder-123")
    let scope2 = SearchScope.folder(id: "folder-456")
    #expect(scope1 != scope2)
  }

  @Test("SearchScope.document with same ID is equal")
  func documentScopeEquality() {
    let scope1 = SearchScope.document(id: "doc-123")
    let scope2 = SearchScope.document(id: "doc-123")
    #expect(scope1 == scope2)
  }

  @Test("SearchScope.document with different IDs is not equal")
  func documentScopeInequality() {
    let scope1 = SearchScope.document(id: "doc-123")
    let scope2 = SearchScope.document(id: "doc-456")
    #expect(scope1 != scope2)
  }

  @Test("Different SearchScope types are not equal")
  func differentScopeTypesNotEqual() {
    let allScope = SearchScope.all
    let folderScope = SearchScope.folder(id: "test")
    let documentScope = SearchScope.document(id: "test")

    #expect(allScope != folderScope)
    #expect(allScope != documentScope)
    #expect(folderScope != documentScope)
  }
}

// MARK: - SearchIndexEntry Tests

@Suite("SearchIndexEntry Tests")
struct SearchIndexEntryTests {

  @Test("creates valid notebook entry at root level")
  func notebookEntryAtRoot() {
    let entry = SearchIndexTestFixtures.notebookEntry(
      id: "nb-123",
      title: "Meeting Notes",
      content: "Meeting notes from Monday",
      folderID: nil
    )

    #expect(entry.documentID == "nb-123")
    #expect(entry.documentType == .notebook)
    #expect(entry.folderID == nil)
    #expect(entry.title == "Meeting Notes")
    #expect(entry.contentText == "Meeting notes from Monday")
  }

  @Test("creates valid PDF entry in folder")
  func pdfEntryInFolder() {
    let entry = SearchIndexTestFixtures.pdfEntry(
      id: "pdf-456",
      title: "Budget Report",
      content: "Annual budget analysis",
      folderID: "projects"
    )

    #expect(entry.documentID == "pdf-456")
    #expect(entry.documentType == .pdf)
    #expect(entry.folderID == "projects")
    #expect(entry.title == "Budget Report")
    #expect(entry.contentText == "Annual budget analysis")
  }

  @Test("creates valid entry with empty content")
  func entryWithEmptyContent() {
    let entry = SearchIndexTestFixtures.emptyContentEntry

    #expect(entry.documentID == "empty-content")
    #expect(entry.contentText == "")
    #expect(entry.title.isEmpty == false)
  }

  @Test("entry is equatable")
  func entryEquatable() {
    let date = Date()
    let entry1 = SearchIndexEntry(
      documentID: "doc-1",
      documentType: .notebook,
      folderID: nil,
      title: "Test",
      contentText: "Content",
      modifiedAt: date
    )
    let entry2 = SearchIndexEntry(
      documentID: "doc-1",
      documentType: .notebook,
      folderID: nil,
      title: "Test",
      contentText: "Content",
      modifiedAt: date
    )

    #expect(entry1 == entry2)
  }

  @Test("entry is codable")
  func entryCodable() throws {
    let entry = SearchIndexTestFixtures.notebookEntry()

    let encoder = JSONEncoder()
    let data = try encoder.encode(entry)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SearchIndexEntry.self, from: data)

    #expect(decoded.documentID == entry.documentID)
    #expect(decoded.documentType == entry.documentType)
    #expect(decoded.title == entry.title)
    #expect(decoded.contentText == entry.contentText)
  }
}

// MARK: - IndexedMatch Tests

@Suite("IndexedMatch Tests")
struct IndexedMatchTests {

  @Test("creates valid IndexedMatch")
  func createsValidMatch() {
    let match = IndexedMatch(
      documentID: "doc-123",
      documentType: .notebook,
      title: "Budget Report",
      snippet: "...The annual budget report shows...",
      folderID: nil,
      relevanceRank: 2.5
    )

    #expect(match.documentID == "doc-123")
    #expect(match.documentType == .notebook)
    #expect(match.title == "Budget Report")
    #expect(match.snippet.contains("budget"))
    #expect(match.folderID == nil)
    #expect(match.relevanceRank == 2.5)
  }

  @Test("IndexedMatch id property returns documentID")
  func matchIdProperty() {
    let match = IndexedMatch(
      documentID: "unique-doc-id",
      documentType: .pdf,
      title: "Test",
      snippet: "Test snippet",
      folderID: nil,
      relevanceRank: 1.0
    )

    #expect(match.id == "unique-doc-id")
  }

  @Test("IndexedMatch is equatable")
  func matchEquatable() {
    let match1 = IndexedMatch(
      documentID: "doc-1",
      documentType: .notebook,
      title: "Test",
      snippet: "Snippet",
      folderID: nil,
      relevanceRank: 1.0
    )
    let match2 = IndexedMatch(
      documentID: "doc-1",
      documentType: .notebook,
      title: "Test",
      snippet: "Snippet",
      folderID: nil,
      relevanceRank: 1.0
    )

    #expect(match1 == match2)
  }

  @Test("IndexedMatch with folder ID")
  func matchWithFolderID() {
    let match = IndexedMatch(
      documentID: "doc-in-folder",
      documentType: .notebook,
      title: "Folder Doc",
      snippet: "Snippet",
      folderID: "work-folder",
      relevanceRank: 1.5
    )

    #expect(match.folderID == "work-folder")
  }
}

// MARK: - SearchIndexError Tests

@Suite("SearchIndexError Tests")
struct SearchIndexErrorTests {

  @Test("initializationFailed has correct description")
  func initializationFailedDescription() {
    let error = SearchIndexError.initializationFailed(reason: "Database locked")

    #expect(error.errorDescription?.contains("initialization failed") == true)
    #expect(error.errorDescription?.contains("Database locked") == true)
  }

  @Test("databaseError has correct description")
  func databaseErrorDescription() {
    let error = SearchIndexError.databaseError(reason: "Insert failed")

    #expect(error.errorDescription?.contains("database error") == true)
    #expect(error.errorDescription?.contains("Insert failed") == true)
  }

  @Test("invalidQuery has correct description")
  func invalidQueryDescription() {
    let error = SearchIndexError.invalidQuery(query: "")

    #expect(error.errorDescription?.contains("Invalid search query") == true)
  }

  @Test("documentNotFound has correct description")
  func documentNotFoundDescription() {
    let error = SearchIndexError.documentNotFound(documentID: "missing-doc")

    #expect(error.errorDescription?.contains("not found") == true)
    #expect(error.errorDescription?.contains("missing-doc") == true)
  }

  @Test("fileSystemError has correct description")
  func fileSystemErrorDescription() {
    let error = SearchIndexError.fileSystemError(reason: "Permission denied")

    #expect(error.errorDescription?.contains("file system error") == true)
    #expect(error.errorDescription?.contains("Permission denied") == true)
  }

  @Test("errors of same type are equal")
  func sameTypeErrorsEqual() {
    let error1 = SearchIndexError.initializationFailed(reason: "Reason 1")
    let error2 = SearchIndexError.initializationFailed(reason: "Reason 2")

    #expect(error1 == error2)
  }

  @Test("invalidQuery errors with same query are equal")
  func invalidQueryErrorsEqual() {
    let error1 = SearchIndexError.invalidQuery(query: "test")
    let error2 = SearchIndexError.invalidQuery(query: "test")

    #expect(error1 == error2)
  }

  @Test("invalidQuery errors with different queries are not equal")
  func invalidQueryErrorsNotEqual() {
    let error1 = SearchIndexError.invalidQuery(query: "test1")
    let error2 = SearchIndexError.invalidQuery(query: "test2")

    #expect(error1 != error2)
  }

  @Test("documentNotFound errors with same ID are equal")
  func documentNotFoundErrorsEqual() {
    let error1 = SearchIndexError.documentNotFound(documentID: "doc-1")
    let error2 = SearchIndexError.documentNotFound(documentID: "doc-1")

    #expect(error1 == error2)
  }

  @Test("different error types are not equal")
  func differentTypesNotEqual() {
    let error1 = SearchIndexError.initializationFailed(reason: "test")
    let error2 = SearchIndexError.databaseError(reason: "test")

    #expect(error1 != error2)
  }
}

// MARK: - SearchIndexConfiguration Tests

@Suite("SearchIndexConfiguration Tests")
struct SearchIndexConfigurationTests {

  @Test("default configuration has expected values")
  func defaultConfigurationValues() {
    let config = SearchIndexConfiguration.default

    #expect(config.databaseDirectory == "SearchIndex")
    #expect(config.databaseFileName == "search.sqlite")
    #expect(config.defaultSearchLimit == 50)
    #expect(config.snippetLength == 100)
  }

  @Test("testing configuration has expected values")
  func testingConfigurationValues() {
    let config = SearchIndexConfiguration.testing

    #expect(config.databaseDirectory == ":memory:")
    #expect(config.databaseFileName == "")
    #expect(config.defaultSearchLimit == 10)
    #expect(config.snippetLength == 50)
  }

  @Test("custom configuration can be created")
  func customConfiguration() {
    let config = SearchIndexConfiguration(
      databaseDirectory: "CustomDir",
      databaseFileName: "custom.sqlite",
      defaultSearchLimit: 25,
      snippetLength: 150
    )

    #expect(config.databaseDirectory == "CustomDir")
    #expect(config.databaseFileName == "custom.sqlite")
    #expect(config.defaultSearchLimit == 25)
    #expect(config.snippetLength == 150)
  }
}

// MARK: - SearchIndexConstants Tests

@Suite("SearchIndexConstants Tests")
struct SearchIndexConstantsTests {

  @Test("FTS table name is defined")
  func ftsTableName() {
    #expect(SearchIndexConstants.ftsTableName == "document_search")
  }

  @Test("tokenizer configuration is defined")
  func tokenizerConfig() {
    #expect(SearchIndexConstants.tokenizerConfig == "porter unicode61")
  }

  @Test("title weight is higher than content weight")
  func titleWeightHigher() {
    #expect(SearchIndexConstants.titleWeight > SearchIndexConstants.contentWeight)
    #expect(SearchIndexConstants.titleWeight == 2.0)
    #expect(SearchIndexConstants.contentWeight == 1.0)
  }

  @Test("debounce interval is positive")
  func debounceInterval() {
    #expect(SearchIndexConstants.indexingDebounceInterval > 0)
    #expect(SearchIndexConstants.indexingDebounceInterval == 2.0)
  }
}

// MARK: - SearchIndexProtocol Initialize Tests

@Suite("SearchIndex Initialize Tests")
struct SearchIndexInitializeTests {

  @Test("initialize can be called on mock")
  func initializeCallable() async throws {
    let mockIndex = MockSearchIndex()

    try await mockIndex.initialize()

    let callCount = await mockIndex.initializeCallCount
    #expect(callCount == 1)
  }

  @Test("initialize is idempotent - multiple calls succeed")
  func initializeIdempotent() async throws {
    let mockIndex = MockSearchIndex()

    try await mockIndex.initialize()
    try await mockIndex.initialize()
    try await mockIndex.initialize()

    let callCount = await mockIndex.initializeCallCount
    #expect(callCount == 3)
  }

  @Test("initialize throws when configured to throw")
  func initializeThrowsError() async {
    let mockIndex = MockSearchIndex()
    await mockIndex.setError(.initializationFailed(reason: "Database locked"))

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.initialize()
    }
  }
}

// Helper extension to set error on mock.
extension MockSearchIndex {
  func setError(_ error: SearchIndexError?) async {
    self.errorToThrow = error
  }

  func setSearchResults(_ results: [IndexedMatch]) async {
    self.searchResultsToReturn = results
  }
}

// MARK: - SearchIndexProtocol indexDocument Tests

@Suite("SearchIndex indexDocument Tests")
struct SearchIndexIndexDocumentTests {

  @Test("indexDocument indexes new document")
  func indexNewDocument() async throws {
    let mockIndex = MockSearchIndex()
    try await mockIndex.initialize()

    let entry = SearchIndexTestFixtures.notebookEntry()
    try await mockIndex.indexDocument(entry)

    let isIndexed = await mockIndex.isDocumentIndexed(documentID: entry.documentID)
    #expect(isIndexed == true)
  }

  @Test("indexDocument records the entry")
  func indexDocumentRecordsEntry() async throws {
    let mockIndex = MockSearchIndex()
    let entry = SearchIndexTestFixtures.notebookEntry(id: "test-doc")

    try await mockIndex.indexDocument(entry)

    let calls = await mockIndex.indexDocumentCalls
    #expect(calls.count == 1)
    #expect(calls.first?.documentID == "test-doc")
  }

  @Test("indexDocument updates existing document")
  func indexDocumentUpdatesExisting() async throws {
    let mockIndex = MockSearchIndex()

    let entry1 = SearchIndexTestFixtures.notebookEntry(id: "doc1", content: "old text")
    try await mockIndex.indexDocument(entry1)

    let entry2 = SearchIndexTestFixtures.notebookEntry(id: "doc1", content: "new text")
    try await mockIndex.indexDocument(entry2)

    let calls = await mockIndex.indexDocumentCalls
    #expect(calls.count == 2)
    #expect(calls.last?.contentText == "new text")
  }

  @Test("indexDocument with empty content succeeds")
  func indexEmptyContent() async throws {
    let mockIndex = MockSearchIndex()

    let entry = SearchIndexTestFixtures.emptyContentEntry
    try await mockIndex.indexDocument(entry)

    let isIndexed = await mockIndex.isDocumentIndexed(documentID: entry.documentID)
    #expect(isIndexed == true)
  }

  @Test("indexDocument with special characters succeeds")
  func indexSpecialCharacters() async throws {
    let mockIndex = MockSearchIndex()

    let entry = SearchIndexTestFixtures.specialCharactersEntry
    try await mockIndex.indexDocument(entry)

    let isIndexed = await mockIndex.isDocumentIndexed(documentID: entry.documentID)
    #expect(isIndexed == true)
  }

  @Test("indexDocument throws configured error")
  func indexDocumentThrowsError() async {
    let mockIndex = MockSearchIndex()
    await mockIndex.setError(.databaseError(reason: "Insert failed"))

    let entry = SearchIndexTestFixtures.notebookEntry()

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.indexDocument(entry)
    }
  }
}

// MARK: - SearchIndexProtocol indexDocuments Tests

@Suite("SearchIndex indexDocuments Tests")
struct SearchIndexIndexDocumentsTests {

  @Test("indexDocuments indexes multiple documents")
  func indexMultipleDocuments() async throws {
    let mockIndex = MockSearchIndex()

    let entries = SearchIndexTestFixtures.bulkEntries(count: 5)
    try await mockIndex.indexDocuments(entries)

    for entry in entries {
      let isIndexed = await mockIndex.isDocumentIndexed(documentID: entry.documentID)
      #expect(isIndexed == true)
    }
  }

  @Test("indexDocuments records batch")
  func indexDocumentsRecordsBatch() async throws {
    let mockIndex = MockSearchIndex()

    let entries = SearchIndexTestFixtures.bulkEntries(count: 10)
    try await mockIndex.indexDocuments(entries)

    let calls = await mockIndex.indexDocumentsCalls
    #expect(calls.count == 1)
    #expect(calls.first?.count == 10)
  }

  @Test("indexDocuments with empty array is no-op")
  func indexEmptyArray() async throws {
    let mockIndex = MockSearchIndex()

    try await mockIndex.indexDocuments([])

    let calls = await mockIndex.indexDocumentsCalls
    #expect(calls.count == 1)
    #expect(calls.first?.isEmpty == true)
  }

  @Test("indexDocuments with large batch succeeds")
  func indexLargeBatch() async throws {
    let mockIndex = MockSearchIndex()

    let entries = SearchIndexTestFixtures.bulkEntries(count: 100)
    try await mockIndex.indexDocuments(entries)

    let calls = await mockIndex.indexDocumentsCalls
    #expect(calls.first?.count == 100)
  }

  @Test("indexDocuments throws configured error")
  func indexDocumentsThrowsError() async {
    let mockIndex = MockSearchIndex()
    await mockIndex.setError(.databaseError(reason: "Transaction failed"))

    let entries = SearchIndexTestFixtures.bulkEntries(count: 3)

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.indexDocuments(entries)
    }
  }
}

// MARK: - SearchIndexProtocol removeDocument Tests

@Suite("SearchIndex removeDocument Tests")
struct SearchIndexRemoveDocumentTests {

  @Test("removeDocument removes indexed document")
  func removeIndexedDocument() async throws {
    let mockIndex = MockSearchIndex()

    let entry = SearchIndexTestFixtures.notebookEntry(id: "doc-to-remove")
    try await mockIndex.indexDocument(entry)

    var isIndexed = await mockIndex.isDocumentIndexed(documentID: "doc-to-remove")
    #expect(isIndexed == true)

    try await mockIndex.removeDocument(documentID: "doc-to-remove")

    isIndexed = await mockIndex.isDocumentIndexed(documentID: "doc-to-remove")
    #expect(isIndexed == false)
  }

  @Test("removeDocument records removal")
  func removeDocumentRecordsRemoval() async throws {
    let mockIndex = MockSearchIndex()

    try await mockIndex.removeDocument(documentID: "some-doc")

    let calls = await mockIndex.removeDocumentCalls
    #expect(calls.count == 1)
    #expect(calls.first == "some-doc")
  }

  @Test("removeDocument for non-existent document is no-op")
  func removeNonExistentDocument() async throws {
    let mockIndex = MockSearchIndex()

    // Should not throw.
    try await mockIndex.removeDocument(documentID: "non-existent")

    let calls = await mockIndex.removeDocumentCalls
    #expect(calls.count == 1)
  }

  @Test("remove and re-index document succeeds")
  func removeAndReindex() async throws {
    let mockIndex = MockSearchIndex()

    let entry = SearchIndexTestFixtures.notebookEntry(id: "doc-1")
    try await mockIndex.indexDocument(entry)
    try await mockIndex.removeDocument(documentID: "doc-1")

    var isIndexed = await mockIndex.isDocumentIndexed(documentID: "doc-1")
    #expect(isIndexed == false)

    try await mockIndex.indexDocument(entry)

    isIndexed = await mockIndex.isDocumentIndexed(documentID: "doc-1")
    #expect(isIndexed == true)
  }
}

// MARK: - SearchIndexProtocol search Tests

@Suite("SearchIndex search Tests")
struct SearchIndexSearchTests {

  @Test("search records query parameters")
  func searchRecordsParameters() async throws {
    let mockIndex = MockSearchIndex()

    _ = try await mockIndex.search(query: "budget", scope: .all, limit: 10)

    let calls = await mockIndex.searchCalls
    #expect(calls.count == 1)
    #expect(calls.first?.query == "budget")
    #expect(calls.first?.scope == .all)
    #expect(calls.first?.limit == 10)
  }

  @Test("search with folder scope records correct scope")
  func searchWithFolderScope() async throws {
    let mockIndex = MockSearchIndex()

    _ = try await mockIndex.search(query: "notes", scope: .folder(id: "work"), limit: 10)

    let calls = await mockIndex.searchCalls
    #expect(calls.first?.scope == .folder(id: "work"))
  }

  @Test("search with document scope records correct scope")
  func searchWithDocumentScope() async throws {
    let mockIndex = MockSearchIndex()

    _ = try await mockIndex.search(query: "chapter", scope: .document(id: "book1"), limit: 10)

    let calls = await mockIndex.searchCalls
    #expect(calls.first?.scope == .document(id: "book1"))
  }

  @Test("search returns configured results")
  func searchReturnsConfiguredResults() async throws {
    let mockIndex = MockSearchIndex()
    let expectedResults = [
      IndexedMatch(
        documentID: "doc-1",
        documentType: .notebook,
        title: "Budget Report",
        snippet: "...annual budget review...",
        folderID: nil,
        relevanceRank: 2.5
      )
    ]
    await mockIndex.setSearchResults(expectedResults)

    let results = try await mockIndex.search(query: "budget", scope: .all, limit: 10)

    #expect(results.count == 1)
    #expect(results.first?.documentID == "doc-1")
    #expect(results.first?.relevanceRank == 2.5)
  }

  @Test("search with no results returns empty array")
  func searchNoResults() async throws {
    let mockIndex = MockSearchIndex()
    await mockIndex.setSearchResults([])

    let results = try await mockIndex.search(query: "xyznonexistent", scope: .all, limit: 10)

    #expect(results.isEmpty)
  }

  @Test("search throws configured error")
  func searchThrowsError() async {
    let mockIndex = MockSearchIndex()
    await mockIndex.setError(.invalidQuery(query: ""))

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.search(query: "", scope: .all, limit: 10)
    }
  }

  @Test("search with limit 0 records correct limit")
  func searchWithZeroLimit() async throws {
    let mockIndex = MockSearchIndex()

    _ = try await mockIndex.search(query: "test", scope: .all, limit: 0)

    let calls = await mockIndex.searchCalls
    #expect(calls.first?.limit == 0)
  }
}

// MARK: - SearchIndexProtocol isDocumentIndexed Tests

@Suite("SearchIndex isDocumentIndexed Tests")
struct SearchIndexIsDocumentIndexedTests {

  @Test("isDocumentIndexed returns true for indexed document")
  func isIndexedReturnsTrue() async throws {
    let mockIndex = MockSearchIndex()

    let entry = SearchIndexTestFixtures.notebookEntry(id: "indexed-doc")
    try await mockIndex.indexDocument(entry)

    let result = await mockIndex.isDocumentIndexed(documentID: "indexed-doc")
    #expect(result == true)
  }

  @Test("isDocumentIndexed returns false for non-indexed document")
  func isIndexedReturnsFalse() async {
    let mockIndex = MockSearchIndex()

    let result = await mockIndex.isDocumentIndexed(documentID: "not-indexed")
    #expect(result == false)
  }

  @Test("isDocumentIndexed records check")
  func isIndexedRecordsCheck() async {
    let mockIndex = MockSearchIndex()

    _ = await mockIndex.isDocumentIndexed(documentID: "doc-check")

    let calls = await mockIndex.isDocumentIndexedCalls
    #expect(calls.count == 1)
    #expect(calls.first == "doc-check")
  }

  @Test("isDocumentIndexed returns false after removal")
  func isIndexedAfterRemoval() async throws {
    let mockIndex = MockSearchIndex()

    let entry = SearchIndexTestFixtures.notebookEntry(id: "doc-1")
    try await mockIndex.indexDocument(entry)
    try await mockIndex.removeDocument(documentID: "doc-1")

    let result = await mockIndex.isDocumentIndexed(documentID: "doc-1")
    #expect(result == false)
  }
}

// MARK: - SearchIndexProtocol documentNeedsReindex Tests

@Suite("SearchIndex documentNeedsReindex Tests")
struct SearchIndexDocumentNeedsReindexTests {

  @Test("documentNeedsReindex returns true for non-indexed document")
  func needsReindexForNewDocument() async {
    let mockIndex = MockSearchIndex()

    let result = await mockIndex.documentNeedsReindex(
      documentID: "new-doc",
      modifiedAt: Date()
    )

    #expect(result == true)
  }

  @Test("documentNeedsReindex returns true for outdated document")
  func needsReindexForOutdated() async throws {
    let mockIndex = MockSearchIndex()

    let oldDate = Date(timeIntervalSince1970: 1704067200)  // 2024-01-01
    let entry = SearchIndexTestFixtures.notebookEntry(id: "doc-1", modifiedAt: oldDate)
    try await mockIndex.indexDocument(entry)

    let newDate = Date(timeIntervalSince1970: 1718409600)  // 2024-06-15
    let result = await mockIndex.documentNeedsReindex(documentID: "doc-1", modifiedAt: newDate)

    #expect(result == true)
  }

  @Test("documentNeedsReindex returns false for up-to-date document")
  func needsReindexForUpToDate() async throws {
    let mockIndex = MockSearchIndex()

    let date = Date(timeIntervalSince1970: 1718409600)  // 2024-06-15
    let entry = SearchIndexTestFixtures.notebookEntry(id: "doc-1", modifiedAt: date)
    try await mockIndex.indexDocument(entry)

    let result = await mockIndex.documentNeedsReindex(documentID: "doc-1", modifiedAt: date)

    #expect(result == false)
  }

  @Test("documentNeedsReindex returns false for newer indexed version")
  func needsReindexForNewerIndexed() async throws {
    let mockIndex = MockSearchIndex()

    let newDate = Date(timeIntervalSince1970: 1718409600)  // 2024-06-15
    let entry = SearchIndexTestFixtures.notebookEntry(id: "doc-1", modifiedAt: newDate)
    try await mockIndex.indexDocument(entry)

    let oldDate = Date(timeIntervalSince1970: 1704067200)  // 2024-01-01
    let result = await mockIndex.documentNeedsReindex(documentID: "doc-1", modifiedAt: oldDate)

    #expect(result == false)
  }

  @Test("documentNeedsReindex records check")
  func needsReindexRecordsCheck() async {
    let mockIndex = MockSearchIndex()
    let date = Date()

    _ = await mockIndex.documentNeedsReindex(documentID: "doc-check", modifiedAt: date)

    let calls = await mockIndex.documentNeedsReindexCalls
    #expect(calls.count == 1)
    #expect(calls.first?.documentID == "doc-check")
  }
}

// MARK: - SearchIndexProtocol clearIndex Tests

@Suite("SearchIndex clearIndex Tests")
struct SearchIndexClearIndexTests {

  @Test("clearIndex removes all documents")
  func clearRemovesAll() async throws {
    let mockIndex = MockSearchIndex()

    let entries = SearchIndexTestFixtures.bulkEntries(count: 5)
    try await mockIndex.indexDocuments(entries)

    try await mockIndex.clearIndex()

    for entry in entries {
      let isIndexed = await mockIndex.isDocumentIndexed(documentID: entry.documentID)
      #expect(isIndexed == false)
    }
  }

  @Test("clearIndex records call")
  func clearRecordsCall() async throws {
    let mockIndex = MockSearchIndex()

    try await mockIndex.clearIndex()

    let callCount = await mockIndex.clearIndexCallCount
    #expect(callCount == 1)
  }

  @Test("clearIndex on empty index is no-op")
  func clearEmptyIndex() async throws {
    let mockIndex = MockSearchIndex()

    try await mockIndex.clearIndex()

    let callCount = await mockIndex.clearIndexCallCount
    #expect(callCount == 1)
  }

  @Test("index usable after clear")
  func indexUsableAfterClear() async throws {
    let mockIndex = MockSearchIndex()

    let entry1 = SearchIndexTestFixtures.notebookEntry(id: "doc-1")
    try await mockIndex.indexDocument(entry1)
    try await mockIndex.clearIndex()

    let entry2 = SearchIndexTestFixtures.notebookEntry(id: "doc-2")
    try await mockIndex.indexDocument(entry2)

    let isIndexed = await mockIndex.isDocumentIndexed(documentID: "doc-2")
    #expect(isIndexed == true)
  }

  @Test("clearIndex throws configured error")
  func clearThrowsError() async {
    let mockIndex = MockSearchIndex()
    await mockIndex.setError(.databaseError(reason: "Clear failed"))

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.clearIndex()
    }
  }
}

// MARK: - Edge Case Tests

@Suite("SearchIndex Edge Case Tests")
struct SearchIndexEdgeCaseTests {

  @Test("search with empty query throws invalidQuery error")
  func emptyQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    await mockIndex.setError(.invalidQuery(query: ""))

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.search(query: "", scope: .all, limit: 10)
    }
  }

  @Test("search with whitespace-only query throws invalidQuery error")
  func whitespaceQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    await mockIndex.setError(.invalidQuery(query: "   "))

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.search(query: "   ", scope: .all, limit: 10)
    }
  }

  @Test("indexDocument with very long content succeeds")
  func indexVeryLongContent() async throws {
    let mockIndex = MockSearchIndex()

    let entry = SearchIndexTestFixtures.longContentEntry()
    try await mockIndex.indexDocument(entry)

    let isIndexed = await mockIndex.isDocumentIndexed(documentID: entry.documentID)
    #expect(isIndexed == true)
  }

  @Test("search scope with non-existent folder returns empty results")
  func searchNonExistentFolder() async throws {
    let mockIndex = MockSearchIndex()
    await mockIndex.setSearchResults([])

    let results = try await mockIndex.search(
      query: "test",
      scope: .folder(id: "deleted-folder"),
      limit: 10
    )

    #expect(results.isEmpty)
  }

  @Test("search scope with non-existent document returns empty results")
  func searchNonExistentDocument() async throws {
    let mockIndex = MockSearchIndex()
    await mockIndex.setSearchResults([])

    let results = try await mockIndex.search(
      query: "test",
      scope: .document(id: "deleted-doc"),
      limit: 10
    )

    #expect(results.isEmpty)
  }

  @Test("negative limit is handled")
  func negativeLimitHandled() async throws {
    let mockIndex = MockSearchIndex()

    // Mock should record the negative limit; real impl would handle appropriately.
    _ = try await mockIndex.search(query: "test", scope: .all, limit: -5)

    let calls = await mockIndex.searchCalls
    #expect(calls.first?.limit == -5)
  }

  @Test("search with SQL injection attempt is safe")
  func sqlInjectionSafe() async throws {
    let mockIndex = MockSearchIndex()
    await mockIndex.setSearchResults([])

    // This should be treated as a literal search string, not SQL.
    let results = try await mockIndex.search(
      query: "'; DROP TABLE documents; --",
      scope: .all,
      limit: 10
    )

    // If we get here without crash, the mock handled it safely.
    // Real implementation must escape this properly.
    #expect(results.isEmpty)
  }

  @Test("concurrent operations are serialized by actor")
  func concurrentOperations() async throws {
    let mockIndex = MockSearchIndex()

    // Launch multiple concurrent operations.
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<10 {
        group.addTask {
          let entry = SearchIndexTestFixtures.notebookEntry(id: "concurrent-\(i)")
          try? await mockIndex.indexDocument(entry)
        }
      }
    }

    // All operations should complete without error.
    let calls = await mockIndex.indexDocumentCalls
    #expect(calls.count == 10)
  }
}

// MARK: - MockSearchIndex Verification Tests

@Suite("MockSearchIndex Tests")
struct MockSearchIndexTests {

  @Test("reset clears all tracking state")
  func resetClearsState() async throws {
    let mockIndex = MockSearchIndex()

    // Perform various operations.
    try await mockIndex.initialize()
    let entry = SearchIndexTestFixtures.notebookEntry()
    try await mockIndex.indexDocument(entry)
    try await mockIndex.indexDocuments([entry])
    try await mockIndex.removeDocument(documentID: "test")
    _ = try await mockIndex.search(query: "test", scope: .all, limit: 10)
    _ = await mockIndex.isDocumentIndexed(documentID: "test")
    _ = await mockIndex.documentNeedsReindex(documentID: "test", modifiedAt: Date())
    try await mockIndex.clearIndex()

    // Reset.
    await mockIndex.reset()

    // Verify all tracking is cleared.
    let initCount = await mockIndex.initializeCallCount
    let indexDocCalls = await mockIndex.indexDocumentCalls
    let indexDocsCalls = await mockIndex.indexDocumentsCalls
    let removeCalls = await mockIndex.removeDocumentCalls
    let searchCalls = await mockIndex.searchCalls
    let isIndexedCalls = await mockIndex.isDocumentIndexedCalls
    let needsReindexCalls = await mockIndex.documentNeedsReindexCalls
    let clearCount = await mockIndex.clearIndexCallCount

    #expect(initCount == 0)
    #expect(indexDocCalls.isEmpty)
    #expect(indexDocsCalls.isEmpty)
    #expect(removeCalls.isEmpty)
    #expect(searchCalls.isEmpty)
    #expect(isIndexedCalls.isEmpty)
    #expect(needsReindexCalls.isEmpty)
    #expect(clearCount == 0)
  }

  @Test("error configuration affects operations")
  func errorConfigurationWorks() async {
    let mockIndex = MockSearchIndex()

    await mockIndex.setError(.fileSystemError(reason: "Disk full"))

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.initialize()
    }

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.indexDocument(SearchIndexTestFixtures.notebookEntry())
    }

    await #expect(throws: SearchIndexError.self) {
      try await mockIndex.clearIndex()
    }
  }

  @Test("search results configuration works")
  func searchResultsConfigurationWorks() async throws {
    let mockIndex = MockSearchIndex()

    let matches = [
      IndexedMatch(
        documentID: "result-1",
        documentType: .notebook,
        title: "Result 1",
        snippet: "Snippet 1",
        folderID: nil,
        relevanceRank: 1.0
      ),
      IndexedMatch(
        documentID: "result-2",
        documentType: .pdf,
        title: "Result 2",
        snippet: "Snippet 2",
        folderID: "folder",
        relevanceRank: 0.5
      )
    ]
    await mockIndex.setSearchResults(matches)

    let results = try await mockIndex.search(query: "test", scope: .all, limit: 10)

    #expect(results.count == 2)
    #expect(results[0].documentID == "result-1")
    #expect(results[1].documentID == "result-2")
  }
}

// MARK: - SearchIndexTriggers Mock

// Mock implementation for testing SearchIndexTriggersProtocol behavior.
final class MockSearchIndexTriggers: SearchIndexTriggersProtocol {

  // Tracks observer lifecycle.
  private(set) var isObserving = false
  private(set) var startObservingCallCount = 0
  private(set) var stopObservingCallCount = 0

  // Tracks received notifications.
  private(set) var receivedNotebookIDs: [String] = []
  private(set) var receivedPDFIDs: [String] = []

  func startObserving() {
    startObservingCallCount += 1
    isObserving = true
  }

  func stopObserving() {
    stopObservingCallCount += 1
    isObserving = false
  }

  // Test helper to simulate receiving a notebook notification.
  func simulateNotebookContentSaved(documentID: String) {
    guard isObserving else { return }
    receivedNotebookIDs.append(documentID)
  }

  // Test helper to simulate receiving a PDF notification.
  func simulatePDFDocumentImported(documentID: String) {
    guard isObserving else { return }
    receivedPDFIDs.append(documentID)
  }

  // Test helper to reset state.
  func reset() {
    isObserving = false
    startObservingCallCount = 0
    stopObservingCallCount = 0
    receivedNotebookIDs = []
    receivedPDFIDs = []
  }
}

// MARK: - SearchIndexTriggers Tests

@Suite("SearchIndexTriggers Tests")
struct SearchIndexTriggersTests {

  @Test("startObserving sets observing state")
  func startObservingSetsState() {
    let triggers = MockSearchIndexTriggers()

    triggers.startObserving()

    #expect(triggers.isObserving == true)
    #expect(triggers.startObservingCallCount == 1)
  }

  @Test("stopObserving clears observing state")
  func stopObservingClearsState() {
    let triggers = MockSearchIndexTriggers()
    triggers.startObserving()

    triggers.stopObserving()

    #expect(triggers.isObserving == false)
    #expect(triggers.stopObservingCallCount == 1)
  }

  @Test("stopObserving when not started is safe")
  func stopObservingWhenNotStarted() {
    let triggers = MockSearchIndexTriggers()

    // Should not crash or error.
    triggers.stopObserving()

    #expect(triggers.isObserving == false)
    #expect(triggers.stopObservingCallCount == 1)
  }

  @Test("notifications received when observing")
  func notificationsReceivedWhenObserving() {
    let triggers = MockSearchIndexTriggers()
    triggers.startObserving()

    triggers.simulateNotebookContentSaved(documentID: "nb-1")
    triggers.simulatePDFDocumentImported(documentID: "pdf-1")

    #expect(triggers.receivedNotebookIDs.count == 1)
    #expect(triggers.receivedNotebookIDs.first == "nb-1")
    #expect(triggers.receivedPDFIDs.count == 1)
    #expect(triggers.receivedPDFIDs.first == "pdf-1")
  }

  @Test("notifications ignored when not observing")
  func notificationsIgnoredWhenNotObserving() {
    let triggers = MockSearchIndexTriggers()
    // Do not call startObserving.

    triggers.simulateNotebookContentSaved(documentID: "nb-1")
    triggers.simulatePDFDocumentImported(documentID: "pdf-1")

    #expect(triggers.receivedNotebookIDs.isEmpty)
    #expect(triggers.receivedPDFIDs.isEmpty)
  }

  @Test("notifications ignored after stopObserving")
  func notificationsIgnoredAfterStop() {
    let triggers = MockSearchIndexTriggers()
    triggers.startObserving()
    triggers.stopObserving()

    triggers.simulateNotebookContentSaved(documentID: "nb-1")

    #expect(triggers.receivedNotebookIDs.isEmpty)
  }

  @Test("multiple start calls increment count")
  func multipleStartCalls() {
    let triggers = MockSearchIndexTriggers()

    triggers.startObserving()
    triggers.startObserving()

    #expect(triggers.startObservingCallCount == 2)
    #expect(triggers.isObserving == true)
  }

  @Test("reset clears all state")
  func resetClearsAllState() {
    let triggers = MockSearchIndexTriggers()
    triggers.startObserving()
    triggers.simulateNotebookContentSaved(documentID: "nb-1")
    triggers.stopObserving()

    triggers.reset()

    #expect(triggers.isObserving == false)
    #expect(triggers.startObservingCallCount == 0)
    #expect(triggers.stopObservingCallCount == 0)
    #expect(triggers.receivedNotebookIDs.isEmpty)
    #expect(triggers.receivedPDFIDs.isEmpty)
  }
}

// MARK: - Integration Scenario Tests

@Suite("Search Index Integration Scenarios")
struct SearchIndexIntegrationTests {

  @Test("full workflow: initialize, index, search, remove, clear")
  func fullWorkflow() async throws {
    let mockIndex = MockSearchIndex()

    // Initialize.
    try await mockIndex.initialize()

    // Index multiple documents.
    let notebook = SearchIndexTestFixtures.notebookEntry(
      id: "nb-1",
      title: "Meeting Notes",
      content: "Budget meeting discussion"
    )
    let pdf = SearchIndexTestFixtures.pdfEntry(
      id: "pdf-1",
      title: "Budget Report",
      content: "Annual budget analysis"
    )
    try await mockIndex.indexDocument(notebook)
    try await mockIndex.indexDocument(pdf)

    // Verify indexed.
    let nbIndexed = await mockIndex.isDocumentIndexed(documentID: "nb-1")
    let pdfIndexed = await mockIndex.isDocumentIndexed(documentID: "pdf-1")
    #expect(nbIndexed == true)
    #expect(pdfIndexed == true)

    // Configure and perform search.
    let searchResults = [
      IndexedMatch(
        documentID: "nb-1",
        documentType: .notebook,
        title: "Meeting Notes",
        snippet: "...Budget meeting discussion...",
        folderID: nil,
        relevanceRank: 1.5
      ),
      IndexedMatch(
        documentID: "pdf-1",
        documentType: .pdf,
        title: "Budget Report",
        snippet: "...Annual budget analysis...",
        folderID: nil,
        relevanceRank: 2.0
      )
    ]
    await mockIndex.setSearchResults(searchResults)

    let results = try await mockIndex.search(query: "budget", scope: .all, limit: 10)
    #expect(results.count == 2)

    // Remove one document.
    try await mockIndex.removeDocument(documentID: "nb-1")
    let nbStillIndexed = await mockIndex.isDocumentIndexed(documentID: "nb-1")
    #expect(nbStillIndexed == false)

    // Clear index.
    try await mockIndex.clearIndex()
    let pdfStillIndexed = await mockIndex.isDocumentIndexed(documentID: "pdf-1")
    #expect(pdfStillIndexed == false)
  }

  @Test("folder-scoped search workflow")
  func folderScopedWorkflow() async throws {
    let mockIndex = MockSearchIndex()

    // Index documents in different folders.
    let workDoc = SearchIndexTestFixtures.notebookEntry(
      id: "work-1",
      title: "Work Notes",
      content: "Project meeting notes",
      folderID: "work"
    )
    let personalDoc = SearchIndexTestFixtures.notebookEntry(
      id: "personal-1",
      title: "Personal Notes",
      content: "Personal meeting notes",
      folderID: "personal"
    )
    try await mockIndex.indexDocument(workDoc)
    try await mockIndex.indexDocument(personalDoc)

    // Search in work folder only.
    let workResults = [
      IndexedMatch(
        documentID: "work-1",
        documentType: .notebook,
        title: "Work Notes",
        snippet: "...Project meeting notes...",
        folderID: "work",
        relevanceRank: 1.0
      )
    ]
    await mockIndex.setSearchResults(workResults)

    let results = try await mockIndex.search(query: "notes", scope: .folder(id: "work"), limit: 10)
    #expect(results.count == 1)
    #expect(results.first?.folderID == "work")

    // Verify search was called with correct scope.
    let calls = await mockIndex.searchCalls
    #expect(calls.last?.scope == .folder(id: "work"))
  }

  @Test("reindex check workflow")
  func reindexCheckWorkflow() async throws {
    let mockIndex = MockSearchIndex()

    // Document not indexed - needs reindex.
    let needsReindex1 = await mockIndex.documentNeedsReindex(
      documentID: "new-doc",
      modifiedAt: Date()
    )
    #expect(needsReindex1 == true)

    // Index document with old date.
    let oldDate = Date(timeIntervalSince1970: 1704067200)
    let entry = SearchIndexTestFixtures.notebookEntry(id: "doc-1", modifiedAt: oldDate)
    try await mockIndex.indexDocument(entry)

    // Check with newer date - needs reindex.
    let newDate = Date(timeIntervalSince1970: 1718409600)
    let needsReindex2 = await mockIndex.documentNeedsReindex(documentID: "doc-1", modifiedAt: newDate)
    #expect(needsReindex2 == true)

    // Reindex with new content.
    let updatedEntry = SearchIndexTestFixtures.notebookEntry(
      id: "doc-1",
      content: "Updated content",
      modifiedAt: newDate
    )
    try await mockIndex.indexDocument(updatedEntry)

    // Check with same date - does not need reindex.
    let needsReindex3 = await mockIndex.documentNeedsReindex(documentID: "doc-1", modifiedAt: newDate)
    #expect(needsReindex3 == false)
  }
}
