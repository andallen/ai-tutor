// swiftlint:disable file_length
// This file contains comprehensive test coverage for RawContentConfiguration,
// including all acceptance criteria and edge cases specified in the contract.
// The file length is necessary to maintain test organization and readability.

import Testing

@testable import InkOS

// MARK: - Mock ExtendedConfiguration

/// Mock implementation of ExtendedConfigurationProtocol for testing.
/// Records all method calls with keys and values to verify correct configuration application.
final class MockExtendedConfiguration: ExtendedConfigurationProtocol {

  // Records all setConfigString calls with key and value.
  var stringCalls: [(key: String, value: String)] = []

  // Records all setConfigStringArray calls with key and value.
  var stringArrayCalls: [(key: String, value: [String])] = []

  // Records all setConfigBoolean calls with key and value.
  var booleanCalls: [(key: String, value: Bool)] = []

  // Records all setConfigNumber calls with key and value.
  var numberCalls: [(key: String, value: Double)] = []

  // Error to throw for setConfigString calls matching specific keys.
  var stringErrorsByKey: [String: Error] = [:]

  // Error to throw for setConfigStringArray calls matching specific keys.
  var stringArrayErrorsByKey: [String: Error] = [:]

  // Error to throw for setConfigBoolean calls matching specific keys.
  var booleanErrorsByKey: [String: Error] = [:]

  // Error to throw for setConfigNumber calls matching specific keys.
  var numberErrorsByKey: [String: Error] = [:]

  func setConfigString(_ value: String, forKey key: String) throws {
    stringCalls.append((key: key, value: value))
    if let error = stringErrorsByKey[key] {
      throw error
    }
  }

  func setConfigStringArray(_ value: [String], forKey key: String) throws {
    stringArrayCalls.append((key: key, value: value))
    if let error = stringArrayErrorsByKey[key] {
      throw error
    }
  }

  func setConfigBoolean(_ value: Bool, forKey key: String) throws {
    booleanCalls.append((key: key, value: value))
    if let error = booleanErrorsByKey[key] {
      throw error
    }
  }

  func setConfigNumber(_ value: Double, forKey key: String) throws {
    numberCalls.append((key: key, value: value))
    if let error = numberErrorsByKey[key] {
      throw error
    }
  }

  // Helper to find a string call by key.
  func stringCall(forKey key: String) -> (key: String, value: String)? {
    return stringCalls.first { $0.key == key }
  }

  // Helper to find a string array call by key.
  func stringArrayCall(forKey key: String) -> (key: String, value: [String])? {
    return stringArrayCalls.first { $0.key == key }
  }

  // Helper to find a boolean call by key.
  func booleanCall(forKey key: String) -> (key: String, value: Bool)? {
    return booleanCalls.first { $0.key == key }
  }

  // Helper to count calls for a specific key.
  func callCount(forStringKey key: String) -> Int {
    return stringCalls.filter { $0.key == key }.count
  }

  func callCount(forStringArrayKey key: String) -> Int {
    return stringArrayCalls.filter { $0.key == key }.count
  }

  func callCount(forBooleanKey key: String) -> Int {
    return booleanCalls.filter { $0.key == key }.count
  }
}

// MARK: - Test Error Type

/// Custom error type for testing error propagation.
struct TestConfigurationError: Error, Equatable {
  let message: String
}

// MARK: - Default Configuration Tests

/// Tests for DefaultRawContentConfigurationProvider.
/// Verifies that the default configuration contains all correct values as specified in the contract.
struct DefaultConfigurationTests {

