// PDFEditorHostView.swift
// SwiftUI wrapper for PDFDocumentViewController.
// Follows the EditorHostView pattern for consistency.
// Creates and configures the view controller hierarchy.

import PDFKit
import SwiftUI
import UIKit

// SwiftUI bridge that presents PDFDocumentViewController in a fullScreenCover.
// Takes a PDFDocumentSession containing all data needed for the PDF editor.
// Wraps the controller in a UINavigationController for navigation bar support.
struct PDFEditorHostView: UIViewControllerRepresentable {
  // The session containing all data needed for the PDF editor.
  let session: PDFDocumentSession

  // Creates the PDFDocumentViewController wrapped in a UINavigationController.
  // Configures the controller with the document handle.
  // Returns an error view controller if initialization fails.
  func makeUIViewController(context: Context) -> UIViewController {
    do {
      // Create PDFDocumentViewController with noteDocument and pdfDocument.
      let pdfViewController = try PDFDocumentViewController(
        noteDocument: session.noteDocument,
        pdfDocument: session.pdfDocument
      )

      // Configure with document handle for MyScript part access.
      pdfViewController.configure(documentHandle: session.handle)

      // Wrap in navigation controller for navigation bar support.
      let navigationController = UINavigationController(rootViewController: pdfViewController)
      return navigationController
    } catch {
      // Return error view controller if initialization fails.
      return createErrorViewController(error: error)
    }
  }

  // No-op update since the session is immutable.
  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    // No updates needed - session is immutable.
  }

  // Creates a simple error view controller displaying the error message.
  // Includes an error icon and a message for the user.
  private func createErrorViewController(error: Error) -> UIViewController {
    let viewController = UIViewController()
    viewController.view.backgroundColor = .systemBackground

    // Create container stack view.
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.spacing = 16
    stackView.translatesAutoresizingMaskIntoConstraints = false
    viewController.view.addSubview(stackView)

    // Create error icon.
    let iconView = UIImageView()
    iconView.image = UIImage(systemName: "exclamationmark.triangle")
    iconView.tintColor = .systemRed
    iconView.contentMode = .scaleAspectFit
    iconView.translatesAutoresizingMaskIntoConstraints = false
    stackView.addArrangedSubview(iconView)

    // Create error message label.
    let messageLabel = UILabel()
    messageLabel.text = "Failed to load PDF:\n\(error.localizedDescription)"
    messageLabel.textAlignment = .center
    messageLabel.textColor = .secondaryLabel
    messageLabel.font = .systemFont(ofSize: 16)
    messageLabel.numberOfLines = 0
    messageLabel.translatesAutoresizingMaskIntoConstraints = false
    stackView.addArrangedSubview(messageLabel)

    // Layout constraints.
    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
      stackView.leadingAnchor.constraint(
        greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: 32),
      stackView.trailingAnchor.constraint(
        lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -32),
      iconView.widthAnchor.constraint(equalToConstant: 48),
      iconView.heightAnchor.constraint(equalToConstant: 48)
    ])

    return viewController
  }
}
