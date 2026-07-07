# Prompt 工作流索引

本文记录阶段提示词的存放规则和云端协作要求。具体业务逻辑仍以 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 和当前源码为准。

## 1. 角色召唤

- `agenta`、`a:`、`A:`：召唤 Agent A。最终回复第一行必须写：`我是 Agent A。`
- `agentb`、`b:`、`B:`：召唤 Agent B。最终回复第一行必须写：`我是 Agent B。`
- `agentc`、`c:`、`C:`：召唤 Agent C。最终回复第一行必须写：`我是 Agent C。`
- 没有这些前缀时，按普通 Codex 任务处理；若任务需要严格 A/B/C 边界，先说明本轮按普通任务执行，或提醒人工指定角色。

## 2. 阶段提示词存放

- 新阶段提示词放入 `md/prompt/<版本或主题>/`。
- 已完成阶段可以继续保留在 `md/prompt/...（已完成）/` 或既有历史目录中，不删除旧 prompt。
- 每个阶段目录至少应能看出版本、目标和负责角色；示例：`md/prompt/v2.0-三国迁移/`。
- Agent A 写给 Agent B 的提示词必须包含目标、非目标、源码依据、实现步骤、禁止项、轻量检查、文档更新、main push、CI artifact 和 Agent C 验收要求。

## 3. Agent A 提示词最低要求

Agent A 写提示词时必须明确：

- 本轮是否是业务功能、流程制度、文档维护或验收任务。
- 本轮默认分支是 `main`，Agent B 基于最新 `origin/main` 实现。
- 本机默认只跑 `md/test/test.md` 允许的轻量检查。
- Agent B 完成后需要 commit 并 push 到 `origin/main`，触发 `ci-results` workflow。
- GitHub Actions 结果包必须未加密，至少包含 manifest、失败摘要、JUnit 摘要、主构建日志和 `.xcresult`（如生成）。
- Agent C 必须用 `gh auth login` 后下载最新 `origin/main` run 的 artifact，并核对 `commitSha`、`runId`、`runAttempt`。
- 云端失败时，不做回滚式处理，默认由 Agent B 在 `main` 上追加修复 commit 后再次 push。

## 4. 当前云端阶段

当前默认云端 workflow：

```text
.github/workflows/ci-results.yml
```

当前 workflow 目标：

- 在 `push` 到 `main` 和 `workflow_dispatch` 时运行。
- 执行轻量静态检查和云端 `xcodebuild build`。
- 上传 Agent C 可下载、可追溯、未加密的 CI 结果包。

当前不纳入默认流程：

- `smalldata_test`、`develop`、`codeb/...` 长期分支。
- PR 创建、PR merge 或候选分支合并制度。
- AITRANS 的漫画探针、GGUF、模型 Release、大数据输出、密码 artifact。

## 5. 当前三国迁移阶段记录