  @Test("Default configuration has correct analyzer bundle")
  func defaultConfigurationAnalyzerBundle() {
    // Create default configuration using the provider.
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Verify analyzer bundle values match the contract specification.
    #expect(
      config.analyzerBundle.analyzerBundle == "raw-content2",
      "Default analyzer bundle should be raw-content2")
    #expect(
      config.analyzerBundle.analyzerName == "standard",
      "Default analyzer name should be standard")
    #expect(
      config.analyzerBundle.mathBundle == "math2",
      "Default math bundle should be math2")
  }

  @Test("Default configuration has correct classification types")
  func defaultConfigurationClassificationTypes() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Classification types should include all five types.
    let expected = ["text", "math", "shape", "decoration", "drawing"]
    #expect(
      config.contentTypes.classificationTypes == expected,
      "Default classification types should be text, math, shape, decoration, drawing")
  }

  @Test("Default configuration has correct recognition types")
  func defaultConfigurationRecognitionTypes() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Recognition types should be a subset of classification types.
    let expected = ["text", "math", "shape"]
    #expect(
      config.contentTypes.recognitionTypes == expected,
      "Default recognition types should be text, math, shape")
  }

  @Test("Default configuration has correct gestures")
  func defaultConfigurationGestures() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Gestures should include the two default gestures.
    let expected = ["scratch-out", "underline"]
    #expect(
      config.gestures.enabledGestures == expected,
      "Default gestures should be scratch-out, underline")
  }

  @Test("Default configuration has correct conversion settings")
  func defaultConfigurationConversion() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Verify convert types array.
    let expectedTypes = ["text", "math", "shape"]
    #expect(
      config.conversion.convertTypes == expectedTypes,
      "Default convert types should be text, math, shape")

    // Verify boolean conversion settings.
    #expect(
      config.conversion.shapeAutoConvertOnHold == true,
      "shapeAutoConvertOnHold should be true by default")
    #expect(
      config.conversion.snapToNearbyItems == false,
      "snapToNearbyItems should be false by default")
  }

  @Test("Default configuration has correct language")
  func defaultConfigurationLanguage() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Language should default to US English.
    #expect(
      config.language.languageCode == "en_US",
      "Default language should be en_US")
  }

  @Test("Default configuration has correct interactivity settings")
  func defaultConfigurationInteractivity() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Verify tap behavior settings.
    #expect(
      config.interactivity.selectOnTap == true,
      "selectOnTap should be true by default")
    #expect(
      config.interactivity.convertOnDoubleTap == true,
      "convertOnDoubleTap should be true by default")

    // Verify interactive block types.
    let expectedTypes = ["text", "shape"]
    #expect(
      config.interactivity.interactiveBlockTypes == expectedTypes,
      "Default interactive block types should be text, shape")
  }

  @Test("Default configuration has correct guide settings")
  func defaultConfigurationGuides() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Guides should be empty by default.
    #expect(
      config.guides.showGuides.isEmpty,
      "showGuides should be empty by default")
    #expect(
      config.guides.snapGuides.isEmpty,
      "snapGuides should be empty by default")
  }

  @Test("Default configuration has correct export settings")
  func defaultConfigurationExport() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()

    // Verify all four export options.
    #expect(
      config.export.includeStrokes == false,
      "includeStrokes should be false by default")
    #expect(
      config.export.includeRanges == true,
      "includeRanges should be true by default")
    #expect(
      config.export.includeBoundingBoxes == true,
      "includeBoundingBoxes should be true by default")
    #expect(
      config.export.includeMathLabels == true,
      "includeMathLabels should be true by default")
  }
}

// MARK: - Custom Configuration Tests

/// Tests for creating custom RawContentConfiguration instances.
/// Verifies that configurations can be created with custom values.
struct CustomConfigurationTests {

  @Test("Custom configuration with custom analyzer bundle")
  func customAnalyzerBundle() {
    // Create configuration with custom analyzer bundle.
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content",
        analyzerName: "text-block",
        mathBundle: "math"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    // Verify the custom values are set correctly.
    #expect(
      config.analyzerBundle.analyzerBundle == "raw-content",
      "Custom analyzer bundle should be set")
    #expect(
      config.analyzerBundle.mathBundle == "math",
      "Custom math bundle should be set")
  }

  @Test("Custom configuration with French language")
  func customLanguage() {
    // Create configuration with French language.
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "fr_FR"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    // Verify the French language is set.
    #expect(
      config.language.languageCode == "fr_FR",
      "Custom language should be fr_FR")
  }

  @Test("Custom configuration with all gestures enabled")
  func customGestures() {
    // Create configuration with all valid gestures.
    let allGestures = [
      "scratch-out", "underline", "insert", "join", "long-press", "strike-through", "surround"
    ]
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: allGestures),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    // Verify all gestures are set.
    #expect(
      config.gestures.enabledGestures == allGestures,
      "All gestures should be enabled")
  }
}

// MARK: - Configuration Application Tests

/// Tests for RawContentConfigurationApplier.
/// Verifies that all configuration values are correctly applied to the target.
struct ConfigurationApplicationTests {

