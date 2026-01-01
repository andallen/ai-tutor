// Copyright @ MyScript. All rights reserved.

// swiftlint:disable file_length
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

// Bridges gesture callbacks from MyScript SDK to the Swift EditorDelegate protocol.
// IINKGestureDelegate is a separate protocol from IINKEditorDelegate and must be set
// separately on the editor via the gestureDelegate property.
private class GestureDelegateTrampoline: NSObject, IINKGestureDelegate {

  private weak var editorDelegate: EditorDelegate?

  init(editorDelegate: EditorDelegate?) {
    self.editorDelegate = editorDelegate
  }

  func onTap(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    x: Float,
    y: Float
  ) -> IINKGestureAction {
    // Let MyScript handle tap behavior (selection, etc.) by default.
    return .apply
  }

  func onDoubleTap(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeIds: [String],
    x: Float,
    y: Float
  ) -> IINKGestureAction {
    // Let MyScript handle double-tap conversion by default.
    return .apply
  }

  func onLongPress(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    x: Float,
    y: Float
  ) -> IINKGestureAction {
    // Let MyScript handle long-press behavior by default.
    return .apply
  }

  func onUnderline(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    selection: any NSObjectProtocol & IINKIContentSelection
  ) -> IINKGestureAction {
    // Let MyScript apply the underline decoration.
    return .apply
  }

  func onSurround(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    selection: any NSObjectProtocol & IINKIContentSelection
  ) -> IINKGestureAction {
    // Surround gesture not used - treat as regular ink.
    return .add
  }

  func onJoin(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    before: any NSObjectProtocol & IINKIContentSelection,
    after: any NSObjectProtocol & IINKIContentSelection
  ) -> IINKGestureAction {
    // Let MyScript handle join behavior.
    return .apply
  }

  func onInsert(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    before: any NSObjectProtocol & IINKIContentSelection,
    after: any NSObjectProtocol & IINKIContentSelection
  ) -> IINKGestureAction {
    // Let MyScript handle insert behavior.
    return .apply
  }

  func onStrikethrough(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    selection: any NSObjectProtocol & IINKIContentSelection
  ) -> IINKGestureAction {
    // Let MyScript apply the strikethrough decoration.
    return .apply
  }

