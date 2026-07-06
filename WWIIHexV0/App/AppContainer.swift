import Combine
import Foundation

struct GeneralAssignedDivisionRow: Equatable {
    let id: String
    let iconName: String
    let summary: String
}

final class AppContainer: ObservableObject {
    @Published private(set) var gameState: GameState
    @Published private(set) var selectedUnitId: String?
    @Published private(set) var selectedHex: HexCoord?
    @Published private(set) var selectedRegionId: RegionId?
    @Published private(set) var movementHighlights: Set<HexCoord>
    @Published private(set) var attackHighlights: Set<HexCoord>
    @Published private(set) var interactionLog: [GameLogEntry]
    @Published private(set) var lastCommandMessage: String?
    @Published private(set) var lastAgentDecisionRecord: AgentDecisionRecord?
    @Published private(set) var lastWarDirectiveRecords: [WarDirectiveRecord]
    @Published private(set) var observerModeEnabled: Bool
    @Published private(set) var mapDisplayLayer: MapDisplayLayer

    let commandHandler: GameCommandHandling
    let dataLoader: DataLoader
    let generalRegistry: GeneralRegistry
    let playerFaction: Faction
    let warPipelineMode: WarPipelineMode
    let turnManager: TurnManager?
    private var isRunningAI = false
    private let combatPreviewRetreatLossThreshold = 0.35

    init(
        gameState: GameState,
        commandHandler: GameCommandHandling,
        dataLoader: DataLoader,
        generalRegistry: GeneralRegistry = .empty,
        playerFaction: Faction = .allies,
        turnManager: TurnManager? = nil,
        warPipelineMode: WarPipelineMode = .marshalDirective,
        observerModeEnabled: Bool = false,
        mapDisplayLayer: MapDisplayLayer = .hex
    ) {
        let bootstrappedState = StrategicStateBootstrapper().bootstrapIfNeeded(gameState)
        self.gameState = Self.refreshGeneralAssignments(in: bootstrappedState, registry: generalRegistry)
        self.commandHandler = commandHandler
        self.dataLoader = dataLoader
        self.generalRegistry = generalRegistry
        self.playerFaction = playerFaction
        self.warPipelineMode = warPipelineMode
        self.turnManager = turnManager
        self.selectedUnitId = nil
        self.selectedHex = nil
        self.selectedRegionId = nil
        self.movementHighlights = []
        self.attackHighlights = []
        self.interactionLog = []
        self.lastCommandMessage = nil
        self.lastAgentDecisionRecord = nil
        self.lastWarDirectiveRecords = []
        self.observerModeEnabled = observerModeEnabled
        self.mapDisplayLayer = mapDisplayLayer
    }

