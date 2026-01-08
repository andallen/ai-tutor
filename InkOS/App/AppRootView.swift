import SwiftUI

// Root view that presents the main navigation structure of the app.
// Validates that the MyScript engine initialized successfully on launch.
struct AppRootView: View {
  // Track whether the engine failed to initialize.
  @State private var engineError: String?

  // Track whether engine initialization is in progress.
  @State private var isInitializing = true

  var body: some View {
    Group {
      if isInitializing {
        // Show loading indicator while engine initializes.
        EngineLoadingView()
      } else if let errorMessage = engineError {
        // Display an error view if the engine failed to initialize.
        EngineErrorView(errorMessage: errorMessage)
      } else {
        // Normal app flow with the Dashboard.
        // Use feature flag to switch between SwiftUI and UIKit implementations.
        if DashboardFeatureFlags.useUIKitDashboard {
          DashboardHostView()
        } else {
          NavigationStack {
            DashboardView()
          }
        }
      }
    }
    .task {
      // Initialize the GetStarted engine lazily to match the reference behavior.
      let provider = EngineProvider.sharedInstance
      _ = provider.engine

      if provider.engine == nil {
        engineError = provider.engineErrorMessage
      }

      isInitializing = false
    }
  }
}

// Displays a loading indicator while the MyScript engine initializes.
struct EngineLoadingView: View {
  var body: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.5)

      Text("Initializing...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

// Displays an error message when the MyScript engine fails to initialize.
// This prevents the user from accessing the app without a working engine.
struct EngineErrorView: View {
  let errorMessage: String

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.orange)

      Text("Engine Initialization Failed")
        .font(.title2)
        .fontWeight(.semibold)

      Text(errorMessage)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Text("Please ensure your MyScript certificate is valid and your bundle ID matches.")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
    .padding()
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
