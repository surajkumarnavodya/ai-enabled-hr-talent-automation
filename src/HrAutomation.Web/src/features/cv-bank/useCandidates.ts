import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { Candidate } from "@/types/workflow";
import type { AgentActionResponse, CursorPage } from "@/types/api";

export function useCandidateList(searchTerm: string, cursor?: string) {
  return useQuery({
    queryKey: [QUERY_KEYS.cvBank, "list", searchTerm, cursor ?? null],
    queryFn: () =>
      http.get<CursorPage<Candidate>>("/v1/candidates", {
        params: { cursor, limit: 20 },
      }),
  });
}

export function useCandidate(candidateId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.candidates, candidateId],
    queryFn: () => http.get<Candidate>(`/v1/candidates/${candidateId}`),
    enabled: Boolean(candidateId),
  });
}

// NOTE (API missing): there is no `GET /v1/candidates/{id}/cvs` endpoint on
// HrAutomation.Api - CV documents aren't separately listable per candidate yet.
// Intentionally not exporting a hook for this; CandidateProfilePage shows a
// truthful "not available" state instead of calling a nonexistent endpoint.

/** Uploads exactly one CV - matches HrAutomation.Api's
 * `POST /api/v1/candidates/cvs` (CandidatesController.UploadCv), which binds a
 * single `IFormFile file`, not a list. Multi-file upload isn't supported server-side. */
export function useUploadCv() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (file: File) => {
      const formData = new FormData();
      formData.append("file", file);
      return http.post<AgentActionResponse>("/v1/candidates/cvs", formData, {
        headers: { "Content-Type": "multipart/form-data" },
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.cvBank] });
    },
  });
}
