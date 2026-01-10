import SwiftUI
import UIKit

// MARK: - Notebook Card Representable

// UIViewRepresentable wrapper for NotebookCardView.
// Embeds the UIKit card in SwiftUI and handles tap and context menu callbacks.
struct NotebookCardRepresentable: UIViewRepresentable {
  let notebook: NotebookMetadata
  let onTap: () -> Void
  var titleOpacity: Double = 1.0

  // Context menu action callbacks.
  var onRename: (() -> Void)?
  var onDelete: (() -> Void)?
  var onMoveToFolder: (() -> Void)?
  var onMoveOutOfFolder: (() -> Void)?

  func makeUIView(context: Context) -> NotebookCardContainerView {
    let container = NotebookCardContainerView()
    container.backgroundColor = .clear

    let cardView = NotebookCardView()
    cardView.delegate = context.coordinator
    cardView.contextMenuProvider = context.coordinator
    cardView.configure(with: notebook)
    cardView.titleOpacity = titleOpacity

    container.cardView = cardView
    container.addSubview(cardView)

    context.coordinator.cardView = cardView
    context.coordinator.containerView = container

    return container
  }

  func updateUIView(_ container: NotebookCardContainerView, context: Context) {
    // Update callbacks.
    context.coordinator.onTap = onTap
    context.coordinator.notebook = notebook
    context.coordinator.onRename = onRename
    context.coordinator.onDelete = onDelete
    context.coordinator.onMoveToFolder = onMoveToFolder
    context.coordinator.onMoveOutOfFolder = onMoveOutOfFolder

    // Update card content.
    container.cardView?.configure(with: notebook)
    container.cardView?.titleOpacity = titleOpacity
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      notebook: notebook,
      onTap: onTap,
      onRename: onRename,
      onDelete: onDelete,
      onMoveToFolder: onMoveToFolder,
      onMoveOutOfFolder: onMoveOutOfFolder
    )
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, DashboardCardDelegate, DashboardCardContextMenuProvider {
    var notebook: NotebookMetadata
    var onTap: () -> Void
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMoveToFolder: (() -> Void)?
    var onMoveOutOfFolder: (() -> Void)?

    weak var cardView: NotebookCardView?
    weak var containerView: NotebookCardContainerView?

    init(
      notebook: NotebookMetadata,
      onTap: @escaping () -> Void,
      onRename: (() -> Void)?,
      onDelete: (() -> Void)?,
      onMoveToFolder: (() -> Void)?,
      onMoveOutOfFolder: (() -> Void)?
    ) {
      self.notebook = notebook
      self.onTap = onTap
      self.onRename = onRename
      self.onDelete = onDelete
      self.onMoveToFolder = onMoveToFolder
      self.onMoveOutOfFolder = onMoveOutOfFolder
    }

    // MARK: - DashboardCardDelegate

    func cardDidTap(_ card: DashboardCardView) {
      onTap()
    }

    // MARK: - DashboardCardContextMenuProvider

    func contextMenuConfiguration(for card: DashboardCardView) -> UIContextMenuConfiguration? {
      // Only show context menu if at least one action is available.
      guard onRename != nil || onDelete != nil || onMoveToFolder != nil || onMoveOutOfFolder != nil else {
        return nil
      }

      return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
        guard let self else { return nil }
        return self.buildMenu()
      }
    }

    func contextMenuPreviewViewController(for card: DashboardCardView) -> UIViewController? {
      return nil
    }

    private func buildMenu() -> UIMenu {
      var actions: [UIMenuElement] = []

      // Rename action.
      if let onRename {
        let renameAction = UIAction(
          title: "Rename",
          image: UIImage(systemName: "pencil")
        ) { _ in
          onRename()
        }
        actions.append(renameAction)
      }

      // Move to folder action.
      if let onMoveToFolder {
        let moveAction = UIAction(
          title: "Move to Folder",
          image: UIImage(systemName: "folder")
        ) { _ in
          onMoveToFolder()
        }
        actions.append(moveAction)
      }

      // Move out of folder action.
      if let onMoveOutOfFolder {
        let moveOutAction = UIAction(
          title: "Move Out of Folder",
          image: UIImage(systemName: "folder.badge.minus")
        ) { _ in
          onMoveOutOfFolder()
        }
        actions.append(moveOutAction)
      }

      // Delete action (destructive, at the end).
      if let onDelete {
        let deleteAction = UIAction(
          title: "Delete",
          image: UIImage(systemName: "trash"),
          attributes: .destructive
        ) { _ in
          onDelete()
        }
        actions.append(deleteAction)
      }

      return UIMenu(children: actions)
    }
  }
}

// MARK: - Notebook Card Container View

// Container view that maintains size.
class NotebookCardContainerView: UIView {
  var cardView: NotebookCardView?

