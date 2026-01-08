// Collection view cell for PDF document cards.
// Wraps the existing PDFCardView UIKit implementation.

import UIKit

// Delegate for PDF cell interactions.
// All positions are in window coordinates.
protocol PDFDocumentCellDelegate: AnyObject {
  func pdfCellDidTap(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata)
  func pdfCellDidLongPress(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata, frame: CGRect, cardHeight: CGFloat)
  func pdfCellDidStartDrag(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata, frame: CGRect, position: CGPoint)
  func pdfCellDidMoveDrag(_ cell: PDFDocumentCell, position: CGPoint)
  func pdfCellDidEndDrag(_ cell: PDFDocumentCell, position: CGPoint)
}

class PDFDocumentCell: UICollectionViewCell {
  static let reuseIdentifier = "PDFDocumentCell"

  // The UIKit card view.
  private let cardView = PDFCardView()

  // Current PDF being displayed.
  private(set) var pdfDocument: PDFDocumentMetadata?

  // Delegate for interaction callbacks.
  weak var delegate: PDFDocumentCellDelegate?

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

  // Configures the cell with PDF document data.
  func configure(with pdfDocument: PDFDocumentMetadata) {
    self.pdfDocument = pdfDocument
    cardView.configure(with: pdfDocument)
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
    pdfDocument = nil
    isDropTarget = false
    dropTargetOverlay.alpha = 0
    cardView.transform = .identity
  }
}

// MARK: - DashboardCardDelegate

extension PDFDocumentCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    guard let pdfDocument else { return }
    delegate?.pdfCellDidTap(self, pdf: pdfDocument)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    guard let pdfDocument else { return }
    delegate?.pdfCellDidLongPress(self, pdf: pdfDocument, frame: frame, cardHeight: cardHeight)
  }

  func cardDidStartDrag(_ card: DashboardCardView, frame: CGRect, position: CGPoint) {
    guard let pdfDocument else { return }
    delegate?.pdfCellDidStartDrag(self, pdf: pdfDocument, frame: frame, position: position)
  }

  func cardDidMoveDrag(_ card: DashboardCardView, position: CGPoint) {
    delegate?.pdfCellDidMoveDrag(self, position: position)
  }

  func cardDidEndDrag(_ card: DashboardCardView, position: CGPoint) {
    delegate?.pdfCellDidEndDrag(self, position: position)
  }
}
