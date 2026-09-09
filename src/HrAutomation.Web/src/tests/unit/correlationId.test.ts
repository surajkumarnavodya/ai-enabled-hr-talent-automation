import { describe, expect, it } from "vitest";
import { createCorrelationId, createIdempotencyKey } from "@/api/client/correlationId";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

describe("correlationId", () => {
  it("generates a valid v4-shaped UUID", () => {
    expect(createCorrelationId()).toMatch(UUID_PATTERN);
  });

  it("generates a unique value on every call", () => {
    const ids = new Set(Array.from({ length: 20 }, () => createCorrelationId()));
    expect(ids.size).toBe(20);
  });

  it("idempotency keys are also unique per call", () => {
    expect(createIdempotencyKey()).not.toBe(createIdempotencyKey());
  });
});
