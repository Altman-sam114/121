import Foundation

struct DiplomatDirectiveAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let record: DiplomatDecisionRecord
}

struct DiplomatAgentConfig: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let faction: Faction
    let diplomaticStyle: DiplomaticStyle

    enum DiplomaticStyle: String, Codable, Equatable, CaseIterable {
        case coalition
        case coercive
        case legitimacy
        case pragmatic

        var displayName: String {
            switch self {
            case .coalition:
                return "合纵"
            case .coercive:
                return "威压"
            case .legitimacy:
                return "名义"
            case .pragmatic:
                return "务实"
            }
        }
    }
}

struct DiplomatAgent {
    let config: DiplomatAgentConfig

    func plan(
        envelope: DirectiveEnvelope,
        in state: GameState,
        rulerRecord: RulerDecisionRecord?
    ) -> DiplomatDirectiveAdjustment {
        let sourceCountry = state.diplomacyState.primaryCountry(for: config.faction)
        let snapshot = DiplomaticSnapshot(
            faction: config.faction,
            sourceCountryId: sourceCountry?.id,
            state: state
        )
        let proposal = chooseProposal(snapshot: snapshot, rulerRecord: rulerRecord)
        let target = chooseTarget(snapshot: snapshot, proposal: proposal)
        let objectiveRegionIds = chooseObjectiveRegionIds(snapshot: snapshot, rulerRecord: rulerRecord)
        let record = DiplomatDecisionRecord(
            id: "diplomat_\(config.id)_turn_\(state.turn)_\(config.faction.rawValue)",
            turn: state.turn,
            faction: config.faction,
            diplomatAgentId: config.id,
            sourceCountryId: sourceCountry?.id,
            targetCountryId: target?.countryId,
            targetFaction: target?.faction,
            proposal: proposal,
            relationStatus: target?.relation.status,
            tension: target?.relation.tension,
            objectiveRegionIds: objectiveRegionIds,
            summary: summary(proposal: proposal, target: target),
            rationale: rationale(
                proposal: proposal,
                target: target,
                rulerRecord: rulerRecord,
                snapshot: snapshot
            )
        )
        let adjustedEnvelope = DirectiveEnvelope(
            schemaVersion: envelope.schemaVersion,
            issuerId: envelope.issuerId,
            turn: envelope.turn,
            directives: envelope.directives,
            commanderAgentId: envelope.commanderAgentId,
            theaterContext: appendDiplomatContext(envelope.theaterContext, record: record)
        )
        return DiplomatDirectiveAdjustment(envelope: adjustedEnvelope, record: record)
    }

    private func chooseProposal(
        snapshot: DiplomaticSnapshot,
        rulerRecord: RulerDecisionRecord?
    ) -> DiplomaticProposal {
        if snapshot.highPressureZoneCount > 0,
           snapshot.hostileTargets.contains(where: { $0.relation.tension >= 80 }),
           rulerRecord?.posture == .defensive {
            return .truce
        }

        if rulerRecord?.posture == .offensive || config.diplomaticStyle == .coercive {
            return snapshot.hostileTargets.isEmpty ? .vassalage : .warAppeal
        }

        if rulerRecord?.posture == .coalitionMaintenance || config.diplomaticStyle == .coalition {
            return snapshot.neutralTargets.isEmpty ? .warAppeal : .alliance
        }

        if config.diplomaticStyle == .legitimacy {
            return snapshot.hanTargets.isEmpty ? .alliance : .tribute
        }

        if snapshot.neutralTargets.isEmpty {
            return snapshot.hostileTargets.isEmpty ? .borrowPassage : .truce
        }
        return .borrowPassage
    }

    private func chooseTarget(
        snapshot: DiplomaticSnapshot,
        proposal: DiplomaticProposal
    ) -> DiplomaticTarget? {
        let candidates: [DiplomaticTarget]
        switch proposal {
        case .warAppeal,
             .truce:
            candidates = snapshot.hostileTargets
        case .alliance,
             .borrowPassage:
            candidates = snapshot.neutralTargets + snapshot.coBelligerentTargets
        case .vassalage:
            candidates = snapshot.neutralTargets + snapshot.hostileTargets
        case .tribute:
            candidates = snapshot.hanTargets + snapshot.neutralTargets
        }

        return candidates.sorted {
            if $0.score == $1.score {
                return $0.countryId.rawValue < $1.countryId.rawValue
            }
            return $0.score > $1.score
        }.first
    }

    private func chooseObjectiveRegionIds(
        snapshot: DiplomaticSnapshot,
        rulerRecord: RulerDecisionRecord?
    ) -> [RegionId] {
        let rulerTargets = rulerRecord?.targetRegionIds ?? []
        if !rulerTargets.isEmpty {
            return Array(rulerTargets.prefix(3))
        }
        return Array(snapshot.contestedRegionIds.prefix(3))
    }

    private func summary(proposal: DiplomaticProposal, target: DiplomaticTarget?) -> String {
        let targetText = target?.countryName ?? target?.countryId.rawValue ?? "无目标"
        return "\(proposal.displayName) -> \(targetText)"
    }

    private func rationale(
        proposal: DiplomaticProposal,
        target: DiplomaticTarget?,
        rulerRecord: RulerDecisionRecord?,
        snapshot: DiplomaticSnapshot
    ) -> String {
        let posture = rulerRecord?.posture.displayName ?? "未定"
        let targetName = target?.countryName ?? target?.countryId.rawValue ?? "暂无可用对象"
        let relation = target?.relation.status.displayName ?? "无关系"
        return "外交官以\(config.diplomaticStyle.displayName)风格承接君主\(posture)姿态，针对 \(targetName)（\(relation)）提出\(proposal.displayName)；敌对关系 \(snapshot.hostileTargets.count)，中立关系 \(snapshot.neutralTargets.count)，高压防区 \(snapshot.highPressureZoneCount)。"
    }

