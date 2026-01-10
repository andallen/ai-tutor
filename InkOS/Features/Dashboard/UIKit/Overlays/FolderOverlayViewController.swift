// UIKit folder overlay view controller.
// Displays an expanded folder with its contents in a liquid glass modal overlay.
// Uses custom presentation for scale-from-source animation with synchronized blur.

import UIKit

// Delegate for folder overlay interactions.
protocol FolderOverlayDelegate: AnyObject {
  func folderOverlayDidSelectNotebook(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata)
  func folderOverlayDidSelectPDF(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata)
  func folderOverlayDidDismiss(_ overlay: FolderOverlayViewController)
  func folderOverlayDidRequestRename(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata)
  func folderOverlayDidRequestRename(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata)
  func folderOverlayDidRequestDelete(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata)
  func folderOverlayDidRequestDelete(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata)
  func folderOverlayDidRequestMoveToRoot(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata)
  func folderOverlayDidRequestMoveToRoot(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata)
}

class FolderOverlayViewController: UIViewController {

  // MARK: - Properties

  // Folder being displayed.
  let folder: FolderMetadata

  // Contents of the folder.
  private(set) var notebooks: [NotebookMetadata]
  private(set) var pdfDocuments: [PDFDocumentMetadata]

  // Source frame for animation (folder card frame in window coordinates).
  let sourceFrame: CGRect

  // Delegate for interactions.
  weak var delegate: FolderOverlayDelegate?

  // Layout constants for larger liquid glass overlay.
  private let overlayWidth: CGFloat = 420
  private let overlayCornerRadius: CGFloat = 32
  private let contentPadding: CGFloat = 24
  private let headerHeight: CGFloat = 60
  private let gridSpacing: CGFloat = 24
  private let cardAspectRatio: CGFloat = 0.72
  private let columns: Int = 2

  // Main container view with shadow.
  private let containerView = UIView()

  // Liquid glass background layers.
  private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
  private let glassGradientLayer = CAGradientLayer()
  private let glassBorderLayer = CAShapeLayer()

  // Header label.
  private let headerLabel = UILabel()

  // Collection view for folder contents.
  private var collectionView: UICollectionView!
  private var dataSource: UICollectionViewDiffableDataSource<Section, FolderOverlayItem>!

  // Section definition.
  private enum Section: Hashable {
    case main
  }

  // Item type for data source.
  private enum FolderOverlayItem: Hashable {
    case notebook(NotebookMetadata)
    case pdf(PDFDocumentMetadata)

    var id: String {
      switch self {
      case .notebook(let notebook): return "notebook-\(notebook.id)"
      case .pdf(let pdf): return "pdf-\(pdf.id)"
      }
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    static func == (lhs: FolderOverlayItem, rhs: FolderOverlayItem) -> Bool {
      lhs.id == rhs.id
    }
  }

  // MARK: - Initialization

  init(folder: FolderMetadata, notebooks: [NotebookMetadata], pdfDocuments: [PDFDocumentMetadata], sourceFrame: CGRect) {
    self.folder = folder
    self.notebooks = notebooks
    self.pdfDocuments = pdfDocuments
    self.sourceFrame = sourceFrame
    super.init(nibName: nil, bundle: nil)

    // Configure for custom presentation.
    modalPresentationStyle = .custom
    transitioningDelegate = self
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setupViews()
    setupCollectionView()
    setupDataSource()
    applySnapshot()
  }

  // MARK: - Setup

