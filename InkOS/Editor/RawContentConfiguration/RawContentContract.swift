// Contract.swift
// Defines the API contract for Raw Content configuration in the InkOS project.
// This file serves as the specification for test-driven development, enabling
// test-writers to implement tests before the actual implementation exists.

import Foundation

// MARK: - API Contract

// Note: ExtendedConfigurationProtocol is defined in SDKProtocols.swift to allow
// IINKConfiguration to conform to it. This file uses that protocol.

// Protocol for types that can provide a Raw Content configuration.
// Allows different sources of configuration values, such as defaults or user preferences.
protocol RawContentConfigurationProviding {
  func provideConfiguration() -> RawContentConfiguration
}

// Protocol for types that can apply a Raw Content configuration to an engine.
// Decouples the configuration logic from the actual MyScript engine implementation.
protocol RawContentConfigurationApplying {
  func applyConfiguration(
    _ configuration: RawContentConfiguration, to target: any ExtendedConfigurationProtocol) throws
}

// Holds all configuration values for a Raw Content part type.
// Each property corresponds to a specific MyScript configuration key.
struct RawContentConfiguration: Equatable, Sendable {

  // Configuration bundle settings that define which recognition bundles to use.
  // The analyzerName specifies which configuration within the bundle to use.
  struct AnalyzerBundle: Equatable, Sendable {
    let analyzerBundle: String
    let analyzerName: String
    let mathBundle: String
  }

  // Classification and recognition type settings that control what ink types are detected.
  struct ContentTypes: Equatable, Sendable {
    let classificationTypes: [String]
    let recognitionTypes: [String]
  }

  // Gesture settings that enable pen gesture recognition.
  struct Gestures: Equatable, Sendable {
    let enabledGestures: [String]
  }

  // Conversion settings that control how recognized content is converted.
  struct Conversion: Equatable, Sendable {
    let convertTypes: [String]
    let shapeAutoConvertOnHold: Bool
    let snapToNearbyItems: Bool
  }

  // Language setting for text recognition.
  struct Language: Equatable, Sendable {
    let languageCode: String
  }

  // Interactivity settings that control tap and selection behavior.
  struct Interactivity: Equatable, Sendable {
    let selectOnTap: Bool
    let convertOnDoubleTap: Bool
    let interactiveBlockTypes: [String]
  }

  // Guide settings that control alignment and snapping guides.
  struct Guides: Equatable, Sendable {
    let showGuides: [String]
    let snapGuides: [String]
  }

  // Export settings that control JIIX export options.
  struct Export: Equatable, Sendable {
    let includeStrokes: Bool
    let includeRanges: Bool
    let includeBoundingBoxes: Bool
    let includeMathLabels: Bool
  }

  let analyzerBundle: AnalyzerBundle
  let contentTypes: ContentTypes
  let gestures: Gestures
  let conversion: Conversion
  let language: Language
  let interactivity: Interactivity
  let guides: Guides
  let export: Export
}

// MARK: - Default Configuration Factory

// Provides the default Raw Content configuration as specified in the requirements.
// Use this factory when creating a configuration with all standard settings.
struct DefaultRawContentConfigurationProvider: RawContentConfigurationProviding {

  func provideConfiguration() -> RawContentConfiguration {
    return RawContentConfiguration(
      analyzerBundle: RawContentConfiguration.AnalyzerBundle(
        analyzerBundle: "raw-content2",
        analyzerName: "standard",
        mathBundle: "math2"
      ),
      contentTypes: RawContentConfiguration.ContentTypes(
        classificationTypes: ["text", "math", "shape", "decoration", "drawing"],
        recognitionTypes: ["text", "math", "shape"]
      ),
      gestures: RawContentConfiguration.Gestures(
        enabledGestures: ["scratch-out", "underline"]
      ),
      conversion: RawContentConfiguration.Conversion(
        convertTypes: ["text", "math", "shape"],
        shapeAutoConvertOnHold: true,
        snapToNearbyItems: false
      ),
      language: RawContentConfiguration.Language(
        languageCode: "en_US"
      ),
      interactivity: RawContentConfiguration.Interactivity(
        selectOnTap: true,
        convertOnDoubleTap: true,
        interactiveBlockTypes: ["text", "shape"]
      ),
      guides: RawContentConfiguration.Guides(
        showGuides: [],
        snapGuides: []
      ),
      export: RawContentConfiguration.Export(
        includeStrokes: false,
        includeRanges: true,
        includeBoundingBoxes: true,
        includeMathLabels: true
      )
    )
  }
}

