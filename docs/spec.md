# Product Spec (Alpha)

## 产品定位
- New-Terminal 不是终端模拟器、也不是 IDE。
- Alpha 聚焦为 Agent 工作流可观测工作台：可观测、可干预、可恢复。

## 目标
- 解决三类核心问题：
  - 变更不可控：实时看到 Agent 对文件的影响。
  - 会话迷失：把线性日志重建为可导航的会话图。
  - 工具割裂：在同一工作面完成对话、追踪、审计、干预。
- 支持单项目内多会话并行与会话分支回放。

## 非目标
- 不做自动任务分工或自动多 Agent 编排。
- 不做完整 skill/mcp 配置中心编辑能力（仅保留接口）。
- 不与 VSCode/Cursor 的完整 IDE 能力正面竞争。

## Alpha 卡片范围
- `agent_chat`: 与 Agent 对话主入口。
- `session_graph`: 可视化消息、动作、产物、会话事件。
- `change_tracking`: 文件变更列表与状态高亮。
- `diff`: 单文件 before/after 审计。
- `editor`: 人工介入编辑。
- `terminal`: PTY 原始输出可见性。
- `notes`: 人工记录决策与上下文。

## 信息架构
- `Project -> Layout -> Card`。
- `Session` 独立于 `Layout`，可被多个卡片引用。
- Alpha 每个项目默认一个布局，但保留多布局能力。

## 左侧侧边栏（Sidebar）定义
- 目标：提供跨卡片的全局导航与上下文切换入口，不承载重内容编辑。
- 结构：
  - `ProjectTree`：项目列表、当前项目高亮、创建/删除/打开项目。
  - `LayoutList`：当前项目下布局列表（Tab 的导航镜像）、新建布局、切换活动布局。
  - `SessionList`：当前项目会话列表（active/ended）、按 `agent_type` 和状态分组。
  - `QuickActions`：`start_session`、`new_note_card`、`open_change_tracking` 等快捷动作。
- 交互原则：
  - 切项目时，主工作区切换到该项目的活动布局与最近会话。
  - 切布局时，不影响会话事实数据，仅切换卡片排布与卡片绑定。
  - 点会话时，联动更新 Chat/Graph/ChangeTracking/Diff 的默认 `session_id` 绑定。
- 可见性：支持折叠/展开；折叠后保留最小图标态与当前项目会话标识。

## 关键链路与验收口径
- 关键链路：`message_user/message_assistant -> action_tool_call -> file_changed -> diff/card 联动`。
- 多会话并行不串线：所有状态更新必须按 `session_id` 隔离。
- 生命周期可追踪：`session_started/session_compact/session_branched/session_ended` 可回放。
- 重启恢复：项目、布局、会话状态与关键历史可恢复。

## 约束
- 固定技术架构：`Tauri v2 + Rust + React + TypeScript`。
- 事件驱动：卡片联动只允许通过事件总线和 reducer。
- Diff 与 Editor 职责分离，避免审计与编辑混淆。
- 可靠性优先于功能扩张。

## 提交粒度规则
- 每完成一个可独立验证、可独立回滚、可独立评审的小阶段/小节点/小功能，提交一次 commit。
- 提交前至少运行该节点最小必要验证；跨里程碑前需完成约定的 build/test 检查。
- commit message 使用 Conventional Commits，并体现对应任务或 milestone。
