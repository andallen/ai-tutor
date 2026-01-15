//
// ImageContent.swift
// InkOS
//
// Static images from any source (URL, base64, library, AI-generated).
// Rendered natively using SwiftUI Image.
//

import Foundation

// MARK: - ImageContent

// Static images from any source.
struct ImageContent: Sendable, Codable, Equatable {
  // Image source (URL, base64, library, or generated).
  let source: ImageSource

  // Accessibility description.
  let altText: String?

  // Caption displayed below the image.
  let caption: String?

  // Source attribution.
  let attribution: ImageAttribution?

  // Sizing options.
  let sizing: ImageSizing?

  // Border options.
  let border: ImageBorder?

  private enum CodingKeys: String, CodingKey {
    case source
    case altText = "alt_text"
    case caption
    case attribution
    case sizing
    case border
  }

  init(
    source: ImageSource,
    altText: String? = nil,
    caption: String? = nil,
    attribution: ImageAttribution? = nil,
    sizing: ImageSizing? = nil,
    border: ImageBorder? = nil
  ) {
    self.source = source
    self.altText = altText
    self.caption = caption
    self.attribution = attribution
    self.sizing = sizing
    self.border = border
  }

  // Convenience initializers.

  static func url(_ url: String, altText: String? = nil, caption: String? = nil) -> ImageContent {
    ImageContent(source: .url(url: url), altText: altText, caption: caption)
  }

  static func base64(data: String, mimeType: ImageMimeType, altText: String? = nil) -> ImageContent {
    ImageContent(source: .base64(data: data, mimeType: mimeType), altText: altText)
  }

  static func library(id: String, altText: String? = nil) -> ImageContent {
    ImageContent(source: .library(libraryId: id), altText: altText)
  }

  static func generated(prompt: String, altText: String? = nil) -> ImageContent {
    ImageContent(source: .generated(prompt: prompt, resultUrl: nil, model: nil), altText: altText)
  }
}

// MARK: - ImageSource

// Image source types.
enum ImageSource: Sendable, Equatable {
  case url(url: String)
  case base64(data: String, mimeType: ImageMimeType)
  case library(libraryId: String)
  case generated(prompt: String, resultUrl: String?, model: String?)
}

// MARK: - ImageSource Codable

extension ImageSource: Codable {
  private enum TypeKey: String, CodingKey {
    case type
    case url
    case data
    case mimeType = "mime_type"
    case libraryId = "library_id"
    case prompt
    case resultUrl = "result_url"
    case model
  }

  private enum SourceType: String, Codable {
    case url
    case base64
    case library
    case generated
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(SourceType.self, forKey: .type)

    switch type {
    case .url:
      let url = try container.decode(String.self, forKey: .url)
      self = .url(url: url)

    case .base64:
      let data = try container.decode(String.self, forKey: .data)
      let mimeType = try container.decode(ImageMimeType.self, forKey: .mimeType)
      self = .base64(data: data, mimeType: mimeType)

    case .library:
      let libraryId = try container.decode(String.self, forKey: .libraryId)
      self = .library(libraryId: libraryId)

    case .generated:
      let prompt = try container.decode(String.self, forKey: .prompt)
      let resultUrl = try container.decodeIfPresent(String.self, forKey: .resultUrl)
      let model = try container.decodeIfPresent(String.self, forKey: .model)
      self = .generated(prompt: prompt, resultUrl: resultUrl, model: model)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TypeKey.self)

    switch self {
    case .url(let url):
      try container.encode(SourceType.url, forKey: .type)
      try container.encode(url, forKey: .url)

    case .base64(let data, let mimeType):
      try container.encode(SourceType.base64, forKey: .type)
      try container.encode(data, forKey: .data)
      try container.encode(mimeType, forKey: .mimeType)

    case .library(let libraryId):
      try container.encode(SourceType.library, forKey: .type)
      try container.encode(libraryId, forKey: .libraryId)

    case .generated(let prompt, let resultUrl, let model):
      try container.encode(SourceType.generated, forKey: .type)
      try container.encode(prompt, forKey: .prompt)
      try container.encodeIfPresent(resultUrl, forKey: .resultUrl)
      try container.encodeIfPresent(model, forKey: .model)
    }
  }
}

// MARK: - ImageMimeType

// Supported image MIME types.
enum ImageMimeType: String, Sendable, Codable, Equatable {
  case png = "image/png"
  case jpeg = "image/jpeg"
  case gif = "image/gif"
  case webp = "image/webp"
  case svg = "image/svg+xml"
}

// MARK: - ImageAttribution

// Source attribution for the image.
struct ImageAttribution: Sendable, Codable, Equatable {
  // Source name (e.g., "NASA", "OpenStax Biology").
  let source: String?

  // Source URL.
  let url: String?

  // License type (e.g., "CC BY 4.0", "Public Domain").
  let license: String?

  init(source: String? = nil, url: String? = nil, license: String? = nil) {
    self.source = source
    self.url = url
    self.license = license
  }
}

// MARK: - ImageSizing

// Image sizing options.
struct ImageSizing: Sendable, Codable, Equatable {
  // Sizing mode.
  let mode: ImageSizingMode

  // Maximum width as fraction of container (0.0-1.0).
  let maxWidth: Double?

  // Forced aspect ratio (width/height). If omitted, use natural ratio.
  let aspectRatio: Double?

  private enum CodingKeys: String, CodingKey {
    case mode
    case maxWidth = "max_width"
    case aspectRatio = "aspect_ratio"
  }

  init(mode: ImageSizingMode = .fit, maxWidth: Double? = nil, aspectRatio: Double? = nil) {
    self.mode = mode
    self.maxWidth = maxWidth
    self.aspectRatio = aspectRatio
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.mode = try container.decodeIfPresent(ImageSizingMode.self, forKey: .mode) ?? .fit
    self.maxWidth = try container.decodeIfPresent(Double.self, forKey: .maxWidth)
    self.aspectRatio = try container.decodeIfPresent(Double.self, forKey: .aspectRatio)
  }
}

// MARK: - ImageSizingMode

// Image sizing modes.
enum ImageSizingMode: String, Sendable, Codable, Equatable {
  // Contain within bounds.
  case fit

  // Cover bounds.
  case fill

  // Natural size.
  case original
}

// MARK: - ImageBorder

// Image border options.
struct ImageBorder: Sendable, Codable, Equatable {
  let enabled: Bool
  let color: String?
  let width: Double
  let radius: Double

  private enum CodingKeys: String, CodingKey {
    case enabled
    case color
    case width
    case radius
  }

  init(enabled: Bool = false, color: String? = nil, width: Double = 1, radius: Double = 0) {
    self.enabled = enabled
    self.color = color
    self.width = width
    self.radius = radius
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    self.color = try container.decodeIfPresent(String.self, forKey: .color)
    self.width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 1
    self.radius = try container.decodeIfPresent(Double.self, forKey: .radius) ?? 0
  }
}
