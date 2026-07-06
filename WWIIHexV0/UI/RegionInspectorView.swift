import SwiftUI

struct RegionInspectorView: View {
    let inspectorState: RegionInspectorState?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("郡县")
                .font(.headline)

            if let inspectorState {
                regionDetails(inspectorState)
            } else {
                Text("未选择郡县。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func regionDetails(_ state: RegionInspectorState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.region.name)
                .font(.subheadline.weight(.semibold))

            if let selectedHex = state.selectedHex {
                LabeledContent("地格") {
                    Text("\(selectedHex.q),\(selectedHex.r)")
                }

                LabeledContent("地格控制") {
                    Text(state.selectedHexController?.displayName ?? "无")
                }

                LabeledContent("动态方面") {
                    Text(state.selectedHexDynamicTheaterDisplayName ?? "无")
                }

                LabeledContent("防区") {
                    Text(state.selectedHexFrontZoneDisplayName ?? "无")
                }

                LabeledContent("当前官道") {
                    Text(state.selectedHexHasRoad == true ? "是" : "否")
                }
            }

            LabeledContent("控制") {
                Text(state.region.controller.displayName)
            }

            LabeledContent("地形") {
                Text(state.region.terrain.displayName)
            }

            LabeledContent("城池") {
                Text(state.region.city?.name ?? "无")
            }

            LabeledContent("城级") {
                Text(state.cityLevel.displayName)
            }

            LabeledContent("关隘") {
                Text(state.region.terrain == .fortress ? "是" : "否")
            }

            LabeledContent("官道覆盖") {
                Text(roadSummary(state))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("官道压迫") {
                Text(summaryLines(state.roadPressureSourceSummaries))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("粮草") {
                Text("\(state.region.supplyValue)")
            }

            LabeledContent("工坊") {
                Text("\(state.region.factories)")
            }

            LabeledContent("产出") {
                Text("人口 \(state.economicOutput.manpower), 军械 \(state.economicOutput.industry), 粮草 \(state.economicOutput.supplies)")
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("方面") {
                Text(state.theaterDisplayName ?? "无")
            }

            LabeledContent("防区") {
                Text(state.frontZoneDisplayName ?? "无")
            }

            LabeledContent("战线压力") {
                Text(state.frontPressure, format: .number.precision(.fractionLength(2)))
            }

            LabeledContent("道路民生") {
                Text("\(state.region.infrastructure)")
            }

            LabeledContent("要地") {
                Text(state.objectiveNames.isEmpty ? "无" : state.objectiveNames.joined(separator: ", "))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("要地状态") {
                Text(state.objectiveStatus)
            }

            LabeledContent("己方军队") {
                Text(unitNames(state.friendlyDivisions))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("本郡武将") {
                Text(summaryLines(state.friendlyGeneralSummaries))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("可见敌军") {
                Text(unitNames(state.visibleEnemyDivisions))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("敌军接战") {
                Text(summaryLines(state.visibleEnemyEngagementSummaries))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("可见非敌对军队") {
                Text(unitNames(state.visibleNonHostileDivisions))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("非敌对关系") {
                Text(summaryLines(state.visibleNonHostileRelationSummaries))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func unitNames(_ divisions: [Division]) -> String {
        guard !divisions.isEmpty else {
            return "无"
        }
        return divisions.map(\.thematicDisplayName).joined(separator: ", ")
    }

    private func summaryLines(_ summaries: [String]) -> String {
        summaries.isEmpty ? "无" : summaries.joined(separator: "\n")
    }

    private func roadSummary(_ state: RegionInspectorState) -> String {
        guard state.passableHexCount > 0 else {
            return "无可通行地格"
        }
        let pressureSummary = state.pressuredRoadHexCount > 0
            ? "，受压 \(state.pressuredRoadHexCount)"
            : "，未受压"
        return "\(state.roadHexCount)/\(state.passableHexCount) 格\(pressureSummary)"
    }
}
