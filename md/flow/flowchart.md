# 三国棋策 Agent Mermaid 核心流程图（v2.4 君主/外交/太守/军师/武将指令编排、外交与太守生产命令、武将战术塑形、道路、粮道和交战兼容层）

> 本图参照 `md/flow/flow.md`。项目正从 `WWIIHexV0` 二战原型迁移到三国题材；v2.4 当前完成官渡默认剧本预览、三国兵种模板兼容层、战术审计显示三国化、围城/粮草最小规则、兵种克制最小规则和君主/外交/太守/军师/武将指令编排、外交与太守生产命令、武将战术塑形、道路、粮道与交战兼容层，图中仍保留 `Division`、`Faction`、`Theater`、`FrontZone` 等代码名，中文解释已按三国迁移口径理解为军队、势力、方面、防区。

## 0. 读图总纲

项目当前最重要的逻辑是：

```text
地图编辑器/JSON 数据
  -> 游戏启动加载为 GameState
  -> hex 是真实战术权威
  -> region / theater / front / deploy 都是从 hex 和军队位置派生出来的战略层
  -> economy 是势力级钱粮总账，收入仍从真实控制的 hex/region 聚合
  -> v2.4 接入官渡默认剧本、三国兵种模板、战术显示、围城/粮草、兵种克制和君主/外交/太守/军师/武将指令编排、外交与太守生产命令、武将战术塑形、道路、粮道与交战
  -> 玩家和 AI 都必须把命令交给 RuleEngine
  -> 命令执行/拒绝原因中文化后再同步刷新战略层和 UI
```

v2.4 命名边界：

