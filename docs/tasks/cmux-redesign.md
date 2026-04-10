# CMux Workbench Redesign Task

## Context
- Change source: `openspec/changes/redesign-cmux-workbench-ui/`
- Goal: 将当前 alpha workbench 重构为 cmux 风格桌面 shell，并保持当前桌面稳定性、诊断能力和核心卡片链路可用。

## Scope
- 新 shell：黑底、灰黑侧栏、白字、暗橙分隔线、全局直角
- 顶栏：左侧交通灯区、项目 `+`、侧栏收起；右侧通知、卡片 `+`
- 项目导入：调用系统目录选择器，导入后自动创建默认 layout
- 工作区：从静态 grid 切换为 pane split，可自动分布、拖拽调整、按 layout 持久化

## Constraints
- 不回退已有运行期诊断、ErrorBoundary、卡片级 fallback
- 保持 `snake_case` 事件契约不变
- 仅做本次 redesign 所需的最小状态模型扩展，不顺手重构其他卡片内部逻辑
- 每个 milestone 都必须可独立验证并可独立回滚

## Delivery Strategy
1. 先重做 shell 和视觉层，不改变现有卡片内部逻辑
2. 再打通项目导入与默认 layout bootstrap
3. 最后替换 pane engine 和持久化模型
4. 全量回归 `npm test`、`npm run build`、`npm run tauri:dev`

## Validation Focus
- 重复启动桌面窗口不能再因持久化状态导致白屏
- 新项目导入后立即可见，并自动进入默认 layout
- 1/2/4 卡片场景下 pane 分布与拖拽调整可用
