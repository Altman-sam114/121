import SwiftUI

struct AgentPanelView: View {
    let record: AgentDecisionRecord?
    let rulerRecord: RulerDecisionRecord?
    let diplomatRecord: DiplomatDecisionRecord?
    let governorRecord: GovernorDecisionRecord?
    let strategistRecord: StrategistDecisionRecord?
    let generalRecords: [GeneralDecisionRecord]
    let directiveRecords: [WarDirectiveRecord]
    let regionDisplayNames: [RegionId: String]
    let frontZoneDisplayNames: [FrontZoneId: String]
    let countryDisplayNames: [CountryId: String]

    init(
        record: AgentDecisionRecord?,
        rulerRecord: RulerDecisionRecord? = nil,
        diplomatRecord: DiplomatDecisionRecord? = nil,
        governorRecord: GovernorDecisionRecord? = nil,
        strategistRecord: StrategistDecisionRecord? = nil,
        generalRecords: [GeneralDecisionRecord] = [],
        directiveRecords: [WarDirectiveRecord] = [],
        regionDisplayNames: [RegionId: String] = [:],
        frontZoneDisplayNames: [FrontZoneId: String] = [:],
        countryDisplayNames: [CountryId: String] = [:]
    ) {
        self.record = record
        self.rulerRecord = rulerRecord
        self.diplomatRecord = diplomatRecord
        self.governorRecord = governorRecord
        self.strategistRecord = strategistRecord
        self.generalRecords = generalRecords
        self.directiveRecords = directiveRecords
        self.regionDisplayNames = regionDisplayNames
        self.frontZoneDisplayNames = frontZoneDisplayNames
        self.countryDisplayNames = countryDisplayNames
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("军机谋议")
                .font(.headline)

            LabeledContent("执行者") {
                Text(record?.agentDisplayName ?? "兼容武将")
            }

            LabeledContent("来源") {
                Text(record?.providerDisplayName ?? "兼容策略")
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
                    Text(AgentDecisionRecord.displayName(forAgentId: rulerRecord.rulerAgentId))
                }
                LabeledContent("姿态") {
                    Text(rulerRecord.posture.displayName)
                }
                if let zoneId = rulerRecord.preferredFrontZoneId {
                    LabeledContent("重点") {
                        Text(frontZoneDisplayName(for: zoneId))
                    }
                }
            }

            if let diplomatRecord {
                Divider()
                LabeledContent("外交官") {
                    Text(AgentDecisionRecord.displayName(forAgentId: diplomatRecord.diplomatAgentId))
                }
                LabeledContent("提案") {
                    Text(diplomatRecord.proposal.displayName)
                }
                if let target = diplomatRecord.targetCountryId {
                    LabeledContent("对象") {
                        Text(countryDisplayName(for: target))
                    }
                }
                if !diplomatRecord.objectiveRegionIds.isEmpty {
                    LabeledContent("目标郡县") {
                        Text(regionDisplayList(diplomatRecord.objectiveRegionIds))
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
                    Text(AgentDecisionRecord.displayName(forAgentId: governorRecord.governorAgentId))
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
                        Text(regionDisplayList(governorRecord.focusRegionIds))
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
                    Text(AgentDecisionRecord.displayName(forAgentId: strategistRecord.strategistAgentId))
                }
                if let zoneId = strategistRecord.selectedFrontZoneId {
                    LabeledContent("主防区") {
                        Text(frontZoneDisplayName(for: zoneId))
                    }
                }
                if !strategistRecord.focusRegionIds.isEmpty {
                    LabeledContent("目标") {
                        Text(regionDisplayList(strategistRecord.focusRegionIds))
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
                            Text(result.commandDisplayName ?? result.orderType?.rawValue ?? "军令")
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
                                Text(frontZoneDisplayName(for: directive.zoneId))
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

            Text("调试 JSON")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(record?.debugJSONDisplay ?? rawJSONPlaceholder)
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
        let targets = regionDisplayList(directive.targetRegionIds)
        let targetText = targets.isEmpty ? "无目标" : targets
        return "\(type) / \(tactic) / \(executed) 成功, \(rejected) 拒绝 / \(targetText)"
    }

    private func generalRecordSummary(_ record: GeneralDecisionRecord) -> String {
        let tactic = record.tactic?.displayName ?? "未定战术"
        let style = record.commandStyle?.displayName ?? "未定风格"
        let targets = regionDisplayList(record.targetRegionIds)
        let targetText = targets.isEmpty ? "无目标" : targets
        return "\(frontZoneDisplayName(for: record.zoneId)) / \(record.directiveType.displayName) / \(tactic) / \(style) / \(targetText)"
    }

    private func regionDisplayList(_ regionIds: [RegionId]) -> String {
        regionIds.map(regionDisplayName).joined(separator: ", ")
    }

    private func regionDisplayName(for regionId: RegionId) -> String {
        let displayName = regionDisplayNames[regionId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? regionId.rawValue : displayName
    }

    private func frontZoneDisplayName(for zoneId: FrontZoneId?) -> String {
        guard let zoneId else {
            return "全局"
        }
        return frontZoneDisplayName(for: zoneId)
    }

    private func frontZoneDisplayName(for zoneId: FrontZoneId) -> String {
        let displayName = frontZoneDisplayNames[zoneId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? zoneId.rawValue : displayName
    }

    private func countryDisplayName(for countryId: CountryId) -> String {
        let displayName = countryDisplayNames[countryId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? countryId.rawValue : displayName
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
          "agentDisplayName": "军机武将",
          "status": "暂无记录",
          "orders": []
        }
        """
    }
}
