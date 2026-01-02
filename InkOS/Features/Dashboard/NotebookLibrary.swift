import Combine
import Foundation
import PDFKit
import SwiftUI

// The Notebook Library connects the Dashboard to the Bundle Manager.
// It translates Dashboard actions into operations on the Bundle Manager
// and keeps the Dashboard list of Notebooks and Folders accurate.
// The Notebook Library does not read or write files directly.
// It treats the Bundle Manager as the one place that knows how items are stored.
// swiftlint:disable type_body_length
// Type body length exception: Centralized facade for notebook, folder, and PDF document operations.
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

  // The list of PDF documents currently available.
  // Updated when loadPDFDocuments is called.
  @Published var pdfDocuments: [PDFDocumentMetadata] = []

  // The Bundle Manager instance used to perform operations on Bundles.
  private let bundleManager: BundleManager

  // Creates a new Notebook Library with the given Bundle Manager.
  // The Bundle Manager dependency is passed in to allow testing and flexibility.
  init(bundleManager: BundleManager) {
    self.bundleManager = bundleManager
  }

  // Loads the list of Notebooks, Folders, and PDF documents.
  // Updates the notebooks, folders, pdfDocuments, and combined items arrays.
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

    await loadPDFDocuments()

    combineItems()
  }

  // Loads PDF documents from the PDFNotes directory.
  // Enumerates document directories and reads manifests to build metadata.
  // Errors are silently ignored to keep the app usable.
  func loadPDFDocuments() async {
    do {
      let pdfNotesDir = try await PDFNoteStorage.pdfNotesDirectory()
      let fileManager = FileManager.default

      // Check if directory exists.
      guard fileManager.fileExists(atPath: pdfNotesDir.path) else {
        pdfDocuments = []
        return
      }

      // Enumerate subdirectories.
      let contents = try fileManager.contentsOfDirectory(
        at: pdfNotesDir,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )

      var metadata: [PDFDocumentMetadata] = []

      for url in contents {
        // Skip non-directory items.
        let isDir = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
        guard isDir else { continue }

        // Check for manifest file.
        let manifestURL = url.appendingPathComponent(ImportCoordinator.manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else { continue }

        do {
          // Read and decode manifest.
          let data = try Data(contentsOf: manifestURL)
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          let noteDoc = try decoder.decode(NoteDocument.self, from: data)

          // Load preview image if available.
          let previewURL = url.appendingPathComponent("preview.png")
          let previewData: Data? =
            fileManager.fileExists(atPath: previewURL.path)
            ? try? Data(contentsOf: previewURL)
            : nil

          // Build metadata from NoteDocument.
          let docMetadata = PDFDocumentMetadataBuilder.build(
            from: noteDoc,
            previewImageData: previewData
          )
          metadata.append(docMetadata)
        } catch {
          // Skip invalid documents.
          continue
        }
      }

      pdfDocuments = metadata
    } catch {
      // Silently ignore errors to keep the app usable.
      pdfDocuments = []
    }
  }

  // Combines notebooks, folders, and PDF documents into a single sorted list.
  // Sorts by most recently accessed/modified first, with folders appearing before other types
  // when they have the same date.
  private func combineItems() {
    var combined: [DashboardItem] = []
    combined.append(contentsOf: notebooks.map { DashboardItem.notebook($0) })
    combined.append(contentsOf: folders.map { DashboardItem.folder($0) })
    combined.append(contentsOf: pdfDocuments.map { DashboardItem.pdfDocument($0) })

    // Sort by date, most recent first. Folders come before other types with same date.
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

  // MARK: - PDF Document Operations

  // Opens a PDF document for editing.
  // Loads the manifest and PDF file from the document directory.
  // Creates a PDFDocumentHandle for MyScript annotation access.
  // documentID: The UUID of the PDF document to open.
  // Returns: PDFDocumentOpenResult containing handle, noteDocument, and pdfDocument.
  // Throws: PDFDocumentLifecycleError on failure.
  func openPDFDocument(documentID: UUID) async throws -> PDFDocumentOpenResult {
    let documentDirectory = try await getDocumentDirectory(for: documentID)
    let noteDocument = try loadManifest(from: documentDirectory, documentID: documentID)
    let pdfDocument = try loadPDFDocument(from: documentDirectory, documentID: documentID)
    let handle = try await createDocumentHandle(
      documentDirectory: documentDirectory,
      noteDocument: noteDocument,
      documentID: documentID
    )
    let package = try await loadMyScriptPackage(
      from: documentDirectory,
      documentID: documentID
    )

    return PDFDocumentOpenResult(
      handle: handle,
      noteDocument: noteDocument,
      pdfDocument: pdfDocument,
      package: package
    )
  }

  // Retrieves and validates the document directory.
  // documentID: The UUID of the document.
  // Returns: The validated document directory URL.
  // Throws: PDFDocumentLifecycleError if directory is not found or invalid.
  private func getDocumentDirectory(for documentID: UUID) async throws -> URL {
    let documentDirectory: URL
    do {
      documentDirectory = try await PDFNoteStorage.documentDirectory(for: documentID)
    } catch {
      throw PDFDocumentLifecycleError.documentDirectoryNotFound(documentID: documentID)
    }

    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: documentDirectory.path) else {
      throw PDFDocumentLifecycleError.documentDirectoryNotFound(documentID: documentID)
    }

    return documentDirectory
  }

  // Loads and decodes the manifest file.
  // documentDirectory: The directory containing the manifest.
  // documentID: The UUID of the document.
  // Returns: The decoded NoteDocument.
  // Throws: PDFDocumentLifecycleError if manifest is not found or cannot be decoded.
  private func loadManifest(
    from documentDirectory: URL,
    documentID: UUID
  ) throws -> NoteDocument {
    let manifestURL = documentDirectory.appendingPathComponent(ImportCoordinator.manifestFileName)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw PDFDocumentLifecycleError.manifestNotFound(documentID: documentID)
    }

    do {
      let manifestData = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode(NoteDocument.self, from: manifestData)
    } catch {
      throw PDFDocumentLifecycleError.manifestDecodingFailed(
        documentID: documentID,
        reason: error.localizedDescription
      )
    }
  }

  // Loads the PDF document from file.
  // documentDirectory: The directory containing the PDF file.
  // documentID: The UUID of the document.
  // Returns: The loaded PDFDocument.
  // Throws: PDFDocumentLifecycleError if PDF is not found or cannot be loaded.
  private func loadPDFDocument(
    from documentDirectory: URL,
    documentID: UUID
  ) throws -> PDFDocument {
    let pdfURL = documentDirectory.appendingPathComponent(ImportCoordinator.pdfFileName)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: pdfURL.path) else {
      throw PDFDocumentLifecycleError.pdfNotFound(documentID: documentID)
    }

    guard let pdfDocument = PDFDocument(url: pdfURL) else {
      throw PDFDocumentLifecycleError.pdfLoadFailed(
        documentID: documentID,
        reason: "Could not load PDF file"
      )
    }

    return pdfDocument
  }

  // Creates the PDF document handle.
  // documentDirectory: The directory containing the document files.
  // noteDocument: The decoded manifest.
  // documentID: The UUID of the document.
  // Returns: The created PDFDocumentHandle.
  // Throws: PDFDocumentLifecycleError if handle creation fails.
  private func createDocumentHandle(
    documentDirectory: URL,
    noteDocument: NoteDocument,
    documentID: UUID
  ) async throws -> PDFDocumentHandle {
    do {
      return try await PDFDocumentHandle(
        documentDirectory: documentDirectory,
        noteDocument: noteDocument
      )
    } catch {
      throw PDFDocumentLifecycleError.handleCreationFailed(
        documentID: documentID,
        reason: error.localizedDescription
      )
    }
  }

  // Loads the MyScript package.
  // documentDirectory: The directory containing the package file.
  // documentID: The UUID of the document.
  // Returns: The loaded MyScript package.
  // Throws: PDFDocumentLifecycleError if package cannot be loaded.
  private func loadMyScriptPackage(
    from documentDirectory: URL,
    documentID: UUID
  ) async throws -> any ContentPackageProtocol {
    let packageURL = documentDirectory.appendingPathComponent(ImportCoordinator.iinkFileName)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: packageURL.path) else {
      throw PDFDocumentLifecycleError.packageNotFound(documentID: documentID)
    }

    do {
      return try await MainActor.run {
        guard let engine = EngineProvider.sharedInstance.engine else {
          throw PDFDocumentLifecycleError.engineNotAvailable(documentID: documentID)
        }
        return try engine.openPackage(packageURL.path, openOption: .existing)
      }
    } catch let error as PDFDocumentLifecycleError {
      throw error
    } catch {
      throw PDFDocumentLifecycleError.packageLoadFailed(
        documentID: documentID,
        reason: error.localizedDescription
      )
    }
  }

  // MARK: - Folder Operations

  // Creates a new Folder by asking the Bundle Manager to create it.
  // After creation, refreshes the list to include the new Folder.
  // Uses a default display name if none is provided.
  // Errors are silently ignored to keep the app usable.
  func createFolder(displayName: String = "Untitled Folder") async {
    do {
      _ = try await bundleManager.createFolder(displayName: displayName)
      // Refresh the list to include the newly created Folder.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
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
