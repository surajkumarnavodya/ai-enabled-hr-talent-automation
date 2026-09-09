import { setupServer } from "msw/node";
import { handlers } from "@/mocks/handlers";

/** Node-side MSW server for Vitest — separate from mocks/browser.ts (browser worker). */
export const server = setupServer(...handlers);
