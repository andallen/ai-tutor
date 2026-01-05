//
// Tests for InputViewModel with dependency injection.
// Tests the real InputViewModel class with mocked SDK dependencies.
//
// swiftlint:disable file_length type_body_length
// Comprehensive test suite benefits from being in a single file for maintainability.

import Combine
import QuartzCore
import Testing
import UIKit

@testable import InkOS

// MARK: - Mock Types

// Mock IINKRenderer for testing viewport operations.
@MainActor
final class MockInputRenderer: RendererProtocol {
  var viewOffset: CGPoint = .zero
  var viewScale: Float = 1.0
  var zoomCallCount = 0
  var lastZoomCenter: CGPoint = .zero
  var lastZoomFactor: Float = 1.0
  var shouldThrowOnZoom = false

  func performZoom(at point: CGPoint, by factor: Float) throws {
    if shouldThrowOnZoom {
      throw MockInputError.zoomFailed
    }
    zoomCallCount += 1
    lastZoomCenter = point
    lastZoomFactor = factor
    viewScale *= factor
  }
}

// Mock IINKConfiguration for testing margin configuration.
@MainActor
final class MockInputConfiguration: ConfigurationProtocol {
  var setNumberCallCount = 0
  var setBooleanCallCount = 0
  var lastSetNumberKey: String?
  var lastSetNumberValue: Double?

  func setConfigNumber(_ value: Double, forKey key: String) throws {
    setNumberCallCount += 1
    lastSetNumberKey = key
    lastSetNumberValue = value
  }

  func setConfigBoolean(_ value: Bool, forKey key: String) throws {
    setBooleanCallCount += 1
  }
}

// Mock IINKToolController for testing tool selection.
@MainActor
final class MockInputToolController: ToolControllerProtocol {
  var setToolCallCount = 0
  var lastSetTool: IINKPointerTool?
  var lastSetPointerType: IINKPointerType?
  var setStyleCallCount = 0
  var shouldThrowOnSetTool = false

  func setToolForPointerType(tool: IINKPointerTool, pointerType: IINKPointerType) throws {
    if shouldThrowOnSetTool {
      throw MockInputError.toolSelectionFailed
    }
    setToolCallCount += 1
    lastSetTool = tool
    lastSetPointerType = pointerType
  }

  func setStyleForTool(style: String, tool: IINKPointerTool) throws {
    setStyleCallCount += 1
  }

  func styleForTool(tool: IINKPointerTool) throws -> String {
    return ""
  }
}

// Mock IINKEditor for testing editor operations.
@MainActor
final class MockInputEditor: EditorProtocol {
  var mockRenderer: MockInputRenderer
  var mockConfiguration: MockInputConfiguration
  var mockToolController: MockInputToolController
  var isScrollAllowed: Bool = true
  var viewSize: CGSize = CGSize(width: 800, height: 600)
  var setViewSizeCallCount = 0
  var clampViewOffsetCallCount = 0
  var shouldThrowOnSetViewSize = false

  var editorRenderer: any RendererProtocol { mockRenderer }
  var editorConfiguration: any ConfigurationProtocol { mockConfiguration }
  var editorToolController: any ToolControllerProtocol { mockToolController }

  init() {
    self.mockRenderer = MockInputRenderer()
    self.mockConfiguration = MockInputConfiguration()
    self.mockToolController = MockInputToolController()
  }

  func setEditorViewSize(_ size: CGSize) throws {
    if shouldThrowOnSetViewSize {
      throw MockInputError.viewSizeSetFailed
    }
    setViewSizeCallCount += 1
    viewSize = size
  }

  func clampEditorViewOffset(_ offset: inout CGPoint) {
    clampViewOffsetCallCount += 1
    // Clamp vertical offset to non-negative.
    if offset.y < 0 {
      offset.y = 0
    }
  }