  @Test("Applying default configuration calls all setters with correct keys")
  func applyingDefaultConfiguration() throws {
    // Create default configuration and mock target.
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    // Apply configuration.
    try applier.applyConfiguration(config, to: mockTarget)

    // Verify all string setters were called.
    #expect(
      mockTarget.callCount(forStringKey: "raw-content.configuration.analyzer.bundle") == 1,
      "Analyzer bundle setter should be called once")
    #expect(
      mockTarget.callCount(forStringKey: "raw-content.configuration.analyzer.name") == 1,
      "Analyzer name setter should be called once")
    #expect(
      mockTarget.callCount(forStringKey: "raw-content.configuration.math.bundle") == 1,
      "Math bundle setter should be called once")
    #expect(
      mockTarget.callCount(forStringKey: "lang") == 1,
      "Language setter should be called once")

    // Verify total count of string calls.
    #expect(
      mockTarget.stringCalls.count == 4,
      "Should have exactly 4 string setter calls")
  }

  @Test("Analyzer bundle configuration applies correct values")
  func analyzerBundleApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify analyzer bundle setter.
    let analyzerCall = mockTarget.stringCall(forKey: "raw-content.configuration.analyzer.bundle")
    #expect(
      analyzerCall?.value == "raw-content2",
      "Analyzer bundle should be set to raw-content2")

    // Verify analyzer name setter.
    let analyzerNameCall = mockTarget.stringCall(forKey: "raw-content.configuration.analyzer.name")
    #expect(
      analyzerNameCall?.value == "standard",
      "Analyzer name should be set to standard")

    // Verify math bundle setter.
    let mathCall = mockTarget.stringCall(forKey: "raw-content.configuration.math.bundle")
    #expect(
      mathCall?.value == "math2",
      "Math bundle should be set to math2")
  }

  @Test("Content types configuration applies correct values")
  func contentTypesApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify classification types setter.
    let classificationCall = mockTarget.stringArrayCall(forKey: "raw-content.classification.types")
    #expect(
      classificationCall?.value == ["text", "math", "shape", "decoration", "drawing"],
      "Classification types should be set correctly")

    // Verify recognition types setter.
    let recognitionCall = mockTarget.stringArrayCall(forKey: "raw-content.recognition.types")
    #expect(
      recognitionCall?.value == ["text", "math", "shape"],
      "Recognition types should be set correctly")
  }

  @Test("Gestures configuration applies correct values")
  func gesturesApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify gestures setter.
    let gesturesCall = mockTarget.stringArrayCall(forKey: "raw-content.pen.gestures")
    #expect(
      gesturesCall?.value == ["scratch-out", "underline"],
      "Gestures should be set correctly")
  }

  @Test("Conversion configuration applies correct values")
  func conversionApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify convert types setter.
    let convertTypesCall = mockTarget.stringArrayCall(forKey: "raw-content.convert.types")
    #expect(
      convertTypesCall?.value == ["text", "math", "shape"],
      "Convert types should be set correctly")

    // Verify shape-on-hold setter.
    let shapeOnHoldCall = mockTarget.booleanCall(forKey: "raw-content.convert.shape-on-hold")
    #expect(
      shapeOnHoldCall?.value == true,
      "Shape auto convert on hold should be true")

    // Verify snap setter.
    let snapCall = mockTarget.booleanCall(forKey: "raw-content.convert.snap")
    #expect(
      snapCall?.value == false,
      "Snap to nearby items should be false")
  }

  @Test("Language configuration applies correct value")
  func languageApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify language setter.
    let languageCall = mockTarget.stringCall(forKey: "lang")
    #expect(
      languageCall?.value == "en_US",
      "Language should be set to en_US")
  }

  @Test("Interactivity configuration applies correct values")
  func interactivityApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify select-on-tap setter.
    let selectOnTapCall = mockTarget.booleanCall(
      forKey: "raw-content.interactive-blocks.select-on-tap")
    #expect(
      selectOnTapCall?.value == true,
      "Select on tap should be true")

    // Verify convert-on-double-tap setter.
    let convertOnDoubleTapCall = mockTarget.booleanCall(
      forKey: "raw-content.interactive-blocks.convert-on-double-tap")
    #expect(
      convertOnDoubleTapCall?.value == true,
      "Convert on double tap should be true")

    // Verify interactive blocks setter.
    let interactiveBlocksCall = mockTarget.stringArrayCall(forKey: "raw-content.interactive-blocks.converted")
    #expect(
      interactiveBlocksCall?.value == ["text", "shape"],
      "Interactive blocks should be set correctly")
  }

  @Test("Guides configuration applies correct values")
  func guidesApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify show guides setter.
    let showGuidesCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.show")
    #expect(
      showGuidesCall?.value == [],
      "Show guides should be empty array")

    // Verify snap guides setter.
    let snapGuidesCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.snap")
    #expect(
      snapGuidesCall?.value == [],
      "Snap guides should be empty array")
  }

  @Test("Export configuration applies correct values")
  func exportApplication() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Verify all four export setters.
    let strokesCall = mockTarget.booleanCall(forKey: "export.jiix.strokes")
    #expect(
      strokesCall?.value == false,
      "Include strokes should be false")

    let rangesCall = mockTarget.booleanCall(forKey: "export.jiix.text.chars")
    #expect(
      rangesCall?.value == true,
      "Include ranges should be true")

    let boundingBoxCall = mockTarget.booleanCall(forKey: "export.jiix.bounding-box")
    #expect(
      boundingBoxCall?.value == true,
      "Include bounding boxes should be true")

    let mathLabelsCall = mockTarget.booleanCall(forKey: "export.jiix.math.item.labels")
    #expect(
      mathLabelsCall?.value == true,
      "Include math labels should be true")
  }

  @Test("Application calls correct number of setters")
  func applicationCallCount() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    // Count total setter calls.
    // 4 string setters (analyzer bundle, analyzer name, math bundle, language)
    #expect(
      mockTarget.stringCalls.count == 4,
      "Should call 4 string setters")

    // 7 string array setters (classification, recognition, gestures,
    // convert types, interactive blocks, show guides, snap guides)
    #expect(
      mockTarget.stringArrayCalls.count == 7,
      "Should call 7 string array setters")

    // 8 boolean setters (shape-on-hold, snap, select-on-tap, convert-on-double-tap, 4 export options)
    #expect(
      mockTarget.booleanCalls.count == 8,
      "Should call 8 boolean setters")

    // No number setters.
    #expect(
      mockTarget.numberCalls.isEmpty,
      "Should not call any number setters")
  }

  @Test("Application with string setter throwing error propagates error")
  func stringSetterThrowsError() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    // Configure mock to throw on analyzer bundle setter.
    let testError = TestConfigurationError(message: "String setter failed")
    mockTarget.stringErrorsByKey["raw-content.configuration.analyzer.bundle"] = testError

    // Verify that applying configuration throws.
    #expect(throws: TestConfigurationError.self) {
      try applier.applyConfiguration(config, to: mockTarget)
    }
  }

  @Test("Application with boolean setter throwing error propagates error")
  func booleanSetterThrowsError() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    // Configure mock to throw on shape-on-hold setter.
    let testError = TestConfigurationError(message: "Boolean setter failed")
    mockTarget.booleanErrorsByKey["raw-content.convert.shape-on-hold"] = testError

    // Verify that applying configuration throws.
    #expect(throws: TestConfigurationError.self) {
      try applier.applyConfiguration(config, to: mockTarget)
    }
  }

  @Test("Application with string array setter throwing error propagates error")
  func stringArraySetterThrowsError() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    // Configure mock to throw on classification types setter.
    let testError = TestConfigurationError(message: "String array setter failed")
    mockTarget.stringArrayErrorsByKey["raw-content.classification.types"] = testError

    // Verify that applying configuration throws.
    #expect(throws: TestConfigurationError.self) {
      try applier.applyConfiguration(config, to: mockTarget)
    }
  }
}

