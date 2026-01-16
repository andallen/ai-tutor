//
// BlockContainerView.swift
// InkOS
//
// Layout wrapper for individual blocks.
// Handles block status (pending vs ready) and entrance animations.
// Routes to the appropriate block type renderer.
// Applies trailing spacing based on block role (see NotebookDesignTokens).
// Reports position of animating block for Alan presence indicator placement.
//

import SwiftUI

// MARK: - FirstLineAnchor

// Preference key for the first line of content in the active block.
// For text blocks, reports the bounds of the first text segment.
// For other blocks, reports the bounds of the content itself.
// Used to position the metaball at the vertical center of the first line.
struct FirstLineAnchor: PreferenceKey {
  static var defaultValue: Anchor<CGRect>?

  static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
    value = nextValue() ?? value
  }
}

// MARK: - BlockContainerView

// Wraps individual block renderers with layout and animation.
// Applies vertical spacing based on block role for proper rhythm.
struct BlockContainerView: View {
  let block: Block
  let animationState: BlockAnimationState
  let isMetaballTarget: Bool

  // Whether this block should report its anchor for metaball positioning.
  private var shouldReportAnchor: Bool {
    isMetaballTarget || animationState == .animating
  }

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
    case .image, .graphics, .table, .embed:
      return .content
    case .input:
      return .interactive
    }
  }

  // Routes to the appropriate block type renderer.
  // Text blocks report anchor from first line; others report from content bounds.
  @ViewBuilder
  private var blockContent: some View {
    switch block.content {
    case .text(let content):
      // TextBlockView reports FirstLineAnchor from its first segment.
      TextBlockView(
        content: content,
        animationState: animationState,
        isMetaballTarget: shouldReportAnchor
      )
    case .image(let content):
      ImageBlockView(content: content)
        .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
          shouldReportAnchor ? anchor : nil
        }
    case .graphics(let content):
      GraphicsBlockView(content: content)
        .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
          shouldReportAnchor ? anchor : nil
        }
    case .table(let content):
      TableBlockView(content: content)
        .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
          shouldReportAnchor ? anchor : nil
        }
    case .embed(let content):
      EmbedBlockView(content: content)
        .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
          shouldReportAnchor ? anchor : nil
        }
    case .input(let content):
      InputBlockView(content: content)
        .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
          shouldReportAnchor ? anchor : nil
        }
    case .checkpoint(let content):
      CheckpointBlockView(content: content)
        .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
          shouldReportAnchor ? anchor : nil
        }
    }
  }
}
