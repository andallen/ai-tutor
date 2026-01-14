import UIKit

// Protocol for PDF background rendering.
// Used by the display chain to draw PDF pages behind ink strokes.
protocol PDFBackgroundRendererProtocol: AnyObject {
    // Draw the PDF pages in the given context.
    func draw(in context: CGContext, rect: CGRect, scale: CGFloat)

    // Return which pages are visible in the given viewport rect (in content coordinates).
    // Returns array of (pageIndex, pageFrame) tuples.
    func visiblePages(in viewportRect: CGRect) -> [(Int, CGRect)]

    // Render a specific page at the given scale.
    // Returns nil if the page cannot be rendered.
    func renderPage(at pageIndex: Int, scale: CGFloat) -> CGImage?
}

// MARK: - IINKEditor Extensions

// Extensions for IINKEditor to provide convenience wrapper methods.
// These match the wrapper methods previously defined for the EditorProtocol.
extension IINKEditor {
    var editorRenderer: IINKRenderer {
        return self.renderer
    }

    var editorConfiguration: IINKConfiguration {
        return self.configuration
    }

    var editorToolController: IINKToolController {
        return self.toolController
    }

    func setEditorViewSize(_ size: CGSize) throws {
        try self.set(viewSize: size)
    }

    func clampEditorViewOffset(_ offset: inout CGPoint) {
        self.clampViewOffset(&offset)
    }

    func setEditorPart(_ part: IINKContentPart?) throws {
        try self.set(part: part)
    }

    func setEditorTheme(_ theme: String) throws {
        try self.set(theme: theme)
    }

    func setEditorFontMetricsProvider(_ provider: IINKIFontMetricsProvider) {
        self.set(fontMetricsProvider: provider)
    }

    func addEditorDelegate(_ delegate: IINKEditorDelegate) {
        self.addDelegate(delegate)
    }

    func performClear() throws {
        try self.clear()
    }

    func performUndo() {
        self.undo()
    }

    func performRedo() {
        self.redo()
    }
}

// MARK: - IINKToolController Extensions

// Extensions for IINKToolController to provide convenience wrapper methods.
extension IINKToolController {
    func setToolForPointerType(tool: IINKPointerTool, pointerType: IINKPointerType) throws {
        try self.set(tool: tool, forType: pointerType)
    }

    func setStyleForTool(style: String, tool: IINKPointerTool) throws {
        try self.set(style: style, forTool: tool)
    }

    func styleForTool(tool: IINKPointerTool) throws -> String {
        return try self.style(forTool: tool)
    }
}

// MARK: - IINKConfiguration Extensions

// Extensions for IINKConfiguration to provide convenience wrapper methods.
extension IINKConfiguration {
    func setConfigNumber(_ value: Double, forKey key: String) throws {
        try self.set(number: value, forKey: key)
    }

    func setConfigBoolean(_ value: Bool, forKey key: String) throws {
        try self.set(boolean: value, forKey: key)
    }

    func setConfigString(_ value: String, forKey key: String) throws {
        try self.set(string: value, forKey: key)
    }

    func setConfigStringArray(_ value: [String], forKey key: String) throws {
        try self.set(stringArray: value, forKey: key)
    }
}

// MARK: - IINKRenderer Extensions

// Extensions for IINKRenderer to provide convenience wrapper methods.
extension IINKRenderer {
    func performZoom(at point: CGPoint, by factor: Float) throws {
        try self.zoom(at: point, factor: factor)
    }
}
