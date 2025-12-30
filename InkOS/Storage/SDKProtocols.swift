import Foundation
import UIKit

// MARK: - ContentPartProtocol

// Protocol abstracting IINKContentPart for testability.
// Allows dependency injection of mock content parts in tests.
protocol ContentPartProtocol: AnyObject {}

// Makes the real IINKContentPart conform to the protocol.
extension IINKContentPart: ContentPartProtocol {}

// MARK: - ContentPackageProtocol

// Protocol abstracting IINKContentPackage for testability.
// Covers the methods used by DocumentHandle.
protocol ContentPackageProtocol: AnyObject {
  func getPartCount() -> Int
  func getPart(at index: Int) throws -> any ContentPartProtocol
  func createNewPart(with type: String) throws -> any ContentPartProtocol
  func savePackage() throws
  func savePackageToTemp() throws
}

// Makes the real IINKContentPackage conform to the protocol.
// Uses distinct method names to avoid ambiguity with SDK methods.
extension IINKContentPackage: ContentPackageProtocol {
  func getPartCount() -> Int {
    return self.partCount()
  }

  func getPart(at index: Int) throws -> any ContentPartProtocol {
    return try self.part(at: index)
  }

  func createNewPart(with type: String) throws -> any ContentPartProtocol {
    return try self.createPart(with: type)
  }

  func savePackage() throws {
    try self.save()
  }

  func savePackageToTemp() throws {
    try self.saveToTemp()
  }
}

// MARK: - EngineProtocol

// Protocol abstracting IINKEngine for testability.
// Covers the package opening method used by DocumentHandle.
protocol EngineProtocol: AnyObject {
  func openContentPackage(_ path: String, openOption: IINKPackageOpenOption) throws -> any ContentPackageProtocol
}

// Makes the real IINKEngine conform to the protocol.
// Uses a distinct method name to avoid ambiguity with SDK method.
extension IINKEngine: EngineProtocol {
  func openContentPackage(_ path: String, openOption: IINKPackageOpenOption) throws -> any ContentPackageProtocol {
    return try self.openPackage(path, openOption: openOption)
  }
}

// MARK: - EngineProviderProtocol

// Protocol abstracting EngineProvider for testability.
// Allows dependency injection of mock engine providers in tests.
@MainActor
protocol EngineProviderProtocol: AnyObject {
  var engineInstance: (any EngineProtocol)? { get }
}

// Makes the real EngineProvider conform to the protocol.
// Uses a distinct property name to avoid ambiguity.
extension EngineProvider: EngineProviderProtocol {
  var engineInstance: (any EngineProtocol)? {
    return self.engine
  }
}

// MARK: - RendererProtocol

// Protocol abstracting IINKRenderer for testability.
// Covers the properties and methods used by InputViewModel for scrolling and zooming.
protocol RendererProtocol: AnyObject {
  var viewOffset: CGPoint { get set }
  var viewScale: Float { get set }
  func performZoom(at point: CGPoint, by factor: Float) throws
}

// Makes the real IINKRenderer conform to the protocol.
extension IINKRenderer: RendererProtocol {
  func performZoom(at point: CGPoint, by factor: Float) throws {
    try self.zoom(at: point, factor: factor)
  }
}

// MARK: - ConfigurationProtocol

// Protocol abstracting IINKConfiguration for testability.
// Covers the methods used by InputViewModel for margin configuration.
protocol ConfigurationProtocol: AnyObject {
  func setConfigNumber(_ value: Double, forKey key: String) throws
  func setConfigBoolean(_ value: Bool, forKey key: String) throws
}

// Makes the real IINKConfiguration conform to the protocol.
extension IINKConfiguration: ConfigurationProtocol {
  func setConfigNumber(_ value: Double, forKey key: String) throws {
    try self.set(number: value, forKey: key)
  }

  func setConfigBoolean(_ value: Bool, forKey key: String) throws {
    try self.set(boolean: value, forKey: key)
  }
}

// MARK: - ToolControllerProtocol

// Protocol abstracting IINKToolController for testability.
// Covers the methods used by InputViewModel for tool selection.
protocol ToolControllerProtocol: AnyObject {
  func setToolForPointerType(tool: IINKPointerTool, pointerType: IINKPointerType) throws
  func setStyleForTool(style: String, tool: IINKPointerTool) throws
}

// Makes the real IINKToolController conform to the protocol.
extension IINKToolController: ToolControllerProtocol {
  func setToolForPointerType(tool: IINKPointerTool, pointerType: IINKPointerType) throws {
    try self.set(tool: tool, forType: pointerType)
  }

  func setStyleForTool(style: String, tool: IINKPointerTool) throws {
    try self.set(style: style, forTool: tool)
  }
}

// MARK: - EditorProtocol

// Protocol abstracting IINKEditor for testability.
// Covers the properties and methods used by InputViewModel and EditorViewModel for editor operations.
protocol EditorProtocol: AnyObject {
  var editorRenderer: any RendererProtocol { get }
  var editorConfiguration: any ConfigurationProtocol { get }
  var editorToolController: any ToolControllerProtocol { get }
  var isScrollAllowed: Bool { get }
  var viewSize: CGSize { get }
  func setEditorViewSize(_ size: CGSize) throws
  func clampEditorViewOffset(_ offset: inout CGPoint)
  func setEditorPart(_ part: IINKContentPart?) throws
  func setEditorTheme(_ theme: String) throws
  func setEditorFontMetricsProvider(_ provider: IINKIFontMetricsProvider)
  func addEditorDelegate(_ delegate: IINKEditorDelegate)
  func performClear() throws
  func performUndo()
  func performRedo()
}

// Makes the real IINKEditor conform to the protocol.
extension IINKEditor: EditorProtocol {
  var editorRenderer: any RendererProtocol {
    return self.renderer
  }

  var editorConfiguration: any ConfigurationProtocol {
    return self.configuration
  }

  var editorToolController: any ToolControllerProtocol {
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

// MARK: - InputViewControllerProtocol

// Protocol abstracting InputViewController for testability.
// Covers the methods used by EditorViewModel for tool selection and input mode.
@MainActor
protocol InputViewControllerProtocol: AnyObject {
  var view: UIView! { get }
  func selectPenTool()
  func selectEraserTool()
  func selectHighlighterTool()
  func updateInputMode(newInputMode: InputMode)
}

// Makes the real InputViewController conform to the protocol.
extension InputViewController: InputViewControllerProtocol {}

// MARK: - DocumentHandleProtocol

// Protocol abstracting DocumentHandle for testability.
// Covers the properties and methods used by EditorViewModel for document operations.
protocol DocumentHandleProtocol: AnyObject, Sendable {
  var notebookID: String { get }
  var initialManifest: Manifest { get }
  var manifest: Manifest { get async }
  func ensureInitialPart(type: String) async throws -> any ContentPartProtocol
  func savePackageToTemp() async throws
  func savePackage() async throws
  func savePreviewImageData(_ data: Data) async throws
  func updateViewportState(_ state: ViewportState) async
  func close(saveBeforeClose: Bool) async
}

// Makes the real DocumentHandle conform to the protocol.
extension DocumentHandle: DocumentHandleProtocol {}