// MARK: - Configuration Applier

// Applies a Raw Content configuration to a target that conforms to ExtendedConfigurationProtocol.
// Maps each configuration property to its corresponding MyScript configuration key.
struct RawContentConfigurationApplier: RawContentConfigurationApplying {

  func applyConfiguration(
    _ configuration: RawContentConfiguration,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try applyAnalyzerBundle(configuration.analyzerBundle, to: target)
    try applyContentTypes(configuration.contentTypes, to: target)
    try applyGestures(configuration.gestures, to: target)
    try applyConversion(configuration.conversion, to: target)
    try applyLanguage(configuration.language, to: target)
    try applyInteractivity(configuration.interactivity, to: target)
    try applyGuides(configuration.guides, to: target)
    try applyExport(configuration.export, to: target)
  }

  private func applyAnalyzerBundle(
    _ bundle: RawContentConfiguration.AnalyzerBundle,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigString(
      bundle.analyzerBundle,
      forKey: "raw-content.configuration.analyzer.bundle"
    )
    try target.setConfigString(
      bundle.analyzerName,
      forKey: "raw-content.configuration.analyzer.name"
    )
    try target.setConfigString(
      bundle.mathBundle,
      forKey: "raw-content.configuration.math.bundle"
    )
  }

  private func applyContentTypes(
    _ types: RawContentConfiguration.ContentTypes,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigStringArray(
      types.classificationTypes,
      forKey: "raw-content.classification.types"
    )
    try target.setConfigStringArray(
      types.recognitionTypes,
      forKey: "raw-content.recognition.types"
    )
  }

  private func applyGestures(
    _ gestures: RawContentConfiguration.Gestures,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigStringArray(
      gestures.enabledGestures,
      forKey: "raw-content.pen.gestures"
    )
  }

  private func applyConversion(
    _ conversion: RawContentConfiguration.Conversion,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigStringArray(
      conversion.convertTypes,
      forKey: "raw-content.convert.types"
    )
    try target.setConfigBoolean(
      conversion.shapeAutoConvertOnHold,
      forKey: "raw-content.convert.shape-on-hold"
    )
    try target.setConfigBoolean(
      conversion.snapToNearbyItems,
      forKey: "raw-content.convert.snap"
    )
  }

  private func applyLanguage(
    _ language: RawContentConfiguration.Language,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigString(language.languageCode, forKey: "lang")
  }

  private func applyInteractivity(
    _ interactivity: RawContentConfiguration.Interactivity,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigBoolean(
      interactivity.selectOnTap,
      forKey: "raw-content.interactive-blocks.select-on-tap"
    )
    try target.setConfigBoolean(
      interactivity.convertOnDoubleTap,
      forKey: "raw-content.interactive-blocks.convert-on-double-tap"
    )
    try target.setConfigStringArray(
      interactivity.interactiveBlockTypes,
      forKey: "raw-content.interactive-blocks.converted"
    )
  }

  private func applyGuides(
    _ guides: RawContentConfiguration.Guides,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigStringArray(
      guides.showGuides,
      forKey: "raw-content.guides.show"
    )
    try target.setConfigStringArray(
      guides.snapGuides,
      forKey: "raw-content.guides.snap"
    )
  }

  private func applyExport(
    _ export: RawContentConfiguration.Export,
    to target: any ExtendedConfigurationProtocol
  ) throws {
    try target.setConfigBoolean(
      export.includeStrokes,
      forKey: "export.jiix.strokes"
    )
    try target.setConfigBoolean(
      export.includeRanges,
      forKey: "export.jiix.text.chars"
    )
    try target.setConfigBoolean(
      export.includeBoundingBoxes,
      forKey: "export.jiix.bounding-box"
    )
    try target.setConfigBoolean(
      export.includeMathLabels,
      forKey: "export.jiix.math.item.labels"
    )
  }
}

// MARK: - Error Definitions

