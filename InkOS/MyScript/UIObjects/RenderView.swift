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

    let scale = contentScaleFactor
    let pixelSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    if layerType == .model {
      appLog("🧭 RenderView.draw layer=\(layerType) rectPt=\(rect) scale=\(scale)")
    }

    let originalCTM = ctx.ctm
    let originalClip = ctx.boundingBoxOfClipPath

    ctx.saveGState()
    // Normalize into pixel space with a y-down coordinate system.
    let currentCTM = ctx.ctm
    ctx.concatenate(currentCTM.inverted())
    ctx.translateBy(x: 0, y: pixelSize.height)
    ctx.scaleBy(x: 1, y: -1)

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
    // Sets canvas size in pixels to match renderer coordinate system.
    canvas.size = pixelSize
    canvas.offscreenRenderSurfaces = offscreenRenderSurfaces
    // Prevents clearing the main view when renderer calls startDraw.
    canvas.clearAtStartDraw = false

    // Converts the UIKit redraw rect from points to pixels.
    let regionPx = CGRect(
      x: rect.origin.x * scale,
      y: rect.origin.y * scale,
      width: rect.size.width * scale,
      height: rect.size.height * scale
    )

    // Draws the selected renderer layer for the invalidated region.
    if layerType == .model {
      let result = renderer.drawModel(regionPx, canvas: canvas)
      if !result {
        appLog("❌ RenderView.draw: drawModel returned false")
      }
    } else if layerType == .capture {
      let result = renderer.drawCaptureStrokes(regionPx, canvas: canvas)
      if !result {
        appLog("❌ RenderView.draw: drawCaptureStrokes returned false")
      }
    }

    ctx.restoreGState()

    if ctx.ctm != originalCTM || ctx.boundingBoxOfClipPath != originalClip {
      appLog("⚠️ RenderView.draw: CGContext state leaked across draw")
      appLog("   original CTM=\(originalCTM)")
      appLog("   restored CTM=\(ctx.ctm)")
      appLog("   original clip=\(originalClip)")
      appLog("   restored clip=\(ctx.boundingBoxOfClipPath)")
    }
  }

  func setNeedsDisplay(areaPx: CGRect) {
    // Converts pixel rectangles back to points for UIKit invalidation.
    let scale = contentScaleFactor
    let areaPt = CGRect(
      x: areaPx.origin.x / scale,
      y: areaPx.origin.y / scale,
      width: areaPx.size.width / scale,
      height: areaPx.size.height / scale
    )
    setNeedsDisplay(areaPt)
  }
}
