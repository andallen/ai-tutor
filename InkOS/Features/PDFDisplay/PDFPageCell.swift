// PDFPageCell.swift
// UICollectionViewCell subclass for displaying a single PDF page.

import PDFKit
import UIKit

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

  // The MyScript part identifier for this page's annotations.
  private(set) var myScriptPartID: String?

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
  // Accepts the shared PDFDocument and navigates to the specified page.
  func configure(
    document: PDFDocument,
    pageIndex: Int,
    uuid: UUID,
    myScriptPartID: String
  ) {
    // Store identifiers.
    self.pageIndex = pageIndex
    self.blockUUID = uuid
    self.myScriptPartID = myScriptPartID

    // Set shared document once (optimization).
    if pdfView.document !== document {
      pdfView.document = document
    }

    // Navigate to specific page.
    if let page = document.page(at: pageIndex) {
      pdfView.go(to: page)
    }
  }

  // Called when the cell is about to be reused.
  override func prepareForReuse() {
    super.prepareForReuse()
    // Don't nil out document (optimization for shared instance).
    // Clear identifiers.
    pageIndex = nil
    blockUUID = nil
    myScriptPartID = nil
    // Coordinator will handle removing MyScript views.
    overlayContainer.isUserInteractionEnabled = false
  }
}
