import SpriteKit
import SwiftUI

struct BoardSceneView: UIViewRepresentable {
    let renderState: BoardRenderState
    let onHexTapped: (HexCoord) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onHexTapped: onHexTapped)
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.backgroundColor = SKColor(red: 0.16, green: 0.20, blue: 0.18, alpha: 1)

        // v0.21: 放大 scene 容纳大 hex（hexSize=36），给平移余量
        let scene = BoardScene(size: CGSize(width: 1400, height: 900))
        context.coordinator.scene = scene
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.onHexTapped = onHexTapped

        if context.coordinator.scene == nil {
            let scene = BoardScene(size: uiView.bounds.size == .zero ? CGSize(width: 1400, height: 900) : uiView.bounds.size)
            context.coordinator.scene = scene
            uiView.presentScene(scene)
        }

        let coordinator = context.coordinator
        coordinator.scene?.configure(with: renderState) { coord in
            coordinator.onHexTapped(coord)
        }
    }

    final class Coordinator {
        var scene: BoardScene?
        var onHexTapped: (HexCoord) -> Void

        init(onHexTapped: @escaping (HexCoord) -> Void) {
            self.onHexTapped = onHexTapped
        }
    }
}
