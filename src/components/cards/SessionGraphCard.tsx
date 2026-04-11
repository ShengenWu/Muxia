import { useMemo } from "react";
import { useAppStore } from "../../state/store";

export function SessionGraphCard() {
  const sessionId = useAppStore((s) => s.activeSessionId);
  const nodes = useAppStore((s) => (sessionId ? s.nodes[sessionId] ?? [] : []));
  const edges = useAppStore((s) => (sessionId ? s.edges[sessionId] ?? [] : []));

  const sortedNodes = useMemo(() => [...nodes].sort((a, b) => a.ts.localeCompare(b.ts)), [nodes]);

  if (!sessionId) {
    return (
      <section className="card-shell">
        <header className="card-header">
          <h2>Session Graph</h2>
        </header>
        <p className="empty">Create a session to render action graph.</p>
      </section>
    );
  }

  return (
    <section className="card-shell">
      <header className="card-header">
        <h2>Session Graph</h2>
        <span className="muted">nodes: {nodes.length} edges: {edges.length}</span>
      </header>
      <div className="graph-list">
        {sortedNodes.map((node) => (
          <article key={node.id} className="graph-node">
            <div className="graph-node-title">{node.kind} - {node.title}</div>
            <div className="muted">{new Date(node.ts).toLocaleTimeString()}</div>
            {node.artifactPath ? <code>{node.artifactPath}</code> : null}
            {node.detail ? <p>{node.detail}</p> : null}
          </article>
        ))}
      </div>
    </section>
  );
}
