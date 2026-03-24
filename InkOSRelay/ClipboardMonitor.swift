//
// ClipboardMonitor.swift
// InkOSRelay
//
// Monitors the macOS clipboard for InkOS-marked PNG images.
// When one is detected and the frontmost app is a terminal,
// simulates Ctrl+V to paste the image into Claude Code.
//

import AppKit
import Foundation

class ClipboardMonitor {
  // Polling interval in seconds.
  private let pollInterval: TimeInterval = 0.5

  // Cooldown between pastes to avoid rapid-fire.
  private let pasteCooldown: TimeInterval = 2.0

  // Last known clipboard change count.
  private var lastChangeCount: Int

  // Timestamp of last paste action.
  private var lastPasteTime: Date = .distantPast

  // Polling timer.
  private var timer: Timer?

  // Terminal bundle identifiers that Claude Code runs in.
  private let terminalBundleIDs: Set<String> = [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "net.kovidgoyal.kitty",
    "com.mitchellh.ghostty",
    "dev.warp.Warp-Stable",
  ]

  init() {
    lastChangeCount = NSPasteboard.general.changeCount
  }

  // Starts monitoring the clipboard.
  func start() {
    timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
      self?.checkClipboard()
    }
    print("[InkOSRelay] Monitoring clipboard for InkOS images...")
  }

  // Stops monitoring.
  func stop() {
    timer?.invalidate()
    timer = nil
  }

  // Checks the clipboard for new InkOS images.
  private func checkClipboard() {
    let currentCount = NSPasteboard.general.changeCount
    guard currentCount != lastChangeCount else { return }
    lastChangeCount = currentCount

    // Check cooldown.
    guard Date().timeIntervalSince(lastPasteTime) > pasteCooldown else {
      print("[InkOSRelay] Cooldown active, skipping.")
      return
    }

    // Check if clipboard has PNG data.
    guard let pngData = NSPasteboard.general.data(forType: .png) else { return }

    // Check for InkOS marker.
    guard PNGMetadata.isInkOSImage(pngData) else { return }

    // Check if a terminal is the frontmost app.
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          let bundleID = frontApp.bundleIdentifier,
          terminalBundleIDs.contains(bundleID)
    else {
      print("[InkOSRelay] InkOS image detected but terminal is not frontmost.")
      return
    }

    print("[InkOSRelay] InkOS image detected, pasting into \(bundleID)...")

    // Brief delay to let clipboard settle.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.simulateCtrlV()
      self?.lastPasteTime = Date()
    }
  }

  // Simulates Ctrl+V keystroke in the frontmost app using CGEvent.
  // Only requires Accessibility permission (no Automation needed).
  // Claude Code intercepts Ctrl+V for image paste in the terminal.
  private func simulateCtrlV() {
    let vKeyCode: UInt16 = 9

    // Key down with control modifier.
    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true) else {
      print("[InkOSRelay] Failed to create key down event.")
      return
    }
    keyDown.flags = .maskControl

    // Key up with control modifier.
    guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
      print("[InkOSRelay] Failed to create key up event.")
      return
    }
    keyUp.flags = .maskControl

    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)

    print("[InkOSRelay] Pasted successfully.")
  }
}
