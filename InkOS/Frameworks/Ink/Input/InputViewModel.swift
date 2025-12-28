// Copyright @ MyScript. All rights reserved.

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

/// This class is the ViewModel of the InputViewController. It handles all its business logic.

class InputViewModel {

  //MARK: - Reactive Properties

  @Published var inputMode: InputMode = .forcePen
  @Published var displayViewController: DisplayViewController?
  @Published var smartGuideViewController: SmartGuideViewController?
  @Published var neboInputView: InputView?

  //MARK: - Properties

  var editor: IINKEditor?
  private weak var engine: IINKEngine?
  // Stores the tool controller so tools can be switched from the Notebook toolbar.
  private var toolController: IINKToolController?
  private(set) var originalViewOffset: CGPoint = CGPoint.zero
  private weak var editorDelegate: EditorDelegate?
  private var editorDelegateTrampoline: EditorDelegateTrampoline
  private weak var smartGuideDelegate: SmartGuideViewControllerDelegate?
  private var smartGuideDisabled: Bool = false
  private var didSetConstraints: Bool = false
  // Tracks inertial scrolling so the canvas can glide after the finger lifts.
  private var decelerationLink: CADisplayLink?
  private var decelerationVelocity: CGFloat = 0
  private var lastDecelerationTimestamp: CFTimeInterval?

  // Softens drag to feel closer to native scroll physics.
  private let dragResistance: CGFloat = 0.88
  // Filters out tiny lifts so motion only continues when the finger is still moving.
  private let velocityThreshold: CGFloat = 60

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

  func setupModel(with panGesture: UIPanGestureRecognizer?) {
    let displayViewModel = DisplayViewModel()
    self.initEditor(with: displayViewModel)
    self.displayViewController = DisplayViewController(viewModel: displayViewModel)
    if self.smartGuideDisabled == false {
      self.smartGuideViewController = SmartGuideViewController()
      self.smartGuideViewController?.editor = self.editor
      self.smartGuideViewController?.delegate = self.smartGuideDelegate
    }
    self.neboInputView = InputView(frame: CGRect.zero)
    self.neboInputView?.inputMode = self.inputMode
    self.neboInputView?.editor = self.editor
    if let panGesture = panGesture {
      self.neboInputView?.addGestureRecognizer(panGesture)
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
    try? editor.set(viewSize: viewSize)
    let conf: IINKConfiguration = editor.configuration
    let horizontalMarginMM: Double = 5
    let verticalMarginMM: Double = 15

    try? conf.set(number: verticalMarginMM, forKey: "text.margin.top")
    try? conf.set(number: horizontalMarginMM, forKey: "text.margin.left")
    try? conf.set(number: horizontalMarginMM, forKey: "text.margin.right")
    try? conf.set(number: verticalMarginMM, forKey: "math.margin.top")
    try? conf.set(number: verticalMarginMM, forKey: "math.margin.bottom")
    try? conf.set(number: horizontalMarginMM, forKey: "math.margin.left")
    try? conf.set(number: horizontalMarginMM, forKey: "math.margin.right")
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
      "inputView": inputView,
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
      self.originalViewOffset = self.editor?.renderer.viewOffset ?? CGPoint.zero
    }
    // Reduce translation to avoid 1:1 tracking and match iOS scrolling cadence.
    let adjustedTranslationY = translation.y * dragResistance
    var proposedOffset = CGPoint(
      x: originalViewOffset.x, y: originalViewOffset.y - adjustedTranslationY)
    if var clampedOffset = Optional(proposedOffset) {
      self.editor?.clampViewOffset(&clampedOffset)
      proposedOffset.x = clampedOffset.x
    }
    self.editor?.renderer.viewOffset = proposedOffset
    if state == UIGestureRecognizer.State.ended {
      self.originalViewOffset = self.editor?.renderer.viewOffset ?? CGPoint.zero
      // Keep deceleration direction consistent with drag direction to avoid bouncing back.
      let verticalVelocity = velocity.y * dragResistance
      if abs(verticalVelocity) > velocityThreshold {
        startDeceleration(with: verticalVelocity)
      }
    }
    NotificationCenter.default.post(name: DisplayViewController.refreshNotification, object: nil)
  }

  func setEditorViewSize(size: CGSize) {
    try? self.editor?.set(viewSize: size)
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
      try toolController?.set(tool: tool, forType: .pen)
    } catch {
      appLog(
        "❌ InputViewModel.setPointerTool failed tool=\(tool) error=\(error.localizedDescription)")
    }
  }

  private func startDeceleration(with velocity: CGFloat) {
    self.decelerationVelocity = velocity
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
    self.decelerationVelocity *= decay
    if abs(self.decelerationVelocity) < 8 {
      stopDeceleration()
      return
    }

    var nextOffset = editor.renderer.viewOffset
    nextOffset.y -= CGFloat(self.decelerationVelocity) * CGFloat(deltaTime)
    if var clampedOffset = Optional(nextOffset) {
      editor.clampViewOffset(&clampedOffset)
      nextOffset.x = clampedOffset.x
    }
    editor.renderer.viewOffset = nextOffset
    self.originalViewOffset = nextOffset
    NotificationCenter.default.post(name: DisplayViewController.refreshNotification, object: nil)
  }

  private func stopDeceleration() {
    self.decelerationLink?.invalidate()
    self.decelerationLink = nil
    self.lastDecelerationTimestamp = nil
    self.decelerationVelocity = 0
  }

  // Stops inertial scrolling when the user touches down.
  func stopInertialScroll() {
    stopDeceleration()
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
    let toolController: IINKToolController = engine.createToolController()
    self.editor = self.engine?.createEditor(
      renderer: renderer,
      toolController: toolController)
    self.toolController = toolController

    // Apply theme from css file if any
    if let path = Bundle.main.path(forResource: "theme", ofType: "css"),
      let cssString = try? String(contentsOfFile: path).trimmingCharacters(
        in: .whitespacesAndNewlines)
    {
      try? self.editor?.set(theme: cssString)
    }

    self.editor?.set(fontMetricsProvider: FontMetricsProvider())
    if self.editor != nil {
      self.editorDelegate?.didCreateEditor(editor: self.editor!)
    }
    target.renderer = renderer
    target.imageLoader = ImageLoader()

    self.editor?.addDelegate(self.editorDelegateTrampoline)
  }
}
