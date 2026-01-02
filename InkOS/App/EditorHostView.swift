import SwiftUI
import UIKit

// SwiftUI wrapper for EditorViewController.
// Bridges the UIKit editor into SwiftUI's view hierarchy.
struct EditorHostView: UIViewControllerRepresentable {
  let documentHandle: DocumentHandle
  // Callback invoked when the editor requests dismissal (e.g., home button tapped).
  // When provided, this replaces the default dismiss behavior.
  var onDismiss: (() -> Void)?

  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }

  func makeUIViewController(context: Context) -> UIViewController {
    // Creates the EditorViewController programmatically.
    let editorViewController = EditorViewController()
    editorViewController.configure(documentHandle: documentHandle)
    // Pass the dismiss handler so the editor can notify SwiftUI.
    editorViewController.dismissHandler = context.coordinator.onDismiss

    // Wraps it in a navigation controller for navigation bar support.
    let navigationController = UINavigationController(rootViewController: editorViewController)
    return navigationController
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    // Update the dismiss handler if it changes.
    if let navController = uiViewController as? UINavigationController,
       let editor = navController.viewControllers.first as? EditorViewController {
      editor.dismissHandler = context.coordinator.onDismiss
    }
  }

  // Coordinator holds the dismiss callback to avoid capturing self in closures.
  class Coordinator {
    var onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)?) {
      self.onDismiss = onDismiss
    }
  }
}
