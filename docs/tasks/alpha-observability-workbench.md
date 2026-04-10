# Task: Agent 工作流可观测工作台（Alpha）

## 文档目的
本文件承载本轮任务的完整实施约束，补充 `spec/architecture/ADR`，作为执行时的细节参考。

## 范围
- 交付目标：可观测、可干预、可恢复的 Agent 工作流工作台。
- Alpha 卡片：`agent_chat`、`session_graph`、`change_tracking`、`diff`、`editor`、`terminal`、`notes`。
- 会话图模型：`Message/Action/Artifact/SessionEvent` + `next/caused_by/reads/writes/validates/updates/branches_to`。
- 左侧侧边栏：`ProjectTree`、`LayoutList`、`SessionList`、`QuickActions`。

## 关键契约
- 事件链路：
  - `message_user | message_assistant`
  - `action_tool_call | action_tool_result`
  - `file_changed | file_created | file_deleted`
  - `session_started | session_compact | session_branched | session_ended`
- 数据流：`PTY/Watcher -> Rust EventBus -> SQLite + Frontend Store -> Cards`。
- 会话隔离：一切视图更新必须绑定 `session_id`。

## 实施分层
- Rust 后端：PTY 管理、适配器解析、事件总线、图构建、文件监听、快照、恢复。
- 前端：卡片渲染、布局管理、事件归约、会话图可视化、Diff/Editor 联动。
- 存储：SQLite 持久化事件、图、快照、会话关系。

## 运行期诊断补充
- 若桌面端出现白屏、闪退式空白或卡片级运行时异常，必须优先补运行期诊断能力，而不是继续盲改功能。
- 最小诊断闭环应包括：
  - 前端全局错误捕获：`window.onerror`、`unhandledrejection`
  - React 根级 `ErrorBoundary`，崩溃后仍能在窗口内显示错误摘要与最近日志
  - 前端结构化日志缓冲区：至少包含 `ts/level/scope/message/details`
  - 后端关键链路日志：会话命令、事件广播、watcher 归因、错误路径
  - 可见诊断面板：即使主 UI 局部异常，也能看到最近日志
- 日志原则：
  - 记录关键状态切换与失败证据，不做无意义刷屏
  - 前后端日志字段尽量同构，便于串联问题
  - 新增日志不能破坏 P0 最小闭环

## 迁移策略（基于当前骨架）
1. 先补事件契约标准化与映射层（ADR-0002）。
2. 再补事件回放与图构建，保证可恢复。
3. 最后扩卡片与布局能力，保持每步可运行可验证。

## 验收最小集
- 多会话并行不串线。
- 修改文件后可在 Change Tracking 与 Diff 中看到一致结果。
- 会话 compact/new 后在 Session Graph 可见分支。
- 重启应用后可恢复项目、布局、会话与关键事件。
- Sidebar 切换项目/布局/会话后，主工作区联动正确且不丢失会话事实数据。

## 关联文档
- 规格：`docs/spec.md`
- 架构：`docs/architecture.md`
- ADR：`docs/decisions/0001-initial-architecture.md`、`docs/decisions/0002-event-contract-normalization.md`
- 执行计划：`.agent/PLANS.md`
