import Foundation

struct RegionVictoryAssessment: Equatable {
    let winner: Faction?
    let reason: VictoryReason?
    let reasonDescription: String?

    init(winner: Faction?, reason: VictoryReason?, reasonDescription: String? = nil) {
        self.winner = winner
        self.reason = reason
        self.reasonDescription = reasonDescription
    }

    var displayReason: String? {
        reasonDescription ?? reason?.displayName
    }
}

struct RegionVictoryRules {
    func assessVictory(in state: GameState) -> RegionVictoryAssessment {
        if let scenarioAssessment = assessScenarioVictory(in: state) {
            return scenarioAssessment
        }

        let bastogneController = controller(ofCityNamed: "Bastogne", in: state)
        let stVithController = controller(ofCityNamed: "St. Vith", in: state)

        if bastogneController == .germany && stVithController == .germany {
            return RegionVictoryAssessment(winner: .germany, reason: .bastogneAndStVithControlledByGermany)
        }

        if state.turn >= state.maxTurns && bastogneController == .allies {
            return RegionVictoryAssessment(winner: .allies, reason: .bastogneHeldByAlliesAtFinalTurn)
        }

        return RegionVictoryAssessment(winner: nil, reason: nil)
    }

    func controller(ofCityNamed name: String, in state: GameState) -> Faction? {
        state.map.regions.values.first { $0.city?.name == name }?.controller
    }

    private func assessScenarioVictory(in state: GameState) -> RegionVictoryAssessment? {
        for condition in state.victoryState.scenarioConditions where condition.status == "active" {
            switch condition.type {
            case "controlObjective":
                guard controlsAllObjectives(for: condition, in: state.map) else {
                    continue
                }
                return RegionVictoryAssessment(
                    winner: condition.faction,
                    reason: .scenarioObjectiveControlled,
                    reasonDescription: condition.description
                )
            default:
                continue
            }
        }

        return nil
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
