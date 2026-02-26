//
// BlockContainerView.swift
// InkOS
//
// Layout wrapper for individual blocks.
// Handles block status (pending vs ready) and entrance animations.
// Routes to the appropriate block type renderer.
// Applies trailing spacing based on block role (see NotebookDesignTokens).
//

import SwiftUI

// MARK: - BlockContainerView

// Wraps individual block renderers with layout and animation.
// Applies vertical spacing based on block role for proper rhythm.
struct BlockContainerView: View {
  let block: Block
  let animationState: BlockAnimationState

  var body: some View {
    Group {
      switch block.status {
      case .pending:
        PendingBlockView()
      case .hidden:
        EmptyView()
      case .ready, .rendered:
        blockContent
      }
    }
    .padding(.top, leadingSpace)
    .padding(.bottom, trailingSpace)
  }

  // Leading space based on block role.
  // Headings get more space above to separate from previous content.
  private var leadingSpace: CGFloat {
    BlockSpacing.before(blockRole)
  }

  // Trailing space based on block role.
  // Headings get less space below to connect with following content.
  private var trailingSpace: CGFloat {
    BlockSpacing.after(blockRole)
  }

  // Determines block role from content.
  private var blockRole: BlockRole {
    switch block.content {
    case .text(let content):
      return content.dominantRole
    case .checkpoint:
      return .interactive
    case .image, .graphics, .embed:
      return .content
    }
  }

  // Routes to the appropriate block type renderer.
  @ViewBuilder
  private var blockContent: some View {
    switch block.content {
    case .text(let content):
      TextBlockView(
        content: content,
        animationState: animationState
      )
    case .image(let content):
      ImageBlockView(content: content)
    case .graphics(let content):
      GraphicsBlockView(content: content)
    case .embed(let content):
      EmbedBlockView(content: content)
    case .checkpoint(let content):
      CheckpointBlockView(content: content)
    }
  }
}
