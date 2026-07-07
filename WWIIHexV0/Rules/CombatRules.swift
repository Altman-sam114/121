import Foundation

struct CombatDamage: Equatable {
    let strengthDamage: Int
    let lossRatio: Double
}

struct CombatAuditSummary: Equatable {
    let baseAttack: Int
    let effectiveAttack: Int
    let baseDefense: Int
    let effectiveDefense: Int
    let flankBonus: Int
    let attackFactors: [String]
    let defenseFactors: [String]

    var logFragment: String? {
        var headline: [String] = []
        if baseAttack != effectiveAttack {
            headline.append("攻击 \(baseAttack)->\(effectiveAttack)")
        }
        if baseDefense != effectiveDefense {
            headline.append("防御 \(baseDefense)->\(effectiveDefense)")
        }
        if let flankDescription {
            headline.append(flankDescription)
        }

        let factors = attackFactors + defenseFactors
        guard !headline.isEmpty || !factors.isEmpty else {
            return nil
        }

        let headlineText = headline.isEmpty ? "修正因素" : headline.joined(separator: "，")
        if factors.isEmpty {
            return "交战审计：\(headlineText)"
        }
        return "交战审计：\(headlineText)（\(factors.joined(separator: "，"))）"
    }

    private var flankDescription: String? {
        switch flankBonus {
        case 0:
            return nil
        case 2:
            return "侧击 +2"
        case 4:
            return "背击 +4"
        default:
            return "夹击 \(signed(flankBonus))"
        }
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

struct CombatRules {
    let movementRules = MovementRules()
    private let supplyRules = SupplyRules()
    private let generalInfluence = GeneralInfluence()

    func terrainDefenseBonus(for defender: Division, attackedBy attacker: Division, in state: GameState) -> Int {
        guard let defenderTile = state.map.tile(at: defender.coord) else {
            return 0
        }

        var bonus = defenderTile.baseTerrain.defenseBonus
        if hasRiverBetween(attacker.coord, defender.coord, in: state) {
            bonus += 2
        }
        return bonus
    }

    func effectiveDefense(for defender: Division, attackedBy attacker: Division, in state: GameState) -> Int {
        defenseProfile(defender: defender, attackedBy: attacker, in: state).effectiveDefense
    }

    func flankBonus(attacker: Division, defender: Division) -> Int {
        guard let attackDirection = defender.coord.direction(to: attacker.coord) else {
            return 0
        }

        switch attackDirection.relation(toFacing: defender.facing) {
        case .front:
            return 0
        case .flank:
            return 2
        case .rear:
            return 4
        }
    }

    func damage(attacker: Division, defender: Division, in state: GameState) -> Int {
        let rawDamage = effectiveAttack(for: attacker, against: defender, in: state) -
            effectiveDefense(for: defender, attackedBy: attacker, in: state) / 2
        return clamp(rawDamage + flankBonus(attacker: attacker, defender: defender), min: 1, max: 8)
    }

    func effectiveAttack(for attacker: Division, against defender: Division, in state: GameState) -> Int {
        attackProfile(attacker: attacker, defender: defender, in: state).effectiveAttack
    }

    func attackDamage(attacker: Division, defender: Division, in state: GameState) -> CombatDamage {
        let strengthDamage = damage(attacker: attacker, defender: defender, in: state)
        return CombatDamage(
            strengthDamage: strengthDamage,
            lossRatio: lossRatio(strengthDamage: strengthDamage, defender: defender)
        )
    }

    func canCounterAttack(defender: Division, attacker: Division) -> Bool {
        guard defender.hp > 0 else {
            return false
        }

        if defender.isArtillery && defender.coord.distance(to: attacker.coord) == 1 {
            return false
        }

        return defender.coord.distance(to: attacker.coord) <= defender.range
    }

    func counterDamage(defender: Division, attacker: Division, in state: GameState) -> Int {
        max(1, damage(attacker: defender, defender: attacker, in: state) / 2)
    }

    func counterAttackDamage(defender: Division, attacker: Division, in state: GameState) -> CombatDamage {
        let strengthDamage = counterDamage(defender: defender, attacker: attacker, in: state)
        return CombatDamage(
            strengthDamage: strengthDamage,
            lossRatio: lossRatio(strengthDamage: strengthDamage, defender: attacker)
        )
    }

    func generalInfluenceSummary(
        attacker: Division,
        defender: Division,
        in state: GameState
    ) -> GeneralCombatInfluenceSummary {
        generalInfluence.combatSummary(attacker: attacker, defender: defender, in: state)
    }

    func combatAuditSummary(
        attacker: Division,
        defender: Division,
        in state: GameState
    ) -> CombatAuditSummary {
        let attackProfile = attackProfile(attacker: attacker, defender: defender, in: state)
        let defenseProfile = defenseProfile(defender: defender, attackedBy: attacker, in: state)
        return CombatAuditSummary(
            baseAttack: attackProfile.baseAttack,
            effectiveAttack: attackProfile.effectiveAttack,
            baseDefense: defenseProfile.baseDefense,
            effectiveDefense: defenseProfile.effectiveDefense,
            flankBonus: flankBonus(attacker: attacker, defender: defender),
            attackFactors: attackProfile.factors,
            defenseFactors: defenseProfile.factors
        )
    }

    func hasRiverBetween(_ a: HexCoord, _ b: HexCoord, in state: GameState) -> Bool {
        guard a.distance(to: b) == 1,
              let direction = a.direction(to: b),
              let fromTile = state.map.tile(at: a),
              let toTile = state.map.tile(at: b) else {
            return false
        }

        return movementRules.hasRiverCrossing(from: fromTile, to: toTile, direction: direction)
    }

    private func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private func isCityOrFortress(_ tile: HexTile) -> Bool {
        tile.baseTerrain == .city ||
            tile.baseTerrain == .fortress ||
            tile.cityName != nil ||
            tile.fortressName != nil
    }

    private func lossRatio(strengthDamage: Int, defender: Division) -> Double {
        guard defender.strength > 0 else {
            return 1
        }
        return Double(strengthDamage) / Double(defender.strength)
    }

    private func signedBonus(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func attackProfile(attacker: Division, defender: Division, in state: GameState) -> AttackProfile {
        guard let defenderTile = state.map.tile(at: defender.coord) else {
            return AttackProfile(baseAttack: attacker.attack, effectiveAttack: attacker.attack, factors: [])
        }

        var multiplier = 1.0
        var factors: [String] = []
        if attacker.isArmor && defenderTile.baseTerrain == .plain {
            multiplier += 0.2
            factors.append("攻方骑兵平原 +20%")
        }
        if attacker.isArmor && defenderTile.baseTerrain.armorSlowdownCost > 0 {
            multiplier -= 0.1
            factors.append("攻方骑兵受 \(defenderTile.baseTerrain.displayName) -10%")
        }
        if attacker.isSiegeCapable && isCityOrFortress(defenderTile) {
            multiplier += 0.25
            factors.append("攻方器械攻城 +25%")
        }

        let generalAttackBonus = generalInfluence.attackBonus(attacker: attacker, defender: defender, in: state)
        if generalAttackBonus != 0 {
            factors.append("攻方武将 \(signedBonus(generalAttackBonus))")
        }

        let modifiedAttack = Int((Double(attacker.attack) * multiplier).rounded()) + generalAttackBonus
        return AttackProfile(
            baseAttack: attacker.attack,
            effectiveAttack: max(1, modifiedAttack),
            factors: factors
        )
    }

    private func defenseProfile(defender: Division, attackedBy attacker: Division, in state: GameState) -> DefenseProfile {
        var effectiveDefense = defender.defense
        var factors: [String] = []

        if let defenderTile = state.map.tile(at: defender.coord) {
            let terrainBonus = defenderTile.baseTerrain.defenseBonus
            if terrainBonus != 0 {
                factors.append("守方\(defenderTile.baseTerrain.displayName)防御 +\(terrainBonus)")
            }
            effectiveDefense += terrainBonus

            if hasRiverBetween(attacker.coord, defender.coord, in: state) {
                effectiveDefense += 2
                factors.append("守方隔河 +2")
            }

            let generalDefenseBonus = generalInfluence.defenseBonus(defender: defender, attackedBy: attacker, in: state)
            if generalDefenseBonus != 0 {
                factors.append("守方武将 \(signedBonus(generalDefenseBonus))")
            }
            effectiveDefense += generalDefenseBonus

            if defender.isInfantryHeavy,
               defenderTile.baseTerrain.supportsInfantryDefenseBonus {
                effectiveDefense = max(1, Int((Double(effectiveDefense) * 1.3).rounded()))
                factors.append("守方步卒据险 x1.3")
            }
        } else {
            let generalDefenseBonus = generalInfluence.defenseBonus(defender: defender, attackedBy: attacker, in: state)
            if generalDefenseBonus != 0 {
                factors.append("守方武将 \(signedBonus(generalDefenseBonus))")
            }
            effectiveDefense += generalDefenseBonus
        }

        if supplyRules.isBesieged(defender, in: state) {
            effectiveDefense = max(1, Int((Double(effectiveDefense) * 0.75).rounded()))
            factors.append("守方围城 x0.75")
        }

        if defender.retreatMode == .hold {
            effectiveDefense = max(1, Int((Double(effectiveDefense) * 1.2).rounded()))
            factors.append("守方死守 x1.2")
        }

        return DefenseProfile(
            baseDefense: defender.defense,
            effectiveDefense: effectiveDefense,
            factors: factors
        )
    }
}

private struct AttackProfile: Equatable {
    let baseAttack: Int
    let effectiveAttack: Int
    let factors: [String]
}

private struct DefenseProfile: Equatable {
    let baseDefense: Int
    let effectiveDefense: Int
    let factors: [String]
}
