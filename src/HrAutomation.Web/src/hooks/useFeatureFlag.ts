import { useMemo } from "react";
import { getFeatureFlags, type FeatureFlags } from "@/app/config/featureFlags";

export function useFeatureFlag(flag: keyof FeatureFlags): boolean {
  return useMemo(() => getFeatureFlags()[flag], [flag]);
}
