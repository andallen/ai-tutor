//
// Tests for DisplayViewModel.
// Tests the real DisplayViewModel class with mocked dependencies.
//

import Testing
import UIKit
@testable import InkOS

// MARK: - Mock Dependencies

// Mock OffscreenRenderSurfaces for testing. Tracks method calls and manages surfaces.
final class MockOffscreenRenderSurfaces: NSObject, OffscreenRenderSurfacesProtocol {
  var scale: CGFloat = 1.0
  var addSurfaceCallCount = 0
  var getSurfaceBufferCallCount = 0
  var releaseSurfaceCallCount = 0
  var lastReleasedSurfaceId: UInt32?
  var lastAddedBuffer: CGLayer?

  // Internal storage for surface buffers.
  private var buffers: [UInt32: CGLayer] = [:]
  private var nextId: UInt32 = 0

  func addSurface(with buffer: CGLayer) -> UInt32 {
    addSurfaceCallCount += 1
    lastAddedBuffer = buffer
    nextId += 1
    buffers[nextId] = buffer
    return nextId
  }

  func getSurfaceBuffer(forId offscreenId: UInt32) -> CGLayer? {
    getSurfaceBufferCallCount += 1
    return buffers[offscreenId]
  }

  func releaseSurface(forId offscreenId: UInt32) {
    releaseSurfaceCallCount += 1
    lastReleasedSurfaceId = offscreenId
    buffers.removeValue(forKey: offscreenId)
  }

  // Test helper to check if a surface exists.
  func hasSurface(forId offscreenId: UInt32) -> Bool {
    return buffers[offscreenId] != nil
  }

  // Test helper to get surface count.
  var surfaceCount: Int {
    return buffers.count
  }
}

// MARK: - Test Suite

@Suite("DisplayViewModel Tests")
struct DisplayViewModelTests {

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("default initializer creates OffscreenRenderSurfaces")
    @MainActor
    func defaultInitCreatesOffscreenRenderSurfaces() {
      let viewModel = DisplayViewModel()
      // The default initializer creates a real OffscreenRenderSurfaces instance.
      #expect(viewModel.offscreenRenderSurfaces.scale >= 1.0)
    }

