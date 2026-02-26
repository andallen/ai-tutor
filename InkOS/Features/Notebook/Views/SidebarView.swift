//
// SidebarView.swift
// InkOS
//
// Floating sidebar for session management.
// Shows session list with search, compose button, and hamburger close.
// Long-press on sessions for rename/delete context menu.
//

import SwiftUI

// MARK: - SidebarView

// Sidebar overlay for browsing and managing sessions.
struct SidebarView: View {
  @Bindable var sessionService: SessionService
  @Binding var isPresented: Bool
  var activeSessionId: String?

  // Callbacks.
  var onSelectSession: ((SessionData) -> Void)?
  var onNewSession: (() -> Void)?
  var onOpenSettings: (() -> Void)?

  @State private var searchText = ""
  @FocusState private var searchFocused: Bool

  // Rename state for context menu.
  @State private var renamingSession: SessionMetadata?
  @State private var renameText = ""

  // Sessions filtered by search query.
  private var filteredSessions: [SessionMetadata] {
    if searchText.isEmpty {
      return sessionService.sessions
    }
    let query = searchText.lowercased()
    return sessionService.sessions.filter {
      $0.title.lowercased().contains(query)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Top row: search, compose, and hamburger close.
      topBar

      // Session list.
      ScrollView {
        LazyVStack(spacing: 2) {
          ForEach(filteredSessions) { session in
            sessionRow(session)
          }
        }
        .padding(.horizontal, 8)
      }

      Spacer(minLength: 0)

      // Bottom: settings button.
      settingsButton
    }
    .frame(maxHeight: .infinity)
    .accessibilityIdentifier("sidebar_view")
    .alert("Rename Session", isPresented: .init(
      get: { renamingSession != nil },
      set: { if !$0 { renamingSession = nil } }
    )) {
      TextField("Session name", text: $renameText)
      Button("Cancel", role: .cancel) { renamingSession = nil }
      Button("Rename") {
        if let session = renamingSession, !renameText.isEmpty {
          sessionService.renameSession(id: session.id, newTitle: renameText)
        }
        renamingSession = nil
      }
    } message: {
      Text("Enter a new name for this session.")
    }
  }

  // MARK: - Top Bar

  // Combined search field, compose button, and hamburger close.
  private var topBar: some View {
    HStack(spacing: 10) {
      searchField

      // New session.
      Button(action: {
        searchFocused = false
        onNewSession?()
      }) {
        Image(systemName: "square.and.pencil")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(NotebookPalette.ink)
          .frame(width: 32, height: 32)
      }
      .accessibilityIdentifier("sidebar_new_session_button")

      // Close sidebar via hamburger icon.
      Button(action: {
        searchFocused = false
        withAnimation(.easeInOut(duration: 0.25)) { isPresented = false }
      }) {
        HamburgerIcon()
          .frame(width: 32, height: 32)
      }
      .accessibilityIdentifier("sidebar_hamburger_close")
    }
    .padding(.horizontal, 14)
    .padding(.top, 14)
    .padding(.bottom, 10)
  }

  // MARK: - Search Field

  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 14))
        .foregroundColor(NotebookPalette.inkFaint)

      TextField("Search", text: $searchText)
        .font(NotebookTypography.body)
        .foregroundColor(NotebookPalette.ink)
        .focused($searchFocused)
        .accessibilityIdentifier("sidebar_search_field")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      Capsule()
        .fill(Color.gray.opacity(0.06))
    )
    .overlay(
      Capsule()
        .stroke(NotebookPalette.inkFaint.opacity(0.2), lineWidth: 1)
    )
  }

  // MARK: - Session Row

  // Session row with title only (no date subtitle).
  // Long-press shows rename/delete context menu.
  private func sessionRow(_ session: SessionMetadata) -> some View {
    Button(action: {
      searchFocused = false
      if let data = sessionService.loadSession(id: session.id) {
        onSelectSession?(data)
      }
    }) {
      HStack {
        Text(session.title)
          .font(NotebookTypography.body)
          .foregroundColor(NotebookPalette.ink)
          .lineLimit(1)

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(
            activeSessionId == session.id
              ? NotebookPalette.ink.opacity(0.06)
              : Color.clear
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("sidebar_session_row_\(session.id)")
    .contextMenu {
      Button {
        renameText = session.title
        renamingSession = session
      } label: {
        Label("Rename", systemImage: "pencil")
      }
      Button(role: .destructive) {
        sessionService.deleteSession(id: session.id)
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  // MARK: - Settings Button

  private var settingsButton: some View {
    Button(action: { onOpenSettings?() }) {
      HStack(spacing: 8) {
        Image(systemName: "gearshape")
          .font(.system(size: 16))
          .foregroundColor(NotebookPalette.ink)
        Text("Settings")
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(NotebookPalette.ink)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .accessibilityIdentifier("sidebar_settings_button")
    .overlay(alignment: .top) {
      LinearGradient(
        colors: [NotebookPalette.paper, NotebookPalette.paper.opacity(0)],
        startPoint: .bottom,
        endPoint: .top
      )
      .frame(height: 24)
      .offset(y: -24)
    }
  }
}
