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
        guard let ctx = UIGraphicsGetCurrentContext(), let renderer else { return }

        // Creates a canvas that wraps the current Core Graphics context.
        let canvas = Canvas()
        canvas.context = ctx
        canvas.size = bounds.size
        canvas.offscreenRenderSurfaces = offscreenRenderSurfaces

        // Converts the UIKit redraw rect from points to pixels.
        let scale = contentScaleFactor
        let regionPx = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )

        // Draws the selected renderer layer for the invalidated region.
        if layerType == .model {
            _ = renderer.drawModel(region: regionPx, canvas: canvas)
        } else if layerType == .capture {
            _ = renderer.drawCaptureStrokes(region: regionPx, canvas: canvas)
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