// Errors that can occur when applying a Raw Content configuration.
// Each case provides context about what failed during configuration.
enum RawContentConfigurationError: Error, Equatable {
  case invalidAnalyzerBundle(bundle: String)
  case invalidAnalyzerName(name: String)
  case invalidMathBundle(bundle: String)
  case invalidClassificationType(type: String)
  case invalidRecognitionType(type: String)
  case invalidGesture(gesture: String)
  case invalidConvertType(type: String)
  case invalidLanguage(code: String)
  case invalidInteractiveBlockType(type: String)
  case invalidGuideType(type: String)
  case configurationApplicationFailed(key: String, underlyingError: Error)

  // Equality implementation requires checking all error cases exhaustively.
  // Complexity is inherent to the number of distinct error types in the enum.
  // swiftlint:disable:next cyclomatic_complexity
  static func == (lhs: RawContentConfigurationError, rhs: RawContentConfigurationError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidAnalyzerBundle(let left), .invalidAnalyzerBundle(let right)):
      return left == right
    case (.invalidAnalyzerName(let left), .invalidAnalyzerName(let right)):
      return left == right
    case (.invalidMathBundle(let left), .invalidMathBundle(let right)):
      return left == right
    case (.invalidClassificationType(let left), .invalidClassificationType(let right)):
      return left == right
    case (.invalidRecognitionType(let left), .invalidRecognitionType(let right)):
      return left == right
    case (.invalidGesture(let left), .invalidGesture(let right)):
      return left == right
    case (.invalidConvertType(let left), .invalidConvertType(let right)):
      return left == right
    case (.invalidLanguage(let left), .invalidLanguage(let right)):
      return left == right
    case (.invalidInteractiveBlockType(let left), .invalidInteractiveBlockType(let right)):
      return left == right
    case (.invalidGuideType(let left), .invalidGuideType(let right)):
      return left == right
    case (
      .configurationApplicationFailed(let lKey, _), .configurationApplicationFailed(let rKey, _)
    ):
      return lKey == rKey
    default:
      return false
    }
  }
}

// MARK: - Valid Value Constants

// Defines the set of valid values for configuration options that have restricted choices.
// Used for validation before applying configuration to prevent runtime errors.
enum RawContentValidValues {
  static let classificationTypes = Set(["text", "math", "shape", "decoration", "drawing"])
  static let recognitionTypes = Set(["text", "math", "shape"])
  static let gestures = Set([
    "scratch-out", "underline", "insert", "join", "long-press", "strike-through", "surround"
  ])
  static let convertTypes = Set(["text", "math", "shape"])
  static let interactiveBlockTypes = Set(["text", "shape", "drawing"])
  static let guideTypes = Set([
    "alignment", "text", "square", "square-inside", "image-aspect-ratio", "rotation"
  ])
  static let analyzerBundles = Set(["raw-content", "raw-content2"])
  // Analyzer names: raw-content has "text-block" and "text-non-text"; raw-content2 has "standard".
  static let analyzerNames = Set(["text-block", "text-non-text", "standard"])
  static let mathBundles = Set(["math", "math2"])
}

// MARK: - Configuration Validator

// Validates a Raw Content configuration before it is applied.
// Returns a list of all validation errors found, allowing batch error reporting.
struct RawContentConfigurationValidator {

  func validate(_ configuration: RawContentConfiguration) -> [RawContentConfigurationError] {
    var errors: [RawContentConfigurationError] = []

    errors.append(contentsOf: validateAnalyzerBundle(configuration.analyzerBundle))
    errors.append(contentsOf: validateContentTypes(configuration.contentTypes))
    errors.append(contentsOf: validateGestures(configuration.gestures))
    errors.append(contentsOf: validateConversion(configuration.conversion))
    errors.append(contentsOf: validateInteractivity(configuration.interactivity))
    errors.append(contentsOf: validateGuides(configuration.guides))

    return errors
  }

  private func validateAnalyzerBundle(
    _ bundle: RawContentConfiguration.AnalyzerBundle
  ) -> [RawContentConfigurationError] {
    var errors: [RawContentConfigurationError] = []

    if !RawContentValidValues.analyzerBundles.contains(bundle.analyzerBundle) {
      errors.append(.invalidAnalyzerBundle(bundle: bundle.analyzerBundle))
    }

    if !RawContentValidValues.analyzerNames.contains(bundle.analyzerName) {
      errors.append(.invalidAnalyzerName(name: bundle.analyzerName))
    }

    if !RawContentValidValues.mathBundles.contains(bundle.mathBundle) {
      errors.append(.invalidMathBundle(bundle: bundle.mathBundle))
    }

    return errors
  }

