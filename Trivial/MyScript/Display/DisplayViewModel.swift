import UIKit
import Combine

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

    func setupModel() {
        // Creates the model only once per screen instance.
        guard !didSetup else { return }
        didSetup = true

        // Builds the model and wires shared dependencies into the views.
        let m = DisplayModel()
        m.modelRenderView.offscreenRenderSurfaces = offscreenRenderSurfaces
        m.captureRenderView.offscreenRenderSurfaces = offscreenRenderSurfaces
        m.modelRenderView.renderer = renderer
        m.captureRenderView.renderer = renderer

        // Publishes the model so the controller can install the views.
        model = m
    }

    func setOffScreenRendererSurfacesScale(scale: CGFloat) {
        // Matches offscreen buffers to the screen scale.
        offscreenRenderSurfaces.scale = scale
    }

    func refreshDisplay() {
        // Invalidates both layers for a full redraw.
        model?.modelRenderView.setNeedsDisplay()
        model?.captureRenderView.setNeedsDisplay()
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
        let sizePx = CGSize(width: CGFloat(width), height: CGFloat(height))
        UIGraphicsBeginImageContextWithOptions(sizePx, false, 1)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return 0 }

        return offscreenRenderSurfaces.createSurface(
            width: width,
            height: height,
            context: context,
            alphaMask: alphaMask
        )
    }

    func releaseOffscreenRenderSurface(_ surfaceId: UInt32) {
        // Releases an offscreen buffer when the renderer is done with it.
        offscreenRenderSurfaces.releaseSurface(surfaceId)
    }

    func createOffscreenRenderCanvas(_ surfaceId: UInt32) -> IINKICanvas {
        // Wraps the offscreen context in a canvas object.
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
        // Restores the graphics state saved when the canvas was created.
        (canvas as? Canvas)?.context?.restoreGState()
    }
}
