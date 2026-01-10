// Collection view cell for items inside the folder overlay.
// Displays notebooks and PDFs with tap and context menu support.

import UIKit

// Delegate for folder overlay cell interactions.
protocol FolderOverlayCellDelegate: AnyObject {
  func folderOverlayCellDidTapNotebook(_ cell: FolderOverlayCell, notebook: NotebookMetadata)
  func folderOverlayCellDidTapPDF(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata)

  // Context menu action callbacks.
  func folderOverlayCellDidRequestRename(_ cell: FolderOverlayCell, notebook: NotebookMetadata)
  func folderOverlayCellDidRequestRename(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata)
  func folderOverlayCellDidRequestDelete(_ cell: FolderOverlayCell, notebook: NotebookMetadata)
  func folderOverlayCellDidRequestDelete(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata)
  func folderOverlayCellDidRequestMoveToRoot(_ cell: FolderOverlayCell, notebook: NotebookMetadata)
  func folderOverlayCellDidRequestMoveToRoot(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata)
}

class FolderOverlayCell: UICollectionViewCell {
  static let reuseIdentifier = "FolderOverlayCell"

  // Current item type.
  private enum ItemType {
    case notebook(NotebookMetadata)
    case pdf(PDFDocumentMetadata)
    case none
  }
  private var itemType: ItemType = .none

  // Delegate for interactions.
  weak var delegate: FolderOverlayCellDelegate?

  // Card preview container.
  private let previewContainer = UIView()
  private let previewImageView = UIImageView()

  // Placeholder for PDFs without preview.
  private let placeholderImageView = UIImageView()

  // Title labels.
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()

  // Gesture recognizers.
  private var tapRecognizer: UITapGestureRecognizer!

  // Context menu interaction.
  private var contextMenuInteraction: UIContextMenuInteraction?

  // Date formatter for notebook subtitles.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a  MM/dd/yy"
    return formatter
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
    setupGestureRecognizers()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    contentView.backgroundColor = .clear
    backgroundColor = .clear

    // Preview container with shadow.
    previewContainer.backgroundColor = .clear
    previewContainer.layer.cornerRadius = CardConstants.cornerRadius
    previewContainer.layer.shadowColor = UIColor.black.cgColor
    previewContainer.layer.shadowOpacity = 0.14
    previewContainer.layer.shadowRadius = 7
    previewContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
    previewContainer.clipsToBounds = false
    contentView.addSubview(previewContainer)

    // Preview image.
    previewImageView.contentMode = .scaleAspectFill
    previewImageView.clipsToBounds = true
    previewImageView.layer.cornerRadius = CardConstants.cornerRadius
    previewImageView.backgroundColor = .white
    previewContainer.addSubview(previewImageView)

    // Placeholder icon for PDFs.
    placeholderImageView.image = UIImage(systemName: "doc.richtext")
    placeholderImageView.tintColor = .systemBlue
    placeholderImageView.contentMode = .scaleAspectFit
    placeholderImageView.isHidden = true
    previewImageView.addSubview(placeholderImageView)

    // Title label.
    titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    titleLabel.textColor = UIColor.black.withAlphaComponent(0.88)
    titleLabel.lineBreakMode = .byTruncatingTail
    contentView.addSubview(titleLabel)

