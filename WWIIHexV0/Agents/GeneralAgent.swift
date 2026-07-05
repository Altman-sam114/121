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
        let shaped = shape(
            directive: directive,
            zone: zone,
            assignment: assignment,
            general: general,
            state: state
        )
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
        general: GeneralData?,
        state: GameState
    ) -> (directive: ZoneDirective, action: String, rationale: String) {
        switch directive.parameters {
        case .attack(let attack):
            return shapeAttack(
                directive: directive,
                attack: attack,
                zone: zone,
                assignment: assignment,
                general: general,
                state: state
            )
        case .defend(let defense):
            return shapeDefense(
                directive: directive,
                defense: defense,
                zone: zone,
                assignment: assignment,
                general: general,
                state: state
            )
        }
    }

    private func shapeAttack(
        directive: ZoneDirective,
        attack: AttackParameters,
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?,
        state: GameState
    ) -> (directive: ZoneDirective, action: String, rationale: String) {
        let style = general?.commandStyle ?? commandStyle(from: assignment)
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

        let tactic = shapedAttackTactic(
            current: directive.tactic,
            attack: attack,
            zone: zone,
            assignment: assignment,
            general: general,
            style: style,
            state: state
        )
        action = actionWithTactic(
            base: action,
            tactic: tactic,
            previous: directive.tactic,
            defaultTactic: .standardAttack
        )

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
            category: .offense,
            tactic: tactic,
            commandTarget: directive.commandTarget
        )
        let rationale = "\(generalName(general, fallback: assignment.generalId)) 依据忠诚 \(assignment.loyalty)、满意 \(assignment.satisfaction)、\(style.displayName)风格和\(skillSummary(assignment: assignment, general: general))复核攻势，采用\(tactic.displayName)。"
        return (adjusted, action, rationale)
    }

    private func shapeDefense(
        directive: ZoneDirective,
        defense: DefenseParameters,
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?,
        state: GameState
    ) -> (directive: ZoneDirective, action: String, rationale: String) {
        let style = general?.commandStyle ?? commandStyle(from: assignment)
        let reserveTarget: Int
        var action: String
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

        let tactic = shapedDefenseTactic(
            current: directive.tactic,
            defense: defense,
            zone: zone,
            assignment: assignment,
            general: general,
            style: style,
            state: state
        )
        action = actionWithTactic(
            base: action,
            tactic: tactic,
            previous: directive.tactic,
            defaultTactic: .holdPosition
        )

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
            category: .defense,
            tactic: tactic,
            commandTarget: directive.commandTarget
        )
        let rationale = "\(generalName(general, fallback: assignment.generalId)) 依据忠诚 \(assignment.loyalty)、满意 \(assignment.satisfaction)、防区压力 \(zone.pressure)、\(style.displayName)风格和\(skillSummary(assignment: assignment, general: general))复核防务，采用\(tactic.displayName)。"
        return (adjusted, action, rationale)
    }

    private func shapedAttackTactic(
        current: TacticName?,
        attack: AttackParameters,
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?,
        style: ZoneCommanderAgentConfig.CommandStyle,
        state: GameState
    ) -> TacticName {
        let fallback = offensiveTactic(from: current)
        let skills = skillSet(assignment: assignment, general: general)

        if assignment.satisfaction < 35 || assignment.loyalty < 35 {
            return firstUsable(
                [.feint, .standardAttack],
                zone: zone,
                assignment: assignment,
                general: general,
                style: style,
                state: state
            ) ?? fallback
        }

        var candidates: [TacticName] = []
        let coordinatedZoneIds = attack.coordinatedZoneIds ?? []
        let hasCrossZoneCoordination = coordinatedZoneIds.count > 1 || coordinatedZoneIds.contains { $0 != zone.id }
        if attack.convergenceRegionId != nil || hasCrossZoneCoordination {
            candidates.append(.pincerMovement)
        }
        if hasAnySkill(["fortress_operations", "siegecraft", "set_piece_attack"], in: skills) {
            candidates.append(.fireCoverage)
        }
        if style == .aggressive,
           hasAnySkill(["cavalry_charge", "rapid_exploitation", "armor_expert"], in: skills) {
            candidates.append((attack.exploitDepth ?? 0) > 0 || !zone.unitsDepth.isEmpty ? .blitzkrieg : .spearhead)
            candidates.append(.spearhead)
        }
        if hasAnySkill(["breakthrough", "counterattack", "offensive_planning"], in: skills) {
            candidates.append(.breakthrough)
        }
        if style == .cautious {
            candidates.append(.feint)
        }
        candidates.append(fallback)
        candidates.append(.standardAttack)

        return firstUsable(
            candidates,
            zone: zone,
            assignment: assignment,
            general: general,
            style: style,
            state: state
        ) ?? .standardAttack
    }

    private func shapedDefenseTactic(
        current: TacticName?,
        defense: DefenseParameters,
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?,
        style: ZoneCommanderAgentConfig.CommandStyle,
        state: GameState
    ) -> TacticName {
        let fallback = defensiveTactic(from: current)
        let skills = skillSet(assignment: assignment, general: general)

        var candidates: [TacticName] = []
        if zone.pressure >= 3 && zone.unitsDepth.isEmpty {
            candidates.append(.lastStand)
        }
        if assignment.satisfaction < 35 || assignment.loyalty < 35 {
            candidates.append(.defenseInDepth)
            candidates.append(.holdPosition)
        }
        if style == .cautious ||
            hasAnySkill(["defensive_master", "staff_coordination", "reserve_control"], in: skills) {
            candidates.append(.defenseInDepth)
        }
        if style == .aggressive,
           zone.pressure == 0,
           !(defense.counterattackRegionIds ?? []).isEmpty {
            candidates.append(.elasticDefense)
        }
        if hasAnySkill(["fortress_operations", "discipline"], in: skills) {
            candidates.append(.holdPosition)
        }
        candidates.append(fallback)
        candidates.append(.holdPosition)

        return firstUsable(
            candidates,
            zone: zone,
            assignment: assignment,
            general: general,
            style: style,
            state: state
        ) ?? .holdPosition
    }

    private func firstUsable(
        _ tactics: [TacticName],
        zone: FrontZone,
        assignment: GeneralAssignment,
        general: GeneralData?,
        style: ZoneCommanderAgentConfig.CommandStyle,
        state: GameState
    ) -> TacticName? {
        let checker = TacticConditionChecker()
        let config = ZoneCommanderAgentConfig(
            id: assignment.generalId,
            name: generalName(general, fallback: assignment.generalDisplayName ?? assignment.generalId),
            faction: zone.faction,
            assignedZoneId: zone.id,
            skills: Array(skillSet(assignment: assignment, general: general)).sorted(),
            commandStyle: style
        )
        for tactic in stableUnique(tactics) where checker.canUseTactic(
            tactic,
            commander: config,
            zone: zone,
            state: state
        ) {
            return tactic
        }
        return nil
    }

    private func offensiveTactic(from tactic: TacticName?) -> TacticName {
        guard let tactic, tactic.category == .offense else {
            return .standardAttack
        }
        return tactic
    }

    private func defensiveTactic(from tactic: TacticName?) -> TacticName {
        guard let tactic, tactic.category == .defense else {
            return .holdPosition
        }
        return tactic
    }

    private func actionWithTactic(
        base: String,
        tactic: TacticName,
        previous: TacticName?,
        defaultTactic: TacticName
    ) -> String {
        if previous == tactic || (previous == nil && tactic == defaultTactic) {
            return base
        }
        let tacticAction = "改用\(tactic.displayName)"
        if base.hasPrefix("保持") {
            return tacticAction
        }
        return "\(base)，\(tacticAction)"
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
            commandStyle: general?.commandStyle ?? assignment.map { commandStyle(from: $0) },
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

    private func skillSet(assignment: GeneralAssignment, general: GeneralData?) -> Set<String> {
        Set(assignment.skills).union(general?.skills ?? [])
    }

    private func hasAnySkill(_ candidates: [String], in skills: Set<String>) -> Bool {
        !Set(candidates).isDisjoint(with: skills)
    }

    private func stableUnique(_ tactics: [TacticName]) -> [TacticName] {
        var seen: Set<TacticName> = []
        var result: [TacticName] = []
        for tactic in tactics where seen.insert(tactic).inserted {
            result.append(tactic)
        }
        return result
    }

    private func skillSummary(assignment: GeneralAssignment, general: GeneralData?) -> String {
        let skills = Array(skillSet(assignment: assignment, general: general)).sorted()
        guard !skills.isEmpty else {
            return "无技能快照"
        }
        return "技能 \(skills.prefix(3).joined(separator: "/"))"
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

    private func commandStyle(from assignment: GeneralAssignment) -> ZoneCommanderAgentConfig.CommandStyle {
        if let rawValue = assignment.commandStyleRawValue,
           let style = ZoneCommanderAgentConfig.CommandStyle(rawValue: rawValue) {
            return style
        }
        return inferredStyle(from: assignment)
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
