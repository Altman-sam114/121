import Foundation

struct VictoryRules {
    func updateVictoryState(in state: inout GameState) {
        guard state.victoryState.winner == nil else {
            return
        }

        if applyScenarioVictoryConditions(in: &state) {
            return
        }

        let bastogneController = state.map.controllerOfObjective(id: "bastogne")
        let stVithController = state.map.controllerOfObjective(id: "st_vith")

        if bastogneController == .germany {
            if let heldSince = state.victoryState.germanBastogneHeldSinceTurn,
               state.turn > heldSince {
                state.victoryState.winner = .germany
                state.victoryState.reason = .bastogneHeldByGermany
                return
            } else if state.victoryState.germanBastogneHeldSinceTurn == nil {
                state.victoryState.germanBastogneHeldSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanBastogneHeldSinceTurn = nil
        }

        if bastogneController == .germany && stVithController == .germany {
            state.victoryState.winner = .germany
            state.victoryState.reason = .bastogneAndStVithControlledByGermany
            return
        }

        if state.victoryState.eliminatedAlliedDivisions >= 3 {
            state.victoryState.winner = .germany
            state.victoryState.reason = .alliedUnitsDestroyed
            return
        }

        if state.victoryState.eliminatedGermanDivisions >= 3 {
            state.victoryState.winner = .allies
            state.victoryState.reason = .germanUnitsDestroyed
            return
        }

        let germanArmor = state.divisions.filter { $0.faction == .germany && $0.isArmor }
        if !germanArmor.isEmpty && germanArmor.allSatisfy({ $0.supplyState != .supplied }) {
            if let since = state.victoryState.germanArmorUnsuppliedSinceTurn,
               state.turn > since {
                state.victoryState.winner = .allies
                state.victoryState.reason = .germanArmorUnsupplied
                return
            } else if state.victoryState.germanArmorUnsuppliedSinceTurn == nil {
                state.victoryState.germanArmorUnsuppliedSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanArmorUnsuppliedSinceTurn = nil
        }

        if state.turn >= state.maxTurns && bastogneController == .allies {
            state.victoryState.winner = .allies
            state.victoryState.reason = .bastogneHeldByAlliesAtFinalTurn
        }
    }

    private func applyScenarioVictoryConditions(in state: inout GameState) -> Bool {
        for condition in state.victoryState.scenarioConditions where condition.status == "active" {
            switch condition.type {
            case "controlObjective":
                guard controlsAllObjectives(for: condition, in: state.map) else {
                    continue
                }
                state.victoryState.winner = condition.faction
                state.victoryState.reason = .scenarioObjectiveControlled
                state.victoryState.reasonDescription = condition.description
                return true
            default:
                continue
            }
        }

        return false
    }

    private func controlsAllObjectives(for condition: ScenarioVictoryCondition, in map: MapState) -> Bool {
        let objectiveIds = Set(([condition.objectiveId].compactMap { $0 }) + condition.objectiveIds)
        guard !objectiveIds.isEmpty else {
            return false
        }

        return objectiveIds.allSatisfy { objectiveId in
            guard let objective = map.objective(id: objectiveId) else {
                return false
            }
            return map.tile(at: objective.coord)?.controller == condition.faction
        }
    }
}
