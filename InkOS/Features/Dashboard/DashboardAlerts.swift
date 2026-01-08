import SwiftUI

// MARK: - Alert Modifiers

// Encapsulates all alert modifiers to reduce complexity in the main view body.
struct AlertModifiers: ViewModifier {
  @Binding var renamingNotebook: NotebookMetadata?
  @Binding var renameText: String
  @Binding var deletingNotebook: NotebookMetadata?
  @Binding var renamingPDF: PDFDocumentMetadata?
  @Binding var deletingPDF: PDFDocumentMetadata?
  @Binding var renamingLesson: LessonMetadata?
  @Binding var deletingLesson: LessonMetadata?
  @Binding var renamingFolder: FolderMetadata?
  @Binding var deletingFolder: FolderMetadata?
  @Binding var showCreateFolderAlert: Bool
  @Binding var newFolderName: String
  @Binding var openErrorMessage: String?
  @ObservedObject var library: NotebookLibrary
  let onCreateFolder: () async -> Void

  func body(content: Content) -> some View {
    content
      .modifier(
        RenameNotebookAlert(
          renamingNotebook: $renamingNotebook,
          renameText: $renameText,
          library: library
        )
      )
      .modifier(
        DeleteNotebookAlert(
          deletingNotebook: $deletingNotebook,
          library: library
        )
      )
      .modifier(
        RenamePDFAlert(
          renamingPDF: $renamingPDF,
          renameText: $renameText,
          library: library
        )
      )
      .modifier(
        DeletePDFAlert(
          deletingPDF: $deletingPDF,
          library: library
        )
      )
      .modifier(
        RenameLessonAlert(
          renamingLesson: $renamingLesson,
          renameText: $renameText,
          library: library
        )
      )
      .modifier(
        DeleteLessonAlert(
          deletingLesson: $deletingLesson,
          library: library
        )
      )
      .modifier(
        RenameFolderAlert(
          renamingFolder: $renamingFolder,
          renameText: $renameText,
          library: library
        )
      )
      .modifier(
        DeleteFolderAlert(
          deletingFolder: $deletingFolder,
          library: library
        )
      )
      .modifier(
        CreateFolderAlert(
          showCreateFolderAlert: $showCreateFolderAlert,
          newFolderName: $newFolderName,
          library: library,
          onCreateFolder: onCreateFolder
        )
      )
      .modifier(OpenErrorAlert(openErrorMessage: $openErrorMessage))
  }
}

// MARK: - Rename Notebook Alert

// Alert dialog for renaming a notebook.
struct RenameNotebookAlert: ViewModifier {
  @Binding var renamingNotebook: NotebookMetadata?
  @Binding var renameText: String
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Rename Notebook",
        isPresented: .init(
          get: { renamingNotebook != nil },
          set: { if !$0 { renamingNotebook = nil } }
        )
      ) {
        TextField("Notebook name", text: $renameText)
        Button("Cancel", role: .cancel) {
          renamingNotebook = nil
        }
        Button("Rename") {
          let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
          if let notebook = renamingNotebook, !trimmedName.isEmpty {
            Task {
              await library.renameNotebook(notebookID: notebook.id, newDisplayName: trimmedName)
            }
          }
          renamingNotebook = nil
        }
      } message: {
        Text("Enter a new name for this notebook.")
      }
  }
}

// MARK: - Delete Notebook Alert

// Confirmation alert for deleting a notebook.
struct DeleteNotebookAlert: ViewModifier {
  @Binding var deletingNotebook: NotebookMetadata?
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Delete Notebook?",
        isPresented: .init(
          get: { deletingNotebook != nil },
          set: { if !$0 { deletingNotebook = nil } }
        )
      ) {
        Button("Cancel", role: .cancel) {
          deletingNotebook = nil
        }
        Button("Delete", role: .destructive) {
          if let notebook = deletingNotebook {
            Task {
              await library.deleteNotebook(notebookID: notebook.id)
            }
          }
          deletingNotebook = nil
        }
      } message: {
        if let notebook = deletingNotebook {
          Text("\"\(notebook.displayName)\" will be permanently deleted. This cannot be undone.")
        }
      }
  }
}

// MARK: - Rename Folder Alert

// Alert dialog for renaming a folder.
struct RenameFolderAlert: ViewModifier {
  @Binding var renamingFolder: FolderMetadata?
  @Binding var renameText: String
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Rename Folder",
        isPresented: .init(
          get: { renamingFolder != nil },
          set: { if !$0 { renamingFolder = nil } }
        )
      ) {
        TextField("Folder name", text: $renameText)
        Button("Cancel", role: .cancel) {
          renamingFolder = nil
        }
        Button("Rename") {
          let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
          if let folder = renamingFolder, !trimmedName.isEmpty {
            Task {
              await library.renameFolder(folderID: folder.id, newDisplayName: trimmedName)
            }
          }
          renamingFolder = nil
        }
      } message: {
        Text("Enter a new name for this folder.")
      }
  }
}

// MARK: - Delete Folder Alert

