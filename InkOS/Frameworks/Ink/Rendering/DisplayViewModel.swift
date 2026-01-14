// Copyright @ MyScript. All rights reserved.

import Combine
import Foundation
import UIKit

/// This class is the ViewModel of the DisplayViewController. It handles all its business logic.

class DisplayViewModel: NSObject {

  // MARK: - Reactive Properties

  @Published var renderView: RenderView?

  // MARK: - Properties

  var renderer: IINKRenderer?
  var imageLoader: ImageLoader?
  // Uses protocol type to allow dependency injection for testing.
  private(set) var offscreenRenderSurfaces: OffscreenRenderSurfacesProtocol
  private var didSetConstraints: Bool = false

  // MARK: - Initialization

  // Accepts an offscreenRenderSurfaces dependency. Defaults to production implementation.
  init(offscreenRenderSurfaces: OffscreenRenderSurfacesProtocol = OffscreenRenderSurfaces()) {
    self.offscreenRenderSurfaces = offscreenRenderSurfaces
    super.init()
  }

  func setupModel() {
    let renderView = RenderView(frame: CGRect.zero)
    renderView.offscreenRenderSurfaces = offscreenRenderSurfaces
    if let renderer {
      renderView.renderer = renderer
    }
    if let imageLoader {
      renderView.imageLoader = imageLoader
    }
    self.renderView = renderView
  }

  func setOffScreenRendererSurfacesScale(scale: CGFloat) {
    self.offscreenRenderSurfaces.scale = scale
  }

  func initModelViewConstraints(view: UIView) {
    guard self.didSetConstraints == false, let renderView = self.renderView else { return }
    self.didSetConstraints = true
    let views: [String: RenderView] = ["renderView": renderView]
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "H:|[renderView]|", options: .alignAllLeft, metrics: nil, views: views))
    view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "V:|[renderView]|", options: .alignAllLeft, metrics: nil, views: views))
  }

  func refreshDisplay() {
    self.renderView?.setNeedsDisplay()
  }
}

extension DisplayViewModel: IINKIRenderTarget {

  func invalidate(_ renderer: IINKRenderer, layers: IINKLayerType) {
    DispatchQueue.main.async { [weak self] in
      self?.renderView?.setNeedsDisplay()
    }
  }

  func invalidate(_ renderer: IINKRenderer, area: CGRect, layers: IINKLayerType) {
    DispatchQueue.main.async { [weak self] in
      // Force a full redraw to avoid live-capture striping artifacts.
      self?.renderView?.setNeedsDisplay()
    }
  }

  func createOffscreenRenderSurface(width: Int32, height: Int32, alphaMask: Bool) -> UInt32 {
    // Guard against zero or negative dimensions to prevent UIKit crash.
    guard width > 0, height > 0 else {
      return 0
    }
    defer {
      UIGraphicsEndImageContext()
    }
    let scale: CGFloat = self.offscreenRenderSurfaces.scale
    let size = CGSize(width: scale * CGFloat(width), height: scale * CGFloat(height))
    UIGraphicsBeginImageContextWithOptions(size, false, 1)
    if let context = UIGraphicsGetCurrentContext(),
      let buffer = CGLayer(context, size: size, auxiliaryInfo: nil) {
      context.scaleBy(x: size.width, y: size.height)
      return self.offscreenRenderSurfaces.addSurface(with: buffer)
    }
    return 0
  }

  func releaseOffscreenRenderSurface(_ surfaceId: UInt32) {
    self.offscreenRenderSurfaces.releaseSurface(forId: surfaceId)
  }

  func createOffscreenRenderCanvas(_ surfaceId: UInt32) -> IINKICanvas {
    let canvas = Canvas()
    var pixelSize: CGSize = CGSize.zero
    if let buffer: CGLayer = self.offscreenRenderSurfaces.getSurfaceBuffer(forId: surfaceId) {
      pixelSize = buffer.size
      canvas.context = buffer.context
    }
    let scale: CGFloat = offscreenRenderSurfaces.scale
    let size = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    canvas.offscreenRenderSurfaces = self.offscreenRenderSurfaces
    canvas.imageLoader = self.imageLoader
    canvas.context?.saveGState()
    canvas.size = size
    return canvas
  }

  func releaseOffscreenRenderCanvas(_ canvas: IINKICanvas) {
    if let canvasCast: Canvas = canvas as? Canvas {
      canvasCast.context?.restoreGState()
    }
  }

  var pixelDensity: Float {
    return Float(UIScreen.main.scale)
  }
}