  func setEditorPart(_ part: IINKContentPart?) throws {}
  func setEditorTheme(_ theme: String) throws {}
  func setEditorFontMetricsProvider(_ provider: IINKIFontMetricsProvider) {}
  func addEditorDelegate(_ delegate: IINKEditorDelegate) {}
  func performClear() throws {}
  func performUndo() {}
  func performRedo() {}
  func pointerDown(point: CGPoint, timestamp: Int64, force: Float, type: IINKPointerType) throws {}
  func pointerMove(point: CGPoint, timestamp: Int64, force: Float, type: IINKPointerType) throws {}
  func pointerUp(point: CGPoint, timestamp: Int64, force: Float, type: IINKPointerType) throws {}
}

// Mock errors for testing error handling.
enum MockInputError: Error, LocalizedError {
  case viewSizeSetFailed
  case zoomFailed
  case toolSelectionFailed

  var errorDescription: String? {
    switch self {
    case .viewSizeSetFailed: return "Failed to set view size"
    case .zoomFailed: return "Failed to zoom"
    case .toolSelectionFailed: return "Failed to select tool"
    }
  }
}

// MARK: - Test Suite

@Suite("InputViewModel Tests")
struct InputViewModelTests {

  // MARK: - Helper Types

  // Container for test dependencies to avoid large tuple violation.
  struct TestDependencies {
    let viewModel: InputViewModel
    let mockEditor: MockInputEditor
    let mockToolController: MockInputToolController
  }

  // MARK: - Helper Methods

