// Collection view cell for lesson cards.
// Wraps the LessonCardView UIKit implementation.

import UIKit

// Delegate for lesson cell interactions.
// All positions are in window coordinates.
protocol LessonCellDelegate: AnyObject {
  func lessonCellDidTap(_ cell: LessonCell, lesson: LessonMetadata)
  func lessonCellDidLongPress(_ cell: LessonCell, lesson: LessonMetadata, frame: CGRect, cardHeight: CGFloat)
  func lessonCellMenu(_ cell: LessonCell, lesson: LessonMetadata) -> UIMenu?
}

// Default implementation for optional menu method.
extension LessonCellDelegate {
  func lessonCellMenu(_ cell: LessonCell, lesson: LessonMetadata) -> UIMenu? { nil }
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

    // Set up menu provider for long press.
    cardView.menuProvider = { [weak self] in
      guard let self, let lesson = self.lesson else { return nil }
      return self.delegate?.lessonCellMenu(self, lesson: lesson)
    }
  }

  // Configures the cell with lesson data.
  func configure(with lesson: LessonMetadata) {
    self.lesson = lesson
    cardView.configure(with: lesson)

    // Set accessibility identifier for UI testing.
    accessibilityIdentifier = "lessonCard_\(lesson.id)"
    isAccessibilityElement = true
    accessibilityLabel = "Lesson: \(lesson.displayName)"
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    lesson = nil
    // Reset any lift animation.
    cardView.animateLift(false)
  }

  // Resets the lift animation after action sheet dismisses.
  func resetLiftAnimation() {
    cardView.animateLift(false)
  }
}

// MARK: - DashboardCardDelegate

extension LessonCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    print("[LessonCell] cardDidTap called")
    guard let lesson else {
      print("[LessonCell] cardDidTap - no lesson, returning")
      return
    }
    print("[LessonCell] cardDidTap - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.lessonCellDidTap(self, lesson: lesson)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    print("[LessonCell] cardDidLongPress called, frame=\(frame), cardHeight=\(cardHeight)")
    guard let lesson else {
      print("[LessonCell] cardDidLongPress - no lesson, returning")
      return
    }
    print("[LessonCell] cardDidLongPress - lesson=\(lesson.displayName)")
    print("[LessonCell] cardDidLongPress - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.lessonCellDidLongPress(self, lesson: lesson, frame: frame, cardHeight: cardHeight)
    print("[LessonCell] cardDidLongPress - delegate notified")
  }
}
