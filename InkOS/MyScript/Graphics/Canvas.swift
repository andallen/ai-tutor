import CoreGraphics
import CoreText
import UIKit

// Canvas bridges MyScript drawing calls to Core Graphics.
@objcMembers
final class Canvas: NSObject, IINKICanvas {

  // Store the current Core Graphics context used for rendering.
  var context: CGContext?

  // Store the current view size in pixels.
  var size: CGSize = .zero

  // Clear the drawing rect at the start of each draw pass when enabled.
  var clearAtStartDraw: Bool = true

  // Hold offscreen tile buffers used by the renderer for caching.
  var offscreenRenderSurfaces: OffscreenRenderSurfaces?

  // Store the current transform so delta transforms can be applied correctly.
  private var transform: CGAffineTransform = .identity

  // Store the current drawing style pushed by the renderer.
  private var style: IINKStyle = IINKStyle()

  // Track nested clipped groups to restore clip behavior correctly.
  private var clippedGroupIdentifier: [String] = []

  // Store the fill rule used for filling paths.
  private var cgFillRule: CGPathFillRule = .winding

  // Store the current font attributes for drawText calls.
  private var fontAttributes: [NSAttributedString.Key: Any] = [:]

  // Store stroke dash settings so dash offset changes can be applied separately.
  private var strokeDashPattern: [CGFloat] = []
  private var strokeDashOffset: CGFloat = 0

  var debugLayer: String?
  private var loggedModelStroke = false
  private var loggedModelStyle = false
  private var loggedModelNonZeroStyle = false
  private var loggedModelBlend = false
  private var loggedCaptureStyle = false
  private var loggedCaptureNonZeroStyle = false
  private var loggedForcedOpaque = false

  // MyScript iOS reference implementation treats packed colors as RGBA (0xRRGGBBAA).
  // `blendOffscreen(..., color:)` alpha is documented/implemented as `color & 0xFF`.
  private func cgColor(from rgba: UInt32) -> CGColor {
    let r = CGFloat((rgba >> 24) & 0xFF) / 255.0
    let g = CGFloat((rgba >> 16) & 0xFF) / 255.0
    let b = CGFloat((rgba >> 8) & 0xFF) / 255.0
    let a = CGFloat(rgba & 0xFF) / 255.0
    return CGColor(red: r, green: g, blue: b, alpha: a)
  }

  private func alpha(from rgba: UInt32) -> CGFloat {
    CGFloat(rgba & 0xFF) / 255.0
  }

  // Apply the current dash pattern and offset to the context.
  private func applyDash() {
    guard let context else { return }
    context.setLineDash(phase: strokeDashOffset, lengths: strokeDashPattern)
  }

  // Update the Core Graphics text matrix so CoreText draws in UIKit coordinates.
  private func applyTextMatrix() {
    guard let context else { return }
    let matrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
    context.textMatrix = matrix
  }

  // MARK: - Optional draw lifecycle

  // Begin a drawing pass in the given rect.
  func startDraw(in rect: CGRect) {
    guard let context else { return }

    // Start a fresh draw session like the reference implementation:
    // - save/restore gstate per session
    // - reset our transform tracking
    // - enforce style defaults so the renderer isn't depending on stale CG state
    context.saveGState()
    transform = .identity
    style.setAllChangeFlags()
    style.apply(to: self)
    style.clearChangeFlags()
    loggedModelStroke = false
    loggedModelStyle = false
    loggedModelNonZeroStyle = false
    loggedModelBlend = false
    // Clip to the session rect (this is what the MyScript ref impl does).
    context.clip(to: rect)

    if clearAtStartDraw {
      context.clear(rect)
    }

    applyTextMatrix()
  }

  // End a drawing pass.
  func endDraw() {
    // Matches startDraw's saveGState() to prevent clip/CTM leaking across draw sessions.
    context?.restoreGState()
    loggedModelStroke = false
    loggedModelStyle = false
    loggedModelNonZeroStyle = false
    loggedModelBlend = false
  }

