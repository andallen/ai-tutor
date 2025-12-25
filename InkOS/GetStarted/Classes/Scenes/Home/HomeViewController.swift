// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

/// This is the Main ViewController of the project.
/// It Encapsulates the EditorViewController, and permits editing actions (such as undo/redo)

class HomeViewController: UIViewController {

  // MARK: Outlets

  @IBOutlet private weak var editorContainerView: UIView!

  // MARK: Properties

  private var inputTypeSegmentedControl: UISegmentedControl?
  private var viewModel: HomeViewModel = HomeViewModel()
  private var editorViewController: EditorViewController?
  private var cancellables: Set<AnyCancellable> = []
  private var documentHandle: DocumentHandle?
  private let offBlack: UIColor = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
  // Stores the floating tool palette attached to the canvas view.
  private var toolPaletteView: ToolPaletteView?

  // MARK: - Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    self.configureNavigationItems()
    self.configureToolPalette()
    self.bindViewModel()
    guard let documentHandle = documentHandle else {
      self.viewModel.presentMissingNotebookError()
      return
    }
    self.viewModel.setupModel(
      engineProvider: EngineProvider.sharedInstance,
      documentHandle: documentHandle
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if self.isBeingDismissed || self.isMovingFromParent {
      self.viewModel.releaseEditor()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  // MARK: - Data Binding

  private func bindViewModel() {
    self.viewModel.$model.sink { [weak self] model in
      if let model = model, let editorViewController = model.editorViewController {
        self?.injectEditor(editor: editorViewController)
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

  @IBAction func inputTypeSegmentedControlValueChanged(_ sender: UISegmentedControl) {
    guard let inputMode = InputMode(rawValue: sender.selectedSegmentIndex) else { return }
    self.viewModel.updateInputMode(newInputMode: inputMode)
  }

  // MARK: - Navigation

  private func configureNavigationItems() {
    // Provide a clear way to return to the Dashboard.
    let backImage = UIImage(systemName: "house")?.withRenderingMode(.alwaysTemplate)
    let backItem = UIBarButtonItem(
      image: backImage,
      style: .plain,
      target: self,
      action: #selector(backButtonTapped)
    )
    backItem.accessibilityLabel = "Home"
    backItem.tintColor = offBlack
    if backImage == nil {
      backItem.title = "Home"
    }
    self.navigationItem.leftBarButtonItem = backItem
    // Center the pen and touch toggle in the navigation bar.
    let segmentedControl = UISegmentedControl(items: ["Pen", "Touch"])
    segmentedControl.selectedSegmentIndex = 0
    segmentedControl.addTarget(
      self,
      action: #selector(inputTypeSegmentedControlValueChanged(_:)),
      for: .valueChanged
    )
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .foregroundColor: offBlack
    ]
    segmentedControl.setTitleTextAttributes(titleAttributes, for: .normal)
    segmentedControl.setTitleTextAttributes(titleAttributes, for: .selected)
    segmentedControl.selectedSegmentTintColor = offBlack.withAlphaComponent(0.12)
    self.inputTypeSegmentedControl = segmentedControl
    self.navigationItem.titleView = segmentedControl
    self.navigationItem.rightBarButtonItem = makeEditingBarButtonItem()
  }

  private func configureToolPalette() {
    let paletteView = ToolPaletteView(accentColor: offBlack)
    paletteView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(paletteView)

    paletteView.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    paletteView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -20
    ).isActive = true
    toolPaletteView = paletteView
  }

  // Creates a single bar button item that hosts the undo, redo, and clear icons.
  private func makeEditingBarButtonItem() -> UIBarButtonItem {
    let undoButton = makeToolbarButton(
      imageName: "Undo",
      action: #selector(undoButtonWasTouchedUpInside(_:)),
      accessibilityLabel: "Undo"
    )
    let redoButton = makeToolbarButton(
      imageName: "Redo",
      action: #selector(redoButtonWasTouchedUpInside(_:)),
      accessibilityLabel: "Redo"
    )
    let clearButton = makeToolbarButton(
      imageName: "Clear",
      action: #selector(clearButtonWasTouchedUpInside(_:)),
      accessibilityLabel: "Clear"
    )
    let stackView = UIStackView(arrangedSubviews: [undoButton, redoButton, clearButton])
    stackView.axis = .horizontal
    stackView.spacing = 12
    stackView.alignment = .center
    return UIBarButtonItem(customView: stackView)
  }

  // Ensures consistent sizing and tint for the toolbar icons.
  private func makeToolbarButton(
    imageName: String,
    action: Selector,
    accessibilityLabel: String
  ) -> UIButton {
    let button = UIButton(type: .system)
    if let image = UIImage(named: imageName) {
      button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
    } else {
      button.setTitle(imageName, for: .normal)
    }
    button.tintColor = offBlack
    button.accessibilityLabel = accessibilityLabel
    button.addTarget(self, action: action, for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    let widthConstraint = button.widthAnchor.constraint(equalToConstant: 28)
    let heightConstraint = button.heightAnchor.constraint(equalToConstant: 28)
    NSLayoutConstraint.activate([widthConstraint, heightConstraint])
    return button
  }

  @objc private func backButtonTapped() {
    self.viewModel.releaseEditor()
    self.dismiss(animated: true)
  }

  @objc private func handleWillResignActive() {
    self.viewModel.handleAppBackground()
  }

  func configure(documentHandle: DocumentHandle) {
    self.documentHandle = documentHandle
  }
}
