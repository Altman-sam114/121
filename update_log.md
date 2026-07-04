# WWIIHexV0 v 版本更新记录

本文档记录项目从 v0 到 v0.37 的正式 v 版本演进。资料来源包括 `git log`、`README.md`、阶段文档与测试/验收报告。

维护规则：

- 每完成一个新的 v 版本任务后，必须在本文档追加对应版本记录。
- 记录应包含：版本号、完成日期、核心变更、关键文件/系统、验证结果、遗留事项。
- 若本轮只是文档整理、目录迁移、回滚或打捞，不应伪装成新 v 版本；可写入“历史维护记录”。
- 若 README、测试规范或源码语义发生变化，应同步更新本日志。

## v0 - 六角格测试板

完成日期：2026-06-14 至 2026-06-15

核心更新：

- 建立 iOS 二战回合制战棋原型，技术栈为 Swift + SwiftUI + SpriteKit。
- 创建阿登测试战场，使用 11x9 左右的 axial hex 地图。
- 落地地形、移动、战斗、占领、补给、包围、胜利条件、回合流程。
- 建立德军 MockAI 将领 `guderian`，按局势摘要生成结构化命令，再经规则系统校验执行。
- 建立 SwiftUI HUD、命令面板、事件日志、单位详情和 SpriteKit 六角格渲染。

关键系统：

- `Core/HexCoord.swift`
- `Core/MapState.swift`
- `Core/Division.swift`
- `Rules/RuleEngine.swift`
- `Rules/MovementRules.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/VictoryRules.swift`
- `SpriteKit/BoardScene.swift`
- `UI/RootGameView.swift`

备注：

- v0 的核心边界是“可玩测试板”，不做空军、海军、经济、生产、外交、多级指挥链和真实 LLM。
- 后续所有版本都必须保留 hex 作为战术层权威。

## v0.1 - strength、撤退与补员

完成日期：2026-06-15 前后

核心更新：

- `Division` 战斗模型升级为 `strength/maxStrength`，保留 `hp/maxHP` 兼容。
- 战斗伤害从 HP 语义转向兵力语义，后续明确不恢复 organization。
- 引入撤退状态与 `RetreatMode`：`retreatable` 可自动撤退，`hold` 获得防御加成。
- 撤退失败会施加额外惩罚；无补给、包围会影响战斗与回合损耗。
- `resupply/rest` 能恢复兵力。
- UI 和日志补充 Strength、Retreating、combat/retreat/reinforce/encircle/supply 分类。

关键系统：

- `Core/Division.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/RuleEngine.swift`
- `UI/UnitInspectorView.swift`
- `UI/HUDView.swift`

备注：

- v0.1 最终模型只看兵力，不引入 organization。
- `HOLD` 防御约 +20%，`RETREATABLE` 在单次损失比例达到阈值时自动撤退。

## Agent D - AI/Agent 决策管线

完成日期：2026-06-15

核心更新：

- 打捞并恢复早期 Agent D 管线，修复此前异常删除。
- 建立 `DecisionProvider` 协议，为 MockAI 与未来本地 LLM 共用。
- 建立 `AgentContext` / `AgentContextBuilder`，只传 Codable 摘要，不暴露 UI/SpriteKit 对象。
- 建立 `AgentDecisionEnvelope` / `AgentOrder` JSON schema。
- 建立 parser、command mapper、decision record 与 AI 决策展示面板。
- `TurnManager` 负责德军 AI 回合编排，`AppContainer.runAIIfNeeded()` 接入启动流程。

关键系统：

- `Agents/DecisionProvider.swift`
- `Agents/AgentContexts.swift`
- `Agents/AgentDecision.swift`
- `Agents/AgentDecisionParser.swift`
- `Agents/AgentCommandMapper.swift`
- `Agents/MockAIClient.swift`
- `Agents/LocalLLMDecisionProvider.swift`
- `Turn/TurnManager.swift`
- `UI/AgentPanelView.swift`
- `Tests/AgentPipelineTests.swift`

备注：

- Agent D 是重要历史管线，但 v0.37 后默认战争 AI 主路径已改为 ZoneDirective。
- 后续不得删除 Legacy Agent D；只能隔离、退役或作为回归参考。

## v0.2 - Region 战略层叠加

完成日期：2026-06-15 至 2026-06-16

核心更新：

- 明确废弃旧版“用 province 替换 hex”的方案，改为 Region 战略层叠加。
- `MapState` 同时持有 hex 与 region：`regions`、`hexToRegion`、`regionEdges`。
- 新增 `RegionId`、`RegionNode`、`RegionEdge`、`RegionGraph` 与校验错误类型。
- 建立阿登 v0.2 省份数据：17 省、41 边、99 hex 全覆盖、零重叠。
- `DataLoader` 加载 `ardennes_v02_regions.json` 并反向填充 `HexTile.regionId`。
- 新增 Region 规则层：移动、战斗、占领、补给、视野、胜利、pathfinder、rule system。
- 新增 `RegionCommand`、`CommandIntentAdapter`、AgentOrder schema v2，支持 region 命令与 hex 命令互转。
- UI 增加 `MapDisplayAdapter`、Region overlay 与 `RegionInspectorView`，hex 仍为唯一渲染对象。

关键系统：

- `Core/Region.swift`
- `Core/MapState.swift`
- `Data/RegionDataSet.swift`
- `Data/ardennes_v02_regions.json`
- `Rules/RegionRuleSystem.swift`
- `Rules/RegionMovementRules.swift`
- `Rules/RegionCombatRules.swift`
- `Rules/RegionOccupationRules.swift`
- `Rules/RegionSupplyRules.swift`
- `Rules/RegionVisibilityRules.swift`
- `Rules/RegionVictoryRules.swift`
- `Commands/RegionCommand.swift`
- `Commands/CommandIntentAdapter.swift`
- `SpriteKit/MapDisplayAdapter.swift`
- `UI/RegionInspectorView.swift`

验证记录：

- v0.2 Agent 6 验收：132 tests, 0 failures。
- 关键覆盖：RegionGraph、ArdennesV02Data、Region rules、Agent region command、MapDisplayAdapter、Board interaction、RuleEngineCore。

备注：

- v0.2 达成 Hex x Region 双轨架构稳定状态。
- 技术债：中立省 owner/controller 为 null 时仍回退到 `.allies`，因为 `Faction` 暂无 neutral case。

## v0.21 - 界面优化与重置流程

完成日期：2026-06-16

核心更新：

- 新增 `InfoPanelToggle`，信息面板默认收起，通过 `[ INFO ]` 展开。
- 新增 `UnitTooltipView`，右下角固定展示选中单位摘要。
- 新增 `NewGameButton` 与 `AppContainer.resetGame()`，支持重载初始地图/单位/Region 并清空选择与日志。
- `RootGameView` 在常规、竖屏、横屏布局中接入 Info toggle 与单位 tooltip。
- 任务 6 zoom 按设计跳过，保留固定放大 hex 与 camera drag。

关键系统：

- `UI/InfoPanelToggle.swift`
- `UI/UnitTooltipView.swift`
- `UI/NewGameButton.swift`
- `UI/RootGameView.swift`
- `UI/HUDView.swift`
- `App/AppContainer.swift`

验证记录：

- 135 tests, 0 failures。
- `swiftc -parse`、`plutil -lint`、`git diff --check` 通过。
- 模拟器烟测通过，截图记录为 `/tmp/wwiihex_v021_smoke2.png`。

## v0.31 - Theater 战区系统

完成日期：2026-06-17

核心更新：

- 新增战区数据结构：`TheaterId`、`TheaterNode`、`TheaterState`、支援请求和 AI 摘要。
- 新增 `TheaterSystem`，从 v0.2 Region 生成四个固定战区。
- 建立 `hex -> region -> theater` 映射与控制比例/胜利点聚合。
- 引入 70% 控制阈值，用于战区扩张正式化、退役和单位池重分配。
- 在 `GameState` 中加入 `theaterState`，兼容旧存档解码。
- `DataLoader` 在加载 Region 后自动生成 v0.31 四战区。

关键系统：

- `Core/Theater.swift`
- `Rules/TheaterSystem.swift`
- `Core/GameState.swift`
- `Data/DataLoader.swift`
- `Tests/TheaterSystemTests.swift`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。
- 全量测试：146 tests, 0 failures。

备注：

- v0.31 不做 FrontLine、自动布防、攻势规划、LLM 决策、UI 重构或战斗/hex 规则改动。

## v0.32 - FrontLine 前线层

完成日期：2026-06-17

核心更新：

- 新增前线模型：`FrontLine`、`FrontSegment`、`RegionFrontState`、`FrontLineState`。
- 新增 `FrontLineManager`，支持 turn rebuild 与 event-driven dirty update。
- 建立 `enemyNeighborCache`，简化包围识别。
- 单战区面对多敌战区时，仍暴露一条主 `FrontLine` 给 AI/UI 聚合使用。
- `GameState` 增加 `frontLineState` 并兼容旧存档 empty。
- `DataLoader` 初始加载 Region/Theater 后生成 FrontLine。

关键系统：

- `Core/FrontLine.swift`
- `Core/FrontSegment.swift`
- `Core/RegionFrontState.swift`
- `Core/FrontLineState.swift`
- `Rules/FrontLineManager.swift`
- `Tests/FrontLineCreationTests.swift`
- `Tests/FrontLineUpdateTests.swift`
- `Tests/MultiEnemyFrontTests.swift`

验证记录：

- v0.32 专项测试：9 tests, 0 failures。
- 全量测试：155 tests, 0 failures。
- `project.pbxproj` lint 通过。

备注：

- v0.32 未改 UI、SpriteKit、AI agent、LLM、命令系统、RegionGraph 或 TheaterSystem 结构。

## v0.33 - WarDeployment 部署层

完成日期：2026-06-17

核心更新：

- 新增 `FrontZone`、`FrontZoneSegment`、`WarDeploymentState` 与 `WarDeploymentManager`。
- 从 v0.31 Theater 生成 v0.33 `FrontZone`。
- 建立 region 粒度前线 segment 与 `FRONT / DEPTH / GARRISON` 三层单位池。
- 支持推进、崩溃、战区消亡与事件更新。
- dirty region + neighbor zone 局部重建，避免每次全图前线扫描。
- 新增前线、segment、部署、战争演化和局部更新性能测试。

关键系统：

- `Core/FrontZone.swift`
- `Core/FrontZoneSegment.swift`
- `Core/WarDeploymentState.swift`
- `Core/WarDeploymentTypes.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/WarDeploymentFrontLineTests.swift`
- `Tests/WarDeploymentSegmentTests.swift`
- `Tests/WarDeploymentDeploymentTests.swift`
- `Tests/WarEvolutionTests.swift`

验证记录：

- v0.33 选定测试：13 tests, 0 failures。
- 全量测试：168 tests, 0 failures。
- `plutil -lint` 通过。

备注：

- v0.33 未改 UI/SpriteKit、AI/LLM/命令系统，也未引入复杂路径搜索。

## v0.331 - v0.31 至 v0.33 总测试

完成日期：2026-06-18

核心更新：

- 对 v0.31 战区、v0.32 前线、v0.33 部署进行阶段集成测试。
- 清理和巩固测试 fixture，使战区、前线、部署三层能稳定共同回归。
- 优化探针检测，准备后续地图编辑器和战争命令系统接入。

