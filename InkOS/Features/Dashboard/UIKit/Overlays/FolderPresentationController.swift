// Custom presentation controller for folder overlay.
// Manages the animated blur background synced with overlay expand/contract.

import UIKit

class FolderPresentationController: UIPresentationController {

  // Blur background view with animated intensity.
  private let blurView = UIVisualEffectView(effect: nil)

  // Animator for smooth blur transitions.
  private var blurAnimator: UIViewPropertyAnimator?

  // Display link for smooth blur interpolation.
  private var displayLink: CADisplayLink?
  private var currentBlurFraction: CGFloat = 0
  private var targetBlurFraction: CGFloat = 0
  private var animationStartTime: CFTimeInterval = 0
  private var animationStartFraction: CGFloat = 0
  private var animationDuration: TimeInterval = 0.45

  // Maximum blur intensity (0.0 to 1.0).
  private let maxBlurIntensity: CGFloat = 0.85

  override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
    super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    setupBlurView()
  }

  private func setupBlurView() {
    blurView.effect = nil

    // Create animator that applies blur when fractionComplete increases.
    let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
      self?.blurView.effect = UIBlurEffect(style: .systemThinMaterial)
    }
    animator.pausesOnCompletion = true
    animator.fractionComplete = 0
    blurAnimator = animator
  }

  // MARK: - Presentation

  override func presentationTransitionWillBegin() {
    guard let containerView else { return }

    blurView.frame = containerView.bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    containerView.insertSubview(blurView, at: 0)

    // Animate blur in sync with overlay expansion.
    animateTo(fraction: maxBlurIntensity, duration: 0.45)
  }

  override func dismissalTransitionWillBegin() {
    // Clear blur as overlay contracts.
    animateTo(fraction: 0.0, duration: 0.25)
  }

  override func dismissalTransitionDidEnd(_ completed: Bool) {
    if completed {
      blurView.removeFromSuperview()
      displayLink?.invalidate()
      displayLink = nil
      blurAnimator?.stopAnimation(true)
    }
  }

  // MARK: - Layout

  override var frameOfPresentedViewInContainerView: CGRect {
    containerView?.bounds ?? .zero
  }

  override func containerViewDidLayoutSubviews() {
    super.containerViewDidLayoutSubviews()
    presentedView?.frame = frameOfPresentedViewInContainerView
    blurView.frame = containerView?.bounds ?? .zero
  }

  // MARK: - Blur Animation

  // Animates blur fraction from current value to target using CADisplayLink.
  // Uses ease-out cubic for smooth deceleration.
  private func animateTo(fraction target: CGFloat, duration: TimeInterval) {
    targetBlurFraction = target
    animationStartFraction = currentBlurFraction
    animationDuration = duration
    animationStartTime = CACurrentMediaTime()

    // Cancel existing display link.
    displayLink?.invalidate()

    // Create new display link for animation.
    let link = CADisplayLink(target: self, selector: #selector(updateBlurAnimation))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @objc private func updateBlurAnimation() {
    let elapsed = CACurrentMediaTime() - animationStartTime
    var progress = min(1.0, elapsed / animationDuration)

    // Apply ease-out cubic for smooth deceleration.
    progress = easeOutCubic(progress)

    // Interpolate between start and target.
    let newFraction = animationStartFraction + (targetBlurFraction - animationStartFraction) * progress
    currentBlurFraction = newFraction
    blurAnimator?.fractionComplete = newFraction

    // Stop animation when complete.
    if progress >= 1.0 {
      displayLink?.invalidate()
      displayLink = nil
    }
  }

  // Ease out cubic for smooth deceleration.
  private func easeOutCubic(_ t: CGFloat) -> CGFloat {
    let adjusted = t - 1
    return adjusted * adjusted * adjusted + 1
  }

  deinit {
    displayLink?.invalidate()
    blurAnimator?.stopAnimation(true)
  }
}
