import SwiftUI

struct AgentPanelView: View {
    let record: AgentDecisionRecord?
    let rulerRecord: RulerDecisionRecord?
    let diplomatRecord: DiplomatDecisionRecord?
    let governorRecord: GovernorDecisionRecord?
    let strategistRecord: StrategistDecisionRecord?
    let generalRecords: [GeneralDecisionRecord]
    let directiveRecords: [WarDirectiveRecord]

    init(
        record: AgentDecisionRecord?,
        rulerRecord: RulerDecisionRecord? = nil,
        diplomatRecord: DiplomatDecisionRecord? = nil,
        governorRecord: GovernorDecisionRecord? = nil,
        strategistRecord: StrategistDecisionRecord? = nil,
        generalRecords: [GeneralDecisionRecord] = [],
        directiveRecords: [WarDirectiveRecord] = []
    ) {
        self.record = record
        self.rulerRecord = rulerRecord
        self.diplomatRecord = diplomatRecord
        self.governorRecord = governorRecord
        self.strategistRecord = strategistRecord
        self.generalRecords = generalRecords
        self.directiveRecords = directiveRecords
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 决策")
                .font(.headline)

            LabeledContent("Agent") {
                Text(record?.agentId ?? "sanguo_mock_general")
            }

            LabeledContent("来源") {
                Text(record?.provider ?? "MockStrategy")
            }

            LabeledContent("意图") {
                Text(record?.parsedIntent ?? "暂无决策")
                    .multilineTextAlignment(.trailing)
            }

            if let contextSummary = record?.contextSummary {
                LabeledContent("摘要") {
                    Text(contextSummary)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let rulerRecord {
                Divider()
                LabeledContent("君主") {
                    Text(rulerRecord.rulerAgentId)
                }
                LabeledContent("姿态") {
                    Text(rulerRecord.posture.displayName)
                }
                if let zoneId = rulerRecord.preferredFrontZoneId {
                    LabeledContent("重点") {
                        Text(zoneId.rawValue)
                    }
                }
            }

            if let diplomatRecord {
                Divider()
                LabeledContent("外交官") {
                    Text(diplomatRecord.diplomatAgentId)
                }
                LabeledContent("提案") {
                    Text(diplomatRecord.proposal.displayName)
                }
                if let target = diplomatRecord.targetCountryId {
                    LabeledContent("对象") {
                        Text(target.rawValue)
                    }
                }
                if !diplomatRecord.objectiveRegionIds.isEmpty {
                    LabeledContent("目标郡县") {
                        Text(diplomatRecord.objectiveRegionIds.map(\.rawValue).joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Text(diplomatRecord.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let governorRecord {
                Divider()
                LabeledContent("太守") {
                    Text(governorRecord.governorAgentId)
                }
                LabeledContent("内政") {
                    Text(governorRecord.focus.displayName)
                }
                if let kind = governorRecord.recommendedProductionKind {
                    LabeledContent("建议") {
                        Text(kind.displayName)
                    }
                }
                if !governorRecord.focusRegionIds.isEmpty {
                    LabeledContent("郡县") {
                        Text(governorRecord.focusRegionIds.map(\.rawValue).joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Text(governorRecord.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let strategistRecord {
                Divider()
                LabeledContent("军师") {
                    Text(strategistRecord.strategistAgentId)
                }
                if let zoneId = strategistRecord.selectedFrontZoneId {
                    LabeledContent("主防区") {
                        Text(zoneId.rawValue)
                    }
                }
                if !strategistRecord.focusRegionIds.isEmpty {
                    LabeledContent("目标") {
                        Text(strategistRecord.focusRegionIds.map(\.rawValue).joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Text(strategistRecord.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !generalRecords.isEmpty {
                Divider()
                Text("武将")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(generalRecords.prefix(4))) { generalRecord in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(generalRecord.generalName ?? generalRecord.generalId ?? "未分配")
                                    .font(.caption.bold())
                                Text(generalRecord.action)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(generalRecordSummary(generalRecord))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(generalRecord.rationale)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            }

            if let record, !record.commandResults.isEmpty {
                Text("命令结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(record.commandResults) { result in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.commandDisplayName ?? result.orderType?.rawValue ?? "Order")
                                .font(.caption)
                                .bold()
                            Text(resultLine(result))
                                .font(.caption)
                                .foregroundStyle(result.executed ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !directiveRecords.isEmpty {
                Text("防区指令")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(directiveRecords) { directive in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(directive.zoneId?.rawValue ?? "global")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PlatformStyles.selectionTint)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(directiveSummary(directive))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            if !directive.diagnostics.isEmpty {
                                Text(directive.diagnostics.joined(separator: " / "))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(PlatformStyles.tertiarySystemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if let record, !record.errors.isEmpty {
                Text("错误")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(record.errors, id: \.self) { error in
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Text("Raw JSON")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(record?.rawJSON ?? rawJSONPlaceholder)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(PlatformStyles.tertiarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func directiveSummary(_ directive: WarDirectiveRecord) -> String {
        let type = directive.directiveType?.displayName ?? "诊断"
        let tactic = directive.tactic?.displayName ?? directive.category?.displayName ?? "无"
        let executed = directive.commandResults.filter(\.executed).count
        let rejected = directive.commandResults.count - executed
        let targets = directive.targetRegionIds.map(\.rawValue).joined(separator: ", ")
        let targetText = targets.isEmpty ? "无目标" : targets
        return "\(type) / \(tactic) / \(executed) 成功, \(rejected) 拒绝 / \(targetText)"
    }

    private func generalRecordSummary(_ record: GeneralDecisionRecord) -> String {
        let tactic = record.tactic?.displayName ?? "未定战术"
        let style = commandStyleDisplayName(record.commandStyle)
        let targets = record.targetRegionIds.map(\.rawValue).joined(separator: ", ")
        let targetText = targets.isEmpty ? "无目标" : targets
        return "\(record.zoneId.rawValue) / \(record.directiveType.displayName) / \(tactic) / \(style) / \(targetText)"
    }

    private func commandStyleDisplayName(_ style: ZoneCommanderAgentConfig.CommandStyle?) -> String {
        guard let style else {
            return "未定风格"
        }
        switch style {
        case .aggressive:
            return "进取"
        case .balanced:
            return "持重"
        case .cautious:
            return "谨慎"
        }
    }

    private func resultLine(_ result: CommandResultSummary) -> String {
        if !result.mappingSucceeded {
            return "映射失败：\(result.errors.joined(separator: ", "))"
        }

        if result.executed {
            return result.message
        }

        if !result.errors.isEmpty {
            return "被拒绝：\(result.errors.joined(separator: ", "))"
        }

        return result.message
    }

    private var rawJSONPlaceholder: String {
        """
        {
          "agentId": "sanguo_mock_general",
          "status": "placeholder",
          "orders": []
        }
        """
    }
}
