# Execution Plan (Tonight P0)

## 计划定位
本文件是执行期唯一真相源（source of truth）。当前窗口目标是落地 `redesign-cmux-workbench-ui` 的最小可运行闭环：cmux 风格 shell、原生项目导入、pane 工作区，并保持桌面端稳定可验证。

## Active Task
- 实现 `redesign-cmux-workbench-ui`：
  - cmux 风格桌面 shell（黑/白/暗橙、直角、顶部控制区）
  - 左侧项目导入与默认 layout bootstrap
  - 右侧卡片新增入口
  - pane-based 工作区与拖拽调整
  - 保留运行期诊断、错误边界、重型卡片安全回退

## Milestones
- M1 Shell 骨架与视觉系统 - `completed`
  - 范围：
    - 替换现有顶栏与两栏壳层
    - 引入 cmux 风格 token、直角规则、黑/灰黑/暗橙配色
    - 实现左侧交通灯占位、项目 `+`、侧栏折叠、右侧通知与卡片 `+`
  - 验收：
    - 桌面窗口能看到新顶栏与新侧栏
    - 全局无圆角，主工作区为纯黑，侧栏为灰黑
    - 现有 Sidebar/Diagnostics 仍可见，窗口不白屏
  - 最小验证：
    - `npm run build`

- M2 项目导入与 layout bootstrap - `in_progress`
  - 范围：
    - Tauri 新增目录选择命令
    - 前端新增 `createOrActivateProjectFromPath`
    - 导入项目后自动创建默认 layouts 并切为活动项目
  - 验收：
    - 点击左侧 `+` 能拉起系统目录选择器
    - 成功选择目录后侧栏出现项目，且自动进入默认 layout
  - 最小验证：
    - `npm test -- src/state/__tests__/store.test.ts`
    - `npm run build`
    - `npm run tauri:dev`

- M3 Pane workspace engine - `pending`
  - 范围：
    - 用 pane split 模型替换静态 grid
    - 支持单卡全屏、双卡 1/2 分布、多卡自动分区
    - 支持拖拽分隔线并按 `project_id + layout_id` 持久化
    - 右侧 `+` 新增卡片并重排 pane
  - 验收：
    - 1/2/4 卡片场景自动分布符合 spec
    - 拖拽后 pane 比例可保存并恢复
    - 高级 `Diff/Terminal` 仍通过卡片级 fallback 保护
  - 最小验证：
    - `npm test`
    - `npm run build`

- M4 收口验证与评审 - `pending`
  - 范围：
    - 跑全量验证与桌面烟测
    - reviewer 复核 redesign 验收项与回归风险
    - 回写状态、风险、下一步
  - 验收：
    - `npm test` 通过
    - `npm run build` 通过
    - `npm run tauri:dev` 完成关键路径 smoke
    - reviewer 无阻断级问题
  - 最小验证：
    - `npm test`
    - `npm run build`
    - `npm run tauri:dev`

## Acceptance Criteria（当前任务）
- AC1：Shell 对齐 cmux 风格：纯黑主区、灰黑侧栏、白字、暗橙分隔线、全局直角
- AC2：顶部左侧存在交通灯区、项目 `+`、侧栏收起；右侧存在通知与卡片 `+`
- AC3：左侧 `+` 通过系统目录选择器导入项目，并自动生成默认 layout
- AC4：主区为 pane 工作区，至少支持 1/2/4 卡片自动分布与拖拽调整
- AC5：pane 和项目/layout 持久化在重复启动后可恢复，且不回归白屏
- AC6：`npm test`、`npm run build`、`npm run tauri:dev` 通过

## Validation Commands
- 单元：`npm test -- src/state/__tests__/store.test.ts`
- 全量：`npm test`
- 构建：`npm run build`
- 桌面烟测：`npm run tauri:dev`

## Current Status
- 当前 change：`redesign-cmux-workbench-ui`
- 当前里程碑：M2 项目导入与 layout bootstrap
- 已完成：OpenSpec proposal/design/specs/tasks 已全部创建并通过 `openspec validate`
- 现状判断：
  - 当前 `App` 已切为 cmux 风格顶栏，具备交通灯区、项目 `+`、侧栏折叠、通知与卡片 `+`
  - `Sidebar` 已切为灰黑主题并支持折叠态
  - 全局 shell / card 已切换到黑白暗橙主题，并移除圆角
  - `workspace.ts` 仍以旧的 `defaultGrid` 持久化模型驱动布局
  - `CardLayout` 仍是静态 CSS grid，不支持 pane split 或卡片动态增删
  - 运行期诊断与启动恢复保护已经可用，必须在 redesign 中保留
- 当前执行策略：
  - M1 已完成并通过 `npm run build`
  - 当前进入目录选择和项目 bootstrap
  - 最后替换 pane engine 与布局持久化

## Next Step
- 增加 Tauri 原生目录选择命令，并让左侧 `+` 真正创建项目与默认 layout

## Blockers
- 暂无
