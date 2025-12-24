import UIKit

// Draws either the model layer or the capture layer.
final class RenderView: UIView {
  // Selects which renderer layer should be drawn.
  private let layerType: IINKLayerType

  // Holds the renderer created by the engine.
  var renderer: IINKRenderer?

  // Provides access to offscreen buffers used by the renderer.
  var offscreenRenderSurfaces: OffscreenRenderSurfaces?

  init(frame: CGRect, layer: IINKLayerType) {
    self.layerType = layer
    super.init(frame: frame)

    // Keeps the view transparent so layers can stack.
    isOpaque = false
    backgroundColor = .clear

    // Redraws on invalidation.
    contentMode = .redraw
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func draw(_ rect: CGRect) {
    // Skips drawing if the renderer is not ready.
    guard let ctx = UIGraphicsGetCurrentContext() else {
      appLog("❌ RenderView.draw: No graphics context")
      return
    }
    guard let renderer else {
      appLog("⚠️ RenderView.draw: renderer not set")
      return
    }

    if layerType == .model {
      appLog("🧭 RenderView.draw layer=\(layerType) rect=\(rect) scale=\(contentScaleFactor)")
    }

    let originalCTM = ctx.ctm
    let originalClip = ctx.boundingBoxOfClipPath

    // Creates a canvas that wraps the current Core Graphics context.
    let canvas = Canvas()
    canvas.context = ctx
    if layerType == .model {
      canvas.debugLayer = "model"
    } else if layerType == .capture {
      canvas.debugLayer = "capture"
    } else {
      canvas.debugLayer = String(describing: layerType)
    }
    // Use view coordinates in points to match input events.
    canvas.size = bounds.size
    canvas.offscreenRenderSurfaces = offscreenRenderSurfaces
    // Prevents clearing the main view when renderer calls startDraw.
    canvas.clearAtStartDraw = false

    // Draws the selected renderer layer for the invalidated region.
    if layerType == .model {
      let result = renderer.drawModel(rect, canvas: canvas)
      if !result {
        appLog("❌ RenderView.draw: drawModel returned false")
      }
    } else if layerType == .capture {
      let result = renderer.drawCaptureStrokes(rect, canvas: canvas)
      if !result {
        appLog("❌ RenderView.draw: drawCaptureStrokes returned false")
      }
    }

    if ctx.ctm != originalCTM || ctx.boundingBoxOfClipPath != originalClip {
      appLog("⚠️ RenderView.draw: CGContext state leaked across draw")
      appLog("   original CTM=\(originalCTM)")
      appLog("   restored CTM=\(ctx.ctm)")
      appLog("   original clip=\(originalClip)")
      appLog("   restored clip=\(ctx.boundingBoxOfClipPath)")
    }
  }

  func setNeedsDisplay(areaInView area: CGRect) {
    // Use view coordinates for invalidation to match draw rects.
    setNeedsDisplay(area)
  }
}
