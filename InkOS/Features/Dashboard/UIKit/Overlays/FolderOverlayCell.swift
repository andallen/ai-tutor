// Collection view cell for items inside the folder overlay.
// Displays notebooks and PDFs with tap and long press support.

import UIKit

// Delegate for folder overlay cell interactions.
protocol FolderOverlayCellDelegate: AnyObject {
  func folderOverlayCellDidTapNotebook(_ cell: FolderOverlayCell, notebook: NotebookMetadata)
  func folderOverlayCellDidTapPDF(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata)
  func folderOverlayCellDidLongPress(_ cell: FolderOverlayCell, frame: CGRect, cardHeight: CGFloat)
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
  private let dimOverlay = UIView()
  private let sweepLayer = CAGradientLayer()

  // Placeholder for PDFs without preview.
  private let placeholderImageView = UIImageView()

  // Title labels.
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()

  // Gesture recognizers.
  private var tapRecognizer: UITapGestureRecognizer!
  private var longPressRecognizer: UILongPressGestureRecognizer!

  // Date formatter for notebook subtitles.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a  MM/dd/yy"
    return formatter
  }()

  // Gesture state.
  private var longPressTriggered = false

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

    // Dim overlay for press feedback.
    dimOverlay.backgroundColor = .black
    dimOverlay.alpha = 0
    dimOverlay.layer.cornerRadius = CardConstants.cornerRadius
    dimOverlay.clipsToBounds = true
    dimOverlay.isUserInteractionEnabled = false
    previewContainer.addSubview(dimOverlay)

    // Sweep gradient layer.
    sweepLayer.colors = [
      UIColor.white.withAlphaComponent(0.0).cgColor,
      UIColor.white.withAlphaComponent(0.45).cgColor,
      UIColor.white.withAlphaComponent(0.75).cgColor,
      UIColor.white.withAlphaComponent(0.0).cgColor
    ]
    sweepLayer.locations = [0.0, 0.45, 0.55, 1.0]
    sweepLayer.startPoint = CGPoint(x: 0, y: 0.5)
    sweepLayer.endPoint = CGPoint(x: 1, y: 0.5)
    sweepLayer.opacity = 0
    sweepLayer.cornerRadius = CardConstants.cornerRadius
    sweepLayer.masksToBounds = true
    previewContainer.layer.addSublayer(sweepLayer)

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

    longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    longPressRecognizer.minimumPressDuration = CardConstants.longPressDelay
    contentView.addGestureRecognizer(longPressRecognizer)

    tapRecognizer.require(toFail: longPressRecognizer)
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let width = contentView.bounds.width
    let height = contentView.bounds.height
    let previewHeight = height - CardConstants.titleAreaHeight

    // Preview container.
    previewContainer.frame = CGRect(x: 0, y: 0, width: width, height: previewHeight)
    previewImageView.frame = previewContainer.bounds
    dimOverlay.frame = previewContainer.bounds
    sweepLayer.frame = previewContainer.bounds

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

  // MARK: - Gesture Handlers

  @objc private func handleTap() {
    guard !longPressTriggered else { return }

    switch itemType {
    case .notebook(let notebook):
      delegate?.folderOverlayCellDidTapNotebook(self, notebook: notebook)
    case .pdf(let pdf):
      delegate?.folderOverlayCellDidTapPDF(self, pdf: pdf)
    case .none:
      break
    }
  }

  @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
    switch recognizer.state {
    case .began:
      longPressTriggered = true
      showPressFeedback()
      playSweepAnimation()

      // Report long press to delegate.
      guard let window = self.window else { return }
      let frameInWindow = previewContainer.convert(previewContainer.bounds, to: window)
      delegate?.folderOverlayCellDidLongPress(self, frame: frameInWindow, cardHeight: previewContainer.bounds.height)

    case .ended, .cancelled, .failed:
      hidePressFeedback()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.longPressTriggered = false
      }

    default:
      break
    }
  }

  // MARK: - Press Feedback

  private func showPressFeedback() {
    UIView.animate(withDuration: CardConstants.Press.dimDuration, delay: 0, options: .curveEaseOut) {
      self.dimOverlay.alpha = CardConstants.Press.dimOpacity
    }

    UIView.animate(
      withDuration: CardConstants.Press.springResponse,
      delay: 0,
      usingSpringWithDamping: CardConstants.Press.springDamping,
      initialSpringVelocity: 0,
      options: []
    ) {
      self.contentView.transform = CGAffineTransform(
        scaleX: CardConstants.Press.scale,
        y: CardConstants.Press.scale
      )
    }
  }

  private func hidePressFeedback() {
    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
      self.dimOverlay.alpha = 0
    }

    UIView.animate(
      withDuration: CardConstants.Press.springResponse,
      delay: 0,
      usingSpringWithDamping: CardConstants.Press.springDamping,
      initialSpringVelocity: 0,
      options: []
    ) {
      self.contentView.transform = .identity
    }
  }

  // MARK: - Sweep Animation

  private func playSweepAnimation() {
    // Flash overlay.
    let flashLayer = CALayer()
    flashLayer.backgroundColor = UIColor.white.withAlphaComponent(0.7).cgColor
    flashLayer.frame = previewContainer.bounds
    flashLayer.cornerRadius = CardConstants.cornerRadius
    flashLayer.masksToBounds = true
    previewContainer.layer.addSublayer(flashLayer)

    // Fade out flash.
    let flashAnimation = CABasicAnimation(keyPath: "opacity")
    flashAnimation.fromValue = 0.7
    flashAnimation.toValue = 0.0
    flashAnimation.duration = 0.28
    flashAnimation.fillMode = .forwards
    flashAnimation.isRemovedOnCompletion = false
    flashLayer.add(flashAnimation, forKey: "flashFade")

    // Sweep gradient across.
    sweepLayer.opacity = 1.0
    let sweepWidth = contentView.bounds.width * 1.2

    sweepLayer.frame = CGRect(
      x: -sweepWidth,
      y: 0,
      width: sweepWidth,
      height: previewContainer.bounds.height
    )

    let sweepAnimation = CABasicAnimation(keyPath: "position.x")
    sweepAnimation.fromValue = -sweepWidth / 2
    sweepAnimation.toValue = contentView.bounds.width + sweepWidth / 2
    sweepAnimation.duration = 0.5
    sweepAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
    sweepAnimation.fillMode = .forwards
    sweepAnimation.isRemovedOnCompletion = false
    sweepLayer.add(sweepAnimation, forKey: "sweepMove")

    // Clean up after animation.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.sweepLayer.opacity = 0
      self?.sweepLayer.removeAllAnimations()
      flashLayer.removeFromSuperlayer()
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    itemType = .none
    longPressTriggered = false
    previewImageView.image = nil
    placeholderImageView.isHidden = true
    contentView.transform = .identity
    dimOverlay.alpha = 0
  }
}
