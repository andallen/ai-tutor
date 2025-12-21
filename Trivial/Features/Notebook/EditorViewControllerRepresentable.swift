import SwiftUI
import UIKit

// SwiftUI wrapper for the UIKit EditorViewController.
// Provides a thin bridge between SwiftUI state and the UIKit controller.
struct EditorViewControllerRepresentable: UIViewControllerRepresentable {
  // The worker that manages the editor state.
  @ObservedObject var editorWorker: EditorWorker

  func makeUIViewController(context: Context) -> EditorViewController {
    let controller = EditorViewController(editorWorker: editorWorker)
    // Store the controller reference in the coordinator for future delegate hooks.
    context.coordinator.controller = controller
    return controller
  }

  func updateUIViewController(_ uiViewController: EditorViewController, context: Context) {
    // Update coordinator reference if the controller changed.
    if context.coordinator.controller !== uiViewController {
      context.coordinator.controller = uiViewController
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(editorWorker: editorWorker)
  }

  // Coordinator to handle events flowing back from the Editor to SwiftUI.
  class Coordinator {
    let editorWorker: EditorWorker
    weak var controller: EditorViewController?

    init(editorWorker: EditorWorker) {
      self.editorWorker = editorWorker
    }

    // Future: Add delegate methods here for content changed, undo/redo state, etc.
  }
}
