// Copyright @ MyScript. All rights reserved.

import Combine
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

/// This class is the ViewModel of the EditorViewController. It handles all its business logic.

class EditorViewModel {

  //MARK: - Reactive Properties

  @Published var inputMode: InputMode = .forcePen
  @Published var model: EditorModel?

  //MARK: - Properties

  var editor: IINKEditor?
  private weak var engine: IINKEngine?
  // Stores the tool controller so tools can be switched from the Notebook toolbar.
  private var toolController: IINKToolController?
  private(set) var originalViewOffset: CGPoint = CGPoint.zero
  // Keeps the zoom baseline so the canvas cannot be scaled smaller than the initial view width.
  private var pinchStartScale: CGFloat = 1.0
  private var minimumViewScale: CGFloat = 1.0
  private weak var editorDelegate: EditorDelegate?
  private var editorDelegateTrampoline: EditorDelegateTrampoline
  private weak var smartGuideDelegate: SmartGuideViewControllerDelegate?
  private var smartGuideDisabled: Bool = false
  private var didSetConstraints: Bool = false

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

  func setupModel(with panGesture: UIPanGestureRecognizer?, pinchGesture: UIPinchGestureRecognizer?)
  {
    let model = EditorModel()
    let displayViewModel = DisplayViewModel()
    self.initEditor(with: displayViewModel)
    model.displayViewController = DisplayViewController(viewModel: displayViewModel)
    if self.smartGuideDisabled == false {
      model.smartGuideViewController = SmartGuideViewController()
      model.smartGuideViewController?.editor = self.editor
      model.smartGuideViewController?.delegate = self.smartGuideDelegate
    }
    model.neboInputView = InputView(frame: CGRect.zero)
    model.neboInputView?.inputMode = self.inputMode
    model.neboInputView?.editor = self.editor
    if let panGesture = panGesture {
      model.neboInputView?.addGestureRecognizer(panGesture)
    }
    if let pinchGesture = pinchGesture {
      model.neboInputView?.addGestureRecognizer(pinchGesture)
    }
    self.model = model
  }

  func updateInputMode(newInputMode: InputMode) {
    self.inputMode = newInputMode
    self.model?.neboInputView?.inputMode = inputMode
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
      let model = self.model,
      let displayViewController = model.displayViewController,
      let displayViewControllerView = displayViewController.view,
      let inputView = model.neboInputView
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

  func handlePanGestureRecognizerAction(with translation: CGPoint, state: UIGestureRecognizer.State)
  {
    guard self.editor?.isScrollAllowed == true else {
      return
    }
    if state == UIGestureRecognizer.State.began {
      self.originalViewOffset = self.editor?.renderer.viewOffset ?? CGPoint.zero
    }
    let adjustedOffset = lockedViewOffset(for: translation)
    self.editor?.renderer.viewOffset = adjustedOffset
    if state == UIGestureRecognizer.State.ended {
      self.originalViewOffset = self.editor?.renderer.viewOffset ?? CGPoint.zero
    }
    NotificationCenter.default.post(name: DisplayViewController.refreshNotification, object: nil)
  }

  func handlePinchGestureRecognizerAction(with scale: CGFloat, state: UIGestureRecognizer.State) {
    guard let renderer = self.editor?.renderer, self.editor?.isScrollAllowed == true else {
      return
    }
    if state == UIGestureRecognizer.State.began {
      self.pinchStartScale = renderer.viewScale
    }
    var newScale = self.pinchStartScale * scale
    // Keep the zoom level at or above the canvas width that matches the screen edges.
    newScale = max(self.minimumViewScale, newScale)
    renderer.viewScale = newScale
    var clampedOffset = renderer.viewOffset
    clampedOffset = self.clampedOffsetForLockedCanvas(offset: clampedOffset)
    renderer.viewOffset = clampedOffset
    NotificationCenter.default.post(name: DisplayViewController.refreshNotification, object: nil)
    if state == UIGestureRecognizer.State.ended {
      self.pinchStartScale = renderer.viewScale
    }
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
        "❌ EditorViewModel.setPointerTool failed tool=\(tool) error=\(error.localizedDescription)")
    }
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
    self.minimumViewScale = renderer.viewScale

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

  private func lockedViewOffset(for translation: CGPoint) -> CGPoint {
    // Allow moving back toward the origin but never past it; horizontal motion stays fixed.
    let verticalOffset = max(0, self.originalViewOffset.y - translation.y)
    var newOffset: CGPoint = CGPoint(x: 0, y: verticalOffset)
    newOffset = self.clampedOffsetForLockedCanvas(offset: newOffset)
    newOffset.x = 0
    return newOffset
  }

  private func clampedOffsetForLockedCanvas(offset: CGPoint) -> CGPoint {
    // The canvas is fixed horizontally and cannot move above the starting origin.
    var adjustedOffset = CGPoint(x: 0, y: max(0, offset.y))
    self.editor?.clampViewOffset(&adjustedOffset)
    return adjustedOffset
  }
}
