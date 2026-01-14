import SwiftUI

// Root view that presents the main navigation structure of the app.
// Shows "CLAUDE WAS HERE" screen on launch.
struct AppRootView: View {
    var body: some View {
        ClaudeWasHereView()
    }
}

// Screen displayed immediately when the app launches.
struct ClaudeWasHereView: View {
    var body: some View {
        ZStack {
            AlanColors.void
                .ignoresSafeArea()

            Text("CLAUDE WAS HERE")
                .font(AlanTypography.display(size: 48, weight: .bold))
                .foregroundColor(AlanColors.textPrimary)
                .accessibilityIdentifier("claudeWasHereLabel")
        }
        .preferredColorScheme(.dark)
    }
}

// Placeholder main app view after onboarding.
// This will be replaced with the actual Alan learning interface.
struct MainAppView: View {
    var body: some View {
        ZStack {
            AlanColors.void
                .ignoresSafeArea()

            VStack(spacing: AlanSpacing.lg) {
                Text("Welcome to Alan")
                    .font(AlanTypography.display(size: 32, weight: .light))
                    .foregroundColor(AlanColors.textPrimary)

                Text("Your personalized learning experience begins here.")
                    .font(AlanTypography.body(size: 16, weight: .regular))
                    .foregroundColor(AlanColors.textSecondary)
                    .multilineTextAlignment(.center)

                // Debug button to reset onboarding
                #if DEBUG
                Button("Reset Onboarding") {
                    OnboardingAnswers.resetOnboarding()
                }
                .font(AlanTypography.body(size: 14, weight: .medium))
                .foregroundColor(AlanColors.textTertiary)
                .padding(.top, AlanSpacing.xxl)
                #endif
            }
            .padding(AlanSpacing.xl)
        }
        .preferredColorScheme(.dark)
    }
}

// Displays a loading indicator while the MyScript engine initializes.
struct EngineLoadingView: View {
    var body: some View {
        ZStack {
            AlanColors.void
                .ignoresSafeArea()

            VStack(spacing: AlanSpacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(AlanColors.textPrimary)

                Text("Initializing...")
                    .font(AlanTypography.body(size: 14, weight: .regular))
                    .foregroundColor(AlanColors.textSecondary)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Displays an error message when the MyScript engine fails to initialize.
// This prevents the user from accessing the app without a working engine.
struct EngineErrorView: View {
    let errorMessage: String

    var body: some View {
        ZStack {
            AlanColors.void
                .ignoresSafeArea()

            VStack(spacing: AlanSpacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AlanColors.accentConfidence)

                Text("Engine Initialization Failed")
                    .font(AlanTypography.display(size: 24, weight: .medium))
                    .foregroundColor(AlanColors.textPrimary)

                Text(errorMessage)
                    .font(AlanTypography.body(size: 14, weight: .regular))
                    .foregroundColor(AlanColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AlanSpacing.xl)

                Text("Please ensure your MyScript certificate is valid and your bundle ID matches.")
                    .font(AlanTypography.body(size: 12, weight: .regular))
                    .foregroundColor(AlanColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AlanSpacing.xl)
            }
            .padding(AlanSpacing.lg)
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
  struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        AppRootView()
        EngineLoadingView()
        EngineErrorView(errorMessage: "Invalid certificate or application identifier mismatch.")
      }
    }
  }
#endif
