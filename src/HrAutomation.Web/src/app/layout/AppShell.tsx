import { useState } from "react";
import { Outlet } from "react-router-dom";
import { Header } from "@/app/layout/Header";
import { Sidebar } from "@/app/layout/Sidebar";
import { PageContainer } from "@/app/layout/PageContainer";
import { DevIntegrationStatus } from "@/components/common/DevIntegrationStatus";

/** Authenticated app frame: header + sidebar + routed page content. */
export function AppShell() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  // Session-only (not persisted to browser storage — see the reviewed,
  // file-scoped exemption on ThemeProvider.tsx; extending browser-storage
  // access elsewhere requires the same deliberate security review, not a
  // silent second usage). Resets to expanded on reload, which is an
  // acceptable tradeoff for a purely cosmetic preference.
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div className="min-h-screen bg-surface-sunken">
      <Header
        onToggleSidebar={() => setSidebarOpen((v) => !v)}
        sidebarCollapsed={collapsed}
        onToggleCollapsed={() => setCollapsed((v) => !v)}
      />
      <DevIntegrationStatus />
      <div className="flex">
        <Sidebar open={sidebarOpen} collapsed={collapsed} onNavigate={() => setSidebarOpen(false)} />
        {sidebarOpen && (
          <button
            type="button"
            aria-label="Close navigation menu"
            className="fixed inset-0 z-20 bg-neutral-900/40 lg:hidden"
            onClick={() => setSidebarOpen(false)}
          />
        )}
        <div className="min-w-0 flex-1">
          <PageContainer>
            <Outlet />
          </PageContainer>
        </div>
      </div>
    </div>
  );
}
