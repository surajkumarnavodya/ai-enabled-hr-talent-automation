import { useId, useRef, useState, type DragEvent } from "react";
import { UploadCloud, FileWarning } from "lucide-react";
import { validateFileForUpload } from "@/lib/validation";
import { ALLOWED_DOCUMENT_MIME_TYPES, MAX_UPLOAD_SIZE_BYTES } from "@/lib/constants";
import { cn } from "@/lib/cn";

export interface FileUploadProps {
  label: string;
  hint?: string;
  allowedMimeTypes?: readonly string[];
  maxSizeBytes?: number;
  multiple?: boolean;
  disabled?: boolean;
  onFilesAccepted: (files: File[]) => void;
}

/**
 * Client-side validation (extension/MIME/size) is a UX convenience only.
 * HrAutomation.Api performs the authoritative malware scan, content-type
 * verification, and size enforcement before a file is ever usable — see
 * docs/05-security-governance/frontend-security.md "File upload validation
 * is advisory only".
 */
export function FileUpload({
  label,
  hint,
  allowedMimeTypes = ALLOWED_DOCUMENT_MIME_TYPES,
  maxSizeBytes = MAX_UPLOAD_SIZE_BYTES,
  multiple = false,
  disabled,
  onFilesAccepted,
}: FileUploadProps) {
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [errors, setErrors] = useState<string[]>([]);
  const [isDragging, setIsDragging] = useState(false);

  function processFiles(fileList: FileList | null) {
    if (!fileList || fileList.length === 0) return;
    const files = Array.from(fileList);
    const allErrors: string[] = [];
    const accepted: File[] = [];

    for (const file of files) {
      const result = validateFileForUpload(file, allowedMimeTypes, maxSizeBytes);
      if (result.valid) {
        accepted.push(file);
      } else {
        allErrors.push(...result.errors);
      }
    }

    setErrors(allErrors);
    if (accepted.length > 0) onFilesAccepted(accepted);
  }

  function handleDrop(e: DragEvent<HTMLDivElement>) {
    e.preventDefault();
    setIsDragging(false);
    if (disabled) return;
    processFiles(e.dataTransfer.files);
  }

  return (
    <div>
      <label
        htmlFor={inputId}
        className="mb-1 block text-sm font-medium text-secondary"
      >
        {label}
      </label>
      <div
        onDragOver={(e) => {
          e.preventDefault();
          if (!disabled) setIsDragging(true);
        }}
        onDragLeave={() => setIsDragging(false)}
        onDrop={handleDrop}
        className={cn(
          "flex flex-col items-center justify-center rounded-lg border-2 border-dashed p-6 text-center transition-colors",
          isDragging
            ? "border-brand-500 bg-brand-50 dark:bg-brand-950/40"
            : "border-strong",
          disabled && "cursor-not-allowed opacity-60"
        )}
      >
        <UploadCloud className="mb-2 h-6 w-6 text-tertiary" aria-hidden="true" />
        <p className="text-sm text-secondary">
          Drag and drop, or{" "}
          <button
            type="button"
            className="font-medium text-brand-600 underline underline-offset-2"
            onClick={() => inputRef.current?.click()}
            disabled={disabled}
          >
            browse
          </button>
        </p>
        {hint && <p className="mt-1 text-xs text-tertiary">{hint}</p>}
        <input
          ref={inputRef}
          id={inputId}
          type="file"
          className="sr-only"
          multiple={multiple}
          disabled={disabled}
          accept={allowedMimeTypes.join(",")}
          onChange={(e) => processFiles(e.target.files)}
        />
      </div>
      {errors.length > 0 && (
        <ul role="alert" className="mt-2 space-y-1">
          {errors.map((err) => (
            <li key={err} className="flex items-center gap-1.5 text-xs text-status-danger">
              <FileWarning className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
              {err}
            </li>
          ))}
        </ul>
      )}
      <p className="mt-2 text-xs text-tertiary">
        Server-side malware scanning and validation are mandatory and are performed after upload.
      </p>
    </div>
  );
}
