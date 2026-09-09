import { setupWorker } from "msw/browser";
import { handlers } from "@/mocks/handlers";

/**
 * Local-development mock server. Started conditionally from main.tsx when
 * VITE_ENABLE_MSW=true (default). Requires `public/mockServiceWorker.js`,
 * generated via `npx msw init public/ --save` (see README.md "Mock
 * development mode").
 */
export const worker = setupWorker(...handlers);
