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
                Text(displaySafePanelText(record?.parsedIntent, fallback: record == nil ? "暂无决策" : "军令意图已记录"))
                    .multilineTextAlignment(.trailing)
            }

            if let contextSummary = record?.contextSummary {
                LabeledContent("摘要") {
                    Text(displaySafePanelText(contextSummary, fallback: "军情摘要已记录"))
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
                Text(displaySafePanelText(diplomatRecord.rationale, fallback: "外交理由已写入审计记录"))
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
                Text(displaySafePanelText(governorRecord.rationale, fallback: "内政理由已写入审计记录"))
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
                Text(displaySafePanelText(strategistRecord.rationale, fallback: "军师理由已写入审计记录"))
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
                                Text(generalRecordDisplayName(generalRecord))
                                    .font(.caption.bold())
                                Text(generalRecord.action)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(generalRecordSummary(generalRecord))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(displaySafePanelText(generalRecord.rationale, fallback: "武将复核理由已写入审计记录"))
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
                            Text(result.commandDisplayNameForDisplay)
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

                            let tacticalDiagnostics = tacticalDirectiveDiagnostics(directive.diagnostics)
                            if !tacticalDiagnostics.isEmpty {
                                Text("战术审计")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(Array(tacticalDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                                        Label(diagnostic.text, systemImage: diagnostic.iconName)
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

                            let generalDiagnostics = generalDirectiveDiagnostics(directive.diagnostics)
                            if !generalDiagnostics.isEmpty {
                                Text(generalDiagnostics.joined(separator: "；"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            let commandBreakdown = directiveCommandBreakdown(directive.commandResults)
                            if !commandBreakdown.isEmpty {
                                Text(commandBreakdown)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                        Text(displaySafeError(error))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Text("审计摘要")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(auditSummary(for: record))
                .font(.caption)
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

    private func directiveCommandBreakdown(_ results: [CommandResultSummary]) -> String {
        guard !results.isEmpty else {
            return ""
        }

        let grouped = Dictionary(grouping: results, by: \.commandDisplayNameForDisplay)
        return grouped.keys.sorted().compactMap { commandName in
            guard let commandResults = grouped[commandName] else {
                return nil
            }
            let executed = commandResults.filter(\.executed).count
            let rejected = commandResults.count - executed
            return "\(commandName) \(executed) 成功 / \(rejected) 拒绝"
        }
        .joined(separator: "；")
    }

    private func generalRecordSummary(_ record: GeneralDecisionRecord) -> String {
        let tactic = record.tactic?.displayName ?? "未定战术"
        let style = record.commandStyle?.displayName ?? "未定风格"
        let targets = regionDisplayList(record.targetRegionIds)
        let targetText = targets.isEmpty ? "无目标" : targets
        return "\(frontZoneDisplayName(for: record.zoneId)) / \(record.directiveType.displayName) / \(tactic) / \(style) / \(targetText)"
    }

    private func generalRecordDisplayName(_ record: GeneralDecisionRecord) -> String {
        let name = record.generalName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty {
            return name
        }
        let id = record.generalId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return id.isEmpty ? "未分配" : "未命名武将"
    }

    private func regionDisplayList(_ regionIds: [RegionId]) -> String {
        regionIds.map(regionDisplayName).joined(separator: ", ")
    }

    private func regionDisplayName(for regionId: RegionId) -> String {
        let displayName = regionDisplayNames[regionId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? "未知郡县" : displayName
    }

    private func frontZoneDisplayName(for zoneId: FrontZoneId?) -> String {
        guard let zoneId else {
            return "全局"
        }
        return frontZoneDisplayName(for: zoneId)
    }

    private func frontZoneDisplayName(for zoneId: FrontZoneId) -> String {
        let displayName = frontZoneDisplayNames[zoneId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? "未知防区" : displayName
    }

    private func countryDisplayName(for countryId: CountryId) -> String {
        let displayName = countryDisplayNames[countryId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? "未知外交对象" : displayName
    }

    private func resultLine(_ result: CommandResultSummary) -> String {
        let errors = result.errors.map(displaySafeError)

        if !result.mappingSucceeded {
            return "映射失败：\(errors.joined(separator: "；"))"
        }

        if result.executed {
            return displaySafePanelText(result.message, fallback: "命令已执行，详情已写入审计记录")
        }

        if !errors.isEmpty {
            return "被拒绝：\(errors.joined(separator: "；"))"
        }

        return displaySafePanelText(result.message, fallback: "命令未能执行，详情已写入审计记录")
    }

    private func tacticalDirectiveDiagnostics(_ diagnostics: [String]) -> [(text: String, iconName: String)] {
        diagnostics.compactMap { diagnostic in
            guard let type = tacticalDirectiveDiagnosticType(for: diagnostic) else {
                return nil
            }
            return (
                displaySafePanelText(diagnostic, fallback: type.fallback),
                type.iconName
            )
        }
    }

    private func generalDirectiveDiagnostics(_ diagnostics: [String]) -> [String] {
        diagnostics.compactMap { diagnostic in
            guard tacticalDirectiveDiagnosticType(for: diagnostic) == nil else {
                return nil
            }
            return displaySafePanelText(diagnostic, fallback: "军令诊断已记录")
        }
    }

    private func tacticalDirectiveDiagnosticType(for diagnostic: String) -> TacticalDirectiveDiagnosticType? {
        if diagnostic.contains("道路审计") {
            return .road
        }
        if diagnostic.contains("交战审计") {
            return .combat
        }
        return nil
    }

    private func displaySafeError(_ error: String) -> String {
        displaySafePanelText(error, fallback: "军令解析或执行失败，详情已写入审计记录")
    }

    private func displaySafePanelText(_ value: String?, fallback: String) -> String {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            return fallback
        }
        if isRawDebugText(text) {
            return fallback
        }
        return text
    }

    private func isRawDebugText(_ text: String) -> Bool {
        let rawMarkers = [
            "{", "}", "[", "]", "\"",
            "debugJSONDisplay", "rawValue", "agentId", "frontZoneId", "regionId", "theaterId",
            "targetDivisionId", "toRegionId", "schemaVersion",
            "JSON", "UTF-8", "decoder", "DecodingError",
            "NorthWest", "NorthEast", "SouthWest", "SouthEast",
            "germany", "allies", "German", "Allied",
            "panzer", "division", "Ardennes", "Bastogne", "St. Vith",
            "Guderian", "Heinz"
        ]
        if rawMarkers.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
            return true
        }

        let hasChinese = text.range(of: "\\p{Han}", options: .regularExpression) != nil
        if !hasChinese {
            return true
        }

        let rawIdentifierPattern = #"\b[a-zA-Z]+_[a-zA-Z0-9_]+\b|\b[a-z]+[A-Z][A-Za-z0-9]*\b"#
        return text.range(of: rawIdentifierPattern, options: .regularExpression) != nil
    }

    private func auditSummary(for record: AgentDecisionRecord?) -> String {
        guard let record else {
            if directiveRecords.isEmpty {
                return "暂无军机审计记录。"
            }
            return "暂无军机审计记录。防区指令已记录：\(directiveRecords.count) 条。"
        }
        let executed = record.commandResults.filter(\.executed).count
        let rejected = record.commandResults.count - executed
        let errors = record.errors.count
        let directiveText = directiveRecords.isEmpty ? "" : "防区指令 \(directiveRecords.count) 条，"
        return "军机审计已记录：\(directiveText)\(record.commandResults.count) 条命令，\(executed) 条执行，\(rejected) 条拒绝，\(errors) 条错误。原始记录保留在兼容审计字段中。"
    }

    private enum TacticalDirectiveDiagnosticType {
        case road
        case combat

        var fallback: String {
            switch self {
            case .road:
                return "道路审计已记录"
            case .combat:
                return "交战审计已记录"
            }
        }

        var iconName: String {
            switch self {
            case .road:
                return "arrow.up.right.circle"
            case .combat:
                return "scope"
            }
        }
    }
}
