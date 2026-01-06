// SearchServiceTests.swift
// Comprehensive tests for the Search Service layer.
// These tests validate the SearchServiceProtocol, FolderLookupProtocol,
// and associated types defined in Service/Contract.swift.
// The SearchService transforms raw IndexedMatch results from the SearchIndex
// into UI-ready SearchResult objects.

import Foundation
import Testing

@testable import InkOS

// MARK: - Test Fixtures

// Creates test data for SearchService tests.
enum SearchServiceTestFixtures {

  // Creates an IndexedMatch for testing transformation.
  static func indexedMatch(
    documentID: String = "doc-1",
    documentType: DocumentType = .notebook,
    title: String = "Test Document",
    snippet: String = "...sample content...",
    folderID: String? = nil,
    relevanceRank: Double = 1.0
  ) -> IndexedMatch {
    return IndexedMatch(
      documentID: documentID,
      documentType: documentType,
      title: title,
      snippet: snippet,
      folderID: folderID,
      relevanceRank: relevanceRank
    )
  }

  // Creates an expected SearchResult for assertion.
  static func expectedResult(
    documentID: String = "doc-1",
    documentType: DocumentType = .notebook,
    displayName: String = "Test Document",
    matchSnippet: String = "...sample content...",
    matchSource: MatchSource = .title,
    folderPath: String? = nil,
    modifiedAt: Date = Date()
  ) -> SearchResult {
    return SearchResult(
      documentID: documentID,
      documentType: documentType,
      displayName: displayName,
      matchSnippet: matchSnippet,
      matchSource: matchSource,
      folderPath: folderPath,
      modifiedAt: modifiedAt
    )
  }

  // Creates multiple IndexedMatch instances for bulk testing.
  static func bulkMatches(count: Int, titlePrefix: String = "Document") -> [IndexedMatch] {
    return (0..<count).map { index in
      indexedMatch(
        documentID: "doc-\(index)",
        title: "\(titlePrefix) \(index)",
        snippet: "Content for document \(index)",
        relevanceRank: Double(count - index)
      )
    }
  }

  // Creates a notebook match with title containing the query.
  static func notebookTitleMatch(query: String) -> IndexedMatch {
    return indexedMatch(
      documentID: "notebook-title-match",
      documentType: .notebook,
      title: "Budget Report for Q1",
      snippet: "...quarterly budget analysis...",
      relevanceRank: 2.5
    )
  }

  // Creates a notebook match where query is in content, not title.
  static func notebookContentMatch() -> IndexedMatch {
    return indexedMatch(
      documentID: "notebook-content-match",
      documentType: .notebook,
      title: "Meeting Notes",
      snippet: "...discussed the quarterly budget...",
      relevanceRank: 1.5
    )
  }

  // Creates a PDF match where query is in content, not title.
  static func pdfContentMatch() -> IndexedMatch {
    return indexedMatch(
      documentID: "pdf-content-match",
      documentType: .pdf,
      title: "Annual Report",
      snippet: "...revenue growth analysis...",
      relevanceRank: 1.0
    )
  }

  // Creates a match in a folder.
  static func matchInFolder(folderID: String) -> IndexedMatch {
    return indexedMatch(
      documentID: "doc-in-folder",
      title: "Folder Document",
      snippet: "...content...",
      folderID: folderID,
      relevanceRank: 1.0
    )
  }
}

// MARK: - MockFolderLookup

// Mock implementation of FolderLookupProtocol for testing folder resolution.
final class MockFolderLookup: FolderLookupProtocol, @unchecked Sendable {

  // Configurable folder name mappings.
  var folderNames: [String: String] = [:]

  // Tracks lookup calls for verification.
  private(set) var lookupCalls: [String] = []

  // Lock for thread-safe access to lookupCalls.
  private let lock = NSLock()

  func getFolderDisplayName(folderID: String) async -> String? {
    lock.lock()
    lookupCalls.append(folderID)
    lock.unlock()
    return folderNames[folderID]
  }