// MARK: - Validation Tests

// Tests for RawContentConfigurationValidator.
// Verifies that invalid configurations are detected and errors are reported.
// swiftlint:disable:next type_body_length
struct ValidationTests {

  @Test("Valid default configuration passes validation")
  func validDefaultConfiguration() {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let validator = RawContentConfigurationValidator()

    let errors = validator.validate(config)

    #expect(
      errors.isEmpty,
      "Default configuration should pass validation with no errors")
  }

  @Test("Invalid analyzer bundle is detected")
  func invalidAnalyzerBundle() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "invalid-bundle",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidAnalyzerBundle(bundle: "invalid-bundle")),
      "Should detect invalid analyzer bundle")
  }

  @Test("Invalid math bundle is detected")
  func invalidMathBundle() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math3"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidMathBundle(bundle: "math3")),
      "Should detect invalid math bundle")
  }

  @Test("Invalid classification type is detected")
  func invalidClassificationType() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text", "invalid-type"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidClassificationType(type: "invalid-type")),
      "Should detect invalid classification type")
  }

  @Test("Invalid recognition type is detected")
  func invalidRecognitionType() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text", "decoration"],
        recognitionTypes: ["text", "decoration"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidRecognitionType(type: "decoration")),
      "Should detect decoration as invalid recognition type")
  }

  @Test("Invalid gesture is detected")
  func invalidGesture() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: ["invalid-gesture"]),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidGesture(gesture: "invalid-gesture")),
      "Should detect invalid gesture")
  }

  @Test("Invalid convert type is detected")
  func invalidConvertType() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: ["decoration"],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidConvertType(type: "decoration")),
      "Should detect decoration as invalid convert type")
  }

  @Test("Invalid interactive block type is detected")
  func invalidInteractiveBlockType() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: ["invalid-block"]
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidInteractiveBlockType(type: "invalid-block")),
      "Should detect invalid interactive block type")
  }

  @Test("Invalid guide type in showGuides is detected")
  func invalidShowGuideType() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(
        showGuides: ["invalid-guide"],
        snapGuides: []
      ),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidGuideType(type: "invalid-guide")),
      "Should detect invalid guide type in showGuides")
  }

  @Test("Invalid guide type in snapGuides is detected")
  func invalidSnapGuideType() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(
        showGuides: [],
        snapGuides: ["invalid-guide"]
      ),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.contains(.invalidGuideType(type: "invalid-guide")),
      "Should detect invalid guide type in snapGuides")
  }

  @Test("Validation collects multiple errors")
  func multipleValidationErrors() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "invalid-bundle",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text", "invalid-type"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: ["invalid-gesture"]),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.count == 3,
      "Should collect exactly 3 errors")
    #expect(
      errors.contains(.invalidAnalyzerBundle(bundle: "invalid-bundle")),
      "Should include invalid analyzer bundle error")
    #expect(
      errors.contains(.invalidClassificationType(type: "invalid-type")),
      "Should include invalid classification type error")
    #expect(
      errors.contains(.invalidGesture(gesture: "invalid-gesture")),
      "Should include invalid gesture error")
  }
}

