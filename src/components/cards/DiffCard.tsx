import { lazy, Suspense, useMemo } from "react";
import { CardErrorBoundary } from "../system/CardErrorBoundary";
import { DiffFallbackView } from "./DiffFallbackView";

const LazyAdvancedDiffCard = lazy(async () => {
  const mod = await import("./AdvancedDiffCard");
  return { default: mod.AdvancedDiffCard };
});

export function DiffCard() {
  return (
    <CardErrorBoundary cardName="DiffCard" fallback={<DiffFallbackView />}>
      <Suspense fallback={<DiffFallbackView />}>
        <LazyAdvancedDiffCard />
      </Suspense>
    </CardErrorBoundary>
  );
}
