//
// SSEParserTests.swift
// InkOSTests
//
// Tests for SSE stream parsing.
//

import XCTest

@testable import InkOS

final class SSEParserTests: XCTestCase {

  // MARK: - Basic Parsing Tests

  func testParseTextChunk() {
    let line = "data: {\"text\": \"Hello world\"}"
    let event = SSEParser.parse(line: line)

    XCTAssertEqual(event, .textChunk("Hello world"))
  }

  func testParseDoneEvent() {
    let line = "data: {\"done\": true}"
    let event = SSEParser.parse(line: line)

    if case .done(let metadata) = event {
      XCTAssertNil(metadata)
    } else {
      XCTFail("Expected done event")
    }
  }

  func testParseDoneMarker() {
    let line = "data: [DONE]"
    let event = SSEParser.parse(line: line)

    if case .done(let metadata) = event {
      XCTAssertNil(metadata)
    } else {
      XCTFail("Expected done event")
    }
  }

  func testParseErrorEvent() {
    let line = "data: {\"error\": {\"code\": \"rate_limited\", \"message\": \"Too many requests\"}}"
    let event = SSEParser.parse(line: line)

    XCTAssertEqual(event, .error(code: "rate_limited", message: "Too many requests"))
  }

  func testParseDoneWithTokenMetadata() {
    let line =
      "data: {\"done\": true, \"token_metadata\": {\"prompt_token_count\": 100, \"candidates_token_count\": 50, \"total_token_count\": 150}}"
    let event = SSEParser.parse(line: line)

    if case .done(let metadata) = event {
      XCTAssertEqual(metadata?.promptTokenCount, 100)
      XCTAssertEqual(metadata?.candidatesTokenCount, 50)
      XCTAssertEqual(metadata?.totalTokenCount, 150)
    } else {
      XCTFail("Expected done event with metadata")
    }
  }

  // MARK: - Invalid Input Tests

  func testParseNonDataLine() {
    let line = "event: message"
    let event = SSEParser.parse(line: line)

    XCTAssertNil(event)
  }

  func testParseEmptyDataLine() {
    let line = "data: "
    let event = SSEParser.parse(line: line)

    XCTAssertNil(event)
  }

  func testParseInvalidJSON() {
    let line = "data: {invalid json}"
    let event = SSEParser.parse(line: line)

    XCTAssertNil(event)
  }

  func testParseUnknownEvent() {
    let line = "data: {\"unknown_field\": \"value\"}"
    let event = SSEParser.parse(line: line)

    XCTAssertNil(event)
  }

  // MARK: - SSELineBuffer Tests

  func testLineBufferSingleLine() {
    var buffer = SSELineBuffer()
    let lines = buffer.append("data: {\"text\": \"hello\"}\n".data(using: .utf8)!)

    XCTAssertEqual(lines.count, 1)
    XCTAssertEqual(lines[0], "data: {\"text\": \"hello\"}")
  }

