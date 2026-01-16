// UI components for the editor toolbar.

import UIKit

// MARK: - ToolPaletteView

// Bottom toolbar for tool selection (pen, eraser, highlighter).
// Displays an expandable pill-shaped toolbar with tool options.
final class ToolPaletteView: UIView {

  // Tool selection options available in the palette.
  enum ToolSelection {
    case pen
    case eraser
    case highlighter
  }

  // Callbacks for tool interactions.
  var selectionChanged: ((ToolSelection) -> Void)?
  var colorSelectionChanged: ((ToolSelection, String) -> Void)?
  var thicknessChanged: ((ToolSelection, CGFloat) -> Void)?

  // Whether the toolbar is in expanded state showing additional options.
  private(set) var isExpanded: Bool = false

  // UI elements.
  private let accentColor: UIColor
  private let glassView = UIVisualEffectView()
  private let stackView = UIStackView()
  private var penButton: UIButton!
  private var eraserButton: UIButton!
  private var highlighterButton: UIButton!
  private var currentSelection: ToolSelection = .pen

  // Layout constants.
  private let buttonSize: CGFloat = 44
  private let collapsedHeight: CGFloat = 56
  private let expandedHeight: CGFloat = 120

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

  // Builds the view hierarchy.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)
    configureStackView()

    // Set height constraint.
    heightAnchor.constraint(equalToConstant: collapsedHeight).isActive = true

    // Pin glass view to edges.
    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
  }

  // Configures the glass material background.
  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.layer.cornerRadius = collapsedHeight / 2
    glassView.layer.cornerCurve = .continuous
    glassView.clipsToBounds = true
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = false
      glassView.effect = effect
    } else {
      glassView.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  // Configures the horizontal stack of tool buttons.
  private func configureStackView() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .center
    stackView.distribution = .equalSpacing

    penButton = makeToolButton(icon: "pencil.tip", accessibilityLabel: "Pen")
    eraserButton = makeToolButton(icon: "eraser", accessibilityLabel: "Eraser")
    highlighterButton = makeToolButton(icon: "highlighter", accessibilityLabel: "Highlighter")

    penButton.addTarget(self, action: #selector(penTapped), for: .touchUpInside)
    eraserButton.addTarget(self, action: #selector(eraserTapped), for: .touchUpInside)
    highlighterButton.addTarget(self, action: #selector(highlighterTapped), for: .touchUpInside)

    stackView.addArrangedSubview(penButton)
    stackView.addArrangedSubview(eraserButton)
    stackView.addArrangedSubview(highlighterButton)

    glassView.contentView.addSubview(stackView)

    // Center the stack in the glass view.
    stackView.centerXAnchor.constraint(equalTo: glassView.contentView.centerXAnchor).isActive = true
    stackView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor).isActive = true

    // Update visual selection state.
    updateSelectionState()
  }

  // Creates a tool button with the given SF Symbol icon.
  private func makeToolButton(icon: String, accessibilityLabel: String) -> UIButton {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.tintColor = accentColor
    button.accessibilityLabel = accessibilityLabel

    let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
    let image = UIImage(systemName: icon, withConfiguration: configuration)
    button.setImage(image, for: .normal)

    button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
    button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true

    return button
  }

  // Updates button states to reflect current selection.
  private func updateSelectionState() {
    let selectedAlpha: CGFloat = 1.0
    let unselectedAlpha: CGFloat = 0.4

    penButton.alpha = (currentSelection == .pen) ? selectedAlpha : unselectedAlpha
    eraserButton.alpha = (currentSelection == .eraser) ? selectedAlpha : unselectedAlpha
    highlighterButton.alpha = (currentSelection == .highlighter) ? selectedAlpha : unselectedAlpha
  }

  @objc private func penTapped() {
    currentSelection = .pen
    updateSelectionState()
    selectionChanged?(.pen)
  }

  @objc private func eraserTapped() {
    currentSelection = .eraser
    updateSelectionState()
    selectionChanged?(.eraser)
  }

  @objc private func highlighterTapped() {
    currentSelection = .highlighter
    updateSelectionState()
    selectionChanged?(.highlighter)
  }

  // Sets the toolbar visibility with optional animation.
  func setToolbarVisible(_ visible: Bool, animated: Bool) {
    isExpanded = visible
    // In a full implementation this would expand/collapse the toolbar.
  }

  // Checks if a touch point is within the palette's interaction area.
  func containsInteraction(at point: CGPoint, in view: UIView) -> Bool {
    let localPoint = convert(point, from: view)
    return bounds.contains(localPoint)
  }
}

// MARK: - EditingToolbarView

// Top-right toolbar with undo, redo, and clear buttons.
final class EditingToolbarView: UIView {

  // Callbacks for toolbar actions.
  var undoTapped: (() -> Void)?
  var redoTapped: (() -> Void)?
  var clearTapped: (() -> Void)?

  // UI elements.
  private let accentColor: UIColor
  private let glassView = UIVisualEffectView()
  private let stackView = UIStackView()
  private var undoButton: UIButton!
  private var redoButton: UIButton!
  private var clearButton: UIButton!

  // Layout constants.
  private let buttonSize: CGFloat = 36
  private let toolbarHeight: CGFloat = 48

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

  // Builds the view hierarchy.
  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear

    configureGlassView()
    addSubview(glassView)
    configureStackView()

    // Set height constraint.
    heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true

    // Pin glass view to edges.
    glassView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    glassView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    glassView.topAnchor.constraint(equalTo: topAnchor).isActive = true
    glassView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
  }

  // Configures the glass material background.
  private func configureGlassView() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.layer.cornerRadius = toolbarHeight / 2
    glassView.layer.cornerCurve = .continuous
    glassView.clipsToBounds = true
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = false
      glassView.effect = effect
    } else {
      glassView.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  // Configures the horizontal stack of action buttons.
  private func configureStackView() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .horizontal
    stackView.spacing = 4
    stackView.alignment = .center

    undoButton = makeActionButton(icon: "arrow.uturn.backward", accessibilityLabel: "Undo")
    redoButton = makeActionButton(icon: "arrow.uturn.forward", accessibilityLabel: "Redo")
    clearButton = makeActionButton(icon: "trash", accessibilityLabel: "Clear")

    undoButton.addTarget(self, action: #selector(undoPressed), for: .touchUpInside)
    redoButton.addTarget(self, action: #selector(redoPressed), for: .touchUpInside)
    clearButton.addTarget(self, action: #selector(clearPressed), for: .touchUpInside)

    stackView.addArrangedSubview(undoButton)
    stackView.addArrangedSubview(redoButton)
    stackView.addArrangedSubview(clearButton)

    glassView.contentView.addSubview(stackView)

    // Center the stack in the glass view with padding.
    stackView.leadingAnchor.constraint(
      equalTo: glassView.contentView.leadingAnchor,
      constant: 12
    ).isActive = true
    stackView.trailingAnchor.constraint(
      equalTo: glassView.contentView.trailingAnchor,
      constant: -12
    ).isActive = true
    stackView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor).isActive = true
  }

  // Creates an action button with the given SF Symbol icon.
  private func makeActionButton(icon: String, accessibilityLabel: String) -> UIButton {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.tintColor = accentColor
    button.accessibilityLabel = accessibilityLabel

    let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
    let image = UIImage(systemName: icon, withConfiguration: configuration)
    button.setImage(image, for: .normal)

    button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
    button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true

    return button
  }

  @objc private func undoPressed() {
    undoTapped?()
  }

  @objc private func redoPressed() {
    redoTapped?()
  }

  @objc private func clearPressed() {
    clearTapped?()
  }
}
