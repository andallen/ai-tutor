import CoreText
import Foundation
import UIKit

// Provides font metrics for text rendering in MyScript.
// Required by the IINKEditor to properly render recognized text.
class FontMetricsProvider: NSObject, IINKIFontMetricsProvider {
  // Returns the bounding box of each character in the text.
  func getCharacterBoundingBoxes(_ text: IINKText!, spans: [IINKTextSpan]!) -> [NSValue]! {
    var charBoxes = [NSValue]()
    guard let glyphMetrics = getGlyphMetrics(text, spans: spans) else {
      return charBoxes
    }
    for glyphMetric in glyphMetrics {
      charBoxes.append(NSValue(cgRect: glyphMetric.boundingBox))
    }
    return charBoxes
  }

  // Returns the font size in pixels for the given style.
  func getFontSizePx(_ style: IINKStyle!) -> Float {
    return style.fontSize
  }

  // Returns detailed metrics for each glyph in the text.
  // This is an optional method but provides better accuracy.
  func getGlyphMetrics(_ text: IINKText!, spans: [IINKTextSpan]!) -> [IINKGlyphMetrics]! {
    var glyphMetrics = [IINKGlyphMetrics]()
    let attributedString = createAttributedString(text: text, spans: spans)
    let line = CTLineCreateWithAttributedString(attributedString)
    let cfLineRuns = CTLineGetGlyphRuns(line)
    guard let lineRuns = cfLineRuns as? [CTRun] else {
      return glyphMetrics
    }
    for run in lineRuns {
      if let font = run.font {
        let glyphsCount = CTRunGetGlyphCount(run)
        let glyphs = run.glyphs()
        let boundingRects = run.boundingRects(for: glyphs, in: font)
        let advances = run.advances(for: glyphs, in: font)
        let positions = run.positions()
        // Loop through glyphs to get metrics.
        for i in 0..<glyphsCount {
          let origin = boundingRects[i].origin
          let size = boundingRects[i].size
          let position = positions[i]
          let advance = advances[i]
          let metrics = IINKGlyphMetrics()
          metrics.boundingBox.origin.x = position.x + origin.x
          metrics.boundingBox.origin.y = -origin.y - size.height
          metrics.boundingBox.size.width = size.width
          metrics.boundingBox.size.height = size.height
          metrics.leftSideBearing = -origin.x
          metrics.rightSideBearing = advance.width - (origin.x + size.width)
          glyphMetrics.append(metrics)
        }
      }
    }
    return glyphMetrics
  }

  // Creates an NSAttributedString from IINKText and spans.
  private func createAttributedString(text: IINKText, spans: [IINKTextSpan]) -> NSAttributedString {
    let completeAttributedString = NSMutableAttributedString(string: text.label)
    // Apply styles from each span.
    for span in spans {
      let begin = text.getGlyphUtf16Begin(at: span.beginPosition, error: nil)
      let end = text.getGlyphUtf16End(at: span.endPosition - 1, error: nil)
      let range = NSRange(location: Int(begin), length: Int(end - begin))
      if let font = fontFromStyle(style: span.style, string: text.label) {
        let dict: [NSAttributedString.Key: Any] = [
          .font: font,
          .ligature: NSNumber(value: 0),
        ]
        completeAttributedString.setAttributes(dict, range: range)
      }
    }
    return completeAttributedString
  }

  // Creates a UIFont from an IINKStyle.
  private func fontFromStyle(style: IINKStyle, string: String) -> UIFont? {
    let fontSize = CGFloat(style.fontSize)
    let fontName = style.fontFamily ?? "Helvetica"
    // Map common font families to system fonts.
    if fontName.lowercased() == "helvetica" || fontName.lowercased() == "arial" {
      return UIFont.systemFont(ofSize: fontSize)
    }
    // Try to create the font with the specified name.
    if let font = UIFont(name: fontName, size: fontSize) {
      return font
    }
    // Fallback to system font.
    return UIFont.systemFont(ofSize: fontSize)
  }
}

// Extension to help extract glyph data from CTRun.
extension CTRun {
  var font: CTFont? {
    let attributes = CTRunGetAttributes(self) as Dictionary
    if let fontValue = attributes[kCTFontAttributeName] {
      return (fontValue as! CTFont)
    }
    return nil
  }

  func glyphs() -> [CGGlyph] {
    let count = CTRunGetGlyphCount(self)
    var glyphs = [CGGlyph](repeating: 0, count: count)
    CTRunGetGlyphs(self, CFRange(location: 0, length: count), &glyphs)
    return glyphs
  }

  func boundingRects(for glyphs: [CGGlyph], in font: CTFont) -> [CGRect] {
    let count = glyphs.count
    var rects = [CGRect](repeating: .zero, count: count)
    // Get the overall bounding rect for the run.
    let bounds = CTRunGetImageBounds(self, nil, CFRange(location: 0, length: count))
    // Get positions and advances to calculate individual glyph bounds.
    let positions = self.positions()
    let advances = self.advances(for: glyphs, in: font)
    // Calculate bounding rect for each glyph.
    for i in 0..<count {
      let position = positions[i]
      let advance = advances[i]
      rects[i] = CGRect(
        x: position.x, y: position.y - bounds.height, width: advance.width, height: bounds.height)
    }
    return rects
  }

  func advances(for glyphs: [CGGlyph], in font: CTFont) -> [CGSize] {
    let count = glyphs.count
    var advances = [CGSize](repeating: .zero, count: count)
    CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, count)
    return advances
  }

  func positions() -> [CGPoint] {
    let count = CTRunGetGlyphCount(self)
    var positions = [CGPoint](repeating: .zero, count: count)
    CTRunGetPositions(self, CFRange(location: 0, length: count), &positions)
    return positions
  }
}