  // MARK: - Required protocol methods

  func getTransform() -> CGAffineTransform {
    transform
  }

  func setTransform(_ newTransform: CGAffineTransform) {
    guard let context else { return }

    // Apply a delta transform so transforms do not compound.
    let invOld = transform.inverted()
    let delta = newTransform.concatenating(invOld)
    transform = newTransform
    context.concatenate(delta)
  }

  func setStrokeColor(_ color: UInt32) {
    var resolvedColor = color
    if color == 0, debugLayer == "model" || debugLayer == "capture" {
      resolvedColor = 0x0000_00FF
      if !loggedForcedOpaque {
        loggedForcedOpaque = true
        let layerName = debugLayer ?? "unknown"
        appLog("⚠️ Canvas.setStrokeColor forced opaque color=0x000000FF for layer=\(layerName)")
      }
    }
    style.strokeColor = resolvedColor
    if debugLayer == "model" {
      let alpha = self.alpha(from: resolvedColor)
      if resolvedColor != 0, !loggedModelNonZeroStyle {
        loggedModelNonZeroStyle = true
        appLog(
          "🧭 Canvas.setStrokeColor model nonzero color=0x\(String(format: "%08X", resolvedColor)) alpha=\(alpha)"
        )
      } else if !loggedModelStyle {
        loggedModelStyle = true
        appLog(
          "🧭 Canvas.setStrokeColor model color=0x\(String(format: "%08X", resolvedColor)) alpha=\(alpha)"
        )
      }
    } else if debugLayer == "capture" {
      let alpha = self.alpha(from: resolvedColor)
      if resolvedColor != 0, !loggedCaptureNonZeroStyle {
        loggedCaptureNonZeroStyle = true
        appLog(
          "🧭 Canvas.setStrokeColor capture nonzero color=0x\(String(format: "%08X", resolvedColor)) alpha=\(alpha)"
        )
      } else if !loggedCaptureStyle {
        loggedCaptureStyle = true
        appLog(
          "🧭 Canvas.setStrokeColor capture color=0x\(String(format: "%08X", resolvedColor)) alpha=\(alpha)"
        )
      }
    }
    context?.setStrokeColor(cgColor(from: resolvedColor))
  }

  func setStrokeWidth(_ width: Float) {
    style.strokeWidth = width
    if debugLayer == "model", !loggedModelStyle {
      loggedModelStyle = true
      appLog("🧭 Canvas.setStrokeWidth model width=\(width)")
    }
    context?.setLineWidth(CGFloat(width))
  }

  func setStroke(_ lineCap: IINKLineCap) {
    style.strokeLineCap = lineCap
    switch lineCap {
    case .butt:
      context?.setLineCap(.butt)
    case .round:
      context?.setLineCap(.round)
    case .square:
      context?.setLineCap(.square)
    @unknown default:
      context?.setLineCap(.butt)
    }
  }

  func setStroke(_ lineJoin: IINKLineJoin) {
    style.strokeLineJoin = lineJoin
    switch lineJoin {
    case .miter:
      context?.setLineJoin(.miter)
    case .round:
      context?.setLineJoin(.round)
    case .bevel:
      context?.setLineJoin(.bevel)
    @unknown default:
      context?.setLineJoin(.miter)
    }
  }

  func setStrokeMiterLimit(_ limit: Float) {
    context?.setMiterLimit(CGFloat(limit))
  }

  func setStrokeDashArray(_ array: UnsafePointer<Float>?, size: Int) {
    strokeDashPattern.removeAll(keepingCapacity: true)

    if let array, size > 0 {
      strokeDashPattern = (0..<size).map { CGFloat(array[$0]) }
    }

    applyDash()
  }

  func setStrokeDashOffset(_ offset: Float) {
    strokeDashOffset = CGFloat(offset)
    applyDash()
  }