  private func setupViews() {
    view.backgroundColor = .clear

    // Tap on background dismisses.
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
    tapGesture.delegate = self
    view.addGestureRecognizer(tapGesture)

    // Container view with layered drop shadow for depth.
    containerView.backgroundColor = .clear
    containerView.layer.cornerRadius = overlayCornerRadius
    containerView.clipsToBounds = false
    view.addSubview(containerView)

    // Primary soft shadow for ambient depth.
    containerView.layer.shadowColor = UIColor.black.cgColor
    containerView.layer.shadowOpacity = 0.12
    containerView.layer.shadowRadius = 40
    containerView.layer.shadowOffset = CGSize(width: 0, height: 16)

    // Liquid glass blur background with ultra-thin material.
    blurView.layer.cornerRadius = overlayCornerRadius
    blurView.clipsToBounds = true
    containerView.addSubview(blurView)

    // Glass gradient overlay for subtle shine effect (top-left highlight).
    glassGradientLayer.colors = [
      UIColor.white.withAlphaComponent(0.35).cgColor,
      UIColor.white.withAlphaComponent(0.08).cgColor,
      UIColor.clear.cgColor
    ]
    glassGradientLayer.locations = [0.0, 0.3, 0.6]
    glassGradientLayer.startPoint = CGPoint(x: 0, y: 0)
    glassGradientLayer.endPoint = CGPoint(x: 1, y: 1)
    glassGradientLayer.cornerRadius = overlayCornerRadius
    blurView.contentView.layer.addSublayer(glassGradientLayer)

    // Glass border for subtle edge definition.
    glassBorderLayer.fillColor = UIColor.clear.cgColor
    glassBorderLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
    glassBorderLayer.lineWidth = 1.0
    blurView.contentView.layer.addSublayer(glassBorderLayer)

    // Header label with slightly larger font for bigger overlay.
    headerLabel.text = folder.displayName
    headerLabel.font = .systemFont(ofSize: 20, weight: .semibold)
    headerLabel.textColor = UIColor.black.withAlphaComponent(0.85)
    headerLabel.lineBreakMode = .byTruncatingTail
    blurView.contentView.addSubview(headerLabel)
  }

  private func setupCollectionView() {
    let layout = createCollectionViewLayout()
    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.backgroundColor = .clear
    collectionView.delegate = self
    collectionView.showsVerticalScrollIndicator = false
    collectionView.alwaysBounceVertical = false

    // Register cell.
    collectionView.register(FolderOverlayCell.self, forCellWithReuseIdentifier: FolderOverlayCell.reuseIdentifier)

    blurView.contentView.addSubview(collectionView)
  }

  private func createCollectionViewLayout() -> UICollectionViewLayout {
    // Calculate card dimensions.
    let availableWidth = overlayWidth - contentPadding * 2 - gridSpacing * CGFloat(columns - 1)
    let cardWidth = availableWidth / CGFloat(columns)
    let cardHeight = cardWidth / cardAspectRatio

    // Create layout with fixed size items.
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .absolute(cardWidth),
      heightDimension: .absolute(cardHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    // Group with 2 items per row.
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cardHeight)
    )
    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
    group.interItemSpacing = .fixed(gridSpacing)

    // Section with spacing.
    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = gridSpacing
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 8,
      leading: contentPadding,
      bottom: contentPadding,
      trailing: contentPadding
    )

    return UICollectionViewCompositionalLayout(section: section)
  }

  private func setupDataSource() {
    dataSource = UICollectionViewDiffableDataSource<Section, FolderOverlayItem>(
      collectionView: collectionView
    ) { [weak self] collectionView, indexPath, item in
      guard let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: FolderOverlayCell.reuseIdentifier,
        for: indexPath
      ) as? FolderOverlayCell else { return nil }

      switch item {
      case .notebook(let notebook):
        cell.configureAsNotebook(notebook)
      case .pdf(let pdf):
        cell.configureAsPDF(pdf)
      }

      cell.delegate = self
      return cell
    }
  }

  private func applySnapshot() {
    var snapshot = NSDiffableDataSourceSnapshot<Section, FolderOverlayItem>()
    snapshot.appendSections([.main])

    // Add notebooks first, then PDFs.
    let items: [FolderOverlayItem] = notebooks.map { .notebook($0) } + pdfDocuments.map { .pdf($0) }
    snapshot.appendItems(items, toSection: .main)

    dataSource.apply(snapshot, animatingDifferences: false)
  }

  // MARK: - Layout

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let containerFrame = calculateContainerFrame()
    containerView.frame = containerFrame

    // Update shadow path for performance.
    containerView.layer.shadowPath = UIBezierPath(
      roundedRect: containerView.bounds,
      cornerRadius: overlayCornerRadius
    ).cgPath

    blurView.frame = containerView.bounds

    // Update glass gradient layer frame.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    glassGradientLayer.frame = blurView.bounds

    // Update glass border path.
    let borderPath = UIBezierPath(
      roundedRect: blurView.bounds.insetBy(dx: 0.5, dy: 0.5),
      cornerRadius: overlayCornerRadius - 0.5
    )
    glassBorderLayer.path = borderPath.cgPath
    glassBorderLayer.frame = blurView.bounds
    CATransaction.commit()

    // Header with larger padding.
    headerLabel.frame = CGRect(
      x: contentPadding,
      y: contentPadding,
      width: containerFrame.width - contentPadding * 2,
      height: 26
    )

    // Collection view below header.
    let collectionTop = headerHeight
    collectionView.frame = CGRect(
      x: 0,
      y: collectionTop,
      width: containerFrame.width,
      height: containerFrame.height - collectionTop
    )
  }

  // Calculates the expanded container frame centered in the view.
  private func calculateContainerFrame() -> CGRect {
    let totalItems = notebooks.count + pdfDocuments.count

    // Calculate grid dimensions with larger spacing.
    let availableWidth = overlayWidth - contentPadding * 2 - gridSpacing * CGFloat(columns - 1)
    let cardWidth = availableWidth / CGFloat(columns)
    let cardHeight = cardWidth / cardAspectRatio

    let rows = max(1, (totalItems + columns - 1) / columns)
    let gridHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * gridSpacing

    // Total height with more breathing room.
    let contentHeight = headerHeight + 12 + gridHeight + contentPadding

    // Minimum height for empty state.
    let minHeight: CGFloat = headerHeight + 200 + contentPadding
    let isEmpty = notebooks.isEmpty && pdfDocuments.isEmpty
    let totalHeight = isEmpty ? minHeight : contentHeight

    // Center in view.
    let x = (view.bounds.width - overlayWidth) / 2
    let y = (view.bounds.height - totalHeight) / 2

    return CGRect(x: x, y: y, width: overlayWidth, height: totalHeight)
  }

  // Returns the container view for transition animations.
  var containerViewForTransition: UIView {
    containerView
  }

  // MARK: - Actions

  @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
    dismiss(animated: true)
  }

  override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
    super.dismiss(animated: flag) { [weak self] in
      guard let self else { return }
      self.delegate?.folderOverlayDidDismiss(self)
      completion?()
    }
  }

  // MARK: - Content Updates

  // Updates the folder contents and refreshes the grid.
  func updateContents(notebooks: [NotebookMetadata], pdfDocuments: [PDFDocumentMetadata]) {
    self.notebooks = notebooks
    self.pdfDocuments = pdfDocuments
    applySnapshot()
    view.setNeedsLayout()
  }
}

