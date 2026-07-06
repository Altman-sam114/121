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

## v2.4 - 核心行动日志中文化兼容层

完成日期：2026-07-05

核心更新：

- `CommandExecutor` 的移动、攻击、反击、兵力损失、自动撤退、额外兵力损失、歼灭、死守、允许撤退和回合推进日志改为中文。
- `CommandExecutor` 的动态方面推进审计日志改为中文。
- `WarCommandExecutor` 中同源的动态方面推进和前线变化审计日志改为中文。
- 保持移动、战斗、撤退、占领、动态方面推进、前线更新和 AI 指令执行规则不变；本轮只改善玩家可见和审计日志文本。

关键系统：

- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_core_action_log_localization.md`

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

- 本轮不是全项目文案清零；Legacy Agent D、MockAI、部分历史文档、调试文案和更深层审计文本仍可能保留英文。
- 未做运行时 UI 烟测，日志宽度、换行和实际面板可读性仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。

## v2.4 - 命令结果与拒绝原因中文化兼容层

完成日期：2026-07-05

核心更新：

- `CommandValidationError` 新增中文展示文案，保留 rawValue / Codable 兼容。
- `CommandValidation` 新增 `displayErrors` 和 `displayMessage`，供规则层、AI 记录层和事件日志共用。
- `RuleEngine` 的 `CommandResult.message` 改为中文成功/拒绝文案。
- `AgentDecisionRecord.CommandResultSummary`、`TurnManager` 和 `WarCommandExecutor` 改用中文校验原因，避免 AI 面板、`WarDirectiveRecord.diagnostics` 和事件日志继续暴露 `wrongPhase`、`destinationOccupied` 等枚举名。
- 保持命令校验、移动、交战、外交、生产、fallback hold 和动态方面推进规则不变；本轮只改善玩家/审计可见反馈文本。

关键系统：

- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_command_result_localization.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- 旧英文命令结果/拒绝诊断残留扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮不是全项目文案清零；region id、zone id、JSON id、旧测试、历史 prompt 和部分调试文本仍可能保留英文。
- 未做运行时 UI 烟测，AI 面板实际换行和日志宽度仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。

## v2.4 - 太守修路命令兼容层

完成日期：2026-07-05

核心更新：

- 新增 `Command.improveRoad(regionId:)`，把太守修路从审计建议推进为规则层最小命令。
- `CommandValidator` 新增修路校验：必须处于可行动阶段、郡县存在、当前势力控制且有己方控制 hex、郡县仍需要修路、资源足够。
- `EconomyRules.improveRoad` 消耗人口 20、军械 30、粮草 10，最多给目标郡县补两格战术道路，并提升郡县基础设施 1 点，上限 5。
- `TurnManager.applyGovernorPlanning` 在太守焦点为 `roadRepair` 时把首个重点郡县转换为 `Command.improveRoad`；原有生产建议继续转换为 `Command.queueProduction`，两条命令结果都进入 `AgentDecisionRecord.commandResults`。
- `WarCommandExecutor` 对新增命令补齐无 acting division 和受影响郡县处理，保持命令枚举 switch 完整。
- 保持太守 Agent 本身不直接修改 `GameState`；修路仍必须经 `CommandValidator -> CommandExecutor -> RuleEngine`。

关键系统：

- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_governor_road_executor.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- 修路旧口径扫描无旧残留。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只做最小道路修缮，不保证自动连成跨郡县主干路，也不实现玩家手动修路 UI。
- 修路命令可能消耗资源导致同轮生产建议被拒绝；这会作为中文命令结果记录，属于当前兼容层预期行为。
- 未做运行时 UI 烟测，AI 面板多条太守命令的实际换行和日志宽度仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。

## v2.4 - 交战因素日志审计兼容层

完成日期：2026-07-05

核心更新：

- 新增 `CombatAuditSummary`，把攻击/防御有效值变化、地形、河流、器械攻城、围城、死守和侧击整理为中文审计片段。
- `CombatRules.effectiveAttack` / `effectiveDefense` 改为读取同一套内部 attack / defense profile，避免战斗计算和日志解释分叉。
- `CommandExecutor` 在攻击和反击日志中追加 `交战审计：...`，并继续保留已有武将攻防修正日志。
- 保持伤害、撤退、反击、占领、动态方面推进、防区推进和武将修正规则不变；本轮只改善交战原因可读性。

关键系统：

- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_combat_factor_log_audit.md`

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

- 本轮只做事件日志审计，不实现发布级战报面板、图标化战斗解释、士气、疲劳或单挑。
- 未做运行时 UI 烟测，事件日志换行、宽度和实际战报可读性仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。

## v2.4 - 太守连通修路兼容层

完成日期：2026-07-05

核心更新：

- `EconomyRules.improveRoad` 保持原有资源成本、基础设施 +1 和每次最多补两格道路的执行边界。
- 修路目标从单纯按高价值 hex 排序，升级为优先从已有官道、外部相邻官道入口或郡县核心出发，补一段连续道路。
- 新增内部 BFS 路径选择与 deterministic 坐标排序，只在当前势力控制、可通行且属于目标郡县的 hex 内规划。
- 找不到连通方案时仍回退到原高价值目标排序，避免合法修路命令无效果。
- 保持太守 Agent 不直接修改 `GameState`；道路和基础设施变化仍只能经 `Command.improveRoad -> CommandValidator -> CommandExecutor -> EconomyRules` 执行。

关键系统：

- `WWIIHexV0/Rules/EconomyRules.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_governor_connected_road_repair.md`

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

- 本轮仍不是完整跨郡县主干路规划；复杂道路网络需要多轮太守修路逐步形成。
- 未做运行时 UI 烟测，事件日志坐标、AI 面板换行和实际道路可读性仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。

## v2.4 - 武将战术塑形兼容层

完成日期：2026-07-05

核心更新：

- `GeneralAgent.plan` 在军师层之后、`WarCommandExecutor` 之前，继续只返回调整后的 `DirectiveEnvelope`，不直接修改 `GameState`。
- 攻势军令会按武将忠诚、满意度、风格和技能快照塑形为合法攻势 tactic：低忠诚/满意度优先佯攻，跨防区协同或会师点优先合围，器械/攻坚技能优先箭雨/器械压制，骑兵/快速 exploitation 风格优先疾袭或突击，突破/反击/进攻规划技能可改用破阵。
- 守势军令会按压力、预备队、风格和防守技能塑形为合法守势 tactic：高压且无纵深预备队可死守，谨慎/防守/参谋/预备队技能优先层层设防，低压且有反击目标的进取武将可诱敌/退守，城防或纪律技能可维持固守。
- 复用现有 `TacticConditionChecker` 过滤机动、器械/远程、预备队等轻量可用性，避免武将把防区改成明显不可执行的 tactic。
- `GeneralDecisionRecord` 记录塑形后的 tactic；rationale 补充武将姓名、忠诚/满意度、风格、技能摘要和最终战术。
- 保持道路机动、攻防数值、交战因素审计、命令校验、执行器和规则引擎边界不变。

关键系统：

- `WWIIHexV0/Agents/GeneralAgent.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_tactic_shaping.md`

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

- 本轮只做 `GeneralAgent` 的 deterministic tactic shaping，不实现完整武将技能树、士气、疲劳、单挑、战报 UI 或真实 LLM。
- 未做运行时 AI 回合或 UI 烟测，武将塑形后的实际日志换行、AI 面板显示和战术效果仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。

## v2.4 - 武将战术 AI 面板审计兼容层

完成日期：2026-07-05

核心更新：

- `AgentPanelView` 的“武将”审计块从只显示武将姓名、动作、防区和攻守类型，扩展为显示最终 tactic、指挥风格、目标郡县和 rationale。
- 缺失 tactic 时显示“未定战术”，缺失风格时显示“未定风格”，无目标 region 时显示“无目标”，保持旧记录兼容。
- rationale 限制最多三行，避免 AI 面板武将块挤压命令结果、防区指令和 raw JSON。
- 保持 `GeneralDecisionRecord` schema、`GeneralAgent` 战术塑形、`WarCommandExecutor`、`RuleEngine` 和战斗计算不变；本轮只改善审计可见性。

关键系统：

- `WWIIHexV0/UI/AgentPanelView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_tactic_audit.md`

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

- 本轮未做运行时 UI 截图或可读性烟测，实际面板换行、窄屏布局和 Dynamic Type 下的显示效果仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 本轮不实现武将头像、技能详情面板、战报图标化或玩家手动下达武将战术。

## v2.4 - 玩家武将宏观军令战术塑形兼容层

完成日期：2026-07-05

核心更新：

- 玩家通过 `GeneralCommandPanelView` 下达“固守战线 / 进攻郡县”宏观军令时，`AppContainer.submitPlayerDirective` 会先把 `ZoneDirective` 包装为单条 `DirectiveEnvelope`，交给 `GeneralAgent.plan` 按防区武将塑形最终 tactic。
- 玩家宏观军令后续执行、`CommandResultSummary`、`WarDirectiveRecord` 和 `PlayerPlannedOperation` 都使用塑形后的 directive；武将复核记录追加到 `GameState.generalRecords`，供 AI 面板和后续审计读取。
- `PlayerPlannedOperation` 新增可选 `tactic` 字段，旧记录缺失时保持 nil 兼容。
- `GeneralCommandPanelView` 的计划军令摘要从“指令 / 目标”扩展为“指令 / 最终战术 / 目标”，便于玩家确认武将对军令的影响。
- 保持微操锁、`WarCommandExecutor -> RuleEngine`、不自动结束玩家回合、不直接改 hex / 军队 / 道路 / 资源的边界不变。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Core/PlayerCommandState.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_player_general_tactic_shaping.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，计划军令列表在窄屏和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- `GeneralAgent` 仍是 deterministic 兼容层；本轮不实现完整武将抗命、技能树、士气、疲劳、单挑或真实 LLM 聊天军令。

## v2.4 - 武将道路与交战面板摘要兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralInfluenceNotes` 复用 `GeneralInfluence.movementSummary`，为当前选中武将防区汇总麾下军队的官道机动加成数量和最高加成。
- 同一派生属性复用 `GeneralInfluence.combatSummary`，只统计当前已进入射程的敌我配对，汇总接敌攻击和防御修正；未接敌时显示后续接战再计算。
- `GeneralCommandPanelView` 新增“道路与交战”只读摘要区，显示道路机动与接敌攻防影响，让玩家不必等移动/攻击日志才知道武将对道路和交战的当前作用。
- `RootGameView` 在 Unit tab 和 General tab 两个现有武将面板入口传入同一套摘要。
- 保持 `GeneralInfluence`、`MovementRules`、`CombatRules`、`WarCommandExecutor`、`RuleEngine` 和状态写入边界不变；本轮只做 UI 可见性和 App 层只读派生。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_influence_panel_summary.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“道路与交战”摘要在窄屏、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 交战摘要只统计当前射程内敌我配对，不做完整战斗预报、伤害预测、士气、疲劳或单挑展示。

## v2.4 - 武将技能中文展示兼容层

完成日期：2026-07-05

核心更新：

