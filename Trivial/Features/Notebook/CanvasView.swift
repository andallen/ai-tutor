import UIKit
import Foundation

// A UIView that acts as the rendering target for the MyScript engine.
// Implements IINKIRenderTarget to handle drawing commands.
// Routes touch input to the IINKEditor.
class CanvasView: UIView, IINKIRenderTarget {
  // The MyScript editor to route input to.
  weak var editor: IINKEditor?

  // Storage for offscreen render surfaces.
  private var offscreenSurfaces: [UInt32: CALayer] = [:]

  // Storage for offscreen render canvases.
  private var offscreenCanvases: [UInt32: IINKICanvas] = [:]

  // Next available surface ID.
  private var nextSurfaceId: UInt32 = 1

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    self.backgroundColor = .white
    self.isMultipleTouchEnabled = true
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let editor = editor else { return }
    for touch in touches {
      let pointerEvent = createPointerEvent(from: touch, eventType: .down)
      do {
        try editor.pointerDown(
          point: CGPoint(x: CGFloat(pointerEvent.x), y: CGFloat(pointerEvent.y)),
          timestamp: pointerEvent.t,
          force: pointerEvent.f,
          type: pointerEvent.pointerType,
          pointerId: Int(pointerEvent.pointerId)
        )
      } catch {
        // Pointer down failed.
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let editor = editor else { return }
    guard let touch = touches.first else { return }
    
    // Collect coalesced touches to capture all hardware samples (120Hz/240Hz).
    // This ensures we capture every point the hardware provides for smooth ink.
    let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
    
    // Map coalesced touches to MyScript Pointer Events.
    // Always use the batch API for consistent stroke quality, even for single points.
    var events = coalescedTouches.map { coalescedTouch in
      createPointerEvent(from: coalescedTouch, eventType: .move)
    }
    
    // Capture count before accessing mutable buffer to avoid exclusivity violation.
    let eventCount = events.count
    
    // Use the batch API to process all points in one engine cycle.
    // This reduces latency and maintains consistent stroke rendering.
    // Convert Swift array to unsafe mutable pointer using withUnsafeMutableBufferPointer.
    events.withUnsafeMutableBufferPointer { buffer in
      guard let baseAddress = buffer.baseAddress else { return }
      do {
        try editor.pointerEvents(baseAddress, count: eventCount, doProcessGestures: true)
      } catch {
        // Batch pointer events failed. This should be rare.
      }
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let editor = editor else { return }
    for touch in touches {
      let pointerEvent = createPointerEvent(from: touch, eventType: .up)
      do {
        try editor.pointerUp(
          point: CGPoint(x: CGFloat(pointerEvent.x), y: CGFloat(pointerEvent.y)),
          timestamp: pointerEvent.t,
          force: pointerEvent.f,
          type: pointerEvent.pointerType,
          pointerId: Int(pointerEvent.pointerId)
        )
      } catch {
        // Pointer up failed.
      }
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let editor = editor else { return }
    for touch in touches {
      let pointerEvent = createPointerEvent(from: touch, eventType: .cancel)
      do {
        try editor.pointerCancel(Int(pointerEvent.pointerId))
      } catch {
        // Pointer cancel failed.
      }
    }
  }

  // Converts a UITouch to an IINKPointerEvent.
  private func createPointerEvent(from touch: UITouch, eventType: IINKPointerEventType) -> IINKPointerEvent {
    let location = touch.preciseLocation(in: self)

    // Normalize force to 0-1 range. Default to 0 if device has no force sensor.
    let force: Float
    if touch.maximumPossibleForce > 0 {
      force = Float(touch.force / touch.maximumPossibleForce)
    } else {
      force = 0
    }

    // Convert timestamp to milliseconds.
    let timestamp = Int64(touch.timestamp * 1000)

    // Determine pointer type based on touch type.
    let pointerType: IINKPointerType = (touch.type == .stylus) ? .pen : .touch

    // Use hash of touch as pointer ID to track individual fingers.
    // Mask to 32 bits to safely convert Int (64-bit) to Int32.
    let pointerId = Int32(truncatingIfNeeded: touch.hash)

    return IINKPointerEventMake(
      eventType,
      CGPoint(x: location.x, y: location.y),
      timestamp,
      force,
      pointerType,
      pointerId
    )
  }

  // MARK: - IINKIRenderTarget Protocol

  // Invalidates the given set of layers.
  func invalidate(_ renderer: IINKRenderer, layers: IINKLayerType) {
    // Mark the view as needing display for the specified layers.
    // Ensure this runs on the main thread since setNeedsDisplay requires it.
    DispatchQueue.main.async { [weak self] in
      self?.setNeedsDisplay()
    }
  }

  // Invalidates a specified rectangle area on the given set of layers.
  func invalidate(_ renderer: IINKRenderer, area: CGRect, layers: IINKLayerType) {
    // Mark the specific area as needing display.
    // Ensure this runs on the main thread since setNeedsDisplay requires it.
    // Capture the area parameter before the async block.
    let invalidateArea = area
    DispatchQueue.main.async { [weak self] in
      self?.setNeedsDisplay(invalidateArea)
    }
  }

  // The device Pixel Density.
  var pixelDensity: Float {
    // Ensure this runs on the main thread since contentScaleFactor is a UIKit property.
    if Thread.isMainThread {
      return Float(self.contentScaleFactor)
    } else {
      return DispatchQueue.main.sync {
        return Float(self.contentScaleFactor)
      }
    }
  }

  // Creates an offscreen render surface and returns a unique identifier.
  func createOffscreenRenderSurface(width: Int32, height: Int32, alphaMask: Bool) -> UInt32 {
    // Ensure this runs on the main thread since it accesses UIKit properties and dictionaries.
    if Thread.isMainThread {
      return createOffscreenRenderSurfaceSync(width: width, height: height, alphaMask: alphaMask)
    } else {
      return DispatchQueue.main.sync {
        return createOffscreenRenderSurfaceSync(width: width, height: height, alphaMask: alphaMask)
      }
    }
  }

  // Synchronous implementation of createOffscreenRenderSurface.
  private func createOffscreenRenderSurfaceSync(width: Int32, height: Int32, alphaMask: Bool) -> UInt32 {
    let surfaceId = nextSurfaceId
    nextSurfaceId += 1

    // Create a CALayer for the offscreen surface.
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    layer.contentsScale = self.contentScaleFactor
    offscreenSurfaces[surfaceId] = layer

    return surfaceId
  }

  // Releases the offscreen render surface associated with the given identifier.
  func releaseOffscreenRenderSurface(_ surfaceId: UInt32) {
    // Ensure this runs on the main thread since it accesses dictionaries.
    if Thread.isMainThread {
      offscreenSurfaces.removeValue(forKey: surfaceId)
      offscreenCanvases.removeValue(forKey: surfaceId)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.offscreenSurfaces.removeValue(forKey: surfaceId)
        self?.offscreenCanvases.removeValue(forKey: surfaceId)
      }
    }
  }

  // Creates a Canvas that draws onto the offscreen render surface.
  func createOffscreenRenderCanvas(_ surfaceId: UInt32) -> IINKICanvas {
    // Ensure this runs on the main thread since it accesses dictionaries.
    if Thread.isMainThread {
      return createOffscreenRenderCanvasSync(surfaceId: surfaceId)
    } else {
      return DispatchQueue.main.sync {
        return createOffscreenRenderCanvasSync(surfaceId: surfaceId)
      }
    }
  }

  // Synchronous implementation of createOffscreenRenderCanvas.
  private func createOffscreenRenderCanvasSync(surfaceId: UInt32) -> IINKICanvas {
    // Create a canvas that draws to the offscreen surface layer.
    guard let layer = offscreenSurfaces[surfaceId] else {
      // Return a basic canvas if surface not found.
      return OffscreenCanvas()
    }
    let canvas = OffscreenCanvas(layer: layer)
    offscreenCanvases[surfaceId] = canvas
    return canvas
  }

  // Releases the offscreen render canvas.
  func releaseOffscreenRenderCanvas(_ canvas: IINKICanvas) {
    // Ensure this runs on the main thread since it accesses dictionaries.
    // Use async to avoid blocking the caller, as this is a cleanup operation.
    if Thread.isMainThread {
      releaseOffscreenRenderCanvasSync(canvas: canvas)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.releaseOffscreenRenderCanvasSync(canvas: canvas)
      }
    }
  }

  // Synchronous implementation of releaseOffscreenRenderCanvas.
  private func releaseOffscreenRenderCanvasSync(canvas: IINKICanvas) {
    // Find and remove the canvas from storage.
    // Use identity comparison to find the matching canvas instance.
    // The MyScript SDK should pass the exact same object instance that was returned.
    for (key, storedCanvas) in offscreenCanvases {
      if (storedCanvas as AnyObject) === (canvas as AnyObject) {
        offscreenCanvases.removeValue(forKey: key)
        break
      }
    }
  }
}

// A basic implementation of IINKICanvas for offscreen rendering.
// This canvas draws to a CALayer using Core Graphics.
class OffscreenCanvas: NSObject, IINKICanvas {
  private let layer: CALayer?
  private var currentTransform = CGAffineTransform.identity
  private var strokeColor: UInt32 = 0xFF000000
  private var strokeWidth: Float = 1.0
  private var fillColor: UInt32 = 0xFF000000

