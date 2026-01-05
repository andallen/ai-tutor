// Copyright @ MyScript. All rights reserved.

import Foundation
import UIKit

enum InputMode: Int {
  case forcePen
  case forceTouch
  case auto
}

/// The InputView role is to capture all the touch events and follow them back to the editor
/// so it can convert them to a stroke

class InputView: UIView {

  // MARK: - Properties

  weak var editor: IINKEditor?
  // Auto mode detects input type: stylus → .pen, finger → .touch.
  var inputMode: InputMode = .auto
  private var trackPressure: Bool = false
  private var cancelled: Bool = false
  private var touchesBegan: Bool = false
  private var eventTimeOffset: TimeInterval = 0

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.ownInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    self.ownInit()
  }

  private func ownInit() {
    self.isMultipleTouchEnabled = false
    self.trackPressure = self.traitCollection.forceTouchCapability == .available
    let relativeTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    let absoluteTime: TimeInterval = NSTimeIntervalSince1970
    self.eventTimeOffset = absoluteTime - relativeTime
  }

  // MARK: - Touches

  private func normalizeForce(from touch: UITouch) -> Float {
    var force: CGFloat = 1.0
    if touch.type == .stylus {
      if touch.maximumPossibleForce > 1.0 {
        if touch.force <= 1.0 {
          force = touch.force / 2.0  // average touch force = 0.5
        } else {
          force = ((touch.force - 1.0) / (touch.maximumPossibleForce - 1.0)) / 2.0 + 0.5  // max touch force = 1.0
        }
      } else if touch.maximumPossibleForce > 0.0 {
        force = touch.force / touch.maximumPossibleForce
      }
    }
    return Float(force)
  }

  private func pointerEvent(
    from touch: UITouch,
    eventType: IINKPointerEventType
  ) -> IINKPointerEvent {
    var pointerType: IINKPointerType = .pen
    switch self.inputMode {
    case .forcePen:
      pointerType = .pen
    case .forceTouch:
      pointerType = .touch
    default:
      pointerType = touch.type == .stylus ? .pen : .touch
    }
    var point: CGPoint = CGPoint.zero
    var force: Float = 1.0
    if touch.type == .stylus {
      point = touch.preciseLocation(in: self)
      force = self.normalizeForce(from: touch)
    } else {
      point = touch.location(in: self)
    }
    let timestamp: Int64 = Int64(1000 * (touch.timestamp + self.eventTimeOffset))
    return IINKPointerEventMake(eventType, point, timestamp, force, pointerType, 0)
  }

  func pointerDownEvent(from touch: UITouch) -> IINKPointerEvent {
    return self.pointerEvent(from: touch, eventType: .down)
  }

  func pointerMoveEvent(from touch: UITouch) -> IINKPointerEvent {
    return self.pointerEvent(from: touch, eventType: .move)
  }

  func pointerUpEvent(from touch: UITouch) -> IINKPointerEvent {
    return self.pointerEvent(from: touch, eventType: .up)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    guard let touch: UITouch = touches.randomElement() else { return }
    let pointerEvent: IINKPointerEvent = self.pointerDownEvent(from: touch)
    if pointerEvent.pointerType == .pen {
      self.touchesBegan = true
    }
    let point = CGPoint(x: CGFloat(pointerEvent.x), y: CGFloat(pointerEvent.y))
    _ = try? self.editor?.pointerDown(
      point: point,
      timestamp: pointerEvent.t,
      force: pointerEvent.f,
      type: pointerEvent.pointerType,
      pointerId: Int(pointerEvent.pointerId)
    )
    self.cancelled = false
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    guard let touch: UITouch = touches.randomElement() else { return }
    let coalescedTouches: [UITouch]? = event?.coalescedTouches(for: touch)
    if let coalescedTouchesUnwrapped = coalescedTouches {
      var events: [IINKPointerEvent] = coalescedTouchesUnwrapped.map { coalescedTouch in
        self.pointerMoveEvent(from: coalescedTouch)
      }
      let pointerEvent: UnsafeMutablePointer<IINKPointerEvent> = UnsafeMutablePointer<
        IINKPointerEvent
      >.allocate(capacity: events.count)
      pointerEvent.initialize(from: &events, count: events.count)
      do {
        try self.editor?.pointerEvents(pointerEvent, count: events.count, doProcessGestures: true)
      } catch {
        // Silently ignore pointer event errors.
      }
    } else {
      let pointerEvent: IINKPointerEvent = self.pointerMoveEvent(from: touch)
      do {
        try self.editor?.pointerMove(
          point: CGPoint(x: CGFloat(pointerEvent.x), y: CGFloat(pointerEvent.y)),
          timestamp: pointerEvent.t,
          force: pointerEvent.f,
          type: pointerEvent.pointerType,
          pointerId: Int(pointerEvent.pointerId)
        )
      } catch {
        // Silently ignore pointer move errors.
      }
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    guard let touch: UITouch = touches.randomElement() else { return }
    let pointerEvent: IINKPointerEvent = self.pointerUpEvent(from: touch)
    do {
      try self.editor?.pointerUp(
        point: CGPoint(x: CGFloat(pointerEvent.x), y: CGFloat(pointerEvent.y)),
        timestamp: pointerEvent.t,
        force: pointerEvent.f,
        type: pointerEvent.pointerType,
        pointerId: Int(pointerEvent.pointerId)
      )
    } catch {
      // Silently ignore pointer up errors.
    }
    self.touchesBegan = false
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    do {
      try self.editor?.pointerCancel(0)
    } catch {
      // Silently ignore pointer cancel errors.
    }
    self.cancelled = true
    self.touchesBegan = false
  }
}
