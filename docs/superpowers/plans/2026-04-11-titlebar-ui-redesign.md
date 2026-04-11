# Titlebar & UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 启用 Tauri overlay titlebar，将操作按钮移进原生标题栏区域，删除 Diagnostics 面板和 debug badges，整体色调重构为 Claude orange 风格。

**Architecture:** 修改 `tauri.conf.json` 启用 `titleBarStyle: "overlay"`，更新 `App.tsx` 移除冗余元素并加 drag 区域声明，最后全面重绘 `styles.css` 的配色与 topbar 布局。无新文件，纯改存量代码。

**Tech Stack:** Tauri v2, React/TypeScript, CSS custom properties

---

## 文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `src-tauri/tauri.conf.json` | 修改 | 加 `titleBarStyle: "overlay"` |
| `src/App.tsx` | 修改 | 移除 DiagnosticsPanel、fake traffic lights、debug badges |
| `src/styles.css` | 修改 | 配色重构 + topbar 布局 + 删除 diagnostics 样式 |

---

### Task 1: 启用 Overlay Titlebar

**Files:**
- Modify: `src-tauri/tauri.conf.json`

- [ ] **Step 1: 修改 tauri.conf.json，添加 titleBarStyle**

在 `app.windows[0]` 对象内追加：
```json
"titleBarStyle": "overlay"
```

完整 windows 配置应为：
```json
"windows": [
  {
    "label": "main",
    "title": "new-terminal",
    "width": 1400,
    "height": 900,
    "resizable": true,
    "titleBarStyle": "overlay"
  }
]
```

- [ ] **Step 2: 验证 JSON 格式合法**

```bash
cat src-tauri/tauri.conf.json | python3 -m json.tool > /dev/null && echo "OK"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add src-tauri/tauri.conf.json
git commit -m "feat: enable overlay titlebar for native traffic lights integration"
```

---

### Task 2: 清理 App.tsx

**Files:**
- Modify: `src/App.tsx`

移除的元素：
1. `import { DiagnosticsPanel }` 这行 import
2. `import { runtimeLogger, markRuntimeHealthy }` → 只保留 `markRuntimeHealthy`（仍被 useEffect 调用）
3. `.traffic-lights` div（原生流量灯会通过 overlay 显示）
4. `<DiagnosticsPanel />` 组件
5. `.workspace-status` div（debug badges）

新增：
- `<header>` 上加 `data-tauri-drag-region` 属性（让标题栏可拖拽）
- topbar 左组 `padding-left` 由 CSS 控制（见 Task 3），不需要 JS

- [ ] **Step 1: 移除 DiagnosticsPanel import**

将：
```tsx
import { DiagnosticsPanel } from "./components/system/DiagnosticsPanel";
import { runtimeLogger, markRuntimeHealthy } from "./lib/runtimeDiagnostics";
```
改为：
```tsx
import { markRuntimeHealthy } from "./lib/runtimeDiagnostics";
```

注意：`runtimeLogger` 仍在文件中多处使用，不能全删——只删 import 中的 `runtimeLogger,` 前缀保留 `markRuntimeHealthy`。实际上 `runtimeLogger` 仍有使用，需保留：
```tsx
import { runtimeLogger, markRuntimeHealthy } from "./lib/runtimeDiagnostics";
```
只移除 `DiagnosticsPanel` 的 import 行。

- [ ] **Step 2: 移除 topbar 中的 .traffic-lights div**

在 `return` JSX 中，找到：
```tsx
<div className="traffic-lights" aria-hidden="true">
  <span className="traffic-light traffic-light-close" />
  <span className="traffic-light traffic-light-minimize" />
  <span className="traffic-light traffic-light-expand" />
</div>
```
整块删除。

- [ ] **Step 3: 给 header 加 data-tauri-drag-region**

将：
```tsx
<header className="topbar">
```
改为：
```tsx
<header className="topbar" data-tauri-drag-region>
```

- [ ] **Step 4: 移除 workspace-status div**

找到并删除：
```tsx
<div className="workspace-status">
  <span className="workspace-badge">project:{activeProject.id}</span>
  <span className="workspace-badge">layout:{activeLayout.id}</span>
  <span className="workspace-badge">sessions:{projectSessions.length}</span>
</div>
```

- [ ] **Step 5: 移除 DiagnosticsPanel 组件**

找到并删除：
```tsx
<DiagnosticsPanel />
```

- [ ] **Step 6: 运行类型检查**