- `Faction.germany/allies` 仍是源码和旧 JSON 兼容 rawValue；UI 当前显示为曹操势力 / 袁绍势力。
- 默认新局优先加载 `guandu_200_scenario.json` / `guandu_200_regions.json`；旧阿登数据保留作 fallback。
- 单位模板优先加载 `sanguo_unit_templates.json`；缺文件时才 fallback 到旧 `unit_templates.json`。
- `Faction` 可解码 `cao`、`yuan`、`liuBei`、`sun`、`liuBiao`、`maTeng`、`han`、`neutral`；`Faction.scenarioCases` 给 MapEditor、场景数据和战略派生层控制计算使用。
- 默认 `Faction.activeTurnCases` / 兼容 `Faction.allCases` 仍只枚举当前可行动双方，新增三国势力不参与旧回合循环。
- null / 缺省的 `RegionDataSet` owner/controller 会映射到 `.neutral`，不会再 fallback 给 `.allies`。
- Theater / FrontLine / WarDeployment / Region visibility 派生层会识别 `Faction.scenarioCases` 中的三国势力，不再只看旧二元回合列表。
- `DiplomacyState.initial` 能生成三国基础 country / bloc profile，默认曹袁为 `atWar`，其他新势力默认中立关系。
- 规则、AI 摘要、MockAI 威胁估算和 `WarCommandExecutor` 单位目标筛选中的敌对判断不在新代码里继续依赖二元 `opponent`；攻击合法性、玩家点击/高亮、道路 ZOC、粮道单位阻断、粮道控制格通行、撤退安全格控制格、宏观军令落点敌控优先级、围城邻接、安全补员邻接、部署层敌军存在、相邻敌对防区接触、动态前线敌对接触、ZoneCommanderAgent / MarshalBattlefieldSummarizer / RulerStrategicSnapshot / StrategistBattlefieldSnapshot 单位级 AI hostile 摘要、执行器单位目标筛选和区域交战压力优先使用 `DiplomacyState` 的 hostile / atWar 口径，缺外交建档时 fallback 到 `Faction.isHostile(to:)`。
- `Division` 仍是源码单位类型；UI 当前显示为军队、步卒营、骑兵军、器械营、弓弩营、亲卫营、舟师营。
- `ComponentType` 保留旧 `tank/motorizedInfantry/infantry/artillery` rawValue，并新增 `cavalry/archer/siegeEngine/naval/guard` 给三国模板使用。
- `TacticName` 保留旧 rawValue 作为指令 schema，但 UI / `WarDirectiveRecord` 显示使用正攻、疾袭、突击、破阵、合围、箭雨/器械压制、佯攻、奇袭/袭扰、固守、诱敌/退守、层层设防、死守。
- `SupplyRules.isBesieged` 以城池/关隘、粮道断绝、敌军邻接判定围城；`CombatRules.effectiveDefense` 对围城守军降低有效防御，恢复仍沿用 supplied / 安全后方规则。
- `CombatRules.effectiveAttack` 和 `MovementRules` 已表达骑兵平原优势、困难地形限制、弓弩/器械远程和器械攻城加成；`CombatRules.combatAuditSummary` 会把地形、河流、攻城、围城、死守和侧击等交战因素写成只读审计摘要；`GeneralAgent` 会按武将风格/技能塑形 `ZoneDirective.tactic`，`GeneralSkillDisplay` 会把技能 raw id 中文化展示并提供只读道路/交战效果短提示，`GeneralInfluence` 让武将分配影响道路机动和交战攻防，其中骑兵突击与粮道调度、疾行、甲骑专精共用借郡县官道网络的道路机动触发口径。
- `WarCommandExecutor` 的宏观军令选兵排序和目标郡县候选 hex 可达判断已读取 `MovementRules.effectiveMovementLimit` / `shortestPath`，目标郡县候选和接近候选的敌控格优先级也按 `DiplomacyState` hostile / atWar 判断，让武将官道机动、道路、外交敌对控制格、敌控区、地形和占位影响 AI / 玩家武将宏观军令落点；`CommandExecutor` 会把中文武将姓名、道路机动、交战审计、攻防修正摘要和结算后剩余兵力写入移动、攻击和反击日志；`BoardScene` 会只读 `PlayerCommandState.plannedOperations`，把玩家宏观军令画成源点、目标点、进攻箭头或固守圆环，并显示武将/攻守/短战术、源目锚点官道状态、可见敌军压迫和最近可见敌军短标签；`GeneralCommandPanelView` 会只读显示当前防区道路机动、官道受益军队或无加成原因、可见接敌攻防、当前可见接敌配对、最近可见敌军对象和麾下军队兵力/粮草/军令/行动/官道/接敌状态摘要，也会通过 `AppContainer.selectedGeneralPlannedOperationRows` 在计划军令列表显示武将、最终战术、源→目标、官道状态、源目可见受压和最近可见敌军对象/距离，并通过 `AppContainer.selectedGeneralTargetPreviewNotes` 在提交进攻前显示目标郡县源/目标代表 hex 的官道据守/受压和最近可见敌军距离；武将面板固守/进攻按钮不可用时，`AppContainer` 生成只读原因，`GeneralCommandPanelView` 只展示原因，不改变真实军令执行；`UnitInspectorView` 会通过 `UnitInspectorStrategicState.generalAssignment` 显示选中军队所属武将、风格、忠诚/满意和带短效果提示的中文技能摘要，通过 `AppContainer.selectedUnitMobilityPreviewNotes` 对选中军队显示基础/有效机动、武将官道加成、玩家视角可见可达格数、当前位置官道可见受压或郡县官道状态、本回合可达官道、最近可达/可见安全官道距离、可见安全官道和受可见敌控区压迫的官道格数，通过 `selectedUnitCombatPreviewNotes` 显示最多三名玩家视角可见射程内敌军的首选理由、可见接战官道压制位、首选交战武将、候选敌将、候选武将修正、候选交战审计、预计伤害、结算后敌我剩余兵力、撤退/死守/断粮额外损失/歼灭风险、反击风险、目标地形/城关/官道/粮道/撤退姿态和距离排序；无可见射程内敌军但存在可见敌对军队时显示最近可见敌军、接近候选、候选可达距/可见安全官道/入敌射风险、接近武将、非零接近参考修正、接近态势、接近威胁、需接近格数、可达更近官道位和抵达官道后是否入射程；无可见 hostile 敌军时显示当前无可预判敌对军队空状态；首选目标继续显示武将影响详情，前三个候选目标行各自显示交战审计；`RegionInspectorView` 会显示当前郡县官道覆盖、可见敌军造成的官道受压和最近来源、本郡武将、可见敌军距离/射程/兵力/敌将、当前地格官道状态、可见敌对军队、可见非敌对军队及势力/外交关系/紧张度；这些 UI 只读复用移动/交战/地图派生计算，不执行命令；核心移动、攻击、反击、姿态、回合推进、动态方面事件日志和命令结果/拒绝原因已开始中文化，便于审计“武将做了什么、命令为什么失败”。
- `GeneralData.rank` raw 字段保留数据兼容；`GeneralCommandPanelView` 和 `GeneralProfileView` 使用 `rankDisplayName` 将旧英文 fallback 军衔显示为三国语义军衔，头像辅助功能文案使用中文“头像”。
- `AgentPanelView` 的主审计字段、君主/外交官/太守/军师/武将记录和防区指令摘要优先使用展示名；标题、执行者和命令 fallback 已显示为军机谋议、执行者和军令，外交对象来自 `CountryProfile.name`，郡县来自 `RegionNode.name`，防区来自 `FrontZone.name` 或 `曹军防区：官渡、许昌` 这类只读 fallback，调试 JSON 和 Codable raw id 保持原样。
- `RootGameView` / HUD / macOS 菜单 / `InfoPanelToggle` / `AppContainer.interactionLog` 的玩家可见文本也已中文优先：新开战局、结束回合、军情、军机回合、本地 mock / no-op 来源、兼容 fallback 指挥者名称、基础命令执行/拒绝、武将军令提交/拒绝、规则拒绝摘要、命令条数、手动指挥军队排除、查看/选择军队和选择地格/郡县都显示为三国语义；军队点击日志使用 `Division.thematicDisplayName`，底层命令、记录 id、Codable 和 rawValue 不变。
- Legacy `LocalLLMDecisionProvider` 默认不启用，但 `AgentPromptBuilder` 的提示词已改为三国棋策、武将、官道、粮草和可见交战语义；JSON schema、字段名、命令 rawValue、parser / mapper 和命令执行链保持兼容。
- `MovementRules.isEnemyZoneOfControl`、`SupplyRules` 粮道单位阻断、粮道控制格通行、撤退安全格控制格和围城邻接、`EconomyRules` 安全补员邻接、`WarDeploymentManager` 单位级敌军存在和相邻敌对防区接触、`FrontLineManager` 动态相邻 theater 是否形成敌对前线、Legacy `AgentContextBuilder` 敌军摘要、`MockAICommander.visibleEnemyStrength`、`ZoneCommanderAgent` / `MarshalBattlefieldSummarizer` / `RulerStrategicSnapshot` / `StrategistBattlefieldSnapshot` 单位级 AI hostile 摘要、`CommandValidator` / `RegionCommandValidator` 攻击目标校验、`CommandExecutor.executeAttack` 防绕过 guard、玩家地图点击攻击、可见攻击高亮、武将宏观目标选择、`WarCommandExecutor` 单位敌军强度/存在/目标筛选和宏观军令落点敌控优先级、`RegionCombatRules.pressure`、郡县检查器的可见敌军/非敌对军队分组、官道受压计数和最近来源，`AppContainer` 的军队接战预判、武将麾下/目标/计划军令近敌与受压摘要、移动预览可见敌控过滤和点击日志敌对措辞，以及 `BoardScene` 计划军令地图短标签、部署图层角色 fallback、`CommandPanelView` 状态文案、`GeneralCommandPanelView` 目标预览显示 gate，优先使用 `DiplomacyState` 的 `DiplomaticRelation.status`，缺建档时 fallback 到 `Faction.isHostile(to:)`；objective 和 region controller 来源仍保持 controller / occupation 事实，只在 hostile 分类时使用外交关系；`OccupationRules.canOccupy` 只允许无控制者或外交 hostile / atWar 控制格被自动占领，`WarCommandExecutor` 只把执行前真实可占领的移动作为动态方面突破来源；`MovementRules` 的非同 faction 堆叠阻挡、部署控制权、`FrontLineManager` 的 pressure / supplyImpact / encirclementCandidate 和 `WarDeploymentManager` encirclement 拓扑仍保留原语义；只读预判和高亮还会按玩家视角可见性过滤；中立不会只因不是当前阵营就阻断道路、阻断粮道控制格、阻止撤退安全格、被宏观军令当成敌控优先落点、生成敌对部署接触、生成敌对前线、进入 AI 敌军摘要、影响 MockAI 威胁、被自动占领或成为合法攻击目标。
- `RegionSupplyRules` 的战略郡县粮道控制区通行和撤退安全郡县也使用同一 `DiplomacyState` hostile / atWar 口径；中立、停战、同盟或共同作战 controller 不会仅因旧二元阵营关系阻断战略郡县粮道或战略撤退安全郡县。
- `TurnManager` 在 `.marshalDirective` 和显式 `.zoneDirective` 执行前调用 `RulerAgent.adjust`、`DiplomatAgent.plan`、`GovernorAgent.plan`、`StrategistAgent.plan` 与 `GeneralAgent.plan`；外交提案可转换为 `Command.proposeDiplomacy` 经规则层最小更新关系，太守修路焦点可转换为 `Command.improveRoad` 经规则层连通优先修缮道路，太守生产建议可转换为 `Command.queueProduction` 经规则层排产，武将层会把军令 tactic 收束为合法攻守战术。玩家武将面板宏观命令也会先经 `GeneralAgent.plan` 塑形 tactic，再进入 `WarCommandExecutor -> RuleEngine`，但不会自动结束玩家回合。
- `Region` 显示为郡县，`Theater` 显示为方面，`FrontZone` 显示为防区。
- 正式三国大地图、完整多势力 turn order、真实借道/贡赋/臣属制度和发布级 UI 后续分阶段实现。

