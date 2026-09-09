import { useState } from "react";
import { Link } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { FileUpload } from "@/components/common/FileUpload";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useUploadCv } from "@/features/cv-bank/useCandidates";
import { ALLOWED_CV_MIME_TYPES } from "@/lib/constants";
import { userSafeMessage } from "@/api/client/apiError";

interface FileUploadResult {
  fileName: string;
  status: "uploading" | "completed" | "failed";
  candidateId: string | null;
  message: string | null;
}

/** HrAutomation.Api accepts one CV per request (CandidatesController.UploadCv binds a
 * single IFormFile) - each selected file is uploaded as its own real API call, and the
 * result shown per file is the server's actual response, not an invented "pending" state. */
export default function CvUploadPage() {
  const uploadMutation = useUploadCv();
  const [results, setResults] = useState<FileUploadResult[]>([]);

  async function handleFilesAccepted(files: File[]) {
    setResults(files.map((f) => ({ fileName: f.name, status: "uploading", candidateId: null, message: null })));

    for (const file of files) {
      try {
        const response = await uploadMutation.mutateAsync(file);
        setResults((prev) =>
          prev.map((r) =>
            r.fileName === file.name
              ? {
                  fileName: file.name,
                  status: response.action_status === "completed" ? "completed" : "failed",
                  candidateId: response.candidate_id,
                  message: response.explanation.summary,
                }
              : r
          )
        );
      } catch (error) {
        setResults((prev) =>
          prev.map((r) =>
            r.fileName === file.name
              ? { fileName: file.name, status: "failed", candidateId: null, message: userSafeMessage(error) }
              : r
          )
        );
      }
    }
  }

  return (
    <>
      <PageHeader
        title="Upload CVs"
        breadcrumbs={[{ label: "CV Bank", to: "/cv-bank" }, { label: "Upload" }]}
        description="Files are scanned and parsed server-side. Duplicate candidates are flagged, never silently merged."
      />

      <div className="max-w-xl space-y-4">
        <FileUpload
          label="CV files"
          hint="PDF or DOCX, up to 10 MB each — uploaded one at a time"
          allowedMimeTypes={ALLOWED_CV_MIME_TYPES}
          multiple
          disabled={results.some((r) => r.status === "uploading")}
          onFilesAccepted={handleFilesAccepted}
        />

        {results.length > 0 && (
          <div className="rounded-md border border-subtle p-4">
            <p className="mb-2 text-sm font-medium text-primary">
              Upload results
            </p>
            <ul className="space-y-2">
              {results.map((r) => (
                <li key={r.fileName} className="flex items-center justify-between gap-3 text-sm">
                  <div className="min-w-0">
                    <span className="block truncate text-secondary">
                      {r.fileName}
                    </span>
                    {r.message && (
                      <span className="block truncate text-xs text-tertiary">{r.message}</span>
                    )}
                  </div>
                  {r.status === "uploading" && (
                    <StatusBadge status="uploading" tone="info" label="Uploading…" />
                  )}
                  {r.status === "completed" && r.candidateId && (
                    <Link
                      to={`/candidates/${r.candidateId}`}
                      className="shrink-0 text-brand-600 underline"
                    >
                      <StatusBadge status="completed" tone="success" label="View candidate" />
                    </Link>
                  )}
                  {r.status === "failed" && (
                    <StatusBadge status="failed" tone="danger" label="Failed" />
                  )}
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </>
  );
}
