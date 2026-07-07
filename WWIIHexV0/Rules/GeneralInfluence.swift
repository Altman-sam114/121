import Foundation

struct GeneralCombatInfluenceSummary: Equatable {
    let attackerGeneralId: String?
    let attackerGeneralName: String?
    let defenderGeneralId: String?
    let defenderGeneralName: String?
    let attackBonus: Int
    let defenseBonus: Int

    var logFragment: String? {
        var parts: [String] = []
        if attackBonus != 0 {
            parts.append("\(attackerDisplayName ?? "未命名武将") 攻击 \(signed(attackBonus))")
        }
        if defenseBonus != 0 {
            parts.append("\(defenderDisplayName ?? "未命名武将") 防御 \(signed(defenseBonus))")
        }
        guard !parts.isEmpty else {
            return nil
        }
        return "武将影响：\(parts.joined(separator: "，"))"
    }

    var attackerDisplayName: String? {
        displayName(name: attackerGeneralName, id: attackerGeneralId)
    }

    var defenderDisplayName: String? {
        displayName(name: defenderGeneralName, id: defenderGeneralId)
    }

    private func displayName(name: String?, id: String?) -> String? {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }
        let trimmedId = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedId.isEmpty ? nil : "未命名武将"
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

enum GeneralRoadMobilityNoBonusReason: Hashable {
    case noAssignedGeneral
    case commandQualityTooLow
    case noRoadNetworkSkill
    case noRoadInRegion
}

struct GeneralMovementInfluenceSummary: Equatable {
    let generalId: String?
    let generalName: String?
    let baseMovement: Int
    let effectiveMovement: Int
    let roadBonus: Int
    let noBonusReason: GeneralRoadMobilityNoBonusReason?

    var logFragment: String? {
        guard roadBonus != 0 else {
            return nil
        }
        return "武将道路：\(assignedGeneralDisplayName ?? "未命名武将") 机动 \(signed(roadBonus))，上限由 \(baseMovement) 提至 \(effectiveMovement)"
    }

    var noBonusFragment: String? {
        guard roadBonus == 0, let noBonusReason else {
            return nil
        }
        switch noBonusReason {
        case .noAssignedGeneral:
            return "道路：未分配武将，按基础机动行军"
        case .commandQualityTooLow:
            return "道路：\(assignedGeneralDisplayName ?? "未命名武将") 忠诚/满意不足，官道机动暂未触发"
        case .noRoadNetworkSkill:
            return "道路：\(assignedGeneralDisplayName ?? "未命名武将") 需进驻官道，或凭粮道/疾行/骑战技能借郡县官道"
        case .noRoadInRegion:
            return "道路：\(assignedGeneralDisplayName ?? "未命名武将") 所在郡县暂无可借官道"
        }
    }

    var assignedGeneralDisplayName: String? {
        let trimmedName = generalName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }
        let trimmedId = generalId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedId.isEmpty ? nil : "未命名武将"
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

struct GeneralInfluence {
    private static let roadNetworkSkills = [
        "logistics",
        "rapid_exploitation",
        "armor_expert",
        "cavalry_charge"
    ]

    func effectiveMovementLimit(for division: Division, in state: GameState) -> Int {
        division.movement + roadMobilityBonus(for: division, in: state)
    }

    func roadMobilityBonus(for division: Division, in state: GameState) -> Int {
        guard let assignment = assignment(for: division, in: state) else {
            return 0
        }
        return roadMobilityBonus(for: division, assignment: assignment, in: state)
    }

    func movementSummary(for division: Division, in state: GameState) -> GeneralMovementInfluenceSummary {
        let assignment = assignment(for: division, in: state)
        let roadBonus = assignment.map {
            roadMobilityBonus(for: division, assignment: $0, in: state)
        } ?? 0
        let noBonusReason: GeneralRoadMobilityNoBonusReason?
        if roadBonus == 0 {
            noBonusReason = assignment.map {
                roadMobilityNoBonusReason(for: division, assignment: $0, in: state)
            } ?? .noAssignedGeneral
        } else {
            noBonusReason = nil
        }
        return GeneralMovementInfluenceSummary(
            generalId: assignment?.generalId,
            generalName: assignment?.generalDisplayName,
            baseMovement: division.movement,
            effectiveMovement: division.movement + roadBonus,
            roadBonus: roadBonus,
            noBonusReason: noBonusReason
        )
    }

    private func roadMobilityBonus(
        for division: Division,
        assignment: GeneralAssignment,
        in state: GameState
    ) -> Int {
        guard roadMobilityNoBonusReason(for: division, assignment: assignment, in: state) == nil else {
            return 0
        }
        var bonus = 1
        if hasAnySkill(Self.roadNetworkSkills, in: assignment) {
            bonus += 1
        }
        return min(2, bonus)
    }

