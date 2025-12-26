import UIKit

final class ToolPaletteView: UIView {
  enum ToolSelection {
    case pen
    case eraser
    case highlighter
  }

  // Notifies the host when a new tool selection is made.
  var selectionChanged: ((ToolSelection) -> Void)?

  // Defines the shared tint used for the toolbar icons.
  private let accentColor: UIColor
  // Sets the toolbar height to align with navigation bar sizing.
  private let toolbarHeight: CGFloat = 44
  // Stores the main toolbar that slides up from the bottom.
  private let toolbar = UIToolbar()
  // Stores the pencil toggle button shown when the toolbar is hidden.
  private let toggleButton = UIButton(type: .system)
  // Tracks the bottom constraint so the toolbar can animate.
  private var toolbarBottomConstraint: NSLayoutConstraint?
  // Tracks whether the toolbar is visible.
  private var isToolbarVisible = false
  // Tracks which tool is currently selected.
  private var selectedTool: ToolSelection = .pen
  // Stores references to each bar button item so their tint can be updated.
  private lazy var penItem = makeBarButton(
    systemName: "pencil.tip",
    accessibilityLabel: "Pen",
    action: #selector(penTapped)
  )
  private lazy var eraserItem = makeBarButton(
    systemName: "eraser",
    accessibilityLabel: "Eraser",
    action: #selector(eraserTapped)
  )
  private lazy var highlighterItem = makeBarButton(
    systemName: "highlighter",
    accessibilityLabel: "Highlighter",
    action: #selector(highlighterTapped)
  )

  init(accentColor: UIColor) {
    self.accentColor = accentColor
    super.init(frame: .zero)
    configureView()
  }

  required init?(coder: NSCoder) {
    self.accentColor = UIColor.label
    super.init(coder: coder)
    configureView()
  }

  // Exposes the current selection without sending callbacks.
  func setSelection(_ selection: ToolSelection) {
    applySelection(selection, notify: false)
  }

  // Presents the toolbar and hides the toggle button.
  func showToolbar() {
    guard isToolbarVisible == false else { return }
    isToolbarVisible = true
    toolbar.isHidden = false
    toolbarBottomConstraint?.constant = 0
    UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
      self.layoutIfNeeded()
      self.toggleButton.alpha = 0
    } completion: { _ in
      self.toggleButton.isHidden = true
    }
  }

  // Hides the toolbar and restores the toggle button.
  func hideToolbar() {
    guard isToolbarVisible else {
      toolbarBottomConstraint?.constant = toolbarHeight + 12
      toolbar.isHidden = true
      toggleButton.isHidden = false
      toggleButton.alpha = 1
      return
    }
    isToolbarVisible = false
    toggleButton.isHidden = false
    toolbarBottomConstraint?.constant = toolbarHeight + 12
    UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
      self.layoutIfNeeded()
      self.toggleButton.alpha = 1
      self.toolbar.alpha = 0
    } completion: { _ in
      self.toolbar.isHidden = true
      self.toolbar.alpha = 1
    }
  }

  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    configureToggleButton()
    configureToolbar()
    applySelection(.pen, notify: false)
    hideToolbar()
  }

  private func configureToggleButton() {
    let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    let image = UIImage(systemName: "pencil", withConfiguration: configuration)
    toggleButton.setImage(image, for: .normal)
    toggleButton.tintColor = accentColor
    toggleButton.accessibilityLabel = "Show tools"
    toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
    toggleButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(toggleButton)

    toggleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
    toggleButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true
    toggleButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
    toggleButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
  }

  private func configureToolbar() {
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    toolbar.isTranslucent = true
    toolbar.tintColor = accentColor
    addSubview(toolbar)

    toolbar.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    toolbar.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
    toolbarBottomConstraint = toolbar.bottomAnchor.constraint(
      equalTo: bottomAnchor, constant: toolbarHeight + 12)
    toolbarBottomConstraint?.isActive = true

    let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [penItem, flexible, eraserItem, flexible, highlighterItem]
  }

  private func makeBarButton(systemName: String, accessibilityLabel: String, action: Selector)
    -> UIBarButtonItem
  {
    let image = UIImage(systemName: systemName)
    let item = UIBarButtonItem(image: image, style: .plain, target: self, action: action)
    item.accessibilityLabel = accessibilityLabel
    return item
  }

  private func applySelection(_ selection: ToolSelection, notify: Bool) {
    selectedTool = selection
    updateItemAppearance()
    if notify {
      selectionChanged?(selection)
    }
  }

  private func updateItemAppearance() {
    let unselectedColor = accentColor.withAlphaComponent(0.45)
    penItem.tintColor = selectedTool == .pen ? accentColor : unselectedColor
    eraserItem.tintColor = selectedTool == .eraser ? accentColor : unselectedColor
    highlighterItem.tintColor = selectedTool == .highlighter ? accentColor : unselectedColor
  }

  @objc private func toggleTapped() {
    showToolbar()
  }

  @objc private func penTapped() {
    applySelection(.pen, notify: true)
  }

  @objc private func eraserTapped() {
    applySelection(.eraser, notify: true)
  }

  @objc private func highlighterTapped() {
    applySelection(.highlighter, notify: true)
  }
}