  override var intrinsicContentSize: CGSize {
    return bounds.size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    cardView?.frame = bounds
  }
}

// MARK: - PDF Card Representable

// UIViewRepresentable wrapper for PDFCardView.
// Same pattern as NotebookCardRepresentable.
struct PDFCardRepresentable: UIViewRepresentable {
  let pdfDocument: PDFDocumentMetadata
  let onTap: () -> Void
  var titleOpacity: Double = 1.0

  // Context menu action callbacks.
  var onRename: (() -> Void)?
  var onDelete: (() -> Void)?
  var onMoveToFolder: (() -> Void)?
  var onMoveOutOfFolder: (() -> Void)?

  func makeUIView(context: Context) -> PDFCardContainerView {
    let container = PDFCardContainerView()
    container.backgroundColor = .clear

    let cardView = PDFCardView()
    cardView.delegate = context.coordinator
    cardView.contextMenuProvider = context.coordinator
    cardView.configure(with: pdfDocument)
    cardView.titleOpacity = titleOpacity

    container.cardView = cardView
    container.addSubview(cardView)

    context.coordinator.cardView = cardView
    context.coordinator.containerView = container

    return container
  }

  func updateUIView(_ container: PDFCardContainerView, context: Context) {
    // Update callbacks.
    context.coordinator.onTap = onTap
    context.coordinator.pdfDocument = pdfDocument
    context.coordinator.onRename = onRename
    context.coordinator.onDelete = onDelete
    context.coordinator.onMoveToFolder = onMoveToFolder
    context.coordinator.onMoveOutOfFolder = onMoveOutOfFolder

    // Update card content.
    container.cardView?.configure(with: pdfDocument)
    container.cardView?.titleOpacity = titleOpacity
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      pdfDocument: pdfDocument,
      onTap: onTap,
      onRename: onRename,
      onDelete: onDelete,
      onMoveToFolder: onMoveToFolder,
      onMoveOutOfFolder: onMoveOutOfFolder
    )
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, DashboardCardDelegate, DashboardCardContextMenuProvider {
    var pdfDocument: PDFDocumentMetadata
    var onTap: () -> Void
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMoveToFolder: (() -> Void)?
    var onMoveOutOfFolder: (() -> Void)?

    weak var cardView: PDFCardView?
    weak var containerView: PDFCardContainerView?

    init(
      pdfDocument: PDFDocumentMetadata,
      onTap: @escaping () -> Void,
      onRename: (() -> Void)?,
      onDelete: (() -> Void)?,
      onMoveToFolder: (() -> Void)?,
      onMoveOutOfFolder: (() -> Void)?
    ) {
      self.pdfDocument = pdfDocument
      self.onTap = onTap
      self.onRename = onRename
      self.onDelete = onDelete
      self.onMoveToFolder = onMoveToFolder
      self.onMoveOutOfFolder = onMoveOutOfFolder
    }

    // MARK: - DashboardCardDelegate

    func cardDidTap(_ card: DashboardCardView) {
      onTap()
    }

    // MARK: - DashboardCardContextMenuProvider

    func contextMenuConfiguration(for card: DashboardCardView) -> UIContextMenuConfiguration? {
      guard onRename != nil || onDelete != nil || onMoveToFolder != nil || onMoveOutOfFolder != nil else {
        return nil
      }

      return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
        guard let self else { return nil }
        return self.buildMenu()
      }
    }

    func contextMenuPreviewViewController(for card: DashboardCardView) -> UIViewController? {
      return nil
    }

    private func buildMenu() -> UIMenu {
      var actions: [UIMenuElement] = []

      if let onRename {
        let renameAction = UIAction(
          title: "Rename",
          image: UIImage(systemName: "pencil")
        ) { _ in
          onRename()
        }
        actions.append(renameAction)
      }

      if let onMoveToFolder {
        let moveAction = UIAction(
          title: "Move to Folder",
          image: UIImage(systemName: "folder")
        ) { _ in
          onMoveToFolder()
        }
        actions.append(moveAction)
      }

      if let onMoveOutOfFolder {
        let moveOutAction = UIAction(
          title: "Move Out of Folder",
          image: UIImage(systemName: "folder.badge.minus")
        ) { _ in
          onMoveOutOfFolder()
        }
        actions.append(moveOutAction)
      }

      if let onDelete {
        let deleteAction = UIAction(
          title: "Delete",
          image: UIImage(systemName: "trash"),
          attributes: .destructive
        ) { _ in
          onDelete()
        }
        actions.append(deleteAction)
      }

      return UIMenu(children: actions)
    }
  }
}

// MARK: - PDF Card Container View

// Container view that maintains size.
class PDFCardContainerView: UIView {
  var cardView: PDFCardView?

  override var intrinsicContentSize: CGSize {
    return bounds.size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    cardView?.frame = bounds
  }
}