    static func bootstrap() -> AppContainer {
        let dataLoader = DataLoader()
        let gameState = dataLoader.loadInitialGameState()
        let commandHandler = RuleEngine()
        let generalRegistry = (try? dataLoader.loadGeneralRegistry()) ?? .empty
        let guderian = GameAgent.guderian(from: dataLoader, state: gameState)
        let bootstrappedState = Self.refreshGeneralAssignments(
            in: StrategicStateBootstrapper().bootstrapIfNeeded(gameState),
            registry: generalRegistry
        )
        let turnManager = TurnManager(
            agent: guderian,
            provider: MockAIClient(),
            providerName: "MockAI",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: bootstrappedState, registry: generalRegistry),
            marshalAgent: Self.buildMarshalAgent(faction: .germany, state: bootstrappedState),
            diplomatAgent: DiplomatAgent.automatic(for: .germany, in: bootstrappedState),
            governorAgent: GovernorAgent.automatic(for: .germany, in: bootstrappedState),
            generalAgent: GeneralAgent(registry: generalRegistry)
        )
        return AppContainer(
            gameState: bootstrappedState,
            commandHandler: commandHandler,
            dataLoader: dataLoader,
            generalRegistry: generalRegistry,
            turnManager: turnManager,
            warPipelineMode: .marshalDirective
        )
    }

    func submit(_ command: Command) {
        let stateBeforeCommand = gameState
        let result = commandHandler.execute(command, in: gameState)
        var nextState = StrategicStateBootstrapper().bootstrapIfNeeded(result.state)
        if result.succeeded {
            nextState = applyPlayerCommandBookkeeping(
                command,
                to: nextState,
                previousState: stateBeforeCommand
            )
        }
        gameState = refreshGeneralAssignments(in: nextState)
        lastCommandMessage = result.message

        let status = result.succeeded ? "accepted" : "rejected"
        appendInteractionEvent("Command \(status): \(command.displayName). \(result.message)")
        refreshSelectionAfterStateChange()
        runAIIfNeeded()
    }

    func runAIIfNeeded() {
        guard !isRunningAI else {
            return
        }

        gameState = refreshedRuntimeState(gameState)
        guard shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) else {
            return
        }

        isRunningAI = true
        let stateSnapshot = gameState
        let pipelineMode = warPipelineMode
        let observerEnabled = observerModeEnabled

        Task {
            let outcome = await self.runAISequence(
                from: stateSnapshot,
                pipelineMode: pipelineMode,
                observerEnabled: observerEnabled
            )
            await MainActor.run {
                self.gameState = self.refreshedRuntimeState(outcome.state)
                self.lastAgentDecisionRecord = outcome.record
                self.lastWarDirectiveRecords = outcome.directiveRecords
                self.lastCommandMessage = outcome.record.errors.isEmpty
                    ? "AI turn completed."
                    : "AI turn completed with \(outcome.record.errors.count) issue(s)."
                self.appendInteractionEvent("AI \(outcome.record.provider) resolved \(outcome.record.commandResults.count) command result(s).")
                self.isRunningAI = false
                self.refreshSelectionAfterStateChange()
            }
        }
    }

    func handleBoardTap(_ coord: HexCoord) {
        guard gameState.map.contains(coord) else {
            return
        }

        selectedHex = coord
        selectedRegionId = mapDisplayAdapter.regionId(for: coord)
        appendInteractionEvent(selectionMessage(for: coord))

        let displayedDivisions = mapDisplayAdapter.divisions(displayedAt: coord, viewerFaction: playerFaction)
        if let attacker = selectedActionDivision,
           let enemy = displayedDivisions.first(where: { $0.faction.isHostile(to: attacker.faction) }) {
            submit(.attack(attackerId: attacker.id, targetId: enemy.id))
            return
        }

        if let tappedDivision = displayedDivisions.first {
            handleDivisionTap(tappedDivision)
            return
        }

        if let division = selectedActionDivision {
            submitMove(division: division, tappedHex: coord)
        } else {
            selectedUnitId = nil
            clearHighlights()
        }
    }

    func holdSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Hold rejected: no active allied unit selected.")
            return
        }

        submit(.hold(divisionId: division.id))
    }

    func allowRetreatSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Allow retreat rejected: no active allied unit selected.")
            return
        }

        submit(.allowRetreat(divisionId: division.id))
    }

    func resupplySelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Resupply rejected: no active allied unit selected.")
            return
        }

        submit(.resupply(divisionId: division.id))
    }

    func orderSelectedGeneralHoldLine() {
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent("General order rejected: no allied front zone selected.")
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            defense: DefenseParameters(
                targetReserves: max(1, min(2, zone.unitsDepth.count)),
                stance: .holdLine
            ),
            category: .defense,
            tactic: .holdPosition
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: nil),
            targetRegionId: nil
        )
    }

    func orderSelectedGeneralAttackRegion() {
        guard let target = selectedAttackTarget else {
            appendInteractionEvent("General order rejected: select an enemy front region to attack.")
            return
        }
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent("General order rejected: no allied source front zone available.")
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            attack: AttackParameters(
                targetTheaterId: TheaterId(target.zone.id.rawValue),
                weightedRegions: [target.region.id],
                intensity: .limitedCounter,
                focusRegionId: target.region.id,
                maxCommittedUnits: max(1, min(3, zone.unitsFront.count + zone.unitsDepth.count))
            ),
            category: .offense,
            tactic: .standardAttack,
            commandTarget: .region(target.region.id)
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: target.zone.id),
            targetRegionId: target.region.id
        )
    }

    func queueProduction(_ kind: ProductionKind) {
        guard !observerModeEnabled else {
            appendInteractionEvent("Production rejected: observer mode is read-only.")
            return
        }

        submit(.queueProduction(kind: kind))
    }

    func endTurn() {
        submit(.endTurn)
    }

    func advanceOrRunAI() {
        if shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) {
            runAIIfNeeded()
        } else {
            endTurn()
        }
    }

    func setObserverModeEnabled(_ enabled: Bool) {
        observerModeEnabled = enabled
    }

    func setMapDisplayLayer(_ layer: MapDisplayLayer) {
        mapDisplayLayer = layer
    }

    func resetGame() {
        isRunningAI = false
        gameState = refreshGeneralAssignments(
            in: StrategicStateBootstrapper().bootstrapIfNeeded(dataLoader.loadInitialGameState())
        )
        selectedUnitId = nil
        selectedHex = nil
        selectedRegionId = nil
        movementHighlights = []
        attackHighlights = []
        interactionLog = []
        lastCommandMessage = nil
        lastAgentDecisionRecord = nil
        lastWarDirectiveRecords = []
    }

    var selectedDivision: Division? {
        guard let selectedUnitId else {
            return nil
        }
        return gameState.division(id: selectedUnitId)
    }

    var selectedRegionInspectorState: RegionInspectorState? {
        guard let selectedRegionId else {
            return nil
        }
        return mapDisplayAdapter.inspectorState(for: selectedRegionId, selectedHex: selectedHex, viewerFaction: playerFaction)
    }

    var selectedUnitInspectorStrategicState: UnitInspectorStrategicState? {
        guard let selectedDivision else {
            return nil
        }
        return mapDisplayAdapter.unitInspectorState(for: selectedDivision)
    }

    var selectedUnitMobilityPreviewNotes: [String] {
        guard let division = selectedDivision else {
            return []
        }

        let movementRules = MovementRules()
        let summary = movementRules.generalInfluenceSummary(for: division, in: gameState)
        let reachableCoords = movementRules.movementRange(for: division, in: gameState)
        let reachableCount = reachableCoords.count
        var notes = [
            "机动：基础 \(summary.baseMovement)，有效 \(summary.effectiveMovement)，可达 \(reachableCount) 格"
        ]

        if let roadInfluence = summary.logFragment {
            notes.append(roadInfluence)
        } else if let generalName = summary.generalName ?? summary.generalId {
            notes.append("道路：\(generalName) 当前未触发官道机动加成")
        } else {
            notes.append("道路：未分配武将，按基础机动行军")
        }

        if let currentRoadStatus = currentRoadStatusNote(for: division, movementRules: movementRules) {
            notes.append(currentRoadStatus)
        } else if let roadCount = currentRegionRoadCount(for: division), roadCount > 0 {
            notes.append("郡县官道：\(roadCount) 格，可作为行军和粮道参考")
        } else {
            notes.append("郡县官道：暂无可用官道")
        }

        if let roadAccessNote = reachableRoadAccessNote(
            for: division,
            reachableCoords: reachableCoords,
            movementRules: movementRules
        ) {
            notes.append(roadAccessNote)
        }

        return notes
    }

    var selectedUnitCombatPreviewNotes: [String] {
        guard let division = selectedDivision else {
            return []
        }

        let combatRules = CombatRules()
        let movementRules = MovementRules()
        let enemyDistances: [(target: Division, distance: Int)] = gameState.divisions
            .compactMap { target in
                guard target.id != division.id,
                      !target.isDestroyed,
                      target.faction.isHostile(to: division.faction) else {
                    return nil
                }
                return (
                    target: target,
                    distance: division.coord.distance(to: target.coord)
                )
            }
        guard !enemyDistances.isEmpty else {
            return ["接战：当前无可预判敌对军队"]
        }

        let previews: [(
            target: Division,
            damage: CombatDamage,
            counterDamage: CombatDamage?,
            influence: GeneralCombatInfluenceSummary,
            audit: CombatAuditSummary,
            distance: Int
        )] = enemyDistances
            .compactMap { candidate in
                let target = candidate.target
                let distance = candidate.distance
                guard distance <= division.range else {
                    return nil
                }

                let counterDamage: CombatDamage?
                if combatRules.canCounterAttack(defender: target, attacker: division) {
                    counterDamage = combatRules.counterAttackDamage(defender: target, attacker: division, in: gameState)
                } else {
                    counterDamage = nil
                }

                return (
                    target: target,
                    damage: combatRules.attackDamage(attacker: division, defender: target, in: gameState),
                    counterDamage: counterDamage,
                    influence: combatRules.generalInfluenceSummary(attacker: division, defender: target, in: gameState),
                    audit: combatRules.combatAuditSummary(attacker: division, defender: target, in: gameState),
                    distance: distance
                )
            }
            .sorted {
                if $0.damage.strengthDamage != $1.damage.strengthDamage {
                    return $0.damage.strengthDamage > $1.damage.strengthDamage
                }

                let lhsCounter = $0.counterDamage?.strengthDamage ?? 0
                let rhsCounter = $1.counterDamage?.strengthDamage ?? 0
                if lhsCounter != rhsCounter {
                    return lhsCounter < rhsCounter
                }

                if $0.distance != $1.distance {
                    return $0.distance < $1.distance
                }

                if $0.target.name != $1.target.name {
                    return $0.target.name < $1.target.name
                }

                return $0.target.id < $1.target.id
            }

        guard let leadingPreview = previews.first else {
            return combatOutOfRangePreviewNotes(
                attacker: division,
                enemies: enemyDistances,
                movementRules: movementRules,
                combatRules: combatRules
            )
        }

        var notes = [
            combatTargetPriorityText(
                target: leadingPreview.target,
                damage: leadingPreview.damage,
                counterDamage: leadingPreview.counterDamage,
                distance: leadingPreview.distance,
                comparedTargetCount: previews.count
            )
        ]

        if let roadApproach = combatRoadApproachText(
            attacker: division,
            target: leadingPreview.target,
            movementRules: movementRules
        ) {
            notes.append(roadApproach)
        }

        if let generalMatchup = combatGeneralMatchupText(leadingPreview.influence) {
            notes.append(generalMatchup)
        }

        notes.append(contentsOf: previews.prefix(3).enumerated().map { index, preview in
            combatTargetPreviewLine(
                rank: index,
                attacker: division,
                target: preview.target,
                damage: preview.damage,
                counterDamage: preview.counterDamage,
                distance: preview.distance,
                influence: preview.influence,
                audit: preview.audit
            )
        })

        if let influence = leadingPreview.influence.logFragment {
            notes.append(influence)
        }

        if previews.count > 3 {
            notes.append("另有 \(previews.count - 3) 支敌军在射程内")
        }

        return notes
    }

    var selectedGeneralCommandZone: FrontZone? {
        inferredPlayerCommandZone()
    }

    var selectedGeneral: GeneralData? {
        generalRegistry.general(id: selectedGeneralAssignment?.generalId)
    }

    var selectedGeneralAssignment: GeneralAssignment? {
        selectedGeneralCommandZone?.generalAssignment
    }

    var selectedGeneralAssignedDivisions: [Division] {
        guard let assignment = selectedGeneralAssignment else {
            return []
        }
        let assignedIds = Set(assignment.assignedDivisionIds)
        return gameState.divisions
            .filter { assignedIds.contains($0.id) }
            .sorted { $0.id < $1.id }
    }

    var selectedGeneralAssignedDivisionRows: [GeneralAssignedDivisionRow] {
        let movementRules = MovementRules()
        let visibleHostiles = gameState.divisions.filter { division in
            division.faction.isHostile(to: playerFaction) &&
                !division.isDestroyed &&
                mapDisplayAdapter.isDivisionVisible(division, viewerFaction: playerFaction)
        }
        return selectedGeneralAssignedDivisions.map {
            generalAssignedDivisionRow(
                for: $0,
                movementRules: movementRules,
                visibleHostiles: visibleHostiles
            )
        }
    }

    var selectedGeneralTargetPreviewNotes: [String] {
        guard let zone = selectedGeneralCommandZone,
              let targetRegion = selectedGeneralTargetRegion,
              let targetZone = selectedGeneralTargetZone,
              targetZone.faction.isHostile(to: zone.faction) else {
            return []
        }

        let sourceRegionId = sourceRegionId(for: zone, targetZoneId: targetZone.id)
        let sourceHex = plannedOperationHex(regionId: sourceRegionId, zoneId: zone.id)
        let targetHex = gameState.map.representativeHex(for: targetRegion.id)
        var notes: [String] = []
        if let roadNote = generalTargetRoadPreviewNote(
            sourceHex: sourceHex,
            targetHex: targetHex,
            faction: zone.faction
        ) {
            notes.append(roadNote)
        }
        if let enemyNote = generalTargetVisibleEnemyPreviewNote(
            sourceHex: sourceHex,
            targetHex: targetHex,
            faction: zone.faction
        ) {
            notes.append(enemyNote)
        }
        return notes
    }

    var selectedGeneralInfluenceNotes: [String] {
        guard let zone = selectedGeneralCommandZone,
              let assignment = selectedGeneralAssignment else {
            return []
        }

        let divisions = selectedGeneralAssignedDivisions
        guard !divisions.isEmpty else {
            return [
                "道路：暂无麾下军队",
                "交战：暂无麾下军队可计算"
            ]
        }

        let influence = GeneralInfluence()
        let movementSummaries = divisions.map { influence.movementSummary(for: $0, in: gameState) }
        let roadBoostedCount = movementSummaries.filter { $0.roadBonus > 0 }.count
        let maxRoadBonus = movementSummaries.map(\.roadBonus).max() ?? 0
        let boostedRoadUnits = Array(zip(divisions, movementSummaries))
            .filter { _, summary in
                summary.roadBonus > 0
            }
            .sorted { lhs, rhs in
                if lhs.1.roadBonus != rhs.1.roadBonus {
                    return lhs.1.roadBonus > rhs.1.roadBonus
                }
                return lhs.0.id < rhs.0.id
            }
        let roadNote: String
        let roadBenefitNote: String?
        if maxRoadBonus > 0 {
            roadNote = "道路：\(roadBoostedCount)/\(divisions.count) 支军队获得官道机动，最高 +\(maxRoadBonus)"
            let displayedUnits = boostedRoadUnits.prefix(3)
                .map { division, summary in
                    "\(division.thematicDisplayName) +\(summary.roadBonus)"
                }
                .joined(separator: "，")
            let remainingCount = max(0, roadBoostedCount - 3)
            let remainingText = remainingCount > 0 ? "，另 \(remainingCount) 支" : ""
            roadBenefitNote = "道路受益：\(displayedUnits)\(remainingText)"
        } else {
            roadNote = "道路：当前麾下军队未获得官道机动加成"
            roadBenefitNote = generalRoadNoBonusReasonText(
                for: divisions,
                assignment: assignment
            )
        }

        let enemyDivisions = gameState.divisions
            .filter { $0.faction.isHostile(to: zone.faction) && !$0.isDestroyed }
        let nearestEnemyText = nearestEnemyText(for: divisions, enemyDivisions: enemyDivisions)
        let engagementPairingNote = engagementPairingText(
            for: divisions,
            enemyDivisions: enemyDivisions,
            influence: influence
        )
        var attackBonuses: [Int] = []
        var defenseBonuses: [Int] = []
        for division in divisions {
            for enemy in enemyDivisions {
                if division.coord.distance(to: enemy.coord) <= division.range {
                    attackBonuses.append(
                        influence.combatSummary(attacker: division, defender: enemy, in: gameState).attackBonus
                    )
                }
                if enemy.coord.distance(to: division.coord) <= enemy.range {
                    defenseBonuses.append(
                        influence.combatSummary(attacker: enemy, defender: division, in: gameState).defenseBonus
                    )
                }
            }
        }

        let combatNote: String
        if attackBonuses.isEmpty && defenseBonuses.isEmpty {
            let enemyText = nearestEnemyText.map { "，\($0)" } ?? ""
            combatNote = "交战：当前未接敌\(enemyText)，进入射程后计算武将攻防"
        } else {
            let enemyText = nearestEnemyText.map { "；\($0)" } ?? ""
            combatNote = "交战：当前接敌攻击 \(bonusRange(attackBonuses))，防御 \(bonusRange(defenseBonuses))\(enemyText)"
        }

        return [roadNote, roadBenefitNote, combatNote, engagementPairingNote].compactMap { $0 }
    }

    private func generalRoadNoBonusReasonText(
        for divisions: [Division],
        assignment: GeneralAssignment
    ) -> String? {
        let commandQuality = (assignment.loyalty + assignment.satisfaction) / 2
        if commandQuality < 45 {
            return "道路受益：忠诚/满意不足，官道机动暂未触发"
        }

        let roadReadyCount = divisions.filter {
            generalRoadNetworkAvailable(for: $0, assignment: assignment)
        }.count
        guard roadReadyCount == 0 else {
            return nil
        }

        if hasGeneralRoadNetworkSkill(assignment) {
            return "道路受益：所在郡县暂无可借官道"
        }
        return "道路受益：需进驻官道，或凭粮道/疾行/骑战技能借郡县官道"
    }

    private func generalRoadNetworkAvailable(
        for division: Division,
        assignment: GeneralAssignment
    ) -> Bool {
        if gameState.map.tile(at: division.coord)?.hasRoad == true {
            return true
        }
        guard hasGeneralRoadNetworkSkill(assignment),
              let regionId = gameState.map.region(for: division.coord),
              let region = gameState.map.region(id: regionId) else {
            return false
        }
        return region.displayHexes.contains {
            gameState.map.tile(at: $0)?.hasRoad == true
        }
    }

    private func hasGeneralRoadNetworkSkill(_ assignment: GeneralAssignment) -> Bool {
        !Set(["logistics", "rapid_exploitation", "armor_expert", "cavalry_charge"])
            .isDisjoint(with: assignment.skills)
    }

    private enum EngagementPairingPerspective {
        case attack
        case defense

        var sortRank: Int {
            switch self {
            case .attack:
                return 0
            case .defense:
                return 1
            }
        }

        func modifierText(for bonus: Int) -> String {
            switch self {
            case .attack:
                return "攻\(bonus > 0 ? "+\(bonus)" : "\(bonus)")"
            case .defense:
                return "防\(bonus > 0 ? "+\(bonus)" : "\(bonus)")"
            }
        }
    }

    private struct EngagementPairingCandidate {
        let attacker: Division
        let defender: Division
        let distance: Int
        let bonus: Int
        let perspective: EngagementPairingPerspective
    }

    private func engagementPairingText(
        for divisions: [Division],
        enemyDivisions: [Division],
        influence: GeneralInfluence
    ) -> String? {
        var candidates: [EngagementPairingCandidate] = []
        let activeDivisions = divisions.filter { !$0.isDestroyed }

        for division in activeDivisions {
            for enemy in enemyDivisions {
                let distance = division.coord.distance(to: enemy.coord)
                if distance <= division.range {
                    let summary = influence.combatSummary(attacker: division, defender: enemy, in: gameState)
                    candidates.append(
                        EngagementPairingCandidate(
                            attacker: division,
                            defender: enemy,
                            distance: distance,
                            bonus: summary.attackBonus,
                            perspective: .attack
                        )
                    )
                }
                if distance <= enemy.range {
                    let summary = influence.combatSummary(attacker: enemy, defender: division, in: gameState)
                    candidates.append(
                        EngagementPairingCandidate(
                            attacker: enemy,
                            defender: division,
                            distance: distance,
                            bonus: summary.defenseBonus,
                            perspective: .defense
                        )
                    )
                }
            }
        }

        let selected = candidates.sorted { lhs, rhs in
            let lhsHasBonus = lhs.bonus != 0
            let rhsHasBonus = rhs.bonus != 0
            if lhsHasBonus != rhsHasBonus {
                return lhsHasBonus && !rhsHasBonus
            }

            let lhsMagnitude = abs(lhs.bonus)
            let rhsMagnitude = abs(rhs.bonus)
            if lhsMagnitude != rhsMagnitude {
                return lhsMagnitude > rhsMagnitude
            }
            if lhs.distance != rhs.distance {
                return lhs.distance < rhs.distance
            }
            if lhs.perspective.sortRank != rhs.perspective.sortRank {
                return lhs.perspective.sortRank < rhs.perspective.sortRank
            }
            if lhs.attacker.thematicDisplayName != rhs.attacker.thematicDisplayName {
                return lhs.attacker.thematicDisplayName < rhs.attacker.thematicDisplayName
            }
            if lhs.defender.thematicDisplayName != rhs.defender.thematicDisplayName {
                return lhs.defender.thematicDisplayName < rhs.defender.thematicDisplayName
            }
            if lhs.attacker.id != rhs.attacker.id {
                return lhs.attacker.id < rhs.attacker.id
            }
            return lhs.defender.id < rhs.defender.id
        }.first

        guard let selected else {
            return nil
        }

        return "接敌配对：\(selected.attacker.thematicDisplayName) -> \(selected.defender.thematicDisplayName)，\(selected.perspective.modifierText(for: selected.bonus))，距 \(selected.distance) 格"
    }

    private func nearestEnemyText(for divisions: [Division], enemyDivisions: [Division]) -> String? {
        let nearest = divisions
            .flatMap { division in
                enemyDivisions.map { enemy in
                    (
                        division: division,
                        enemy: enemy,
                        distance: division.coord.distance(to: enemy.coord)
                    )
                }
            }
            .min {
                if $0.distance != $1.distance {
                    return $0.distance < $1.distance
                }
                if $0.enemy.thematicDisplayName != $1.enemy.thematicDisplayName {
                    return $0.enemy.thematicDisplayName < $1.enemy.thematicDisplayName
                }
                return $0.division.thematicDisplayName < $1.division.thematicDisplayName
            }

        guard let nearest else {
            return nil
        }
        return "近敌 \(nearest.enemy.thematicDisplayName) 距 \(nearest.distance) 格（\(nearest.division.thematicDisplayName)）"
    }

    private func generalAssignedDivisionRow(
        for division: Division,
        movementRules: MovementRules,
        visibleHostiles: [Division]
    ) -> GeneralAssignedDivisionRow {
        let roadSummary = generalAssignedDivisionRoadSummary(
            for: division,
            movementRules: movementRules
        )
        let engagementSummary = generalAssignedDivisionEngagementSummary(
            for: division,
            visibleHostiles: visibleHostiles
        )
        let summary = "\(division.thematicDisplayName)：兵 \(division.strength)/\(division.maxStrength)，粮 \(division.supplyState.shortDisplayName)，令 \(division.retreatMode.shortDisplayCode)，\(generalAssignedDivisionActionSummary(for: division))；\(roadSummary)；\(engagementSummary)"
        return GeneralAssignedDivisionRow(
            id: division.id,
            iconName: generalAssignedDivisionIconName(for: division),
            summary: summary
        )
    }

    private func generalAssignedDivisionActionSummary(for division: Division) -> String {
        if division.isDestroyed {
            return "溃散"
        }
        if division.isRetreating {
            return "撤退"
        }
        if division.canAct {
            return "可动"
        }
        return "已动"
    }

    private func generalAssignedDivisionRoadSummary(
        for division: Division,
        movementRules: MovementRules
    ) -> String {
        guard gameState.map.tile(at: division.coord)?.hasRoad == true else {
            return "离官道"
        }
        if movementRules.isEnemyZoneOfControl(division.coord, for: division.faction, in: gameState) {
            return "官道受压"
        }
        return "据官道"
    }

    private func generalAssignedDivisionEngagementSummary(
        for division: Division,
        visibleHostiles: [Division]
    ) -> String {
        let distances = visibleHostiles.map {
            (
                enemy: $0,
                distance: division.coord.distance(to: $0.coord)
            )
        }
        guard !distances.isEmpty else {
            return "无可见敌军"
        }

        let attackable = distances
            .filter { $0.distance <= division.range }
            .sorted(by: generalAssignedDivisionDistanceSort)
            .first
        let threatened = distances
            .filter { $0.distance <= $0.enemy.range }
            .sorted(by: generalAssignedDivisionDistanceSort)
            .first

        if let attackable, let threatened {
            if attackable.enemy.id == threatened.enemy.id {
                return "接敌 \(attackable.enemy.thematicDisplayName) 距 \(attackable.distance)，互在射程"
            }
            return "可战 \(attackable.enemy.thematicDisplayName) 距 \(attackable.distance)，受敌射 \(threatened.enemy.thematicDisplayName) 距 \(threatened.distance)"
        }
        if let attackable {
            return "可战 \(attackable.enemy.thematicDisplayName) 距 \(attackable.distance)"
        }
        if let threatened {
            return "受敌射 \(threatened.enemy.thematicDisplayName) 距 \(threatened.distance)"
        }

        guard let nearest = distances.sorted(by: generalAssignedDivisionDistanceSort).first else {
            return "无可见敌军"
        }
        return "近敌 \(nearest.enemy.thematicDisplayName) 距 \(nearest.distance)"
    }

    private func generalAssignedDivisionDistanceSort(
        _ lhs: (enemy: Division, distance: Int),
        _ rhs: (enemy: Division, distance: Int)
    ) -> Bool {
        if lhs.distance != rhs.distance {
            return lhs.distance < rhs.distance
        }
        if lhs.enemy.thematicDisplayName != rhs.enemy.thematicDisplayName {
            return lhs.enemy.thematicDisplayName < rhs.enemy.thematicDisplayName
        }
        return lhs.enemy.id < rhs.enemy.id
    }

    private func generalAssignedDivisionIconName(for division: Division) -> String {
        if division.isArmor {
            return "shield.lefthalf.filled"
        }
        if division.isArtillery {
            return "scope"
        }
        return "person.3.fill"
    }

    private func generalTargetRoadPreviewNote(
        sourceHex: HexCoord?,
        targetHex: HexCoord?,
        faction: Faction
    ) -> String? {
        guard sourceHex != nil || targetHex != nil else {
            return nil
        }

        let sourceText = sourceHex.map {
            "源\(generalTargetRoadStateText(for: $0, faction: faction))"
        }
        let targetText = targetHex.map {
            "目\(generalTargetRoadStateText(for: $0, faction: faction))"
        }
        return "目标官道：\([sourceText, targetText].compactMap { $0 }.joined(separator: "，"))"
    }

    private func generalTargetRoadStateText(for coord: HexCoord, faction: Faction) -> String {
        let roadText = gameState.map.tile(at: coord)?.hasRoad == true ? "据道" : "离道"
        let pressureText = generalTargetHexIsVisiblyPressured(coord, faction: faction) ? "/受压" : ""
        return "\(roadText)\(pressureText)"
    }

    private func generalTargetHexIsVisiblyPressured(_ coord: HexCoord, faction: Faction) -> Bool {
        gameState.divisions.contains { division in
            division.faction.isHostile(to: faction) &&
                !division.isDestroyed &&
                mapDisplayAdapter.isDivisionVisible(division, viewerFaction: faction) &&
                division.coord.distance(to: coord) <= 1
        }
    }

    private func generalTargetVisibleEnemyPreviewNote(
        sourceHex: HexCoord?,
        targetHex: HexCoord?,
        faction: Faction
    ) -> String? {
        let sourceEnemy = sourceHex.flatMap {
            nearestVisibleHostileSummary(from: $0, faction: faction)
        }
        let targetEnemy = targetHex.flatMap {
            nearestVisibleHostileSummary(from: $0, faction: faction)
        }

        if let sourceEnemy, let targetEnemy {
            return "目标近敌：源\(sourceEnemy.name)距\(sourceEnemy.distance)格，目\(targetEnemy.name)距\(targetEnemy.distance)格"
        }
        if let targetEnemy {
            return "目标近敌：目\(targetEnemy.name)距\(targetEnemy.distance)格"
        }
        if let sourceEnemy {
            return "目标近敌：源\(sourceEnemy.name)距\(sourceEnemy.distance)格"
        }
        return nil
    }

    private func nearestVisibleHostileSummary(
        from coord: HexCoord,
        faction: Faction
    ) -> (name: String, distance: Int)? {
        let nearest = gameState.divisions
            .filter {
                $0.faction.isHostile(to: faction) &&
                    !$0.isDestroyed &&
                    mapDisplayAdapter.isDivisionVisible($0, viewerFaction: faction)
            }
            .map {
                (
                    name: $0.thematicDisplayName,
                    distance: $0.coord.distance(to: coord),
                    id: $0.id
                )
            }
            .min {
                if $0.distance != $1.distance {
                    return $0.distance < $1.distance
                }
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.id < $1.id
            }

        guard let nearest else {
            return nil
        }
        return (nearest.name, nearest.distance)
    }

    var selectedGeneralHQUnderAttack: Bool {
        guard let zone = selectedGeneralCommandZone else {
            return false
        }
        return GeneralDispatcher(registry: generalRegistry).isHQUnderAttack(
            zone: zone,
            map: gameState.map
        )
    }

    var selectedGeneralTargetRegion: RegionNode? {
        selectedRegionId.flatMap { gameState.map.region(id: $0) }
    }

    var selectedGeneralTargetZone: FrontZone? {
        guard let selectedRegionId else {
            return nil
        }
        return gameState.warDeploymentState.zone(for: selectedRegionId)
    }

    var selectedGeneralPlannedOperations: [PlayerPlannedOperation] {
        let zoneId = selectedGeneralCommandZone?.id
        return Array(gameState.playerCommandState.plannedOperations
            .filter { operation in
                operation.turn == gameState.turn &&
                    (zoneId == nil || operation.zoneId == zoneId)
            }
            .suffix(5))
    }

    var selectedGeneralPlannedOperationRows: [(id: String, iconName: String, summary: String)] {
        selectedGeneralPlannedOperations.map { operation in
            (
                id: operation.id,
                iconName: plannedOperationIconName(for: operation),
                summary: plannedOperationSummaryText(for: operation)
            )
        }
    }

    var canOrderSelectedGeneralHoldLine: Bool {
        selectedGeneralHoldLineUnavailableReason == nil
    }

    var canOrderSelectedGeneralAttackRegion: Bool {
        selectedGeneralAttackRegionUnavailableReason == nil
    }

    var selectedGeneralHoldLineUnavailableReason: String? {
        if let reason = playerDirectiveUnavailableReason {
            return reason
        }
        guard selectedGeneralCommandZone != nil else {
            return "请选择己方防区、己方军队，或相邻敌方郡县以确定固守防区。"
        }
        return nil
    }

    var selectedGeneralAttackRegionUnavailableReason: String? {
        if let reason = playerDirectiveUnavailableReason {
            return reason
        }
        guard let selectedRegionId else {
            return "请选择敌方前线郡县作为进攻目标。"
        }
        guard let targetZone = gameState.warDeploymentState.zone(for: selectedRegionId) else {
            return "选中郡县未映射防区，暂不能生成进攻军令。"
        }
        guard targetZone.faction.isHostile(to: playerFaction) else {
            return targetZone.faction == playerFaction
                ? "目标是己方防区；请选择敌方前线郡县。"
                : "目标防区当前非敌对；请选择交战中的敌方郡县。"
        }
        guard selectedGeneralCommandZone != nil else {
            return "目标附近没有可用己方相邻防区；请先选择己方防区或己方军队。"
        }
        return nil
    }

    var displayEventLog: [GameLogEntry] {
        Array((gameState.eventLog + interactionLog).suffix(80))
    }

    var selectedUnitCanAct: Bool {
        selectedActionDivision != nil
    }

    private var selectedActionDivision: Division? {
        guard !observerModeEnabled else {
            return nil
        }
        guard let division = selectedDivision,
              division.faction == playerFaction,
              gameState.activeFaction == playerFaction,
              gameState.phase == .alliedPlayer,
              !division.hasActed else {
            return nil
        }

        return division
    }

    private var canIssuePlayerDirective: Bool {
        !observerModeEnabled &&
            gameState.activeFaction == playerFaction &&
            gameState.phase == .alliedPlayer
    }

    private var playerDirectiveUnavailableReason: String? {
        if observerModeEnabled {
            return "观察模式不能下达武将军令。"
        }
        guard gameState.activeFaction == playerFaction else {
            return "当前行动势力为 \(gameState.activeFaction.displayName)，未到玩家武将军令阶段。"
        }
        guard gameState.phase == .alliedPlayer else {
            return "\(gameState.phase.displayName) 阶段不能下达武将军令。"
        }
        return nil
    }

    private var selectedAttackTarget: (region: RegionNode, zone: FrontZone)? {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId),
              let targetZone = gameState.warDeploymentState.zone(for: selectedRegionId),
              targetZone.faction.isHostile(to: playerFaction) else {
            return nil
        }
        return (region, targetZone)
    }

    private var mapDisplayAdapter: MapDisplayAdapter {
        MapDisplayAdapter(state: gameState, revealAll: observerModeEnabled)
    }

    private func refreshedRuntimeState(_ state: GameState) -> GameState {
        refreshGeneralAssignments(
            in: StrategicStateBootstrapper().refreshRuntimeState(state)
        )
    }

    private func refreshGeneralAssignments(in state: GameState) -> GameState {
        Self.refreshGeneralAssignments(in: state, registry: generalRegistry)
    }

    private static func refreshGeneralAssignments(
        in state: GameState,
        registry: GeneralRegistry
    ) -> GameState {
        guard !registry.allGenerals.isEmpty else {
            return state
        }
        var next = state
        next.warDeploymentState = GeneralDispatcher(registry: registry).assignGenerals(
            to: state.warDeploymentState,
            map: state.map
        )
        return next
    }

    private func applyPlayerCommandBookkeeping(
        _ command: Command,
        to state: GameState,
        previousState: GameState
    ) -> GameState {
        var next = state
        if command == .endTurn || next.activeFaction != previousState.activeFaction || next.turn != previousState.turn {
            next.playerCommandState.clearTurnLocks()
            return next
        }

        guard let divisionId = command.actingDivisionId,
              previousState.activeFaction == playerFaction,
              previousState.phase == .alliedPlayer,
              previousState.division(id: divisionId)?.faction == playerFaction else {
            return next
        }

        next.playerCommandState.lockDivision(divisionId)
        return registerPlayerIntervention(for: divisionId, in: next)
    }

    private func registerPlayerIntervention(for divisionId: String, in state: GameState) -> GameState {
        guard let zoneId = logicalZoneId(for: divisionId, in: state.warDeploymentState),
              var zone = state.warDeploymentState.frontZones[zoneId],
              let assignment = zone.generalAssignment else {
            return state
        }

        var next = state
        zone.generalAssignment = assignment.registeringPlayerIntervention(cost: 2)
        next.warDeploymentState.frontZones[zoneId] = zone
        return next
    }

    private func inferredPlayerCommandZone() -> FrontZone? {
        if let division = selectedDivision,
           division.faction == playerFaction,
           let zoneId = gameState.warDeploymentState.zoneId(for: division.coord, map: gameState.map),
           let zone = gameState.warDeploymentState.frontZones[zoneId],
           zone.faction == playerFaction {
            return zone
        }

        if let selectedRegionId,
           let zone = gameState.warDeploymentState.zone(for: selectedRegionId),
           zone.faction == playerFaction {
            return zone
        }

        guard let targetZone = selectedGeneralTargetZone,
              targetZone.faction.isHostile(to: playerFaction) else {
            return nil
        }

        return playerZonesAdjacent(to: targetZone.id).first
    }

    private func playerZonesAdjacent(to targetZoneId: FrontZoneId) -> [FrontZone] {
        gameState.warDeploymentState.frontZones.values
            .filter { zone in
                zone.faction == playerFaction &&
                    zone.frontSegments.contains { $0.neighborEnemyZone == targetZoneId }
            }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func sourceRegionId(for zone: FrontZone, targetZoneId: FrontZoneId?) -> RegionId? {
        if let selectedDivision,
           selectedDivision.faction == zone.faction,
           let regionId = selectedDivision.location(in: gameState.map),
           zone.regionIds.contains(regionId) {
            return regionId
        }

        if let selectedRegionId,
           zone.regionIds.contains(selectedRegionId) {
            return selectedRegionId
        }

        if let targetZoneId,
           let segment = zone.frontSegments
            .filter({ $0.neighborEnemyZone == targetZoneId })
            .sorted(by: { $0.regionId.rawValue < $1.regionId.rawValue })
            .first {
            return segment.regionId
        }

        return zone.generalAssignment?.hqRegionId ?? zone.regionIds.first
    }

    private func logicalZoneId(for divisionId: String, in deploymentState: WarDeploymentState) -> FrontZoneId? {
        deploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first {
                $0.unitsFront.contains(divisionId)
                    || $0.unitsDepth.contains(divisionId)
                    || $0.unitsGarrison.contains(divisionId)
            }?
            .id
    }

    private func bonusRange(_ values: [Int]) -> String {
        guard let minValue = values.min(),
              let maxValue = values.max() else {
            return "无接战"
        }
        if minValue == maxValue {
            return signedBonus(minValue)
        }
        return "\(signedBonus(minValue))~\(signedBonus(maxValue))"
    }

    private func signedBonus(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func plannedOperationIconName(for operation: PlayerPlannedOperation) -> String {
        operation.directiveType == .attack ? "arrow.up.right.circle" : "shield.fill"
    }

    private func plannedOperationSummaryText(for operation: PlayerPlannedOperation) -> String {
        let generalPrefix = plannedOperationGeneralName(for: operation).map { "\($0)：" } ?? ""
        let tactic = operation.tactic?.displayName ?? "未定战术"
        let route = plannedOperationRouteName(for: operation)
        let roadText = plannedOperationRoadPressureText(for: operation).map { "；\($0)" } ?? ""
        let enemyDistanceText = plannedOperationEnemyDistanceText(for: operation).map { "；\($0)" } ?? ""
        return "\(generalPrefix)\(operation.directiveType.displayName) / \(tactic) / \(route)\(roadText)\(enemyDistanceText)"
    }

    private func plannedOperationGeneralName(for operation: PlayerPlannedOperation) -> String? {
        let assignment = gameState.warDeploymentState.frontZones[operation.zoneId]?.generalAssignment
        if let displayName = assignment?.generalDisplayName,
           !displayName.isEmpty {
            return displayName
        }
        guard let generalId = operation.createdByGeneralId,
              !generalId.isEmpty else {
            return nil
        }
        return generalRegistry.general(id: generalId)?.localizedName ?? generalId
    }

    private func plannedOperationRouteName(for operation: PlayerPlannedOperation) -> String {
        let sourceName = plannedOperationRegionName(operation.sourceRegionId)
        let targetName = plannedOperationRegionName(operation.targetRegionId)

        if let sourceName, let targetName, sourceName != targetName {
            return "\(sourceName)→\(targetName)"
        }
        if let targetName {
            return targetName
        }
        if let sourceName {
            return sourceName
        }
        return gameState.warDeploymentState.frontZones[operation.zoneId]?.name ?? operation.zoneId.rawValue
    }

    private func plannedOperationRegionName(_ regionId: RegionId?) -> String? {
        guard let regionId else {
            return nil
        }
        return gameState.map.region(id: regionId)?.name ?? regionId.rawValue
    }

    private func plannedOperationEnemyDistanceText(for operation: PlayerPlannedOperation) -> String? {
        guard let sourceHex = plannedOperationHex(
            regionId: operation.sourceRegionId,
            zoneId: operation.zoneId
        ) else {
            return nil
        }
        let targetHex = operation.targetRegionId.flatMap {
            plannedOperationHex(regionId: $0, zoneId: operation.zoneId)
        }
        let sourceEnemy = plannedOperationNearestHostileSummary(from: sourceHex, faction: operation.faction)
        let targetEnemy = targetHex.flatMap {
            plannedOperationNearestHostileSummary(from: $0, faction: operation.faction)
        }

        if let targetEnemy, let sourceEnemy {
            return "近敌：源\(sourceEnemy.name)距\(sourceEnemy.distance)格/目\(targetEnemy.name)距\(targetEnemy.distance)格"
        }
        if let targetEnemy {
            return "近敌：目\(targetEnemy.name)距\(targetEnemy.distance)格"
        }
        if let sourceEnemy {
            return "近敌：\(sourceEnemy.name)距\(sourceEnemy.distance)格"
        }
        return nil
    }

    private func plannedOperationNearestHostileSummary(
        from coord: HexCoord,
        faction: Faction
    ) -> (name: String, distance: Int)? {
        let nearest = gameState.divisions
            .filter {
                $0.faction.isHostile(to: faction) &&
                    !$0.isDestroyed &&
                    mapDisplayAdapter.isDivisionVisible($0, viewerFaction: faction)
            }
            .map {
                (
                    name: $0.thematicDisplayName,
                    distance: $0.coord.distance(to: coord),
                    id: $0.id
                )
            }
            .min {
                if $0.distance != $1.distance {
                    return $0.distance < $1.distance
                }
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.id < $1.id
            }

        guard let nearest else {
            return nil
        }
        return (name: nearest.name, distance: nearest.distance)
    }

    private func plannedOperationRoadPressureText(for operation: PlayerPlannedOperation) -> String? {
        guard let sourceHex = plannedOperationHex(
            regionId: operation.sourceRegionId,
            zoneId: operation.zoneId
        ) else {
            return nil
        }
        let targetHex = operation.targetRegionId.flatMap {
            plannedOperationHex(regionId: $0, zoneId: operation.zoneId)
        }
        let sourceHasRoad = gameState.map.tile(at: sourceHex)?.hasRoad == true
        let targetHasRoad = targetHex.flatMap { gameState.map.tile(at: $0)?.hasRoad } ?? false
        let sourceIsPressured = plannedOperationHexIsPressured(sourceHex, faction: operation.faction)
        let targetIsPressured = targetHex.map {
            plannedOperationHexIsPressured($0, faction: operation.faction)
        } ?? false

        let roadLabel: String
        if targetHex == nil {
            roadLabel = sourceHasRoad ? "据道" : "离道"
        } else if sourceHasRoad && targetHasRoad {
            roadLabel = "双道"
        } else if sourceHasRoad {
            roadLabel = "源道"
        } else if targetHasRoad {
            roadLabel = "目道"
        } else {
            roadLabel = "无道"
        }

        var fragments = ["官道 \(roadLabel)"]
        let pressureText = plannedOperationPressureText(
            hasTarget: targetHex != nil,
            sourceIsPressured: sourceIsPressured,
            targetIsPressured: targetIsPressured
        )
        if let pressureText {
            fragments.append(pressureText)
        }
        return fragments.joined(separator: "，")
    }

    private func plannedOperationHex(regionId: RegionId?, zoneId: FrontZoneId) -> HexCoord? {
        if let regionId,
           let hex = gameState.map.representativeHex(for: regionId) {
            return hex
        }

        guard let zone = gameState.warDeploymentState.frontZones[zoneId] else {
            return nil
        }
        let hqRegionId = zone.generalAssignment?.hqRegionId ?? zone.regionIds.first
        guard let hqRegionId else {
            return nil
        }
        return gameState.map.representativeHex(for: hqRegionId)
    }

    private func plannedOperationHexIsPressured(_ coord: HexCoord, faction: Faction) -> Bool {
        gameState.divisions.contains { division in
            division.faction.isHostile(to: faction) &&
                !division.isDestroyed &&
                mapDisplayAdapter.isDivisionVisible(division, viewerFaction: faction) &&
                division.coord.distance(to: coord) <= 1
        }
    }

    private func plannedOperationPressureText(
        hasTarget: Bool,
        sourceIsPressured: Bool,
        targetIsPressured: Bool
    ) -> String? {
        if hasTarget {
            if sourceIsPressured && targetIsPressured {
                return "源目受压"
            }
            if sourceIsPressured {
                return "源受压"
            }
            if targetIsPressured {
                return "目受压"
            }
            return nil
        }
        return sourceIsPressured ? "据点受压" : nil
    }

    private func combatTargetPreviewLine(
        rank: Int,
        attacker: Division,
        target: Division,
        damage: CombatDamage,
        counterDamage: CombatDamage?,
        distance: Int,
        influence: GeneralCombatInfluenceSummary,
        audit: CombatAuditSummary
    ) -> String {
        let prefix = rank == 0 ? "首选" : "候选 \(rank + 1)"
        let targetOutcome = combatPreviewOutcome(for: target, damage: damage)
        let targetOutcomeText = combatStrengthOutcomeText(
            label: "敌余",
            outcome: targetOutcome
        )
        let counterOutcome = combatCounterPreviewText(
            counterDamage,
            attacker: attacker,
            targetOutcome: targetOutcome
        )
        let riskText = combatPreviewRiskText(for: targetOutcome)
            .map { "；风险：\($0)" } ?? ""
        let stanceText = combatTargetStanceText(for: target)
            .map { "；态势：\($0)" } ?? ""
        let defenderGeneralText = combatTargetDefenderGeneralText(influence)
            .map { "；\($0)" } ?? ""
        let generalModifierText = combatTargetGeneralModifierText(influence)
            .map { "；\($0)" } ?? ""
        let auditText = audit.logFragment
            .map { "；\($0)" } ?? ""
        return "\(prefix) \(target.thematicDisplayName)：伤害 \(damage.strengthDamage)，\(targetOutcomeText)\(riskText)；\(counterOutcome)\(stanceText)\(defenderGeneralText)\(generalModifierText)\(auditText)；距 \(distance) 格"
    }

    private func combatTargetPriorityText(
        target: Division,
        damage: CombatDamage,
        counterDamage: CombatDamage?,
        distance: Int,
        comparedTargetCount: Int
    ) -> String {
        let targetOutcome = combatPreviewOutcome(for: target, damage: damage)
        var reasons = [
            "\(comparedTargetCount) 敌中伤害 \(damage.strengthDamage)"
        ]

        if targetOutcome.wasDestroyed {
            reasons.append("可能歼灭")
        } else if targetOutcome.shouldRetreat {
            reasons.append("可能撤退")
            reasons.append("敌余 \(targetOutcome.remainingStrength)/\(targetOutcome.maxStrength)")
        } else {
            reasons.append("敌余 \(targetOutcome.remainingStrength)/\(targetOutcome.maxStrength)")
        }

        if targetOutcome.wasDestroyed || targetOutcome.shouldRetreat {
            reasons.append("预计无反击")
        } else if let counterDamage {
            reasons.append("反击 \(counterDamage.strengthDamage)")
        } else {
            reasons.append("无反击")
        }

        reasons.append("距 \(distance) 格")
        return "首选理由：\(target.thematicDisplayName)，\(reasons.joined(separator: "，"))"
    }

    private func combatOutOfRangePreviewNotes(
        attacker: Division,
        enemies: [(target: Division, distance: Int)],
        movementRules: MovementRules,
        combatRules: CombatRules
    ) -> [String] {
        guard let nearest = enemies.sorted(by: {
            if $0.distance != $1.distance {
                return $0.distance < $1.distance
            }
            if $0.target.name != $1.target.name {
                return $0.target.name < $1.target.name
            }
            return $0.target.id < $1.target.id
        }).first else {
            return []
        }

        let reachableCoords = movementRules.movementRange(for: attacker, in: gameState)
        let approachGap = max(0, nearest.distance - attacker.range)
        var notes = [
            "接战距离：最近 \(nearest.target.thematicDisplayName)，距 \(nearest.distance) 格，射程 \(attacker.range)，需接近 \(approachGap) 格"
        ]
        if let candidateText = combatOutOfRangeCandidateText(
            attacker: attacker,
            enemies: enemies,
            reachableCoords: reachableCoords,
            movementRules: movementRules,
            combatRules: combatRules
        ) {
            notes.append(candidateText)
        }
        let influence = combatRules.generalInfluenceSummary(attacker: attacker, defender: nearest.target, in: gameState)
        if let generalText = combatApproachGeneralText(influence) {
            notes.append(generalText)
        }
        if let modifierText = combatTargetGeneralModifierText(influence) {
            notes.append("接近参考：\(modifierText)")
        }
        if let stanceText = combatTargetStanceText(for: nearest.target) {
            notes.append("接近态势：\(stanceText)")
        }
        if let threatText = combatOutOfRangeThreatText(
            attacker: attacker,
            target: nearest.target,
            reachableCoords: reachableCoords
        ) {
            notes.append(threatText)
        }
        if let roadApproach = combatOutOfRangeRoadApproachText(
            attacker: attacker,
            target: nearest.target,
            reachableCoords: reachableCoords,
            movementRules: movementRules
        ) {
            notes.append(roadApproach)
        }
        return notes
    }

    private func combatRoadApproachText(
        attacker: Division,
        target: Division,
        movementRules: MovementRules
    ) -> String? {
        var candidateCoords = movementRules.movementRange(for: attacker, in: gameState)
        candidateCoords.insert(attacker.coord)

        let roadAttackCoords = candidateCoords.filter { coord in
            gameState.map.tile(at: coord)?.hasRoad == true &&
                coord.distance(to: target.coord) <= attacker.range
        }
        let attackerOnRoad = gameState.map.tile(at: attacker.coord)?.hasRoad == true
        let targetOnRoad = gameState.map.tile(at: target.coord)?.hasRoad == true

        var fragments: [String] = []
        if roadAttackCoords.isEmpty {
            fragments.append("无可用官道压制位")
        } else {
            let pressuredCount = roadAttackCoords.filter {
                movementRules.isEnemyZoneOfControl($0, for: attacker.faction, in: gameState)
            }.count
            let safeCount = roadAttackCoords.count - pressuredCount
            fragments.append("\(roadAttackCoords.count) 个官道压制位")
            if safeCount > 0 {
                fragments.append("安全 \(safeCount)")
            }
            if pressuredCount > 0 {
                fragments.append("受敌控区 \(pressuredCount)")
            }
        }

        if attackerOnRoad {
            fragments.append("我方在官道")
        }
        if targetOnRoad {
            fragments.append("目标临官道")
        }

        guard !fragments.isEmpty else {
            return nil
        }
        return "接战官道：\(fragments.joined(separator: "，"))"
    }

    private func combatOutOfRangeCandidateText(
        attacker: Division,
        enemies: [(target: Division, distance: Int)],
        reachableCoords: Set<HexCoord>,
        movementRules: MovementRules,
        combatRules: CombatRules
    ) -> String? {
        let candidates = enemies.sorted {
            if $0.distance != $1.distance {
                return $0.distance < $1.distance
            }
            if $0.target.name != $1.target.name {
                return $0.target.name < $1.target.name
            }
            return $0.target.id < $1.target.id
        }
        guard candidates.count > 1 else {
            return nil
        }

        let fragments = candidates.prefix(3).map { candidate in
            let approachGap = max(0, candidate.distance - attacker.range)
            let influence = combatRules.generalInfluenceSummary(attacker: attacker, defender: candidate.target, in: gameState)
            var details = [
                "距 \(candidate.distance)",
                "需 \(approachGap)",
                "敌射 \(candidate.target.range)"
            ]
            details.append(contentsOf: combatOutOfRangeCandidateApproachDetails(
                attacker: attacker,
                target: candidate.target,
                currentDistance: candidate.distance,
                reachableCoords: reachableCoords,
                movementRules: movementRules
            ))
            if let defenderName = influence.defenderGeneralName ?? influence.defenderGeneralId {
                details.append("敌将 \(defenderName)")
            }
            return "\(candidate.target.thematicDisplayName) \(details.joined(separator: "/"))"
        }
        return "接近候选：\(fragments.joined(separator: "；"))"
    }

    private func combatOutOfRangeCandidateApproachDetails(
        attacker: Division,
        target: Division,
        currentDistance: Int,
        reachableCoords: Set<HexCoord>,
        movementRules: MovementRules
    ) -> [String] {
        let reachableCloserCoords = reachableCoords.filter {
            $0.distance(to: target.coord) < currentDistance
        }
        guard !reachableCloserCoords.isEmpty else {
            return ["无可近位"]
        }

        var details: [String] = []
        let nearestReachableDistance = reachableCloserCoords
            .map { $0.distance(to: target.coord) }
            .min() ?? currentDistance
        details.append("可达距 \(nearestReachableDistance)")
        if nearestReachableDistance <= attacker.range {
            details.append("可入射程")
        }

        let roadCloserCoords = reachableCloserCoords.filter {
            gameState.map.tile(at: $0)?.hasRoad == true
        }
        if !roadCloserCoords.isEmpty {
            let safeRoadCount = roadCloserCoords.count {
                !movementRules.isEnemyZoneOfControl($0, for: attacker.faction, in: gameState)
            }
            if safeRoadCount > 0 {
                details.append("安全官道 \(safeRoadCount)")
            } else {
                details.append("官道受压 \(roadCloserCoords.count)")
            }
        }

        let threatenedApproachCount = reachableCloserCoords.count {
            $0.distance(to: target.coord) <= target.range
        }
        if threatenedApproachCount > 0 {
            details.append("入敌射 \(threatenedApproachCount)")
        }
        return details
    }

    private func combatOutOfRangeThreatText(
        attacker: Division,
        target: Division,
        reachableCoords: Set<HexCoord>
    ) -> String? {
        let currentDistance = attacker.coord.distance(to: target.coord)
        let enemyRange = target.range
        let reachableCloserCoords = reachableCoords.filter { $0.distance(to: target.coord) < currentDistance }
        let threatenedApproachCount = reachableCloserCoords.count {
            $0.distance(to: target.coord) <= enemyRange
        }

        var fragments = ["敌射程 \(enemyRange)"]
        if currentDistance <= enemyRange {
            fragments.append("当前已在敌方射程内")
        } else {
            fragments.append("当前距敌射程 \(currentDistance - enemyRange) 格")
        }

        if threatenedApproachCount > 0 {
            fragments.append("\(threatenedApproachCount) 个可达接近位会入敌射程")
        }

        guard fragments.count > 1 else {
            return nil
        }
        return "接近威胁：\(fragments.joined(separator: "，"))"
    }

    private func combatOutOfRangeRoadApproachText(
        attacker: Division,
        target: Division,
        reachableCoords: Set<HexCoord>,
        movementRules: MovementRules
    ) -> String? {
        let currentDistance = attacker.coord.distance(to: target.coord)
        let reachableRoadCoords = reachableCoords.filter { coord in
            gameState.map.tile(at: coord)?.hasRoad == true &&
                coord.distance(to: target.coord) < currentDistance
        }
        let attackerOnRoad = gameState.map.tile(at: attacker.coord)?.hasRoad == true
        let targetOnRoad = gameState.map.tile(at: target.coord)?.hasRoad == true

        var fragments: [String] = []
        if !reachableRoadCoords.isEmpty {
            let nearestRoadDistance = reachableRoadCoords
                .map { $0.distance(to: target.coord) }
                .min() ?? currentDistance
            let pressuredCount = reachableRoadCoords.filter {
                movementRules.isEnemyZoneOfControl($0, for: attacker.faction, in: gameState)
            }.count
            let safeCount = reachableRoadCoords.count - pressuredCount
            let inRangeRoadCoords = reachableRoadCoords.filter {
                $0.distance(to: target.coord) <= attacker.range
            }
            let remainingApproachGap = max(0, nearestRoadDistance - attacker.range)
            fragments.append("\(reachableRoadCoords.count) 个可达更近官道位")
            fragments.append("最近距 \(nearestRoadDistance)")
            if inRangeRoadCoords.isEmpty {
                fragments.append("仍差 \(remainingApproachGap) 格入射程")
            } else {
                fragments.append("\(inRangeRoadCoords.count) 个抵达后入射程")
            }
            if safeCount > 0 {
                fragments.append("安全 \(safeCount)")
            }
            if pressuredCount > 0 {
                fragments.append("受敌控区 \(pressuredCount)")
            }
        }

        if attackerOnRoad {
            fragments.append("我方在官道")
        }
        if targetOnRoad {
            fragments.append("目标临官道")
        }

        guard !fragments.isEmpty else {
            return nil
        }
        return "官道接近：\(fragments.joined(separator: "，"))"
    }

    private func combatGeneralMatchupText(_ influence: GeneralCombatInfluenceSummary) -> String? {
        let attackerName = influence.attackerGeneralName ?? influence.attackerGeneralId
        let defenderName = influence.defenderGeneralName ?? influence.defenderGeneralId

        guard attackerName != nil || defenderName != nil else {
            return nil
        }

        let attackerText = attackerName.map { "我方 \($0)" } ?? "我方未任命"
        let defenderText = defenderName.map { "敌方 \($0)" } ?? "敌方未任命"
        return "交战武将：\(attackerText)，\(defenderText)"
    }

    private func combatApproachGeneralText(_ influence: GeneralCombatInfluenceSummary) -> String? {
        let attackerName = influence.attackerGeneralName ?? influence.attackerGeneralId
        let defenderName = influence.defenderGeneralName ?? influence.defenderGeneralId

        guard attackerName != nil || defenderName != nil else {
            return nil
        }

        let attackerText = attackerName.map { "我方 \($0)" } ?? "我方未任命"
        let defenderText = defenderName.map { "敌方 \($0)" } ?? "敌方未任命"
        return "接近武将：\(attackerText)，\(defenderText)"
    }

    private func combatTargetDefenderGeneralText(_ influence: GeneralCombatInfluenceSummary) -> String? {
        guard let defenderName = influence.defenderGeneralName ?? influence.defenderGeneralId else {
            return nil
        }
        return "敌将 \(defenderName)"
    }

    private func combatTargetGeneralModifierText(_ influence: GeneralCombatInfluenceSummary) -> String? {
        var fragments: [String] = []
        if influence.attackBonus != 0 {
            fragments.append("攻\(signedBonus(influence.attackBonus))")
        }
        if influence.defenseBonus != 0 {
            fragments.append("防\(signedBonus(influence.defenseBonus))")
        }
        guard !fragments.isEmpty else {
            return nil
        }
        return "武将修正 \(fragments.joined(separator: " "))"
    }

    private func combatCounterPreviewText(
        _ counterDamage: CombatDamage?,
        attacker: Division,
        targetOutcome: CombatPreviewOutcome
    ) -> String {
        if targetOutcome.wasDestroyed {
            return "预计无反击（目标可能歼灭）"
        }
        if targetOutcome.shouldRetreat {
            return "预计无反击（目标可能撤退）"
        }
        guard let counterDamage else {
            return "无反击"
        }
        let attackerOutcome = combatPreviewOutcome(for: attacker, damage: counterDamage)
        var text = "反击 \(counterDamage.strengthDamage)，"
        text += combatStrengthOutcomeText(
            label: "我余",
            outcome: attackerOutcome
        )
        if let riskText = combatPreviewRiskText(for: attackerOutcome, sideName: "我方") {
            text += "（\(riskText)）"
        }
        return text
    }

    private func combatStrengthOutcomeText(
        label: String,
        outcome: CombatPreviewOutcome
    ) -> String {
        "\(label) \(outcome.remainingStrength)/\(outcome.maxStrength)"
    }

    private func combatPreviewOutcome(for division: Division, damage: CombatDamage) -> CombatPreviewOutcome {
        var remainingStrength = max(0, division.strength - damage.strengthDamage)
        var shouldRetreat = false
        var holdExtraStrengthDamage = 0
        var encircledRetreatExtraStrengthDamage = 0

        if remainingStrength > 0 {
            shouldRetreat = division.retreatMode == .retreatable &&
                damage.lossRatio >= combatPreviewRetreatLossThreshold

            if division.retreatMode == .hold {
                holdExtraStrengthDamage = max(1, Int((Double(damage.strengthDamage) * 0.2).rounded()))
                remainingStrength = max(0, remainingStrength - holdExtraStrengthDamage)
            }

            if shouldRetreat && division.supplyState == .encircled && remainingStrength > 0 {
                encircledRetreatExtraStrengthDamage = max(1, damage.strengthDamage / 2)
                remainingStrength = max(0, remainingStrength - encircledRetreatExtraStrengthDamage)
            }
        }

        return CombatPreviewOutcome(
            remainingStrength: remainingStrength,
            maxStrength: division.maxStrength,
            shouldRetreat: shouldRetreat,
            wasDestroyed: remainingStrength <= 0,
            holdExtraStrengthDamage: holdExtraStrengthDamage,
            encircledRetreatExtraStrengthDamage: encircledRetreatExtraStrengthDamage
        )
    }

    private func combatPreviewRiskText(
        for outcome: CombatPreviewOutcome,
        sideName: String? = nil
    ) -> String? {
        var fragments: [String] = []
        if outcome.holdExtraStrengthDamage > 0 {
            fragments.append("死守额外损失约 \(outcome.holdExtraStrengthDamage)")
        }
        if outcome.encircledRetreatExtraStrengthDamage > 0 {
            fragments.append("断粮撤退额外损失约 \(outcome.encircledRetreatExtraStrengthDamage)")
        }
        if outcome.wasDestroyed {
            fragments.append(sideName.map { "\($0)可能被歼" } ?? "可能歼灭")
        } else if outcome.shouldRetreat {
            fragments.append(sideName.map { "\($0)可能撤退" } ?? "可能撤退")
        }

        guard !fragments.isEmpty else {
            return nil
        }
        return fragments.joined(separator: "，")
    }

    private func combatTargetStanceText(for target: Division) -> String? {
        var fragments: [String] = []
        if let tile = gameState.map.tile(at: target.coord) {
            fragments.append(tile.baseTerrain.displayName)
            if tile.cityName != nil {
                fragments.append("据城")
            } else if tile.fortressName != nil {
                fragments.append("据关")
            }
            if tile.hasRoad {
                fragments.append("临官道")
            }
        }

        fragments.append(target.supplyState.shortDisplayName)
        fragments.append(target.retreatMode.shortDisplayCode)

        guard !fragments.isEmpty else {
            return nil
        }
        return fragments.joined(separator: "，")
    }

    private func currentRegionRoadCount(for division: Division) -> Int? {
        guard let regionId = gameState.map.region(for: division.coord),
              let region = gameState.map.region(id: regionId) else {
            return nil
        }
        return region.displayHexes.count {
            gameState.map.tile(at: $0)?.hasRoad == true
        }
    }

    private func currentRoadStatusNote(for division: Division, movementRules: MovementRules) -> String? {
        guard gameState.map.tile(at: division.coord)?.hasRoad == true else {
            return nil
        }

        if movementRules.isEnemyZoneOfControl(division.coord, for: division.faction, in: gameState) {
            return "当前位置：已在官道，受敌控区压迫"
        }
        return "当前位置：已在官道，未受敌控区压迫"
    }

    private func reachableRoadAccessNote(
        for division: Division,
        reachableCoords: Set<HexCoord>,
        movementRules: MovementRules
    ) -> String? {
        let reachableRoadCoords = reachableCoords.filter {
            gameState.map.tile(at: $0)?.hasRoad == true
        }
        guard !reachableRoadCoords.isEmpty else {
            return gameState.map.tile(at: division.coord)?.hasRoad == true
                ? nil
                : "可达官道：本回合尚不能接入官道"
        }

        let contestedRoadCount = reachableRoadCoords.count {
            movementRules.isEnemyZoneOfControl($0, for: division.faction, in: gameState)
        }
        let safeRoadCount = reachableRoadCoords.count - contestedRoadCount
        let nearestRoadDistance = reachableRoadCoords.map {
            division.coord.distance(to: $0)
        }.min() ?? 0
        let safeRoadCoords = reachableRoadCoords.filter {
            !movementRules.isEnemyZoneOfControl($0, for: division.faction, in: gameState)
        }
        let nearestSafeRoadDistance = safeRoadCoords.map {
            division.coord.distance(to: $0)
        }.min()
        let safeDistanceText = nearestSafeRoadDistance.map { "，最近安全 \($0) 格" } ?? ""

        if contestedRoadCount > 0 {
            return "可达官道：本回合可入 \(reachableRoadCoords.count) 格，最近可达 \(nearestRoadDistance) 格，安全 \(safeRoadCount) 格\(safeDistanceText)，敌控压迫 \(contestedRoadCount) 格"
        }
        return "可达官道：本回合可入 \(reachableRoadCoords.count) 格，最近可达 \(nearestRoadDistance) 格\(safeDistanceText)，均未受敌控区压迫"
    }

    private func submitPlayerDirective(
        _ directive: ZoneDirective,
        sourceRegionId: RegionId?,
        targetRegionId: RegionId?
    ) {
        guard canIssuePlayerDirective else {
            appendInteractionEvent("General order rejected: not in the player command phase.")
            return
        }
        guard gameState.warDeploymentState.frontZones[directive.zoneId]?.faction == playerFaction else {
            appendInteractionEvent("General order rejected: source zone is not controlled by the player.")
            return
        }

        let startState = refreshedRuntimeState(gameState)
        guard let refreshedZone = startState.warDeploymentState.frontZones[directive.zoneId],
              refreshedZone.faction == playerFaction else {
            appendInteractionEvent("General order rejected: source zone changed during refresh.")
            return
        }
        let generalAdjustment = GeneralAgent(registry: generalRegistry).plan(
            envelope: DirectiveEnvelope(
                schemaVersion: 2,
                issuerId: "player",
                turn: startState.turn,
                directives: [directive],
                commanderAgentId: refreshedZone.generalAssignment?.generalId
            ),
            in: startState
        )
        let shapedDirective = generalAdjustment.envelope.directives.first ?? directive
        let lockedIds = startState.playerCommandState.micromanagedDivisionIds
        let execution = WarCommandExecutor(commandHandler: commandHandler).execute(
            shapedDirective,
            in: startState,
            excluding: lockedIds
        )

        var nextState = refreshGeneralAssignments(in: execution.finalState)
        nextState.appendGeneralRecords(generalAdjustment.records)
        let commandSummaries = execution.commandResults.enumerated().map { index, result in
            CommandResultSummary.directiveCommand(
                directiveIndex: 0,
                commandIndex: index,
                directive: shapedDirective,
                command: execution.generatedCommands[index],
                result: result
            )
        }
        var diagnostics: [String] = []
        if execution.generatedCommands.isEmpty {
            diagnostics.append("Player directive generated no executable commands.")
        }
        let rejected = commandSummaries.filter { !$0.executed }
        if !rejected.isEmpty {
            diagnostics.append("\(rejected.count) command(s) were rejected by rules.")
        }
        if !lockedIds.isEmpty {
            diagnostics.append("\(lockedIds.count) micromanaged division(s) excluded.")
        }

        let record = WarDirectiveRecord(
            id: "player_directive_turn_\(startState.turn)_\(shapedDirective.zoneId.rawValue)_\(shapedDirective.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
            issuerId: "player",
            turn: startState.turn,
            faction: playerFaction,
            zoneId: shapedDirective.zoneId,
            directiveType: shapedDirective.type,
            targetRegionIds: targetRegionId.map { [$0] } ?? shapedDirective.targetRegionIds,
            commandResults: commandSummaries,
            diagnostics: diagnostics,
            category: shapedDirective.category,
            tactic: shapedDirective.tactic,
            commanderAgentId: refreshedZone.generalAssignment?.generalId,
            commandTarget: shapedDirective.commandTarget
        )

        nextState.warDirectiveRecords.append(record)
        nextState.playerCommandState.recordOperation(
            PlayerPlannedOperation(
                id: "player_operation_turn_\(startState.turn)_\(shapedDirective.zoneId.rawValue)_\(shapedDirective.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
                turn: startState.turn,
                zoneId: shapedDirective.zoneId,
                faction: playerFaction,
                directiveType: shapedDirective.type,
                tactic: shapedDirective.tactic,
                sourceRegionId: sourceRegionId,
                targetRegionId: targetRegionId,
                createdByGeneralId: refreshedZone.generalAssignment?.generalId
            )
        )

        gameState = nextState
        lastWarDirectiveRecords = Array((lastWarDirectiveRecords + [record]).suffix(12))
        lastCommandMessage = playerDirectiveMessage(for: execution, diagnostics: diagnostics)
        appendInteractionEvent("General order submitted: \(shapedDirective.type.rawValue) \(shapedDirective.zoneId.rawValue).")
        refreshSelectionAfterStateChange()
    }

    private func playerDirectiveMessage(
        for execution: WarCommandExecutionResult,
        diagnostics: [String]
    ) -> String {
        let acceptedCount = execution.commandResults.filter(\.succeeded).count
        let totalCount = execution.generatedCommands.count
        if totalCount == 0 {
            return diagnostics.first ?? "General order produced no commands."
        }
        if acceptedCount == totalCount {
            return "General order executed \(acceptedCount) command(s)."
        }
        return "General order executed \(acceptedCount)/\(totalCount) command(s)."
    }

    private func shouldRunAI(for faction: Faction, phase: GamePhase) -> Bool {
        switch faction {
        case .germany:
            return phase == .germanAI
        case .allies:
            return observerModeEnabled && phase == .alliedPlayer
        case .cao, .yuan, .liuBei, .sun, .liuBiao, .maTeng, .han, .neutral:
            return false
        }
    }

    private func runAISequence(
        from state: GameState,
        pipelineMode: WarPipelineMode,
        observerEnabled: Bool
    ) async -> AgentTurnOutcome {
        var currentState = refreshedRuntimeState(state)
        var lastOutcome: AgentTurnOutcome?
        let maxSteps = observerEnabled ? 2 : 1

        for _ in 0..<maxSteps {
            currentState = refreshedRuntimeState(currentState)
            guard shouldRunAIInSnapshot(state: currentState, observerEnabled: observerEnabled) else {
                break
            }

            let manager = turnManager(for: currentState.activeFaction, state: currentState)
            let outcome = await manager.runAITurn(
                state: currentState,
                faction: currentState.activeFaction,
                pipelineMode: pipelineMode
            )
            currentState = refreshedRuntimeState(outcome.state)
            lastOutcome = AgentTurnOutcome(
                state: currentState,
                record: outcome.record,
                directiveRecords: (lastOutcome?.directiveRecords ?? []) + outcome.directiveRecords
            )
        }

        return lastOutcome ?? AgentTurnOutcome(
            state: currentState,
            record: AgentDecisionRecord(
                id: "agent_noop_turn_\(currentState.turn)",
                turn: currentState.turn,
                agentId: "system",
                provider: "System",
                contextSummary: "No AI faction was active.",
                rawJSON: nil,
                parsedIntent: nil,
                commandResults: [],
                errors: []
            )
        )
    }

    private func shouldRunAIInSnapshot(state: GameState, observerEnabled: Bool) -> Bool {
        switch state.activeFaction {
        case .germany:
            return state.phase == .germanAI
        case .allies:
            return observerEnabled && state.phase == .alliedPlayer
        case .cao, .yuan, .liuBei, .sun, .liuBiao, .maTeng, .han, .neutral:
            return false
        }
    }

    private func turnManager(for faction: Faction, state: GameState) -> TurnManager {
        if faction == .germany, let turnManager, generalRegistry.allGenerals.isEmpty {
            return turnManager
        }

        let agent: GameAgent
        switch faction {
        case .germany:
            agent = GameAgent.guderian(from: dataLoader, state: state)
        case .allies:
            let assignedIds = state.divisions
                .filter { $0.faction == .allies && !$0.isDestroyed }
                .map(\.id)
            agent = GameAgent.sample(
                id: "allied_mock_commander",
                name: "Allied Mock Commander",
                faction: .allies,
                role: .armyCommander,
                assignedDivisionIds: assignedIds
            )
        case .cao, .yuan, .liuBei, .sun, .liuBiao, .maTeng, .han, .neutral:
            let assignedIds = state.divisions
                .filter { $0.faction == faction && !$0.isDestroyed }
                .map(\.id)
            agent = GameAgent.sample(
                id: "\(faction.rawValue)_observer",
                name: "\(faction.displayName) Observer",
                faction: faction,
                role: .armyCommander,
                assignedDivisionIds: assignedIds
            )
        }

        return TurnManager(
            agent: agent,
            provider: MockAIClient(),
            providerName: "MockAI",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: state, registry: generalRegistry),
            marshalAgent: Self.buildMarshalAgent(faction: faction, state: state),
            diplomatAgent: DiplomatAgent.automatic(for: faction, in: state),
            governorAgent: GovernorAgent.automatic(for: faction, in: state),
            generalAgent: GeneralAgent(registry: generalRegistry)
        )
    }

    private static func buildCommanderPool(
        state: GameState,
        registry: GeneralRegistry = .empty
    ) -> TheaterCommanderPool {
        if !registry.allGenerals.isEmpty {
            return GeneralDispatcher(registry: registry).commanderPool(for: state)
        }

        let agents: [any ZoneCommanderProviding] = state.warDeploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { zone in
                let style: ZoneCommanderAgentConfig.CommandStyle = zone.faction == .germany ? .aggressive : .balanced
                let factionName = zone.faction == .germany ? "German" : "Allied"
                let config = ZoneCommanderAgentConfig(
                    id: "auto_\(zone.id.rawValue)",
                    name: "\(factionName) Commander (\(zone.id.rawValue))",
                    faction: zone.faction,
                    assignedZoneId: zone.id,
                    skills: [],
                    commandStyle: style
                )
                return ZoneCommanderAgent(config: config)
            }
        return TheaterCommanderPool(commanders: agents)
    }

    private static func buildMarshalAgent(faction: Faction, state: GameState) -> MarshalAgent {
        MarshalAgent(config: MarshalAgentConfig.automatic(for: faction, state: state))
    }

    private func handleDivisionTap(_ division: Division) {
        if observerModeEnabled {
            selectDivision(division)
            appendInteractionEvent("Inspecting unit: \(division.name).")
            return
        }

        if division.faction == playerFaction {
            selectDivision(division)
            appendInteractionEvent("Selected unit: \(division.name).")
            return
        }

        if let attacker = selectedActionDivision,
           division.faction.isHostile(to: attacker.faction) {
            submit(.attack(attackerId: attacker.id, targetId: division.id))
        } else {
            selectDivision(division)
            let relation = division.faction.isHostile(to: playerFaction) ? "敌军" : "非敌对军队"
            appendInteractionEvent("选择\(relation)：\(division.name)。")
        }
    }

    private func selectDivision(_ division: Division) {
        selectedUnitId = division.id
        selectedHex = mapDisplayAdapter.unitDisplayHex(for: division) ?? division.coord
        selectedRegionId = division.location(in: gameState.map)
        refreshHighlights()
    }

    private func refreshSelectionAfterStateChange() {
        if let selectedUnitId,
           gameState.division(id: selectedUnitId) == nil {
            self.selectedUnitId = nil
        }

        if let selectedDivision {
            selectedHex = mapDisplayAdapter.unitDisplayHex(for: selectedDivision) ?? selectedDivision.coord
            selectedRegionId = selectedDivision.location(in: gameState.map)
        }

        refreshHighlights()
    }

    private func refreshHighlights() {
        guard let division = selectedActionDivision else {
            clearHighlights()
            return
        }

        movementHighlights = MovementRules().movementRange(for: division, in: gameState)
        attackHighlights = Set(
            gameState.divisions
                .filter {
                    $0.faction.isHostile(to: division.faction) &&
                        division.coord.distance(to: $0.coord) <= division.range
                }
                .map(\.coord)
        )
    }

    private func clearHighlights() {
        movementHighlights = []
        attackHighlights = []
    }

    private func submitMove(division: Division, tappedHex: HexCoord) {
        submit(.move(divisionId: division.id, destination: tappedHex))
    }

    private func selectionMessage(for coord: HexCoord) -> String {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId) else {
            return "Selected hex \(coord.q),\(coord.r)."
        }
        return "Selected region: \(region.name) (\(selectedRegionId.rawValue))."
    }

    private func appendInteractionEvent(_ message: String) {
        interactionLog.append(
            GameLogEntry(
                turn: gameState.turn,
                faction: gameState.activeFaction,
                phase: gameState.phase,
                message: message,
                createdAt: Date()
            )
        )

        if interactionLog.count > 80 {
            interactionLog.removeFirst(interactionLog.count - 80)
        }
    }

}

private struct CombatPreviewOutcome {
    let remainingStrength: Int
    let maxStrength: Int
    let shouldRetreat: Bool
    let wasDestroyed: Bool
    let holdExtraStrengthDamage: Int
    let encircledRetreatExtraStrengthDamage: Int
}