  init(layer: CALayer? = nil) {
    self.layer = layer
    super.init()
  }

  // MARK: - View Properties

  func getTransform() -> CGAffineTransform {
    return currentTransform
  }

  func setTransform(_ transform: CGAffineTransform) {
    currentTransform = transform
  }

  // MARK: - Stroking Properties

  func setStrokeColor(_ color: UInt32) {
    strokeColor = color
  }

  func setStrokeWidth(_ width: Float) {
    strokeWidth = width
  }

  func setStroke(_ lineCap: IINKLineCap) {
    // Store for path drawing.
  }

  func setStroke(_ lineJoin: IINKLineJoin) {
    // Store for path drawing.
  }

  func setStrokeMiterLimit(_ limit: Float) {
    // Store for path drawing.
  }

  func setStrokeDashArray(_ array: UnsafePointer<Float>?, size: size_t) {
    // Store for path drawing.
  }

  func setStrokeDashOffset(_ offset: Float) {
    // Store for path drawing.
  }

  // MARK: - Filling Properties

  func setFillColor(_ color: UInt32) {
    fillColor = color
  }

  func setFillRule(_ rule: IINKFillRule) {
    // Store for path drawing.
  }

  // MARK: - Drop Shadow Properties

  func setDropShadow(_ xOffset: Float, yOffset: Float, radius: Float, color: UInt32) {
    // Store for path drawing.
  }

