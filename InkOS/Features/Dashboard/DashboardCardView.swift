import UIKit

// MARK: - Card Delegate Protocol

// Protocol for card interaction callbacks.
// All positions are in window coordinates for drag operations.
protocol DashboardCardDelegate: AnyObject {
  func cardDidTap(_ card: DashboardCardView)
  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat)
  func cardDidStartDrag(_ card: DashboardCardView, frame: CGRect, position: CGPoint)
  func cardDidMoveDrag(_ card: DashboardCardView, position: CGPoint)
  func cardDidEndDrag(_ card: DashboardCardView, position: CGPoint)
}

// MARK: - Base Dashboard Card View

// Base UIKit view for dashboard cards (notebooks, PDFs, and folders).
// Uses gesture recognizers for proper interaction with SwiftUI scroll views.
// Handles press feedback, sweep animation, and drag initiation.
// Subclasses provide custom content via setupPreviewContent() and configure methods.
class DashboardCardView: UIView {
  weak var delegate: DashboardCardDelegate?

  // Card dimensions - must match SwiftUI constants.
  static let cornerRadius: CGFloat = 10
  static let titleAreaHeight: CGFloat = 36
  static let aspectRatio: CGFloat = 0.72

  // Shadow configuration - matches SwiftUI shadow.
  private static let shadowOpacity: Float = 0.14
  private static let shadowRadius: CGFloat = 7
  private static let shadowOffset = CGSize(width: 0, height: 4)

  // Press feedback configuration.
  private static let pressScale: CGFloat = 1.04
  private static let pressDimOpacity: CGFloat = 0.12
  private static let pressDimDuration: TimeInterval = 0.06
  private static let pressScaleDuration: TimeInterval = 0.15

  // Gesture configuration.
  private let longPressDelay: TimeInterval = 0.3
  private let dragThreshold: CGFloat = 10

  // Whether this card type supports drag-to-move. Folders override to false.
  var isDraggable: Bool { true }

  // Container for preview content. Subclasses add their content here.
  // Provides shadow and houses the dim overlay and sweep animation.
  private(set) var previewContainer = UIView()

  // Default preview image view. Used by notebooks and PDFs.
  // Folders override setupPreviewContent() to provide their own content.
  private let previewImageView = UIImageView()

  // Overlay and animation layers.
  private let dimOverlay = UIView()
  private let sweepLayer = CAGradientLayer()

  // Title labels.
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()

  // Gesture recognizers.
  private var tapRecognizer: UITapGestureRecognizer!
  private var longPressRecognizer: UILongPressGestureRecognizer!

  // Gesture state.
  private var longPressStartLocation: CGPoint = .zero
  private var hasTriggeredLongPress = false
  private var isDragging = false

  // Title opacity control (for drop target effects).
  var titleOpacity: CGFloat = 1.0 {
    didSet {
      titleLabel.alpha = titleOpacity
      subtitleLabel.alpha = titleOpacity
    }
  }

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    backgroundColor = .clear
    isUserInteractionEnabled = true
    isMultipleTouchEnabled = false

    // Preview container holds the content and provides shadow.
    previewContainer.backgroundColor = .clear
    previewContainer.layer.cornerRadius = Self.cornerRadius
    previewContainer.layer.shadowColor = UIColor.black.cgColor
    previewContainer.layer.shadowOpacity = Self.shadowOpacity
    previewContainer.layer.shadowRadius = Self.shadowRadius
    previewContainer.layer.shadowOffset = Self.shadowOffset
    addSubview(previewContainer)

    // Let subclasses set up their preview content.
    setupPreviewContent()

    // Dim overlay for press feedback (added after content so it's on top).
    dimOverlay.backgroundColor = .black
    dimOverlay.alpha = 0
    dimOverlay.isUserInteractionEnabled = false
    dimOverlay.layer.cornerRadius = Self.cornerRadius
    dimOverlay.clipsToBounds = true
    previewContainer.addSubview(dimOverlay)

