import Foundation

struct GovernorDomesticAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let record: GovernorDecisionRecord
}

struct GovernorAgentConfig: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let faction: Faction
    let administrationStyle: AdministrationStyle

    enum AdministrationStyle: String, Codable, Equatable, CaseIterable {
        case agrarian
        case militarized
        case logistics
        case balanced

        var displayName: String {
            switch self {
            case .agrarian:
                return "屯田"
            case .militarized:
                return "征发"
            case .logistics:
                return "转运"
            case .balanced:
                return "均衡"
            }
        }
    }
}

enum GovernorDomesticFocus: String, Codable, Equatable, CaseIterable {
    case conscription
    case roadRepair
    case tuntian
    case publicOrder
    case logistics

    var displayName: String {
        switch self {
        case .conscription:
            return "征兵"
        case .roadRepair:
            return "修路"
        case .tuntian:
            return "屯田"
        case .publicOrder:
            return "治安"
        case .logistics:
            return "补给"
        }
    }
}

struct GovernorAgent {
    let config: GovernorAgentConfig

    func plan(
        envelope: DirectiveEnvelope,
        in state: GameState,
        rulerRecord: RulerDecisionRecord?
    ) -> GovernorDomesticAdjustment {
        let ledger = state.economyState.ledger(for: config.faction)
        let controlledRegions = controlledRegions(in: state)
        let focus = domesticFocus(ledger: ledger, controlledRegions: controlledRegions, state: state)
        let focusRegionIds = focusRegions(for: focus, controlledRegions: controlledRegions, state: state)
        let recommendedProductionKind = productionRecommendation(
            focus: focus,
            ledger: ledger,
            state: state
        )
        let record = GovernorDecisionRecord(
            id: "governor_\(config.id)_turn_\(state.turn)_\(config.faction.rawValue)",
            turn: state.turn,
            faction: config.faction,
            governorAgentId: config.id,
            focus: focus,
            focusRegionIds: focusRegionIds,
            recommendedProductionKind: recommendedProductionKind,
            resourceSummary: resourceSummary(ledger: ledger),
            rationale: rationale(
                focus: focus,
                focusRegionIds: focusRegionIds,
                recommendedProductionKind: recommendedProductionKind,
                rulerRecord: rulerRecord,
                ledger: ledger,
                state: state
            )
        )
        let adjustedEnvelope = DirectiveEnvelope(
            schemaVersion: envelope.schemaVersion,
            issuerId: envelope.issuerId,
            turn: envelope.turn,
            directives: envelope.directives,
            commanderAgentId: envelope.commanderAgentId,
            theaterContext: appendGovernorContext(envelope.theaterContext, record: record)
        )
        return GovernorDomesticAdjustment(envelope: adjustedEnvelope, record: record)
    }

    private func domesticFocus(
        ledger: FactionEconomyLedger,
        controlledRegions: [RegionNode],
        state: GameState
    ) -> GovernorDomesticFocus {
        let upkeep = ledger.lastUpkeep.supplies
        let lowSupplyCount = state.divisions.filter {
            $0.faction == config.faction && $0.supplyState != .supplied && !$0.isDestroyed
        }.count
        let depletedCount = state.divisions.filter {
            $0.faction == config.faction &&
                !$0.isDestroyed &&
                $0.strength < $0.maxStrength
        }.count
        if lowSupplyCount > 0 || ledger.stockpile.supplies < max(60, upkeep * 2) {
            return .logistics
        }
        if config.administrationStyle == .militarized || ledger.stockpile.manpower < 140 || depletedCount >= 2 {
            return .conscription
        }
        if controlledRegions.contains(where: { needsRoadWork(region: $0, state: state) }) {
            return .roadRepair
        }
        if ledger.lastIncome.supplies < upkeep + 20 || config.administrationStyle == .agrarian {
            return .tuntian
        }
        return .publicOrder
    }

    private func focusRegions(
        for focus: GovernorDomesticFocus,
        controlledRegions: [RegionNode],
        state: GameState
    ) -> [RegionId] {
        controlledRegions
            .sorted { lhs, rhs in
                let lhsScore = regionScore(lhs, focus: focus, state: state)
                let rhsScore = regionScore(rhs, focus: focus, state: state)
                return lhsScore == rhsScore ? lhs.id.rawValue < rhs.id.rawValue : lhsScore > rhsScore
            }
            .prefix(3)
            .map(\.id)
    }

