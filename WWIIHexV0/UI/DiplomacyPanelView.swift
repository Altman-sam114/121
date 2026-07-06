import SwiftUI

struct DiplomacyPanelView: View {
    let diplomacyState: DiplomacyState
    let activeFaction: Faction
    let frontZoneDisplayNames: [FrontZoneId: String]

    init(
        diplomacyState: DiplomacyState,
        activeFaction: Faction,
        frontZoneDisplayNames: [FrontZoneId: String] = [:]
    ) {
        self.diplomacyState = diplomacyState
        self.activeFaction = activeFaction
        self.frontZoneDisplayNames = frontZoneDisplayNames
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("外交")
                .font(.headline)

            if let rulerRecord = diplomacyState.latestRulerRecord {
                rulerSection(rulerRecord)
                Divider()
            }

            if let diplomatRecord = diplomacyState.latestDiplomatRecord {
                diplomatSection(diplomatRecord)
                Divider()
            }

            countrySection
            Divider()
            blocSection
            Divider()
            relationSection
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var countrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("势力")
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.countries) { country in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(countryDisplayName(for: country))
                            .font(.caption.weight(.semibold))
                        Text("\(country.faction.displayName) | \(blocDisplayName(for: country.blocId))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(country.warSupport)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(country.faction == activeFaction ? .primary : .secondary)
                }
            }
        }
    }

    private var blocSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("集团")
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.blocs) { bloc in
                LabeledContent(blocDisplayName(for: bloc)) {
                    Text("\(bloc.memberCountryIds.count) 方")
                        .foregroundStyle(bloc.faction == activeFaction ? .primary : .secondary)
                }
                .font(.caption)
            }
        }
    }

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关系")
                .font(.subheadline.weight(.semibold))

            if diplomacyState.relations.isEmpty {
                Text("暂无外交关系。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(diplomacyState.relations) { relation in
                    HStack {
                        Text("\(countryDisplayName(for: relation.firstCountryId)) - \(countryDisplayName(for: relation.secondCountryId))")
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(relation.status.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(relation.status.isHostile ? .red : .secondary)
                    }
                }
            }
        }
    }

    private func rulerSection(_ record: RulerDecisionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("君主")
                .font(.subheadline.weight(.semibold))
            LabeledContent("Agent") {
                Text(AgentDecisionRecord.displayName(forAgentId: record.rulerAgentId))
            }
            LabeledContent("姿态") {
                Text(record.posture.displayName)
            }
            if let zoneId = record.preferredFrontZoneId {
                LabeledContent("重点") {
                    Text(frontZoneDisplayName(for: zoneId))
                }
            }
            Text(record.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func diplomatSection(_ record: DiplomatDecisionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("外交官")
                .font(.subheadline.weight(.semibold))
            LabeledContent("Agent") {
                Text(AgentDecisionRecord.displayName(forAgentId: record.diplomatAgentId))
            }
            LabeledContent("提案") {
                Text(record.proposal.displayName)
            }
            if let target = record.targetCountryId {
                LabeledContent("对象") {
                    Text(countryDisplayName(for: target))
                }
            }
            Text(record.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func countryDisplayName(for country: CountryProfile) -> String {
        let name = country.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && name != country.id.rawValue {
            return name
        }
        return country.faction.displayName
    }

    private func countryDisplayName(for countryId: CountryId) -> String {
        guard let country = diplomacyState.countries.first(where: { $0.id == countryId }) else {
            return "未知势力"
        }
        return countryDisplayName(for: country)
    }

    private func blocDisplayName(for blocId: DiplomaticBlocId) -> String {
        guard let bloc = diplomacyState.blocs.first(where: { $0.id == blocId }) else {
            return "未知集团"
        }
        return blocDisplayName(for: bloc)
    }

    private func blocDisplayName(for bloc: DiplomaticBloc) -> String {
        let name = bloc.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && name != bloc.id.rawValue {
            return name
        }
        return "\(bloc.faction.shortDisplayName)集团"
    }

    private func frontZoneDisplayName(for zoneId: FrontZoneId) -> String {
        let name = frontZoneDisplayNames[zoneId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "未知防区" : name
    }
}