// MARK: - Error Equality Tests

/// Tests for RawContentConfigurationError equality implementation.
/// Verifies that error comparison works correctly.
struct ErrorEqualityTests {

  @Test("Invalid analyzer bundle errors are equal with same bundle")
  func invalidAnalyzerBundleEquality() {
    let error1 = RawContentConfigurationError.invalidAnalyzerBundle(bundle: "test")
    let error2 = RawContentConfigurationError.invalidAnalyzerBundle(bundle: "test")

    #expect(
      error1 == error2,
      "Errors with same bundle should be equal")
  }

  @Test("Invalid analyzer bundle errors are not equal with different bundles")
  func invalidAnalyzerBundleInequality() {
    let error1 = RawContentConfigurationError.invalidAnalyzerBundle(bundle: "test1")
    let error2 = RawContentConfigurationError.invalidAnalyzerBundle(bundle: "test2")

    #expect(
      error1 != error2,
      "Errors with different bundles should not be equal")
  }

  @Test("Invalid math bundle errors are equal with same bundle")
  func invalidMathBundleEquality() {
    let error1 = RawContentConfigurationError.invalidMathBundle(bundle: "test")
    let error2 = RawContentConfigurationError.invalidMathBundle(bundle: "test")

    #expect(
      error1 == error2,
      "Errors with same bundle should be equal")
  }

  @Test("Invalid classification type errors are equal with same type")
  func invalidClassificationTypeEquality() {
    let error1 = RawContentConfigurationError.invalidClassificationType(type: "test")
    let error2 = RawContentConfigurationError.invalidClassificationType(type: "test")

    #expect(
      error1 == error2,
      "Errors with same type should be equal")
  }

  @Test("Invalid recognition type errors are equal with same type")
  func invalidRecognitionTypeEquality() {
    let error1 = RawContentConfigurationError.invalidRecognitionType(type: "test")
    let error2 = RawContentConfigurationError.invalidRecognitionType(type: "test")

    #expect(
      error1 == error2,
      "Errors with same type should be equal")
  }

  @Test("Invalid gesture errors are equal with same gesture")
  func invalidGestureEquality() {
    let error1 = RawContentConfigurationError.invalidGesture(gesture: "test")
    let error2 = RawContentConfigurationError.invalidGesture(gesture: "test")

    #expect(
      error1 == error2,
      "Errors with same gesture should be equal")
  }

  @Test("Invalid convert type errors are equal with same type")
  func invalidConvertTypeEquality() {
    let error1 = RawContentConfigurationError.invalidConvertType(type: "test")
    let error2 = RawContentConfigurationError.invalidConvertType(type: "test")

    #expect(
      error1 == error2,
      "Errors with same type should be equal")
  }

  @Test("Invalid language errors are equal with same code")
  func invalidLanguageEquality() {
    let error1 = RawContentConfigurationError.invalidLanguage(code: "test")
    let error2 = RawContentConfigurationError.invalidLanguage(code: "test")

    #expect(
      error1 == error2,
      "Errors with same code should be equal")
  }

  @Test("Invalid interactive block type errors are equal with same type")
  func invalidInteractiveBlockTypeEquality() {
    let error1 = RawContentConfigurationError.invalidInteractiveBlockType(type: "test")
    let error2 = RawContentConfigurationError.invalidInteractiveBlockType(type: "test")

    #expect(
      error1 == error2,
      "Errors with same type should be equal")
  }

  @Test("Invalid guide type errors are equal with same type")
  func invalidGuideTypeEquality() {
    let error1 = RawContentConfigurationError.invalidGuideType(type: "test")
    let error2 = RawContentConfigurationError.invalidGuideType(type: "test")

    #expect(
      error1 == error2,
      "Errors with same type should be equal")
  }

  @Test("Configuration application failed errors are equal with same key")
  func configurationApplicationFailedEquality() {
    let testError = TestConfigurationError(message: "test")
    let error1 = RawContentConfigurationError.configurationApplicationFailed(
      key: "testKey", underlyingError: testError)
    let error2 = RawContentConfigurationError.configurationApplicationFailed(
      key: "testKey", underlyingError: testError)

    #expect(
      error1 == error2,
      "Errors with same key should be equal regardless of underlying error")
  }

  @Test("Different error types are not equal")
  func differentErrorTypesNotEqual() {
    let error1 = RawContentConfigurationError.invalidAnalyzerBundle(bundle: "test")
    let error2 = RawContentConfigurationError.invalidMathBundle(bundle: "test")

    #expect(
      error1 != error2,
      "Different error types should not be equal")
  }
}

