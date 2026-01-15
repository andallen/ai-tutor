//
// TextContentTests.swift
// InkOSTests
//
// Tests for TextContent and related types.
//

import XCTest

@testable import InkOS

final class TextContentTests: XCTestCase {

  // MARK: - TextContent Convenience Init Tests

  func testTextContentPlain() {
    let content = TextContent.plain("Hello, world!")

    XCTAssertEqual(content.segments.count, 1)
    if case .plain(let text, _) = content.segments[0] {
      XCTAssertEqual(text, "Hello, world!")
    } else {
      XCTFail("Expected plain segment")
    }
  }

  func testTextContentLatex() {
    let content = TextContent.latex("x^2 + y^2 = z^2", displayMode: true)

    XCTAssertEqual(content.segments.count, 1)
    if case .latex(let latex, let displayMode, _) = content.segments[0] {
      XCTAssertEqual(latex, "x^2 + y^2 = z^2")
      XCTAssertTrue(displayMode)
    } else {
      XCTFail("Expected latex segment")
    }
  }

  func testTextContentCode() {
    let content = TextContent.code("print('hello')", language: "python")

    XCTAssertEqual(content.segments.count, 1)
    if case .code(let code, let language, _, _) = content.segments[0] {
      XCTAssertEqual(code, "print('hello')")
      XCTAssertEqual(language, "python")
    } else {
      XCTFail("Expected code segment")
    }
  }

  // MARK: - TextSegment Tests

  func testTextSegmentPlain() {
    let segment = TextSegment.plain(text: "Test", style: TextStyle(weight: .bold))

    if case .plain(let text, let style) = segment {
      XCTAssertEqual(text, "Test")
      XCTAssertEqual(style?.weight, .bold)
    } else {
      XCTFail("Expected plain segment")
    }
  }

  func testTextSegmentKinetic() {
    let segment = TextSegment.kinetic(
      text: "Animated",
      animation: .wordCascade,
      durationMs: 1000,
      delayMs: 200
    )

    if case .kinetic(let text, let animation, let duration, let delay, _) = segment {
      XCTAssertEqual(text, "Animated")
      XCTAssertEqual(animation, .wordCascade)
      XCTAssertEqual(duration, 1000)
      XCTAssertEqual(delay, 200)
    } else {
      XCTFail("Expected kinetic segment")
    }
  }

  // MARK: - TextStyle Tests

  func testTextStyleDefaults() {
    let style = TextStyle()

    XCTAssertNil(style.size)
    XCTAssertNil(style.weight)
    XCTAssertNil(style.color)
    XCTAssertFalse(style.italic)
    XCTAssertFalse(style.underline)
    XCTAssertFalse(style.strikethrough)
  }

  func testTextStyleCustom() {
    let style = TextStyle(
      size: .headline,
      weight: .semibold,
      color: "#FF0000",
      italic: true,
      underline: true
    )

    XCTAssertEqual(style.size, .headline)
    XCTAssertEqual(style.weight, .semibold)
    XCTAssertEqual(style.color, "#FF0000")
    XCTAssertTrue(style.italic)
    XCTAssertTrue(style.underline)
    XCTAssertFalse(style.strikethrough)
  }

  // MARK: - Codable Tests

  func testTextContentCodable() throws {
    let content = TextContent(
      segments: [
        .plain(text: "Introduction: "),
        .latex(latex: "\\int_0^1 x^2 dx", displayMode: false),
        .code(code: "def f(x): return x**2", language: "python"),
        .kinetic(text: "Important!", animation: .slam),
      ],
      alignment: .center,
      spacing: .relaxed
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let data = try encoder.encode(content)
    let decoded = try decoder.decode(TextContent.self, from: data)

    XCTAssertEqual(content.segments.count, decoded.segments.count)
    XCTAssertEqual(content.alignment, decoded.alignment)
    XCTAssertEqual(content.spacing, decoded.spacing)
  }

  func testTextSegmentCodable() throws {
    let segments: [TextSegment] = [
      .plain(text: "Plain text"),
      .latex(latex: "x^2", displayMode: true, color: "#0000FF"),
      .code(code: "let x = 1", language: "swift", showLineNumbers: true),
      .kinetic(text: "Animated", animation: .pulse, durationMs: 800, delayMs: 100),
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for segment in segments {
      let data = try encoder.encode(segment)
      let decoded = try decoder.decode(TextSegment.self, from: data)
      XCTAssertEqual(segment, decoded)
    }
  }

  // MARK: - KineticAnimation Tests

  func testKineticAnimationTypes() {
    let animations: [KineticAnimation] = [
      .typewriter, .wordCascade, .letterBounce, .slam, .shake, .pulse, .rainbow,
    ]

    for animation in animations {
      let segment = TextSegment.kinetic(text: "Test", animation: animation)
      if case .kinetic(_, let anim, _, _, _) = segment {
        XCTAssertEqual(anim, animation)
      }
    }
  }
}