  func testLineBufferMultipleLines() {
    var buffer = SSELineBuffer()
    let lines = buffer.append("data: {\"text\": \"one\"}\ndata: {\"text\": \"two\"}\n".data(using: .utf8)!)

    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0], "data: {\"text\": \"one\"}")
    XCTAssertEqual(lines[1], "data: {\"text\": \"two\"}")
  }

  func testLineBufferPartialLine() {
    var buffer = SSELineBuffer()

    // First chunk: partial line.
    let lines1 = buffer.append("data: {\"tex".data(using: .utf8)!)
    XCTAssertEqual(lines1.count, 0)

    // Second chunk: completes the line.
    let lines2 = buffer.append("t\": \"hello\"}\n".data(using: .utf8)!)
    XCTAssertEqual(lines2.count, 1)
    XCTAssertEqual(lines2[0], "data: {\"text\": \"hello\"}")
  }

  func testLineBufferSkipsEmptyLines() {
    var buffer = SSELineBuffer()
    let lines = buffer.append("data: {\"text\": \"one\"}\n\n\ndata: {\"text\": \"two\"}\n".data(using: .utf8)!)

    XCTAssertEqual(lines.count, 2)
  }

  func testLineBufferRemainder() {
    var buffer = SSELineBuffer()
    _ = buffer.append("data: {\"text\": \"partial".data(using: .utf8)!)

    XCTAssertEqual(buffer.remainder(), "data: {\"text\": \"partial")
  }

  func testLineBufferClear() {
    var buffer = SSELineBuffer()
    _ = buffer.append("data: {\"text\": \"partial".data(using: .utf8)!)
    buffer.clear()

    XCTAssertEqual(buffer.remainder(), "")
  }

  // MARK: - Subagent Request Parsing Tests

  func testParseSubagentRequest() {
    let json = """
      data: {"subagent_request": {"id": "req-123", "target_type": "visual", "concept": "projectile motion", "intent": "demonstrate physics", "description": "Show trajectory"}}
      """
    let event = SSEParser.parse(line: json)

    if case .subagentRequest(let request) = event {
      XCTAssertEqual(request.id.rawValue, "req-123")
      XCTAssertEqual(request.targetType, .visual)
      XCTAssertEqual(request.concept, "projectile motion")
    } else {
      XCTFail("Expected subagent request event")
    }
  }

  // MARK: - Notebook Update Parsing Tests

  func testParseNotebookUpdateAppend() {
    let json = """
      data: {"notebook_update": {"action": "append", "content": {"id": "block-1", "type": "text", "created_at": "2024-01-01T00:00:00Z", "status": "ready", "content": {"segments": [{"type": "plain", "text": "Hello"}]}}}}
      """
    let event = SSEParser.parse(line: json)

    if case .blockComplete(let block) = event {
      XCTAssertEqual(block.type, .text)
    } else {
      XCTFail("Expected block complete event, got \(String(describing: event))")
    }
  }

  func testParseNotebookUpdateRequest() {
    let json = """
      data: {"notebook_update": {"action": "request", "content": {"id": "req-456", "target_type": "table", "concept": "multiplication", "intent": "practice", "description": "1-10 table"}}}
      """
    let event = SSEParser.parse(line: json)

    if case .subagentRequest(let request) = event {
      XCTAssertEqual(request.targetType, .table)
      XCTAssertEqual(request.concept, "multiplication")
    } else {
      XCTFail("Expected subagent request event, got \(String(describing: event))")
    }
  }

  // MARK: - Session Model Update Parsing Tests

  func testParseSessionModelUpdate() {
    let json = """
      data: {"session_model": {"session_id": "doc-123", "turn_count": 1, "goal": null, "concepts": {}, "signals": {"engagement": "medium", "frustration": "none", "pace": "normal"}, "facts": []}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.sessionId, "doc-123")
      XCTAssertEqual(model.turnCount, 1)
      XCTAssertNil(model.goal)
      XCTAssertTrue(model.concepts.isEmpty)
      XCTAssertEqual(model.signals.engagement, .medium)
      XCTAssertEqual(model.signals.frustration, .none)
      XCTAssertEqual(model.signals.pace, .normal)
      XCTAssertTrue(model.facts.isEmpty)
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseSessionModelUpdateWithGoal() {
    let json = """
      data: {"session_model": {"session_id": "doc-456", "turn_count": 5, "goal": {"description": "Understand derivatives", "status": "active", "progress": 45}, "concepts": {"derivatives": {"status": "practicing", "attempts": 3}}, "signals": {"engagement": "high", "frustration": "none", "pace": "fast"}, "facts": ["Prefers visual examples"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.sessionId, "doc-456")
      XCTAssertEqual(model.turnCount, 5)
      XCTAssertEqual(model.goal?.description, "Understand derivatives")
      XCTAssertEqual(model.goal?.status, .active)
      XCTAssertEqual(model.goal?.progress, 45)
      XCTAssertEqual(model.concepts["derivatives"]?.status, .practicing)
      XCTAssertEqual(model.concepts["derivatives"]?.attempts, 3)
      XCTAssertEqual(model.signals.engagement, .high)
      XCTAssertEqual(model.facts.count, 1)
      XCTAssertEqual(model.facts[0], "Prefers visual examples")
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseSessionModelUpdateWithCompletedGoal() {
    let json = """
      data: {"session_model": {"session_id": "doc-789", "turn_count": 10, "goal": {"description": "Master calculus", "status": "completed", "progress": 100}, "concepts": {"limits": {"status": "mastered", "attempts": 5}, "derivatives": {"status": "mastered", "attempts": 8}}, "signals": {"engagement": "high", "frustration": "none", "pace": "normal"}, "facts": ["Quick learner", "Completed derivatives module"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.goal?.status, .completed)
      XCTAssertEqual(model.goal?.progress, 100)
      XCTAssertEqual(model.concepts.count, 2)
      XCTAssertEqual(model.concepts["limits"]?.status, .mastered)
      XCTAssertEqual(model.concepts["derivatives"]?.status, .mastered)
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseSessionModelUpdateWithFrustration() {
    let json = """
      data: {"session_model": {"session_id": "doc-frustration", "turn_count": 8, "goal": {"description": "Learn integration", "status": "active", "progress": 20}, "concepts": {"integration": {"status": "struggling", "attempts": 7}}, "signals": {"engagement": "low", "frustration": "high", "pace": "slow"}, "facts": ["Finds u-substitution difficult"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.signals.engagement, .low)
      XCTAssertEqual(model.signals.frustration, .high)
      XCTAssertEqual(model.signals.pace, .slow)
      XCTAssertEqual(model.concepts["integration"]?.status, .struggling)
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseSessionModelUpdateWithAbandonedGoal() {
    let json = """
      data: {"session_model": {"session_id": "doc-abandoned", "turn_count": 6, "goal": {"description": "Learn advanced topology", "status": "abandoned", "progress": 15}, "concepts": {}, "signals": {"engagement": "low", "frustration": "high", "pace": "slow"}, "facts": ["Student decided to switch topics"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.goal?.status, .abandoned)
      XCTAssertEqual(model.goal?.description, "Learn advanced topology")
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseSessionModelUpdateWithMultipleConcepts() {
    let json = """
      data: {"session_model": {"session_id": "doc-multi", "turn_count": 15, "goal": {"description": "Complete calculus review", "status": "active", "progress": 70}, "concepts": {"limits": {"status": "mastered", "attempts": 5}, "derivatives": {"status": "mastered", "attempts": 10}, "chain_rule": {"status": "practicing", "attempts": 4}, "product_rule": {"status": "practicing", "attempts": 3}, "quotient_rule": {"status": "introduced", "attempts": 1}, "integration": {"status": "introduced", "attempts": 0}}, "signals": {"engagement": "high", "frustration": "none", "pace": "fast"}, "facts": ["Reviewing for exam", "Strong foundation in algebra"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.concepts.count, 6)
      XCTAssertEqual(model.concepts["limits"]?.status, .mastered)
      XCTAssertEqual(model.concepts["chain_rule"]?.status, .practicing)
      XCTAssertEqual(model.concepts["integration"]?.status, .introduced)
      XCTAssertEqual(model.concepts["integration"]?.attempts, 0)
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseSessionModelUpdateWithManyFacts() {
    let json = """
      data: {"session_model": {"session_id": "doc-facts", "turn_count": 20, "goal": null, "concepts": {}, "signals": {"engagement": "medium", "frustration": "none", "pace": "normal"}, "facts": ["Fact 1", "Fact 2", "Fact 3", "Fact 4", "Fact 5", "Fact 6", "Fact 7", "Fact 8", "Fact 9", "Fact 10"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.facts.count, 10)
      XCTAssertEqual(model.facts[0], "Fact 1")
      XCTAssertEqual(model.facts[9], "Fact 10")
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseInvalidSessionModelUpdate() {
    // Missing required fields.
    let json = """
      data: {"session_model": {"session_id": "incomplete"}}
      """
    let event = SSEParser.parse(line: json)

    // Should return nil due to failed decoding.
    XCTAssertNil(event)
  }

  func testParseSessionModelUpdateWithInvalidSignals() {
    // Invalid signal values.
    let json = """
      data: {"session_model": {"session_id": "invalid-signals", "turn_count": 1, "goal": null, "concepts": {}, "signals": {"engagement": "very_high", "frustration": "extreme", "pace": "ultra_fast"}, "facts": []}}
      """
    let event = SSEParser.parse(line: json)

    // Should return nil due to invalid enum values.
    XCTAssertNil(event)
  }

  // MARK: - Session Model with Streaming Context Tests

  func testParseSessionModelAfterTextChunks() {
    // Simulate receiving session model after text content in a stream.
    var buffer = SSELineBuffer()

    // First: text chunks.
    let textLines = buffer.append("data: {\"text\": \"Hello\"}\ndata: {\"text\": \" world\"}\n".data(using: .utf8)!)
    XCTAssertEqual(textLines.count, 2)

    for line in textLines {
      if let event = SSEParser.parse(line: line) {
        if case .textChunk = event {
          // Expected text chunk.
        } else {
          XCTFail("Expected text chunk")
        }
      }
    }

    // Then: session model update.
    let modelLines = buffer.append("data: {\"session_model\": {\"session_id\": \"doc-stream\", \"turn_count\": 2, \"goal\": null, \"concepts\": {}, \"signals\": {\"engagement\": \"medium\", \"frustration\": \"none\", \"pace\": \"normal\"}, \"facts\": []}}\n".data(using: .utf8)!)
    XCTAssertEqual(modelLines.count, 1)

    if let event = SSEParser.parse(line: modelLines[0]) {
      if case .sessionModelUpdate(let model) = event {
        XCTAssertEqual(model.sessionId, "doc-stream")
        XCTAssertEqual(model.turnCount, 2)
      } else {
        XCTFail("Expected sessionModelUpdate event")
      }
    } else {
      XCTFail("Failed to parse session model")
    }
  }

  func testParseSessionModelWithUnicode() {
    let json = """
      data: {"session_model": {"session_id": "unicode-session", "turn_count": 1, "goal": {"description": "理解微积分 🎓", "status": "active", "progress": 25}, "concepts": {"微积分": {"status": "introduced", "attempts": 0}}, "signals": {"engagement": "high", "frustration": "none", "pace": "normal"}, "facts": ["学生喜欢例子 📚"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertEqual(model.goal?.description, "理解微积分 🎓")
      XCTAssertNotNil(model.concepts["微积分"])
      XCTAssertEqual(model.facts[0], "学生喜欢例子 📚")
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }

  func testParseSessionModelWithSpecialCharacters() {
    let json = """
      data: {"session_model": {"session_id": "special-chars", "turn_count": 1, "goal": {"description": "Learn about \\"quotes\\" and backslashes", "status": "active", "progress": 10}, "concepts": {}, "signals": {"engagement": "medium", "frustration": "none", "pace": "normal"}, "facts": ["Uses LaTeX: $\\\\frac{a}{b}$"]}}
      """
    let event = SSEParser.parse(line: json)

    if case .sessionModelUpdate(let model) = event {
      XCTAssertTrue(model.goal?.description.contains("quotes") ?? false)
      XCTAssertTrue(model.facts[0].contains("LaTeX"))
    } else {
      XCTFail("Expected sessionModelUpdate event, got \(String(describing: event))")
    }
  }
}
