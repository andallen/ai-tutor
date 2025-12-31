//
// Tests for EditorViewModel using real class with mocked dependencies.
// Tests cover published properties, setup, tool selection, edit operations, and lifecycle.
//
// swiftlint:disable file_length type_body_length
// Comprehensive test suite benefits from being in a single file for maintainability.

import Testing
import UIKit
import Combine
@testable import InkOS

// MARK: - Mock Types

// Mock errors for testing error handling.
enum MockEditorVMError: Error, LocalizedError {
  case clearFailed
  case saveFailed
  case partCreationFailed

  var errorDescription: String? {
    switch self {
    case .clearFailed: return "Failed to clear editor content"
    case .saveFailed: return "Failed to save notebook"
    case .partCreationFailed: return "Failed to create part"
    }
  }
}

// Mock renderer for testing viewport operations.
@MainActor
final class MockEditorVMRenderer: RendererProtocol {
  var viewOffset: CGPoint = .zero
  var viewScale: Float = 1.0
  var zoomCallCount = 0

  func performZoom(at point: CGPoint, by factor: Float) throws {
    zoomCallCount += 1
    viewScale *= factor
  }
}

// Mock configuration for testing eraser settings.
@MainActor
final class MockEditorVMConfiguration: ConfigurationProtocol {
  var setBooleanCallCount = 0
  var setNumberCallCount = 0
  var lastBooleanValue: Bool?
  var lastNumberValue: Double?

  func setConfigNumber(_ value: Double, forKey key: String) throws {
    setNumberCallCount += 1
    lastNumberValue = value
  }

  func setConfigBoolean(_ value: Bool, forKey key: String) throws {
    setBooleanCallCount += 1
    lastBooleanValue = value
  }
}

// Mock tool controller for testing tool selection.
@MainActor
final class MockEditorVMToolController: ToolControllerProtocol {
  var setToolCallCount = 0
  var setStyleCallCount = 0
  var lastSetTool: IINKPointerTool?
  var lastPointerType: IINKPointerType?
  var lastStyle: String?
  var shouldThrowOnSetTool = false
  var shouldThrowOnSetStyle = false

  func setToolForPointerType(tool: IINKPointerTool, pointerType: IINKPointerType) throws {
    if shouldThrowOnSetTool {
      throw MockEditorVMError.clearFailed
    }
    setToolCallCount += 1
    lastSetTool = tool
    lastPointerType = pointerType
  }

  func setStyleForTool(style: String, tool: IINKPointerTool) throws {
    if shouldThrowOnSetStyle {
      throw MockEditorVMError.clearFailed
    }
    setStyleCallCount += 1
    lastStyle = style
  }
}

// Mock editor for testing editor operations.
@MainActor
final class MockEditorVMEditor: EditorProtocol {
  var mockRenderer = MockEditorVMRenderer()
  var mockConfiguration = MockEditorVMConfiguration()
  var mockToolController = MockEditorVMToolController()

  var isScrollAllowed: Bool = true
  var viewSize: CGSize = CGSize(width: 800, height: 600)

  var clearCallCount = 0
  var undoCallCount = 0
  var redoCallCount = 0
  var setPartCallCount = 0
  var clampOffsetCallCount = 0
  var shouldThrowOnClear = false
  var lastSetPart: IINKContentPart?

  var editorRenderer: any RendererProtocol { mockRenderer }
  var editorConfiguration: any ConfigurationProtocol { mockConfiguration }
  var editorToolController: any ToolControllerProtocol { mockToolController }

  func setEditorViewSize(_ size: CGSize) throws {
    viewSize = size
  }

  func clampEditorViewOffset(_ offset: inout CGPoint) {
    clampOffsetCallCount += 1
    // Clamp offset to reasonable bounds for testing.
    offset.x = max(-500, min(500, offset.x))
    offset.y = max(-500, min(500, offset.y))
  }

  func setEditorPart(_ part: IINKContentPart?) throws {
    setPartCallCount += 1
    lastSetPart = part
  }

