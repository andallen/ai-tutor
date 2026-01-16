//
// AlanContractTests.swift
// InkOSTests
//
// Tests for Alan contract types and Codable conformance.
//

import XCTest

@testable import InkOS

final class AlanContractTests: XCTestCase {

  // MARK: - SubagentRequestID Tests

  func testSubagentRequestIDGeneration() {
    let id1 = SubagentRequestID()
    let id2 = SubagentRequestID()

    XCTAssertTrue(id1.rawValue.hasPrefix("req-"))
    XCTAssertTrue(id2.rawValue.hasPrefix("req-"))
    XCTAssertNotEqual(id1, id2)
  }

  func testSubagentRequestIDCodable() throws {
    let id = SubagentRequestID("req-test-123")

    let encoder = JSONEncoder()
    let data = try encoder.encode(id)
    let json = String(data: data, encoding: .utf8)

    XCTAssertEqual(json, "\"req-test-123\"")

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SubagentRequestID.self, from: data)

    XCTAssertEqual(decoded, id)
  }

  // MARK: - SubagentRequest Tests

  func testSubagentRequestCodable() throws {
    let request = SubagentRequest(
      id: SubagentRequestID("req-001"),
      targetType: .visual,
      concept: "projectile motion",
      intent: "demonstrate physics",
      description: "Show trajectory of a ball being thrown",
      constraints: RequestConstraints(
        preferredEngine: "p5",
        preferredProvider: "phet"
      )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(request)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SubagentRequest.self, from: data)

    XCTAssertEqual(decoded.id, request.id)
    XCTAssertEqual(decoded.targetType, .visual)
    XCTAssertEqual(decoded.concept, "projectile motion")
    XCTAssertEqual(decoded.intent, "demonstrate physics")
    XCTAssertEqual(decoded.description, "Show trajectory of a ball being thrown")
    XCTAssertEqual(decoded.constraints?.preferredEngine, "p5")
    XCTAssertEqual(decoded.constraints?.preferredProvider, "phet")
  }

  func testSubagentRequestWithoutConstraints() throws {
    let request = SubagentRequest(
      targetType: .table,
      concept: "multiplication table",
      intent: "practice multiplication",
      description: "1-10 multiplication table"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(request)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SubagentRequest.self, from: data)

    XCTAssertEqual(decoded.targetType, .table)
    XCTAssertEqual(decoded.concept, "multiplication table")
    XCTAssertNil(decoded.constraints)
  }

  // MARK: - SubagentResponse Tests

  func testSubagentResponseSuccess() throws {
    let block = Block.text(content: TextContent.plain("Hello"))
    let response = SubagentResponse.success(
      requestId: SubagentRequestID("req-001"),
      block: block
    )

    XCTAssertTrue(response.isSuccess)
    XCTAssertNotNil(response.block)
    XCTAssertNil(response.error)
  }

  func testSubagentResponseFailure() throws {
    let response = SubagentResponse.failure(
      requestId: SubagentRequestID("req-001"),
      error: SubagentError(code: "generation_failed", message: "Could not generate content")
    )

    XCTAssertFalse(response.isSuccess)
    XCTAssertNil(response.block)
    XCTAssertEqual(response.error?.code, "generation_failed")
    XCTAssertEqual(response.error?.message, "Could not generate content")
  }

  // MARK: - VisualRouterDecision Tests

  func testVisualRouterDecisionCodable() throws {
    let decision = VisualRouterDecision(
      selectedType: .embed,
      reasoning: "User requested interactive simulation",
      specificRecommendation: "phet projectile-motion"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(decision)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(VisualRouterDecision.self, from: data)

    XCTAssertEqual(decoded.selectedType, .embed)
    XCTAssertEqual(decoded.reasoning, "User requested interactive simulation")
    XCTAssertEqual(decoded.specificRecommendation, "phet projectile-motion")
  }

  // MARK: - ChatMessage Tests

  func testChatMessageCodable() throws {
    let message = ChatMessage(role: .user, content: "Explain quadratic equations")

    let encoder = JSONEncoder()
    let data = try encoder.encode(message)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ChatMessage.self, from: data)

    XCTAssertEqual(decoded.role, .user)
    XCTAssertEqual(decoded.content, "Explain quadratic equations")
  }

  // MARK: - NotebookContext Tests

  func testNotebookContextCodable() throws {
    let context = NotebookContext(
      documentId: "doc-123",
      currentBlocks: nil,
      sessionTopic: "Algebra"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(context)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(NotebookContext.self, from: data)

    XCTAssertEqual(decoded.documentId, "doc-123")
    XCTAssertNil(decoded.currentBlocks)
    XCTAssertEqual(decoded.sessionTopic, "Algebra")
  }

  // MARK: - AlanRequest Tests

  func testAlanRequestCodable() throws {
    let request = AlanRequest(
      messages: [
        ChatMessage(role: .user, content: "What is gravity?"),
        ChatMessage(role: .assistant, content: "Gravity is a force..."),
        ChatMessage(role: .user, content: "Why do objects fall?"),
      ],
      notebookContext: NotebookContext(documentId: "doc-456")
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(request)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AlanRequest.self, from: data)

    XCTAssertEqual(decoded.messages.count, 3)
    XCTAssertEqual(decoded.messages[0].role, .user)
    XCTAssertEqual(decoded.messages[1].role, .assistant)
    XCTAssertEqual(decoded.notebookContext.documentId, "doc-456")
  }

  // MARK: - RequestConstraints Tests

  func testRequestConstraintsPartial() throws {
    let constraints = RequestConstraints(
      maxRows: 10,
      preferredEngine: nil,
      preferredProvider: "geogebra"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(constraints)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(RequestConstraints.self, from: data)

    XCTAssertEqual(decoded.maxRows, 10)
    XCTAssertNil(decoded.preferredEngine)
    XCTAssertEqual(decoded.preferredProvider, "geogebra")
  }

  // MARK: - TokenMetadata Tests

  func testTokenMetadataCodable() throws {
    let metadata = TokenMetadata(
      promptTokenCount: 100,
      candidatesTokenCount: 50,
      totalTokenCount: 150
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(metadata)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(TokenMetadata.self, from: data)

    XCTAssertEqual(decoded.promptTokenCount, 100)
    XCTAssertEqual(decoded.candidatesTokenCount, 50)
    XCTAssertEqual(decoded.totalTokenCount, 150)
  }

  // MARK: - SessionModel Tests

  func testSessionModelNew() {
    let model = SessionModel.new(sessionId: "test-session-123")

    XCTAssertEqual(model.sessionId, "test-session-123")
    XCTAssertEqual(model.turnCount, 0)
    XCTAssertNil(model.goal)
    XCTAssertTrue(model.concepts.isEmpty)
    XCTAssertEqual(model.signals.engagement, .medium)
    XCTAssertEqual(model.signals.frustration, .none)
    XCTAssertEqual(model.signals.pace, .normal)
    XCTAssertTrue(model.facts.isEmpty)
  }

  func testSessionModelCodable() throws {
    let model = SessionModel(
      sessionId: "doc-456",
      turnCount: 5,
      goal: SessionGoal(
        description: "Understand derivatives",
        status: .active,
        progress: 45
      ),
      concepts: [
        "derivatives": ConceptStatus(status: .practicing, attempts: 3),
        "limits": ConceptStatus(status: .mastered, attempts: 5),
      ],
      signals: SessionSignals(engagement: .high, frustration: .none, pace: .fast),
      facts: ["Studying for AP Calc", "Prefers visual examples"]
    )

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let data = try encoder.encode(model)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let decoded = try decoder.decode(SessionModel.self, from: data)

    XCTAssertEqual(decoded.sessionId, "doc-456")
    XCTAssertEqual(decoded.turnCount, 5)
    XCTAssertEqual(decoded.goal?.description, "Understand derivatives")
    XCTAssertEqual(decoded.goal?.status, .active)
    XCTAssertEqual(decoded.goal?.progress, 45)
    XCTAssertEqual(decoded.concepts["derivatives"]?.status, .practicing)
    XCTAssertEqual(decoded.concepts["derivatives"]?.attempts, 3)
    XCTAssertEqual(decoded.concepts["limits"]?.status, .mastered)
    XCTAssertEqual(decoded.signals.engagement, .high)
    XCTAssertEqual(decoded.signals.frustration, .none)
    XCTAssertEqual(decoded.signals.pace, .fast)
    XCTAssertEqual(decoded.facts.count, 2)
  }

  func testSessionModelWithNullGoal() throws {
    let model = SessionModel(sessionId: "session-123", turnCount: 1)

    let encoder = JSONEncoder()
    let data = try encoder.encode(model)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SessionModel.self, from: data)

    XCTAssertNil(decoded.goal)
    XCTAssertTrue(decoded.concepts.isEmpty)
    XCTAssertTrue(decoded.facts.isEmpty)
  }

  func testSessionModelMutability() {
    var model = SessionModel.new(sessionId: "mutable-session")

    // Update turn count.
    model.turnCount = 5
    XCTAssertEqual(model.turnCount, 5)

    // Set goal.
    model.goal = SessionGoal(description: "Learn calculus", status: .active, progress: 0)
    XCTAssertEqual(model.goal?.description, "Learn calculus")

    // Update goal progress.
    model.goal?.progress = 50
    XCTAssertEqual(model.goal?.progress, 50)

    // Add concepts.
    model.concepts["limits"] = ConceptStatus(status: .introduced, attempts: 0)
    XCTAssertEqual(model.concepts["limits"]?.status, .introduced)

    // Update concept.
    model.concepts["limits"]?.status = .practicing
    model.concepts["limits"]?.attempts = 2
    XCTAssertEqual(model.concepts["limits"]?.status, .practicing)
    XCTAssertEqual(model.concepts["limits"]?.attempts, 2)

    // Update signals.
    model.signals.engagement = .high
    model.signals.frustration = .mild
    model.signals.pace = .slow
    XCTAssertEqual(model.signals.engagement, .high)
    XCTAssertEqual(model.signals.frustration, .mild)
    XCTAssertEqual(model.signals.pace, .slow)

    // Add facts.
    model.facts.append("New fact")
    XCTAssertEqual(model.facts.count, 1)
    XCTAssertEqual(model.facts[0], "New fact")
  }

  // MARK: - SessionGoal Tests

  func testSessionGoalAllStatuses() throws {
    let statuses: [SessionGoal.GoalStatus] = [.active, .completed, .abandoned]

    for status in statuses {
      let goal = SessionGoal(description: "Test goal", status: status, progress: 50)

      let encoder = JSONEncoder()
      let data = try encoder.encode(goal)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode(SessionGoal.self, from: data)

      XCTAssertEqual(decoded.status, status)
    }
  }

  func testSessionGoalProgressBoundaries() throws {
    // Test progress = 0.
    let goalZero = SessionGoal(description: "Starting", status: .active, progress: 0)
    XCTAssertEqual(goalZero.progress, 0)

    // Test progress = 100.
    let goalComplete = SessionGoal(description: "Done", status: .completed, progress: 100)
    XCTAssertEqual(goalComplete.progress, 100)

    // Both should encode/decode correctly.
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let dataZero = try encoder.encode(goalZero)
    let decodedZero = try decoder.decode(SessionGoal.self, from: dataZero)
    XCTAssertEqual(decodedZero.progress, 0)

    let dataComplete = try encoder.encode(goalComplete)
    let decodedComplete = try decoder.decode(SessionGoal.self, from: dataComplete)
    XCTAssertEqual(decodedComplete.progress, 100)
  }

  // MARK: - ConceptStatus Tests

  func testConceptStatusAllStates() throws {
    let statuses: [ConceptStatus.Status] = [.introduced, .practicing, .mastered, .struggling]

    for status in statuses {
      let conceptStatus = ConceptStatus(status: status, attempts: 1)

      let encoder = JSONEncoder()
      let data = try encoder.encode(conceptStatus)

      let decoder = JSONDecoder()
      let decoded = try decoder.decode(ConceptStatus.self, from: data)

      XCTAssertEqual(decoded.status, status)
    }
  }

  func testConceptStatusAttemptsTracking() throws {
    var conceptStatus = ConceptStatus(status: .introduced, attempts: 0)
    XCTAssertEqual(conceptStatus.attempts, 0)

    // Simulate attempts increasing.
    conceptStatus.attempts = 5
    conceptStatus.status = .practicing
    XCTAssertEqual(conceptStatus.attempts, 5)

    conceptStatus.attempts = 10
    conceptStatus.status = .mastered
    XCTAssertEqual(conceptStatus.attempts, 10)

    let encoder = JSONEncoder()
    let data = try encoder.encode(conceptStatus)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ConceptStatus.self, from: data)

    XCTAssertEqual(decoded.status, .mastered)
    XCTAssertEqual(decoded.attempts, 10)
  }

  // MARK: - SessionSignals Tests

  func testSessionSignalsDefaults() {
    let signals = SessionSignals()

    XCTAssertEqual(signals.engagement, .medium)
    XCTAssertEqual(signals.frustration, .none)
    XCTAssertEqual(signals.pace, .normal)
  }

  func testSessionSignalsAllCombinations() throws {
    let engagements: [SessionSignals.Engagement] = [.high, .medium, .low]
    let frustrations: [SessionSignals.Frustration] = [.none, .mild, .high]
    let paces: [SessionSignals.Pace] = [.fast, .normal, .slow]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for engagement in engagements {
      for frustration in frustrations {
        for pace in paces {
          let signals = SessionSignals(engagement: engagement, frustration: frustration, pace: pace)

          let data = try encoder.encode(signals)
          let decoded = try decoder.decode(SessionSignals.self, from: data)

          XCTAssertEqual(decoded.engagement, engagement)
          XCTAssertEqual(decoded.frustration, frustration)
          XCTAssertEqual(decoded.pace, pace)
        }
      }
    }
  }

  // MARK: - AlanRequest with SessionModel Tests

  func testAlanRequestWithSessionModel() throws {
    let sessionModel = SessionModel(
      sessionId: "doc-789",
      turnCount: 3,
      goal: SessionGoal(description: "Learn integration", status: .active, progress: 30),
      concepts: ["integration": ConceptStatus(status: .practicing, attempts: 2)],
      signals: SessionSignals(engagement: .medium, frustration: .mild, pace: .slow),
      facts: ["Finds u-substitution difficult"]
    )

    let request = AlanRequest(
      messages: [
        ChatMessage(role: .user, content: "I don't understand u-substitution"),
      ],
      notebookContext: NotebookContext(documentId: "doc-789"),
      sessionModel: sessionModel
    )

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let data = try encoder.encode(request)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let decoded = try decoder.decode(AlanRequest.self, from: data)

    XCTAssertNotNil(decoded.sessionModel)
    XCTAssertEqual(decoded.sessionModel?.sessionId, "doc-789")
    XCTAssertEqual(decoded.sessionModel?.turnCount, 3)
    XCTAssertEqual(decoded.sessionModel?.goal?.description, "Learn integration")
    XCTAssertEqual(decoded.sessionModel?.concepts["integration"]?.status, .practicing)
  }

  func testAlanRequestWithoutSessionModel() throws {
    let request = AlanRequest(
      messages: [ChatMessage(role: .user, content: "Hello")],
      notebookContext: NotebookContext(documentId: "doc-first-turn")
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(request)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AlanRequest.self, from: data)

    XCTAssertNil(decoded.sessionModel)
  }

  // MARK: - AlanOutput with SessionModel Tests

  func testAlanOutputDecoding() throws {
    let json = """
    {
      "notebook_updates": [],
      "session_model": {
        "session_id": "doc-output-test",
        "turn_count": 1,
        "goal": null,
        "concepts": {},
        "signals": {
          "engagement": "medium",
          "frustration": "none",
          "pace": "normal"
        },
        "facts": []
      }
    }
    """

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let data = json.data(using: .utf8)!
    let output = try decoder.decode(AlanOutput.self, from: data)

    XCTAssertTrue(output.notebookUpdates.isEmpty)
    XCTAssertEqual(output.sessionModel.sessionId, "doc-output-test")
    XCTAssertEqual(output.sessionModel.turnCount, 1)
    XCTAssertNil(output.sessionModel.goal)
  }

  func testAlanOutputWithCompleteSessionModel() throws {
    let json = """
    {
      "notebook_updates": [
        {
          "action": "append",
          "content": {
            "type": "text",
            "segments": [
              {"type": "plain", "text": "Great progress!"}
            ]
          }
        }
      ],
      "session_model": {
        "session_id": "doc-complete",
        "turn_count": 10,
        "goal": {
          "description": "Master calculus",
          "status": "completed",
          "progress": 100
        },
        "concepts": {
          "limits": {
            "status": "mastered",
            "attempts": 5
          },
          "derivatives": {
            "status": "mastered",
            "attempts": 8
          }
        },
        "signals": {
          "engagement": "high",
          "frustration": "none",
          "pace": "fast"
        },
        "facts": ["Quick learner", "Prefers visual examples"]
      }
    }
    """

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let data = json.data(using: .utf8)!
    let output = try decoder.decode(AlanOutput.self, from: data)

    XCTAssertEqual(output.notebookUpdates.count, 1)
    XCTAssertEqual(output.sessionModel.sessionId, "doc-complete")
    XCTAssertEqual(output.sessionModel.turnCount, 10)
    XCTAssertEqual(output.sessionModel.goal?.status, .completed)
    XCTAssertEqual(output.sessionModel.goal?.progress, 100)
    XCTAssertEqual(output.sessionModel.concepts.count, 2)
    XCTAssertEqual(output.sessionModel.concepts["limits"]?.status, .mastered)
    XCTAssertEqual(output.sessionModel.signals.engagement, .high)
    XCTAssertEqual(output.sessionModel.facts.count, 2)
  }

  // MARK: - SessionModel JSON Key Mapping Tests

  func testSessionModelSnakeCaseKeys() throws {
    // Verify that snake_case JSON keys map correctly to camelCase Swift properties.
    let json = """
    {
      "session_id": "test-snake-case",
      "turn_count": 7,
      "goal": {
        "description": "Test goal",
        "status": "active",
        "progress": 50
      },
      "concepts": {},
      "signals": {
        "engagement": "high",
        "frustration": "mild",
        "pace": "slow"
      },
      "facts": []
    }
    """

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let data = json.data(using: .utf8)!
    let model = try decoder.decode(SessionModel.self, from: data)

    XCTAssertEqual(model.sessionId, "test-snake-case")
    XCTAssertEqual(model.turnCount, 7)
  }

  // MARK: - SessionModel Equality Tests

  func testSessionModelEquality() {
    let model1 = SessionModel(
      sessionId: "test",
      turnCount: 1,
      goal: SessionGoal(description: "Goal", status: .active, progress: 50),
      concepts: ["concept": ConceptStatus(status: .introduced, attempts: 0)],
      signals: SessionSignals(),
      facts: ["fact"]
    )

    let model2 = SessionModel(
      sessionId: "test",
      turnCount: 1,
      goal: SessionGoal(description: "Goal", status: .active, progress: 50),
      concepts: ["concept": ConceptStatus(status: .introduced, attempts: 0)],
      signals: SessionSignals(),
      facts: ["fact"]
    )

    XCTAssertEqual(model1, model2)
  }

  func testSessionModelInequality() {
    let model1 = SessionModel.new(sessionId: "session-1")
    var model2 = SessionModel.new(sessionId: "session-1")
    model2.turnCount = 1

    XCTAssertNotEqual(model1, model2)
  }

  // MARK: - Edge Cases

  func testSessionModelWithManyFacts() throws {
    var model = SessionModel.new(sessionId: "many-facts")
    for i in 0..<100 {
      model.facts.append("Fact \(i)")
    }

    let encoder = JSONEncoder()
    let data = try encoder.encode(model)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SessionModel.self, from: data)

    XCTAssertEqual(decoded.facts.count, 100)
  }

  func testSessionModelWithManyConcepts() throws {
    var model = SessionModel.new(sessionId: "many-concepts")
    for i in 0..<50 {
      model.concepts["concept_\(i)"] = ConceptStatus(status: .introduced, attempts: i)
    }

    let encoder = JSONEncoder()
    let data = try encoder.encode(model)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SessionModel.self, from: data)

    XCTAssertEqual(decoded.concepts.count, 50)
  }

  func testSessionModelWithUnicodeContent() throws {
    let model = SessionModel(
      sessionId: "unicode-test",
      turnCount: 1,
      goal: SessionGoal(description: "理解微积分 🎓", status: .active, progress: 25),
      concepts: ["微积分": ConceptStatus(status: .introduced, attempts: 0)],
      signals: SessionSignals(),
      facts: ["学生喜欢例子 📚", "Préfère des explications visuelles"]
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(model)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SessionModel.self, from: data)

    XCTAssertEqual(decoded.goal?.description, "理解微积分 🎓")
    XCTAssertNotNil(decoded.concepts["微积分"])
    XCTAssertEqual(decoded.facts[0], "学生喜欢例子 📚")
    XCTAssertEqual(decoded.facts[1], "Préfère des explications visuelles")
  }

  func testSessionModelWithEmptyStrings() throws {
    let model = SessionModel(
      sessionId: "",
      turnCount: 0,
      goal: SessionGoal(description: "", status: .active, progress: 0),
      concepts: ["": ConceptStatus(status: .introduced, attempts: 0)],
      signals: SessionSignals(),
      facts: [""]
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(model)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SessionModel.self, from: data)

    XCTAssertEqual(decoded.sessionId, "")
    XCTAssertEqual(decoded.goal?.description, "")
    XCTAssertNotNil(decoded.concepts[""])
    XCTAssertEqual(decoded.facts[0], "")
  }
}
