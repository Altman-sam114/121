import Foundation

struct GeneralDirectiveAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let records: [GeneralDecisionRecord]
}

struct GeneralAgent {
    let registry: GeneralRegistry

    init(registry: GeneralRegistry = .empty) {
        self.registry = registry
    }

    func plan(envelope: DirectiveEnvelope, in state: GameState) -> GeneralDirectiveAdjustment {
        var records: [GeneralDecisionRecord] = []
        let directives = envelope.directives.enumerated().map { index, directive in
            let result = plan(directive: directive, index: index, state: state)
            records.append(result.record)
            return result.directive
        }
        let adjustedEnvelope = DirectiveEnvelope(
            schemaVersion: envelope.schemaVersion,
            issuerId: envelope.issuerId,
            turn: envelope.turn,
            directives: directives,
            commanderAgentId: envelope.commanderAgentId,
            theaterContext: appendGeneralContext(envelope.theaterContext, records: records)
        )
        return GeneralDirectiveAdjustment(envelope: adjustedEnvelope, records: records)
    }

    private func plan(
        directive: ZoneDirective,
        index: Int,
        state: GameState
    ) -> (directive: ZoneDirective, record: GeneralDecisionRecord) {
        guard let zone = state.warDeploymentState.frontZones[directive.zoneId] else {
            return (
                directive,
                record(
                    directive: directive,
                    index: index,
                    state: state,
                    zone: nil,
                    general: nil,
                    action: "保持军令",
                    rationale: "未找到对应防区，武将层不改写指令。"
                )
            )
        }

        guard let assignment = zone.generalAssignment else {
            return (
                directive,
                record(
                    directive: directive,
                    index: index,
                    state: state,
                    zone: zone,
                    general: nil,
                    action: "未分配武将",
                    rationale: "该防区暂无武将分配，保持军师编排后的军令。"
                )
            )
        }

        let general = registry.general(id: assignment.generalId)
        let shaped = shape(directive: directive, zone: zone, assignment: assignment, general: general)
        return (
            shaped.directive,
            record(
                directive: shaped.directive,
                index: index,
                state: state,
                zone: zone,
                general: general,
                action: shaped.action,
                rationale: shaped.rationale
            )
        )
    }

    private func shape(
        directive: ZoneDirective,
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?
    ) -> (directive: ZoneDirective, action: String, rationale: String) {
        switch directive.parameters {
        case .attack(let attack):
            return shapeAttack(
                directive: directive,
                attack: attack,
                zone: zone,
                assignment: assignment,
                general: general
            )
        case .defend(let defense):
            return shapeDefense(
                directive: directive,
                defense: defense,
                zone: zone,
                assignment: assignment,
                general: general
            )
        }
    }

    private func shapeAttack(
        directive: ZoneDirective,
        attack: AttackParameters,
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?
    ) -> (directive: ZoneDirective, action: String, rationale: String) {
        let style = general?.commandStyle ?? inferredStyle(from: assignment)
        var intensity = attack.intensity
        var maxCommittedUnits = attack.maxCommittedUnits
        var action = "保持攻势"

        if assignment.satisfaction < 35 || assignment.loyalty < 35 {
            intensity = intensity == .allOut ? .limitedCounter : intensity
            maxCommittedUnits = minOptional(maxCommittedUnits, max(1, zone.unitsFront.count))
            action = "收束攻势"
        } else if style == .aggressive && intensity == .infiltration && !zone.unitsDepth.isEmpty {
            intensity = .limitedCounter
            action = "催促进攻"
        } else if style == .cautious && intensity == .allOut {
            intensity = .limitedCounter
            action = "谨慎推进"
        }

        let adjusted = ZoneDirective(
            zoneId: directive.zoneId,
            attack: AttackParameters(
                targetTheaterId: attack.targetTheaterId,
                weightedRegions: attack.weightedRegions,
                intensity: intensity,
                focusRegionId: attack.focusRegionId,
                supportRegionIds: attack.supportRegionIds,
                convergenceRegionId: attack.convergenceRegionId,
                coordinatedZoneIds: attack.coordinatedZoneIds,
                maxCommittedUnits: maxCommittedUnits,
                exploitDepth: attack.exploitDepth
            ),
            category: directive.category,
            tactic: directive.tactic,
            commandTarget: directive.commandTarget
        )
        let rationale = "\(generalName(general, fallback: assignment.generalId)) 依据忠诚 \(assignment.loyalty)、满意 \(assignment.satisfaction) 与 \(style.displayName)风格处理攻势。"
        return (adjusted, action, rationale)
    }

