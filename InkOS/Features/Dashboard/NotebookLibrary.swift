import Combine
import Foundation
import PDFKit
import SwiftUI

// The Notebook Library connects the Dashboard to the Bundle Manager.
// It translates Dashboard actions into operations on the Bundle Manager
// and keeps the Dashboard list of Notebooks and Folders accurate.
// The Notebook Library does not read or write files directly.
// It treats the Bundle Manager as the one place that knows how items are stored.
// swiftlint:disable file_length type_body_length
// File and type body length exceptions: Centralized facade for notebook, folder, and PDF document operations.
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

  // The list of lessons currently available.
  // Updated when loadBundles is called.
  @Published var lessons: [LessonMetadata] = []

  // The Bundle Manager instance used to perform operations on Bundles.
  // Exposed as internal (not private) for search index initialization.
  let bundleManager: BundleManager

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

    // Load folders first (without PDF info).
    var folderList: [FolderMetadata] = []
    do {
      folderList = try await bundleManager.listFolders()
    } catch {
      // Silently ignore errors to keep the app usable.
    }

    // Load all PDFs to get folder membership info.
    let allPDFs = await loadAllPDFDocuments()

    // Filter to only show root-level PDFs (not in a folder).
    pdfDocuments = allPDFs.filter { $0.folderID == nil }

    // Enhance folder metadata with PDF counts and previews.
    folders = enhanceFoldersWithPDFInfo(folders: folderList, allPDFs: allPDFs)

    // Load lessons.
    do {
      lessons = try await bundleManager.listLessons()
    } catch {
      // Silently ignore errors to keep the app usable.
    }

    combineItems()
  }

  // Enhances folder metadata with PDF counts and preview images.
  // Combines notebook previews with PDF previews (up to 4 total).
  private func enhanceFoldersWithPDFInfo(
    folders: [FolderMetadata],
    allPDFs: [PDFDocumentMetadata]
  ) -> [FolderMetadata] {
    // Group PDFs by folder ID.
    var pdfsByFolder: [String: [PDFDocumentMetadata]] = [:]
    for pdf in allPDFs {
      if let folderID = pdf.folderID {
        pdfsByFolder[folderID, default: []].append(pdf)
      }
    }

    // Rebuild folder metadata with PDF info.
    return folders.map { folder in
      let pdfsInFolder = pdfsByFolder[folder.id] ?? []
      let pdfCount = pdfsInFolder.count

      // Combine notebook previews with PDF previews (up to 4 total).
      var combinedPreviews = folder.previewImages
      let remainingSlots = FolderConstants.maxPreviewImages - combinedPreviews.count
      if remainingSlots > 0 {
        let pdfPreviews = pdfsInFolder
          .prefix(remainingSlots)
          .compactMap { $0.previewImageData }
        combinedPreviews.append(contentsOf: pdfPreviews)
      }

      return FolderMetadata(
        id: folder.id,
        displayName: folder.displayName,
        previewImages: combinedPreviews,
        notebookCount: folder.notebookCount,
        pdfCount: pdfCount,
        modifiedAt: folder.modifiedAt
      )
    }
  }

  // Loads PDF documents from the PDFNotes directory.
  // Only loads root-level PDFs (those without a folderID).
  // Enumerates document directories and reads manifests to build metadata.
  // Errors are silently ignored to keep the app usable.
  func loadPDFDocuments() async {
    let allPDFs = await loadAllPDFDocuments()
    // Filter to only show root-level PDFs (not in a folder).
    pdfDocuments = allPDFs.filter { $0.folderID == nil }
  }

  // Loads all PDF documents from the PDFNotes directory without filtering.
  // Used internally by both loadPDFDocuments and pdfDocumentsInFolder.
  private func loadAllPDFDocuments() async -> [PDFDocumentMetadata] {
    do {
      let pdfNotesDir = try await PDFNoteStorage.pdfNotesDirectory()
      let fileManager = FileManager.default

      // Check if directory exists.
      guard fileManager.fileExists(atPath: pdfNotesDir.path) else {
        return []
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

      // Sort by modifiedAt descending (most recent first).
      // IMPORTANT: This sort order must match the display order in FolderOverlay
      // for thumbnail index consistency when dragging items out of folders.
      metadata.sort { $0.modifiedAt > $1.modifiedAt }

      return metadata
    } catch {
      // Silently ignore errors to keep the app usable.
      return []
    }
  }

  // Returns PDF documents that belong to a specific folder.
  // Used by FolderOverlay to display PDFs inside folders.
  func pdfDocumentsInFolder(folderID: String) async -> [PDFDocumentMetadata] {
    let allPDFs = await loadAllPDFDocuments()
    return allPDFs.filter { $0.folderID == folderID }
  }

  // Combines notebooks, folders, PDF documents, and lessons into a single sorted list.
  // Sorts by most recently accessed/modified first, with folders appearing before other types
  // when they have the same date.
  private func combineItems() {
    var combined: [DashboardItem] = []
    combined.append(contentsOf: notebooks.map { DashboardItem.notebook($0) })
    combined.append(contentsOf: folders.map { DashboardItem.folder($0) })
    combined.append(contentsOf: pdfDocuments.map { DashboardItem.pdfDocument($0) })
    combined.append(contentsOf: lessons.map { DashboardItem.lesson($0) })

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

  // Renames a PDF document by updating its displayName in the manifest.
  // After renaming, refreshes the list of items to show the updated name.
  // Errors are silently ignored to keep the app usable.
  func renamePDFDocument(documentID: String, newDisplayName: String) async {
    guard let uuid = UUID(uuidString: documentID) else { return }

    do {
      let documentDirectory = try await PDFNoteStorage.documentDirectory(for: uuid)
      let manifestURL = documentDirectory.appendingPathComponent(ImportCoordinator.manifestFileName)
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: manifestURL.path) else { return }

      // Read the current manifest.
      let data = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      var noteDocument = try decoder.decode(NoteDocument.self, from: data)

      // Update the display name and modification date.
      noteDocument = NoteDocument(
        documentID: noteDocument.documentID,
        displayName: newDisplayName,
        sourceFileName: noteDocument.sourceFileName,
        createdAt: noteDocument.createdAt,
        modifiedAt: Date(),
        blocks: noteDocument.blocks
      )

      // Write the updated manifest.
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      encoder.dateEncodingStrategy = .iso8601
      let updatedData = try encoder.encode(noteDocument)
      try updatedData.write(to: manifestURL)

      // Refresh the list to show the updated name.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
    }
  }

  // Deletes a PDF document by removing its entire directory.
  // After deletion, refreshes the list of items to remove the deleted document.
  // Errors are silently ignored to keep the app usable.
  func deletePDFDocument(documentID: String) async {
    guard let uuid = UUID(uuidString: documentID) else { return }

    do {
      let documentDirectory = try await PDFNoteStorage.documentDirectory(for: uuid)
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: documentDirectory.path) else { return }

      try fileManager.removeItem(at: documentDirectory)

      // Refresh the list to remove the deleted document.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
    }
  }

  // MARK: - Debug Utilities

  // Represents a corrupt PDF document for debug display.
  struct CorruptPDFInfo: Identifiable {
    let id: String
    let displayName: String
    let reason: String
    let directoryURL: URL
  }

  // Finds PDF documents that are corrupt or improperly imported.
  // A PDF is considered corrupt if:
  // - It has an empty blocks array (no pages were created)
  // - It is missing the annotations.iink file
  // Returns an array of CorruptPDFInfo for display in debug UI.
  func findCorruptPDFs() async -> [CorruptPDFInfo] {
    do {
      let pdfNotesDir = try await PDFNoteStorage.pdfNotesDirectory()
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: pdfNotesDir.path) else {
        return []
      }

      let contents = try fileManager.contentsOfDirectory(
        at: pdfNotesDir,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )

      var corruptPDFs: [CorruptPDFInfo] = []

      for url in contents {
        let isDir = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
        guard isDir else { continue }

        if let corruptInfo = checkPDFDirectory(url: url, fileManager: fileManager) {
          corruptPDFs.append(corruptInfo)
        }
      }

      return corruptPDFs
    } catch {
      return []
    }
  }

  // Checks a single PDF directory for corruption issues.
  // Returns CorruptPDFInfo if the directory contains a corrupt PDF, nil otherwise.
  private func checkPDFDirectory(url: URL, fileManager: FileManager) -> CorruptPDFInfo? {
    let manifestURL = url.appendingPathComponent(ImportCoordinator.manifestFileName)
    let iinkURL = url.appendingPathComponent(ImportCoordinator.iinkFileName)

    // Check if manifest exists.
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      return CorruptPDFInfo(
        id: url.lastPathComponent,
        displayName: "Unknown (no manifest)",
        reason: "Missing manifest file",
        directoryURL: url
      )
    }

    do {
      let data = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let noteDoc = try decoder.decode(NoteDocument.self, from: data)

      var reasons: [String] = []

      // Check for empty blocks.
      if noteDoc.blocks.isEmpty {
        reasons.append("Empty blocks array (0 pages)")
      }

      // Check for missing iink file.
      if !fileManager.fileExists(atPath: iinkURL.path) {
        reasons.append("Missing annotations.iink")
      }

      if !reasons.isEmpty {
        return CorruptPDFInfo(
          id: noteDoc.documentID.uuidString,
          displayName: noteDoc.displayName,
          reason: reasons.joined(separator: ", "),
          directoryURL: url
        )
      }
    } catch {
      // Failed to decode manifest.
      return CorruptPDFInfo(
        id: url.lastPathComponent,
        displayName: "Unknown (decode error)",
        reason: "Invalid manifest: \(error.localizedDescription)",
        directoryURL: url
      )
    }

    return nil
  }

  // Deletes a corrupt PDF by its directory URL.
  // Used by the debug UI to clean up corrupt documents.
  func deleteCorruptPDF(directoryURL: URL) async {
    let fileManager = FileManager.default
    do {
      try fileManager.removeItem(at: directoryURL)
      await loadBundles()
    } catch {
      // Silently ignore errors.
    }
  }

  // Moves a PDF document to a folder by updating its manifest with folder information.
  // The PDF file location does not change; only the folderID property is updated.
  // After moving, refreshes the list to reflect the change.
  // Errors are silently ignored to keep the app usable.
  func movePDFDocumentToFolder(documentID: String, folderID: String) async {
    guard let uuid = UUID(uuidString: documentID) else { return }

    do {
      let documentDirectory = try await PDFNoteStorage.documentDirectory(for: uuid)
      let manifestURL = documentDirectory.appendingPathComponent(ImportCoordinator.manifestFileName)
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: manifestURL.path) else { return }

      // Read the current manifest.
      let data = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      var noteDocument = try decoder.decode(NoteDocument.self, from: data)

      // Update the folder ID and modification date.
      noteDocument = NoteDocument(
        documentID: noteDocument.documentID,
        displayName: noteDocument.displayName,
        sourceFileName: noteDocument.sourceFileName,
        createdAt: noteDocument.createdAt,
        modifiedAt: Date(),
        blocks: noteDocument.blocks,
        folderID: folderID
      )

      // Write the updated manifest.
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      encoder.dateEncodingStrategy = .iso8601
      let updatedData = try encoder.encode(noteDocument)
      try updatedData.write(to: manifestURL)

      // Refresh the list to reflect the move.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
    }
  }

  // Moves a PDF document out of a folder back to the root level.
  // Clears the folderID property in the manifest.
  // After moving, refreshes the list to reflect the change.
  // Errors are silently ignored to keep the app usable.
  func movePDFDocumentToRoot(documentID: String) async {
    guard let uuid = UUID(uuidString: documentID) else { return }

    do {
      let documentDirectory = try await PDFNoteStorage.documentDirectory(for: uuid)
      let manifestURL = documentDirectory.appendingPathComponent(ImportCoordinator.manifestFileName)
      let fileManager = FileManager.default

      guard fileManager.fileExists(atPath: manifestURL.path) else { return }

      // Read the current manifest.
      let data = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      var noteDocument = try decoder.decode(NoteDocument.self, from: data)

      // Clear the folder ID and update modification date.
      noteDocument = NoteDocument(
        documentID: noteDocument.documentID,
        displayName: noteDocument.displayName,
        sourceFileName: noteDocument.sourceFileName,
        createdAt: noteDocument.createdAt,
        modifiedAt: Date(),
        blocks: noteDocument.blocks,
        folderID: nil
      )

      // Write the updated manifest.
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      encoder.dateEncodingStrategy = .iso8601
      let updatedData = try encoder.encode(noteDocument)
      try updatedData.write(to: manifestURL)

      // Refresh the list to reflect the move.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
    }
  }

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

  // MARK: - Lesson Operations

  // Renames a Lesson by asking the Bundle Manager to update the display name.
  // After renaming, refreshes the list of items to show the updated name.
  // Errors are silently ignored to keep the app usable.
  func renameLesson(lessonID: String, newDisplayName: String) async {
    do {
      try await bundleManager.renameLesson(lessonID: lessonID, newDisplayName: newDisplayName)
      // Refresh the list to show the updated name.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }

  // Deletes a Lesson by asking the Bundle Manager to remove the lesson bundle.
  // After deletion, refreshes the list of items to remove the deleted one.
  // Errors are silently ignored to keep the app usable.
  func deleteLesson(lessonID: String) async {
    do {
      try await bundleManager.deleteLesson(lessonID: lessonID)
      // Refresh the list to remove the deleted Lesson.
      await loadBundles()
    } catch {
      // Silently ignore errors to keep the app usable.
      // Later on, should show error message to the user.
    }
  }
}
