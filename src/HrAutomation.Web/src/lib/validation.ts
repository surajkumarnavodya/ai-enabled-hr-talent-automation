import { z } from "zod";
import { ALLOWED_DOCUMENT_MIME_TYPES, MAX_UPLOAD_SIZE_BYTES } from "@/lib/constants";

/**
 * Client-side validation is a UX convenience only — it never replaces
 * server-side validation/authorization. See CLAUDE.md non-negotiable rules
 * and docs/05-security-governance/frontend-security.md.
 */

export const requiredString = (label: string) => z.string().trim().min(1, `${label} is required.`);

export interface FileValidationResult {
  valid: boolean;
  errors: string[];
}

/**
 * Client-side pre-check for uploads (extension/MIME/size) so users get fast
 * feedback. The server performs the authoritative scan, MIME sniffing, and
 * size enforcement — see docs/05-security-governance/frontend-security.md
 * "File upload validation is advisory only".
 */
export function validateFileForUpload(
  file: File,
  allowedMimeTypes: readonly string[] = ALLOWED_DOCUMENT_MIME_TYPES,
  maxSizeBytes: number = MAX_UPLOAD_SIZE_BYTES
): FileValidationResult {
  const errors: string[] = [];

  if (!allowedMimeTypes.includes(file.type)) {
    errors.push(`"${file.name}" has an unsupported file type (${file.type || "unknown"}).`);
  }
  if (file.size > maxSizeBytes) {
    errors.push(
      `"${file.name}" exceeds the maximum size of ${Math.round(maxSizeBytes / (1024 * 1024))} MB.`
    );
  }
  if (file.size === 0) {
    errors.push(`"${file.name}" is empty.`);
  }

  return { valid: errors.length === 0, errors };
}
