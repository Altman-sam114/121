# 三国棋策 Agent — iOS / macOS AI Agent 战棋迁移版

> **当前状态：v2.5 发布级三国 UI、美术和交互收口起步；v2.4 君主/外交/太守/军师/武将指令编排、外交与太守生产命令、武将战术塑形、道路和交战兼容层仍是规则主线。工程仍沿用 `WWIIHexV0` 目录、`Faction.germany/allies`、`Division`、`TacticName` 等源码兼容名，但默认新局已优先加载 `guandu_200_scenario.json` / `guandu_200_regions.json` 和 `sanguo_unit_templates.json`；旧阿登数据与旧 `unit_templates.json` 保留作 fallback 和历史回归参考。`Faction` 已可解码曹、袁、刘备、孙氏、刘表、马腾、汉室和中立等三国势力，底层行动权威不变：玩家、AI 和后续聊天命令仍必须落到 `Command` / `ZoneDirective`，再经 `WarCommandExecutor -> RuleEngine` 校验执行。历史重测试基线只作参考；当前工作流默认不跑 Xcode / XCTest / 模拟器，只按 `md/test/test.md` 做轻量检查。**

---

## 项目定位

一款正在从二战原型迁移为三国题材的 iOS / macOS 回合制 AI Agent 战棋。目标结合六角格战术操作、郡县/方面军战略调度、粮草与城池争夺，以及君主、外交官、太守、军师、武将等 Agent 的结构化决策。

**迁移目标：**
- 首发方向以“官渡前夜 200”一类区域剧本为目标，不一次性做全中国沙盒。
- Hex 仍是移动、攻击、占领、视野、补给落点的战术权威。
- Region 显示为郡县/州，是人口、钱粮、军械、城池和胜利点的战略聚合层。
- Theater / FrontZone 显示为方面、战线、防区，服务 AI 调度，不替代 hex 权威。
- 当前阶段已完成官渡小地图默认入口、兼容显示层、多势力数据表达、初始外交 profile、三国兵种模板兼容层、战术审计显示三国化、围城/粮草和兵种克制最小规则，并开始把君主、外交官、太守、军师和武将层接入 AI 回合的 directive 编排；外交官提案可经 `Command.proposeDiplomacy -> RuleEngine` 最小更新外交状态和紧张度，太守建议的生产项可经 `Command.queueProduction -> RuleEngine` 进入生产队列，太守修路焦点可经 `Command.improveRoad -> RuleEngine` 连通优先修缮战术道路和郡县基础设施，AI 军令和玩家武将面板宏观军令都会经 `GeneralAgent` 按性格/技能把 `ZoneDirective.tactic` 塑形为合法攻守战术，武将分配也已能影响道路机动与交战攻防修正，攻击/反击日志、地图计划军令标识、武将军令面板、军队详情和郡县面板都会输出所属武将、道路机动、官道受益军队/无加成原因、玩家视角可见可达官道、最近可达/可见安全官道距离、官道覆盖/受压/最近敌军来源、本郡武将、麾下军队兵力/粮草/军令/行动/官道/接敌状态、可见敌军距离/射程/兵力/敌将、可见非敌对军队的势力/关系/紧张度、可见当前接敌配对、可见接战目标态势、可见接战结算风险预判、可见多目标交战对比、无可见敌对空状态或交战影响摘要；玩家宏观军令在地图上显示为带武将/战术/官道、可见受压与最近可见敌军短标签的进攻箭头或固守标记，并在武将军令面板用同一源/目标代表 hex 摘要显示武将、最终战术、源→目标、官道状态、源目可见受压和最近可见敌军对象/距离；尚未提交“进攻郡县”时，武将军令面板也会按当前可见 hostile 口径预览源/目标代表 hex 的官道据守/受压和最近可见敌军距离；选中武将防区的道路与交战摘要会显示当前可见接敌配对、最近可见敌军、距离和对应麾下军队，固守/进攻按钮灰态时也会显示观察模式、阶段、防区或目标条件不足的只读原因。武将技能在档案、军令面板、军队详情和复核理由中已中文化显示，其中档案、军令面板和军队详情还会追加官道机动、骑兵突击、攻城修正、地形/渡河防御等只读短提示；核心移动、交战、姿态、回合、动态方面事件日志以及命令结果/拒绝原因已开始中文化；道路敌控区、粮道单位阻断、粮道控制格通行、撤退安全格控制格、战略郡县粮道控制区通行、撤退安全郡县、围城邻接、安全补员邻接、部署层敌军存在、相邻敌对防区接触、动态前线敌对接触、Legacy `AgentContext.enemyDivisions` / enemy supply 摘要、`MockAICommander` 威胁估算、`MarshalBattlefieldSummarizer`、`ZoneCommanderAgent`、`RulerStrategicSnapshot`、`StrategistBattlefieldSnapshot` 的单位级敌军摘要、玩家地图点击攻击、攻击高亮、武将宏观目标选择、`CommandValidator` / `RegionCommandValidator` 攻击校验、`WarCommandExecutor` 单位目标筛选和宏观军令落点敌控优先级、区域交战压力、郡县检查器、`AppContainer` 军队/武将/计划军令只读预览、`BoardScene` 计划军令地图短标签、`CommandPanelView` 状态文案和 `GeneralCommandPanelView` 目标预览显示 gate 会优先按 `DiplomaticRelation.status` 区分敌军与非敌对军队，缺外交建档时回退到 `Faction.isHostile(to:)`；领土 controller、objective / region controller 来源、非同 faction 堆叠阻挡、非己方控制 hex/region 的部署压力分类、前线压力/补给/包围拓扑和 encirclement 拓扑仍保留原控制权/阵营语义，其中攻击高亮、道路受压和只读预判只使用玩家视角可见 hostile。完整多势力 turn order、完整官渡大地图、借道/贡赋/称臣/屯田治安等完整制度和发布级 UI 将按 v2.4+ 分阶段推进。

**当前补给/撤退控制格边界：** `SupplyRules` 的粮道控制格通行和撤退安全格控制格阻断、`RegionSupplyRules` 的战略郡县粮道控制区通行和撤退安全郡县已按 `DiplomacyState` hostile / atWar 口径判断；非敌对控制格不会仅因旧二元阵营关系切断粮道或阻止安全撤退，但非同 faction 堆叠、补给源共享和完整借道制度仍未实现。

**当前武将显示边界：** `GeneralData.rank` raw 字段和旧 `generals.json` fallback 数据保留兼容；武将军令面板和武将档案使用 `rankDisplayName` 把旧英文军衔映射为三国语义显示名，头像占位的辅助功能文案显示为中文“头像”。武将统军风格由 `ZoneCommanderAgentConfig.CommandStyle.displayName` 和 `GeneralAssignment.commandStyleDisplayName` 统一展示为进取、持重、谨慎；assignment 快照缺失或坏值时按忠诚/满意推断，保持军队详情与 `GeneralAgent` 执行口径一致。武将道路/交战日志、军队详情预览、计划军令摘要、武将复核事件和军机面板记录缺少姓名快照时使用“未命名武将 / 未知郡县 / 未知防区”等中文占位，不把 raw `generalId`、`RegionId` 或 `FrontZoneId` 当作玩家文案 fallback；底层 id、Codable 和调试 JSON 仍保留。

