// Collection view cell for folder cards.
// Wraps the FolderCardView UIKit implementation.

import UIKit

// Delegate for folder cell interactions.
protocol FolderCellDelegate: AnyObject {
  func folderCellDidTap(_ cell: FolderCell, folder: FolderMetadata)
  func folderCellDidLongPress(_ cell: FolderCell, folder: FolderMetadata, frame: CGRect, cardHeight: CGFloat)
}

class FolderCell: UICollectionViewCell {
  static let reuseIdentifier = "FolderCell"

  // The UIKit card view.
  private let cardView = FolderCardView()

  // Current folder being displayed.
  private(set) var folder: FolderMetadata?

  // Delegate for interaction callbacks.
  weak var delegate: FolderCellDelegate?

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

  // Configures the cell with folder data and thumbnails.
  func configure(with folder: FolderMetadata, thumbnails: [UIImage]) {
    self.folder = folder
    cardView.configure(with: folder, thumbnails: thumbnails)
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
    folder = nil
    isDropTarget = false
    dropTargetOverlay.alpha = 0
    cardView.transform = .identity
    cardView.prepareForReuse()
  }
}

// MARK: - DashboardCardDelegate

extension FolderCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    guard let folder else { return }
    delegate?.folderCellDidTap(self, folder: folder)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    guard let folder else { return }
    delegate?.folderCellDidLongPress(self, folder: folder, frame: frame, cardHeight: cardHeight)
  }

  // Folders don't support drag, so these are no-ops.
  func cardDidStartDrag(_ card: DashboardCardView, frame: CGRect, position: CGPoint) {}
  func cardDidMoveDrag(_ card: DashboardCardView, position: CGPoint) {}
  func cardDidEndDrag(_ card: DashboardCardView, position: CGPoint) {}
}