    // Subtitle label.
    subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
    subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.62)
    subtitleLabel.lineBreakMode = .byTruncatingTail
    contentView.addSubview(subtitleLabel)
  }

  private func setupGestureRecognizers() {
    tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    contentView.addGestureRecognizer(tapRecognizer)

    // Add context menu interaction for long-press.
    contextMenuInteraction = UIContextMenuInteraction(delegate: self)
    contentView.addInteraction(contextMenuInteraction!)
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let width = contentView.bounds.width
    let height = contentView.bounds.height
    let previewHeight = height - CardConstants.titleAreaHeight

    // Preview container.
    previewContainer.frame = CGRect(x: 0, y: 0, width: width, height: previewHeight)
    previewImageView.frame = previewContainer.bounds

    // Update shadow path for performance.
    previewContainer.layer.shadowPath = UIBezierPath(
      roundedRect: previewContainer.bounds,
      cornerRadius: CardConstants.cornerRadius
    ).cgPath

    // Placeholder icon centered in preview.
    let iconSize: CGFloat = 36
    placeholderImageView.frame = CGRect(
      x: (previewImageView.bounds.width - iconSize) / 2,
      y: (previewImageView.bounds.height - iconSize) / 2,
      width: iconSize,
      height: iconSize
    )

    // Title labels.
    let titleY = previewHeight + 4
    let titleWidth = width - 4
    titleLabel.frame = CGRect(x: 2, y: titleY, width: titleWidth, height: 17)
    subtitleLabel.frame = CGRect(x: 2, y: titleY + 17 + 1, width: titleWidth, height: 14)
  }

  // MARK: - Configuration

  // Configures the cell as a notebook.
  func configureAsNotebook(_ notebook: NotebookMetadata) {
    itemType = .notebook(notebook)

    // Preview image.
    let previewImage = notebook.previewImageData.flatMap { UIImage(data: $0) }
    previewImageView.image = previewImage
    previewImageView.backgroundColor = .white
    placeholderImageView.isHidden = true

    // Title.
    titleLabel.text = notebook.displayName

    // Subtitle (last accessed date).
    if let lastAccessed = notebook.lastAccessedAt {
      subtitleLabel.text = Self.dateFormatter.string(from: lastAccessed)
      subtitleLabel.isHidden = false
    } else {
      subtitleLabel.isHidden = true
    }
  }

  // Configures the cell as a PDF.
  func configureAsPDF(_ pdf: PDFDocumentMetadata) {
    itemType = .pdf(pdf)

    // Preview image or placeholder.
    let previewImage = pdf.previewImageData.flatMap { UIImage(data: $0) }
    previewImageView.image = previewImage
    previewImageView.backgroundColor = UIColor.systemGray5
    placeholderImageView.isHidden = previewImage != nil

    // Title.
    titleLabel.text = pdf.displayName

    // Subtitle (page count).
    let pageText = pdf.pageCount == 1 ? "1 page" : "\(pdf.pageCount) pages"
    subtitleLabel.text = pageText
    subtitleLabel.isHidden = false
  }

  // MARK: - Gesture Handler

  @objc private func handleTap() {
    switch itemType {
    case .notebook(let notebook):
      delegate?.folderOverlayCellDidTapNotebook(self, notebook: notebook)
    case .pdf(let pdf):
      delegate?.folderOverlayCellDidTapPDF(self, pdf: pdf)
    case .none:
      break
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    itemType = .none
    previewImageView.image = nil
    placeholderImageView.isHidden = true
  }
}

// MARK: - UIContextMenuInteractionDelegate

extension FolderOverlayCell: UIContextMenuInteractionDelegate {
  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
      guard let self else { return nil }
      return self.buildContextMenu()
    }
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    // Use the preview container for the lift animation.
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    parameters.visiblePath = UIBezierPath(
      roundedRect: previewContainer.bounds,
      cornerRadius: CardConstants.cornerRadius
    )
    return UITargetedPreview(view: previewContainer, parameters: parameters)
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    parameters.visiblePath = UIBezierPath(
      roundedRect: previewContainer.bounds,
      cornerRadius: CardConstants.cornerRadius
    )
    return UITargetedPreview(view: previewContainer, parameters: parameters)
  }

  private func buildContextMenu() -> UIMenu {
    switch itemType {
    case .notebook(let notebook):
      return buildNotebookMenu(notebook)
    case .pdf(let pdf):
      return buildPDFMenu(pdf)
    case .none:
      return UIMenu(children: [])
    }
  }

  private func buildNotebookMenu(_ notebook: NotebookMetadata) -> UIMenu {
    let renameAction = UIAction(
      title: "Rename",
      image: UIImage(systemName: "pencil")
    ) { [weak self] _ in
      guard let self else { return }
      self.delegate?.folderOverlayCellDidRequestRename(self, notebook: notebook)
    }

    let moveOutAction = UIAction(
      title: "Move Out of Folder",
      image: UIImage(systemName: "folder.badge.minus")
    ) { [weak self] _ in
      guard let self else { return }
      self.delegate?.folderOverlayCellDidRequestMoveToRoot(self, notebook: notebook)
    }

    let deleteAction = UIAction(
      title: "Delete",
      image: UIImage(systemName: "trash"),
      attributes: .destructive
    ) { [weak self] _ in
      guard let self else { return }
      self.delegate?.folderOverlayCellDidRequestDelete(self, notebook: notebook)
    }

    return UIMenu(children: [renameAction, moveOutAction, deleteAction])
  }

  private func buildPDFMenu(_ pdf: PDFDocumentMetadata) -> UIMenu {
    let renameAction = UIAction(
      title: "Rename",
      image: UIImage(systemName: "pencil")
    ) { [weak self] _ in
      guard let self else { return }
      self.delegate?.folderOverlayCellDidRequestRename(self, pdf: pdf)
    }

    let moveOutAction = UIAction(
      title: "Move Out of Folder",
      image: UIImage(systemName: "folder.badge.minus")
    ) { [weak self] _ in
      guard let self else { return }
      self.delegate?.folderOverlayCellDidRequestMoveToRoot(self, pdf: pdf)
    }

    let deleteAction = UIAction(
      title: "Delete",
      image: UIImage(systemName: "trash"),
      attributes: .destructive
    ) { [weak self] _ in
      guard let self else { return }
      self.delegate?.folderOverlayCellDidRequestDelete(self, pdf: pdf)
    }

    return UIMenu(children: [renameAction, moveOutAction, deleteAction])
  }
}