- 新增 `GeneralSkillDisplay`，把 `logistics`、`rapid_exploitation`、`cavalry_charge`、`defensive_master`、`siegecraft` 等技能 raw id 显示为粮道调度、疾行追击、骑兵突击、守备专精、攻城术等中文标签。
- `GeneralData.skillDisplayNames` 为 UI 提供中文技能列表，但 `GeneralData.skills` 和 `GeneralAssignment.skills` 仍保留 raw id，避免破坏 JSON、Codable、排序和规则匹配。
- `GeneralCommandPanelView` 和 `GeneralProfileView` 改为显示中文技能标签，不再把 `_` 分隔的开发字段直接展示给玩家。
- `GeneralAgent` 的武将复核 rationale 继续记录技能摘要，但使用中文技能标签，方便 AI 面板审计。
- 保持 `GeneralInfluence`、`MovementRules`、`CombatRules`、`WarCommandExecutor`、`RuleEngine` 和所有技能规则判断不变；本轮只做展示层和审计文字中文化。

关键系统：

- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Agents/GeneralAgent.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_skill_display_labels.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/GeneralProfileView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，技能标签在窄屏、长标签和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 未登记的新技能只做英文 fallback 展示，不会影响规则执行；后续新增技能时应同步补中文标签。

## v2.4 - 武将技能道路与交战效果提示兼容层

完成日期：2026-07-05

核心更新：

- `GeneralSkillDisplay` 新增只读 `effectHint(for:)` 与 `displayNameWithHint(for:)`，在纯中文技能标签之外提供官道机动、骑兵突击、攻城修正、地形/渡河防御等短效果提示。
- `GeneralCommandPanelView` 的武将技能行改为显示前三个“技能名：短效果”，帮助玩家把武将技能和道路/交战摘要联系起来。
- `GeneralProfileView` 的技能卡片保留技能名，同时在卡片内分行显示短效果提示，降低长文本挤压。
- `UnitInspectorView` 的“所属武将”摘要改为显示带短效果提示的前三个技能，让选中军队时能直接看出所属武将可能影响官道机动或接敌攻防。
- 保持 `GeneralData.skills`、`GeneralAssignment.skills`、JSON schema、`GeneralInfluence`、`MovementRules`、`CombatRules`、`CommandExecutor`、`WarCommandExecutor`、`RuleEngine`、真实道路机动、攻防修正、伤害、反击、撤退和日志结算不变；本轮只做 UI 文案解释层和文档同步。

关键系统：

- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_skill_road_combat_effect_hints.md`

验证记录：

- `swiftc -parse WWIIHexV0/Agents/GeneralRegistry.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/GeneralProfileView.swift WWIIHexV0/UI/UnitInspectorView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增技能短效果在窄屏、长技能名、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 短效果只是根据当前规则入口和技能语义给出的只读提示，不代表完整技能树、胜率、士气、疲劳、单挑、隐藏敌军、成长或敌方回合反制。

## v2.4 - 军队接战预判与敌对入口过滤兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 为当前选中军队生成只读接战预判，挑选射程内首个敌对目标，显示预计伤害、是否反击、武将攻防影响和交战审计摘要。
- `UnitInspectorView` 新增“接战预判”小节，复用同一套 `CombatRules` / `GeneralInfluence` 结果，让玩家在执行攻击前就能看到武将和地形等因素的影响。
- 玩家地图点击攻击、单位点击攻击、攻击高亮、武将宏观目标选择和武将面板目标展示统一改用 `Faction.isHostile(to:)`，不再用旧二元 `!= faction` 推断可攻击对象。
- 保持 `CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`RuleEngine`、伤害公式、反击规则、道路规则和状态写入边界不变；本轮只做 UI 预览和输入入口一致性。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/GeneralProfileView.swift WWIIHexV0/UI/UnitInspectorView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，接战预判在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 预判只展示当前射程内首个敌对目标，不实现完整战斗预报、胜负概率、士气、疲劳、单挑或多目标比较。

## v2.4 - 军队道路机动预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitMobilityPreviewNotes` 为当前选中军队生成只读道路机动预判，显示基础机动、有效机动、可达格数、武将官道加成和当前位置/郡县官道状态。
- `UnitInspectorView` 新增“道路机动”小节，并复用同一套 note section 显示“接战预判”，让军队详情能同时呈现道路与交战影响。
- `RootGameView` 将新的只读道路机动派生属性传入军队详情面板。
- 保持 `MovementRules`、`GeneralInfluence`、`CombatRules`、`WarCommandExecutor`、`RuleEngine`、道路移动成本、武将道路加成条件、寻路和敌控区规则不变；本轮只做 UI 预览和 App 层只读派生。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_road_mobility_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/GeneralProfileView.swift WWIIHexV0/UI/UnitInspectorView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，道路机动预判在窄屏、长武将名、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 预判只展示当前规则下的可达格数和官道状态，不实现完整行军路径解释、粮道覆盖图或道路修建路线规划。

## v2.4 - 军队接战目标对比兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 从“射程内首个敌军”升级为最多三名射程内敌军对比，统一计算预计伤害、反击伤害、武将影响、交战审计和距离。
- 接战目标排序改为预计伤害高者优先，伤害相同时反击伤害低者优先，再按距离和名称稳定排序，帮助玩家在执行攻击前判断首选目标。
- 军队详情仍只通过既有“接战预判”小节展示文本；首选目标继续追加武将影响和交战审计，候选目标保持短行，避免面板膨胀。
- 保持 `CombatRules`、`GeneralInfluence`、`MovementRules`、`WarCommandExecutor`、`RuleEngine`、伤害公式、反击规则、武将加成规则和 UI 入参不变；本轮只做 App 层只读派生和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_target_comparison.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/GeneralProfileView.swift WWIIHexV0/UI/UnitInspectorView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，三目标接战预判在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 预判只做当前射程内的目标排序和伤害/反击对比，不实现完整胜负概率、士气、疲劳、单挑、AI 推荐解释或跨回合战斗规划。

## v2.4 - 郡县官道摘要兼容层

完成日期：2026-07-05

核心更新：

- `RegionInspectorState` 增加当前选中地格是否有官道、郡县官道格数和可通行格数等只读字段。
- `MapDisplayAdapter.inspectorState` 从 `RegionNode.displayHexes` 和 `MapState.tile(at:)` 派生官道覆盖，不修改地图、道路、补给或经济状态。
- `RegionInspectorView` 在郡县面板展示“当前官道”和“官道覆盖”，让玩家查看郡县时能直接判断修路、行军和粮道价值。
- 保持 `MovementRules`、`SupplyRules`、`EconomyRules`、`Command.improveRoad`、`CommandValidator`、`RuleEngine`、道路移动成本和太守修路执行逻辑不变；本轮只做 UI 状态派生和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_road_summary.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI / SpriteKit 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/SpriteKit/MapDisplayAdapter.swift WWIIHexV0/UI/RegionInspectorView.swift WWIIHexV0/UI/RootGameView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，郡县面板新增字段在窄屏、长郡县名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 官道摘要只显示当前覆盖数量和选中地格状态，不实现完整粮道覆盖图、修路路线预览、道路价值评分或跨郡县交通网络分析。

## v2.4 - 军队所属武将摘要兼容层

完成日期：2026-07-05

核心更新：

- `UnitInspectorStrategicState` 增加 `GeneralAssignment?` 只读快照，让军队详情能直接知道当前军队所属武将。
- `MapDisplayAdapter.unitInspectorState` 使用与武将影响一致的查找优先级：先找显式包含该军队 id 的 `FrontZone.generalAssignment`，再 fallback 到当前 hex 所属防区武将。
- `UnitInspectorView` 新增“所属武将”摘要，展示武将姓名、风格、忠诚、满意、前三个中文技能和玩家干预次数；无分配时显示“武将：未任命”。
- 保持 `GeneralInfluence`、`GeneralAgent`、`GeneralDispatcher`、`WarCommandExecutor`、`RuleEngine`、武将分配、忠诚满意、道路机动、交战修正和战术塑形规则不变；本轮只做 UI 状态派生和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_general_assignment_summary.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- UI / SpriteKit 相关 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/SpriteKit/MapDisplayAdapter.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/UI/RootGameView.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，“所属武将”摘要在窄屏、长武将名、长技能名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只展示当前武将分配快照，不实现武将任免、头像资产、详细属性、忠诚变化解释或技能效果展开。

## v2.4 - 军队接战剩余兵力预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 的三目标接战预判行增加战后兵力结果，预计攻击后显示敌军剩余兵力。
- 若目标可反击，预判行同时显示反击伤害和我方反击后剩余兵力；无反击时继续显示“无反击”。
- 剩余兵力只用当前 `Division.strength/maxStrength` 与既有 `CombatDamage.strengthDamage` 做只读派生，不写入日志、审计记录或持久状态。
- 保持 `CombatRules`、`GeneralInfluence`、`MovementRules`、`WarCommandExecutor`、`RuleEngine`、伤害公式、反击规则、排序规则和 UI 入参不变；本轮只做接战预览文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_strength_outcome_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“敌余/我余”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 预判只展示单次攻击/反击后的兵力余量，不实现完整胜负概率、士气、疲劳、撤退预测、单挑或跨回合战斗规划。

## v2.4 - 交战日志剩余兵力兼容层

完成日期：2026-07-05

核心更新：

- `CommandExecutor` 的真实攻击日志和反击日志增加结算后剩余兵力，格式为“余 当前/上限”。
- `CombatResultSummary` 私有摘要增加 `remainingStrength` 与 `maxStrength`，让日志能读取真实结算结果；歼灭时记录 `0/maxStrength`。
- 死守、包围撤退等额外损失发生时，余兵显示为额外损失后的最终兵力；日志仍保留“额外兵力 -X”“触发自动撤退”“被歼灭”等既有审计片段。
- 保持 `CombatRules`、`GeneralInfluence`、`MovementRules`、`WarCommandExecutor`、`RuleEngine`、伤害公式、反击规则、撤退规则和状态写入边界不变；本轮只做事件日志文案和文档同步。

关键系统：

- `WWIIHexV0/Rules/CommandExecutor.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_combat_log_strength_outcome.md`

验证记录：

- 规则/核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，事件日志中新增“余 当前/上限”在日志面板窄宽、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 日志只展示单次攻击/反击结算后的兵力余量，不实现完整胜负概率、士气、疲劳、撤退路径预测、单挑或跨回合战斗规划。

## v2.4 - 军队接战风险预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 的三目标接战预判进一步贴近真实结算，敌方剩余兵力改为按基础伤害、死守额外损失和断粮撤退额外损失后的只读预估值展示。
- 预判行新增中文风险片段：可能撤退、死守额外损失约值、断粮撤退额外损失约值和可能歼灭。
- 若目标预估会撤退或被歼灭，反击提示改为“预计无反击”，避免继续把不会发生的反击伤害展示成确定风险。
- 若目标仍能反击，我方反击后剩余兵力也使用同一套只读风险估算，并在需要时提示我方可能撤退或被歼。
- 保持 `CombatRules`、`CommandExecutor`、`SupplyRules`、`WarCommandExecutor`、`RuleEngine`、真实伤害、撤退路径、撤退失败、死守、歼灭和日志写入逻辑不变；本轮只做单位详情接战预判文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_risk_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增风险片段在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 预判不计算撤退目的地、撤退失败惩罚、士气、疲劳、单挑或跨回合围攻概率；真实结果仍以 `CommandExecutor` 结算日志为准。

