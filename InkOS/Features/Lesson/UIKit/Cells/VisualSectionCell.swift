// VisualSectionCell.swift
// UICollectionViewCell displaying visual content sections.

import UIKit

// Cell displaying visual content (images, interactive elements) in a lesson.
// Shows a placeholder when image is not yet generated.
final class VisualSectionCell: UICollectionViewCell {

  static let reuseIdentifier = "VisualSectionCell"

  // MARK: - UI Elements

  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
    view.layer.cornerRadius = 12
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let iconView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(systemName: "photo")
    imageView.tintColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private let descriptionLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 14, weight: .medium)
    label.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let typeLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 11, weight: .semibold)
    label.textColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
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
      containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
      containerHeightConstraint,

      iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -24),
      iconView.widthAnchor.constraint(equalToConstant: 48),
      iconView.heightAnchor.constraint(equalToConstant: 48),

      descriptionLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
      descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
      descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

      typeLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 8),
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

    // Set type label.
    switch section.visualType {
    case .generated:
      typeLabel.text = "GENERATED IMAGE"
      iconView.image = UIImage(systemName: "photo")
    case .interactive:
      typeLabel.text = "INTERACTIVE"
      iconView.image = UIImage(systemName: "hand.tap")
    }
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    descriptionLabel.text = nil
    typeLabel.text = nil
    iconView.image = UIImage(systemName: "photo")
  }
}
