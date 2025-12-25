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
  // Stores the editing toolbar anchored to the bottom right.
  private var editingToolbarView: EditingToolbarView?

  // MARK: - Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    self.configureNavigationItems()
    self.configureToolPalette()
    self.configureEditingToolbar()
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
    configureNavigationBarAppearance()
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
    self.navigationItem.rightBarButtonItem = nil
  }

  // Removes bar button backgrounds so only the icon glyphs show.
  private func configureNavigationBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()
    let buttonAppearance = appearance.buttonAppearance
    clearBarButtonItemBackground(buttonAppearance)
    appearance.buttonAppearance = buttonAppearance
    navigationItem.standardAppearance = appearance
    navigationItem.scrollEdgeAppearance = appearance
    navigationItem.compactAppearance = appearance
  }

  // Clears the background visuals for a bar button item appearance.
  private func clearBarButtonItemBackground(_ appearance: UIBarButtonItemAppearance) {
    appearance.normal.backgroundImage = UIImage()
    appearance.highlighted.backgroundImage = UIImage()
    appearance.disabled.backgroundImage = UIImage()
  }

  private func configureToolPalette() {
    let paletteView = ToolPaletteView(accentColor: offBlack)
    paletteView.translatesAutoresizingMaskIntoConstraints = false
    paletteView.expansionChanged = { [weak self] isExpanded in
      self?.editingToolbarView?.setCollapsed(isExpanded, animated: true)
    }
    paletteView.selectionChanged = { [weak self] selection in
      self?.viewModel.selectTool(selection)
    }
    view.addSubview(paletteView)

    paletteView.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    paletteView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -4
    ).isActive = true
    toolPaletteView = paletteView
  }

  // Adds the editing toolbar to the bottom right of the screen.
  private func configureEditingToolbar() {
    let toolbarView = EditingToolbarView(accentColor: offBlack)
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.undoTapped = { [weak self] in
      self?.viewModel.undo()
    }
    toolbarView.redoTapped = { [weak self] in
      self?.viewModel.redo()
    }
    toolbarView.clearTapped = { [weak self] in
      self?.viewModel.clear()
    }
    view.addSubview(toolbarView)

    toolbarView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    toolbarView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -4
    ).isActive = true
    editingToolbarView = toolbarView
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
