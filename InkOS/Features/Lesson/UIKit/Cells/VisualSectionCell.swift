// VisualSectionCell.swift
// UICollectionViewCell displaying visual content sections.
// Uses LessonTypography for consistent visual design.

import UIKit

// Cell displaying visual content (images, interactive elements) in a lesson.
// Shows a placeholder when image is not yet generated.
final class VisualSectionCell: UICollectionViewCell {

  static let reuseIdentifier = "VisualSectionCell"

  // MARK: - UI Elements

  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = LessonTypography.Color.cardBackground
    view.layer.cornerRadius = LessonTypography.CornerRadius.medium
    view.layer.borderWidth = 1
    view.layer.borderColor = LessonTypography.Color.border.cgColor
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let iconView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(systemName: "photo")
    imageView.tintColor = LessonTypography.Color.tertiary
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private let descriptionLabel: UILabel = {
    let label = UILabel()
    label.font = LessonTypography.font(size: LessonTypography.Size.caption, weight: .medium)
    label.textColor = LessonTypography.Color.secondary
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let typeLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  // Constraint for container height.
  private var containerHeightConstraint: NSLayoutConstraint!

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
    containerView.addSubview(iconView)
    containerView.addSubview(descriptionLabel)
    containerView.addSubview(typeLabel)

    containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: 200)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LessonTypography.Spacing.sm),
      containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -LessonTypography.Spacing.sm),
      containerHeightConstraint,

      iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -LessonTypography.Spacing.lg),
      iconView.widthAnchor.constraint(equalToConstant: 48),
      iconView.heightAnchor.constraint(equalToConstant: 48),

      descriptionLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: LessonTypography.Spacing.md),
      descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: LessonTypography.Spacing.lg),
      descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),

      typeLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: LessonTypography.Spacing.xs),
      typeLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
    ])
  }

  // MARK: - Configuration

  func configure(with section: VisualSection) {
    // Set description text.
    if let description = section.fallbackDescription {
      descriptionLabel.text = description
    } else if let prompt = section.imagePrompt {
      descriptionLabel.text = prompt
    } else {
      descriptionLabel.text = "Visual content"
    }

    // Set type label with overline styling.
    let typeText: String
    let icon: String

    switch section.visualType {
    case .generated:
      typeText = "GENERATED IMAGE"
      icon = "photo"
    case .interactive:
      typeText = "INTERACTIVE"
      icon = "hand.tap"
    }

    iconView.image = UIImage(systemName: icon)

    let typeAttributes: [NSAttributedString.Key: Any] = [
      .font: LessonTypography.font(size: LessonTypography.Size.overline, weight: .semibold),
      .foregroundColor: LessonTypography.Color.tertiary,
      .kern: 1.0
    ]
    typeLabel.attributedText = NSAttributedString(string: typeText, attributes: typeAttributes)
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    descriptionLabel.text = nil
    typeLabel.attributedText = nil
    iconView.image = UIImage(systemName: "photo")
  }
}
