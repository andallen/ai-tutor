//
// AIOverlayContextProvider.swift
// InkOS
//
// Protocol for view controllers that host the AI overlay.
// Provides context information when the AI sends messages.
//

import Foundation

// MARK: - AIOverlayContextProvider

// Protocol for view controllers that host the AI overlay.
// The coordinator queries this protocol dynamically when sending messages.
protocol AIOverlayContextProvider: AnyObject {
  // The current location in the app (determines available context scopes).
  var overlayLocation: AIOverlayLocation { get }

  // ID of the currently open notebook (nil if no notebook is open).
  var currentNoteID: String? { get }

  // ID of the current folder context (nil if not in a folder).
  var currentFolderID: String? { get }

  // Current page number for editors (nil for non-editor views).
  var currentPageNumber: Int? { get }

  // Selected content for editors (nil if no selection or not an editor).
  var currentSelection: String? { get }
}

// Default implementations for optional properties.
extension AIOverlayContextProvider {
  var currentPageNumber: Int? { nil }
  var currentSelection: String? { nil }
}

// MARK: - AIOverlayCoordinatorDelegate

// Optional delegate for receiving overlay state change notifications.
protocol AIOverlayCoordinatorDelegate: AnyObject {
  // Called when the overlay is about to expand.
  func overlayWillExpand(_ coordinator: AIOverlayCoordinator)

  // Called when the overlay finished collapsing.
  func overlayDidCollapse(_ coordinator: AIOverlayCoordinator)

  // Called when a message is sent (for analytics or custom handling).
  func overlay(_ coordinator: AIOverlayCoordinator, didSendMessage text: String)
}

// Default empty implementations.
extension AIOverlayCoordinatorDelegate {
  func overlayWillExpand(_ coordinator: AIOverlayCoordinator) {}
  func overlayDidCollapse(_ coordinator: AIOverlayCoordinator) {}
  func overlay(_ coordinator: AIOverlayCoordinator, didSendMessage text: String) {}
}
