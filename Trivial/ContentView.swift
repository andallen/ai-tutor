import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            DashboardMockupView()
        }
    }
}

struct DashboardMockupView: View {
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 22, alignment: .top)
    ]

    var body: some View {
        ZStack {
            BackgroundWhite()
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 18) {
                Sidebar()
                    .frame(width: 240)

                ScrollView(showsIndicators: false) {
                    RightPane(columns: columns)
                        .padding(.vertical, 18)
                        .padding(.trailing, 22)
                        .padding(.leading, 6)
                }
            }
            .padding(.leading, 22)
        }
        .fontDesign(.rounded)
    }
}

private struct RightPane: View {
    let columns: [GridItem]
    
    private let notes: [(title: String, subtitle: String, date: String)] = [
        ("Linear Algebra — Eigenvectors", "Intuition, geometric meaning, and worked examples…", "Dec 18")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Notes")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.ink)

            SearchBar()

            Spacer().frame(height: 10)
            Capsule()
                .fill(Color.separator)
                .frame(height: 1)
                .padding(.trailing, 6)
            Spacer().frame(height: 14)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                NewNoteCard()
                
                ForEach(notes, id: \.title) { note in
                    NavigationLink(value: note.title) {
                        NoteCard(title: note.title, subtitle: note.subtitle, date: note.date)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: String.self) { notebookName in
                NotebookView(notebookName: notebookName)
            }

            Spacer(minLength: 22)
        }
    }
}

private struct BackgroundWhite: View {
    var body: some View {
        ZStack {
            Color.white

            RadialGradient(colors: [
                Color.black.opacity(0.06),
                Color.clear
            ], center: .topTrailing, startRadius: 40, endRadius: 520)
            .blendMode(.multiply)

            RadialGradient(colors: [
                Color.black.opacity(0.04),
                Color.clear
            ], center: .bottomLeading, startRadius: 60, endRadius: 620)
            .blendMode(.multiply)
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SidebarRow(icon: "tray.full", title: "Notes")

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .glassBackground(cornerRadius: 18)
    }
}

private struct SidebarRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(Color.inkSubtle)

            Text(title)
                .font(.system(.body))
                .foregroundStyle(Color.ink)

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Search

private struct SearchBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkSubtle)

            Text("Search")
                .font(.system(.body))
                .foregroundStyle(Color.inkFaint)

            Spacer()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: 12)
    }
}

// MARK: - Notebook View

struct NotebookView: View {
    let notebookName: String
    
    var body: some View {
        ZStack {
            BackgroundWhite()
                .ignoresSafeArea()
            
            VStack {
                Text(notebookName)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }
        }
        .fontDesign(.rounded)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Cards

private struct NoteCard: View {
    let title: String
    let subtitle: String
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(2)

            Text(subtitle)
                .font(.system(.body))
                .foregroundStyle(Color.inkSubtle)
                .lineSpacing(3)
                .lineLimit(3)

            Spacer(minLength: 0)

            Text(date.uppercased())
                .font(.system(.footnote))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .glassBackground(cornerRadius: 14)
    }
}

private struct NewNoteCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.inkSubtle)

            Text("New note")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Color.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 160)
        .glassBackground(cornerRadius: 14)
    }
}

// MARK: - View Modifiers

private extension View {
    func glassBackground(cornerRadius: CGFloat) -> some View {
        Group {
            if #available(iOS 18.0, *) {
                self
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.rule, lineWidth: 1)
                    )
            } else {
                let opacity: Double = cornerRadius == 18 ? 0.82 : (cornerRadius == 12 ? 0.86 : 0.92)
                self
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(opacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.rule, lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Colors

private extension Color {
    static let rule      = Color.black.opacity(0.10)
    static let separator = Color.black.opacity(0.14)

    static let ink       = Color.black.opacity(0.88)
    static let inkSubtle = Color.black.opacity(0.62)
    static let inkFaint  = Color.black.opacity(0.40)
}

#Preview {
    ContentView()
}
