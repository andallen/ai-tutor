import SwiftUI
import UIKit

struct GetStartedHostView: UIViewControllerRepresentable {
  let documentHandle: DocumentHandle

  func makeUIViewController(context: Context) -> UIViewController {
    let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
    let viewController = storyboard.instantiateInitialViewController() ?? UIViewController()
    if let navigationController = viewController as? UINavigationController {
      let rootViewController = navigationController.viewControllers.first
      if let homeViewController = rootViewController as? HomeViewController {
        homeViewController.configure(documentHandle: documentHandle)
      }
    } else if let homeViewController = viewController as? HomeViewController {
      homeViewController.configure(documentHandle: documentHandle)
    }
    return viewController
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