图里颜色含义：

- 红色：权威状态，不能被下游反向覆盖。
- 绿色：派生状态，可以重建，但来源必须清楚。
- 蓝色：初始快照/基准状态，不是运行时推进状态。
- 紫色：命令管线，玩家、AI、未来聊天命令都要走这里。

## 1. 总主线：从地图数据到游戏行动

这张图看全局。左上是地图数据怎么进入游戏；中间是 hex、region、theater、front、deploy 的分层关系；右侧是玩家/AI 命令如何统一进入规则系统；底部是 UI 和日志怎么读取结果。

```mermaid
flowchart TD
    ME["地图编辑器<br/>MapEditor<br/>用来画格子、省份、战区、初始部队"]:::editor
    JSON["游戏数据 JSON<br/>ScenarioDefinition + RegionDataSet<br/>保存地图、单位、省份、初始战区"]:::data
    DL["数据加载器<br/>DataLoader.loadGameState<br/>把 JSON 变成可运行 GameState"]:::loader
    GS["运行时总状态<br/>GameState<br/>一局游戏所有状态都在这里"]:::state

    HEX["战术权威：六角格和单位位置<br/>HexTile.controller + Division.coord<br/>谁占哪个格、单位在哪，先看这里"]:::authority
    REGION["省份战略层<br/>RegionNode<br/>资源、补给、胜利点；控制权由 hex 聚合"]:::derived
    INIT["开局战区快照<br/>TheaterInitialSnapshot<br/>记录地图编辑器给的初始战区"]:::snapshot
    R2T["基础战区映射<br/>regionToTheater<br/>只作初始/基准，不表示战线推进"]:::snapshot
    H2T["动态战区权威<br/>hexToTheater<br/>运行时推进只改具体 hex"]:::authority
    FRONT["前线层<br/>FrontLine / FrontSegment<br/>按双方动态战区的真实相邻 hex 生成"]:::derived
    DEPLOY["部署层<br/>WarDeploymentState<br/>用 hexToFrontZone 把单位分成前线/纵深/驻军"]:::derived
    ECO["经济总账<br/>EconomyState / EconomyRules<br/>收入、维护费、生产队列、自动补员"]:::economy
    PLAYER["玩家输入<br/>点击地图、移动、攻击、结束回合"]:::input
    PGEN["玩家武将面板宏观军令<br/>GeneralCommandPanelView<br/>固守战线 / 进攻郡县"]:::input
    PZD["玩家 ZoneDirective<br/>AppContainer.submitPlayerDirective<br/>先进入武将战术塑形"]:::command
    AI["AI 元帅系统<br/>MarshalAgent + TheaterDirective JSON<br/>先做大战役级规划"]:::input
    DEC["元帅 JSON 解码<br/>TheaterDirectiveDecoder<br/>提取 fenced JSON、校验 id 与 schema"]:::command
    COMP["元帅意图编译<br/>TheaterDirectiveCompiler<br/>把 TheaterDirective 降级成 ZoneDirective"]:::command
    RULER["君主姿态塑形<br/>RulerAgent.adjust<br/>显示名按三国势力 fallback，写 RulerDecisionRecord"]:::command
    DIPLO["外交提案<br/>DiplomatAgent.plan<br/>同盟/停战/借道/称臣/讨伐檄文"]:::command
    DCMD["外交命令<br/>Command.proposeDiplomacy<br/>经规则层更新关系/紧张度"]:::command
    GOV["太守内政建议<br/>GovernorAgent.plan<br/>征兵/修路/屯田/治安/补给审计"]:::command
    ROAD["太守修路命令<br/>Command.improveRoad<br/>经规则层连通优先修缮道路和基础设施"]:::command
    GCMD["太守生产命令<br/>Command.queueProduction<br/>经规则层校验资源并排产"]:::command
    STRAT["军师目标编排<br/>StrategistAgent.plan<br/>军师/防区指挥 fallback 显示名三国化"]:::command
    GENA["武将军令复核与战术塑形<br/>GeneralAgent.plan<br/>按武将分配复核投入和 tactic，写 GeneralDecisionRecord"]:::command
    GSKILL["武将技能显示<br/>GeneralSkillDisplay<br/>raw skill id -> 中文标签 + 短效果提示"]:::ui
    GINF["武将战场影响<br/>GeneralInfluence<br/>姓名快照 + 官道/骑战机动 + 攻防修正"]:::rules
    GIP["武将影响面板摘要<br/>GeneralCommandPanelView<br/>道路机动 + 官道受益/无加成原因 + 可见接敌攻防 + 可见接敌配对 + 可见近敌对象 + 目标预览 + 麾下备战 + 灰态原因"]:::ui
    UGA["军队所属武将摘要<br/>UnitInspectorStrategicState.generalAssignment<br/>姓名 + 风格 + 忠诚满意 + 技能短效果"]:::ui
    UMP["军队道路机动预判<br/>AppContainer.selectedUnitMobilityPreviewNotes<br/>基础/有效机动 + 可见可达格 + 当前官道可见受压 + 最近可达/可见安全官道"]:::ui
    UCP["军队接战预判<br/>AppContainer.selectedUnitCombatPreviewNotes<br/>可见敌对空状态 + 最近可见敌军 + 接近候选可达/官道/入敌射 + 接近武将 + 接近参考 + 接近态势 + 接近威胁 + 官道接近 + 官道入射程判断 + 首选理由 + 接战官道 + 交战武将 + 候选敌将 + 候选武将修正 + 候选交战审计 + 三目标排序 + 敌我余兵 + 目标态势 + 撤退/歼灭风险 + 首选武将影响"]:::ui
    RRP["郡县态势摘要<br/>RegionInspectorState / RegionInspectorView<br/>官道覆盖/受压/近敌来源 + 本郡武将 + 敌军距离/射程/兵力/敌将 + 非敌对关系"]:::ui
    POM["计划军令反馈<br/>BoardScene 地图短标签 + GeneralCommandPanelView 面板摘要<br/>源/目标点 + 箭头/固守环 + 官道可见受压 + 地图/面板近敌对象距离"]:::ui
    ZD["战争指令<br/>ZoneDirective<br/>战区级 attack/defend 意图"]:::command
    WCE["指令翻译器<br/>WarCommandExecutor<br/>把战区意图翻成具体单位命令"]:::command
    CMD["底层命令<br/>Command<br/>move / attack / hold / resupply / queueProduction / proposeDiplomacy / endTurn"]:::command
    RE["规则引擎<br/>RuleEngine<br/>先校验，再真正修改 GameState"]:::rules
    SYNC["战略同步器<br/>StrategicStateSynchronizer<br/>占领后刷新省份、战区、前线、部署"]:::rules
    DIP["外交与君主审计<br/>DiplomacyState.rulerRecords + diplomatRecords<br/>保存姿态、提案、目标和理由"]:::state
    DREL["外交关系<br/>DiplomaticRelation.status / tension<br/>只由外交命令最小更新"]:::state
    GOVREC["太守审计<br/>GameState.governorRecords<br/>保存内政重点、修路和生产结果"]:::state
    SREC["军师审计<br/>GameState.strategistRecords<br/>保存主防区、目标和理由"]:::state
    GREC["武将审计<br/>GameState.generalRecords<br/>保存防区武将动作、战术和理由"]:::state

    UI["地图和面板显示<br/>SpriteKit / SwiftUI Overlay<br/>显示 hex、省份、初始战区、动态战区、前线、部署"]:::ui
    LOG["日志和复盘记录<br/>EventLog / interactionLog / WarDirectiveRecord / AgentDecisionRecord / RulerDecisionRecord<br/>核心行动、玩家交互和命令结果中文化，含武将军令、军队选择、道路机动、粮草撤退、围城损耗、交战审计、余兵和攻防修正摘要"]:::ui

    ME --> JSON --> DL --> GS
    GS --> HEX
    HEX --> REGION
    HEX --> ECO
    REGION --> ECO
    REGION --> INIT
    INIT --> R2T
    R2T -.->|缺失时只用来补初始值| H2T
    HEX --> H2T
    H2T --> FRONT --> DEPLOY
    GS --> ECO
    GS --> DIP

    PLAYER --> CMD
    PLAYER --> PGEN --> PZD --> GENA
    AI --> DEC --> COMP --> RULER --> DIPLO --> DCMD --> GOV --> ROAD --> GCMD --> STRAT --> GENA --> ZD --> WCE --> CMD
    DCMD --> CMD
    ROAD --> CMD
    GCMD --> CMD
    GENA --> GINF
    GENA --> GSKILL
    GSKILL --> UI
    GINF --> WCE
    GINF --> RE
    GINF --> GIP
    DEPLOY --> UGA
    GSKILL --> UGA
    GINF --> UMP
    GINF --> UCP
    REGION --> RRP
    HEX --> RRP
    GS --> POM
    RULER --> DIP
    DIPLO --> DIP
    GOV --> GOVREC
    STRAT --> SREC
    GENA --> GREC
    CMD --> RE --> HEX
    RE --> ECO
    RE --> DREL
    RE --> SYNC
    SYNC --> REGION
    SYNC --> H2T
    SYNC --> FRONT
    SYNC --> DEPLOY

    GS --> UI
    HEX --> UI
    REGION --> UI
    INIT --> UI
    H2T --> UI
    FRONT --> UI
    DEPLOY --> UI
    ECO --> UI
    DIP --> UI
    GOVREC --> UI
    SREC --> UI
    GREC --> UI
    GIP --> UI
    UGA --> UI
    UMP --> UI
    UCP --> UI
    RRP --> UI
    POM --> UI
    DREL --> UI
    DIP --> LOG
    DREL --> LOG
    GOVREC --> LOG
    SREC --> LOG
    GREC --> LOG
    RE --> LOG
    WCE --> LOG

    classDef editor fill:#f6d365,stroke:#8a5a00,color:#1f1b10
    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef loader fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef authority fill:#fee2e2,stroke:#dc2626,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef snapshot fill:#e0f2fe,stroke:#0284c7,color:#082f49
    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef economy fill:#fef9c3,stroke:#ca8a04,color:#292107
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
```

