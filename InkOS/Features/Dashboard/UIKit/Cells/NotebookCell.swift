// Collection view cell for notebook cards.
// Wraps the existing NotebookCardView UIKit implementation.

import UIKit

// Delegate for notebook cell interactions.
protocol NotebookCellDelegate: AnyObject {
  func notebookCellDidTap(_ cell: NotebookCell, notebook: NotebookMetadata)
  func notebookCellDidLongPress(_ cell: NotebookCell, notebook: NotebookMetadata, frame: CGRect, cardHeight: CGFloat)
  func notebookCellMenu(_ cell: NotebookCell, notebook: NotebookMetadata) -> UIMenu?
}

// Default implementation for optional menu method.
extension NotebookCellDelegate {
  func notebookCellMenu(_ cell: NotebookCell, notebook: NotebookMetadata) -> UIMenu? { nil }
}

class NotebookCell: UICollectionViewCell {
  static let reuseIdentifier = "NotebookCell"

  // The UIKit card view.
  private let cardView = NotebookCardView()

  // Current notebook being displayed.
  private(set) var notebook: NotebookMetadata?

  // Delegate for interaction callbacks.
  weak var delegate: NotebookCellDelegate?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    contentView.backgroundColor = .clear
    backgroundColor = .clear

    // Add card view.
    cardView.translatesAutoresizingMaskIntoConstraints = false
    cardView.delegate = self
    contentView.addSubview(cardView)

    // Pin card view to cell bounds.
    NSLayoutConstraint.activate([
      cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
      cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])

    // Set up menu provider for long press.
    cardView.menuProvider = { [weak self] in
      guard let self, let notebook = self.notebook else { return nil }
      return self.delegate?.notebookCellMenu(self, notebook: notebook)
    }
  }

  // Configures the cell with notebook data.
  func configure(with notebook: NotebookMetadata) {
    self.notebook = notebook
    cardView.configure(with: notebook)

    // Set accessibility identifier for UI testing.
    accessibilityIdentifier = "notebookCard_\(notebook.id)"
    isAccessibilityElement = true
    accessibilityLabel = "Notebook: \(notebook.displayName)"
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    notebook = nil
    // Reset any lift animation.
    cardView.animateLift(false)
  }

  // Resets the lift animation after action sheet dismisses.
  func resetLiftAnimation() {
    cardView.animateLift(false)
  }
}

// MARK: - DashboardCardDelegate

extension NotebookCell: DashboardCardDelegate {
  func cardDidTap(_ card: DashboardCardView) {
    print("[NotebookCell] cardDidTap called")
    guard let notebook else {
      print("[NotebookCell] cardDidTap - no notebook, returning")
      return
    }
    print("[NotebookCell] cardDidTap - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.notebookCellDidTap(self, notebook: notebook)
  }

  func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
    print("[NotebookCell] cardDidLongPress called, frame=\(frame), cardHeight=\(cardHeight)")
    guard let notebook else {
      print("[NotebookCell] cardDidLongPress - no notebook, returning")
      return
    }
    print("[NotebookCell] cardDidLongPress - notebook=\(notebook.displayName)")
    print("[NotebookCell] cardDidLongPress - delegate is \(delegate == nil ? "nil" : "set")")
    delegate?.notebookCellDidLongPress(self, notebook: notebook, frame: frame, cardHeight: cardHeight)
    print("[NotebookCell] cardDidLongPress - delegate notified")
  }
}
