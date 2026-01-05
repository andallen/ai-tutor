import SwiftUI
import UIKit

// Protocol for touch tracking callbacks to avoid generic type issues.
protocol TouchTrackingDelegate: AnyObject {
  func touchDown()
  func touchUp()
  func longPress(frame: CGRect)
  func dragStart(frame: CGRect, position: CGPoint)
  func dragMove(position: CGPoint)
  func dragEnd(position: CGPoint)
  func tap()
}

// A UIViewRepresentable that wraps SwiftUI content and provides manual touch tracking.
// Uses UIKit touch handling to report positions in window coordinates,
// which are immune to parent view transforms (scale, position changes).
// This solves the coordinate drift issue when dragging items out of animated overlays.
struct UIKitDragWrapper<Content: View>: UIViewRepresentable {
  let content: Content
  // Called immediately when touch begins.
  let onTouchDown: () -> Void
  // Called when touch ends without triggering long press or drag.
  let onTouchUp: () -> Void
  // Called after long press threshold (0.3s) is reached.
  let onLongPress: (CGRect) -> Void
  // Called when drag starts (movement after long press). Provides frame and position in window coords.
  let onDragStart: (CGRect, CGPoint) -> Void
  // Called during drag with position in window coordinates.
  let onDragMove: (CGPoint) -> Void
  // Called when drag ends with final position in window coordinates.
  let onDragEnd: (CGPoint) -> Void
  // Called for a short tap (touch up before long press threshold).
  let onTap: () -> Void

  func makeUIView(context: Context) -> TouchTrackingContainerView {
    let container = TouchTrackingContainerView()
    container.backgroundColor = .clear
    container.delegate = context.coordinator

    // Create hosting controller for SwiftUI content.
    let hostingController = UIHostingController(rootView: content)
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    // Disable user interaction on hosting view so touches go to container.
    hostingController.view.isUserInteractionEnabled = false
    container.addSubview(hostingController.view)

    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
    ])

    context.coordinator.hostingController = hostingController

    return container
  }

  func updateUIView(_ uiView: TouchTrackingContainerView, context: Context) {
    context.coordinator.hostingController?.rootView = content
    context.coordinator.onTouchDown = onTouchDown
    context.coordinator.onTouchUp = onTouchUp
    context.coordinator.onLongPress = onLongPress
    context.coordinator.onDragStart = onDragStart
    context.coordinator.onDragMove = onDragMove
    context.coordinator.onDragEnd = onDragEnd
    context.coordinator.onTap = onTap
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      onTouchDown: onTouchDown,
      onTouchUp: onTouchUp,
      onLongPress: onLongPress,
      onDragStart: onDragStart,
      onDragMove: onDragMove,
      onDragEnd: onDragEnd,
      onTap: onTap
    )
  }

  class Coordinator: TouchTrackingDelegate {
    var hostingController: UIHostingController<Content>?
    var onTouchDown: () -> Void
    var onTouchUp: () -> Void
    var onLongPress: (CGRect) -> Void
    var onDragStart: (CGRect, CGPoint) -> Void
    var onDragMove: (CGPoint) -> Void
    var onDragEnd: (CGPoint) -> Void
    var onTap: () -> Void

    init(
      onTouchDown: @escaping () -> Void,
      onTouchUp: @escaping () -> Void,
      onLongPress: @escaping (CGRect) -> Void,
      onDragStart: @escaping (CGRect, CGPoint) -> Void,
      onDragMove: @escaping (CGPoint) -> Void,
      onDragEnd: @escaping (CGPoint) -> Void,
      onTap: @escaping () -> Void
    ) {
      self.onTouchDown = onTouchDown
      self.onTouchUp = onTouchUp
      self.onLongPress = onLongPress
      self.onDragStart = onDragStart
      self.onDragMove = onDragMove
      self.onDragEnd = onDragEnd
      self.onTap = onTap
    }

    // TouchTrackingDelegate conformance.
    func touchDown() { onTouchDown() }
    func touchUp() { onTouchUp() }
    func longPress(frame: CGRect) { onLongPress(frame) }
    func dragStart(frame: CGRect, position: CGPoint) { onDragStart(frame, position) }
    func dragMove(position: CGPoint) { onDragMove(position) }
    func dragEnd(position: CGPoint) { onDragEnd(position) }
    func tap() { onTap() }
  }
}

