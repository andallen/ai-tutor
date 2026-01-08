//
// SummarySectionView.swift
// InkOS
//
// Displays summary sections with key takeaways.
// Styled as a highlighted card with bullet points.
//

import SwiftUI

// Renders a summary section with key takeaways.
struct SummarySectionView: View {
  let section: SummarySection
  @ObservedObject var viewModel: LessonViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Card container with accent tint.
      VStack(alignment: .leading, spacing: 0) {
        // Header.
        HStack(spacing: 10) {
          Image(systemName: "lightbulb.fill")
            .font(.system(size: 18))
            .foregroundStyle(Color.lessonAccent)

          Text("Key Takeaways")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

        // Divider.
        Rectangle()
          .fill(Color.rule)
          .frame(height: 1)

        // Content.
        VStack(alignment: .leading, spacing: 12) {
          MarkdownTextView(text: section.content)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color.lessonAccent.opacity(0.05))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.lessonAccent.opacity(0.20), lineWidth: 1)
      )
    }
  }
}

// MARK: - Preview

#Preview {
  let sampleSummary = SummarySection(
    content: """
      - Photosynthesis converts light energy to chemical energy
      - Takes place in chloroplasts
      - Produces glucose and oxygen from CO₂ and water
      """
  )

  return ScrollView {
    SummarySectionView(section: sampleSummary, viewModel: LessonViewModel())
      .padding(24)
  }
  .background(Color.white)
}
