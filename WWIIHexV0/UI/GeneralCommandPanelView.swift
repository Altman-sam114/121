import SwiftUI

struct GeneralCommandPanelView: View {
    let zone: FrontZone?
    let general: GeneralData?
    let assignment: GeneralAssignment?
    let assignedDivisions: [Division]
    let targetRegion: RegionNode?
    let targetZone: FrontZone?
    let hqUnderAttack: Bool
    let plannedOperations: [PlayerPlannedOperation]
    let canHoldLine: Bool
    let canAttackRegion: Bool
    let onShowProfile: () -> Void
    let onHoldLine: () -> Void
    let onAttackRegion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("武将军令")
                .font(.headline)

            if let zone {
                LabeledContent("防区") {
                    Text(zone.name)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                Text("未选择己方防区。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let general {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Button(action: onShowProfile) {
                            portraitBadge(for: general)
                        }
                            .accessibilityLabel("查看 \(general.localizedName) 档案")
                            .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(general.localizedName)
                                .font(.subheadline.weight(.semibold))
                            Text("\(general.rank) / \(styleLabel(general.commandStyle))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(general.biography)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if !general.skills.isEmpty {
                        Text(general.skills.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let assignment {
                        metricBar(title: "忠诚", value: assignment.loyalty)
                        metricBar(title: "满意", value: assignment.satisfaction)
                        LabeledContent("干预") {
                            Text("\(assignment.interventionCount)")
                        }
                    }

                    Button("查看档案", systemImage: "person.text.rectangle", action: onShowProfile)
                        .buttonStyle(.bordered)
                }
            } else if zone != nil {
                Text("该防区尚未任命武将。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if hqUnderAttack {
                Label("帅帐所在郡县受威胁", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if !assignedDivisions.isEmpty {
                Text("麾下军队")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(assignedDivisions.prefix(5)), id: \.id) { division in
                        Label(division.thematicDisplayName, systemImage: unitIcon(for: division))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            if let targetRegion, targetZone?.faction != zone?.faction {
                LabeledContent("目标") {
                    Text(targetRegion.name)
                }
            }

            HStack(spacing: 8) {
                Button("固守战线", systemImage: "shield.fill", action: onHoldLine)
                    .disabled(!canHoldLine)
                Button("进攻郡县", systemImage: "arrow.up.right.circle", action: onAttackRegion)
                    .disabled(!canAttackRegion)
            }
            .buttonStyle(.bordered)

            if !plannedOperations.isEmpty {
                Text("计划军令")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plannedOperations) { operation in
                        Label(operationSummary(operation), systemImage: operationIcon(operation))
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func portraitBadge(for general: GeneralData) -> some View {
        Text(initials(for: general))
            .font(.caption.weight(.bold))
            .frame(width: 40, height: 40)
            .background(PlatformStyles.selectionTint)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("\(general.localizedName) portrait placeholder")
    }

    private func metricBar(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
            }
            .font(.caption)
            ProgressView(value: Double(value), total: 100)
                .tint(value >= 65 ? .green : value >= 40 ? .orange : .red)
        }
    }

    private func initials(for general: GeneralData) -> String {
        let words = general.localizedName.split(separator: " ")
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(general.name.prefix(2)).uppercased() : String(letters).uppercased()
    }

    private func styleLabel(_ style: ZoneCommanderAgentConfig.CommandStyle) -> String {
        switch style {
        case .aggressive:
            return "进取"
        case .balanced:
            return "持重"
        case .cautious:
            return "谨慎"
        }
    }

    private func unitIcon(for division: Division) -> String {
        if division.isArmor {
            return "shield.lefthalf.filled"
        }
        if division.isArtillery {
            return "scope"
        }
        return "person.3.fill"
    }

    private func operationIcon(_ operation: PlayerPlannedOperation) -> String {
        operation.directiveType == .attack ? "arrow.up.right.circle" : "shield.fill"
    }

    private func operationSummary(_ operation: PlayerPlannedOperation) -> String {
        let target = operation.targetRegionId?.rawValue ?? operation.sourceRegionId?.rawValue ?? operation.zoneId.rawValue
        return "\(operation.directiveType.displayName) / \(target)"
    }
}
