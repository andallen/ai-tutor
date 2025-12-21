import Foundation
import Combine

@MainActor
final class EditorWorker: NSObject, ObservableObject {
    @Published private(set) var editor: IINKEditor?
    private var documentHandle: DocumentHandle?
    private var pendingPart: IINKContentPart?
    private var pendingViewSize: CGSize?
    private var toolController: IINKToolController?

    func attach(engine: IINKEngine, renderer: IINKRenderer) {
        // Create a tool controller for the editor.
        let tc = engine.createToolController()
        toolController = tc
        
        // Create the editor with the tool controller.
        // The tool controller must be passed at creation time.
        guard let e = engine.createEditor(renderer: renderer, toolController: tc) else {
            print("❌ EditorWorker: Failed to create editor")
            return
        }
        
        // Assign the delegate immediately.
        e.delegate = self
        
        // Apply theme using the editor's theme API (not configuration.set).
        // Use 8-digit color format (#000000FF) to ensure alpha is included.
        do {
            try e.set(theme: ".ink { color: #000000FF; -myscript-pen-width: 1.5; }")
        } catch {
            print("❌ EditorWorker: Failed to set theme: \(error)")
        }
        
        // Map pointer types to tools using the editor's tool controller.
        // By default, TOUCH → HAND (pan/interaction) and PEN → PEN (ink).
        // Disable "active pen mode" behavior: let finger draw ink.
        do {
            try e.toolController.set(tool: IINKPointerTool.toolPen, forType: IINKPointerType.touch)
            // Keep stylus drawing ink too.
            try e.toolController.set(tool: IINKPointerTool.toolPen, forType: IINKPointerType.pen)
        } catch {
            print("❌ EditorWorker: Failed to map tools: \(error)")
        }
        
        // Set tool style through the editor's tool controller (not configuration).
        // This ensures the pen tool has an explicit opaque color.
        do {
            try e.toolController.set(style: "color: #000000FF; -myscript-pen-width: 1.5", forTool: IINKPointerTool.toolPen)
        } catch {
            print("❌ EditorWorker: Failed to set tool style: \(error)")
        }
        
        // Set font metrics provider.
        e.set(fontMetricsProvider: FontMetricsProvider())
        
        // Assign editor synchronously to avoid race conditions.
        // This ensures loadPart can immediately set the part if it arrives first.
        editor = e
        
        // Apply pending view size if it was set before the editor was ready.
        // The SDK requires viewSize to be set before attaching a part.
        if let size = pendingViewSize, size.width > 0 && size.height > 0 {
            do {
                try e.set(viewSize: size)
                pendingViewSize = nil
            } catch {
                print("❌ EditorWorker: Failed to set pending view size: \(error)")
            }
        }
        
        // If a part was loaded before the editor was ready, apply it now.
        // But only if view size has been set (either just now or previously).
        if let part = pendingPart {
            // Verify view size is set before attaching part.
            // If not set yet, keep part pending until view size is available.
            if e.viewSize.width > 0 && e.viewSize.height > 0 {
                e.part = part
                pendingPart = nil
            }
        }
    }
    
    // Set the view size. Must be called before attaching a part.
    func setViewSize(_ size: CGSize) {
        if let e = editor {
            // Editor exists, set size immediately.
            do {
                try e.set(viewSize: size)
                // If we have a pending part and view size is now valid, apply it.
                if let part = pendingPart, size.width > 0 && size.height > 0 {
                    e.part = part
                    pendingPart = nil
                }
            } catch {
                print("❌ EditorWorker: Failed to set view size: \(error)")
            }
        } else {
            // Editor doesn't exist yet, store size for later.
            if size.width > 0 && size.height > 0 {
                pendingViewSize = size
            }
        }
    }

    func loadPart(from handle: DocumentHandle) async {
        self.documentHandle = handle
        guard let part = await handle.getPart(at: 0) else { return }
        
        // Set the part synchronously if editor exists, otherwise store it for later.
        // This prevents the race where loadPart is called before attach completes.
        await MainActor.run {
            if let e = editor {
                e.part = part
            } else {
                pendingPart = part
            }
        }
    }

    func clear() {
        try? self.editor?.clear()
    }

    func close() {
        // Defer the @Published update to avoid publishing during view updates.
        // This is called from onDisappear which might be during a view update.
        Task { @MainActor in
            self.editor?.part = nil
            self.editor = nil
        }
    }
}

// Extension to conform to IINKEditorDelegate for error handling.
// This captures errors that happen on background threads, such as ink being rejected
// due to coordinate or configuration issues.
extension EditorWorker: IINKEditorDelegate {
    func onError(_ editor: IINKEditor, blockId: String, message: String) {
        // This captures errors that happen on background threads.
        // Critical for finding errors like INK_REJECTED_TOO_SMALL.
        print("❌ MyScript Editor Error [BlockId: \(blockId)]: \(message)")
    }
    
    func partChanged(_ editor: IINKEditor) {
        // Called when the part changes.
        // This is a required protocol method.
    }
    
    func contentChanged(_ editor: IINKEditor, blockIds: [String]) {
        // If this prints, it means the engine successfully processed your strokes into the model.
        print("📈 EditorWorker: Content changed. Blocks updated: \(blockIds)")
    }
}