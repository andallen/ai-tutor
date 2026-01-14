import SwiftUI

// Root view for the search overlay window.
struct SearchOverlayRootView: View {
  @ObservedObject var state: SearchOverlayState
  let onDismiss: () -> Void
  let onClear: () -> Void
  let onResultTapped: (SearchResult) -> Void

  // Debug callbacks for populating and clearing test data.
  #if DEBUG
  var onPopulateDebugData: (() -> Void)?
  var onClearDebugData: (() -> Void)?
  #endif

  var body: some View {
    GeometryReader { geometry in
      let safeAreaTop = geometry.safeAreaInsets.top
      let screenWidth = geometry.size.width
      let screenHeight = geometry.size.height

      // Overlay dimensions (clamped to non-negative to avoid invalid frame warnings).
      let overlayWidth = max(0, min(screenWidth - 48, 500))
      let overlayHeight = max(0, min(screenHeight * 0.6, 480))
      let cornerRadius: CGFloat = 24
      let slideDistance = overlayHeight + safeAreaTop + 50

      ZStack {
        // Layer 1: Blur background (visual only, no hit testing).
        AnimatedBlurView(
          blurFraction: state.isExpanded ? 1 : 0,
          animationDuration: state.isExpanded ? 0.35 : 0.2
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)

        // Layer 2: Tap-to-dismiss layer covering the entire screen.
        Color.black.opacity(0.001)
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            dismissOverlay()
          }
          .allowsHitTesting(state.isExpanded)

        // Layer 3: Glass panel with search bar and results.
        VStack(spacing: 0) {
          // Search bar row.
          HStack(spacing: 12) {
            DashboardSearchBar(
              text: $state.searchText,
              isFocused: $state.isSearchFieldFocused
            )
            .frame(maxWidth: .infinity)

            // Clear button.
            Button {
              onClear()
            } label: {
              Text("Clear")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.inkSubtle)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  Capsule()
                    .fill(Color.black.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .disabled(state.searchText.isEmpty)
            .opacity(state.searchText.isEmpty ? 0.4 : 1)
          }
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .padding(.bottom, 12)

          // Debug buttons for testing.
          #if DEBUG
          if onPopulateDebugData != nil || onClearDebugData != nil {
            HStack(spacing: 12) {
              if let onPopulate = onPopulateDebugData {
                Button {
                  onPopulate()
                } label: {
                  HStack(spacing: 4) {
                    Image(systemName: "testtube.2")
                      .font(.system(size: 12))
                    Text("Populate")
                      .font(.system(size: 12, weight: .medium))
                  }
                  .foregroundColor(.white)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(
                    Capsule()
                      .fill(Color.green.opacity(0.8))
                  )
                }
                .buttonStyle(.plain)
              }

              if let onClear = onClearDebugData {
                Button {
                  onClear()
                } label: {
                  HStack(spacing: 4) {
                    Image(systemName: "trash")
                      .font(.system(size: 12))
                    Text("Clear Debug")
                      .font(.system(size: 12, weight: .medium))
                  }
                  .foregroundColor(.white)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(
                    Capsule()
                      .fill(Color.red.opacity(0.8))
                  )
                }
                .buttonStyle(.plain)
              }

              Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
          }
          #endif

          // Results list.
          DashboardSearchResults(
            results: state.searchResults,
            query: state.searchText,
            isLoading: state.isSearching,
            onResultTapped: { result in
              onResultTapped(result)
            }
          )
          .padding(.bottom, 16)
        }
        .frame(width: overlayWidth, height: overlayHeight)
        .liquidGlassBackground(cornerRadius: cornerRadius, style: .regular)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .position(x: screenWidth / 2, y: safeAreaTop + 16 + overlayHeight / 2)
        .offset(y: state.isExpanded ? 0 : -slideDistance)
        .animation(
          .spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0),
          value: state.isExpanded
        )
        .allowsHitTesting(state.isExpanded)
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(state.isExpanded)
    .fontDesign(.rounded)
    .tint(Color.offBlack)
  }

  private func dismissOverlay() {
    // Dismiss keyboard first.
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil
    )
    onDismiss()
  }
}

