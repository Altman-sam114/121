import Foundation

struct CommandValidator {
    private let movementRules = MovementRules()

    func validate(_ command: Command, in state: GameState) -> CommandValidation {
        switch command {
        case .move(let divisionId, let destination):
            return validateMove(divisionId: divisionId, destination: destination, in: state)
        case .attack(let attackerId, let targetId):
            return validateAttack(attackerId: attackerId, targetId: targetId, in: state)
        case .hold(let divisionId):
            return validateUnitCommand(divisionId: divisionId, in: state)
        case .allowRetreat(let divisionId):
            return validateUnitCommand(divisionId: divisionId, in: state)
        case .resupply(let divisionId):
            return validateRecoveryCommand(divisionId: divisionId, in: state)
        case .queueProduction(let kind):
            return validateProduction(kind: kind, in: state)
        case .improveRoad(let regionId):
            return validateRoadImprovement(regionId: regionId, in: state)
        case .proposeDiplomacy(let sourceCountryId, let targetCountryId, let proposal):
            return validateDiplomacy(
                sourceCountryId: sourceCountryId,
                targetCountryId: targetCountryId,
                proposal: proposal,
                in: state
            )
        case .endTurn:
            return validateEndTurn(in: state)
        }
    }

    private func validateMove(divisionId: String, destination: HexCoord, in state: GameState) -> CommandValidation {
        let unitValidation = validateUnitCommand(divisionId: divisionId, in: state)
        guard unitValidation.isValid,
              let division = state.division(id: divisionId) else {
            return unitValidation
        }

        guard state.map.contains(destination) else {
            return .invalid(.destinationOutOfBounds)
        }

        guard state.map.tile(at: destination)?.isPassable == true else {
            return .invalid(.noPath)
        }

        if state.division(at: destination) != nil {
            return .invalid(.destinationOccupied)
        }

        if let path = movementRules.shortestPathIgnoringMovement(for: division, to: destination, in: state),
           path.cost > movementRules.effectiveMovementLimit(for: division, in: state) {
            return .invalid(.insufficientMovement)
        }

        guard movementRules.shortestPath(for: division, to: destination, in: state) != nil else {
            return .invalid(.noPath)
        }

        return .valid
    }

    private func validateAttack(attackerId: String, targetId: String, in state: GameState) -> CommandValidation {
        let unitValidation = validateUnitCommand(divisionId: attackerId, in: state)
        guard unitValidation.isValid,
              let attacker = state.division(id: attackerId) else {
            return unitValidation
        }

        guard let target = state.division(id: targetId) else {
            return .invalid(.targetNotFound)
        }

        guard target.faction.isHostile(to: attacker.faction) else {
            return .invalid(.invalidTargetFaction)
        }

        guard attacker.coord.distance(to: target.coord) <= attacker.range else {
            return .invalid(.targetOutOfRange)
        }

        return .valid
    }

    private func validateUnitCommand(divisionId: String, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard let division = state.division(id: divisionId) else {
            return .invalid(.divisionNotFound)
        }

        guard division.faction == state.activeFaction else {
            return .invalid(.wrongFaction)
        }

        guard !division.hasActed, !division.isRetreating else {
            return .invalid(.alreadyActed)
        }

        guard division.canAct else {
            return .invalid(.alreadyActed)
        }

        return .valid
    }

    private func validateRecoveryCommand(divisionId: String, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard let division = state.division(id: divisionId) else {
            return .invalid(.divisionNotFound)
        }

        guard division.faction == state.activeFaction else {
            return .invalid(.wrongFaction)
        }

        guard !division.hasActed, !division.isDestroyed, !division.isRetreating else {
            return .invalid(.alreadyActed)
        }

        return .valid
    }

    private func validateEndTurn(in state: GameState) -> CommandValidation {
        phaseAllowsCommands(in: state) ? .valid : .invalid(.wrongPhase)
    }

    private func validateProduction(kind: ProductionKind, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard EconomyRules().canQueueProduction(kind: kind, faction: state.activeFaction, in: state) else {
            return .invalid(.insufficientResources)
        }

        return .valid
    }

    private func validateRoadImprovement(regionId: RegionId, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard let region = state.map.region(id: regionId) else {
            return .invalid(.regionNotFound)
        }

        let economyRules = EconomyRules()
        guard region.controller == state.activeFaction,
              economyRules.hasControlledHex(in: region, faction: state.activeFaction, map: state.map) else {
            return .invalid(.wrongFaction)
        }

        guard economyRules.roadImprovementNeeded(region: region, faction: state.activeFaction, map: state.map) else {
            return .invalid(.roadAlreadyImproved)
        }

        guard state.economyState
            .ledger(for: state.activeFaction)
            .stockpile
            .canAfford(economyRules.roadImprovementCost) else {
            return .invalid(.insufficientResources)
        }

        return .valid
    }

    private func validateDiplomacy(
        sourceCountryId: CountryId,
        targetCountryId: CountryId,
        proposal: DiplomaticProposal,
        in state: GameState
    ) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard sourceCountryId != targetCountryId else {
            return .invalid(.invalidDiplomaticTarget)
        }

        guard let sourceCountry = state.diplomacyState.countries.first(where: { $0.id == sourceCountryId }),
              let targetCountry = state.diplomacyState.countries.first(where: { $0.id == targetCountryId }) else {
            return .invalid(.countryNotFound)
        }

        guard sourceCountry.faction == state.activeFaction else {
            return .invalid(.wrongFaction)
        }

        guard sourceCountry.faction != targetCountry.faction else {
            return .invalid(.invalidDiplomaticTarget)
        }

        guard let relation = state.diplomacyState.relation(between: sourceCountryId, and: targetCountryId) else {
            return .invalid(.diplomaticRelationNotFound)
        }

        guard isDiplomaticProposal(
            proposal,
            legalFor: relation,
            sourceCountry: sourceCountry,
            targetCountry: targetCountry
        ) else {
            return .invalid(.invalidDiplomaticProposal)
        }

        return .valid
    }

    private func isDiplomaticProposal(
        _ proposal: DiplomaticProposal,
        legalFor relation: DiplomaticRelation,
        sourceCountry: CountryProfile,
        targetCountry: CountryProfile
    ) -> Bool {
        switch proposal {
        case .alliance:
            return relation.status == .neutral || relation.status == .coBelligerent
        case .truce:
            return relation.status == .hostile || relation.status == .atWar
        case .borrowPassage:
            return relation.status == .neutral ||
                relation.status == .coBelligerent ||
                relation.status == .allied
        case .vassalage:
            return relation.status == .neutral || relation.status == .hostile
        case .warAppeal:
            return relation.status == .neutral ||
                relation.status == .hostile ||
                relation.status == .atWar
        case .tribute:
            return sourceCountry.faction == .han || targetCountry.faction == .han
        }
    }

    private func phaseAllowsCommands(in state: GameState) -> Bool {
        switch state.phase {
        case .germanAI:
            return state.activeFaction == .germany
        case .alliedPlayer:
            return state.activeFaction == .allies
        case .resolution:
            return false
        }
    }
}
