// PDFCollectionViewController.swift
// UIViewController that displays a PDF-based NoteDocument in a vertical collection view.

import PDFKit
import UIKit

// UIViewController that displays a PDF-based NoteDocument in a vertical collection view.
// Uses UICollectionViewCompositionalLayout with full-width items and estimated heights.
// Cells are sized based on content: PDF pages maintain aspect ratio, spacers use stored height.
@MainActor
class PDFCollectionViewController: UIViewController, PDFCollectionViewControllerProtocol {

  // The NoteDocument being displayed.
  let noteDocument: NoteDocument

  // The PDFDocument containing the actual page content.
  let pdfDocument: PDFDocument

  // The collection view displaying the blocks.
  var collectionView: UICollectionView!

  // Data source for the collection view.
  private var dataSource: UICollectionViewDiffableDataSource<Int, NoteBlock>!

  // Coordinator managing MyScript annotation across cells.
  private var annotationCoordinator: PDFAnnotationCoordinator?

  // Creates a PDF collection view controller for the given documents and MyScript dependencies.
  // Throws if the NoteDocument is empty.
  init(
    noteDocument: NoteDocument,
    pdfDocument: PDFDocument,
    package: any ContentPackageProtocol,
    engineProvider: EngineProvider,
    editorDelegate: (any EditorDelegate)?
  ) throws {
    // Validate that document has blocks.
    guard !noteDocument.blocks.isEmpty else {
      throw PDFCollectionViewControllerError.emptyDocument
    }
    self.noteDocument = noteDocument
    self.pdfDocument = pdfDocument
    super.init(nibName: nil, bundle: nil)

    // Create annotation coordinator.
    self.annotationCoordinator = PDFAnnotationCoordinator(
      engineProvider: engineProvider,
      package: package,
      editorDelegate: editorDelegate
    )
  }

  // Storyboard initializer not supported.
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupCollectionView()
    configureDataSource()
    applyInitialSnapshot()
  }

  // Sets up the collection view with compositional layout.
  private func setupCollectionView() {
    // Create layout.
    let layout = PDFCollectionLayout.createLayout { [weak self] indexPath, environment in
      guard let self = self else { return 0 }
      do {
        return try self.cellHeight(
          at: indexPath.item, containerWidth: environment.container.contentSize.width)
      } catch {
        // Return estimated height on error.
        return 500
      }
    }

    // Create collection view.
    collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.backgroundColor = .systemBackground

    // Add to view hierarchy.
    view.addSubview(collectionView)

    // Constrain to fill view.
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    // Register cell types.
    collectionView.register(
      PDFPageCell.self, forCellWithReuseIdentifier: PDFPageCell.reuseIdentifier)
    collectionView.register(SpacerCell.self, forCellWithReuseIdentifier: SpacerCell.reuseIdentifier)

    // Set delegate for cell visibility tracking.
    collectionView.delegate = self
  }

  // Configures the diffable data source with cell providers.
  private func configureDataSource() {
    dataSource = UICollectionViewDiffableDataSource<Int, NoteBlock>(
      collectionView: collectionView
    ) { [weak self] collectionView, indexPath, block in
      guard let self = self else { return nil }

      switch block {
      case .pdfPage(let pageIndex, let uuid, let partID):
        guard
          let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PDFPageCell.reuseIdentifier,
            for: indexPath
          ) as? PDFPageCell
        else {
          return nil
        }

        // Pass shared document instead of individual page.
        cell.configure(
          document: self.pdfDocument,
          pageIndex: pageIndex,
          uuid: uuid,
          myScriptPartID: partID
        )
        return cell

      case .writingSpacer(let height, let uuid, _):
        guard
          let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SpacerCell.reuseIdentifier,
            for: indexPath
          ) as? SpacerCell
        else {
          return nil
        }
        cell.configure(height: height, uuid: uuid)
        return cell
      }
    }
  }

  // Applies the initial snapshot with all blocks.
  private func applyInitialSnapshot() {
    var snapshot = NSDiffableDataSourceSnapshot<Int, NoteBlock>()
    snapshot.appendSections([0])
    snapshot.appendItems(noteDocument.blocks, toSection: 0)
    dataSource.apply(snapshot, animatingDifferences: false)
  }

  // Calculates the height for a cell at the given block index.
  func cellHeight(at blockIndex: Int, containerWidth: CGFloat) throws -> CGFloat {
    // Validate block index.
    guard blockIndex >= 0 && blockIndex < noteDocument.blocks.count else {
      throw PDFCollectionViewControllerError.pageIndexOutOfBounds(
        blockIndex: blockIndex,
        pageIndex: -1,
        pdfPageCount: pdfDocument.pageCount
      )
    }

    let block = noteDocument.blocks[blockIndex]

    switch block {
    case .pdfPage(let pageIndex, _, _):
      // Validate page index.
      guard pageIndex >= 0 && pageIndex < pdfDocument.pageCount else {
        throw PDFCollectionViewControllerError.pageIndexOutOfBounds(
          blockIndex: blockIndex,
          pageIndex: pageIndex,
          pdfPageCount: pdfDocument.pageCount
        )
      }

      // Get the page to calculate dimensions.
      guard let page = pdfDocument.page(at: pageIndex) else {
        throw PDFCollectionViewControllerError.pdfPageUnavailable(pageIndex: pageIndex)
      }

      // Calculate height based on aspect ratio.
      let bounds = page.bounds(for: .mediaBox)
      guard bounds.width > 0 else {
        return 0
      }
      let aspectRatio = bounds.height / bounds.width
      return containerWidth * aspectRatio

    case .writingSpacer(let height, _, _):
      // Return the stored height for spacers.
      return height
    }
  }
}

// MARK: - UICollectionViewDelegate

extension PDFCollectionViewController: UICollectionViewDelegate {

  // Called when a cell becomes visible.
  // Notifies coordinator to track visible cells and activate if needed.
  func collectionView(
    _ collectionView: UICollectionView,
    willDisplay cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
  ) {
    guard let pdfCell = cell as? PDFPageCell,
      let partID = pdfCell.myScriptPartID
    else { return }

    annotationCoordinator?.cellDidBecomeVisible(
      pdfCell,
      at: indexPath,
      myScriptPartID: partID
    )
  }

  // Called when a cell is no longer visible.
  // Notifies coordinator to clean up tracking and deactivate if needed.
  func collectionView(
    _ collectionView: UICollectionView,
    didEndDisplaying cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
  ) {
    guard let pdfCell = cell as? PDFPageCell else { return }
    annotationCoordinator?.cellDidEndDisplay(pdfCell, at: indexPath)
  }
}