  // Test helper to configure folder mappings.
  func setFolderName(_ name: String, forID id: String) {
    folderNames[id] = name
  }

  // Test helper to reset state.
  func reset() {
    lock.lock()
    folderNames = [:]
    lookupCalls = []
    lock.unlock()
  }
}

// MARK: - MatchSource Tests

@Suite("MatchSource Tests")
struct MatchSourceTests {

  @Test("MatchSource has title case")
  func hasTitleCase() {
    let source = MatchSource.title
    #expect(source == .title)
  }

  @Test("MatchSource has handwriting case")
  func hasHandwritingCase() {
    let source = MatchSource.handwriting
    #expect(source == .handwriting)
  }

  @Test("MatchSource has pdfText case")
  func hasPdfTextCase() {
    let source = MatchSource.pdfText
    #expect(source == .pdfText)
  }

  @Test("MatchSource is Equatable")
  func isEquatable() {
    let source1 = MatchSource.title
    let source2 = MatchSource.title
    let source3 = MatchSource.handwriting

    #expect(source1 == source2)
    #expect(source1 != source3)
  }

  @Test("MatchSource is Codable")
  func isCodable() throws {
    let source = MatchSource.handwriting

    let encoder = JSONEncoder()
    let data = try encoder.encode(source)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(MatchSource.self, from: data)

    #expect(decoded == source)
  }

  @Test("MatchSource rawValue is correct")
  func rawValueIsCorrect() {
    #expect(MatchSource.title.rawValue == "title")
    #expect(MatchSource.handwriting.rawValue == "handwriting")
    #expect(MatchSource.pdfText.rawValue == "pdfText")
  }

  @Test("MatchSource can be created from rawValue")
  func canBeCreatedFromRawValue() {
    let title = MatchSource(rawValue: "title")
    let handwriting = MatchSource(rawValue: "handwriting")
    let pdfText = MatchSource(rawValue: "pdfText")

    #expect(title == .title)
    #expect(handwriting == .handwriting)
    #expect(pdfText == .pdfText)
  }

  @Test("MatchSource invalid rawValue returns nil")
  func invalidRawValueReturnsNil() {
    let invalid = MatchSource(rawValue: "invalid")
    #expect(invalid == nil)
  }
}

// MARK: - SearchResult Tests

@Suite("SearchResult Tests")
struct SearchResultTests {

  @Test("SearchResult id property returns documentID")
  func idPropertyReturnsDocumentID() {
    let result = SearchServiceTestFixtures.expectedResult(documentID: "unique-doc-123")

    #expect(result.id == "unique-doc-123")
  }

  @Test("SearchResult conforms to Identifiable")
  func conformsToIdentifiable() {
    let result = SearchServiceTestFixtures.expectedResult()

    // Identifiable requires id property.
    let _: String = result.id
    #expect(result.id == result.documentID)
  }

  @Test("SearchResult is Equatable")
  func isEquatable() {
    let date = Date()
    let result1 = SearchResult(
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Test",
      matchSnippet: "Snippet",
      matchSource: .title,
      folderPath: nil,
      modifiedAt: date
    )
    let result2 = SearchResult(
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Test",
      matchSnippet: "Snippet",
      matchSource: .title,
      folderPath: nil,
      modifiedAt: date
    )

    #expect(result1 == result2)
  }

  @Test("SearchResult with different documentID is not equal")
  func differentDocumentIDNotEqual() {
    let date = Date()
    let result1 = SearchResult(
      documentID: "doc-1",
      documentType: .notebook,
      displayName: "Test",
      matchSnippet: "Snippet",
      matchSource: .title,
      folderPath: nil,
      modifiedAt: date
    )
    let result2 = SearchResult(
      documentID: "doc-2",
      documentType: .notebook,
      displayName: "Test",
      matchSnippet: "Snippet",
      matchSource: .title,
      folderPath: nil,
      modifiedAt: date
    )

    #expect(result1 != result2)
  }