关键系统：

- `Tests/TheaterSystemTests.swift`
- `Tests/FrontLine*Tests.swift`
- `Tests/WarDeployment*Tests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段主要是集成验收和测试基线整理，不是新玩法版本。

## v0.34 - 地图编辑器

完成日期：2026-06-18 至 2026-06-19

核心更新：

- 在 `MapEditor/` 下加入项目专属地图编辑器骨架。
- 使用 SwiftUI 管理工具面板，SpriteKit 管理六角格交互视口。
- 编辑器直接导出项目自有 `ScenarioDefinition` 与 `RegionDataSet` JSON，不再引入 Tiled 中间件。
- 新增 macOS 独立 target `MapEditorMac`。
- 支持地块、省份、战区、初始部队编辑。
- `DataLoader` 增加任意文件名加载入口和 MapEditor 输出专用加载路径。
- 地形补充 `hill`，并同步 `terrain_rules.json`、颜色和 inspector 显示。

关键系统：

- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorHexMath.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorMacApp.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `Tests/MapEditorOutputTests.swift`

验证记录：

- `MapEditorOutputTests` 覆盖编辑器输出到 `GameState` 的集成链路。

## v0.341 - macOS 独立编辑器

完成日期：2026-06-18

核心更新：

- 新增 `MapEditorMac` target，作为独立 macOS app 运行。
- 默认窗口适配宽屏/全屏地图编辑。
- 左侧 SwiftUI split panel 管理地图、模式、参数、文件操作。
- 右侧 SpriteKit canvas 渲染六角格。
- 支持鼠标拖拽连续涂色、滚轮/触控板缩放、右键/中键/Option+左键平移。
- 默认工作流读写 `WWIIHexV0/Data/ardennes_v0_scenario.json` 与 `ardennes_v02_regions.json`。

备注：

- MapEditor 不接入 iOS 主入口，避免污染游戏 app 启动流程。

## v0.342 - 地图编辑器中文化与显式编辑流

完成日期：2026-06-18

核心更新：

- 地图编辑器左侧面板改为中文。
- 模式拆成：地块、省份、战区、部队。
- 各模式采用统一 `添加 / 删除 / 完成 / 取消` 显式编辑会话。
- 切换模式会取消当前编辑会话，避免误操作。
- 分层显示只突出当前模式相关数据。
- `MapEditorOutputTests.testEditorSessionActionsReflectInGameState` 覆盖地块、省份、战区、部队完整编辑与导出读取。

## v0.343 - 地图编辑器视口稳定、稀疏扩图与快捷键

完成日期：2026-06-18

核心更新：

- 平移改用 view-space 指针增量，避免 camera 移动导致拖动抖动。
- 滚轮/触控板缩放以鼠标所在 scene point 为锚点，减少视口漂移。
- `MapEditorDocument.contains(_:)` 改为判断实际存在 hex，支持稀疏地图。
- 地块模式新增扩展地块动作，允许在已有 hex 邻位生成新 hex。
- 删除 hex 会清理该 hex 上的初始部队，并移除空 region/theater assignment。
- region/theater 名称由 UI 输入，内部 ID 自动递增。
- 新增快捷键：`N` 添加，`M` 完成。

验证记录：

- `MapEditorOutputTests` 扩展覆盖自动 ID、邻接扩展、虚空造地失败、删除清理、平移/缩放数学。

## v0.344 - 地图编辑器交互修复、信息面板与底图层

完成日期：2026-06-19

核心更新：

- macOS 画布改用 `NSViewRepresentable + SKView`，直接接收 `keyDown`。
- 修复 SpriteKit 抢焦点后 SwiftUI `Button.keyboardShortcut` 不稳定的问题。
- 滚轮缩放与水平/Shift 滚轮平移接入 `SKView.scrollWheel`。
- 右键短按选择 hex，并在左侧信息面板展示/编辑坐标、地形、道路、region、theater 信息。
- Region/Theater 颜色改用固定高对比色板按 ID hash 取色。
- 新增编辑器底图层：导入图片、设置透明度、缩放和位置；底图不写入游戏 JSON。

验证记录：

- `MapEditorOutputTests` 扩展覆盖快捷键、右键信息选择、名称保存、底图文档状态与移动增量。

## v0.351 - 初步战争命令系统

完成日期：2026-06-19

核心更新：

- 新增战争指令协议：`DirectiveEnvelope` / `ZoneDirective`。
- 新增 `WarCommandExecutor`，将 zone 级 attack/defend 意图翻译为底层 `Command`。
- 新增 `MockAICommander`，按兵力比阈值输出 attack/defend。
- AI 指令与玩家命令最终都走 `RuleEngine` / `CommandValidator` 校验执行。
- 为后续 LLM 输出 JSON 指令预留协议层。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`

备注：

- v0.351 只是初级战争命令，不做复杂战术、撤退命令、装甲差异化或真实 LLM。

## v0.352 - 新管线唯一化、观察者模式与分层 UI

完成日期：2026-06-19

核心更新：

- 新增/强化 `WarPipelineMode.zoneDirective`，默认战争 AI 走新 ZoneDirective 管线。
- Legacy Agent D 保留但不作为默认战争 AI 主路径。
- 引入观察者模式，支持双方由 AI 自动对战，但回合推进仍受玩家操作控制。
- 新增 `WarDirectiveRecord`，记录 directive、结果、诊断和 UI 回放信息。
- UI 支持 hex/province/theater/frontLine 等图层切换。
- `MockAICommander` attack 阈值从 1.5 调整到 1.2，使战局更容易推进。

关键系统：

- `Core/WarPipelineMode.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Core/WarDirectiveRecord.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

## v0.353 - 默认地图验收与归属权威重构

完成日期：2026-06-19

核心更新：

- 默认地图接入真实战局模拟验收。
- 确立 hex controller 为归属权威。
- region controller、theater 控制比例、补给站归属改为从 hex controller 派生。
- 避免继续依赖静态阵营标签判断动态占领结果。
- 观察者模式下新地图可用于战争模拟和回归测试。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/TheaterSystem.swift`
- `Rules/RegionOccupationRules.swift`
- `Tests/ObserverModeIntegrationTests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段是后续 v0.354/v0.355 修复“AI 不动、联动不及时、占领不对称”的地基。

## v0.354 - 联动修复、拒绝率治理与玩家/AI 对称性

完成日期：2026-06-19 至 2026-06-20

核心更新：

- 修复占领后 region、theater、frontline、visibility 不在同一回合联动的问题。
- 修复 ZOC 友军穿越误判，避免友军互相阻挡。
- 定位“德军若干回合后不动”的真实病灶：推进过深的部队被部署层误判为 garrison，从前线兵力池消失。
- 统一玩家与 AI 的占领判定入口，避免 AI 能占玩家地、玩家不能占 AI 地的不对称。
- 改善 RuleEngine 拒绝率诊断，避免非法命令被静默吞掉。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/WarDeploymentManager.swift`
- `Rules/CommandValidator.swift`
- `Commands/WarCommandExecutor.swift`
- `Tests/WarEvolutionTests.swift`
- `Tests/ObserverModeIntegrationTests.swift`

备注：

- v0.354 期间有多轮 debug 与修复提交，包括 `v0.354 优化1`、`v0.354修复`、`0.354debug`。

## v0.355 - 动态/初始战区分离、前线 UI 与观察者收尾

完成日期：2026-06-20 至 2026-06-23

核心更新：

- 正式分离 `TheaterState.initialSnapshot` 与运行时动态战区状态。
- 修复战区阵营身份不能从动态控制比例反推的问题。
- 图层拆分为 `hex`、`province`、`initialTheater`、`dynamicTheater`、`frontLine`。
- 前线 overlay 改为按 `FrontSegment` 连线绘制。
- 观察者模式开关接入主界面 UI。
- 执行 20 回合观察者模式模拟与阶段分析，记录 directive、拒绝原因、省份换手和补给/包围趋势。

关键系统：

