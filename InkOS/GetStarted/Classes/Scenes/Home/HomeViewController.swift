// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

/// This is the Main ViewController of the project.
/// It Encapsulates the EditorViewController, and permits editing actions (such as undo/redo)

class HomeViewController: UIViewController {

  // MARK: Outlets

  @IBOutlet private weak var inputTypeSegmentedControl: UISegmentedControl!
  @IBOutlet private weak var editorContainerView: UIView!

  // MARK: Properties

  private var viewModel: HomeViewModel = HomeViewModel()
  private var editorViewController: EditorViewController?
  private var cancellables: Set<AnyCancellable> = []

  // MARK: - Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    self.configureNavigationItems()
    self.bindViewModel()
    self.viewModel.setupModel(engineProvider: EngineProvider.sharedInstance)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if self.isBeingDismissed || self.isMovingFromParent {
      self.viewModel.releaseEditor()
    }
  }

  // MARK: - Data Binding

  private func bindViewModel() {
    self.viewModel.$model.sink { [weak self] model in
      if let model = model,
        let editorViewController = model.editorViewController
      {
        self?.injectEditor(editor: editorViewController)
        self?.title = model.title
      }
    }.store(in: &cancellables)
    self.viewModel.$alert.sink { [weak self] alert in
      guard let unwrappedAlert = alert else { return }
      self?.present(unwrappedAlert, animated: true, completion: nil)
    }.store(in: &cancellables)
  }

  // MARK: - EditorViewController UI config

  private func injectEditor(editor: EditorViewController) {
    self.addChild(editor)
    self.editorContainerView.addSubview(editor.view)
    editor.view.frame = self.view.bounds
    editor.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.viewModel.setEditorViewSize(bounds: self.view.bounds)
  }

  // MARK: - Outlets actions

  @IBAction func clearButtonWasTouchedUpInside(_ sender: Any) {
    self.viewModel.clear()
  }

  @IBAction func undoButtonWasTouchedUpInside(_ sender: Any) {
    self.viewModel.undo()
  }

  @IBAction func redoButtonWasTouchedUpInside(_ sender: Any) {
    self.viewModel.redo()
  }

  @IBAction func convertButtonWasTouchedUpInside(_ sender: Any) {
    self.viewModel.convert()
  }

  @IBAction func inputTypeSegmentedControlValueChanged(_ sender: UISegmentedControl) {
    guard let inputMode = InputMode(rawValue: sender.selectedSegmentIndex) else { return }
    self.viewModel.updateInputMode(newInputMode: inputMode)
  }

  // MARK: - Navigation

  private func configureNavigationItems() {
    // Provide a clear way to return to the Dashboard.
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Back",
      style: .plain,
      target: self,
      action: #selector(backButtonTapped)
    )
  }

  @objc private func backButtonTapped() {
    self.viewModel.releaseEditor()
    self.dismiss(animated: true)
  }
}
