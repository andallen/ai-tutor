//
// PNGMetadata.swift
// PaperClip
//
// Utility for embedding and reading a marker in PNG metadata.
// Used to distinguish PaperClip clipboard images from regular copies.
// The marker is stored in the PNG tEXt chunk via kCGImagePropertyPNGDescription.
// Shared between iPad app and Mac relay.
//

import ImageIO
import UniformTypeIdentifiers

// Capture mode tag stored alongside the PaperClip marker in PNG metadata.
// Used by the Mac app to decide display treatment (e.g. rounded corners).
enum CaptureMode: String {
  case crop     = "crop"
  case viewport = "viewport"
}

enum PNGMetadata {
  // The marker string embedded in PNG metadata.
  static let marker = "PaperClip-v1"

  // Separator between the marker and the capture mode tag.
  private static let separator = ":"

  // Creates PNG data with the PaperClip marker and capture mode embedded
  // in metadata. Returns nil if the image cannot be encoded.
  static func buildMarkedPNG(from cgImage: CGImage, mode: CaptureMode) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      data,
      UTType.png.identifier as CFString,
      1,
      nil
    ) else { return nil }

    // Encode marker and mode as "PaperClip-v1:viewport" etc.
    let description = marker + separator + mode.rawValue

    let properties: [String: Any] = [
      kCGImagePropertyPNGDictionary as String: [
        kCGImagePropertyPNGDescription as String: description,
      ],
    ]

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

    guard CGImageDestinationFinalize(destination) else { return nil }

    return data as Data
  }

  // Checks whether the given PNG data contains the PaperClip marker.
  static func isPaperClipImage(_ pngData: Data) -> Bool {
    guard let description = readDescription(from: pngData) else { return false }
    return description.hasPrefix(marker)
  }

  // Reads the capture mode from PaperClip PNG metadata.
  // Returns nil for non-PaperClip images or legacy images without a mode tag.
  static func captureMode(from pngData: Data) -> CaptureMode? {
    guard let description = readDescription(from: pngData),
          description.hasPrefix(marker)
    else { return nil }

    // Split "PaperClip-v1:viewport" into marker and mode.
    let parts = description.split(separator: Character(separator), maxSplits: 1)
    guard parts.count == 2 else { return nil }
    return CaptureMode(rawValue: String(parts[1]))
  }

  // Reads the PNG description string from image metadata.
  private static func readDescription(from pngData: Data) -> String? {
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

    return pngDict[kCGImagePropertyPNGDescription as String] as? String
  }
}
