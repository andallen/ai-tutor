import SwiftUI

// Root view for the search overlay window.
struct SearchOverlayRootView: View {
  @ObservedObject var state: SearchOverlayState
  let onDismiss: () -> Void
  let onClear: () -> Void
  let onResultTapped: (SearchResult) -> Void

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
        // Blur background (tap to dismiss).
        // Always present so it can smoothly fade in/out.
        AnimatedBlurView(
          blurFraction: state.isExpanded ? 1 : 0,
          animationDuration: state.isExpanded ? 0.35 : 0.2
        )
        .ignoresSafeArea()
        .onTapGesture {
          print("[DashboardView] Blur background tapped - dismissing search")
          onDismiss()
        }
        .allowsHitTesting(state.isExpanded)

        // Glass panel with search bar row and results.
        VStack(spacing: 0) {
          // Search bar row with a separate clear button.
          HStack(spacing: 12) {
            // Search bar fills the remaining width.
            DashboardSearchBar(
              text: $state.searchText,
              isFocused: $state.isSearchFieldFocused
            )
            .frame(maxWidth: .infinity)

            // Clear button sits outside the search bar.
            Button {
              print("[DashboardView] Clear button tapped")
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
            // Button stays visible but inactive when there is no text.
            .buttonStyle(.plain)
            .disabled(state.searchText.isEmpty)
            .opacity(state.searchText.isEmpty ? 0.4 : 1)
            .overlay(HitTestLoggerView(label: "SearchClearButton"))
            .simultaneousGesture(
              TapGesture().onEnded {
                print("[DashboardView] Clear button TapGesture fired")
              }
            )
          }
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .padding(.bottom, 12)
          .overlay(HitTestLoggerView(label: "SearchBarRow"))
          .simultaneousGesture(
            TapGesture().onEnded {
              print("[DashboardView] Search bar row TapGesture fired")
            }
          )

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
        .overlay(HitTestLoggerView(label: "SearchOverlayPanel"))
        .frame(width: overlayWidth, height: overlayHeight)
        .background(
          Group {
            if #available(iOS 26.0, *) {
              RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            } else {
              RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            }
          }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .position(x: screenWidth / 2, y: safeAreaTop + 16 + overlayHeight / 2)
        .offset(y: state.isExpanded ? 0 : -slideDistance)
        .animation(
          .spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0),
          value: state.isExpanded
        )
        .allowsHitTesting(state.isExpanded)
      }
      .overlay(HitTestLoggerView(label: "SearchOverlayZStack"))
      // Logs window-level taps while the overlay is visible.
      .background(
        Group {
          if state.isExpanded {
            WindowTapLoggerView(label: "SearchOverlayWindow")
              .frame(width: 1, height: 1)
          }
        }
      )
    }
    .ignoresSafeArea()
    .zIndex(160)
    .allowsHitTesting(state.isExpanded)
    .fontDesign(.rounded)
    .tint(Color.offBlack)
  }
}
