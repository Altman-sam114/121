import SpriteKit
import UIKit

final class BoardScene: SKScene {
    private var renderState: BoardRenderState?
    private var layout: HexLayout?
    private var onHexTapped: ((HexCoord) -> Void)?
    // v0.21: camera 平移
    private var boardCamera: SKCameraNode?
    private var lastDragViewPosition: CGPoint?
    private var totalDragDistance: CGFloat = 0
    private let tapThreshold: CGFloat = 8

    override init(size: CGSize) {
        super.init(size: size)
        // v0.21: resizeFill 让 scene 跟 SKView 同尺寸；hex 大小由 HexLayout.fixed 决定（不塞满），
        // 超出 view 的 hex 画在 scene 外，由平移（任务 0.2）暴露。
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.16, green: 0.20, blue: 0.18, alpha: 1.0)
        setupCamera()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.16, green: 0.20, blue: 0.18, alpha: 1.0)
        setupCamera()
    }

    private func setupCamera() {
        let camera = SKCameraNode()
        self.camera = camera
        addChild(camera)
        self.boardCamera = camera
    }

    func configure(with renderState: BoardRenderState, onHexTapped: @escaping (HexCoord) -> Void) {
        self.renderState = renderState
        self.onHexTapped = onHexTapped
        redraw()
    }

    override func didMove(to view: SKView) {
        redraw()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        redraw()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view else { return }
        lastDragViewPosition = touch.location(in: view)
        totalDragDistance = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let view,
              let prev = lastDragViewPosition,
              let camera = boardCamera else {
            return
        }
        let current = touch.location(in: view)
        let delta = CGPoint(x: current.x - prev.x, y: current.y - prev.y)
        totalDragDistance += hypot(delta.x, delta.y)
        // 拖动方向反转（手指右移 → 内容右移 → camera 左移）
        camera.position.x -= delta.x
        camera.position.y += delta.y
        clampCamera()
        lastDragViewPosition = current
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            lastDragViewPosition = nil
        }
        // 累计拖动超阈值视为平移，不当 tap
        guard totalDragDistance < tapThreshold,
              let touch = touches.first,
              let layout,
              let state = renderState?.gameState else {
            return
        }

        let point = touch.location(in: self)
        let coord = layout.pixelToHex(point)
        guard state.map.contains(coord) else {
            return
        }

        onHexTapped?(coord)
    }

    /// 限制 camera 在地图边界内，避免拖空。
    private func clampCamera() {
        guard let layout, let state = renderState?.gameState else { return }
        let mapWidth = state.map.width
        let mapHeight = state.map.height
        // 地图四角像素（fixed layout 下）
        let corners: [CGPoint] = [
            layout.hexToPixel(HexCoord(q: 0, r: 0)),
            layout.hexToPixel(HexCoord(q: mapWidth - 1, r: 0)),
            layout.hexToPixel(HexCoord(q: 0, r: mapHeight - 1)),
            layout.hexToPixel(HexCoord(q: mapWidth - 1, r: mapHeight - 1))
        ]
        let minX = corners.map(\.x).min() ?? 0
        let maxX = corners.map(\.x).max() ?? 0
        let minY = corners.map(\.y).min() ?? 0
        let maxY = corners.map(\.y).max() ?? 0
        let margin = layout.hexSize
        if let camera = boardCamera {
            camera.position.x = min(max(camera.position.x, minX - margin), maxX + margin)
            camera.position.y = min(max(camera.position.y, minY - margin), maxY + margin)
        }
    }

    private func redraw() {
        // v0.21: 保 camera，只清内容节点
        let cameraRef = boardCamera
        removeAllChildren()
        if let cameraRef {
            addChild(cameraRef)
            self.camera = cameraRef
            self.boardCamera = cameraRef
        }

        guard let renderState else {
            drawEmptyState()
            return
        }

        let state = renderState.gameState
        // v0.21: 固定大 hexSize（~36），不再 fitted 塞满 scene。超出靠平移（任务 0.2）。
        let layout = HexLayout.fixed(mapWidth: state.map.width, mapHeight: state.map.height)
        self.layout = layout

        drawTiles(renderState: renderState, layout: layout)
        drawLayerOverlay(renderState: renderState, layout: layout)
        drawRegionOverlays(renderState: renderState, layout: layout)
        drawRoads(map: state.map, layout: layout)
        drawRivers(map: state.map, layout: layout)
        drawUnits(renderState: renderState, layout: layout)
    }

    private func drawTiles(renderState: BoardRenderState, layout: HexLayout) {
        let state = renderState.gameState
        let supplyByCoord = Dictionary(uniqueKeysWithValues: state.map.supplySources.compactMap { source in
            state.map.controllingFaction(for: source).map { (source.coord, $0) }
        })
        let adapter = renderState.displayAdapter

        for tile in state.map.tiles.values.sorted(by: tileSort) {
            guard let displayState = adapter.hexDisplayState(for: tile.coord, viewerFaction: renderState.viewerFaction) else {
                continue
            }

            let node = HexNode(
                displayState: displayState,
                layout: layout,
                supplySourceFaction: supplyByCoord[tile.coord],
                isSelected: renderState.selectedHex == tile.coord,
                isMoveHighlighted: renderState.movementHighlights.contains(tile.coord),
                isAttackHighlighted: renderState.attackHighlights.contains(tile.coord)
            )
            addChild(node)
        }
    }

    private func drawRoads(map: MapState, layout: HexLayout) {
        let directions: [HexDirection] = [.east, .southEast, .southWest]

        for tile in map.tiles.values where tile.hasRoad {
            for direction in directions {
                let nextCoord = tile.coord.neighbor(in: direction)
                guard let nextTile = map.tile(at: nextCoord),
                      nextTile.hasRoad else {
                    continue
                }

                let start = layout.hexToPixel(tile.coord)
                let end = layout.hexToPixel(nextCoord)
                let path = CGMutablePath()
                path.move(to: start)
                path.addLine(to: end)

                let road = SKShapeNode(path: path)
                road.strokeColor = TerrainStyle.roadStroke
                road.lineWidth = max(2, layout.hexSize * 0.08)
                road.lineCap = .round
                road.zPosition = 15
                addChild(road)
            }
        }
    }

    private func drawRegionOverlays(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer == .hex else {
            return
        }

        for region in renderState.gameState.map.regions.values {
            let node = RegionOverlayNode(
                region: region,
                layout: layout,
                isSelected: renderState.selectedRegionId == region.id
            )
            addChild(node)
        }
    }

    private func drawLayerOverlay(renderState: BoardRenderState, layout: HexLayout) {
        let node = MapLayerOverlayNode(
            state: renderState.gameState,
            layer: renderState.mapDisplayLayer,
            layout: layout
        )
        addChild(node)
    }

    private func drawRivers(map: MapState, layout: HexLayout) {
        for tile in map.tiles.values {
            let center = layout.hexToPixel(tile.coord)
            for direction in HexDirection.ordered where tile.riverEdges.contains(direction) {
                let edge = layout.edgePoints(center: center, direction: direction)
                let path = CGMutablePath()
                path.move(to: edge.0)
                path.addLine(to: edge.1)

                let river = SKShapeNode(path: path)
                river.strokeColor = TerrainStyle.riverStroke
                river.lineWidth = max(3, layout.hexSize * 0.10)
                river.lineCap = .round
                river.zPosition = 18
                addChild(river)
            }
        }
    }

    private func drawUnits(renderState: BoardRenderState, layout: HexLayout) {
        guard renderState.mapDisplayLayer != .frontLine else {
            return
        }
        let adapter = renderState.displayAdapter
        let placements = adapter.unitPlacements(viewerFaction: renderState.viewerFaction)

        let divisions = renderState.gameState.divisions.sorted { lhs, rhs in
            let lhsHex = adapter.unitDisplayHex(for: lhs) ?? lhs.coord
            let rhsHex = adapter.unitDisplayHex(for: rhs) ?? rhs.coord
            if lhsHex.r == rhsHex.r {
                return lhsHex.q < rhsHex.q
            }
            return lhsHex.r < rhsHex.r
        }

        for division in divisions {
            guard let placement = placements[division.id] else {
                continue
            }

            let node = UnitNode(
                division: division,
                layout: layout,
                placement: placement,
                isSelected: renderState.selectedUnitId == division.id,
                fillColorOverride: deploymentColorOverride(for: division, renderState: renderState)
            )
            addChild(node)
        }
    }

    private func deploymentColorOverride(for division: Division, renderState: BoardRenderState) -> SKColor? {
        guard renderState.mapDisplayLayer == .deployment else {
            return nil
        }
        let role = WarDeploymentManager().deploymentRole(
            for: division,
            in: renderState.gameState.map,
            state: renderState.gameState.warDeploymentState
        )
        return TerrainStyle.deploymentUnitColor(for: division.faction, role: role)
    }

    private func drawEmptyState() {
        let field = SKShapeNode(
            rectOf: CGSize(width: max(size.width - 48, 120), height: max(size.height - 48, 120)),
            cornerRadius: 8
        )
        field.fillColor = SKColor(red: 0.24, green: 0.30, blue: 0.22, alpha: 1.0)
        field.strokeColor = SKColor(red: 0.55, green: 0.60, blue: 0.48, alpha: 1.0)
        field.lineWidth = 2
        field.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(field)

        let title = SKLabelNode(text: "Ardennes V0 Board")
        title.fontName = "AvenirNext-DemiBold"
        title.fontSize = 24
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        addChild(title)
    }

    private func tileSort(_ lhs: HexTile, _ rhs: HexTile) -> Bool {
        if lhs.coord.r == rhs.coord.r {
            return lhs.coord.q < rhs.coord.q
        }
        return lhs.coord.r < rhs.coord.r
    }
}
