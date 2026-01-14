// LessonHeaderCell.swift
// UICollectionViewCell displaying the lesson title and subject.
// Uses LessonTypography for consistent visual hierarchy.

import UIKit

// Cell displaying the lesson header with title and optional subject.
// Features a prominent title with an overline subject label for visual hierarchy.
final class LessonHeaderCell: UICollectionViewCell {

  static let reuseIdentifier = "LessonHeaderCell"

  // MARK: - UI Elements

  // Overline label for subject/category (uppercase, letter-spaced).
  private let subjectLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  // Main title label using rounded font for approachable feel.
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.font = LessonTypography.roundedFont(size: LessonTypography.Size.h1, weight: .bold)
    label.textColor = LessonTypography.Color.primary
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  // Decorative accent line below the header.
  private let accentLine: UIView = {
    let view = UIView()
    view.backgroundColor = LessonTypography.Color.accent
    view.layer.cornerRadius = 2
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
    contentView.addSubview(subjectLabel)
    contentView.addSubview(titleLabel)
    contentView.addSubview(accentLine)

    NSLayoutConstraint.activate([
      // Subject label at top (overline style).
      subjectLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
      subjectLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      subjectLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

      // Title label below subject with proper spacing.
      titleLabel.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: LessonTypography.Spacing.xs),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

      // Accent line below title.
      accentLine.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: LessonTypography.Spacing.lg),
      accentLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      accentLine.widthAnchor.constraint(equalToConstant: 48),
      accentLine.heightAnchor.constraint(equalToConstant: 4),
      accentLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])
  }

  // MARK: - Configuration

  func configure(title: String, subject: String?) {
    // Configure title.
    titleLabel.text = title

    // Configure subject with overline styling (uppercase, letter-spaced).
    if let subject = subject {
      let attributes: [NSAttributedString.Key: Any] = [
        .font: LessonTypography.font(size: LessonTypography.Size.overline, weight: .semibold),
        .foregroundColor: LessonTypography.Color.accent,
        .kern: 1.5
      ]
      subjectLabel.attributedText = NSAttributedString(string: subject.uppercased(), attributes: attributes)
      subjectLabel.isHidden = false
    } else {
      subjectLabel.isHidden = true
    }
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    titleLabel.text = nil
    subjectLabel.attributedText = nil
    subjectLabel.isHidden = true
  }
}