```bash
npm run build 2>&1 | tail -20
```
Expected: 无 TypeScript 错误（Vite build 成功）

- [ ] **Step 7: Commit**

```bash
git add src/App.tsx
git commit -m "feat: remove diagnostics panel, fake traffic lights, debug badges; add drag region"
```

---

### Task 3: 重绘 styles.css

**Files:**
- Modify: `src/styles.css`

配色方案（Claude orange 主色）：
```css
--shell-bg: #0a0a0a;
--shell-panel: #111111;
--shell-panel-2: #181818;
--shell-card: #0d0d0d;
--shell-divider: #c4673a;        /* Claude orange, 边框高亮 */
--shell-divider-muted: #2e1a10;  /* 低调橙，普通边框 */
--text: #e8e8e8;
--muted: #666666;
--accent: #d97757;               /* Claude orange 主色 */
```

topbar 关键改动：
- `padding-left: 80px`（为原生流量灯留出空间，标准 macOS = ~76px）
- `min-height: 44px`（保持不变）
- 背景更深：`#060606`

- [ ] **Step 1: 更新 CSS 变量**

将 `:root` 块改为：
```css
:root {
  color-scheme: dark;
  --shell-bg: #0a0a0a;
  --shell-panel: #111111;
  --shell-panel-2: #181818;
  --shell-card: #0d0d0d;
  --shell-divider: #c4673a;
  --shell-divider-muted: #2e1a10;
  --text: #e8e8e8;
  --muted: #666666;
  --accent: #d97757;
}
```

- [ ] **Step 2: 更新 topbar 样式**

将 `.topbar` 块改为：
```css
.topbar {
  min-height: 44px;
  padding: 0 12px 0 80px;     /* 左侧 80px 给原生流量灯 */
  border-bottom: 1px solid var(--shell-divider);
  background: #060606;
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 12px;
  -webkit-app-region: drag;   /* 标题栏可拖拽（CSS fallback） */
}
```

按钮不可拖拽（防止 CSS drag 覆盖点击）：
在 `.shell-icon-button` 规则中追加：
```css
-webkit-app-region: no-drag;
```

- [ ] **Step 3: 移除 .traffic-lights 相关样式**

删除以下 CSS 块：
```css
.traffic-lights { ... }
.traffic-light { ... }
.traffic-light-close { ... }
.traffic-light-minimize { ... }
.traffic-light-expand { ... }
```

- [ ] **Step 4: 移除所有 diagnostics 样式**

删除以下所有 CSS 块：
- `.diagnostics-shell`
- `.diagnostics-header`
- `.diagnostics-header h2`
- `.diagnostics-log-list`
- `.diagnostics-log`
- `.diagnostics-error`
- `.diagnostics-warn`
- `.diagnostics-meta`
- `.diagnostics-message`
- `.diagnostics-details`

同时删除 `.workspace-status` 和 `.workspace-badge` 块。

- [ ] **Step 5: 更新 active 状态颜色（侧边栏 / nav items）**

将所有 `.active` 背景色从 `#15100c` 改为 `#1a0f08`（偏橙的深色），边框从 `var(--shell-divider)` 保持不变（已是橙色）：

```css
.nav-item.active,
.nav-subitem.active,
.sidebar-compact-item.active {
  border-color: var(--shell-divider);
  background: #1a0f08;
}
```

将 `.bubble.agent` 背景改为 `#1a0f08`（橙调）：
```css
.bubble.agent {
  background: #1a0f08;
}
```

- [ ] **Step 6: 更新 session-pill active 状态**

```css
.session-pill.active {
  border-color: var(--shell-divider);
  background: #1a0f08;
}
```

- [ ] **Step 7: 运行构建验证**

```bash
npm run build 2>&1 | tail -20
```
Expected: 成功

- [ ] **Step 8: Commit**

```bash
git add src/styles.css
git commit -m "feat: redesign UI with Claude orange theme and overlay titlebar layout"
```

---

## 验证清单

- [ ] `npm run tauri:dev` 启动后，流量灯出现在窗口最顶部，右侧紧跟操作按钮
- [ ] 不再有第二条 topbar（无重复）
- [ ] Diagnostics 面板消失
- [ ] 无 debug badge 行（project:xxx / layout:xxx / sessions:0）
- [ ] 主色调为 Claude orange（`#d97757`），边框可见橙色
- [ ] 点击 `+`（add project / add card）按钮仍然有效
- [ ] 侧边栏折叠/展开正常
