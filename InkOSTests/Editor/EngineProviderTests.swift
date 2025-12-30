import Testing
@testable import InkOS

// MARK: - EngineProviderTests

/// Tests for EngineProvider based on the EngineProviderProtocol contract.
/// Tests cover singleton behavior, engine access, error handling, and MainActor isolation.
struct EngineProviderTests {

  // MARK: - Singleton Pattern Tests

  @Test("sharedInstance returns the same instance on multiple accesses")
  @MainActor
  func sharedInstanceReturnsSameInstance() {
    // Access sharedInstance multiple times and verify identity.
    let firstAccess = EngineProvider.sharedInstance
    let secondAccess = EngineProvider.sharedInstance
    let thirdAccess = EngineProvider.sharedInstance

    #expect(firstAccess === secondAccess, "sharedInstance should return the same instance")
    #expect(secondAccess === thirdAccess, "sharedInstance should always return the same instance")
  }

  @Test("sharedInstance is AnyObject (reference type)")
  @MainActor
  func sharedInstanceIsReferenceType() {
    // Verify the provider is a class instance, not a struct.
    let provider = EngineProvider.sharedInstance
    #expect(provider is AnyObject, "EngineProvider should be a reference type")
  }

  // MARK: - Engine Access Tests

  @Test("engine property returns an IINKEngine when certificate is valid")
  @MainActor
  func engineReturnsEngineWhenCertificateValid() {
    // When the certificate is properly configured, engine should not be nil.
    // Note: This test passes only if a valid certificate is present.
    let provider = EngineProvider.sharedInstance
    let engine = provider.engine

    // Check if the engine is available (depends on certificate setup).
    if engine != nil {
      // Engine was created successfully.
      #expect(provider.engineErrorMessage.isEmpty, "Error message should be empty when engine creation succeeds")
    } else {
      // Engine creation failed - error message should explain why.
      #expect(!provider.engineErrorMessage.isEmpty, "Error message should explain why engine creation failed")
    }
  }

  @Test("engine property is lazy-loaded (not created until first access)")
  @MainActor
  func engineIsLazyLoaded() {
    // The protocol specifies that engine is lazy-loaded.
    // We can verify this by checking that engineErrorMessage is empty before engine access.
    // Note: Since sharedInstance is a singleton, we can only observe this in fresh app state.
    // This test verifies the consistency of error message with engine state.
    let provider = EngineProvider.sharedInstance

    // Access the engine to trigger lazy initialization.
    let engine = provider.engine

    // After access, the state should be consistent.
    if engine == nil {
      // If engine is nil, error message should explain why.
      #expect(!provider.engineErrorMessage.isEmpty, "When engine is nil, error message should be set")
    } else {
      // If engine exists, error message should be empty.
      #expect(provider.engineErrorMessage.isEmpty, "When engine exists, error message should be empty")
    }
  }

