// PDFEditorHostView.swift
// SwiftUI wrapper for PDFEditorViewController.
// Bridges the UIKit-based PDF editor to SwiftUI.

import PDFKit
import SwiftUI

// SwiftUI view that hosts the PDF annotation editor.
struct PDFEditorHostView: UIViewControllerRepresentable {

  // The PDF document session to edit.
  let session: PDFDocumentSession

  // Called when the editor is dismissed.
  var onDismiss: (() -> Void)?

  // Creates the UIKit view controller.
  func makeUIViewController(context: Context) -> UINavigationController {
    let viewModel = PDFEditorViewModel(session: session)
    let editorVC = PDFEditorViewController(viewModel: viewModel)
    editorVC.dismissHandler = onDismiss

    // Use UINavigationController to match EditorHostView.
    let navController = UINavigationController(rootViewController: editorVC)
    navController.modalPresentationStyle = .fullScreen
    return navController
  }

  // Updates the view controller when SwiftUI state changes.
  func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    // No updates needed - session is immutable.
  }

  // Coordinator for handling delegate callbacks.
  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }

  // Coordinator class.
  class Coordinator: NSObject {
    let onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)?) {
      self.onDismiss = onDismiss
    }
  }
}
