// ContentSectionCell.swift
// UICollectionViewCell displaying markdown content sections.
// Uses LessonTypography for consistent spacing and typography.

import UIKit

// Cell displaying markdown text content in a lesson.
// Renders markdown and LaTeX math using MathContentView.
final class ContentSectionCell: UICollectionViewCell {

  static let reuseIdentifier = "ContentSectionCell"

  // MARK: - UI Elements

  private let mathContentView: MathContentView = {
    let view = MathContentView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setupViews() {
    contentView.addSubview(mathContentView)

    NSLayoutConstraint.activate([
      mathContentView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LessonTypography.Spacing.sm),
      mathContentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      mathContentView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      mathContentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -LessonTypography.Spacing.sm)
    ])
  }

  // MARK: - Configuration

  func configure(with section: ContentSection) {
    mathContentView.fontSize = LessonTypography.Size.body
    mathContentView.textColor = LessonTypography.Color.primary
    mathContentView.configure(with: section.content)
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    mathContentView.clear()
  }
}
