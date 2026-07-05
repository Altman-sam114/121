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
- `md/prompt/v2.0-三国迁移/v2.4_general_combat_log_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_combat_factor_log_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_name_snapshot.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_road_log_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_core_action_log_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_command_result_localization.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_tactic_shaping.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_tactic_audit.md`
