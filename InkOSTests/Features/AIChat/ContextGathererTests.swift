// ContextGathererTests.swift
// Tests for ContextGatherer content extraction from notebooks.
// These tests use mock implementations until ContextGatherer is implemented.
// Tests against contract-defined types (GatheredContext, ChatScope, etc.)
// and mock implementations for protocol testing.

import Foundation
import Testing

@testable import InkOS

// MARK: - MockContextGatherer

// Mock implementation of ContextGathererProtocol for testing dependent services.
// Tracks method invocations and allows configuring return values and errors.
actor MockContextGatherer: ContextGathererProtocol {

  // Tracks the number of times gatherContext was called.
  private(set) var gatherContextCallCount = 0

  // Tracks parameters passed to gatherContext.
  private(set) var gatherContextCalls: [(scope: ChatScope, currentNoteID: String?, currentFolderID: String?)] = []

  // Tracks the number of times resolveAutoScope was called.
  private(set) var resolveAutoScopeCallCount = 0

  // Tracks queries passed to resolveAutoScope.
  private(set) var resolveAutoScopeCalls: [String] = []

  // Context to return from gatherContext.
  var gatheredContextResult: GatheredContext = GatheredContext.empty(scope: .chatOnly)

  // Error to throw from gatherContext.
  var gatherContextError: Error?

  // Scope to return from resolveAutoScope.
  var resolvedScope: ChatScope = .allNotes

  // Error to throw from resolveAutoScope.
  var resolveAutoScopeError: Error?

  func gatherContext(
    scope: ChatScope,
    currentNoteID: String?,
    currentFolderID: String?
  ) async throws -> GatheredContext {
    gatherContextCallCount += 1
    gatherContextCalls.append((scope: scope, currentNoteID: currentNoteID, currentFolderID: currentFolderID))

    if let error = gatherContextError {
      throw error
    }

    return gatheredContextResult
  }

  func resolveAutoScope(query: String) async throws -> ChatScope {
    resolveAutoScopeCallCount += 1
    resolveAutoScopeCalls.append(query)

    if let error = resolveAutoScopeError {
      throw error
    }

    return resolvedScope
  }

  // Resets all recorded state.
  func reset() {
    gatherContextCallCount = 0
    gatherContextCalls = []
    resolveAutoScopeCallCount = 0
    resolveAutoScopeCalls = []
    gatheredContextResult = GatheredContext.empty(scope: .chatOnly)
    gatherContextError = nil
    resolvedScope = .allNotes
    resolveAutoScopeError = nil
  }
}

// MARK: - ContextGatherer Tests

// Note: Tests against the real ContextGatherer will be enabled once implementation exists.
// For now, these tests verify the mock implementation and contract types work correctly.
@Suite("ContextGatherer Tests")
struct ContextGathererTests {

  // MARK: - MockContextGatherer gatherContext Tests

  @Suite("gatherContext Operations via Mock")
  struct GatherContextMockTests {

    @Test("mock returns configured context")
    func mockReturnsConfiguredContext() async throws {
      let mockGatherer = MockContextGatherer()
      let expectedContext = GatheredContext(
        scope: .allNotes,
        text: "Test content from notes",
        documentIDs: ["note-1", "note-2"],
        documentCount: 2,
        characterCount: 22
      )

      await mockGatherer.setGatheredContext(expectedContext)

      let context = try await mockGatherer.gatherContext(
        scope: .allNotes,
        currentNoteID: nil,
        currentFolderID: nil
      )

      #expect(context == expectedContext)
    }

    @Test("mock tracks call count")
    func mockTracksCallCount() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.gatherContext(scope: .chatOnly, currentNoteID: nil, currentFolderID: nil)
      _ = try await mockGatherer.gatherContext(scope: .allNotes, currentNoteID: nil, currentFolderID: nil)

      let count = await mockGatherer.gatherContextCallCount
      #expect(count == 2)
    }

    @Test("mock tracks scope parameter")
    func mockTracksScopeParameter() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.gatherContext(
        scope: .specificNote("note-123"),
        currentNoteID: nil,
        currentFolderID: nil
      )