## v2.4 - 军队可达官道预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitMobilityPreviewNotes` 复用 `MovementRules.movementRange` 的本回合可达格，额外统计可达官道格数。
- 道路机动预判新增“可达官道”摘要：显示本回合可进入的官道总数、未受敌控区压迫的安全官道格数，以及受敌控区压迫的官道格数。
- 若军队当前不在官道且本回合无法抵达官道，显示“本回合尚不能接入官道”，让玩家更容易判断是否需要调整行军或等待修路。
- 保持 `MovementRules`、`CommandExecutor`、`Command.improveRoad`、`CommandValidator`、`RuleEngine`、太守修路、真实移动成本、敌控区停止规则、粮道和战略同步不变；本轮只做军队详情道路机动预判文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_reachable_road_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“可达官道”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 预判只统计本回合可达官道，不计算跨回合道路接入计划、完整补给线安全、修路收益或多势力借道/同盟通行。

## v2.4 - 军队接战目标态势预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 的三目标接战预判行新增“态势”片段，显示目标地形、据城/据关、临官道、粮道短名和撤退姿态短码。
- 目标态势复用 `HexTile`、`SupplyState` 和 `RetreatMode` 的现有只读字段，不新增规则状态、不写日志、不修改持久数据。
- 预判行保留预计伤害、结算后敌我剩余兵力、撤退/歼灭风险、反击风险和距离排序，让玩家能同时看到数值结果和目标防守环境。
- 保持 `CombatRules`、`CommandExecutor`、`SupplyRules`、`MovementRules`、`WarCommandExecutor`、`RuleEngine`、真实伤害、防御、反击、撤退、围城、粮道、道路和地形规则不变；本轮只做军队详情接战预判文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_target_stance_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“态势”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 态势摘要只展示当前格和目标自身状态，不解释完整伤害公式；完整目标评分、AI 推荐、胜率和多回合围攻计划仍待后续版本。

## v2.4 - 军队接战首选理由预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 在三目标接战对比前新增“首选理由”摘要，说明当前首选目标来自多少支射程内敌军对比。
- 首选理由复用既有只读伤害和风险估算，显示预计伤害、敌方战后余兵、可能撤退/歼灭、反击风险和距离。
- 三目标候选行、目标态势、撤退/死守/断粮风险、武将影响和交战审计保持原有显示。
- 保持 `CombatRules`、`CommandExecutor`、`SupplyRules`、`MovementRules`、`WarCommandExecutor`、`RuleEngine`、真实伤害、防御、反击、撤退、围城、粮道、道路和地形规则不变；本轮只做军队详情接战预判解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_target_priority_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“首选理由”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 首选理由不是胜率，不计算撤退目的地、撤退失败、士气、疲劳、单挑或跨回合围攻计划；真实结果仍以 `CommandExecutor` 结算日志为准。

## v2.4 - 军队接战官道压制预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 在首选理由后新增“接战官道”摘要，把道路机动与首选目标交战判断连起来。
- 摘要复用 `MovementRules.movementRange` 和 `isEnemyZoneOfControl`，统计本回合可从多少个官道位置压制首选目标，并拆分安全官道位与受敌控区压迫的官道位。
- 若当前没有可用官道压制位，会明确显示“无可用官道压制位”；若我方或目标当前在官道，也会补充对应片段。
- 保持 `MovementRules`、`CombatRules`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实移动成本、敌控区停止、道路加成、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情接战预判解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_road_approach_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“接战官道”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只看本回合可达官道压制位，不计算最佳路径、跨回合道路计划、完整粮道安全、同盟借道通行或真实胜率；真实结果仍以 `CommandExecutor` 结算日志为准。

## v2.4 - 军队接战武将对阵预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 在首选理由和接战官道之后新增“交战武将”摘要，显示首选目标接战中的我方武将和敌方武将。
- 摘要复用 `GeneralCombatInfluenceSummary` 已有的 `attackerGeneralName/id` 与 `defenderGeneralName/id`，和真实武将攻防修正使用同一套查找来源。
- 若一侧缺少武将分配，会显示“未任命”；若双方都没有武将分配，则不额外显示该行，避免噪声。
- 保持 `GeneralInfluence`、`CombatRules`、`MovementRules`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实武将加成、伤害、防御、反击、撤退、围城、道路和粮道规则不变；本轮只做军队详情接战预判解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_general_matchup_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“交战武将”文本在窄屏、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只展示当前首选接战双方的武将快照，不实现任免、头像、技能详情、士气、单挑或忠诚变化解释。

## v2.4 - 军队接战候选敌将预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 的最多三条接战候选目标行新增敌将身份提示；当候选目标防守方存在武将 name/id 时，候选行追加 `敌将 ...`。
- 候选敌将摘要复用每个 `CombatTargetPreview.influence` 中的 `defenderGeneralName/id`，和真实武将防御修正使用同一套查找来源。
- 保留首选目标已有“交战武将”总览、非零“武将影响”摘要、接战官道、强度结算、风险、态势和交战审计。
- 保持 `GeneralInfluence`、`CombatRules`、`MovementRules`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实武将加成、伤害、防御、反击、撤退、围城、道路和粮道规则不变；本轮只做军队详情接战候选解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_candidate_general_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“敌将 ...”候选文本在窄屏、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只展示候选目标防守方武将身份，不实现任免、头像、技能详情、士气、单挑或忠诚变化解释。

## v2.4 - 军队接战候选武将修正预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 的最多三条接战候选目标行新增非零武将攻防修正提示，显示为 `武将修正 攻+... 防+...`。
- 候选武将修正摘要复用每个 `CombatTargetPreview.influence` 中的 `attackBonus` 与 `defenseBonus`，和真实 `CombatRules` 武将攻防修正使用同一套来源。
- 两项修正均为 0 时不追加额外文本，避免候选行无意义膨胀；首选目标仍保留已有“交战武将”总览和非零“武将影响”详情。
- 保持 `GeneralInfluence`、`CombatRules`、`MovementRules`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实武将加成、伤害、防御、反击、撤退、围城、道路和粮道规则不变；本轮只做军队详情接战候选解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_candidate_general_modifier_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“武将修正 ...”候选文本在窄屏、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只展示候选目标当前攻防修正数值，不解释完整技能、忠诚、满意、士气、单挑或武将成长。

## v2.4 - 军队接战候选交战审计预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 的最多三条射程内候选目标行各自显示本候选目标的 `CombatAuditSummary.logFragment`。
- 候选交战审计复用 `CombatRules.combatAuditSummary(attacker:defender:in:)`，与真实交战日志同源，显示有效攻击/防御变化、地形、河流、器械攻城、围城、死守和侧击等因素。
- 移除原先只对首选目标额外追加的一条独立交战审计，避免首选目标重复显示；首选目标仍保留非零武将影响详情。
- 保留已完成的首选理由、接战官道、交战武将、候选敌将、候选武将修正、强度结算、风险、态势、候选数量提示和换行逻辑。
- 保持 `CombatRules`、`MovementRules`、`GeneralInfluence`、`CommandValidator`、`CommandExecutor`、`WarCommandExecutor`、`RuleEngine`、真实伤害、反击、撤退、围城、道路、粮道、命令执行和日志结算不变；本轮只做军队详情接战预判只读反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_candidate_audit_preview.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，前三个候选目标行追加交战审计后，在窄屏、长军队名、长因素列表和 Dynamic Type 下的实际高度与滚动体验仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 候选交战审计只读展示当前静态交战因素，不代表完整胜率、路径安全、隐藏敌军、同盟借道、移动后同回合攻击或敌方回合反制。

## v2.4 - 军队未接敌时接近距离与官道预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 先统一收集敌对军队距离；射程内仍走既有三目标接战预判。
- 当当前射程内没有敌军但地图上存在敌军时，接战预判会显示最近敌军、当前距离、军队射程和需接近格数，避免玩家在未接敌阶段看到空白接战信息。
- 新增“官道接近”摘要：复用 `MovementRules.movementRange` 和 `isEnemyZoneOfControl`，统计可达范围内能缩短到最近敌军距离的官道格、最近距离、安全数量和受敌控区数量，并标出我方/目标是否临官道。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实移动成本、敌控区停止、道路加成、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情接近预判解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_combat_approach_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“接战距离/官道接近”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只做当前位置的只读接近判断，不模拟移动后同回合攻击、跨回合追击、完整路径安全、同盟借道或真实胜率。

## v2.4 - 军队未接敌时接近武将预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.combatOutOfRangePreviewNotes` 在最近敌军接近预判中补充 `接近武将` 摘要，显示当前位置下我方军队和最近敌军对应的武将身份。
- 摘要复用 `CombatRules.generalInfluenceSummary` 的 `attackerGeneralName/id` 与 `defenderGeneralName/id`；若一侧缺少分配，显示“未任命”，双方均无武将时不显示该行。
- 当最近敌军存在非零武将攻防修正时，追加 `接近参考：武将修正 ...`，复用同一 `GeneralCombatInfluenceSummary.attackBonus/defenseBonus`。
- 保持 `GeneralInfluence`、`CombatRules`、`MovementRules`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实武将加成、移动成本、敌控区、道路加成、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情未接敌接近预判解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_general_approach_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“接近武将/接近参考”文本在窄屏、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只做当前位置对最近敌军的只读武将参考，不模拟移动后同回合攻击、跨回合追击、完整路径安全、同盟借道或真实胜率。

## v2.4 - 军队未接敌时官道接战距离预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.combatOutOfRangeRoadApproachText` 在“官道接近”摘要中补充抵达官道后的射程判断。
- 当本回合可达、更接近最近敌军的官道位中存在入射程位置时，显示 `... 个抵达后入射程`；若没有，则显示最近官道位 `仍差 ... 格入射程`。
- 摘要继续保留可达更近官道位、最近距离、安全官道、受敌控区官道、我方在官道和目标临官道等既有信息。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实移动成本、敌控区、道路加成、射程、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情未接敌官道接近预判解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_road_engagement_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“抵达后入射程 / 仍差 ... 格入射程”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只做当前位置到最近敌军的只读官道接近距离判断，不模拟移动后同回合攻击、跨回合追击、完整路径安全、同盟借道或真实胜率。

## v2.4 - 军队未接敌时最近敌军态势预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.combatOutOfRangePreviewNotes` 在最近敌军接近预判中补充 `接近态势` 摘要。
- 摘要复用既有 `combatTargetStanceText(for:)`，与射程内候选目标行使用同一套只读态势来源，显示目标地形、据城/据关、临官道、粮道状态和撤退姿态。
- 保留既有接战距离、接近武将、接近参考、官道接近和官道入射程判断；射程内存在敌军时仍走既有三目标接战预判。
- 保持 `HexTile`、`SupplyState`、`RetreatMode`、`MovementRules`、`CombatRules`、`GeneralInfluence`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实移动、道路、射程、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情未接敌最近敌军态势解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_stance_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“接近态势”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只读展示当前最近敌军的站位状态，不模拟移动后同回合攻击、跨回合追击、完整路径安全、同盟借道或真实胜率。