**当前外交面板显示边界：** `DiplomacyPanelView` 只读展示 `DiplomacyState`，势力、集团、关系、君主重点防区和外交对象优先使用国家名、集团名、势力名和防区展示名；空名或等于 raw id 时显示“未知势力 / 未知集团 / 未知防区”等中文占位，不直接把 `CountryId`、`DiplomaticBlocId` 或 `FrontZoneId` rawValue 作为玩家文案 fallback。外交关系、借道、敌对和交战规则仍由 `DiplomacyState`、`Command.proposeDiplomacy` 与规则系统决定。

**当前 Agent 上下文显示边界：** 君主、外交官、太守、军师和模拟军机写入 `DirectiveEnvelope.theaterContext`、rationale 或 `DiplomacyState.summary` 时，防区优先显示 `FrontZone.name` 或势力简称加郡县名，郡县优先显示 `RegionNode.name`，外交对象优先显示 `CountryProfile.name`，缺资料时使用中文占位；legacy `.germany/.allies` 外交 profile 的可见名称已按曹操/袁绍语义显示。底层 id、bloc id、Codable、调试 JSON 和执行规则不变。

**当前 Legacy Agent D 错误边界：** `AgentDecisionParserError` 和 `AgentCommandMappingError` 的可见错误说明已改为中文军机/军令语义；`schemaVersion`、`agentId`、`toRegionId`、`targetDivisionId` 等 JSON 字段名和 parser / mapper 行为仍保持兼容，Legacy Agent D 也仍只作回归参考，不恢复为默认战争 AI 主路径。

**当前经济/生产日志边界：** `EconomyRules` 的经济启动、排产、府库结算、战略粮草短缺、自动补员、粮草辎重完成、生产军队部署和无安全后方部署格事件日志已改为中文三国语义；资源摘要显示人口、军械、粮草，生产部署优先显示军队展示名、郡县后方和地名优先的安全格摘要，修路结果优先显示城池、关隘、郡县、官道或地形，坐标只作次级定位。底层 `EconomyResources` 字段、`ProductionKind` rawValue、生产队列、收入、维护费、补员、修路选点、部署筛选和命令管线不变。

**当前战略同步日志边界：** 占领后 region controller 变化、动态方面推进、周边前线变化和战略状态补建事件日志已改为中文三国语义，优先显示 `RegionNode.name`、`TheaterNode.name` 或 `FrontZone.name`；缺展示名时使用“未命名郡县 / 动态方面”等中文占位，不把 raw id 当玩家文案 fallback。底层 `RegionId`、`TheaterId`、`FrontZoneId`、`Command.displayName`、Codable/rawValue、`hexToTheater`、`hexToFrontZone` 和同步规则不变。

**当前命令结果展示名边界：** `RuleEngine` 成功 `CommandResult.message` 已改为 state-aware 中文摘要，移动/交战会使用 `Division.thematicDisplayName`，修路会显示郡县名，外交会显示国家或势力名；`AppContainer` 玩家交互日志不再重复拼接 raw id 版 `Command.displayName`，`AgentPanelView` 的命令结果标题显示“进军命令 / 交战命令 / 修缮道路命令”等类别。`Command.displayName` 本体、`CommandResultSummary.commandDisplayName` 存储字段、Codable/rawValue 和旧 AI 兼容判断不变。

**当前指令诊断展示边界：** 旧 `RegionCommand.displayName` 兼容层已收口为“郡县进军 / 郡县交战 / 郡县固守 / 郡县补给”等安全类别；`CommandIntentAdapterError` 和 `TheaterDirectiveDecoderError` 的可见说明已改为中文军师/郡县语义，缺失防区、方面或郡县时不把 raw id 当作玩家文案；`TurnManager` 的外交和太守命令成功诊断复用 `CommandResult.message`。底层 region 命令、军师指令 JSON、Codable schema、rawValue、命令校验和规则执行不变。

**当前剧本胜负条件边界：** `DataLoader` 会把 `ScenarioDefinition.victoryConditions` 中 active 的 `controlObjective` 条件注入 `VictoryState.scenarioConditions`；`VictoryRules` 优先按 objective id 和 hex controller 判断官渡剧本目标，例如袁绍控制许昌或曹操控制邺城，并在 HUD 的“胜负”中显示中文胜利原因。`RegionVictoryRules` / `RegionRuleSystem` 的只读战略分析也会先按同一剧本条件评估，避免 region 层分析继续只看旧阿登城市名。旧 `VictoryReason` rawValue、阿登目标名和歼灭/断粮 fallback 规则保留作历史兼容；本轮不实现多目标计分、限回合条件、歼灭模板条件或完整胜利面板。

**当前地图兵牌边界：** `UnitNode` 的地图兵牌中心显示三国兵种 glyph，姿态短标记使用 `退/守`；底层 `Division`、`ComponentType`、`RetreatMode` rawValue、移动/交战/撤退规则和 `BoardScene` 创建流程不变。

**当前 v2.5 UI 收口边界：** `SanguoDesignTokens` 已作为共享视觉 token 起步，提供绢帛面板、墨色文字、朱印、玉色、铜色、河道蓝、8pt 面板圆角和 44pt 触控高度；HUD、战报、主覆盖层和 SpriteKit 地图底色已接入这组 token。MapEditor 新建军队默认模板已切到 `sanguo_unit_templates.json` 的步卒营、骑军、弓弩营、器械营、守军和舟师，并把新建城池、粮仓和导出错误文案改为三国语义。该切片只改变显示和编辑器默认值，不改变规则、JSON schema、Codable rawValue、旧 fallback 数据或命令管线。

**当前检查器展示边界：** 军队详情和郡县详情由 `MapDisplayAdapter` 生成郡县、动态方面、防区、战线和要地状态的玩家可见展示名，优先读取 `RegionNode.name`、`TheaterNode.name`、`FrontZone.name`；空名、等于 raw id 或明显内部 id 时退回势力简称与郡县名摘要。底层 `RegionId`、`TheaterId`、`FrontZoneId`、`FrontLineId`、`GeneralAssignment.generalId`、Codable rawValue、动态方面/防区/战线规则不变。

**核心创新：本地部署 LLM 驱动游戏 AI**
- 当前已有将军/元帅式指令链；三国迁移后将逐步改造为君主、外交官、太守、军师、武将等 Agent。
- Agent 根据视野、战况摘要、性格和历史背景输出结构化 JSON / Codable directive。
- 游戏规则系统负责校验并执行，AI 不直接绕过规则修改状态。

---

## 地图 / 战区架构（核心决策）

**分层叠加，不是替换。** 六角格保留作战术/战斗层，省份与战区负责战略聚合。

