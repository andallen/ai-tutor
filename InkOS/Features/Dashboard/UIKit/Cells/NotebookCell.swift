// Collection view cell for notebook cards.
// Wraps the existing NotebookCardView UIKit implementation.

import UIKit

// Delegate for notebook cell interactions.
// All positions are in window coordinates.
protocol NotebookCellDelegate: AnyObject {
  func notebookCellDidTap(_ cell: NotebookCell, notebook: NotebookMetadata)
  func notebookCellDidLongPress(_ cell: NotebookCell, notebook: NotebookMetadata, frame: CGRect, cardHeight: CGFloat)
  func notebookCellDidStartDrag(_ cell: NotebookCell, notebook: NotebookMetadata, frame: CGRect, position: CGPoint)
  func notebookCellDidMoveDrag(_ cell: NotebookCell, position: CGPoint)
  func notebookCellDidEndDrag(_ cell: NotebookCell, position: CGPoint)
}

class NotebookCell: UICollectionViewCell {
  static let reuseIdentifier = "NotebookCell"

  // The UIKit card view.
  private let cardView = NotebookCardView()

  // Current notebook being displayed.
  private(set) var notebook: NotebookMetadata?

  // Delegate for interaction callbacks.
  weak var delegate: NotebookCellDelegate?

  // Drop target visual state.
  private var isDropTarget = false
  private let dropTargetOverlay = UIView()

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

    // Setup drop target overlay (hidden by default).
    dropTargetOverlay.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.5)
    dropTargetOverlay.layer.cornerRadius = CardConstants.cornerRadius
    dropTargetOverlay.alpha = 0
    dropTargetOverlay.isUserInteractionEnabled = false
    dropTargetOverlay.translatesAutoresizingMaskIntoConstraints = false
    contentView.insertSubview(dropTargetOverlay, belowSubview: cardView)

    NSLayoutConstraint.activate([
      dropTargetOverlay.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -8),
      dropTargetOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: -8),
      dropTargetOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 8),
      dropTargetOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 8)
    ])
  }

  // Configures the cell with notebook data.
  func configure(with notebook: NotebookMetadata) {
    self.notebook = notebook
    cardView.configure(with: notebook)
  }

  // Shows or hides the drop target visual state.
  func setDropTargetActive(_ active: Bool, animated: Bool) {
    guard isDropTarget != active else { return }
    isDropTarget = active

    let targetAlpha: CGFloat = active ? 1.0 : 0.0
    let targetScale: CGFloat = active ? 0.82 : 1.0

    if animated {
      UIView.animate(
        withDuration: 0.3,
        delay: 0,
        usingSpringWithDamping: 0.7,
        initialSpringVelocity: 0,
        options: []
      ) {
        self.dropTargetOverlay.alpha = targetAlpha
        self.cardView.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
      }
    } else {
      dropTargetOverlay.alpha = targetAlpha
      cardView.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
    }
  }

  // Returns the card view for snapshot during drag.
  var cardViewForSnapshot: UIView {
    cardView
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    notebook = nil
    isDropTarget = false
    dropTargetOverlay.alpha = 0
    cardView.transform = .identity
  }
}

// MARK: - DashboardCardDelegate

extension NotebookCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    guard let notebook else { return }
    delegate?.notebookCellDidTap(self, notebook: notebook)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    guard let notebook else { return }
    delegate?.notebookCellDidLongPress(self, notebook: notebook, frame: frame, cardHeight: cardHeight)
  }

  func cardDidStartDrag(_ card: DashboardCardView, frame: CGRect, position: CGPoint) {
    guard let notebook else { return }
    delegate?.notebookCellDidStartDrag(self, notebook: notebook, frame: frame, position: position)
  }

  func cardDidMoveDrag(_ card: DashboardCardView, position: CGPoint) {
    delegate?.notebookCellDidMoveDrag(self, position: position)
  }

  func cardDidEndDrag(_ card: DashboardCardView, position: CGPoint) {
    delegate?.notebookCellDidEndDrag(self, position: position)
  }
}
