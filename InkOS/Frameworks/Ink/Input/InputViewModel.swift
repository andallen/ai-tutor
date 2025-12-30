// Copyright @ MyScript. All rights reserved.

// InputViewModel manages editor setup, gesture handling, inertial scrolling, and zoom logic.
// Splitting this into separate files would break cohesion of related gesture state management.

import Combine
import QuartzCore
import UIKit

protocol EditorDelegate: AnyObject {
  func didCreateEditor(editor: IINKEditor)
  func partChanged(editor: IINKEditor)
  func contentChanged(editor: IINKEditor, blockIds: [String])
  func onError(editor: IINKEditor, blockId: String, message: String)
}

private class EditorDelegateTrampoline: NSObject, IINKEditorDelegate {

  private weak var editorDelegate: EditorDelegate?

  init(editorDelegate: EditorDelegate?) {
    self.editorDelegate = editorDelegate
  }

  func partChanged(_ editor: IINKEditor) {
    self.editorDelegate?.partChanged(editor: editor)
  }

  func contentChanged(_ editor: IINKEditor, blockIds: [String]) {
    self.editorDelegate?.contentChanged(editor: editor, blockIds: blockIds)
  }

  func onError(_ editor: IINKEditor, blockId: String, message: String) {
    self.editorDelegate?.onError(editor: editor, blockId: blockId, message: message)
  }
}

// swiftlint:disable type_body_length
// InputViewModel manages editor setup, gesture handling, inertial scrolling, and zoom logic.
// Splitting this into separate classes would break cohesion of related gesture state management.
/// This class is the ViewModel of the InputViewController. It handles all its business logic.
class InputViewModel {

  // MARK: - Reactive Properties

  @Published var inputMode: InputMode = .forcePen
  @Published var displayViewController: DisplayViewController?
  @Published var smartGuideViewController: SmartGuideViewController?
  @Published var neboInputView: InputView?

  // MARK: - Properties

  // Uses protocol type to allow dependency injection for testing.
  var editor: (any EditorProtocol)?
  private weak var engine: IINKEngine?
  // Stores the tool controller so tools can be switched from the Notebook toolbar.
  // Uses protocol type to allow dependency injection for testing.
  private var toolController: (any ToolControllerProtocol)?
  private(set) var originalViewOffset: CGPoint = CGPoint.zero
  private weak var editorDelegate: EditorDelegate?
  private var editorDelegateTrampoline: EditorDelegateTrampoline
  private weak var smartGuideDelegate: SmartGuideViewControllerDelegate?
  private var smartGuideDisabled: Bool = false
  private var didSetConstraints: Bool = false
  // Tracks inertial scrolling so the canvas can glide after the finger lifts.
  private var decelerationLink: CADisplayLink?
  private var decelerationVelocityY: CGFloat = 0
  private var decelerationVelocityX: CGFloat = 0
  private var lastDecelerationTimestamp: CFTimeInterval?

  // Softens drag to feel closer to native scroll physics.
  private let dragResistance: CGFloat = 0.88
  // Filters out tiny lifts so motion only continues when the finger is still moving.
  private let velocityThreshold: CGFloat = 60

  // Zoom scale limits. Default view is 1.0, so minimum prevents zooming out beyond default.
  // Maximum of 4.0 allows significant zoom while maintaining performance.
  private let minZoomScale: Float = 1.0
  private let maxZoomScale: Float = 4.0

  init(
    engine: IINKEngine?,
    inputMode: InputMode,
    editorDelegate: EditorDelegate?,
    smartGuideDelegate: SmartGuideViewControllerDelegate?,
    smartGuideDisabled: Bool = false
  ) {
    self.engine = engine
    self.inputMode = inputMode
    self.editorDelegate = editorDelegate
    self.editorDelegateTrampoline = EditorDelegateTrampoline(editorDelegate: editorDelegate)
    self.smartGuideDelegate = smartGuideDelegate
  }

  func setupModel(
    panGesture: UIPanGestureRecognizer?,
    pinchGesture: UIPinchGestureRecognizer?
  ) {
    let displayViewModel = DisplayViewModel()
    self.initEditor(with: displayViewModel)
    self.displayViewController = DisplayViewController(viewModel: displayViewModel)
    if self.smartGuideDisabled == false {
      self.smartGuideViewController = SmartGuideViewController()
      // Cast to IINKEditor since SmartGuideViewController expects concrete SDK type.
      self.smartGuideViewController?.editor = self.editor as? IINKEditor
      self.smartGuideViewController?.delegate = self.smartGuideDelegate
    }
    self.neboInputView = InputView(frame: CGRect.zero)
    self.neboInputView?.inputMode = self.inputMode
    // Cast to IINKEditor since InputView expects concrete SDK type.
    self.neboInputView?.editor = self.editor as? IINKEditor
    if let panGesture = panGesture {
      self.neboInputView?.addGestureRecognizer(panGesture)
    }
    if let pinchGesture = pinchGesture {
      self.neboInputView?.addGestureRecognizer(pinchGesture)
    }
  }

