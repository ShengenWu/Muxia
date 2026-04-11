# ADR 0002: Event Contract Normalization (snake_case)

## 状态
Accepted

## 背景
当前骨架代码中同时存在点语义事件（如 `session.started`）与规划中的 `snake_case` 事件（如 `session_started`）。双规范并存会带来：
- 前后端类型对齐困难
- SQLite 查询与聚合复杂化
- 会话图构建规则实现分叉

## 决策
- 统一以 `snake_case` 作为系统内部唯一标准（持久化、广播、前端 reducer、图构建）。
- 外部适配器可接受点语义输入，但必须在后端进入 EventBus 前完成规范化。
- `diff.updated` 不再作为一级事实事件；Diff 刷新由 `file_changed/file_created/file_deleted` + 快照计算驱动。

## 结果与影响
- 优点：跨端类型更稳定，索引与统计规则更直接，回放逻辑更清晰。
- 代价：需要补一层兼容映射，并逐步迁移现有类型定义与测试。

## 迁移计划
1. 新增映射层：`session.started -> session_started` 等。
2. Rust/TS 类型声明切换到 `snake_case` 枚举。
3. 更新测试数据与 fixtures。
4. 删除遗留点语义分支。