// Custom UIView that handles all touch events for drag tracking.
// Implements the same gesture flow as the dashboard cards:
// - Touch down → dim feedback
// - 0.3s hold → long press (context menu)
// - Movement after long press → drag mode
// - Release before 0.3s → tap
class TouchTrackingContainerView: UIView {
  weak var delegate: TouchTrackingDelegate?

  // Gesture state tracking.
  private var touchStartLocation: CGPoint = .zero
  private var longPressTimer: Timer?
  private var hasTriggeredLongPress = false
  private var isDragging = false
  private var dragStartPosition: CGPoint = .zero

  // Minimum distance to move after long press to start drag.
  private let dragThreshold: CGFloat = 10
  // Long press delay in seconds.
  private let longPressDelay: TimeInterval = 0.3

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = true
    isMultipleTouchEnabled = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }

    // Reset state for new touch.
    touchStartLocation = touch.location(in: self)
    hasTriggeredLongPress = false
    isDragging = false

    // Notify touch down for visual feedback.
    delegate?.touchDown()

    // Schedule long press timer.
    longPressTimer?.invalidate()
    longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) {
      [weak self] _ in
      self?.triggerLongPress()
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, let window = self.window else { return }

    let currentLocation = touch.location(in: self)
    let windowLocation = touch.location(in: window)

    // If we haven't triggered long press yet, check if movement cancels it.
    if !hasTriggeredLongPress {
      let distance = hypot(
        currentLocation.x - touchStartLocation.x,
        currentLocation.y - touchStartLocation.y
      )
      // If moved too much before long press, cancel it (this becomes a scroll/pan).
      if distance > dragThreshold {
        longPressTimer?.invalidate()
        longPressTimer = nil
      }
      return
    }

    // Long press has triggered. Check for drag initiation.
    if !isDragging {
      let distance = hypot(
        currentLocation.x - touchStartLocation.x,
        currentLocation.y - touchStartLocation.y
      )
      if distance > dragThreshold {
        // Start drag mode.
        isDragging = true
        dragStartPosition = windowLocation

        let frameInWindow = self.convert(self.bounds, to: window)
        delegate?.dragStart(frame: frameInWindow, position: windowLocation)
      }
    } else {
      // Already dragging - report position update in window coordinates.
      delegate?.dragMove(position: windowLocation)
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, let window = self.window else {
      cleanup()
      return
    }

    let windowLocation = touch.location(in: window)

    if isDragging {
      // End drag with final position.
      delegate?.dragEnd(position: windowLocation)
    } else if hasTriggeredLongPress {
      // Long press without drag - just touch up.
      delegate?.touchUp()
    } else {
      // Short tap - didn't reach long press threshold.
      longPressTimer?.invalidate()
      longPressTimer = nil
      delegate?.tap()
    }

    cleanup()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    if isDragging, let window = self.window, let touch = touches.first {
      let windowLocation = touch.location(in: window)
      delegate?.dragEnd(position: windowLocation)
    } else {
      delegate?.touchUp()
    }
    cleanup()
  }

  // Triggers long press callback.
  private func triggerLongPress() {
    hasTriggeredLongPress = true
    guard let window = self.window else { return }
    let frameInWindow = self.convert(self.bounds, to: window)
    delegate?.longPress(frame: frameInWindow)
  }

  // Cleans up state after touch ends.
  private func cleanup() {
    longPressTimer?.invalidate()
    longPressTimer = nil
    hasTriggeredLongPress = false
    isDragging = false
    touchStartLocation = .zero
    dragStartPosition = .zero
  }
}