// Confirmation alert for deleting a folder and all its contents.
struct DeleteFolderAlert: ViewModifier {
  @Binding var deletingFolder: FolderMetadata?
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Delete Folder?",
        isPresented: .init(
          get: { deletingFolder != nil },
          set: { if !$0 { deletingFolder = nil } }
        )
      ) {
        Button("Cancel", role: .cancel) {
          deletingFolder = nil
        }
        Button("Delete", role: .destructive) {
          if let folder = deletingFolder {
            Task {
              await library.deleteFolder(folderID: folder.id)
            }
          }
          deletingFolder = nil
        }
      } message: {
        if let folder = deletingFolder {
          Text(
            "\"\(folder.displayName)\" and all notebooks inside it will be permanently deleted. This cannot be undone."
          )
        }
      }
  }
}

// MARK: - Create Folder Alert

// Alert dialog for creating a new folder.
struct CreateFolderAlert: ViewModifier {
  @Binding var showCreateFolderAlert: Bool
  @Binding var newFolderName: String
  @ObservedObject var library: NotebookLibrary
  let onCreateFolder: () async -> Void

  func body(content: Content) -> some View {
    content
      .alert(
        "New Folder",
        isPresented: $showCreateFolderAlert
      ) {
        TextField("Folder name", text: $newFolderName)
        Button("Cancel", role: .cancel) {
          showCreateFolderAlert = false
        }
        Button("Create") {
          let trimmedName = newFolderName.trimmingCharacters(in: .whitespaces)
          let folderName = trimmedName.isEmpty ? "Untitled Folder" : trimmedName
          Task {
            await library.createFolder(displayName: folderName)
            await onCreateFolder()
          }
          showCreateFolderAlert = false
        }
      } message: {
        Text("Enter a name for the new folder.")
      }
  }
}

// MARK: - Open Error Alert

// Alert displayed when opening a notebook fails.
struct OpenErrorAlert: ViewModifier {
  @Binding var openErrorMessage: String?

  func body(content: Content) -> some View {
    content
      .alert(
        "Unable to Open Notebook",
        isPresented: .init(
          get: { openErrorMessage != nil },
          set: { if !$0 { openErrorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {
          openErrorMessage = nil
        }
      } message: {
        Text(openErrorMessage ?? "Unknown error.")
      }
  }
}

// MARK: - Rename PDF Alert

// Alert dialog for renaming a PDF document.
struct RenamePDFAlert: ViewModifier {
  @Binding var renamingPDF: PDFDocumentMetadata?
  @Binding var renameText: String
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Rename PDF",
        isPresented: .init(
          get: { renamingPDF != nil },
          set: { if !$0 { renamingPDF = nil } }
        )
      ) {
        TextField("PDF name", text: $renameText)
        Button("Cancel", role: .cancel) {
          renamingPDF = nil
        }
        Button("Rename") {
          let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
          if let pdf = renamingPDF, !trimmedName.isEmpty {
            Task {
              await library.renamePDFDocument(documentID: pdf.id, newDisplayName: trimmedName)
            }
          }
          renamingPDF = nil
        }
      } message: {
        Text("Enter a new name for this PDF.")
      }
  }
}

// MARK: - Delete PDF Alert

// Confirmation alert for deleting a PDF document.
struct DeletePDFAlert: ViewModifier {
  @Binding var deletingPDF: PDFDocumentMetadata?
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Delete PDF?",
        isPresented: .init(
          get: { deletingPDF != nil },
          set: { if !$0 { deletingPDF = nil } }
        )
      ) {
        Button("Cancel", role: .cancel) {
          deletingPDF = nil
        }
        Button("Delete", role: .destructive) {
          if let pdf = deletingPDF {
            Task {
              await library.deletePDFDocument(documentID: pdf.id)
            }
          }
          deletingPDF = nil
        }
      } message: {
        if let pdf = deletingPDF {
          Text("\"\(pdf.displayName)\" will be permanently deleted. This cannot be undone.")
        }
      }
  }
}

// MARK: - Rename Lesson Alert

// Alert dialog for renaming a lesson.
struct RenameLessonAlert: ViewModifier {
  @Binding var renamingLesson: LessonMetadata?
  @Binding var renameText: String
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Rename Lesson",
        isPresented: .init(
          get: { renamingLesson != nil },
          set: { if !$0 { renamingLesson = nil } }
        )
      ) {
        TextField("Lesson name", text: $renameText)
        Button("Cancel", role: .cancel) {
          renamingLesson = nil
        }
        Button("Rename") {
          let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
          if let lesson = renamingLesson, !trimmedName.isEmpty {
            Task {
              await library.renameLesson(lessonID: lesson.id, newDisplayName: trimmedName)
            }
          }
          renamingLesson = nil
        }
      } message: {
        Text("Enter a new name for this lesson.")
      }
  }
}

// MARK: - Delete Lesson Alert

// Confirmation alert for deleting a lesson.
struct DeleteLessonAlert: ViewModifier {
  @Binding var deletingLesson: LessonMetadata?
  @ObservedObject var library: NotebookLibrary

  func body(content: Content) -> some View {
    content
      .alert(
        "Delete Lesson?",
        isPresented: .init(
          get: { deletingLesson != nil },
          set: { if !$0 { deletingLesson = nil } }
        )
      ) {
        Button("Cancel", role: .cancel) {
          deletingLesson = nil
        }
        Button("Delete", role: .destructive) {
          if let lesson = deletingLesson {
            Task {
              await library.deleteLesson(lessonID: lesson.id)
            }
          }
          deletingLesson = nil
        }
      } message: {
        if let lesson = deletingLesson {
          Text("\"\(lesson.displayName)\" will be permanently deleted. This cannot be undone.")
        }
      }
  }
}
