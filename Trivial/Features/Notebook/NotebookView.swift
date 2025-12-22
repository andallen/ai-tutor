import SwiftUI

// Acts as the SwiftUI entry point for the notebook screen.
struct NotebookView: View {
    // Holds the title and identity for the selected notebook.
    let model: NotebookModel

    // Provides access to the MyScript package backing the notebook.
    let documentHandle: DocumentHandle

    var body: some View {
        // Hosts a UIKit editor controller inside SwiftUI.
        NotebookEditorHost(documentHandle: documentHandle)
            // Sets the navigation title for the screen.
            .navigationTitle(model.name)
            // Keeps the title compact for a writing surface.
            .navigationBarTitleDisplayMode(.inline)
    }
}