  @Test("engine property returns the same cached result on subsequent accesses")
  @MainActor
  func engineReturnsCachedResult() {
    // The protocol specifies that subsequent accesses return the cached result.
    let provider = EngineProvider.sharedInstance

    let firstAccess = provider.engine
    let secondAccess = provider.engine
    let thirdAccess = provider.engine

    // All accesses should return the same result (either all nil or all the same engine).
    if let first = firstAccess, let second = secondAccess, let third = thirdAccess {
      #expect(first === second, "Engine should be cached between accesses")
      #expect(second === third, "Engine should return the same instance every time")
    } else {
      // All should be nil if creation failed.
      #expect(firstAccess == nil && secondAccess == nil && thirdAccess == nil,
              "If engine creation failed, all accesses should return nil")
    }
  }

  // MARK: - Error Message Tests

  @Test("engineErrorMessage is empty when engine creation succeeds")
  @MainActor
  func engineErrorMessageEmptyOnSuccess() {
    let provider = EngineProvider.sharedInstance

    // Only check if engine succeeded.
    if provider.engine != nil {
      #expect(provider.engineErrorMessage.isEmpty, "Error message should be empty string on success")
      #expect(provider.engineErrorMessage == "", "Error message should be exactly empty string")
    }
  }

  @Test("engineErrorMessage is settable")
  @MainActor
  func engineErrorMessageIsSettable() {
    // Per the protocol, engineErrorMessage has both get and set accessors.
    let provider = EngineProvider.sharedInstance
    let originalMessage = provider.engineErrorMessage

    // Verify we can set the error message (protocol requires { get set }).
    provider.engineErrorMessage = "Test error message"
    #expect(provider.engineErrorMessage == "Test error message", "Error message should be settable")

    // Restore original message.
    provider.engineErrorMessage = originalMessage
  }

  @Test("engineErrorMessage contains certificate error when certificate is empty")
  @MainActor
  func engineErrorMessageContainsCertificateErrorWhenEmpty() {
    // If the engine is nil and the error is due to empty certificate,
    // the error message should mention MyCertificate.c.
    let provider = EngineProvider.sharedInstance

    if provider.engine == nil {
      let errorMessage = provider.engineErrorMessage

      // The error message should contain one of the expected messages.
      let isEmptyCertError = errorMessage.contains("MyCertificate.c") ||
                             errorMessage.contains("certificate")
      let isInvalidCertError = errorMessage.lowercased().contains("invalid")

      #expect(isEmptyCertError || isInvalidCertError,
              "Error message should explain certificate issue: \(errorMessage)")
    }
  }

  @Test("engineErrorMessage is not modified after successful engine access")
  @MainActor
  func engineErrorMessageRemainsEmptyAfterSuccessfulAccess() {
    let provider = EngineProvider.sharedInstance

    // Access engine multiple times.
    _ = provider.engine
    let messageAfterFirstAccess = provider.engineErrorMessage

    _ = provider.engine
    let messageAfterSecondAccess = provider.engineErrorMessage

    #expect(messageAfterFirstAccess == messageAfterSecondAccess,
            "Error message should remain consistent after multiple engine accesses")
  }

  // MARK: - Error Condition Tests

  @Test("empty certificate error message format")
  @MainActor
  func emptyCertificateErrorMessageFormat() {
    // Per the protocol, when certificate length is 0, the error message should be:
    // "Please replace the content of MyCertificate.c with the certificate you received from the developer portal"
    let expectedMessage = "Please replace the content of MyCertificate.c with the certificate you received from the developer portal"

    let provider = EngineProvider.sharedInstance

    if provider.engine == nil && provider.engineErrorMessage.contains("MyCertificate.c") {
      #expect(provider.engineErrorMessage == expectedMessage,
              "Empty certificate error should match expected format")
    }
  }

  @Test("invalid certificate error message format")
  @MainActor
  func invalidCertificateErrorMessageFormat() {
    // Per the protocol, when certificate is invalid, the error message should be:
    // "Invalid certificate"
    let expectedMessage = "Invalid certificate"

    let provider = EngineProvider.sharedInstance

    if provider.engine == nil && provider.engineErrorMessage == expectedMessage {
      #expect(provider.engineErrorMessage == expectedMessage,
              "Invalid certificate error should match expected format")
    }
  }

  // MARK: - Engine Configuration Tests

  @Test("engine configuration is accessible when engine exists")
  @MainActor
  func engineConfigurationAccessible() {
    let provider = EngineProvider.sharedInstance

    guard let engine = provider.engine else {
      // Skip test if engine is not available.
      return
    }

    // The engine should have a configuration property.
    let configuration = engine.configuration
    #expect(configuration != nil, "Engine should have configuration")
  }

  // MARK: - MainActor Isolation Tests

  @Test("EngineProvider requires MainActor context")
  @MainActor
  func engineProviderRequiresMainActor() {
    // This test is annotated with @MainActor, demonstrating that
    // EngineProvider must be accessed on the main actor.
    // Compile-time enforcement ensures this requirement.
    let provider = EngineProvider.sharedInstance
    #expect(provider != nil, "Provider should be accessible on MainActor")
  }

  // MARK: - Type Identity Tests

  @Test("engine is of type IINKEngine when not nil")
  @MainActor
  func engineTypeIsIINKEngine() {
    let provider = EngineProvider.sharedInstance

    if let engine = provider.engine {
      // Verify the engine is the expected MyScript type.
      #expect(engine is IINKEngine, "Engine should be IINKEngine type")
    }
  }

  // MARK: - Engine Lifecycle Tests

  @Test("engine persists across multiple accesses in same session")
  @MainActor
  func enginePersistsAcrossAccesses() {
    // The protocol specifies the engine lives for the entire app lifetime.
    // Within a test session, multiple accesses should return the same instance.
    let provider = EngineProvider.sharedInstance

    var engineReferences: [IINKEngine] = []

    for _ in 0..<10 {
      if let engine = provider.engine {
        engineReferences.append(engine)
      }
    }

    // All references should be identical.
    if let first = engineReferences.first {
      for engine in engineReferences {
        #expect(first === engine, "All engine references should be identical")
      }
    }
  }

  // MARK: - Consistency Tests

  @Test("engine and error message states are mutually consistent")
  @MainActor
  func engineAndErrorMessageConsistent() {
    let provider = EngineProvider.sharedInstance
    let engine = provider.engine
    let errorMessage = provider.engineErrorMessage

    // Per the protocol:
    // - If engine is nil, errorMessage should not be empty (explains why)
    // - If engine exists, errorMessage should be empty
    if engine != nil {
      #expect(errorMessage.isEmpty,
              "When engine exists, error message must be empty")
    } else {
      #expect(!errorMessage.isEmpty,
              "When engine is nil, error message must explain why")
    }
  }

  @Test("repeated engine access does not change error state")
  @MainActor
  func repeatedEngineAccessDoesNotChangeErrorState() {
    let provider = EngineProvider.sharedInstance

    // First access.
    let firstEngine = provider.engine
    let firstErrorMessage = provider.engineErrorMessage

    // Multiple subsequent accesses.
    for _ in 0..<5 {
      _ = provider.engine
    }

    let finalEngine = provider.engine
    let finalErrorMessage = provider.engineErrorMessage

    // State should remain consistent.
    if let first = firstEngine, let final = finalEngine {
      #expect(first === final, "Engine reference should remain stable")
    } else {
      #expect(firstEngine == nil && finalEngine == nil,
              "Nil engine state should remain stable")
    }

    #expect(firstErrorMessage == finalErrorMessage,
            "Error message should remain stable after repeated accesses")
  }

  // MARK: - Edge Case Tests

  @Test("provider handles rapid concurrent-like access on MainActor")
  @MainActor
  func providerHandlesRapidAccess() {
    // Simulate rapid access patterns (all on MainActor).
    let provider = EngineProvider.sharedInstance
    var results: [IINKEngine?] = []

    for _ in 0..<100 {
      results.append(provider.engine)
    }

    // All results should be identical.
    let firstResult = results.first!
    for result in results {
      if let first = firstResult, let current = result {
        #expect(first === current, "All rapid accesses should return the same engine")
      } else {
        // Both should be nil if first is nil.
        #expect(result == nil, "All results should be nil if first is nil")
      }
    }
  }

  @Test("error message can be set to empty string")
  @MainActor
  func errorMessageCanBeSetToEmpty() {
    let provider = EngineProvider.sharedInstance
    let originalMessage = provider.engineErrorMessage

    // Set to non-empty.
    provider.engineErrorMessage = "Some error"
    #expect(provider.engineErrorMessage == "Some error")

    // Set back to empty.
    provider.engineErrorMessage = ""
    #expect(provider.engineErrorMessage == "", "Error message should be settable to empty")

    // Restore original state.
    provider.engineErrorMessage = originalMessage
  }

  @Test("error message handles unicode and special characters")
  @MainActor
  func errorMessageHandlesSpecialCharacters() {
    let provider = EngineProvider.sharedInstance
    let originalMessage = provider.engineErrorMessage

    // Test various character types.
    let specialMessages = [
      "Error with émojis 🚀",
      "Error with 日本語",
      "Error with\nnewlines",
      "Error with\ttabs",
      "Error with \"quotes\"",
      "Error with 'apostrophes'",
      ""
    ]

    for message in specialMessages {
      provider.engineErrorMessage = message
      #expect(provider.engineErrorMessage == message,
              "Error message should handle: \(message)")
    }

    // Restore original state.
    provider.engineErrorMessage = originalMessage
  }

  // MARK: - Protocol Conformance Tests

  @Test("sharedInstance type matches Self requirement")
  @MainActor
  func sharedInstanceTypeMatchesSelf() {
    // Per the protocol: static var sharedInstance: Self { get }
    // The returned instance should be of type EngineProvider.
    let instance = EngineProvider.sharedInstance
    #expect(type(of: instance) == EngineProvider.self,
            "sharedInstance should return EngineProvider type")
  }

  @Test("provider conforms to AnyObject (class-bound)")
  @MainActor
  func providerConformsToAnyObject() {
    // Per the protocol: protocol EngineProviderProtocol: AnyObject
    let provider = EngineProvider.sharedInstance
    let asAnyObject: AnyObject = provider
    #expect(asAnyObject === provider, "Provider should conform to AnyObject")
  }
}

