# Execution Plan (Tonight P0)

## 计划定位
本文件是执行期唯一真相源（source of truth）。本次窗口目标是交付可运行、可验证、可演示的最小闭环（walking skeleton），并尽量覆盖更多 P0 节点。

## Active Task
- 实现 P0 最小闭环：
  - 左侧常驻 Sidebar（项目/布局/会话导航）
  - 主工作区卡片化自由布局
  - `snake_case` 事件契约统一与前后端联动
  - 最小链路 `message_user -> action_tool_call -> file_changed -> change/diff 展示`

## Milestones
- M1 `snake_case` 事件契约落地（前后端）- `completed`
  - 范围：
    - 后端事件类型改为 `snake_case`
    - 前端类型与 reducer 改为 `snake_case`
    - 兼容旧字段（仅入口映射），不新增点语义事件
  - 验收：
    - Store 测试通过，核心事件可归约
    - 不再依赖 `session.started`/`action.detected`/`diff.updated`
  - 最小验证：
    - `npm test -- src/state/__tests__/store.test.ts`

- M2a Sidebar 骨架 + 项目/布局本地模型 - `completed`
  - 范围：
    - 新增左侧常驻 Sidebar 容器
    - 以前端本地持久化建立最小 `Project -> Layout` 模型
    - 主区改为“侧边栏 + 卡片工作区”两栏结构
  - 验收：
    - 左侧可见当前项目与布局列表
    - 可切换活动布局
    - 刷新后仍能恢复活动项目与布局
  - 最小验证：
    - `npm run build`

- M2b 布局持久化 + 会话绑定联动 - `in_progress`
  - 范围：
    - 布局按 `project_id + layout_id` 隔离保存
    - SessionList 与 active session 绑定进入 Sidebar
    - 切换布局不影响会话事实数据；切换会话联动 Chat/Graph/Diff/Terminal
  - 验收：
    - 同项目多布局可独立保存卡片排布
    - 会话点击后主工作区卡片绑定到该会话
    - 不同布局切换后 session data 不丢失、不串线
  - 最小验证：
    - `npm test -- src/state/__tests__/store.test.ts`
    - `npm run build`

- M3 最小链路打通（watcher/change/diff）- `pending`
  - 范围：
    - `file_changed` 驱动 Change Tracking 与 Diff
    - 移除 `diff.updated` 一级事实事件，Diff 数据来自文件事件/快照
  - 验收：
    - 修改文件后 Change Tracking 列表出现文件
    - 选中文件可查看最新 before/after
  - 最小验证：
    - `npm test`
    - `npm run build`

- M4 收口验证与评审 - `pending`
  - 范围：
    - 运行全量基线验证
    - 依据 `.agent/code_review.md` 做一次 reviewer 复核
    - 回写状态、风险、下一步
  - 验收：
    - `npm test` 通过
    - `npm run build` 通过
    - reviewer 无阻断级问题
  - 最小验证：
    - `npm test`
    - `npm run build`
    - `npm run tauri:dev`（若环境允许）

## Acceptance Criteria（今晚）
- AC1：事件契约统一为 `snake_case`，前后端一致。
- AC2：左侧侧边栏常驻，按“项目 -> 布局”组织，布局可切换。
- AC3：右侧主区全部为卡片，布局按 `project_id + layout_id` 持久化。
- AC4：会话列表按当前项目显示，点击会话可联动 Chat/Graph/Diff/Terminal。
- AC5：形成最小演示链路并可重复验证。

## Validation Commands
- 单元：`npm test -- src/state/__tests__/store.test.ts`
- 全量：`npm test`
- 构建：`npm run build`
- 桌面烟测：`npm run tauri:dev`（若本机具备 Rust 工具链）

## Current Status
- 当前里程碑：M2b（进行中）
- 已完成：M1 事件契约迁移（前后端 `snake_case`），Store/后端已接受 `file_changed` 作为 diff 事实源
- 本轮新增完成：
  - 左侧 Sidebar 骨架已落地，主界面改为 Sidebar + 工作区两栏
  - 建立前端本地 `Project -> Layout` 模型，并支持刷新恢复活动项目/布局
  - 布局存储已切到 `project_id:layout_id` 作用域
  - 修复 `SessionRecord.projectId` 契约缺口，默认绑定到当前 Alpha 项目
- 当前代码现状：
  - 前端已具备 Sidebar、双布局预设与作用域布局持久化
  - 会话事实仍按 `session_id` 存储，会话切换入口仍位于 Chat 卡片内部
  - Sidebar 的 SessionList 目前为占位说明，尚未接管 active session 绑定
- 正在做：把 SessionList 移入 Sidebar，并确保会话切换不受布局切换污染

## Next Step
- 完成 M2b：Sidebar 接管 SessionList，保持 Chat/Graph/Diff/Terminal 随 active session 联动；验证通过后提交 `feat: bind sidebar sessions to workspace layout`。

## Blockers
- 暂无阻塞。