  func onScratch(
    _ editor: IINKEditor,
    tool: IINKPointerTool,
    gestureStrokeId: String,
    selection: any NSObjectProtocol & IINKIContentSelection
  ) -> IINKGestureAction {
    // Let MyScript delete the scratched content.
    return .apply
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
  private var gestureDelegateTrampoline: GestureDelegateTrampoline
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

  // Rubber-band overscroll constants.
  // Maximum distance content can stretch past boundary before hitting hard limit.
  private let maxOverscrollDistance: CGFloat = 180
  // Controls how quickly resistance increases as user drags past boundary.
  // Lower values mean more resistance. 0.55 matches iOS scroll view behavior.
  private let rubberBandFactor: CGFloat = 0.55

  // Current overscroll amounts (negative = past top/left, positive = past bottom/right).
  // Used by deceleration loop to apply per-axis spring-back.
  private var overscrollY: CGFloat = 0
  private var overscrollX: CGFloat = 0

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
    self.gestureDelegateTrampoline = GestureDelegateTrampoline(editorDelegate: editorDelegate)
    self.smartGuideDelegate = smartGuideDelegate
    self.smartGuideDisabled = smartGuideDisabled
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

  // swiftlint:disable function_body_length
  // Pan gesture handling requires comprehensive boundary checking, rubber-banding,
  // and spring-back logic in a single cohesive function to maintain state consistency.
  func handlePanGestureRecognizerAction(
    with translation: CGPoint, velocity: CGPoint, state: UIGestureRecognizer.State
  ) {
    guard self.editor?.isScrollAllowed == true else {
      return
    }
    // Restart inertia when a new pan begins.
    if state == UIGestureRecognizer.State.began {
      stopDeceleration()
      self.originalViewOffset = self.editor?.editorRenderer.viewOffset ?? CGPoint.zero
      // Reset overscroll tracking at pan start.
      self.overscrollY = 0
      self.overscrollX = 0
    }

    // Reduce translation to avoid 1:1 tracking and match iOS scrolling cadence.
    // Track both axes for rubber-band effect. Boundary clamping handles zoom-based limits.
    let adjustedTranslationY = translation.y * dragResistance
    let adjustedTranslationX = translation.x * dragResistance

    // Calculate where the content would move without boundary clamping.
    let rawProposedOffset = CGPoint(
      x: originalViewOffset.x - adjustedTranslationX,
      y: originalViewOffset.y - adjustedTranslationY)

    // Calculate boundary limits.
    let maxXOffset = calculateMaxXOffset()
    let minXOffset: CGFloat = 0
    let minYOffset: CGFloat = 0

    // Apply rubber-band physics if scrolling past boundaries.
    var finalOffset = rawProposedOffset

    // Horizontal rubber-banding (left boundary).
    if rawProposedOffset.x < minXOffset {
      let overscroll = minXOffset - rawProposedOffset.x
      let rubberBandedOverscroll = applyRubberBandEffect(overscroll: overscroll)
      finalOffset.x = minXOffset - rubberBandedOverscroll
      self.overscrollX = -rubberBandedOverscroll
    }
    // Horizontal rubber-banding (right boundary).
    else if rawProposedOffset.x > maxXOffset {
      let overscroll = rawProposedOffset.x - maxXOffset
      let rubberBandedOverscroll = applyRubberBandEffect(overscroll: overscroll)
      finalOffset.x = maxXOffset + rubberBandedOverscroll
      self.overscrollX = rubberBandedOverscroll
    } else {
      self.overscrollX = 0
    }

    // Vertical rubber-banding (top boundary only).
    if rawProposedOffset.y < minYOffset {
      let overscroll = minYOffset - rawProposedOffset.y
      let rubberBandedOverscroll = applyRubberBandEffect(overscroll: overscroll)
      finalOffset.y = minYOffset - rubberBandedOverscroll
      self.overscrollY = -rubberBandedOverscroll
    } else {
      self.overscrollY = 0
    }

    self.editor?.editorRenderer.viewOffset = finalOffset

    if state == UIGestureRecognizer.State.ended {
      self.originalViewOffset = self.editor?.editorRenderer.viewOffset ?? CGPoint.zero

      // Calculate velocities for both axes.
      let verticalVelocity = velocity.y * dragResistance
      let horizontalVelocity = velocity.x * dragResistance

      // Check if currently in overscroll territory.
      let isInOverscrollX = self.overscrollX != 0
      let isInOverscrollY = self.overscrollY != 0

      // Determine if we have meaningful velocity on non-overscrolled axes.
      let hasXVelocity = abs(horizontalVelocity) > velocityThreshold && !isInOverscrollX
      let hasYVelocity = abs(verticalVelocity) > velocityThreshold && !isInOverscrollY

      if isInOverscrollX || isInOverscrollY || hasXVelocity || hasYVelocity {
        // Start unified deceleration which handles both spring-back and momentum.
        // Pass velocity for non-overscrolled axes; overscrolled axes will spring back.
        startDeceleration(
          verticalVelocity: isInOverscrollY ? 0 : verticalVelocity,
          horizontalVelocity: isInOverscrollX ? 0 : horizontalVelocity)
      }
    }
    NotificationCenter.default.post(name: DisplayViewController.refreshNotification, object: nil)
  }
  // swiftlint:enable function_body_length

  // Applies rubber-band physics to overscroll distance.
  // Returns a diminished value that increases with resistance as the user drags further.
  // Uses the iOS-style formula: x = c * (1 - (1 / (x / d * c + 1))) * d
  // where x is the overscroll distance, c is the rubber band coefficient, d is the max distance.
  private func applyRubberBandEffect(overscroll: CGFloat) -> CGFloat {
    // Guard against division by zero or negative values.
    guard overscroll > 0 else { return 0 }

    // Scale max overscroll distance based on zoom level.
    // At higher zoom, content appears larger so overscroll should be proportionally larger.
    let currentScale = CGFloat(self.editor?.editorRenderer.viewScale ?? 1.0)
    let scaledMaxDistance = maxOverscrollDistance * currentScale

    // Simplified rubber-band formula matching UIScrollView behavior.
    // As overscroll increases, the returned value approaches scaledMaxDistance asymptotically.
    let coefficient = rubberBandFactor

    // Formula: result = c * d * (1 - 1 / ((x / (c * d)) + 1))
    // This produces a smooth curve that starts linear and flattens as it approaches max.
    let normalizedOverscroll = overscroll / (coefficient * scaledMaxDistance)
    let dampedValue = coefficient * scaledMaxDistance * (1 - 1 / (normalizedOverscroll + 1))

    return min(dampedValue, scaledMaxDistance)
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

    // Apply decay to velocities independently.
    self.decelerationVelocityY *= decay
    self.decelerationVelocityX *= decay

    var nextOffset = editor.editorRenderer.viewOffset
    let maxXOffset = calculateMaxXOffset()

    // Track whether each axis is still active (decelerating or in overscroll).
    var xAxisActive = true
    var yAxisActive = true

    // Handle horizontal axis: apply velocity then check bounds.
    nextOffset.x -= CGFloat(self.decelerationVelocityX) * CGFloat(deltaTime)

    if nextOffset.x < 0 {
      // Hit left boundary. Use actual overshoot with rubber-band applied.
      let overscrollDistance = applyRubberBandEffect(overscroll: abs(nextOffset.x))
      nextOffset.x = -overscrollDistance
      self.overscrollX = -overscrollDistance
      // Zero X velocity but let Y continue.
      self.decelerationVelocityX = 0
    } else if nextOffset.x > maxXOffset {
      // Hit right boundary.
      let overscrollDistance = applyRubberBandEffect(overscroll: nextOffset.x - maxXOffset)
      nextOffset.x = maxXOffset + overscrollDistance
      self.overscrollX = overscrollDistance
      self.decelerationVelocityX = 0
    }

    // Check if X axis is done (velocity stopped and no overscroll).
    if abs(self.decelerationVelocityX) < 8 && self.overscrollX == 0 {
      xAxisActive = false
    }

    // Handle vertical axis: apply velocity then check bounds.
    nextOffset.y -= CGFloat(self.decelerationVelocityY) * CGFloat(deltaTime)

    if nextOffset.y < 0 {
      // Hit top boundary. Use actual overshoot with rubber-band applied.
      let overscrollDistance = applyRubberBandEffect(overscroll: abs(nextOffset.y))
      nextOffset.y = -overscrollDistance
      self.overscrollY = -overscrollDistance
      // Zero Y velocity but let X continue.
      self.decelerationVelocityY = 0
    }

    // Check if Y axis is done (velocity stopped and no overscroll).
    if abs(self.decelerationVelocityY) < 8 && self.overscrollY == 0 {
      yAxisActive = false
    }

    // Apply spring-back to any axis currently in overscroll.
    // This allows one axis to spring back while the other continues decelerating.
    // Use a gentle spring factor for smooth, natural-feeling return to bounds.
    // Factor of 0.008 at 60fps gives approximately 1.5-2 second return time.
    let springFactor: CGFloat = 0.008

    if self.overscrollX != 0 {
      // Ease X back toward the boundary.
      if self.overscrollX < 0 {
        // Overscrolled past left (offset is negative).
        nextOffset.x = nextOffset.x * (1 - springFactor)
        self.overscrollX = nextOffset.x
        if abs(nextOffset.x) < 0.3 {
          nextOffset.x = 0
          self.overscrollX = 0
        }
      } else {
        // Overscrolled past right (offset is past maxXOffset).
        let currentOverscroll = nextOffset.x - maxXOffset
        let newOverscroll = currentOverscroll * (1 - springFactor)
        nextOffset.x = maxXOffset + newOverscroll
        self.overscrollX = newOverscroll
        if abs(newOverscroll) < 0.3 {
          nextOffset.x = maxXOffset
          self.overscrollX = 0
        }
      }
      xAxisActive = true
    }

    if self.overscrollY != 0 {
      // Ease Y back toward the boundary (top only).
      if self.overscrollY < 0 {
        // Overscrolled past top (offset is negative).
        nextOffset.y = nextOffset.y * (1 - springFactor)
        self.overscrollY = nextOffset.y
        if abs(nextOffset.y) < 0.3 {
          nextOffset.y = 0
          self.overscrollY = 0
        }
      }
      yAxisActive = true
    }

    editor.editorRenderer.viewOffset = nextOffset
    self.originalViewOffset = nextOffset

    // Stop deceleration only when both axes are done.
    if !xAxisActive && !yAxisActive {
      stopDeceleration()
    }

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
    // Reset overscroll state so content snaps to valid bounds.
    self.overscrollX = 0
    self.overscrollY = 0
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

    // Set the gesture delegate for scratch-out, underline, and other gestures.
    // This is a separate delegate from the editor delegate.
    newEditor?.gestureDelegate = self.gestureDelegateTrampoline
  }

  // Internal method for test injection of mock dependencies.
  // Allows tests to set editor and tool controller without going through SDK initialization.
  func setTestDependencies(
    editor: (any EditorProtocol)?, toolController: (any ToolControllerProtocol)?
  ) {
    self.editor = editor
    self.toolController = toolController
  }
}
// swiftlint:enable type_body_length
