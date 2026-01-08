// ContextGatherer.swift
// Extracts context from notebooks and folders based on ChatScope.
// Uses BundleManager and ContentExtractor to access notebook content.

import Foundation

// Actor for extracting context from notebooks based on specified scope.
// Coordinates with BundleManager for file access and ContentExtractor for text extraction.
actor ContextGatherer: ContextGathererProtocol {

  // Reference to the bundle manager for notebook access.
  private let bundleManager: BundleManager

  // Content extractor for parsing JIIX and PDF content.
  private let contentExtractor: any ContentExtractorProtocol

  // Chat client for AI-based scope resolution.
  private let chatClient: any ChatClientProtocol

  // Creates a context gatherer with the specified dependencies.
  init(
    bundleManager: BundleManager,
    contentExtractor: any ContentExtractorProtocol,
    chatClient: any ChatClientProtocol
  ) {
    self.bundleManager = bundleManager
    self.contentExtractor = contentExtractor
    self.chatClient = chatClient
  }

  // Gathers context based on the specified scope.
  func gatherContext(
    scope: ChatScope,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> GatheredContext {
    switch scope {
    case .auto:
      // Auto scope should be resolved first - not valid here.
      throw ChatError.scopeResolutionFailed(
        reason: "Auto scope must be resolved before gathering context"
      )

    case .chatOnly:
      // No context - pure chat mode.
      return GatheredContext.empty(scope: .chatOnly)

    case .thisNote:
      // Extract from currently open notebook.
      guard let noteID = currentNoteID else {
        throw ChatError.invalidRequest(
          reason: "Current note ID required for 'thisNote' scope"
        )
      }
      return try await gatherFromSingleNote(noteID: noteID, scope: .thisNote)

    case .specificNote(let noteID):
      // Extract from specific notebook by ID.
      return try await gatherFromSingleNote(noteID: noteID, scope: .specificNote(noteID))

    case .specificFolder(let folderID):
      // Extract from all notebooks in a folder.
      return try await gatherFromFolder(folderID: folderID)

    case .allNotes:
      // Extract from all notebooks in library.
      return try await gatherFromAllNotes()

    case .thisPage, .selection, .otherNote:
      // Not implemented yet - future features.
      throw ChatError.scopeResolutionFailed(
        reason: "Scope '\(scope)' is not yet supported"
      )
    }
  }

  // Resolves auto scope by calling AI to determine the best scope.
  func resolveAutoScope(query: String) async throws -> ChatScope {
    // Build a system prompt asking AI to choose the best scope.
    let systemPrompt = """
    You are a scope selector. Given a user question, choose the most appropriate search scope.

    Available scopes:
    - chatOnly: No document context needed (for general questions)
    - thisNote: Search in the currently open note
    - allNotes: Search across all notes in the library

    Respond with ONLY ONE of these exact words: chatOnly, thisNote, or allNotes

    User question: \(query)
    """

    let message = APIMessage(role: "user", content: systemPrompt)

    do {
      let response = try await chatClient.sendMessage(messages: [message])
      return try parseScopeFromResponse(response)
    } catch {
      throw ChatError.scopeResolutionFailed(reason: error.localizedDescription)
    }
  }

  // MARK: - Private Methods

  // Extracts content from a single notebook.
  private func gatherFromSingleNote(noteID: String, scope: ChatScope) async throws
    -> GatheredContext {
    do {
      // Open the notebook.
      let handle = try await bundleManager.openNotebook(id: noteID)

      // Load JIIX data.
      guard let jiixData = try await handle.loadJIIXData() else {
        await handle.close(saveBeforeClose: false)
        throw ChatError.documentNotFound(documentID: noteID)
      }

      // Extract content from JIIX.
      let manifest = handle.initialManifest
      let extracted = try await contentExtractor.extractFromJIIX(
        data: jiixData,
        documentID: manifest.notebookID,
        displayName: manifest.displayName,
        modifiedAt: manifest.modifiedAt
      )

      // Close the handle.
      await handle.close(saveBeforeClose: false)

      // Format with header.
      let formattedText: String
      if extracted.text.isEmpty {
        formattedText = "Context from Note (\(extracted.displayName)): (empty)"
      } else {
        formattedText = "Context from Note (\(extracted.displayName)):\n\n\(extracted.text)"
      }

      return GatheredContext(
        scope: scope,
        text: formattedText,
        documentIDs: [noteID],
        documentCount: 1,
        characterCount: formattedText.count
      )

    } catch {
      throw ChatError.documentNotFound(documentID: noteID)
    }
  }

  // Extracts content from all notebooks in a folder.
  private func gatherFromFolder(folderID: String) async throws -> GatheredContext {
    do {
      // Get notebooks in the folder.
      let notebooks = try await bundleManager.listBundlesInFolder(folderID: folderID)

      // Extract content from each notebook (limit to maxNotebooksPerFolder).
      var allTexts: [String] = []
      var documentIDs: [String] = []

      for notebook in notebooks.prefix(ChatConstants.maxNotebooksPerFolder) {
        do {
          let handle = try await bundleManager.openNotebook(id: notebook.id)

          // Load JIIX data.
          guard let jiixData = try await handle.loadJIIXData() else {
            await handle.close(saveBeforeClose: false)
            continue  // Skip notebooks without JIIX data
          }

          // Extract content from JIIX.
          let manifest = handle.initialManifest
          let extracted = try await contentExtractor.extractFromJIIX(
            data: jiixData,
            documentID: manifest.notebookID,
            displayName: manifest.displayName,
            modifiedAt: manifest.modifiedAt
          )
          await handle.close(saveBeforeClose: false)

          let noteText = "--- \(extracted.displayName) ---\n\(extracted.text)"
          allTexts.append(noteText)
          documentIDs.append(notebook.id)
        } catch {
          // Skip notebooks that can't be read.
          continue
        }
      }

      // Combine all text.
      let combinedText = allTexts.joined(separator: "\n\n")
      let formattedText: String
      if combinedText.isEmpty {
        formattedText = "Context from Folder (\(notebooks.count) notes): (empty)"
      } else {
        formattedText = "Context from Folder (\(notebooks.count) notes):\n\n\(combinedText)"
      }

      // Truncate if needed.
      let truncatedText = truncateIfNeeded(formattedText)

      return GatheredContext(
        scope: .specificFolder(folderID),
        text: truncatedText,
        documentIDs: documentIDs,
        documentCount: documentIDs.count,
        characterCount: truncatedText.count
      )

    } catch {
      throw ChatError.folderNotFound(folderID: folderID)
    }
  }

  // Extracts content from all notebooks in the library.
  private func gatherFromAllNotes() async throws -> GatheredContext {
    do {
      // Get all notebooks.
      let notebooks = try await bundleManager.listBundles()

      // Sort by most recently modified.
      let sortedNotebooks = notebooks.sorted { n1, n2 in
        guard let date1 = n1.lastAccessedAt, let date2 = n2.lastAccessedAt else {
          return false
        }
        return date1 > date2
      }

      // Extract content from each notebook (limit to maxNotebooksForAllNotes).
      var allTexts: [String] = []
      var documentIDs: [String] = []

      for notebook in sortedNotebooks.prefix(ChatConstants.maxNotebooksForAllNotes) {
        do {
          let handle = try await bundleManager.openNotebook(id: notebook.id)

          // Load JIIX data.
          guard let jiixData = try await handle.loadJIIXData() else {
            await handle.close(saveBeforeClose: false)
            continue  // Skip notebooks without JIIX data
          }

          // Extract content from JIIX.
          let manifest = handle.initialManifest
          let extracted = try await contentExtractor.extractFromJIIX(
            data: jiixData,
            documentID: manifest.notebookID,
            displayName: manifest.displayName,
            modifiedAt: manifest.modifiedAt
          )
          await handle.close(saveBeforeClose: false)

          let noteText = "--- \(notebook.displayName) ---\n\(extracted.text)"
          allTexts.append(noteText)
          documentIDs.append(notebook.id)
        } catch {
          // Skip notebooks that can't be read.
          continue
        }
      }

      // Combine all text.
      let combinedText = allTexts.joined(separator: "\n\n")
      let formattedText: String
      if combinedText.isEmpty {
        formattedText = "Context from All Notes (\(notebooks.count) total): (empty)"
      } else {
        formattedText = "Context from All Notes (\(notebooks.count) total):\n\n\(combinedText)"
      }

      // Truncate if needed.
      let truncatedText = truncateIfNeeded(formattedText)

      return GatheredContext(
        scope: .allNotes,
        text: truncatedText,
        documentIDs: documentIDs,
        documentCount: documentIDs.count,
        characterCount: truncatedText.count
      )

    } catch {
      throw ChatError.contextExtractionFailed(reason: error.localizedDescription)
    }
  }

  // Truncates text to token-based context limit if needed.
  private func truncateIfNeeded(_ text: String) -> String {
    // Calculate character limit from token budget.
    // Use maxContextTokens * charsPerToken to get character limit.
    let maxChars = Int(Double(TokenBudgetConstants.maxContextTokens) * TokenBudgetConstants.charsPerToken)

    if text.count <= maxChars {
      return text
    }
    let truncated = String(text.prefix(maxChars))
    return truncated + "\n\n[Context truncated to \(maxChars) characters (~\(TokenBudgetConstants.maxContextTokens) tokens)]"
  }

  // Parses AI response to determine the scope.
  private func parseScopeFromResponse(_ response: String) throws -> ChatScope {
    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    switch trimmed {
    case "chatonly":
      return .chatOnly
    case "thisnote":
      return .thisNote
    case "allnotes":
      return .allNotes
    default:
      // If AI returns something unexpected, default to chatOnly.
      return .chatOnly
    }
  }
}
