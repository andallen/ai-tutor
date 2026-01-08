import SwiftUI
import UIKit

// MARK: - Notebook Card Representable

// UIViewRepresentable wrapper for NotebookCardView.
// Embeds the UIKit card in SwiftUI and handles all callbacks.
// During drag, the card view is reparented to the window for smooth dragging.
struct NotebookCardRepresentable: UIViewRepresentable {
  let notebook: NotebookMetadata
  let onTap: () -> Void
  let onLongPress: (CGRect, CGFloat) -> Void
  let onDragStart: (NotebookMetadata, CGRect, CGPoint) -> Void
  let onDragMove: (CGPoint) -> Void
  // Completion callback receives: true = animate return, false = remove immediately (dropped on target).
  let onDragEnd: (CGPoint, @escaping (Bool) -> Void) -> Void
  var titleOpacity: Double = 1.0

  func makeUIView(context: Context) -> NotebookCardContainerView {
    let container = NotebookCardContainerView()
    container.backgroundColor = .clear

    let cardView = NotebookCardView()
    cardView.delegate = context.coordinator
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
    context.coordinator.onLongPress = onLongPress
    context.coordinator.onDragStart = onDragStart
    context.coordinator.onDragMove = onDragMove
    context.coordinator.onDragEnd = onDragEnd
    context.coordinator.notebook = notebook

    // Update card content if not dragging.
    if !context.coordinator.isDragging {
      container.cardView?.configure(with: notebook)
      container.cardView?.titleOpacity = titleOpacity
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      notebook: notebook,
      onTap: onTap,
      onLongPress: onLongPress,
      onDragStart: onDragStart,
      onDragMove: onDragMove,
      onDragEnd: onDragEnd
    )
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, DashboardCardDelegate {
    var notebook: NotebookMetadata
    var onTap: () -> Void
    var onLongPress: (CGRect, CGFloat) -> Void
    var onDragStart: (NotebookMetadata, CGRect, CGPoint) -> Void
    var onDragMove: (CGPoint) -> Void
    var onDragEnd: (CGPoint, @escaping (Bool) -> Void) -> Void

    weak var cardView: NotebookCardView?
    weak var containerView: NotebookCardContainerView?

    // Drag state.
    var isDragging = false
    private var originalSuperview: UIView?
    private var originalFrame: CGRect = .zero

    init(
      notebook: NotebookMetadata,
      onTap: @escaping () -> Void,
      onLongPress: @escaping (CGRect, CGFloat) -> Void,
      onDragStart: @escaping (NotebookMetadata, CGRect, CGPoint) -> Void,
      onDragMove: @escaping (CGPoint) -> Void,
      onDragEnd: @escaping (CGPoint, @escaping (Bool) -> Void) -> Void
    ) {
      self.notebook = notebook
      self.onTap = onTap
      self.onLongPress = onLongPress
      self.onDragStart = onDragStart
      self.onDragMove = onDragMove
      self.onDragEnd = onDragEnd
    }

    // MARK: - DashboardCardDelegate

    func cardDidTap(_ card: DashboardCardView) {
      onTap()
    }

    func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
      onLongPress(frame, cardHeight)
    }

    func cardDidStartDrag(_ card: DashboardCardView, frame: CGRect, position: CGPoint) {
      guard let cardView = cardView, let window = cardView.window else { return }

      isDragging = true

      // Remember original parent and frame.
      originalSuperview = cardView.superview
      originalFrame = cardView.frame

      // Convert frame to window coordinates.
      let windowFrame = cardView.convert(cardView.bounds, to: window)

      // Reparent card to window.
      cardView.removeFromSuperview()
      cardView.frame = windowFrame
      window.addSubview(cardView)

      // Animate lift to finger position.
      UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
        cardView.center = position
      }

      // Notify parent.
      onDragStart(notebook, frame, position)
    }

    func cardDidMoveDrag(_ card: DashboardCardView, position: CGPoint) {
      guard isDragging, let cardView = cardView else { return }

      // Move card to finger position.
      cardView.center = position

      onDragMove(position)
    }

