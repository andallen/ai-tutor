import Combine
import Foundation
import SwiftUI

// The Notebook Library connects the Dashboard to the Bundle Manager.
// It translates Dashboard actions into operations on the Bundle Manager
// and keeps the Dashboard list of Notebooks accurate.
// The Notebook Library does not read or write files directly.
// It treats the Bundle Manager as the one place that knows how Notebooks are stored.
@MainActor
class NotebookLibrary: ObservableObject {
  // The list of Notebooks currently available.
  // Updated when bundles are loaded from the Bundle Manager.
  @Published var notebooks: [NotebookMetadata] = []

  // The Bundle Manager instance used to perform operations on Bundles.
  private let bundleManager: BundleManager

  // Creates a new Notebook Library with the given Bundle Manager.
  // The Bundle Manager dependency is passed in to allow testing and flexibility.
  init(bundleManager: BundleManager) {
    self.bundleManager = bundleManager
  }

  // Loads the list of Notebooks from the Bundle Manager.
  // Updates the notebooks array with the current list of Bundles.
  // This should be called when the Dashboard appears to refresh the list.
  // Errors are silently ignored to keep the app usable.
  func loadBundles() async {
    do {
      let bundles = try await bundleManager.listBundles()
      notebooks = bundles
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
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
}
