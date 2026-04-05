//
// PNGCaptureMode.swift
// PaperClipMac
//
// Reads the capture mode tag from PaperClip PNG metadata.
// The iPad app embeds the mode (crop, viewport, fullCanvas) in the PNG
// tEXt description chunk as "PaperClip-v1:<mode>".
//

import Foundation
import ImageIO

// Capture mode embedded in PNG metadata by the iPad app.
enum CaptureMode: String {
  case crop     = "crop"
  case viewport = "viewport"
}

enum PNGCaptureMode {
  // The marker prefix written by the iPad app.
  private static let marker = "PaperClip-v1"

  // Reads the capture mode from PaperClip PNG metadata.
  // Returns nil for non-PaperClip images or legacy images without a mode tag.
  static func captureMode(from pngData: Data) -> CaptureMode? {
    guard let source = CGImageSourceCreateWithData(pngData as CFData, nil) else {
      return nil
    }

    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
      as? [String: Any]
    else {
      return nil
    }

    guard let pngDict = properties[kCGImagePropertyPNGDictionary as String]
      as? [String: Any]
    else {
      return nil
    }

    guard let description = pngDict[kCGImagePropertyPNGDescription as String] as? String,
          description.hasPrefix(marker)
    else {
      return nil
    }

    // Split "PaperClip-v1:viewport" into marker and mode.
    let parts = description.split(separator: ":", maxSplits: 1)
    guard parts.count == 2 else { return nil }
    return CaptureMode(rawValue: String(parts[1]))
  }
}