```
Hex（战术层 / 真实占领与移动）
  ↓ hexToRegion
Region（省份规则层 / 资源、人力、补给、胜利点聚合）
  ↓ regionToTheater（初始战区基本单位，只读基准）
Initial Theater Layout（地图编辑器初始划分 / 只读 snapshot）
  ↓ hexToTheater
Dynamic Theater State（运行时动态战区 / 随 hex 推进变化）
  ↓ 动态 hex 邻接
FrontLine / FrontSegment（前线与分段，按动态战区接触生成）
  ↓
WarDeploymentState（FRONT / DEPTH / GARRISON 部署池）
  ↓
ZoneDirective / WarCommandExecutor / RuleEngine
```

**为什么分层：**
- 全球地图纯 hex ≈ 16 万节点，iOS 跑不动（尤其带 LLM agent）
- HOI4 证明：省是规则原子，全球 ~1-2 万省可实时跑
- 战术级 hex（UC2 风格）提供精细操作，战略级省提供全球性能
- **同一局内可切换**：大战略模式看省，zoom 进某省切 hex 板战术微操
- **v0.358 之后的关键语义**：
  - `regionToTheater` = 初始战区基本单位，服务地图编辑器、动态战区生成/合并/消亡的参照，不是运行时推进层。
  - `hexToTheater` = 运行时动态战区权威映射。单位占领一个 hex，只推进这个 hex 的动态战区归属，不能把整个 region 拉走。
  - 前线 = 我方动态战区与敌方动态战区的 hex 邻接接触，按 region 形成 `FrontSegment`。

**v0.2 以来的长期原则**：省份作为战略层叠加，**不替换** hex 坐标系。现有 hex 规则全保留，省作为聚合视图 + 省级规则并行运行。

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 平台 | iOS；v1.1 新增 macOS 主游戏 target `WWIIHexV0Mac` |
| 语言 | Swift |
| UI 框架 | SwiftUI（面板、按钮、日志、单位详情） |
| 地图渲染 | SpriteKit（六角格地图、单位显示、移动/攻击反馈） |
| AI 接口 | `DecisionProvider` 协议（MockAI 已实现，预留本地 LLM） |

---

## 协作与云端验证

当前协作制度固定为 `main` 直推和云端结果包验收：Agent B 基于最新 `origin/main` 实现，本机只跑 `md/test/test.md` 允许的轻量检查，提交后直接 push 到 `origin/main` 触发 `.github/workflows/ci-results.yml`。GitHub Actions 负责云端重验证并上传未加密 CI 结果包，内含 manifest、失败摘要、JUnit 摘要、构建日志和 `.xcresult`（如生成）。

Agent C 不只阅读文字汇报，必须用 `gh auth login` 后下载最新 `origin/main` run 的 artifact，核对 `ci-artifact-manifest.json` 中的 branch、commit、run id 和 attempt，再决定通过或退回 Agent B 在 `main` 上追加修复 commit。

---

## 项目架构

```
WWIIHexV0/
├── Core/          — 核心数据模型（Division、GameState、HexTile、HexCoord、MapState 等）
├── Commands/      — 命令系统（Command、CommandResult、CommandValidation、GameCommandHandling）
├── Rules/         — 规则引擎（RuleEngine、CombatRules、SupplyRules、MovementRules、VictoryRules、CommandExecutor、CommandValidator）
├── Agents/        — AI Agent 管线（旧 Agent D + ZoneCommanderAgent / MarshalAgent）
├── Turn/          — 回合管理器（TurnManager，德军 AI 回合编排）
├── SpriteKit/     — 地图渲染（BoardScene、UnitNode、HexNode、HexLayout、TerrainStyle、BoardSceneAdapter）
├── UI/            — 界面组件（UnitInspectorView、EventLogView、HUDView、CommandPanelView、AgentPanelView、RootGameView）
├── App/           — 入口（AppContainer、WWIIHexV0App、WWIIHexV0MacApp）
├── Data/          — 场景数据（DataLoader、ScenarioDefinition JSON、general_agents.json、generals.json、sanguo_unit_templates.json、unit_templates.json、terrain_rules.json）
├── Probes/        — 历史高速探针测试 target（默认不执行）
└── Tests/         — 历史单元测试 / 集成测试 / 真实战局模拟（默认不执行）
```

### 核心架构原则

- **规则与 UI 解耦**：游戏状态只能由 `RuleEngine` 修改，UI 只读取状态
- **命令管线**：玩家 / AI → `Command` → `CommandValidator` 校验 → `CommandExecutor` 执行 → 日志
- **AI 接口可替换**：`DecisionProvider` 协议，MockAI 已实现，未来可插入本地 LLM
- **地图分层**：hex（战术层，`HexCoord`）+ region（省份层，`RegionId`）+ dynamic theater（运行时战区，`hexToTheater`），不替换
- **AI 命令与玩家命令共用同一管线**：都经 `RuleEngine` 校验执行

---

## AI / 指令管线接口（已落地）

当前同时保留两条管线：

