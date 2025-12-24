import SwiftUI

// Acts as the SwiftUI entry point for the notebook screen.
struct NotebookView: View {
  // Holds the title and identity for the selected notebook.
  let model: NotebookModel

  // Provides access to the MyScript package backing the notebook.
  let documentHandle: DocumentHandle

  // Handles manual back navigation when the system gesture is disabled.
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    // Hosts a UIKit editor controller inside SwiftUI.
    NotebookEditorHost(documentHandle: documentHandle)
      // Sets the navigation title for the screen.
      .navigationTitle(model.displayName)
      // Keeps the title compact for a writing surface.
      .navigationBarTitleDisplayMode(.inline)
      // Disable the system back button (this also disables the swipe-back gesture).
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            dismiss()
          } label: {
            HStack(spacing: 5) {
              Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
              Text("Back")
                .font(.system(size: 17))
            }
          }
        }
      }
  }
}
