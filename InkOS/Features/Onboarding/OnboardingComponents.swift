import SwiftUI

// MARK: - Question Card

// Displays a single onboarding question with answer choices.
struct QuestionCard: View {
    let question: OnboardingQuestion
    @ObservedObject var answers: OnboardingAnswers
    let onContinue: () -> Void

    // For text input questions
    @State private var textInput: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Question text
            Text(question.question)
                .font(AlanTypography.display(size: 28, weight: .regular))
                .foregroundColor(AlanColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(.bottom, AlanSpacing.xl)
                .accessibilityAddTraits(.isHeader)

            // Subtitle
            Text("This helps Alan tailor things to you.")
                .font(AlanTypography.body(size: 17, weight: .regular))
                .foregroundColor(AlanColors.textTertiary)
                .padding(.bottom, AlanSpacing.xxxl)

            // Answer choices or text input
            if question.requiresTextInput {
                TextInputField(
                    text: $textInput,
                    isFocused: $isTextFieldFocused,
                    placeholder: "Enter your name"
                )
                .padding(.bottom, AlanSpacing.lg)
            } else {
                // Pill buttons in a flow layout
                FlowLayout(spacing: AlanSpacing.lg) {
                    ForEach(question.options, id: \.self) { option in
                        PillButton(
                            title: option,
                            isSelected: answers.isSelected(option, for: question.id),
                            action: {
                                withAnimation(AlanAnimation.standard(duration: AlanAnimation.fast)) {
                                    answers.select(option, for: question.id, allowsMultiple: question.allowsMultipleSelection)
                                }
                            }
                        )
                    }
                }
                .padding(.bottom, AlanSpacing.xxl)
            }

            // Continue button
            ContinueButton(
                isEnabled: canContinue,
                action: {
                    if question.requiresTextInput {
                        answers.setTextInput(textInput, for: question.id)
                    }
                    onContinue()
                }
            )
        }
        .padding(.horizontal, AlanSpacing.lg)
        .onAppear {
            textInput = answers.getTextInput(for: question.id)
        }
    }

    private var canContinue: Bool {
        if question.requiresTextInput {
            return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return answers.hasAnswer(for: question.id)
    }
}

// MARK: - Pill Button

// A pill-shaped button for answer choices.
struct PillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AlanTypography.body(size: 17, weight: .semibold))
                .foregroundColor(isSelected ? AlanColors.textInverse : AlanColors.textSecondary)
                .padding(.horizontal, AlanDimensions.pillHorizontalPadding)
                .frame(height: AlanDimensions.pillHeight)
                .background(
                    Capsule()
                        .fill(isSelected ? AlanColors.textPrimary : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.clear, lineWidth: 0)
                )
        }
        .buttonStyle(PillButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Custom button style for pill buttons with subtle highlight effect.
private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AlanAnimation.standard(duration: AlanAnimation.instant), value: configuration.isPressed)
    }
}

// MARK: - Continue Button

// The main action button for advancing through onboarding.
struct ContinueButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Continue")
                .font(AlanTypography.body(size: 17, weight: .semibold))
                .foregroundColor(AlanColors.textInverse)
                .padding(.horizontal, AlanDimensions.continueButtonHorizontalPadding)
                .frame(height: AlanDimensions.continueButtonHeight)
                .background(
                    Capsule()
                        .fill(AlanColors.textPrimary)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityHint(isEnabled ? "Tap to continue" : "Select an answer to continue")
    }
}

// MARK: - Text Input Field

// Custom text input field for name entry.
struct TextInputField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(AlanTypography.body(size: 17, weight: .regular))
            .foregroundColor(AlanColors.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AlanSpacing.xl)
            .padding(.vertical, AlanSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isFocused.wrappedValue ? AlanColors.borderFocus : Color.clear, lineWidth: 1)
            )
            .focused(isFocused)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .frame(maxWidth: 380)
    }
}

// MARK: - Progress Bar

// Header progress bar showing onboarding progress.
struct OnboardingProgressBar: View {
    let progress: CGFloat  // 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.15))

                // Fill
                Capsule()
                    .fill(AlanColors.textPrimary)
                    .frame(width: geometry.size.width * progress)
                    .animation(AlanAnimation.standard(), value: progress)
            }
        }
        .frame(height: AlanDimensions.progressBarHeight)
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

// MARK: - Back Button

// Circular back button with chevron.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: AlanDimensions.backButtonSize, height: AlanDimensions.backButtonSize)

                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(AlanColors.textSecondary)
            }
        }
        .buttonStyle(BackButtonStyle())
        .accessibilityLabel("Go back")
    }
}

// Custom button style for back button.
private struct BackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(AlanAnimation.standard(duration: AlanAnimation.instant), value: configuration.isPressed)
    }
}

// MARK: - Flow Layout

// A layout that arranges items in rows, wrapping to new lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            let point = CGPoint(
                x: bounds.minX + position.x,
                y: bounds.minY + position.y
            )
            subviews[index].place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowItems: [(index: Int, size: CGSize)] = []
        var allRows: [[(index: Int, size: CGSize, x: CGFloat)]] = []

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width + (rowItems.isEmpty ? 0 : spacing) > maxWidth && !rowItems.isEmpty {
                // Finalize current row (center it)
                let rowWidth = currentRowWidth
                let xOffset = (maxWidth - rowWidth) / 2
                let finalizedRow = rowItems.map { (index: $0.index, size: $0.size, x: xOffset) }
                allRows.append(finalizedRow)

                totalHeight += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
                rowItems = []
            }

            rowItems.append((index: index, size: size))
            currentRowWidth += size.width + (rowItems.count > 1 ? spacing : 0)
            currentRowHeight = max(currentRowHeight, size.height)
        }

        // Finalize last row
        if !rowItems.isEmpty {
            let rowWidth = currentRowWidth
            let xOffset = (maxWidth - rowWidth) / 2
            let finalizedRow = rowItems.map { (index: $0.index, size: $0.size, x: xOffset) }
            allRows.append(finalizedRow)
            totalHeight += currentRowHeight
        }

        // Calculate positions
        positions = Array(repeating: .zero, count: subviews.count)
        var y: CGFloat = 0
        for row in allRows {
            var x = row.first?.x ?? 0
            var maxHeight: CGFloat = 0
            for item in row {
                positions[item.index] = CGPoint(x: x, y: y)
                x += item.size.width + spacing
                maxHeight = max(maxHeight, item.size.height)
            }
            y += maxHeight + spacing
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Header View

// Header with back button and progress bar.
struct OnboardingHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let showBackButton: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            if showBackButton {
                BackButton(action: onBack)
            } else {
                // Spacer to maintain layout
                Color.clear
                    .frame(width: AlanDimensions.backButtonSize, height: AlanDimensions.backButtonSize)
            }

            OnboardingProgressBar(progress: CGFloat(currentStep) / CGFloat(totalSteps))
                .padding(.trailing, 96)  // More trailing space to narrow the bar
        }
    }
}

#if DEBUG
struct OnboardingComponents_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AlanColors.void.ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                OnboardingHeader(
                    currentStep: 3,
                    totalSteps: 19,
                    showBackButton: true,
                    onBack: {}
                )
                .padding(.horizontal, 24)

                // Question card
                QuestionCard(
                    question: OnboardingQuestions.all[0],
                    answers: OnboardingAnswers(),
                    onContinue: {}
                )

                Spacer()
            }
            .padding(.top, 60)
        }
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
    }
}
#endif
