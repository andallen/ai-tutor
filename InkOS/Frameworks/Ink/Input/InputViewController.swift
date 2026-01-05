// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

/// The InputViewController/ViewModel role is to instantiate all the properties and classes used to display the
/// content of a page. It creates "key" objects like the editor and renderer, and displays the
/// DisplayViewController, the InputView and the SmartGuide (if enabled).

class InputViewController: UIViewController {

  // MARK: - Properties

  private var panGestureRecognizer: UIPanGestureRecognizer?
  // Pinch gesture for zooming in and out.
  private var pinchGestureRecognizer: UIPinchGestureRecognizer?
  // Detects touch-down to stop inertial scrolling immediately.
  private var touchDownGestureRecognizer: UILongPressGestureRecognizer?
  private var viewModel: InputViewModel
  private var containerView: UIView = UIView(frame: CGRect.zero)
  private var cancellables: Set<AnyCancellable> = []

  // MARK: - Life cycle

  init(viewModel: InputViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    self.view = UIView(frame: CGRect.zero)
    self.configureContainerView()
    self.panGestureRecognizer = UIPanGestureRecognizer(
      target: self, action: #selector(panGestureRecognizerAction(panGestureRecognizer:)))
    if let panGestureRecognizer = self.panGestureRecognizer {
      panGestureRecognizer.delegate = self
      panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    }
    // Create pinch gesture for zooming.
    self.pinchGestureRecognizer = UIPinchGestureRecognizer(
      target: self, action: #selector(pinchGestureRecognizerAction(pinchGestureRecognizer:)))
    if let pinchGestureRecognizer = self.pinchGestureRecognizer {
      pinchGestureRecognizer.delegate = self
    }
    let touchDownGestureRecognizer = UILongPressGestureRecognizer(
      target: self, action: #selector(touchDownGestureRecognizerAction(_:)))
    touchDownGestureRecognizer.minimumPressDuration = 0
    touchDownGestureRecognizer.cancelsTouchesInView = false
    touchDownGestureRecognizer.delegate = self
    touchDownGestureRecognizer.allowedTouchTypes = [
      NSNumber(value: UITouch.TouchType.direct.rawValue)
    ]
    self.touchDownGestureRecognizer = touchDownGestureRecognizer
    self.bindViewModel()
    self.viewModel.setupModel(
      panGesture: panGestureRecognizer,
      pinchGesture: pinchGestureRecognizer)
    self.viewModel.configureEditorUI(with: self.view.bounds.size)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.viewModel.setEditorViewSize(size: self.view.bounds.size)
  }

  func updateInputMode(newInputMode: InputMode) {
    self.viewModel.updateInputMode(newInputMode: newInputMode)
  }

  func activateGestureRecognizer(enabled: Bool) {
    self.panGestureRecognizer?.isEnabled = enabled
  }

  // Disables scroll and zoom gestures.
  // Use this when the parent view handles scrolling (e.g., UIScrollView in PDF mode).
  // Ink input remains active; only viewport manipulation gestures are disabled.
  func disableScrollAndZoomGestures() {
    self.panGestureRecognizer?.isEnabled = false
    self.pinchGestureRecognizer?.isEnabled = false
  }

  // Sets the editor tool to pen mode.
  func selectPenTool() {
    viewModel.selectPenTool()
  }

  // Sets the editor tool to eraser mode.
  func selectEraserTool() {
    viewModel.selectEraserTool()
  }

  // Sets the editor tool to highlighter mode.
  func selectHighlighterTool() {
    viewModel.selectHighlighterTool()
  }

  // MARK: - UI settings

  private func configureContainerView() {
    self.view.addSubview(self.containerView)
    self.containerView.translatesAutoresizingMaskIntoConstraints = false
    // Use clear background so PDF content shows through when used as overlay.
    self.containerView.backgroundColor = UIColor.clear
    self.containerView.isOpaque = false
  }

  private func inject(viewController: UIViewController, in container: UIView) {
    self.addChild(viewController)
    container.addSubview(viewController.view)
    viewController.view.translatesAutoresizingMaskIntoConstraints = false
    viewController.didMove(toParent: self)
  }

  internal override func updateViewConstraints() {
    self.viewModel.initModelViewConstraints(view: self.view, containerView: self.containerView)
    super.updateViewConstraints()
  }

  // Captures the current display container as a preview image.
  // Uses layer.render() instead of drawHierarchy() because the RenderView
  // uses drawsAsynchronously=true which can cause drawHierarchy to capture
  // empty/black content on iPad.
  func capturePreviewImage(maxPixelDimension: CGFloat) -> UIImage? {
    let bounds = containerView.bounds
    guard bounds.width > 0, bounds.height > 0 else {
      return nil
    }
    guard maxPixelDimension > 0 else {
      return nil
    }
    containerView.layoutIfNeeded()
    let maxDimension = max(bounds.width, bounds.height)
    guard maxDimension > 0 else {
      return nil
    }
    let scale = min(UIScreen.main.scale, maxPixelDimension / maxDimension)
    guard scale > 0 else {
      return nil
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
    let image = renderer.image { context in
      UIColor.white.setFill()
      context.fill(bounds)
      // Use layer.render() for synchronous capture of async-drawn layers.
      containerView.layer.render(in: context.cgContext)
    }
    return image
  }

  // MARK: - Data Binding

  private func bindViewModel() {
    self.viewModel.$neboInputView.sink { [weak self] inputView in
      if let inputView = inputView, let self = self {
        self.view.addSubview(inputView)
        inputView.translatesAutoresizingMaskIntoConstraints = false
        inputView.backgroundColor = UIColor.clear
        if let touchDownGestureRecognizer = self.touchDownGestureRecognizer {
          let alreadyContains =
            inputView.gestureRecognizers?.contains(touchDownGestureRecognizer) ?? false
          if !alreadyContains {
            inputView.addGestureRecognizer(touchDownGestureRecognizer)
          }
        }
      }
    }.store(in: &cancellables)
    self.viewModel.$displayViewController.sink { [weak self] displayViewController in
      if let displayViewController = displayViewController, let self = self {
        self.inject(viewController: displayViewController, in: self.containerView)
      }
    }.store(in: &cancellables)
    self.viewModel.$smartGuideViewController.sink { [weak self] smartGuideViewController in
      if let smartGuideViewController = smartGuideViewController, let self = self {
        self.inject(viewController: smartGuideViewController, in: self.view)
      }
    }.store(in: &cancellables)
    self.viewModel.$inputMode.sink { [weak self] inputMode in
      if let panGestureRecognizer = self?.panGestureRecognizer {
        switch inputMode {
        case .forcePen:
          panGestureRecognizer.isEnabled = false
        case .forceTouch:
          panGestureRecognizer.isEnabled = true
          panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.stylus.rawValue)
          ]
        case .auto:
          panGestureRecognizer.isEnabled = true
          panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue)
          ]
        }
      }
    }.store(in: &cancellables)
  }
}

