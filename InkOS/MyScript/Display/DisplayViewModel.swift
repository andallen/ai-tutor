import Combine
import UIKit

// Implements the render target and owns the display model.
final class DisplayViewModel: NSObject, ObservableObject {
  // Publishes the render views to the display controller.
  @Published var model: DisplayModel?

  // Stores the renderer used by the render views.
  var renderer: IINKRenderer?

  // Stores the editor so layout code can set viewSize.
  var editor: IINKEditor?

  // Stores offscreen surfaces used internally by the renderer.
  private(set) var offscreenRenderSurfaces = OffscreenRenderSurfaces()

  // Prevents repeated model creation.
  private var didSetup = false

  // Limits noisy sizing logs from offscreen surface creation.
  private var didLogOffscreenSizing = false

  func setupModel() {
    // Creates the model only once per screen instance.
    guard !didSetup else {
      return
    }
    didSetup = true

    // Builds the model and wires shared dependencies into the views.
    let m = DisplayModel()
    m.modelRenderView.offscreenRenderSurfaces = offscreenRenderSurfaces
    m.captureRenderView.offscreenRenderSurfaces = offscreenRenderSurfaces
    m.modelRenderView.renderer = renderer
    m.captureRenderView.renderer = renderer

    // Publishes the model so the controller can install the views.
    model = m
    appLog("🧭 DisplayViewModel.setupModel completed modelReady=\(model != nil)")
  }

  func setOffScreenRendererSurfacesScale(scale: CGFloat) {
    offscreenRenderSurfaces.scale = scale
  }

  func refreshDisplay() {
    // Invalidates both layers for a full redraw.
    if let model = model {
      model.modelRenderView.setNeedsDisplay()
      model.captureRenderView.setNeedsDisplay()
    }
  }

  func updateRenderer() {
    // Updates renderer on existing RenderViews when it becomes available.
    guard let renderer = renderer, let model = model else {
      return
    }
    model.modelRenderView.renderer = renderer
    model.captureRenderView.renderer = renderer
    appLog("🧭 DisplayViewModel.updateRenderer applied renderer")
  }
}

extension DisplayViewModel: IINKIRenderTarget {
  var pixelDensity: Float {
    // Returns pixels per point for the current screen scale.
    Float(offscreenRenderSurfaces.scale)
  }

  func invalidate(_ renderer: IINKRenderer, layers: IINKLayerType) {
    // Schedules invalidation on the main thread for UIKit.
    DispatchQueue.main.async { [weak self] in
      guard let self, let model = self.model else { return }
      // Invalidates only the layers that changed.
      if layers.contains(.model) {
        model.modelRenderView.setNeedsDisplay()
      }
      if layers.contains(.capture) {
        model.captureRenderView.setNeedsDisplay()
      }
    }
  }

  func invalidate(_ renderer: IINKRenderer, area: CGRect, layers: IINKLayerType) {
    // Schedules invalidation on the main thread for UIKit.
    // Uses pixel coordinates as specified by the SDK headers.
    DispatchQueue.main.async { [weak self] in
      guard let self, let model = self.model else { return }
      // Invalidates only the touched pixel area.
      if layers.contains(.model) {
        model.modelRenderView.setNeedsDisplay(areaPx: area)
      }
      if layers.contains(.capture) {
        model.captureRenderView.setNeedsDisplay(areaPx: area)
      }
    }
  }

  func createOffscreenRenderSurface(width: Int32, height: Int32, alphaMask: Bool) -> UInt32 {
    // The SDK provides sizes in pixels; build a 1:1 pixel context.
    let sizePx = CGSize(width: CGFloat(width), height: CGFloat(height))
    UIGraphicsBeginImageContextWithOptions(sizePx, false, 1)
    defer { UIGraphicsEndImageContext() }

    guard let context = UIGraphicsGetCurrentContext() else {
      return 0
    }
    if !didLogOffscreenSizing {
      didLogOffscreenSizing = true
      appLog(
        "🧭 DisplayViewModel.createOffscreenRenderSurface sizePx=\(sizePx) scale=\(offscreenRenderSurfaces.scale)"
      )
    }

    let scaledWidth = Int32(sizePx.width.rounded())
    let scaledHeight = Int32(sizePx.height.rounded())
    let surfaceId = offscreenRenderSurfaces.createSurface(
      width: scaledWidth,
      height: scaledHeight,
      context: context,
      alphaMask: alphaMask
    )
    return surfaceId
  }

  func releaseOffscreenRenderSurface(_ surfaceId: UInt32) {
    offscreenRenderSurfaces.releaseSurface(surfaceId)
  }

  func createOffscreenRenderCanvas(_ surfaceId: UInt32) -> IINKICanvas {
    let canvas = Canvas()
    canvas.offscreenRenderSurfaces = offscreenRenderSurfaces

    // Selects the correct Core Graphics context for the surface id.
    if let context = offscreenRenderSurfaces.getSurface(surfaceId)?.context {
      canvas.context = context
      canvas.context?.saveGState()
    }

    // Sets the canvas size in pixels.
    if let layer = offscreenRenderSurfaces.getSurface(surfaceId) {
      // Keep canvas size in pixels to match renderer coordinates.
      canvas.size = layer.size
    } else {
      canvas.size = .zero
    }

    return canvas
  }

  func releaseOffscreenRenderCanvas(_ canvas: IINKICanvas) {
    (canvas as? Canvas)?.context?.restoreGState()
  }
}