  @Test("SearchResult stores all properties correctly")
  func storesAllProperties() {
    let date = Date()
    let result = SearchResult(
      documentID: "doc-abc",
      documentType: .pdf,
      displayName: "Budget Report",
      matchSnippet: "...annual budget...",
      matchSource: .pdfText,
      folderPath: "Work Projects",
      modifiedAt: date
    )

    #expect(result.documentID == "doc-abc")
    #expect(result.documentType == .pdf)
    #expect(result.displayName == "Budget Report")
    #expect(result.matchSnippet == "...annual budget...")
    #expect(result.matchSource == .pdfText)
    #expect(result.folderPath == "Work Projects")
    #expect(result.modifiedAt == date)
  }

  @Test("SearchResult with nil folderPath indicates root level")
  func nilFolderPathIndicatesRoot() {
    let result = SearchServiceTestFixtures.expectedResult(folderPath: nil)

    #expect(result.folderPath == nil)
  }

  @Test("SearchResult with folderPath indicates folder location")
  func folderPathIndicatesFolderLocation() {
    let result = SearchServiceTestFixtures.expectedResult(folderPath: "My Folder")

    #expect(result.folderPath == "My Folder")
  }
}

// MARK: - InNoteSearchMatch Tests

@Suite("InNoteSearchMatch Tests")
struct InNoteSearchMatchTests {

  @Test("InNoteSearchMatch id property returns matchIndex")
  func idPropertyReturnsMatchIndex() {
    let match = InNoteSearchMatch(
      matchIndex: 5,
      snippet: "...matching text...",
      boundingBox: nil
    )

    #expect(match.id == 5)
  }

  @Test("InNoteSearchMatch conforms to Identifiable")
  func conformsToIdentifiable() {
    let match = InNoteSearchMatch(
      matchIndex: 0,
      snippet: "Snippet",
      boundingBox: nil
    )

    // Identifiable requires id property.
    let _: Int = match.id
    #expect(match.id == match.matchIndex)
  }

  @Test("InNoteSearchMatch is Equatable")
  func isEquatable() {
    let match1 = InNoteSearchMatch(
      matchIndex: 1,
      snippet: "Snippet",
      boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20)
    )
    let match2 = InNoteSearchMatch(
      matchIndex: 1,
      snippet: "Snippet",
      boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20)
    )

    #expect(match1 == match2)
  }

  @Test("InNoteSearchMatch with different matchIndex is not equal")
  func differentMatchIndexNotEqual() {
    let match1 = InNoteSearchMatch(matchIndex: 0, snippet: "Snippet", boundingBox: nil)
    let match2 = InNoteSearchMatch(matchIndex: 1, snippet: "Snippet", boundingBox: nil)

    #expect(match1 != match2)
  }

  @Test("InNoteSearchMatch boundingBox is nil until Phase 5")
  func boundingBoxNilUntilPhase5() {
    let match = InNoteSearchMatch(
      matchIndex: 0,
      snippet: "Some text",
      boundingBox: nil
    )

    #expect(match.boundingBox == nil)
  }

  @Test("InNoteSearchMatch stores snippet correctly")
  func storesSnippetCorrectly() {
    let match = InNoteSearchMatch(
      matchIndex: 2,
      snippet: "...found the matching text here...",
      boundingBox: nil
    )

    #expect(match.snippet == "...found the matching text here...")
  }
}

// MARK: - SearchServiceError Tests

@Suite("SearchServiceError Tests")
struct SearchServiceErrorTests {

  @Test("indexNotInitialized has correct description")
  func indexNotInitializedDescription() {
    let error = SearchServiceError.indexNotInitialized

    #expect(error.errorDescription?.contains("not been initialized") == true)
  }

  @Test("emptyQuery has correct description")
  func emptyQueryDescription() {
    let error = SearchServiceError.emptyQuery

    #expect(error.errorDescription?.contains("cannot be empty") == true)
  }