  func setFillColor(_ color: UInt32) {
    style.fillColor = color
    context?.setFillColor(cgColor(from: color))
  }

  func setFillRule(_ rule: IINKFillRule) {
    style.fillRule = rule

    switch rule {
    case .evenOdd:
      cgFillRule = .evenOdd
    case .nonZero:
      cgFillRule = .winding
    @unknown default:
      cgFillRule = .winding
    }
  }

  func setDropShadow(_ xOffset: Float, yOffset: Float, radius: Float, color: UInt32) {
    let offset = CGSize(width: CGFloat(xOffset), height: CGFloat(yOffset))
    context?.setShadow(offset: offset, blur: CGFloat(radius), color: cgColor(from: color))
  }

  func setFontProperties(
    _ family: String,
    height lineHeight: Float,
    size fontSize: Float,
    style fontStyle: String,
    variant: String,
    weight: Int32
  ) {
    self.style.fontFamily = family
    self.style.fontLineHeight = lineHeight
    self.style.fontSize = fontSize
    self.style.fontStyle = fontStyle
    self.style.fontVariant = variant
    self.style.fontWeight = Int(weight)

    // Build a font that is as close as possible using UIKit.
    var font: UIFont
    if !family.isEmpty, let named = UIFont(name: family, size: CGFloat(fontSize)) {
      font = named
    } else {
      let w: UIFont.Weight
      if weight >= 700 {
        w = .bold
      } else if weight >= 600 {
        w = .semibold
      } else if weight >= 500 {
        w = .medium
      } else {
        w = .regular
      }
      font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: w)
    }

    // Add italic trait when requested.
    if fontStyle.lowercased().contains("italic") {
      if let d = font.fontDescriptor.withSymbolicTraits([.traitItalic]) {
        font = UIFont(descriptor: d, size: font.pointSize)
      }
    }

