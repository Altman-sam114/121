import SwiftUI

struct RootGameView: View {
    @ObservedObject var container: AppContainer
    @State private var selectedCompactPanel: CompactInfoPanel = .unit
    @State private var isInfoExpanded = false
    @State private var isGeneralProfilePresented = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack(alignment: .bottomTrailing) {
                boardView
                    .ignoresSafeArea()

                VStack {
                    HUDView(
                        gameState: container.gameState,
                        onEndTurn: container.advanceOrRunAI,
                        onNewGame: container.resetGame
                    )
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius))
                    .padding(.top, 8)
                    .padding(.horizontal, 8)

                    Picker("地图图层", selection: Binding(
                        get: { container.mapDisplayLayer },
                        set: { container.setMapDisplayLayer($0) }
                    )) {
                        ForEach(MapDisplayLayer.allCases) { layer in
                            Text(layer.displayName).tag(layer)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius))
                    .padding(.horizontal, 8)

                    Toggle("观察", isOn: Binding(
                        get: { container.observerModeEnabled },
                        set: { container.setObserverModeEnabled($0) }
                    ))
                    .toggleStyle(.button)
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: SanguoDesignTokens.controlMinHeight)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius))
                    .padding(.horizontal, 8)

                    Spacer()
                }

                if isInfoExpanded {
                    infoOverlay(isLandscape: isLandscape, size: proxy.size)
                        .transition(.opacity)
                }

                Button {
                    isInfoExpanded.toggle()
                } label: {
                    Text("军情")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: SanguoDesignTokens.controlMinHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(10)

                UnitTooltipView(division: container.selectedDivision)
                    .allowsHitTesting(false)
            }
        }
        .background(SanguoDesignTokens.jade.opacity(0.18))
        .sheet(isPresented: $isGeneralProfilePresented) {
            if let general = container.selectedGeneral {
                GeneralProfileView(
                    general: general,
                    assignment: container.selectedGeneralAssignment,
                    zone: container.selectedGeneralCommandZone,
                    assignedDivisions: container.selectedGeneralAssignedDivisions,
                    hqUnderAttack: container.selectedGeneralHQUnderAttack,
                    onClose: { isGeneralProfilePresented = false }
                )
            } else {
                Text("未选择武将。")
                    .font(.headline)
                    .padding()
            }
        }
    }

    private var boardView: some View {
        BoardSceneView(
            renderState: BoardSceneAdapter.renderState(from: container),
            onHexTapped: container.handleBoardTap
        )
        .accessibilityLabel("三国六角战场")
    }

    private func infoOverlay(isLandscape: Bool, size: CGSize) -> some View {
        let width = isLandscape ? min(max(size.width * 0.32, 260), 360) : size.width
        let height = isLandscape ? size.height : min(max(size.height * 0.44, 320), 460)

        return VStack(spacing: 0) {
            compactPanelWithTabs
        }
        .frame(width: width, height: height)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SanguoDesignTokens.panelCornerRadius)
                .stroke(SanguoDesignTokens.panelStroke, lineWidth: 1)
        }
        .padding(isLandscape ? 10 : 0)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: isLandscape ? .trailing : .bottom
        )
    }

    private var compactPanelWithTabs: some View {
        VStack(spacing: 0) {
            Picker("面板", selection: $selectedCompactPanel) {
                ForEach(CompactInfoPanel.allCases) { panel in
                    Text(panel.rawValue).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            compactPanel
        }
    }

    @ViewBuilder
    private var compactPanel: some View {
        ScrollView {
            VStack(spacing: 10) {
                switch selectedCompactPanel {
                case .unit:
                    UnitInspectorView(
                        division: container.selectedDivision,
                        playerFaction: container.playerFaction,
                        strategicState: container.selectedUnitInspectorStrategicState,
                        mobilityPreviewNotes: container.selectedUnitMobilityPreviewNotes,
                        combatPreviewNotes: container.selectedUnitCombatPreviewNotes
                    )
                    RegionInspectorView(inspectorState: container.selectedRegionInspectorState)
                    CommandPanelView(
                        selectedDivision: container.selectedDivision,
                        activeFaction: container.gameState.activeFaction,
                        phase: container.gameState.phase,
                        playerFaction: container.playerFaction,
                        diplomacyState: container.gameState.diplomacyState,
                        observerModeEnabled: container.observerModeEnabled,
                        lastCommandMessage: container.lastCommandMessage,
                        onHold: container.holdSelected,
                        onAllowRetreat: container.allowRetreatSelected,
                        onResupply: container.resupplySelected,
                        onEndTurn: container.advanceOrRunAI
                    )
                    GeneralCommandPanelView(
                        zone: container.selectedGeneralCommandZone,
                        general: container.selectedGeneral,
                        assignment: container.selectedGeneralAssignment,
                        assignedDivisionRows: container.selectedGeneralAssignedDivisionRows,
                        influenceNotes: container.selectedGeneralInfluenceNotes,
                        targetRegion: container.selectedGeneralTargetRegion,
                        shouldShowTargetPreview: container.selectedGeneralTargetUsesDiplomaticHostility,
                        targetPreviewNotes: container.selectedGeneralTargetPreviewNotes,
                        hqUnderAttack: container.selectedGeneralHQUnderAttack,
                        plannedOperationRows: container.selectedGeneralPlannedOperationRows,
                        canHoldLine: container.canOrderSelectedGeneralHoldLine,
                        canAttackRegion: container.canOrderSelectedGeneralAttackRegion,
                        holdLineUnavailableReason: container.selectedGeneralHoldLineUnavailableReason,
                        attackRegionUnavailableReason: container.selectedGeneralAttackRegionUnavailableReason,
                        onShowProfile: { isGeneralProfilePresented = true },
                        onHoldLine: container.orderSelectedGeneralHoldLine,
                        onAttackRegion: container.orderSelectedGeneralAttackRegion
                    )
                case .region:
                    RegionInspectorView(inspectorState: container.selectedRegionInspectorState)
                case .general:
                    GeneralCommandPanelView(
                        zone: container.selectedGeneralCommandZone,
                        general: container.selectedGeneral,
                        assignment: container.selectedGeneralAssignment,
                        assignedDivisionRows: container.selectedGeneralAssignedDivisionRows,
                        influenceNotes: container.selectedGeneralInfluenceNotes,
                        targetRegion: container.selectedGeneralTargetRegion,
                        shouldShowTargetPreview: container.selectedGeneralTargetUsesDiplomaticHostility,
                        targetPreviewNotes: container.selectedGeneralTargetPreviewNotes,
                        hqUnderAttack: container.selectedGeneralHQUnderAttack,
                        plannedOperationRows: container.selectedGeneralPlannedOperationRows,
                        canHoldLine: container.canOrderSelectedGeneralHoldLine,
                        canAttackRegion: container.canOrderSelectedGeneralAttackRegion,
                        holdLineUnavailableReason: container.selectedGeneralHoldLineUnavailableReason,
                        attackRegionUnavailableReason: container.selectedGeneralAttackRegionUnavailableReason,
                        onShowProfile: { isGeneralProfilePresented = true },
                        onHoldLine: container.orderSelectedGeneralHoldLine,
                        onAttackRegion: container.orderSelectedGeneralAttackRegion
                    )
                case .log:
                    EventLogView(entries: container.displayEventLog)
                case .economy:
                    EconomyPanelView(
                        gameState: container.gameState,
                        playerFaction: container.playerFaction,
                        observerModeEnabled: container.observerModeEnabled,
                        onQueueProduction: container.queueProduction
                    )
                case .diplomacy:
                    DiplomacyPanelView(
                        diplomacyState: container.gameState.diplomacyState,
                        activeFaction: container.gameState.activeFaction,
                        frontZoneDisplayNames: agentPanelFrontZoneDisplayNames
                    )
                case .agent:
                    AgentPanelView(
                        record: container.lastAgentDecisionRecord,
                        rulerRecord: container.gameState.diplomacyState.latestRulerRecord,
                        diplomatRecord: container.gameState.diplomacyState.latestDiplomatRecord,
                        governorRecord: container.gameState.latestGovernorRecord,
                        strategistRecord: container.gameState.latestStrategistRecord,
                        generalRecords: container.gameState.latestGeneralRecords,
                        directiveRecords: container.lastWarDirectiveRecords,
                        regionDisplayNames: agentPanelRegionDisplayNames,
                        frontZoneDisplayNames: agentPanelFrontZoneDisplayNames,
                        countryDisplayNames: agentPanelCountryDisplayNames
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
    }

    private var agentPanelRegionDisplayNames: [RegionId: String] {
        container.gameState.map.regions.mapValues { region in
            region.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "未知郡县"
                : region.name
        }
    }

    private var agentPanelFrontZoneDisplayNames: [FrontZoneId: String] {
        Dictionary(uniqueKeysWithValues: container.gameState.warDeploymentState.frontZones.map { zoneId, zone in
            (zoneId, agentPanelFrontZoneDisplayName(for: zone))
        })
    }

    private func agentPanelFrontZoneDisplayName(for zone: FrontZone) -> String {
        let trimmedName = zone.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != zone.id.rawValue {
            return trimmedName
        }

        let regionNames = zone.regionIds
            .prefix(2)
            .map(agentPanelRegionDisplayName)
            .filter { !$0.isEmpty }
            .joined(separator: "、")
        let regionSuffix = regionNames.isEmpty ? "" : "：\(regionNames)"
        return "\(zone.faction.shortDisplayName)防区\(regionSuffix)"
    }

    private var agentPanelCountryDisplayNames: [CountryId: String] {
        Dictionary(uniqueKeysWithValues: container.gameState.diplomacyState.countries.map { country in
            let displayName = country.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return (country.id, displayName.isEmpty ? "未知外交对象" : displayName)
        })
    }

    private func agentPanelRegionDisplayName(for regionId: RegionId) -> String {
        let displayName = container.gameState.map.region(id: regionId)?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? "未知郡县" : displayName
    }
}

private enum CompactInfoPanel: String, CaseIterable, Identifiable {
    case unit = "军队"
    case region = "郡县"
    case general = "武将"
    case log = "战报"
    case economy = "钱粮"
    case diplomacy = "外交"
    case agent = "军机"

    var id: String {
        rawValue
    }
}