- **Legacy Agent D 管线**：`AgentContextBuilder → DecisionProvider → AgentDecisionParser → AgentCommandMapper → RuleEngine`。已保留作回归参考，默认不再作为战争 AI 主路径。
- **ZoneDirective 管线（执行权威）**：`ZoneDirective → WarCommandExecutor → RuleEngine → WarDirectiveRecord`。`WarCommandExecutor.execute(_ directive:in:)` 不依赖具体 `ZoneCommanderAgent` 实例，手写合法 `ZoneDirective` 也可执行。
- **v0.5 元帅管线（默认上游）**：`MarshalAgent → MarshalBattlefieldSummarizer → SimulatedMarshalLLMClient → TheaterDirectiveDecoder → TheaterDirectiveCompiler → DirectiveEnvelope / ZoneDirective`。它只做战略意图、JSON I/O、解码校验和 fallback，不直接修改 `GameState`；`MarshalBattlefieldSummarizer` 的敌军强度、敌军存在和敌对 objective 分类按 `DiplomacyState` hostile / atWar 口径筛选，objective controller 来源仍来自地图事实。
- **v2.4 君主姿态塑形层**：`TurnManager` 在 `.marshalDirective` 和显式 `.zoneDirective` 执行前调用 `RulerAgent.adjust`，写入 `RulerDecisionRecord`，只调整 `DirectiveEnvelope`，不得绕过 `WarCommandExecutor -> RuleEngine`；`RulerStrategicSnapshot` 的敌对国家数来自 `DiplomacyState`，相邻敌军强度只统计外交 hostile 单位。
- **v2.4 外交提案与命令层**：`DiplomatAgent.plan` 接在君主层之后，读取国家、集团、关系和紧张度，写入 `DiplomatDecisionRecord`；`TurnManager` 会把有源国家和目标国家的提案转换为 `Command.proposeDiplomacy`，经 `CommandValidator -> CommandExecutor -> RuleEngine` 最小更新 `DiplomaticRelation.status/tension` 并写入 AI 命令结果。
- **v2.4 太守内政、修路与生产命令层**：`GovernorAgent.plan` 接在外交层之后，读取经济总账、郡县、道路、粮草和生产队列，写入 `GovernorDecisionRecord`；`TurnManager` 会把 `roadRepair` 焦点的首个重点郡县转换为 `Command.improveRoad`，经 `CommandValidator -> CommandExecutor -> RuleEngine` 消耗资源、优先从已有官道或外部官道入口连缀最多两格战术道路，并提升郡县基础设施；`recommendedProductionKind` 仍会转换为 `Command.queueProduction`，经同一规则链路校验资源并排入生产队列。
- **v2.4 军师目标编排层**：`StrategistAgent.plan` 承接君主姿态，重排目标 region、focus/support/convergence 和强度倾向，写入 `StrategistDecisionRecord`；它不生成底层 `Command`，不直接修改战术状态；`StrategistBattlefieldSnapshot` 的邻近敌对单位存在判断按 `DiplomacyState` hostile / atWar 过滤，region/controller 争夺语义保持不变。
- **v2.4 武将复核与战术塑形层**：`GeneralAgent.plan` 读取 `FrontZone.generalAssignment` 与武将 registry，对军师后的 `ZoneDirective` 和玩家武将面板宏观军令做忠诚/满意度/风格收束，并按武将技能把攻势塑形为突击、破阵、合围、箭雨/器械压制或佯攻，把守势塑形为固守、诱敌/退守、层层设防或死守；它只返回调整后的 `DirectiveEnvelope` 和 `GeneralDecisionRecord`，不绕过执行器，也不直接移动军队。AI 面板的武将审计会显示动作、战术、风格、目标郡县和理由；玩家计划军令会在面板显示执行前塑形后的武将、最终战术、源→目标、官道、源目受压和最近敌军对象/距离摘要，并在地图上显示武将/攻守/战术以及源目锚点官道/受压短标签；武将姓名、目标郡县或防区名缺失时显示中文占位，不直接暴露 raw id；武将面板的固守/进攻按钮灰掉时，会显示对应不可用原因或下一步选择提示。
- **v2.4 武将道路/交战规则**：`GeneralAssignment` 保存武将姓名、风格和技能快照；`GeneralSkillDisplay` 将 raw skill id 显示为粮道调度、骑兵突击、守备专精等中文标签，并为档案、军令面板和军队详情提供只读道路/交战效果短提示，规则仍使用原 id；`GeneralInfluence` 让武将影响 `MovementRules` 的道路机动上限，以及 `CombatRules` 的攻击/防御修正，且骑兵突击与粮道调度、疾行、甲骑专精共用借郡县官道网络的道路机动触发口径；`WarCommandExecutor` 在宏观军令选兵排序中使用有效机动，并用 `MovementRules.shortestPath` 判断目标郡县候选 hex 是否本回合可达，让武将官道机动、道路、敌控区、地形和占位共同影响 AI / 玩家武将宏观军令落点；`CommandExecutor` 会在移动日志中追加中文武将道路机动摘要，在攻击和反击日志中追加中文武将姓名、攻防修正摘要、交战审计和结算后剩余兵力，并通过 `CombatAuditSummary` 输出攻击/防御有效值、地形、河流、器械攻城、围城、死守和侧击等交战因素；`GeneralCommandPanelView` 显示当前选中防区的道路机动、官道受益军队或无加成原因、可见接敌攻防、当前可见接敌配对、最近可见敌军对象和麾下军队兵力/粮草/军令/行动/官道/接敌状态只读摘要，`UnitInspectorView` 会通过 `UnitInspectorStrategicState.generalAssignment` 显示选中军队所属武将、风格、忠诚/满意和带短效果提示的中文技能摘要，通过 `AppContainer.selectedUnitMobilityPreviewNotes` 显示选中军队的基础/有效机动、武将官道加成、玩家视角可见可达格数、当前位置官道可见受压或郡县官道状态、本回合可达官道、最近可达/可见安全官道距离、可见安全官道和受可见敌控区压迫的官道格数，通过 `selectedUnitCombatPreviewNotes` 显示最多三名玩家视角可见射程内敌军的首选理由、可见接战官道压制位、首选交战武将、候选敌将、候选武将修正、候选交战审计、预计伤害、结算后敌我剩余兵力、撤退/死守/断粮额外损失/歼灭风险、反击风险、目标地形/城关/官道/粮道/撤退姿态和距离排序；无可见射程内敌军但存在可见敌对军队时同一小节会显示最近可见敌军、接近候选、候选可达距/可见安全官道/入敌射风险、接近武将、非零接近参考修正、接近态势、接近威胁、需接近格数、可达更近官道位以及抵达官道后是否入射程；若当前无可见 hostile 敌军，则显示“当前无可预判敌对军队”空状态；首选目标继续显示武将影响详情，前三个候选目标行各自显示交战审计；`RegionInspectorView` 会从 `RegionInspectorState` 读取当前郡县官道覆盖、可见敌军造成的官道受压和最近来源、本郡武将、可见敌军相对选中地格或代表格的距离/射程/兵力/敌将、当前地格官道状态、可见敌对军队、可见非敌对军队及其势力/外交关系/紧张度摘要，且可见敌军/非敌对军队分组和官道受压来源优先按 `DiplomacyState` 的 `DiplomaticRelation.status` 判定，缺外交建档时才 fallback 到 `Faction.isHostile(to:)`，方便玩家判断修路、行军、粮道、交战和多势力态势；核心移动、攻击、反击、姿态、回合推进、动态方面事件日志和命令结果/拒绝原因已开始中文化；道路敌控区、粮道单位阻断、围城邻接、安全补员邻接、部署层敌军存在、相邻敌对防区接触、动态前线敌对接触、Legacy AgentContext 敌军摘要、MockAICommander 威胁估算、`MarshalBattlefieldSummarizer`、`ZoneCommanderAgent`、`RulerStrategicSnapshot`、`StrategistBattlefieldSnapshot` 单位级 AI hostile 摘要、玩家地图点击攻击、攻击高亮、武将宏观目标选择、`CommandValidator` / `RegionCommandValidator` 攻击目标校验、`WarCommandExecutor` 单位目标筛选和 `RegionCombatRules.pressure` 优先按 `DiplomacyState` 判定敌对，缺外交建档时 fallback 到 `Faction.isHostile(to:)`；objective / region controller 来源、非己方控制 hex/region 的部署压力分类、前线压力/补给/包围拓扑、encirclement 拓扑和非同 faction 堆叠阻挡仍保留原控制权/阵营语义，移动后自动占领的 controller 改写则按下一条 `OccupationRules.canOccupy` 外交 gate 收束。
- **v2.4 非敌对借道占领边界**：`OccupationRules.canOccupy` 只允许移动后自动占领无控制者或外交 hostile / atWar 控制格；allied、coBelligerent、neutral 控制格不会因道路经过或武将宏观军令移动被自动翻转 controller，`WarCommandExecutor` 也只把执行前真实可占领的移动作为动态方面突破依据，避免非敌对借道推进 `hexToTheater` / `hexToFrontZone`。
- **v2.4 上游 Agent fallback 显示名**：`RulerAgent.automatic`、`MarshalAgentConfig.automatic`、`TheaterCommanderPool.automatic` 和 `AppContainer.buildCommanderPool` 的缺省显示名使用 `Faction.displayName` / `shortDisplayName` 输出曹军/袁军等三国语义；`AgentRole.displayName` 显示为君主、军师、武将，减少 AI 面板和审计记录中的 German / Allied / Rundstedt / Eisenhower 题材残留。
- **v2.4 兼容武将 Agent 身份**：Legacy Agent D 的 `general_agents.json` 和 `GameAgent.guderianFallback` 继续保留 `guderian` 兼容 id、德军 rawValue 与旧单位分配校验，但默认展示武将改为张辽，personality 文案改成骑军突击、官道机动、兵力集中、快速合围和攻城支援语义；MockAI 启发式本身仍作为旧回归参考另行迁移。
- **v2.4 Agent 记录展示名兼容层**：`AgentDecisionRecord` 保留 raw `agentId`、`provider` 和原始 `rawJSON` 用于 Codable、parser 和回归审计，同时提供 `agentDisplayName`、`providerDisplayName` 与展示用调试 JSON；`TurnManager.contextSummary`、`AgentPanelView` 的 Agent/来源/子 Agent 字段、`AppContainer` AI 回合消息和交互日志使用张辽、兼容武将 AI、君主/外交/太守/军师/武将等中文展示名，不再把 `guderian` / `MockAI` 当作主 UI 文案。
- **v2.4 Agent 面板战略锚点展示名**：`AgentPanelView` 的外交对象、君主重点防区、外交/太守/军师目标郡县、武将摘要和防区指令摘要优先显示 `CountryProfile.name`、`RegionNode.name` 与 `FrontZone.name`；防区名缺失或仍等于 raw id 时，由 `RootGameView` 按势力简称和前 1-2 个郡县名生成 `曹军防区：官渡、许昌` 这类只读展示名。底层 `CountryId`、`RegionId`、`FrontZoneId`、记录 Codable 和调试 JSON 不变。
- **v2.4 HUD、菜单与军机面板三国化**：主 HUD 新局按钮、macOS 战局菜单、信息面板开关、紧凑面板 tab、`AgentPanelView` 标题/执行者字段、命令 fallback、`AppContainer` 军机回合消息、本地 mock / no-op 来源、兼容 fallback 指挥者名称和军队/郡县选择日志已改为中文三国语义；军队选择日志优先使用 `Division.thematicDisplayName`，底层记录、调试 JSON、命令管线和规则行为不变。
- **v2.4 Local LLM 提示词三国语义**：Legacy `LocalLLMDecisionProvider` 仍默认不启用，但 `AgentPromptBuilder` 的 system/user prompt 已从二战原型语义改为三国棋策、武将、军队、郡县、官道、粮草、围城压力和可见交战机会；`schemaVersion`、JSON keys、`move/attack/hold/resupply` rawValue、parser、mapper 和命令执行链保持不变。
- **v2.4 AppContainer 玩家交互日志三国化**：`AppContainer` 的 `interactionLog` 已将基础命令执行/拒绝、武将军令提交/拒绝、规则拒绝摘要、命令条数、手动指挥军队排除、查看/选择军队和选择地格/郡县等玩家可见文案改为中文三国语义；底层 `Command`、`ZoneDirective`、`WarDirectiveRecord`、Codable/rawValue 和执行管线不变。
- **v2.4 SupplyRules 撤退、围城与粮草日志三国化**：`SupplyRules` 的整补、围城恢复阻断、撤退、撤退失败、粮道断绝围城损耗、包围损耗和撤退整顿事件日志已改为中文，并使用军队主题展示名；撤退位置优先显示城池、关隘、郡县、官道或地形，坐标只作次级定位。补给路径、围城判定、撤退目的地、损耗数值、事件类别和规则执行不变。
- **v2.4 SupplyRules 控制格 hostile gate 外交化**：`SupplyRules.isSafeRetreatTile` 和粮道 `canSupplyPass` 的 capturable 控制格阻断改用 `DiplomacyState.isHostile(between:and:)`；非敌对控制格不再仅因旧 `Faction.isHostile(to:)` 阵营关系阻断粮道或撤退安全格。单位阻断、ZOC、补给源归属、堆叠限制、占领和共享补给制度边界不变。
- **v2.4 WarCommandExecutor 落点 hostile controller 外交化**：`WarCommandExecutor` 目标郡县候选和接近候选的“敌控格优先”排序改用 `DiplomacyState.isHostile(between:and:)`；非敌对控制格不再仅因旧二元阵营关系被宏观军令当成敌控优先落点。真实移动、攻击、占领、动态战区推进和借道边界仍由既有规则链路决定。
- **v2.4 命令结果中文化**：`CommandValidationError` 保留 rawValue / Codable 兼容，同时提供中文展示文案；`RuleEngine`、`WarCommandExecutor`、`TurnManager` 和 `AgentDecisionRecord` 会把玩家/AI 可见的成功、拒绝和校验原因写成中文，AI 面板不再直接展示常见校验枚举名；`CommandPanelView` 的不能下令状态按 `DiplomacyState` 区分敌军和非敌对军队。

