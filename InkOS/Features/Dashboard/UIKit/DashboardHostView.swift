// SwiftUI wrapper for the UIKit DashboardViewController.
// Allows the UIKit dashboard to be used within the SwiftUI app structure.

import PDFKit
import SwiftUI

// SwiftUI view that hosts the UIKit DashboardViewController.
struct DashboardHostView: View {
  // Notebook session state (passed to editor when opening a notebook).
  @State private var activeSession: NotebookSession?

  // PDF session state (passed to PDF editor when opening a PDF).
  @State private var activePDFSession: PDFDocumentSession?

  // Lesson session state (passed to lesson view when opening a lesson).
  @State private var activeLessonID: String?

  var body: some View {
    DashboardViewControllerRepresentable(
      onNotebookSelected: { notebook in
        Task {
          await openNotebook(notebook)
        }
      },
      onPDFSelected: { pdf in
        Task {
          await openPDF(pdf)
        }
      },
      onLessonSelected: { lesson in
        activeLessonID = lesson.id
      }
    )
    .ignoresSafeArea()
    // Notebook editor presentation.
    .fullScreenCover(item: $activeSession) { session in
      EditorHostView(documentHandle: session.handle, onDismiss: {
        activeSession = nil
      })
    }
    // PDF editor presentation.
    .fullScreenCover(item: $activePDFSession) { session in
      PDFEditorHostView(session: session, onDismiss: {
        activePDFSession = nil
      })
    }
  }

  // Opens a notebook in the editor.
  private func openNotebook(_ notebook: NotebookMetadata) async {
    do {
      let handle = try await NotebookLibrary(bundleManager: BundleManager.shared)
        .openNotebook(notebookID: notebook.id)
      activeSession = NotebookSession(id: notebook.id, handle: handle)
    } catch {
      // TODO: Show error alert
    }
  }

  // Opens a PDF document in the PDF editor.
  private func openPDF(_ pdf: PDFDocumentMetadata) async {
    guard let uuid = UUID(uuidString: pdf.id) else { return }
    do {
      let result = try await NotebookLibrary(bundleManager: BundleManager.shared)
        .openPDFDocument(documentID: uuid)
      activePDFSession = PDFDocumentSession(
        id: pdf.id,
        handle: result.handle,
        noteDocument: result.noteDocument,
        pdfDocument: result.pdfDocument
      )
    } catch {
      // TODO: Show error alert
    }
  }
}

// UIViewControllerRepresentable for the UIKit dashboard.
// Folder overlay is now handled internally by DashboardViewController.
struct DashboardViewControllerRepresentable: UIViewControllerRepresentable {
  let onNotebookSelected: (NotebookMetadata) -> Void
  let onPDFSelected: (PDFDocumentMetadata) -> Void
  let onLessonSelected: (LessonMetadata) -> Void

  func makeUIViewController(context: Context) -> UINavigationController {
    let library = NotebookLibrary(bundleManager: BundleManager.shared)
    let dashboardVC = DashboardViewController(library: library)
    dashboardVC.delegate = context.coordinator

    let navController = UINavigationController(rootViewController: dashboardVC)
    navController.navigationBar.prefersLargeTitles = true

    return navController
  }

  func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    // Update callbacks if needed.
    context.coordinator.onNotebookSelected = onNotebookSelected
    context.coordinator.onPDFSelected = onPDFSelected
    context.coordinator.onLessonSelected = onLessonSelected
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      onNotebookSelected: onNotebookSelected,
      onPDFSelected: onPDFSelected,
      onLessonSelected: onLessonSelected
    )
  }

  class Coordinator: NSObject, DashboardViewControllerDelegate {
    var onNotebookSelected: (NotebookMetadata) -> Void
    var onPDFSelected: (PDFDocumentMetadata) -> Void
    var onLessonSelected: (LessonMetadata) -> Void

    init(
      onNotebookSelected: @escaping (NotebookMetadata) -> Void,
      onPDFSelected: @escaping (PDFDocumentMetadata) -> Void,
      onLessonSelected: @escaping (LessonMetadata) -> Void
    ) {
      self.onNotebookSelected = onNotebookSelected
      self.onPDFSelected = onPDFSelected
      self.onLessonSelected = onLessonSelected
    }

    func dashboardDidSelectNotebook(_ notebook: NotebookMetadata) {
      onNotebookSelected(notebook)
    }

    func dashboardDidSelectPDF(_ pdf: PDFDocumentMetadata) {
      onPDFSelected(pdf)
    }

    func dashboardDidSelectFolder(_ folder: FolderMetadata, thumbnails: [UIImage]) {
      // Folder overlay is now handled internally by DashboardViewController.
      // This delegate method is no longer called but kept for protocol conformance.
    }

    func dashboardDidSelectLesson(_ lesson: LessonMetadata) {
      onLessonSelected(lesson)
    }
  }
}