// MARK: - Edge Case Tests

// Tests for edge cases and boundary conditions.
// Verifies that edge cases are handled correctly.
// swiftlint:disable:next type_body_length
struct EdgeCaseTests {

  @Test("Empty classification types array is valid")
  func emptyClassificationTypesValid() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: [],
        recognitionTypes: []
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.isEmpty,
      "Empty classification types should be valid")
  }

  @Test("Empty classification types applies correctly")
  func emptyClassificationTypesApplication() throws {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: [],
        recognitionTypes: []
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    let classificationCall = mockTarget.stringArrayCall(forKey: "raw-content.classification.types")
    #expect(
      classificationCall?.value == [],
      "Empty classification types should be applied as empty array")
  }

  @Test("Duplicate classification types are allowed")
  func duplicateClassificationTypes() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text", "text", "math"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.isEmpty,
      "Duplicate classification types should not cause validation errors")
  }

  @Test("Duplicate classification types are applied as-is")
  func duplicateClassificationTypesApplication() throws {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text", "text", "math"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    try applier.applyConfiguration(config, to: mockTarget)

    let classificationCall = mockTarget.stringArrayCall(forKey: "raw-content.classification.types")
    #expect(
      classificationCall?.value == ["text", "text", "math"],
      "Duplicates should be passed to target as-is")
  }

  @Test("All guides enabled applies correctly")
  // swiftlint:disable:next function_body_length
  func allGuidesEnabled() throws {
    let allGuides = [
      "alignment", "text", "square", "square-inside", "image-aspect-ratio", "rotation"
    ]
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(
        showGuides: allGuides,
        snapGuides: allGuides
      ),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)
    #expect(
      errors.isEmpty,
      "All valid guides should pass validation")

    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()
    try applier.applyConfiguration(config, to: mockTarget)

    let showCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.show")
    #expect(
      showCall?.value == allGuides,
      "All guides should be applied to show")

    let snapCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.snap")
    #expect(
      snapCall?.value == allGuides,
      "All guides should be applied to snap")
  }

  @Test("Show guides without snap guides applies correctly")
  func showGuidesWithoutSnapGuides() throws {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(
        showGuides: ["alignment"],
        snapGuides: []
      ),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()
    try applier.applyConfiguration(config, to: mockTarget)

    let showCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.show")
    #expect(
      showCall?.value == ["alignment"],
      "Show guides should have alignment")

    let snapCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.snap")
    #expect(
      snapCall?.value == [],
      "Snap guides should be empty")
  }

  @Test("Snap guides without show guides applies correctly")
  func snapGuidesWithoutShowGuides() throws {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(
        showGuides: [],
        snapGuides: ["alignment"]
      ),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()
    try applier.applyConfiguration(config, to: mockTarget)

    let showCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.show")
    #expect(
      showCall?.value == [],
      "Show guides should be empty")

    let snapCall = mockTarget.stringArrayCall(forKey: "raw-content.guides.snap")
    #expect(
      snapCall?.value == ["alignment"],
      "Snap guides should have alignment")
  }

  @Test("All export options disabled applies correctly")
  func allExportOptionsDisabled() throws {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()
    try applier.applyConfiguration(config, to: mockTarget)

    #expect(mockTarget.booleanCall(forKey: "export.jiix.strokes")?.value == false)
    #expect(mockTarget.booleanCall(forKey: "export.jiix.text.chars")?.value == false)
    #expect(mockTarget.booleanCall(forKey: "export.jiix.bounding-box")?.value == false)
    #expect(mockTarget.booleanCall(forKey: "export.jiix.math.item.labels")?.value == false)
  }

  @Test("All export options enabled applies correctly")
  func allExportOptionsEnabled() throws {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: true,
        includeRanges: true,
        includeBoundingBoxes: true,
        includeMathLabels: true
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()
    try applier.applyConfiguration(config, to: mockTarget)

    #expect(mockTarget.booleanCall(forKey: "export.jiix.strokes")?.value == true)
    #expect(mockTarget.booleanCall(forKey: "export.jiix.text.chars")?.value == true)
    #expect(mockTarget.booleanCall(forKey: "export.jiix.bounding-box")?.value == true)
    #expect(mockTarget.booleanCall(forKey: "export.jiix.math.item.labels")?.value == true)
  }

  @Test("Partial application failure leaves target in partially configured state")
  func partialApplicationFailure() throws {
    let provider = DefaultRawContentConfigurationProvider()
    let config = provider.provideConfiguration()
    let mockTarget = MockExtendedConfiguration()
    let applier = RawContentConfigurationApplier()

    // Configure mock to throw after some successful calls.
    mockTarget.booleanErrorsByKey["raw-content.convert.shape-on-hold"] =
      TestConfigurationError(message: "Partial failure")

    // Attempt to apply configuration.
    do {
      try applier.applyConfiguration(config, to: mockTarget)
      Issue.record("Expected error to be thrown")
    } catch {
      // Verify some calls succeeded before the failure.
      #expect(
        !mockTarget.stringCalls.isEmpty,
        "Some string setters should have succeeded")
      #expect(
        !mockTarget.stringArrayCalls.isEmpty,
        "Some string array setters should have succeeded")
    }
  }

  @Test("Legacy analyzer bundle with new math bundle is valid")
  func legacyAnalyzerWithNewMath() {
    let config = RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content",
        analyzerName: "text-block",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text"],
        recognitionTypes: ["text"]
      ),
      gestures: RawContentConfiguration.Gestures(enabledGestures: []),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: [],
        shapeAutoConvertOnHold: false,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(languageCode: "en_US"),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: false,
        convertOnDoubleTap: false,
        interactiveBlockTypes: []
      ),
      guides: RawContentConfiguration.Guides(showGuides: [], snapGuides: []),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: false,
        includeBoundingBoxes: false,
        includeMathLabels: false
      ),
      highlighter: RawContentConfiguration.Highlighter(highlightText: false)
    )

    let validator = RawContentConfigurationValidator()
    let errors = validator.validate(config)

    #expect(
      errors.isEmpty,
      "Legacy analyzer with new math bundle should be valid")
  }
}
