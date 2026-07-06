import SwiftUI

struct GeneralCommandPanelView: View {
    let zone: FrontZone?
    let general: GeneralData?
    let assignment: GeneralAssignment?
    let assignedDivisionRows: [GeneralAssignedDivisionRow]
    let influenceNotes: [String]
    let targetRegion: RegionNode?
    let targetZone: FrontZone?
    let targetPreviewNotes: [String]
    let hqUnderAttack: Bool
    let plannedOperationRows: [(id: String, iconName: String, summary: String)]
    let canHoldLine: Bool
    let canAttackRegion: Bool
    let holdLineUnavailableReason: String?
    let attackRegionUnavailableReason: String?
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
                        Text(general.skillEffectSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    if let assignment {
                        metricBar(title: "忠诚", value: assignment.loyalty)
                        metricBar(title: "满意", value: assignment.satisfaction)
                        LabeledContent("干预") {
                            Text("\(assignment.interventionCount)")
                        }
                    }

                    if !influenceNotes.isEmpty {
                        Text("道路与交战")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(influenceNotes.enumerated()), id: \.offset) { _, note in
                                Label(note, systemImage: influenceIcon(for: note))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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

            if !assignedDivisionRows.isEmpty {
                Text("麾下军队")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(assignedDivisionRows.prefix(5)), id: \.id) { row in
                        Label(row.summary, systemImage: row.iconName)
                            .font(.caption)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if assignedDivisionRows.count > 5 {
                        Text("另有 \(assignedDivisionRows.count - 5) 支麾下军队")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let targetRegion,
               let sourceFaction = zone?.faction,
               targetZone?.faction.isHostile(to: sourceFaction) == true {
                LabeledContent("目标") {
                    Text(targetRegion.name)
                }

                if !targetPreviewNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(targetPreviewNotes.enumerated()), id: \.offset) { _, note in
                            Label(note, systemImage: targetPreviewIcon(for: note))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button("固守战线", systemImage: "shield.fill", action: onHoldLine)
                    .disabled(!canHoldLine)
                Button("进攻郡县", systemImage: "arrow.up.right.circle", action: onAttackRegion)
                    .disabled(!canAttackRegion)
            }
            .buttonStyle(.bordered)

            if let commandHintText {
                Label(commandHintText, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !plannedOperationRows.isEmpty {
                Text("计划军令")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plannedOperationRows.indices, id: \.self) { index in
                        let row = plannedOperationRows[index]
                        Label(row.summary, systemImage: row.iconName)
                            .font(.caption)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
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

    private func influenceIcon(for note: String) -> String {
        note.hasPrefix("道路") ? "arrow.up.right.circle" : "shield.lefthalf.filled"
    }

    private func targetPreviewIcon(for note: String) -> String {
        note.hasPrefix("目标官道") ? "arrow.up.right.circle" : "scope"
    }

    private var commandHintText: String? {
        if let holdLineUnavailableReason, let attackRegionUnavailableReason {
            return "固守：\(holdLineUnavailableReason)\n进攻：\(attackRegionUnavailableReason)"
        }
        if let holdLineUnavailableReason {
            return "固守：\(holdLineUnavailableReason)"
        }
        if let attackRegionUnavailableReason {
            return "进攻：\(attackRegionUnavailableReason)"
        }
        return nil
    }
}

private extension GeneralData {
    var skillEffectSummary: String {
        skills
            .prefix(3)
            .map(GeneralSkillDisplay.displayNameWithHint)
            .joined(separator: " / ")
    }
}
