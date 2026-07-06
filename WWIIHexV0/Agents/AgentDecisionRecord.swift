import Foundation

struct CommandResultSummary: Identifiable, Codable, Equatable {
    let id: String
    let orderIndex: Int?
    let divisionId: String?
    let orderType: AgentOrderType?
    let commandDisplayName: String?
    let mappingSucceeded: Bool
    let validationSucceeded: Bool?
    let executed: Bool
    let message: String
    let errors: [String]

    static func mapped(
        orderIndex: Int,
        order: AgentOrder,
        command: Command,
        result: CommandResult
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "order_\(orderIndex)_\(order.divisionId)_\(order.type.rawValue)",
            orderIndex: orderIndex,
            divisionId: order.divisionId,
            orderType: order.type,
            commandDisplayName: command.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.displayErrors
        )
    }

    static func mappingFailed(
        orderIndex: Int,
        order: AgentOrder,
        error: Error
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "order_\(orderIndex)_\(order.divisionId)_mapping_failed",
            orderIndex: orderIndex,
            divisionId: order.divisionId,
            orderType: order.type,
            commandDisplayName: nil,
            mappingSucceeded: false,
            validationSucceeded: nil,
            executed: false,
            message: "命令映射失败。",
            errors: [error.localizedDescription]
        )
    }

    static func endTurn(result: CommandResult) -> CommandResultSummary {
        CommandResultSummary(
            id: "end_turn",
            orderIndex: nil,
            divisionId: nil,
            orderType: nil,
            commandDisplayName: Command.endTurn.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.displayErrors
        )
    }

    static func directiveCommand(
        directiveIndex: Int,
        commandIndex: Int,
        directive: ZoneDirective,
        command: Command,
        result: CommandResult
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "directive_\(directiveIndex)_command_\(commandIndex)_\(directive.type.rawValue)",
            orderIndex: commandIndex,
            divisionId: command.actingDivisionId,
            orderType: nil,
            commandDisplayName: command.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.displayErrors
        )
    }

    static func diplomatCommand(
        record: DiplomatDecisionRecord,
        result: CommandResult
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "diplomat_\(record.id)_command",
            orderIndex: nil,
            divisionId: nil,
            orderType: nil,
            commandDisplayName: result.command.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.displayErrors
        )
    }

    static func governorCommand(
        record: GovernorDecisionRecord,
        result: CommandResult,
        commandIndex: Int = 0
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "governor_\(record.id)_command_\(commandIndex)",
            orderIndex: nil,
            divisionId: nil,
            orderType: nil,
            commandDisplayName: result.command.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.displayErrors
        )
    }
}

extension CommandResultSummary {
    var commandDisplayNameForDisplay: String {
        guard let commandDisplayName,
              !commandDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return orderType?.displayName ?? "军令"
        }

        if commandDisplayName.hasPrefix("进军(") || commandDisplayName.lowercased().hasPrefix("move") {
            return "进军命令"
        }
        if commandDisplayName.hasPrefix("攻击(") || commandDisplayName.lowercased().hasPrefix("attack") {
            return "交战命令"
        }
        if commandDisplayName.hasPrefix("固守(") || commandDisplayName.lowercased().hasPrefix("hold") {
            return "固守命令"
        }
        if commandDisplayName.hasPrefix("准许撤退(") || commandDisplayName.lowercased().hasPrefix("allow") {
            return "机动撤退命令"
        }
        if commandDisplayName.hasPrefix("补给(") || commandDisplayName.lowercased().hasPrefix("resupply") {
            return "补给休整命令"
        }
        if commandDisplayName.hasPrefix("募兵(") {
            return "征发生产命令"
        }
        if commandDisplayName.hasPrefix("修路(") {
            return "修缮道路命令"
        }
        if commandDisplayName.hasPrefix("外交(") {
            return "外交命令"
        }
        if commandDisplayName == Command.endTurn.displayName {
            return "结束回合命令"
        }

        return orderType?.displayName ?? "军令"
    }
}

struct AgentDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let agentId: String
    let provider: String
    let contextSummary: String
    let rawJSON: String?
    let parsedIntent: String?
    let commandResults: [CommandResultSummary]
    let errors: [String]
}

extension AgentDecisionRecord {
    var agentDisplayName: String {
        Self.displayName(forAgentId: agentId)
    }

    var providerDisplayName: String {
        Self.displayName(forProvider: provider)
    }

    var debugJSONDisplay: String? {
        rawJSON.map(Self.localizedDebugJSONForDisplay)
    }

    static func displayName(forAgentId agentId: String) -> String {
        switch agentId {
        case "guderian":
            return "张辽"
        case "system":
            return "系统"
        case "sanguo_mock_general":
            return "兼容武将"
        default:
            if agentId.hasPrefix("ruler_") {
                return "君主"
            }
            if agentId.hasPrefix("diplomat_") {
                return "外交官"
            }
            if agentId.hasPrefix("governor_") {
                return "太守"
            }
            if agentId.hasPrefix("marshal_") {
                return "军师"
            }
            return agentId
        }
    }

    static func displayName(forProvider provider: String) -> String {
        provider
            .split(separator: "+")
            .map { providerComponentDisplayName(String($0)) }
            .joined(separator: " + ")
    }

    private static func providerComponentDisplayName(_ provider: String) -> String {
        switch provider {
        case "MockAI":
            return "兼容武将 AI"
        case "System":
            return "系统"
        case "RulerDiplomatGovernorStrategistGeneralDirective":
            return "君主/外交/太守/军师/武将指令"
        case "RulerDiplomatGovernorStrategistGeneralMarshalDirective":
            return "君主/外交/太守/军师/武将/军师指令"
        default:
            return provider
        }
    }

    private static func localizedDebugJSONForDisplay(_ rawJSON: String) -> String {
        rawJSON
            .replacingOccurrences(of: "\"agentId\" : \"guderian\"", with: "\"agentDisplayName\" : \"张辽\"")
            .replacingOccurrences(of: "\"agentId\": \"guderian\"", with: "\"agentDisplayName\": \"张辽\"")
            .replacingOccurrences(of: "\"provider\" : \"MockAI\"", with: "\"providerDisplayName\" : \"兼容武将 AI\"")
            .replacingOccurrences(of: "\"provider\": \"MockAI\"", with: "\"providerDisplayName\": \"兼容武将 AI\"")
    }
}
