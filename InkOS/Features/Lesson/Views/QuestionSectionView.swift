//
// QuestionSectionView.swift
// InkOS
//
// Displays question sections with interactive answer input.
// Supports multiple choice, free response, and math question types.
//

import SwiftUI

// Container for question sections that routes to the appropriate view.
struct QuestionSectionView: View {
  let section: QuestionSection
  @ObservedObject var viewModel: LessonViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      // Question prompt.
      Text(section.prompt)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Color.ink)
        .lineSpacing(4)

      // Question input based on type.
      switch section.questionType {
      case .multipleChoice:
        if let options = section.options {
          MultipleChoiceView(
            sectionID: section.id,
            options: options,
            correctAnswer: section.answer,
            viewModel: viewModel
          )
        }

      case .freeResponse:
        FreeResponsePlaceholderView(section: section, viewModel: viewModel)

      case .math:
        MathPlaceholderView(section: section, viewModel: viewModel)
      }

      // Answer feedback.
      if let answerState = viewModel.answerStates[section.id] {
        AnswerFeedbackView(state: answerState, correctAnswer: section.answer)
      }
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color.white)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Color.rule, lineWidth: 1)
    )
  }
}

// MARK: - Multiple Choice View

// Interactive multiple choice question with selectable options.
struct MultipleChoiceView: View {
  let sectionID: String
  let options: [String]
  let correctAnswer: String
  @ObservedObject var viewModel: LessonViewModel

  // Current answer state.
  private var answerState: AnswerState {
    viewModel.answerStates[sectionID] ?? .unanswered
  }

  // Currently selected answer.
  private var selectedAnswer: String? {
    viewModel.selectedAnswers[sectionID]
  }

  // Whether the user can still modify their answer.
  private var canModify: Bool {
    switch answerState {
    case .unanswered, .selected:
      return true
    case .checking, .correct, .incorrect, .revealed:
      return false
    }
  }

  var body: some View {
    VStack(spacing: 12) {
      // Option buttons.
      ForEach(options, id: \.self) { option in
        OptionButton(
          text: option,
          isSelected: selectedAnswer == option,
          state: optionState(for: option),
          action: {
            if canModify {
              viewModel.selectAnswer(option, for: sectionID)
            }
          }
        )
      }

      // Action buttons.
      HStack(spacing: 16) {
        // Check button.
        Button {
          Task {
            await viewModel.checkAnswer(for: sectionID)
          }
        } label: {
          Text(checkButtonText)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(checkButtonDisabled ? Color.inkFaint : Color.lessonAccent)
            )
        }
        .disabled(checkButtonDisabled)

        // Show Answer button.
        Button {
          viewModel.revealAnswer(for: sectionID)
        } label: {
          Text("Show Answer")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.lessonAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.lessonAccent, lineWidth: 1.5)
            )
        }
        .disabled(showAnswerDisabled)
        .opacity(showAnswerDisabled ? 0.5 : 1.0)
      }
      .padding(.top, 8)
    }
  }

  // Returns the visual state for an option based on the answer state.
  private func optionState(for option: String) -> OptionState {
    switch answerState {
    case .unanswered:
      return .normal

    case .selected:
      return selectedAnswer == option ? .selected : .normal

    case .checking:
      return selectedAnswer == option ? .selected : .normal

    case .correct:
      if option == correctAnswer {
        return .correct
      }
      return selectedAnswer == option ? .selected : .normal

    case .incorrect:
      if option == correctAnswer {
        return .correct
      }
      if selectedAnswer == option {
        return .incorrect
      }
      return .normal

    case .revealed:
      return option == correctAnswer ? .correct : .normal
    }
  }

  // Check button text based on state.
  private var checkButtonText: String {
    switch answerState {
    case .checking:
      return "Checking..."
    case .correct, .incorrect:
      return "Checked"
    default:
      return "Check"
    }
  }

  // Whether the check button should be disabled.
  private var checkButtonDisabled: Bool {
    switch answerState {
    case .unanswered:
      return true
    case .checking, .correct, .incorrect, .revealed:
      return true
    case .selected:
      return false
    }
  }

  // Whether the show answer button should be disabled.
  private var showAnswerDisabled: Bool {
    switch answerState {
    case .revealed, .correct:
      return true
    default:
      return false
    }
  }
}

