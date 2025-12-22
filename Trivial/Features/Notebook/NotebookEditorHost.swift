import SwiftUI
import UIKit

// Bridges a UIKit editor controller into SwiftUI.
struct NotebookEditorHost: UIViewControllerRepresentable {
    // Identifies which package should be opened for editing.
    let documentHandle: DocumentHandle

    func makeUIViewController(context: Context) -> NotebookEditorViewController {
        // Creates the controller once for the lifetime of the SwiftUI view.
        NotebookEditorViewController(documentHandle: documentHandle)
    }

    func updateUIViewController(_ uiViewController: NotebookEditorViewController, context: Context) {
        // Skips streaming state updates into the controller.
        // Lets the controller own the editor lifecycle for the opened document.
    }
}