  @Test("folderLookupFailed has correct description with reason")
  func folderLookupFailedDescription() {
    let error = SearchServiceError.folderLookupFailed(reason: "Folder not found")

    #expect(error.errorDescription?.contains("Failed to look up folder") == true)
    #expect(error.errorDescription?.contains("Folder not found") == true)
  }

  @Test("indexError wraps underlying error")
  func indexErrorWrapsUnderlying() {
    let underlyingError = SearchIndexError.invalidQuery(query: "")
    let error = SearchServiceError.indexError(underlyingError)

    #expect(error.errorDescription?.contains("Search index error") == true)
  }

  @Test("indexNotInitialized errors are equal")
  func indexNotInitializedEqual() {
    let error1 = SearchServiceError.indexNotInitialized
    let error2 = SearchServiceError.indexNotInitialized

    #expect(error1 == error2)
  }

  @Test("emptyQuery errors are equal")
  func emptyQueryEqual() {
    let error1 = SearchServiceError.emptyQuery
    let error2 = SearchServiceError.emptyQuery

    #expect(error1 == error2)
  }

  @Test("folderLookupFailed errors with same reason are equal")
  func folderLookupFailedSameReasonEqual() {
    let error1 = SearchServiceError.folderLookupFailed(reason: "Not found")
    let error2 = SearchServiceError.folderLookupFailed(reason: "Not found")

    #expect(error1 == error2)
  }

  @Test("folderLookupFailed errors with different reasons are not equal")
  func folderLookupFailedDifferentReasonsNotEqual() {
    let error1 = SearchServiceError.folderLookupFailed(reason: "Reason 1")
    let error2 = SearchServiceError.folderLookupFailed(reason: "Reason 2")

    #expect(error1 != error2)
  }

  @Test("indexError errors with same underlying error are equal")
  func indexErrorSameUnderlyingEqual() {
    let underlying1 = SearchIndexError.invalidQuery(query: "test")
    let underlying2 = SearchIndexError.invalidQuery(query: "test")
    let error1 = SearchServiceError.indexError(underlying1)
    let error2 = SearchServiceError.indexError(underlying2)

    #expect(error1 == error2)
  }

  @Test("indexError errors with different underlying errors are not equal")
  func indexErrorDifferentUnderlyingNotEqual() {
    let underlying1 = SearchIndexError.invalidQuery(query: "test1")
    let underlying2 = SearchIndexError.invalidQuery(query: "test2")
    let error1 = SearchServiceError.indexError(underlying1)
    let error2 = SearchServiceError.indexError(underlying2)

    #expect(error1 != error2)
  }

  @Test("different error types are not equal")
  func differentTypesNotEqual() {
    let error1 = SearchServiceError.indexNotInitialized
    let error2 = SearchServiceError.emptyQuery
    let error3 = SearchServiceError.folderLookupFailed(reason: "test")

    #expect(error1 != error2)
    #expect(error2 != error3)
    #expect(error1 != error3)
  }
}

// MARK: - SearchServiceConstants Tests

@Suite("SearchServiceConstants Tests")
struct SearchServiceConstantsTests {

  @Test("defaultResultLimit is 25")
  func defaultResultLimitIs25() {
    #expect(SearchServiceConstants.defaultResultLimit == 25)
  }

  @Test("defaultResultLimit is positive")
  func defaultResultLimitIsPositive() {
    #expect(SearchServiceConstants.defaultResultLimit > 0)
  }
}

// MARK: - MockFolderLookup Tests

@Suite("MockFolderLookup Tests")
struct MockFolderLookupTests {

  @Test("returns configured folder name")
  func returnsConfiguredFolderName() async {
    let lookup = MockFolderLookup()
    lookup.setFolderName("Work Projects", forID: "folder-123")

    let name = await lookup.getFolderDisplayName(folderID: "folder-123")

    #expect(name == "Work Projects")
  }

  @Test("returns nil for unconfigured folder")
  func returnsNilForUnconfigured() async {
    let lookup = MockFolderLookup()

    let name = await lookup.getFolderDisplayName(folderID: "unknown-folder")

    #expect(name == nil)
  }

