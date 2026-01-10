// Collection view cell for folder cards.
// Wraps the FolderCardView UIKit implementation.

import UIKit

// Delegate for folder cell interactions.
protocol FolderCellDelegate: AnyObject {
  func folderCellDidTap(_ cell: FolderCell, folder: FolderMetadata)
  func folderCellDidLongPress(_ cell: FolderCell, folder: FolderMetadata, frame: CGRect, cardHeight: CGFloat)
  func folderCellMenu(_ cell: FolderCell, folder: FolderMetadata) -> UIMenu?
}

// Default implementation for optional menu method.
extension FolderCellDelegate {
  func folderCellMenu(_ cell: FolderCell, folder: FolderMetadata) -> UIMenu? { nil }
}

class FolderCell: UICollectionViewCell {
  static let reuseIdentifier = "FolderCell"

  // The UIKit card view.
  private let cardView = FolderCardView()

  // Current folder being displayed.
  private(set) var folder: FolderMetadata?

  // Delegate for interaction callbacks.
  weak var delegate: FolderCellDelegate?

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
      guard let self, let folder = self.folder else { return nil }
      return self.delegate?.folderCellMenu(self, folder: folder)
    }
  }

  // Configures the cell with folder data and thumbnails.
  func configure(with folder: FolderMetadata, thumbnails: [UIImage]) {
    self.folder = folder
    cardView.configure(with: folder, thumbnails: thumbnails)

    // Set accessibility identifier for UI testing.
    accessibilityIdentifier = "folderCard_\(folder.id)"
    isAccessibilityElement = true
    accessibilityLabel = "Folder: \(folder.displayName)"
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    folder = nil
    cardView.prepareForReuse()
    // Reset any lift animation.
    cardView.animateLift(false)
  }

  // Resets the lift animation after action sheet dismisses.
  func resetLiftAnimation() {
    cardView.animateLift(false)
  }
}

// MARK: - DashboardCardDelegate

extension FolderCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    print("[FolderCell] cardDidTap called")
    guard let folder else {
      print("[FolderCell] cardDidTap - no folder, returning")
      return
    }
    print("[FolderCell] cardDidTap - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.folderCellDidTap(self, folder: folder)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    print("[FolderCell] cardDidLongPress called, frame=\(frame), cardHeight=\(cardHeight)")
    guard let folder else {
      print("[FolderCell] cardDidLongPress - no folder, returning")
      return
    }
    print("[FolderCell] cardDidLongPress - folder=\(folder.displayName)")
    print("[FolderCell] cardDidLongPress - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.folderCellDidLongPress(self, folder: folder, frame: frame, cardHeight: cardHeight)
    print("[FolderCell] cardDidLongPress - delegate notified")
  }
}