    func cardDidEndDrag(_ card: DashboardCardView, position: CGPoint) {
      guard isDragging else { return }

      // Ask parent what to do. Parent calls completion with:
      // - true: animate return to original position
      // - false: remove card immediately (dropped on target)
      onDragEnd(position) { [weak self] shouldAnimateReturn in
        if shouldAnimateReturn {
          self?.animateReturn()
        } else {
          self?.removeImmediately()
        }
      }
    }

    // Animates the card back to its original position in the grid.
    private func animateReturn() {
      guard let cardView = cardView, let container = containerView else {
        isDragging = false
        return
      }

      // Target is the container's current position in window coordinates.
      let returnFrame: CGRect
      if let window = cardView.window {
        returnFrame = container.convert(container.bounds, to: window)
      } else {
        returnFrame = originalFrame
      }

      UIView.animate(
        withDuration: 0.4,
        delay: 0,
        usingSpringWithDamping: 0.75,
        initialSpringVelocity: 0,
        options: []
      ) {
        cardView.frame = returnFrame
      } completion: { [weak self] _ in
        self?.reparentToContainer()
      }
    }

    // Removes the card immediately (for dropping on targets).
    private func removeImmediately() {
      cardView?.removeFromSuperview()
      isDragging = false
      originalSuperview = nil
      originalFrame = .zero
    }

    // Reparents the card back to its container after animation.
    private func reparentToContainer() {
      guard let cardView = cardView, let container = containerView else {
        isDragging = false
        return
      }

      cardView.removeFromSuperview()
      cardView.frame = CGRect(origin: .zero, size: container.bounds.size)
      container.addSubview(cardView)

      isDragging = false
      originalSuperview = nil
      originalFrame = .zero
    }
  }
}

// MARK: - Notebook Card Container View

// Container view that maintains size when card is reparented during drag.
// This prevents the SwiftUI grid from collapsing when the card is removed.
class NotebookCardContainerView: UIView {
  var cardView: NotebookCardView?

  override var intrinsicContentSize: CGSize {
    return bounds.size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Only layout card if it's our subview (not reparented).
    if let cardView = cardView, cardView.superview == self {
      cardView.frame = bounds
    }
  }
}

// MARK: - PDF Card Representable

// UIViewRepresentable wrapper for PDFCardView.
// Same pattern as NotebookCardRepresentable.
struct PDFCardRepresentable: UIViewRepresentable {
  let pdfDocument: PDFDocumentMetadata
  let onTap: () -> Void
  let onLongPress: (CGRect, CGFloat) -> Void
  let onDragStart: (PDFDocumentMetadata, CGRect, CGPoint) -> Void
  let onDragMove: (CGPoint) -> Void
  // Completion callback receives: true = animate return, false = remove immediately (dropped on target).
  let onDragEnd: (CGPoint, @escaping (Bool) -> Void) -> Void
  var titleOpacity: Double = 1.0

