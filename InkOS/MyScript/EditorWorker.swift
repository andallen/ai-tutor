import Combine
import Foundation

@MainActor
final class EditorWorker: NSObject, ObservableObject {
  @Published private(set) var editor: IINKEditor?
  private var documentHandle: DocumentHandle?
  private var pendingPart: IINKContentPart?
  private var pendingViewSize: CGSize?
  private var toolController: IINKToolController?

  func attach(engine: IINKEngine, renderer: IINKRenderer) {
    appLog("🧭 EditorWorker.attach start")
    // Create a tool controller for the editor.
    let tc = engine.createToolController()
    toolController = tc
    appLog("🧭 EditorWorker.attach toolController ready=\(tc != nil)")

    // Create the editor with the tool controller.
    // The tool controller must be passed at creation time.
    guard let e = engine.createEditor(renderer: renderer, toolController: tc) else {
      appLog("❌ EditorWorker: Failed to create editor")
      return
    }
    appLog("🧭 EditorWorker.attach editor created")

    // Assign the delegate immediately.
    e.delegate = self

    // Apply theme using the editor's theme API (not configuration.set).
    do {
      try e.set(theme: ".ink { color: #000000; -myscript-pen-width: 1.5; }")
    } catch {
      appLog("❌ EditorWorker: Failed to set theme: \(error)")
    }

    // Map pointer types to tools using the editor's tool controller.
    // By default, TOUCH → HAND (pan/interaction) and PEN → PEN (ink).
    // Disable "active pen mode" behavior: let finger draw ink.
    do {
      try e.toolController.set(tool: IINKPointerTool.toolPen, forType: IINKPointerType.touch)
      // Keep stylus drawing ink too.
      try e.toolController.set(tool: IINKPointerTool.toolPen, forType: IINKPointerType.pen)
    } catch {
      appLog("❌ EditorWorker: Failed to map tools: \(error)")
    }

    // Set tool style through the editor's tool controller (not configuration).
    // This ensures the pen tool has an explicit opaque color.
    do {
      try e.toolController.set(
        style: "color: #000000; -myscript-pen-width: 1.5", forTool: IINKPointerTool.toolPen)
    } catch {
      appLog("❌ EditorWorker: Failed to set tool style: \(error)")
    }

    // Set font metrics provider.
    e.set(fontMetricsProvider: FontMetricsProvider())
    appLog("🧭 EditorWorker.attach fontMetricsProvider set")

    // Apply pending view size if it was set before the editor was ready.
    // The SDK requires viewSize to be set before attaching a part.
    if let size = pendingViewSize, size.width > 0 && size.height > 0 {
      appLog("🧭 EditorWorker.attach applying pending viewSize=\(size)")
      do {
        try e.set(viewSize: size)
        // Defer clearing pendingViewSize to avoid publishing during view updates.
        DispatchQueue.main.async { [weak self] in
          self?.pendingViewSize = nil
        }
      } catch {
        appLog("❌ EditorWorker: Failed to set pending view size: \(error)")
      }
    }

    // If a part was loaded before the editor was ready, apply it now.
    // But only if view size has been set (either just now or previously).
    if let part = pendingPart {
      // Verify view size is set before attaching part.
      // If not set yet, keep part pending until view size is available.
      if e.viewSize.width > 0 && e.viewSize.height > 0 {
        appLog("🧭 EditorWorker.attach applying pending part")
        e.part = part
        DispatchQueue.main.async { [weak self] in
          self?.pendingPart = nil
        }
      }
    }

    // Defer @Published assignment to avoid "publishing during view update" warnings.
    // This ensures the assignment happens after the current view update cycle completes.
    DispatchQueue.main.async { [weak self] in
      self?.editor = e
      appLog("🧭 EditorWorker.attach published editor")
    }
  }

  // Set the view size. Must be called before attaching a part.
  func setViewSize(_ size: CGSize) {
    appLog("🧭 EditorWorker.setViewSize size=\(size) editorReady=\(editor != nil)")
    if let e = editor {
      // Editor exists, set size immediately.
      do {
        try e.set(viewSize: size)
        // If we have a pending part and view size is now valid, apply it.
        if let part = pendingPart, size.width > 0 && size.height > 0 {
          appLog("🧭 EditorWorker.setViewSize applying pending part")
          e.part = part
          DispatchQueue.main.async { [weak self] in
            self?.pendingPart = nil
          }
        }
      } catch {
        appLog("❌ EditorWorker: Failed to set view size: \(error)")
      }
    } else {
      // Editor doesn't exist yet, store size for later.
      if size.width > 0 && size.height > 0 {
        appLog("🧭 EditorWorker.setViewSize stored pending size")
        pendingViewSize = size
      }
    }
  }

  func loadPart(from handle: DocumentHandle) async {
    appLog("🧭 EditorWorker.loadPart start")
    self.documentHandle = handle
    guard let part = await handle.getPart(at: 0) else { return }

    // Set the part synchronously if editor exists, otherwise store it for later.
    // This prevents the race where loadPart is called before attach completes.
    await MainActor.run {
      if let e = editor {
        appLog("🧭 EditorWorker.loadPart attaching to editor")
        e.part = part
      } else {
        appLog("🧭 EditorWorker.loadPart storing pending part")
        pendingPart = part
      }
    }
  }

  func clear() {
    appLog("🧭 EditorWorker.clear")
    try? self.editor?.clear()
  }

  func close() {
    appLog("🧭 EditorWorker.close")
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
    appLog("❌ MyScript Editor Error [BlockId: \(blockId)]: \(message)")
  }

  func partChanged(_ editor: IINKEditor) {
    // Called when the part changes.
    // This is a required protocol method.
    appLog("🧭 EditorWorker.partChanged")
  }

  func contentChanged(_ editor: IINKEditor, blockIds: [String]) {
    // If this prints, it means the engine successfully processed your strokes into the model.
    appLog("📈 EditorWorker: Content changed. Blocks updated: \(blockIds)")
  }
}