  @Test("tracks lookup calls")
  func tracksLookupCalls() async {
    let lookup = MockFolderLookup()

    _ = await lookup.getFolderDisplayName(folderID: "folder-1")
    _ = await lookup.getFolderDisplayName(folderID: "folder-2")
    _ = await lookup.getFolderDisplayName(folderID: "folder-1")

    #expect(lookup.lookupCalls.count == 3)
    #expect(lookup.lookupCalls[0] == "folder-1")
    #expect(lookup.lookupCalls[1] == "folder-2")
    #expect(lookup.lookupCalls[2] == "folder-1")
  }

  @Test("reset clears all state")
  func resetClearsAllState() async {
    let lookup = MockFolderLookup()
    lookup.setFolderName("Test", forID: "folder-1")
    _ = await lookup.getFolderDisplayName(folderID: "folder-1")

    lookup.reset()

    #expect(lookup.folderNames.isEmpty)
    #expect(lookup.lookupCalls.isEmpty)
  }
}

// MARK: - SearchService searchAll Tests

@Suite("SearchService searchAll Tests")
struct SearchServiceSearchAllTests {

  @Test("searchAll with empty query throws emptyQuery error")
  func emptyQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await #expect(throws: SearchServiceError.self) {
      _ = try await service.searchAll(query: "")
    }
  }

  @Test("searchAll with whitespace-only query throws emptyQuery error")
  func whitespaceQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await #expect(throws: SearchServiceError.self) {
      _ = try await service.searchAll(query: "   ")
    }
  }

  @Test("searchAll trims query before validation")
  func trimsQueryBeforeValidation() async {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Query with leading/trailing whitespace but valid content should work.
    await mockIndex.setSearchResults([])
    let results = try? await service.searchAll(query: "  meeting  ")

    // If it did not throw, the query was trimmed and processed.
    #expect(results != nil)
  }

  @Test("searchAll returns empty array when no matches")
  func returnsEmptyArrayWhenNoMatches() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])

    let results = try await service.searchAll(query: "nonexistent")

    #expect(results.isEmpty)
  }

  @Test("searchAll transforms IndexedMatch to SearchResult")
  func transformsIndexedMatchToSearchResult() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let match = SearchServiceTestFixtures.indexedMatch(
      documentID: "doc-1",
      documentType: .notebook,
      title: "Budget Meeting",
      snippet: "...budget discussion...",
      folderID: nil,
      relevanceRank: 2.0
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "budget")

    #expect(results.count == 1)
    #expect(results.first?.documentID == "doc-1")
    #expect(results.first?.documentType == .notebook)
    #expect(results.first?.displayName == "Budget Meeting")
    #expect(results.first?.matchSnippet == "...budget discussion...")
  }

  @Test("searchAll resolves folderID to folderPath")
  func resolvesFolderIDToFolderPath() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    mockLookup.setFolderName("Work Projects", forID: "folder-abc")
    let match = SearchServiceTestFixtures.matchInFolder(folderID: "folder-abc")
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "test")

    #expect(results.first?.folderPath == "Work Projects")
    #expect(mockLookup.lookupCalls.contains("folder-abc"))
  }

  @Test("searchAll returns nil folderPath for root-level documents")
  func returnsNilFolderPathForRootLevel() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let match = SearchServiceTestFixtures.indexedMatch(folderID: nil)
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "test")

    #expect(results.first?.folderPath == nil)
  }

  @Test("searchAll determines matchSource as title when query in title")
  func matchSourceTitleWhenQueryInTitle() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let match = SearchServiceTestFixtures.indexedMatch(
      documentID: "doc-1",
      documentType: .notebook,
      title: "Budget Report",
      snippet: "...quarterly analysis..."
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "budget")

    #expect(results.first?.matchSource == .title)
  }

  @Test("searchAll determines matchSource as title case-insensitively")
  func matchSourceTitleCaseInsensitive() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let match = SearchServiceTestFixtures.indexedMatch(
      documentID: "doc-1",
      documentType: .notebook,
      title: "BUDGET Report",
      snippet: "...quarterly analysis..."
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "budget")

    #expect(results.first?.matchSource == .title)
  }

  @Test("searchAll determines matchSource as handwriting for notebook content match")
  func matchSourceHandwritingForNotebookContent() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Title does not contain "budget", document type is notebook.
    let match = SearchServiceTestFixtures.indexedMatch(
      documentID: "doc-1",
      documentType: .notebook,
      title: "Meeting Notes",
      snippet: "...discussed the budget..."
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "budget")

    #expect(results.first?.matchSource == .handwriting)
  }

  @Test("searchAll determines matchSource as pdfText for PDF content match")
  func matchSourcePdfTextForPdfContent() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Title does not contain "revenue", document type is PDF.
    let match = SearchServiceTestFixtures.indexedMatch(
      documentID: "doc-1",
      documentType: .pdf,
      title: "Annual Report",
      snippet: "...revenue growth analysis..."
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "revenue")

    #expect(results.first?.matchSource == .pdfText)
  }

  @Test("searchAll passes scope .all to underlying index")
  func passesScopeAllToIndex() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])
    _ = try await service.searchAll(query: "test")

    let calls = await mockIndex.searchCalls
    #expect(calls.first?.scope == .all)
  }

  @Test("searchAll respects default result limit")
  func respectsDefaultResultLimit() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Create 50 matches but expect only 25 returned.
    let matches = SearchServiceTestFixtures.bulkMatches(count: 50)
    await mockIndex.setSearchResults(matches)

    let results = try await service.searchAll(query: "Document")

    #expect(results.count <= SearchServiceConstants.defaultResultLimit)
  }

  @Test("searchAll passes limit to underlying index")
  func passesLimitToIndex() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])
    _ = try await service.searchAll(query: "test")

    let calls = await mockIndex.searchCalls
    #expect(calls.first?.limit == SearchServiceConstants.defaultResultLimit)
  }

  @Test("searchAll does not perform folder lookups when no results")
  func noFolderLookupsWhenNoResults() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])
    _ = try await service.searchAll(query: "nonexistent")

    #expect(mockLookup.lookupCalls.isEmpty)
  }

  @Test("searchAll handles deleted folder gracefully")
  func handlesDeletedFolderGracefully() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Folder lookup returns nil (folder does not exist).
    let match = SearchServiceTestFixtures.matchInFolder(folderID: "deleted-folder")
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "test")

    // Should return result with nil folderPath.
    #expect(results.first?.folderPath == nil)
  }
}

