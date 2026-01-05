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

  // Inset to crop out the thin black line on the right edge of the canvas capture.
  // Must match NotebookDismissAnimator.previewEdgeInset for consistency.
  private let previewEdgeInset: CGFloat = 2

  // MARK: - Initialization

  init(sourceFrame: CGRect, previewImage: UIImage?) {
    self.sourceFrame = sourceFrame
    self.previewImage = previewImage
    super.init()
  }

  // MARK: - UIViewControllerAnimatedTransitioning

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?)
    -> TimeInterval {
    return 0.42
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let toViewController = transitionContext.viewController(forKey: .to),
      let toView = transitionContext.view(forKey: .to)
    else {
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

    // Prepare and add the destination view to the container.
    configureDestinationView(
      toView: toView,
      finalFrame: finalFrame,
      editorNavController: editorNavController,
      editorVC: editorVC,
      containerView: containerView
    )

    // Keep the source dashboard visible but add a blur overlay that intensifies.
    let fromView = transitionContext.view(forKey: .from)

    // Create blur overlay for the dashboard background.
    let blurComponents = createBlurOverlay(frame: containerView.bounds)
    if let fromView = fromView {
      containerView.insertSubview(blurComponents.overlay, aboveSubview: fromView)
    }

    // Create and configure the morphing snapshot.
    let snapshotView = createSnapshotView()
    configureSnapshotView(snapshotView, containerView: containerView)
    containerView.addSubview(snapshotView)

    // Perform all animations.
    animateSnapshotMorph(snapshotView: snapshotView, finalFrame: finalFrame, duration: duration)
    animateBlurIn(animator: blurComponents.animator, duration: duration)
    animateDestinationReveal(toView: toView, duration: duration)
    animateSnapshotFadeOut(snapshotView: snapshotView, duration: duration)
    animateUIElementsIn(editorVC: editorVC, duration: duration)

    // Complete the transition after all animations finish.
    let components = TransitionComponents(
      snapshotView: snapshotView,
      blurOverlay: blurComponents.overlay,
      blurAnimator: blurComponents.animator,
      fromView: fromView,
      editorVC: editorVC
    )
    completeTransition(
      after: duration,
      components: components,
      transitionContext: transitionContext
    )
  }

  // MARK: - Helpers

  // Configures the destination view and adds it to the container.
  private func configureDestinationView(
    toView: UIView,
    finalFrame: CGRect,
    editorNavController: EditorNavigationController?,
    editorVC: EditorViewController?,
    containerView: UIView
  ) {
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
  }

  // Configures the snapshot view frame and subview insets.
  private func configureSnapshotView(_ snapshotView: UIView, containerView: UIView) {
    // Convert sourceFrame from global (window) coordinates to containerView's coordinate space.
    snapshotView.frame = containerView.convert(sourceFrame, from: nil)

    // Extend the image view beyond the right edge to crop out the black line.
    // Must be set after the snapshot frame so bounds is correct.
    for subview in snapshotView.subviews {
      subview.frame = snapshotView.bounds.inset(
        by: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -previewEdgeInset)
      )
    }
  }

  // Animates the snapshot morphing from card size to fullscreen.
  private func animateSnapshotMorph(
    snapshotView: UIView, finalFrame: CGRect, duration: TimeInterval
  ) {
    UIView.animate(
      withDuration: duration * 0.83,
      delay: 0,
      usingSpringWithDamping: 0.86,
      initialSpringVelocity: 0,
      options: [.curveEaseOut]
    ) { [previewEdgeInset] in
      snapshotView.frame = finalFrame
      snapshotView.layer.cornerRadius = 0

      // Manually resize all subviews to maintain the right edge inset.
      // autoresizingMask doesn't maintain the extended frame correctly.
      for subview in snapshotView.subviews {
        subview.frame = snapshotView.bounds.inset(
          by: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -previewEdgeInset)
        )
      }
    }
  }

  // Creates a blur overlay with an animator for controlling blur intensity.
  // Returns the overlay view and animator as a tuple.
  private func createBlurOverlay(frame: CGRect) -> (
    overlay: UIVisualEffectView, animator: UIViewPropertyAnimator
  ) {
    // Create a visual effect view without an effect initially.
    let blurView = UIVisualEffectView(effect: nil)
    blurView.frame = frame
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // Create an animator that will apply blur when its fractionComplete increases.
    let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
      blurView.effect = UIBlurEffect(style: .regular)
    }
    // Pause the animator so fractionComplete can be set manually.
    animator.pausesOnCompletion = true

    return (blurView, animator)
  }

  // Animates the blur overlay from clear to blurred.
  private func animateBlurIn(animator: UIViewPropertyAnimator, duration: TimeInterval) {
    // Animate the blur fraction from 0 to 1 over most of the transition.
    let blurDuration = duration * 0.7
    let startTime = CACurrentMediaTime()

    // Use a display link for smooth blur animation.
    let displayLink = CADisplayLink(
      target: BlurAnimationHelper(
        animator: animator,
        startTime: startTime,
        duration: blurDuration,
        fromValue: 0,
        toValue: 1
      ), selector: #selector(BlurAnimationHelper.update))
    displayLink.add(to: .main, forMode: .common)
  }

  // Reveals the destination view once the snapshot has expanded.
  private func animateDestinationReveal(toView: UIView, duration: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.45) {
      toView.alpha = 1
    }
  }

  // Fades out the snapshot to reveal the editor UI.
  private func animateSnapshotFadeOut(snapshotView: UIView, duration: TimeInterval) {
    UIView.animate(
      withDuration: duration * 0.4,
      delay: duration * 0.5,
      options: [.curveEaseOut]
    ) {
      snapshotView.alpha = 0
    }
  }

  // Animates UI elements in with staggered timing.
  private func animateUIElementsIn(editorVC: EditorViewController?, duration: TimeInterval) {
    // Home button slides down from top.
    UIView.animate(
      withDuration: duration * 0.45,
      delay: duration * 0.5,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      editorVC?.setHomeButtonVisible(true, animated: false)
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

    // Editing toolbar slides down from top (now positioned at top right).
    UIView.animate(
      withDuration: duration * 0.4,
      delay: duration * 0.6,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      editorVC?.setEditingToolbarVisible(true, animated: false)
    }

    // AI button fades in.
    UIView.animate(
      withDuration: duration * 0.4,
      delay: duration * 0.55,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0,
      options: []
    ) {
      editorVC?.setAIButtonVisible(true, animated: false)
    }
  }

  // Groups all the views and components needed for transition cleanup.
  private struct TransitionComponents {
    let snapshotView: UIView
    let blurOverlay: UIVisualEffectView
    let blurAnimator: UIViewPropertyAnimator
    let fromView: UIView?
    let editorVC: EditorViewController?
  }

  // Completes the transition after all animations finish.
  private func completeTransition(
    after duration: TimeInterval,
    components: TransitionComponents,
    transitionContext: UIViewControllerContextTransitioning
  ) {
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      // Clean up transition views.
      components.snapshotView.removeFromSuperview()
      components.blurOverlay.removeFromSuperview()

      // Stop the blur animator and release resources.
      components.blurAnimator.stopAnimation(true)

      // Ensure all UI elements are visible.
      components.editorVC?.showAllUIAfterTransition(animated: false)

      // Restore fromView alpha before completing so it's ready for dismiss.
      // The opaque white toView background should prevent any flash.
      components.fromView?.alpha = 1

      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
  }

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

// MARK: - Blur Animation Helper

// Helper class that drives blur animation using CADisplayLink for smooth updates.
// Animates a UIViewPropertyAnimator's fractionComplete from one value to another.
class BlurAnimationHelper: NSObject {
  private weak var animator: UIViewPropertyAnimator?
  private let startTime: CFTimeInterval
  private let duration: TimeInterval
  private let fromValue: CGFloat
  private let toValue: CGFloat
  private var displayLink: CADisplayLink?

  init(
    animator: UIViewPropertyAnimator, startTime: CFTimeInterval, duration: TimeInterval,
    fromValue: CGFloat, toValue: CGFloat
  ) {
    self.animator = animator
    self.startTime = startTime
    self.duration = duration
    self.fromValue = fromValue
    self.toValue = toValue
    super.init()
  }

  // Called on each display refresh to update the blur fraction.
  @objc func update(displayLink: CADisplayLink) {
    self.displayLink = displayLink
    let elapsed = CACurrentMediaTime() - startTime
    let progress = min(max(elapsed / duration, 0), 1)

    // Apply easing for smoother feel.
    let easedProgress = easeOutCubic(progress)
    let currentValue = fromValue + (toValue - fromValue) * easedProgress

    animator?.fractionComplete = currentValue

    // Stop the display link when animation completes.
    if progress >= 1 {
      displayLink.invalidate()
    }
  }

  // Ease out cubic for a smooth deceleration.
  private func easeOutCubic(_ progress: CGFloat) -> CGFloat {
    let adjustedProgress = progress - 1
    return adjustedProgress * adjustedProgress * adjustedProgress + 1
  }
}