    fontAttributes = [
      .font: font,
      .foregroundColor: UIColor(cgColor: cgColor(from: self.style.fillColor)),
    ]
  }

  func startGroup(_ identifier: String, region: CGRect, clip clipContent: Bool) {
    guard let context else { return }

    context.saveGState()

    if clipContent {
      context.clip(to: region)
      clippedGroupIdentifier.append(identifier)
    }
  }

  func endGroup(_ identifier: String) {
    guard let context else { return }

    context.restoreGState()

    if clippedGroupIdentifier.last == identifier {
      clippedGroupIdentifier.removeLast()
    }

    applyTextMatrix()
    applyDash()
  }

  func startItem(_ identifier: String) {
    // Keep as a no-op unless item-level state is needed.
  }

  func endItem(_ identifier: String) {
    // Keep as a no-op unless item-level state is needed.
  }

  func createPath() -> any IINKIPath {
    Path()
  }

  func draw(_ path: any IINKIPath) {
    guard let context else { return }
    guard let p = path as? Path else { return }

    // Fill when fill alpha is non-zero.
    let fillAlpha = alpha(from: style.fillColor)
    if fillAlpha > 0 {
      context.addPath(p.bezierPath.cgPath)
      context.setFillColor(cgColor(from: style.fillColor))
      context.fillPath(using: cgFillRule)
    }

    // Stroke when stroke alpha is non-zero.
    let strokeAlpha = alpha(from: style.strokeColor)
    if debugLayer == "model", !loggedModelStroke {
      loggedModelStroke = true
      appLog(
        "🧭 Canvas.modelStroke color=0x\(String(format: "%08X", style.strokeColor)) alpha=\(strokeAlpha) width=\(style.strokeWidth)"
      )
    }
    if strokeAlpha > 0 {
      context.addPath(p.bezierPath.cgPath)
      context.setStrokeColor(cgColor(from: style.strokeColor))
      context.strokePath()
    }
  }

  func drawRectangle(_ rect: CGRect) {
    guard let context else { return }

    let fillAlpha = alpha(from: style.fillColor)
    if fillAlpha > 0 {
      context.addRect(rect)
      context.setFillColor(cgColor(from: style.fillColor))
      context.fillPath(using: cgFillRule)
    }

    let strokeAlpha = alpha(from: style.strokeColor)
    if strokeAlpha > 0 {
      context.addRect(rect)
      context.setStrokeColor(cgColor(from: style.strokeColor))
      context.strokePath()
    }
  }

  func drawLine(_ from: CGPoint, to: CGPoint) {
    guard let context else { return }

    context.beginPath()
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
  }

  func drawObject(_ url: String, mimeType: String, region rect: CGRect) {
    guard let context else { return }

    // Load images only from file URLs or absolute file paths.
    let image: UIImage?
    if let u = URL(string: url), u.isFileURL {
      image = UIImage(contentsOfFile: u.path)
    } else {
      image = UIImage(contentsOfFile: url)
    }

    guard let cgImage = image?.cgImage else { return }
    context.draw(cgImage, in: rect)
  }

  func drawText(_ label: String, anchor origin: CGPoint, region rect: CGRect) {
    guard let context else { return }

    // Draw text using CoreText so anchor points match the renderer’s coordinates.
    let attributed = NSAttributedString(string: label, attributes: fontAttributes)
    let line = CTLineCreateWithAttributedString(attributed)

    context.saveGState()
    applyTextMatrix()
    context.textPosition = origin
    CTLineDraw(line, context)
    context.restoreGState()
  }

  // MARK: - Optional protocol method

  func blendOffscreen(_ surfaceId: UInt32, src: CGRect, dest: CGRect, color: UInt32) {
    guard let context else {
      appLog("❌ Canvas.blendOffscreen: No context")
      return
    }
    guard let surfaces = offscreenRenderSurfaces else {
      appLog("❌ Canvas.blendOffscreen: No offscreen surfaces")
      return
    }
    guard let layer = surfaces.getSurface(surfaceId) else {
      appLog("❌ Canvas.blendOffscreen: No surface for id=\(surfaceId)")
      return
    }

    // Keep blend logging minimal; only emit diagnostics when alpha/clipping look suspicious.
    let destInBounds =
      dest.minX >= 0 && dest.minY >= 0 && dest.maxX <= size.width && dest.maxY <= size.height

    context.saveGState()
    // Clip in main canvas coordinate space where dest is defined
    // Save current CTM, reset to identity, clip, then restore CTM
    let savedCTM = context.ctm
    context.concatenate(savedCTM.inverted())  // Reset to identity
    context.clip(to: dest)  // Clip in main canvas space (dest is in pixel coordinates)
    context.concatenate(savedCTM)  // Restore original CTM
    let alpha = CGFloat(color & 0xFF) / 255.0
    if debugLayer == "model", !loggedModelBlend, alpha < 1.0 || color != 0xFFFF_FFFF {
      loggedModelBlend = true
      appLog(
        "🧭 Canvas.blendOffscreen model surfaceId=\(surfaceId) color=0x\(String(format: "%08X", color)) alpha=\(alpha) src=\(src) dest=\(dest)"
      )
    }
    if alpha < 1.0 {
      context.setAlpha(alpha)
    }

    let scaleX = dest.width / src.width
    let scaleY = dest.height / src.height

    var t = CGAffineTransform.identity
    t = t.translatedBy(
      x: dest.origin.x - src.origin.x * scaleX, y: dest.origin.y - src.origin.y * scaleY)
    t = t.scaledBy(x: scaleX, y: scaleY)

    context.concatenate(t)

    context.draw(layer, in: src)
    context.restoreGState()
    if !destInBounds {
      appLog(
        "⚠️ Canvas.blendOffscreen: dest out of bounds. surfaceId=\(surfaceId) dest=\(dest) canvas.size=\(size)"
      )
    }
  }

}
