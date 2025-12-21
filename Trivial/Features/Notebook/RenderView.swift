import UIKit

// Custom view that bridges MyScript rendering to the UIKit screen.
class RenderView: UIView, IINKIRenderTarget {
    weak var renderer: IINKRenderer?
    weak var editor: IINKEditor?
    private var canvas: Canvas?
    private let offscreenSurfaces = OffscreenRenderSurfaces()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white
        // Disable multiple touch while drawing ink to prevent gesture conflicts.
        // Two simultaneous touches will be treated as a gesture and can prevent stroke creation.
        self.isMultipleTouchEnabled = false
        let canvas = Canvas()
        canvas.offscreenRenderSurfaces = offscreenSurfaces
        self.canvas = canvas
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - IINKIRenderTarget
    
    func invalidate(_ renderer: IINKRenderer, layers: IINKLayerType) {
        // MyScript calls this frequently during a stroke.
        // If this isn't on the main thread, the screen won't update.
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsDisplay()
        }
    }

    func invalidate(_ renderer: IINKRenderer, area: CGRect, layers: IINKLayerType) {
        // Check if the engine is actually signaling a redraw.
        print("🔄 RenderView: invalidate called for area: \(area), layers: \(layers.rawValue)")
        
        // MyScript calls this on a background thread whenever the ink model changes.
        // MyScript provides the area in millimeters, but UIKit expects points.
        // While debugging, invalidate the entire view to ensure the ink is visible
        // regardless of mm-to-point coordinate mismatches.
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsDisplay()
        }
    }

    var pixelDensity: Float {
        return Float(self.contentScaleFactor)
    }
    
    func createOffscreenRenderSurface(width: Int32, height: Int32, alphaMask: Bool) -> UInt32 {
        // Get the current graphics context to create a CGLayer.
        // CGLayer must be created from a context that will be used for drawing.
        // If we're not in a drawing context, we need to get the context from the main canvas.
        let context: CGContext
        if let currentContext = UIGraphicsGetCurrentContext() {
            context = currentContext
        } else if let canvasContext = canvas?.context {
            context = canvasContext
        } else {
            // Fallback: create a temporary context for layer creation.
            // This should rarely happen, but ensures we can create surfaces.
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let tempContext = CGContext(
                data: nil,
                width: Int(width),
                height: Int(height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return 0
            }
            return offscreenSurfaces.createSurface(width: width, height: height, context: tempContext, alphaMask: alphaMask)
        }
        
        return offscreenSurfaces.createSurface(width: width, height: height, context: context, alphaMask: alphaMask)
    }
    
    func releaseOffscreenRenderSurface(_ surfaceId: UInt32) {
        offscreenSurfaces.releaseSurface(surfaceId)
    }
    
    func createOffscreenRenderCanvas(_ surfaceId: UInt32) -> IINKICanvas {
        let canvas = Canvas()
        
        // Set up the canvas with the offscreen surface's context.
        if let context = offscreenSurfaces.getContext(surfaceId) {
            canvas.context = context
        }
        
        // Link the canvas to the offscreen surfaces manager for blending.
        canvas.offscreenRenderSurfaces = offscreenSurfaces
        
        return canvas
    }
    
    func releaseOffscreenRenderCanvas(_ canvas: IINKICanvas) {
        // Restore graphics state if needed.
        // The canvas may have modified the context state during drawing.
        if let canvas = canvas as? Canvas {
            canvas.context?.restoreGState()
        }
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        // Verify all drawing dependencies are present.
        guard let context = UIGraphicsGetCurrentContext() else {
            print("⚠️ RenderView: CGContext is NIL")
            return
        }
        guard let renderer = renderer else {
            print("⚠️ RenderView: Renderer is NIL")
            return
        }
        guard let canvas = canvas else {
            print("⚠️ RenderView: Canvas object is NIL")
            return
        }
        
        // Set up the canvas with the current graphics context.
        canvas.context = context
        canvas.size = self.bounds.size
        canvas.clearAtStartDraw = false
        
        // 1. Draw Model: The permanent, recognized ink.
        renderer.drawModel(rect, canvas: canvas)
        
        // 2. Draw Capture: The "temporary" ink currently under the pen/mouse.
        // IF THIS LINE IS MISSING, YOU WILL SEE NOTHING DURING THE DRAG.
        renderer.drawCaptureStrokes(rect, canvas: canvas)
    }

    // MARK: - Input Routing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("📱 UIKit: touchesBegan - sending pointerDown (type 0)")
        // DO NOT call processTouches(touches, type: .down) here!
        processTouches(touches, type: .down)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // DO NOT call processTouches(touches, type: .down) here!
        guard let touch = touches.first, let event = event else { return }
        let coalesced = event.coalescedTouches(for: touch) ?? [touch]
        processTouches(Set(coalesced), type: .move)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("📱 UIKit: touchesEnded - sending pointerUp (type 2)")
        processTouches(touches, type: .up)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("📱 UIKit: touchesCancelled - treating as pointerUp (type 2)")
        // Treat cancelled touches as pointerUp to ensure strokes are completed.
        processTouches(touches, type: .up)
    }

    private func processTouches(_ touches: Set<UITouch>, type: IINKPointerEventType) {
        // Check if the editor reference exists.
        guard let editor = editor else {
            print("⚠️ Input Routing Failed: Editor is NIL in RenderView")
            return
        }
        
        print("🖱️ Touch detected: \(touches.count) points of type \(type.rawValue)")
        
        let pointerEvents = touches.map { touch in
            let location = touch.location(in: self)
            let force = touch.maximumPossibleForce > 0 ? Float(touch.force / touch.maximumPossibleForce) : 1.0
            let timestamp = Int64(touch.timestamp * 1000)
            let pointerType: IINKPointerType = (touch.type == .stylus) ? .pen : .touch
            // Use a stable id per UITouch instance. touch.hash is not guaranteed to remain stable
            // across events for the same touch. iink expects the same pointer id for down/move/up.
            let pointerId = Int32(truncatingIfNeeded: ObjectIdentifier(touch).hashValue)

            return IINKPointerEventMake(type, location, timestamp, force, pointerType, pointerId)
        }

        // Convert array to UnsafeMutablePointer for the API.
        var mutableEvents = pointerEvents
        let count = mutableEvents.count
        mutableEvents.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            do {
                // Send the events to the engine.
                try editor.pointerEvents(baseAddress, count: count, doProcessGestures: true)
            } catch {
                print("❌ MyScript failed to process pointer events: \(error.localizedDescription)")
            }
        }
    }
}