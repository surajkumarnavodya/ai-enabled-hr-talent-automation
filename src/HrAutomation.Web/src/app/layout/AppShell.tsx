import { useState } from "react";
import { Outlet } from "react-router-dom";
import { Header } from "@/app/layout/Header";
import { Sidebar } from "@/app/layout/Sidebar";
import { PageContainer } from "@/app/layout/PageContainer";
import { DevIntegrationStatus } from "@/components/common/DevIntegrationStatus";

/** Authenticated app frame: header + sidebar + routed page content. */
export function AppShell() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950">
      <Header onToggleSidebar={() => setSidebarOpen((v) => !v)} />
      <DevIntegrationStatus />
      <div className="flex">
        <Sidebar open={sidebarOpen} onNavigate={() => setSidebarOpen(false)} />
        {sidebarOpen && (
          <button
            type="button"
            aria-label="Close navigation menu"
            className="fixed inset-0 z-20 bg-slate-900/40 lg:hidden"
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
