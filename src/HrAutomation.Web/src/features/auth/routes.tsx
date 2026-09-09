import { lazy } from "react";
import type { RouteObject } from "react-router-dom";
import { RouteErrorBoundary } from "@/components/common/RouteErrorBoundary";

const LoginPage = lazy(() => import("@/features/auth/pages/LoginPage"));
const LogoutPage = lazy(() => import("@/features/auth/pages/LogoutPage"));
const AccessDeniedPage = lazy(() => import("@/features/auth/pages/AccessDeniedPage"));

/** Public routes — no ProtectedRoute wrapper, reachable while unauthenticated. */
export const authRoutes: RouteObject[] = [
  { path: "/login", element: <LoginPage />, errorElement: <RouteErrorBoundary /> },
  { path: "/logout", element: <LogoutPage />, errorElement: <RouteErrorBoundary /> },
  { path: "/access-denied", element: <AccessDeniedPage />, errorElement: <RouteErrorBoundary /> },
];
