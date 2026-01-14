// SearchService.swift
// Actor that transforms raw IndexedMatch results from SearchIndex into
// UI-ready SearchResult objects by enriching with folder display names
// and determining match sources.

import Foundation

// MARK: - SearchService Actor

// Actor that provides high-level search operations for the UI.
// Transforms raw IndexedMatch results into UI-ready SearchResult objects.
// Thread-safe through actor isolation.
actor SearchService: SearchServiceProtocol {

  // The underlying search index for FTS5 queries.
  private let index: any SearchIndexProtocol

  // Protocol for resolving folder IDs to display names.
  private let folderLookup: FolderLookupProtocol

  // Protocol for resolving document IDs to preview image data.
  private let previewLookup: PreviewLookupProtocol?

  // Creates a SearchService with the given dependencies.
  // index: The search index to query.
  // folderLookup: Protocol for resolving folder IDs to display names.
  // previewLookup: Optional protocol for resolving document IDs to preview images.
  init(
    index: any SearchIndexProtocol,
    folderLookup: FolderLookupProtocol,
    previewLookup: PreviewLookupProtocol? = nil
  ) {
    self.index = index
    self.folderLookup = folderLookup
    self.previewLookup = previewLookup
  }

  // MARK: - SearchServiceProtocol

  func searchAll(query: String) async throws -> [SearchResult] {
    // Validate query.
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      throw SearchServiceError.emptyQuery
    }

    // Search the index with scope .all.
    let matches = try await index.search(
      query: trimmedQuery,
      scope: .all,
      limit: SearchServiceConstants.defaultResultLimit
    )

    // Transform matches to results.
    return await transformMatches(matches, query: trimmedQuery)
  }

  func searchInFolder(query: String, folderID: String) async throws -> [SearchResult] {
    // Validate query.
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      throw SearchServiceError.emptyQuery
    }

    // Search the index scoped to the folder.
    let matches = try await index.search(
      query: trimmedQuery,
      scope: .folder(id: folderID),
      limit: SearchServiceConstants.defaultResultLimit
    )

    // Transform matches to results.
    return await transformMatches(matches, query: trimmedQuery)
  }

  func searchInNote(query: String, documentID: String) async throws -> [InNoteSearchMatch] {
    // Validate query.
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      throw SearchServiceError.emptyQuery
    }

    // Phase 5 stub: return empty array.
    // Will be implemented with bounding box extraction from JIIX/PDF.
    return []
  }

  // MARK: - Private Helpers

  // Transforms IndexedMatch array to SearchResult array with enriched metadata.
  // Deduplicates by documentID, keeping the highest-ranked match.
  private func transformMatches(_ matches: [IndexedMatch], query: String) async -> [SearchResult] {
    var results: [SearchResult] = []
    var seenDocumentIDs: Set<String> = []

    for match in matches {
      // Skip duplicate documents - keep first (highest ranked) only.
      guard !seenDocumentIDs.contains(match.documentID) else {
        continue
      }
      seenDocumentIDs.insert(match.documentID)

      // Resolve folder display name if applicable.
      var folderPath: String?
      if let folderID = match.folderID {
        folderPath = await folderLookup.getFolderDisplayName(folderID: folderID)
      }

      // Resolve preview image data if lookup is available.
      var previewImageData: Data?
      if let previewLookup {
        previewImageData = await previewLookup.getPreviewImageData(
          documentID: match.documentID,
          documentType: match.documentType
        )
      }

      // Determine match source based on query and title.
      let matchSource = determineMatchSource(
        query: query,
        title: match.title,
        documentType: match.documentType
      )

      // Create SearchResult.
      let result = SearchResult(
        documentID: match.documentID,
        documentType: match.documentType,
        displayName: match.title,
        matchSnippet: match.snippet,
        matchSource: matchSource,
        folderPath: folderPath,
        modifiedAt: Date(),
        previewImageData: previewImageData
      )

      results.append(result)
    }

    return results
  }

  // Determines where the match was found based on query presence in title.
  // If any query term appears in the title (case-insensitive), returns .title.
  // Otherwise returns .handwriting for notebooks, .pdfText for PDFs, or .lessonContent for lessons.
  private func determineMatchSource(
    query: String,
    title: String,
    documentType: DocumentType
  ) -> MatchSource {
    // Normalize query and title to lowercase for case-insensitive comparison.
    let normalizedTitle = title.lowercased()
    let queryTerms = query.lowercased()
      .components(separatedBy: .whitespaces)
      .filter { !$0.isEmpty }

    // Check if any query term appears in the title.
    for term in queryTerms {
      if normalizedTitle.contains(term) {
        return .title
      }
    }

    // No query term found in title - match is in content.
    switch documentType {
    case .notebook:
      return .handwriting
    case .pdf:
      return .pdfText
    case .lesson:
      return .lessonContent
    case .folder:
      // Folders only have a name, so if query matched, it was the name.
      return .folderName
    }
  }
}
