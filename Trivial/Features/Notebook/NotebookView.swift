import Combine
import SwiftUI

// Displays a single Notebook and provides the ink editing experience.
// Handles drawing, scrolling, zooming, and rendering ink on screen.
struct NotebookView: View {
  // The in-memory representation of the Notebook metadata.
  let model: NotebookModel

  // The handle for safe file operations on the notebook package.
  let documentHandle: DocumentHandle

  // Worker that manages the MyScript editor logic.
  @StateObject private var editorWorker = EditorWorker()

  init(model: NotebookModel, documentHandle: DocumentHandle) {
    self.model = model
    self.documentHandle = documentHandle
  }

  var body: some View {
    ZStack {
      BackgroundWhite()
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Header with title and clear button.
        HStack {
          Spacer()
          Text(model.displayName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.ink)
          Spacer()

          // Clear button for testing purposes.
          Button("Clear") {
            editorWorker.clear()
          }
          .padding(.trailing)
        }
        .padding(.top, 10)
        .padding(.bottom, 10)

        // The MyScript editor canvas.
        EditorViewControllerRepresentable(
          editorWorker: editorWorker
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .fontDesign(.rounded)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      // Load the content part when the view appears.
      Task {
        await editorWorker.loadPart(from: documentHandle)
      }
    }
    .onDisappear {
      // Unload content when the view disappears.
      editorWorker.close()
    }
  }
}
