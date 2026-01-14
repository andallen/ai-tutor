import Foundation

// Notification names used for notebook updates.
extension Notification.Name {
  // Posted after a preview image is saved.
  static let notebookPreviewUpdated = Notification.Name("notebookPreviewUpdated")

  // MARK: - Indexing Notifications

  // Posted after notebook JIIX content is saved to disk.
  // userInfo contains: documentID (String)
  static let notebookContentSaved = Notification.Name("notebookContentSaved")

  // Posted after a PDF document is imported.
  // userInfo contains: documentID (String), displayName (String), modifiedAt (Date)
  static let pdfDocumentImported = Notification.Name("pdfDocumentImported")

  // Posted after a lesson is created or modified.
  // userInfo contains: documentID (String)
  static let lessonContentSaved = Notification.Name("lessonContentSaved")

  // Posted when document indexing completes successfully.
  // userInfo contains: documentID (String), result (IndexingResult)
  static let documentIndexingCompleted = Notification.Name("documentIndexingCompleted")

  // Posted when document indexing fails.
  // userInfo contains: documentID (String), error (String)
  static let documentIndexingFailed = Notification.Name("documentIndexingFailed")

  // MARK: - Folder Notifications

  // Posted when a folder is created.
  // userInfo contains: folderID (String), displayName (String)
  static let folderCreated = Notification.Name("folderCreated")

  // Posted when a folder is renamed.
  // userInfo contains: folderID (String), displayName (String)
  static let folderRenamed = Notification.Name("folderRenamed")
}
