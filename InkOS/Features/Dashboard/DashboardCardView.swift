import UIKit

// MARK: - Card Delegate Protocol

// Protocol for card interaction callbacks.
protocol DashboardCardDelegate: AnyObject {
  // Called when the card is tapped.
  func cardDidTap(_ card: DashboardCardView)

  // Called when the card is long-pressed (for context menu).
  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat)
}

// Default implementations for optional delegate methods.
extension DashboardCardDelegate {
  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {}
}

// MARK: - Context Menu Provider Protocol

// Protocol for providing context menu configuration to cards.
// Implemented by representable coordinators to customize menu content.
protocol DashboardCardContextMenuProvider: AnyObject {
  // Returns the menu configuration for this card, or nil for no menu.
  func contextMenuConfiguration(for card: DashboardCardView) -> UIContextMenuConfiguration?

  // Returns a preview view controller for the context menu lift animation.
  func contextMenuPreviewViewController(for card: DashboardCardView) -> UIViewController?
}

// MARK: - Base Dashboard Card View

// Base UIKit view for dashboard cards (notebooks, PDFs, and folders).
// Uses gesture recognizers for proper interaction with SwiftUI scroll views.
// Subclasses provide custom content via setupPreviewContent() and configure methods.
class DashboardCardView: UIView {
  weak var delegate: DashboardCardDelegate?

  // Context menu provider for customizing long-press menu.
  weak var contextMenuProvider: DashboardCardContextMenuProvider?

  // Card dimensions - must match SwiftUI constants.
  static let cornerRadius: CGFloat = 10
  static let titleAreaHeight: CGFloat = 36
  static let aspectRatio: CGFloat = 0.72

  // Shadow configuration - matches SwiftUI shadow.
  private static let shadowOpacity: Float = 0.14
  private static let shadowRadius: CGFloat = 7
  private static let shadowOffset = CGSize(width: 0, height: 4)

  // Container for preview content. Subclasses add their content here.
  // Provides shadow and houses content.
  private(set) var previewContainer = UIView()

  // Default preview image view. Used by notebooks and PDFs.
  // Folders override setupPreviewContent() to provide their own content.
  private let previewImageView = UIImageView()

  // Title labels.
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()

  // Gesture recognizers.
  private var tapRecognizer: UITapGestureRecognizer!
  private var longPressRecognizer: UILongPressGestureRecognizer!

  // Edit menu interaction for showing menu without preview lift.
  private var editMenuInteraction: UIEditMenuInteraction?

  // Menu to show on long press. Set by the cell when configuring.
  var menuProvider: (() -> UIMenu?)?

  // Title opacity control for visual effects.
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
    // Long press recognizer for showing menu.
    longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    longPressRecognizer.minimumPressDuration = 0.3
    longPressRecognizer.delegate = self
    addGestureRecognizer(longPressRecognizer)

    // Tap recognizer for quick taps.
    tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tapRecognizer.delegate = self
    tapRecognizer.require(toFail: longPressRecognizer)
    addGestureRecognizer(tapRecognizer)

    // Edit menu interaction for showing menu without preview lift.
    editMenuInteraction = UIEditMenuInteraction(delegate: self)
    addInteraction(editMenuInteraction!)
  }

  @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
    guard recognizer.state == .began else { return }

    // Animate lift effect.
    animateLift(true)

    // Present the edit menu at the long press location.
    let location = recognizer.location(in: self)
    let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
    editMenuInteraction?.presentEditMenu(with: config)
  }

  // Animates the lift effect when long-pressing.
  // Scales the card up slightly and enhances shadow to indicate selection.
  // Public so cells/view controllers can reset the animation after action sheet dismisses.
  func animateLift(_ lifted: Bool) {
    // Scale UP to 108% when lifted for a "pop" effect.
    let scale: CGFloat = lifted ? 1.08 : 1.0
    // Enhance shadow when lifted.
    let shadowRadius: CGFloat = lifted ? 16 : Self.shadowRadius
    let shadowOpacity: Float = lifted ? 0.3 : Self.shadowOpacity

    UIView.animate(
      withDuration: 0.25,
      delay: 0,
      usingSpringWithDamping: 0.7,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction, .beginFromCurrentState]
    ) {
      self.transform = lifted ? CGAffineTransform(scaleX: scale, y: scale) : .identity
      self.previewContainer.layer.shadowRadius = shadowRadius
      self.previewContainer.layer.shadowOpacity = shadowOpacity
    }
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

// MARK: - Lesson Card View