// MARK: - Option Button

// Visual state for an option button.
enum OptionState {
  case normal
  case selected
  case correct
  case incorrect
}

// A single option button in a multiple choice question.
struct OptionButton: View {
  let text: String
  let isSelected: Bool
  let state: OptionState
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        // Radio indicator.
        ZStack {
          Circle()
            .stroke(borderColor, lineWidth: isSelected ? 2 : 1.5)
            .frame(width: 22, height: 22)

          if isSelected || state == .correct || state == .incorrect {
            Circle()
              .fill(fillColor)
              .frame(width: 12, height: 12)
          }
        }

        // Option text.
        Text(text)
          .font(.system(size: 16))
          .foregroundStyle(Color.ink)
          .multilineTextAlignment(.leading)

        Spacer()

        // Status icon.
        if state == .correct {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.correctGreen)
        } else if state == .incorrect {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.incorrectRed)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(minHeight: 52)
      .background(backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
      )
    }
    .buttonStyle(PlainButtonStyle())
    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: state)
  }

  // Border color based on state.
  private var borderColor: Color {
    switch state {
    case .normal:
      return isSelected ? Color.lessonAccent : Color.rule
    case .selected:
      return Color.lessonAccent
    case .correct:
      return Color.correctGreen
    case .incorrect:
      return Color.incorrectRed
    }
  }

  // Fill color for the radio indicator.
  private var fillColor: Color {
    switch state {
    case .normal, .selected:
      return Color.lessonAccent
    case .correct:
      return Color.correctGreen
    case .incorrect:
      return Color.incorrectRed
    }
  }

  // Background color based on state.
  private var backgroundColor: Color {
    switch state {
    case .normal:
      return isSelected ? Color.lessonAccent.opacity(0.08) : Color.white
    case .selected:
      return Color.lessonAccent.opacity(0.08)
    case .correct:
      return Color.correctGreen.opacity(0.08)
    case .incorrect:
      return Color.incorrectRed.opacity(0.08)
    }
  }
}

// MARK: - Answer Feedback View

// Displays feedback after an answer is checked.
struct AnswerFeedbackView: View {
  let state: AnswerState
  let correctAnswer: String

  var body: some View {
    Group {
      switch state {
      case .correct(let feedback):
        feedbackCard(isCorrect: true, feedback: feedback)

      case .incorrect(let feedback):
        feedbackCard(isCorrect: false, feedback: feedback)

      case .revealed:
        revealedAnswerCard()

      default:
        EmptyView()
      }
    }
    .transition(.asymmetric(
      insertion: .move(edge: .bottom).combined(with: .opacity),
      removal: .opacity
    ))
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: feedbackKey)
  }

  // Unique key for animations.
  private var feedbackKey: String {
    switch state {
    case .correct: return "correct"
    case .incorrect: return "incorrect"
    case .revealed: return "revealed"
    default: return "none"
    }
  }

  // Feedback card for correct/incorrect answers.
  @ViewBuilder
  private func feedbackCard(isCorrect: Bool, feedback: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.system(size: 24))
        .foregroundStyle(isCorrect ? Color.correctGreen : Color.incorrectRed)

      VStack(alignment: .leading, spacing: 4) {
        Text(isCorrect ? "Correct!" : "Not quite")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.ink)

        Text(feedback)
          .font(.system(size: 15))
          .foregroundStyle(Color.inkSubtle)
          .lineSpacing(3)
      }

      Spacer()
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(isCorrect ? Color.correctGreen.opacity(0.08) : Color.incorrectRed.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(isCorrect ? Color.correctGreen.opacity(0.25) : Color.incorrectRed.opacity(0.25), lineWidth: 1)
    )
  }

  // Card showing the revealed correct answer.
  @ViewBuilder
  private func revealedAnswerCard() -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lightbulb.fill")
        .font(.system(size: 24))
        .foregroundStyle(Color.lessonAccent)

      VStack(alignment: .leading, spacing: 4) {
        Text("Correct Answer")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.ink)

        Text(correctAnswer)
          .font(.system(size: 15))
          .foregroundStyle(Color.inkSubtle)
      }

      Spacer()
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.lessonAccent.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.lessonAccent.opacity(0.25), lineWidth: 1)
    )
  }
}

