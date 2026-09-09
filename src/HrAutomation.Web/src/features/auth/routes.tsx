import { lazy } from "react";
import type { RouteObject } from "react-router-dom";

const LoginPage = lazy(() => import("@/features/auth/pages/LoginPage"));
const LogoutPage = lazy(() => import("@/features/auth/pages/LogoutPage"));
const AccessDeniedPage = lazy(() => import("@/features/auth/pages/AccessDeniedPage"));

/** Public routes — no ProtectedRoute wrapper, reachable while unauthenticated. */
export const authRoutes: RouteObject[] = [
  { path: "/login", element: <LoginPage /> },
  { path: "/logout", element: <LogoutPage /> },
  { path: "/access-denied", element: <AccessDeniedPage /> },
];
