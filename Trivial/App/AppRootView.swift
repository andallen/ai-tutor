import SwiftUI

// Root view that presents the main navigation structure of the app.
// Validates that the MyScript engine initialized successfully on launch.
struct AppRootView: View {
  // Track whether the engine failed to initialize.
  @State private var engineError: String?

  var body: some View {
    Group {
      if let errorMessage = engineError {
        // Display an error view if the engine failed to initialize.
        EngineErrorView(errorMessage: errorMessage)
      } else {
        // Normal app flow with the Dashboard.
        NavigationStack {
          DashboardView()
        }
      }
    }
    .task {
      // Validate engine initialization on launch.
      // Access the engine property to trigger lazy initialization.
      let provider = EngineProvider.shared
      if provider.engine == nil {
        engineError = provider.engineErrorMessage
      }
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

#Preview("Normal") {
  AppRootView()
}

#Preview("Engine Error") {
  EngineErrorView(errorMessage: "Invalid certificate or application identifier mismatch.")
}
