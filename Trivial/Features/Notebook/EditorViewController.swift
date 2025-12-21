import UIKit
import Foundation
import Combine

// UIKit controller that manages the IINKRenderer and CanvasView.
// Acts as the bridge between the MyScript engine and the view hierarchy.
class EditorViewController: UIViewController {

  // The worker that manages the editor logic.
  let editorWorker: EditorWorker

  // Reference to the MyScript engine.
  private let engine: IINKEngine?

  // The rendering target view.
  private var canvasView: CanvasView?

  // The MyScript renderer instance.
  private var renderer: IINKRenderer?

  // Combine subscriptions for reactive updates.
  private var cancellables = Set<AnyCancellable>()

  init(editorWorker: EditorWorker) {
    self.editorWorker = editorWorker
    self.engine = EngineProvider.shared.engine
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Create and add the CanvasView.
    let canvas = CanvasView(frame: self.view.bounds)
    canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.view.addSubview(canvas)
    self.canvasView = canvas

    // Initialize the MyScript engine and renderer.
    setupMyScript()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    // Inform the editor of the new view size for coordinate calibration.
    if let editor = editorWorker.editor {
      let size = self.view.bounds.size
      if size.width > 0 && size.height > 0 {
        do {
          try editor.set(viewSize: size)
        } catch {
          // Setting view size failed.
        }
      }
    }
  }

  // Creates the renderer and attaches the editor to the canvas.
  private func setupMyScript() {
    guard let engine = self.engine, let canvas = self.canvasView else {
      return
    }

    // Calculate physical DPI using nativeScale for accurate coordinate mapping.
    // iPad Pro standard is ~264 DPI, but we derive it from nativeScale.
    // Use the view's window scene screen if available, otherwise fall back to trait collection.
    let nativeScale: CGFloat
    if let windowScene = self.view.window?.windowScene {
      nativeScale = windowScene.screen.nativeScale
    } else {
      // Fallback: nativeScale is typically 2x displayScale for retina displays.
      nativeScale = self.view.traitCollection.displayScale * 2
    }
    let dpiX = Float(nativeScale * 132)
    let dpiY = Float(nativeScale * 132)

    // Create renderer targeting the canvas view.
    if let renderer = try? engine.createRenderer(dpiX: dpiX, dpiY: dpiY, target: canvas) {
      self.renderer = renderer

      // Attach the editor worker to this renderer.
      editorWorker.attach(engine: engine, renderer: renderer)

      // Connect the editor to the canvas for input routing.
      canvas.editor = editorWorker.editor

      // Set the view size immediately after creation for coordinate calibration.
      // This ensures the editor knows the pixel dimensions of the rendering surface.
      if let editor = editorWorker.editor {
        let size = self.view.bounds.size
        if size.width > 0 && size.height > 0 {
          do {
            try editor.set(viewSize: size)
          } catch {
            // Setting view size failed.
          }
        }
      }
    }
  }

  deinit {
    // MyScript objects are reference-counted and release automatically.
  }
}
