import Foundation

enum CommandValidationError: String, Codable, Equatable {
    case wrongPhase
    case wrongFaction
    case divisionNotFound
    case targetNotFound
    case alreadyActed
    case destinationOutOfBounds
    case destinationOccupied
    case noPath
    case insufficientMovement
    case targetOutOfRange
    case invalidTargetFaction
    case regionNotFound
    case invalidRegionForHex
    case insufficientResources
    case countryNotFound
    case diplomaticRelationNotFound
    case invalidDiplomaticTarget
    case invalidDiplomaticProposal

    var displayName: String {
        switch self {
        case .wrongPhase:
            return "当前阶段不能执行该命令"
        case .wrongFaction:
            return "不是当前行动势力"
        case .divisionNotFound:
            return "未找到军队"
        case .targetNotFound:
            return "未找到目标"
        case .alreadyActed:
            return "军队本回合已行动"
        case .destinationOutOfBounds:
            return "目标格越界"
        case .destinationOccupied:
            return "目标格已有军队"
        case .noPath:
            return "没有可用行军路径"
        case .insufficientMovement:
            return "机动力不足"
        case .targetOutOfRange:
            return "目标超出射程"
        case .invalidTargetFaction:
            return "目标势力不可攻击"
        case .regionNotFound:
            return "未找到郡县"
        case .invalidRegionForHex:
            return "目标格不属于指定郡县"
        case .insufficientResources:
            return "资源不足"
        case .countryNotFound:
            return "未找到外交国家"
        case .diplomaticRelationNotFound:
            return "未找到外交关系"
        case .invalidDiplomaticTarget:
            return "外交对象不合法"
        case .invalidDiplomaticProposal:
            return "外交提案不合法"
        }
    }
}

struct CommandValidation: Codable, Equatable {
    var errors: [CommandValidationError]

    var isValid: Bool {
        errors.isEmpty
    }

    static let valid = CommandValidation(errors: [])

    static func invalid(_ error: CommandValidationError) -> CommandValidation {
        CommandValidation(errors: [error])
    }

    var displayErrors: [String] {
        errors.map(\.displayName)
    }

    var displayMessage: String {
        displayErrors.joined(separator: "，")
    }
}
