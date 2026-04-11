# Architecture (Alpha)

## 当前状态与目标状态
- 当前代码为最小骨架：
  - 前端：`src/components/cards/*` + `src/state/store.ts`
  - 后端：`src-tauri/src/{pty,event_bus,graph,watcher,db,models}.rs`
- 目标结构见 `docs/tasks/alpha-observability-workbench.md`，按里程碑逐步迁移，不一次性重构。

## 核心设计
- 双通道分流：同一 PTY 输出同时走
  - A 通道：原始字节流到 Terminal/Chat 展示。
  - B 通道：适配器解析成结构化事件，进入事件总线。
- 单向数据流：`PTY/Watcher -> Rust EventBus -> Frontend Store -> Cards`。
- 会话图由事件增量构建，节点与边可持久化回放。

## Sidebar 架构边界
- 侧边栏组件边界（前端）：
  - `Sidebar`：容器与折叠态。
  - `ProjectTree`：读取 `projectStore`，触发 `open_project/create_project/delete_project`。
  - `LayoutList`：读取 `layoutStore`，触发 `save_layout/create_layout/set_active_layout`。
  - `SessionList`：读取 `sessionStore`，按 `project_id` + `status` 过滤。
- 状态来源：
  - 项目与布局来自 SQLite（通过 Tauri commands 加载）。
  - 会话实时状态来自 `backend:event` + `sessionStore` 聚合。
- 事件联动：
  - `project_switched`（前端 UI 事件）触发重新加载项目上下文。
  - `session_started/session_ended` 驱动 `SessionList` 增量更新。
  - `layout_activated` 驱动卡片容器重排，不影响事件流与图数据。

## 事件契约
- 持久化与跨端契约统一为 `snake_case` 的 `event_type`。
- Alpha 标准事件：
  - 消息：`message_user`、`message_assistant`、`message_system`
  - 动作：`action_tool_call`、`action_tool_result`
  - 文件：`file_changed`、`file_created`、`file_deleted`
  - 生命周期：`session_started`、`session_compact`、`session_branched`、`session_ended`、`session_error`
- 兼容规则：现有点语义事件（如 `session.started`）允许在适配器层输入，但必须在后端标准化后再写库/广播。

## 图模型契约
- 节点：`Message | Action | Artifact | SessionEvent`
- 边：`next | caused_by | reads | writes | validates | updates | branches_to`
- 最小建图规则：
  - 每个消息/动作/生命周期事件至少产出一个节点。
  - `action_tool_call(file_read/file_write)` 必须产出到 Artifact 的 `reads/writes` 边。
  - 同一 `session_id` 中节点时间序关系必须可形成 `next` 链。

## 存储边界
- SQLite 为事件事实源：`projects/layouts/cards/sessions/events/graph_nodes/graph_edges/file_versions`。
- `events` 采用追加写（append-only），回放以 `session_id + ts` 为主索引。
- 文件快照遵循小文件存内容、大文件存 hash 的策略。

## 接口边界
- Tauri 会话命令统一为：`start_session`、`write_to_session`、`resize_session`、`end_session`。
- 项目与布局命令：`create_project/list_projects/open_project/save_layout/create_card/remove_card/update_card_state`。
- 前端仅通过 typed command wrapper 和 `backend:event` 订阅与后端交互。

## 风险与缓解
- 解析漂移：CLI 输出变化导致事件识别失真。
  - 缓解：优先结构化输出（Claude `stream-json`），并保留 raw adapter 回退。
- 事件乱序：会话图边构建错误。
  - 缓解：事件幂等键 + 归并排序 + 回放校验。
- 监听噪声：无关文件变化污染变更追踪。
  - 缓解：项目边界 + ignore 列表 + `.git`/构建产物过滤。
