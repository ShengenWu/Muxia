# Repository Guidelines

## 文档组织规范
- `AGENTS.md` 只放仓库级规则、流程入口、文档索引，不承载长篇方案。
- 产品方向定义放 `docs/spec.md`，实现方案放 `docs/architecture.md`。
- 关键技术决策按 ADR 记录到 `docs/decisions/*.md`（从 `0001-` 递增）。
- 执行期唯一计划真相源为 `.agent/PLANS.md`，施工约束放 `.agent/IMPLEMENT.md`，评审清单放 `.agent/code_review.md`。
- 复杂任务必须落到 task-specific 文档，并在本文档索引中登记。

## 文档索引（当前）
- 产品规格：`docs/spec.md`
- 架构方案：`docs/architecture.md`
- ADR：`docs/decisions/0001-initial-architecture.md`、`docs/decisions/0002-event-contract-normalization.md`
- 任务文档目录：`docs/tasks/*.md`
- 当前 redesign 任务：`docs/tasks/cmux-redesign.md`
- 当前活跃任务以 `.agent/PLANS.md` 的 Active Task / Current Task 段为准

## 执行入口规则
- 涉及以下任一情况，必须先更新 task-specific 文档与 `.agent/PLANS.md`，再开始编码：
  - 新功能或新卡片类型
  - 跨 `src/` 与 `src-tauri/` 的联动修改
  - 事件契约 / 持久化结构 / 状态模型调整
  - 预期会改动 3 个以上文件
  - 需要分 milestone 推进的任务

## 代码结构
- `src/`: React + TypeScript 前端。
- `src/components/cards/`: Alpha 卡片实现（Chat/Graph/Diff/Terminal）。
- `src/state/`: 当前 Zustand 状态与测试（`__tests__/`）。
- `src-tauri/`: Tauri v2 + Rust 后端（PTY、事件总线、适配器、监听、存储）。
- `docs/`: 规格、架构、决策记录与任务文档。
- `.agent/`: 执行计划、施工手册、评审规范。

## 构建与运行
- `npm install`: 安装依赖。
- `npm run build`: TypeScript 检查 + Vite 打包。
- `npm test`: 运行 Vitest。
- `npm run dev`: 仅前端调试。
- `npm run tauri:dev`: 桌面端联调（需要 `rustc`/`cargo`）。

## 编码约定
- TS/TSX 使用 2 空格缩进，开启 strict，优先显式类型。
- React 组件与文件名使用 `PascalCase`，函数/变量用 `camelCase`。
- Rust 代码遵循 `rustfmt` 默认风格。
- 事件命名统一以 `snake_case` 作为持久化与跨端契约（如 `session_started`、`action_tool_call`）；外部适配器若输出点语义事件，需在后端做一次规范化映射。

## 提交流程
- 提交信息使用 Conventional Commits（`feat:`、`fix:`、`chore:`）。
- 每个 PR 至少包含：变更摘要、验证结果（`npm test`/`npm run build`）、UI 改动截图（若有）。
- 不提交 `*.db`、`dist/`、`target/`、本地缓存产物。
