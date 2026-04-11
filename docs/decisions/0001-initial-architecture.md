# ADR 0001: Initial Architecture for Alpha

## 状态
Accepted

## 背景
目标是构建一个 Agent 工作流优先的终端/IDE 融合产品。核心挑战不是终端渲染本身，而是会话动作、文件变更、审计与干预之间的实时联动。

## 决策
- 桌面框架采用 `Tauri v2`，后端使用 `Rust`。
- 前端采用 `React + TypeScript + Zustand`。
- 卡片布局引擎采用 `react-grid-layout`（Alpha 阶段优先稳定与交付速度）。
- 终端渲染采用 `xterm.js`。
- 存储采用 `SQLite`，记录事件日志、文件快照、会话图数据。
- 事件通信采用 Tauri 事件机制，统一事件信封驱动前端状态归约。
- Diff 与 Editor 分离为两类卡片，分别承担审计与干预职责。
- 左侧信息架构采用“项目 -> 布局（Tab）”两级模型。

## 结果与影响
- 优点：工程分层清晰，便于多 Agent、多会话扩展；卡片联动可建立在稳定事件协议上。
- 代价：需要先定义事件契约和回放机制，前期架构工作量高于单纯 UI 拼装。

## 备选方案（未采纳）
- Electron：生态成熟但资源占用更高，非首选。
- 自研自由画布布局引擎：灵活但交付风险高，Alpha 不采用。
- 将 Diff 与 Editor 合并：卡片数量减少，但不利于并行审计与干预。

## 后续动作
- 在 `docs/spec.md`、`docs/architecture.md` 与 `.agent/PLANS.md` 中保持与本 ADR 一致。
- 事件命名与兼容映射策略见 ADR `0002-event-contract-normalization.md`。
- 后续重大变更新增 ADR（`0003-...`）并引用本决策。
