import Foundation

struct WarDirectiveRecord: Identifiable, Codable, Equatable {
    let id: String
    let issuerId: String
    let turn: Int
    let faction: Faction
    let zoneId: FrontZoneId?
    let directiveType: DirectiveType?
    let targetRegionIds: [RegionId]
    let commandResults: [CommandResultSummary]
    let diagnostics: [String]
    let category: CommandCategory?
    let tactic: TacticName?
    let commanderAgentId: String?
    let commandTarget: DirectiveTarget?

    init(
        id: String,
        issuerId: String,
        turn: Int,
        faction: Faction,
        zoneId: FrontZoneId?,
        directiveType: DirectiveType?,
        targetRegionIds: [RegionId] = [],
        commandResults: [CommandResultSummary] = [],
        diagnostics: [String] = [],
        category: CommandCategory? = nil,
        tactic: TacticName? = nil,
        commanderAgentId: String? = nil,
        commandTarget: DirectiveTarget? = nil
    ) {
        self.id = id
        self.issuerId = issuerId
        self.turn = turn
        self.faction = faction
        self.zoneId = zoneId
        self.directiveType = directiveType
        self.targetRegionIds = targetRegionIds
        self.commandResults = commandResults
        self.diagnostics = diagnostics
        self.category = category
        self.tactic = tactic
        self.commanderAgentId = commanderAgentId
        self.commandTarget = commandTarget
    }
}

struct StrategistDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let strategistAgentId: String
    let selectedFrontZoneId: FrontZoneId?
    let focusRegionIds: [RegionId]
    let supportRegionIds: [RegionId]
    let rulerPosture: RulerStrategicPosture?
    let intent: String
    let rationale: String

    init(
        id: String,
        turn: Int,
        faction: Faction,
        strategistAgentId: String,
        selectedFrontZoneId: FrontZoneId?,
        focusRegionIds: [RegionId],
        supportRegionIds: [RegionId],
        rulerPosture: RulerStrategicPosture?,
        intent: String,
        rationale: String
    ) {
        self.id = id
        self.turn = turn
        self.faction = faction
        self.strategistAgentId = strategistAgentId
        self.selectedFrontZoneId = selectedFrontZoneId
        self.focusRegionIds = focusRegionIds
        self.supportRegionIds = supportRegionIds
        self.rulerPosture = rulerPosture
        self.intent = intent
        self.rationale = rationale
    }
}

struct GeneralDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let zoneId: FrontZoneId
    let generalId: String?
    let generalName: String?
    let commandStyle: ZoneCommanderAgentConfig.CommandStyle?
    let directiveType: DirectiveType
    let tactic: TacticName?
    let targetRegionIds: [RegionId]
    let action: String
    let rationale: String

    init(
        id: String,
        turn: Int,
        faction: Faction,
        zoneId: FrontZoneId,
        generalId: String?,
        generalName: String?,
        commandStyle: ZoneCommanderAgentConfig.CommandStyle?,
        directiveType: DirectiveType,
        tactic: TacticName?,
        targetRegionIds: [RegionId],
        action: String,
        rationale: String
    ) {
        self.id = id
        self.turn = turn
        self.faction = faction
        self.zoneId = zoneId
        self.generalId = generalId
        self.generalName = generalName
        self.commandStyle = commandStyle
        self.directiveType = directiveType
        self.tactic = tactic
        self.targetRegionIds = targetRegionIds
        self.action = action
        self.rationale = rationale
    }
}
