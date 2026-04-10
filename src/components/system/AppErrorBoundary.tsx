import type { ErrorInfo, ReactNode } from "react";
import { Component } from "react";
import { DiagnosticsPanel } from "./DiagnosticsPanel";
import { runtimeLogger } from "../../lib/runtimeDiagnostics";

interface AppErrorBoundaryProps {
  children: ReactNode;
}

interface AppErrorBoundaryState {
  error?: Error;
  componentStack?: string;
}

export class AppErrorBoundary extends Component<AppErrorBoundaryProps, AppErrorBoundaryState> {
  state: AppErrorBoundaryState = {};

  static getDerivedStateFromError(error: Error): AppErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    runtimeLogger.error("react", "AppErrorBoundary caught render error", {
      name: error.name,
      message: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack
    });
    this.setState({ componentStack: errorInfo.componentStack ?? undefined });
  }

  render() {
    if (this.state.error) {
      return (
        <main className="app-root error-root">
          <section className="error-shell">
            <h1>new-terminal crashed during render</h1>
            <p className="muted">{this.state.error.message}</p>
            <pre className="error-stack">{this.state.error.stack}</pre>
            {this.state.componentStack ? <pre className="error-stack">{this.state.componentStack}</pre> : null}
          </section>
          <DiagnosticsPanel title="Recent Runtime Logs" expanded />
        </main>
      );
    }

    return this.props.children;
  }
}