    private func regionScore(
        _ region: RegionNode,
        focus: GovernorDomesticFocus,
        state: GameState
    ) -> Int {
        let zonePressure = state.warDeploymentState.zone(for: region.id)?.pressure ?? 0
        let cityScore = region.city == nil ? 0 : 4
        switch focus {
        case .conscription:
            return cityScore + region.infrastructure + region.factories + zonePressure
        case .roadRepair:
            return (needsRoadWork(region: region, state: state) ? 10 : 0) + zonePressure + region.infrastructure
        case .tuntian:
            return region.supplyValue * 3 + region.infrastructure + cityScore
        case .publicOrder:
            return cityScore + region.infrastructure + zonePressure * 2
        case .logistics:
            return region.supplyValue * 2 + zonePressure * 3 + roadHexCount(in: region, state: state)
        }
    }

    private func productionRecommendation(
        focus: GovernorDomesticFocus,
        ledger: FactionEconomyLedger,
        state: GameState
    ) -> ProductionKind? {
        let preferred: [ProductionKind]
        switch focus {
        case .conscription:
            preferred = [.infantryDivision, .motorizedDivision]
        case .roadRepair,
             .tuntian,
             .publicOrder,
             .logistics:
            preferred = [.supplyStockpile, .infantryDivision]
        }

        return preferred.first { kind in
            ledger.stockpile.canAfford(kind.cost) &&
                state.economyState.ledger(for: config.faction).productionQueue.count < 4
        }
    }

    private func controlledRegions(in state: GameState) -> [RegionNode] {
        state.map.regions.values
            .filter { region in
                region.controller == config.faction &&
                    region.isPassable &&
                    region.displayHexes.contains { state.map.tile(at: $0)?.controller == config.faction }
            }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func needsRoadWork(region: RegionNode, state: GameState) -> Bool {
        region.infrastructure < 3 || roadHexCount(in: region, state: state) == 0
    }

    private func roadHexCount(in region: RegionNode, state: GameState) -> Int {
        region.displayHexes.filter { state.map.tile(at: $0)?.hasRoad == true }.count
    }

    private func resourceSummary(ledger: FactionEconomyLedger) -> String {
        let queueCount = ledger.productionQueue.count
        return "库存 人口\(ledger.stockpile.manpower) / 军械\(ledger.stockpile.industry) / 粮草\(ledger.stockpile.supplies)，队列 \(queueCount) 项。"
    }

    private func rationale(
        focus: GovernorDomesticFocus,
        focusRegionIds: [RegionId],
        recommendedProductionKind: ProductionKind?,
        rulerRecord: RulerDecisionRecord?,
        ledger: FactionEconomyLedger,
        state: GameState
    ) -> String {
        let postureText = rulerRecord.map { "承接君主\($0.posture.displayName)姿态" } ?? "无君主姿态输入"
        let regionText = focusRegionIds.map(\.rawValue).joined(separator: ", ")
        let productionText = recommendedProductionKind?.displayName ?? "暂不建议新增队列"
        let lowSupplyCount = state.divisions.filter {
            $0.faction == config.faction && $0.supplyState != .supplied && !$0.isDestroyed
        }.count
        return "\(postureText)，太守以\(config.administrationStyle.displayName)风格转向\(focus.displayName)；重点郡县 \(regionText.isEmpty ? "无" : regionText)；建议生产 \(productionText)。粮草库存 \(ledger.stockpile.supplies)，低补给军队 \(lowSupplyCount)。"
    }

    private func appendGovernorContext(_ context: String?, record: GovernorDecisionRecord) -> String? {
        let regions = record.focusRegionIds.map(\.rawValue).joined(separator: ", ")
        let governorContext = "太守层：\(record.focus.displayName) \(regions.isEmpty ? "无重点郡县" : regions)"
        guard let context, !context.isEmpty else {
            return governorContext
        }
        return "\(context) \(governorContext)"
    }
}

extension GovernorAgent {
    static func automatic(for faction: Faction, in state: GameState) -> GovernorAgent {
        let style: GovernorAgentConfig.AdministrationStyle
        switch faction {
        case .germany,
             .cao:
            style = .logistics
        case .allies,
             .yuan:
            style = .militarized
        case .liuBei,
             .liuBiao,
             .han,
             .neutral:
            style = .agrarian
        case .sun,
             .maTeng:
            style = .balanced
        }
        let country = state.diplomacyState.primaryCountry(for: faction)
        let id = country?.rulerAgentId.replacingOccurrences(of: "ruler_", with: "governor_") ?? "governor_\(faction.rawValue)"
        let name = country.map { "\($0.name)太守" } ?? "\(faction.displayName)太守"
        return GovernorAgent(
            config: GovernorAgentConfig(
                id: id,
                name: name,
                faction: faction,
                administrationStyle: style
            )
        )
    }
}
