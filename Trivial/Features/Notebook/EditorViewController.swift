import UIKit
import Foundation
import Combine

// UIKit controller that manages the IINKRenderer and the custom RenderView.
class EditorViewController: UIViewController {

  let editorWorker: EditorWorker
  private let engine: IINKEngine?
  private var renderer: IINKRenderer?
  private var editorSubscription: AnyCancellable?
  
  // Use the custom RenderView for high-performance rendering.
  private var renderView: RenderView?

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

    // Ensure the parent view allows interaction.
    self.view.isUserInteractionEnabled = true
    
    // Initialize the custom RenderView.
    let canvas = RenderView(frame: self.view.bounds)
    canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    // Explicitly enable interaction to ensure touch events are received.
    canvas.isUserInteractionEnabled = true
    
    // Prevent parent gestures from hijacking the ink strokes.
    canvas.gestureRecognizers?.forEach {
        $0.cancelsTouchesInView = false
        $0.delaysTouchesBegan = false
    }
    
    // Prevent the system from stealing touches for navigation gestures.
    // If this is in a navigation controller, it prevents the "swipe to go back"
    // gesture from canceling your ink strokes.
    self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    
    self.view.addSubview(canvas)
    self.renderView = canvas

    setupMyScript()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Disabling this prevents the side-swipe gesture from canceling ink strokes.
    self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // Re-enable when leaving the notebook view.
    self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    // Use the renderView bounds to ensure accurate coordinate mapping.
    let size = renderView?.bounds.size ?? .zero
    if size.width > 0 && size.height > 0 {
      // Use EditorWorker's setViewSize to ensure proper ordering with part attachment.
      editorWorker.setViewSize(size)
    }
  }

  private func setupMyScript() {
    guard let engine = self.engine, let canvas = self.renderView else {
      return
    }

    // Adjust DPI based on environment.
    // Simulator needs a fixed DPI to ensure strokes aren't rejected as "too small".
    // Physical devices use native scale for accurate coordinate mapping.
    let physicalDPI: Float
    #if targetEnvironment(simulator)
      // Use a fixed, standard DPI for the Simulator to ensure correct scale.
      physicalDPI = 96.0
    #else
      // Use the actual device scale for physical hardware.
      let scale = UIScreen.main.nativeScale
      physicalDPI = Float(scale * 132)
    #endif
    
    print("📏 Setting MyScript DPI to: \(physicalDPI)")

    if let renderer = try? engine.createRenderer(dpiX: physicalDPI, dpiY: physicalDPI, target: canvas) {
      self.renderer = renderer
      canvas.renderer = renderer
      editorWorker.attach(engine: engine, renderer: renderer)
      
      // Observe the @Published editor property to set it on the canvas.
      // This ensures the editor is set deterministically after attach() completes.
      // Note: view size is set via viewDidLayoutSubviews to ensure proper ordering.
      self.editorSubscription = editorWorker.$editor
        .compactMap { $0 }
        .first()
        .sink { [weak canvas] editor in
          canvas?.editor = editor
        }
    }
  }
}