| 文件 | 职责 | 关键类型/协议 |
|------|------|--------------|
| `Agents/DecisionProvider.swift` | 统一 AI 接口 | `protocol DecisionProvider { func decide(context:) async throws -> AgentDecisionEnvelope }` |
| `Agents/GameAgent.swift` | 运行时 agent 模型 | `GameAgent`（精简版，无 Cabinet/DirectiveDomain，v0.5 污染已剔除） |
| `Agents/AgentConfiguration.swift` | agent 加载 | `GameAgent.guderian(from:state:)`，保留兼容 id，优先 `general_agents.json` 的三国显示名，失败 fallback |
| `Agents/AgentContexts.swift` | agent 能看到的摘要 | `AgentContext` + `AgentContextBuilder`（无 organization，适配 v0.1） |
| `Agents/AgentDecision.swift` | 结构化决策 DTO | `AgentDecisionEnvelope` / `AgentOrder` / `AgentOrderType`（move/attack/hold/resupply） |
| `Agents/AgentDecisionParser.swift` | JSON → envelope | 校验 schemaVersion / agentId / turn，malformed 抛 typed error |
| `Agents/AgentCommandMapper.swift` | order → Command | `AgentCommandMapper.map(_:agentId:) -> IssuedCommand`，缺字段抛 error |
| `Agents/AgentDecisionRecord.swift` | 决策记录 | `AgentDecisionRecord` / `CommandResultSummary`（保留 raw id，提供展示名） |
| `Agents/MockAIClient.swift` | v0 默认 provider | 启发式：resupply → attack → move(向 Bastogne) → hold |
| `Agents/LLMClient.swift` | Legacy LLM 接口预留 | `protocol LLMClient` + `LLMRequest`（旧 Agent D 用，默认不启用） |
| `Agents/LocalLLMDecisionProvider.swift` | 本地 LLM provider | 注入 `LLMClient` + `AgentPromptBuilder` + parser，失败由上层 fallback MockAI |
| `Agents/AgentPromptBuilder.swift` | prompt 构造 | system + user prompt 三国语义，强制兼容 JSON 输出 |
| `Turn/TurnManager.swift` | 德军 AI 回合编排 | `runGermanAITurn(state:) async -> AgentTurnOutcome`（含 endTurn 推进） |
| `App/AppContainer.swift` | AI 接线 | `runAIIfNeeded()`（guard germany+germanAI → Task → 写 state/record），`lastAgentDecisionRecord` |
| `UI/AgentPanelView.swift` | 决策展示 | 读 `record` 与展示名映射（Agent/来源、国家/郡县/防区、intent、context、command results、errors、调试 JSON） |
| `UI/RootGameView.swift` | 启动触发 | `.task { container.runAIIfNeeded() }` |

