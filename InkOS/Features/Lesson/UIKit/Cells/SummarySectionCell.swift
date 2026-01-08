// SummarySectionCell.swift
// UICollectionViewCell displaying summary sections.

import UIKit

// Cell displaying a summary section with key takeaways.
// Styled with a distinct background to stand out.
final class SummarySectionCell: UICollectionViewCell {

  static let reuseIdentifier = "SummarySectionCell"

  // MARK: - UI Elements

  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0)
    view.layer.cornerRadius = 12
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let headerStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 8
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  private let iconView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(systemName: "lightbulb.fill")
    imageView.tintColor = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.text = "Key Takeaways"
    label.font = .systemFont(ofSize: 16, weight: .semibold)
    label.textColor = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let contentLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
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
    contentView.addSubview(containerView)
    containerView.addSubview(headerStack)
    containerView.addSubview(contentLabel)

    headerStack.addArrangedSubview(iconView)
    headerStack.addArrangedSubview(titleLabel)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
      containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

      headerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
      headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      headerStack.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),

      iconView.widthAnchor.constraint(equalToConstant: 20),
      iconView.heightAnchor.constraint(equalToConstant: 20),

      contentLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
      contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      contentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
      contentLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
    ])
  }

  // MARK: - Configuration

  func configure(with section: SummarySection) {
    contentLabel.attributedText = renderSummaryContent(section.content)
  }

  // Renders summary content with bullet point styling.
  private func renderSummaryContent(_ text: String) -> NSAttributedString {
    let result = NSMutableAttributedString()

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 4
    paragraphStyle.paragraphSpacing = 8

    let textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    let baseAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 15, weight: .regular),
      .foregroundColor: textColor,
      .paragraphStyle: paragraphStyle
    ]

    let lines = text.components(separatedBy: "\n")
    for (index, line) in lines.enumerated() {
      var processedLine = line

      // Convert bullet markers.
      if line.hasPrefix("- ") || line.hasPrefix("* ") {
        processedLine = "•  " + String(line.dropFirst(2))
      }

      result.append(NSAttributedString(string: processedLine, attributes: baseAttributes))

      if index < lines.count - 1 {
        result.append(NSAttributedString(string: "\n", attributes: baseAttributes))
      }
    }

    return result
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    contentLabel.attributedText = nil
  }
}
