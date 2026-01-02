import UIKit

// Handles the dismissal animation for the notebook hero transition.
// Morphs a snapshot from full screen back to the source card position.
class NotebookDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {

  // MARK: - Properties

  // The target card's frame in window coordinates.
  private let targetFrame: CGRect

  // The preview image to display during the morph animation.
  private let previewImage: UIImage?

  // Corner radius of the target card.
  private let targetCornerRadius: CGFloat = 10

  // MARK: - Initialization

  init(targetFrame: CGRect, previewImage: UIImage?) {
    self.targetFrame = targetFrame
    self.previewImage = previewImage
    super.init()
  }

  // MARK: - UIViewControllerAnimatedTransitioning

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.38
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let fromView = transitionContext.view(forKey: .from),
          let toView = transitionContext.view(forKey: .to) else {
      transitionContext.completeTransition(false)
      return
    }

    let containerView = transitionContext.containerView
    let finalFrame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)
    let duration = transitionDuration(using: transitionContext)

    // Ensure containerView has white background for consistency.
    containerView.backgroundColor = .white

    // Add toView behind the snapshot during morph.
    toView.frame = finalFrame
    containerView.insertSubview(toView, at: 0)

    // Hide fromView immediately so it's invisible during the transition.
    fromView.alpha = 0

    // Create the snapshot view that will morph from fullscreen to card.
    // Convert targetFrame from global (window) coordinates to containerView's coordinate space.
    let snapshotView = createSnapshotView()
    snapshotView.frame = containerView.bounds

    // Manually set subview frames since autoresizingMask doesn't apply when
    // manually setting frame (only during layout passes).
    for subview in snapshotView.subviews {
      subview.frame = snapshotView.bounds
    }

    containerView.addSubview(snapshotView)

    let convertedTargetFrame = containerView.convert(targetFrame, from: nil)

    // Animate the snapshot morphing back to the card position.
    UIView.animate(
      withDuration: duration,
      delay: 0,
      usingSpringWithDamping: 0.88,
      initialSpringVelocity: 0.1,
      options: [.curveEaseOut]
    ) {
      snapshotView.frame = convertedTargetFrame
      snapshotView.layer.cornerRadius = self.targetCornerRadius

      // Manually resize all subviews to match the animating snapshot frame.
      // autoresizingMask doesn't apply during manual frame animations.
      for subview in snapshotView.subviews {
        subview.frame = snapshotView.bounds
      }
    }

    // Complete the transition after animations finish.
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      // Clean up transition views.
      snapshotView.removeFromSuperview()

      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
  }

  // MARK: - Helpers

  // Creates the snapshot view used during the morph animation.
  private func createSnapshotView() -> UIView {
    let snapshotView = UIView()
    snapshotView.backgroundColor = .white
    snapshotView.clipsToBounds = true
    snapshotView.layer.cornerRadius = 0

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
    snapshotView.layer.shadowOpacity = 0.25
    snapshotView.layer.shadowRadius = 16
    snapshotView.layer.shadowOffset = CGSize(width: 0, height: 8)

    return snapshotView
  }
}
