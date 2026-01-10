// Animated transition for folder overlay presentation and dismissal.
// Scales the overlay from/to the source folder card frame with smooth blur sync.

import UIKit

class FolderTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

  // Whether this is a presentation (true) or dismissal (false).
  let presenting: Bool

  // Source frame of the folder card in window coordinates.
  let sourceFrame: CGRect

  // Animation constants tuned for liquid glass effect.
  private let expandDuration: TimeInterval = 0.45
  private let expandDamping: CGFloat = 0.82
  private let contractDuration: TimeInterval = 0.25

  // Source corner radius (folder card).
  private let sourceCornerRadius: CGFloat = 10

  // Target corner radius (larger overlay).
  private let targetCornerRadius: CGFloat = 32

  init(presenting: Bool, sourceFrame: CGRect) {
    self.presenting = presenting
    self.sourceFrame = sourceFrame
    super.init()
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    presenting ? expandDuration : contractDuration
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    if presenting {
      animatePresentation(using: transitionContext)
    } else {
      animateDismissal(using: transitionContext)
    }
  }

  // MARK: - Presentation Animation

  private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning) {
    guard let toVC = transitionContext.viewController(forKey: .to) as? FolderOverlayViewController,
          let toView = transitionContext.view(forKey: .to) else {
      transitionContext.completeTransition(false)
      return
    }

    let containerView = transitionContext.containerView
    let finalFrame = transitionContext.finalFrame(for: toVC)

    // Add the view to the container.
    toView.frame = finalFrame
    containerView.addSubview(toView)

    // Force layout to get the container frame.
    toView.layoutIfNeeded()

    // Get the container view that will animate.
    let animatingView = toVC.containerViewForTransition
    let expandedFrame = animatingView.frame

    // Calculate scale factors to match source frame.
    let scaleX = sourceFrame.width / expandedFrame.width
    let scaleY = sourceFrame.height / expandedFrame.height

    // Calculate initial center position (source frame center).
    let initialCenter = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)

    // Save final center.
    let finalCenter = animatingView.center

    // Set initial state: scaled down at source position with slight transparency.
    animatingView.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    animatingView.center = initialCenter
    animatingView.alpha = 0
    animatingView.layer.cornerRadius = sourceCornerRadius

    // Animate to expanded state with spring for liquid feel.
    UIView.animate(
      withDuration: expandDuration,
      delay: 0,
      usingSpringWithDamping: expandDamping,
      initialSpringVelocity: 0.3,
      options: [.curveEaseOut]
    ) {
      animatingView.transform = .identity
      animatingView.center = finalCenter
      animatingView.layer.cornerRadius = self.targetCornerRadius
    }

    // Quick fade-in synced with scale for glass material reveal.
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
      animatingView.alpha = 1
    } completion: { _ in
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
  }

  // MARK: - Dismissal Animation

  private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning) {
    guard let fromVC = transitionContext.viewController(forKey: .from) as? FolderOverlayViewController,
          let fromView = transitionContext.view(forKey: .from) else {
      transitionContext.completeTransition(false)
      return
    }

    // Get the container view that will animate.
    let animatingView = fromVC.containerViewForTransition
    let currentFrame = animatingView.frame

    // Calculate scale factors to match source frame.
    let scaleX = sourceFrame.width / currentFrame.width
    let scaleY = sourceFrame.height / currentFrame.height

    // Target center (source frame center).
    let targetCenter = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)

    // Animate to collapsed state with smooth ease-in-out.
    UIView.animate(
      withDuration: contractDuration,
      delay: 0,
      options: [.curveEaseInOut]
    ) {
      animatingView.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
      animatingView.center = targetCenter
      animatingView.layer.cornerRadius = self.sourceCornerRadius
    }

    // Fade-out timed to complete just before scale animation.
    UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
      animatingView.alpha = 0
    } completion: { _ in
      fromView.removeFromSuperview()
      transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
  }
}