## v2.4 - 军队未接敌时敌方射程威胁预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.combatOutOfRangePreviewNotes` 在最近敌军接近预判中补充 `接近威胁` 摘要。
- 新增只读 `combatOutOfRangeThreatText`，读取最近敌军射程、当前双方距离和 `MovementRules.movementRange`，显示我方当前是否已在敌方射程内，或当前距敌方射程还有几格。
- 当本回合可达且更接近最近敌军的位置会进入敌方射程时，摘要显示对应可达接近位数量，帮助玩家判断靠近弓弩/器械/远程敌军的风险。
- 保留既有接战距离、接近武将、接近参考、接近态势、官道接近和官道入射程判断；射程内存在敌军时仍走既有三目标接战预判。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实移动、道路、射程、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情未接敌敌方射程威胁解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_threat_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“接近威胁”文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只读展示当前静态射程威胁，不模拟敌方下回合 AI 行动、完整路径安全、同盟借道或真实胜率。

## v2.4 - 军队未接敌时接近候选预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.combatOutOfRangePreviewNotes` 在当前射程内没有敌军、但地图上存在多支敌军时补充 `接近候选` 摘要。
- 新增只读 `combatOutOfRangeCandidateText`，按距离、军队名称和 id 稳定排序，最多展示三支最近敌军。
- 每个接近候选显示目标军队、当前距离、需接近格数、敌方射程，并在候选防守方有武将分配时显示敌将姓名或 id。
- 保留既有最近敌军详细预判、接近武将、接近参考、接近态势、接近威胁、官道接近和官道入射程判断；射程内存在敌军时仍走既有三目标接战预判。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实移动、道路、射程、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情未接敌接近候选解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_candidate_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“接近候选”文本在窄屏、长军队名、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只读展示当前静态接近候选，不模拟敌方下回合 AI 行动、完整路径安全、同盟借道或真实胜率。