  func setEditorTheme(_ theme: String) throws {
    // No-op for testing.
  }

  func setEditorFontMetricsProvider(_ provider: IINKIFontMetricsProvider) {
    // No-op for testing.
  }

  func addEditorDelegate(_ delegate: IINKEditorDelegate) {
    // No-op for testing.
  }

  func performClear() throws {
    if shouldThrowOnClear {
      throw MockEditorVMError.clearFailed
    }
    clearCallCount += 1
  }

  func performUndo() {
    undoCallCount += 1
  }

  func performRedo() {
    redoCallCount += 1
  }
}

// Mock content part for testing part operations.
final class MockEditorVMContentPart: ContentPartProtocol {}

// Mock InputViewController for testing tool delegation.
@MainActor
final class MockEditorVMInputViewController: InputViewControllerProtocol {
  var selectPenToolCallCount = 0
  var selectEraserToolCallCount = 0
  var selectHighlighterToolCallCount = 0
  var updateInputModeCallCount = 0
  var lastInputMode: InputMode?

  var view: UIView! = UIView()

  func selectPenTool() {
    selectPenToolCallCount += 1
  }

  func selectEraserTool() {
    selectEraserToolCallCount += 1
  }

  func selectHighlighterTool() {
    selectHighlighterToolCallCount += 1
  }

  func updateInputMode(newInputMode: InputMode) {
    updateInputModeCallCount += 1
    lastInputMode = newInputMode
  }
}

// Mock DocumentHandle for testing document operations.
final actor MockEditorVMDocumentHandle: DocumentHandleProtocol {
  let notebookID: String
  let initialManifest: Manifest
  private var currentManifest: Manifest
  var savedViewportState: ViewportState?
  var savedPreviewData: Data?
  var savePackageCallCount = 0
  var savePackageToTempCallCount = 0
  var closeCallCount = 0
  var shouldThrowOnSave = false
  var shouldThrowOnEnsurePart = false

  init(notebookID: String, displayName: String, viewportState: ViewportState? = nil) {
    self.notebookID = notebookID
    var manifest = Manifest(notebookID: notebookID, displayName: displayName)
    manifest.viewportState = viewportState
    self.initialManifest = manifest
    self.currentManifest = manifest
  }

  var manifest: Manifest {
    get async { currentManifest }
  }

  func ensureInitialPart(type: String) async throws -> any ContentPartProtocol {
    if shouldThrowOnEnsurePart {
      throw MockEditorVMError.partCreationFailed
    }
    return MockEditorVMContentPart()
  }

  func savePackageToTemp() async throws {
    savePackageToTempCallCount += 1
  }

  func savePackage() async throws {
    if shouldThrowOnSave {
      throw MockEditorVMError.saveFailed
    }
    savePackageCallCount += 1
  }

  func savePreviewImageData(_ data: Data) async throws {
    savedPreviewData = data
  }

  func updateViewportState(_ state: ViewportState) async {
    savedViewportState = state
  }

  // JIIX persistence protocol conformance for testing.
  func saveJIIXData(_ data: Data) async throws {
    // No-op for testing.
  }

  func loadJIIXData() async throws -> Data? {
    // Return nil for testing.
    return nil
  }

  func close(saveBeforeClose: Bool) async {
    closeCallCount += 1
  }
}

// MARK: - Test Suite

@Suite("EditorViewModel Tests")
struct EditorViewModelTests {

  // MARK: - Published Properties Tests

  @Suite("Published Properties")
  struct PublishedPropertiesTests {

    @Test("editorViewController is nil before setup")
    @MainActor
    func editorViewControllerNilBeforeSetup() {
      let viewModel = EditorViewModel()
      #expect(viewModel.editorViewController == nil)
    }

    @Test("title is empty string by default")
    @MainActor
    func titleEmptyByDefault() {
      let viewModel = EditorViewModel()
      #expect(viewModel.title == "")
    }

    @Test("alert is nil by default")
    @MainActor
    func alertNilByDefault() {
      let viewModel = EditorViewModel()
      #expect(viewModel.alert == nil)
    }