// MARK: - Pan Gesture

extension InputViewController: UIGestureRecognizerDelegate {

  @objc private func panGestureRecognizerAction(panGestureRecognizer: UIPanGestureRecognizer) {
    guard let state = self.panGestureRecognizer?.state else { return }
    let translation: CGPoint = panGestureRecognizer.translation(in: self.view)
    let velocity: CGPoint = panGestureRecognizer.velocity(in: self.view)
    self.viewModel.handlePanGestureRecognizerAction(
      with: translation, velocity: velocity, state: state)
  }

  // Handles pinch gesture for zooming in and out.
  @objc private func pinchGestureRecognizerAction(
    pinchGestureRecognizer: UIPinchGestureRecognizer
  ) {
    guard let state = self.pinchGestureRecognizer?.state else {
      return
    }
    let scale = pinchGestureRecognizer.scale
    let center = pinchGestureRecognizer.location(in: self.view)
    self.viewModel.handlePinchGestureRecognizerAction(
      scale: scale, center: center, state: state)
    // Reset scale to 1.0 for incremental updates on each gesture change.
    pinchGestureRecognizer.scale = 1.0
  }

  @objc private func touchDownGestureRecognizerAction(
    _ gestureRecognizer: UILongPressGestureRecognizer
  ) {
    guard gestureRecognizer.state == .began else {
      return
    }
    self.viewModel.stopInertialScroll()
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    // Pinch gesture for zooming should always be allowed regardless of input mode.
    if gestureRecognizer is UIPinchGestureRecognizer {
      return true
    }
    // Pan gesture only begins when not in forcePen mode and scrolling is allowed.
    let shouldBegin =
      self.viewModel.inputMode != .forcePen && self.viewModel.editor?.isScrollAllowed ?? false
    return shouldBegin
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    // Prevent pan and pinch from firing simultaneously to avoid conflicting
    // viewport transformations. Pan modifies offset while pinch zooms around
    // a center point, causing drift when both fire together.
    let isPan =
      gestureRecognizer is UIPanGestureRecognizer
      || otherGestureRecognizer is UIPanGestureRecognizer
    let isPinch =
      gestureRecognizer is UIPinchGestureRecognizer
      || otherGestureRecognizer is UIPinchGestureRecognizer
    if isPan && isPinch {
      return false
    }
    return true
  }
}