      let calls = await mockGatherer.gatherContextCalls
      #expect(calls.count == 1)
      #expect(calls[0].scope == .specificNote("note-123"))
    }

    @Test("mock tracks currentNoteID parameter")
    func mockTracksCurrentNoteID() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.gatherContext(
        scope: .thisNote,
        currentNoteID: "current-note-456",
        currentFolderID: nil
      )

      let calls = await mockGatherer.gatherContextCalls
      #expect(calls[0].currentNoteID == "current-note-456")
    }

    @Test("mock tracks currentFolderID parameter")
    func mockTracksCurrentFolderID() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.gatherContext(
        scope: .specificFolder("folder-789"),
        currentNoteID: nil,
        currentFolderID: "folder-789"
      )

      let calls = await mockGatherer.gatherContextCalls
      #expect(calls[0].currentFolderID == "folder-789")
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let mockGatherer = MockContextGatherer()
      await mockGatherer.setGatherContextError(
        ChatError.contextExtractionFailed(reason: "Test failure")
      )

      await #expect(throws: ChatError.self) {
        _ = try await mockGatherer.gatherContext(
          scope: .allNotes,
          currentNoteID: nil,
          currentFolderID: nil
        )
      }
    }

    @Test("mock throws documentNotFound error")
    func mockThrowsDocumentNotFound() async {
      let mockGatherer = MockContextGatherer()
      await mockGatherer.setGatherContextError(
        ChatError.documentNotFound(documentID: "missing-doc")
      )

      do {
        _ = try await mockGatherer.gatherContext(
          scope: .specificNote("missing-doc"),
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected documentNotFound error")
      } catch let error as ChatError {
        if case .documentNotFound(let id) = error {
          #expect(id == "missing-doc")
        } else {
          Issue.record("Expected documentNotFound but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    @Test("mock throws folderNotFound error")
    func mockThrowsFolderNotFound() async {
      let mockGatherer = MockContextGatherer()
      await mockGatherer.setGatherContextError(
        ChatError.folderNotFound(folderID: "missing-folder")
      )

      do {
        _ = try await mockGatherer.gatherContext(
          scope: .specificFolder("missing-folder"),
          currentNoteID: nil,
          currentFolderID: nil
        )
        Issue.record("Expected folderNotFound error")
      } catch let error as ChatError {
        if case .folderNotFound(let id) = error {
          #expect(id == "missing-folder")
        } else {
          Issue.record("Expected folderNotFound but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }
  }

  // MARK: - MockContextGatherer resolveAutoScope Tests

  @Suite("resolveAutoScope Operations via Mock")
  struct ResolveAutoScopeMockTests {

    @Test("mock returns configured scope")
    func mockReturnsConfiguredScope() async throws {
      let mockGatherer = MockContextGatherer()
      await mockGatherer.setResolvedScope(.thisNote)

      let resolvedScope = try await mockGatherer.resolveAutoScope(query: "Summarize this document")

      #expect(resolvedScope == .thisNote)
    }

    @Test("mock tracks call count")
    func mockTracksCallCount() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.resolveAutoScope(query: "First")
      _ = try await mockGatherer.resolveAutoScope(query: "Second")

      let count = await mockGatherer.resolveAutoScopeCallCount
      #expect(count == 2)
    }

    @Test("mock tracks query parameter")
    func mockTracksQueryParameter() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.resolveAutoScope(query: "Search all my notes for recipes")

      let calls = await mockGatherer.resolveAutoScopeCalls
      #expect(calls.count == 1)
      #expect(calls[0] == "Search all my notes for recipes")
    }

    @Test("mock throws configured error")
    func mockThrowsConfiguredError() async {
      let mockGatherer = MockContextGatherer()
      await mockGatherer.setResolveAutoScopeError(
        ChatError.scopeResolutionFailed(reason: "AI service unavailable")
      )

      await #expect(throws: ChatError.self) {
        _ = try await mockGatherer.resolveAutoScope(query: "Test query")
      }
    }

    @Test("mock throws scopeResolutionFailed with reason")
    func mockThrowsScopeResolutionFailed() async {
      let mockGatherer = MockContextGatherer()
      await mockGatherer.setResolveAutoScopeError(
        ChatError.scopeResolutionFailed(reason: "Network timeout")
      )

      do {
        _ = try await mockGatherer.resolveAutoScope(query: "Test")
        Issue.record("Expected scopeResolutionFailed error")
      } catch let error as ChatError {
        if case .scopeResolutionFailed(let reason) = error {
          #expect(reason == "Network timeout")
        } else {
          Issue.record("Expected scopeResolutionFailed but got \(error)")
        }
      } catch {
        Issue.record("Expected ChatError but got \(error)")
      }
    }

    @Test("mock can return different scopes")
    func mockReturnsVariousScopes() async throws {
      let mockGatherer = MockContextGatherer()
      let scopesToTest: [ChatScope] = [
        .chatOnly,
        .allNotes,
        .thisNote,
        .thisPage,
        .selection,
        .specificNote("test-note"),
        .specificFolder("test-folder")
      ]

      for scope in scopesToTest {
        await mockGatherer.setResolvedScope(scope)
        let result = try await mockGatherer.resolveAutoScope(query: "Test")
        #expect(result == scope)
      }
    }
  }

  // MARK: - Mock reset Tests

  @Suite("MockContextGatherer Reset")
  struct MockResetTests {

    @Test("reset clears call counts")
    func resetClearsCallCounts() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.gatherContext(scope: .chatOnly, currentNoteID: nil, currentFolderID: nil)
      _ = try await mockGatherer.resolveAutoScope(query: "Test")

      await mockGatherer.reset()

      let gatherCount = await mockGatherer.gatherContextCallCount
      let resolveCount = await mockGatherer.resolveAutoScopeCallCount

      #expect(gatherCount == 0)
      #expect(resolveCount == 0)
    }

    @Test("reset clears recorded calls")
    func resetClearsCalls() async throws {
      let mockGatherer = MockContextGatherer()

      _ = try await mockGatherer.gatherContext(scope: .chatOnly, currentNoteID: nil, currentFolderID: nil)

      await mockGatherer.reset()

      let calls = await mockGatherer.gatherContextCalls
      #expect(calls.isEmpty)
    }

    @Test("reset clears configured error")
    func resetClearsError() async throws {
      let mockGatherer = MockContextGatherer()
      await mockGatherer.setGatherContextError(ChatError.networkError(reason: "Test"))

      await mockGatherer.reset()

      // Should not throw after reset.
      let context = try await mockGatherer.gatherContext(scope: .chatOnly, currentNoteID: nil, currentFolderID: nil)
      #expect(context.scope == .chatOnly)
    }
  }
}

// MARK: - GatheredContext Tests

@Suite("GatheredContext Tests")
struct GatheredContextTests {

  @Test("empty creates context with zero values")
  func emptyCreatesZeroContext() {
    let context = GatheredContext.empty(scope: .chatOnly)

    #expect(context.text.isEmpty)
    #expect(context.documentIDs.isEmpty)
    #expect(context.documentCount == 0)
    #expect(context.characterCount == 0)
    #expect(context.scope == .chatOnly)
  }

  @Test("empty preserves specified scope")
  func emptyPreservesScope() {
    let scopes: [ChatScope] = [.chatOnly, .allNotes, .thisNote, .thisPage, .selection]

    for scope in scopes {
      let context = GatheredContext.empty(scope: scope)
      #expect(context.scope == scope)
    }
  }

  @Test("creates context with all properties")
  func createsWithAllProperties() {
    let context = GatheredContext(
      scope: .allNotes,
      text: "Extracted content from multiple notes",
      documentIDs: ["doc-1", "doc-2", "doc-3"],
      documentCount: 3,
      characterCount: 36
    )

    #expect(context.scope == .allNotes)
    #expect(context.text == "Extracted content from multiple notes")
    #expect(context.documentIDs == ["doc-1", "doc-2", "doc-3"])
    #expect(context.documentCount == 3)
    #expect(context.characterCount == 36)
  }

  @Test("GatheredContext is Equatable")
  func isEquatable() {
    let context1 = GatheredContext(
      scope: .chatOnly,
      text: "Test",
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 4
    )

    let context2 = GatheredContext(
      scope: .chatOnly,
      text: "Test",
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 4
    )

    let context3 = GatheredContext(
      scope: .allNotes,
      text: "Test",
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 4
    )

    #expect(context1 == context2)
    #expect(context1 != context3)
  }

  @Test("GatheredContext equality checks all properties")
  func equalityChecksAllProperties() {
    let base = GatheredContext(
      scope: .chatOnly,
      text: "Test",
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 4
    )

    // Different text.
    let differentText = GatheredContext(
      scope: .chatOnly,
      text: "Different",
      documentIDs: ["doc-1"],
      documentCount: 1,
      characterCount: 4
    )
    #expect(base != differentText)

    // Different documentIDs.
    let differentDocs = GatheredContext(
      scope: .chatOnly,
      text: "Test",
      documentIDs: ["doc-2"],
      documentCount: 1,
      characterCount: 4
    )
    #expect(base != differentDocs)

    // Different count.
    let differentCount = GatheredContext(
      scope: .chatOnly,
      text: "Test",
      documentIDs: ["doc-1"],
      documentCount: 2,
      characterCount: 4
    )
    #expect(base != differentCount)
  }

  @Test("GatheredContext is Sendable")
  func isSendable() async {
    let context = GatheredContext(
      scope: .allNotes,
      text: "Test content",
      documentIDs: ["doc-1", "doc-2"],
      documentCount: 2,
      characterCount: 12
    )

    // Verify context can be passed across actor boundaries.
    let result = await Task {
      context
    }.value

    #expect(result == context)
  }
}

// MARK: - ChatScope Tests

@Suite("ChatScope Tests")
struct ChatScopeTests {

  @Test("ChatScope cases are distinct")
  func casesAreDistinct() {
    #expect(ChatScope.auto != ChatScope.chatOnly)
    #expect(ChatScope.chatOnly != ChatScope.allNotes)
    #expect(ChatScope.allNotes != ChatScope.thisNote)
    #expect(ChatScope.thisNote != ChatScope.thisPage)
    #expect(ChatScope.thisPage != ChatScope.selection)
    #expect(ChatScope.selection != ChatScope.otherNote)
  }

  @Test("ChatScope is Equatable for simple cases")
  func isEquatableSimpleCases() {
    #expect(ChatScope.auto == ChatScope.auto)
    #expect(ChatScope.chatOnly == ChatScope.chatOnly)
    #expect(ChatScope.allNotes == ChatScope.allNotes)
    #expect(ChatScope.thisNote == ChatScope.thisNote)
    #expect(ChatScope.thisPage == ChatScope.thisPage)
    #expect(ChatScope.selection == ChatScope.selection)
    #expect(ChatScope.otherNote == ChatScope.otherNote)
  }

  @Test("ChatScope is Equatable for associated values")
  func isEquatableAssociatedValues() {
    #expect(ChatScope.specificNote("note-1") == ChatScope.specificNote("note-1"))
    #expect(ChatScope.specificNote("note-1") != ChatScope.specificNote("note-2"))

    #expect(ChatScope.specificFolder("folder-1") == ChatScope.specificFolder("folder-1"))
    #expect(ChatScope.specificFolder("folder-1") != ChatScope.specificFolder("folder-2"))

    #expect(ChatScope.specificNote("id") != ChatScope.specificFolder("id"))
  }

  @Test("ChatScope is Codable")
  func isCodable() throws {
    let scopes: [ChatScope] = [
      .auto,
      .chatOnly,
      .specificNote("note-123"),
      .specificFolder("folder-456"),
      .allNotes,
      .thisPage,
      .thisNote,
      .selection,
      .otherNote
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for original in scopes {
      let data = try encoder.encode(original)
      let decoded = try decoder.decode(ChatScope.self, from: data)
      #expect(decoded == original)
    }
  }

  @Test("ChatScope is Sendable")
  func isSendable() async {
    let scope = ChatScope.specificNote("note-123")

    // Verify scope can be passed across actor boundaries.
    let result = await Task {
      scope
    }.value

    #expect(result == scope)
  }

  @Test("specificNote extracts ID correctly")
  func specificNoteExtractsID() {
    let scope = ChatScope.specificNote("my-note-id")

    if case .specificNote(let id) = scope {
      #expect(id == "my-note-id")
    } else {
      Issue.record("Expected specificNote case")
    }
  }

  @Test("specificFolder extracts ID correctly")
  func specificFolderExtractsID() {
    let scope = ChatScope.specificFolder("my-folder-id")

    if case .specificFolder(let id) = scope {
      #expect(id == "my-folder-id")
    } else {
      Issue.record("Expected specificFolder case")
    }
  }
}

// MARK: - MockContextGatherer Extension

extension MockContextGatherer {
  func setGatheredContext(_ context: GatheredContext) {
    gatheredContextResult = context
  }

  func setGatherContextError(_ error: Error) {
    gatherContextError = error
  }

  func setResolvedScope(_ scope: ChatScope) {
    resolvedScope = scope
  }

  func setResolveAutoScopeError(_ error: Error) {
    resolveAutoScopeError = error
  }
}