  private func validateContentTypes(
    _ types: RawContentConfiguration.ContentTypes
  ) -> [RawContentConfigurationError] {
    var errors: [RawContentConfigurationError] = []

    for type in types.classificationTypes
    where !RawContentValidValues.classificationTypes.contains(type) {
      errors.append(.invalidClassificationType(type: type))
    }

    for type in types.recognitionTypes where !RawContentValidValues.recognitionTypes.contains(type) {
      errors.append(.invalidRecognitionType(type: type))
    }

    return errors
  }

  private func validateGestures(_ gestures: RawContentConfiguration.Gestures)
    -> [RawContentConfigurationError] {
    var errors: [RawContentConfigurationError] = []

    for gesture in gestures.enabledGestures where !RawContentValidValues.gestures.contains(gesture) {
      errors.append(.invalidGesture(gesture: gesture))
    }

    return errors
  }

  private func validateConversion(
    _ conversion: RawContentConfiguration.Conversion
  ) -> [RawContentConfigurationError] {
    var errors: [RawContentConfigurationError] = []

    for type in conversion.convertTypes where !RawContentValidValues.convertTypes.contains(type) {
      errors.append(.invalidConvertType(type: type))
    }

    return errors
  }

  private func validateInteractivity(
    _ interactivity: RawContentConfiguration.Interactivity
  ) -> [RawContentConfigurationError] {
    var errors: [RawContentConfigurationError] = []

    for type in interactivity.interactiveBlockTypes
    where !RawContentValidValues.interactiveBlockTypes.contains(type) {
      errors.append(.invalidInteractiveBlockType(type: type))
    }

    return errors
  }

  private func validateGuides(_ guides: RawContentConfiguration.Guides)
    -> [RawContentConfigurationError] {
    var errors: [RawContentConfigurationError] = []

    for guide in guides.showGuides where !RawContentValidValues.guideTypes.contains(guide) {
      errors.append(.invalidGuideType(type: guide))
    }

    for guide in guides.snapGuides where !RawContentValidValues.guideTypes.contains(guide) {
      errors.append(.invalidGuideType(type: guide))
    }

    return errors
  }
}

// MARK: - Acceptance Criteria

