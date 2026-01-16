//
// OutputParser.swift
// InkOS
//
// Parses Alan's structured output into actionable items.
// Separates direct blocks from subagent requests for the orchestration layer.
//

import Foundation

// MARK: - ParsedOutput

// Result of parsing Alan's output.
struct ParsedOutput: Sendable {
  // Direct blocks that can be inserted immediately (Text, Input).
  let directBlocks: [Block]

  // Subagent requests that need additional processing (Table, Visual).
  let subagentRequests: [SubagentRequest]

  // Token metadata from the response.
  let tokenMetadata: TokenMetadata?

  // Whether any updates were parsed.
  var hasUpdates: Bool {
    !directBlocks.isEmpty || !subagentRequests.isEmpty
  }
}

// MARK: - OutputParser

// Parses Alan's structured output.
struct OutputParser {
  private init() {}

  // Parses an AlanOutput into direct blocks and subagent requests.
  static func parse(_ output: AlanOutput) -> ParsedOutput {
    var directBlocks: [Block] = []
    var subagentRequests: [SubagentRequest] = []

    for update in output.notebookUpdates {
      switch update.action {
      case .append:
        if let block = parseDirectBlock(update.content) {
          directBlocks.append(block)
        }
      case .request:
        if let request = parseSubagentRequest(update.content) {
          subagentRequests.append(request)
        }
      }
    }

    return ParsedOutput(
      directBlocks: directBlocks,
      subagentRequests: subagentRequests,
      tokenMetadata: nil
    )
  }

  // Parses stream events into a ParsedOutput incrementally.
  static func parseStreamEvents(_ events: [AlanStreamEvent]) -> ParsedOutput {
    var directBlocks: [Block] = []
    var subagentRequests: [SubagentRequest] = []
    var tokenMetadata: TokenMetadata?

    for event in events {
      switch event {
      case .blockComplete(let block):
        directBlocks.append(block)
      case .subagentRequest(let request):
        subagentRequests.append(request)
      case .done(let metadata):
        tokenMetadata = metadata
      case .sessionModelUpdate:
        // Session model updates are handled by the orchestration layer.
        break
      case .textChunk, .error:
        // Text chunks are handled elsewhere; errors are thrown.
        break
      }
    }

    return ParsedOutput(
      directBlocks: directBlocks,
      subagentRequests: subagentRequests,
      tokenMetadata: tokenMetadata
    )
  }

  // Parses a single stream event.
  static func parseStreamEvent(_ event: AlanStreamEvent) -> (Block?, SubagentRequest?) {
    switch event {
    case .blockComplete(let block):
      return (block, nil)
    case .subagentRequest(let request):
      return (nil, request)
    default:
      return (nil, nil)
    }
  }

  // MARK: - Private Parsing Helpers

  // Parses direct block content (Text or Input).
  private static func parseDirectBlock(_ content: UpdateContent) -> Block? {
    switch content {
    case .text(let textContent):
      return BlockFactory.createTextBlock(content: textContent)
    case .input(let inputContent):
      return BlockFactory.createInputBlock(content: inputContent)
    case .subagentRequest:
      // Subagent requests are not direct blocks.
      return nil
    }
  }

  // Parses subagent request content.
  private static func parseSubagentRequest(_ content: UpdateContent) -> SubagentRequest? {
    switch content {
    case .subagentRequest(let request):
      return request
    case .text, .input:
      // Direct blocks are not subagent requests.
      return nil
    }
  }
}
