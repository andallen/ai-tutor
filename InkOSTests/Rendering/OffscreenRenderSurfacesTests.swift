//
// Tests for OffscreenRenderSurfaces based on the protocol contract.
// Covers surface management, ID generation, scale factor, and edge cases.
//

import Testing
import UIKit
@testable import InkOS

// MARK: - Test Helpers

// Helper function to create a CGLayer for testing purposes.
// Returns nil if creation fails.
@MainActor
private func createTestCGLayer(width: Int = 100, height: Int = 100) -> CGLayer? {
  UIGraphicsBeginImageContext(CGSize(width: width, height: height))
  defer { UIGraphicsEndImageContext() }

  guard let context = UIGraphicsGetCurrentContext() else {
    return nil
  }

  return CGLayer(context, size: CGSize(width: width, height: height), auxiliaryInfo: nil)
}

// MARK: - Test Suite

@Suite("OffscreenRenderSurfaces Tests")
struct OffscreenRenderSurfacesTests {

  // MARK: - Scale Property Tests

  @Suite("Scale Property")
  struct ScalePropertyTests {

    @Test("scale can be set and retrieved")
    @MainActor
    func scaleSetAndRetrieved() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 2.0

      #expect(surfaces.scale == 2.0)
    }

    @Test("scale defaults to a valid value")
    @MainActor
    func scaleDefaultsToValidValue() {
      let surfaces = OffscreenRenderSurfaces()

      // Default scale should be a reasonable value (1.0 or screen scale).
      #expect(surfaces.scale >= 1.0)
    }

    @Test("scale can be set to 1.0 for standard resolution")
    @MainActor
    func scaleStandardResolution() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 1.0

