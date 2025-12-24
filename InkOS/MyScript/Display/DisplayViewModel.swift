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

  // Limits invalidation logs to avoid noisy output.
  private var didLogInvalidate = false

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
    // Treats invalidation rectangles as view coordinates in points.
    DispatchQueue.main.async { [weak self] in
      guard let self, let model = self.model else { return }
      if !self.didLogInvalidate {
        self.didLogInvalidate = true
        appLog("🧭 DisplayViewModel.invalidate area=\(area) layers=\(layers)")
      }
      // Invalidates only the touched area.
      if layers.contains(.model) {
        model.modelRenderView.setNeedsDisplay(areaInView: area)
      }
      if layers.contains(.capture) {
        model.captureRenderView.setNeedsDisplay(areaInView: area)
      }
    }
  }

  func createOffscreenRenderSurface(width: Int32, height: Int32, alphaMask: Bool) -> UInt32 {
    // Build the offscreen surface at device scale.
    let scale = offscreenRenderSurfaces.scale
    let size = CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
    UIGraphicsBeginImageContextWithOptions(size, false, 1)
    defer { UIGraphicsEndImageContext() }

    guard let context = UIGraphicsGetCurrentContext() else {
      return 0
    }
    // Scale points into pixels for offscreen rendering.
    context.scaleBy(x: size.width, y: size.height)

    let scaledWidth = Int32(size.width.rounded())
    let scaledHeight = Int32(size.height.rounded())
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

    // Sets the canvas size in points.
    if let layer = offscreenRenderSurfaces.getSurface(surfaceId) {
      let scale = offscreenRenderSurfaces.scale
      canvas.size = CGSize(width: layer.size.width / scale, height: layer.size.height / scale)
    } else {
      canvas.size = .zero
    }

    return canvas
  }

  func releaseOffscreenRenderCanvas(_ canvas: IINKICanvas) {
    (canvas as? Canvas)?.context?.restoreGState()
  }
}
