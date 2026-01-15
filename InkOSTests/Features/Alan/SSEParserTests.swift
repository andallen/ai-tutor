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
}
