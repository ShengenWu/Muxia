# Code Review Checklist

## 使用方式
- 每个里程碑结束后执行一次本清单。
- 先记录风险与缺陷，再记录通过项。

## 核心检查项
- 事件契约一致性：
  - 事件类型使用 `snake_case`，无新引入点语义残留。
  - 事件字段完整，`session_id/project_id/ts/payload` 不缺失。
- 会话隔离：
  - 多会话并行时，消息、动作、文件变更、Diff 不串线。
- 侧边栏联动：
  - 项目/布局/会话切换后，主工作区绑定正确，且不会污染其他会话数据。
- 图构建正确性：
  - `Message/Action/Artifact/SessionEvent` 节点类型正确。
  - `reads/writes/caused_by/next` 等关键边可重建且无断链。
- 变更可控：
  - `file_changed/file_created/file_deleted` 能驱动 Change Tracking 与 Diff。
- 回放恢复：
  - 重启后布局、会话、关键事件与图结构可恢复。

## 验证命令记录
- `npm run build`:
  - 结果：通过
  - 备注：前端生产构建完成；仍有 Vite chunk size warning，但不阻断今晚交付。
- `npm test`:
  - 结果：通过
  - 备注：Vitest 当前 1 个 store reducer 用例通过。
- `npm run tauri:dev`:
  - 结果：通过关键路径 smoke（编译并启动 `target/debug/new-terminal`）
  - 备注：首次运行暴露 `Emitter` import 与缺失 `icons/icon.png`，已修复后成功启动。

## 本轮结论
- 阻断级问题：无
- 重要已修复项：
  - 前端 active session 切换已同步到后端 `set_active_session`，避免 Sidebar 切换后 watcher 继续归因到旧 session。
  - `selectedDiffPath` 已按 `session_id` 隔离，Change Tracking 与 Diff 不再共享全局选中态。
- 剩余低级风险：
  - `file_changed` 仍通过后端 `last_active_session` 归因；在极短窗口内快速切换会话与文件写入同时发生时，仍可能出现一次串线。

## 缺陷记录模板
- 严重级别：
- 现象：
- 复现步骤：
- 预期行为：
- 影响范围：
- 修复建议：