    // Sweep gradient layer for long press animation.
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
    sweepLayer.cornerRadius = Self.cornerRadius
    sweepLayer.masksToBounds = true
    previewContainer.layer.addSublayer(sweepLayer)

    // Title label.
    titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    titleLabel.textColor = UIColor.black.withAlphaComponent(0.88)
    titleLabel.lineBreakMode = .byTruncatingTail
    addSubview(titleLabel)

    // Subtitle label (date or page count).
    subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
    subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.62)
    subtitleLabel.lineBreakMode = .byTruncatingTail
    addSubview(subtitleLabel)

    // Setup gesture recognizers.
    setupGestureRecognizers()
  }

  // Override in subclasses to provide custom preview content.
  // Default implementation adds a single image view for notebooks/PDFs.
  func setupPreviewContent() {
    previewImageView.contentMode = .scaleAspectFill
    previewImageView.clipsToBounds = true
    previewImageView.layer.cornerRadius = Self.cornerRadius
    previewImageView.backgroundColor = .white
    previewContainer.addSubview(previewImageView)
  }

  private func setupGestureRecognizers() {
    // Tap recognizer for quick taps.
    tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    addGestureRecognizer(tapRecognizer)

    // Long press recognizer for long press and drag.
    // Uses minimal allowable movement so user can initiate drag after long press.
    longPressRecognizer = UILongPressGestureRecognizer(
      target: self,
      action: #selector(handleLongPress(_:))
    )
    longPressRecognizer.minimumPressDuration = longPressDelay
    longPressRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
    addGestureRecognizer(longPressRecognizer)

    // Tap should fail if long press is recognized.
    tapRecognizer.require(toFail: longPressRecognizer)
  }

  // MARK: - Layout

  override func layoutSubviews() {
    super.layoutSubviews()

    let width = bounds.width
    let height = bounds.height
    let previewHeight = height - Self.titleAreaHeight

    // Preview container.
    previewContainer.frame = CGRect(x: 0, y: 0, width: width, height: previewHeight)

    // Let subclasses lay out their content.
    layoutPreviewContent()

    // Overlays match container bounds.
    dimOverlay.frame = previewContainer.bounds
    sweepLayer.frame = previewContainer.bounds

    // Update shadow path for performance.
    previewContainer.layer.shadowPath = UIBezierPath(
      roundedRect: previewContainer.bounds,
      cornerRadius: Self.cornerRadius
    ).cgPath

    // Title labels below preview with 4pt spacing.
    let titleY = previewHeight + 4
    let titleWidth = width - 4  // 2pt padding on each side
    titleLabel.frame = CGRect(x: 2, y: titleY, width: titleWidth, height: 17)
    subtitleLabel.frame = CGRect(x: 2, y: titleY + 17 + 1, width: titleWidth, height: 14)
  }

  // Override in subclasses to lay out custom preview content.
  // Default implementation lays out the single image view.
  func layoutPreviewContent() {
    previewImageView.frame = previewContainer.bounds
  }

  // MARK: - Configuration

  // Sets the preview image. Called by subclasses.
  func setPreviewImage(_ image: UIImage?) {
    previewImageView.image = image
  }

  // Sets the background color for the preview (white for notebooks, gray for PDFs).
  func setPreviewBackgroundColor(_ color: UIColor) {
    previewImageView.backgroundColor = color
  }

  // Sets the title text.
  func setTitle(_ text: String) {
    titleLabel.text = text
  }

  // Sets the subtitle text (date or page count).
  func setSubtitle(_ text: String?) {
    subtitleLabel.text = text
    subtitleLabel.isHidden = text == nil
  }

  // MARK: - Gesture Handlers

  @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
    delegate?.cardDidTap(self)
  }

  @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
    guard let window = self.window else { return }

    let location = recognizer.location(in: window)

    switch recognizer.state {
    case .began:
      // Long press triggered - show context menu feedback.
      hasTriggeredLongPress = true
      longPressStartLocation = recognizer.location(in: self)

      // Show press feedback scale.
      showPressFeedback()

      // Play sweep animation and notify delegate.
      triggerLongPress()

    case .changed:
      // Only allow drag if this card type supports it.
      guard isDraggable else { return }

      // Check if user has moved enough to initiate drag.
      let currentLocation = recognizer.location(in: self)
      let distance = hypot(
        currentLocation.x - longPressStartLocation.x,
        currentLocation.y - longPressStartLocation.y
      )

      if !isDragging && distance > dragThreshold {
        // Start drag mode.
        isDragging = true
        let frameInWindow = self.convert(self.bounds, to: window)
        delegate?.cardDidStartDrag(self, frame: frameInWindow, position: location)
      } else if isDragging {
        // Continue dragging - report position update.
        delegate?.cardDidMoveDrag(self, position: location)
      }

    case .ended:
      if isDragging {
        // End drag with final position.
        delegate?.cardDidEndDrag(self, position: location)
      } else {
        // Long press ended without drag - hide feedback.
        hidePressFeedback()
      }
      cleanup()

    case .cancelled, .failed:
      if isDragging {
        delegate?.cardDidEndDrag(self, position: location)
      }
      hidePressFeedback()
      cleanup()

    default:
      break
    }
  }

  // MARK: - Press Feedback

  private func showPressFeedback() {
    UIView.animate(withDuration: Self.pressDimDuration, delay: 0, options: .curveEaseOut) {
      self.dimOverlay.alpha = Self.pressDimOpacity
    }

    // Scale up slightly.
    UIView.animate(
      withDuration: Self.pressScaleDuration,
      delay: 0,
      usingSpringWithDamping: 0.75,
      initialSpringVelocity: 0,
      options: []
    ) {
      self.previewContainer.transform = CGAffineTransform(scaleX: Self.pressScale, y: Self.pressScale)
    }
  }

  private func hidePressFeedback() {
    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
      self.dimOverlay.alpha = 0
    }

    UIView.animate(
      withDuration: Self.pressScaleDuration,
      delay: 0,
      usingSpringWithDamping: 0.75,
      initialSpringVelocity: 0,
      options: []
    ) {
      self.previewContainer.transform = .identity
    }
  }

  // MARK: - Long Press and Sweep Animation

  private func triggerLongPress() {
    hasTriggeredLongPress = true

    // Hide dim overlay when context menu triggers.
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
      self.dimOverlay.alpha = 0
    }

    // Notify delegate.
    guard let window = self.window else { return }
    let frameInWindow = self.convert(self.bounds, to: window)
    let previewHeight = bounds.height - Self.titleAreaHeight
    delegate?.cardDidLongPress(self, frame: frameInWindow, cardHeight: previewHeight)

    // Play sweep animation.
    playSweepAnimation()
  }

  private func playSweepAnimation() {
    // Flash overlay.
    let flashLayer = CALayer()
    flashLayer.backgroundColor = UIColor.white.withAlphaComponent(0.7).cgColor
    flashLayer.frame = previewContainer.bounds
    flashLayer.cornerRadius = Self.cornerRadius
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
    let sweepWidth = bounds.width * 1.2

    // Position sweep off screen left.
    sweepLayer.frame = CGRect(
      x: -sweepWidth,
      y: 0,
      width: sweepWidth,
      height: previewContainer.bounds.height
    )

    // Animate sweep to right.
    let sweepAnimation = CABasicAnimation(keyPath: "position.x")
    sweepAnimation.fromValue = -sweepWidth / 2
    sweepAnimation.toValue = bounds.width + sweepWidth / 2
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

  // MARK: - Cleanup

  private func cleanup() {
    hasTriggeredLongPress = false
    isDragging = false
    longPressStartLocation = .zero
  }

  // MARK: - Intrinsic Content Size

  override var intrinsicContentSize: CGSize {
    // Returns a size based on aspect ratio if width is known.
    if bounds.width > 0 {
      let height = bounds.width / Self.aspectRatio
      return CGSize(width: bounds.width, height: height)
    }
    return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
  }
}

