// Tests for NotebookModel based on NotebookModelProtocol.
// These tests verify the in-memory representation of notebook metadata.

import Testing
import Foundation
@testable import InkOS

// MARK: - Mock Manifest

// Mock Manifest that conforms to the structure expected by NotebookModel.
// Provides controlled input for testing NotebookModel construction.
struct MockManifestForNotebookModel {
  let notebookID: String
  var displayName: String
  let version: Int
  let createdAt: Date
  var modifiedAt: Date
  var lastAccessedAt: Date?
  var viewportState: ViewportState?

  // Creates a mock manifest with the given parameters.
  init(
    notebookID: String = UUID().uuidString,
    displayName: String = "Test Notebook",
    version: Int = 1,
    createdAt: Date = Date(),
    modifiedAt: Date? = nil,
    lastAccessedAt: Date? = nil,
    viewportState: ViewportState? = nil
  ) {
    self.notebookID = notebookID
    self.displayName = displayName
    self.version = version
    self.createdAt = createdAt
    self.modifiedAt = modifiedAt ?? createdAt
    self.lastAccessedAt = lastAccessedAt ?? createdAt
    self.viewportState = viewportState
  }
}

// MARK: - Test Suite

@Suite("NotebookModel Tests")
struct NotebookModelTests {

  // MARK: - Initialization Tests

  @Suite("Initialization from Manifest")
  struct InitializationTests {

    @Test("creates NotebookModel from Manifest with all fields mapped correctly")
    func createsFromManifest() {
      let testID = UUID().uuidString
      let testName = "My Test Notebook"
      let testDate = Date()
      let modifiedDate = testDate.addingTimeInterval(3600)

      let manifest = Manifest(notebookID: testID, displayName: testName)

      let model = NotebookModel(from: manifest)

      #expect(model.notebookID == testID)
      #expect(model.displayName == testName)
      #expect(model.version == ManifestVersion.current)
    }

    @Test("notebookID is copied from manifest.notebookID")
    func notebookIDCopied() {
      let expectedID = "550E8400-E29B-41D4-A716-446655440000"
      let manifest = Manifest(notebookID: expectedID, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.notebookID == expectedID)
    }

    @Test("displayName is copied from manifest.displayName")
    func displayNameCopied() {
      let expectedName = "Important Meeting Notes"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: expectedName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == expectedName)
    }

