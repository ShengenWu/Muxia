import type { ErrorInfo, ReactNode } from "react";
import { Component } from "react";
import { runtimeLogger } from "../../lib/runtimeDiagnostics";

interface CardErrorBoundaryProps {
  cardName: string;
  fallback: ReactNode;
  children: ReactNode;
}

interface CardErrorBoundaryState {
  failed: boolean;
}

export class CardErrorBoundary extends Component<CardErrorBoundaryProps, CardErrorBoundaryState> {
  state: CardErrorBoundaryState = { failed: false };

  static getDerivedStateFromError(): CardErrorBoundaryState {
    return { failed: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    runtimeLogger.error("card", `${this.props.cardName} crashed and fell back`, {
      cardName: this.props.cardName,
      name: error.name,
      message: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack
    });
  }

  render() {
    if (this.state.failed) {
      return this.props.fallback;
    }

    return this.props.children;
  }
}
