// UIKit dashboard view controller with collection view grid.
// Replaces SwiftUI DashboardView for full animation control.

import Combine
import PDFKit
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

  // MARK: - Search Properties

  // Shared state for search overlay.
  private let searchOverlayState = SearchOverlayState()

  // Search index for SQLite FTS5 queries.
  private var searchIndex: SearchIndex?

  // Search service for transforming results.
  private var searchService: SearchService?

  // Tracks whether the search index has been initialized.
  private var isSearchIndexReady = false

  // Hosting controller for search overlay.
  private var searchOverlayHostingController: UIHostingController<SearchOverlayRootView>?

  // Debounce timer for search queries.
  private var searchDebounceTimer: Timer?

  #if DEBUG
  // Debug data populator for testing search with real notebooks.
  private lazy var debugDataPopulator = DebugDataPopulator(bundleManager: library.bundleManager)
  #endif

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
    setupSearch()
  }

  // Sets up the AI overlay coordinator with dashboard configuration.
  private func setupAIOverlayCoordinator() {
    let coordinator = AIOverlayCoordinator(configuration: .dashboard)
    coordinator.attach(to: self, contextProvider: self)
    aiOverlayCoordinator = coordinator
  }

  // Initializes the search index and service.
  private func setupSearch() {
    Task {
      await initializeSearchIndex()
    }
    setupSearchBindings()
  }

  // Sets up Combine bindings for search text changes.
  private func setupSearchBindings() {
    searchOverlayState.$searchText
      .dropFirst()
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] query in
        self?.handleSearchTextChanged(query)
      }
      .store(in: &cancellables)
  }

  // Handles search text changes with debouncing.
  private func handleSearchTextChanged(_ query: String) {
    searchDebounceTimer?.invalidate()

    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      searchOverlayState.searchResults = []
      searchOverlayState.isSearching = false
      return
    }

    searchOverlayState.isSearching = true
    searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
      Task {
        await self?.performSearch(query: trimmed)
      }
    }
  }

  // Initializes the search index and indexes existing documents.
  private func initializeSearchIndex() async {
    guard !isSearchIndexReady else { return }

    let index = SearchIndex()
    searchIndex = index

    do {
      try await index.initialize()
      let folderLookup = BundleManagerFolderLookup(bundleManager: library.bundleManager)
      let previewLookup = LibraryPreviewLookup(library: library)
      let service = SearchService(index: index, folderLookup: folderLookup, previewLookup: previewLookup)
      searchService = service
      isSearchIndexReady = true
      await indexExistingDocuments()
    } catch {
      print("Failed to initialize search index: \(error.localizedDescription)")
    }
  }

  // Indexes all existing notebooks and PDFs.
  private func indexExistingDocuments() async {
    guard let index = searchIndex else { return }

    let bundleManager = library.bundleManager

    // Index notebooks.
    for notebook in library.notebooks {
      do {
        let handle = try await bundleManager.openNotebook(id: notebook.id)
        let manifest = handle.initialManifest
        let content = await extractNotebookContent(from: handle)
        await handle.close()

        let entry = SearchIndexEntry(
          documentID: notebook.id,
          documentType: .notebook,
          folderID: nil,
          title: manifest.displayName,
          contentText: content,
          modifiedAt: manifest.modifiedAt
        )
        try await index.indexDocument(entry)
      } catch {
        print("Failed to index notebook \(notebook.id): \(error.localizedDescription)")
      }
    }

    // Index PDFs.
    for pdf in library.pdfDocuments {
      do {
        let content = await extractPDFContent(documentID: pdf.id)
        let entry = SearchIndexEntry(
          documentID: pdf.id,
          documentType: .pdf,
          folderID: nil,
          title: pdf.displayName,
          contentText: content,
          modifiedAt: pdf.modifiedAt
        )
        try await index.indexDocument(entry)
      } catch {
        print("Failed to index PDF \(pdf.id): \(error.localizedDescription)")
      }
    }

    // Index lessons.
    print("[Search] Indexing \(library.lessons.count) lessons")
    for lesson in library.lessons {
      do {
        let content = await extractLessonContent(lessonID: lesson.id)
        print("[Search] Indexing lesson '\(lesson.displayName)' with \(content.count) chars of content")
        let entry = SearchIndexEntry(
          documentID: lesson.id,
          documentType: .lesson,
          folderID: nil,
          title: lesson.displayName,
          contentText: content,
          modifiedAt: lesson.modifiedAt
        )
        try await index.indexDocument(entry)
        print("[Search] Successfully indexed lesson '\(lesson.displayName)'")
      } catch {
        print("[Search] Failed to index lesson \(lesson.id): \(error.localizedDescription)")
      }
    }
  }

  // Extracts text content from a notebook's JIIX data.
  private func extractNotebookContent(from handle: DocumentHandle) async -> String {
    do {
      guard let jiixData = try await handle.loadJIIXData() else { return "" }

      if let json = try JSONSerialization.jsonObject(with: jiixData) as? [String: Any],
         let label = json["label"] as? String {
        return label
      }
    } catch {
      print("Failed to load/parse JIIX: \(error.localizedDescription)")
    }
    return ""
  }

  // Extracts text content from a PDF document.
  private func extractPDFContent(documentID: String) async -> String {
    do {
      guard let uuid = UUID(uuidString: documentID) else { return "" }
      let documentDir = try await PDFNoteStorage.documentDirectory(for: uuid)
      let pdfURL = documentDir.appendingPathComponent("source.pdf")

      guard let pdfDoc = PDFDocument(url: pdfURL) else { return "" }

      var content = ""
      for pageIndex in 0..<pdfDoc.pageCount {
        if let page = pdfDoc.page(at: pageIndex),
           let pageContent = page.string {
          content += pageContent + " "
        }
      }
      return content.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      print("Failed to extract PDF content: \(error.localizedDescription)")
      return ""
    }
  }

  // Extracts searchable text content from a lesson.
  // Includes lesson title, section prompts, content, questions, and answers.
  private func extractLessonContent(lessonID: String) async -> String {
    let bundleManager = library.bundleManager
    do {
      let lesson = try await bundleManager.loadLesson(lessonID: lessonID)
      var content = ""

      // Add lesson title.
      content += lesson.title + " "

      // Add subject if present.
      if let subject = lesson.metadata.subject {
        content += subject + " "
      }

      // Extract text from each section.
      for section in lesson.sections {
        switch section {
        case .content(let contentSection):
          // Add markdown content.
          content += contentSection.content + " "

        case .visual(let visualSection):
          // Add image prompt and fallback description if present.
          if let imagePrompt = visualSection.imagePrompt {
            content += imagePrompt + " "
          }
          if let fallbackDescription = visualSection.fallbackDescription {
            content += fallbackDescription + " "
          }

        case .question(let questionSection):
          // Add question prompt, answer, and explanation.
          content += questionSection.prompt + " "
          content += questionSection.answer + " "
          if let explanation = questionSection.explanation {
            content += explanation + " "
          }
          // Add multiple choice options if present.
          if let options = questionSection.options {
            content += options.joined(separator: " ") + " "
          }

        case .summary(let summarySection):
          // Add summary content.
          content += summarySection.content + " "
        }
      }

      return content.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      print("Failed to extract lesson content: \(error.localizedDescription)")
      return ""
    }
  }

  // Performs a search query against the search service.
  private func performSearch(query: String) async {
    guard let searchService = searchService, isSearchIndexReady else {
      await MainActor.run {
        searchOverlayState.isSearching = false
        searchOverlayState.searchResults = []
      }
      return
    }

    do {
      let results = try await searchService.searchAll(query: query)
      await MainActor.run {
        searchOverlayState.searchResults = results
        searchOverlayState.isSearching = false
      }
    } catch {
      print("Search error: \(error.localizedDescription)")
      await MainActor.run {
        searchOverlayState.searchResults = []
        searchOverlayState.isSearching = false
      }
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // Reload data when view appears.
    Task {
      await library.loadBundles()
      // Reindex documents after bundles are loaded to catch any new/updated content.
      await indexExistingDocuments()
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
    // Create the search overlay view.
    var overlayView = SearchOverlayRootView(
      state: searchOverlayState,
      onDismiss: { [weak self] in
        self?.dismissSearch()
      },
      onClear: { [weak self] in
        self?.searchOverlayState.searchText = ""
      },
      onResultTapped: { [weak self] result in
        self?.handleSearchResultTapped(result)
      }
    )

    // Set up debug callbacks.
    #if DEBUG
    overlayView.onPopulateDebugData = { [weak self] in
      self?.populateDebugData()
    }
    overlayView.onClearDebugData = { [weak self] in
      self?.clearDebugData()
    }
    #endif

    // Create hosting controller.
    let hostingController = UIHostingController(rootView: overlayView)
    hostingController.view.backgroundColor = .clear
    hostingController.modalPresentationStyle = .overFullScreen
    hostingController.modalTransitionStyle = .crossDissolve

    searchOverlayHostingController = hostingController

    // Present and expand.
    present(hostingController, animated: false) { [weak self] in
      self?.searchOverlayState.isExpanded = true
      self?.searchOverlayState.isSearchFieldFocused = true
    }
  }

  // Dismisses the search overlay.
  private func dismissSearch() {
    searchOverlayState.isExpanded = false
    searchOverlayState.isSearchFieldFocused = false

    // Delay dismissal to allow animation.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      self?.searchOverlayHostingController?.dismiss(animated: false) {
        self?.searchOverlayHostingController = nil
        self?.searchOverlayState.searchText = ""
        self?.searchOverlayState.searchResults = []
      }
    }
  }

  #if DEBUG
  // Populates the dashboard with debug test data.
  // Creates notebooks with JIIX content and folders for testing search.
  private func populateDebugData() {
    Task {
      do {
        let count = try await debugDataPopulator.populateTestData()
        print("[DashboardViewController] Populated \(count) debug items")

        // Reload library to show new items.
        await library.loadBundles()

        // Reindex to include new items in search.
        await indexExistingDocuments()

        // Show success feedback.
        await MainActor.run {
          let alert = UIAlertController(
            title: "Debug Data Created",
            message: "Created \(count) test items with JIIX content.\n\nTry searching for: budget, calculus, cookie, or project",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default))
          self.searchOverlayHostingController?.present(alert, animated: true)
        }
      } catch {
        print("[DashboardViewController] Failed to populate debug data: \(error.localizedDescription)")
        await MainActor.run {
          let alert = UIAlertController(
            title: "Error",
            message: "Failed to create debug data: \(error.localizedDescription)",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default))
          self.searchOverlayHostingController?.present(alert, animated: true)
        }
      }
    }
  }

  // Clears only debug-created data from the dashboard.
  // Does not affect user-created items.
  private func clearDebugData() {
    Task {
      do {
        let count = try await debugDataPopulator.clearDebugData()
        print("[DashboardViewController] Cleared \(count) debug items")

        // Reload library to reflect deletions.
        await library.loadBundles()

        // Reinitialize search index to remove deleted items.
        isSearchIndexReady = false
        await initializeSearchIndex()

        // Show success feedback.
        await MainActor.run {
          let alert = UIAlertController(
            title: "Debug Data Cleared",
            message: "Removed \(count) debug items.",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default))
          self.searchOverlayHostingController?.present(alert, animated: true)
        }
      } catch {
        print("[DashboardViewController] Failed to clear debug data: \(error.localizedDescription)")
        await MainActor.run {
          let alert = UIAlertController(
            title: "Error",
            message: "Failed to clear debug data: \(error.localizedDescription)",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default))
          self.searchOverlayHostingController?.present(alert, animated: true)
        }
      }
    }
  }
  #endif

  // Handles tapping on a search result.
  private func handleSearchResultTapped(_ result: SearchResult) {
    dismissSearch()

    // Delay navigation to allow overlay to dismiss.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
      guard let self = self else { return }

      switch result.documentType {
      case .notebook:
        // Find the notebook and open it.
        if let notebook = self.library.notebooks.first(where: { $0.id == result.documentID }) {
          self.delegate?.dashboardDidSelectNotebook(notebook)
        }
      case .pdf:
        // Find the PDF and open it.
        if let pdf = self.library.pdfDocuments.first(where: { $0.id == result.documentID }) {
          self.delegate?.dashboardDidSelectPDF(pdf)
        }
      case .lesson:
        // Find the lesson and open it.
        if let lesson = self.library.lessons.first(where: { $0.id == result.documentID }) {
          self.delegate?.dashboardDidSelectLesson(lesson)
        }
      case .folder:
        // Find the folder and open its overlay.
        if let folder = self.library.folders.first(where: { $0.id == result.documentID }) {
          self.openFolderFromSearch(folder)
        }
      }
    }
  }

  // Opens a folder overlay when a folder is selected from search results.
  // Uses screen center as source frame since there's no cell to animate from.
  private func openFolderFromSearch(_ folder: FolderMetadata) {
    Task {
      let notebooks = await library.notebooksInFolder(folderID: folder.id)
      let pdfs = await library.pdfDocumentsInFolder(folderID: folder.id)

      await MainActor.run {
        // Use center of screen as source frame for animation.
        let centerFrame = CGRect(
          x: view.bounds.midX - 50,
          y: view.bounds.midY - 50,
          width: 100,
          height: 100
        )
        presentFolderOverlay(folder: folder, notebooks: notebooks, pdfs: pdfs, sourceFrame: centerFrame)
      }
    }
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
    // Reindex to include the new lesson in search.
    await indexExistingDocuments()
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
    delegate?.dashboardDidSelectNotebook(notebook)
  }

  func notebookCellDidLongPress(
    _ cell: NotebookCell,
    notebook: NotebookMetadata,
    frame: CGRect,
    cardHeight: CGFloat
  ) {
    // Show context menu.
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      self?.showRenameAlert(for: notebook)
    })
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      self?.showDeleteConfirmation(for: notebook)
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    // Configure popover for iPad.
    if let popover = alert.popoverPresentationController {
      popover.sourceView = cell
      popover.sourceRect = cell.bounds
    }

    present(alert, animated: true)
  }

  func notebookCellDidStartDrag(
    _ cell: NotebookCell,
    notebook: NotebookMetadata,
    frame: CGRect,
    position: CGPoint
  ) {
    // Phase 3: Drag handling
  }

  func notebookCellDidMoveDrag(_ cell: NotebookCell, position: CGPoint) {
    // Phase 3: Drag handling
  }

  func notebookCellDidEndDrag(_ cell: NotebookCell, position: CGPoint) {
    // Phase 3: Drag handling
  }
}

