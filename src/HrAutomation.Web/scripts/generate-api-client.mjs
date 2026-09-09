#!/usr/bin/env node
/**
 * Generates TypeScript types from the canonical OpenAPI contract into
 * src/api/generated/schema.d.ts. See docs/04-api/frontend-api-integration.md
 * for the full workflow, and src/api/generated/README.md for what to do with
 * the output.
 *
 * This only generates *types* (via openapi-typescript), not a full client —
 * src/api/client/apiClient.ts stays the single hand-written Axios client;
 * once generated, import request/response types from "@/api/generated/schema"
 * in place of the temporary types in src/types/workflow.ts.
 */
import { existsSync } from "node:fs";
import { resolve, dirname, join } from "node:path";
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";

const SPEC_PATH = resolve(process.cwd(), "../../openapi/hr-onboarding-api.openapi.yaml");
const OUTPUT_PATH = resolve(process.cwd(), "src/api/generated/schema.d.ts");

if (!existsSync(SPEC_PATH)) {
  console.error(
    `\n[generate-api-client] OpenAPI spec not found at ${SPEC_PATH}.\n` +
      "Run \"npm run api:validate\" for details. Nothing was generated.\n"
  );
  process.exit(1);
}

console.log(`[generate-api-client] Generating types from ${SPEC_PATH} -> ${OUTPUT_PATH}`);

// Resolve and invoke the CLI script directly with `node <cli.js> ...args` rather
// than via `npx`/a shell — repository paths containing spaces (e.g. "HR
// Automation Agent") get mangled by shell-string reassembly on Windows when
// `execFileSync` is given `shell: true`. Passing an explicit argv array with
// shell disabled (the default) avoids any shell re-parsing entirely.
// openapi-typescript's package.json "exports" map rewrites any "*.js" subpath
// request to "*.mjs" (which doesn't exist for bin/cli.js) — resolve the
// package root via its package.json instead, then join the real on-disk path.
const require = createRequire(import.meta.url);
const packageJsonPath = require.resolve("openapi-typescript/package.json");
const cliEntry = join(dirname(packageJsonPath), "bin", "cli.js");

execFileSync(process.execPath, [cliEntry, SPEC_PATH, "-o", OUTPUT_PATH], {
  stdio: "inherit",
});

console.log(
  "\n[generate-api-client] Done. Review the diff, then replace the temporary hand-written types\n" +
    "(marked TODO(api-contract) in src/types/workflow.ts and feature hook files) with imports from\n" +
    '"@/api/generated/schema".\n'
);
