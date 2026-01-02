import UIKit

// Coordinates the custom hero transition between the dashboard and the editor.
// Manages the presentation and dismissal of the editor with animated transitions.
class NotebookTransitionCoordinator: NSObject {

  // MARK: - Properties

  // The source card's frame in the window's coordinate space.
  var sourceFrame: CGRect = .zero

  // The preview image to display during the transition.
  var previewImage: UIImage?

  // The document handle for the notebook being opened.
  var documentHandle: DocumentHandle?

  // Callback invoked when the editor is dismissed.
  // Passes the updated preview image if available.
  var onDismiss: ((UIImage?) -> Void)?

  // Closure that returns the card's current frame at dismiss time.
  // Allows querying the up-to-date position after the card may have moved.
  var frameProvider: (() -> CGRect?)?

  // The navigation controller being presented.
  private weak var presentedNavigationController: EditorNavigationController?

  // The view controller that presented the editor.
  private weak var presentingViewController: UIViewController?

  // Preview image captured at dismiss time. Stored so the animator can use the
  // same image that was passed to onDismiss, ensuring visual continuity.
  private var dismissPreviewImage: UIImage?

  // MARK: - Presentation

  // Presents the editor from the given source view controller with a custom hero transition.
  func present(from sourceViewController: UIViewController) {
    guard let documentHandle = documentHandle else {
      return
    }

    // Create the editor view controller.
    let editorViewController = EditorViewController()
    editorViewController.configure(documentHandle: documentHandle)

    // Wrap in custom navigation controller.
    let navigationController = EditorNavigationController(rootViewController: editorViewController)
    navigationController.notebookTransitionCoordinator = self
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.transitioningDelegate = self

    // Store references for later dismissal.
    presentedNavigationController = navigationController
    presentingViewController = sourceViewController

    // Present with custom transition.
    sourceViewController.present(navigationController, animated: true)
  }

  // MARK: - Dismissal

  // Dismisses the editor with a custom hero transition back to the source card.
  func dismiss() {
    guard let navigationController = presentedNavigationController else {
      return
    }

    // Capture the preview image from the editor.
    if let editorVC = navigationController.viewControllers.first as? EditorViewController {
      dismissPreviewImage = editorVC.capturePreviewImage(maxPixelDimension: 1200)
    }

    // Update the card's preview BEFORE starting the animation.
    // This ensures the card shows the same image as the animating snapshot,
    // so when the snapshot lands and fades out, there's no visual discontinuity.
    onDismiss?(dismissPreviewImage)

    // Wait for SwiftUI to re-render the card with the new preview,
    // then start the dismiss animation.
    DispatchQueue.main.async { [weak self] in
      navigationController.dismiss(animated: true) {
        self?.cleanup()
      }
    }
  }

  // Clears references after dismissal completes.
  private func cleanup() {
    presentedNavigationController = nil
    presentingViewController = nil
    dismissPreviewImage = nil
  }
}

// MARK: - UIViewControllerTransitioningDelegate

extension NotebookTransitionCoordinator: UIViewControllerTransitioningDelegate {

  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return NotebookPresentAnimator(sourceFrame: sourceFrame, previewImage: previewImage)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    // Query the card's current frame (it may have moved since opening).
    // Fallback to the stored sourceFrame if frameProvider returns nil.
    let fullFrame = frameProvider?() ?? sourceFrame

    // Adjust to exclude the title area below the card (36pt).
    // The snapshot represents only the card portion, not the title.
    let targetFrame = CGRect(
      x: fullFrame.minX,
      y: fullFrame.minY,
      width: fullFrame.width,
      height: fullFrame.height - 36
    )

    // Use the preview captured in dismiss(). This is the same image passed to
    // onDismiss, so the card underneath shows the same image as the snapshot.
    return NotebookDismissAnimator(targetFrame: targetFrame, previewImage: dismissPreviewImage)
  }
}
