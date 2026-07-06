import SwiftUI

struct NewGameButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("新开战局", systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(minHeight: SanguoDesignTokens.controlMinHeight)
        }
        .buttonStyle(.bordered)
    }
}
