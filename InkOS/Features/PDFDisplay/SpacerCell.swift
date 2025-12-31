// SpacerCell.swift
// UICollectionViewCell subclass for displaying writing spacer blocks.

import UIKit

// UICollectionViewCell subclass for displaying writing spacer blocks.
// Contains a DottedGridView that fills the content view.
// Cell height is determined by UICollectionView layout, not the cell itself.
class SpacerCell: UICollectionViewCell, SpacerCellProtocol {

  // Reuse identifier for dequeuing cells.
  static let reuseIdentifier = "SpacerCell"

  // The dotted grid background view.
  private(set) var dottedGridView: DottedGridView!

  // The UUID of the NoteBlock this cell represents.
  // Used for tracking which spacer this cell displays.
  private(set) var blockUUID: UUID?

  // Called when the cell is dequeued from the reuse pool.
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupSubviews()
  }

  // Required initializer for Interface Builder.
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupSubviews()
  }

  // Sets up the dotted grid view to fill the content view.
  private func setupSubviews() {
    // Create dotted grid view.
    dottedGridView = DottedGridView()
    dottedGridView.translatesAutoresizingMaskIntoConstraints = false

    // Add to content view.
    contentView.addSubview(dottedGridView)

    // Constrain to fill content view.
    NSLayoutConstraint.activate([
      dottedGridView.topAnchor.constraint(equalTo: contentView.topAnchor),
      dottedGridView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      dottedGridView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      dottedGridView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])

    // Set a light background color behind the grid.
    contentView.backgroundColor = .white
  }

  // Configures the cell for a specific spacer block.
  func configure(height: CGFloat, uuid: UUID) {
    // Store the block UUID for identification.
    blockUUID = uuid
    // Height is managed by layout, not stored here.
  }

  // Called when the cell is about to be reused.
  override func prepareForReuse() {
    super.prepareForReuse()
    // Clear block UUID for clean reuse.
    blockUUID = nil
  }
}