// MARK: - UIViewControllerTransitioningDelegate

extension FolderOverlayViewController: UIViewControllerTransitioningDelegate {
  func presentationController(
    forPresented presented: UIViewController,
    presenting: UIViewController?,
    source: UIViewController
  ) -> UIPresentationController? {
    FolderPresentationController(presentedViewController: presented, presenting: presenting)
  }

  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    FolderTransitionAnimator(presenting: true, sourceFrame: sourceFrame)
  }

  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    FolderTransitionAnimator(presenting: false, sourceFrame: sourceFrame)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension FolderOverlayViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    // Only handle taps outside the container.
    let location = touch.location(in: view)
    return !containerView.frame.contains(location)
  }
}

// MARK: - UICollectionViewDelegate

extension FolderOverlayViewController: UICollectionViewDelegate {
  // Selection handled via cell delegate.
}

// MARK: - FolderOverlayCellDelegate

extension FolderOverlayViewController: FolderOverlayCellDelegate {
  func folderOverlayCellDidTapNotebook(_ cell: FolderOverlayCell, notebook: NotebookMetadata) {
    delegate?.folderOverlayDidSelectNotebook(self, notebook: notebook)
  }

  func folderOverlayCellDidTapPDF(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata) {
    delegate?.folderOverlayDidSelectPDF(self, pdf: pdf)
  }

  // Context menu action callbacks.
  func folderOverlayCellDidRequestRename(_ cell: FolderOverlayCell, notebook: NotebookMetadata) {
    delegate?.folderOverlayDidRequestRename(self, notebook: notebook)
  }

  func folderOverlayCellDidRequestRename(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata) {
    delegate?.folderOverlayDidRequestRename(self, pdf: pdf)
  }

  func folderOverlayCellDidRequestDelete(_ cell: FolderOverlayCell, notebook: NotebookMetadata) {
    delegate?.folderOverlayDidRequestDelete(self, notebook: notebook)
  }

  func folderOverlayCellDidRequestDelete(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata) {
    delegate?.folderOverlayDidRequestDelete(self, pdf: pdf)
  }

  func folderOverlayCellDidRequestMoveToRoot(_ cell: FolderOverlayCell, notebook: NotebookMetadata) {
    delegate?.folderOverlayDidRequestMoveToRoot(self, notebook: notebook)
  }

  func folderOverlayCellDidRequestMoveToRoot(_ cell: FolderOverlayCell, pdf: PDFDocumentMetadata) {
    delegate?.folderOverlayDidRequestMoveToRoot(self, pdf: pdf)
  }
}