// MARK: - Placeholder Views for Free Response and Math

// Placeholder for free response questions (handwriting deferred).
struct FreeResponsePlaceholderView: View {
  let section: QuestionSection
  @ObservedObject var viewModel: LessonViewModel

  @State private var textInput: String = ""

  var body: some View {
    VStack(spacing: 12) {
      // Text input area.
      TextEditor(text: $textInput)
        .font(.system(size: 17))
        .foregroundStyle(Color.ink)
        .frame(minHeight: 120)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.rule, lineWidth: 1)
        )
        .overlay(
          Group {
            if textInput.isEmpty {
              Text("Type your answer...")
                .font(.system(size: 17))
                .foregroundStyle(Color.inkFaint)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .allowsHitTesting(false)
            }
          },
          alignment: .topLeading
        )

      // Keyboard toggle hint (handwriting not yet implemented).
      HStack {
        Image(systemName: "keyboard")
          .font(.system(size: 14))
        Text("Handwriting input coming soon")
          .font(.system(size: 13))
      }
      .foregroundStyle(Color.inkFaint)

      // Action buttons.
      HStack(spacing: 16) {
        Button {
          if !textInput.isEmpty {
            viewModel.selectAnswer(textInput, for: section.id)
            Task {
              await viewModel.checkAnswer(for: section.id)
            }
          }
        } label: {
          Text("Check")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(textInput.isEmpty ? Color.inkFaint : Color.lessonAccent)
            )
        }
        .disabled(textInput.isEmpty)

        Button {
          viewModel.revealAnswer(for: section.id)
        } label: {
          Text("Show Answer")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.lessonAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.lessonAccent, lineWidth: 1.5)
            )
        }
      }
    }
  }
}

// Placeholder for math questions (MyScript math mode deferred).
struct MathPlaceholderView: View {
  let section: QuestionSection
  @ObservedObject var viewModel: LessonViewModel

  @State private var textInput: String = ""

  var body: some View {
    VStack(spacing: 12) {
      // Text input area with math hint.
      TextEditor(text: $textInput)
        .font(.system(size: 17, design: .default))
        .foregroundStyle(Color.ink)
        .frame(minHeight: 100)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.rule, lineWidth: 1)
        )
        .overlay(
          Group {
            if textInput.isEmpty {
              Text("Type your equation...")
                .font(.system(size: 17))
                .foregroundStyle(Color.inkFaint)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .allowsHitTesting(false)
            }
          },
          alignment: .topLeading
        )

      // Math mode hint.
      HStack {
        Image(systemName: "function")
          .font(.system(size: 14))
        Text("Math handwriting recognition coming soon")
          .font(.system(size: 13))
      }
      .foregroundStyle(Color.inkFaint)

      // Action buttons.
      HStack(spacing: 16) {
        Button {
          if !textInput.isEmpty {
            viewModel.selectAnswer(textInput, for: section.id)
            Task {
              await viewModel.checkAnswer(for: section.id)
            }
          }
        } label: {
          Text("Check")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(textInput.isEmpty ? Color.inkFaint : Color.lessonAccent)
            )
        }
        .disabled(textInput.isEmpty)

        Button {
          viewModel.revealAnswer(for: section.id)
        } label: {
          Text("Show Answer")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.lessonAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.lessonAccent, lineWidth: 1.5)
            )
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  let sampleQuestion = QuestionSection(
    questionType: .multipleChoice,
    prompt: "Which organelle is responsible for photosynthesis?",
    options: ["Mitochondria", "Chloroplast", "Nucleus", "Ribosome"],
    answer: "Chloroplast",
    explanation: "Chloroplasts contain chlorophyll and are the site of photosynthesis in plant cells."
  )

  return ScrollView {
    QuestionSectionView(section: sampleQuestion, viewModel: LessonViewModel())
      .padding(24)
  }
  .background(BackgroundWhite())
}
