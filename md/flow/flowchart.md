# WWIIHexV0 Mermaid 核心流程图

> 本图参照 `md/flow/flow.md`。每个图块都用“中文解释 + 关键代码名”标注：先看中文理解逻辑，再用代码名回到源码定位。

## 0. 读图总纲

项目当前最重要的逻辑是：

```text
地图编辑器/JSON 数据
  -> 游戏启动加载为 GameState
  -> hex 是真实战术权威
  -> region / theater / front / deploy 都是从 hex 和单位位置派生出来的战略层
  -> 玩家和 AI 都必须把命令交给 RuleEngine
  -> 命令执行后再同步刷新战略层和 UI
```

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

    PLAYER["玩家输入<br/>点击地图、移动、攻击、结束回合"]:::input
    AI["AI 将领系统<br/>TheaterCommanderPool + ZoneCommanderAgent<br/>按战区生成战争指令"]:::input
    ZD["战争指令<br/>ZoneDirective<br/>战区级 attack/defend 意图"]:::command
    WCE["指令翻译器<br/>WarCommandExecutor<br/>把战区意图翻成具体单位命令"]:::command
    CMD["底层命令<br/>Command<br/>move / attack / hold / resupply / endTurn"]:::command
    RE["规则引擎<br/>RuleEngine<br/>先校验，再真正修改 GameState"]:::rules
    SYNC["战略同步器<br/>StrategicStateSynchronizer<br/>占领后刷新省份、战区、前线、部署"]:::rules

    UI["地图和面板显示<br/>SpriteKit / SwiftUI Overlay<br/>显示 hex、省份、初始战区、动态战区、前线、部署"]:::ui
    LOG["日志和复盘记录<br/>EventLog / WarDirectiveRecord / AgentDecisionRecord<br/>用于 UI 展示和后续调试"]:::ui

    ME --> JSON --> DL --> GS
    GS --> HEX
    HEX --> REGION
    REGION --> INIT
    INIT --> R2T
    R2T -.->|缺失时只用来补初始值| H2T
    HEX --> H2T
    H2T --> FRONT --> DEPLOY

    PLAYER --> CMD
    AI --> ZD --> WCE --> CMD
    CMD --> RE --> HEX
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
    O{"能否占领目标 hex?<br/>OccupationRules.canOccupy<br/>目标可占、非己方控制、没有其他单位"}:::decision
    NO["普通移动<br/>只改变单位位置<br/>不改变目标 hex 控制权"]:::state
    HC["改写真实占领权<br/>HexTile.controller = division.faction<br/>这是占领的权威来源"]:::authority
    SA{"是否需要推进动态战区?<br/>目标属于敌方 zone 或仍是敌控 hex 时才推进"}:::decision
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

## 3. AI / ZoneDirective 管线：AI 怎么下命令

这张图看当前默认 AI 主路径。AI 不直接控制单位，也不直接改地图；AI 先输出战区级 `ZoneDirective`，再由 `WarCommandExecutor` 翻译成底层 `Command`，最后仍然交给 `RuleEngine`。

当前 v0.37 的默认 AI 主线是 `TheaterCommanderPool -> ZoneCommanderAgent -> ZoneDirective -> WarCommandExecutor -> RuleEngine`。旧 Agent D 管线仍保留，但默认不走。

```mermaid
flowchart TD
    START["触发 AI 行动<br/>AppContainer.advanceOrRunAI / runAIIfNeeded<br/>玩家点下一回合，或命令后轮到 AI"]:::input
    CHECK{"当前阵营该由 AI 控制吗?<br/>德军 AI 阶段一定可跑；盟军只有观察者模式才跑"}:::decision
    STOP["不运行 AI<br/>等待玩家操作或阶段切换"]:::stop
    REFRESH["行动前刷新运行时战略层<br/>StrategicStateBootstrapper.refreshRuntimeState<br/>避免 AI 读到旧前线/旧部署"]:::rules
    TM["AI 回合编排器<br/>TurnManager.runAITurn<br/>默认 pipelineMode = zoneDirective"]:::rules
    POOL["战区将领池<br/>TheaterCommanderPool<br/>给每个有前线的 FrontZone 找一个将领"]:::ai
    ZONE{"这个 FrontZone 有前线吗?<br/>frontSegments 非空才需要出命令"}:::decision
    SKIP["跳过该 zone<br/>没有前线就不生成 directive"]:::stop
    AGENT["单战区将领<br/>ZoneCommanderAgent<br/>读取本 zone 的前线单位、敌军摘要、压力"]:::ai
    CLS["战术分类器<br/>BinaryTacticClassifier<br/>按兵力比、将领风格、前沿状态判断攻防"]:::ai
    ATK["进攻意图<br/>standardAttack<br/>生成 ZoneDirective.attack"]:::command
    DEF["防御意图<br/>holdPosition<br/>生成 ZoneDirective.defend"]:::command
    ENV["指令信封<br/>DirectiveEnvelope<br/>收集本回合所有 ZoneDirective"]:::command
    WCE["指令执行器<br/>WarCommandExecutor.execute<br/>把战区意图翻译成单位命令"]:::command
    BOTTOM["具体单位命令<br/>Command<br/>attack / move / hold / allowRetreat"]:::command
    RE["统一规则校验执行<br/>RuleEngine<br/>AI 和玩家共用同一套规则"]:::rules
    RECORD["指令复盘记录<br/>WarDirectiveRecord<br/>记录 tactic、target、结果、拒绝原因"]:::ui
    END["AI 自动结束回合<br/>RuleEngine.execute(.endTurn)<br/>切换 activeFaction / phase"]:::rules

    START --> CHECK
    CHECK -->|否| STOP
    CHECK -->|是| REFRESH --> TM --> POOL --> ZONE
    ZONE -->|否| SKIP
    ZONE -->|是| AGENT --> CLS
    CLS -->|兵力优势 / 已有前沿突破 / 连续防守| ATK
    CLS -->|兵力劣势| DEF
    ATK --> ENV
    DEF --> ENV
    ENV --> WCE --> BOTTOM --> RE --> RECORD --> END

    LEGACY["旧 Agent D 管线<br/>AgentContext -> DecisionProvider -> AgentCommandMapper<br/>只在 legacyAgentOrder 显式分支或测试中使用"]:::legacy
    TM -.默认不走.-> LEGACY

    MANUAL["手写战区指令<br/>手工 ZoneDirective<br/>未来玩家聊天命令也可以复用这条后端"]:::input
    MANUAL --> WCE

    classDef input fill:#fef3c7,stroke:#d97706,color:#1f1600
    classDef decision fill:#fff7ed,stroke:#ea580c,color:#1f1300
    classDef stop fill:#fee2e2,stroke:#b91c1c,color:#111827
    classDef rules fill:#ccfbf1,stroke:#0f766e,color:#042f2e
    classDef ai fill:#e0e7ff,stroke:#4f46e5,color:#111827
    classDef command fill:#fae8ff,stroke:#a21caf,color:#2a0a2f
    classDef ui fill:#e5e7eb,stroke:#4b5563,color:#111827
    classDef legacy fill:#f3f4f6,stroke:#6b7280,stroke-dasharray:5 5,color:#111827
```

## 4. MapEditor 到游戏数据：地图怎么进入主游戏

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
    FILES["项目默认数据文件<br/>WWIIHexV0/Data<br/>ardennes_v0_scenario.json + ardennes_v02_regions.json"]:::data
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