## 2. 占领与动态推进：一个单位移动后发生什么

这张图只看最容易出 bug 的链路：单位移动到敌控空格后，游戏如何占领这个 hex，并且只推进这个 hex 的动态战区和部署归属。

核心原则：占一个 hex，只改这个 hex 的 `hexToTheater` / `hexToFrontZone`；不能把整个 region 的 `regionToTheater` 改掉。

```mermaid
flowchart TD
    A["移动命令进入<br/>Command.move<br/>来源可以是玩家，也可以是 WarCommandExecutor"]:::command
    B["移动合法性检查<br/>CommandValidator.validateMove<br/>检查阶段、阵营、行动力、路径、目标是否被占"]:::rules
    C{"移动是否合法?"}:::decision
    R["命令被拒绝<br/>CommandResult rejected<br/>GameState 不变，只记录拒绝原因"]:::stop
    M["执行移动<br/>CommandExecutor.executeMove<br/>更新单位坐标、朝向、已行动标记"]:::rules
    O{"能否占领目标 hex?<br/>OccupationRules.canOccupy<br/>目标可占、非己方控制、无其他单位、无 controller 或外交 hostile/atWar"}:::decision
    NO["普通移动<br/>只改变单位位置<br/>不改变目标 hex 控制权"]:::state
    HC["改写真实占领权<br/>HexTile.controller = division.faction<br/>这是占领的权威来源"]:::authority
    SA{"是否需要推进动态战区?<br/>先受真实可占领 gate 限制<br/>目标属于敌对 zone 或敌对控制 hex 时才推进"}:::decision
    ET["推进动态战区<br/>TheaterSystem.expandDynamicTheater<br/>只把目标 hex 写入进攻方 hexToTheater"]:::authority
    AF["推进部署归属<br/>WarDeploymentManager.advanceHex<br/>只把目标 hex 写入进攻方 hexToFrontZone"]:::authority
    SS["占领后同步战略层<br/>StrategicStateSynchronizer<br/>把 hex 变化传导到 region/theater/front/deploy"]:::rules
    RO["刷新省份控制权<br/>RegionOccupationRules.aggregateControl<br/>按 region 内 hex 控制权加权计算"]:::derived
    TU["刷新动态战区摘要<br/>TheaterSystem.updateTheaters(force)<br/>重算控制比例、战区邻接、单位池"]:::derived
    FU["刷新前线<br/>FrontLineManager.update<br/>重新扫描动态战区之间的真实 hex 接触"]:::derived
    DU["刷新部署层<br/>WarDeploymentManager.update<br/>重分前线、纵深、驻军单位"]:::derived
    UI["刷新显示和日志<br/>UI overlay / inspector / EventLog<br/>玩家看到地图颜色、前线和面板变化"]:::ui

    A --> B --> C
    C -->|否| R
    C -->|是| M --> O
    O -->|否| NO --> UI
    O -->|是| HC --> SA
    SA -->|目标已经是己方动态战区| SS
    SA -->|目标仍属敌方动态战区| ET --> AF --> SS
    SS --> RO --> TU --> FU --> DU --> UI

    WARN1["绝对不要这样做<br/>占一个 hex 就把整个 regionToTheater 改掉<br/>会导致前线跳到敌军身后"]:::warn
    WARN2["也不要这样做<br/>只改 Region.controller<br/>却不改 HexTile.controller<br/>会破坏玩家/AI 对称性"]:::warn
    ET -.守住.-> WARN1
    HC -.守住.-> WARN2

    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef authority fill:#fee2e2,stroke:#dc2626,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 3. v0.8 经济、生产与补员链路

这张图看 v0.8 初级经济。经济总账是 faction 级资源池，但收入和部署资格仍回到真实 hex 控制和 region 聚合；生产命令仍走 `RuleEngine`，UI 不直接改 `GameState`。

```mermaid
flowchart TD
    BOOT["经济启动补账<br/>EconomyRules.bootstrapIfNeeded<br/>旧状态缺 economyState 时从地图推导账本"]:::economy
    HEX["真实控制权<br/>HexTile.controller<br/>经济收入必须有己方控制 hex 证据"]:::authority
    REGION["战略聚合<br/>RegionNode<br/>city / factories / infrastructure / supplyValue"]:::derived
    INCOME["收入计算<br/>EconomyRules.income<br/>manpower / industry / supplies"]:::economy
    LEDGER["阵营总账<br/>FactionEconomyLedger<br/>库存、上回合收入、维护费、补员消耗、队列"]:::economy

    UI["经济面板<br/>EconomyPanelView<br/>展示资源和生产按钮"]:::ui
    QUEUE["生产命令<br/>Command.queueProduction<br/>玩家/未来 AI 共用底层命令"]:::command
    VALIDATE["生产校验<br/>CommandValidator.validateProduction<br/>检查 phase 与资源是否足够"]:::rules
    PAY["预付成本并入队<br/>EconomyRules.queueProduction<br/>扣 MP/IC/SUP，追加 ProductionOrder"]:::economy

    END["结束当前阵营回合<br/>Command.endTurn<br/>CommandExecutor.executeEndTurn"]:::command
    SUPPLY["补给状态刷新<br/>SupplyRules.updateSupplyStates"]:::rules
    SIEGE["围城判定<br/>SupplyRules.isBesieged<br/>城池/关隘 + 无粮道 + 敌邻接"]:::rules
    RESOLVE["经济结算<br/>EconomyRules.resolveFactionTurn<br/>收入、维护费、短缺、补员、生产推进"]:::economy
    SHORT{"补给库存够吗?"}:::decision
    LOW["战略补给短缺<br/>supplied 单位降为 lowSupply"]:::rules
    REINF["自动补员<br/>安全后方 supplied 非敌邻单位<br/>围城/断粮单位不会恢复"]:::rules
    PROD["推进生产队列<br/>remainingTurns - 1<br/>ready 后部署或发补给箱"]:::economy
    DEPLOY{"有合格后方部署点吗?"}:::decision
    SPAWN["部署新单位<br/>首都/城镇/工厂/高基建/高补给或 supply source<br/>必须己控、空置、非敌邻"]:::rules
    WAIT["保留订单<br/>本回合无安全 hex，等待后续回合"]:::economy
    NEXT["切换阵营并刷新运行时层<br/>StrategicStateBootstrapper.refreshRuntimeState"]:::rules

    BOOT --> LEDGER
    HEX --> REGION --> INCOME --> LEDGER
    UI --> QUEUE --> VALIDATE --> PAY --> LEDGER
    END --> SUPPLY --> SIEGE --> RESOLVE
    LEDGER --> RESOLVE
    RESOLVE --> SHORT
    SHORT -->|不足| LOW --> REINF
    SHORT -->|足够| REINF
    REINF --> PROD --> DEPLOY
    DEPLOY -->|有| SPAWN --> NEXT
    DEPLOY -->|没有| WAIT --> NEXT
    RESOLVE --> LEDGER

    WARN["边界<br/>经济系统不能直接占 hex<br/>也不能把中立/空控制 region 收入算给某阵营"]:::warn
    HEX -.守住.-> WARN
    VALIDATE -.守住.-> WARN

    classDef authority fill:#fee2e2,stroke:#dc2626,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef economy fill:#fef9c3,stroke:#ca8a04,color:#292107
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 4. AI / 元帅决策链：AI 怎么下命令