    private func appendDiplomatContext(_ context: String?, record: DiplomatDecisionRecord) -> String? {
        let target = record.targetCountryId?.rawValue ?? "无对象"
        let diplomatContext = "外交层：\(record.proposal.displayName) \(target)"
        guard let context, !context.isEmpty else {
            return diplomatContext
        }
        return "\(context) \(diplomatContext)"
    }
}

extension DiplomatAgent {
    static func automatic(for faction: Faction, in state: GameState) -> DiplomatAgent {
        let style: DiplomatAgentConfig.DiplomaticStyle
        switch faction {
        case .germany,
             .cao,
             .yuan:
            style = .coercive
        case .allies,
             .sun,
             .maTeng:
            style = .pragmatic
        case .liuBei,
             .han:
            style = .legitimacy
        case .liuBiao,
             .neutral:
            style = .coalition
        }
        let country = state.diplomacyState.primaryCountry(for: faction)
        let id = country?.rulerAgentId.replacingOccurrences(of: "ruler_", with: "diplomat_") ?? "diplomat_\(faction.rawValue)"
        let name = country.map { "\($0.name)外交官" } ?? "\(faction.displayName)外交官"
        return DiplomatAgent(
            config: DiplomatAgentConfig(
                id: id,
                name: name,
                faction: faction,
                diplomaticStyle: style
            )
        )
    }
}

private struct DiplomaticTarget: Equatable {
    let countryId: CountryId
    let countryName: String
    let faction: Faction
    let relation: DiplomaticRelation
    let score: Int
}

private struct DiplomaticSnapshot {
    let hostileTargets: [DiplomaticTarget]
    let neutralTargets: [DiplomaticTarget]
    let coBelligerentTargets: [DiplomaticTarget]
    let hanTargets: [DiplomaticTarget]
    let contestedRegionIds: [RegionId]
    let highPressureZoneCount: Int

    init(faction: Faction, sourceCountryId: CountryId?, state: GameState) {
        let ownCountryIds = Set(state.diplomacyState.countries(for: faction).map(\.id))
        let sourceIds: Set<CountryId>
        if let sourceCountryId {
            sourceIds = [sourceCountryId]
        } else {
            sourceIds = ownCountryIds
        }

        var hostile: [DiplomaticTarget] = []
        var neutral: [DiplomaticTarget] = []
        var coBelligerent: [DiplomaticTarget] = []
        var han: [DiplomaticTarget] = []

        for relation in state.diplomacyState.relations {
            guard let otherCountryId = Self.otherCountryId(in: relation, sourceIds: sourceIds),
                  !ownCountryIds.contains(otherCountryId),
                  let country = state.diplomacyState.countries.first(where: { $0.id == otherCountryId }) else {
                continue
            }
            let score = Self.relationScore(
                relation: relation,
                country: country,
                faction: faction,
                state: state
            )
            let target = DiplomaticTarget(
                countryId: country.id,
                countryName: country.name,
                faction: country.faction,
                relation: relation,
                score: score
            )
            switch relation.status {
            case .atWar,
                 .hostile:
                hostile.append(target)
            case .neutral:
                neutral.append(target)
            case .coBelligerent:
                coBelligerent.append(target)
            case .allied:
                coBelligerent.append(target)
            }
            if country.faction == .han {
                han.append(target)
            }
        }

        hostileTargets = hostile
        neutralTargets = neutral
        coBelligerentTargets = coBelligerent
        hanTargets = han
        contestedRegionIds = Self.contestedRegionIds(faction: faction, state: state)
        highPressureZoneCount = state.warDeploymentState.frontZones.values.filter {
            $0.faction == faction && $0.pressure >= 4
        }.count
    }

    private static func otherCountryId(
        in relation: DiplomaticRelation,
        sourceIds: Set<CountryId>
    ) -> CountryId? {
        if sourceIds.contains(relation.firstCountryId) {
            return relation.secondCountryId
        }
        if sourceIds.contains(relation.secondCountryId) {
            return relation.firstCountryId
        }
        return nil
    }

    private static func relationScore(
        relation: DiplomaticRelation,
        country: CountryProfile,
        faction: Faction,
        state: GameState
    ) -> Int {
        let targetRegionValue = state.map.regions.values
            .filter { $0.controller == country.faction }
            .reduce(0) { $0 + ($1.city == nil ? 0 : 3) + $1.supplyValue + $1.factories }
        let hostileBonus = relation.status.isHostile ? relation.tension : max(0, 70 - relation.tension)
        let warSupportBonus = max(0, country.warSupport / 5)
        let nonNeutralPenalty = country.faction == .neutral ? -20 : 0
        let selfPenalty = country.faction == faction ? -100 : 0
        return hostileBonus + targetRegionValue + warSupportBonus + nonNeutralPenalty + selfPenalty
    }

    private static func contestedRegionIds(faction: Faction, state: GameState) -> [RegionId] {
        var scores: [RegionId: Int] = [:]
        for zone in state.warDeploymentState.frontZones.values where zone.faction == faction {
            for segment in zone.frontSegments {
                scores[segment.regionId, default: 0] += segment.strength + zone.pressure
                if state.map.regions[segment.regionId]?.controller != faction {
                    scores[segment.regionId, default: 0] += 5
                }
            }
        }
        return scores.sorted {
            if $0.value == $1.value {
                return $0.key.rawValue < $1.key.rawValue
            }
            return $0.value > $1.value
        }.map(\.key)
    }
}
