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

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Keeps the overlay transparent.
        isOpaque = false
        backgroundColor = .clear

        // Allows multi-touch pointer streams.
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Sends pointer down events for new touches.
        forward(touches: touches, with: event, eventType: .down)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Sends pointer move events for touch updates.
        forward(touches: touches, with: event, eventType: .move)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Sends pointer up events when touches end.
        forward(touches: touches, with: event, eventType: .up)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Cancels the current pointer sequence in the editor.
        do { try editor?.pointerCancel() } catch { }
    }

    private func forward(touches: Set<UITouch>, with event: UIEvent?, eventType: IINKPointerEventType) {
        // Requires a live editor instance.
        guard let editor else { return }

        // Prefers coalesced touches for smoother ink.
        let allTouches: [UITouch]
        if let event, let first = touches.first, let coalesced = event.coalescedTouches(for: first) {
            allTouches = coalesced
        } else {
            allTouches = Array(touches)
        }

        // Builds a contiguous pointer event buffer for the editor call.
        var events = [IINKPointerEvent]()
        events.reserveCapacity(allTouches.count)

        for t in allTouches {
            // Converts a touch location into view coordinates.
            let p = t.location(in: self)

            // Maps the UIKit touch into a MyScript pointer type.
            let type = mapPointerType(t)

            // Uses a stable id derived from the touch object identity.
            let pointerId = Int32(bitPattern: UInt32(t.hash))

            // Converts seconds into milliseconds.
            let timestampMs = Int64(t.timestamp * 1000.0)

            // Sets pressure only for pencil touches.
            let pressure = Float(t.type == .pencil ? max(0.001, t.force) : 0.0)

            // Creates the pointer event struct expected by the SDK.
            let pe = IINKPointerEventMake(eventType, p, timestampMs, pressure, type, pointerId)
            events.append(pe)
        }

        // Sends the pointer event batch into the editor.
        do {
            try events.withUnsafeMutableBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                _ = try editor.pointerEvents(base, count: Int32(buf.count))
            }
        } catch {
            // Ignores errors to keep input responsive.
        }
    }

    private func mapPointerType(_ touch: UITouch) -> IINKPointerType {
        // Selects the pointer type based on the configured input mode.
        switch inputMode {
        case .forcePen:
            return .pen
        case .forceTouch:
            return .touch
        case .auto:
            return (touch.type == .pencil) ? .pen : .touch
        }
    }
}