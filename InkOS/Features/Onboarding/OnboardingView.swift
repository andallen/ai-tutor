import SwiftUI

// Preference key for measuring content area frame.
private struct ContentFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// Main onboarding flow view for the Alan app.
// Presents a series of questions with scale+fade transitions between them.
struct OnboardingView: View {
    @StateObject private var answers = OnboardingAnswers()
    @State private var currentQuestionIndex = 0
    @State private var transitionDirection: TransitionDirection = .forward
    @State private var isTransitioning = false

    // Callback when onboarding completes
    let onComplete: () -> Void

    // All questions to present
    private let questions = OnboardingQuestions.all

    // Exclusion zones for ghost notation (progress bar + question content)
    @State private var exclusionZones: [CGRect] = []

    // Trigger to force ghost notation refresh with new random positions
    @State private var ghostNotationRefreshTrigger = UUID()

    var body: some View {
        GeometryReader { geometry in
            let coordinateSpace = "onboarding"

            ZStack {
                // Layer 0: Void background
                AlanColors.void
                    .ignoresSafeArea()

                // Layer 1: Ghost notation effect
                GhostNotationView(
                    speed: 1.0,
                    opacity: 0.15,
                    density: 10,
                    exclusionZones: exclusionZones,
                    refreshTrigger: ghostNotationRefreshTrigger
                )

                // Layer 2: Content
                VStack(spacing: 0) {
                    // Header with back button and progress bar
                    OnboardingHeader(
                        currentStep: currentQuestionIndex + 1,
                        totalSteps: questions.count,
                        showBackButton: currentQuestionIndex > 0,
                        onBack: goBack
                    )
                    .padding(.horizontal, AlanSpacing.lg)
                    .padding(.top, AlanSpacing.lg)

                    Spacer()

                    // Question card with transition animation
                    // Wrapped in container to measure just the content area
                    VStack {
                        ZStack {
                            ForEach(questions.indices, id: \.self) { index in
                                if index == currentQuestionIndex {
                                    QuestionCard(
                                        question: questions[index],
                                        answers: answers,
                                        onContinue: goForward
                                    )
                                    .transition(cardTransition)
                                    .zIndex(1)
                                }
                            }
                        }
                        .animation(AlanAnimation.standard(), value: currentQuestionIndex)
                    }
                    .overlay(
                        GeometryReader { contentGeometry in
                            Color.clear.preference(
                                key: ContentFrameKey.self,
                                value: contentGeometry.frame(in: .named(coordinateSpace))
                            )
                        }
                    )

                    Spacer()
                }
                .padding(.bottom, AlanSpacing.xxl)
            }
            .coordinateSpace(name: coordinateSpace)
            .task(id: currentQuestionIndex) {
                // Refresh ghost notation whenever question changes
                ghostNotationRefreshTrigger = UUID()
            }
            .onPreferenceChange(ContentFrameKey.self) { frame in
                // Create TWO exclusion zones:
                // 1. Progress bar area at top
                // 2. Question content area
                // This leaves the space BETWEEN them free for equations

                let progressBarHeight: CGFloat = 100

                let progressBarZone = CGRect(
                    x: 0,
                    y: 0,
                    width: geometry.size.width,
                    height: progressBarHeight
                )

                let contentZone = frame

                exclusionZones = [progressBarZone, contentZone]
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
    }

    // Custom transition for question cards
    private var cardTransition: AnyTransition {
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .scale(scale: 1.05).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 1.05).combined(with: .opacity)
            )
        }
    }

    // Navigate to the next question or complete onboarding.
    private func goForward() {
        guard !isTransitioning else { return }

        if currentQuestionIndex < questions.count - 1 {
            isTransitioning = true
            transitionDirection = .forward
            withAnimation(AlanAnimation.standard()) {
                currentQuestionIndex += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + AlanAnimation.normal) {
                isTransitioning = false
            }
        } else {
            completeOnboarding()
        }
    }

    // Navigate to the previous question.
    private func goBack() {
        guard !isTransitioning, currentQuestionIndex > 0 else { return }

        isTransitioning = true
        transitionDirection = .backward
        withAnimation(AlanAnimation.standard()) {
            currentQuestionIndex -= 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AlanAnimation.normal) {
            isTransitioning = false
        }
    }

    // Save answers and signal completion.
    private func completeOnboarding() {
        answers.save()
        onComplete()
    }

    private enum TransitionDirection {
        case forward
        case backward
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
            .previewDevice("iPad Pro (12.9-inch) (6th generation)")
    }
}
#endif
