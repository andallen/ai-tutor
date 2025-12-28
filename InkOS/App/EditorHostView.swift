import SwiftUI
import UIKit

struct EditorHostView: UIViewControllerRepresentable {
  let documentHandle: DocumentHandle

  func makeUIViewController(context: Context) -> UIViewController {
    // Creates the EditorViewController programmatically.
    let editorViewController = EditorViewController()
    editorViewController.configure(documentHandle: documentHandle)

    // Wraps it in a navigation controller for navigation bar support.
    let navigationController = UINavigationController(rootViewController: editorViewController)
    return navigationController
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