## v2.4 - 军队未接敌时接近候选路况与风险预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.combatOutOfRangePreviewNotes` 在未接敌分支中只计算一次 `MovementRules.movementRange`，供最近敌军威胁、官道接近和候选摘要复用。
- `AppContainer.combatOutOfRangeCandidateText` 的每个接近候选追加本回合可达接近摘要：最近可达距离、是否可入我方射程、是否存在安全官道或受压官道，以及接近位是否会进入敌方射程。
- 新增 `combatOutOfRangeCandidateApproachDetails`，只读筛选可达且能缩短到候选目标距离的格子；无可达接近位时显示 `无可近位`。
- 保留既有最近敌军详细预判、接近武将、接近参考、接近态势、接近威胁、官道接近和官道入射程判断；射程内存在敌军时仍走既有三目标接战预判。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`CommandExecutor`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、真实移动、道路、射程、伤害、防御、反击、撤退、围城和粮道规则不变；本轮只做军队详情未接敌接近候选路况与风险解释文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_out_of_range_candidate_road_risk_preview.md`

验证记录：

- 核心 Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增“可达距 / 安全官道 / 官道受压 / 入敌射”候选文本在窄屏、长军队名、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只读展示当前静态可达格、官道和射程关系，不模拟敌方下回合 AI 行动、完整路径安全、同盟借道、移动后同回合攻击或真实胜率。

## v2.4 - 地图计划军令武将战术标识兼容层

完成日期：2026-07-05

核心更新：

- `BoardScene.drawPlannedOperations` 在玩家当前回合计划军令地图层补充源点、目标点和短标签。
- 进攻计划继续显示源 region 到目标 region 的箭头，并在箭头中点附近显示武将/攻/短战术标签；防御计划继续显示固守圆环，并在圆环上方显示武将/守/短战术标签。
- 标签优先读取 `FrontZone.generalAssignment.generalDisplayName`，无武将名时退回 `PlayerPlannedOperation.createdByGeneralId` 或仅显示攻守/战术。
- 战术标签使用短名收束，例如箭雨、奇袭、诱敌、设防，避免地图标识过宽。
- 保持 `PlayerCommandState` schema、`GeneralAgent`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给、微操锁和计划军令面板列表行为不变；本轮只做 SpriteKit 地图只读反馈和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_map_planned_operation_tactic_labels.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/BoardScene.swift` 通过。
- 核心 + SpriteKit/UI Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/*.swift WWIIHexV0/UI/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，多个计划箭头相互靠近、长武将名、长战术名和小屏缩放下的实际重叠情况仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 地图标识只读展示已记录的计划态势，不模拟完整路径、真实胜率、移动后同回合攻击、敌方下回合反制或外交借道。

## v2.4 - 地图计划军令官道与受压标识兼容层

完成日期：2026-07-05

核心更新：

- `BoardScene.drawPlannedOperations` 在玩家当前回合计划军令标签中追加源/目标锚点的官道与受压短摘要。
- 进攻计划按源/目标代表 hex 显示 `双道`、`源道`、`目道` 或 `无道`；防御计划按源点显示 `据道` 或 `离道`。
- 源/目标锚点距离敌对且未毁灭军队 0 或 1 格时追加 `/受压`；敌对判断使用 `Faction.isHostile(to:)`，不退回旧二元 `!= faction`。
- 源/目标锚点附近新增小路况点：官道为金色，离道为深色，受压时使用红色描边。
- 保持 `PlayerCommandState` schema、`MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给、微操锁和计划军令面板列表行为不变；本轮只做 SpriteKit 地图源/目标代表 hex 的只读路况反馈和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_map_planned_operation_road_pressure_tags.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/BoardScene.swift` 通过。
- 核心 + SpriteKit/UI Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/*.swift WWIIHexV0/UI/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，多个计划箭头靠近、长标签和小屏缩放下的实际重叠情况仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 标识只读展示源/目标代表 hex，不代表完整行军路径全程安全，不模拟移动后同回合攻击、敌方回合反制、同盟借道或真实胜率。

## v2.4 - 武将面板计划军令官道与受压摘要兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralPlannedOperationRows` 基于本回合 `PlayerPlannedOperation` 生成武将面板计划军令摘要。
- 摘要优先显示防区武将姓名，继续显示指令类型、最终战术和目标名称，并追加源/目标代表 hex 的官道状态与敌军压迫状态。
- 进攻计划摘要显示 `双道`、`源道`、`目道` 或 `无道`，并按源/目标代表 hex 显示 `源目受压`、`源受压` 或 `目受压`；防御计划显示 `据道` 或 `离道`，受压时显示 `据点受压`。
- 敌军压迫判断继续使用 `Faction.isHostile(to:)`，只统计未毁灭且距离源/目标代表 hex 0 或 1 格的敌对军队。
- `GeneralCommandPanelView` 只消费 `AppContainer` 生成的摘要行，不在 SwiftUI View 内直接推导道路、敌军压迫或 region 名称。
- 保持 `PlayerPlannedOperation` schema、`MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做计划军令面板的只读反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_road_pressure_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/RootGameView.swift` 通过。
- 核心 + SpriteKit/UI Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/*.swift WWIIHexV0/UI/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，计划军令摘要新增武将名、目标名、官道和受压文本后，在窄屏、长武将名、长战术名、长郡县名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 摘要只读展示源/目标代表 hex，不代表完整行军路径全程安全，不模拟移动后同回合攻击、敌方回合反制、同盟借道或真实胜率。

## v2.4 - 武将面板计划军令源目与敌距摘要兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralPlannedOperationRows` 的计划军令摘要从单一目标名扩展为源→目标路线。
- 进攻计划优先显示 `源郡县→目标郡县`，防御计划显示源郡县或防区名，帮助玩家确认该武将军令从哪里出发、往哪里压。
- 摘要保留武将、指令类型、最终战术、官道状态和源/目标受压文本，并追加当前静态最近敌距。
- 有源和目标时显示 `敌距 源N/目M`；只有源点时显示 `近敌 N`。
- 最近敌距只统计 `Faction.isHostile(to:)` 判定为敌对且未毁灭的军队，读取当前军队坐标和源/目标代表 hex 距离。
- `GeneralCommandPanelView` 将计划军令行显示上限从 3 行调整为 4 行，降低源→目标、官道和敌距文本被截断的概率。
- 保持 `PlayerPlannedOperation` schema、`MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做计划军令面板的只读源目/敌距反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_route_enemy_distance_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift` 通过。
- 核心 + SpriteKit/UI Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/*.swift WWIIHexV0/UI/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，计划军令摘要新增源→目标和敌距后，在窄屏、长武将名、长战术名、长郡县名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 敌距摘要只读展示源/目标代表 hex 到最近敌军的当前静态距离，不代表完整行军路径全程安全，不模拟移动后同回合攻击、敌方回合反制、同盟借道或真实胜率。

## v2.4 - 武将面板计划军令换行兼容层

完成日期：2026-07-05

核心更新：

- `GeneralCommandPanelView` 的“计划军令”行取消固定 4 行截断，改为按内容纵向展开。
- 计划军令摘要继续显示既有武将、最终战术、源→目标、官道状态、源目受压和最近敌军对象/距离，图标和 `plannedOperationRows` tuple/API 保持不变。
- 面板本身已位于 `RootGameView` 的 `ScrollView` 内，长摘要通过现有滚动承接，不新增滚动容器。
- 保持 `AppContainer.selectedGeneralPlannedOperationRows`、`PlayerPlannedOperation` schema、`MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做计划军令面板只读可读性修正和文档同步。

关键系统：

- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_wrapping.md`

验证记录：

- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，计划军令行放开截断后在窄屏、长武将名、长战术名、长郡县名、长军队名和 Dynamic Type 下的实际高度与滚动体验仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该改动只影响 `GeneralCommandPanelView` 文本展示，不代表完整行军路径安全、隐藏敌军、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 军队详情道路机动与接战预判换行兼容层

完成日期：2026-07-05

核心更新：

- `UnitInspectorView.noteSection` 新增 `lineLimit` 参数，默认仍保持 2 行上限。
- “道路机动”和“接战预判”调用点传入不限行，让长道路、官道接近、敌射威胁、武将对阵、候选目标和风险摘要按内容纵向展开。
- “所属武将”等默认 note section 仍保持 2 行上限，避免短摘要无意膨胀。
- 保持 `AppContainer.selectedUnitMobilityPreviewNotes`、`selectedUnitCombatPreviewNotes`、`MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做军队详情面板只读可读性修正和文档同步。

关键系统：

- `WWIIHexV0/UI/UnitInspectorView.swift`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_inspector_road_combat_note_wrapping.md`

验证记录：

- `swiftc -parse WWIIHexV0/UI/UnitInspectorView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，军队详情“道路机动”和“接战预判”放开截断后在窄屏、长军队名、长武将名、长敌将名和 Dynamic Type 下的实际高度与滚动体验仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该改动只影响 `UnitInspectorView` 文本展示，不代表完整路径安全、攻击合法性、隐藏敌军、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 军队可达官道距离预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.reachableRoadAccessNote` 在已有本回合可达官道总数、安全/受压数量基础上，追加最近可达官道距当前军队的 hex 距离。
- 若存在未受敌控区压迫的可达官道，同一摘要追加最近安全官道距离；若所有可达官道均受压，则保留安全 0 格和敌控压迫数量。
- 该距离只在 `MovementRules.movementRange` 已判定可达的官道集合内计算，不新增路径规划、不改变移动成本、不推断跨回合接道计划。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做军队详情道路机动预判文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_reachable_road_distance_preview.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `rg -n "[[:blank:]]+$" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/prompt/README.md md/prompt/v2.0-三国迁移/v2.4_unit_reachable_road_distance_preview.md WWIIHexV0/App/AppContainer.swift` 无命中。
- `rg -n "^(<<<<<<<|=======|>>>>>>>)" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/prompt/README.md md/prompt/v2.0-三国迁移/v2.4_unit_reachable_road_distance_preview.md WWIIHexV0/App/AppContainer.swift` 无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md` 无命中。
- `git diff --check` 通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，军队详情“道路机动”新增距离文本在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该摘要只读展示当前 hex 到本回合可达官道 hex 的距离，不代表完整路径安全、真实移动成本、隐藏敌军、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 军队当前官道受压预判兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitMobilityPreviewNotes` 在选中军队当前位于官道时，不再只显示“当前位置：已在官道”，而是追加当前官道是否受敌控区压迫。
- 新增私有 `currentRoadStatusNote(for:movementRules:)`，复用 `MovementRules.isEnemyZoneOfControl` 和既有 `Faction.isHostile(to:)` 敌对口径，只读判断当前位置是否受 hostile 敌军邻接压迫。
- 当前不在官道时保留既有郡县官道数量或暂无官道文案；本回合可达官道安全/受压统计保持不变。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做军队详情道路机动预判文案和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_current_road_pressure_preview.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `rg -n "[[:blank:]]+$" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/prompt/README.md md/prompt/v2.0-三国迁移/v2.4_unit_current_road_pressure_preview.md WWIIHexV0/App/AppContainer.swift` 无命中。
- `rg -n "^(<<<<<<<|=======|>>>>>>>)" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/prompt/README.md md/prompt/v2.0-三国迁移/v2.4_unit_current_road_pressure_preview.md WWIIHexV0/App/AppContainer.swift` 无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md` 无命中。
- `git diff --check` 通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，军队详情当前官道受压文案在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该摘要只读展示当前 hex 的 hostile 邻接压迫，不代表完整路径安全、隐藏敌军、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 武将面板当前接敌配对摘要兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralInfluenceNotes` 在当前选中武将防区已接敌时，追加一条当前接敌配对摘要。
- 新增私有 `engagementPairingText`，复用 `GeneralInfluence.combatSummary(attacker:defender:in:)`，只读显示当前射程内的攻/防配对、对应攻防修正和 hex 距离，例如 `接敌配对：曹骑兵军 -> 袁步卒营，攻+1，距 1 格`。
- 配对选择继续沿用 `Faction.isHostile(to:)` 敌对口径，并排除已毁灭敌军；多个配对同时存在时，优先非零修正，再按修正幅度、距离、攻防方向、军队名和 id 稳定选择。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence` 规则结果、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做武将面板只读反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_engagement_pairing_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `rg -n "[[:blank:]]+$" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/prompt/README.md md/prompt/v2.0-三国迁移/v2.4_general_panel_engagement_pairing_summary.md WWIIHexV0/App/AppContainer.swift` 无命中。
- `rg -n "^(<<<<<<<|=======|>>>>>>>)" README.md update_log.md md/flow/flow.md md/flow/flowchart.md md/prompt/README.md md/prompt/v2.0-三国迁移/v2.4_general_panel_engagement_pairing_summary.md WWIIHexV0/App/AppContainer.swift` 无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md` 无命中。
- `git diff --check` 通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，道路与交战摘要新增接敌配对后，在窄屏、长军队名、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该摘要只读展示当前静态射程内配对，不代表完整路径安全、隐藏敌军、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 武将面板道路与交战摘要换行兼容层

完成日期：2026-07-05

核心更新：

- `GeneralCommandPanelView` 的“道路与交战”摘要行取消固定 3 行截断，改为按内容纵向展开。
- 道路与交战摘要继续显示既有道路机动、官道受益军队、接敌攻防、当前接敌配对、最近敌军对象和麾下备战文本，图标和 `influenceNotes` API 保持不变。
- 面板本身已位于 `RootGameView` 的 `ScrollView` 内，长摘要通过现有滚动承接，不新增滚动容器。
- 保持 `AppContainer.selectedGeneralInfluenceNotes`、`GeneralInfluence`、`MovementRules`、`CombatRules`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做武将面板只读可读性修正和文档同步。

关键系统：

- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_road_combat_note_wrapping.md`

验证记录：

- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，道路与交战摘要放开截断后在窄屏、长武将名、长军队名和 Dynamic Type 下的实际高度与滚动体验仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该改动只影响 `GeneralCommandPanelView` 文本展示，不代表完整行军路径安全、隐藏敌军、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 武将面板道路与交战近敌摘要兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralInfluenceNotes` 在当前选中武将防区的道路与交战摘要中追加最近敌军对象。
- 最近敌军摘要显示最近敌对军队、当前 hex 距离，以及与该敌军最近的麾下军队，例如 `近敌 袁骑兵军 2 距 3 格（曹步卒营 1）`。
- 当前未接敌时，交战行会显示近敌对象并保留“进入射程后计算武将攻防”的提示；当前接敌时，交战行保留攻击/防御修正范围并追加近敌对象。
- 敌军过滤继续使用 `Faction.isHostile(to:)`，只统计未毁灭敌对军队；近敌距离只读使用当前军队坐标，不模拟路径、胜率或敌方回合反制。
- `GeneralCommandPanelView` 将“道路与交战”摘要行显示上限从 2 行调整为 3 行，降低近敌对象和接敌修正文案被截断的概率。
- 保持 `MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和计划军令行为不变；本轮只做武将面板只读反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_nearest_enemy_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift` 通过。
- 核心 + SpriteKit/UI Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/*.swift WWIIHexV0/UI/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，道路与交战摘要新增近敌对象后，在窄屏、长军队名、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 近敌摘要只读展示当前静态最近敌对军队和距离，不代表完整行军路径安全、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 武将面板计划军令近敌对象摘要兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralPlannedOperationRows` 的计划军令摘要继续保留武将、指令类型、最终战术、源→目标、官道状态和源/目标受压文本，并将最近敌距从纯数字升级为最近敌军对象 + 距离。
- `plannedOperationEnemyDistanceText(for:)` 现在会显示源/目标代表 hex 对应的近敌对象，例如 `近敌：源袁骑兵军距2格/目袁步卒营距1格`。
- 最近敌军继续只统计 `Faction.isHostile(to:)` 判定为敌对且未溃散的军队，并按距离、军队展示名和 id 稳定选择，避免摘要抖动。
- 保持 `PlayerPlannedOperation` schema、`GeneralCommandPanelView` API、`MovementRules`、`CombatRules`、`GeneralInfluence`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、真实移动、道路、交战、补给和微操锁规则不变；本轮只做计划军令面板只读近敌对象反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_planned_operation_nearest_enemy_identity_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，计划军令近敌对象摘要在窄屏、长武将名、长战术名、长郡县名、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 近敌对象摘要只读展示源/目标代表 hex 到当前最近 hostile 军队的静态距离，不代表完整行军路径安全、隐藏敌军、同盟借道、移动后同回合攻击、敌方回合反制或真实胜率。

## v2.4 - 军队接战无敌对空状态兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 在当前选中军队没有任何未溃散 hostile 敌对军队时，返回“接战：当前无可预判敌对军队”空状态。
- `UnitInspectorView` 继续通过既有“接战预判”小节展示该只读 notes，不新增参数、不改 UI API。
- 当存在 hostile 敌对军队但未入射程时，保留既有最近敌军、接近候选、接近武将、接近态势、威胁和官道接近预判；射程内存在敌对军队时仍走既有多目标接战预判。
- 保持 `Faction.isHostile(to:)`、`CombatRules`、`MovementRules`、`GeneralInfluence`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮草、撤退、补给和计划军令行为不变；本轮只做军队详情接战预判空状态和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_no_hostile_empty_state.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，军队详情“接战预判”空状态在窄屏和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该空状态只读表示当前没有 hostile 目标可用于接战预判，不代表完整外交关系、隐藏敌军、未来回合威胁、路径安全、移动后同回合攻击或真实胜率。

## v2.4 - 武将面板官道受益军队摘要兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralInfluenceNotes` 在当前选中武将防区已有道路汇总后追加“道路受益”只读摘要，列出实际获得官道机动加成的麾下军队。
- 摘要继续复用 `GeneralInfluence.movementSummary(for:in:)`，按 `roadBonus` 从高到低、再按军队 id 排序，最多显示前三支受益军队和加成值；超过三支时追加“另 N 支”。
- 无官道机动加成时保持原有“当前麾下军队未获得官道机动加成”文案，不新增空摘要行。
- 保持 `GeneralInfluence`、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮草、撤退、补给和计划军令行为不变；本轮只做武将面板只读官道受益反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_road_benefit_units_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，武将面板“道路受益”摘要在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该摘要只读展示当前武将麾下军队已经获得的官道机动加成，不代表完整路径安全、真实可达路径、敌控区绕行、同盟借道、移动后同回合攻击或未来回合机动。

## v2.4 - 武将面板官道无加成原因提示兼容层

完成日期：2026-07-05

核心更新：

- `AppContainer.selectedGeneralInfluenceNotes` 在当前选中武将防区没有任何麾下军队获得官道机动加成时，追加一条“道路受益”只读原因提示。
- 原因提示优先解释忠诚/满意不足导致官道机动暂未触发；若武将状态足够，则区分当前所在郡县无可借官道，或需要军队进驻官道/依赖粮道、疾行、骑战类技能借郡县官道。
- 有官道机动加成时继续显示既有受益军队列表，不追加无加成原因噪声。
- 保持 `GeneralInfluence`、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮草、撤退、补给和计划军令行为不变；本轮只做武将面板只读原因反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_road_no_bonus_reason.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，武将面板无官道加成原因提示在窄屏、长军队名、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该提示只读解释当前静态状态，不代表完整路径安全、真实可达路径、敌控区绕行、同盟借道、移动后同回合攻击或未来回合机动。

## v2.4 - 武将面板麾下军队备战摘要兼容层

完成日期：2026-07-05

核心更新：

- `GeneralCommandPanelView` 的“麾下军队”列表从单纯军队名扩展为兵力、粮草、军令和行动状态短摘要。
- 短摘要复用现有 `Division.thematicDisplayName`、`SupplyState.shortDisplayName`、`RetreatMode.shortDisplayCode` 和 `Division.canAct` 等只读字段，显示如 `兵 8/12，粮 足，令 守，可动`。
- 当麾下军队超过当前展示上限时追加“另有 N 支麾下军队”，避免列表被 `prefix(5)` 静默截断。
- 保持 `AppContainer.selectedGeneralInfluenceNotes`、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮草、撤退、补给和计划军令行为不变；本轮只做武将面板只读备战反馈和文档同步。

关键系统：

- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_assigned_unit_readiness_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，麾下军队短摘要在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该摘要只读展示当前兵力、粮草、军令和行动状态，不代表完整道路机动、伤害胜率、路径安全、攻击合法性、隐藏敌军推断或敌方回合反制。

## v2.4 - 郡县检查器武将与接战摘要兼容层

完成日期：2026-07-05

核心更新：

- `RegionInspectorState` 新增 `friendlyGeneralSummaries` 和 `visibleEnemyEngagementSummaries`，用于郡县检查器只读展示本郡己方军队对应武将，以及可见敌军距离/射程/兵力/敌将态势。
- `MapDisplayAdapter.inspectorState` 复用现有 `GeneralAssignment` 快照，从己方军队派生本郡武将摘要；可见敌军接战摘要只来自当前郡县内可见、未溃散且 hostile 的军队，锚点优先使用选中 hex，否则使用郡县代表 hex。
- `RegionInspectorView` 新增“本郡武将”和“敌军接战”行，方便玩家在郡县层同时判断谁在守、敌军离当前地格或郡县核心有多近、是否已处于敌军射程内。
- 保持 `MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮道和补给规则不变；本轮只做郡县检查器只读反馈和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_general_engagement_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/MapDisplayAdapter.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/RegionInspectorView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，郡县检查器新增“本郡武将”和“敌军接战”多行摘要后，在窄屏、长军队名、长武将名、长敌将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 敌军接战摘要只读展示当前可见 hostile 军队相对锚点的距离、射程态势、兵力和敌将，不代表完整攻击合法性、伤害胜率、路径安全、隐藏敌军推断、同盟借道、移动后同回合攻击或敌方回合反制。

## v2.4 - 郡县检查器官道受压摘要兼容层

完成日期：2026-07-05

核心更新：

- `RegionInspectorState` 新增 `pressuredRoadHexCount`，用于郡县检查器只读展示当前郡县官道受压数量。
- `MapDisplayAdapter.inspectorState` 统计当前 region 内 `hasRoad` 的官道格，并只用当前 viewer 可见、未毁灭且 hostile 的军队作为压迫来源，避免不可见敌军通过郡县面板泄漏。
- `RegionInspectorView.roadSummary` 将“官道覆盖”从单纯覆盖数扩展为覆盖数 + `受压 N` / `未受压` 摘要，服务修路、行军、粮道和接战态势判断。
- 保持 `MovementRules.isEnemyZoneOfControl`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮道和补给规则不变；本轮只做郡县检查器只读反馈和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_hostile_road_pressure_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/MapDisplayAdapter.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/RegionInspectorView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，郡县检查器“官道覆盖”追加受压摘要后，在窄屏、长地名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 该摘要是当前可见 hostile 军队造成的只读态势提示，不代表完整路径安全、隐藏敌军推断、同盟借道、移动后同回合攻击或真实胜率。

## v2.4 - 郡县检查器敌对可见军队口径兼容层

完成日期：2026-07-05

核心更新：

- `MapDisplayAdapter.inspectorState` 将 `RegionInspectorState.visibleEnemyDivisions` 从旧的“非己方军队”收口为真正 hostile 军队。
- 郡县检查器的“可见敌军”现在只统计 `Faction.isHostile(to:)` 判定为敌对且当前可见的军队，避免中立、友好或后续借道势力被误写成敌军。
- `RegionInspectorState` 新增 `visibleNonHostileDivisions`，保留当前可见但非敌对的非己方军队，避免修正敌军口径后丢失中立/友军态势。
- `RegionInspectorView` 新增“可见非敌对军队”行，与“可见敌军”分开展示，便于玩家判断郡县内的多势力态势。
- 保持 `Faction.isHostile(to:)` 当前最小实现、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、真实攻击、敌控区、道路、粮道、补给和外交关系规则不变；本轮只做郡县检查器只读显示口径收口和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_hostile_visibility.md`

验证记录：

- 本轮在当前命令行工具链中实际尝试了下列 `swiftc -parse` 轻量语法检查并通过；这不是后续本机默认重测试要求，后续仍以 `md/test/test.md` 为准，遇到 SwiftUI / SpriteKit / SDK 依赖、耗时或报错应立即停止并记录。
- `swiftc -parse WWIIHexV0/SpriteKit/MapDisplayAdapter.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/RegionInspectorView.swift` 通过。
- 核心 + SpriteKit/UI Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/*.swift WWIIHexV0/UI/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，郡县检查器新增“可见非敌对军队”行后，在窄屏、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 当前 `Faction.isHostile(to:)` 仍是最小兼容敌对判断，不代表完整同盟、借道、停战或臣属制度已经落地。

## v2.4 - 命令面板敌对状态文案兼容层

完成日期：2026-07-05

核心更新：

- `CommandPanelView.statusText` 在玩家选择非己方军队时，不再一律显示“已选择敌军”。
- 若所选军队对玩家势力 hostile，仍显示“已选择敌军，不能下令”；若所选军队非己方但非 hostile，则显示“已选择非敌对军队，只能查看”。
- 下令权限、按钮可用性和真实命令执行保持不变：`canCommandSelectedUnit` 仍只允许玩家当前回合指挥己方、未行动军队。
- 保持 `Faction.isHostile(to:)` 当前最小实现、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、补给和外交关系规则不变；本轮只做命令面板只读状态文案收口和文档同步。

关键系统：

- `WWIIHexV0/UI/CommandPanelView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_command_panel_hostile_status_text.md`

验证记录：

- 本轮在当前命令行工具链中实际尝试了下列 `swiftc -parse` 轻量语法检查并通过；这不是后续本机默认重测试要求，后续仍以 `md/test/test.md` 为准，遇到 SwiftUI / SDK 依赖、耗时或报错应立即停止并记录。
- `swiftc -parse WWIIHexV0/UI/CommandPanelView.swift` 通过。
- 核心 + SpriteKit/UI Swift parse 通过：`swiftc -parse WWIIHexV0/Core/*.swift WWIIHexV0/Data/*.swift WWIIHexV0/Commands/*.swift WWIIHexV0/Rules/*.swift WWIIHexV0/Agents/*.swift WWIIHexV0/Turn/*.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/*.swift WWIIHexV0/UI/*.swift`。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，命令面板新增“非敌对军队”状态文案后，在窄屏和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 当前 `Faction.isHostile(to:)` 仍未接完整外交关系、停战、同盟和借道制度；本轮只避免 UI 文案把非 hostile 军队误称为敌军。

## v2.4 - 郡县检查器非敌对关系摘要

完成日期：2026-07-05

核心更新：

- `RegionInspectorState` 新增 `visibleNonHostileRelationSummaries`，用于郡县检查器只读展示可见非敌对军队的势力、外交关系、紧张度和非敌对标记。
- `MapDisplayAdapter.inspectorState` 从当前可见、非己方、非 hostile 且未毁灭的军队中最多生成三条非敌对关系摘要；若 `DiplomacyState` 没有对应 country 或 relation，则明确显示“关系未建档”。
- `RegionInspectorView` 新增“非敌对关系”行，与“可见敌军”和“可见非敌对军队”分开，帮助玩家判断中立、友好或后续借道势力为什么不是当前交战对象。
- 保持 `Faction.isHostile(to:)` 当前最小实现、`DiplomacyState` schema、外交命令、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、真实攻击、敌控区、道路压迫、粮道和补给规则不变；本轮只做郡县检查器只读态势摘要和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_non_hostile_relation_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/MapDisplayAdapter.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/RegionInspectorView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，郡县检查器新增“非敌对关系”行后，在窄屏、长军队名、长势力名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 当前 `Faction.isHostile(to:)` 和外交关系读取仍是兼容层只读摘要，不代表完整同盟、借道、停战、称臣或臣属制度已经落地。

## v2.4 - 武将面板命令按钮不可用原因提示兼容层

完成日期：2026-07-06

核心更新：

- `AppContainer` 新增 `selectedGeneralHoldLineUnavailableReason` 与 `selectedGeneralAttackRegionUnavailableReason`，集中生成武将面板“固守战线 / 进攻郡县”灰态原因。
- `canOrderSelectedGeneralHoldLine` 与 `canOrderSelectedGeneralAttackRegion` 改为由对应原因是否为 `nil` 决定，避免按钮可用性和提示条件分叉。
- `GeneralCommandPanelView` 新增只读 `info.circle` 提示，显示观察模式、非玩家阶段、未选择己方防区、未选择敌方前线郡县、目标防区非敌对或目标附近无己方相邻防区等下一步提示。
- `RootGameView` 在两个 `GeneralCommandPanelView` 入口传入灰态原因。
- 保持 `GeneralAgent`、`WarCommandExecutor`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实 `ZoneDirective` 执行、移动、攻击、道路、粮道、补给和动态防区归属不变；本轮只做武将面板只读操作反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_command_button_unavailable_reason.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/RootGameView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，按钮下方新增多行灰态原因后，在窄屏、长阶段名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 灰态原因是当前 UI 派生条件的只读解释，不代表完整路径安全、真实进攻胜率、敌方反制、同盟借道或后续外交制度已经落地。

## v2.4 - 郡县检查器官道受压最近敌军来源摘要兼容层

完成日期：2026-07-06

核心更新：

- `RegionInspectorState` 新增 `roadPressureSourceSummaries`，记录本郡官道受压的最近可见敌军来源摘要。
- `MapDisplayAdapter.inspectorState` 将官道受压数量和来源摘要统一到当前 viewer 可见、未毁灭、且 `Faction.isHostile(to:)` 判定 hostile 的敌军口径，避免隐藏敌军泄漏。
- `roadPressureSummaries` 按敌军来源去重，同一支敌军只输出一条最近受压官道，最多显示三条，并追加受压官道坐标、距官道、距锚点和敌将名。
- `RegionInspectorView` 新增“官道压迫”行，在郡县检查器中与官道覆盖、本郡武将、敌军接战和非敌对关系摘要并列展示。
- 保持移动、攻击、道路修缮、粮道、补给、外交、真实敌控区和 `Command / ZoneDirective -> WarCommandExecutor / RuleEngine` 执行链路不变；本轮只做只读 UI 派生和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_road_pressure_nearest_enemy_source_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/MapDisplayAdapter.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/RegionInspectorView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，新增多行“官道压迫”摘要在窄屏、长军队名、长武将名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 官道压迫来源是只读态势摘要，不代表完整路径安全、真实攻击合法性、胜率、借道、同盟通行或敌方回合反制制度。

## v2.4 - 武将面板麾下军队道路与接敌摘要兼容层

完成日期：2026-07-06

核心更新：

- 新增 `GeneralAssignedDivisionRow` 轻量只读 row model，由 `AppContainer.selectedGeneralAssignedDivisionRows` 统一生成武将面板“麾下军队”行摘要。
- 麾下军队行在既有兵力、粮草、军令和行动状态之外，追加当前官道态势：`据官道`、`官道受压` 或 `离官道`。
- 麾下军队行追加可见敌军接敌态势：可战、受敌射、互在射程、最近可见敌军或无可见敌军。
- 接敌摘要只使用当前 viewer 可见、未毁灭且 `Faction.isHostile(to:)` 判定 hostile 的敌军，避免隐藏敌军泄漏，也不把非敌对势力写成敌军。
- `GeneralCommandPanelView` 改为接收 `GeneralAssignedDivisionRow` 并只负责展示；`RootGameView` 两个入口改传 `selectedGeneralAssignedDivisionRows`。
- 保持 `MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实 `ZoneDirective` 执行、移动、攻击、道路、粮道、补给和动态防区归属不变；本轮只做武将面板只读态势摘要和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_assigned_unit_road_engagement_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/RootGameView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，麾下军队行追加官道和接敌摘要后，在窄屏、长军队名、长敌军名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 麾下军队道路与接敌摘要是只读态势提示，不代表完整路径安全、真实攻击合法性、胜率、同盟借道或敌方回合反制制度。

## v2.4 - 武将面板目标郡县官道与近敌预览兼容层

完成日期：2026-07-06

核心更新：

- `AppContainer.selectedGeneralTargetPreviewNotes` 在玩家选择敌对目标郡县、尚未提交“进攻郡县”时，生成提交前只读目标预览。
- 预览读取当前武将防区源代表 hex 与目标郡县 representative hex，显示源/目标是否据官道或离道；若该代表 hex 邻近当前 viewer 可见 hostile 军队，则追加受压提示。
- 目标近敌摘要只统计当前 viewer 可见、未毁灭且 `Faction.isHostile(to:)` 判定 hostile 的敌军，并显示源/目标到最近可见敌军的 hex 距离。
- `GeneralCommandPanelView` 新增 `targetPreviewNotes` 输入，只在目标郡县名下展示这些 notes；`RootGameView` 两个入口统一传入 `selectedGeneralTargetPreviewNotes`。
- 保持 `PlayerPlannedOperation` schema、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实 `ZoneDirective` 执行、移动、攻击、道路、粮道、补给、外交和动态防区归属不变；本轮只做武将面板只读下令前反馈和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_target_road_enemy_preview.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/RootGameView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，目标郡县名下新增预览在窄屏、长郡县名、长军队名和 Dynamic Type 下的实际换行仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 目标郡县官道与近敌预览是只读态势提示，不代表完整路径安全、真实攻击合法性、胜率、隐藏敌军、同盟借道、移动后同回合攻击或敌方回合反制制度。

## v2.4 - 地图计划军令可见近敌短标签兼容层

完成日期：2026-07-06

核心更新：

- `BoardScene` 的计划军令标签在既有武将、攻守战术和官道短标签基础上，追加最近可见 hostile 敌军短标签，例如 `近袁骑2`。
- 地图计划军令的官道受压判断改为只统计当前 operation faction 可见、未毁灭且 `Faction.isHostile(to:)` 判定 hostile 的敌军，避免隐藏敌军通过地图标签泄漏。
- `AppContainer.selectedGeneralPlannedOperationRows` 的源/目标受压和近敌对象/距离摘要同步改为可见 hostile 口径，与提交前目标郡县预览一致。
- 地图计划军令标签对长文本做小幅字号和背景宽度适配，降低近敌短标签挤出背景的概率。
- `md/prompt/README.md` 补入 `codex-v2.0-三国aiagent迁移总提示词.md` 总提示词入口，避免阶段索引漏掉当前长期目标的路线文件。
- 保持 `PlayerPlannedOperation` schema、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实 `ZoneDirective` 执行、移动、攻击、道路、粮道、补给、外交和动态防区归属不变；本轮只做只读地图/面板反馈和文档同步。

关键系统：

- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_map_planned_operation_visible_enemy_tags.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/BoardScene.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，地图计划军令短标签在密集箭头、长武将名、长敌军名、小屏和 Dynamic Type 下的实际遮挡仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 地图和面板计划军令近敌/受压摘要是只读态势提示，不代表完整路径安全、真实攻击合法性、胜率、隐藏敌军、同盟借道、移动后同回合攻击或敌方回合反制制度。

## v2.4 - 军队可见官道受压审计兼容层

完成日期：2026-07-06

核心更新：

- `AppContainer` 新增 `isVisibleHostileZoneOfControl`，用玩家视角可见、未毁灭且 `Faction.isHostile(to:)` 的军队判断只读 UI 文案中的官道受压。
- `AppContainer` 新增 `visibilityFilteredPreviewState`，在军队详情/接战预判的只读可达范围计算中剔除玩家不可见 hostile 军队，避免隐藏敌军 ZOC 改写可达官道、最近安全官道或接近候选摘要。
- `selectedUnitMobilityPreviewNotes` 的当前位置官道受压、可达官道安全/受压数量和最近安全官道距离改为玩家视角可见 hostile 口径。
- `selectedUnitCombatPreviewNotes` 的接战官道压制位、未接敌接近候选和官道接近安全/受压数量改为玩家视角可见 hostile 口径。
- `GeneralCommandPanelView` 麾下军队行的官道受压摘要通过 `AppContainer.generalAssignedDivisionRoadSummary` 使用同一可见 hostile 口径。
- 保持 `MovementRules.isEnemyZoneOfControl`、`MovementRules.movementRange` 真实规则、`CombatRules`、`GeneralInfluence`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮道、补给、外交和动态防区归属不变；本轮只做只读道路/交战预览情报边界修正和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_visible_road_pressure_audit.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，过滤隐藏敌军后的道路/接近预判在观察模式、敌军刚离开视野、长军队名和 Dynamic Type 下的实际体验仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 只读可达/道路安全摘要为避免情报泄漏会使用过滤隐藏敌军后的预览状态，可能与真实移动命令受隐藏敌军 ZOC 阻挡的结果不完全一致；真实合法性仍以 `CommandValidator -> RuleEngine` 为准。

## v2.4 - 武将面板可见敌军接敌摘要兼容层

完成日期：2026-07-06

核心更新：

- `AppContainer.selectedGeneralInfluenceNotes` 收集武将防区敌军集合时，除 `Faction.isHostile(to:)` 和未毁灭条件外，追加 `mapDisplayAdapter.isDivisionVisible(target, viewerFaction: playerFaction)`。
- 武将面板“道路与交战”的最近敌军对象、距离、当前接敌配对和攻防修正范围只来自玩家视角可见 hostile 军队，避免隐藏敌军通过武将面板摘要泄漏。
- 观察模式继续通过 `mapDisplayAdapter` 的 revealAll 行为兼容全图查看；普通玩家视角不使用防区 faction 或敌军 faction 推导额外视野。
- 保持 `GeneralInfluence`、`MovementRules`、`CombatRules`、`SupplyRules`、`CommandValidator`、`WarCommandExecutor`、`RuleEngine`、`CommandExecutor`、真实移动、攻击、道路、粮道、补给、外交和动态防区归属不变；本轮只做只读武将面板情报边界修正和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_general_panel_visible_hostile_engagement_summary.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，武将面板可见敌军过滤后，在隐藏敌军刚离开视野、观察模式、长武将名、长敌军名和 Dynamic Type 下的实际体验仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 武将面板道路与交战摘要仍是只读态势提示，不代表完整路径安全、真实攻击合法性、胜率、隐藏敌军、同盟借道、移动后同回合攻击或敌方回合反制制度。

## v2.4 - 军队详情可见敌军接战预判兼容层

完成日期：2026-07-06

核心更新：

- `AppContainer.selectedUnitCombatPreviewNotes` 收集接战候选时，除 `Faction.isHostile(to:)` 和未毁灭条件外，追加 `mapDisplayAdapter.isDivisionVisible(target, viewerFaction: playerFaction)`。
- 军队详情“接战预判”的射程内三目标对比、首选理由、反击风险、敌将、交战审计、接近候选、接近态势、接近威胁和官道接近都只来自玩家视角可见 hostile 军队。
- `refreshHighlights` 的攻击高亮也改为只标出玩家视角可见 hostile 目标，避免不可见敌军坐标通过高亮泄漏。
- 观察模式继续通过 `mapDisplayAdapter` 的 revealAll 行为兼容全图查看；普通玩家视角不使用选中敌军所属 faction 推导敌方视野。
- 保持 `CombatRules`、`MovementRules`、`SupplyRules`、`GeneralInfluence`、`CommandValidator`、`RuleEngine`、`CommandExecutor`、真实攻击、移动、道路、粮道、补给、外交和动态防区归属不变；本轮只做只读接战预判与高亮情报边界修正和文档同步。

关键系统：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_unit_combat_visible_hostile_preview.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做运行时 UI 烟测，军队详情可见敌军过滤后，在敌军刚离开视野、选中敌军、观察模式和 Dynamic Type 下的实际体验仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 军队详情接战预判和攻击高亮是只读态势提示，不代表完整攻击合法性、隐藏敌军、真实胜率、同盟借道、移动后同回合攻击或敌方回合反制制度。

## v2.4 - AI 与执行器单位敌对筛选兼容层

完成日期：2026-07-06

核心更新：

- `WarCommandExecutor.enemyStrength`、`hasEnemyPresence` 和 `visibleEnemyDivision` 改用 `Faction.isHostile(to:)` 筛选单位级敌军，避免同阵营或 `.neutral` 中立单位影响突破目标排序、敌军存在判断或具体攻击目标选择。
- `RulerAgent`、`MockAICommander` 和 `ZoneCommanderAgent` 的单位级敌军强度、威胁和接触判断改用 hostile 口径，减少三国多势力场景下把中立单位当作敌军的误判。
- 保持 region/controller 的非所属判断不动；本轮只修单位级敌对筛选，不把未控制区域等同于敌军单位。
- 真实移动、攻击、道路、粮道、补给、外交、生产、回合推进、`CommandValidator`、`RuleEngine` 和 `Faction.isHostile(to:)` 语义不变。

关键系统：

- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Agents/MockAICommander.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_ai_executor_unit_hostile_filtering.md`

验证记录：

- `swiftc -parse WWIIHexV0/Commands/WarCommandExecutor.swift` 通过。
- `swiftc -parse WWIIHexV0/Agents/RulerAgent.swift` 通过。
- `swiftc -parse WWIIHexV0/Agents/MockAICommander.swift` 通过。
- `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做本机运行时 AI 回合或战斗烟测；AI 威胁、突破排序和执行器目标选择在完整多势力外交关系、非交战、同盟或借道制度下的行为仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 区域非所属/争夺判断仍可把未控制 region 纳入目标候选，这是战略目标选择语义，不代表该 region 内一定存在 hostile 单位。

## v2.4 - 郡县检查器外交敌对分组兼容层

完成日期：2026-07-06

核心更新：

- `DiplomacyState` 新增 faction-to-faction 只读 helper，可通过双方 primary country 读取 `DiplomaticRelation.status`，将 `.hostile` / `.atWar` 判为敌对，将 `.neutral` / `.allied` / `.coBelligerent` 判为非敌对；缺国家或关系建档时 fallback 到 `Faction.isHostile(to:)`。
- `MapDisplayAdapter.inspectorState` 的可见敌军、可见非敌对军队、郡县官道受压计数和官道压力来源改用该外交 helper，避免郡县检查器关系摘要与分组口径不一致。
- `RegionInspectorView` 继续只读展示可见敌军、可见非敌对军队及其外交关系/紧张度；本轮不改变真实攻击、移动、道路、粮道、补给、部署或 AI 执行规则。
- `Faction.isHostile(to:)`、`CommandValidator`、`RuleEngine`、`MovementRules`、`SupplyRules`、`WarDeploymentManager` 和 `WarCommandExecutor` 真实规则口径保持不变；完整借道、同盟通行、共同作战堆叠和补给共享仍待后续制度化。

关键系统：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_region_inspector_diplomacy_hostile_grouping.md`

验证记录：

- `swiftc -parse WWIIHexV0/Core/DiplomacyState.swift` 通过。
- `swiftc -parse WWIIHexV0/SpriteKit/MapDisplayAdapter.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做本机运行时 UI 烟测；郡县检查器外交分组在动态外交状态变化、缺国家建档、观察模式、长军队名和 Dynamic Type 下的实际表现仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- 真实攻击合法性、道路敌控区、粮道阻断、补给、安全补员和部署层仍按现有规则口径执行；这次只是郡县检查器只读展示口径与外交关系摘要对齐。

## v2.4 - 部署层与 Region 命令敌对边界兼容层

完成日期：2026-07-06

核心更新：

- `WarDeploymentManager.rebuildSegments` 的单位级 `hasEnemyPresence` 改用 `division.faction.isHostile(to: zone.faction)`，避免中立或非 hostile 单位触发敌军存在。
- `WarDeploymentManager.enemyZoneIdsTouching`、`regionTouchesEnemyZone` 和 `hexTouchesEnemyZone` 的相邻防区接触改用 `neighborFaction.isHostile(to: faction)`，避免中立或非 hostile 防区生成敌对前线接触。
- `RegionCommandValidator` 的 `.attack` 目标阵营校验改用 `target.faction.isHostile(to: attacker.faction)`，与 hex `CommandValidator.validateAttack` 口径对齐。
- 保持非己方控制 hex/region 的部署压力和前沿分类不动；`controller != faction` 仍表达未控制、争夺或非所属位置，不等同于敌军单位。
- `Faction.isHostile(to:)`、`RuleEngine`、`CommandExecutor`、`MovementRules`、`SupplyRules`、真实伤害、移动、补给和完整借道/同盟通行制度不变。

关键系统：

- `WWIIHexV0/Rules/WarDeploymentManager.swift`
- `WWIIHexV0/Rules/RegionCommandValidator.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_deployment_region_hostile_rules.md`

验证记录：

- `swiftc -parse WWIIHexV0/Rules/WarDeploymentManager.swift` 通过。
- `swiftc -parse WWIIHexV0/Rules/RegionCommandValidator.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮没有做本机运行时前线/部署烟测；中立或非 hostile 防区不再生成敌对接触后，动态部署层在复杂多势力接壤下的实际 front/depth/garrison 分配仍待云端 CI、后续 Agent C artifact 复判或人工授权运行检查。
- RegionCommandValidator 只是旧 region 命令校验兼容层；默认执行链仍会经 `CommandIntentAdapter -> CommandValidator -> RuleEngine` 兜底。

## v2.4 AppContainer 外交敌对预览兼容层

完成日期：2026-07-06

目标：

- 继续围绕武将、道路、交战和多势力外交口径做小步迁移，把 `AppContainer` 的只读敌军/近敌/受压/接战预览接到 `DiplomacyState` 的敌对关系 helper。

完成内容：

- `WWIIHexV0/App/AppContainer.swift` 新增本地 `isDiplomaticallyHostile(_:to:)` helper，复用 `DiplomacyState.isHostile(between:and:)` 的 `DiplomaticRelation.status` 判定和缺建档 fallback。
- 军队接战预判、武将麾下军队摘要、武将目标预览、武将影响摘要、计划军令近敌/受压摘要、移动预览可见敌控过滤和非己方军队点击日志改用外交敌对口径。
- 保留地图点击自动攻击、攻击高亮、武将宏观目标可用性、真实攻击/移动/道路/粮道/部署/补给/伤害/撤退规则的 `Faction.isHostile(to:)` 口径，避免 UI 预览切片扩大成执行规则变更。

关键文件：

- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_appcontainer_diplomacy_hostile_preview.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮只覆盖 `AppContainer` 的只读预览和日志；`BoardScene` 计划军令地图短标签、`CommandPanelView` 状态文本和 `GeneralCommandPanelView` 面板显示 gate 仍可在后续小切片继续接入外交敌对口径。
- 完整借道、同盟通行、共同作战堆叠、补给共享和外交宣战制度仍未实现。

## v2.4 地图与面板外交敌对显示兼容层

完成日期：2026-07-06

目标：

- 补齐上一轮遗留的 `BoardScene` 计划军令地图短标签、`CommandPanelView` 状态文本和 `GeneralCommandPanelView` 目标预览显示 gate，让这些只读显示与 `DiplomacyState` 的 hostile / atWar 口径一致。

完成内容：

- `WWIIHexV0/SpriteKit/BoardScene.swift` 的计划军令官道“受压”和最近可见敌军短标签改用 `state.diplomacyState.isHostile(between:and:)`，保留玩家视角可见性过滤。
- `WWIIHexV0/UI/CommandPanelView.swift` 新增 `DiplomacyState` 入参，只影响非己方军队状态文案中的“敌军/非敌对军队”判断，按钮权限不变。
- `WWIIHexV0/UI/GeneralCommandPanelView.swift` 不再自行读取 `targetZone.faction.isHostile(to:)`，改由 `AppContainer.selectedGeneralTargetUsesDiplomaticHostility` 派生显示 gate。
- `WWIIHexV0/UI/RootGameView.swift` 同步传入外交状态和目标预览显示布尔值。
- `WWIIHexV0/App/AppContainer.swift` 暴露目标预览显示派生，让目标预览区块和目标预览 notes 使用同一外交敌对口径。

关键文件：

- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_display_diplomacy_hostile_preview.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `swiftc -parse WWIIHexV0/SpriteKit/BoardScene.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/CommandPanelView.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift` 通过。
- `swiftc -parse WWIIHexV0/UI/RootGameView.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 本轮仍未修改实际命令入口：地图点击自动攻击、攻击高亮、武将“进攻郡县”按钮可用性、`selectedAttackTarget` 和相邻己方防区反推仍使用 `Faction.isHostile(to:)`，需要后续单独切片决定是否把玩家 UI 命令 affordance 接到外交 hostile。
- 完整借道、同盟通行、共同作战堆叠、补给共享和外交宣战制度仍未实现。

## v2.4 外交敌对攻击入口兼容层

完成日期：2026-07-06

目标：

- 让玩家点击攻击、攻击高亮、武将宏观进攻 affordance、底层攻击校验和 AI 单位攻击目标筛选使用同一 `DiplomacyState` hostile / atWar 口径，避免只读预览、提交入口和 `RuleEngine` 校验分叉。

完成内容：

- `WWIIHexV0/App/AppContainer.swift` 的地图点击自动攻击、点击非己方军队直接攻击、攻击高亮、武将“进攻郡县”按钮可用性、`selectedAttackTarget` 和相邻己方防区反推改用 `isDiplomaticallyHostile`。
- `WWIIHexV0/Rules/CommandValidator.swift` 的 `.attack` 目标合法性改用 `state.diplomacyState.isHostile(between:and:)`。
- `WWIIHexV0/Rules/CommandExecutor.swift` 在 `executeAttack` 增加同口径防绕过 guard，避免直接调用执行器时结算外交非敌对目标。
- `WWIIHexV0/Rules/RegionCommandValidator.swift` 的旧 region attack 兼容校验改用 `DiplomacyState`。
- `WWIIHexV0/Commands/WarCommandExecutor.swift` 的单位级敌军强度、敌军存在和可见攻击目标筛选改用 `DiplomacyState`。
- `WWIIHexV0/Rules/RegionCombatRules.swift` 的区域交战压力只统计外交 hostile / atWar 单位。

关键文件：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/RegionCommandValidator.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Rules/RegionCombatRules.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_attack_entry.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift` 通过。
- `swiftc -parse WWIIHexV0/Rules/CommandValidator.swift` 通过。
- `swiftc -parse WWIIHexV0/Rules/CommandExecutor.swift` 通过。
- `swiftc -parse WWIIHexV0/Rules/RegionCommandValidator.swift` 通过。
- `swiftc -parse WWIIHexV0/Commands/WarCommandExecutor.swift` 通过。
- `swiftc -parse WWIIHexV0/Rules/RegionCombatRules.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- 道路敌控区、粮道通行、安全补员邻接、部署层敌军存在/相邻敌对防区接触和非己方控制 hex/region 的推进/压力分类仍使用原控制权或 `Faction.isHostile(to:)` 口径；完整借道、同盟通行、共同作战堆叠、补给共享和外交宣战制度仍未实现。
- 本轮没有运行本机运行时烟测；复杂多势力关系下的真实战局行为仍待云端 CI、后续 Agent C artifact 复判或人工授权补测。

## v2.4 外交敌对 ZOC / 粮道 / 安全补员兼容层

完成日期：2026-07-06

目标：

- 继续围绕武将、道路和交战迁移，把单位级道路敌控区、粮道阻断、围城邻接和安全补员邻接从静态 `Faction.isHostile(to:)` 迁移到 `DiplomacyState` 的 hostile / atWar 口径。

完成内容：

- `WWIIHexV0/Rules/MovementRules.swift` 的 `isEnemyZoneOfControl` 改用 `state.diplomacyState.isHostile(between:and:)`，让外交非敌对单位不再形成道路/移动 ZOC。
- `WWIIHexV0/Rules/SupplyRules.swift` 的粮道路径单位阻断和围城邻接 hostile 单位判断改用 `DiplomacyState`。
- `WWIIHexV0/Rules/EconomyRules.swift` 的安全补员相邻敌军判断改用 `DiplomacyState`。
- 保留 `SupplyRules` 的 capturable tile controller 判断、`MovementRules` 的非同 faction 堆叠/路径阻挡、部署层敌军存在/相邻敌对防区接触和占领/控制权语义，避免把本轮扩大成完整借道、同盟通行、共同作战堆叠或共享补给制度。

关键文件：

- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `md/prompt/v2.0-三国迁移/v2.4_diplomacy_hostile_zoc_supply_reinforcement.md`

验证记录：

- `swiftc -parse WWIIHexV0/Rules/MovementRules.swift` 通过。
- `swiftc -parse WWIIHexV0/Rules/SupplyRules.swift` 通过。
- `swiftc -parse WWIIHexV0/Rules/EconomyRules.swift` 通过。
- 本轮改动文件尾随空白扫描无命中。
- 行首冲突标记扫描无命中。
- 旧默认测试口径扫描无命中。
- `git diff --check` 通过，无输出。
- `md/prompt/v2.0-三国迁移` 目录 md 文件与 `md/prompt/README.md` 索引差集为空。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范禁止默认执行本机重测试。

遗留风险：

- `WarDeploymentManager` 的单位级敌军存在和相邻敌对防区接触仍待后续切片决定是否迁移到 `DiplomacyState`。
- 本轮没有实现完整借道、同盟通行、共同作战堆叠、补给共享或外交宣战制度。
- 复杂多势力关系下的真实战局行为仍待云端 CI、后续 Agent C artifact 复判或人工授权补测。

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