这张图看当前默认 AI 主路径。AI 不直接控制单位，也不直接改地图；元帅先读取降维战场摘要，模拟 LLM 输出 `TheaterDirectiveEnvelope` JSON，经 decoder 校验和 compiler 降级后，形成战区级 `DirectiveEnvelope`。v2.4 君主层随后做姿态塑形并写 `RulerDecisionRecord`，外交层读取国家/集团/关系并写 `DiplomatDecisionRecord`，有效外交提案会转换为 `Command.proposeDiplomacy` 经规则层执行，太守层读取经济/郡县/道路/粮草并写 `GovernorDecisionRecord`，修路焦点会转换为 `Command.improveRoad` 经规则层执行，有效生产建议会转换为 `Command.queueProduction` 经规则层执行，军师层再编排目标 region 并写 `StrategistDecisionRecord`，武将层最后复核防区军令、按风格/技能塑形 `ZoneDirective.tactic` 并写 `GeneralDecisionRecord`。底层移动和交战再由 `GeneralInfluence` 读取武将快照做道路机动和攻防修正，`CombatRules.combatAuditSummary` 读取同一套交战 profile 生成因素审计；移动、攻击、反击日志和命令拒绝原因会记录中文可审计摘要，最终仍由 `WarCommandExecutor`、`RuleEngine` 执行。

当前默认 AI 主线是 `MarshalAgent -> TheaterDirective JSON -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler -> RulerAgent.adjust -> DiplomatAgent.plan -> Command.proposeDiplomacy -> GovernorAgent.plan -> Command.improveRoad / Command.queueProduction -> StrategistAgent.plan -> GeneralAgent.plan -> ZoneDirective.tactic shaping -> WarCommandExecutor -> RuleEngine`。旧 v0.37 `TheaterCommanderPool -> ZoneCommanderAgent` 作为 fallback 和显式 `.zoneDirective` 路径保留，这条路径也会在执行前经过君主、外交、太守、军师和武将层。旧 Agent D 管线仍保留，但默认不走。