// UIKit card view for lessons.
// Displays lesson preview image or placeholder, title, and "Lesson" subtitle.
class LessonCardView: DashboardCardView {
  private var lesson: LessonMetadata?
  private let placeholderView = UIView()
  private let placeholderIcon = UIImageView()
  private let placeholderLabel = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupPlaceholder()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupPlaceholder() {
    // Container for placeholder content.
    placeholderView.backgroundColor = .white
    placeholderView.layer.cornerRadius = Self.cornerRadius
    placeholderView.clipsToBounds = true
    placeholderView.isHidden = true

    // Icon.
    placeholderIcon.image = UIImage(systemName: "book.pages")
    placeholderIcon.tintColor = UIColor.black.withAlphaComponent(0.35)
    placeholderIcon.contentMode = .scaleAspectFit
    placeholderView.addSubview(placeholderIcon)

    // Label.
    placeholderLabel.text = "Lesson"
    placeholderLabel.font = .systemFont(ofSize: 12, weight: .medium)
    placeholderLabel.textColor = UIColor.black.withAlphaComponent(0.35)
    placeholderLabel.textAlignment = .center
    placeholderView.addSubview(placeholderLabel)

    previewContainer.addSubview(placeholderView)
  }

  override func layoutPreviewContent() {
    super.layoutPreviewContent()

    placeholderView.frame = previewContainer.bounds

    // Center icon and label in placeholder.
    let iconSize: CGFloat = 32
    let labelHeight: CGFloat = 16
    let spacing: CGFloat = 8
    let totalHeight = iconSize + spacing + labelHeight
    let topOffset = (previewContainer.bounds.height - totalHeight) / 2

    placeholderIcon.frame = CGRect(
      x: (previewContainer.bounds.width - iconSize) / 2,
      y: topOffset,
      width: iconSize,
      height: iconSize
    )

    placeholderLabel.frame = CGRect(
      x: 0,
      y: topOffset + iconSize + spacing,
      width: previewContainer.bounds.width,
      height: labelHeight
    )
  }

  // Configures the card with lesson data.
  func configure(with lesson: LessonMetadata) {
    self.lesson = lesson

    // Set preview image or show placeholder.
    let previewImage = lesson.previewImage.flatMap { UIImage(data: $0) }
    setPreviewImage(previewImage)
    setPreviewBackgroundColor(.white)

    // Show/hide placeholder based on preview availability.
    placeholderView.isHidden = previewImage != nil

    // Set title.
    setTitle(lesson.displayName)

    // Set subtitle to "Lesson".
    setSubtitle("Lesson")
  }

  // Returns the configured lesson.
  var configuredLesson: LessonMetadata? {
    return lesson
  }
}

// MARK: - UIEditMenuInteractionDelegate

extension DashboardCardView: UIEditMenuInteractionDelegate {
  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    menuFor configuration: UIEditMenuConfiguration,
    suggestedActions: [UIMenuElement]
  ) -> UIMenu? {
    // Return the menu from the provider (set by the cell).
    return menuProvider?()
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    targetRectFor configuration: UIEditMenuConfiguration
  ) -> CGRect {
    // Get card position in window coordinates.
    guard let window = window else {
      return previewContainer.frame
    }

    let frameInWindow = convert(bounds, to: window)

    // Check if card is in the leftmost column.
    // Left edge of leftmost cards is typically around 24pt (section inset).
    let isLeftColumn = frameInWindow.minX < 50

    if isLeftColumn {
      // Left column - use default positioning.
      return previewContainer.frame
    } else {
      // Non-left column - return narrow rect centered horizontally over the card.
      // Menu anchors to this rect and appears centered over it.
      // Shift 4pt left to compensate for UIEditMenuInteraction's internal offset.
      let centerX = previewContainer.frame.midX - 4
      return CGRect(
        x: centerX - 1,
        y: previewContainer.frame.minY,
        width: 2,
        height: previewContainer.frame.height
      )
    }
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    willDismissMenuFor configuration: UIEditMenuConfiguration,
    animator: any UIEditMenuInteractionAnimating
  ) {
    // Reset lift animation immediately when menu starts to dismiss.
    // Call directly instead of in completion handler for instant visual feedback.
    animateLift(false)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension DashboardCardView: UIGestureRecognizerDelegate {
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    // Allow long press and tap coordination.
    if gestureRecognizer == longPressRecognizer && otherGestureRecognizer == tapRecognizer {
      return true
    }
    if gestureRecognizer == tapRecognizer && otherGestureRecognizer == longPressRecognizer {
      return true
    }
    return false
  }
}
