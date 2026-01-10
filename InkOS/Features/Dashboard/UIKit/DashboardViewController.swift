// UIKit dashboard view controller with collection view grid.
// Replaces SwiftUI DashboardView for full animation control.

import Combine
import SwiftUI
import UIKit

// Delegate for dashboard navigation events.
protocol DashboardViewControllerDelegate: AnyObject {
  func dashboardDidSelectNotebook(_ notebook: NotebookMetadata)
  func dashboardDidSelectPDF(_ pdf: PDFDocumentMetadata)
  func dashboardDidSelectFolder(_ folder: FolderMetadata, thumbnails: [UIImage])
  func dashboardDidSelectLesson(_ lesson: LessonMetadata)
}

class DashboardViewController: UIViewController {

  // MARK: - Properties

  // Data source.
  private let library: NotebookLibrary

  // Delegate for navigation.
  weak var delegate: DashboardViewControllerDelegate?

  // Collection view and data source.
  private var collectionView: UICollectionView!
  private var dataSource: UICollectionViewDiffableDataSource<Section, DashboardItem>!

  // Combine subscriptions for data updates.
  private var cancellables = Set<AnyCancellable>()

  // Thumbnail cache for folders.
  private var folderThumbnails: [String: [UIImage]] = [:]

  // Loading state.
  private var isLoading = true

  // AI overlay coordinator.
  private var aiOverlayCoordinator: AIOverlayCoordinator?

  // Tracks the currently expanded folder for AI context.
  private(set) var expandedFolderID: String?

  // Lesson generator for creating lessons.
  private var lessonGenerator: LessonGenerator?

  // Hosting controller for lesson generation overlay.
  private var lessonOverlayHostingController: UIHostingController<LessonGenerationOverlay>?

  // Section definition.
  private enum Section: Hashable {
    case main
  }

  // MARK: - Initialization

  init(library: NotebookLibrary) {
    self.library = library
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    setupCollectionView()
    setupDataSource()
    setupBindings()
    setupAIOverlayCoordinator()
  }

  // Sets up the AI overlay coordinator with dashboard configuration.
  private func setupAIOverlayCoordinator() {
    let coordinator = AIOverlayCoordinator(configuration: .dashboard)
    coordinator.attach(to: self, contextProvider: self)
    aiOverlayCoordinator = coordinator
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // Reload data when view appears.
    Task {
      await library.loadBundles()
    }
  }

  // MARK: - Setup

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Configure navigation bar.
    title = "InkOS"
    navigationController?.navigationBar.prefersLargeTitles = true

    // Add search button on the left.
    let searchButton = UIBarButtonItem(
      systemItem: .search,
      primaryAction: UIAction { [weak self] _ in
        self?.showSearch()
      }
    )
    navigationItem.leftBarButtonItem = searchButton

