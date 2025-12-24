import Combine
import UIKit

// Creates and lays out the render views owned by the display model.
final class DisplayViewController: UIViewController {
  // Supplies the model and render target implementation.
  private let viewModel: DisplayViewModel

  // Holds Combine subscriptions for model binding.
  private var cancellables: Set<AnyCancellable> = []

  init(viewModel: DisplayViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func loadView() {
    // Sets up a plain container for the render views.
    view = UIView(frame: .zero)
    view.backgroundColor = .clear

    // Binds to the model so render views are added once created.
    bindViewModel()

    // Sets the scale used by offscreen surfaces.
    // `view.contentScaleFactor` is often `1.0` in `loadView` (before the view is in a window),
    // but the SDK expects view coordinates in pixels.
    let scale = UIScreen.main.scale
    view.contentScaleFactor = scale
    viewModel.setOffScreenRendererSurfacesScale(scale: scale)

    // Builds the display model if it does not exist.
    viewModel.setupModel()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Ensure the scale matches the actual screen once attached to a window.
    let scale = view.window?.screen.scale ?? UIScreen.main.scale
    view.contentScaleFactor = scale
    viewModel.setOffScreenRendererSurfacesScale(scale: scale)
    if let model = viewModel.model {
      model.modelRenderView.contentScaleFactor = scale
      model.captureRenderView.contentScaleFactor = scale
    }
  }

  private func bindViewModel() {
    // Installs render views when the model becomes available.
    viewModel.$model.sink { [weak self] model in
      guard let self, let model else { return }

      // Installs the model layer view.
      self.configure(renderView: model.modelRenderView)

      // Installs the capture layer view on top.
      self.configure(renderView: model.captureRenderView)

      // Forces an initial draw after installation.
      self.viewModel.refreshDisplay()
    }.store(in: &cancellables)
  }

  private func configure(renderView: RenderView) {
    // Avoids re-adding a view that is already installed.
    if renderView.superview != nil {
      return
    }

    // Makes the render view fill the container.
    view.addSubview(renderView)
    renderView.translatesAutoresizingMaskIntoConstraints = false
    renderView.backgroundColor = .clear
    renderView.isOpaque = false

    NSLayoutConstraint.activate([
      renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      renderView.topAnchor.constraint(equalTo: view.topAnchor),
      renderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }
}
