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

    XCTAssertTrue(response.success)
    XCTAssertNotNil(response.block)
    XCTAssertNil(response.error)
  }

  func testSubagentResponseFailure() throws {
    let response = SubagentResponse.failure(
      requestId: SubagentRequestID("req-001"),
      error: SubagentError(code: "generation_failed", message: "Could not generate content")
    )

    XCTAssertFalse(response.success)
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
}