```mermaid
flowchart TD
    START["触发 AI 行动<br/>AppContainer.advanceOrRunAI / runAIIfNeeded<br/>玩家点下一回合，或命令后轮到 AI"]:::input
    CHECK{"当前阵营该由 AI 控制吗?<br/>德军 AI 阶段一定可跑；盟军只有观察者模式才跑"}:::decision
    STOP["不运行 AI<br/>等待玩家操作或阶段切换"]:::stop
    REFRESH["行动前刷新运行时战略层<br/>StrategicStateBootstrapper.refreshRuntimeState<br/>避免 AI 读到旧前线/旧部署"]:::rules
    TM["AI 回合编排器<br/>TurnManager.runAITurn<br/>默认 pipelineMode = marshalDirective"]:::rules
    SUM["战场摘要<br/>MarshalBattlefieldSummarizer<br/>enemy/strength 按 DiplomacyState hostile<br/>只给元帅 front/deploy/目标/补给摘要，不给全量 hex"]:::ai
    LLM["模拟 LLM 客户端<br/>SimulatedMarshalLLMClient<br/>输出 fenced JSON，不接真实网络或模型"]:::ai
    DEC["元帅 JSON 解码器<br/>TheaterDirectiveDecoder<br/>提取 JSON、解码、校验 schema/zone/region/tactic"]:::command
    COMP["元帅意图编译器<br/>TheaterDirectiveCompiler<br/>TheaterDirective -> ZoneDirective<br/>传递 focus/convergence/coordinated 参数"]:::command
    ENV["指令信封<br/>DirectiveEnvelope<br/>收集编译后的 ZoneDirective"]:::command
    RULER["君主姿态塑形<br/>RulerAgent.adjust<br/>敌对国家和相邻敌军强度按 DiplomacyState<br/>选择进取/守成/合盟/稳固，只调整指令信封"]:::ai
    DIP["君主审计<br/>DiplomacyState.rulerRecords + EventLog<br/>记录姿态、优先防区和理由"]:::ui
    DIPLO["外交提案<br/>DiplomatAgent.plan<br/>同盟/停战/借道/称臣/讨伐檄文"]:::ai
    DCMD["外交命令<br/>Command.proposeDiplomacy<br/>校验国家/关系/提案合法性"]:::command
    DRE["外交规则执行<br/>RuleEngine.execute<br/>更新 DiplomaticRelation 状态/紧张度"]:::rules
    DREC["外交审计<br/>DiplomatDecisionRecord + CommandResultSummary<br/>记录提案、对象、中文执行结果"]:::ui
    GOV["太守内政建议<br/>GovernorAgent.plan<br/>征兵/修路/屯田/治安/补给"]:::ai
    RCMD["太守修路命令<br/>Command.improveRoad<br/>校验控制权/资源并修缮道路"]:::command
    RRE["修路规则执行<br/>RuleEngine.execute<br/>连缀官道、提升基础设施、扣资源"]:::rules
    GCMD["太守生产命令<br/>Command.queueProduction<br/>校验资源并加入生产队列"]:::command
    GRE["生产规则执行<br/>RuleEngine.execute<br/>扣资源、追加 ProductionOrder"]:::rules
    GOVREC["太守审计<br/>GovernorDecisionRecord + CommandResultSummary<br/>记录内政重点、建议和中文执行结果"]:::ui
    STRAT["军师目标编排<br/>StrategistAgent.plan<br/>hostile unit presence 按 DiplomacyState<br/>选择主防区，编排 focus/support/convergence"]:::ai
    SREC["军师审计<br/>StrategistDecisionRecord + EventLog<br/>记录目标 region 和理由"]:::ui
    GENA["武将军令复核与战术塑形<br/>GeneralAgent.plan<br/>读取防区武将，复核投入、预备队和 tactic"]:::ai
    GREC["武将审计<br/>GeneralDecisionRecord + EventLog<br/>记录武将动作、战术、风格和理由"]:::ui
    GINF["武将战场影响与交战审计<br/>GeneralInfluence / CombatAuditSummary<br/>道路机动、攻击、防御与交战因素摘要"]:::rules
    TACTIC["高级战术路由<br/>TacticName<br/>正攻 / 疾袭 / 突击 / 破阵 / 合围 / 箭雨 / 固守 / 死守"]:::command
    WCE["指令执行器<br/>WarCommandExecutor.execute<br/>按战术 profile 选择单位、目标和 fallback"]:::command
    BOTTOM["具体单位命令<br/>Command<br/>attack / move / hold / allowRetreat"]:::command
    RE["统一规则校验执行<br/>RuleEngine<br/>AI 和玩家共用同一套规则"]:::rules
    RECORD["指令复盘记录<br/>WarDirectiveRecord<br/>记录 tactic、target、中文结果和拒绝原因"]:::ui
    END["AI 自动结束回合<br/>RuleEngine.execute(.endTurn)<br/>切换 activeFaction / phase"]:::rules

    START --> CHECK
    CHECK -->|否| STOP
    CHECK -->|是| REFRESH --> TM --> SUM --> LLM --> DEC --> COMP --> ENV
    ENV --> RULER --> DIPLO --> DCMD --> DRE --> GOV --> RCMD --> RRE --> GCMD --> GRE --> STRAT --> GENA --> TACTIC --> WCE --> BOTTOM --> RE --> RECORD --> END
    DRE --> DREC
    RRE --> GOVREC
    GRE --> GOVREC
    GENA --> GINF
    GINF --> WCE
    GINF --> RE
    RULER --> DIP
    DIPLO --> DREC
    GOV --> GOVREC
    STRAT --> SREC
    GENA --> GREC

    FALLBACK["Fallback 将军池<br/>TheaterCommanderPool + ZoneCommanderAgent<br/>visibleEnemyStrengthByRegion 按 DiplomacyState hostile<br/>元帅 JSON 无效或某 zone 无指令时使用"]:::ai
    DEC -.解码失败.-> FALLBACK --> ENV
    COMP -.zone 缺指令.-> FALLBACK

    LEGACY["旧 Agent D 管线<br/>AgentContext -> DecisionProvider -> AgentCommandMapper<br/>只在 legacyAgentOrder 显式分支或测试中使用"]:::legacy
    TM -.默认不走.-> LEGACY

    MANUAL["显式 zoneDirective 路径<br/>TheaterCommanderPool / 手写 ZoneDirective<br/>也可指定 tactic/focus/convergence"]:::input
    MANUAL --> RULER

    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef ai fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef legacy fill:#f3f4f6,stroke:#6b7280,stroke-dasharray:5 5,color:#111827
```

## 5. MapEditor 到游戏数据：地图怎么进入主游戏

这张图看地图编辑器的输出链路。编辑器里画的是初始地图和初始战区；运行时动态战区仍由游戏里的 `hexToTheater` 推进，不是编辑器脚本控制。