      #expect(surfaces.scale == 1.0)
    }

    @Test("scale can be set to 2.0 for Retina resolution")
    @MainActor
    func scaleRetinaResolution() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 2.0

      #expect(surfaces.scale == 2.0)
    }

    @Test("scale can be set to 3.0 for Super Retina resolution")
    @MainActor
    func scaleSuperRetinaResolution() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 3.0

      #expect(surfaces.scale == 3.0)
    }

    @Test("scale can be changed multiple times")
    @MainActor
    func scaleChangedMultipleTimes() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 1.0
      #expect(surfaces.scale == 1.0)

      surfaces.scale = 2.0
      #expect(surfaces.scale == 2.0)

      surfaces.scale = 3.0
      #expect(surfaces.scale == 3.0)
    }

    @Test("scale with fractional value")
    @MainActor
    func scaleFractionalValue() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 1.5

      #expect(surfaces.scale == 1.5)
    }

    @Test("scale with zero value")
    @MainActor
    func scaleZeroValue() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 0.0

      // Zero scale may not be practical but should be storable.
      #expect(surfaces.scale == 0.0)
    }

    @Test("scale with negative value")
    @MainActor
    func scaleNegativeValue() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = -1.0

      // Negative scale may not be practical but should be storable.
      #expect(surfaces.scale == -1.0)
    }
  }

  // MARK: - Add Surface Tests

  @Suite("Add Surface")
  struct AddSurfaceTests {

    @Test("addSurface returns a non-zero ID")
    @MainActor
    func addSurfaceReturnsNonZeroID() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)

      // ID 0 is reserved for creation failure, so valid IDs should be >= 1.
      #expect(id >= 1)
    }

    @Test("addSurface returns sequential IDs starting from 1")
    @MainActor
    func addSurfaceSequentialIDs() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer1 = createTestCGLayer(),
            let layer2 = createTestCGLayer(),
            let layer3 = createTestCGLayer() else {
        Issue.record("Failed to create CGLayers for test")
        return
      }

      let id1 = surfaces.addSurface(with: layer1)
      let id2 = surfaces.addSurface(with: layer2)
      let id3 = surfaces.addSurface(with: layer3)

      // IDs should be sequential starting from 1.
      #expect(id1 == 1)
      #expect(id2 == 2)
      #expect(id3 == 3)
    }

    @Test("addSurface generates unique IDs")
    @MainActor
    func addSurfaceUniqueIDs() {
      let surfaces = OffscreenRenderSurfaces()
      var ids: Set<UInt32> = []

      // Add multiple surfaces and verify all IDs are unique.
      for _ in 0..<100 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        let id = surfaces.addSurface(with: layer)
        #expect(!ids.contains(id), "Duplicate ID generated: \(id)")
        ids.insert(id)
      }

      #expect(ids.count == 100)
    }

    @Test("addSurface IDs are never reused after release")
    @MainActor
    func addSurfaceIDsNeverReused() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer1 = createTestCGLayer(),
            let layer2 = createTestCGLayer() else {
        Issue.record("Failed to create CGLayers for test")
        return
      }

      let id1 = surfaces.addSurface(with: layer1)
      surfaces.releaseSurface(forId: id1)

      let id2 = surfaces.addSurface(with: layer2)

      // ID2 should not reuse the released ID1.
      #expect(id2 != id1)
      #expect(id2 > id1)
    }

    @Test("addSurface stores the buffer correctly")
    @MainActor
    func addSurfaceStoresBuffer() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)
      let retrievedBuffer = surfaces.getSurfaceBuffer(forId: id)

      #expect(retrievedBuffer != nil)
    }

    @Test("addSurface with different sized layers")
    @MainActor
    func addSurfaceDifferentSizes() {
      let surfaces = OffscreenRenderSurfaces()

      guard let smallLayer = createTestCGLayer(width: 10, height: 10),
            let mediumLayer = createTestCGLayer(width: 500, height: 500),
            let largeLayer = createTestCGLayer(width: 2000, height: 2000) else {
        Issue.record("Failed to create CGLayers for test")
        return
      }

      let id1 = surfaces.addSurface(with: smallLayer)
      let id2 = surfaces.addSurface(with: mediumLayer)
      let id3 = surfaces.addSurface(with: largeLayer)

      #expect(id1 >= 1)
      #expect(id2 >= 1)
      #expect(id3 >= 1)

      // All should be retrievable.
      #expect(surfaces.getSurfaceBuffer(forId: id1) != nil)
      #expect(surfaces.getSurfaceBuffer(forId: id2) != nil)
      #expect(surfaces.getSurfaceBuffer(forId: id3) != nil)
    }

    @Test("addSurface with many surfaces")
    @MainActor
    func addSurfaceManyItems() {
      let surfaces = OffscreenRenderSurfaces()
      var ids: [UInt32] = []

      // Add a larger number of surfaces.
      for _ in 0..<500 {
        guard let layer = createTestCGLayer(width: 50, height: 50) else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        let id = surfaces.addSurface(with: layer)
        ids.append(id)
      }

      // All IDs should be valid and unique.
      #expect(Set(ids).count == 500)

      // All surfaces should be retrievable.
      for id in ids {
        #expect(surfaces.getSurfaceBuffer(forId: id) != nil)
      }
    }
  }

  // MARK: - Get Surface Buffer Tests

  @Suite("Get Surface Buffer")
  struct GetSurfaceBufferTests {

    @Test("getSurfaceBuffer returns buffer for valid ID")
    @MainActor
    func getSurfaceBufferValidID() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)
      let buffer = surfaces.getSurfaceBuffer(forId: id)

      #expect(buffer != nil)
    }

    @Test("getSurfaceBuffer returns nil for ID 0")
    @MainActor
    func getSurfaceBufferIDZero() {
      let surfaces = OffscreenRenderSurfaces()

      let buffer = surfaces.getSurfaceBuffer(forId: 0)

      // ID 0 is invalid and should return nil.
      #expect(buffer == nil)
    }

    @Test("getSurfaceBuffer returns nil for invalid ID")
    @MainActor
    func getSurfaceBufferInvalidID() {
      let surfaces = OffscreenRenderSurfaces()

      // No surfaces added yet, so any ID should be invalid.
      let buffer = surfaces.getSurfaceBuffer(forId: 999)

      #expect(buffer == nil)
    }

    @Test("getSurfaceBuffer returns nil for never-assigned ID")
    @MainActor
    func getSurfaceBufferNeverAssignedID() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      _ = surfaces.addSurface(with: layer) // ID 1

      // ID 100 was never assigned.
      let buffer = surfaces.getSurfaceBuffer(forId: 100)

      #expect(buffer == nil)
    }

    @Test("getSurfaceBuffer returns nil for released surface")
    @MainActor
    func getSurfaceBufferReleasedSurface() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)
      surfaces.releaseSurface(forId: id)

      let buffer = surfaces.getSurfaceBuffer(forId: id)

      #expect(buffer == nil)
    }

    @Test("getSurfaceBuffer returns correct buffer for each ID")
    @MainActor
    func getSurfaceBufferCorrectBuffer() {
      let surfaces = OffscreenRenderSurfaces()

      guard let layer1 = createTestCGLayer(width: 100, height: 100),
            let layer2 = createTestCGLayer(width: 200, height: 200),
            let layer3 = createTestCGLayer(width: 300, height: 300) else {
        Issue.record("Failed to create CGLayers for test")
        return
      }

      let id1 = surfaces.addSurface(with: layer1)
      let id2 = surfaces.addSurface(with: layer2)
      let id3 = surfaces.addSurface(with: layer3)

      let buffer1 = surfaces.getSurfaceBuffer(forId: id1)
      let buffer2 = surfaces.getSurfaceBuffer(forId: id2)
      let buffer3 = surfaces.getSurfaceBuffer(forId: id3)

      // Each buffer should have the correct size.
      #expect(buffer1?.size == CGSize(width: 100, height: 100))
      #expect(buffer2?.size == CGSize(width: 200, height: 200))
      #expect(buffer3?.size == CGSize(width: 300, height: 300))
    }

    @Test("getSurfaceBuffer can be called multiple times for same ID")
    @MainActor
    func getSurfaceBufferMultipleCalls() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)

      // Multiple calls should return the same buffer.
      for _ in 0..<10 {
        let buffer = surfaces.getSurfaceBuffer(forId: id)
        #expect(buffer != nil)
      }
    }

    @Test("getSurfaceBuffer with UInt32.max ID")
    @MainActor
    func getSurfaceBufferMaxUInt32ID() {
      let surfaces = OffscreenRenderSurfaces()

      let buffer = surfaces.getSurfaceBuffer(forId: UInt32.max)

      // UInt32.max should return nil as it was never assigned.
      #expect(buffer == nil)
    }
  }

  // MARK: - Release Surface Tests

  @Suite("Release Surface")
  struct ReleaseSurfaceTests {

    @Test("releaseSurface removes surface from cache")
    @MainActor
    func releaseSurfaceRemovesFromCache() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)
      #expect(surfaces.getSurfaceBuffer(forId: id) != nil)

      surfaces.releaseSurface(forId: id)

      #expect(surfaces.getSurfaceBuffer(forId: id) == nil)
    }

    @Test("releaseSurface is safe for invalid ID")
    @MainActor
    func releaseSurfaceSafeForInvalidID() {
      let surfaces = OffscreenRenderSurfaces()

      // Should not crash with invalid ID.
      surfaces.releaseSurface(forId: 999)

      // Test passes if no crash.
    }

    @Test("releaseSurface is safe for ID 0")
    @MainActor
    func releaseSurfaceSafeForIDZero() {
      let surfaces = OffscreenRenderSurfaces()

      // Should not crash with ID 0.
      surfaces.releaseSurface(forId: 0)

      // Test passes if no crash.
    }

    @Test("releaseSurface double release is safe (no-op)")
    @MainActor
    func releaseSurfaceDoubleRelease() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)
      surfaces.releaseSurface(forId: id)

      // Second release should be a no-op and not crash.
      surfaces.releaseSurface(forId: id)

      // Third release should also be safe.
      surfaces.releaseSurface(forId: id)

      // Surface should still be gone.
      #expect(surfaces.getSurfaceBuffer(forId: id) == nil)
    }

    @Test("releaseSurface does not affect other surfaces")
    @MainActor
    func releaseSurfaceDoesNotAffectOthers() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer1 = createTestCGLayer(),
            let layer2 = createTestCGLayer(),
            let layer3 = createTestCGLayer() else {
        Issue.record("Failed to create CGLayers for test")
        return
      }

      let id1 = surfaces.addSurface(with: layer1)
      let id2 = surfaces.addSurface(with: layer2)
      let id3 = surfaces.addSurface(with: layer3)

      surfaces.releaseSurface(forId: id2)

      // ID1 and ID3 should still be available.
      #expect(surfaces.getSurfaceBuffer(forId: id1) != nil)
      #expect(surfaces.getSurfaceBuffer(forId: id2) == nil)
      #expect(surfaces.getSurfaceBuffer(forId: id3) != nil)
    }

    @Test("releaseSurface can release surfaces in any order")
    @MainActor
    func releaseSurfaceAnyOrder() {
      let surfaces = OffscreenRenderSurfaces()
      var ids: [UInt32] = []

      for _ in 0..<10 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        ids.append(surfaces.addSurface(with: layer))
      }

      // Release in reverse order.
      for id in ids.reversed() {
        surfaces.releaseSurface(forId: id)
        #expect(surfaces.getSurfaceBuffer(forId: id) == nil)
      }
    }

    @Test("releaseSurface with UInt32.max ID")
    @MainActor
    func releaseSurfaceMaxUInt32ID() {
      let surfaces = OffscreenRenderSurfaces()

      // Should not crash.
      surfaces.releaseSurface(forId: UInt32.max)

      // Test passes if no crash.
    }

    @Test("releaseSurface releases multiple surfaces")
    @MainActor
    func releaseSurfaceMultiple() {
      let surfaces = OffscreenRenderSurfaces()
      var ids: [UInt32] = []

      for _ in 0..<50 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        ids.append(surfaces.addSurface(with: layer))
      }

      // Release every other surface.
      for (index, id) in ids.enumerated() where index % 2 == 0 {
        surfaces.releaseSurface(forId: id)
      }

      // Verify correct surfaces are released.
      for (index, id) in ids.enumerated() {
        if index % 2 == 0 {
          #expect(surfaces.getSurfaceBuffer(forId: id) == nil)
        } else {
          #expect(surfaces.getSurfaceBuffer(forId: id) != nil)
        }
      }
    }
  }

  // MARK: - ID Generation Tests

  @Suite("ID Generation")
  struct IDGenerationTests {

    @Test("first ID is 1, not 0")
    @MainActor
    func firstIDIsOne() {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)

      #expect(id == 1)
    }

    @Test("IDs increment by 1")
    @MainActor
    func idsIncrementByOne() {
      let surfaces = OffscreenRenderSurfaces()

      for expected in 1...10 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        let id = surfaces.addSurface(with: layer)
        #expect(id == UInt32(expected))
      }
    }

    @Test("IDs continue incrementing after release")
    @MainActor
    func idsContinueAfterRelease() {
      let surfaces = OffscreenRenderSurfaces()

      guard let layer1 = createTestCGLayer(),
            let layer2 = createTestCGLayer(),
            let layer3 = createTestCGLayer() else {
        Issue.record("Failed to create CGLayers for test")
        return
      }

      let id1 = surfaces.addSurface(with: layer1) // 1
      let id2 = surfaces.addSurface(with: layer2) // 2

      surfaces.releaseSurface(forId: id1)
      surfaces.releaseSurface(forId: id2)

      let id3 = surfaces.addSurface(with: layer3) // 3 (not 1)

      #expect(id3 == 3)
    }

    @Test("ID 0 is never assigned")
    @MainActor
    func idZeroNeverAssigned() {
      let surfaces = OffscreenRenderSurfaces()
      var ids: [UInt32] = []

      for _ in 0..<100 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        ids.append(surfaces.addSurface(with: layer))
      }

      #expect(!ids.contains(0))
    }
  }

  // MARK: - Thread Safety Tests

  @Suite("Thread Safety")
  struct ThreadSafetyTests {

    @Test("concurrent addSurface calls produce unique IDs")
    @MainActor
    func concurrentAddSurfaceUniqueIDs() async {
      let surfaces = OffscreenRenderSurfaces()
      let idsLock = NSLock()
      var allIds: [UInt32] = []

      await withTaskGroup(of: UInt32?.self) { group in
        for _ in 0..<100 {
          group.addTask { @MainActor in
            guard let layer = createTestCGLayer() else {
              return nil
            }
            return surfaces.addSurface(with: layer)
          }
        }

        for await id in group {
          if let id = id {
            idsLock.lock()
            allIds.append(id)
            idsLock.unlock()
          }
        }
      }

      // All IDs should be unique.
      #expect(Set(allIds).count == allIds.count)
    }

    @Test("concurrent getSurfaceBuffer calls are safe")
    @MainActor
    func concurrentGetSurfaceBufferSafe() async {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)

      await withTaskGroup(of: Bool.self) { group in
        for _ in 0..<100 {
          group.addTask { @MainActor in
            return surfaces.getSurfaceBuffer(forId: id) != nil
          }
        }

        for await result in group {
          #expect(result == true)
        }
      }
    }

    @Test("concurrent releaseSurface calls are safe")
    @MainActor
    func concurrentReleaseSurfaceSafe() async {
      let surfaces = OffscreenRenderSurfaces()
      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)

      await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
          group.addTask { @MainActor in
            surfaces.releaseSurface(forId: id)
          }
        }
      }

      // Surface should be released.
      #expect(surfaces.getSurfaceBuffer(forId: id) == nil)
    }

    @Test("mixed concurrent operations are safe")
    @MainActor
    func mixedConcurrentOperations() async {
      let surfaces = OffscreenRenderSurfaces()

      await withTaskGroup(of: Void.self) { group in
        // Add surfaces concurrently.
        for _ in 0..<50 {
          group.addTask { @MainActor in
            guard let layer = createTestCGLayer() else { return }
            _ = surfaces.addSurface(with: layer)
          }
        }

        // Get surface buffers concurrently.
        for id in 1...50 {
          group.addTask { @MainActor in
            _ = surfaces.getSurfaceBuffer(forId: UInt32(id))
          }
        }

        // Release surfaces concurrently.
        for id in 1...25 {
          group.addTask { @MainActor in
            surfaces.releaseSurface(forId: UInt32(id))
          }
        }
      }

      // Test passes if no crash or deadlock.
    }
  }

  // MARK: - Memory Management Tests

  @Suite("Memory Management")
  struct MemoryManagementTests {

    @Test("adding and releasing surfaces does not leak")
    @MainActor
    func addReleaseNoLeak() {
      let surfaces = OffscreenRenderSurfaces()

      // Add and release many surfaces.
      for _ in 0..<100 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        let id = surfaces.addSurface(with: layer)
        surfaces.releaseSurface(forId: id)
      }

      // After releasing all, getting any ID should return nil.
      for id in 1..<100 {
        #expect(surfaces.getSurfaceBuffer(forId: UInt32(id)) == nil)
      }
    }

    @Test("surfaces with large dimensions can be added")
    @MainActor
    func largeDimensionSurfaces() {
      let surfaces = OffscreenRenderSurfaces()
      guard let largeLayer = createTestCGLayer(width: 4096, height: 4096) else {
        Issue.record("Failed to create large CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: largeLayer)

      #expect(id >= 1)
      #expect(surfaces.getSurfaceBuffer(forId: id) != nil)

      // Clean up.
      surfaces.releaseSurface(forId: id)
    }
  }

  // MARK: - Integration Tests

  @Suite("Integration")
  struct IntegrationTests {

    @Test("complete lifecycle: add, retrieve, use, release")
    @MainActor
    func completeLifecycle() {
      let surfaces = OffscreenRenderSurfaces()
      surfaces.scale = 2.0

      guard let layer = createTestCGLayer(width: 400, height: 300) else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      // 1. Add surface.
      let id = surfaces.addSurface(with: layer)
      #expect(id >= 1)

      // 2. Retrieve surface.
      let buffer = surfaces.getSurfaceBuffer(forId: id)
      #expect(buffer != nil)

      // 3. Surface can be retrieved multiple times.
      let buffer2 = surfaces.getSurfaceBuffer(forId: id)
      #expect(buffer2 != nil)

      // 4. Release surface.
      surfaces.releaseSurface(forId: id)

      // 5. Surface is no longer available.
      let buffer3 = surfaces.getSurfaceBuffer(forId: id)
      #expect(buffer3 == nil)

      // 6. Double release is safe.
      surfaces.releaseSurface(forId: id)
    }

    @Test("multiple surfaces lifecycle")
    @MainActor
    func multipleSurfacesLifecycle() {
      let surfaces = OffscreenRenderSurfaces()
      surfaces.scale = UIScreen.main.scale

      var ids: [UInt32] = []

      // Add multiple surfaces.
      for i in 1...5 {
        guard let layer = createTestCGLayer(width: i * 100, height: i * 100) else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        ids.append(surfaces.addSurface(with: layer))
      }

      // All should be retrievable.
      for id in ids {
        #expect(surfaces.getSurfaceBuffer(forId: id) != nil)
      }

      // Release some.
      surfaces.releaseSurface(forId: ids[0])
      surfaces.releaseSurface(forId: ids[2])
      surfaces.releaseSurface(forId: ids[4])

      // Check availability.
      #expect(surfaces.getSurfaceBuffer(forId: ids[0]) == nil)
      #expect(surfaces.getSurfaceBuffer(forId: ids[1]) != nil)
      #expect(surfaces.getSurfaceBuffer(forId: ids[2]) == nil)
      #expect(surfaces.getSurfaceBuffer(forId: ids[3]) != nil)
      #expect(surfaces.getSurfaceBuffer(forId: ids[4]) == nil)

      // Release remaining.
      surfaces.releaseSurface(forId: ids[1])
      surfaces.releaseSurface(forId: ids[3])

      // All should be gone.
      for id in ids {
        #expect(surfaces.getSurfaceBuffer(forId: id) == nil)
      }
    }

    @Test("scale affects intended usage not storage")
    @MainActor
    func scaleAffectsUsageNotStorage() {
      let surfaces = OffscreenRenderSurfaces()
      surfaces.scale = 3.0

      guard let layer = createTestCGLayer(width: 100, height: 100) else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)

      // Scale property should be readable.
      #expect(surfaces.scale == 3.0)

      // Surface should still be added and retrievable regardless of scale.
      let buffer = surfaces.getSurfaceBuffer(forId: id)
      #expect(buffer != nil)
    }

    @Test("fresh instance has no surfaces")
    @MainActor
    func freshInstanceNoSurfaces() {
      let surfaces = OffscreenRenderSurfaces()

      // No surfaces have been added, so all IDs should return nil.
      for id in 0..<100 {
        #expect(surfaces.getSurfaceBuffer(forId: UInt32(id)) == nil)
      }
    }

    @Test("interleaved add and release operations")
    @MainActor
    func interleavedOperations() {
      let surfaces = OffscreenRenderSurfaces()

      guard let layer1 = createTestCGLayer(),
            let layer2 = createTestCGLayer(),
            let layer3 = createTestCGLayer(),
            let layer4 = createTestCGLayer() else {
        Issue.record("Failed to create CGLayers for test")
        return
      }

      let id1 = surfaces.addSurface(with: layer1) // 1
      let id2 = surfaces.addSurface(with: layer2) // 2

      surfaces.releaseSurface(forId: id1)

      let id3 = surfaces.addSurface(with: layer3) // 3

      #expect(surfaces.getSurfaceBuffer(forId: id1) == nil)
      #expect(surfaces.getSurfaceBuffer(forId: id2) != nil)
      #expect(surfaces.getSurfaceBuffer(forId: id3) != nil)

      surfaces.releaseSurface(forId: id3)

      let id4 = surfaces.addSurface(with: layer4) // 4

      #expect(id4 == 4)
      #expect(surfaces.getSurfaceBuffer(forId: id4) != nil)
    }
  }

  // MARK: - Edge Case Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("release then add then get sequence")
    @MainActor
    func releaseThenAddThenGet() {
      let surfaces = OffscreenRenderSurfaces()

      // Release on empty is safe.
      surfaces.releaseSurface(forId: 1)

      guard let layer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let id = surfaces.addSurface(with: layer)
      let buffer = surfaces.getSurfaceBuffer(forId: id)

      #expect(buffer != nil)
    }

    @Test("get on empty surfaces returns nil")
    @MainActor
    func getOnEmptyReturnsNil() {
      let surfaces = OffscreenRenderSurfaces()

      for id in 0..<1000 {
        #expect(surfaces.getSurfaceBuffer(forId: UInt32(id)) == nil)
      }
    }

    @Test("release all then add new")
    @MainActor
    func releaseAllThenAddNew() {
      let surfaces = OffscreenRenderSurfaces()
      var ids: [UInt32] = []

      // Add 10 surfaces.
      for _ in 0..<10 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        ids.append(surfaces.addSurface(with: layer))
      }

      // Release all.
      for id in ids {
        surfaces.releaseSurface(forId: id)
      }

      // Add new surface.
      guard let newLayer = createTestCGLayer() else {
        Issue.record("Failed to create CGLayer for test")
        return
      }

      let newId = surfaces.addSurface(with: newLayer)

      // New ID should continue from where it left off.
      #expect(newId == 11)
      #expect(surfaces.getSurfaceBuffer(forId: newId) != nil)
    }

    @Test("rapid add-release cycles")
    @MainActor
    func rapidAddReleaseCycles() {
      let surfaces = OffscreenRenderSurfaces()

      for i in 1...100 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }

        let id = surfaces.addSurface(with: layer)
        #expect(id == UInt32(i))

        surfaces.releaseSurface(forId: id)
        #expect(surfaces.getSurfaceBuffer(forId: id) == nil)
      }
    }

    @Test("scale can be very large")
    @MainActor
    func scaleVeryLarge() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 100.0

      #expect(surfaces.scale == 100.0)
    }

    @Test("scale can be very small")
    @MainActor
    func scaleVerySmall() {
      let surfaces = OffscreenRenderSurfaces()

      surfaces.scale = 0.001

      #expect(surfaces.scale == 0.001)
    }

    @Test("operations after many releases")
    @MainActor
    func operationsAfterManyReleases() {
      let surfaces = OffscreenRenderSurfaces()

      // Add 50 surfaces.
      for _ in 0..<50 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        _ = surfaces.addSurface(with: layer)
      }

      // Release all with IDs 1-50.
      for id in 1...50 {
        surfaces.releaseSurface(forId: UInt32(id))
      }

      // Add another 50 surfaces.
      for i in 51...100 {
        guard let layer = createTestCGLayer() else {
          Issue.record("Failed to create CGLayer for test")
          return
        }
        let id = surfaces.addSurface(with: layer)
        #expect(id == UInt32(i))
      }

      // Old IDs should still be nil.
      for id in 1...50 {
        #expect(surfaces.getSurfaceBuffer(forId: UInt32(id)) == nil)
      }

      // New IDs should be valid.
      for id in 51...100 {
        #expect(surfaces.getSurfaceBuffer(forId: UInt32(id)) != nil)
      }
    }
  }
}
