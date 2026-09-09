import { describe, expect, it } from "vitest";
import { redact } from "@/lib/safeLogger";

describe("safeLogger redaction", () => {
  it("redacts keys that look sensitive", () => {
    const result = redact({
      token: "abc123",
      password: "hunter2",
      candidateEmail: "demo@example.invalid",
      salary: 150000,
      note: "this is fine",
    });

    expect(result.token).toBe("[redacted]");
    expect(result.password).toBe("[redacted]");
    expect(result.candidateEmail).toBe("[redacted]");
    expect(result.salary).toBe("[redacted]");
    expect(result.note).toBe("this is fine");
  });

  it("redacts sensitive keys inside nested objects", () => {
    const result = redact({ context: { document: "raw cv text", safeField: 42 } });
    const nested = result.context as Record<string, unknown>;
    expect(nested.document).toBe("[redacted]");
    expect(nested.safeField).toBe(42);
  });

  it("never throws on deeply nested or array input", () => {
    expect(() => redact({ a: { b: { c: { d: { e: "deep" } } } }, list: [1, 2, 3] })).not.toThrow();
  });
});