```mermaid
flowchart TD
    DOC["编辑器文档<br/>MapEditorDocument<br/>保存 hex、省份、战区分配、初始单位"]:::editor
    MODE1["地块编辑<br/>hexPainter<br/>画地形、道路、控制方、补给点"]:::editor
    MODE2["省份编辑<br/>regionBuilder<br/>把每个 hex 分配给一个 region"]:::editor
    MODE3["初始战区编辑<br/>theaterAssignment<br/>把 region 分配给开局 theater"]:::editor
    MODE4["初始部队编辑<br/>unitPlanner<br/>放置开局单位和模板"]:::editor
    EXPORT["导出器<br/>MapEditorExporter.export<br/>把编辑器文档转成游戏 JSON"]:::loader
    CHECK{"导出校验通过吗?<br/>每个 hex 必须有 region；region 不能为空"}:::decision
    ERR["导出失败<br/>unassignedHex / missingRegion / emptyRegion<br/>先回编辑器补数据"]:::stop
    SCEN["场景 JSON<br/>ScenarioDefinition<br/>保存 hex 地形、控制方、补给、目标、初始单位"]:::data
    REG["省份 JSON<br/>RegionDataSet<br/>保存 hexToRegion、省份、边、初始 theaterId"]:::data
    NEI["自动推导省份邻接<br/>真实 hex 邻接 -> Region.neighbors / RegionEdge<br/>避免手写邻接出错"]:::derived
    BRIDGE["默认资源桥<br/>MapEditorGameResourceBridge<br/>读取或覆盖项目默认地图资源"]:::loader
    FILES["项目默认数据文件<br/>WWIIHexV0/Data<br/>guandu_200_scenario.json + guandu_200_regions.json<br/>阿登数据保留作 fallback"]:::data
    LOAD["游戏启动加载<br/>DataLoader.loadGameState<br/>DEBUG 下优先读源码 JSON"]:::loader
    MAP["地图状态<br/>MapState<br/>tiles + hexToRegion + RegionGraph"]:::state
    THEATER["战区状态<br/>TheaterState<br/>捕获 initialSnapshot，并 seed hexToTheater"]:::state
    FRONT["初始前线<br/>FrontLineState<br/>按开局动态战区接触生成"]:::derived
    DEPLOY["初始部署<br/>WarDeploymentState<br/>按前线/纵深/驻军分配单位"]:::derived
    GAME["游戏可运行<br/>GameState ready<br/>主游戏 UI 和规则系统开始读取"]:::state

    DOC --> MODE1 --> EXPORT
    DOC --> MODE2 --> EXPORT
    DOC --> MODE3 --> EXPORT
    DOC --> MODE4 --> EXPORT
    EXPORT --> CHECK
    CHECK -->|失败| ERR
    CHECK -->|通过| SCEN
    CHECK -->|通过| REG
    REG --> NEI --> REG
    SCEN --> BRIDGE
    REG --> BRIDGE
    BRIDGE --> FILES
    FILES --> LOAD --> MAP --> THEATER --> FRONT --> DEPLOY --> GAME

    NOTE["重要提醒<br/>MapEditor 的 theater assignment 只定义开局战区<br/>运行时推进看 hexToTheater，不看 regionToTheater"]:::warn
    MODE3 -.语义.-> NOTE

    classDef editor fill:#f6d365,stroke:#8a5a00,color:#1f1b10
    classDef loader fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef derived fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 6. v1.1 主游戏 macOS 入口

这张图只说明 v1.1 新增的 macOS 主游戏 target。它复用主游戏数据、UI、SpriteKit 棋盘和规则系统；macOS 输入只是平台桥接，不是新的规则入口。

```mermaid
flowchart TD
    TARGET["macOS 主游戏 target<br/>WWIIHexV0Mac<br/>独立于 iOS target 和 MapEditorMac"]:::platform
    APP["macOS App 入口<br/>WWIIHexV0MacApp<br/>WindowGroup + Game 菜单"]:::platform
    BOOT["游戏容器<br/>AppContainer.bootstrap<br/>加载默认 JSON 并初始化规则/AI"]:::state
    ROOT["主游戏界面<br/>RootGameView<br/>HUD、图层、Info、棋盘"]:::ui
    BRIDGE["macOS SpriteKit 桥<br/>BoardSceneView + BoardEventSKView<br/>NSViewRepresentable 承载 SKView"]:::platform
    SCENE["棋盘场景<br/>BoardScene<br/>鼠标点击、拖拽、滚轮/触控板缩放"]:::ui
    TAP["hex 点击回调<br/>onHexTapped(coord)<br/>只传坐标，不改 GameState"]:::input
    CONTAINER["输入解释<br/>AppContainer.handleBoardTap<br/>选中、移动、攻击意图判断"]:::rules
    COMMAND["统一命令<br/>Command / ZoneDirective<br/>玩家和 AI 共用入口"]:::command
    ENGINE["规则权威<br/>RuleEngine / WarCommandExecutor<br/>校验后修改 GameState"]:::rules
    DATA["默认资源<br/>WWIIHexV0/Data JSON<br/>DEBUG 优先源码文件，bundle 作 fallback"]:::data

    TARGET --> APP --> BOOT --> ROOT --> BRIDGE --> SCENE --> TAP --> CONTAINER --> COMMAND --> ENGINE
    DATA --> BOOT
    ENGINE --> ROOT

    WARN["禁止绕过<br/>AppKit / SpriteKit 不得直接改 GameState<br/>仍必须走规则系统"]:::warn
    SCENE -.守住.-> WARN

    classDef platform fill:#e0f2fe,stroke:#0284c7,color:#082f49
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 7. v1.0 UI / AI / 初版试玩链路

这张图说明 v1.0 分支的收口点：它不新增规则入口，只改善 UI 可读性、AI 回放、轻量性能和试玩记录。

