import SpriteKit

final class UnitNode: SKNode {
    let divisionId: String

    init(
        division: Division,
        layout: HexLayout,
        placement: UnitDisplayPlacement,
        isSelected: Bool,
        isPlayerManaged: Bool = false,
        fillColorOverride: SKColor? = nil
    ) {
        self.divisionId = division.id
        super.init()

        let anchor = layout.hexToPixel(placement.hex)
        position = CGPoint(x: anchor.x + placement.offset.x, y: anchor.y + placement.offset.y)
        zPosition = 40
        alpha = division.hasActed ? 0.58 : 1

        let width = layout.hexSize * 1.08
        let height = layout.hexSize * 0.72

        if isPlayerManaged {
            let halo = SKShapeNode(rectOf: CGSize(width: width + 8, height: height + 8), cornerRadius: min(7, layout.hexSize * 0.14))
            halo.fillColor = SKColor(red: 0.95, green: 0.72, blue: 0.22, alpha: 0.22)
            halo.strokeColor = SKColor(red: 1.00, green: 0.78, blue: 0.24, alpha: 0.95)
            halo.lineWidth = max(2, layout.hexSize * 0.06)
            halo.zPosition = -1
            addChild(halo)
        }

        let body = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: min(5, layout.hexSize * 0.10))
        body.fillColor = fillColorOverride ?? TerrainStyle.unitFillColor(for: division.faction)
        body.strokeColor = isSelected ? TerrainStyle.selectedStroke : TerrainStyle.unitStrokeColor(for: division.faction)
        body.lineWidth = isSelected ? max(3, layout.hexSize * 0.08) : 1.5
        body.zPosition = 0
        addChild(body)

        addUnitKindGlyph(for: division, height: height)

        addLabel(
            text: division.markerReadinessText,
            y: -height * 0.28,
            fontSize: max(7, layout.hexSize * 0.16),
            weight: "AvenirNext-Regular"
        )

        addSupplyMarker(for: division, layout: layout, bodyWidth: width, bodyHeight: height)
        addStackMarker(placement: placement, layout: layout, bodyWidth: width, bodyHeight: height)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addUnitKindGlyph(for division: Division, height: CGFloat) {
        addLabel(
            text: division.markerCode,
            y: height * 0.08,
            fontSize: max(15, height * 0.48),
            weight: "AvenirNext-DemiBold"
        )
    }

    private func addLabel(text: String, y: CGFloat, fontSize: CGFloat, weight: String) {
        let label = SKLabelNode(text: text)
        label.fontName = weight
        label.fontSize = fontSize
        label.fontColor = SKColor(white: 0.97, alpha: 1)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: y)
        label.zPosition = 2
        addChild(label)
    }

    private func addSupplyMarker(for division: Division, layout: HexLayout, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let radius = max(3, layout.hexSize * 0.10)
        let marker = SKShapeNode(circleOfRadius: radius)
        marker.fillColor = TerrainStyle.supplyColor(for: division.supplyState)
        marker.strokeColor = SKColor(white: 1, alpha: 0.85)
        marker.lineWidth = 1
        marker.position = CGPoint(x: bodyWidth / 2 - radius * 0.8, y: bodyHeight / 2 - radius * 0.8)
        marker.zPosition = 3
        addChild(marker)

        guard division.supplyState != .supplied else {
            return
        }

        let alert = SKLabelNode(text: "!")
        alert.fontName = "AvenirNext-Bold"
        alert.fontSize = max(7, layout.hexSize * 0.16)
        alert.fontColor = SKColor(white: 1, alpha: 1)
        alert.horizontalAlignmentMode = .center
        alert.verticalAlignmentMode = .center
        alert.position = marker.position
        alert.zPosition = 4
        addChild(alert)
    }

    private func addStackMarker(placement: UnitDisplayPlacement, layout: HexLayout, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        guard placement.stackCount > 1 else {
            return
        }

        let marker = SKShapeNode(circleOfRadius: max(4, layout.hexSize * 0.12))
        marker.fillColor = SKColor(white: 0.05, alpha: 0.94)
        marker.strokeColor = SKColor(white: 1, alpha: 0.75)
        marker.lineWidth = 1
        marker.position = CGPoint(x: -bodyWidth / 2 + layout.hexSize * 0.13, y: bodyHeight / 2 - layout.hexSize * 0.13)
        marker.zPosition = 4
        addChild(marker)

        let count = SKLabelNode(text: "\(placement.stackCount)")
        count.fontName = "AvenirNext-DemiBold"
        count.fontSize = max(7, layout.hexSize * 0.17)
        count.fontColor = SKColor(white: 1, alpha: 1)
        count.horizontalAlignmentMode = .center
        count.verticalAlignmentMode = .center
        count.position = marker.position
        count.zPosition = 5
        addChild(count)
    }
}

private extension Division {
    var markerCode: String {
        if isArtillery {
            return "械"
        }
        if isArmor {
            return "骑"
        }
        if components.contains(where: { $0.type == .archer && $0.weight >= 0.40 }) {
            return "弓"
        }
        if components.contains(where: { $0.type == .guardUnit && $0.weight >= 0.40 }) {
            return "卫"
        }
        if components.contains(where: { $0.type == .naval && $0.weight >= 0.40 }) {
            return "舟"
        }
        if components.contains(where: { $0.type == .motorizedInfantry && $0.weight >= 0.40 }) {
            return "轻"
        }
        return "步"
    }

    var markerReadinessText: String {
        "\(strength)/\(maxStrength) \(retreatMode.shortDisplayCode)"
    }
}
