import SwiftUI

private struct SearchFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .font(.system(size: 16))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: SearchFrameKey.self, value: geo.frame(in: .global))
            }
        )
        .onPreferenceChange(SearchFrameKey.self) { frame in
            SearchFieldGeometry.frame = frame
        }
        .onAppear { focused = true }
    }
}