// MARK: - SearchService searchInFolder Tests

@Suite("SearchService searchInFolder Tests")
struct SearchServiceSearchInFolderTests {

  @Test("searchInFolder with empty query throws emptyQuery error")
  func emptyQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await #expect(throws: SearchServiceError.self) {
      _ = try await service.searchInFolder(query: "", folderID: "folder-1")
    }
  }

  @Test("searchInFolder with whitespace-only query throws emptyQuery error")
  func whitespaceQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await #expect(throws: SearchServiceError.self) {
      _ = try await service.searchInFolder(query: "   ", folderID: "folder-1")
    }
  }

  @Test("searchInFolder passes scope .folder to underlying index")
  func passesFolderScopeToIndex() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])
    _ = try await service.searchInFolder(query: "test", folderID: "work-folder")

    let calls = await mockIndex.searchCalls
    #expect(calls.first?.scope == .folder(id: "work-folder"))
  }

  @Test("searchInFolder transforms results same as searchAll")
  func transformsResultsSameAsSearchAll() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    mockLookup.setFolderName("Work Projects", forID: "work")
    let match = SearchServiceTestFixtures.indexedMatch(
      documentID: "doc-1",
      title: "Budget Report",
      folderID: "work"
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchInFolder(query: "budget", folderID: "work")

    #expect(results.first?.documentID == "doc-1")
    #expect(results.first?.matchSource == .title)
    #expect(results.first?.folderPath == "Work Projects")
  }

  @Test("searchInFolder returns empty array when no matches in folder")
  func returnsEmptyArrayWhenNoMatchesInFolder() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])

    let results = try await service.searchInFolder(query: "nonexistent", folderID: "folder-1")

    #expect(results.isEmpty)
  }
}

