import SwiftUI

// Root view that presents the main navigation structure of the app.
struct AppRootView: View {
    
  var body: some View {
    NavigationStack {
      DashboardView()
    }
  }
}

#Preview {
  AppRootView()
}