- `Core/Theater.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`
- `Tests/Stage035CampaignSimulationTests.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

验证记录：

- 历史记录显示 v0.355 阶段曾达到 Probe 9/0、Smoke 4/0、Stage Regression 63/0、Full 198/0。
- 20 回合观察者模拟：57 条 directive，拒绝率约 10%，主要拒绝原因为移动力不足与无路径。

备注：

- 文档 `0.355-迄今概览.md` 记录该阶段架构总结与后续注意事项。

## v0.356 - 默认资源一致性与前线 UI 修正

完成日期：2026-06-24

核心更新：

- DEBUG 下 `DataLoader` 优先读取源码 `WWIIHexV0/Data/*.json`，避免编辑器覆盖保存后游戏仍读取旧 bundle 资源。
- 新增默认资源一致性测试，确保编辑器 document、导出 JSON、游戏加载后的 `hexToRegion`、`regionToTheater`、`tile.regionId`、`region.name` 一致。
- 前线 UI 改为在我方动态战区侧绘制，用 `segment.regionA` 内接敌 hex 的中心点连线。
- 不同 theater 前线使用固定不同基色。
- 每个 segment 单独绘制，并在 segment 起点加分隔符，避免被看成一整条红线。

验证记录：

- 定向 MapEditorOutputTests + Stage0355DynamicTheaterTests：10 tests, 0 failures。
- Probe：9 tests, 0 failures。
- Smoke：4 tests, 0 failures。
- Full regression：200 tests, 0 failures。
- `git diff --check` 通过。

备注：

- 如果模拟器中仍运行旧 app 进程，需要重新运行 app 才会读到 DEBUG 源码 JSON。

## v0.357 - 地图视角、开局单位与前线 UI 修正

完成日期：2026-06-24

核心更新：

- 修复地图编辑器与游戏内视角上下颠倒/不一致问题。
- 修复部队初始部署异常与跨阵营战区问题。
- 修正开局不应立即让 AI 自动行动的行为，开局应先显示真实初始部队状态。
- 继续优化前线 UI，使动态战区、segment 与视觉表达一致。

关键系统：

- `MapEditor/*`
- `Data/DataLoader.swift`
- `App/AppContainer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

## v0.358 - 动态 hex 战区语义收口

完成日期：2026-06-24

核心更新：

- 确认核心语义：`regionToTheater` 是初始/基础战区映射，`hexToTheater` 是运行时动态战区权威。
- 单位占领一个 hex 只推进该 hex 的动态战区归属，不能把整个 region 拖入进攻方 theater。
- 部署层同步引入/强化 `hexToFrontZone`，避免 region 粒度误判 FRONT/DEPTH/GARRISON。
- 前线改按动态 hex 邻接生成，测试 fixture 必须构造真实相邻 hex，不能只声明 region 邻接。
- AI target、WarDeployment、overlay、probe 和 stage tests 同步适配动态 hex 语义。

关键系统：

- `Core/Theater.swift`
- `Core/WarDeploymentState.swift`
- `Rules/TheaterSystem.swift`
- `Rules/FrontLineManager.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

备注：

- 这是 v0.3 主线的重要铁律：运行时动态战区跟 hex 走，不跟 region 走。

## v0.359 - 前线 UI 优化

完成日期：2026-06-25

核心更新：

- 继续优化前线 overlay 的可读性。
- 强化不同战区/不同 segment 的视觉区分。
- 保留 encirclement/collapsing 等警示状态的红色与加粗表达。
- 使前线 UI 更接近真实动态战区接触，而不是静态 region/theater 边界。

关键系统：

- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`

## v0.3510 - 颜色优化

完成日期：2026-06-25

核心更新：

- 优化地图分层 UI 的颜色表达。
- 强化 province、initialTheater、dynamicTheater、frontLine 等 layer 的辨识度。
- 避免相邻 region/theater 颜色过近导致误判。

关键系统：

- `SpriteKit/TerrainStyle.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

备注：

- 该版本号沿用提交历史中的 `v0.3510`，语义上属于 v0.35x UI 收尾序列，不是 v0.351 的子补丁。

## v0.3511 - UI 修复优化

完成日期：2026-06-25

核心更新：

- 继续修复和优化主游戏 UI。
- 配合 v0.359/v0.3510 的颜色和前线显示调整，改善可读性。
- 为 v0.36 命令层扩展前的界面状态收口。

关键系统：

- `UI/*`
- `SpriteKit/*`

备注：

- 该版本号同样来自提交历史，属于 v0.35x 收尾序列。

## v0.36 - 命令层扩展与多将领 MockAI

完成日期：2026-06-25

核心更新：

- `ZoneDirective` 扩展 `CommandCategory`、`TacticName`、`DirectiveTarget`。
- 新增 `ZoneCommanderAgent`，每个动态战区可由独立将领 agent 生成 directive。
- 新增 `BinaryTacticClassifier`，在 `standardAttack` 与 `holdPosition` 之间做初步分类。
- 新增 `TheaterCommanderPool`，为动态战区提供将领配置，未知新战区使用 fallback commander。
- `WarDirectiveRecord` 增加 category、tactic、commanderAgentId、commandTarget 等字段，便于回放和审计。
- `MockAICommander` 转为兼容 facade，不作为未来扩展主入口。
- 修复旧测试 fixture，使其符合 v0.358 动态 hex 邻接语义。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Core/WarDirectiveRecord.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：17 tests, 0 failures。
- Stage Regression：63 tests, 0 failures。
- Full Regression：213 tests, 0 failures。
- 静态检查：`plutil`、`xmllint`、`jq`、`git diff --check` 通过。

备注：

- `AttackIntensity` 字段仍存在，但没有实际分流执行逻辑。
- 战区互助接口仍无调用方。
- 真 LLM 尚未接入。

## v0.37 - 命令层统一整合

完成日期：2026-06-27

核心更新：

- 默认战争 AI 路径收口为：

```text
TheaterCommanderPool -> ZoneCommanderAgent -> ZoneDirective -> WarCommandExecutor -> RuleEngine -> WarDirectiveRecord
```

- 移除 `TurnManager` 中 `MockAICommander` fallback，避免默认路径语义模糊。
- `.zoneDirective` 分支只通过显式 `commanderPool` 或 `TheaterCommanderPool.automatic(for:)` 产生 envelope。
- Legacy Agent D 只在显式 `.legacyAgentOrder` 或测试回归中使用。
- 保留 `MockAICommander` 作兼容/阈值行为测试用途，但不再作为 `TurnManager` 默认备用入口。
- 确认 `WarCommandExecutor.execute(_ directive:in:)` 不依赖具体 `ZoneCommanderAgent` 实例，手写合法 `ZoneDirective` 可直接执行。
- 新增 v0.37 手写 directive 探针，为 v0.4 玩家 UI 共用命令管线预留后端能力。
- 决定将撤退命令、突破/闪电战、装甲差异化、`AttackIntensity` 实际分流推迟到 1.x。

关键系统：

- `Turn/TurnManager.swift`
- `Commands/WarCommandExecutor.swift`
- `Commands/WarDirective.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：18 tests, 0 failures。
- CommandSystemTests：15 tests, 0 failures。
- Stage Regression：69 tests, 0 failures。
- Full Regression：226 tests, 0 failures。

备注：

- v0.37 是命令层地基工程，不新增玩法机制。
- v0.4 可以在此基础上接玩家聊天/命令 UI，但必须继续共用 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。

## v0.5 - 元帅层、模拟 LLM JSON 与决策链规范化

完成日期：2026-07-04

目标分支：`v0.5-marshal-decision-chain`

分支审计：本轮开始时创建并切换过该分支；后续轻量审计中当前 checkout 先后显示为 `v0.9-ruler-diplomacy`、`v0.4-generals-command-ui-resume`、`v1.1-macos-main-game`、`v1.0-ui-ai-playtest` 等非 v0.5 分支，且工作树已有多批其他版本未提交改动。用户同意切换后，当前 checkout 已确认回到 `v0.5-marshal-decision-chain`；合并前仍必须审查 dirty worktree 中非 v0.5 文件归属和文件级冲突。

核心更新：

- 新增元帅层 `MarshalAgent`，在战区将军上游读取降维战场摘要并产出战役级意图。
- 默认战争 AI 管线升级为：

```text
MarshalAgent
  -> MarshalBattlefieldSummarizer
  -> SimulatedMarshalLLMClient
  -> TheaterDirectiveDecoder
  -> TheaterDirectiveCompiler
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
```

- 新增 `TheaterDirectiveEnvelope` / `TheaterDirective` 作为 v0.5 LLM-facing JSON schema。
- 新增 `TheaterDirectiveDecoder`，支持 fenced JSON 提取、`JSONDecoder` 解码、schemaVersion / issuer / turn / faction / zone / region / tactic-category 校验。
- 新增 `SimulatedMarshalLLMClient`，只模拟 LLM 接口和 JSON 输出，不接真实网络、本地模型或云端 API。
- 新增 `TheaterDirectiveCompiler`，把元帅意图降级为现有 `ZoneDirective`；缺失或失败时 fallback 到 `TheaterCommanderPool`。
- `WarPipelineMode` 新增 `.marshalDirective`，`AppContainer` 和 `TurnManager` 默认使用该模式；旧 `.zoneDirective` 和 `.legacyAgentOrder` 仍保留为显式路径。
- `TurnManager` 抽出公共 `executeDirectiveEnvelope`，确保元帅链路和旧将军池链路共享同一执行、记录和 endTurn 逻辑。
- v0.5 收口时移除 v0.9 旁支曾插入的 `RulerAgent` 塑形调用；当前 `.marshalDirective` 与显式 `.zoneDirective` 都不写统治者记录，统治者仅作为后续上游预留。
- 新增实现记录文档，详细写明本分支算法、边界、fallback 和轻量验证。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/WarPipelineMode.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `md/prompt/anti生成/v0.5/anti/0.50_v0.5_marshal_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `git rev-parse --abbrev-ref HEAD`：`v0.5-marshal-decision-chain`。
- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`
  - `swiftc -parse WWIIHexV0/App/AppContainer.swift`
  - `swiftc -parse WWIIHexV0/Core/WarPipelineMode.swift`
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty` 已通过：
  - `WWIIHexV0/Data/ardennes_v02_regions.json`
  - `WWIIHexV0/Data/general_agents.json`
  - `WWIIHexV0/Data/generals.json`
  - `WWIIHexV0/Data/terrain_rules.json`
  - `WWIIHexV0/Data/unit_templates.json`
- 文档尾随空白扫描：无命中。
- 旧默认测试口径扫描（`AGENTS.md`、`md/flow/flow.md`）：无命中。
- Cabinet/Minister 旧污染源码扫描：无命中。
- v0.5 当前文档与 `TurnManager` 的 `RulerAgent` 默认接入残留扫描：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

备注：

- 本轮没有恢复历史回退的 `CabinetState`、`DirectiveBoard`、`MinisterDecisionProvider`、`RulerDirectiveFactory`、`national_cabinet.json` 或部长系统。
- 统治者层仅作为未来元帅上游预留方向，不在 v0.5 当前实现中落地。
- 当前工作树还存在不属于本 v0.5 核心目标的高级战术、外交、经济、UI 和地图编辑器方向未提交改动；v0.5 实现选择兼容现有工作树，不回滚其他改动。

## v0.8 - 初级经济、生产、城市、地形与补兵

完成日期：2026-07-04

目标分支：`codex/v0.8-economy-production`

分支审计：本轮早期创建 v0.8 分支曾因 `.git` 写入权限受限失败；期间当前 checkout 先后观察到其他版本分支，且工作树已有多批其他版本未提交改动。最终已通过受控审批成功创建 `codex/v0.8-economy-production`，但创建后仍观察到外部 checkout 漂移。因此本记录描述当前工作树中的 v0.8 经济系统实现，合并前必须重新确认当前分支、分支基点、文件级冲突、public API 冲突和 Xcode project 引用。

核心更新：

- 新增 `EconomyState`，建立 faction 级 manpower、industry、supplies 总账、生产队列、上回合收入/维护费/补员消耗。
- 新增 `EconomyRules`，从真实己方 hex 控制证据、region 城市、工厂、基础设施和补给值聚合收入。
- `GameState` 增加 `economyState`，旧存档缺失时 fallback `.empty`。
- `StrategicStateBootstrapper` 与 `RuleEngine` 在需要时 bootstrap 经济总账，保证旧状态第一次执行命令也有经济账本。
- `Command` 新增 `queueProduction(kind:)`，经 `CommandValidator` 检查 phase 和资源，经 `CommandExecutor` 调 `EconomyRules.queueProduction` 预付成本并入队。
- `CommandExecutor.executeEndTurn` 增加 active faction 经济结算：收入、战略补给维护费、短缺降级、自动补兵、生产队列推进和完成部署。
- 自动补兵只处理本阵营、未毁灭、未撤退、supplied、非敌邻、strength 未满的单位，每回合每单位最多恢复 2 strength，按兵种权重扣资源。
- 生产完成单位只能部署到本方控制、passable、空置、非敌邻，且位于首都、城镇/大都会、工厂、高基建、高补给 region 或 supply source 的后方 hex；找不到安全部署点时订单保留。
- `BaseTerrain`、`MovementRules`、`CombatRules` 增加地形加成：装甲进困难地形额外移动成本，装甲攻击平原加成，攻击困难地形惩罚，步兵在森林/城市/堡垒防御加成。
- 新增 `EconomyPanelView`，`RootGameView` 接入 Economy tab，`HUDView` 展示经济摘要，Region inspector 展示城市等级和经济产出。
- `project.pbxproj` 当前已有 `EconomyState.swift`、`EconomyRules.swift`、`EconomyPanelView.swift` 引用，未新增重复 UUID。
- 新增 v0.8 实现记录，详细写明规则算法、接入点、非目标、轻量检查和风险。

关键系统：

- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `md/prompt/anti生成/v0.8/anti/0.80_v0.8_economy_implementation_record.md`
- `md/prompt/anti生成/v0.8/anti/0.80_overall_analysis_report.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 轻量 Swift parse 通过：
  - 核心规则集合，含 `EconomyState.swift`、`EconomyRules.swift`、`GameState.swift`、`Command.swift`、`CommandValidator.swift`、`CommandExecutor.swift`、`RuleEngine.swift`、`StrategicStateBootstrapper.swift`、`MovementRules.swift`、`CombatRules.swift` 等。
  - 核心规则集合 + `PlatformStyles.swift` + `EconomyPanelView.swift`。
  - 核心规则集合 + `MapDisplayAdapter.swift` + `PlatformStyles.swift` + `EconomyPanelView.swift` + `HUDView.swift` + `RegionInspectorView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过。
- 改动文档尾随空白检查：通过。
- 旧默认测试口径残留检查：通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范和用户要求均禁止本轮主动跑 Xcode 与重测试。

备注：

- v0.8 不接真实 LLM 经济部长、不做完整商品价格网、不恢复 organization、不做空军/海军/战略轰炸/工厂损毁。
- `RegionDataSet.toRegions()` 仍有历史 fallback：owner/controller 缺失最终落到 `.allies`。v0.8 经济收入已加真实 hex 控制守卫，但数据层中立语义建议后续单独修。
- 当前 AI 不会主动排产；规则层已支持 active faction 通过统一 `Command` 排产，AI 经济策略留后续版本。

## v1.0 - UI / AI / 初版试玩收口

完成日期：2026-07-04

分支：`v1.0-ui-ai-playtest`

分支审计：续接收尾时当前 checkout 曾显示为 `v1.1-macos-main-game`，切回 `v1.0-ui-ai-playtest` 后又在轻量检查期间漂到 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`。`v1.0-ui-ai-playtest` 分支已存在且与当前基线一致；交付前最后一次即时核对显示当前分支为 `v1.0-ui-ai-playtest`。由于当前工作树存在外部 checkout 漂移风险，合并前必须重新做分支与冲突审查。

核心更新：

- 创建并切换到 1.0 分支，围绕主游戏 UI、MockAI 行为、轻量性能和试玩记录做收口。
- `AgentPanelView` 接入 `WarDirectiveRecord`，AI tab 现在展示 zone、directive type、tactic、成功/拒绝命令数、目标 region 和 diagnostics。
- `EventLogView` 改为 `LogDisplayEntry` 展示模型，最近 60 条日志每条只计算一次分类，并补充 diplomacy 日志分类。
- `BoardScene.drawUnits` 缓存单位显示 hex 后排序，部署图层复用同一个 `WarDeploymentManager` 计算 role。
- `WarCommandExecutor` 开始解释 `AttackIntensity.infiltration`，无显式投入上限时限制默认投入单位数；佯攻/袭扰保留低投入策略。
- `PlatformStyles` 补充跨平台面板样式；Economy / Diplomacy 面板收口到跨平台背景和更可读字号。
- 新增 1.0 分支实现记录，写明 UI、性能、MockAI、试玩观察点、风险和未跑重测试原因。

关键系统：

- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `git branch --show-current`：切回后曾返回 `v1.0-ui-ai-playtest`，但后续轻量检查期间又返回 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`；分支漂移未完全消除。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `git diff --check`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（AGENTS.md、README.md、update_log.md、md/flow、WWIIHexV0、MapEditor）：无命中。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑重测试。

备注：

- 本轮并发子 agent 中 UI 只读定位完成，AI / 性能子 agent 因外部 503 失败，主线程接回实现。
- 当前工作树仍含 v0.5 / v0.7 / v1.1 等方向未提交改动，合并前必须做文件级、public API、schema、Xcode project 和文档口径冲突审查。

## v0.9 - 统治者、多国家、阵营集团与初步外交状态

完成日期：2026-07-04

分支：`v0.9-ruler-diplomacy`

核心更新：

- 新增 `DiplomacyState`，在 `GameState` 中保存国家、阵营集团、国家间外交关系和统治者决策记录。
- 新增 `CountryProfile`、`DiplomaticBloc`、`DiplomaticRelation`、`DiplomaticStatus`、`RulerStrategicPosture`、`RulerDecisionRecord` 等数据结构。
- 开局外交种子：
  - Germany 规则阵营：`German Reich`，`Axis`，`ruler_germany`。
  - Allies 规则阵营：`United States`、`United Kingdom`、`Belgium`，`Allied Coalition`，主统治者 `ruler_allies`。
  - 同阵营关系为 `allied`，跨阵营关系为 `atWar`。
- 新增 `RulerAgent`：读取外交、前线、部署、历史战争指令记录，生成 `RulerStrategicSnapshot`，选择 `offensive` / `defensive` / `coalitionMaintenance` / `stabilizeFront` 姿态。
- `RulerAgent` 只塑形 `DirectiveEnvelope`：
  - offensive：攻击强度提升为 `allOut`，按 region priority 重排目标。
  - defensive：攻击 directive 转为 `holdLine` 防御 directive。
  - coalitionMaintenance：提高防御预备队。
  - stabilizeFront：降低 `allOut` 为 `limitedCounter`，或采用 `flexible` 防御。
- `TurnManager` 在 `.marshalDirective` 与显式 `.zoneDirective` 路径中执行 `applyRuler`，写入 `RulerDecisionRecord` 和 `.diplomacy` 日志后，再交给 `WarCommandExecutor -> RuleEngine`。
- `DataLoader` 和 `StrategicStateBootstrapper` 会为新局或旧存档补齐外交状态。
- 新增 `DiplomacyPanelView`，`RootGameView` 增加 `Diplomacy` 面板，`AgentPanelView` 展示最近统治者 posture / focus。
- `GameLogCategory` 新增 `diplomacy`。
- 修复 `RulerStrategicSnapshot` 静态去重调用；修复 `hostileCountryIds(to:)` 在多盟友共享同一敌国时重复计数的问题。
- 新增 v0.9 实现记录，详细写明本分支算法、边界、冲突情况和未跑重测试原因。

关键系统：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Core/GameLogEntry.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`

验证记录：

- `git branch --show-current`：`v0.9-ruler-diplomacy`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（README.md、update_log.md、md/flow、v0.9 实现记录与相关 Swift 文件）：无命中。
- `swiftc -parse WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与本轮用户要求均禁止主动跑 Xcode 和重测试。

备注：

- 本轮尝试把国家/外交、AI 管线、文档三块拆给子 Agent 并行，但子 Agent 调用返回 503，没有可用产物；最终由主 Agent 在当前分支内完成实现和整合。
- 当前工作树已有 v0.5 元帅层、经济层、v1.1 macOS target、地图编辑器和 UI 等未提交改动；v0.9 选择兼容当前源码，不回滚其他改动。合并前仍需做文件级冲突审查。
- 多国家当前是战略身份层，底层规则阵营仍是 `Faction.germany` / `Faction.allies`。后续若要国家级参战、中立、投降、宣战或外交行动，需要先设计国家级权限和命令入口。

## v1.1 - 主游戏 macOS target

完成日期：2026-07-04

分支：`v1.1-macos-main-game`

核心更新：

- 新增独立主游戏 macOS app target `WWIIHexV0Mac`，区别于既有 iOS 主游戏 target `WWIIHexV0` 和地图编辑器 target `MapEditorMac`。
- 新增 macOS 主入口 `WWIIHexV0MacApp`，复用 `AppContainer.bootstrap()` 与 `RootGameView(container:)`，默认窗口 1440x900，最小内容区域 1200x760。
- `WWIIHexV0Mac` resource phase 接入主游戏默认 JSON：`ardennes_v0_scenario.json`、`ardennes_v02_regions.json`、`general_agents.json`、`generals.json`、`terrain_rules.json`、`unit_templates.json`。
- `BoardSceneView` 增加 macOS `NSViewRepresentable` 分支，用 `BoardEventSKView` 承载 `BoardScene`，iOS 继续使用 `UIViewRepresentable` 分支。
- `BoardScene` 增加 macOS 鼠标点击、拖拽平移、滚轮/触控板缩放；点击仍只回调 `onHexTapped`，后续由 `AppContainer.handleBoardTap -> RuleEngine` 处理。
- 新增 `PlatformStyles`，将主游戏 UI 的 `Color(.systemBackground)` / `Color(.tertiarySystemBackground)` 替换为 iOS/macOS 条件背景色。
- 因当前工作树已有经济、外交、统治者、将领 registry 等源码引用，`project.pbxproj` 同步把这些已被引用的支持文件和 `generals.json` 接入相关 target phase，但本轮不改这些业务逻辑。
- 新增 v1.1 实现记录，详细写明 target 设计、输入桥接算法、资源加载、轻量检查和风险。

关键系统：

- `WWIIHexV0.xcodeproj/project.pbxproj`
- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/BoardSceneView.swift`
- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/prompt/anti生成/v1.1/anti/1.10_v1.1_macos_main_game_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / macOS app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与用户要求均禁止本轮主动跑 Xcode 和重测试。

备注：

- v1.1 是平台承载和输入桥接分支，不改变 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 规则权威链路。
- 当前工作树存在多条其他方向的未提交改动；v1.1 选择兼容当前源码引用并记录风险，不回滚其他人改动。

## v0.7 - 高级战术与命令扩展

完成日期：2026-07-04

目标分支：`v0.7-tactical-upgrade`

分支审计：本轮曾创建并切换到 `v0.7-tactical-upgrade`，但连续接力时当前 checkout 多次显示为其他分支，且工作树已有多批 v0.5 / v1.0 / v1.1 / UI / 经济 / 外交方向未提交改动。按项目规则，本轮未回滚这些改动；合并前必须重新确认分支归属和文件级冲突。

核心更新：

- `TacticName` 扩展为进攻 8 类、防御 4 类：
  - 进攻：`standardAttack`、`blitzkrieg`、`spearhead`、`breakthrough`、`pincerMovement`、`fireCoverage`、`feint`、`guerrillaWarfare`。
  - 防御：`holdPosition`、`elasticDefense`、`defenseInDepth`、`lastStand`。
- `AttackParameters` 新增 `focusRegionId`、`supportRegionIds`、`convergenceRegionId`、`coordinatedZoneIds`、`maxCommittedUnits`、`exploitDepth`，支持定点突破、钳形会师、投入上限和纵深目标意图。
- `DefenseParameters` 新增 `fallbackRegionIds`、`counterattackRegionIds`、`strongpointRegionIds`、`maxFrontCommitment`，支持弹性防御、纵深防御和死守口径。
- `TheaterDirective` 新增 `convergenceRegionId` / `coordinatedZoneIds`，并补自定义 decode，旧 JSON 缺字段时仍兼容。
- `TheaterDirectiveDecoder` 校验 convergence region 和 coordinated zone 存在性，继续校验 tactic/category 一致性。
- `BinaryTacticClassifier` 从二元分类升级为读取兵力比、机动兵力、炮兵支援、纵深预备队、压力和补给警告的战术分类器。
- `TacticConditionChecker` 从恒 true 改为按战术最低条件放行：机动战术要求机动单位，火力覆盖要求炮兵/远程单位，佯攻要求前线单位，纵深防御要求 depth 预备队。
- `WarCommandExecutor` 新增 `AttackTacticProfile`，按战术控制单位来源、机动优先、炮兵优先、只攻击不推进、弱点聚焦、深目标候选、非矛头单位 hold 和投入上限。
- 定点突破弱点评分落地：

```text
enemyStrength 越低越优先
terrain.movementCost 越低越优先
region 内有 road 越优先
city.victoryPoints + supplyValue + factories 越高越优先
guerrillaWarfare 额外参考 infrastructure
```

- `defenseInDepth` 新增独立执行路径：一线 `allowRetreat`，保留预备队，其余 depth 机动单位尝试反击，否则向 fallback / strongpoint 防御地形移动。
- `fireCoverage` 落地为炮兵/远程优先、能打则打、无目标则 hold，不主动推进。
- `feint` 落地为少量前线单位牵制，默认约 1/3 前线投入。
- `blitzkrieg` / `spearhead` 落地为机动优先、集中弱点、可使用 depth 单位，非矛头前线单位 hold。
- `pincerMovement` 落地为 convergence / coordinated 数据层和单 zone 执行器 profile；多 zone 会师由元帅层或人工下发多条 directive，包围效果交给动态战区/前线/补给派生。
- `MockAICommander` 保留新增 attack 参数，避免 allOut 包装时丢失 focus/convergence/coordinated 字段。
- 新增 v0.7 实现记录文档，详细写明算法、边界、冲突风险和轻量检查口径。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Agents/MockAICommander.swift`
- `md/prompt/anti生成/v0.7/anti/0.70_v0.7_tactical_upgrade_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/03_ai_zone_directive_pipeline.mermaid`
- `README.md`

验证记录：

- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Commands/WarCommandExecutor.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Agents/MockAICommander.swift`

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

遗留风险：

- 未做运行时战局验证，战术效果和 AI 行为只通过源码与轻量 parse 检查确认语法层可用。
- 当前工作树混有其他版本改动，合并前必须做文件/API/schema/文档冲突检查。

## v0.4 - 将军养成初步、将军 UI 与玩家双轨命令

完成日期：2026-07-04

目标分支：`v0.4-generals-command-ui-final`

分支审计：本轮从一个已混入 v0.9 / v0.5 / v1.x 外部未提交改动的工作树创建 0.4 续作分支。期间 checkout 又被外部切到 `codex/v0.8-economy-production`，最终已重新固定到 `v0.4-generals-command-ui-final`。按项目规则，本轮没有回滚外部改动；只在当前分支继续补齐 0.4 将军和玩家命令链路。合并前必须重新审查 project、public API、JSON schema 和文档口径冲突。

核心更新：

- 新增实体将军数据链：`generals.json`、`GeneralData`、`GeneralRegistry`、`GeneralDispatcher`。
- `RegionNodeDefinition` / MapEditor region draft 支持 `assignedGeneralId`，默认阿登 region JSON 已给蒙哥马利、魏刚、古德里安、里布写入初始种子。
- `FrontZone` 增加 `generalAssignment`，记录将军 id、HQ region、辖下 division、忠诚、满意度和玩家干预次数。
- `WarDeploymentState.preservingGeneralAssignments` 与 AppContainer 刷新逻辑保留/补齐将军分配，避免部署层重建后将军丢失。
- `TheaterCommanderPool` 在 AppContainer 构造时可由 `GeneralDispatcher.commanderPool` 使用真实将军配置，缺失时仍 fallback 到自动 commander。
- 新增 `PlayerCommandState` 和 `PlayerPlannedOperation`，保存本回合微操锁和玩家战区计划。
- 玩家微操 move/attack/hold/resupply/allowRetreat 成功后锁定该师，降低所属将军满意度并增加干预次数；结束回合或阵营/回合变化时清空锁。
- `WarCommandExecutor.execute` 新增兼容参数 `excluding excludedDivisionIds`，在进攻、防御、纵深防御和非矛头 hold 阶段跳过玩家微操部队。
- `AppContainer` 新增玩家宏观将军命令：`Hold Line` 生成 defense `ZoneDirective`，`Attack Region` 根据当前选中敌方 region 和相邻玩家 FrontZone 生成 attack `ZoneDirective`，执行后不自动结束回合。
- 新增 `GeneralCommandPanelView` 与 `GeneralProfileView`，展示将军头像占位、军衔、风格、技能、履历、忠诚/满意度、HQ 状态、辖下部队和计划操作。
- `RootGameView` 新增 `General` tab，Unit tab 也嵌入将军命令面板。
- `BoardScene` 根据 `PlayerPlannedOperation` 画进攻箭头/防御圆环，`UnitNode` 对本回合玩家微操单位画金色圈。
- `WarDirectiveRecord` 记录玩家宏观指令结果，AI 面板与日志可继续共用同一复盘数据。

关键系统：

- `WWIIHexV0/Data/generals.json`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Core/GeneralAssignment.swift`
- `WWIIHexV0/Core/PlayerCommandState.swift`
- `WWIIHexV0/Core/FrontZone.swift`
- `WWIIHexV0/Core/WarDeploymentState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/anti生成/0.4/v0.4_generals_command_ui_branch_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `jq empty WWIIHexV0/Data/generals.json` 通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json` 通过。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- `git diff --check` 通过。
- 文档尾随空白检查无匹配。
- 单文件轻量 parse 通过：`PlayerCommandState.swift`、`GeneralAssignment.swift`、`GeneralRegistry.swift`、`GeneralCommandPanelView.swift`、`GeneralProfileView.swift`、`WarCommandExecutor.swift`、`AppContainer.swift`、`BoardScene.swift`、`UnitNode.swift`、`RootGameView.swift`。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑 Xcode 与重测试。

遗留风险：

- 未做运行时 UI 点击和 SpriteKit 视觉验证，按钮行为、sheet 展示、计划线位置仍需后续人工或授权轻量运行确认。
- 当前工作树混有其他版本改动，合并前必须重新做文件/API/schema/project 冲突审查。

## v2.0 - 三国迁移审计与兼容显示层

完成日期：2026-07-04

核心更新：

- 项目文档入口从二战原型口径改为“三国棋策 Agent”迁移口径，明确当前仍是 v2.0 兼容层。
- 新增 `md/prompt/v2.0-三国迁移/v2.0_audit_and_contract.md`，记录迁移目标、非目标、兼容合同、硬编码审计摘要、后续版本拆分和验证边界。
- 在不改变 Codable/rawValue 的前提下，迁移主要玩家可见术语：
  - `Faction.germany/allies` 显示为曹操势力 / 袁绍势力。
  - `Division` 显示为军队/步卒营/骑兵军/器械营。
  - `Region` 显示为郡县，`Theater` 显示为方面，`FrontZone` 显示为防区。
  - `manpower/industry/supplies` 显示为人口/军械/粮草。
- 主 UI 面板、SpriteKit 可见短标签、战报、HUD、军令、经济、武将、AI 决策面板完成首轮三国化显示收束。
- `Command`、`DirectiveType`、`TacticName`、`SupplyState`、`BaseTerrain`、`CityLevel`、`ProductionKind` 增加或调整三国显示名。

关键系统：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Core/SupplyState.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/MapDisplayLayer.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/Core/WarDeploymentTypes.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/HexNode.swift`
- `WWIIHexV0/UI/`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 只做 `md/test/test.md` 允许的轻量检查；具体命令和结果见本轮交付。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行重测试。

遗留风险：

- 当前仍是显示层与文档兼容迁移，不是正式三国剧本。
- `Faction` 仍只有 `germany/allies`，`Faction.opponent` 仍是二元敌我假设。
- 默认 JSON、DataLoader、MapEditor、测试和历史文档仍大量保留阿登/二战语义；v2.1-v2.2 必须分阶段迁移。
- 未做运行时 UI 和 SpriteKit 截图验证，显示是否完全无残留需后续授权运行检查。

## v2.1 - 中立兼容、三国势力数据与敌对判断去二元化小步

完成日期：2026-07-04

核心更新：

- `Faction` 新增 `.neutral`，用于数据层中立 owner/controller；默认 `Faction.allCases` 仍只枚举当前可行动的 `.germany` / `.allies`，避免中立进入旧二元回合、经济初始化和默认 AI 行动。
- `Faction` 新增三国数据势力 rawValue：`.cao`、`.yuan`、`.liuBei`、`.sun`、`.liuBiao`、`.maTeng`、`.han`。
- 新增 `Faction.activeTurnCases` 和 `Faction.scenarioCases`：前者保留当前旧二元回合参与者，后者供 MapEditor 和场景 JSON 表达完整三国势力集合。
- `TheaterSystem`、`FrontLineManager`、`WarDeploymentManager`、`RegionRuleSystem` 的控制比例、主控方和可见 region 候选改用 `Faction.scenarioCases`，让三国 controller 能进入战略派生层计算，但不进入旧回合顺序。
- `RegionDataSet.toRegions()` 修正 owner/controller 缺省或 null 时的旧 fallback：现在映射为 `.neutral`，不再错误回退到 `.allies`。
- `Faction.opponent` 保留为旧兼容 helper，但规则和 AI 摘要的核心敌对判断改用 `Faction.isHostile(to:)`。
- `DiplomacyState.initial` 可按传入 faction 列表生成基础 country / bloc profile：保留旧 germany/allies 兼容 profile，并新增曹操、袁绍、刘备、孙氏、刘表、马腾、汉室和中立郡县 profile。
- 初始外交关系中，旧 germany/allies 与新曹袁设为 `atWar`；汉室/中立和其他新增势力默认 `neutral`。
- `CommandExecutor`、`AppContainer`、`TurnManager`、`VictoryState` 补齐 `.neutral` 分支：中立不触发 AI、不作为默认回合参与者、不计入当前二元胜负统计。
- `SupplyRules`、`RegionSupplyRules`、`RegionCombatRules`、`WarCommandExecutor`、`AgentContexts`、`ZoneCommanderAgent`、`FrontLineManager` 改用 hostile 判断处理敌控、敌军、敌方目标和前线对手。
- `RulerAgent`、`MarshalAgentConfig`、`TerrainStyle`、`MapEditorView` 增加三国势力与中立 fallback。
- `MapEditorView` 的势力选择器和 `MapEditorExporter` 导出的 scenario factions 改用 `Faction.scenarioCases`。
- 新增 `md/prompt/v2.0-三国迁移/v2.1_neutral_faction_foundation.md`，记录本轮目标、非目标、兼容边界和后续风险。
- 新增 `md/prompt/v2.0-三国迁移/v2.1_sanguo_power_profiles.md`，记录三国势力数据和初始外交 profile 小步。

关键系统：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/RegionSupplyRules.swift`
- `WWIIHexV0/Rules/RegionCombatRules.swift`
- `WWIIHexV0/Rules/TheaterSystem.swift`
- `WWIIHexV0/Rules/FrontLineManager.swift`
- `WWIIHexV0/Rules/WarDeploymentManager.swift`
- `WWIIHexV0/Rules/RegionRuleSystem.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/AgentContexts.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/SpriteKit/TerrainStyle.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorExporter.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- SpriteKit 相关 parse 通过：`swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/Terrain.swift WWIIHexV0/Core/SupplyState.swift WWIIHexV0/Core/WarDeploymentTypes.swift WWIIHexV0/SpriteKit/TerrainStyle.swift`。
- MapEditor 相关 parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift MapEditor/*.swift`。
- 文档尾随空白扫描无命中。
- 冲突标记扫描无命中。
- `git diff --check` 通过，无输出。
- 旧默认测试口径扫描无命中。
- `.opponent` call site 扫描无命中；`Faction.opponent` 仍保留为旧兼容属性。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行重测试。

遗留风险：

- 这只是 v2.1 的多势力数据基础，不是完整多势力 turn order / 运行时外交迁移。
- 三国新增势力当前可被数据表达并有基础外交 profile，但还不是完整 playable turn order。
- `Faction.isHostile(to:)` 当前只是不同且非中立即敌对的轻量规则；后续仍需接 `DiplomacyState` / `PowerRelation`。
- 默认 JSON、DataLoader、MapEditor、测试和历史文档仍大量保留阿登/二战语义；v2.2 仍需迁移官渡剧本和默认加载入口。

## v2.2 - 官渡默认剧本预览入口

完成日期：2026-07-04

核心更新：

- 新增 `WWIIHexV0/Data/guandu_200_scenario.json`，作为 40 hex / 8 region 的“官渡前夜 200”迁移预览场景。
- 新增 `WWIIHexV0/Data/guandu_200_regions.json`，覆盖邺城、黎阳渡、官渡、许昌、汝南、襄阳、洛阳残垣、寿春等首批区域。
- `DataLoader.loadInitialGameState()` 默认先尝试 `guandu_200_scenario` + `guandu_200_regions`，失败时再 fallback 到旧阿登兼容 JSON。
- `MapEditorGameResourceBridge` 默认读写 `guandu_200_scenario` + `guandu_200_regions`，让编辑器默认地图和游戏默认入口保持一致。
- `WWIIHexV0.xcodeproj/project.pbxproj` 将两个官渡 JSON 加入 iOS/macOS 主资源。
- `WarCommandExecutor.defensiveDestination()` 拆开候选 hex 链式表达式，修复云端 Xcode 16.4 对复杂表达式 type-check 超时的问题，不改变防守目的地排序语义。
- 文档状态更新为 v2.2 官渡默认剧本预览，并记录旧阿登数据保留为 fallback / 历史回归参考。

关键系统：

- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/guandu_200_scenario.json`
- `WWIIHexV0/Data/guandu_200_regions.json`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.2_guandu_preview_default.md`

验证记录：

- `jq empty WWIIHexV0/Data/guandu_200_scenario.json`：通过。
- `jq empty WWIIHexV0/Data/guandu_200_regions.json`：通过。
- 官渡 JSON 语义轻量检查通过：场景 id/displayName/tile 数、tile 坐标唯一、初始单位坐标存在、scenario tile regionId 与 region hexToRegion 一致、factions 列表包含三国势力且 player/AI 仍是兼容双方。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- MapEditor 相关 parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift MapEditor/*.swift`。
- 文档尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行重测试。

遗留风险：

- 官渡数据目前是迁移预览，不是完整 80-160 hex 首发地图。
- 当前 `GamePhase` / `CommandValidator` 仍只允许旧 `.germany/.allies` 行动，所以官渡预览用旧 rawValue 承载曹/袁可行动双方。
- `cao/yuan/liuBei/sun/liuBiao/maTeng/han/neutral` 已进入数据和外交基础，但还未进入完整 playable turn order。
- 仍复用旧 `unit_templates.json` 的二战模板 id；三国兵种模板属于后续 v2.3。

## v2.3 - 三国兵种模板兼容层

完成日期：2026-07-04

核心更新：

- 新增 `WWIIHexV0/Data/sanguo_unit_templates.json`，提供 `infantry_camp`、`cavalry_wing`、`archer_camp`、`siege_engine_camp`、`garrison_camp`、`naval_fleet` 等三国 templateId。
- `ComponentType` 保留旧 `tank/motorizedInfantry/infantry/artillery` rawValue，并新增 `cavalry/archer/siegeEngine/naval/guard`，供三国模板解码。
- 官渡预览初始单位改用三国 templateId，不再引用 `infantry_division`、`artillery_division`、`motorized_division`、`panzer_division`、`garrison_division`。
- `DataLoader.loadUnitTemplates()` 优先加载 `sanguo_unit_templates.json`，缺文件时再 fallback 到旧 `unit_templates.json`。
- `DataLoader.makeDivisions()` 使用模板 `maxHP` 作为军队 `maxStrength` 上限，避免官渡 `hp: 18` 被旧默认 10 截断。
- 经济补员、兵牌短码、tooltip 和 MapEditor 画布缩写补齐三国 component 兼容显示。
- `WWIIHexV0.xcodeproj/project.pbxproj` 将 `sanguo_unit_templates.json` 加入 iOS/macOS 主资源。

关键系统：

- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/sanguo_unit_templates.json`
- `WWIIHexV0/Data/guandu_200_scenario.json`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/v2.0-三国迁移/v2.3_sanguo_unit_templates.md`

验证记录：

- `jq empty WWIIHexV0/Data/sanguo_unit_templates.json`：通过。
- `jq empty WWIIHexV0/Data/guandu_200_scenario.json`：通过。
- 三国模板语义轻量检查通过：components 权重和为 1、component rawValue 在兼容白名单内、官渡初始单位 templateId 均能在三国模板中找到、官渡初始单位 templateId 不再以 `_division` 结尾。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI / SpriteKit / MapEditor 改动 parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/SpriteKit/UnitNode.swift WWIIHexV0/UI/UnitTooltipView.swift MapEditor/MapEditorCanvasScene.swift`。
- 文档和改动 Swift 文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 当前状态 v2.2 旧口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成兵种模板和兼容显示，不实现完整围城、士气、兵种克制和多势力 turn order。
- `Division`、`hp/maxHP`、`unit_templates.json` 等源码/旧数据兼容名仍保留，后续需要继续分阶段迁移。

## v2.3 - 战术审计显示三国化

完成日期：2026-07-05

核心更新：

- `TacticName.displayName` 按 v2.3 总提示词补齐三国战术口径：箭雨/器械压制、奇袭/袭扰、固守、诱敌/退守等。
- `TheaterDirectiveDecoderError.tacticCategoryMismatch` 改用 tactic/category 的 `displayName`，避免面向日志和 UI 的诊断继续暴露旧 rawValue。
- `SimulatedMarshalLLMClient` 的 rationale 改用中文元帅说明、`tactic.displayName` 和 Swift `FormatStyle` 数字格式，不再输出 `blitzkrieg` / `fireCoverage` 等旧战术 rawValue。
- `MarshalFrontSummary.statusDisplayName` 将内部战线状态字符串映射为粮道告急、承压、占优、寡势、对峙，保留原 `status` 字符串给分类逻辑使用。
- 文档状态更新为 v2.3 兵种模板与战术审计显示兼容层；执行管线和 Codable rawValue 不变。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `md/prompt/v2.0-三国迁移/v2.3_tactic_display_labels.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 人读战术 rawValue 扫描无命中：`rg -n "tactic\\.rawValue|String\\(format:.*strengthRatio|Simulated marshal JSON" WWIIHexV0/Commands WWIIHexV0/Agents WWIIHexV0/UI`。
- 文档和改动 Swift 文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 当前状态旧口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成战术显示和审计文本三国化，不新增围城、士气、兵种克制和多势力 turn order。
- `TacticName` 的 rawValue 仍保留 `blitzkrieg` 等旧 schema 值，后续若要彻底改 schema 需单独版本迁移和兼容桥。

## v2.3 - 围城与粮草最小规则

完成日期：2026-07-05

核心更新：

- `SupplyRules.isBesieged` 新增围城判定：军队位于城池/关隘 hex，或位于带 city 的 region；该军队无可用补给线；相邻 hex 有敌对军队。
- `CombatRules.effectiveDefense` 对围城守军施加有效防御下降修正，保持最低防御为 1，并继续叠加现有 terrain / infantry / hold 规则。
- `SupplyRules.applyResupplyRest` 在围城恢复失败时输出更明确的围城和粮道日志。
- `SupplyRules.applyEncirclementAttrition` 对围城单位使用 siege attrition 文案，说明粮道断绝导致损耗。
- `EconomyRules` 未新增重复恢复逻辑；现有自动补员已经要求 supplied、非撤退、非敌邻，因此围城/断粮单位不会自动恢复。
- 文档状态更新为 v2.3 三国兵种、战术审计显示、围城和粮草规则兼容层。

关键系统：

- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `md/prompt/v2.0-三国迁移/v2.3_siege_grain_rules.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 文档和改动 Swift 文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成围城/粮草最小规则，不新增士气、疲劳、独立粮仓库存、多回合围城进度、兵种克制和多势力 turn order。
- city region 围城判定当前是 v2.3 简化：同一城池 region 内断粮且敌邻的守军会被视作围城；后续若需要可收紧到具体 city / fortress hex。

## v2.3 - 兵种克制最小规则

完成日期：2026-07-05

核心更新：

- 新增 `Division.isSiegeCapable`，把旧 `artillery` 和三国 `siegeEngine` 统一视为攻城能力单位。
- `Division.isArtillery` 保留为兼容名并转接到 `isSiegeCapable`，避免影响旧 AI、UI、经济补员和 fallback 数据。
- `CombatRules.effectiveAttack` 对攻城能力单位攻击 city / fortress terrain、`cityName` 或 `fortressName` hex 时增加攻坚修正。
- v2.3 兵种克制当前形成最小闭环：骑兵/旧装甲攻平原有加成、进困难地形有移动和攻击惩罚；弓弩/器械 range 来自 component stats；攻城器械/旧炮兵对城池和关隘有效。
- 文档状态更新为 v2.3 三国兵种、战术审计显示、围城、粮草和兵种克制规则兼容层。

关键系统：

- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `md/prompt/v2.0-三国迁移/v2.3_unit_counter_rules.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 文档和改动 Swift 文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成兵种克制最小规则，不新增完整克制矩阵、水战、士气、疲劳、武将技能和多势力 turn order。
- 旧 `artillery` fallback 也获得攻城加成；后续若要区分野战火力和攻城器械，需要新增更细 component 或模板字段。

## v2.4 - 君主姿态塑形兼容层

完成日期：2026-07-05

核心更新：

- `TurnManager` 新增可注入 `RulerAgent?`，默认用 `RulerAgent.automatic(for:in:)` 生成当前阵营君主。
- `.marshalDirective` 路径在 `TheaterDirectiveCompiler` 产出 `DirectiveEnvelope` 后调用 `RulerAgent.adjust`，把调整后的 `ZoneDirective` 交给 `WarCommandExecutor`。
- 显式 `.zoneDirective` 路径同样在执行前经过 `RulerAgent.adjust`，保持 fallback / 手写 directive 与元帅路径一致。
- `applyRulerAdjustment` 将 `RulerDecisionRecord` 写入 `DiplomacyState.rulerRecords`，追加 diplomacy 事件日志，并把君主塑形诊断写入 `AgentDecisionRecord.errors`。
- `RulerStrategicPosture.displayName`、`RulerAgent` rationale、君主事件和诊断文本改为中文口径。
- 文档状态更新为 v2.4 君主姿态塑形兼容层；核心流程图新增 `RulerAgent.adjust` 与 `DiplomacyState.rulerRecords` 节点。

关键系统：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_ruler_posture_shaping.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 文档和改动 Swift 文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成君主姿态塑形兼容层，不实现完整君主 / 军师 / 太守 / 武将 / 外交 Agent 分层。
- 君主层当前只调整 `DirectiveEnvelope`，不新增独立战略 directive schema；后续完整 v2.4 Agent court 仍需单独版本推进。
- 未做本机运行时 AI 回合烟测，真实行为正确性等待云端 CI 和后续 Agent C artifact 复判。

## v2.4 - 军师目标编排兼容层

完成日期：2026-07-05

核心更新：

- 新增 deterministic `StrategistAgent`，接在 `RulerAgent.adjust` 之后、`WarCommandExecutor` 之前。
- `.marshalDirective` 和显式 `.zoneDirective` 路径都经过 `StrategistAgent.plan`，保持元帅主线与 fallback / 手写 directive 路径一致。
- `StrategistAgent` 根据 front zone、敌邻 region、压力、据点状态和君主姿态，重排目标 region，补齐 focus/support/convergence 和强度倾向。
- 新增 `StrategistDecisionRecord` 和 `GameState.strategistRecords`，旧存档缺字段时默认空数组兼容。
- `AgentPanelView` 显示军师 agent、主防区、目标 region 和 rationale，让 AI 回合能解释“军师选哪里”。
- `WWIIHexV0.xcodeproj/project.pbxproj` 加入 `StrategistAgent.swift` 的文件引用和 source phase。

关键系统：

- `WWIIHexV0/Agents/StrategistAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/WarDirectiveRecord.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_strategist_directive_planning.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 文档和改动 Swift / project 文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成军师目标编排兼容层，不实现太守、武将、外交 Agent，也不新增真实 LLM。
- 军师层只调整 `DirectiveEnvelope`，不会直接验证运行时 AI 回合行为；真实行为正确性等待云端 CI 和后续 Agent C artifact 复判。
- 完整 v2.4 Agent court 仍需继续推进太守内政、武将指令和外交 directive。

## v2.4 - 武将军令复核兼容层

完成日期：2026-07-05

核心更新：

- 新增 deterministic `GeneralAgent`，接在 `StrategistAgent.plan` 之后、`WarCommandExecutor` 之前。
- `.marshalDirective` 和显式 `.zoneDirective` 路径都经过 `GeneralAgent.plan`，保持元帅主线与 fallback / 手写 directive 路径一致。
- `GeneralAgent` 读取 `FrontZone.generalAssignment` 与 `GeneralRegistry`，按武将忠诚、满意度、指挥风格和防区压力复核军令。
- 新增 `GeneralDecisionRecord` 和 `GameState.generalRecords`，旧存档缺字段时默认空数组兼容。
- `AgentPanelView` 显示武将、动作和防区，让 AI 回合能解释“武将做了什么”。
- `AppContainer` 创建 `TurnManager` 时传入 `GeneralAgent(registry:)`，保留现有将军池与武将分配逻辑。
- `WWIIHexV0.xcodeproj/project.pbxproj` 加入 `GeneralAgent.swift` 的文件引用和 source phase。

关键系统：

- `WWIIHexV0/Agents/GeneralAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/WarDirectiveRecord.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_directive_audit.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 文档和改动 Swift / project 文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成武将军令复核兼容层，不实现完整武将技能、太守、外交 Agent，也不新增真实 LLM。
- 武将层只调整 `DirectiveEnvelope`，不会直接验证运行时 AI 回合行为；真实行为正确性等待云端 CI 和后续 Agent C artifact 复判。
- 完整 v2.4 Agent court 仍需继续推进太守内政和外交 directive。

## v2.4 - 武将道路与交战规则兼容层

完成日期：2026-07-05

核心更新：

- `GeneralAssignment` 新增 `commandStyleRawValue` 和 `skills` 快照字段，旧存档缺字段时默认兼容为空技能和既有忠诚/满意度。
- `GeneralRegistry.GeneralData.defaultAssignment()` 将武将风格和技能写入防区分配；既有有效分配在重分配时会刷新风格/技能快照并保留忠诚、满意度和人工干预次数。
- 新增 `GeneralInfluence`，只从 `GameState.warDeploymentState.frontZones`、单位坐标和地图道路/河流/城池状态推导武将影响。
- `MovementRules` 对已分配武将且使用道路网络的军队提供小幅有效行动力加成；`CommandValidator.validateMove` 同步使用有效行动力上限。
- `CombatRules.effectiveAttack` / `effectiveDefense` 接入武将攻防修正，并继续叠加既有地形、围城、兵种克制、河流和固守规则。
- `DataLoader.loadGeneralRegistry()` 默认优先加载 `sanguo_generals.json`，缺文件时 fallback 到旧 `generals.json`。
- 新增 `sanguo_generals.json`，补入曹操、荀攸、张辽、袁绍、沮授、张郃、孙策、文聘等首批三国武将数据。
- 官渡 region 数据补入 `assignedGeneralId` 种子，让默认防区能挂接三国武将。
- `WWIIHexV0.xcodeproj/project.pbxproj` 将 `GeneralInfluence.swift` 和 `sanguo_generals.json` 接入主目标源码/资源。
- 文档状态更新为 v2.4 君主/军师/武将指令编排、道路和交战兼容层。

关键系统：

- `WWIIHexV0/Core/GeneralAssignment.swift`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Agents/GeneralAgent.swift`
- `WWIIHexV0/Rules/GeneralInfluence.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/sanguo_generals.json`
- `WWIIHexV0/Data/guandu_200_regions.json`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/v2.0-三国迁移/v2.4_general_road_combat_rules.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- `jq empty WWIIHexV0/Data/sanguo_generals.json`：通过。
- `jq empty WWIIHexV0/Data/guandu_200_regions.json`：通过。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成武将道路与交战最小规则影响，不实现完整武将技能树、单挑、士气、疲劳、太守和外交 directive。
- 武将攻防修正当前是小幅整数加成，未做本机运行时 AI 回合烟测；真实行为正确性等待云端 CI 和后续 Agent C artifact 复判。
- 三国新增势力武将可进入数据和分配种子，但完整多势力 turn order 仍未迁移。

## v2.4 - 太守内政建议审计兼容层

完成日期：2026-07-05

核心更新：

- 新增 deterministic `GovernorAgent`，在君主姿态之后、军师目标编排之前读取经济总账、受控郡县、道路、粮草、补给状态和生产队列。
- 新增 `GovernorDomesticFocus` 和 `GovernorDecisionRecord`，记录征兵、修路、屯田、治安或补给等内政重点、重点郡县、建议生产和 rationale。
- `GameState` 新增 `governorRecords`，旧存档缺字段时默认空数组兼容，并提供 `latestGovernorRecord` 与 append helper。
- `TurnManager` 在 `.marshalDirective` 和显式 `.zoneDirective` 路径中调用 `GovernorAgent.plan`，把太守建议写入事件日志、AI raw JSON 和 `DirectiveEnvelope.theaterContext`。
- `AgentPanelView` 显示太守 agent、内政重点、重点郡县、建议生产和理由。
- `AppContainer.bootstrap()` 显式传入默认太守 agent，`WWIIHexV0.xcodeproj/project.pbxproj` 将 `GovernorAgent.swift` 接入主目标源码。
- 文档状态更新为 v2.4 君主/太守/军师/武将指令编排、道路和交战兼容层。

关键系统：

- `WWIIHexV0/Agents/GovernorAgent.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/WarDirectiveRecord.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/v2.0-三国迁移/v2.4_governor_domestic_audit.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成太守内政建议与审计，不自动执行生产、不实现修路/屯田/治安状态变化，也不新增完整内政 directive validator / executor。
- 太守建议只进入 `DirectiveEnvelope.theaterContext`、AI raw JSON 和 UI 审计；后续若要真实排产，必须经 `Command.queueProduction -> CommandValidator -> EconomyRules.queueProduction`。
- 真实外交关系执行器、完整多势力 turn order 和发布级 UI 仍待后续版本推进。

## v2.4 - 外交提案审计兼容层

完成日期：2026-07-05

核心更新：

- 新增 deterministic `DiplomatAgent`，在君主姿态之后、太守内政建议之前读取国家、集团、外交关系、紧张度和战线压力。
- 新增 `DiplomaticProposal` 和 `DiplomatDecisionRecord`，支持同盟、停战、借道、称臣、讨伐檄文、奉表勤王等外交提案审计。
- `DiplomacyState` 新增 `diplomatRecords`、`latestDiplomatRecord` 和 `appendDiplomatRecord`，并为旧存档缺字段提供默认空数组解码。
- `TurnManager` 在 `.marshalDirective` 和显式 `.zoneDirective` 路径中调用 `DiplomatAgent.plan`，把提案写入事件日志、AI raw JSON 和 `DirectiveEnvelope.theaterContext`。
- `AgentPanelView` 和 `DiplomacyPanelView` 显示外交官、提案、对象、目标郡县和理由。
- `DiplomaticStatus.displayName` 与 `DiplomacyPanelView` 主要标题迁移为中文显示，不改变 Codable rawValue。
- `AppContainer` 创建 `TurnManager` 时传入默认外交 agent，`WWIIHexV0.xcodeproj/project.pbxproj` 将 `DiplomatAgent.swift` 接入主目标源码。
- 文档状态更新为 v2.4 君主/外交/太守/军师/武将指令编排、道路和交战兼容层。

关键系统：

- `WWIIHexV0/Agents/DiplomatAgent.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/v2.0-三国迁移/v2.4_diplomat_proposal_audit.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只完成外交提案与审计，不自动改变外交关系、不实现借道、停战、同盟或称臣执行器。
- 外交建议只进入 `DirectiveEnvelope.theaterContext`、AI raw JSON、外交日志和 UI 审计；后续若要真实生效，必须新增结构化外交 directive、validator 和 executor。
- 完整多势力 turn order、完整外交系统和发布级 UI 仍待后续版本推进。

## v2.4 - 外交命令执行兼容层

完成日期：2026-07-05

核心更新：

- 新增 `Command.proposeDiplomacy(sourceCountryId:targetCountryId:proposal:)`，让外交提案和玩家/AI 其它动作一样进入底层命令管线。
- `CommandValidator.validateDiplomacy` 校验阶段、源国家、目标国家、当前行动势力、既有关系和提案合法性，并新增 `countryNotFound`、`diplomaticRelationNotFound`、`invalidDiplomaticTarget`、`invalidDiplomaticProposal` 等拒绝原因。
- `DiplomacyState.applyProposal` 以既有 `DiplomaticStatus` 和 tension 做兼容映射：同盟、停战、借道、称臣、讨伐檄文、奉表勤王都能产生最小状态或紧张度变化，但不新增 vassal/truce/rawValue schema。
- `CommandExecutor.executeDiplomaticProposal` 通过 `DiplomacyState.applyProposal` 修改 `DiplomaticRelation` 并追加 diplomacy 事件日志；外交 Agent、UI 和 MapEditor 仍不得直接改关系。
- `TurnManager.applyDiplomatPlanning` 将有源国家和目标国家的 `DiplomatDecisionRecord` 转成 `Command.proposeDiplomacy` 经 `commandHandler.execute` 执行，执行结果写入 `AgentDecisionRecord.commandResults`，不混入单条 `WarDirectiveRecord`。
- `WarCommandExecutor` 和 `CommandResultSummary` 同步识别外交命令，确保新增命令不会破坏战区指令执行和 AI 面板命令结果展示。
- 文档状态更新为 v2.4 君主/外交/太守/军师/武将指令编排、外交命令、道路和交战兼容层。

关键系统：

- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomatic_command_executor.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。
- 未跑 `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`；本轮未修改 Xcode project 文件。

遗留风险：

- 本轮是外交执行兼容层，不实现真实借道通行、贡赋资源转移、臣属体系、完整外交谈判或完整多势力 turn order。
- 当前战斗敌我判断仍主要来自 `Faction` 兼容层；外交关系变化会影响外交摘要和后续 Agent 语境，但不会自动改变移动/攻击合法性。
- 真实运行时 AI 回合行为仍等待云端 CI 和后续 Agent C artifact 复判。

## v2.4 - 太守生产命令执行兼容层

完成日期：2026-07-05

核心更新：

- `TurnManager.applyGovernorPlanning` 将 `GovernorDecisionRecord.recommendedProductionKind` 转换为 `Command.queueProduction`，通过 `commandHandler.execute` 进入 `RuleEngine`。
- 太守推荐生产沿用既有 `CommandValidator.validateProduction` 和 `CommandExecutor.executeQueueProduction`，由规则层校验阶段、资源并扣款入队。
- `CommandResultSummary` 新增太守命令摘要，AI 面板能在 `AgentDecisionRecord.commandResults` 中看到生产建议是否成功或被拒绝。
- 外交预命令和太守生产预命令都会进入 `executeDirectiveEnvelope` 的 `preCommandResults`，不混入单条 `WarDirectiveRecord`。
- 文档状态更新为 v2.4 君主/外交/太守/军师/武将指令编排、外交与太守生产命令、道路和交战兼容层。

关键系统：

- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_governor_production_executor.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。
- 未跑 `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`；本轮未修改 Xcode project 文件。

遗留风险：

- 本轮只执行太守推荐生产，不实现真实修路、屯田、治安、民心、郡县状态变化或完整内政 directive schema。
- 太守推荐依赖现有资源账本和生产队列；运行时经济行为正确性仍等待云端 CI 和后续 Agent C artifact 复判。

## v2.4 - 道路与交战敌对边界兼容层

完成日期：2026-07-05

核心更新：

- `MovementRules.isEnemyZoneOfControl` 改为使用 `Faction.isHostile(to:)` 判断敌控区，并忽略已毁灭军队。
- `CommandValidator.validateAttack` 改为只允许攻击敌对势力军队，避免中立/汉室仅因阵营不同被视为合法攻击目标。
- `SupplyRules.canSupplyPass` 的军队阻断改为只看敌对军队，粮道不会被非敌对单位误断。
- `EconomyRules` 的安全补员邻接判断改为只看敌对军队，避免非敌对邻接误阻止后方补员。
- 文档补充道路 ZOC、攻击目标、粮道阻断和安全补员邻接都按 `Faction.isHostile(to:)` 收口。

关键系统：

- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_hostile_road_combat_boundary.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 当前 `Faction.isHostile(to:)` 仍是“不同且双方非中立即敌对”的最小兼容规则，尚未接入完整 `DiplomacyState` 借道/同盟通行。
- `origin/main` 推送仍受 GitHub 443 网络连接失败影响，云端 CI 暂未触发；本地已有上一笔未推送提交。

## v2.4 - 武将交战日志审计兼容层

完成日期：2026-07-05

核心更新：

- 新增 `GeneralCombatInfluenceSummary`，用同一套 `GeneralInfluence.attackBonus` / `defenseBonus` 生成只读交战审计摘要。
- `CombatRules` 暴露 `generalInfluenceSummary(attacker:defender:in:)`，供执行层读取武将攻防修正。
- `CommandExecutor` 在攻击和反击日志中追加武将修正片段，只有攻防修正非 0 时输出，避免噪声。
- 文档补充：武将交战影响不仅改变规则计算，也会进入事件日志，便于 UI、人工和 Agent C 复判。

关键系统：

- `WWIIHexV0/Rules/GeneralInfluence.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_combat_log_audit.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮初版日志摘要使用武将 id；后续“武将姓名快照兼容层”已接上本地化姓名显示。
- 本轮只做交战日志审计，不实现完整战报面板、技能树、单挑或士气。
- `origin/main` 推送仍受 GitHub 443 网络连接失败影响，云端 CI 暂未触发；本地已有两个未推送提交。

## v2.4 - 武将姓名快照兼容层

完成日期：2026-07-05

核心更新：

- `GeneralAssignment` 新增可选 `generalDisplayName`，旧存档缺字段时仍可解码。
- `GeneralData.defaultAssignment` 和 `GeneralDispatcher.assignGenerals` 刷新 assignment 时写入武将 `localizedName`。
- `GeneralCombatInfluenceSummary` 的交战日志片段优先显示武将姓名，缺失时回退到武将 id。
- 规则层仍只读 `GameState.warDeploymentState.frontZones[].generalAssignment`，不依赖 UI 或运行时 `GeneralRegistry`。

关键系统：

- `WWIIHexV0/Core/GeneralAssignment.swift`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Rules/GeneralInfluence.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_combat_log_audit.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_name_snapshot.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 文档和改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 旧存档或缺少 registry 刷新的状态仍可能只显示武将 id，这是兼容 fallback；新分配/刷新后的 assignment 会带 `generalDisplayName`。
- 本轮只改善日志可读性，不实现完整战报 UI、头像或武将技能详情联动。

## v2.4 - 武将道路机动日志审计兼容层

完成日期：2026-07-05

核心更新：

- 新增 `GeneralMovementInfluenceSummary`，用同一套 `GeneralInfluence.roadMobilityBonus` 生成只读道路机动审计摘要。
- `MovementRules` 暴露 `generalInfluenceSummary(for:in:)`，供执行层读取武将道路机动加成。
- `CommandExecutor` 在移动日志中追加武将道路机动片段，只有加成非 0 时输出，避免无武将或无道路加成时产生噪声。
- 文档补充：武将道路影响不仅改变移动上限，也会进入事件日志，便于 UI、人工和 Agent C 复判。

关键系统：

- `WWIIHexV0/Rules/GeneralInfluence.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_road_log_audit.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 旧存档或缺少 registry 刷新的状态仍可能只显示武将 id，这是兼容 fallback；新分配/刷新后的 assignment 会带 `generalDisplayName`。
- 本轮只改善移动日志可读性，不实现完整道路建设、借道通行、粮道可视化或武将详情联动。

## v2.4 - 武将道路与交战日志中文化兼容层

完成日期：2026-07-05

核心更新：

- `GeneralCombatInfluenceSummary.logFragment` 改为中文审计片段，输出 `武将影响：... 攻击/防御 ...`。
- `GeneralMovementInfluenceSummary.logFragment` 改为中文审计片段，输出 `武将道路：... 机动 ... (上限 ...->...)`。
- 保持道路机动、攻防修正、移动执行和交战执行规则不变；本轮只改善玩家可见日志片段。
- 文档补充：武将道路/交战摘要中文优先，但历史移动、攻击、撤退等主体日志仍需后续分批迁移。

关键系统：

- `WWIIHexV0/Rules/GeneralInfluence.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_log_localization.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只中文化武将影响片段，不代表所有事件日志完成中文化。
- 未做运行时 UI 烟测，日志宽度、换行和实际面板可读性仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。

## 协作流程云端化制度升级 - main 直推与 Agent C 结果包验收

完成日期：2026-07-04

性质：

- 这是协作制度和验证骨架变更，不是业务功能质量提升，也不代表 v2.0 三国迁移已通过运行时重测试。

对比记录：

- 项目类型：Swift + SwiftUI + SpriteKit 的 iOS / macOS Xcode 项目，当前处于 v2.3 三国兵种模板与战术审计显示兼容层。
- 当前分支：`main` 存在并跟踪 `origin/main`；历史分支仍保留，但本轮不纳入默认流程。
- 当前 Agent C 流程：从本地文档/轻量检查验收升级为下载 GitHub Actions 未加密结果包复判。
- 当前测试状态：本机默认只跑轻量检查；云端新增 `ci-results` workflow 承接 `xcodebuild build` 重验证。
- 当前 artifact：此前没有 Agent C 可追溯结果包；本轮新增 manifest、failure summary、JUnit 摘要、build log、`.xcresult`（若生成）。
- AITRANS 可复用：main 直推、未加密 CI 结果包、manifest 核对、Agent C 下载复判、失败后追加修复 commit。
- AITRANS 不复用：漫画探针、GGUF、模型 Release、大数据输出、密码 artifact、`smalldata_test` / `develop` / `codeb/...` / PR 候选分支制度。

核心更新：

- `AGENTS.md` 加入 `agenta` / `a:` / `A:`、`agentb` / `b:` / `B:`、`agentc` / `c:` / `C:` 召唤规则和 A/B/C 最终回复第一行身份要求。
- `AGENTS.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 统一写入 `main` 直推、云端重验证、Agent C artifact 验收和失败追加修复 commit 规则。
- 新增 `md/prompt/README.md`，记录阶段 prompt 索引、Agent A 提示词最低要求、main push 和 CI artifact 要求。
- 新增 `.github/workflows/ci-results.yml`，在 `main` push 和 `workflow_dispatch` 时运行，上传未加密 CI 结果包。
- `README.md` 新增简短“协作与云端验证”小节，不替代 `AGENTS.md`。

云端 workflow 当前边界：

- 执行 `git diff --check`、`plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`、Core/Commands/Rules/Agents/Turn Swift parse、`xcodebuild build -scheme WWIIHexV0 -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO`。
- 默认不跑云端 XCTest / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；`testOutcome` 记录为 `skipped`，后续需要稳定 simulator / probe 策略后再扩展。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `.github/workflows/ci-results.yml`
- `update_log.md`

验证记录：

- 本地轻量检查和云端结果以后续本轮交付记录为准。

遗留风险：

- 第一次 push 后才可确认 GitHub-hosted macOS runner、Xcode 版本和 iOS generic build 是否与当前工程完全兼容。
- 当前 workflow 尚未覆盖 XCTest / Probe / 模拟器 UI test；业务行为正确性仍需后续扩展云端验证或人工授权专项验证。

## 历史维护记录

以下提交不作为正式 v 版本，但影响项目资料完整性：

- 2026-06-15：重整 `md` 目录，添加 README，补充 v0.1-v1.0 提示词。
- 2026-06-15：打捞 Agent D 与误删代码，恢复 AI 决策管线。
- 2026-06-15：记录 v0.5 擅自编程与回退资料，保留为历史警示；当前主线不得引入 Cabinet/StrategicDirective/Minister 污染。
- 2026-06-18：整理文档结构，将已完成阶段文档迁入 `md/prompt/...（已完成）`。
- 2026-06-24 至 2026-06-25：补充 0.36 提示词、0.355 截止分析、20 回合文档更新。
- 2026-06-27：创建 `AGENT.md`，写入后续 Codex 接手项目时的架构、测试、文档维护和交付规则。
- 2026-07-04：更新当前协作规范：默认禁止 Xcode / XCTest / 模拟器 / 性能类重测试，只做轻量语法/格式检查；新增多版本分支、并发子 Agent 和合并前冲突检查规则。关键文件：`AGENTS.md`、`md/test/test.md`、`md/flow/flow.md`、`README.md`、`md/prompt/v0.f/fable-5-重构优化总提示词.md`。
