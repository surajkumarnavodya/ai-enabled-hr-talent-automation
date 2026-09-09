#!/usr/bin/env node
/**
 * Confirms the canonical OpenAPI contract exists and is well-formed YAML
 * before `npm run api:generate` attempts to consume it. Does not perform
 * full OpenAPI schema validation (no network calls, no external spec
 * fetches) — just enough to fail fast with a clear message.
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parse } from "yaml";

const SPEC_PATH = resolve(process.cwd(), "../../openapi/hr-onboarding-api.openapi.yaml");

function fail(message) {
  console.error(`\n[validate-openapi] ${message}\n`);
  process.exitCode = 1;
}

if (!existsSync(SPEC_PATH)) {
  fail(
    `OpenAPI spec not found at ${SPEC_PATH}.\n` +
      "This is expected if the contract hasn't been published yet — see src/api/generated/README.md " +
      "for the temporary hand-written-types fallback used until then."
  );
  process.exit();
}

let doc;
try {
  doc = parse(readFileSync(SPEC_PATH, "utf-8"));
} catch (error) {
  fail(`Spec exists but is not valid YAML: ${error.message}`);
  process.exit();
}

if (!doc?.openapi || !doc?.paths) {
  fail("Spec parsed but is missing required top-level `openapi` and/or `paths` keys.");
  process.exit();
}

console.log(`[validate-openapi] OK — ${SPEC_PATH} (openapi ${doc.openapi}, ${Object.keys(doc.paths).length} paths)`);
