// Collection view cell for PDF document cards.
// Wraps the existing PDFCardView UIKit implementation.

import UIKit

// Delegate for PDF cell interactions.
protocol PDFDocumentCellDelegate: AnyObject {
  func pdfCellDidTap(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata)
  func pdfCellDidLongPress(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata, frame: CGRect, cardHeight: CGFloat)
  func pdfCellMenu(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata) -> UIMenu?
}

// Default implementation for optional menu method.
extension PDFDocumentCellDelegate {
  func pdfCellMenu(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata) -> UIMenu? { nil }
}

class PDFDocumentCell: UICollectionViewCell {
  static let reuseIdentifier = "PDFDocumentCell"

  // The UIKit card view.
  private let cardView = PDFCardView()

  // Current PDF being displayed.
  private(set) var pdfDocument: PDFDocumentMetadata?

  // Delegate for interaction callbacks.
  weak var delegate: PDFDocumentCellDelegate?

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
      guard let self, let pdf = self.pdfDocument else { return nil }
      return self.delegate?.pdfCellMenu(self, pdf: pdf)
    }
  }

  // Configures the cell with PDF document data.
  func configure(with pdfDocument: PDFDocumentMetadata) {
    self.pdfDocument = pdfDocument
    cardView.configure(with: pdfDocument)

    // Set accessibility identifier for UI testing.
    accessibilityIdentifier = "pdfCard_\(pdfDocument.id)"
    isAccessibilityElement = true
    accessibilityLabel = "PDF: \(pdfDocument.displayName)"
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    pdfDocument = nil
    // Reset any lift animation.
    cardView.animateLift(false)
  }

  // Resets the lift animation after action sheet dismisses.
  func resetLiftAnimation() {
    cardView.animateLift(false)
  }
}

// MARK: - DashboardCardDelegate

extension PDFDocumentCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    print("[PDFDocumentCell] cardDidTap called")
    guard let pdfDocument else {
      print("[PDFDocumentCell] cardDidTap - no pdfDocument, returning")
      return
    }
    print("[PDFDocumentCell] cardDidTap - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.pdfCellDidTap(self, pdf: pdfDocument)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    print("[PDFDocumentCell] cardDidLongPress called, frame=\(frame), cardHeight=\(cardHeight)")
    guard let pdfDocument else {
      print("[PDFDocumentCell] cardDidLongPress - no pdfDocument, returning")
      return
    }
    print("[PDFDocumentCell] cardDidLongPress - pdf=\(pdfDocument.displayName)")
    print("[PDFDocumentCell] cardDidLongPress - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.pdfCellDidLongPress(self, pdf: pdfDocument, frame: frame, cardHeight: cardHeight)
    print("[PDFDocumentCell] cardDidLongPress - delegate notified")
  }
}
