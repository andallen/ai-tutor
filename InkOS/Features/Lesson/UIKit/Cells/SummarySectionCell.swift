// SummarySectionCell.swift
// UICollectionViewCell displaying summary sections.
// Uses LessonTypography for consistent visual design.

import UIKit

// Cell displaying a summary section with key takeaways.
// Styled with a distinct background to stand out from regular content.
final class SummarySectionCell: UICollectionViewCell {

  static let reuseIdentifier = "SummarySectionCell"

  // MARK: - UI Elements

  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = LessonTypography.Color.summaryBackground
    view.layer.cornerRadius = LessonTypography.CornerRadius.medium
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  // Left accent bar for visual distinction.
  private let accentBar: UIView = {
    let view = UIView()
    view.backgroundColor = LessonTypography.Color.accent
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let headerStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = LessonTypography.Spacing.xs
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  private let iconView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(systemName: "lightbulb.fill")
    imageView.tintColor = LessonTypography.Color.accent
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let mathContentView: MathContentView = {
    let view = MathContentView()
    view.fontSize = LessonTypography.Size.body
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
    contentView.addSubview(containerView)
    containerView.addSubview(accentBar)
    containerView.addSubview(headerStack)
    containerView.addSubview(mathContentView)

    headerStack.addArrangedSubview(iconView)
    headerStack.addArrangedSubview(titleLabel)

    // Configure title with letter spacing.
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: LessonTypography.font(size: LessonTypography.Size.caption, weight: .semibold),
      .foregroundColor: LessonTypography.Color.accent,
      .kern: 0.5
    ]
    titleLabel.attributedText = NSAttributedString(string: "Key Takeaways", attributes: titleAttributes)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LessonTypography.Spacing.lg),
      containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -LessonTypography.Spacing.sm),

      accentBar.topAnchor.constraint(equalTo: containerView.topAnchor),
      accentBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      accentBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      accentBar.widthAnchor.constraint(equalToConstant: 4),

      headerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: LessonTypography.Spacing.lg),
      headerStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: LessonTypography.Spacing.lg),
      headerStack.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),

      iconView.widthAnchor.constraint(equalToConstant: 20),
      iconView.heightAnchor.constraint(equalToConstant: 20),

      mathContentView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: LessonTypography.Spacing.md),
      mathContentView.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: LessonTypography.Spacing.lg),
      mathContentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),
      mathContentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -LessonTypography.Spacing.lg)
    ])
  }

  // MARK: - Configuration

  func configure(with section: SummarySection) {
    mathContentView.textColor = LessonTypography.Color.primary
    mathContentView.configure(with: section.content)
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    mathContentView.clear()
  }
}
