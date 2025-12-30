//
// Tests for Manifest, ManifestVersion, and ViewportState based on protocol specifications.
// Covers initialization, validation, Codable conformance, edge cases, and error handling.
//

import Testing
import Foundation
@testable import InkOS

// MARK: - ManifestVersion Tests

@Suite("ManifestVersion Tests")
struct ManifestVersionTests {

  @Test("current version is 1")
  func currentVersionIsOne() {
    #expect(ManifestVersion.current == 1)
  }

  @Test("supported versions contains current version")
  func supportedContainsCurrent() {
    #expect(ManifestVersion.supported.contains(ManifestVersion.current))
  }

  @Test("supported versions contains version 1")
  func supportedContainsVersionOne() {
    #expect(ManifestVersion.supported.contains(1))
  }

  @Test("supported versions is not empty")
  func supportedIsNotEmpty() {
    #expect(!ManifestVersion.supported.isEmpty)
  }
}

// MARK: - ViewportState Tests

@Suite("ViewportState Tests")
struct ViewportStateTests {

  // MARK: - Default State Tests

  @Suite("Default State")
  struct DefaultStateTests {

    @Test("default offsetX is zero")
    func defaultOffsetXIsZero() {
      let defaultState = ViewportState.default
      #expect(defaultState.offsetX == 0.0)
    }

    @Test("default offsetY is zero")
    func defaultOffsetYIsZero() {
      let defaultState = ViewportState.default
      #expect(defaultState.offsetY == 0.0)
    }

    @Test("default scale is one")
    func defaultScaleIsOne() {
      let defaultState = ViewportState.default
      #expect(defaultState.scale == 1.0)
    }

    @Test("default state is valid")
    func defaultStateIsValid() {
      let defaultState = ViewportState.default
      #expect(defaultState.isValid())
    }
  }

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("can initialize with custom values")
    func initializeWithCustomValues() {
      let state = ViewportState(offsetX: 100.0, offsetY: 200.0, scale: 2.0)
      #expect(state.offsetX == 100.0)
      #expect(state.offsetY == 200.0)
      #expect(state.scale == 2.0)
    }

    @Test("can initialize with zero offsets")
    func initializeWithZeroOffsets() {
      let state = ViewportState(offsetX: 0.0, offsetY: 0.0, scale: 1.5)
      #expect(state.offsetX == 0.0)
      #expect(state.offsetY == 0.0)
      #expect(state.scale == 1.5)
    }

    @Test("can initialize with negative offsets")
    func initializeWithNegativeOffsets() {
      let state = ViewportState(offsetX: -5.0, offsetY: -10.0, scale: 1.0)
      #expect(state.offsetX == -5.0)
      #expect(state.offsetY == -10.0)
    }

