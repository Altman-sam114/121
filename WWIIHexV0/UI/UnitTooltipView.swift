import SwiftUI

struct UnitTooltipView: View {
    let division: Division?

    var body: some View {
        if let division {
            VStack(alignment: .leading, spacing: 6) {
                Text(division.thematicDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        label("兵种")
                        value(division.tooltipTypeCode)
                    }
                    GridRow {
                        label("兵力")
                        value("\(division.strength)/\(division.maxStrength)")
                    }
                    GridRow {
                        label("粮草")
                        value(division.supplyState.shortDisplayName)
                    }
                    GridRow {
                        label("军令")
                        value(division.retreatMode.displayName)
                    }
                    GridRow {
                        label("行动")
                        value(division.hasActed ? "已" : "未")
                    }
                }
            }
            .padding(10)
            .frame(width: 220, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.35), lineWidth: 1)
            }
            .padding(10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(division.thematicDisplayName), \(division.tooltipTypeCode), 兵力 \(division.strength) / \(division.maxStrength)")
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private extension Division {
    var tooltipTypeCode: String {
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
}