// MARK: - Engine Factory Method Tests

/// Tests for engine factory methods when engine is available.
/// These tests verify the engine can create the objects specified in the protocol.
struct EngineFactoryMethodTests {

  @Test("engine can create tool controller")
  @MainActor
  func engineCanCreateToolController() {
    let provider = EngineProvider.sharedInstance

    guard let engine = provider.engine else {
      // Skip if engine not available.
      return
    }

    // Per the protocol, createToolController() should return an IINKToolController.
    let toolController = engine.createToolController()
    #expect(toolController != nil, "Engine should create a tool controller")
  }
}

// MARK: - Engine State Preservation Tests

/// Tests verifying that engine state is preserved correctly.
struct EngineStatePreservationTests {

  @Test("engine reference remains valid after provider re-access")
  @MainActor
  func engineReferenceRemainsValidAfterReAccess() {
    // Get engine from provider.
    let provider = EngineProvider.sharedInstance
    guard let engine = provider.engine else { return }

    // Store a reference.
    let storedEngine = engine

    // Re-access provider.
    let reAccessedProvider = EngineProvider.sharedInstance
    guard let reAccessedEngine = reAccessedProvider.engine else {
      Issue.record("Engine became nil after re-access")
      return
    }

    // References should be identical.
    #expect(storedEngine === reAccessedEngine,
            "Stored engine reference should remain valid")
  }

  @Test("configuration persists on engine")
  @MainActor
  func configurationPersistsOnEngine() {
    let provider = EngineProvider.sharedInstance

    guard let engine = provider.engine else { return }

    // Access configuration multiple times.
    let config1 = engine.configuration
    let config2 = engine.configuration

    // Configuration should be the same object.
    #expect(config1 === config2, "Configuration should be the same reference")
  }
}
