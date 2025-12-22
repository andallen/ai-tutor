import UIKit
import CoreGraphics
import CoreText

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

    // Convert MyScript RGBA color (0xRRGGBBAA) to CGColor.
    private func cgColor(from rgba: UInt32) -> CGColor {
        let r = CGFloat((rgba >> 24) & 0xFF) / 255.0
        let g = CGFloat((rgba >> 16) & 0xFF) / 255.0
        let b = CGFloat((rgba >> 8) & 0xFF) / 255.0
        let a = CGFloat(rgba & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }

    // Apply the current dash pattern and offset to the context.
    private func applyDash() {
        guard let context else { return }
        context.setLineDash(phase: strokeDashOffset, lengths: strokeDashPattern)
    }

    // Update the Core Graphics text matrix so CoreText draws in UIKit coordinates.
    private func applyTextMatrix() {
        guard let context else { return }
        context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
    }

    // MARK: - Optional draw lifecycle

    // Begin a drawing pass in the given rect.
    func startDraw(in rect: CGRect) {
        guard let context else { return }

        if clearAtStartDraw {
            context.clear(rect)
        }

        applyTextMatrix()
    }

    // End a drawing pass.
    func endDraw() {
        // Keep context ownership outside so the caller can manage UIGraphics stack.
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
        style.strokeColor = color
        context?.setStrokeColor(cgColor(from: color))
    }

    func setStrokeWidth(_ width: Float) {
        style.strokeWidth = width
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
        self.style.fontWeight = weight

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
            .foregroundColor: UIColor(cgColor: cgColor(from: self.style.fillColor))
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
        let fillAlpha = CGFloat(style.fillColor & 0xFF) / 255.0
        if fillAlpha > 0 {
            context.addPath(p.cgPath)
            context.setFillColor(cgColor(from: style.fillColor))
            context.fillPath(using: cgFillRule)
        }

        // Stroke when stroke alpha is non-zero.
        let strokeAlpha = CGFloat(style.strokeColor & 0xFF) / 255.0
        if strokeAlpha > 0 {
            context.addPath(p.cgPath)
            context.setStrokeColor(cgColor(from: style.strokeColor))
            context.strokePath()
        }
    }

    func drawRectangle(_ rect: CGRect) {
        guard let context else { return }

        let fillAlpha = CGFloat(style.fillColor & 0xFF) / 255.0
        if fillAlpha > 0 {
            context.addRect(rect)
            context.setFillColor(cgColor(from: style.fillColor))
            context.fillPath(using: cgFillRule)
        }

        let strokeAlpha = CGFloat(style.strokeColor & 0xFF) / 255.0
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
        guard let context else { return }
        guard let surfaces = offscreenRenderSurfaces else { return }
        guard let layer = surfaces.getSurface(surfaceId) else { return }

        context.saveGState()
        context.clip(to: dest)

        let alpha = CGFloat(color & 0xFF) / 255.0
        if alpha < 1.0 {
            context.setAlpha(alpha)
        }

        let scaleX = dest.width / src.width
        let scaleY = dest.height / src.height

        var t = CGAffineTransform.identity
        t = t.translatedBy(x: dest.origin.x - src.origin.x * scaleX, y: dest.origin.y - src.origin.y * scaleY)
        t = t.scaledBy(x: scaleX, y: scaleY)

        context.concatenate(t)
        context.draw(layer, in: src)
        context.restoreGState()
    }
}