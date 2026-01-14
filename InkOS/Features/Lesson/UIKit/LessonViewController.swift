// LessonViewController.swift
// UIViewController for displaying interactive lessons.
// Inherits from BaseEditorViewController for shared chrome (home button, tool palette, AI overlay).
// Uses UICollectionView with compositional layout for scrollable lesson content.

import UIKit

// Main view controller for viewing and interacting with lessons.
// Displays lesson sections in a vertical scroll with embedded drawing areas.
final class LessonViewController: BaseEditorViewController {

  // MARK: - Properties

  // The lesson ID being displayed.
  private let lessonID: String

  // View model for lesson state management. Created lazily on main thread.
  private var viewModel: LessonViewModel!

  // Collection view displaying lesson sections.
  private var collectionView: UICollectionView!

  // Data source for collection view.
  private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

  // The loaded lesson content.
  private var lesson: Lesson?

  // Tracks which drawing areas are visible for tool palette visibility.
  private var visibleDrawingAreaIDs: Set<String> = []

  // The currently active canvas ID for tool commands.
  private var activeCanvasID: String?

  // Manager for question answer canvases.
  private var questionCanvasManager: QuestionCanvasManager?

  // MARK: - Section and Item Types

  // Collection view sections.
  private enum Section: Int, CaseIterable {
    case header
    case content
  }

  // Collection view items.
  private enum Item: Hashable {
    case header(title: String, subject: String?)
    case content(ContentSection)
    case visual(VisualSection)
    case question(QuestionSection)
    case summary(SummarySection)

    // Returns the section ID for tracking purposes.
    var sectionID: String? {
      switch self {
      case .header: return nil
      case .content(let section): return section.id
      case .visual(let section): return section.id
      case .question(let section): return section.id
      case .summary(let section): return section.id
      }
    }
  }

  // MARK: - Initialization

  init(lessonID: String) {
    self.lessonID = lessonID
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = LessonTypography.Color.background

    // Create view model on main thread (it's @MainActor isolated).
    viewModel = LessonViewModel()

    // Hide tool palette and editing toolbar initially (no drawing areas visible).
    setToolPaletteVisible(false, animated: false)
    setEditingToolbarVisible(false, animated: false)

    setupCollectionView()
    setupDataSource()
    setupQuestionCanvasManager()
    loadLesson()
  }

  // MARK: - Question Canvas Manager Setup

  private func setupQuestionCanvasManager() {
    let manager = QuestionCanvasManager(lessonID: lessonID)
    manager.delegate = self
    manager.attach(to: self)
    questionCanvasManager = manager
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // Save any ink data when leaving.
    Task {
      await saveAllInk()
    }
  }

  // MARK: - BaseEditorViewController Overrides

  override var overlayLocation: AIOverlayLocation {
    .note
  }

  override var currentNoteID: String? {
    lessonID
  }

  override func handleBackButtonTapped() {
    Task {
      // Save progress and ink before dismissing.
      await saveAllInk()

      if let handler = dismissHandler {
        handler()
      } else {
        dismiss(animated: true)
      }
    }
  }

  override func handleToolSelectionChanged(_ tool: ToolPaletteView.ToolSelection) {
    // Forward tool selection to active canvas.
    if activeCanvasID != nil {
      questionCanvasManager?.setTool(tool)
    }
  }

  override func handleToolColorChanged(tool: ToolPaletteView.ToolSelection, hex: String) {
    // Forward color change to active canvas.
    if activeCanvasID != nil {
      questionCanvasManager?.setToolColor(hex: hex, tool: tool)
    }
  }

  override func handleToolThicknessChanged(tool: ToolPaletteView.ToolSelection, width: CGFloat) {
    // Forward thickness change to active canvas.
    if activeCanvasID != nil {
      questionCanvasManager?.setToolThickness(width: width, tool: tool)
    }
  }

  override func handleUndoTapped() {
    // Forward undo to active canvas.
    if activeCanvasID != nil {
      questionCanvasManager?.undo()
    }
  }

  override func handleRedoTapped() {
    // Forward redo to active canvas.
    if activeCanvasID != nil {
      questionCanvasManager?.redo()
    }
  }

