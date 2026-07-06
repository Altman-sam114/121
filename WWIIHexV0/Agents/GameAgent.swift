import Foundation

// Legacy Agent D runtime agent. Lightweight: no cabinet, no directive board, no authority ranks.
// Compatibility ids still use v0 names; display names are localized for the 三国 migration.

enum AgentRole: String, Codable, Equatable, CaseIterable {
    case ruler
    case fieldMarshal
    case armyCommander

    var displayName: String {
        switch self {
        case .ruler:
            return "君主"
        case .fieldMarshal:
            return "军师"
        case .armyCommander:
            return "武将"
        }
    }
}

struct AgentPersonality: Codable, Equatable {
    var prompt: String
    var traits: [String]
    var aggression: Int
    var riskTolerance: Int
    var autonomy: Int
}

struct AgentRelationship: Codable, Equatable {
    var loyalty: Int
    var trust: Int
    var satisfaction: Int
}

struct GameAgent: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var faction: Faction
    var role: AgentRole
    var personality: AgentPersonality
    var relationship: AgentRelationship
    var assignedDivisionIds: [String]

    var canIssueUnitCommands: Bool {
        role == .armyCommander
    }
}

extension GameAgent {
    static func sample(
        id: String,
        name: String,
        faction: Faction,
        role: AgentRole,
        assignedDivisionIds: [String] = []
    ) -> GameAgent {
        GameAgent(
            id: id,
            name: name,
            faction: faction,
            role: role,
            personality: AgentPersonality(
                prompt: "Follow role responsibilities and keep recommendations structured.",
                traits: ["disciplined"],
                aggression: 50,
                riskTolerance: 50,
                autonomy: 50
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: assignedDivisionIds
        )
    }
}
