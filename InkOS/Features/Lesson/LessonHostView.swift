// SwiftUI wrapper for LessonViewController.
// Bridges the UIKit lesson viewer into SwiftUI's view hierarchy.

import SwiftUI
import UIKit

struct LessonHostView: UIViewControllerRepresentable {
  let lessonID: String
  // Callback invoked when the lesson requests dismissal (e.g., home button tapped).
  var onDismiss: (() -> Void)?

  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }

  func makeUIViewController(context: Context) -> UIViewController {
    // Creates the LessonViewController programmatically.
    let lessonViewController = LessonViewController(lessonID: lessonID)
    // Pass the dismiss handler so the lesson can notify SwiftUI.
    lessonViewController.dismissHandler = context.coordinator.onDismiss

    // Wraps it in a navigation controller for navigation bar support.
    let navigationController = UINavigationController(rootViewController: lessonViewController)
    return navigationController
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    // Update the dismiss handler if it changes.
    if let navController = uiViewController as? UINavigationController,
       let lesson = navController.viewControllers.first as? LessonViewController {
      lesson.dismissHandler = context.coordinator.onDismiss
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