**MockAI 行为（兼容 id `guderian`，三国显示名张辽，旧启发式仍待迁移）：**
跳过已行动单位 → 粮草紧张/粮道断绝优先 resupply → 射程内低兵力敌军优先 attack（器械优先压制城池/关隘）→ 机动军队沿道路向旧兼容目标 move → 否则 hold；可见 intent / reason 已改为三国官道、粮草、防区和器械语义，但 fallback 目标选择、stance 字符串、排序和评分仍保留旧兼容算法。

**v0.7 ZoneDirective 战术行为：**
`ZoneCommanderAgent` 读取所属 `FrontZone` 的前线/部署摘要，`visibleEnemyStrengthByRegion` 和敌军存在判断只统计 `DiplomacyState` hostile / atWar 单位；`BinaryTacticClassifier` 会结合兵力比、机动兵力、炮兵支援、纵深预备队、压力和补给警告，在 `standardAttack`、`blitzkrieg`、`spearhead`、`breakthrough`、`pincerMovement`、`fireCoverage`、`feint`、`guerrillaWarfare`、`holdPosition`、`elasticDefense`、`defenseInDepth`、`lastStand` 之间分类；`WarCommandExecutor` 将这些战术降级为 `move / attack / hold / allowRetreat`，仍统一交给 `RuleEngine` 校验执行。`WarDirectiveRecord` 记录 `category` / `tactic` / `commanderAgentId` / `commandTarget`，便于后续接真 LLM 回放与审计。

**v0.5 MarshalDirective 行为：**
`MarshalBattlefieldSummarizer` 把 `GameState` 降维为元帅摘要，只包含 front zone、strength ratio、补给警告、目标和事件，不把全量 hex 网格喂给模型；其中 enemy strength、敌军存在和 objectivesLost/hostile objective 名称分类按 `DiplomacyState` hostile / atWar 口径过滤，objective controller 来源仍来自 tile controller。`SimulatedMarshalLLMClient` 生成 fenced JSON 形式的 `TheaterDirectiveEnvelope`；`TheaterDirectiveDecoder` 提取并校验 JSON；`TheaterDirectiveCompiler` 把元帅意图编译成现有 `ZoneDirective`。v0.7 后 `TheaterDirective` 可携带 `convergenceRegionId` / `coordinatedZoneIds` 支持钳形会师意图；解码或编译失败时 fallback 到 `TheaterCommanderPool`，不执行半成品 LLM 输出。

**Ruler / Diplomat / Governor / Strategist / General 边界：**
君主层当前记录国家姿态、优先防区、目标 region 和理由；外交层承接君主姿态并提出同盟、停战、借道、称臣、讨伐檄文或奉表勤王等提案；太守层承接君主与外交上下文并提出征兵、修路、屯田、治安或补给建议；军师层再编排目标 region、支援 region 和会师 region；武将层读取防区武将分配，对 AI 军令和玩家武将面板宏观军令的投入强度、预备队和 `ZoneDirective.tactic` 做最后复核。外交 Agent 本身不直接改关系，只有 `Command.proposeDiplomacy` 经规则层可以最小更新关系状态/紧张度；太守 Agent 本身不直接排产或改路，只有 `Command.queueProduction` / `Command.improveRoad` 经规则层可以校验资源并写生产队列或修缮道路；武将快照会进入战术选择、道路机动和交战攻防计算，交战因素审计会进入攻击/反击日志，武将面板只读展示同一套道路/交战摘要，但仍由 `MovementRules`、`CombatRules`、`WarCommandExecutor` 和 `RuleEngine` 统一执行，不能直接改地图、军队、资源或动态战区。

---

## 当前完成进度

### ✅ v0：六角格测试板（已完成）

**场景**：阿登测试战场（Ardennes），德军 vs 盟军，11×9 六角格地图

| 功能模块 | 状态 |
|----------|------|
| 六角格 axial 坐标系统 | ✅ |
| 地形系统（平原/森林/山地/城市/道路/河流/要塞） | ✅ |
| 移动系统（地形消耗、道路加成、跨河惩罚、敌方阻挡） | ✅ |
| 战斗系统（近战/炮兵远程、地形防御修正、反击） | ✅ |
| 侧翼/背后加成 | ✅ |
| 占领系统（城市控制权变更） | ✅ |
| 补给系统（supplied / lowSupply / encircled） | ✅ |
| 包围判定与惩罚 | ✅ |
| 回合系统（德军 AI 先手 → 盟军玩家 → 结算） | ✅ |
| MockAI 将领 agent（guderian，装甲突破风格） | ✅ |
| 结构化 JSON 命令解析与校验 | ✅ |
| AI 决策日志面板（AgentPanelView 读 AgentDecisionRecord） | ✅ |
| 胜利条件（巴斯托涅占领 / 消灭 3 单位 / 切断补给） | ✅ |

---

### ✅ v0.1：strength、撤退与补员（已完成）

| 功能模块 | 状态 |
|----------|------|
| `Division` 升级为 strength/maxStrength，保留 hp/maxHP 兼容 | ✅ |
| 战斗改为 strength 伤害（organization 已移除） | ✅ |
| 撤退状态：自动寻找安全相邻格撤退 | ✅ |
| 撤退失败施加额外惩罚 | ✅ |
| `resupply/rest` 恢复 strength | ✅ |
| 包围每回合扣 strength | ✅ |
| UI 显示 Strength、Retreating 状态 | ✅ |
| 日志按 combat/retreat/reinforce/encircle/supply 分类 | ✅ |
| 死守 / 允许撤退（RetreatMode）按钮与 HOLD 防御加成 | ✅ |

**v0.1 最终模型：** 只看兵力，无 organization。`RetreatMode`（retreatable/hold）控制撤退：HOLD 防御 +20%，RETREATABLE 单次损失比例 ≥ 35% 自动撤退。

---

### ✅ Agent D：AI/Agent 决策管线（已完成）

| 功能模块 | 状态 |
|----------|------|
| `DecisionProvider` 协议（MockAI + LocalLLM 共用） | ✅ |
| `AgentContext` / `AgentContextBuilder`（Codable 摘要，无 UI/SpriteKit 对象） | ✅ |
| `AgentDecisionEnvelope` / `AgentOrder` JSON schema | ✅ |
| `AgentDecisionParser`（校验 schema/agent/turn） | ✅ |
| `AgentCommandMapper`（order → Command，缺字段抛 error） | ✅ |
| `MockAIClient`（guderian 启发式，向 Bastogne 推进） | ✅ |
| `LLMClient` / `LocalLLMDecisionProvider` / `AgentPromptBuilder`（预留，v0 默认关） | ✅ |
| `TurnManager`（德军 AI 回合编排，含 endTurn） | ✅ |
| `AppContainer.runAIIfNeeded()`（启动自动跑 AI 回合） | ✅ |
| `AgentDecisionRecord` + `AgentPanelView`（UI 读决策记录） | ✅ |
| `AgentPipelineTests`（8 测试：context/MockAI/parser/mapper/provider 失败/非法命令） | ✅ |