  func updateInputMode(newInputMode: InputMode) {
    self.inputMode = newInputMode
    self.neboInputView?.inputMode = inputMode
  }

  func configureEditorUI(with viewSize: CGSize) {
    guard let editor = self.editor else {
      return
    }
    try? editor.setEditorViewSize(viewSize)
    let conf = editor.editorConfiguration
    let horizontalMarginMM: Double = 5
    let verticalMarginMM: Double = 15

    try? conf.setConfigNumber(verticalMarginMM, forKey: "text.margin.top")
    try? conf.setConfigNumber(horizontalMarginMM, forKey: "text.margin.left")
    try? conf.setConfigNumber(horizontalMarginMM, forKey: "text.margin.right")
    try? conf.setConfigNumber(verticalMarginMM, forKey: "math.margin.top")
    try? conf.setConfigNumber(verticalMarginMM, forKey: "math.margin.bottom")
    try? conf.setConfigNumber(horizontalMarginMM, forKey: "math.margin.left")
    try? conf.setConfigNumber(horizontalMarginMM, forKey: "math.margin.right")
  }

  func initModelViewConstraints(view: UIView, containerView: UIView) {
    guard self.didSetConstraints == false,
      let displayViewController = self.displayViewController,
      let displayViewControllerView = displayViewController.view,
      let inputView = self.neboInputView
    else {
      return
    }
    self.didSetConstraints = true
    let views: [String: Any] = [
      "containerView": containerView, "displayViewControllerView": displayViewControllerView,
      "inputView": inputView
    ]
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "H:|[containerView]|", options: .alignAllLeft, metrics: nil, views: views)
    )
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "V:|[containerView]|", options: .alignAllLeft, metrics: nil, views: views)
    )
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "H:|[inputView]|", options: .alignAllLeft, metrics: nil, views: views))
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "V:|[inputView]|", options: .alignAllLeft, metrics: nil, views: views))
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "H:|[displayViewControllerView]|", options: .alignAllLeft, metrics: nil,
        views: views))
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "V:|[displayViewControllerView]|", options: .alignAllLeft, metrics: nil,
        views: views))
  }

  func handlePanGestureRecognizerAction(
    with translation: CGPoint, velocity: CGPoint, state: UIGestureRecognizer.State
  ) {
    guard self.editor?.isScrollAllowed == true else {
      return
    }
    // Restart inertia when a new pan begins.
    if state == UIGestureRecognizer.State.began {
      stopDeceleration()
    }
    if state == UIGestureRecognizer.State.began {
      self.originalViewOffset = self.editor?.editorRenderer.viewOffset ?? CGPoint.zero
    }

    // Check if user is zoomed in to enable 360-degree panning.
    let currentScale = self.editor?.editorRenderer.viewScale ?? 1.0
    let isZoomedIn = currentScale > 1.0

    // Reduce translation to avoid 1:1 tracking and match iOS scrolling cadence.
    let adjustedTranslationY = translation.y * dragResistance
    let adjustedTranslationX = isZoomedIn ? translation.x * dragResistance : 0

    var proposedOffset = CGPoint(
      x: originalViewOffset.x - adjustedTranslationX,
      y: originalViewOffset.y - adjustedTranslationY)

    // Store desired X before SDK clamping since clampViewOffset may reset X to 0.
    let desiredXOffset = proposedOffset.x

    // Let SDK clamp vertical scrolling only.
    if var clampedOffset = Optional(proposedOffset) {
      self.editor?.clampEditorViewOffset(&clampedOffset)
      proposedOffset = clampedOffset
    }

    // Restore X and apply custom horizontal bounds.
    proposedOffset.x = desiredXOffset

    // Enforce horizontal bounds: left edge at 0, right edge at maxXOffset.
    if proposedOffset.x < 0 {
      proposedOffset.x = 0
    }
    let maxXOffset = calculateMaxXOffset()
    if proposedOffset.x > maxXOffset {
      proposedOffset.x = maxXOffset
    }
    // Enforce top edge at 0, no bottom limit (document grows downward).
    if proposedOffset.y < 0 {
      proposedOffset.y = 0
    }
    self.editor?.editorRenderer.viewOffset = proposedOffset
    if state == UIGestureRecognizer.State.ended {
      self.originalViewOffset = self.editor?.editorRenderer.viewOffset ?? CGPoint.zero
      // Keep deceleration direction consistent with drag direction.
      let verticalVelocity = velocity.y * dragResistance
      let horizontalVelocity = isZoomedIn ? velocity.x * dragResistance : 0

      // Start deceleration if velocity exceeds threshold in either direction.
      if abs(verticalVelocity) > velocityThreshold || abs(horizontalVelocity) > velocityThreshold {
        startDeceleration(
          verticalVelocity: verticalVelocity, horizontalVelocity: horizontalVelocity)
      }
    }
    NotificationCenter.default.post(name: DisplayViewController.refreshNotification, object: nil)
  }

  // Handles pinch gesture for zooming. No momentum is applied since zooming
  // should only occur while the user's fingers are on the screen.
  func handlePinchGestureRecognizerAction(
    scale: CGFloat, center: CGPoint, state: UIGestureRecognizer.State
  ) {
    guard let renderer = self.editor?.editorRenderer else {
      return
    }

    switch state {
    case .began, .changed:
      let currentScale = renderer.viewScale
      let proposedScale = currentScale * Float(scale)

      // Clamp to valid zoom range.
      let clampedScale = min(max(proposedScale, minZoomScale), maxZoomScale)

      // Only apply zoom if within bounds.
      if clampedScale != currentScale {
        // Calculate the actual factor to apply after clamping.
        let actualFactor = clampedScale / currentScale
        do {
          try renderer.performZoom(at: center, by: actualFactor)

          // Enforce viewport bounds after zoom to prevent drift.
          // Zoom adjusts viewOffset internally to keep the center point fixed,
          // but does not enforce document bounds, allowing progressive drift.
          var currentOffset = renderer.viewOffset

          // Store desired X before SDK clamping since clampViewOffset may reset X to 0.
          let desiredXOffset = currentOffset.x

          // Let SDK clamp vertical scrolling only.
          if var clampedOffset = Optional(currentOffset) {
            self.editor?.clampEditorViewOffset(&clampedOffset)
            currentOffset = clampedOffset
          }

          // Restore X and apply custom horizontal bounds.
          currentOffset.x = desiredXOffset

          // Enforce horizontal bounds: left edge at 0, right edge at maxXOffset.
          if currentOffset.x < 0 {
            currentOffset.x = 0
          }
          let maxXOffset = calculateMaxXOffset()
          if currentOffset.x > maxXOffset {
            currentOffset.x = maxXOffset
          }
          // Enforce top edge at 0.
          if currentOffset.y < 0 {
            currentOffset.y = 0
          }
          renderer.viewOffset = currentOffset
        } catch {
          // Silently ignore zoom errors.
        }
      }

      NotificationCenter.default.post(
        name: DisplayViewController.refreshNotification,
        object: nil
      )

    case .ended, .cancelled:
      // No momentum - zoom stops immediately when fingers lift.
      break

    default:
      break
    }
  }

  func setEditorViewSize(size: CGSize) {
    try? self.editor?.setEditorViewSize(size)
  }

  // Select pen tool.
  func selectPenTool() {
    setPointerTool(.toolPen)
  }

  // Select eraser tool.
  func selectEraserTool() {
    setPointerTool(.eraser)
  }

  // Select highlighter tool.
  func selectHighlighterTool() {
    setPointerTool(.toolHighlighter)
  }

  // Apply tool to the pen pointer type.
  private func setPointerTool(_ tool: IINKPointerTool) {
    do {
      try toolController?.setToolForPointerType(tool: tool, pointerType: .pen)
    } catch {
      // Silently ignore tool setting errors.
    }
  }

  private func startDeceleration(verticalVelocity: CGFloat, horizontalVelocity: CGFloat) {
    self.decelerationVelocityY = verticalVelocity
    self.decelerationVelocityX = horizontalVelocity
    self.lastDecelerationTimestamp = CACurrentMediaTime()
    self.decelerationLink?.invalidate()
    let displayLink = CADisplayLink(target: self, selector: #selector(applyDeceleration))
    displayLink.add(to: .main, forMode: .common)
    self.decelerationLink = displayLink
  }

  @objc private func applyDeceleration() {
    guard let editor = self.editor, let timestamp = self.lastDecelerationTimestamp else {
      stopDeceleration()
      return
    }
    let now = CACurrentMediaTime()
    let deltaTime = now - timestamp
    self.lastDecelerationTimestamp = now

    let rate = UIScrollView.DecelerationRate.normal.rawValue
    let decay = pow(rate, deltaTime * 1000)
    self.decelerationVelocityY *= decay
    self.decelerationVelocityX *= decay
    if abs(self.decelerationVelocityY) < 8 && abs(self.decelerationVelocityX) < 8 {
      stopDeceleration()
      return
    }

    var nextOffset = editor.editorRenderer.viewOffset
    nextOffset.y -= CGFloat(self.decelerationVelocityY) * CGFloat(deltaTime)
    nextOffset.x -= CGFloat(self.decelerationVelocityX) * CGFloat(deltaTime)

    // Store desired X before SDK clamping since clampViewOffset may reset X to 0.
    let desiredXOffset = nextOffset.x

    // Let SDK clamp vertical scrolling only.
    if var clampedOffset = Optional(nextOffset) {
      editor.clampEditorViewOffset(&clampedOffset)
      nextOffset = clampedOffset
    }

    // Restore X and apply custom horizontal bounds.
    nextOffset.x = desiredXOffset

    // Enforce horizontal bounds: left edge at 0, right edge at maxXOffset.
    if nextOffset.x < 0 {
      nextOffset.x = 0
      self.decelerationVelocityX = 0
    }
    let maxXOffset = calculateMaxXOffset()
    if nextOffset.x > maxXOffset {
      nextOffset.x = maxXOffset
      self.decelerationVelocityX = 0
    }
    // Enforce top edge at 0, no bottom limit (document grows downward).
    if nextOffset.y < 0 {
      nextOffset.y = 0
      self.decelerationVelocityY = 0
    }
    editor.editorRenderer.viewOffset = nextOffset
    self.originalViewOffset = nextOffset
    NotificationCenter.default.post(name: DisplayViewController.refreshNotification, object: nil)
  }

  private func stopDeceleration() {
    self.decelerationLink?.invalidate()
    self.decelerationLink = nil
    self.lastDecelerationTimestamp = nil
    self.decelerationVelocityY = 0
    self.decelerationVelocityX = 0
  }

  // Stops inertial scrolling when the user touches down.
  func stopInertialScroll() {
    stopDeceleration()
  }

  // Calculates the maximum horizontal offset based on current zoom level.
  // At zoom 1.0, maxXOffset = 0 (entire page visible, no right scrolling).
  // At higher zoom, maxXOffset increases to allow viewing the rest of the page.
  // viewOffset is in scaled view coordinates, so maxXOffset = pageWidth * (scale - 1).
  private func calculateMaxXOffset() -> CGFloat {
    guard let editor = self.editor else {
      return 0
    }
    let pageWidth = editor.viewSize.width
    let viewScale = CGFloat(editor.editorRenderer.viewScale)
    // At zoom 1.0: maxX = pageWidth * 0 = 0
    // At zoom 2.0: maxX = pageWidth * 1 = pageWidth
    // At zoom 4.0: maxX = pageWidth * 3
    let maxXOffset = pageWidth * (viewScale - 1)
    return max(0, maxXOffset)
  }

  private func initEditor(with target: DisplayViewModel) {
    guard let engine = self.engine,
      let renderer = try? engine.createRenderer(
        dpiX: Helper.scaledDpi(),
        dpiY: Helper.scaledDpi(),
        target: target)
    else {
      return
    }
    let newToolController: IINKToolController = engine.createToolController()
    let newEditor = self.engine?.createEditor(
      renderer: renderer,
      toolController: newToolController)
    self.editor = newEditor
    self.toolController = newToolController

    // Apply theme from css file if any.
    if let path = Bundle.main.path(forResource: "theme", ofType: "css"),
      let cssString = try? String(contentsOfFile: path).trimmingCharacters(
        in: .whitespacesAndNewlines) {
      try? self.editor?.setEditorTheme(cssString)
    }

    self.editor?.setEditorFontMetricsProvider(FontMetricsProvider())
    // Cast to IINKEditor for delegate callback since EditorDelegate expects concrete SDK type.
    if let iinkEditor = newEditor {
      self.editorDelegate?.didCreateEditor(editor: iinkEditor)
    }
    target.renderer = renderer
    target.imageLoader = ImageLoader()

    self.editor?.addEditorDelegate(self.editorDelegateTrampoline)
  }

  // Internal method for test injection of mock dependencies.
  // Allows tests to set editor and tool controller without going through SDK initialization.
  func setTestDependencies(editor: (any EditorProtocol)?, toolController: (any ToolControllerProtocol)?) {
    self.editor = editor
    self.toolController = toolController
  }
}
// swiftlint:enable type_body_length
