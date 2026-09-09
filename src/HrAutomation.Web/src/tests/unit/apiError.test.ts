import { describe, expect, it } from "vitest";
import { ApiError, kindFromStatus, userSafeMessage, isRetryableError } from "@/api/client/apiError";

describe("apiError mapping", () => {
  it.each([
    [401, "unauthorized"],
    [403, "forbidden"],
    [404, "not_found"],
    [409, "conflict"],
    [422, "validation"],
    [429, "rate_limited"],
    [500, "server_error"],
    [503, "server_error"],
  ] as const)("maps status %i to kind %s", (status, expectedKind) => {
    expect(kindFromStatus(status)).toBe(expectedKind);
  });

  it("maps an undefined status to network_error", () => {
    expect(kindFromStatus(undefined)).toBe("network_error");
  });

  it("never surfaces the raw error message to the user", () => {
    const error = new ApiError("server_error", "NullReferenceException at Foo.Bar:42");
    expect(userSafeMessage(error)).not.toContain("NullReferenceException");
    expect(userSafeMessage(error)).toMatch(/something went wrong/i);
  });

  it("only treats network/server errors as retryable", () => {
    expect(isRetryableError(new ApiError("network_error", "x"))).toBe(true);
    expect(isRetryableError(new ApiError("server_error", "x"))).toBe(true);
    expect(isRetryableError(new ApiError("validation", "x"))).toBe(false);
    expect(isRetryableError(new ApiError("forbidden", "x"))).toBe(false);
    expect(isRetryableError(new Error("not an ApiError"))).toBe(false);
  });
});
