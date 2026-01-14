// NotesOverlayView.swift
// Glass overlay panel containing a MyScript canvas for lesson notes.
// Slides up from the bottom-right corner when expanded.

import UIKit

// Delegate for notes overlay events.
protocol NotesOverlayViewDelegate: AnyObject {
  func notesOverlayDidRequestDismiss(_ overlay: NotesOverlayView)
}

// Glass overlay panel for free-form notes in lessons.
// Contains a MyScript InputViewController for handwriting input.
final class NotesOverlayView: UIView {

  // Delegate for overlay events.
  weak var delegate: NotesOverlayViewDelegate?

  // Container view for the InputViewController.
  // The coordinator embeds the InputViewController.view here.
  private(set) var canvasContainer: UIView!

  // Overlay dimensions.
  private let overlayWidth: CGFloat = 400
  private let overlayHeight: CGFloat = 500
  private let cornerRadius: CGFloat = 20

  // Header elements.
  private let headerView = UIView()
  private let titleLabel = UILabel()
  private let closeButton = UIButton(type: .system)
  private let clearButton = UIButton(type: .system)

  // Glass background.
  private let glassView = UIVisualEffectView()

  // Header height.
  private let headerHeight: CGFloat = 48

  // Callbacks.
  var onClearTapped: (() -> Void)?

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureView()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func configureView() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = .clear
    layer.cornerRadius = cornerRadius
    layer.cornerCurve = .continuous
    clipsToBounds = true

    // Shadow on the main view.
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.2
    layer.shadowRadius = 16
    layer.shadowOffset = CGSize(width: 0, height: 8)

    setupGlassBackground()
    setupHeader()
    setupCanvasContainer()
    setupConstraints()
  }

  private func setupGlassBackground() {
    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.layer.cornerRadius = cornerRadius
    glassView.layer.cornerCurve = .continuous
    glassView.clipsToBounds = true

    // Apply unified liquid glass effect.
    applyLiquidGlassEffect(to: glassView, style: .regular)

    addSubview(glassView)
  }

  private func setupHeader() {
    headerView.translatesAutoresizingMaskIntoConstraints = false
    headerView.backgroundColor = .clear
    glassView.contentView.addSubview(headerView)

    // Title label.
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = "Notes"
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
    headerView.addSubview(titleLabel)

    // Close button.
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
    closeButton.tintColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
    closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    headerView.addSubview(closeButton)

    // Clear button.
    clearButton.translatesAutoresizingMaskIntoConstraints = false
    clearButton.setImage(UIImage(systemName: "trash"), for: .normal)
    clearButton.tintColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
    clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    headerView.addSubview(clearButton)

    // Separator line.
    let separator = UIView()
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.backgroundColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
    headerView.addSubview(separator)

    NSLayoutConstraint.activate([
      separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
      separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
      separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: 0.5)
    ])
  }

  private func setupCanvasContainer() {
    canvasContainer = UIView()
    canvasContainer.translatesAutoresizingMaskIntoConstraints = false
    canvasContainer.backgroundColor = .white
    canvasContainer.layer.cornerRadius = 8
    canvasContainer.clipsToBounds = true
    glassView.contentView.addSubview(canvasContainer)
  }

  private func setupConstraints() {
    NSLayoutConstraint.activate([
      // Fixed size.
      widthAnchor.constraint(equalToConstant: overlayWidth),
      heightAnchor.constraint(equalToConstant: overlayHeight),

      // Glass fills view.
      glassView.topAnchor.constraint(equalTo: topAnchor),
      glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
      glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
      glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

      // Header at top.
      headerView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor),
      headerView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor),
      headerView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor),
      headerView.heightAnchor.constraint(equalToConstant: headerHeight),

      // Title centered.
      titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

      // Close button left.
      closeButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
      closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
      closeButton.widthAnchor.constraint(equalToConstant: 32),
      closeButton.heightAnchor.constraint(equalToConstant: 32),

      // Clear button right.
      clearButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
      clearButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
      clearButton.widthAnchor.constraint(equalToConstant: 32),
      clearButton.heightAnchor.constraint(equalToConstant: 32),

      // Canvas container below header.
      canvasContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
      canvasContainer.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 12),
      canvasContainer.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -12),
      canvasContainer.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -12)
    ])
  }

  // MARK: - Actions

  @objc private func closeButtonTapped() {
    delegate?.notesOverlayDidRequestDismiss(self)
  }

  @objc private func clearButtonTapped() {
    onClearTapped?()
  }

  // MARK: - Layout

  // Override to ensure shadow path is updated for shadow rendering.
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.shadowPath = UIBezierPath(
      roundedRect: bounds,
      cornerRadius: cornerRadius
    ).cgPath
  }
}
