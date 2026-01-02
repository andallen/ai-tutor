import UIKit

// Custom navigation controller for the editor that supports hero transitions.
// Provides a reference to the transition coordinator for coordinated dismissal.
class EditorNavigationController: UINavigationController {

  // MARK: - Properties

  // Reference to the notebook transition coordinator for dismiss orchestration.
  // Weak to avoid retain cycle since coordinator holds reference to this controller.
  weak var notebookTransitionCoordinator: NotebookTransitionCoordinator?

  // MARK: - Initialization

  override init(rootViewController: UIViewController) {
    super.init(rootViewController: rootViewController)
    configureAppearance()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configureAppearance()
  }

  // MARK: - Configuration

  // Configures the navigation bar appearance to be transparent.
  private func configureAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = .clear
    appearance.shadowColor = .clear

    navigationBar.standardAppearance = appearance
    navigationBar.scrollEdgeAppearance = appearance
    navigationBar.compactAppearance = appearance
    navigationBar.isTranslucent = true
  }

  // MARK: - Status Bar

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .darkContent
  }

  override var prefersStatusBarHidden: Bool {
    return false
  }
}
