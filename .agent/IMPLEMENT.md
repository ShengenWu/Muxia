# Implementation Runbook

## 执行原则
- 严格按 `.agent/PLANS.md` 里程碑推进，不跨阶段抢做。
- 每个里程碑遵循“先契约、后实现、再验证”。
- 发现范围漂移时，先更新 `PLANS.md` 的范围变更记录。

## 单里程碑执行步骤
1. 读取并对齐：`docs/spec.md`、`docs/architecture.md`、相关 ADR、`docs/tasks/alpha-observability-workbench.md`。
2. 实现最小闭环：只做该里程碑 DoD 所需内容。
3. 验证并记录：执行命令、记录结果、列出已知风险。
4. 回写文档：更新 `PLANS.md` 状态和 `.agent/code_review.md` 结论。

## 约束清单
- 事件事实源以 `file_changed/file_created/file_deleted` 为准，不新增 `diff.updated` 一级事件。
- 事件持久化契约以 `snake_case` 为准；兼容映射仅存在于适配器入口。
- Diff 与 Editor 职责分离，不在 Alpha 合并。
- 多 Agent 仅实现“并行会话 + 手动关联”，不实现自动编排。

## 验证基线
- 必跑：`npm run build`、`npm test`。
- 桌面联调：`npm run tauri:dev`（需要 Rust 工具链）。
- 链路验证：至少覆盖一次 `message -> action -> file_changed -> card 联动`。

## 文档更新约束
- 新增复杂设计时，优先写入 task-specific 文档并在 `AGENTS.md` 索引登记。
- `AGENTS.md` 仅做规则与入口，不追加长篇实现细节。

## Commit workflow
1. 完成当前节点实现
2. 运行该节点最小必要验证
3. 若验证通过：
   - 更新 `.agent/PLANS.md` 状态
   - 仅 stage 当前节点相关文件
   - 创建一次 Conventional Commit
4. 若验证失败：
   - 继续修复，不提交“伪完成”节点