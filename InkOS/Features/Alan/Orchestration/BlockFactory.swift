//
// BlockFactory.swift
// InkOS
//
// Creates Block instances from various sources.
// Used by the orchestration layer to create blocks from Alan's output and subagent responses.
//

import Foundation

// MARK: - BlockFactory

// Factory for creating Block instances.
struct BlockFactory {
  private init() {}

  // MARK: - Text Block Creation

  // Creates a text block from TextContent.
  static func createTextBlock(
    content: TextContent,
    status: BlockStatus = .ready
  ) -> Block {
    Block.text(status: status, content: content)
  }

  // Creates a simple text block from a string.
  static func createSimpleTextBlock(_ text: String) -> Block {
    Block.text(content: TextContent.plain(text))
  }

  // MARK: - Input Block Creation

  // Creates an input block from InputContent.
  static func createInputBlock(
    content: InputContent,
    status: BlockStatus = .ready
  ) -> Block {
    Block.input(status: status, content: content)
  }

  // MARK: - Placeholder Block Creation

  // Creates a placeholder block for pending subagent requests.
  static func createPlaceholder(
    for request: SubagentRequest,
    id: BlockID = BlockID()
  ) -> Block {
    switch request.targetType {
    case .table:
      return createTablePlaceholder(concept: request.concept, id: id)
    case .visual:
      return createVisualPlaceholder(concept: request.concept, id: id)
    }
  }

  // Creates a table placeholder block.
  private static func createTablePlaceholder(concept: String, id: BlockID) -> Block {
    let content = TableContent(
      columns: [
        TableColumn(id: "loading", header: "Loading...", dataType: .text),
      ],
      rows: [],
      caption: "Generating table for: \(concept)"
    )
    return Block.table(id: id, status: .pending, content: content)
  }

  // Creates a visual placeholder block (text with loading message).
  private static func createVisualPlaceholder(concept: String, id: BlockID) -> Block {
    let content = TextContent.plain("Generating visualization for: \(concept)...")
    return Block.text(id: id, status: .pending, content: content)
  }

  // MARK: - Error Block Creation

  // Creates an error block to display when a subagent request fails.
  static func createErrorBlock(
    error: SubagentError,
    concept: String,
    id: BlockID = BlockID()
  ) -> Block {
    let errorMessage = """
      Unable to generate content for "\(concept)".
      Error: \(error.message)
      """
    let content = TextContent(
      segments: [
        .plain(
          text: errorMessage,
          style: TextStyle(color: "#FF5722")
        ),
      ]
    )
    return Block.text(id: id, status: .ready, content: content)
  }

  // MARK: - Block Update

  // Updates an existing block with new content from a subagent response.
  static func updateBlock(
    _ existingBlock: Block,
    with response: SubagentResponse
  ) -> Block {
    guard let newBlock = response.block else {
      // If response has no block, convert to error.
      let error = response.error ?? SubagentError(code: "unknown", message: "Unknown error")
      return createErrorBlock(error: error, concept: "content", id: existingBlock.id)
    }

    // Create new block with same ID but updated content and status.
    return Block(
      id: existingBlock.id,
      type: newBlock.type,
      createdAt: existingBlock.createdAt,
      status: .ready,
      content: newBlock.content
    )
  }
}
