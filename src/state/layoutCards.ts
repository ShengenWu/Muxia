export const ALL_CARD_IDS = ["chat", "graph", "change_tracking", "diff", "terminal"] as const;

export type PaneCardId = typeof ALL_CARD_IDS[number];

export const isPaneCardId = (value: string): value is PaneCardId => {
  return (ALL_CARD_IDS as readonly string[]).includes(value);
};
