import SwiftUI

struct CommandPanelView: View {
    let selectedDivision: Division?
    let activeFaction: Faction
    let phase: GamePhase
    let playerFaction: Faction
    let diplomacyState: DiplomacyState
    let observerModeEnabled: Bool
    let lastCommandMessage: String?
    let onHold: () -> Void
    let onAllowRetreat: () -> Void
    let onResupply: () -> Void
    let onEndTurn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("军令")
                .font(.headline)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: onHold) {
                    Label("固守", systemImage: "shield.fill")
                }
                .disabled(!canSetHold)

                Button(action: onAllowRetreat) {
                    Label("准许撤退", systemImage: "arrow.uturn.backward.circle")
                }
                .disabled(!canSetRetreatable)

                Button(action: onResupply) {
                    Label("补员", systemImage: "cross.circle")
                }
                .disabled(!canCommandSelectedUnit)
            }
            .buttonStyle(.bordered)

            Button(action: onEndTurn) {
                Label("结束回合", systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let lastCommandMessage {
                Text(lastCommandMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var canCommandSelectedUnit: Bool {
        guard !observerModeEnabled else {
            return false
        }

        guard let selectedDivision else {
            return false
        }

        return selectedDivision.faction == playerFaction &&
            activeFaction == playerFaction &&
            phase == .alliedPlayer &&
            !selectedDivision.hasActed
    }

    private var canSetHold: Bool {
        canCommandSelectedUnit && selectedDivision?.retreatMode != .hold
    }

    private var canSetRetreatable: Bool {
        canCommandSelectedUnit && selectedDivision?.retreatMode != .retreatable
    }

    private var statusText: String {
        if observerModeEnabled {
            return "观察模式：不能下达军令。"
        }

        guard let selectedDivision else {
            return "未选择可行动军队。"
        }

        guard selectedDivision.faction == playerFaction else {
            if diplomacyState.isHostile(between: selectedDivision.faction, and: playerFaction) {
                return "已选择敌军，不能下令。"
            }
            return "已选择非敌对军队，只能查看。"
        }

        guard activeFaction == playerFaction, phase == .alliedPlayer else {
            return "\(phase.displayName) 阶段不能下令。"
        }

        guard !selectedDivision.hasActed else {
            return "该军队本回合已行动。"
        }

        return "可移动或攻击。"
    }
}
