// PDFPageCell.swift
// UICollectionViewCell subclass for displaying a single PDF page.

import UIKit
import PDFKit

// UICollectionViewCell subclass for displaying a single PDF page.
// Contains a PDFView set to single-page mode with auto-scaling.
// User interaction is disabled on the PDFView to prevent internal scrolling.
// Contains an overlay container for future annotation layers.
class PDFPageCell: UICollectionViewCell, PDFPageCellProtocol {

  // Reuse identifier for dequeuing cells.
  static let reuseIdentifier = "PDFPageCell"

  // The PDFView that renders the PDF page.
  // displayMode = .singlePage, autoScales = true.
  // isUserInteractionEnabled = false to prevent internal scrolling.
  private(set) var pdfView: PDFView!

  // Transparent container view layered on top of PDFView.
  // Placeholder for future annotation overlays.
  // Does not intercept touches (passes through to collection view).
  private(set) var overlayContainer: UIView!

  // The zero-based page index in the original PDF.
  private(set) var pageIndex: Int?

  // The UUID of the NoteBlock this cell represents.
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

  // Sets up the PDF view and overlay container.
  private func setupSubviews() {
    // Create PDF view with required configuration.
    pdfView = PDFView()
    pdfView.translatesAutoresizingMaskIntoConstraints = false
    pdfView.displayMode = .singlePage
    pdfView.autoScales = true
    pdfView.isUserInteractionEnabled = false

    // Add PDF view to content view.
    contentView.addSubview(pdfView)

    // Create overlay container for future annotations.
    overlayContainer = UIView()
    overlayContainer.translatesAutoresizingMaskIntoConstraints = false
    overlayContainer.backgroundColor = .clear
    overlayContainer.isUserInteractionEnabled = false

    // Add overlay on top of PDF view.
    contentView.addSubview(overlayContainer)

    // Constrain both views to fill content view.
    NSLayoutConstraint.activate([
      pdfView.topAnchor.constraint(equalTo: contentView.topAnchor),
      pdfView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      pdfView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      pdfView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

      overlayContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
      overlayContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      overlayContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      overlayContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])

    // Set a white background for the content view.
    contentView.backgroundColor = .white
  }

  // Configures the cell to display a specific PDF page.
  func configure(page: PDFPage, pageIndex: Int, uuid: UUID) {
    // Store identifiers.
    self.pageIndex = pageIndex
    self.blockUUID = uuid

    // Create a document containing just this page and set it on the PDFView.
    // PDFView needs a PDFDocument, so we create one with the single page.
    let document = PDFDocument()
    document.insert(page, at: 0)
    pdfView.document = document
  }

  // Called when the cell is about to be reused.
  override func prepareForReuse() {
    super.prepareForReuse()
    // Clear PDFView document and stored identifiers.
    pdfView.document = nil
    pageIndex = nil
    blockUUID = nil
  }
}