// MARK: - PDFDocumentCellDelegate

extension DashboardViewController: PDFDocumentCellDelegate {
  func pdfCellDidTap(_ cell: PDFDocumentCell, pdf: PDFDocumentMetadata) {
    delegate?.dashboardDidSelectPDF(pdf)
  }

  func pdfCellDidLongPress(
    _ cell: PDFDocumentCell,
    pdf: PDFDocumentMetadata,
    frame: CGRect,
    cardHeight: CGFloat
  ) {
    // Show context menu.
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      self?.showRenameAlert(for: pdf)
    })
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      self?.showDeleteConfirmation(for: pdf)
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = alert.popoverPresentationController {
      popover.sourceView = cell
      popover.sourceRect = cell.bounds
    }

    present(alert, animated: true)
  }

  func pdfCellDidStartDrag(
    _ cell: PDFDocumentCell,
    pdf: PDFDocumentMetadata,
    frame: CGRect,
    position: CGPoint
  ) {
    // Phase 3: Drag handling
  }

  func pdfCellDidMoveDrag(_ cell: PDFDocumentCell, position: CGPoint) {
    // Phase 3: Drag handling
  }

  func pdfCellDidEndDrag(_ cell: PDFDocumentCell, position: CGPoint) {
    // Phase 3: Drag handling
  }
}

// MARK: - FolderCellDelegate

extension DashboardViewController: FolderCellDelegate {
  func folderCellDidTap(_ cell: FolderCell, folder: FolderMetadata) {
    // Get the source frame for animation.
    guard let window = view.window else { return }
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
    // Show context menu.
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      self?.showRenameAlert(for: folder)
    })
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      self?.showDeleteConfirmation(for: folder)
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = alert.popoverPresentationController {
      popover.sourceView = cell
      popover.sourceRect = cell.bounds
    }

    present(alert, animated: true)
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
    // Show context menu.
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
      self?.showRenameAlert(for: lesson)
    })
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      self?.showDeleteConfirmation(for: lesson)
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    // Configure popover for iPad.
    if let popover = alert.popoverPresentationController {
      popover.sourceView = cell
      popover.sourceRect = cell.bounds
    }

    present(alert, animated: true)
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