  // Creates an InputViewModel with mocked dependencies for testing.
  @MainActor
  private func createTestViewModel() -> TestDependencies {
    let viewModel = InputViewModel(
      engine: nil,
      inputMode: .forcePen,
      editorDelegate: nil,
      smartGuideDelegate: nil,
      smartGuideDisabled: true
    )

    let mockEditor = MockInputEditor()
    let mockToolController = MockInputToolController()
    viewModel.setTestDependencies(editor: mockEditor, toolController: mockToolController)

    return TestDependencies(
      viewModel: viewModel,
      mockEditor: mockEditor,
      mockToolController: mockToolController
    )
  }

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("inputMode defaults to value from initialization")
    @MainActor
    func inputModeDefaultsToInitValue() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      #expect(viewModel.inputMode == .forcePen)
    }

    @Test("inputMode can be initialized to auto")
    @MainActor
    func inputModeCanBeAuto() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .auto,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      #expect(viewModel.inputMode == .auto)
    }

    @Test("originalViewOffset defaults to zero")
    @MainActor
    func originalViewOffsetDefaultsToZero() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      #expect(viewModel.originalViewOffset == .zero)
    }
  }

  // MARK: - Input Mode Tests

  @Suite("Input Mode")
  struct InputModeTests {

    @Test("updateInputMode changes input mode")
    @MainActor
    func updateInputModeChangesMode() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      viewModel.updateInputMode(newInputMode: .auto)

      #expect(viewModel.inputMode == .auto)
    }

    @Test("input mode can be toggled back and forth")
    @MainActor
    func inputModeCanBeToggled() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      viewModel.updateInputMode(newInputMode: .auto)
      #expect(viewModel.inputMode == .auto)

      viewModel.updateInputMode(newInputMode: .forcePen)
      #expect(viewModel.inputMode == .forcePen)

      viewModel.updateInputMode(newInputMode: .auto)
      #expect(viewModel.inputMode == .auto)
    }
  }

  // MARK: - Editor View Size Tests

  @Suite("Editor View Size")
  struct EditorViewSizeTests {

    @Test("setEditorViewSize updates editor view size")
    @MainActor
    func setEditorViewSizeUpdatesSize() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.setEditorViewSize(size: CGSize(width: 1024, height: 768))

      #expect(mockEditor.setViewSizeCallCount == 1)
      #expect(mockEditor.viewSize == CGSize(width: 1024, height: 768))
    }

    @Test("setEditorViewSize with zero size")
    @MainActor
    func setEditorViewSizeZero() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.setEditorViewSize(size: .zero)

      #expect(mockEditor.viewSize == .zero)
    }

    @Test("setEditorViewSize can be called multiple times for rotation")
    @MainActor
    func setEditorViewSizeMultipleTimes() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.setEditorViewSize(size: CGSize(width: 375, height: 667))
      viewModel.setEditorViewSize(size: CGSize(width: 667, height: 375))
      viewModel.setEditorViewSize(size: CGSize(width: 375, height: 667))

      #expect(mockEditor.setViewSizeCallCount == 3)
      #expect(mockEditor.viewSize == CGSize(width: 375, height: 667))
    }

    @Test("setEditorViewSize with nil editor does not crash")
    @MainActor
    func setEditorViewSizeNilEditor() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      // No editor set - should not crash.
      viewModel.setEditorViewSize(size: CGSize(width: 800, height: 600))

      #expect(viewModel.editor == nil)
    }

    @Test("setEditorViewSize silently ignores errors")
    @MainActor
    func setEditorViewSizeIgnoresErrors() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.shouldThrowOnSetViewSize = true
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Should not crash or throw.
      viewModel.setEditorViewSize(size: CGSize(width: 800, height: 600))

      // Size should not have changed due to error.
      #expect(mockEditor.viewSize == CGSize(width: 800, height: 600))
    }
  }

  // MARK: - Configure Editor UI Tests

  @Suite("Configure Editor UI")
  struct ConfigureEditorUITests {

    @Test("configureEditorUI sets view size and margins")
    @MainActor
    func configureEditorUISetViewSizeAndMargins() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.configureEditorUI(with: CGSize(width: 800, height: 600))

      #expect(mockEditor.setViewSizeCallCount == 1)
      #expect(mockEditor.viewSize == CGSize(width: 800, height: 600))
      // Should have set 7 margin configuration values.
      #expect(mockEditor.mockConfiguration.setNumberCallCount == 7)
    }

    @Test("configureEditorUI with nil editor does not crash")
    @MainActor
    func configureEditorUIWithNilEditor() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      // No editor set - should not crash.
      viewModel.configureEditorUI(with: CGSize(width: 800, height: 600))

      #expect(viewModel.editor == nil)
    }
  }

  // MARK: - Tool Selection Tests

  @Suite("Tool Selection")
  struct ToolSelectionTests {

    @Test("selectPenTool sets pen pointer tool")
    @MainActor
    func selectPenToolSetsTool() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockToolController = MockInputToolController()
      viewModel.setTestDependencies(editor: nil, toolController: mockToolController)

      viewModel.selectPenTool()

      #expect(mockToolController.setToolCallCount == 1)
      #expect(mockToolController.lastSetTool == .toolPen)
      #expect(mockToolController.lastSetPointerType == .pen)
    }

    @Test("selectEraserTool sets eraser pointer tool")
    @MainActor
    func selectEraserToolSetsTool() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockToolController = MockInputToolController()
      viewModel.setTestDependencies(editor: nil, toolController: mockToolController)

      viewModel.selectEraserTool()

      #expect(mockToolController.setToolCallCount == 1)
      #expect(mockToolController.lastSetTool == .eraser)
      #expect(mockToolController.lastSetPointerType == .pen)
    }

    @Test("selectHighlighterTool sets highlighter pointer tool")
    @MainActor
    func selectHighlighterToolSetsTool() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockToolController = MockInputToolController()
      viewModel.setTestDependencies(editor: nil, toolController: mockToolController)

      viewModel.selectHighlighterTool()

      #expect(mockToolController.setToolCallCount == 1)
      #expect(mockToolController.lastSetTool == .toolHighlighter)
      #expect(mockToolController.lastSetPointerType == .pen)
    }

    @Test("tool selection with nil toolController does not crash")
    @MainActor
    func toolSelectionNilToolController() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      // No tool controller set - should not crash.
      viewModel.selectPenTool()
      viewModel.selectEraserTool()
      viewModel.selectHighlighterTool()

      #expect(true)  // Test passes if no crash.
    }

    @Test("rapid tool switching handles all selections")
    @MainActor
    func rapidToolSwitching() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockToolController = MockInputToolController()
      viewModel.setTestDependencies(editor: nil, toolController: mockToolController)

      for _ in 0..<10 {
        viewModel.selectPenTool()
        viewModel.selectEraserTool()
        viewModel.selectHighlighterTool()
      }

      #expect(mockToolController.setToolCallCount == 30)
    }
  }

  // MARK: - Pan Gesture Tests

  @Suite("Pan Gesture Handling")
  struct PanGestureTests {

    @Test("pan gesture stores original view offset on began")
    @MainActor
    func panGestureBeganStoresOffset() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewOffset = CGPoint(x: 100, y: 200)
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)

      #expect(viewModel.originalViewOffset == CGPoint(x: 100, y: 200))
    }

    @Test("pan gesture does nothing when scroll is not allowed")
    @MainActor
    func panGestureBlockedWhenScrollNotAllowed() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.isScrollAllowed = false
      mockEditor.mockRenderer.viewOffset = CGPoint(x: 100, y: 200)
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.handlePanGestureRecognizerAction(
        with: CGPoint(x: 50, y: 50),
        velocity: .zero,
        state: .changed
      )

      // Offset should not change.
      #expect(mockEditor.mockRenderer.viewOffset == CGPoint(x: 100, y: 200))
    }

    @Test("pan gesture clamps vertical offset to non-negative")
    @MainActor
    func panGestureClampsVerticalOffset() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewOffset = .zero
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)

      // Try to scroll up (which would make offset negative).
      viewModel.handlePanGestureRecognizerAction(
        with: CGPoint(x: 0, y: 100),
        velocity: .zero,
        state: .changed
      )

      // Offset should be clamped to 0.
      #expect(mockEditor.mockRenderer.viewOffset.y >= 0)
    }

    @Test("pan gesture horizontal scrolling disabled at scale 1.0")
    @MainActor
    func panGestureHorizontalDisabledAtScale1() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewOffset = .zero
      mockEditor.mockRenderer.viewScale = 1.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)

      // Try to scroll horizontally.
      viewModel.handlePanGestureRecognizerAction(
        with: CGPoint(x: -100, y: 0),
        velocity: .zero,
        state: .changed
      )

      // Horizontal offset should remain 0.
      #expect(mockEditor.mockRenderer.viewOffset.x == 0)
    }

    @Test("pan gesture horizontal scrolling enabled when zoomed in")
    @MainActor
    func panGestureHorizontalEnabledWhenZoomed() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewOffset = .zero
      mockEditor.mockRenderer.viewScale = 2.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)

      // Scroll horizontally.
      viewModel.handlePanGestureRecognizerAction(
        with: CGPoint(x: -100, y: 0),
        velocity: .zero,
        state: .changed
      )

      // Horizontal offset should change.
      #expect(mockEditor.mockRenderer.viewOffset.x > 0)
    }
  }

  // MARK: - Pinch Gesture Tests

  @Suite("Pinch Gesture Handling")
  struct PinchGestureTests {

    @Test("pinch gesture rejects zoom below minimum (1.0)")
    @MainActor
    func pinchGestureRejectsZoomBelowMin() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewScale = 1.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Try to zoom out (scale < 1.0).
      viewModel.handlePinchGestureRecognizerAction(
        scale: 0.5,
        center: CGPoint(x: 200, y: 200),
        state: .changed
      )

      // Scale should remain at 1.0.
      #expect(mockEditor.mockRenderer.viewScale == 1.0)
    }

    @Test("pinch gesture rejects zoom above maximum (4.0)")
    @MainActor
    func pinchGestureRejectsZoomAboveMax() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewScale = 4.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Try to zoom in further.
      viewModel.handlePinchGestureRecognizerAction(
        scale: 1.5,
        center: CGPoint(x: 200, y: 200),
        state: .changed
      )

      // Scale should remain at 4.0.
      #expect(mockEditor.mockRenderer.viewScale == 4.0)
    }

    @Test("pinch gesture accepts zoom within limits")
    @MainActor
    func pinchGestureAcceptsZoomWithinLimits() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewScale = 1.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Zoom in to 2.0.
      viewModel.handlePinchGestureRecognizerAction(
        scale: 2.0,
        center: CGPoint(x: 200, y: 200),
        state: .changed
      )

      #expect(mockEditor.mockRenderer.zoomCallCount == 1)
      #expect(mockEditor.mockRenderer.viewScale == 2.0)
    }

    @Test("pinch gesture clamps viewport offset after zoom")
    @MainActor
    func pinchGestureClampsViewportOffset() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.viewSize = CGSize(width: 800, height: 600)
      mockEditor.mockRenderer.viewScale = 1.5
      mockEditor.mockRenderer.viewOffset = CGPoint(x: -100, y: -100)
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Zoom in slightly so the clamping logic is triggered.
      viewModel.handlePinchGestureRecognizerAction(
        scale: 1.1,
        center: .zero,
        state: .changed
      )

      // Offset should be clamped to valid range.
      #expect(mockEditor.mockRenderer.viewOffset.x >= 0)
      #expect(mockEditor.mockRenderer.viewOffset.y >= 0)
    }

    @Test("pinch gesture with nil editor does not crash")
    @MainActor
    func pinchGestureNilEditor() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      // No editor set - should not crash.
      viewModel.handlePinchGestureRecognizerAction(
        scale: 2.0,
        center: CGPoint(x: 200, y: 200),
        state: .changed
      )

      #expect(true)  // Test passes if no crash.
    }
  }

  // MARK: - Stop Inertial Scroll Tests

  @Suite("Stop Inertial Scroll")
  struct StopInertialScrollTests {

    @Test("stopInertialScroll can be called multiple times")
    @MainActor
    func stopInertialScrollMultipleCalls() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      // Should not crash when called multiple times.
      viewModel.stopInertialScroll()
      viewModel.stopInertialScroll()
      viewModel.stopInertialScroll()

      #expect(true)  // Test passes if no crash.
    }

    @Test("stopInertialScroll is no-op when not decelerating")
    @MainActor
    func stopInertialScrollNoOpWhenNotDecelerating() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      // Should not crash or have side effects.
      viewModel.stopInertialScroll()

      #expect(true)  // Test passes if no crash.
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("calling methods before setting dependencies does not crash")
    @MainActor
    func methodsBeforeSetupDoNotCrash() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      // All should complete without crashing.
      viewModel.updateInputMode(newInputMode: .auto)
      viewModel.configureEditorUI(with: CGSize(width: 800, height: 600))
      viewModel.setEditorViewSize(size: CGSize(width: 800, height: 600))
      viewModel.selectPenTool()
      viewModel.selectEraserTool()
      viewModel.selectHighlighterTool()
      viewModel.stopInertialScroll()
      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)
      viewModel.handlePinchGestureRecognizerAction(scale: 1.0, center: .zero, state: .began)

      #expect(viewModel.inputMode == .auto)
    }

    @Test("gesture handling with all gesture states")
    @MainActor
    func gestureHandlingAllStates() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Test all gesture states.
      let states: [UIGestureRecognizer.State] = [.began, .changed, .ended, .cancelled, .failed, .possible]

      for state in states {
        viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: state)
        viewModel.handlePinchGestureRecognizerAction(scale: 1.0, center: .zero, state: state)
      }

      #expect(true)  // Test passes if no crash.
    }

    @Test("extreme translation values")
    @MainActor
    func extremeTranslationValues() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewScale = 2.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)

      // Extreme positive translation.
      viewModel.handlePanGestureRecognizerAction(
        with: CGPoint(x: 10000, y: 10000),
        velocity: .zero,
        state: .changed
      )

      // Should not crash and offset should be clamped.
      #expect(mockEditor.mockRenderer.viewOffset.y >= 0)
    }

    @Test("extreme scale values")
    @MainActor
    func extremeScaleValues() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewScale = 1.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Extremely large scale.
      viewModel.handlePinchGestureRecognizerAction(
        scale: 1000,
        center: .zero,
        state: .changed
      )

      // Should be clamped to max of 4.0.
      #expect(mockEditor.mockRenderer.viewScale <= 4.0)
    }

    @Test("zero and negative scale values")
    @MainActor
    func zeroAndNegativeScaleValues() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewScale = 2.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Zero scale.
      viewModel.handlePinchGestureRecognizerAction(
        scale: 0,
        center: .zero,
        state: .changed
      )

      // Scale should remain unchanged (rejected or clamped).
      #expect(mockEditor.mockRenderer.viewScale >= 1.0)

      // Negative scale.
      viewModel.handlePinchGestureRecognizerAction(
        scale: -1,
        center: .zero,
        state: .changed
      )

      // Scale should remain valid.
      #expect(mockEditor.mockRenderer.viewScale >= 1.0)
    }
  }

  // MARK: - Boundary Calculations Tests

  @Suite("Boundary Calculations")
  struct BoundaryCalculationTests {

    @Test("max horizontal offset at scale 1.0 is zero")
    @MainActor
    func maxHorizontalOffsetAtScale1() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.viewSize = CGSize(width: 800, height: 600)
      mockEditor.mockRenderer.viewScale = 1.0
      mockEditor.mockRenderer.viewOffset = CGPoint(x: 100, y: 0)
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Pan gesture should clamp horizontal offset to 0 at scale 1.0.
      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)
      viewModel.handlePanGestureRecognizerAction(
        with: CGPoint(x: -50, y: 0),
        velocity: .zero,
        state: .changed
      )

      // At scale 1.0, no horizontal scrolling should be applied.
      #expect(mockEditor.mockRenderer.viewOffset.x == 0)
    }

    @Test("vertical offset always clamped to non-negative")
    @MainActor
    func verticalOffsetAlwaysNonNegative() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewOffset = CGPoint(x: 0, y: -500)
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      viewModel.handlePanGestureRecognizerAction(with: .zero, velocity: .zero, state: .began)
      viewModel.handlePanGestureRecognizerAction(
        with: CGPoint(x: 0, y: 100),
        velocity: .zero,
        state: .changed
      )

      #expect(mockEditor.mockRenderer.viewOffset.y >= 0)
    }
  }

  // MARK: - Constants Validation Tests

  @Suite("Constants Validation")
  struct ConstantsValidationTests {

    @Test("zoom limits are enforced correctly")
    @MainActor
    func zoomLimitsEnforced() {
      let viewModel = InputViewModel(
        engine: nil,
        inputMode: .forcePen,
        editorDelegate: nil,
        smartGuideDelegate: nil,
        smartGuideDisabled: true
      )

      let mockEditor = MockInputEditor()
      mockEditor.mockRenderer.viewScale = 1.0
      viewModel.setTestDependencies(editor: mockEditor, toolController: nil)

      // Try to zoom below 1.0.
      viewModel.handlePinchGestureRecognizerAction(scale: 0.5, center: .zero, state: .changed)
      #expect(mockEditor.mockRenderer.viewScale >= 1.0)

      // Try to zoom above 4.0.
      mockEditor.mockRenderer.viewScale = 4.0
      viewModel.handlePinchGestureRecognizerAction(scale: 2.0, center: .zero, state: .changed)
      #expect(mockEditor.mockRenderer.viewScale <= 4.0)
    }
  }
}
