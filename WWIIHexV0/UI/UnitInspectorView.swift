import SwiftUI

struct UnitInspectorView: View {
    let division: Division?
    let playerFaction: Faction
    let strategicState: UnitInspectorStrategicState?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("军队详情")
                .font(.headline)

            if let division {
                unitDetails(division)
            } else {
                Text("未选择军队。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func unitDetails(_ division: Division) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(division.thematicDisplayName)
                .font(.subheadline.weight(.semibold))

            LabeledContent("势力") {
                Text(division.faction.displayName)
            }

            LabeledContent("指挥") {
                Text(division.faction == playerFaction ? "玩家" : "只读")
            }

            if let strategicState {
                LabeledContent("地格") {
                    Text("\(strategicState.coord.q),\(strategicState.coord.r)")
                }

                LabeledContent("郡县") {
                    Text(strategicState.regionId?.rawValue ?? "无")
                }

                LabeledContent("动态方面") {
                    Text(strategicState.dynamicTheaterId?.rawValue ?? "无")
                }

                LabeledContent("防区") {
                    Text(strategicState.frontZoneId?.rawValue ?? "无")
                }

                LabeledContent("部署") {
                    Text(strategicState.deploymentRole.displayName)
                }

                LabeledContent("战线") {
                    Text(frontLineSummary(strategicState.frontLineIds))
                        .multilineTextAlignment(.trailing)
                }
            }

            LabeledContent("兵力") {
                Text(division.inspectorStrengthText)
            }

            LabeledContent("军令") {
                Text(division.retreatMode.displayName)
            }

            LabeledContent("粮草") {
                Text(division.supplyState.displayName)
            }

            LabeledContent("已行动") {
                Text(division.hasActed ? "是" : "否")
            }

            LabeledContent("状态") {
                Text(division.inspectorStatusText)
            }

            LabeledContent("兵种") {
                Text(componentSummary(for: division))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func componentSummary(for division: Division) -> String {
        division.components
            .map { "\($0.type.shortDisplayCode) \(Int(($0.weight * 100).rounded()))%" }
            .joined(separator: " / ")
    }

    private func frontLineSummary(_ ids: [FrontLineId]) -> String {
        ids.isEmpty ? "无" : ids.map(\.rawValue).joined(separator: ", ")
    }
}

private extension Division {
    var inspectorStrengthText: String {
        "\(strength) / \(maxStrength)"
    }

    var inspectorStatusText: String {
        var statuses: [String] = []

        if isRetreating {
            statuses.append("撤退中")
        }

        if isDestroyed {
            statuses.append("溃散")
        }

        return statuses.isEmpty ? "待命" : statuses.joined(separator: ", ")
    }
}

private extension Set where Element == HexDirection {
    var displaySummary: String {
        HexDirection.ordered
            .filter { contains($0) }
            .map(\.displayCode)
            .joined(separator: ", ")
    }
}

private extension HexDirection {
    var displayCode: String {
        switch self {
        case .east:
            return "E"
        case .northEast:
            return "NE"
        case .northWest:
            return "NW"
        case .west:
            return "W"
        case .southWest:
            return "SW"
        case .southEast:
            return "SE"
        }
    }
}