    // Add menu button on the right.
    let plusMenu = UIMenu(children: [
      UIAction(title: "New Notebook", image: UIImage(systemName: "doc.badge.plus")) { [weak self] _ in
        self?.createNewNotebook()
      },
      UIAction(title: "New Lesson", image: UIImage(systemName: "book.closed.fill")) { [weak self] _ in
        self?.showNewLessonOverlay()
      },
      UIAction(title: "New Folder", image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
        self?.createNewFolder()
      },
      UIAction(title: "Import PDF", image: UIImage(systemName: "doc.richtext")) { [weak self] _ in
        self?.importPDF()
      }
    ])

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .add,
      primaryAction: nil,
      menu: plusMenu
    )
  }

  private func setupCollectionView() {
    let layout = DashboardLayout.createLayout()
    collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
    collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    collectionView.backgroundColor = .systemBackground
    collectionView.delegate = self

    // Register cells.
    collectionView.register(NotebookCell.self, forCellWithReuseIdentifier: NotebookCell.reuseIdentifier)
    collectionView.register(PDFDocumentCell.self, forCellWithReuseIdentifier: PDFDocumentCell.reuseIdentifier)
    collectionView.register(FolderCell.self, forCellWithReuseIdentifier: FolderCell.reuseIdentifier)
    collectionView.register(LessonCell.self, forCellWithReuseIdentifier: LessonCell.reuseIdentifier)

    view.addSubview(collectionView)
  }

  private func setupDataSource() {
    dataSource = UICollectionViewDiffableDataSource<Section, DashboardItem>(
      collectionView: collectionView
    ) { [weak self] collectionView, indexPath, item in
      self?.configureCell(for: collectionView, at: indexPath, item: item)
    }
  }

  private func setupBindings() {
    // Subscribe to library updates.
    library.$items
      .receive(on: DispatchQueue.main)
      .sink { [weak self] items in
        self?.updateFolderThumbnails()
        self?.applySnapshot(items: items)
      }
      .store(in: &cancellables)
  }

  // MARK: - Data Updates

  private func applySnapshot(items: [DashboardItem], animating: Bool = true) {
    var snapshot = NSDiffableDataSourceSnapshot<Section, DashboardItem>()
    snapshot.appendSections([.main])
    snapshot.appendItems(items, toSection: .main)
    dataSource.apply(snapshot, animatingDifferences: animating)
    isLoading = false
  }

  private func updateFolderThumbnails() {
    // Build thumbnail cache from folder preview images.
    for folder in library.folders {
      let images = folder.previewImages.compactMap { UIImage(data: $0) }
      folderThumbnails[folder.id] = images
    }
  }

  // MARK: - Cell Configuration

  private func configureCell(
    for collectionView: UICollectionView,
    at indexPath: IndexPath,
    item: DashboardItem
  ) -> UICollectionViewCell? {
    switch item {
    case .notebook(let notebook):
      guard let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: NotebookCell.reuseIdentifier,
        for: indexPath
      ) as? NotebookCell else { return nil }
      cell.configure(with: notebook)
      cell.delegate = self
      return cell

    case .pdfDocument(let pdf):
      guard let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: PDFDocumentCell.reuseIdentifier,
        for: indexPath
      ) as? PDFDocumentCell else { return nil }
      cell.configure(with: pdf)
      cell.delegate = self
      return cell

    case .folder(let folder):
      guard let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: FolderCell.reuseIdentifier,
        for: indexPath
      ) as? FolderCell else { return nil }
      let thumbnails = folderThumbnails[folder.id] ?? []
      cell.configure(with: folder, thumbnails: thumbnails)
      cell.delegate = self
      return cell

    case .lesson(let lesson):
      guard let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: LessonCell.reuseIdentifier,
        for: indexPath
      ) as? LessonCell else { return nil }
      cell.configure(with: lesson)
      cell.delegate = self
      return cell
    }
  }

  // MARK: - Actions

  private func createNewNotebook() {
    Task {
      await library.createNotebook()
    }
  }

  private func createNewFolder() {
    let alert = UIAlertController(
      title: "New Folder",
      message: "Enter a name for the folder",
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.placeholder = "Folder name"
      textField.text = "Untitled Folder"
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
      guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
      Task {
        await self?.library.createFolder(displayName: name)
      }
    })
    present(alert, animated: true)
  }

  private func importPDF() {
    // TODO: Implement PDF import picker
  }

  // Shows the search interface.
  private func showSearch() {
    // TODO: Implement search UI
    let alert = UIAlertController(
      title: "Search",
      message: "Search functionality is coming soon.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }

  // Shows the lesson generation overlay.
  private func showNewLessonOverlay() {
    let overlay = LessonGenerationOverlay(
      onGenerate: { [weak self] topic, pdfURL in
        try await self?.generateLesson(prompt: topic, pdfURL: pdfURL)
      },
      onDismiss: { [weak self] in
        self?.dismissLessonOverlay()
      }
    )

    let hostingController = UIHostingController(rootView: overlay)
    hostingController.view.backgroundColor = .clear
    hostingController.modalPresentationStyle = .overFullScreen
    hostingController.modalTransitionStyle = .crossDissolve

    lessonOverlayHostingController = hostingController
    present(hostingController, animated: true)
  }

  // Dismisses the lesson generation overlay.
  private func dismissLessonOverlay() {
    lessonOverlayHostingController?.dismiss(animated: false) { [weak self] in
      self?.lessonOverlayHostingController = nil
    }
  }

  // Generates a lesson with the given prompt and optional PDF.
  private func generateLesson(prompt: String, pdfURL: URL?) async throws {
    // Create generator if needed.
    if lessonGenerator == nil {
      lessonGenerator = LessonGenerator.createDefault(projectID: "inkos-a8de9")
    }

    guard let generator = lessonGenerator else {
      throw NSError(
        domain: "DashboardViewController",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to create lesson generator"]
      )
    }

    // Build the generation request.
    let request = LessonGenerationRequest(
      prompt: prompt,
      displayName: nil,
      pdfURL: pdfURL,
      estimatedMinutes: 15,
      folderID: expandedFolderID
    )

    // Generate the lesson.
    let _ = try await generator.generate(request: request)

    // Reload the library to show the new lesson.
    await library.loadBundles()
  }

  // Shows rename alert for a notebook.
  private func showRenameAlert(for notebook: NotebookMetadata) {
    let alert = UIAlertController(
      title: "Rename Notebook",
      message: "Enter a new name for this notebook.",
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.text = notebook.displayName
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
            !name.isEmpty else { return }
      Task {
        await self?.library.renameNotebook(notebookID: notebook.id, newDisplayName: name)
      }
    })
    present(alert, animated: true)
  }

  // Shows delete confirmation for a notebook.
  private func showDeleteConfirmation(for notebook: NotebookMetadata) {
    let alert = UIAlertController(
      title: "Delete Notebook?",
      message: "\"\(notebook.displayName)\" will be permanently deleted. This cannot be undone.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      Task {
        await self?.library.deleteNotebook(notebookID: notebook.id)
      }
    })
    present(alert, animated: true)
  }

  // Shows rename alert for a PDF.
  private func showRenameAlert(for pdf: PDFDocumentMetadata) {
    let alert = UIAlertController(
      title: "Rename PDF",
      message: "Enter a new name for this PDF.",
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.text = pdf.displayName
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
            !name.isEmpty else { return }
      Task {
        await self?.library.renamePDFDocument(documentID: pdf.id, newDisplayName: name)
      }
    })
    present(alert, animated: true)
  }

  // Shows delete confirmation for a PDF.
  private func showDeleteConfirmation(for pdf: PDFDocumentMetadata) {
    let alert = UIAlertController(
      title: "Delete PDF?",
      message: "\"\(pdf.displayName)\" will be permanently deleted. This cannot be undone.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      Task {
        await self?.library.deletePDFDocument(documentID: pdf.id)
      }
    })
    present(alert, animated: true)
  }

  // Shows rename alert for a folder.
  private func showRenameAlert(for folder: FolderMetadata) {
    let alert = UIAlertController(
      title: "Rename Folder",
      message: "Enter a new name for this folder.",
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.text = folder.displayName
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
            !name.isEmpty else { return }
      Task {
        await self?.library.renameFolder(folderID: folder.id, newDisplayName: name)
      }
    })
    present(alert, animated: true)
  }

  // Shows delete confirmation for a folder.
  private func showDeleteConfirmation(for folder: FolderMetadata) {
    let alert = UIAlertController(
      title: "Delete Folder?",
      message: "\"\(folder.displayName)\" and all its contents will be permanently deleted. This cannot be undone.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      Task {
        await self?.library.deleteFolder(folderID: folder.id)
      }
    })
    present(alert, animated: true)
  }
}