// MARK: - Notebook Card View

// UIKit card view for notebooks.
// Displays notebook preview image, title, and last accessed date.
class NotebookCardView: DashboardCardView {
  private var notebook: NotebookMetadata?

  // Date formatter matching SwiftUI NotebookCardTitle.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a  MM/dd/yy"
    return formatter
  }()

  // Configures the card with notebook data.
  func configure(with notebook: NotebookMetadata) {
    self.notebook = notebook

    // Set preview image.
    let previewImage = notebook.previewImageData.flatMap { UIImage(data: $0) }
    setPreviewImage(previewImage)
    setPreviewBackgroundColor(.white)

    // Set title.
    setTitle(notebook.displayName)

    // Set subtitle (last accessed date).
    if let lastAccessed = notebook.lastAccessedAt {
      setSubtitle(Self.dateFormatter.string(from: lastAccessed))
    } else {
      setSubtitle(nil)
    }
  }

  // Returns the configured notebook.
  var configuredNotebook: NotebookMetadata? {
    return notebook
  }
}

// MARK: - PDF Card View

// UIKit card view for PDF documents.
// Displays PDF preview image (or placeholder), title, and page count.
class PDFCardView: DashboardCardView {
  private var pdfDocument: PDFDocumentMetadata?
  private let placeholderImageView = UIImageView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupPlaceholder()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupPlaceholder() {
    // Placeholder icon for PDFs without preview.
    placeholderImageView.image = UIImage(systemName: "doc.richtext")
    placeholderImageView.tintColor = .systemBlue
    placeholderImageView.contentMode = .center
    placeholderImageView.isHidden = true
    // Will be added to preview container in configure.
  }