/*
 SCENARIO: Default configuration creation
 GIVEN: No custom configuration values
 WHEN: DefaultRawContentConfigurationProvider.provideConfiguration() is called
 THEN: The returned configuration has analyzerBundle.analyzerBundle equal to "raw-content2"
  AND: analyzerBundle.mathBundle equals "math2"
  AND: contentTypes.classificationTypes equals ["text", "math", "shape", "decoration", "drawing"]
  AND: contentTypes.recognitionTypes equals ["text", "math", "shape"]
  AND: gestures.enabledGestures equals ["scratch-out", "underline", "surround", "long-press"]
  AND: conversion.convertTypes equals ["text", "math", "shape"]
  AND: conversion.shapeAutoConvertOnHold equals true
  AND: conversion.snapToNearbyItems equals false
  AND: language.languageCode equals "en_US"
  AND: interactivity.selectOnTap equals true
  AND: interactivity.convertOnDoubleTap equals true
  AND: interactivity.interactiveBlockTypes equals ["text", "shape"]
  AND: guides.showGuides is empty
  AND: guides.snapGuides is empty
  AND: export.includeStrokes equals false
  AND: export.includeRanges equals true
  AND: export.includeBoundingBoxes equals true
  AND: export.includeMathLabels equals true

 SCENARIO: Custom configuration creation
 GIVEN: Custom values for analyzerBundle and language
 WHEN: A RawContentConfiguration is created with analyzerBundle "raw-content" and language "fr_FR"
 THEN: The configuration's analyzerBundle.analyzerBundle equals "raw-content"
  AND: The configuration's language.languageCode equals "fr_FR"
  AND: Other properties remain as specified in the constructor

 SCENARIO: Configuration application to target
 GIVEN: A valid RawContentConfiguration with default values
  AND: A mock ExtendedConfigurationProtocol target
 WHEN: RawContentConfigurationApplier.applyConfiguration is called
 THEN: setConfigString is called with "raw-content2" for key "raw-content.configuration.analyzer.bundle"
  AND: setConfigString is called with "math2" for key "raw-content.configuration.math.bundle"
  AND: setConfigStringArray is called with ["text", "math", "shape", "decoration", "drawing"]
      for key "raw-content.classification.types"
  AND: setConfigStringArray is called with ["text", "math", "shape"] for key "raw-content.recognition.types"
  AND: setConfigStringArray is called with ["scratch-out", "underline", "surround", "long-press"]
      for key "raw-content.pen.gestures"
  AND: setConfigStringArray is called with ["text", "math", "shape"] for key "raw-content.convert.types"
  AND: setConfigBoolean is called with true for key "raw-content.convert.shape-on-hold"
  AND: setConfigBoolean is called with false for key "raw-content.convert.snap"
  AND: setConfigString is called with "en_US" for key "lang"
  AND: setConfigBoolean is called with true for key "raw-content.interactive-blocks.select-on-tap"
  AND: setConfigBoolean is called with true for key "raw-content.interactive-blocks.convert-on-double-tap"
  AND: setConfigStringArray is called with ["text", "shape"] for key "raw-content.interactive-blocks.converted"
  AND: setConfigStringArray is called with [] for key "raw-content.guides.show"
  AND: setConfigStringArray is called with [] for key "raw-content.guides.snap"
  AND: setConfigBoolean is called with false for key "export.jiix.strokes"
  AND: setConfigBoolean is called with true for key "export.jiix.text.chars"
  AND: setConfigBoolean is called with true for key "export.jiix.bounding-box"
  AND: setConfigBoolean is called with true for key "export.jiix.math.item.labels"

 SCENARIO: String setter throws error during application
 GIVEN: A valid RawContentConfiguration
  AND: A mock ExtendedConfigurationProtocol that throws on setConfigString
 WHEN: RawContentConfigurationApplier.applyConfiguration is called
 THEN: The method throws an error
  AND: The error propagates to the caller

 SCENARIO: Application failure handling - boolean setter throws
 GIVEN: A valid RawContentConfiguration
  AND: A mock ExtendedConfigurationProtocol that throws on setConfigBoolean for key "raw-content.convert.shape-on-hold"
 WHEN: RawContentConfigurationApplier.applyConfiguration is called
 THEN: The method throws an error after setConfigString calls succeed
  AND: The error propagates to the caller

 SCENARIO: Application failure handling - string array setter throws
 GIVEN: A valid RawContentConfiguration
  AND: A mock ExtendedConfigurationProtocol that throws on setConfigStringArray
 WHEN: RawContentConfigurationApplier.applyConfiguration is called
 THEN: The method throws an error
  AND: The error propagates to the caller

 SCENARIO: Validation of invalid analyzer bundle
 GIVEN: A RawContentConfiguration with analyzerBundle.analyzerBundle set to "invalid-bundle"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidAnalyzerBundle(bundle: "invalid-bundle")

 SCENARIO: Validation of invalid math bundle
 GIVEN: A RawContentConfiguration with analyzerBundle.mathBundle set to "math3"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidMathBundle(bundle: "math3")

 SCENARIO: Validation of invalid classification type
 GIVEN: A RawContentConfiguration with contentTypes.classificationTypes containing "invalid-type"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidClassificationType(type: "invalid-type")

 SCENARIO: Validation of invalid recognition type
 GIVEN: A RawContentConfiguration with contentTypes.recognitionTypes containing "decoration"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidRecognitionType(type: "decoration")
  NOTE: "decoration" is valid for classification but not for recognition

 SCENARIO: Validation of invalid gesture
 GIVEN: A RawContentConfiguration with gestures.enabledGestures containing "invalid-gesture"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidGesture(gesture: "invalid-gesture")

 SCENARIO: Validation of invalid convert type
 GIVEN: A RawContentConfiguration with conversion.convertTypes containing "decoration"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidConvertType(type: "decoration")

 SCENARIO: Validation of invalid interactive block type
 GIVEN: A RawContentConfiguration with interactivity.interactiveBlockTypes containing "invalid-block"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidInteractiveBlockType(type: "invalid-block")

 SCENARIO: Validation of invalid guide type in showGuides
 GIVEN: A RawContentConfiguration with guides.showGuides containing "invalid-guide"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidGuideType(type: "invalid-guide")

 SCENARIO: Validation of invalid guide type in snapGuides
 GIVEN: A RawContentConfiguration with guides.snapGuides containing "invalid-guide"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains RawContentConfigurationError.invalidGuideType(type: "invalid-guide")

 SCENARIO: Validation of valid default configuration
 GIVEN: A RawContentConfiguration created by DefaultRawContentConfigurationProvider
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result is an empty array (no errors)

 SCENARIO: Validation collects multiple errors
 GIVEN: A RawContentConfiguration with multiple invalid values:
   - analyzerBundle.analyzerBundle set to "invalid-bundle"
   - contentTypes.classificationTypes containing "invalid-type"
   - gestures.enabledGestures containing "invalid-gesture"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: The result contains exactly 3 errors
  AND: One error is RawContentConfigurationError.invalidAnalyzerBundle(bundle: "invalid-bundle")
  AND: One error is RawContentConfigurationError.invalidClassificationType(type: "invalid-type")
  AND: One error is RawContentConfigurationError.invalidGesture(gesture: "invalid-gesture")
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Empty classification types array
 GIVEN: A RawContentConfiguration with contentTypes.classificationTypes as an empty array
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: No validation error is returned for classification types
  AND: When applied to a target, setConfigStringArray is called with an empty array
  NOTE: Empty arrays are valid; MyScript handles this as "no classification"

 EDGE CASE: Empty recognition types array
 GIVEN: A RawContentConfiguration with contentTypes.recognitionTypes as an empty array
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: No validation error is returned for recognition types
  AND: When applied to a target, setConfigStringArray is called with an empty array
  NOTE: This is the MyScript default behavior (no recognition performed)

 EDGE CASE: Empty gestures array
 GIVEN: A RawContentConfiguration with gestures.enabledGestures as an empty array
 WHEN: The configuration is applied to a target
 THEN: setConfigStringArray is called with an empty array for "raw-content.pen.gestures"
  NOTE: This disables all gestures, which is valid behavior

 EDGE CASE: Empty convert types array
 GIVEN: A RawContentConfiguration with conversion.convertTypes as an empty array
 WHEN: The configuration is applied to a target
 THEN: setConfigStringArray is called with an empty array for "raw-content.convert.types"
  NOTE: This means no block types respond to convert operations

 EDGE CASE: Empty interactive block types array
 GIVEN: A RawContentConfiguration with interactivity.interactiveBlockTypes as an empty array
 WHEN: The configuration is applied to a target
 THEN: setConfigStringArray is called with an empty array for "raw-content.interactive-blocks.converted"
  NOTE: This disables interactivity on all block types

 EDGE CASE: Duplicate values in classification types
 GIVEN: A RawContentConfiguration with contentTypes.classificationTypes containing ["text", "text", "math"]
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: No validation error is returned
  AND: When applied, the duplicate is passed to MyScript as-is
  NOTE: Validation does not enforce uniqueness; MyScript handles duplicates

 EDGE CASE: Classification types as superset of recognition types
 GIVEN: A RawContentConfiguration where classificationTypes does not include all recognitionTypes
  FOR EXAMPLE: classificationTypes = ["text"] and recognitionTypes = ["text", "math"]
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: No validation error is returned for this logical inconsistency
  NOTE: This is a semantic issue that MyScript may handle differently;
        the contract does not enforce this business rule at the validation level

 EDGE CASE: Very long language code
 GIVEN: A RawContentConfiguration with language.languageCode as a 100-character string
 WHEN: The configuration is applied to a target
 THEN: setConfigString is called with the full string for key "lang"
  NOTE: Language validation is not performed at this level; MyScript returns an error
        if the language is not supported

 EDGE CASE: Language code with special characters
 GIVEN: A RawContentConfiguration with language.languageCode containing special characters like "en@US"
 WHEN: The configuration is applied to a target
 THEN: setConfigString is called with the string as-is
  NOTE: MyScript validation handles invalid language codes

 EDGE CASE: All guides enabled
 GIVEN: A RawContentConfiguration with guides.showGuides containing all valid guide types
  AND: guides.snapGuides containing all valid guide types
 WHEN: The configuration is applied to a target
 THEN: setConfigStringArray is called with the full arrays for both keys
  AND: No validation errors are returned

 EDGE CASE: Guides in showGuides but not snapGuides
 GIVEN: A RawContentConfiguration with guides.showGuides = ["alignment"]
  AND: guides.snapGuides = []
 WHEN: The configuration is applied to a target
 THEN: setConfigStringArray is called with ["alignment"] for "raw-content.guides.show"
  AND: setConfigStringArray is called with [] for "raw-content.guides.snap"
  NOTE: It is valid to show guides without enabling snapping

 EDGE CASE: Guides in snapGuides but not showGuides
 GIVEN: A RawContentConfiguration with guides.showGuides = []
  AND: guides.snapGuides = ["alignment"]
 WHEN: The configuration is applied to a target
 THEN: Both arrays are applied as specified
  NOTE: MyScript allows snapping to invisible guides

 EDGE CASE: All export options disabled
 GIVEN: A RawContentConfiguration with all export options set to false
 WHEN: The configuration is applied to a target
 THEN: All four setConfigBoolean calls are made with false
  NOTE: This produces minimal JIIX output

 EDGE CASE: All export options enabled
 GIVEN: A RawContentConfiguration with all export options set to true
 WHEN: The configuration is applied to a target
 THEN: All four setConfigBoolean calls are made with true
  NOTE: This produces maximum detail in JIIX output

 EDGE CASE: Configuration application with nil target
 GIVEN: A valid RawContentConfiguration
  AND: A nil target (not applicable due to protocol requirement)
 WHEN: RawContentConfigurationApplier.applyConfiguration is called
 THEN: This scenario is prevented at compile time by the non-optional protocol parameter
  NOTE: Swift type system ensures target is never nil

 EDGE CASE: Concurrent configuration application
 GIVEN: Two valid RawContentConfigurations
  AND: A single ExtendedConfigurationProtocol target
 WHEN: applyConfiguration is called concurrently for both configurations
 THEN: The behavior is undefined at the contract level
  NOTE: Thread safety is the responsibility of the caller and target implementation;
        the applier does not provide synchronization

 EDGE CASE: Target throws different error types
 GIVEN: A valid RawContentConfiguration
  AND: A mock target that throws NSError vs custom Error types
 WHEN: applyConfiguration is called
 THEN: Any thrown error propagates unchanged
  NOTE: The applier does not wrap or transform errors from the target

 EDGE CASE: Legacy analyzer bundle with new math bundle
 GIVEN: A RawContentConfiguration with analyzerBundle = "raw-content" and mathBundle = "math2"
 WHEN: RawContentConfigurationValidator.validate is called
 THEN: No validation error is returned
  NOTE: Compatibility between bundles is a MyScript concern, not a contract concern

 EDGE CASE: Partial application failure
 GIVEN: A valid RawContentConfiguration
  AND: A mock target that succeeds for the first 5 setConfigX calls then fails
 WHEN: applyConfiguration is called
 THEN: The method throws after partial application
  AND: The target is left in a partially configured state
  NOTE: The applier does not implement rollback; callers must handle partial failures
*/

