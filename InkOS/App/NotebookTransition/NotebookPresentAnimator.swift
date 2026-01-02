import UIKit

// Handles the presentation animation for the notebook hero transition.
// Morphs a snapshot from the source card position to full screen while
// animating UI elements into place with a staggered timing.
class NotebookPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {

  // MARK: - Properties

  // The source card's frame in window coordinates.
  private let sourceFrame: CGRect

  // The preview image to display during the morph animation.
  private let previewImage: UIImage?

  // Corner radius of the source card.
  private let sourceCornerRadius: CGFloat = 10

  // MARK: - Initialization

  init(sourceFrame: CGRect, previewImage: UIImage?) {
    self.sourceFrame = sourceFrame
    self.previewImage = previewImage
    super.init()
  }

  // MARK: - UIViewControllerAnimatedTransitioning

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.42
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let toViewController = transitionContext.viewController(forKey: .to),
          let toView = transitionContext.view(forKey: .to) else {
      transitionContext.completeTransition(false)
      return
    }

    let containerView = transitionContext.containerView
    let finalFrame = transitionContext.finalFrame(for: toViewController)
    let duration = transitionDuration(using: transitionContext)

    // Ensure containerView has white background to prevent black flash.
    containerView.backgroundColor = .white

    // Get the editor and hide its UI elements before adding to hierarchy.
    let editorNavController = toViewController as? EditorNavigationController
    let editorVC = editorNavController?.viewControllers.first as? EditorViewController

    // Add toView to container but keep hidden during the morph phase.
    // The snapshot starts at card size and doesn't cover the fullscreen toView,
    // so toView must remain invisible until the snapshot has expanded.
    toView.frame = finalFrame
    toView.alpha = 0
    // Ensure all layers have white backgrounds to prevent black flash.
    toView.backgroundColor = .white
    editorNavController?.view.backgroundColor = .white
    editorVC?.view.backgroundColor = .white
    containerView.addSubview(toView)

    // Hide UI elements using transforms (not alpha) so they can animate in visibly.
    editorVC?.hideAllUIForTransition()

    // Hide the dashboard immediately with alpha = 0.
    let fromView = transitionContext.view(forKey: .from)
    fromView?.alpha = 0

    // Create the snapshot view that will morph from card to fullscreen.
    // Place it on top of toView to cover the editor during the morph.
    // Convert sourceFrame from global (window) coordinates to containerView's coordinate space.
    let snapshotView = createSnapshotView()
    snapshotView.frame = containerView.convert(sourceFrame, from: nil)
    containerView.addSubview(snapshotView)

    // Animate the snapshot morphing to fullscreen.
    UIView.animate(
      withDuration: duration * 0.83,
      delay: 0,
      usingSpringWithDamping: 0.86,
      initialSpringVelocity: 0,
      options: [.curveEaseOut]
    ) {
      snapshotView.frame = finalFrame
      snapshotView.layer.cornerRadius = 0
    }

    // Reveal toView once the snapshot has expanded enough to cover the screen.
    DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.45) {
      toView.alpha = 1
    }

    // Fade out the snapshot earlier so UI element slides are visible.
    UIView.animate(
      withDuration: duration * 0.4,
      delay: duration * 0.5,
      options: [.curveEaseOut]
    ) {
      snapshotView.alpha = 0
    }

    // Animate UI elements in with staggered timing.
    // These start as the snapshot fades so the user sees the slide motion.
    // Navigation bar slides down from top.
    UIView.animate(
      withDuration: duration * 0.45,
      delay: duration * 0.5,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      editorVC?.setNavigationBarVisible(true, animated: false)
    }

    // Tool palette slides up from bottom.
    UIView.animate(
      withDuration: duration * 0.45,
      delay: duration * 0.55,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      editorVC?.setToolPaletteVisible(true, animated: false)
    }

    // Editing toolbar slides up from bottom.
    UIView.animate(
      withDuration: duration * 0.4,
      delay: duration * 0.6,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      editorVC?.setEditingToolbarVisible(true, animated: false)
    }

    // Complete the transition after all animations finish.
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      // Clean up transition views.
      snapshotView.removeFromSuperview()

      // Ensure all UI elements are visible.
      editorVC?.showAllUIAfterTransition(animated: false)

      // Restore fromView alpha before completing so it's ready for dismiss.
      // The opaque white toView background should prevent any flash.
      fromView?.alpha = 1

      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
  }

  // MARK: - Helpers

  // Creates the snapshot view used during the morph animation.
  private func createSnapshotView() -> UIView {
    let snapshotView = UIView()
    snapshotView.backgroundColor = .white
    snapshotView.clipsToBounds = true
    snapshotView.layer.cornerRadius = sourceCornerRadius

    // Add the preview image if available.
    if let previewImage = previewImage {
      let imageView = UIImageView(image: previewImage)
      imageView.contentMode = .scaleAspectFill
      imageView.clipsToBounds = true
      imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      imageView.frame = snapshotView.bounds
      snapshotView.addSubview(imageView)
    }

    // Add a subtle shadow.
    snapshotView.layer.shadowColor = UIColor.black.cgColor
    snapshotView.layer.shadowOpacity = 0.2
    snapshotView.layer.shadowRadius = 12
    snapshotView.layer.shadowOffset = CGSize(width: 0, height: 6)

    return snapshotView
  }
}