// MARK: - SearchService searchInNote Tests

@Suite("SearchService searchInNote Tests")
struct SearchServiceSearchInNoteTests {

  @Test("searchInNote with empty query throws emptyQuery error")
  func emptyQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await #expect(throws: SearchServiceError.self) {
      _ = try await service.searchInNote(query: "", documentID: "doc-1")
    }
  }

  @Test("searchInNote with whitespace-only query throws emptyQuery error")
  func whitespaceQueryThrowsError() async {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await #expect(throws: SearchServiceError.self) {
      _ = try await service.searchInNote(query: "   ", documentID: "doc-1")
    }
  }

  @Test("searchInNote returns empty array (Phase 5 stub)")
  func returnsEmptyArrayPhase5Stub() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let results = try await service.searchInNote(query: "test", documentID: "doc-1")

    #expect(results.isEmpty)
  }
}

// MARK: - MatchSource Determination Logic Tests

@Suite("MatchSource Determination Logic Tests")
struct MatchSourceDeterminationTests {

  @Test("title match takes precedence over content match")
  func titleMatchTakesPrecedence() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Document with "budget" in both title and content.
    let match = SearchServiceTestFixtures.indexedMatch(
      title: "Budget Report",
      snippet: "...budget analysis for quarterly..."
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "budget")

    #expect(results.first?.matchSource == .title)
  }

  @Test("partial query term in title matches")
  func partialQueryTermInTitleMatches() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Query "budget meeting" but title only has "budget".
    let match = SearchServiceTestFixtures.indexedMatch(
      title: "Budget Report",
      snippet: "...quarterly meeting notes..."
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "budget meeting")

    // At least one term is in the title.
    #expect(results.first?.matchSource == .title)
  }

  @Test("empty title results in content match source")
  func emptyTitleResultsInContentMatchSource() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let match = SearchServiceTestFixtures.indexedMatch(
      documentType: .notebook,
      title: "",
      snippet: "...budget discussion..."
    )
    await mockIndex.setSearchResults([match])

    let results = try await service.searchAll(query: "budget")

    #expect(results.first?.matchSource == .handwriting)
  }
}

// MARK: - Integration Tests

@Suite("SearchService Integration Tests")
struct SearchServiceIntegrationTests {

  @Test("mixed folder and root documents are transformed correctly")
  func mixedFolderAndRootDocuments() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    mockLookup.setFolderName("Work", forID: "work-folder")
    mockLookup.setFolderName("Personal", forID: "personal-folder")

    let matches = [
      SearchServiceTestFixtures.indexedMatch(
        documentID: "doc-1",
        title: "Work Notes",
        folderID: "work-folder"
      ),
      SearchServiceTestFixtures.indexedMatch(
        documentID: "doc-2",
        title: "Personal Notes",
        folderID: "personal-folder"
      ),
      SearchServiceTestFixtures.indexedMatch(
        documentID: "doc-3",
        title: "Root Notes",
        folderID: nil
      )
    ]
    await mockIndex.setSearchResults(matches)

    let results = try await service.searchAll(query: "notes")

    #expect(results.count == 3)

    let workResult = results.first { $0.documentID == "doc-1" }
    let personalResult = results.first { $0.documentID == "doc-2" }
    let rootResult = results.first { $0.documentID == "doc-3" }