// MARK: - UICollectionViewDelegate

extension DashboardViewController: UICollectionViewDelegate {
  // Cell selection is handled by cell delegates, not here.
  // This avoids double-tap issues with gesture recognizers.
}

// MARK: - NotebookCellDelegate

extension DashboardViewController: NotebookCellDelegate {
  func notebookCellDidTap(_ cell: NotebookCell, notebook: NotebookMetadata) {
    print("[DashboardVC] notebookCellDidTap called for \(notebook.displayName)")
    delegate?.dashboardDidSelectNotebook(notebook)
  }

  func notebookCellDidLongPress(
    _ cell: NotebookCell,
    notebook: NotebookMetadata,
    frame: CGRect,
    cardHeight: CGFloat
  ) {
    // Menu is handled by notebookCellMenu via UIEditMenuInteraction.
  }

  func notebookCellMenu(_ cell: NotebookCell, notebook: NotebookMetadata) -> UIMenu? {
    return UIMenu(children: [
      UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
        self?.showRenameAlert(for: notebook)
      },
      UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
        self?.showDeleteConfirmation(for: notebook)
      }
    ])
  }
}

// MARK: - PDFDocumentCellDelegate

extension DashboardViewController: PDFDocumentCellDelegate {
  func pdfCellDidTap(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata) {
    print("[DashboardVC] pdfCellDidTap called for \(pdf.displayName)")
    delegate?.dashboardDidSelectPDF(pdf)
  }

  func pdfCellDidLongPress(
    _ cell: PDFDocumentCell,
    pdf: PDFDocumentMetadata,
    frame: CGRect,
    cardHeight: CGFloat
  ) {
    // Menu is handled by pdfCellMenu via UIEditMenuInteraction.
  }

  func pdfCellMenu(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata) -> UIMenu? {
    return UIMenu(children: [
      UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
        self?.showRenameAlert(for: pdf)
      },
      UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
        self?.showDeleteConfirmation(for: pdf)
      }
    ])
  }
}

// MARK: - FolderCellDelegate

