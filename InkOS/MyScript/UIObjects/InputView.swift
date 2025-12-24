import UIKit

// Selects how touch input is interpreted as pen or finger input.
enum InputMode: Int {
  case forcePen
  case forceTouch
  case auto
}

// Turns touch events into MyScript pointer events.
final class InputView: UIView {
  // Receives pointer events.
  weak var editor: IINKEditor?

  // Stores tool state for later extensions.
  weak var toolController: IINKToolController?

  // Controls the pointer type mapping.
  var inputMode: InputMode = .auto

  // Offset to convert UITouch.timestamp (system uptime) into Unix epoch time.
  private var eventTimeOffset: TimeInterval = 0
  private var loggedToolState = false

  override init(frame: CGRect) {
    super.init(frame: frame)

    // Keeps the overlay transparent.
    isOpaque = false
    backgroundColor = .clear

    // Keep single-pointer input (matches MyScript reference implementation).
    isMultipleTouchEnabled = false

    // Convert UITouch.timestamp (relative) into the epoch-based timestamps expected by the SDK.
    let relativeTime = ProcessInfo.processInfo.systemUptime
    let absoluteTime = Date().timeIntervalSince1970
    eventTimeOffset = absoluteTime - relativeTime
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    guard let touch = touches.randomElement() else { return }
    sendPointerDown(for: touch)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    guard let touch = touches.randomElement() else { return }
    sendPointerMoves(for: touch, event: event)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    guard let touch = touches.randomElement() else { return }
    sendPointerUp(for: touch)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    guard let editor else { return }
    do {
      appLog("🧭 InputView.touchesCancelled")
      // Cancel all active pointer traces.
      try editor.pointerCancel(-1)
    } catch {
      appLog("❌ InputView: pointerCancel failed: \(error)")
    }
  }

  private func normalizeForce(from touch: UITouch) -> Float {
    guard touch.type == .pencil else { return 1.0 }
    guard touch.maximumPossibleForce > 0 else { return 0.0 }
    let normalized = touch.force / touch.maximumPossibleForce
    return Float(min(1.0, max(0.0, normalized)))
  }

  private func pointerEvent(from touch: UITouch, eventType: IINKPointerEventType)
    -> IINKPointerEvent
  {
    let scale = window?.screen.scale ?? UIScreen.main.scale
    if contentScaleFactor != scale {
      contentScaleFactor = scale
    }

    let pointPt =
      (touch.type == .pencil) ? touch.preciseLocation(in: self) : touch.location(in: self)
    let pointPx = CGPoint(x: pointPt.x * scale, y: pointPt.y * scale)

    let pointerType = mapPointerType(touch)
    let force = normalizeForce(from: touch)

    // Convert seconds (system uptime) to milliseconds since Unix epoch.
    let timestampMs = Int64(1000.0 * (touch.timestamp + eventTimeOffset))

    // Reference implementation uses a constant pointer id when multi-touch is disabled.
    return IINKPointerEventMake(eventType, pointPx, timestampMs, force, pointerType, 0)
  }

  private func sendPointerDown(for touch: UITouch) {
    guard let editor else { return }
    if !loggedToolState {
      loggedToolState = true
      do {
        let touchTool = try editor.toolController.tool(forType: IINKPointerType.touch).value
        let penTool = try editor.toolController.tool(forType: IINKPointerType.pen).value
        let penStyle = try editor.toolController.style(forTool: IINKPointerTool.toolPen)
        appLog(
          "🧭 InputView.toolState touchTool=\(touchTool) penTool=\(penTool) penStyle=\(penStyle)")
      } catch {
        appLog("❌ InputView: toolState failed: \(error)")
      }
    }
    let e = pointerEvent(from: touch, eventType: .down)
    do {
      try editor.pointerDown(
        point: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y)),
        timestamp: e.t,
        force: e.f,
        type: e.pointerType,
        pointerId: Int(e.pointerId)
      )
    } catch {
      appLog("❌ InputView: pointerDown failed: \(error)")
    }
  }

  private func sendPointerMoves(for touch: UITouch, event: UIEvent?) {
    guard let editor else { return }

    if let event, let coalesced = event.coalescedTouches(for: touch), !coalesced.isEmpty {
      var events = coalesced.map { pointerEvent(from: $0, eventType: .move) }
      do {
        try events.withUnsafeMutableBufferPointer { buf in
          guard let base = buf.baseAddress else { return }
          _ = try editor.pointerEvents(base, count: buf.count, doProcessGestures: true)
        }
      } catch {
        appLog("❌ InputView: pointerEvents(move) failed: \(error)")
      }
      return
    }

    let e = pointerEvent(from: touch, eventType: .move)
    do {
      try editor.pointerMove(
        point: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y)),
        timestamp: e.t,
        force: e.f,
        type: e.pointerType,
        pointerId: Int(e.pointerId)
      )
    } catch {
      appLog("❌ InputView: pointerMove failed: \(error)")
    }
  }

  private func sendPointerUp(for touch: UITouch) {
    guard let editor else { return }
    let e = pointerEvent(from: touch, eventType: .up)
    do {
      try editor.pointerUp(
        point: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y)),
        timestamp: e.t,
        force: e.f,
        type: e.pointerType,
        pointerId: Int(e.pointerId)
      )
    } catch {
      appLog("❌ InputView: pointerUp failed: \(error)")
    }
  }

  private func mapPointerType(_ touch: UITouch) -> IINKPointerType {
    // Selects the pointer type based on the configured input mode.
    let type: IINKPointerType
    switch inputMode {
    case .forcePen:
      type = .pen
    case .forceTouch:
      type = .touch
    case .auto:
      type = (touch.type == .pencil) ? .pen : .touch
    }
    return type
  }
}