    #expect(workResult?.folderPath == "Work")
    #expect(personalResult?.folderPath == "Personal")
    #expect(rootResult?.folderPath == nil)
  }

  @Test("multiple document types have correct match sources")
  func multipleDocumentTypesCorrectMatchSources() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let matches = [
      // Notebook with title match.
      SearchServiceTestFixtures.indexedMatch(
        documentID: "notebook-title",
        documentType: .notebook,
        title: "Budget Notes",
        snippet: "...some content..."
      ),
      // Notebook with content match.
      SearchServiceTestFixtures.indexedMatch(
        documentID: "notebook-content",
        documentType: .notebook,
        title: "Meeting Notes",
        snippet: "...budget discussion..."
      ),
      // PDF with title match.
      SearchServiceTestFixtures.indexedMatch(
        documentID: "pdf-title",
        documentType: .pdf,
        title: "Budget Report PDF",
        snippet: "...quarterly data..."
      ),
      // PDF with content match.
      SearchServiceTestFixtures.indexedMatch(
        documentID: "pdf-content",
        documentType: .pdf,
        title: "Annual Report",
        snippet: "...budget analysis..."
      )
    ]
    await mockIndex.setSearchResults(matches)

    let results = try await service.searchAll(query: "budget")

    let notebookTitleResult = results.first { $0.documentID == "notebook-title" }
    let notebookContentResult = results.first { $0.documentID == "notebook-content" }
    let pdfTitleResult = results.first { $0.documentID == "pdf-title" }
    let pdfContentResult = results.first { $0.documentID == "pdf-content" }

    #expect(notebookTitleResult?.matchSource == .title)
    #expect(notebookContentResult?.matchSource == .handwriting)
    #expect(pdfTitleResult?.matchSource == .title)
    #expect(pdfContentResult?.matchSource == .pdfText)
  }

  @Test("case insensitive matching across queries")
  func caseInsensitiveMatchingAcrossQueries() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    let match = SearchServiceTestFixtures.indexedMatch(
      title: "MEETING NOTES",
      snippet: "...content here..."
    )
    await mockIndex.setSearchResults([match])

    // Lowercase query should match uppercase title.
    let results = try await service.searchAll(query: "meeting")

    #expect(results.first?.matchSource == .title)
  }
}

// MARK: - Edge Case Tests

@Suite("SearchService Edge Case Tests")
struct SearchServiceEdgeCaseTests {

  @Test("query with special characters is handled")
  func queryWithSpecialCharactersHandled() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])

    // Should not throw.
    let results = try await service.searchAll(query: "project's notes")

    #expect(results.isEmpty)
  }

  @Test("query with unicode characters is handled")
  func queryWithUnicodeCharactersHandled() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])

    // Should not throw.
    let results = try await service.searchAll(query: "meeting note")

    #expect(results.isEmpty)
  }

  @Test("very long query is handled")
  func veryLongQueryHandled() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])

    let longQuery = String(repeating: "word ", count: 200)
    let results = try await service.searchAll(query: longQuery)

    #expect(results.isEmpty)
  }

  @Test("query with tabs and newlines is handled")
  func queryWithTabsAndNewlinesHandled() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])

    // Query with various whitespace.
    let results = try await service.searchAll(query: "meeting\tnotes\n")

    #expect(results.isEmpty)
  }
}

// MARK: - SearchService Actor Tests

@Suite("SearchService Actor Tests")
struct SearchServiceActorTests {

  @Test("SearchService is an actor")
  func isActor() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    // Actor methods must be called with await.
    await mockIndex.setSearchResults([])
    _ = try await service.searchAll(query: "test")
  }

  @Test("concurrent searches are serialized by actor")
  func concurrentSearchesAreSerialized() async throws {
    let mockIndex = MockSearchIndex()
    let mockLookup = MockFolderLookup()
    let service = SearchService(index: mockIndex, folderLookup: mockLookup)

    await mockIndex.setSearchResults([])

    // Launch multiple concurrent searches.
    await withTaskGroup(of: [SearchResult].self) { group in
      for i in 0..<10 {
        group.addTask {
          let results = try? await service.searchAll(query: "query\(i)")
          return results ?? []
        }
      }
    }

    // All operations should complete without error.
    let calls = await mockIndex.searchCalls
    #expect(calls.count == 10)
  }
}
