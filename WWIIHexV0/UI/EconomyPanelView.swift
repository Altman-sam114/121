import SwiftUI

struct EconomyPanelView: View {
    let gameState: GameState
    let playerFaction: Faction
    let observerModeEnabled: Bool
    let onQueueProduction: (ProductionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("钱粮")
                .font(.headline)

            ledgerSection(for: gameState.activeFaction)

            Divider()

            productionControls

            Divider()

            queueSection(for: gameState.activeFaction)
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func ledgerSection(for faction: Faction) -> some View {
        let ledger = gameState.economyState.ledger(for: faction)

        return VStack(alignment: .leading, spacing: 8) {
            Text("\(faction.displayName) 府库")
                .font(.subheadline.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    metric("人口", ledger.stockpile.manpower)
                    metric("军械", ledger.stockpile.industry)
                    metric("粮草", ledger.stockpile.supplies)
                }

                GridRow {
                    metric("人口收入", ledger.lastIncome.manpower)
                    metric("军械收入", ledger.lastIncome.industry)
                    metric("粮草维护", ledger.lastUpkeep.supplies)
                }
            }
        }
    }

    private var productionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("募兵与辎重")
                .font(.subheadline.weight(.semibold))

            ForEach(ProductionKind.allCases) { kind in
                Button {
                    onQueueProduction(kind)
                } label: {
                    Label(kind.displayName, systemImage: iconName(for: kind))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(!canQueue(kind))

                Text("耗费 \(resourceSummary(kind.cost)) | \(kind.buildTurns) 回合")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func queueSection(for faction: Faction) -> some View {
        let queue = gameState.economyState.ledger(for: faction).productionQueue

        return VStack(alignment: .leading, spacing: 6) {
            Text("队列")
                .font(.subheadline.weight(.semibold))

            if queue.isEmpty {
                Text("暂无募兵或辎重命令。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(queue) { order in
                    HStack {
                        Text(order.kind.displayName)
                            .lineLimit(1)
                        Spacer()
                        Text(order.isReady ? "就绪" : "\(order.remainingTurns)")
                            .foregroundStyle(order.isReady ? .green : .secondary)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func canQueue(_ kind: ProductionKind) -> Bool {
        !observerModeEnabled &&
            gameState.activeFaction == playerFaction &&
            gameState.phase == .alliedPlayer &&
            gameState.economyState.ledger(for: gameState.activeFaction).stockpile.canAfford(kind.cost)
    }

    private func resourceSummary(_ resources: EconomyResources) -> String {
        "人口 \(resources.manpower), 军械 \(resources.industry), 粮草 \(resources.supplies)"
    }

    private func iconName(for kind: ProductionKind) -> String {
        switch kind {
        case .infantryDivision:
            return "figure.walk"
        case .panzerDivision:
            return "shield.lefthalf.filled"
        case .motorizedDivision:
            return "truck.box"
        case .artilleryDivision:
            return "scope"
        case .supplyStockpile:
            return "shippingbox"
        }
    }
}