    private func shapeDefense(
        directive: ZoneDirective,
        defense: DefenseParameters,
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?
    ) -> (directive: ZoneDirective, action: String, rationale: String) {
        let style = general?.commandStyle ?? inferredStyle(from: assignment)
        let reserveTarget: Int
        let action: String
        if assignment.satisfaction < 35 || assignment.loyalty < 35 {
            reserveTarget = min(zone.unitsDepth.count, defense.targetReserves + 1)
            action = "增调预备"
        } else if style == .aggressive && zone.pressure == 0 {
            reserveTarget = max(0, defense.targetReserves - 1)
            action = "前推守军"
        } else {
            reserveTarget = defense.targetReserves
            action = "保持防务"
        }

        let adjusted = ZoneDirective(
            zoneId: directive.zoneId,
            defense: DefenseParameters(
                targetReserves: reserveTarget,
                stance: defense.stance,
                fallbackRegionIds: defense.fallbackRegionIds,
                counterattackRegionIds: defense.counterattackRegionIds,
                strongpointRegionIds: defense.strongpointRegionIds,
                maxFrontCommitment: defense.maxFrontCommitment
            ),
            category: directive.category,
            tactic: directive.tactic,
            commandTarget: directive.commandTarget
        )
        let rationale = "\(generalName(general, fallback: assignment.generalId)) 依据忠诚 \(assignment.loyalty)、满意 \(assignment.satisfaction)、防区压力 \(zone.pressure) 调整防务。"
        return (adjusted, action, rationale)
    }

    private func record(
        directive: ZoneDirective,
        index: Int,
        state: GameState,
        zone: FrontZone?,
        general: GeneralData?,
        action: String,
        rationale: String
    ) -> GeneralDecisionRecord {
        let assignment = zone?.generalAssignment
        let generalId = general?.id ?? assignment?.generalId
        return GeneralDecisionRecord(
            id: "general_\(generalId ?? "unassigned")_turn_\(state.turn)_\(directive.zoneId.rawValue)_\(index)",
            turn: state.turn,
            faction: zone?.faction ?? state.activeFaction,
            zoneId: directive.zoneId,
            generalId: generalId,
            generalName: general.map { generalName($0, fallback: $0.id) },
            commandStyle: general?.commandStyle ?? assignment.map { inferredStyle(from: $0) },
            directiveType: directive.type,
            tactic: directive.tactic,
            targetRegionIds: directive.targetRegionIds,
            action: action,
            rationale: rationale
        )
    }

    private func appendGeneralContext(_ context: String?, records: [GeneralDecisionRecord]) -> String? {
        guard !records.isEmpty else {
            return context
        }
        let summary = records
            .prefix(3)
            .map { "\($0.generalName ?? $0.generalId ?? "未分配"):\($0.action)" }
            .joined(separator: "；")
        let generalContext = "武将层：\(summary)"
        guard let context, !context.isEmpty else {
            return generalContext
        }
        return "\(context) \(generalContext)"
    }

    private func inferredStyle(from assignment: GeneralAssignment) -> ZoneCommanderAgentConfig.CommandStyle {
        if assignment.loyalty < 45 || assignment.satisfaction < 45 {
            return .cautious
        }
        if assignment.loyalty >= 75 && assignment.satisfaction >= 65 {
            return .aggressive
        }
        return .balanced
    }

    private func minOptional(_ current: Int?, _ cap: Int) -> Int? {
        guard let current else {
            return cap
        }
        return min(current, cap)
    }

    private func generalName(_ general: GeneralData?, fallback: String) -> String {
        guard let general else {
            return fallback
        }
        return general.localizedName.isEmpty ? general.name : general.localizedName
    }
}

private extension ZoneCommanderAgentConfig.CommandStyle {
    var displayName: String {
        switch self {
        case .aggressive:
            return "进取"
        case .balanced:
            return "持重"
        case .cautious:
            return "谨慎"
        }
    }
}