```mermaid
flowchart TD
    STATE["运行时状态<br/>GameState + EventLog + WarDirectiveRecord"]:::state
    ROOT["主界面<br/>RootGameView<br/>HUD + Info tabs"]:::ui
    LOG["日志面板<br/>EventLogView<br/>最近 60 条 LogDisplayEntry"]:::ui
    AIUI["军机面板<br/>AgentPanelView<br/>执行者/国家/郡县/防区展示名 + 调试 JSON + 命令结果 + 防区指令"]:::ui
    BOARD["地图场景<br/>BoardScene<br/>缓存 unit display hex 后排序绘制"]:::ui
    MARSHAL["模拟元帅 / MockAI<br/>MarshalAgent + SimulatedMarshalLLMClient"]:::ai
    ZD["战区指令<br/>ZoneDirective<br/>tactic / focus / intensity"]:::command
    WCE["执行解释<br/>WarCommandExecutor<br/>infiltration 限制默认投入"]:::command
    RULE["规则权威<br/>RuleEngine<br/>唯一修改 GameState"]:::rules
    PLAYTEST["初版试玩记录<br/>观察 UI、图层、AI diagnostics、拒绝原因"]:::doc

    STATE --> ROOT
    ROOT --> LOG
    ROOT --> AIUI
    ROOT --> BOARD
    MARSHAL --> ZD --> WCE --> RULE --> STATE
    AIUI --> PLAYTEST
    LOG --> PLAYTEST
    BOARD --> PLAYTEST

    WARN["边界<br/>UI / MockAI 不直接改 GameState<br/>仍必须走统一命令管线"]:::warn
    AIUI -.守住.-> WARN
    WCE -.守住.-> WARN

    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef ai fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef doc fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 8. v0.4 将军与玩家双轨命令

这张图说明 v0.4 分支的新增主线：实体将军从 JSON / region 种子接入 FrontZone；玩家可以微操具体部队，也可以通过将军面板发战区宏观命令。宏观命令会在执行前经过 `GeneralAgent.plan` 塑形最终 tactic，两条路最终仍收口到规则系统。

```mermaid
flowchart TD
    GJSON["将军数据<br/>generals.json<br/>六位历史将军、倾向、技能、忠诚/满意度"]:::data
    RJSON["Region 种子<br/>默认 regions JSON assignedGeneralId<br/>开局指定某 region 所属将军"]:::data
    DL["加载器<br/>DataLoader.loadGeneralRegistry<br/>读取 GeneralRegistry"]:::loader
    DISP["将军指派器<br/>GeneralDispatcher.assignGenerals<br/>种子 -> 偏好 -> 同阵营后备池"]:::rules
    FZ["战区部署<br/>FrontZone.generalAssignment<br/>generalId、HQ region、辖下 division、忠诚/满意度"]:::state
    POOL["将军池<br/>TheaterCommanderPool<br/>用 GeneralData 生成 ZoneCommanderAgentConfig"]:::ai

    TAP["玩家地图点击<br/>RootGameView / BoardScene<br/>选单位、选 region、选目标"]:::input
    MICRO["全微操<br/>AppContainer.submit(Command)<br/>move / attack / hold / resupply"]:::command
    LOCK["微操锁<br/>PlayerCommandState.micromanagedDivisionIds<br/>本回合玩家亲控单位"]:::state
    GENUI["武将面板<br/>GeneralCommandPanelView<br/>固守战线 / 进攻郡县"]:::ui
    ZD["玩家战区指令<br/>ZoneDirective<br/>defense holdLine 或 attack selected region"]:::command
    GENA["武将战术塑形<br/>GeneralAgent.plan<br/>按防区武将生成最终 tactic"]:::ai
    WCE["执行器<br/>WarCommandExecutor.execute(excluding lockedIds)<br/>跳过已微操单位"]:::command
    RE["规则权威<br/>RuleEngine<br/>校验并修改 GameState"]:::rules
    RECORD["记录<br/>WarDirectiveRecord + PlayerPlannedOperation(tactic)<br/>AI 面板、日志、计划线共用"]:::ui
    BOARD["视觉反馈<br/>BoardScene 地图短标签 + GeneralCommandPanelView 面板摘要<br/>进攻箭头、防御圆环、武将战术/官道受压短标签、面板近敌对象距离、微操单位金色圈"]:::ui
    PROFILE["武将档案<br/>GeneralProfileView<br/>履历、技能、忠诚、满意度、辖下部队"]:::ui

    GJSON --> DL --> DISP
    RJSON --> DISP --> FZ --> POOL
    FZ --> GENUI --> PROFILE
    TAP --> MICRO --> RE --> LOCK
    LOCK --> WCE
    TAP --> GENUI --> ZD --> GENA --> WCE --> RE --> RECORD --> BOARD
    FZ --> GENUI
    FZ --> GENA

    WARN["边界<br/>UI 和将军不直接改 hex / division<br/>行动必须走 Command 或 ZoneDirective"]:::warn
    GENUI -.守住.-> WARN
    GENA -.守住.-> WARN
    WCE -.守住.-> WARN

    classDef data fill:#f8f9fb,stroke:#6b7280,color:#111827
    classDef loader fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef state fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef ai fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```

## 9. 云端迭代与 Agent C 结果包验收

这张图说明当前协作制度：本机只做轻量检查，重验证由 `main` push 后的 GitHub Actions 结果包承接。Agent C 不能只看 Agent B 的文字说明，必须下载并核对最新 `origin/main` run 的 artifact。

```mermaid
flowchart TD
    HUMAN["人工目标<br/>可用 a: / b: / c: 召唤角色"]:::input
    A["Agent A<br/>读入口文档和源码<br/>写阶段提示词"]:::agent
    B0["Agent B 同步 main<br/>git fetch origin<br/>git pull --ff-only origin main"]:::git
    B1["Agent B 实现<br/>只改本轮相关文件<br/>不做业务外扩"]:::agent
    LITE["本机轻量检查<br/>git diff --check<br/>Markdown/YAML/JSON/plist/swift parse"]:::check
    COMMIT["main commit<br/>提交本轮实现和文档"]:::git
    PUSH["push origin main<br/>触发 GitHub Actions"]:::git
    CI["GitHub Actions ci-results<br/>静态检查 + xcodebuild build<br/>生成日志和 xcresult"]:::cloud
    ART["未加密 CI 结果包<br/>manifest / failure summary / junit / xcodebuild.log / xcresult"]:::artifact
    C0["Agent C 下载 artifact<br/>gh auth login<br/>缓存到 /private/tmp/..."]:::agent
    C1{"manifest 是否匹配<br/>main 最新 commit / run id / attempt?"}:::decision
    C2{"CI 与日志是否可验收?"}:::decision
    FAIL["退回清单<br/>说明失败日志、风险和修复范围"]:::stop
    FIX["Agent B 在 main 上<br/>追加修复 commit"]:::git
    PASS["Agent C 通过<br/>更新 flow / update_log<br/>人工复核进入下一轮"]:::done

    HUMAN --> A --> B0 --> B1 --> LITE --> COMMIT --> PUSH --> CI --> ART --> C0 --> C1
    C1 -->|不匹配| FAIL --> FIX --> PUSH
    C1 -->|匹配| C2
    C2 -->|失败| FAIL
    C2 -->|通过| PASS

    WARN["边界<br/>不使用 smalldata_test / develop / codeb / PR 作为默认流程<br/>不复制 AITRANS 漫画探针、GGUF、模型包等项目特例"]:::warn
    PUSH -.守住.-> WARN
    ART -.守住.-> WARN

    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef agent fill:#ede9fe,stroke:#7c3aed,color:#1f143d
    classDef git fill:#dbeafe,stroke:#2563eb,color:#0f172a
    classDef check fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef cloud fill:#e0f2fe,stroke:#0284c7,color:#082f49
    classDef artifact fill:#dcfce7,stroke:#16a34a,color:#052e16
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef done fill:#dcfce7,stroke:#15803d,color:#052e16
    classDef warn fill:#ffedd5,stroke:#f97316,color:#431407
```
