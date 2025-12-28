// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

/// This is the Main ViewController of the project.
/// It Encapsulates the InputViewController, and permits editing actions (such as undo/redo)

class EditorViewController: UIViewController {

  // MARK: Properties

  private var editorContainerView: UIView!

  private var inputTypeSegmentedControl: UISegmentedControl?
  private var viewModel: EditorViewModel = EditorViewModel()
  private var editorViewController: InputViewController?
  private var cancellables: Set<AnyCancellable> = []
  private var documentHandle: DocumentHandle?
  private let offBlack: UIColor = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
  private let previewMaxPixelDimension: CGFloat = 1200
  private var hasPreparedForExit = false
  // Stores the floating tool palette attached to the canvas view.
  private var toolPaletteView: ToolPaletteView?
  // Stores the editing toolbar anchored to the bottom right.
  private var editingToolbarView: EditingToolbarView?
  // Tracks the current visibility state of the editing toolbar.
  private var isEditingToolbarVisible = true
  // Tracks whether touch mode is active for tap-to-dismiss behavior.
  private var isTouchModeEnabled = false
  // Stores the tap gesture that dismisses the tool palette.
  private var outsideTapRecognizer: UITapGestureRecognizer?

  // MARK: - Life cycle

  override func loadView() {
    super.loadView()
    // Creates the editor container view programmatically.
    let containerView = UIView(frame: UIScreen.main.bounds)
    containerView.backgroundColor = UIColor.white
    containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.view.addSubview(containerView)
    self.editorContainerView = containerView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.configureNavigationItems()
    self.configureToolPalette()
    self.configureEditingToolbar()
    self.configureTapToDismissPalette()
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
      prepareForExit()
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
    self.viewModel.$editorViewController.sink { [weak self] editorViewController in
      if let editorViewController = editorViewController {
        self?.injectEditor(editor: editorViewController)
      }
    }.store(in: &cancellables)
    self.viewModel.$alert.sink { [weak self] alert in
      guard let unwrappedAlert = alert else { return }
      self?.present(unwrappedAlert, animated: true, completion: nil)
    }.store(in: &cancellables)
  }

  // MARK: - EditorViewController UI config

  private func injectEditor(editor: InputViewController) {
    self.editorViewController = editor
    self.addChild(editor)
    self.editorContainerView.addSubview(editor.view)
    editor.view.frame = self.view.bounds
    editor.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.viewModel.setEditorViewSize(bounds: self.view.bounds)
  }

  // MARK: - Actions

  @objc private func inputTypeSegmentedControlValueChanged(_ sender: UISegmentedControl) {
    guard let inputMode = InputMode(rawValue: sender.selectedSegmentIndex) else { return }
    isTouchModeEnabled = inputMode == .forceTouch
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
    isTouchModeEnabled = false
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
    // Clear the bar fill so the canvas sits behind the controls.
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = .clear
    appearance.shadowColor = .clear
    let buttonAppearance = appearance.buttonAppearance
    clearBarButtonItemBackground(buttonAppearance)
    appearance.buttonAppearance = buttonAppearance
    navigationController?.navigationBar.isTranslucent = true
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
    paletteView.selectionChanged = { [weak self] selection in
      self?.viewModel.updateTool(selection: selection)
    }
    paletteView.colorSelectionChanged = { [weak self] tool, hex in
      self?.viewModel.updateInkColor(hex: hex, for: tool)
    }
    paletteView.thicknessChanged = { [weak self] tool, width in
      self?.viewModel.updateInkWidth(width: width, for: tool)
    }
    paletteView.expansionChanged = { [weak self] isExpanded in
      self?.setEditingToolbarVisible(isExpanded == false, animated: true)
    }
    view.addSubview(paletteView)

    paletteView.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: 20
    ).isActive = true
    paletteView.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -20
    ).isActive = true
    paletteView.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -8
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

  // Shows or hides the editing toolbar while keeping its layout constraints intact.
  private func setEditingToolbarVisible(_ visible: Bool, animated: Bool) {
    guard let toolbarView = editingToolbarView else {
      return
    }
    guard visible != isEditingToolbarVisible else {
      return
    }
    isEditingToolbarVisible = visible
    let offset = max(toolbarView.bounds.height, 36) + 12
    if visible {
      toolbarView.isHidden = false
      toolbarView.alpha = 0
      toolbarView.transform = CGAffineTransform(translationX: 0, y: offset)
    }

    let animations = {
      toolbarView.alpha = visible ? 1 : 0
      toolbarView.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: offset)
    }

    let completion: (Bool) -> Void = { _ in
      if visible == false {
        toolbarView.isHidden = true
      }
    }

    if animated {
      UIView.animate(
        withDuration: 0.22,
        delay: 0,
        options: [.curveEaseInOut],
        animations: animations,
        completion: completion
      )
    } else {
      animations()
      completion(true)
    }
  }

  // Adds a tap gesture that dismisses the tool palette in touch mode.
  private func configureTapToDismissPalette() {
    let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
    recognizer.cancelsTouchesInView = false
    recognizer.delegate = self
    view.addGestureRecognizer(recognizer)
    outsideTapRecognizer = recognizer
  }

  // Handles taps outside the tool palette when touch mode is enabled.
  @objc private func handleOutsideTap(_ recognizer: UITapGestureRecognizer) {
    guard isTouchModeEnabled else {
      return
    }
    guard let toolPaletteView = toolPaletteView, toolPaletteView.isExpanded else {
      return
    }
    toolPaletteView.setToolbarVisible(false, animated: true)
  }

  @objc private func backButtonTapped() {
    prepareForExit()
    self.dismiss(animated: true)
  }

  @objc private func handleWillResignActive() {
    self.viewModel.handleAppBackground()
  }

  // Captures a preview and releases the editor once per exit.
  private func prepareForExit() {
    guard hasPreparedForExit == false else {
      addLog("🧪 EditorViewController.prepareForExit skip alreadyPrepared")
      return
    }
    hasPreparedForExit = true
    addLog(
      "🧪 EditorViewController.prepareForExit start dismissed=\(isBeingDismissed) movingFromParent=\(isMovingFromParent)"
    )
    let previewImage = editorViewController?.capturePreviewImage(
      maxPixelDimension: previewMaxPixelDimension)
    addLog(
      "🧪 EditorViewController.prepareForExit capturedPreview=\(previewImage != nil)"
    )
    viewModel.releaseEditor(previewImage: previewImage)
  }

  func configure(documentHandle: DocumentHandle) {
    self.documentHandle = documentHandle
  }
}

extension EditorViewController: UIGestureRecognizerDelegate {

  // Allows the tap recognizer only when the palette is open and the touch is outside it.
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch)
    -> Bool
  {
    guard isTouchModeEnabled else {
      return false
    }
    guard let toolPaletteView = toolPaletteView, toolPaletteView.isExpanded else {
      return false
    }
    let location = touch.location(in: view)
    if toolPaletteView.containsInteraction(at: location, in: view) {
      return false
    }
    return true
  }
}