    @Test("dependency injection allows mock surfaces")
    @MainActor
    func dependencyInjectionAllowsMockSurfaces() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 3.0

      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      #expect(viewModel.offscreenRenderSurfaces.scale == 3.0)
    }
  }

  // MARK: - Published Properties Tests

  @Suite("Published Properties")
  struct PublishedPropertiesTests {

    @Test("renderView is nil before setup")
    @MainActor
    func renderViewNilBeforeSetup() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      #expect(viewModel.renderView == nil)
    }

    @Test("renderView is created after setupModel")
    @MainActor
    func renderViewCreatedAfterSetup() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setupModel()

      #expect(viewModel.renderView != nil)
    }

    @Test("renderView has zero frame initially")
    @MainActor
    func renderViewHasZeroFrameInitially() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setupModel()

      #expect(viewModel.renderView?.frame == .zero)
    }
  }

  // MARK: - Properties Tests

  @Suite("Properties")
  struct PropertiesTests {

    @Test("renderer is nil by default")
    @MainActor
    func rendererNilByDefault() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      #expect(viewModel.renderer == nil)
    }

    @Test("imageLoader is nil by default")
    @MainActor
    func imageLoaderNilByDefault() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      #expect(viewModel.imageLoader == nil)
    }

    @Test("pixelDensity returns screen scale")
    @MainActor
    func pixelDensityReturnsScreenScale() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)
      let expectedDensity = Float(UIScreen.main.scale)

      #expect(viewModel.pixelDensity == expectedDensity)
    }
  }

  // MARK: - Setup Tests

  @Suite("Setup Methods")
  struct SetupTests {

    @Test("setupModel creates RenderView")
    @MainActor
    func setupModelCreatesRenderView() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setupModel()

      #expect(viewModel.renderView != nil)
    }

    @Test("setupModel can be called multiple times")
    @MainActor
    func setupModelMultipleTimes() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setupModel()
      let firstView = viewModel.renderView

      viewModel.setupModel()
      let secondView = viewModel.renderView

      // Each call creates a new RenderView.
      #expect(firstView !== secondView)
    }

    @Test("setOffScreenRendererSurfacesScale sets scale on mock")
    @MainActor
    func setOffScreenRendererSurfacesScaleSetsScale() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setOffScreenRendererSurfacesScale(scale: 2.0)

      #expect(mockSurfaces.scale == 2.0)
    }

    @Test("initModelViewConstraints is idempotent")
    @MainActor
    func initModelViewConstraintsIdempotent() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)
      let parentView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

      viewModel.setupModel()
      // Must add renderView as subview before adding constraints.
      if let renderView = viewModel.renderView {
        parentView.addSubview(renderView)
      }
      viewModel.initModelViewConstraints(view: parentView)
      let constraintCount = parentView.constraints.count

      // Second call should not add more constraints.
      viewModel.initModelViewConstraints(view: parentView)

      #expect(parentView.constraints.count == constraintCount)
    }
  }

  // MARK: - Refresh Display Tests

  @Suite("Refresh Display")
  struct RefreshDisplayTests {

    @Test("refreshDisplay does not crash without renderView")
    @MainActor
    func refreshDisplayWithoutRenderView() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      // Should not crash when renderView is nil.
      viewModel.refreshDisplay()
    }

    @Test("refreshDisplay can be called after setup")
    @MainActor
    func refreshDisplayAfterSetup() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setupModel()
      viewModel.refreshDisplay()

      // RenderView should exist and not crash.
      #expect(viewModel.renderView != nil)
    }
  }

  // MARK: - Offscreen Surface Tests

  @Suite("Offscreen Surfaces")
  struct OffscreenSurfaceTests {

    @Test("createOffscreenRenderSurface creates surface via mock")
    @MainActor
    func createOffscreenRenderSurfaceCreatesSurface() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: 100, height: 100, alphaMask: false)

      #expect(surfaceId > 0)
      #expect(mockSurfaces.addSurfaceCallCount == 1)
    }

    @Test("createOffscreenRenderSurface with zero width returns 0")
    @MainActor
    func createOffscreenRenderSurfaceZeroWidthReturnsZero() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: 0, height: 100, alphaMask: false)

      #expect(surfaceId == 0)
      #expect(mockSurfaces.addSurfaceCallCount == 0)
    }

    @Test("createOffscreenRenderSurface with zero height returns 0")
    @MainActor
    func createOffscreenRenderSurfaceZeroHeightReturnsZero() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: 100, height: 0, alphaMask: false)

      #expect(surfaceId == 0)
      #expect(mockSurfaces.addSurfaceCallCount == 0)
    }

    @Test("createOffscreenRenderSurface with zero dimensions returns 0")
    @MainActor
    func createOffscreenRenderSurfaceZeroDimensionsReturnsZero() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: 0, height: 0, alphaMask: false)

      // Now returns 0 instead of crashing.
      #expect(surfaceId == 0)
      #expect(mockSurfaces.addSurfaceCallCount == 0)
    }

    @Test("createOffscreenRenderSurface with negative width returns 0")
    @MainActor
    func createOffscreenRenderSurfaceNegativeWidthReturnsZero() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: -100, height: 100, alphaMask: false)

      #expect(surfaceId == 0)
      #expect(mockSurfaces.addSurfaceCallCount == 0)
    }

    @Test("createOffscreenRenderSurface with negative height returns 0")
    @MainActor
    func createOffscreenRenderSurfaceNegativeHeightReturnsZero() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: 100, height: -100, alphaMask: false)

      #expect(surfaceId == 0)
      #expect(mockSurfaces.addSurfaceCallCount == 0)
    }

    @Test("createOffscreenRenderSurface accounts for scale")
    @MainActor
    func createOffscreenRenderSurfaceAccountsForScale() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 2.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: 100, height: 100, alphaMask: false)

      #expect(surfaceId > 0)
      // The buffer should be scaled (200x200 for scale 2.0).
      let buffer = mockSurfaces.getSurfaceBuffer(forId: surfaceId)
      #expect(buffer != nil)
      #expect(buffer?.size.width == 200)
      #expect(buffer?.size.height == 200)
    }

    @Test("releaseOffscreenRenderSurface releases via mock")
    @MainActor
    func releaseOffscreenRenderSurfaceReleases() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)
      let surfaceId = viewModel.createOffscreenRenderSurface(width: 100, height: 100, alphaMask: false)

      viewModel.releaseOffscreenRenderSurface(surfaceId)

      #expect(mockSurfaces.releaseSurfaceCallCount == 1)
      #expect(mockSurfaces.lastReleasedSurfaceId == surfaceId)
      #expect(mockSurfaces.hasSurface(forId: surfaceId) == false)
    }

    @Test("releaseOffscreenRenderSurface with invalid ID is safe")
    @MainActor
    func releaseOffscreenRenderSurfaceInvalidIdIsSafe() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      // Release a surface that was never created.
      viewModel.releaseOffscreenRenderSurface(999)

      #expect(mockSurfaces.releaseSurfaceCallCount == 1)
      // Should not crash.
    }

    @Test("multiple surfaces can be created")
    @MainActor
    func multipleSurfacesCanBeCreated() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let id1 = viewModel.createOffscreenRenderSurface(width: 100, height: 100, alphaMask: false)
      let id2 = viewModel.createOffscreenRenderSurface(width: 200, height: 200, alphaMask: false)
      let id3 = viewModel.createOffscreenRenderSurface(width: 300, height: 300, alphaMask: true)

      #expect(id1 > 0)
      #expect(id2 > 0)
      #expect(id3 > 0)
      #expect(id1 != id2)
      #expect(id2 != id3)
      #expect(mockSurfaces.surfaceCount == 3)
    }

    @Test("surfaces are independent")
    @MainActor
    func surfacesAreIndependent() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let id1 = viewModel.createOffscreenRenderSurface(width: 100, height: 100, alphaMask: false)
      let id2 = viewModel.createOffscreenRenderSurface(width: 200, height: 200, alphaMask: false)

      // Release first surface.
      viewModel.releaseOffscreenRenderSurface(id1)

      // Second surface should still exist.
      #expect(mockSurfaces.hasSurface(forId: id1) == false)
      #expect(mockSurfaces.hasSurface(forId: id2) == true)
    }
  }

  // MARK: - Offscreen Canvas Tests

  @Suite("Offscreen Canvas")
  struct OffscreenCanvasTests {

    @Test("createOffscreenRenderCanvas creates canvas")
    @MainActor
    func createOffscreenRenderCanvasCreates() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 2.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)
      let surfaceId = viewModel.createOffscreenRenderSurface(width: 400, height: 300, alphaMask: false)

      let canvas = viewModel.createOffscreenRenderCanvas(surfaceId)

      #expect(canvas != nil)
    }

    @Test("createOffscreenRenderCanvas with invalid surface returns empty canvas")
    @MainActor
    func createOffscreenRenderCanvasInvalidSurfaceReturnsEmptyCanvas() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      // Request canvas for non-existent surface.
      let canvas = viewModel.createOffscreenRenderCanvas(999)

      // Returns a Canvas but without a valid context.
      #expect(canvas != nil)
    }

    @Test("releaseOffscreenRenderCanvas does not crash")
    @MainActor
    func releaseOffscreenRenderCanvasDoesNotCrash() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)
      let surfaceId = viewModel.createOffscreenRenderSurface(width: 100, height: 100, alphaMask: false)
      let canvas = viewModel.createOffscreenRenderCanvas(surfaceId)

      viewModel.releaseOffscreenRenderCanvas(canvas)

      // Should complete without crashing.
    }

    @Test("canvas lifecycle: create, use, release")
    @MainActor
    func canvasLifecycle() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 2.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      // Create surface.
      let surfaceId = viewModel.createOffscreenRenderSurface(width: 200, height: 150, alphaMask: false)
      #expect(surfaceId > 0)

      // Create canvas.
      let canvas = viewModel.createOffscreenRenderCanvas(surfaceId)
      #expect(canvas != nil)

      // Release canvas.
      viewModel.releaseOffscreenRenderCanvas(canvas)

      // Release surface.
      viewModel.releaseOffscreenRenderSurface(surfaceId)
      #expect(mockSurfaces.hasSurface(forId: surfaceId) == false)
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("calling methods before setupModel does not crash")
    @MainActor
    func methodsBeforeSetupDoNotCrash() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.refreshDisplay()
      viewModel.setOffScreenRendererSurfacesScale(scale: 2.0)

      // All should complete without crashing.
      #expect(mockSurfaces.scale == 2.0)
    }

    @Test("scale of zero does not crash")
    @MainActor
    func scaleZeroDoesNotCrash() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setOffScreenRendererSurfacesScale(scale: 0)

      #expect(mockSurfaces.scale == 0)
    }

    @Test("negative scale does not crash")
    @MainActor
    func negativeScaleDoesNotCrash() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      viewModel.setOffScreenRendererSurfacesScale(scale: -1.0)

      #expect(mockSurfaces.scale == -1.0)
    }

    @Test("rapid surface creation and release")
    @MainActor
    func rapidSurfaceCreationAndRelease() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      var surfaceIds: [UInt32] = []

      // Create many surfaces.
      for _ in 0..<50 {
        let id = viewModel.createOffscreenRenderSurface(width: 50, height: 50, alphaMask: false)
        if id > 0 {
          surfaceIds.append(id)
        }
      }

      // Release all surfaces.
      for id in surfaceIds {
        viewModel.releaseOffscreenRenderSurface(id)
      }

      #expect(mockSurfaces.surfaceCount == 0)
    }
  }

  // MARK: - Memory Management Tests

  @Suite("Memory Management")
  struct MemoryManagementTests {

    @Test("releasing surfaces decreases surface count")
    @MainActor
    func releasingSurfacesDecreasesCount() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let id1 = viewModel.createOffscreenRenderSurface(width: 50, height: 50, alphaMask: false)
      let id2 = viewModel.createOffscreenRenderSurface(width: 50, height: 50, alphaMask: false)
      let id3 = viewModel.createOffscreenRenderSurface(width: 50, height: 50, alphaMask: false)

      #expect(mockSurfaces.surfaceCount == 3)

      viewModel.releaseOffscreenRenderSurface(id2)

      #expect(mockSurfaces.surfaceCount == 2)
      #expect(mockSurfaces.hasSurface(forId: id1) == true)
      #expect(mockSurfaces.hasSurface(forId: id2) == false)
      #expect(mockSurfaces.hasSurface(forId: id3) == true)
    }

    @Test("surface buffer is accessible until released")
    @MainActor
    func surfaceBufferAccessibleUntilReleased() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 1.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)

      let surfaceId = viewModel.createOffscreenRenderSurface(width: 100, height: 100, alphaMask: false)

      // Buffer should be accessible.
      var buffer = mockSurfaces.getSurfaceBuffer(forId: surfaceId)
      #expect(buffer != nil)

      // Release the surface.
      viewModel.releaseOffscreenRenderSurface(surfaceId)

      // Buffer should no longer be accessible.
      buffer = mockSurfaces.getSurfaceBuffer(forId: surfaceId)
      #expect(buffer == nil)
    }
  }

  // MARK: - Integration Tests

  @Suite("Integration")
  struct IntegrationTests {

    @Test("full rendering setup flow")
    @MainActor
    func fullRenderingSetupFlow() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)
      let parentView = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))

      // 1. Set scale.
      viewModel.setOffScreenRendererSurfacesScale(scale: 2.0)

      // 2. Setup model.
      viewModel.setupModel()

      // 3. Add renderView as subview before adding constraints.
      if let renderView = viewModel.renderView {
        parentView.addSubview(renderView)
      }

      // 4. Initialize constraints.
      viewModel.initModelViewConstraints(view: parentView)

      // All components should be properly configured.
      #expect(viewModel.renderView != nil)
      #expect(mockSurfaces.scale == 2.0)
    }

    @Test("offscreen rendering flow")
    @MainActor
    func offscreenRenderingFlow() {
      let mockSurfaces = MockOffscreenRenderSurfaces()
      mockSurfaces.scale = 2.0
      let viewModel = DisplayViewModel(offscreenRenderSurfaces: mockSurfaces)
      viewModel.setupModel()

      // 1. Create surface.
      let surfaceId = viewModel.createOffscreenRenderSurface(width: 400, height: 300, alphaMask: false)
      #expect(surfaceId > 0)

      // 2. Create canvas for drawing.
      let canvas = viewModel.createOffscreenRenderCanvas(surfaceId)
      #expect(canvas != nil)

      // 3. Drawing would happen here (simulated).

      // 4. Release canvas.
      viewModel.releaseOffscreenRenderCanvas(canvas)

      // 5. Surface still available for compositing.
      #expect(mockSurfaces.hasSurface(forId: surfaceId) == true)

      // 6. When done, release surface.
      viewModel.releaseOffscreenRenderSurface(surfaceId)
      #expect(mockSurfaces.hasSurface(forId: surfaceId) == false)
    }
  }
}