---

### ✅ v0.2 Agent 1：省份图架构（已完成）

省份图规则层模型。**叠加，不替换 hex。** hex 仍战术层权威坐标，province 是战略层聚合。

| 文件 | 职责 |
|------|------|
| `Core/Region.swift` | `RegionId`（RawRepresentable<String>）、`RegionNode`、`RegionEdge`、`RegionGraph`、`CityInfo`、`ResourceAmount`、`ResourceType`、`OccupationState`、`RegionEdgeKey`（对称键）、`RegionValidationError`（9 case） |
| `Core/MapState.swift`（改） | 加 `regions`/`hexToRegion`/`regionEdges` 字段（默认空）；加 province 查询：`region(for:)`/`region(id:)`/`neighbors(of:)`/`areAdjacent`/`edgeBetween`/`representativeHex`/`regionDistance`/`regionGraph`；加 `validateRegionGraph()` |
| `Core/Terrain.swift`（改） | `HexTile` 加 `regionId: RegionId?`（默认 nil） |
| `RegionGraph.validate()` | idMismatch/emptyDisplayHexes/representativeHexNotInDisplayHexes/neighborNotFound/neighborNotBidirectional/edgeEndpointNotFound/edgeNotInNeighbors |
| `MapState.validateRegionGraph()` | 复用上图校验 + hexToRegionPointsToMissingRegion + displayHexesOverlap |
| `Tests/RegionGraphTests.swift` | 19 测试：编解码/neighbors/areAdjacent/hexToRegion/representativeHex/validate 全错误类型+valid+empty |

**设计约束（Agent 1 已守）：**
- hex 规则全保留，province 默认空不破现有行为
- `MapState.ardennesV0()` 不改（保持纯 hex，测试用）
- 省份挂载在 Data 层（DataLoader），Core 不依赖 Data

---

### ✅ v0.2 Agent 2：省份数据层（已完成）

阿登 v0.2 省份图数据 + 加载。17 省覆盖全部 99 hex，零重叠，邻接双向一致。

| 文件 | 职责 |
|------|------|
| `Data/ardennes_v02_regions.json` | 17 省/41 边/99 hex 映射/2 补给源/4 目标。schemaVersion 2 |
| `Data/RegionDataSet.swift` | `RegionDataSet` + Codable 定义（`RegionNodeDefinition`/`CityInfoDefinition`/`ResourceAmountDefinition`/`OccupationStateDefinition`/`RegionEdgeDefinition`/`RegionSupplySourceDefinition`/`RegionObjectiveDefinition`）+ 映射 `toRegions()`/`toRegionEdges()`/`toHexToRegion()` |
| `Data/DataLoader.swift`（改） | 加 `loadArdennesV02Regions()` + `validate(_ regionData:)`（复用 validateRegionGraph）；`loadInitialGameState()` 叠加省份数据（try? 失败 fallback 纯 hex）+ 反向填 HexTile.regionId |

**省份设计：**
- 德方控制：german_east_depot（补给源）、eifel_approach、schnee_eifel
- 盟方控制：allied_west_depot（补给源）、bastogne（主目标 VP5）、bastogne_fortress、st_vith、western_approach
- 中立（owner/controller null 映射为 `.neutral`，不再回退到任一参战方）：meuse_approach、houffalize、luxembourg_road、ardennes_forest_north/central/south、northern_ridge、southern_ridge、northern_frontier
- 路径：german_east_depot→bastogne=2，allied_west_depot→bastogne=3

| `Tests/ArdennesV02DataTests.swift` | 17 测试：解码/region 数/hexToRegion 覆盖/validate/邻接双向/repHex/路径连通/补给源/目标/关键省/控制权 |

---

### ✅ v0.3：战区、前线、部署、战争指令（当前主线，已推进至 v0.37）

| 版本 | 主题 | 关键内容 |
|------|------|----------|
| **v0.31** | Theater 战区层 | 四战区初始化、控制比例、70% 阈值、扩张/退役接口 |
| **v0.32** | FrontLine 前线层 | 动态前线、segment、dirty 更新、简化包围识别 |
| **v0.33** | WarDeployment 部署层 | FRONT / DEPTH / GARRISON 分层，FrontZone 单元池 |
| **v0.34** | 地图编辑器 | 默认地图与项目 schema 打通 |
| **v0.351** | 初级战争指令 | `ZoneDirective` / `WarCommandExecutor` / `MockAICommander` |
| **v0.352** | 新管线唯一化 | `WarPipelineMode.zoneDirective` 默认，观察者模式，分层战略 UI |
| **v0.353** | 默认地图验收 | hex controller 成为归属权威，补给归属跟随占领者 |
| **v0.354** | 联动修复 | 占领→region→theater→frontline 同回合联动，ZOC 友军穿越修正，拒绝率治理 |
| **v0.355** | 动态/初始战区分离 | `initialSnapshot` 与运行时动态战区分离，前线 overlay 与观察者 UI |
| **v0.356-v0.357** | 地图/前线 UI 修正 | 编辑器与游戏视角统一、开局单位越界检查、前线按战区/segment 着色 |
| **v0.358** | hex 动态战区语义收口 | 动态战区改跟 `hexToTheater`，region 基础战区只作初始/生成参照；AI/部署/前线测试同步更新 |
| **v0.36** | 命令层扩展与多将领 MockAI | `CommandCategory` / `TacticName` / `DirectiveTarget` / `ZoneCommanderAgent` / `TheaterCommanderPool` |
| **v0.37** | 命令层统一整合 | 移除 `TurnManager` 的 `MockAICommander` fallback，默认路径收口到 `TheaterCommanderPool`；补 issuer-agnostic executor 探针 |
| **v0.5** | 元帅层与模拟 LLM JSON | `MarshalAgent` / `TheaterDirectiveEnvelope` / decoder / compiler / marshal fallback |
| **v0.7** | 高级战术与命令扩展 | 闪电战、定点矛头、突破、钳形攻势、火力覆盖、佯攻、游击战、弹性防御、纵深防御、死守 |

### ⏳ 后续方向

| 版本 | 主题 | 关键内容 |
|------|------|----------|
| **v0.4** | 聊天命令与角色服从 | 玩家通过聊天框命令将领；将领根据性格/忠诚回应；命令可被质疑/拖延/抗命 |
| **v0.5** | 元帅决策链与模拟 LLM JSON | `MarshalAgent`、`TheaterDirectiveEnvelope`、JSON decoder、compiler、fallback；统治者只预留为后续上游，不恢复 Cabinet/Minister |
| **v1.0** | 大战略原型 | 经济/科技/生产；空军实体化；简化海军；天气；多国家多战区；全球地图；美术资源 |
| **v1.x** | 多回合战术行动 | 撤退命令、突破/闪电战、装甲差异化、`AttackIntensity` 深度分流等复杂多回合行动骨架 |

