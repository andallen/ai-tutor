//
// BlockPropertiesTests.swift
// InkOSTests
//
// Tests for BlockProperties and property structs for each block kind.
//

import Foundation
import Testing

@testable import InkOS

@Suite("BlockProperties Tests")
struct BlockPropertiesTests {

  // MARK: - TextOutputProperties

  @Test("TextOutputProperties preserves content")
  func textOutputPreservesContent() {
    let props = TextOutputProperties(content: "# Heading\n\nParagraph with **bold**")

    #expect(props.content.contains("Heading"))
    #expect(props.content.contains("bold"))
    #expect(props.enableMath == true)
    #expect(props.style == nil)
  }

  @Test("TextOutputProperties supports custom style")
  func textOutputCustomStyle() {
    let style = TextStyle(fontSize: 18, fontWeight: .bold)
    let props = TextOutputProperties(content: "Test", style: style)

    #expect(props.style?.fontSize == 18)
    #expect(props.style?.fontWeight == .bold)
  }

  // MARK: - TextInputProperties

  @Test("TextInputProperties has sensible defaults")
  func textInputDefaults() {
    let props = TextInputProperties()

    #expect(props.value == "")
    #expect(props.multiline == false)
    #expect(props.keyboardType == .default)
    #expect(props.placeholder == nil)
    #expect(props.maxLength == nil)
  }

  @Test("TextInputProperties supports configuration")
  func textInputConfiguration() {
    let props = TextInputProperties(
      placeholder: "Enter your answer",
      value: "Initial",
      maxLength: 100,
      multiline: true,
      keyboardType: .numeric
    )

    #expect(props.placeholder == "Enter your answer")
    #expect(props.value == "Initial")
    #expect(props.maxLength == 100)
    #expect(props.multiline == true)
    #expect(props.keyboardType == .numeric)
  }

  // MARK: - HandwritingInputProperties

  @Test("HandwritingInputProperties has defaults")
  func handwritingDefaults() {
    let props = HandwritingInputProperties()

    #expect(props.jiixContent == nil)
    #expect(props.recognizedText == nil)
    #expect(props.canvasHeight == 200)
    #expect(props.enableMathRecognition == true)
    #expect(props.showSuggestions == true)
  }

  @Test("HandwritingInputProperties stores recognition data")
  func handwritingRecognitionData() {
    var props = HandwritingInputProperties()
    props.jiixContent = "{\"type\":\"text\",\"label\":\"hello\"}"
    props.recognizedText = "hello"

    #expect(props.jiixContent != nil)
    #expect(props.recognizedText == "hello")
  }

  // MARK: - PlotProperties

  @Test("PlotProperties has expressions and ranges")
  func plotPropertiesRanges() {
    let props = PlotProperties(expressions: ["x^2", "sin(x)"])

    #expect(props.expressions.count == 2)
    #expect(props.xRange == -10...10)
    #expect(props.yRange == -10...10)
    #expect(props.interactive == true)
    #expect(props.showGrid == true)
  }

  @Test("PlotProperties supports custom ranges")
  func plotCustomRanges() {
    let props = PlotProperties(
      expressions: ["x"],
      xRange: -5...5,
      yRange: 0...100
    )

    #expect(props.xRange.lowerBound == -5)
    #expect(props.xRange.upperBound == 5)
    #expect(props.yRange.lowerBound == 0)
    #expect(props.yRange.upperBound == 100)
  }

  // MARK: - TableProperties

  @Test("TableProperties has columns and rows")
  func tableHasColumnsAndRows() {
    let col1 = TableColumn(header: "Name", alignment: .leading)
    let col2 = TableColumn(header: "Score", alignment: .trailing)

    let row1: [TableCellValue] = [.text("Alice"), .number(95)]
    let row2: [TableCellValue] = [.text("Bob"), .number(87)]

    let props = TableProperties(
      columns: [col1, col2],
      rows: [row1, row2]
    )

    #expect(props.columns.count == 2)
    #expect(props.rows.count == 2)
    #expect(props.showHeaders == true)
    #expect(props.editable == false)
  }

  @Test("TableCellValue supports multiple types")
  func tableCellValueTypes() {
    let text = TableCellValue.text("Hello")
    let number = TableCellValue.number(42.5)
    let boolean = TableCellValue.boolean(true)
    let empty = TableCellValue.empty

    #expect(text == .text("Hello"))
    #expect(number == .number(42.5))
    #expect(boolean == .boolean(true))
    #expect(empty == .empty)
  }

  // MARK: - DiagramOutputProperties

  @Test("DiagramOutputProperties stores source and format")
  func diagramSourceAndFormat() {
    let props = DiagramOutputProperties(
      source: "graph TD; A-->B; B-->C;",
      format: .mermaid
    )

    #expect(props.source.contains("graph TD"))
    #expect(props.format == .mermaid)
  }

  // MARK: - CardDeckProperties

  @Test("CardDeckProperties manages flashcards")
  func cardDeckManagesCards() {
    let card1 = FlashCard(front: "Question 1", back: "Answer 1")
    let card2 = FlashCard(front: "Question 2", back: "Answer 2", tags: ["math"])

    let props = CardDeckProperties(cards: [card1, card2])

    #expect(props.cards.count == 2)
    #expect(props.currentIndex == 0)
    #expect(props.shuffled == false)
  }

