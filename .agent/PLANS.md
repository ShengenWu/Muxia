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

- M2 Sidebar + 多布局（前端最小可用）- `in_progress`
  - 范围：
    - 左侧常驻：ProjectTree/LayoutList/SessionList
    - 主区右侧卡片栅格，布局可切换、可持久化
    - 同项目下支持多个布局（本地持久化）
  - 验收：
    - 根节点为项目，子节点为布局
    - 切布局仅影响卡片排布，不污染会话事实
    - 会话点击可联动当前会话
  - 最小验证：
    - `npm run build`
    - 手工 smoke：切换布局与会话

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
- AC3：右侧主区全部为卡片，可自由调整布局并持久化。
- AC4：会话列表按项目上下文显示，点击会话可联动 Chat/Graph/Diff。
- AC5：形成最小演示链路并可重复验证。

## Validation Commands
- 单元：`npm test -- src/state/__tests__/store.test.ts`
- 全量：`npm test`
- 构建：`npm run build`
- 桌面烟测：`npm run tauri:dev`（若本机具备 Rust 工具链）

## Current Status
- 当前里程碑：M2（进行中）
- 已完成：M1 事件契约迁移（前后端 `snake_case`），并清理旧 `.js` 镜像文件避免测试解析歧义
- 正在做：左侧 Sidebar 与多布局最小可用实现

## Next Step
- 完成 Sidebar（项目->布局->会话）与右侧卡片区联动，验证后提交 `feat: add persistent sidebar with project-layout navigation`。

## Blockers
- 暂无阻塞。
