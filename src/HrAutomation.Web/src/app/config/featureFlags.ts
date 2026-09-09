/**
 * Frontend feature-flag reader. Mirrors the shape of config/schemas/platform-config.schema.json
 * `featureFlags` block and config/feature-flags/ at the repo root — the backend is the source
 * of truth once an admin/config endpoint exists; until then this ships safe, conservative
 * client-only defaults for local development and Storybook-less component preview.
 *
 * TODO: replace the static DEFAULT_FLAGS below with a query against a real
 * `/api/v1/admin/feature-flags` endpoint once available (see
 * docs/07-mcp-integrations and Administration feature module).
 */
export interface FeatureFlags {
  aiMatchingEnabled: boolean;
  autoSchedulingSuggestions: boolean;
  ragPolicyAnswers: boolean;
}

const DEFAULT_FLAGS: FeatureFlags = {
  aiMatchingEnabled: true,
  autoSchedulingSuggestions: true,
  ragPolicyAnswers: true,
};

export function getFeatureFlags(): FeatureFlags {
  return DEFAULT_FLAGS;
}
