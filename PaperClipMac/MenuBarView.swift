//
// MenuBarView.swift
// PaperClipMac
//
// The dropdown panel shown when the user clicks the menu bar icon.
// Displays connection status with colored indicator, device name,
// last-received timestamp, thumbnail preview, login item toggle,
// and a quit button.
//

import Combine
import ServiceManagement
import SwiftUI

struct MenuBarView: View {
  var service: ReceiverService

  // Persisted toggle for "Start at Login".
  @AppStorage("launchAtLogin") private var launchAtLogin = false

  // Fires every 10 seconds to refresh the relative timestamp.
  @State private var now = Date()

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Status section.
      statusSection
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)

      // Thumbnail preview of last received image.
      // Crop and viewport images get rounded corners; full canvas does not.
      if let imageData = service.lastReceivedImage,
        let nsImage = NSImage(data: imageData)
      {
        thumbnailView(nsImage, roundedCorners: true)
          .padding(.horizontal, 16)
          .padding(.bottom, 10)
      }

      Divider()
        .padding(.horizontal, 12)

      // Login item toggle.
      Toggle("Start at Login", isOn: $launchAtLogin)
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: launchAtLogin) { _, enabled in
          setLoginItem(enabled: enabled)
        }

      Divider()
        .padding(.horizontal, 12)

      // Quit button.
      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        Text("Quit PaperClip Receiver")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
    .frame(width: 280)
    .padding(.bottom, 6)
    .onAppear {
      syncLoginItemState()
    }
    .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
      now = Date()
    }
  }

  // MARK: - Status Section

  // Status indicator dot, text, device name, and timestamp.
  private var statusSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Status row: colored dot + status text.
      HStack(spacing: 8) {
        Circle()
          .fill(statusColor)
          .frame(width: 10, height: 10)

        Text(statusText)
          .font(.system(size: 13, weight: .semibold))
      }

      // Connected device name.
      if let name = service.connectedDeviceName {
        Text(name)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .padding(.leading, 18)
      }

      // Received count and relative timestamp.
      if service.receivedCount > 0 {
        HStack(spacing: 4) {
          Text("\(service.receivedCount) image\(service.receivedCount == 1 ? "" : "s") received")
          if let date = service.lastReceivedDate {
            Text("·")
            Text(relativeTimestamp(since: date))
          }
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.leading, 18)
      }
    }
  }

  // MARK: - Thumbnail

  // Shows a small preview of the last received drawing.
  // Crop and viewport images use rounded corners; full canvas uses sharp corners.
  @ViewBuilder
  private func thumbnailView(_ image: NSImage, roundedCorners: Bool) -> some View {
    if roundedCorners {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    } else {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 140)
        .overlay(
          Rectangle()
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
  }

  // MARK: - Status Helpers

  // Display text for the current receiver state.
  private var statusText: String {
    switch service.state {
    case .idle:
      return "Starting…"
    case .waiting:
      return "Waiting for iPad"
    case .connected:
      return "Connected"
    case .receiving:
      return "Receiving…"
    }
  }

  // Color for the status indicator dot.
  private var statusColor: Color {
    switch service.state {
    case .idle:
      return .gray
    case .waiting:
      return .orange
    case .connected:
      return .green
    case .receiving:
      return .blue
    }
  }

  // MARK: - Relative Timestamp

  // Formats a relative timestamp, omitting seconds once past 1 minute.
  private func relativeTimestamp(since date: Date) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 {
      return "\(seconds)s ago"
    }
    let minutes = seconds / 60
    if minutes < 60 {
      return "\(minutes)m ago"
    }
    let hours = minutes / 60
    if hours < 24 {
      return "\(hours)h ago"
    }
    let days = hours / 24
    return "\(days)d ago"
  }

  // MARK: - Login Item

  // Registers or unregisters the app as a login item.
  private func setLoginItem(enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      // Log failure; toggle will resync on next open.
    }
  }

  // Syncs the toggle state with the actual login item status.
  private func syncLoginItemState() {
    let status = SMAppService.mainApp.status
    launchAtLogin = (status == .enabled)
  }
}
