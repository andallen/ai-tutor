//
// PNGMetadata.swift
// InkOS
//
// Utility for embedding and reading a marker in PNG metadata.
// Used to distinguish InkOS clipboard images from regular copies.
// The marker is stored in the PNG tEXt chunk via kCGImagePropertyPNGDescription.
// Shared between iPad app and Mac relay.
//

import ImageIO
import UniformTypeIdentifiers

enum PNGMetadata {
  // The marker string embedded in PNG metadata.
  static let marker = "InkOS-v1"

  // Creates PNG data with the InkOS marker embedded in metadata.
  // Returns nil if the image cannot be encoded.
  static func buildMarkedPNG(from cgImage: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      data,
      UTType.png.identifier as CFString,
      1,
      nil
    ) else { return nil }

    let properties: [String: Any] = [
      kCGImagePropertyPNGDictionary as String: [
        kCGImagePropertyPNGDescription as String: marker,
      ],
    ]

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

    guard CGImageDestinationFinalize(destination) else { return nil }

    return data as Data
  }

  // Checks whether the given PNG data contains the InkOS marker.
  static func isInkOSImage(_ pngData: Data) -> Bool {
    guard let source = CGImageSourceCreateWithData(pngData as CFData, nil) else {
      return false
    }

    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
      as? [String: Any]
    else {
      return false
    }

    guard let pngDict = properties[kCGImagePropertyPNGDictionary as String]
      as? [String: Any]
    else {
      return false
    }

    let description = pngDict[kCGImagePropertyPNGDescription as String] as? String
    return description == marker
  }
}