    @Test("editorViewController is set after setTestDependencies")
    @MainActor
    func editorViewControllerSetAfterInjection() async {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      #expect(viewModel.editorViewController != nil)
    }

    @Test("title is set from manifest displayName after injection")
    @MainActor
    func titleSetFromManifest() async {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "My Notebook")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      #expect(viewModel.title == "My Notebook")
    }
  }

  // MARK: - Tool Selection Tests

  @Suite("Tool Selection")
  struct ToolSelectionTests {

    @Test("selectTool with pen dispatches to selectPenTool")
    @MainActor
    func selectToolPen() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.selectTool(.pen)

      #expect(mockVC.selectPenToolCallCount == 1)
    }

    @Test("selectTool with eraser dispatches to selectEraserTool")
    @MainActor
    func selectToolEraser() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.selectTool(.eraser)

      #expect(mockVC.selectEraserToolCallCount == 1)
    }

    @Test("selectTool with highlighter dispatches to selectHighlighterTool")
    @MainActor
    func selectToolHighlighter() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.selectTool(.highlighter)

      #expect(mockVC.selectHighlighterToolCallCount == 1)
    }

    @Test("selectPenTool can be called directly")
    @MainActor
    func selectPenToolDirect() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.selectPenTool()

      #expect(mockVC.selectPenToolCallCount == 1)
    }

    @Test("rapid tool switching handles all selections")
    @MainActor
    func rapidToolSwitching() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      for _ in 0..<10 {
        viewModel.selectTool(.pen)
        viewModel.selectTool(.eraser)
        viewModel.selectTool(.highlighter)
      }

      #expect(mockVC.selectPenToolCallCount == 10)
      #expect(mockVC.selectEraserToolCallCount == 10)
      #expect(mockVC.selectHighlighterToolCallCount == 10)
    }
  }

  // MARK: - Input Mode Tests

  @Suite("Input Mode")
  struct InputModeTests {

    @Test("updateInputMode updates InputViewController")
    @MainActor
    func updateInputModeUpdatesViewController() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateInputMode(newInputMode: .auto)

      #expect(mockVC.updateInputModeCallCount == 1)
      #expect(mockVC.lastInputMode == .auto)
    }

    @Test("updateInputMode from forcePen to auto")
    @MainActor
    func updateInputModeForcePenToAuto() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateInputMode(newInputMode: .auto)

      #expect(mockVC.lastInputMode == .auto)
    }
  }

  // MARK: - Tool Updates Tests

  @Suite("Tool Updates")
  struct ToolUpdateTests {

    @Test("updateTool applies tool to editor")
    @MainActor
    func updateToolAppliesToEditor() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateTool(selection: .eraser)

      #expect(mockEditor.mockToolController.setToolCallCount >= 1)
      #expect(mockEditor.mockToolController.lastSetTool == .eraser)
    }

    @Test("updateTool does nothing when editor is nil")
    @MainActor
    func updateToolNoEditorDoesNothing() {
      let viewModel = EditorViewModel()

      // No dependencies injected, so editor is nil.
      viewModel.updateTool(selection: .highlighter)

      // Should not crash.
    }
  }

  // MARK: - Ink Color Tests

  @Suite("Ink Color")
  struct InkColorTests {

    @Test("updateInkColor for pen applies style")
    @MainActor
    func updateInkColorForPen() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateInkColor(hex: "#FF5733", for: .pen)

      #expect(mockEditor.mockToolController.setStyleCallCount >= 1)
      #expect(mockEditor.mockToolController.lastStyle?.contains("#FF5733") == true)
    }

    @Test("updateInkColor for highlighter applies style")
    @MainActor
    func updateInkColorForHighlighter() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateInkColor(hex: "#FFFF00", for: .highlighter)

      #expect(mockEditor.mockToolController.setStyleCallCount >= 1)
      #expect(mockEditor.mockToolController.lastStyle?.contains("#FFFF00") == true)
    }

    @Test("updateInkColor for eraser is a no-op")
    @MainActor
    func updateInkColorForEraserIsNoOp() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      let initialStyleCount = mockEditor.mockToolController.setStyleCallCount

      viewModel.updateInkColor(hex: "#FF0000", for: .eraser)

      #expect(mockEditor.mockToolController.setStyleCallCount == initialStyleCount)
    }
  }

  // MARK: - Ink Width Tests

  @Suite("Ink Width")
  struct InkWidthTests {

    @Test("updateInkWidth for pen applies style")
    @MainActor
    func updateInkWidthForPen() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateInkWidth(width: 1.5, for: .pen)

      #expect(mockEditor.mockToolController.setStyleCallCount >= 1)
    }

    @Test("updateInkWidth for highlighter applies style")
    @MainActor
    func updateInkWidthForHighlighter() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateInkWidth(width: 8.0, for: .highlighter)

      #expect(mockEditor.mockToolController.setStyleCallCount >= 1)
    }

    @Test("updateInkWidth for eraser is a no-op")
    @MainActor
    func updateInkWidthForEraserIsNoOp() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      let initialStyleCount = mockEditor.mockToolController.setStyleCallCount

      viewModel.updateInkWidth(width: 10.0, for: .eraser)

      #expect(mockEditor.mockToolController.setStyleCallCount == initialStyleCount)
    }
  }

  // MARK: - Edit Operations Tests

  @Suite("Edit Operations")
  struct EditOperationsTests {

    @Test("clear calls editor.performClear()")
    @MainActor
    func clearCallsEditor() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.clear()

      #expect(mockEditor.clearCallCount == 1)
    }

    @Test("clear shows alert on error")
    @MainActor
    func clearShowsAlertOnError() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      mockEditor.shouldThrowOnClear = true
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.clear()

      #expect(viewModel.alert != nil)
      #expect(viewModel.alert?.title == "Error")
    }

    @Test("clear with nil editor does nothing")
    @MainActor
    func clearWithNilEditor() {
      let viewModel = EditorViewModel()

      viewModel.clear()

      #expect(viewModel.alert == nil)
    }

    @Test("undo calls editor.performUndo()")
    @MainActor
    func undoCallsEditor() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.undo()

      #expect(mockEditor.undoCallCount == 1)
    }

    @Test("undo with nil editor does nothing")
    @MainActor
    func undoWithNilEditor() {
      let viewModel = EditorViewModel()

      viewModel.undo()

      // Should not crash.
    }

    @Test("redo calls editor.performRedo()")
    @MainActor
    func redoCallsEditor() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.redo()

      #expect(mockEditor.redoCallCount == 1)
    }

    @Test("redo with nil editor does nothing")
    @MainActor
    func redoWithNilEditor() {
      let viewModel = EditorViewModel()

      viewModel.redo()

      // Should not crash.
    }
  }

  // MARK: - Lifecycle Tests

  @Suite("Lifecycle")
  struct LifecycleTests {

    @Test("releaseEditor captures viewport state")
    @MainActor
    func releaseEditorCapturesViewport() async throws {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      mockEditor.mockRenderer.viewOffset = CGPoint(x: 100, y: 200)
      mockEditor.mockRenderer.viewScale = 2.0
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      let releaseTask = viewModel.releaseEditor(previewImage: nil)
      await releaseTask.value

      let savedState = await mockHandle.savedViewportState
      #expect(savedState?.offsetX == 100)
      #expect(savedState?.offsetY == 200)
      #expect(savedState?.scale == 2.0)
    }

    @Test("releaseEditor releases editor part binding")
    @MainActor
    func releaseEditorReleasesPartBinding() async {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      let releaseTask = viewModel.releaseEditor(previewImage: nil)
      await releaseTask.value

      #expect(mockEditor.setPartCallCount == 1)
    }

    @Test("releaseEditor saves preview image when provided")
    @MainActor
    func releaseEditorSavesPreviewImage() async throws {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      // Create a small test image.
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
      let testImage = renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
      }

      let releaseTask = viewModel.releaseEditor(previewImage: testImage)
      await releaseTask.value

      let savedPreviewData = await mockHandle.savedPreviewData
      #expect(savedPreviewData != nil)
    }

    @Test("releaseEditor closes document handle")
    @MainActor
    func releaseEditorClosesHandle() async throws {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      let releaseTask = viewModel.releaseEditor(previewImage: nil)
      await releaseTask.value

      let closeCount = await mockHandle.closeCallCount
      #expect(closeCount == 1)
    }

    @Test("releaseEditor with nil editor does nothing")
    @MainActor
    func releaseEditorWithNilEditor() async {
      let viewModel = EditorViewModel()

      let releaseTask = viewModel.releaseEditor(previewImage: nil)
      await releaseTask.value

      // Should not crash.
    }

    @Test("handleAppBackground does not crash without document handle")
    @MainActor
    func handleAppBackgroundNoHandle() async {
      let viewModel = EditorViewModel()

      viewModel.handleAppBackground()

      // Should not crash.
    }

    @Test("presentMissingNotebookError shows correct alert")
    @MainActor
    func presentMissingNotebookErrorShowsAlert() {
      let viewModel = EditorViewModel()

      viewModel.presentMissingNotebookError()

      #expect(viewModel.alert != nil)
      #expect(viewModel.alert?.title == "Error")
      #expect(viewModel.alert?.message == "Notebook details are missing.")
    }
  }

  // MARK: - SetEditorViewSize Tests

  @Suite("Set Editor View Size")
  struct SetEditorViewSizeTests {

    @Test("setEditorViewSize updates the view frame")
    @MainActor
    func setEditorViewSizeUpdatesFrame() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      let testBounds = CGRect(x: 0, y: 0, width: 800, height: 600)
      viewModel.setEditorViewSize(bounds: testBounds)

      #expect(mockVC.view.frame == testBounds)
    }

    @Test("setEditorViewSize with zero bounds does not crash")
    @MainActor
    func setEditorViewSizeWithZeroBounds() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      let zeroBounds = CGRect.zero
      viewModel.setEditorViewSize(bounds: zeroBounds)

      #expect(mockVC.view.frame == zeroBounds)
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("calling methods before setup does not crash")
    @MainActor
    func methodsBeforeSetupDoNotCrash() {
      let viewModel = EditorViewModel()

      viewModel.selectTool(.pen)
      viewModel.selectPenTool()
      viewModel.selectEraserTool()
      viewModel.selectHighlighterTool()
      viewModel.updateInputMode(newInputMode: .auto)
      viewModel.updateTool(selection: .eraser)
      viewModel.updateInkColor(hex: "#FF0000", for: .pen)
      viewModel.updateInkWidth(width: 1.0, for: .pen)
      viewModel.clear()
      viewModel.undo()
      viewModel.redo()
      viewModel.setEditorViewSize(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))

      // All should complete without crashing.
    }

    @Test("empty title is handled")
    @MainActor
    func emptyTitle() async {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      #expect(viewModel.title == "")
    }

    @Test("special characters in title")
    @MainActor
    func specialCharactersInTitle() async {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let specialTitle = "My Notebook (Draft) - 2024 <test> & more"
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: specialTitle)

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      #expect(viewModel.title == specialTitle)
    }
  }

  // MARK: - State Consistency Tests

  @Suite("State Consistency")
  struct StateConsistencyTests {

    @Test("input mode persists across tool switches")
    @MainActor
    func inputModePersists() {
      let viewModel = EditorViewModel()
      let mockVC = MockEditorVMInputViewController()
      let mockEditor = MockEditorVMEditor()
      let mockHandle = MockEditorVMDocumentHandle(notebookID: "test", displayName: "Test")

      viewModel.setTestDependencies(
        editor: mockEditor,
        viewController: mockVC,
        documentHandle: mockHandle
      )

      viewModel.updateInputMode(newInputMode: .auto)
      viewModel.selectTool(.pen)
      viewModel.selectTool(.eraser)

      #expect(mockVC.lastInputMode == .auto)
    }
  }
}