  @Test("FlashCard has front and back")
  func flashCardFrontBack() {
    let card = FlashCard(front: "What is 2+2?", back: "4", tags: ["arithmetic"])

    #expect(card.front == "What is 2+2?")
    #expect(card.back == "4")
    #expect(card.tags?.count == 1)
  }

  // MARK: - QuizProperties

  @Test("QuizProperties manages questions")
  func quizManagesQuestions() {
    let q1 = QuizQuestion(
      question: "What is 2+2?",
      questionType: .multipleChoice,
      options: ["3", "4", "5"],
      correctAnswer: "4"
    )

    let props = QuizProperties(questions: [q1])

    #expect(props.questions.count == 1)
    #expect(props.currentIndex == 0)
    #expect(props.showAnswers == true)
  }

  @Test("QuizQuestion supports all types")
  func quizQuestionAllTypes() {
    let types: [QuizQuestionType] = [.multipleChoice, .shortAnswer, .trueFalse, .fillInBlank]

    for type in types {
      let q = QuizQuestion(
        question: "Test?",
        questionType: type,
        correctAnswer: "Test"
      )
      #expect(q.questionType == type)
    }
  }

  // MARK: - GeometryProperties

  @Test("GeometryProperties has elements")
  func geometryHasElements() {
    let point = GeometryElement(elementType: .point, label: "A")
    let line = GeometryElement(elementType: .line, label: "AB")

    let props = GeometryProperties(elements: [point, line])

    #expect(props.elements.count == 2)
    #expect(props.interactive == true)
    #expect(props.showLabels == true)
  }

  // MARK: - CodeCellProperties

  @Test("CodeCellProperties stores source code")
  func codeCellStoresSource() {
    let props = CodeCellProperties(
      source: "print('Hello')",
      language: "python"
    )

    #expect(props.source == "print('Hello')")
    #expect(props.language == "python")
    #expect(props.output == nil)
    #expect(props.hasError == false)
  }

  // MARK: - CodeOutputProperties

  @Test("CodeOutputProperties for static display")
  func codePropertiesStatic() {
    let props = CodeOutputProperties(
      source: "func hello() { }",
      language: "swift",
      highlightedLines: [1]
    )

    #expect(props.source.contains("func hello"))
    #expect(props.language == "swift")
    #expect(props.showLineNumbers == true)
    #expect(props.highlightedLines?.count == 1)
  }

  // MARK: - CalloutOutputProperties

  @Test("CalloutOutputProperties has type and content")
  func calloutTypeAndContent() {
    let props = CalloutOutputProperties(
      calloutType: .warning,
      title: "Warning",
      content: "Be careful!"
    )

    #expect(props.calloutType == .warning)
    #expect(props.title == "Warning")
    #expect(props.content == "Be careful!")
  }

  @Test("CalloutType has all expected types")
  func calloutAllTypes() {
    let types: [CalloutType] = [.info, .warning, .error, .success, .note, .tip]

    for type in types {
      let props = CalloutOutputProperties(calloutType: type, content: "Test")
      #expect(props.calloutType == type)
    }
  }

  // MARK: - ImageOutputProperties

  @Test("ImageOutputProperties has source")
  func imageHasSource() {
    let props = ImageOutputProperties(
      source: "image.png",
      altText: "A test image",
      caption: "Figure 1"
    )

    #expect(props.source == "image.png")
    #expect(props.altText == "A test image")
    #expect(props.caption == "Figure 1")
  }

  // MARK: - ButtonInputProperties

  @Test("ButtonInputProperties has label and style")
  func buttonLabelAndStyle() {
    let props = ButtonInputProperties(
      label: "Submit",
      style: .primary
    )

    #expect(props.label == "Submit")
    #expect(props.style == .primary)
    #expect(props.disabled == false)
  }

  @Test("BlockButtonStyle has all types")
  func buttonAllStyles() {
    let styles: [BlockButtonStyle] = [.primary, .secondary, .tertiary, .destructive]

    for style in styles {
      let props = ButtonInputProperties(label: "Test", style: style)
      #expect(props.style == style)
    }
  }

  // MARK: - TimerOutputProperties

  @Test("TimerOutputProperties has duration and state")
  func timerDurationAndState() {
    let props = TimerOutputProperties(duration: 60, countdown: true)

    #expect(props.duration == 60)
    #expect(props.elapsed == 0)
    #expect(props.isRunning == false)
    #expect(props.countdown == true)
  }

  // MARK: - ProgressOutputProperties

  @Test("ProgressOutputProperties tracks completion")
  func progressTracksCompletion() {
    let props = ProgressOutputProperties(total: 10, current: 3)

    #expect(props.total == 10)
    #expect(props.current == 3)
    #expect(props.showPercentage == true)
  }

  // MARK: - AudioProperties

  @Test("AudioProperties has source and controls")
  func audioSourceAndControls() {
    let props = AudioProperties(
      source: "audio.mp3",
      title: "Audio Track",
      autoPlay: false,
      loop: true
    )

    #expect(props.source == "audio.mp3")
    #expect(props.title == "Audio Track")
    #expect(props.autoPlay == false)
    #expect(props.loop == true)
  }

  // MARK: - VideoOutputProperties

  @Test("VideoOutputProperties has source and controls")
  func videoSourceAndControls() {
    let props = VideoOutputProperties(
      source: "video.mp4",
      title: "Video Tutorial",
      showControls: true
    )

    #expect(props.source == "video.mp4")
    #expect(props.title == "Video Tutorial")
    #expect(props.showControls == true)
  }
}
