// Collection view cell for lesson cards.
// Wraps the LessonCardView UIKit implementation.

import UIKit

// Delegate for lesson cell interactions.
// All positions are in window coordinates.
protocol LessonCellDelegate: AnyObject {
  func lessonCellDidTap(_ cell: LessonCell, lesson: LessonMetadata)
  func lessonCellDidLongPress(_ cell: LessonCell, lesson: LessonMetadata, frame: CGRect, cardHeight: CGFloat)
}

class LessonCell: UICollectionViewCell {
  static let reuseIdentifier = "LessonCell"

  // The UIKit card view.
  private let cardView = LessonCardView()

  // Current lesson being displayed.
  private(set) var lesson: LessonMetadata?

  // Delegate for interaction callbacks.
  weak var delegate: LessonCellDelegate?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    contentView.backgroundColor = .clear
    backgroundColor = .clear

    // Add card view.
    cardView.translatesAutoresizingMaskIntoConstraints = false
    cardView.delegate = self
    contentView.addSubview(cardView)

    // Pin card view to cell bounds.
    NSLayoutConstraint.activate([
      cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
      cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])
  }

  // Configures the cell with lesson data.
  func configure(with lesson: LessonMetadata) {
    self.lesson = lesson
    cardView.configure(with: lesson)
  }

  // Returns the card view for snapshot during drag.
  var cardViewForSnapshot: UIView {
    cardView
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    lesson = nil
  }
}

// MARK: - DashboardCardDelegate

extension LessonCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    guard let lesson else { return }
    delegate?.lessonCellDidTap(self, lesson: lesson)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    guard let lesson else { return }
    delegate?.lessonCellDidLongPress(self, lesson: lesson, frame: frame, cardHeight: cardHeight)
  }

  func cardDidStartDrag(_ card: DashboardCardView, frame: CGRect, position: CGPoint) {
    // Lessons do not support drag-to-move.
  }

  func cardDidMoveDrag(_ card: DashboardCardView, position: CGPoint) {
    // Lessons do not support drag-to-move.
  }

  func cardDidEndDrag(_ card: DashboardCardView, position: CGPoint) {
    // Lessons do not support drag-to-move.
  }
}
