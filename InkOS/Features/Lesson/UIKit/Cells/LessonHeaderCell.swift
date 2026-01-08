// LessonHeaderCell.swift
// UICollectionViewCell displaying the lesson title and subject.

import UIKit

// Cell displaying the lesson header with title and optional subject.
final class LessonHeaderCell: UICollectionViewCell {

  static let reuseIdentifier = "LessonHeaderCell"

  // MARK: - UI Elements

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 28, weight: .bold)
    label.textColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let subjectLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 14, weight: .medium)
    label.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    label.numberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
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
    contentView.addSubview(titleLabel)
    contentView.addSubview(subjectLabel)

    NSLayoutConstraint.activate([
      // Subject label at top.
      subjectLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
      subjectLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      subjectLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

      // Title label below subject.
      titleLabel.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: 4),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])
  }

  // MARK: - Configuration

  func configure(title: String, subject: String?) {
    titleLabel.text = title
    subjectLabel.text = subject?.uppercased()
    subjectLabel.isHidden = subject == nil
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    titleLabel.text = nil
    subjectLabel.text = nil
    subjectLabel.isHidden = true
  }
}
