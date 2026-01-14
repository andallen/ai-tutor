//
// BlockKindTests.swift
// InkOSTests
//
// Tests for BlockKind enum and BlockTrait system.
//

import Foundation
import Testing

@testable import InkOS

@Suite("BlockKind Tests")
struct BlockKindTests {

  @Test("All 18 BlockKind cases exist")
  func allKindsCaseIterable() {
    let allKinds = BlockKind.allCases

    #expect(allKinds.count == 18)

    let expectedKinds: [BlockKind] = [
      .textOutput, .textInput, .handwritingInput,
      .plot, .table, .diagramOutput,
      .cardDeck, .quiz,
      .geometry, .codeCell,
      .codeOutput, .calloutOutput, .imageOutput, .buttonInput, .timerOutput, .progressOutput, .audio, .videoOutput
    ]

    for kind in expectedKinds {
      #expect(allKinds.contains(kind))
    }
  }

  @Test("BlockKind encodes to raw string value")
  func kindEncodesToRawValue() throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(BlockKind.textOutput)
    let json = String(data: data, encoding: .utf8)

    #expect(json == "\"textOutput\"")
  }

  @Test("BlockTrait output is assigned correctly")
  func outputTraitAssignment() {
    let outputKinds: [BlockKind] = [
      .textOutput, .plot, .table, .diagramOutput,
      .cardDeck, .quiz, .geometry, .codeCell, .codeOutput, .calloutOutput,
      .imageOutput, .timerOutput, .progressOutput, .audio, .videoOutput
    ]

    for kind in outputKinds {
      #expect(kind.traits.contains(.output))
    }
  }

  @Test("BlockTrait input is assigned correctly")
  func inputTraitAssignment() {
    let inputKinds: [BlockKind] = [
      .textInput, .handwritingInput, .plot, .table, .cardDeck, .quiz,
      .geometry, .codeCell, .buttonInput, .audio
    ]

    for kind in inputKinds {
      #expect(kind.traits.contains(.input))
    }
  }

  @Test("BlockTrait visual is assigned correctly")
  func visualTraitAssignment() {
    let visualKinds: [BlockKind] = [
      .plot, .table, .diagramOutput, .cardDeck, .quiz,
      .geometry, .calloutOutput, .imageOutput, .timerOutput, .progressOutput, .videoOutput
    ]

    for kind in visualKinds {
      #expect(kind.traits.contains(.visual))
    }
  }

  @Test("BlockTrait system is assigned correctly")
  func systemTraitAssignment() {
    let systemKinds: [BlockKind] = [
      .buttonInput, .timerOutput, .progressOutput
    ]

    for kind in systemKinds {
      #expect(kind.traits.contains(.system))
    }
  }

  @Test("acceptsInput computed property works")
  func acceptsInputProperty() {
    #expect(BlockKind.textInput.acceptsInput == true)
    #expect(BlockKind.handwritingInput.acceptsInput == true)
    #expect(BlockKind.buttonInput.acceptsInput == true)

    #expect(BlockKind.textOutput.acceptsInput == false)
    #expect(BlockKind.imageOutput.acceptsInput == false)
  }

  @Test("isVisual computed property works")
  func isVisualProperty() {
    #expect(BlockKind.plot.isVisual == true)
    #expect(BlockKind.diagramOutput.isVisual == true)
    #expect(BlockKind.videoOutput.isVisual == true)

    #expect(BlockKind.textInput.isVisual == false)
    #expect(BlockKind.codeOutput.isVisual == false)
  }

  @Test("isSystem computed property works")
  func isSystemProperty() {
    #expect(BlockKind.buttonInput.isSystem == true)
    #expect(BlockKind.timerOutput.isSystem == true)
    #expect(BlockKind.progressOutput.isSystem == true)

    #expect(BlockKind.textOutput.isSystem == false)
    #expect(BlockKind.plot.isSystem == false)
  }

  @Test("allowsChildren property is correct")
  func allowsChildrenProperty() {
    #expect(BlockKind.cardDeck.allowsChildren == true)
    #expect(BlockKind.quiz.allowsChildren == true)

    #expect(BlockKind.textOutput.allowsChildren == false)
    #expect(BlockKind.textInput.allowsChildren == false)
    #expect(BlockKind.plot.allowsChildren == false)
  }

  @Test("BlockTrait OptionSet combinations work")
  func traitOptionSetCombinations() {
    let interactive: BlockTrait = [.output, .input]
    #expect(interactive.contains(.output))
    #expect(interactive.contains(.input))

    let outputVisual: BlockTrait = [.output, .visual]
    #expect(outputVisual.contains(.output))
    #expect(outputVisual.contains(.visual))
    #expect(outputVisual.contains(.input) == false)
  }

  @Test("BlockTrait is Codable")
  func traitIsCodable() throws {
    let trait: BlockTrait = [.output, .input, .visual]

    let encoder = JSONEncoder()
    let data = try encoder.encode(trait)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(BlockTrait.self, from: data)

    #expect(decoded == trait)
  }

  @Test("Phase 1 kinds have correct traits")
  func phase1KindsTraits() {
    // textOutput: output only
    #expect(BlockKind.textOutput.traits == .output)

    // textInput: input only
    #expect(BlockKind.textInput.traits == .input)

    // handwriting: input only
    #expect(BlockKind.handwritingInput.traits == .input)
  }

  @Test("Interactive blocks have both output and input")
  func interactiveBlocks() {
    let interactiveKinds: [BlockKind] = [.plot, .table, .cardDeck, .quiz, .geometry, .codeCell]

    for kind in interactiveKinds {
      #expect(kind.traits.contains(.output))
      #expect(kind.traits.contains(.input))
    }
  }
}