  func makeUIView(context: Context) -> PDFCardContainerView {
    let container = PDFCardContainerView()
    container.backgroundColor = .clear

    let cardView = PDFCardView()
    cardView.delegate = context.coordinator
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
    context.coordinator.onLongPress = onLongPress
    context.coordinator.onDragStart = onDragStart
    context.coordinator.onDragMove = onDragMove
    context.coordinator.onDragEnd = onDragEnd
    context.coordinator.pdfDocument = pdfDocument

    // Update card content if not dragging.
    if !context.coordinator.isDragging {
      container.cardView?.configure(with: pdfDocument)
      container.cardView?.titleOpacity = titleOpacity
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      pdfDocument: pdfDocument,
      onTap: onTap,
      onLongPress: onLongPress,
      onDragStart: onDragStart,
      onDragMove: onDragMove,
      onDragEnd: onDragEnd
    )
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, DashboardCardDelegate {
    var pdfDocument: PDFDocumentMetadata
    var onTap: () -> Void
    var onLongPress: (CGRect, CGFloat) -> Void
    var onDragStart: (PDFDocumentMetadata, CGRect, CGPoint) -> Void
    var onDragMove: (CGPoint) -> Void
    var onDragEnd: (CGPoint, @escaping (Bool) -> Void) -> Void

    weak var cardView: PDFCardView?
    weak var containerView: PDFCardContainerView?

    // Drag state.
    var isDragging = false
    private var originalSuperview: UIView?
    private var originalFrame: CGRect = .zero

    init(
      pdfDocument: PDFDocumentMetadata,
      onTap: @escaping () -> Void,
      onLongPress: @escaping (CGRect, CGFloat) -> Void,
      onDragStart: @escaping (PDFDocumentMetadata, CGRect, CGPoint) -> Void,
      onDragMove: @escaping (CGPoint) -> Void,
      onDragEnd: @escaping (CGPoint, @escaping (Bool) -> Void) -> Void
    ) {
      self.pdfDocument = pdfDocument
      self.onTap = onTap
      self.onLongPress = onLongPress
      self.onDragStart = onDragStart
      self.onDragMove = onDragMove
      self.onDragEnd = onDragEnd
    }

    // MARK: - DashboardCardDelegate

    func cardDidTap(_ card: DashboardCardView) {
      onTap()
    }

    func cardDidLongPress(_ card: DashboardCardView, frame: CGRect, cardHeight: CGFloat) {
      onLongPress(frame, cardHeight)
    }

    func cardDidStartDrag(_ card: DashboardCardView, frame: CGRect, position: CGPoint) {
      guard let cardView = cardView, let window = cardView.window else { return }

      isDragging = true

      // Remember original parent and frame.
      originalSuperview = cardView.superview
      originalFrame = cardView.frame

      // Convert frame to window coordinates.
      let windowFrame = cardView.convert(cardView.bounds, to: window)

      // Reparent card to window.
      cardView.removeFromSuperview()
      cardView.frame = windowFrame
      window.addSubview(cardView)

      // Animate lift to finger position.
      UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
        cardView.center = position
      }

      // Notify parent.
      onDragStart(pdfDocument, frame, position)
    }

    func cardDidMoveDrag(_ card: DashboardCardView, position: CGPoint) {
      guard isDragging, let cardView = cardView else { return }

      // Move card to finger position.
      cardView.center = position

      onDragMove(position)
    }

    func cardDidEndDrag(_ card: DashboardCardView, position: CGPoint) {
      guard isDragging else { return }

      // Ask parent what to do. Parent calls completion with:
      // - true: animate return to original position
      // - false: remove card immediately (dropped on target)
      onDragEnd(position) { [weak self] shouldAnimateReturn in
        if shouldAnimateReturn {
          self?.animateReturn()
        } else {
          self?.removeImmediately()
        }
      }
    }

    // Animates the card back to its original position in the grid.
    private func animateReturn() {
      guard let cardView = cardView, let container = containerView else {
        isDragging = false
        return
      }

      // Target is the container's current position in window coordinates.
      let returnFrame: CGRect
      if let window = cardView.window {
        returnFrame = container.convert(container.bounds, to: window)
      } else {
        returnFrame = originalFrame
      }

      UIView.animate(
        withDuration: 0.4,
        delay: 0,
        usingSpringWithDamping: 0.75,
        initialSpringVelocity: 0,
        options: []
      ) {
        cardView.frame = returnFrame
      } completion: { [weak self] _ in
        self?.reparentToContainer()
      }
    }

    // Removes the card immediately (for dropping on targets).
    private func removeImmediately() {
      cardView?.removeFromSuperview()
      isDragging = false
      originalSuperview = nil
      originalFrame = .zero
    }

    // Reparents the card back to its container after animation.
    private func reparentToContainer() {
      guard let cardView = cardView, let container = containerView else {
        isDragging = false
        return
      }

      cardView.removeFromSuperview()
      cardView.frame = CGRect(origin: .zero, size: container.bounds.size)
      container.addSubview(cardView)

      isDragging = false
      originalSuperview = nil
      originalFrame = .zero
    }
  }
}

// MARK: - PDF Card Container View

// Container view that maintains size when card is reparented during drag.
class PDFCardContainerView: UIView {
  var cardView: PDFCardView?

  override var intrinsicContentSize: CGSize {
    return bounds.size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Only layout card if it's our subview (not reparented).
    if let cardView = cardView, cardView.superview == self {
      cardView.frame = bounds
    }
  }
}