  // Configures the card with PDF document data.
  func configure(with pdfDocument: PDFDocumentMetadata) {
    self.pdfDocument = pdfDocument

    // Set preview image or show placeholder.
    let previewImage = pdfDocument.previewImageData.flatMap { UIImage(data: $0) }
    setPreviewImage(previewImage)
    setPreviewBackgroundColor(UIColor.systemGray5)

    // Show/hide placeholder based on preview availability.
    placeholderImageView.isHidden = previewImage != nil

    // Set title.
    setTitle(pdfDocument.displayName)

    // Set subtitle (page count).
    let pageCountText = pdfDocument.pageCount == 1 ? "1 page" : "\(pdfDocument.pageCount) pages"
    setSubtitle(pageCountText)
  }

  // Returns the configured PDF document.
  var configuredPDFDocument: PDFDocumentMetadata? {
    return pdfDocument
  }
}

// MARK: - Folder Card View

// UIKit card view for folders.
// Displays a 2x2 thumbnail grid with glass background.
// Folders are not draggable but can be drop targets.
class FolderCardView: DashboardCardView {
  private var folder: FolderMetadata?
  private var thumbnails: [UIImage] = []

  // Layout constants matching original FolderCell.
  private let gridPadding: CGFloat = 6
  private let gridSpacing: CGFloat = 3
  private let thumbnailCornerRadius: CGFloat = 4

