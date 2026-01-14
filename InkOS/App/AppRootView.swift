import SwiftUI

// Placeholder root view while the new Branch architecture is being built.
struct AppRootView: View {
  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "hammer.fill")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      Text("Coming Soon")
        .font(.title)
        .fontWeight(.semibold)

      Text("Building something new...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

#if DEBUG
struct AppRootView_Previews: PreviewProvider {
  static var previews: some View {
    AppRootView()
  }
}
#endif
