// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

/// The EditorViewController/ViewModel role is to instanciate all the properties and classes used to display the content of a page. It creates   "key" objects like the editor and renderer, and displays the DIsplayViewController, the InputView and the SmartGuide (if enabled).

class EditorViewController: UIViewController {

  //MARK: - Properties

  private var panGestureRecognizer: UIPanGestureRecognizer?
  private var pinchGestureRecognizer: UIPinchGestureRecognizer?
  private var viewModel: EditorViewModel
  private var containerView: UIView = UIView(frame: CGRect.zero)
  private var cancellables: Set<AnyCancellable> = []

  //MARK: - Life cycle

  init(viewModel: EditorViewModel) {
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
    self.pinchGestureRecognizer = UIPinchGestureRecognizer(
      target: self, action: #selector(pinchGestureRecognizerAction(pinchGestureRecognizer:)))
    if let panGestureRecognizer = self.panGestureRecognizer {
      panGestureRecognizer.delegate = self
      panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    }
    if let pinchGestureRecognizer = self.pinchGestureRecognizer {
      pinchGestureRecognizer.delegate = self
      pinchGestureRecognizer.allowedTouchTypes = [
        NSNumber(value: UITouch.TouchType.direct.rawValue)
      ]
    }
    self.bindViewModel()
    self.viewModel.setupModel(with: panGestureRecognizer, pinchGesture: self.pinchGestureRecognizer)
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

  //MARK: - UI settings

  private func displayModel(model: EditorModel) {
    if let inputView = model.neboInputView {
      self.view.addSubview(inputView)
      inputView.translatesAutoresizingMaskIntoConstraints = false
      inputView.backgroundColor = UIColor.clear
    }
    if let displayViewController = model.displayViewController {
      self.inject(viewController: displayViewController, in: self.containerView)
    }
    if let smartGuideViewController = model.smartGuideViewController {
      self.inject(viewController: smartGuideViewController, in: self.view)
    }
  }

  private func configureContainerView() {
    self.view.addSubview(self.containerView)
    self.containerView.translatesAutoresizingMaskIntoConstraints = false
    self.containerView.backgroundColor = UIColor.white
    self.containerView.isOpaque = true
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

  //MARK: - Data Binding

  private func bindViewModel() {
    self.viewModel.$model.sink { [weak self] model in
      if let model = model {
        self?.displayModel(model: model)
      }
    }.store(in: &cancellables)
    self.viewModel.$inputMode.sink { [weak self] inputMode in
      if let panGestureRecognizer = self?.panGestureRecognizer {
        switch inputMode {
        case .forcePen:
          panGestureRecognizer.isEnabled = false
          break
        case .forceTouch:
          panGestureRecognizer.isEnabled = true
          panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.stylus.rawValue),
          ]
          break
        case .auto:
          panGestureRecognizer.isEnabled = true
          panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue)
          ]
          break
        }
      }
      if let pinchGestureRecognizer = self?.pinchGestureRecognizer {
        switch inputMode {
        case .forcePen:
          pinchGestureRecognizer.isEnabled = false
          break
        case .forceTouch, .auto:
          pinchGestureRecognizer.isEnabled = true
          break
        }
      }
    }.store(in: &cancellables)
  }
}

//MARK: - Pan Gesture

extension EditorViewController: UIGestureRecognizerDelegate {

  @objc private func panGestureRecognizerAction(panGestureRecognizer: UIPanGestureRecognizer) {
    guard let state = self.panGestureRecognizer?.state else { return }
    let translation: CGPoint = panGestureRecognizer.translation(in: self.view)
    self.viewModel.handlePanGestureRecognizerAction(with: translation, state: state)
  }

  @objc private func pinchGestureRecognizerAction(pinchGestureRecognizer: UIPinchGestureRecognizer)
  {
    self.viewModel.handlePinchGestureRecognizerAction(
      with: pinchGestureRecognizer.scale, state: pinchGestureRecognizer.state)
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard self.viewModel.inputMode != .forcePen else { return false }
    if gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIPinchGestureRecognizer
    {
      return self.viewModel.editor?.isScrollAllowed ?? false
    }
    return true
  }
}