extension DashboardViewController: FolderCellDelegate {
  func folderCellDidTap(_ cell: FolderCell, folder: FolderMetadata) {
    print("[DashboardVC] folderCellDidTap called for \(folder.displayName)")
    // Get the source frame for animation.
    guard let window = view.window else {
      print("[DashboardVC] folderCellDidTap - no window, returning")
      return
    }
    let sourceFrame = cell.convert(cell.bounds, to: window)

    // Load folder contents and present overlay.
    Task {
      let notebooks = await library.notebooksInFolder(folderID: folder.id)
      let pdfs = await library.pdfDocumentsInFolder(folderID: folder.id)

      await MainActor.run {
        presentFolderOverlay(folder: folder, notebooks: notebooks, pdfs: pdfs, sourceFrame: sourceFrame)
      }
    }
  }

  func folderCellDidLongPress(
    _ cell: FolderCell,
    folder: FolderMetadata,
    frame: CGRect,
    cardHeight: CGFloat
  ) {
    // Menu is handled by folderCellMenu via UIEditMenuInteraction.
  }

  func folderCellMenu(_ cell: FolderCell, folder: FolderMetadata) -> UIMenu? {
    return UIMenu(children: [
      UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
        self?.showRenameAlert(for: folder)
      },
      UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
        self?.showDeleteConfirmation(for: folder)
      }
    ])
  }

  // Presents the folder overlay with custom transition.
  private func presentFolderOverlay(
    folder: FolderMetadata,
    notebooks: [NotebookMetadata],
    pdfs: [PDFDocumentMetadata],
    sourceFrame: CGRect
  ) {
    // Track the expanded folder for AI context.
    expandedFolderID = folder.id

    let overlayVC = FolderOverlayViewController(
      folder: folder,
      notebooks: notebooks,
      pdfDocuments: pdfs,
      sourceFrame: sourceFrame
    )
    overlayVC.delegate = self
    present(overlayVC, animated: true)
  }
}

// MARK: - FolderOverlayDelegate

extension DashboardViewController: FolderOverlayDelegate {
  func folderOverlayDidSelectNotebook(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata) {
    // Dismiss overlay and open notebook.
    overlay.dismiss(animated: true) { [weak self] in
      self?.delegate?.dashboardDidSelectNotebook(notebook)
    }
  }

  func folderOverlayDidSelectPDF(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata) {
    // Dismiss overlay and open PDF.
    overlay.dismiss(animated: true) { [weak self] in
      self?.delegate?.dashboardDidSelectPDF(pdf)
    }
  }

  func folderOverlayDidDismiss(_ overlay: FolderOverlayViewController) {
    // Clear the expanded folder when overlay dismisses.
    expandedFolderID = nil
  }

