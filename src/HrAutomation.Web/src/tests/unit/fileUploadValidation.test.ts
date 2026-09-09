import { describe, expect, it } from "vitest";
import { validateFileForUpload } from "@/lib/validation";

function makeFile(name: string, type: string, sizeBytes: number): File {
  const file = new File([new Uint8Array(sizeBytes)], name, { type });
  return file;
}

describe("validateFileForUpload (client-side, advisory only)", () => {
  it("accepts a well-formed PDF under the size limit", () => {
    const file = makeFile("resume-demo.pdf", "application/pdf", 1024);
    const result = validateFileForUpload(file, ["application/pdf"], 10 * 1024 * 1024);
    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it("rejects an unsupported MIME type", () => {
    const file = makeFile("script-demo.exe", "application/x-msdownload", 1024);
    const result = validateFileForUpload(file, ["application/pdf"], 10 * 1024 * 1024);
    expect(result.valid).toBe(false);
    expect(result.errors[0]).toMatch(/unsupported file type/i);
  });

  it("rejects a file exceeding the max size", () => {
    const file = makeFile("large-demo.pdf", "application/pdf", 11 * 1024 * 1024);
    const result = validateFileForUpload(file, ["application/pdf"], 10 * 1024 * 1024);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes("exceeds the maximum size"))).toBe(true);
  });

  it("rejects an empty file", () => {
    const file = makeFile("empty-demo.pdf", "application/pdf", 0);
    const result = validateFileForUpload(file, ["application/pdf"], 10 * 1024 * 1024);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes("empty"))).toBe(true);
  });
});