  // MARK: - Font Properties

  func setFontProperties(_ family: String, height lineHeight: Float, size: Float, style: String, variant: String, weight: Int32) {
    // Store for text drawing.
  }

  // MARK: - Group Management

  func startGroup(_ identifier: String, region: CGRect, clip: Bool) {
    // Group management for complex drawings.
  }

  func endGroup(_ identifier: String) {
    // Group management for complex drawings.
  }

  func startItem(_ identifier: String) {
    // Item management for complex drawings.
  }

  func endItem(_ identifier: String) {
    // Item management for complex drawings.
  }

  // MARK: - Drawing Commands

  func createPath() -> IINKIPath {
    // Create a basic path implementation.
    return BasicPath()
  }

  func draw(_ path: IINKIPath) {
    // Draw the path to the layer.
    // This is a simplified implementation.
  }

  func drawRectangle(_ rect: CGRect) {
    // Draw rectangle to the layer.
    // This is a simplified implementation.
  }

  func drawLine(_ from: CGPoint, to: CGPoint) {
    // Draw line to the layer.
    // This is a simplified implementation.
  }

  func drawObject(_ url: String, mimeType: String, region: CGRect) {
    // Draw object to the layer.
    // This is a simplified implementation.
  }

  func drawText(_ label: String, anchor: CGPoint, region: CGRect) {
    // Draw text to the layer.
    // This is a simplified implementation.
  }

  // MARK: - Blending Operations

  func blendOffscreen(_ offscreenId: UInt32, src: CGRect, dest: CGRect, color: UInt32) {
    // Blend an offscreen surface onto this canvas.
    // This is a simplified implementation that does nothing.
    // For a full implementation, we would need to:
    // 1. Retrieve the offscreen surface by ID
    // 2. Create a graphics context from the layer
    // 3. Perform the blending operation using Core Graphics
    // For now, this stub prevents crashes when MyScript calls this method.
  }
}

// A basic implementation of IINKIPath for path drawing.
class BasicPath: NSObject, IINKIPath {
  private let cgPath = CGMutablePath()

  func move(to position: CGPoint) {
    cgPath.move(to: position)
  }

  func line(to position: CGPoint) {
    cgPath.addLine(to: position)
  }

  func close() {
    cgPath.closeSubpath()
  }
}