- `md/prompt/v2.0-三国迁移/codex-v2.0-三国aiagent迁移总提示词.md`（总提示词 / 路线入口）
- `md/prompt/v2.0-三国迁移/v2.0_audit_and_contract.md`
- `md/prompt/v2.0-三国迁移/v2.1_neutral_faction_foundation.md`
- `md/prompt/v2.0-三国迁移/v2.1_sanguo_power_profiles.md`
- `md/prompt/v2.0-三国迁移/v2.2_guandu_preview_default.md`
- `md/prompt/v2.0-三国迁移/v2.3_sanguo_unit_templates.md`
- `md/prompt/v2.0-三国迁移/v2.3_tactic_display_labels.md`
- `md/prompt/v2.0-三国迁移/v2.3_siege_grain_rules.md`
- `md/prompt/v2.0-三国迁移/v2.3_unit_counter_rules.md`
- `md/prompt/v2.0-三国迁移/v2.4_ruler_posture_shaping.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomat_proposal_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomatic_command_executor.md`
- `md/prompt/v2.0-三国迁移/v2.4_governor_domestic_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_governor_production_executor.md`
- `md/prompt/v2.0-三国迁移/v2.4_governor_road_executor.md`
- `md/prompt/v2.0-三国迁移/v2.4_governor_connected_road_repair.md`
- `md/prompt/v2.0-三国迁移/v2.4_strategist_directive_planning.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_directive_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_road_combat_rules.md`
- `md/prompt/v2.0-三国迁移/v2.4_hostile_road_combat_boundary.md`
- `md/prompt/v2.0-三国迁移/v2.4_ai_executor_unit_hostile_filtering.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_diplomacy_hostile_grouping.md`
- `md/prompt/v2.0-三国迁移/v2.4_deployment_region_hostile_rules.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_combat_log_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_combat_factor_log_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_name_snapshot.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_road_log_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_core_action_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_command_result_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_command_result_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_command_directive_diagnostics_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_command_panel_hostile_status_text.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_command_button_unavailable_reason.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_tactic_shaping.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_tactic_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_nearest_enemy_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_engagement_pairing_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_road_combat_note_wrapping.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_road_pressure_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_route_enemy_distance_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_nearest_enemy_identity_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_wrapping.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_target_road_enemy_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_map_planned_operation_road_pressure_tags.md`
- `md/prompt/v2.0-三国迁移/v2.4_map_planned_operation_visible_enemy_tags.md`
- `md/prompt/v2.0-三国迁移/v2.4_map_planned_operation_tactic_labels.md`
- `md/prompt/v2.0-三国迁移/v2.4_player_general_tactic_shaping.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_influence_panel_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_assigned_unit_readiness_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_assigned_unit_road_engagement_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_visible_hostile_engagement_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_road_benefit_units_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_road_no_bonus_reason.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_cavalry_road_skill_rule.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_skill_display_labels.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_skill_road_combat_effect_hints.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_visible_hostile_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_no_hostile_empty_state.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_inspector_road_combat_note_wrapping.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_current_road_pressure_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_visible_road_pressure_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_road_mobility_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_reachable_road_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_reachable_road_distance_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_target_comparison.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_target_stance_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_target_priority_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_road_approach_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_general_matchup_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_candidate_general_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_candidate_general_modifier_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_candidate_audit_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_candidate_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_candidate_road_risk_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_combat_approach_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_general_approach_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_road_engagement_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_stance_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_threat_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_strength_outcome_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_combat_log_strength_outcome.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_risk_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_road_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_general_engagement_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_hostile_road_pressure_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_road_pressure_nearest_enemy_source_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_hostile_visibility.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_non_hostile_relation_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_general_assignment_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_appcontainer_diplomacy_hostile_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_display_diplomacy_hostile_preview.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_attack_entry.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_zoc_supply_reinforcement.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_deployment_contact.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_agent_context_summary.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_frontline_contact.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_ai_upper_layers.md`
- `md/prompt/v2.0-三国迁移/v2.4_borrow_passage_no_auto_occupation.md`
- `md/prompt/v2.0-三国迁移/v2.4_agent_fallback_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_agent_fallback_sanguo_identity.md`
- `md/prompt/v2.0-三国迁移/v2.4_agent_record_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.4_mockai_visible_text_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_mockai_objective_selection_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_agent_panel_anchor_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.4_local_llm_prompt_sanguo_terms.md`
- `md/prompt/v2.0-三国迁移/v2.4_legacy_agent_error_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_appcontainer_general_order_selection_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_supply_retreat_siege_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_supply_economy_road_log_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.4_agent_panel_theater_display_safety.md`
- `md/prompt/v2.0-三国迁移/v2.4_hex_metadata_display_safety.md`
- `md/prompt/v2.0-三国迁移/v2.4_command_audit_display_name_safety.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_selected_road_pressure.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_engagement_pairing_arrow_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_agent_panel_directive_audit_safety.md`
- `md/prompt/v2.0-三国迁移/v2.4_economy_production_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_scenario_victory_condition_bridge.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_victory_scenario_conditions.md`
- `md/prompt/v2.0-三国迁移/v2.4_strategic_sync_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_ui_chrome_agent_label_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_war_executor_general_road_mobility.md`
- `md/prompt/v2.0-三国迁移/v2.4_supply_control_hostile_gate.md`
- `md/prompt/v2.0-三国迁移/v2.4_war_executor_destination_hostile_control.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_supply_hostile_control.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_rank_display_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_marker_sanguo_glyphs.md`
- `md/prompt/v2.0-三国迁移/v2.4_inspector_strategic_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_style_display_consistency.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_visible_identity_fallback.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_panel_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.4_agent_context_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.5_ui_design_tokens_mapeditor_defaults.md`
- `md/prompt/v2.0-三国迁移/v2.5_game_title_localization.md`
- `md/prompt/v2.0-三国迁移/v2.5_mapeditor_faction_label_localization.md`
- `md/prompt/v2.0-三国迁移/v2.5_dataloader_validation_error_localization.md`
- `md/prompt/v2.0-三国迁移/v2.5_missing_resource_error_display_safety.md`
- `md/prompt/v2.0-三国迁移/v2.5_fallback_unit_template_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.5_fallback_general_registry_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.5_static_fallback_map_display_names.md`
- `md/prompt/v2.0-三国迁移/v2.5_general_combat_audit_factors.md`
- `md/prompt/v2.0-三国迁移/v2.5_general_combat_audit_names.md`
- `md/prompt/v2.0-三国迁移/v2.5_general_road_no_bonus_reason.md`
- `md/prompt/v2.0-三国迁移/v2.5_war_executor_road_diagnostics.md`
- `md/prompt/v2.0-三国迁移/v2.5_fallback_json_display_names.md`