// MARK: - Configuration Keys Reference

// Documents all MyScript configuration keys used by this feature.
// This serves as a reference for test writers and implementers.
enum RawContentConfigurationKeys {
  // Analyzer bundle keys
  static let analyzerBundle = "raw-content.configuration.analyzer.bundle"
  static let analyzerName = "raw-content.configuration.analyzer.name"
  static let mathBundle = "raw-content.configuration.math.bundle"

  // Content type keys
  static let classificationTypes = "raw-content.classification.types"
  static let recognitionTypes = "raw-content.recognition.types"

  // Gesture key
  static let gestures = "raw-content.pen.gestures"

  // Conversion keys
  static let convertTypes = "raw-content.convert.types"
  static let shapeAutoConvertOnHold = "raw-content.convert.shape-on-hold"
  static let snapToNearbyItems = "raw-content.convert.snap"

  // Language key
  static let language = "lang"

  // Interactivity keys
  static let selectOnTap = "raw-content.interactive-blocks.select-on-tap"
  static let convertOnDoubleTap = "raw-content.interactive-blocks.convert-on-double-tap"
  static let interactiveBlocks = "raw-content.interactive-blocks.converted"

  // Guide keys
  static let showGuides = "raw-content.guides.show"
  static let snapGuides = "raw-content.guides.snap"

  // Export keys
  static let exportStrokes = "export.jiix.strokes"
  static let exportRanges = "export.jiix.text.chars"
  static let exportBoundingBoxes = "export.jiix.bounding-box"
  static let exportMathLabels = "export.jiix.math.item.labels"
}
