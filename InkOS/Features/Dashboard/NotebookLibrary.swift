import Combine
import Foundation
import SwiftUI

// The Notebook Library connects the Dashboard to the Bundle Manager.
// It translates Dashboard actions into operations on the Bundle Manager
// and keeps the Dashboard list of Notebooks and Folders accurate.
// The Notebook Library does not read or write files directly.
// It treats the Bundle Manager as the one place that knows how items are stored.
@MainActor
class NotebookLibrary: ObservableObject {
  // The list of root-level Notebooks currently available.
  // Updated when bundles are loaded from the Bundle Manager.
  @Published var notebooks: [NotebookMetadata] = []

  // The list of Folders currently available.
  // Updated when folders are loaded from the Bundle Manager.
  @Published var folders: [FolderMetadata] = []

  // Combined list of notebooks and folders for display in the Dashboard grid.
  // Sorted by most recently accessed/modified first.
  @Published var items: [DashboardItem] = []

  // The Bundle Manager instance used to perform operations on Bundles.
  private let bundleManager: BundleManager

  // Creates a new Notebook Library with the given Bundle Manager.
  // The Bundle Manager dependency is passed in to allow testing and flexibility.
  init(bundleManager: BundleManager) {
    self.bundleManager = bundleManager
  }

  // Loads the list of Notebooks and Folders from the Bundle Manager.
  // Updates the notebooks, folders, and combined items arrays.
  // This should be called when the Dashboard appears to refresh the list.
  // Errors are silently ignored to keep the app usable.
  func loadBundles() async {
    do {
      let bundles = try await bundleManager.listBundles()
      notebooks = bundles
    } catch {
      // Silently ignore errors to keep the app usable.
    }

    do {
      let folderList = try await bundleManager.listFolders()
      folders = folderList
    } catch {
      // Silently ignore errors to keep the app usable.
    }

    combineItems()
  }

  // Combines notebooks and folders into a single sorted list.
  // Sorts by most recently accessed/modified first, with folders appearing before notebooks
  // when they have the same date.
  private func combineItems() {
    var combined: [DashboardItem] = []
    combined.append(contentsOf: notebooks.map { DashboardItem.notebook($0) })
    combined.append(contentsOf: folders.map { DashboardItem.folder($0) })

    // Sort by date, most recent first. Folders come before notebooks with same date.
    combined.sort { lhs, rhs in
      let lhsDate = lhs.sortDate ?? Date.distantPast
      let rhsDate = rhs.sortDate ?? Date.distantPast
      if lhsDate == rhsDate {
        return lhs.isFolder && !rhs.isFolder
      }
      return lhsDate > rhsDate
    }

    items = combined
  }

  // Creates a new Notebook by asking the Bundle Manager to create a Bundle.
  // After creation, refreshes the list of Notebooks to include the new one.
  // Uses a default display name if none is provided.
  // Errors are silently ignored to keep the app usable.
  func createNotebook(displayName: String = "Untitled Notebook") async {
    do {
      _ = try await bundleManager.createBundle(displayName: displayName)
      // Refresh the list to include the newly created Notebook.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Creates a new Notebook inside a specific Folder.
  // The Notebook is created and then moved into the Folder.
  // After creation, refreshes the list to include the new Notebook.
  // Returns the created NotebookMetadata so the caller can use it.
  // Errors are silently ignored to keep the app usable.
  func createNotebookInFolder(
    folderID: String,
    displayName: String = "Untitled Notebook"
  ) async -> NotebookMetadata? {
    do {
      let metadata = try await bundleManager.createBundle(displayName: displayName)
      try await bundleManager.moveNotebookToFolder(notebookID: metadata.id, folderID: folderID)
      // Refresh the list to include the newly created Notebook.
      await loadBundles()
      return metadata
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
      return nil
    }
  }

  // Renames a Notebook by asking the Bundle Manager to update the display name.
  // After renaming, refreshes the list of Notebooks to show the updated name.
  // Errors are silently ignored to keep the app usable.
  func renameNotebook(notebookID: String, newDisplayName: String) async {
    do {
      try await bundleManager.renameBundle(notebookID: notebookID, newDisplayName: newDisplayName)
      // Refresh the list to show the updated name.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Deletes a Notebook by asking the Bundle Manager to remove the Bundle.
  // After deletion, refreshes the list of Notebooks to remove the deleted one.
  // Errors are silently ignored to keep the app usable.
  func deleteNotebook(notebookID: String) async {
    do {
      try await bundleManager.deleteBundle(notebookID: notebookID)
      // Refresh the list to remove the deleted Notebook.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Opens a Notebook by asking the Bundle Manager to validate and open the Bundle.
  // Returns a DocumentHandle that the editor can use for safe operations.
  // Throws if the Notebook cannot be opened.
  func openNotebook(notebookID: String) async throws -> DocumentHandle {
    return try await bundleManager.openNotebook(id: notebookID)
  }

  // MARK: - Folder Operations

  // Creates a new Folder by asking the Bundle Manager to create it.
  // After creation, refreshes the list to include the new Folder.
  // Uses a default display name if none is provided.
  // Returns the folder ID on success, nil on failure.
  // Errors are silently ignored to keep the app usable.
  @discardableResult
  func createFolder(displayName: String = "Untitled Folder") async -> String? {
    do {
      let folder = try await bundleManager.createFolder(displayName: displayName)
      // Refresh the list to include the newly created Folder.
      await loadBundles()
      return folder.id
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
      return nil
    }
  }

  // Renames a Folder by asking the Bundle Manager to update the display name.
  // After renaming, refreshes the list to show the updated name.
  // Errors are silently ignored to keep the app usable.
  func renameFolder(folderID: String, newDisplayName: String) async {
    do {
      try await bundleManager.renameFolder(folderID: folderID, newDisplayName: newDisplayName)
      // Refresh the list to show the updated name.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Deletes a Folder by asking the Bundle Manager to remove it.
  // All Notebooks inside the Folder are also deleted.
  // After deletion, refreshes the list to remove the deleted Folder.
  // Errors are silently ignored to keep the app usable.
  func deleteFolder(folderID: String) async {
    do {
      try await bundleManager.deleteFolder(folderID: folderID)
      // Refresh the list to remove the deleted Folder.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Moves a Notebook into a Folder.
  // The Notebook is relocated from its current location to inside the Folder.
  // After moving, refreshes the list to reflect the change.
  // Errors are silently ignored to keep the app usable.
  func moveNotebookToFolder(notebookID: String, folderID: String) async {
    do {
      try await bundleManager.moveNotebookToFolder(notebookID: notebookID, folderID: folderID)
      // Refresh the list to reflect the move.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Moves a Notebook out of a Folder back to the root level.
  // The Notebook is relocated from inside the Folder to the root Notebooks directory.
  // After moving, refreshes the list to reflect the change.
  // Errors are silently ignored to keep the app usable.
  func moveNotebookToRoot(notebookID: String, fromFolderID: String) async {
    do {
      try await bundleManager.moveNotebookToRoot(notebookID: notebookID, fromFolderID: fromFolderID)
      // Refresh the list to reflect the move.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Loads the list of Notebooks inside a specific Folder.
  // Returns an array of NotebookMetadata for Notebooks in the Folder.
  // Returns empty array if the Folder doesn't exist or cannot be read.
  func notebooksInFolder(folderID: String) async -> [NotebookMetadata] {
    do {
      return try await bundleManager.listBundlesInFolder(folderID: folderID)
    } catch {
      // Return empty array on error to keep the app usable.
      return []
    }
  }
}