    @Test("can initialize with large offset values")
    func initializeWithLargeOffsets() {
      let state = ViewportState(offsetX: 10000.0, offsetY: 50000.0, scale: 1.0)
      #expect(state.offsetX == 10000.0)
      #expect(state.offsetY == 50000.0)
    }
  }

  // MARK: - isValid Tests

  @Suite("Validation")
  struct ValidationTests {

    // MARK: Valid States

    @Test("valid state with default values")
    func validWithDefaultValues() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 1.0)
      #expect(state.isValid())
    }

    @Test("valid state with zoomed and scrolled values")
    func validWithZoomedAndScrolled() {
      let state = ViewportState(offsetX: 100, offsetY: 200, scale: 2.5)
      #expect(state.isValid())
    }

    @Test("valid state with negative finite offsets")
    func validWithNegativeFiniteOffsets() {
      // Negative offsets are finite and will be clamped by editor.
      let state = ViewportState(offsetX: -5, offsetY: -10, scale: 1.0)
      #expect(state.isValid())
    }

    @Test("valid state with minimum allowed scale")
    func validWithMinimumScale() {
      // Scale > 0.1 is valid.
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 0.11)
      #expect(state.isValid())
    }

    @Test("valid state with maximum allowed scale")
    func validWithMaximumScale() {
      // Scale < 10.0 is valid.
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 9.99)
      #expect(state.isValid())
    }

    @Test("valid state at typical zoom levels")
    func validAtTypicalZoomLevels() {
      let zoomLevels: [Float] = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
      for zoom in zoomLevels {
        let state = ViewportState(offsetX: 0, offsetY: 0, scale: zoom)
        #expect(state.isValid(), "Scale \(zoom) should be valid")
      }
    }

    // MARK: Invalid States - Scale

    @Test("invalid state with zero scale")
    func invalidWithZeroScale() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 0.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with negative scale")
    func invalidWithNegativeScale() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: -1.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with scale at boundary 0.1")
    func invalidWithScaleAtLowerBoundary() {
      // Scale must be > 0.1, so 0.1 exactly should be invalid.
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 0.1)
      #expect(!state.isValid())
    }

    @Test("invalid state with scale below minimum")
    func invalidWithScaleBelowMinimum() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 0.05)
      #expect(!state.isValid())
    }

    @Test("invalid state with scale at boundary 10.0")
    func invalidWithScaleAtUpperBoundary() {
      // Scale must be < 10.0, so 10.0 exactly should be invalid.
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 10.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with extreme scale above maximum")
    func invalidWithExtremeScaleAboveMax() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 15.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with very large scale")
    func invalidWithVeryLargeScale() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: 100.0)
      #expect(!state.isValid())
    }

    // MARK: Invalid States - NaN

    @Test("invalid state with NaN offsetX")
    func invalidWithNaNOffsetX() {
      let state = ViewportState(offsetX: .nan, offsetY: 0, scale: 1.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with NaN offsetY")
    func invalidWithNaNOffsetY() {
      let state = ViewportState(offsetX: 0, offsetY: .nan, scale: 1.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with NaN scale")
    func invalidWithNaNScale() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: .nan)
      #expect(!state.isValid())
    }

    @Test("invalid state with all NaN values")
    func invalidWithAllNaN() {
      let state = ViewportState(offsetX: .nan, offsetY: .nan, scale: .nan)
      #expect(!state.isValid())
    }

    // MARK: Invalid States - Infinity

    @Test("invalid state with positive infinity offsetX")
    func invalidWithPositiveInfinityOffsetX() {
      let state = ViewportState(offsetX: .infinity, offsetY: 0, scale: 1.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with negative infinity offsetX")
    func invalidWithNegativeInfinityOffsetX() {
      let state = ViewportState(offsetX: -.infinity, offsetY: 0, scale: 1.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with positive infinity offsetY")
    func invalidWithPositiveInfinityOffsetY() {
      let state = ViewportState(offsetX: 0, offsetY: .infinity, scale: 1.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with negative infinity offsetY")
    func invalidWithNegativeInfinityOffsetY() {
      let state = ViewportState(offsetX: 0, offsetY: -.infinity, scale: 1.0)
      #expect(!state.isValid())
    }

    @Test("invalid state with infinity scale")
    func invalidWithInfinityScale() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: .infinity)
      #expect(!state.isValid())
    }

    @Test("invalid state with negative infinity scale")
    func invalidWithNegativeInfinityScale() {
      let state = ViewportState(offsetX: 0, offsetY: 0, scale: -.infinity)
      #expect(!state.isValid())
    }
  }

  // MARK: - Equatable Tests

  @Suite("Equatable")
  struct EquatableTests {

    @Test("equal states are equal")
    func equalStatesAreEqual() {
      let state1 = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      let state2 = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      #expect(state1 == state2)
    }

    @Test("different offsetX makes states not equal")
    func differentOffsetXNotEqual() {
      let state1 = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      let state2 = ViewportState(offsetX: 101, offsetY: 200, scale: 2.0)
      #expect(state1 != state2)
    }

    @Test("different offsetY makes states not equal")
    func differentOffsetYNotEqual() {
      let state1 = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      let state2 = ViewportState(offsetX: 100, offsetY: 201, scale: 2.0)
      #expect(state1 != state2)
    }

    @Test("different scale makes states not equal")
    func differentScaleNotEqual() {
      let state1 = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      let state2 = ViewportState(offsetX: 100, offsetY: 200, scale: 2.1)
      #expect(state1 != state2)
    }

    @Test("default states are equal")
    func defaultStatesAreEqual() {
      let state1 = ViewportState.default
      let state2 = ViewportState.default
      #expect(state1 == state2)
    }
  }

  // MARK: - Codable Tests

  @Suite("Codable")
  struct CodableTests {

    @Test("can encode and decode viewport state")
    func encodeAndDecode() throws {
      let original = ViewportState(offsetX: 150.5, offsetY: 300.25, scale: 2.5)

      let encoder = JSONEncoder()
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode(ViewportState.self, from: data)

      #expect(decoded == original)
    }

    @Test("can encode and decode default viewport state")
    func encodeAndDecodeDefault() throws {
      let original = ViewportState.default

      let encoder = JSONEncoder()
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode(ViewportState.self, from: data)

      #expect(decoded == original)
    }

    @Test("encoded JSON contains expected keys")
    func encodedJSONHasExpectedKeys() throws {
      let state = ViewportState(offsetX: 10.0, offsetY: 20.0, scale: 1.5)

      let encoder = JSONEncoder()
      let data = try encoder.encode(state)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

      #expect(json?["offsetX"] != nil)
      #expect(json?["offsetY"] != nil)
      #expect(json?["scale"] != nil)
    }

    @Test("can decode from valid JSON string")
    func decodeFromJSONString() throws {
      let jsonString = """
        {"offsetX": 50.0, "offsetY": 100.0, "scale": 2.0}
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      let state = try decoder.decode(ViewportState.self, from: data)

      #expect(state.offsetX == 50.0)
      #expect(state.offsetY == 100.0)
      #expect(state.scale == 2.0)
    }

    @Test("decoding fails with missing offsetX")
    func decodingFailsWithMissingOffsetX() {
      let jsonString = """
        {"offsetY": 100.0, "scale": 2.0}
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(ViewportState.self, from: data)
      }
    }

    @Test("decoding fails with missing offsetY")
    func decodingFailsWithMissingOffsetY() {
      let jsonString = """
        {"offsetX": 50.0, "scale": 2.0}
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(ViewportState.self, from: data)
      }
    }

    @Test("decoding fails with missing scale")
    func decodingFailsWithMissingScale() {
      let jsonString = """
        {"offsetX": 50.0, "offsetY": 100.0}
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(ViewportState.self, from: data)
      }
    }

    @Test("decoding fails with wrong type for offsetX")
    func decodingFailsWithWrongTypeOffsetX() {
      let jsonString = """
        {"offsetX": "not a number", "offsetY": 100.0, "scale": 2.0}
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(ViewportState.self, from: data)
      }
    }

    @Test("decoding fails with malformed JSON")
    func decodingFailsWithMalformedJSON() {
      let jsonString = """
        {not valid json}
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      #expect(throws: Error.self) {
        _ = try decoder.decode(ViewportState.self, from: data)
      }
    }
  }
}

// MARK: - Manifest Tests

@Suite("Manifest Tests")
struct ManifestTests {

  // MARK: - Initialization Tests

  @Suite("Initialization")
  struct InitializationTests {

    @Test("notebookID is set from initializer")
    func notebookIDIsSet() {
      let testID = "550E8400-E29B-41D4-A716-446655440000"
      let manifest = Manifest(notebookID: testID, displayName: "Test")
      #expect(manifest.notebookID == testID)
    }

    @Test("displayName is set from initializer")
    func displayNameIsSet() {
      let manifest = Manifest(notebookID: "test-id", displayName: "My Notebook")
      #expect(manifest.displayName == "My Notebook")
    }

    @Test("version is set to current version")
    func versionIsSetToCurrent() {
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")
      #expect(manifest.version == ManifestVersion.current)
    }

    @Test("createdAt is set to approximately current time")
    func createdAtIsNow() {
      let before = Date()
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")
      let after = Date()

      #expect(manifest.createdAt >= before)
      #expect(manifest.createdAt <= after)
    }

    @Test("modifiedAt equals createdAt on initialization")
    func modifiedAtEqualsCreatedAt() {
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")
      #expect(manifest.modifiedAt == manifest.createdAt)
    }

    @Test("lastAccessedAt equals createdAt on initialization")
    func lastAccessedAtEqualsCreatedAt() {
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")
      #expect(manifest.lastAccessedAt == manifest.createdAt)
    }

    @Test("viewportState is nil on initialization")
    func viewportStateIsNilOnInit() {
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")
      #expect(manifest.viewportState == nil)
    }

    @Test("can initialize with UUID string")
    func initializeWithUUID() {
      let uuid = UUID().uuidString
      let manifest = Manifest(notebookID: uuid, displayName: "Test")
      #expect(manifest.notebookID == uuid)
    }

    @Test("can initialize with empty displayName")
    func initializeWithEmptyDisplayName() {
      let manifest = Manifest(notebookID: "test-id", displayName: "")
      #expect(manifest.displayName == "")
    }

    @Test("can initialize with emoji in displayName")
    func initializeWithEmojiDisplayName() {
      let manifest = Manifest(notebookID: "test-id", displayName: "My Notes 📝✨")
      #expect(manifest.displayName == "My Notes 📝✨")
    }

    @Test("can initialize with unicode characters in displayName")
    func initializeWithUnicodeDisplayName() {
      let manifest = Manifest(notebookID: "test-id", displayName: "日本語ノート — Draft")
      #expect(manifest.displayName == "日本語ノート — Draft")
    }

    @Test("can initialize with very long displayName")
    func initializeWithLongDisplayName() {
      let longName = String(repeating: "A", count: 10000)
      let manifest = Manifest(notebookID: "test-id", displayName: longName)
      #expect(manifest.displayName == longName)
    }

    @Test("can initialize with special characters in displayName")
    func initializeWithSpecialCharacters() {
      let specialName = "<test> & \"quotes\" 'apostrophe' /path/to/file"
      let manifest = Manifest(notebookID: "test-id", displayName: specialName)
      #expect(manifest.displayName == specialName)
    }
  }

  // MARK: - Mutability Tests

  @Suite("Mutability")
  struct MutabilityTests {

    @Test("displayName can be modified")
    func displayNameCanBeModified() {
      var manifest = Manifest(notebookID: "test-id", displayName: "Original Name")
      manifest.displayName = "Updated Name"
      #expect(manifest.displayName == "Updated Name")
    }

    @Test("modifiedAt can be modified")
    func modifiedAtCanBeModified() {
      var manifest = Manifest(notebookID: "test-id", displayName: "Test")
      let newDate = Date().addingTimeInterval(3600)
      manifest.modifiedAt = newDate
      #expect(manifest.modifiedAt == newDate)
    }

    @Test("lastAccessedAt can be modified")
    func lastAccessedAtCanBeModified() {
      var manifest = Manifest(notebookID: "test-id", displayName: "Test")
      let newDate = Date().addingTimeInterval(7200)
      manifest.lastAccessedAt = newDate
      #expect(manifest.lastAccessedAt == newDate)
    }

    @Test("lastAccessedAt can be set to nil")
    func lastAccessedAtCanBeSetToNil() {
      var manifest = Manifest(notebookID: "test-id", displayName: "Test")
      manifest.lastAccessedAt = nil
      #expect(manifest.lastAccessedAt == nil)
    }

    @Test("viewportState can be modified")
    func viewportStateCanBeModified() {
      var manifest = Manifest(notebookID: "test-id", displayName: "Test")
      let viewport = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)
      manifest.viewportState = viewport
      #expect(manifest.viewportState == viewport)
    }

    @Test("viewportState can be set to nil")
    func viewportStateCanBeSetToNil() {
      var manifest = Manifest(notebookID: "test-id", displayName: "Test")
      manifest.viewportState = ViewportState(offsetX: 50, offsetY: 100, scale: 1.5)
      manifest.viewportState = nil
      #expect(manifest.viewportState == nil)
    }
  }

  // MARK: - Codable Tests

  @Suite("Codable")
  struct CodableTests {

    @Test("can encode and decode manifest")
    func encodeAndDecode() throws {
      let original = Manifest(notebookID: "test-id-123", displayName: "My Test Notebook")

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(Manifest.self, from: data)

      #expect(decoded.notebookID == original.notebookID)
      #expect(decoded.displayName == original.displayName)
      #expect(decoded.version == original.version)
    }

    @Test("can encode and decode manifest with viewportState")
    func encodeAndDecodeWithViewport() throws {
      var original = Manifest(notebookID: "test-id", displayName: "Test")
      original.viewportState = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(Manifest.self, from: data)

      #expect(decoded.viewportState == original.viewportState)
    }

    @Test("can decode manifest without optional fields")
    func decodeWithoutOptionalFields() throws {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test Notebook",
          "version": 1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.notebookID == "test-id")
      #expect(manifest.displayName == "Test Notebook")
      #expect(manifest.lastAccessedAt == nil)
      #expect(manifest.viewportState == nil)
    }

    @Test("can decode manifest with all fields")
    func decodeWithAllFields() throws {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test Notebook",
          "version": 1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)",
          "lastAccessedAt": "\(dateString)",
          "viewportState": {
            "offsetX": 50.0,
            "offsetY": 100.0,
            "scale": 1.5
          }
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.notebookID == "test-id")
      #expect(manifest.displayName == "Test Notebook")
      #expect(manifest.lastAccessedAt != nil)
      #expect(manifest.viewportState != nil)
      #expect(manifest.viewportState?.offsetX == 50.0)
    }

    @Test("encoded JSON contains expected keys")
    func encodedJSONHasExpectedKeys() throws {
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(manifest)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

      #expect(json?["notebookID"] != nil)
      #expect(json?["displayName"] != nil)
      #expect(json?["version"] != nil)
      #expect(json?["createdAt"] != nil)
      #expect(json?["modifiedAt"] != nil)
    }

    @Test("dates are encoded in ISO 8601 format")
    func datesEncodedInISO8601() throws {
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(manifest)
      let jsonString = String(data: data, encoding: .utf8)!

      // ISO 8601 dates contain "T" and "Z".
      #expect(jsonString.contains("T"))
      #expect(jsonString.contains("Z"))
    }

    @Test("decoding fails with missing notebookID")
    func decodingFailsWithMissingNotebookID() {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "displayName": "Test",
          "version": 1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("decoding fails with missing displayName")
    func decodingFailsWithMissingDisplayName() {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "version": 1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("decoding fails with missing version")
    func decodingFailsWithMissingVersion() {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("decoding fails with missing createdAt")
    func decodingFailsWithMissingCreatedAt() {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": 1,
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("decoding fails with missing modifiedAt")
    func decodingFailsWithMissingModifiedAt() {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": 1,
          "createdAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("decoding fails with invalid date format")
    func decodingFailsWithInvalidDateFormat() {
      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": 1,
          "createdAt": "January 15, 2024",
          "modifiedAt": "January 15, 2024"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("decoding fails with wrong type for version")
    func decodingFailsWithWrongTypeVersion() {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": "one",
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: DecodingError.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("decoding fails with malformed JSON")
    func decodingFailsWithMalformedJSON() {
      let jsonString = """
        {not valid json at all}
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      #expect(throws: Error.self) {
        _ = try decoder.decode(Manifest.self, from: data)
      }
    }

    @Test("can round-trip encode/decode with special characters in displayName")
    func roundTripWithSpecialCharacters() throws {
      let original = Manifest(notebookID: "test-id", displayName: "Test <>&\"' 日本語 🎉")

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(original)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(Manifest.self, from: data)

      #expect(decoded.displayName == original.displayName)
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("manifest with empty notebookID can be created")
    func emptyNotebookID() {
      let manifest = Manifest(notebookID: "", displayName: "Test")
      #expect(manifest.notebookID == "")
    }

    @Test("manifest with whitespace-only displayName")
    func whitespaceDisplayName() {
      let manifest = Manifest(notebookID: "test-id", displayName: "   ")
      #expect(manifest.displayName == "   ")
    }

    @Test("manifest with newlines in displayName")
    func newlinesInDisplayName() {
      let manifest = Manifest(notebookID: "test-id", displayName: "Line 1\nLine 2\nLine 3")
      #expect(manifest.displayName.contains("\n"))
    }

    @Test("manifest with tabs in displayName")
    func tabsInDisplayName() {
      let manifest = Manifest(notebookID: "test-id", displayName: "Tab\tSeparated")
      #expect(manifest.displayName.contains("\t"))
    }

    @Test("created multiple manifests have different timestamps")
    func multipleManifestsHaveDifferentTimestamps() async throws {
      let manifest1 = Manifest(notebookID: "id1", displayName: "First")

      // Small delay to ensure timestamps differ.
      try await Task.sleep(nanoseconds: 1_000_000)

      let manifest2 = Manifest(notebookID: "id2", displayName: "Second")

      #expect(manifest1.createdAt != manifest2.createdAt)
    }

    @Test("manifest preserves floating point precision in viewport")
    func floatingPointPrecision() throws {
      var manifest = Manifest(notebookID: "test-id", displayName: "Test")
      manifest.viewportState = ViewportState(offsetX: 123.456789, offsetY: 987.654321, scale: 2.5)

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(manifest)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let decoded = try decoder.decode(Manifest.self, from: data)

      // Float precision may result in small differences, so check approximately.
      let tolerance: Float = 0.0001
      #expect(abs(decoded.viewportState!.offsetX - 123.456789) < tolerance)
      #expect(abs(decoded.viewportState!.offsetY - 987.654321) < tolerance)
    }

    @Test("manifest with version 0 can be decoded")
    func versionZeroDecodes() throws {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": 0,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.version == 0)
    }

    @Test("manifest with negative version can be decoded")
    func negativeVersionDecodes() throws {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": -1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.version == -1)
    }

    @Test("manifest with future version can be decoded")
    func futureVersionDecodes() throws {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": 999,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.version == 999)
    }

    @Test("manifest handles dates in the distant past")
    func distantPastDates() throws {
      let pastDate = Date(timeIntervalSince1970: 0) // Jan 1, 1970
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: pastDate)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Ancient Notebook",
          "version": 1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.createdAt == pastDate)
    }

    @Test("manifest handles dates in the distant future")
    func distantFutureDates() throws {
      let futureDate = Date(timeIntervalSince1970: 4102444800) // Jan 1, 2100
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: futureDate)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Future Notebook",
          "version": 1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)"
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.createdAt == futureDate)
    }

    @Test("additional unknown fields in JSON are ignored")
    func unknownFieldsIgnored() throws {
      let now = Date()
      let isoFormatter = ISO8601DateFormatter()
      let dateString = isoFormatter.string(from: now)

      let jsonString = """
        {
          "notebookID": "test-id",
          "displayName": "Test",
          "version": 1,
          "createdAt": "\(dateString)",
          "modifiedAt": "\(dateString)",
          "unknownField": "should be ignored",
          "anotherUnknownField": 12345
        }
        """
      let data = jsonString.data(using: .utf8)!

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let manifest = try decoder.decode(Manifest.self, from: data)

      #expect(manifest.notebookID == "test-id")
    }
  }

  // MARK: - Sendable Tests

  @Suite("Sendable")
  struct SendableTests {

    @Test("manifest can be passed across actor boundaries")
    func canPassAcrossActorBoundaries() async {
      let manifest = Manifest(notebookID: "test-id", displayName: "Test")

      // Simulates passing to another actor.
      let passedManifest = await Task.detached {
        return manifest
      }.value

      #expect(passedManifest.notebookID == manifest.notebookID)
      #expect(passedManifest.displayName == manifest.displayName)
    }

    @Test("viewportState can be passed across actor boundaries")
    func viewportCanPassAcrossActorBoundaries() async {
      let state = ViewportState(offsetX: 100, offsetY: 200, scale: 2.0)

      let passedState = await Task.detached {
        return state
      }.value

      #expect(passedState == state)
    }
  }
}
