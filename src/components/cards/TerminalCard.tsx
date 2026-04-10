import { lazy, Suspense } from "react";
import { CardErrorBoundary } from "../system/CardErrorBoundary";
import { TerminalFallbackView } from "./TerminalFallbackView";

const LazyAdvancedTerminalCard = lazy(async () => {
  const mod = await import("./AdvancedTerminalCard");
  return { default: mod.AdvancedTerminalCard };
});

export function TerminalCard() {
  return (
    <CardErrorBoundary cardName="TerminalCard" fallback={<TerminalFallbackView />}>
      <Suspense fallback={<TerminalFallbackView />}>
        <LazyAdvancedTerminalCard />
      </Suspense>
    </CardErrorBoundary>
  );
}
