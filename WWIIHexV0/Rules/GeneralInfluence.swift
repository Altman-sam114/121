import Foundation

struct GeneralInfluence {
    func effectiveMovementLimit(for division: Division, in state: GameState) -> Int {
        division.movement + roadMobilityBonus(for: division, in: state)
    }

    func roadMobilityBonus(for division: Division, in state: GameState) -> Int {
        guard let assignment = assignment(for: division, in: state),
              usesRoadNetwork(division: division, assignment: assignment, in: state),
              commandQuality(assignment) >= 45 else {
            return 0
        }

        var bonus = 1
        if hasAnySkill(["logistics", "rapid_exploitation", "armor_expert", "cavalry_charge"], in: assignment) {
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

    private func usesRoadNetwork(
        division: Division,
        assignment: GeneralAssignment,
        in state: GameState
    ) -> Bool {
        if state.map.tile(at: division.coord)?.hasRoad == true {
            return true
        }
        if hasAnySkill(["logistics", "rapid_exploitation", "armor_expert"], in: assignment),
           let regionId = state.map.region(for: division.coord),
           let region = state.map.region(id: regionId) {
            return region.displayHexes.contains { state.map.tile(at: $0)?.hasRoad == true }
        }
        return false
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