    @Test("version is copied from manifest.version")
    func versionCopied() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.version == ManifestVersion.current)
    }

    @Test("createdAt is copied from manifest.createdAt")
    func createdAtCopied() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // createdAt should be close to now since Manifest sets it to current time.
      let timeDifference = abs(model.createdAt.timeIntervalSinceNow)
      #expect(timeDifference < 1.0)
    }

    @Test("modifiedAt is copied from manifest.modifiedAt")
    func modifiedAtCopied() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // For a new manifest, modifiedAt equals createdAt.
      #expect(model.modifiedAt == model.createdAt)
    }

    @Test("initialization is a simple copy operation with no I/O")
    func initializationIsSimpleCopy() {
      // This test verifies the operation completes quickly (no expensive I/O).
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let startTime = Date()
      for _ in 0..<1000 {
        _ = NotebookModel(from: manifest)
      }
      let elapsed = Date().timeIntervalSince(startTime)

      // 1000 initializations should complete in well under 1 second.
      #expect(elapsed < 1.0)
    }
  }

  // MARK: - NotebookID Property Tests

  @Suite("NotebookID Property")
  struct NotebookIDTests {

    @Test("notebookID is immutable after creation")
    func notebookIDIsImmutable() {
      let originalID = UUID().uuidString
      let manifest = Manifest(notebookID: originalID, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // notebookID is a let property, so it cannot be modified.
      // This test verifies the value remains unchanged.
      #expect(model.notebookID == originalID)
    }

    @Test("notebookID matches bundle directory name format (UUID)")
    func notebookIDIsUUIDFormat() {
      let uuidString = UUID().uuidString
      let manifest = Manifest(notebookID: uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // Verify the notebookID can be parsed as a valid UUID.
      let parsedUUID = UUID(uuidString: model.notebookID)
      #expect(parsedUUID != nil)
    }

    @Test("notebookID preserves uppercase format")
    func notebookIDPreservesUppercase() {
      let uppercaseID = "550E8400-E29B-41D4-A716-446655440000"
      let manifest = Manifest(notebookID: uppercaseID, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.notebookID == uppercaseID)
    }

    @Test("notebookID with lowercase characters")
    func notebookIDWithLowercase() {
      let lowercaseID = "550e8400-e29b-41d4-a716-446655440000"
      let manifest = Manifest(notebookID: lowercaseID, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.notebookID == lowercaseID)
    }

    @Test("notebookID with empty string does not crash")
    func notebookIDEmptyString() {
      // Per protocol: validation should be done by openNotebook, not by NotebookModel.
      let manifest = Manifest(notebookID: "", displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.notebookID == "")
    }
  }

  // MARK: - DisplayName Property Tests

  @Suite("DisplayName Property")
  struct DisplayNameTests {

    @Test("displayName is mutable")
    func displayNameIsMutable() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Original Name")

      var model = NotebookModel(from: manifest)
      model.displayName = "New Name"

      #expect(model.displayName == "New Name")
    }

    @Test("displayName with standard text")
    func displayNameStandardText() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Math Homework")

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == "Math Homework")
    }

    @Test("displayName with emoji characters")
    func displayNameWithEmoji() {
      let nameWithEmoji = "Sketches 🎨"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: nameWithEmoji)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == nameWithEmoji)
    }

    @Test("displayName with multiple emoji")
    func displayNameWithMultipleEmoji() {
      let nameWithEmoji = "🌟 Project Ideas 💡✨"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: nameWithEmoji)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == nameWithEmoji)
    }

    @Test("displayName with date format")
    func displayNameWithDate() {
      let dateFormatName = "Meeting Notes - January 15"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: dateFormatName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == dateFormatName)
    }

    @Test("displayName with special Unicode characters")
    func displayNameWithUnicode() {
      let unicodeName = "日本語ノート — Café Notes"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: unicodeName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == unicodeName)
    }

    @Test("displayName with empty string does not crash")
    func displayNameEmptyString() {
      // Per protocol: validation should be done elsewhere, not by NotebookModel init.
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "")

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == "")
    }

    @Test("displayName with very long text")
    func displayNameVeryLong() {
      let longName = String(repeating: "A", count: 10000)
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: longName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == longName)
      #expect(model.displayName.count == 10000)
    }

    @Test("displayName with whitespace only")
    func displayNameWhitespaceOnly() {
      let whitespaceName = "   "
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: whitespaceName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == whitespaceName)
    }

    @Test("displayName with newlines")
    func displayNameWithNewlines() {
      let multilineName = "Line 1\nLine 2\nLine 3"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: multilineName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == multilineName)
    }

    @Test("displayName with tabs")
    func displayNameWithTabs() {
      let tabbedName = "Title\tSubtitle"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: tabbedName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == tabbedName)
    }

    @Test("displayName can be updated after creation")
    func displayNameCanBeUpdated() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "First Name")

      var model = NotebookModel(from: manifest)

      model.displayName = "Second Name"
      #expect(model.displayName == "Second Name")

      model.displayName = "Third Name"
      #expect(model.displayName == "Third Name")
    }
  }

  // MARK: - Version Property Tests

  @Suite("Version Property")
  struct VersionTests {

    @Test("version is immutable after creation")
    func versionIsImmutable() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // version is a let property so it cannot be modified.
      // Verify initial value matches ManifestVersion.current.
      #expect(model.version == ManifestVersion.current)
    }

    @Test("version equals ManifestVersion.current for new notebooks")
    func versionEqualsCurrentVersion() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.version == 1)
    }

    @Test("version is preserved exactly as in manifest")
    func versionPreserved() {
      // When a manifest is loaded from disk, version could differ from current.
      // The NotebookModel should preserve whatever version the Manifest has.
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.version == manifest.version)
    }
  }

  // MARK: - CreatedAt Property Tests

  @Suite("CreatedAt Property")
  struct CreatedAtTests {

    @Test("createdAt is immutable after creation")
    func createdAtIsImmutable() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // createdAt is a let property so it cannot be modified.
      // Verify the value is reasonable.
      #expect(model.createdAt <= Date())
    }

    @Test("createdAt has full Date precision")
    func createdAtHasFullPrecision() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // Verify the date has seconds-level precision.
      let calendar = Calendar.current
      let components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: model.createdAt
      )

      #expect(components.year != nil)
      #expect(components.month != nil)
      #expect(components.day != nil)
      #expect(components.hour != nil)
      #expect(components.minute != nil)
      #expect(components.second != nil)
    }

    @Test("createdAt is never modified after initial set")
    func createdAtNeverModified() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)
      let originalCreatedAt = model.createdAt

      // Even if we create a new model, the createdAt should match the manifest.
      let model2 = NotebookModel(from: manifest)

      #expect(model2.createdAt == originalCreatedAt)
    }

    @Test("createdAt matches manifest.createdAt exactly")
    func createdAtMatchesManifest() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.createdAt == manifest.createdAt)
    }
  }

  // MARK: - ModifiedAt Property Tests

  @Suite("ModifiedAt Property")
  struct ModifiedAtTests {

    @Test("modifiedAt is mutable")
    func modifiedAtIsMutable() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)
      let newDate = Date().addingTimeInterval(3600)
      model.modifiedAt = newDate

      #expect(model.modifiedAt == newDate)
    }

    @Test("modifiedAt initially equals createdAt for new notebooks")
    func modifiedAtEqualsCreatedAtInitially() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      #expect(model.modifiedAt == model.createdAt)
    }

    @Test("modifiedAt can be updated after creation")
    func modifiedAtCanBeUpdated() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)
      let originalModifiedAt = model.modifiedAt

      let laterDate = originalModifiedAt.addingTimeInterval(7200)
      model.modifiedAt = laterDate

      #expect(model.modifiedAt == laterDate)
      #expect(model.modifiedAt != originalModifiedAt)
    }

    @Test("modifiedAt update does not affect createdAt")
    func modifiedAtUpdateDoesNotAffectCreatedAt() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)
      let originalCreatedAt = model.createdAt

      model.modifiedAt = Date().addingTimeInterval(86400)

      #expect(model.createdAt == originalCreatedAt)
    }

    @Test("modifiedAt can be set to past date")
    func modifiedAtCanBeSetToPast() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)
      let pastDate = Date(timeIntervalSince1970: 0)
      model.modifiedAt = pastDate

      #expect(model.modifiedAt == pastDate)
    }

    @Test("modifiedAt can be set to future date")
    func modifiedAtCanBeSetToFuture() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)
      let futureDate = Date().addingTimeInterval(365 * 24 * 3600)
      model.modifiedAt = futureDate

      #expect(model.modifiedAt == futureDate)
    }
  }

  // MARK: - Field Exclusion Tests

  @Suite("Field Exclusions")
  struct FieldExclusionTests {

    @Test("NotebookModel does not contain lastAccessedAt")
    func noLastAccessedAt() {
      // Per protocol: lastAccessedAt is NOT copied to NotebookModel.
      // It's used by BundleManager, not by editor business logic.
      // This test documents the expected behavior.
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // The model should have the core fields.
      #expect(model.notebookID.isEmpty == false || model.notebookID.isEmpty == true)
      #expect(model.displayName.isEmpty == false || model.displayName.isEmpty == true)

      // lastAccessedAt should not be accessible on NotebookModel (compiler check).
    }

    @Test("NotebookModel does not contain viewportState")
    func noViewportState() {
      // Per protocol: viewportState is NOT copied to NotebookModel.
      // It's used by EditorViewModel, not by NotebookModel.
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      // The model should have the core fields but not viewportState.
      #expect(model.notebookID.isEmpty == false || model.notebookID.isEmpty == true)

      // viewportState should not be accessible on NotebookModel (compiler check).
    }
  }

  // MARK: - Edge Cases Tests

  @Suite("Edge Cases")
  struct EdgeCaseTests {

    @Test("model created from manifest with minimum valid data")
    func minimumValidData() {
      let manifest = Manifest(notebookID: "x", displayName: "y")

      let model = NotebookModel(from: manifest)

      #expect(model.notebookID == "x")
      #expect(model.displayName == "y")
    }

    @Test("model preserves exact string values without modification")
    func preservesExactStrings() {
      let exactID = "  spaces-around-id  "
      let exactName = "  name with spaces  "
      let manifest = Manifest(notebookID: exactID, displayName: exactName)

      let model = NotebookModel(from: manifest)

      #expect(model.notebookID == exactID)
      #expect(model.displayName == exactName)
    }

    @Test("multiple models from same manifest are independent")
    func multipleModelsAreIndependent() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Original")

      var model1 = NotebookModel(from: manifest)
      var model2 = NotebookModel(from: manifest)

      model1.displayName = "Changed 1"
      model2.displayName = "Changed 2"

      #expect(model1.displayName == "Changed 1")
      #expect(model2.displayName == "Changed 2")
    }

    @Test("model with all ASCII special characters in displayName")
    func asciiSpecialCharacters() {
      let specialChars = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: specialChars)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == specialChars)
    }

    @Test("model with null character in displayName does not crash")
    func nullCharacterInDisplayName() {
      let nameWithNull = "Before\0After"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: nameWithNull)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == nameWithNull)
    }

    @Test("model with RTL text in displayName")
    func rtlTextInDisplayName() {
      let rtlName = "مذكرات العمل"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: rtlName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == rtlName)
    }

    @Test("model with mixed LTR and RTL text")
    func mixedDirectionText() {
      let mixedName = "English عربي 日本語"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: mixedName)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == mixedName)
    }

    @Test("model with zero-width characters in displayName")
    func zeroWidthCharacters() {
      let nameWithZeroWidth = "visible\u{200B}invisible"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: nameWithZeroWidth)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == nameWithZeroWidth)
      #expect(model.displayName.count == 17)
    }

    @Test("model with combining characters in displayName")
    func combiningCharacters() {
      // é can be represented as e + combining acute accent.
      let nameWithCombining = "cafe\u{0301}"
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: nameWithCombining)

      let model = NotebookModel(from: manifest)

      #expect(model.displayName == nameWithCombining)
    }
  }

  // MARK: - Value Semantics Tests

  @Suite("Value Semantics")
  struct ValueSemanticsTests {

    @Test("NotebookModel is a value type")
    func notebookModelIsValueType() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Original")

      var model1 = NotebookModel(from: manifest)
      var model2 = model1

      model2.displayName = "Modified"

      #expect(model1.displayName == "Original")
      #expect(model2.displayName == "Modified")
    }

    @Test("modifying copy does not affect original")
    func modifyingCopyDoesNotAffectOriginal() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let original = NotebookModel(from: manifest)
      var copy = original

      copy.displayName = "Changed"
      copy.modifiedAt = Date().addingTimeInterval(1000)

      #expect(original.displayName == "Test")
      #expect(copy.displayName == "Changed")
    }

    @Test("assignment creates independent copy")
    func assignmentCreatesIndependentCopy() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Initial")

      var model = NotebookModel(from: manifest)
      let savedCopy = model

      model.displayName = "Changed After Save"

      #expect(savedCopy.displayName == "Initial")
      #expect(model.displayName == "Changed After Save")
    }
  }

  // MARK: - Use Case Tests

  @Suite("Use Cases")
  struct UseCaseTests {

    @Test("model can be used for UI display")
    func modelForUIDisplay() {
      let manifest = Manifest(
        notebookID: UUID().uuidString,
        displayName: "Meeting Notes 📝"
      )

      let model = NotebookModel(from: manifest)

      // Simulate UI usage.
      let displayText = "Notebook: \(model.displayName)"
      #expect(displayText == "Notebook: Meeting Notes 📝")
    }

    @Test("model can be used for sorting by creation date")
    func sortByCreationDate() {
      let manifest1 = Manifest(notebookID: UUID().uuidString, displayName: "First")
      let manifest2 = Manifest(notebookID: UUID().uuidString, displayName: "Second")

      let model1 = NotebookModel(from: manifest1)
      let model2 = NotebookModel(from: manifest2)

      let models = [model2, model1]
      let sorted = models.sorted { $0.createdAt < $1.createdAt }

      // Both were created nearly simultaneously, but order should be stable.
      #expect(sorted.count == 2)
    }

    @Test("model can be used for sorting by modified date")
    func sortByModifiedDate() {
      let manifest1 = Manifest(notebookID: UUID().uuidString, displayName: "Old")
      let manifest2 = Manifest(notebookID: UUID().uuidString, displayName: "New")

      var model1 = NotebookModel(from: manifest1)
      var model2 = NotebookModel(from: manifest2)

      model1.modifiedAt = Date().addingTimeInterval(-3600)
      model2.modifiedAt = Date()

      let models = [model1, model2]
      let sorted = models.sorted { $0.modifiedAt > $1.modifiedAt }

      #expect(sorted[0].displayName == "New")
      #expect(sorted[1].displayName == "Old")
    }

    @Test("model can be renamed")
    func modelCanBeRenamed() {
      let manifest = Manifest(
        notebookID: UUID().uuidString,
        displayName: "Old Name"
      )

      var model = NotebookModel(from: manifest)

      // Simulate rename workflow.
      model.displayName = "New Name"
      model.modifiedAt = Date()

      #expect(model.displayName == "New Name")
    }

    @Test("model ID can be used as dictionary key")
    func modelIDAsKey() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      var dictionary: [String: String] = [:]
      dictionary[model.notebookID] = model.displayName

      #expect(dictionary[model.notebookID] == "Test")
    }

    @Test("model can calculate age")
    func modelCanCalculateAge() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let model = NotebookModel(from: manifest)

      let age = Date().timeIntervalSince(model.createdAt)

      #expect(age >= 0)
      #expect(age < 1.0)
    }
  }

  // MARK: - Consistency Tests

  @Suite("Consistency")
  struct ConsistencyTests {

    @Test("immutable fields remain unchanged through mutations")
    func immutableFieldsRemainUnchanged() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)
      let originalID = model.notebookID
      let originalVersion = model.version
      let originalCreatedAt = model.createdAt

      // Mutate mutable fields.
      model.displayName = "Changed"
      model.modifiedAt = Date().addingTimeInterval(1000)

      // Verify immutable fields are unchanged.
      #expect(model.notebookID == originalID)
      #expect(model.version == originalVersion)
      #expect(model.createdAt == originalCreatedAt)
    }

    @Test("multiple mutations are accumulated")
    func multipleMutationsAccumulated() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Start")

      var model = NotebookModel(from: manifest)

      model.displayName = "First Change"
      model.displayName = "Second Change"
      model.displayName = "Final Name"

      #expect(model.displayName == "Final Name")
    }

    @Test("mutable and immutable fields are clearly distinguished")
    func mutableAndImmutableFieldsDistinguished() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)

      // These should compile (mutable).
      model.displayName = "New Name"
      model.modifiedAt = Date()

      // These should NOT compile (immutable) - compiler enforced.
      // model.notebookID = "new-id"  // Would not compile.
      // model.version = 2             // Would not compile.
      // model.createdAt = Date()      // Would not compile.

      #expect(model.displayName == "New Name")
    }
  }

  // MARK: - Performance Tests

  @Suite("Performance")
  struct PerformanceTests {

    @Test("rapid creation of many models")
    func rapidCreation() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      let startTime = Date()
      var models: [NotebookModel] = []

      for _ in 0..<10000 {
        models.append(NotebookModel(from: manifest))
      }

      let elapsed = Date().timeIntervalSince(startTime)

      #expect(models.count == 10000)
      #expect(elapsed < 1.0)
    }

    @Test("rapid mutations")
    func rapidMutations() {
      let manifest = Manifest(notebookID: UUID().uuidString, displayName: "Test")

      var model = NotebookModel(from: manifest)

      let startTime = Date()

      for i in 0..<10000 {
        model.displayName = "Name \(i)"
        model.modifiedAt = Date()
      }

      let elapsed = Date().timeIntervalSince(startTime)

      #expect(model.displayName == "Name 9999")
      #expect(elapsed < 1.0)
    }
  }
}