    func attackBonus(attacker: Division, defender: Division, in state: GameState) -> Int {
        guard let assignment = assignment(for: attacker, in: state) else {
            return 0
        }

        var bonus = qualityBonus(assignment)
        if attacker.isArmor,
           hasAnySkill(["armor_expert", "rapid_exploitation", "cavalry_charge"], in: assignment) {
            bonus += 1
        }
        if hasAnySkill(["breakthrough", "counterattack", "offensive_planning", "set_piece_attack"], in: assignment) {
            bonus += 1
        }
        if assignment.commandStyleRawValue == "aggressive" {
            bonus += 1
        }
        if attacker.isSiegeCapable,
           isCityOrFortress(state.map.tile(at: defender.coord)),
           hasAnySkill(["fortress_operations", "siegecraft", "set_piece_attack"], in: assignment) {
            bonus += 1
        }
        return clamp(bonus, min: -1, max: 2)
    }

    func defenseBonus(defender: Division, attackedBy attacker: Division, in state: GameState) -> Int {
        guard let assignment = assignment(for: defender, in: state) else {
            return 0
        }

        var bonus = qualityBonus(assignment)
        let defenderTile = state.map.tile(at: defender.coord)
        if defenderTile?.baseTerrain.supportsInfantryDefenseBonus == true,
           hasAnySkill(["defensive_master", "fortress_operations", "discipline", "reserve_control"], in: assignment) {
            bonus += 1
        }
        if hasRiverBetween(attacker.coord, defender.coord, in: state),
           hasAnySkill(["defensive_master", "staff_coordination", "reserve_control"], in: assignment) {
            bonus += 1
        }
        if assignment.commandStyleRawValue == "cautious" {
            bonus += 1
        }
        return clamp(bonus, min: -1, max: 2)
    }

    func combatSummary(attacker: Division, defender: Division, in state: GameState) -> GeneralCombatInfluenceSummary {
        let attackerAssignment = assignment(for: attacker, in: state)
        let defenderAssignment = assignment(for: defender, in: state)
        return GeneralCombatInfluenceSummary(
            attackerGeneralId: attackerAssignment?.generalId,
            attackerGeneralName: attackerAssignment?.generalDisplayName,
            defenderGeneralId: defenderAssignment?.generalId,
            defenderGeneralName: defenderAssignment?.generalDisplayName,
            attackBonus: attackBonus(attacker: attacker, defender: defender, in: state),
            defenseBonus: defenseBonus(defender: defender, attackedBy: attacker, in: state)
        )
    }

    private func assignment(for division: Division, in state: GameState) -> GeneralAssignment? {
        let zones = state.warDeploymentState.frontZones.values
            .filter { $0.faction == division.faction }
            .sorted { $0.id.rawValue < $1.id.rawValue }

        if let assigned = zones.first(where: {
            $0.generalAssignment?.assignedDivisionIds.contains(division.id) == true
        })?.generalAssignment {
            return assigned
        }

        guard let zoneId = state.warDeploymentState.zoneId(for: division.coord, map: state.map),
              let zone = state.warDeploymentState.frontZones[zoneId],
              zone.faction == division.faction else {
            return nil
        }
        return zone.generalAssignment
    }

    private func roadMobilityNoBonusReason(
        for division: Division,
        assignment: GeneralAssignment,
        in state: GameState
    ) -> GeneralRoadMobilityNoBonusReason? {
        guard commandQuality(assignment) >= 45 else {
            return .commandQualityTooLow
        }
        if state.map.tile(at: division.coord)?.hasRoad == true {
            return nil
        }
        guard hasAnySkill(Self.roadNetworkSkills, in: assignment) else {
            return .noRoadNetworkSkill
        }
        guard let regionId = state.map.region(for: division.coord),
              let region = state.map.region(id: regionId),
              region.displayHexes.contains(where: { state.map.tile(at: $0)?.hasRoad == true }) else {
            return .noRoadInRegion
        }
        return nil
    }

    private func commandQuality(_ assignment: GeneralAssignment) -> Int {
        (assignment.loyalty + assignment.satisfaction) / 2
    }

    private func qualityBonus(_ assignment: GeneralAssignment) -> Int {
        let quality = commandQuality(assignment)
        if quality < 35 {
            return -1
        }
        if quality >= 70 {
            return 1
        }
        return 0
    }

    private func hasAnySkill(_ candidates: [String], in assignment: GeneralAssignment) -> Bool {
        !Set(candidates).isDisjoint(with: Set(assignment.skills))
    }

    private func isCityOrFortress(_ tile: HexTile?) -> Bool {
        guard let tile else {
            return false
        }
        return tile.baseTerrain == .city ||
            tile.baseTerrain == .fortress ||
            tile.cityName != nil ||
            tile.fortressName != nil
    }

    private func hasRiverBetween(_ a: HexCoord, _ b: HexCoord, in state: GameState) -> Bool {
        guard a.distance(to: b) == 1,
              let direction = a.direction(to: b),
              let fromTile = state.map.tile(at: a),
              let toTile = state.map.tile(at: b) else {
            return false
        }
        return fromTile.riverEdges.contains(direction) ||
            toTile.riverEdges.contains(direction.opposite)
    }

    private func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.max(minValue, Swift.min(maxValue, value))
    }
}
