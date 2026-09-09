import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "@/App";
import { appConfig } from "@/app/config/appConfig";
import "@/styles/globals.css";

async function enableMockingIfNeeded(): Promise<void> {
  if (!appConfig.mswEnabled) return;
  const { worker } = await import("@/mocks/browser");
  await worker.start({ onUnhandledRequest: "bypass" });
}

enableMockingIfNeeded().then(() => {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <App />
    </StrictMode>
  );
});
