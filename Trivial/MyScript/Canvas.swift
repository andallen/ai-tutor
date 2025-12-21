import UIKit
import CoreGraphics

// Canvas implementation that bridges Core Graphics to MyScript's IINKICanvas protocol.
// This is a simplified version based on the MyScript reference implementation.
@objcMembers
class Canvas: NSObject, IINKICanvas {
    var context: CGContext?
    var size: CGSize = .zero
    var clearAtStartDraw: Bool = true
    var offscreenRenderSurfaces: OffscreenRenderSurfaces?
    
    private var transform: CGAffineTransform = .identity
    private var style: IINKStyle = IINKStyle()
    
    // MARK: - IINKICanvas Required Methods
    
    func getTransform() -> CGAffineTransform {
        return transform
    }
    
    func setTransform(_ transform: CGAffineTransform) {
        guard let context = self.context else { return }
        // Concatenation ensures internal engine coordinates map to the UI coordinates.
        self.transform = transform
        context.concatenate(transform)
    }
    
    func setStrokeColor(_ color: UInt32) {
        style.strokeColor = color
        // Add this log to see the raw hex value the engine is sending.
        print("🎨 Canvas: setStrokeColor called with hex: \(String(format: "0x%08X", color))")
        
        // Correct bit shifting for 0xRRGGBBAA format (MyScript uses RGBA, not ARGB).
        let r = CGFloat((color >> 24) & 0xFF) / 255.0
        let g = CGFloat((color >> 16) & 0xFF) / 255.0
        let b = CGFloat((color >> 8) & 0xFF) / 255.0
        let a = CGFloat(color & 0xFF) / 255.0
        context?.setStrokeColor(red: r, green: g, blue: b, alpha: a)
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
            break
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
            break
        }
    }
    
    func setStrokeMiterLimit(_ limit: Float) {
        style.strokeMiterLimit = limit
        context?.setMiterLimit(CGFloat(limit))
    }
    
    func setStrokeDashArray(_ array: UnsafePointer<Float>?, size: Int) {
        if let array = array {
            let buffer = UnsafeBufferPointer(start: array, count: size)
            let dashes = buffer.map { CGFloat($0) }
            context?.setLineDash(phase: 0, lengths: dashes)
        } else {
            context?.setLineDash(phase: 0, lengths: [])
        }
    }
    
    func setStrokeDashOffset(_ offset: Float) {
        style.strokeDashOffset = offset
        // Dash offset is handled in setStrokeDashArray
    }
    
    func setFillColor(_ color: UInt32) {
        style.fillColor = color
        // Correct bit shifting for 0xRRGGBBAA format (MyScript uses RGBA, not ARGB).
        let r = CGFloat((color >> 24) & 0xFF) / 255.0
        let g = CGFloat((color >> 16) & 0xFF) / 255.0
        let b = CGFloat((color >> 8) & 0xFF) / 255.0
        let a = CGFloat(color & 0xFF) / 255.0
        context?.setFillColor(red: r, green: g, blue: b, alpha: a)
    }
    
    func setFillRule(_ rule: IINKFillRule) {
        style.fillRule = rule
    }
    
    func setDropShadow(_ xOffset: Float, yOffset: Float, radius: Float, color: UInt32) {
        if color != 0 {
            // Correct bit shifting for 0xRRGGBBAA format (MyScript uses RGBA, not ARGB).
            let r = CGFloat((color >> 24) & 0xFF) / 255.0
            let g = CGFloat((color >> 16) & 0xFF) / 255.0
            let b = CGFloat((color >> 8) & 0xFF) / 255.0
            let a = CGFloat(color & 0xFF) / 255.0
            let offset = CGSize(width: CGFloat(xOffset), height: CGFloat(yOffset))
            context?.setShadow(offset: offset, blur: CGFloat(radius), color: UIColor(red: r, green: g, blue: b, alpha: a).cgColor)
        }
    }
    
    func setFontProperties(_ family: String, height lineHeight: Float, size: Float, style fontStyle: String, variant: String, weight: Int32) {
        self.style.fontFamily = family
        self.style.fontLineHeight = lineHeight
        self.style.fontSize = size
        self.style.fontVariant = variant
        self.style.fontWeight = Int(weight)
        self.style.fontStyle = fontStyle
    }
    
    func startGroup(_ identifier: String, region: CGRect, clip clipContent: Bool) {
        if clipContent {
            context?.saveGState()
            context?.clip(to: region)
        }
    }
    
    func endGroup(_ identifier: String) {
        context?.restoreGState()
    }
    
    func startItem(_ identifier: String) {
        // No-op for basic implementation
    }
    
    func endItem(_ identifier: String) {
        // No-op for basic implementation
    }
    
    func createPath() -> IINKIPath {
        return Path()
    }
    
    func draw(_ path: IINKIPath) {
        guard let path = path as? Path else {
            print("⚠️ Canvas: Draw failed - path cast failed")
            return
        }
        guard let context = self.context else {
            print("⚠️ Canvas: Draw failed - context is NIL")
            return
        }
        
        // Add this log to see if the engine is actually triggering a draw command.
        print("✒️ Canvas: draw(path) called. Bounds: \(path.bezierPath.bounds)")
        
        context.saveGState()
        
        // Configure stroke properties from the MyScript style object.
        // Check the Alpha channel (low byte) for RGBA format.
        if (style.strokeColor & 0xFF) > 0 {
            let strokeColor = style.strokeColor
            // Correct bit shifting for 0xRRGGBBAA format (MyScript uses RGBA, not ARGB).
            let r = CGFloat((strokeColor >> 24) & 0xFF) / 255.0
            let g = CGFloat((strokeColor >> 16) & 0xFF) / 255.0
            let b = CGFloat((strokeColor >> 8) & 0xFF) / 255.0
            let a = CGFloat(strokeColor & 0xFF) / 255.0
            context.setStrokeColor(red: r, green: g, blue: b, alpha: a)
            context.setLineWidth(CGFloat(style.strokeWidth))
            
            // Set line cap.
            switch style.strokeLineCap {
            case .butt:
                context.setLineCap(.butt)
            case .round:
                context.setLineCap(.round)
            case .square:
                context.setLineCap(.square)
            @unknown default:
                context.setLineCap(.round)
            }
            
            // Set line join.
            switch style.strokeLineJoin {
            case .miter:
                context.setLineJoin(.miter)
            case .round:
                context.setLineJoin(.round)
            case .bevel:
                context.setLineJoin(.bevel)
            @unknown default:
                context.setLineJoin(.round)
            }
        }
        
        // Add and draw the path.
        context.addPath(path.bezierPath.cgPath)
        
        // Fill if fill color has alpha.
        // Check the Alpha channel (low byte) for RGBA format.
        if (style.fillColor & 0xFF) > 0 {
            let fillColor = style.fillColor
            // Correct bit shifting for 0xRRGGBBAA format (MyScript uses RGBA, not ARGB).
            let r = CGFloat((fillColor >> 24) & 0xFF) / 255.0
            let g = CGFloat((fillColor >> 16) & 0xFF) / 255.0
            let b = CGFloat((fillColor >> 8) & 0xFF) / 255.0
            let a = CGFloat(fillColor & 0xFF) / 255.0
            context.setFillColor(red: r, green: g, blue: b, alpha: a)
            let fillRule: CGPathFillRule = style.fillRule == .evenOdd ? .evenOdd : .winding
            context.fillPath(using: fillRule)
            // Re-add path for stroke if needed, since fillPath consumes the path.
            if (style.strokeColor & 0xFF) > 0 {
                context.addPath(path.bezierPath.cgPath)
            }
        }
        
        // Stroke if stroke color has alpha.
        // Check the Alpha channel (low byte) for RGBA format.
        if (style.strokeColor & 0xFF) > 0 {
            context.strokePath()
        } else {
            print("🛑 Canvas: strokePath skipped! Alpha channel (0x\(String(format: "%02X", style.strokeColor & 0xFF))) is 0.")
        }
        
        context.restoreGState()
    }
    
    func drawRectangle(_ rect: CGRect) {
        if (style.fillColor & 0xFF) > 0 {
            context?.fill(rect)
        }
        if (style.strokeColor & 0xFF) > 0 {
            context?.stroke(rect)
        }
    }
    
    func drawLine(_ from: CGPoint, to: CGPoint) {
        context?.move(to: from)
        context?.addLine(to: to)
        context?.strokePath()
    }
    
    func drawObject(_ url: String, mimeType: String, region rect: CGRect) {
        // Basic implementation - can be extended to load and draw images
    }
    
    func drawText(_ label: String, anchor origin: CGPoint, region rect: CGRect) {
        // Basic text drawing implementation
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: CGFloat(style.fontSize)),
            .foregroundColor: UIColor.black
        ]
        let attributedString = NSAttributedString(string: label, attributes: attributes)
        attributedString.draw(at: origin)
    }
    
    // MARK: - Optional IINKICanvas Methods
    
    func startDraw(in rect: CGRect) {
        if context == nil {
            context = UIGraphicsGetCurrentContext()
        }
        transform = .identity
        context?.saveGState()
        style.setAllChangeFlags()
        style.apply(to: self)
        style.clearChangeFlags()
        
        // Text transform for CoreText
        var textTransform = CGAffineTransform(scaleX: 1, y: -1)
        textTransform = textTransform.translatedBy(x: 0, y: -size.height)
        context?.textMatrix = textTransform
        context?.clip(to: rect)
        
        if clearAtStartDraw {
            context?.clear(rect)
        }
    }
    
    func endDraw() {
        context?.restoreGState()
    }
    
    // MARK: - Offscreen Blending
    
    // Blend an offscreen surface back into the main context.
    // This is called by the MyScript renderer when compositing cached tiles.
    @objc func blendOffscreen(_ surfaceId: UInt32, src: CGRect, dest: CGRect, color: UInt32) {
        guard let context = self.context else { return }
        guard let surfaces = offscreenRenderSurfaces else { return }
        guard let layer = surfaces.getSurface(surfaceId) else { return }
        
        // Save graphics state.
        context.saveGState()
        
        // Clip to destination rectangle.
        context.clip(to: dest)
        
        // Extract alpha from color (RRGGBBAA format, alpha in low byte).
        let alpha = CGFloat(color & 0xFF) / 255.0
        
        // Apply alpha if not fully opaque.
        if alpha < 1.0 {
            context.setAlpha(alpha)
        }
        
        // Calculate the scale factor between source and destination.
        let scaleX = dest.width / src.width
        let scaleY = dest.height / src.height
        
        // Create transform to map from source rect in layer to dest rect in context.
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: dest.origin.x - src.origin.x * scaleX, y: dest.origin.y - src.origin.y * scaleY)
        transform = transform.scaledBy(x: scaleX, y: scaleY)
        
        // Apply transform and draw the layer.
        context.concatenate(transform)
        context.draw(layer, in: src)
        
        // Restore graphics state.
        context.restoreGState()
    }
}