  func folderOverlayDidRequestRename(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata) {
    let alert = UIAlertController(
      title: "Rename Notebook",
      message: "Enter a new name for this notebook.",
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.text = notebook.displayName
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak overlay] _ in
      guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
            !name.isEmpty else { return }
      Task {
        await self?.library.renameNotebook(notebookID: notebook.id, newDisplayName: name)
        // Refresh folder overlay contents.
        if let overlay, let folderID = overlay.folder.id as String? {
          let notebooks = await self?.library.notebooksInFolder(folderID: folderID) ?? []
          let pdfs = await self?.library.pdfDocumentsInFolder(folderID: folderID) ?? []
          await MainActor.run {
            overlay.updateContents(notebooks: notebooks, pdfDocuments: pdfs)
          }
        }
      }
    })
    overlay.present(alert, animated: true)
  }

  func folderOverlayDidRequestRename(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata) {
    let alert = UIAlertController(
      title: "Rename PDF",
      message: "Enter a new name for this PDF.",
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.text = pdf.displayName
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak overlay] _ in
      guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
            !name.isEmpty else { return }
      Task {
        await self?.library.renamePDFDocument(documentID: pdf.id, newDisplayName: name)
        // Refresh folder overlay contents.
        if let overlay, let folderID = overlay.folder.id as String? {
          let notebooks = await self?.library.notebooksInFolder(folderID: folderID) ?? []
          let pdfs = await self?.library.pdfDocumentsInFolder(folderID: folderID) ?? []
          await MainActor.run {
            overlay.updateContents(notebooks: notebooks, pdfDocuments: pdfs)
          }
        }
      }
    })
    overlay.present(alert, animated: true)
  }

  func folderOverlayDidRequestDelete(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata) {
    let alert = UIAlertController(
      title: "Delete Notebook?",
      message: "\"\(notebook.displayName)\" will be permanently deleted. This cannot be undone.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self, weak overlay] _ in
      Task {
        await self?.library.deleteNotebook(notebookID: notebook.id)
        // Refresh folder overlay contents.
        if let overlay, let folderID = overlay.folder.id as String? {
          let notebooks = await self?.library.notebooksInFolder(folderID: folderID) ?? []
          let pdfs = await self?.library.pdfDocumentsInFolder(folderID: folderID) ?? []
          await MainActor.run {
            overlay.updateContents(notebooks: notebooks, pdfDocuments: pdfs)
          }
        }
      }
    })
    overlay.present(alert, animated: true)
  }

  func folderOverlayDidRequestDelete(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata) {
    let alert = UIAlertController(
      title: "Delete PDF?",
      message: "\"\(pdf.displayName)\" will be permanently deleted. This cannot be undone.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self, weak overlay] _ in
      Task {
        await self?.library.deletePDFDocument(documentID: pdf.id)
        // Refresh folder overlay contents.
        if let overlay, let folderID = overlay.folder.id as String? {
          let notebooks = await self?.library.notebooksInFolder(folderID: folderID) ?? []
          let pdfs = await self?.library.pdfDocumentsInFolder(folderID: folderID) ?? []
          await MainActor.run {
            overlay.updateContents(notebooks: notebooks, pdfDocuments: pdfs)
          }
        }
      }
    })
    overlay.present(alert, animated: true)
  }

  func folderOverlayDidRequestMoveToRoot(_ overlay: FolderOverlayViewController, notebook: NotebookMetadata) {
    let folderID = overlay.folder.id
    Task {
      await library.moveNotebookToRoot(notebookID: notebook.id, fromFolderID: folderID)
      // Refresh folder overlay contents.
      let notebooks = await library.notebooksInFolder(folderID: folderID)
      let pdfs = await library.pdfDocumentsInFolder(folderID: folderID)
      await MainActor.run {
        overlay.updateContents(notebooks: notebooks, pdfDocuments: pdfs)
      }
    }
  }

  func folderOverlayDidRequestMoveToRoot(_ overlay: FolderOverlayViewController, pdf: PDFDocumentMetadata) {
    let folderID = overlay.folder.id
    Task {
      await library.movePDFDocumentToRoot(documentID: pdf.id)
      // Refresh folder overlay contents.
      let notebooks = await library.notebooksInFolder(folderID: folderID)
      let pdfs = await library.pdfDocumentsInFolder(folderID: folderID)
      await MainActor.run {
        overlay.updateContents(notebooks: notebooks, pdfDocuments: pdfs)
      }
    }
  }
}

// MARK: - LessonCellDelegate

extension DashboardViewController: LessonCellDelegate {
  func lessonCellDidTap(_ cell: LessonCell, lesson: LessonMetadata) {
    delegate?.dashboardDidSelectLesson(lesson)
  }

  func lessonCellDidLongPress(
    _ cell: LessonCell,
    lesson: LessonMetadata,
    frame: CGRect,
    cardHeight: CGFloat
  ) {
    // Menu is handled by lessonCellMenu via UIEditMenuInteraction.
  }

  func lessonCellMenu(_ cell: LessonCell, lesson: LessonMetadata) -> UIMenu? {
    return UIMenu(children: [
      UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
        self?.showRenameAlert(for: lesson)
      },
      UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
        self?.showDeleteConfirmation(for: lesson)
      }
    ])
  }

  // Shows rename alert for a lesson.
  private func showRenameAlert(for lesson: LessonMetadata) {
    let alert = UIAlertController(
      title: "Rename Lesson",
      message: "Enter a new name for this lesson.",
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.text = lesson.displayName
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
            !name.isEmpty else { return }
      Task {
        await self?.library.renameLesson(lessonID: lesson.id, newDisplayName: name)
      }
    })
    present(alert, animated: true)
  }

  // Shows delete confirmation for a lesson.
  private func showDeleteConfirmation(for lesson: LessonMetadata) {
    let alert = UIAlertController(
      title: "Delete Lesson?",
      message: "\"\(lesson.displayName)\" will be permanently deleted. This cannot be undone.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      Task {
        await self?.library.deleteLesson(lessonID: lesson.id)
      }
    })
    present(alert, animated: true)
  }
}

// MARK: - AIOverlayContextProvider

extension DashboardViewController: AIOverlayContextProvider {
  // Returns the appropriate location based on folder overlay state.
  var overlayLocation: AIOverlayLocation {
    expandedFolderID != nil ? .folder : .dashboard
  }

  // Dashboard doesn't have a current note.
  var currentNoteID: String? {
    nil
  }

  // Returns the expanded folder ID when viewing folder contents.
  var currentFolderID: String? {
    expandedFolderID
  }
}