**v0.37 决策记录：** 撤退、突破、闪电战、装甲差异化和 `AttackIntensity` 深度分流推迟至 1.x。v1.0 只先把 `infiltration` 解释为默认低投入上限，不引入额外伤害、绕规则推进或多回合追踪行动。

---

## 核心设计约束

**LLM 使用原则（必须始终遵守）：**
1. 不让每个单位每回合都调用 LLM
2. LLM 只读取摘要，不读取完整地图
3. LLM 输出必须经过 `CommandValidator` 校验才能执行
4. 非法命令先尝试自动修复，修复失败则丢弃并记录日志
5. 没有 LLM 时，MockAI 接管所有决策

**架构扩展约束（后续 agent 必须遵守）：**
- 不要跳过命令管线直接修改 `GameState`
- **不要替换 HexCoord 坐标系**：hex 是战术层，province 是叠加的战略层，两者共存
- **不要把 `regionToTheater` 当动态战区推进层**：运行时战区归属看 `hexToTheater`，突破只推进 hex。
- **不要给 Division 加回 organization**：v0.1 已移除，只看兵力
- **不要引入 v0.5 Cabinet/StrategicDirective/Minister 污染**：v0.5 误删事件已发生，GameAgent 保持精简版
- 新增系统通过 `DecisionProvider` / `RuleEngine` / `Command` 接入，不直接改核心规则
- 保持核心语义不退步；默认只做轻量检查，Xcode / XCTest / 模拟器等重测试必须由人工明确授权。

---

## 文档索引

```
md/
├── 项目总规划.md                    — 整体设计目标、地图方案、LLM 架构、长期路线图
├── v0测试/
│   ├── phase0_v0_minimum_scope.md   — v0 最小可玩范围定义、数据结构清单
│   ├── phase1_hex_core_rules.md     — 六角格坐标、地形、战斗、补给、包围详细规则
│   ├── phase3_v0_engineering_architecture.md — v0 工程架构设计
│   ├── 阶段性4:第一版可玩测试板任务拆解.md  — v0 任务拆解和实现步骤
│   └── 误删agentD/                  — Agent D 打捞代码 + jsonl 会话记录（历史归档）
└── v0.1～1.0提示词/
    ├── 总体长期规划.md              — v0 至 v1.0 路线图全览
    ├── v0.1.md                      — v0.1 子 agent 提示词（已完成）
    ├── v0.2.md                      — v0.2 提示词（⚠️ 旧版纯省份替换方案，已废弃；新版见下方）
    ├── v0.3.md                      — v0.3 前线系统提示词
    ├── v0.4.md                      — v0.4 聊天命令与角色服从提示词
    ├── v0.5.md                      — v0.5 国家与部长 agent 提示词
    └── v1.0.md                      — v1.0 大战略原型提示词
```

> ⚠️ `v0.2.md` 是旧的"纯省份替换 hex"方案，已废弃。v0.2 新方向见本文档"地图架构"与"v0.2"行：**省份叠加，不替换 hex**。

---

## 给后续 Claude Code 的提示

**你接手时的代码库状态：**
- v0.5 分支已引入元帅层与模拟 LLM JSON/decoder/ compiler；历史测试基线曾达到 v0.37 Probe 18/0、Stage Regression 69/0、Full 226/0。当前默认不跑重测试，只做 `md/test/test.md` 允许的轻量检查。
- 战斗模型：兵力伤害为主，`RetreatMode`（retreatable/hold）控制撤退，无 organization。
- 默认战争 AI 管线：`MarshalAgent` 读取摘要并模拟输出 `TheaterDirectiveEnvelope` JSON，经 `TheaterDirectiveDecoder` 与 `TheaterDirectiveCompiler` 降级成 `ZoneDirective`，再由 `RulerAgent.adjust` 做君主姿态塑形、`DiplomatAgent.plan` 做外交提案并经 `Command.proposeDiplomacy` 最小执行、`GovernorAgent.plan` 做太守内政建议并经 `Command.improveRoad` / `Command.queueProduction` 尝试修路和排产、`StrategistAgent.plan` 做军师目标编排、`GeneralAgent.plan` 做武将复核，最后走 `WarCommandExecutor`。`TheaterCommanderPool` / `ZoneCommanderAgent` 仍作为 fallback 和显式 `.zoneDirective` 路径，执行前同样经过君主、外交、太守、军师和武将层；玩家武将面板生成的宏观 `ZoneDirective` 也会先经 `GeneralAgent.plan` 塑形，再进入 `WarCommandExecutor`，但不会自动结束玩家回合。
- Legacy Agent D 管线保留但默认不调用。
- 地图坐标系：hex 仍是战术权威；Region 是省份规则层；动态战区看 `hexToTheater`。

**继续开发前请先阅读：**
1. 本 README（地图架构三层决策 + Agent D 接口表）
2. `WWIIHexV0/Core/Division.swift`（当前 Division 模型）
3. `WWIIHexV0/Core/MapState.swift` / `Region.swift` / `Theater.swift`
4. `WWIIHexV0/Rules/TheaterSystem.swift` / `FrontLineManager.swift` / `WarDeploymentManager.swift`
5. `WWIIHexV0/Commands/WarDirective.swift` / `WarCommandExecutor.swift`
6. `WWIIHexV0/Agents/ZoneCommanderAgent.swift` / `MockAICommander.swift`
7. `md/prompt/anti生成/v0.5/anti/0.50_v0.5_marshal_implementation_record.md`

**当前必须遵守：**
- 不删 `HexCoord`，不把运行时战区推进退回 region 粒度。
- `Initial Theater Layout` / `regionToTheater` 是地图编辑器与动态演化基准，不是实时前线。
- `Dynamic Theater State` / `hexToTheater` 是游戏战区层权威。
- 前线 UI 和 AI target 选择必须基于动态 hex 邻接；历史测试 fixture / 语义文档也必须构造真实相邻 hex，不能只声明 region 邻接。
- `ZoneDirective` 新字段必须保持 Codable 向后兼容。
- 元帅层、君主姿态塑形层、外交提案层、太守内政建议层、军师目标编排层和武将复核层不得绕过 `Command / ZoneDirective -> WarCommandExecutor / RuleEngine`；外交关系变更只能走 `Command.proposeDiplomacy -> CommandValidator -> CommandExecutor`，生产队列变更只能走 `Command.queueProduction -> CommandValidator -> CommandExecutor`，修路只能走 `Command.improveRoad -> CommandValidator -> CommandExecutor`。
- 当前 v0.5 只模拟 LLM JSON 接口，不接真实模型；真实 LLM 接入必须保留 decoder 校验与 fallback。

**轻量检查与云端验证**（每轮先读 [`md/test/test.md`](md/test/test.md)，默认本机禁止 Xcode / XCTest / 模拟器 / 性能类测试；重验证由 GitHub Actions 结果包承接）：
```bash
rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md
```
旧测试口径残留、JSON / project / scheme 检查按 `md/test/test.md` 追加执行。未获人工授权时，本机不跑历史 Probe / Stage / Full；需要重验证时 push 到 `origin/main`，由 `ci-results` workflow 上传 artifact 给 Agent C 复判。
