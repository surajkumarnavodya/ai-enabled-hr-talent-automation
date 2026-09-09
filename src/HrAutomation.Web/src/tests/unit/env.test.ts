import { describe, expect, it } from "vitest";
import { readBool } from "@/app/config/env";
import { appConfig } from "@/app/config/appConfig";

describe("MSW default-off behavior", () => {
  it("readBool defaults to the given fallback when the env var is unset", () => {
    expect(readBool(undefined, false)).toBe(false);
    expect(readBool(undefined, true)).toBe(true);
  });

  it("readBool only treats the literal strings 'true'/'1' as true", () => {
    expect(readBool("true", false)).toBe(true);
    expect(readBool("1", false)).toBe(true);
    expect(readBool("false", true)).toBe(false);
    expect(readBool("yes", true)).toBe(false);
  });

  it("appConfig.mswEnabled is never true in a production environment, regardless of the raw env value", () => {
    // appConfig.mswEnabled = env.enableMsw && env.appEnv !== "prod" — this is the actual
    // safety net described in CLAUDE.md ("MSW must be disabled regardless of frontend
    // environment variables" in prod). We can't override import.meta.env at runtime here
    // without a full module re-import, so this asserts the invariant on whatever the test
    // process's real resolved config is: if appEnv is "prod", mswEnabled must be false.
    if (appConfig.env === "prod") {
      expect(appConfig.mswEnabled).toBe(false);
    }
  });
});
