import SwiftUI

// The Dashboard is the screen the user sees first.
// It shows a list of Notebooks and provides actions to create, rename, delete, and open Notebooks.
struct DashboardView: View {
  // The Notebook Library that provides the list of Notebooks.
  @StateObject private var library: NotebookLibrary

  private let columns: [GridItem] = [
    GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 22, alignment: .top)
  ]

  // Creates a Dashboard with a Notebook Library that uses the given Bundle Manager.
  init(bundleManager: BundleManager = BundleManager()) {
    _library = StateObject(wrappedValue: NotebookLibrary(bundleManager: bundleManager))
  }

  var body: some View {
    ZStack {
      BackgroundWhite()
        .ignoresSafeArea()

      HStack(alignment: .top, spacing: 18) {
        Sidebar()
          .frame(width: 240)

        ScrollView(showsIndicators: false) {
          RightPane(columns: columns, library: library)
            .padding(.vertical, 18)
            .padding(.trailing, 22)
            .padding(.leading, 6)
        }
      }
      .padding(.leading, 22)
    }
    .fontDesign(.rounded)
    .task {
      // Load bundles when the Dashboard appears.
      await library.loadBundles()
    }
  }
}

// Right pane containing the main content area with the list of Notebooks.
private struct RightPane: View {
  let columns: [GridItem]
  @ObservedObject var library: NotebookLibrary

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Notes")
        .font(.system(size: 48, weight: .semibold))
        .foregroundStyle(Color.ink)

      SearchBar()

      Spacer().frame(height: 10)
      Capsule()
        .fill(Color.separator)
        .frame(height: 1)
        .padding(.trailing, 6)
      Spacer().frame(height: 14)

      LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
        NewNoteCard(library: library)

        ForEach(library.notebooks) { notebook in
          NavigationLink(value: notebook.id) {
            NoteCard(title: notebook.displayName, notebookID: notebook.id, library: library)
          }
          .buttonStyle(.plain)
        }
      }
      .navigationDestination(for: String.self) { notebookID in
        NotebookLoadingView(notebookID: notebookID, library: library)
      }

      Spacer(minLength: 22)
    }
  }
}

// Sidebar component showing navigation options.
private struct Sidebar: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SidebarRow(icon: "tray.full", title: "Notes")

      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .glassBackground(cornerRadius: 18)
  }
}

// Individual row in the sidebar.
private struct SidebarRow: View {
  let icon: String
  let title: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .frame(width: 18)
        .foregroundStyle(Color.inkSubtle)

      Text(title)
        .font(.system(.body))
        .foregroundStyle(Color.ink)

      Spacer()
    }
    .padding(.vertical, 6)
  }
}

// Search bar component.
private struct SearchBar: View {
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(Color.inkSubtle)

      Text("Search")
        .font(.system(.body))
        .foregroundStyle(Color.inkFaint)

      Spacer()
    }
    .padding(.vertical, 11)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity)
    .glassBackground(cornerRadius: 12)
  }
}

// Card displaying a Notebook in the grid.
private struct NoteCard: View {
  let title: String
  let notebookID: String
  @ObservedObject var library: NotebookLibrary
  @State private var showingRenameAlert = false
  @State private var newName = ""
  @State private var showingDeleteAlert = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(alignment: .leading, spacing: 10) {
        Text(title)
          .font(.system(.title3, weight: .semibold))
          .foregroundStyle(Color.ink)
          .lineLimit(2)

        Spacer(minLength: 0)
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)

      Menu {
        Button {
          newName = title
          showingRenameAlert = true
        } label: {
          Label("Rename", systemImage: "pencil")
        }

        Button(role: .destructive) {
          showingDeleteAlert = true
        } label: {
          Label("Delete", systemImage: "trash")
        }

        Button(role: .cancel) {
        } label: {
          Label("Cancel", systemImage: "xmark")
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(Color.inkSubtle)
          .padding(8)
          .contentShape(Rectangle())
      }
      .menuIndicator(.hidden)
      .transaction { transaction in
        transaction.animation = nil
      }
      .padding(8)
    }
    .glassBackground(cornerRadius: 14)
    .alert("Rename Notebook", isPresented: $showingRenameAlert) {
      TextField("Name", text: $newName)
      Button("Cancel", role: .cancel) {}
      Button("Rename") {
        Task {
          await library.renameNotebook(notebookID: notebookID, newDisplayName: newName)
        }
      }
    } message: {
      Text("Enter a new name for this notebook.")
    }
    .alert("Delete Notebook", isPresented: $showingDeleteAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        Task {
          await library.deleteNotebook(notebookID: notebookID)
        }
      }
    } message: {
      Text("Are you sure you want to delete \"\(title)\"? This action cannot be undone.")
    }
  }
}

// Card for creating a new Notebook.
private struct NewNoteCard: View {
  @ObservedObject var library: NotebookLibrary

  var body: some View {
    Button {
      Task {
        await library.createNotebook()
      }
    } label: {
      VStack(spacing: 10) {
        Image(systemName: "plus")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(Color.inkSubtle)

        Text("New note")
          .font(.system(.body, weight: .semibold))
          .foregroundStyle(Color.ink)
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: 160)
      .glassBackground(cornerRadius: 14)
    }
    .buttonStyle(.plain)
  }
}
