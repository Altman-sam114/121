import SwiftUI

struct AgentPanelView: View {
    let record: AgentDecisionRecord?
    let rulerRecord: RulerDecisionRecord?
    let directiveRecords: [WarDirectiveRecord]

    init(
        record: AgentDecisionRecord?,
        rulerRecord: RulerDecisionRecord? = nil,
        directiveRecords: [WarDirectiveRecord] = []
    ) {
        self.record = record
        self.rulerRecord = rulerRecord
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