  // Glass background.
  private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))

  // Thumbnail image views (2x2 grid).
  private let thumbnailViews: [UIImageView] = (0..<4).map { _ in UIImageView() }

  // Placeholder views for items without thumbnails.
  private let placeholderViews: [UIView] = (0..<4).map { _ in UIView() }

  // Folders are not draggable.
  override var isDraggable: Bool { false }

  // MARK: - Preview Content Setup

  override func setupPreviewContent() {
    // Glass blur background.
    blurView.layer.cornerRadius = Self.cornerRadius
    blurView.clipsToBounds = true
    previewContainer.addSubview(blurView)

    // Thumbnail image views.
    for imageView in thumbnailViews {
      imageView.contentMode = .scaleAspectFill
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = thumbnailCornerRadius
      imageView.layer.shadowColor = UIColor.black.cgColor
      imageView.layer.shadowOpacity = 0.25
      imageView.layer.shadowRadius = 4
      imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
      imageView.isHidden = true
      blurView.contentView.addSubview(imageView)
    }

    // Placeholder views for items without thumbnails.
    for placeholder in placeholderViews {
      placeholder.backgroundColor = .white
      placeholder.layer.cornerRadius = thumbnailCornerRadius
      placeholder.clipsToBounds = true
      placeholder.layer.shadowColor = UIColor.black.cgColor
      placeholder.layer.shadowOpacity = 0.25
      placeholder.layer.shadowRadius = 4
      placeholder.layer.shadowOffset = CGSize(width: 0, height: 2)
      placeholder.isHidden = true

      let iconView = UIImageView(image: UIImage(systemName: "doc.text"))
      iconView.tintColor = UIColor.black.withAlphaComponent(0.2)
      iconView.contentMode = .scaleAspectFit
      iconView.tag = 100
      placeholder.addSubview(iconView)

      blurView.contentView.addSubview(placeholder)
    }
  }

  // MARK: - Preview Content Layout

  override func layoutPreviewContent() {
    blurView.frame = previewContainer.bounds

    let width = previewContainer.bounds.width
    let height = previewContainer.bounds.height

    // Calculate thumbnail cell size.
    let maxCellWidth = (width - gridPadding * 2 - gridSpacing) / 2
    let maxCellHeight = (height - gridPadding * 2 - gridSpacing) / 2
    let cellSize = min(maxCellWidth, maxCellHeight)

    // Layout 2x2 grid.
    let positions: [(row: Int, col: Int)] = [(0, 0), (0, 1), (1, 0), (1, 1)]
    for (index, pos) in positions.enumerated() {
      let x = gridPadding + CGFloat(pos.col) * (cellSize + gridSpacing)
      let y = gridPadding + CGFloat(pos.row) * (cellSize + gridSpacing)
      let frame = CGRect(x: x, y: y, width: cellSize, height: cellSize)

      thumbnailViews[index].frame = frame
      placeholderViews[index].frame = frame

      // Size the placeholder icon.
      if let iconView = placeholderViews[index].viewWithTag(100) {
        let iconSize = cellSize * 0.35
        iconView.frame = CGRect(
          x: (cellSize - iconSize) / 2,
          y: (cellSize - iconSize) / 2,
          width: iconSize,
          height: iconSize
        )
      }
    }
  }

  // MARK: - Configuration

  // Configures the card with folder data and thumbnail images.
  func configure(with folder: FolderMetadata, thumbnails: [UIImage]) {
    self.folder = folder
    self.thumbnails = thumbnails

    // Set title.
    setTitle(folder.displayName)

    // Set subtitle (item count).
    let total = folder.itemCount
    let subtitle: String
    if total == 0 {
      subtitle = "Empty"
    } else if folder.pdfCount == 0 {
      subtitle = total == 1 ? "1 notebook" : "\(total) notebooks"
    } else if folder.notebookCount == 0 {
      subtitle = total == 1 ? "1 PDF" : "\(total) PDFs"
    } else {
      subtitle = total == 1 ? "1 item" : "\(total) items"
    }
    setSubtitle(subtitle)

    // Update thumbnail visibility.
    let displayCount = min(folder.itemCount, 4)
    for i in 0..<4 {
      if i < displayCount {
        if i < thumbnails.count {
          thumbnailViews[i].image = thumbnails[i]
          thumbnailViews[i].isHidden = false
          placeholderViews[i].isHidden = true
        } else {
          thumbnailViews[i].isHidden = true
          placeholderViews[i].isHidden = false
        }
      } else {
        thumbnailViews[i].isHidden = true
        placeholderViews[i].isHidden = true
      }
    }
  }

  // Returns the configured folder.
  var configuredFolder: FolderMetadata? {
    return folder
  }

  // Clears configuration for cell reuse.
  func prepareForReuse() {
    folder = nil
    thumbnails = []
    for imageView in thumbnailViews {
      imageView.image = nil
      imageView.isHidden = true
    }
    for placeholder in placeholderViews {
      placeholder.isHidden = true
    }
  }
}
