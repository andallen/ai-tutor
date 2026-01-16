import SwiftUI

// Root view that presents the notebook canvas renderer.
struct AppRootView: View {
    @State private var viewModel = NotebookViewModel(document: .preview)

    var body: some View {
        NotebookCanvasView(viewModel: viewModel)
            .ignoresSafeArea()
    }
}

#if DEBUG
struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
        AppRootView()
    }
}
#endif
