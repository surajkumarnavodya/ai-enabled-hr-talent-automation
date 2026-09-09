import { lazy, Suspense } from "react";
import { createBrowserRouter, type RouteObject } from "react-router-dom";
import { AppShell } from "@/app/layout/AppShell";
import { ProtectedRoute } from "@/app/router/ProtectedRoute";
import { PermissionRoute } from "@/app/router/PermissionRoute";
import { LoadingState } from "@/components/common/LoadingState";
import { authRoutes } from "@/features/auth/routes";

function lazyPage(loader: Parameters<typeof lazy>[0]) {
  const Component = lazy(loader);
  return (
    <Suspense
      fallback={
        <div className="p-6">
          <LoadingState label="Loading page" />
        </div>
      }
    >
      <Component />
    </Suspense>
  );
}

// Candidate-facing, token-authorized pages — never wrapped in ProtectedRoute
// (no internal session exists for an external candidate). See
// features/green-form/GreenFormPage.tsx.
const publicRoutes: RouteObject[] = [
  {
    path: "/green-form/:token",
    element: lazyPage(() => import("@/features/green-form/GreenFormPage")),
  },
  {
    path: "/green-form/submission/:submissionId",
    element: lazyPage(() => import("@/features/green-form/GreenFormSubmissionStatusPage")),
  },
];

const protectedRoutes: RouteObject = {
  element: <ProtectedRoute />,
  children: [
    {
      element: <AppShell />,
      children: [
        { path: "/", element: lazyPage(() => import("@/features/dashboard/DashboardPage")) },
        {
          path: "/dashboard",
          element: lazyPage(() => import("@/features/dashboard/DashboardPage")),
        },

        // CV Bank
        { path: "/cv-bank", element: lazyPage(() => import("@/features/cv-bank/CvBankListPage")) },
        {
          path: "/cv-bank/upload",
          element: lazyPage(() => import("@/features/cv-bank/CvUploadPage")),
        },
        {
          path: "/candidates/:candidateId",
          element: lazyPage(() => import("@/features/candidates/CandidateProfilePage")),
        },

        // TANs
        { path: "/tans", element: lazyPage(() => import("@/features/tans/TanListPage")) },
        { path: "/tans/new", element: lazyPage(() => import("@/features/tans/TanFormPage")) },
        { path: "/tans/:tanId", element: lazyPage(() => import("@/features/tans/TanDetailPage")) },
        {
          path: "/tans/:tanId/edit",
          element: lazyPage(() => import("@/features/tans/TanFormPage")),
        },
        {
          path: "/tans/:tanId/matches",
          element: lazyPage(() => import("@/features/candidate-matching/CandidateMatchesPage")),
        },

        // Interviews
        {
          path: "/interviews",
          element: lazyPage(() => import("@/features/interviews/InterviewsListPage")),
        },
        {
          path: "/interviews/:interviewId",
          element: lazyPage(() => import("@/features/interviews/InterviewDetailPage")),
        },
        {
          path: "/interviews/:interviewId/feedback",
          element: lazyPage(() => import("@/features/interviews/InterviewFeedbackPage")),
        },

        // Offers
        { path: "/offers", element: lazyPage(() => import("@/features/offers/OffersListPage")) },
        {
          path: "/offers/new/:applicationId",
          element: lazyPage(() => import("@/features/offers/OfferNewPage")),
        },
        {
          path: "/offers/:offerId",
          element: lazyPage(() => import("@/features/offers/OfferDetailPage")),
        },
        {
          path: "/offers/:offerId/approval",
          element: lazyPage(() => import("@/features/offers/OfferApprovalPage")),
        },

        // Verification & discrepancies
        {
          path: "/verification",
          element: lazyPage(() => import("@/features/verification/VerificationQueuePage")),
        },
        {
          path: "/verification/:applicationId",
          element: lazyPage(() => import("@/features/verification/VerificationDetailPage")),
        },
        {
          path: "/discrepancies",
          element: lazyPage(() => import("@/features/discrepancies/DiscrepancyListPage")),
        },
        {
          path: "/discrepancies/:discrepancyId",
          element: lazyPage(() => import("@/features/discrepancies/DiscrepancyDetailPage")),
        },

        // Employee conversion
        {
          path: "/employee-conversion",
          element: lazyPage(
            () => import("@/features/employee-conversion/EmployeeConversionListPage")
          ),
        },
        {
          path: "/employee-conversion/:applicationId",
          element: lazyPage(
            () => import("@/features/employee-conversion/EmployeeConversionDetailPage")
          ),
        },

        // Approvals & audit
        {
          path: "/approvals",
          element: <PermissionRoute />,
          children: [
            {
              index: true,
              element: lazyPage(() => import("@/features/approvals/ApprovalsQueuePage")),
            },
          ],
        },
        {
          path: "/audit",
          element: <PermissionRoute permission="audit.read" />,
          children: [
            { index: true, element: lazyPage(() => import("@/features/audit/AuditPage")) },
          ],
        },

        // Administration — permission-gated section
        {
          path: "/admin",
          element: <PermissionRoute permission="admin.access" />,
          children: [
            {
              path: "/admin",
              element: lazyPage(() => import("@/features/administration/AdminPage")),
              children: [
                {
                  path: "users",
                  element: lazyPage(() => import("@/features/administration/AdminUsersListPage")),
                },
                {
                  path: "users/:userId",
                  element: lazyPage(() => import("@/features/administration/AdminUserDetailPage")),
                },
                {
                  path: "configuration",
                  element: lazyPage(
                    () => import("@/features/administration/AdminConfigurationPage")
                  ),
                },
                {
                  path: "roles",
                  element: lazyPage(() => import("@/features/administration/AdminRolesPage")),
                },
                {
                  path: "feature-flags",
                  element: lazyPage(
                    () => import("@/features/administration/AdminFeatureFlagsPage")
                  ),
                },
                {
                  path: "integrations",
                  element: lazyPage(
                    () => import("@/features/administration/AdminIntegrationsPage")
                  ),
                },
              ],
            },
          ],
        },
      ],
    },
  ],
};

/**
 * Exported separately from the created router so tests can build a
 * `createMemoryRouter(routeObjects, ...)` instead — `createBrowserRouter`
 * performs real History/fetch API work that is unreliable under jsdom. See
 * app/providers/RouterProvider.tsx and tests/components/App.test.tsx.
 */
export const routeObjects: RouteObject[] = [...authRoutes, ...publicRoutes, protectedRoutes];

export const router = createBrowserRouter(routeObjects);

/** Shared type for both the real browser router and test-only memory routers. */
export type AppRouter = ReturnType<typeof createBrowserRouter>;