  override func handleClearTapped() {
    // Forward clear to active canvas.
    if activeCanvasID != nil {
      questionCanvasManager?.clear()
    }
  }

  // MARK: - Collection View Setup

  private func setupCollectionView() {
    let layout = createLayout()
    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.backgroundColor = .clear
    collectionView.delegate = self
    collectionView.contentInsetAdjustmentBehavior = .always
    collectionView.accessibilityIdentifier = "lessonCollectionView"

    // Add bottom inset for tool palette.
    collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)

    editorContainerView.addSubview(collectionView)

    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: editorContainerView.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: editorContainerView.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: editorContainerView.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: editorContainerView.bottomAnchor)
    ])

    // Register cells.
    collectionView.register(LessonHeaderCell.self, forCellWithReuseIdentifier: LessonHeaderCell.reuseIdentifier)
    collectionView.register(ContentSectionCell.self, forCellWithReuseIdentifier: ContentSectionCell.reuseIdentifier)
    collectionView.register(VisualSectionCell.self, forCellWithReuseIdentifier: VisualSectionCell.reuseIdentifier)
    collectionView.register(QuestionSectionCell.self, forCellWithReuseIdentifier: QuestionSectionCell.reuseIdentifier)
    collectionView.register(SummarySectionCell.self, forCellWithReuseIdentifier: SummarySectionCell.reuseIdentifier)
  }

  private func createLayout() -> UICollectionViewLayout {
    UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
      guard let section = Section(rawValue: sectionIndex) else {
        return self?.createContentSectionLayout(environment: environment)
      }

      switch section {
      case .header:
        return self?.createHeaderSectionLayout(environment: environment)
      case .content:
        return self?.createContentSectionLayout(environment: environment)
      }
    }
  }

  private func createHeaderSectionLayout(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    // Full-width header with estimated height.
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(120)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(120)
    )
    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

    let section = NSCollectionLayoutSection(group: group)

    // Center content with max width for header.
    let maxWidth: CGFloat = 680
    let availableWidth = environment.container.contentSize.width
    let horizontalInset = max(LessonTypography.Spacing.lg, (availableWidth - maxWidth) / 2)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 80,
      leading: horizontalInset,
      bottom: LessonTypography.Spacing.xl,
      trailing: horizontalInset
    )

    return section
  }

  private func createContentSectionLayout(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    // Constrained width content with self-sizing cells.
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

    let section = NSCollectionLayoutSection(group: group)

    // Center content with max width for optimal reading.
    let maxWidth: CGFloat = 680
    let availableWidth = environment.container.contentSize.width
    let horizontalInset = max(LessonTypography.Spacing.lg, (availableWidth - maxWidth) / 2)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: horizontalInset,
      bottom: LessonTypography.Spacing.md,
      trailing: horizontalInset
    )

    return section
  }

  // MARK: - Data Source Setup

  private func setupDataSource() {
    dataSource = UICollectionViewDiffableDataSource<Section, Item>(
      collectionView: collectionView
    ) { [weak self] collectionView, indexPath, item in
      self?.configureCell(for: collectionView, at: indexPath, item: item)
    }
  }

  private func configureCell(
    for collectionView: UICollectionView,
    at indexPath: IndexPath,
    item: Item
  ) -> UICollectionViewCell {
    switch item {
    case .header(let title, let subject):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: LessonHeaderCell.reuseIdentifier,
        for: indexPath
      ) as! LessonHeaderCell
      cell.configure(title: title, subject: subject)
      return cell

    case .content(let section):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: ContentSectionCell.reuseIdentifier,
        for: indexPath
      ) as! ContentSectionCell
      cell.configure(with: section)
      return cell

    case .visual(let section):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: VisualSectionCell.reuseIdentifier,
        for: indexPath
      ) as! VisualSectionCell
      cell.configure(with: section)
      return cell

    case .question(let section):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: QuestionSectionCell.reuseIdentifier,
        for: indexPath
      ) as! QuestionSectionCell
      cell.delegate = self
      cell.configure(with: section, viewModel: viewModel)
      return cell

    case .summary(let section):
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: SummarySectionCell.reuseIdentifier,
        for: indexPath
      ) as! SummarySectionCell
      cell.configure(with: section)
      return cell
    }
  }

  // MARK: - Loading

  private func loadLesson() {
    Task {
      await viewModel.loadLesson(lessonID: lessonID)

      guard let lesson = viewModel.lesson else {
        showError("Failed to load lesson")
        return
      }

      self.lesson = lesson
      applySnapshot(for: lesson)
    }
  }

  private func applySnapshot(for lesson: Lesson) {
    var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

    // Header section.
    snapshot.appendSections([.header])
    snapshot.appendItems(
      [.header(title: lesson.title, subject: lesson.metadata.subject)],
      toSection: .header
    )

    // Content sections.
    snapshot.appendSections([.content])
    let items: [Item] = lesson.sections.map { section in
      switch section {
      case .content(let contentSection):
        return .content(contentSection)
      case .visual(let visualSection):
        return .visual(visualSection)
      case .question(let questionSection):
        return .question(questionSection)
      case .summary(let summarySection):
        return .summary(summarySection)
      }
    }
    snapshot.appendItems(items, toSection: .content)

    dataSource.apply(snapshot, animatingDifferences: false)
  }

  // MARK: - Tool Palette Visibility

  // Updates tool palette visibility based on visible drawing areas.
  private func updateToolPaletteVisibility() {
    let hasVisibleDrawingArea = !visibleDrawingAreaIDs.isEmpty
    setToolPaletteVisible(hasVisibleDrawingArea, animated: true)
    setEditingToolbarVisible(hasVisibleDrawingArea, animated: true)
  }

  // Called when a drawing area becomes visible.
  func registerVisibleDrawingArea(id: String) {
    visibleDrawingAreaIDs.insert(id)
    updateToolPaletteVisibility()
  }

  // Called when a drawing area is no longer visible.
  func unregisterVisibleDrawingArea(id: String) {
    visibleDrawingAreaIDs.remove(id)
    updateToolPaletteVisibility()
  }

  // MARK: - Ink Persistence

  private func saveAllInk() async {
    // Save question canvas ink.
    await questionCanvasManager?.saveAllInk()
  }

  // MARK: - Error Handling

  private func showError(_ message: String) {
    let alert = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(
      UIAlertAction(title: "OK", style: .default) { [weak self] _ in
        self?.handleBackButtonTapped()
      }
    )
    present(alert, animated: true)
  }
}

// MARK: - UICollectionViewDelegate

extension LessonViewController: UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    // Mark content/visual/summary sections as viewed when displayed.
    guard let item = dataSource.itemIdentifier(for: indexPath),
          let sectionID = item.sectionID else {
      return
    }

    Task {
      await viewModel.markSectionViewed(sectionID)
    }
  }
}

// MARK: - QuestionCanvasManagerDelegate

extension LessonViewController: QuestionCanvasManagerDelegate {

  func questionCanvasDidBecomeActive(sectionID: String) {
    // Set question canvas as the active canvas for tool commands.
    activeCanvasID = sectionID

    // Register as visible drawing area.
    registerVisibleDrawingArea(id: sectionID)
  }

  func questionCanvasDidBecomeInactive(sectionID: String) {
    // Clear active canvas if it was this section.
    if activeCanvasID == sectionID {
      activeCanvasID = nil
    }

    // Unregister from visible drawing areas.
    unregisterVisibleDrawingArea(id: sectionID)
  }
}

// MARK: - QuestionSectionCellDelegate

extension LessonViewController: QuestionSectionCellDelegate {

  func questionCell(_ cell: QuestionSectionCell, needsCanvasFor sectionID: String, questionType: QuestionType, in container: UIView) {
    // Embed canvas using the question canvas manager.
    _ = questionCanvasManager?.embedCanvas(in: container, for: sectionID, questionType: questionType)
  }

  func questionCell(_ cell: QuestionSectionCell, didActivateCanvas sectionID: String) {
    // Set this canvas as active for tool commands.
    questionCanvasManager?.setActiveCanvas(sectionID)
  }
}
