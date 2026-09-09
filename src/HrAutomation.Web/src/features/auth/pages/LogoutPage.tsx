import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";

export default function LogoutPage() {
  const { logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    logout().finally(() => navigate("/login", { replace: true }));
    // eslint-disable-next-line react-hooks/exhaustive-deps -- run once on mount
  }, []);

  return (
    <div className="flex min-h-screen items-center justify-center">
      <p className="text-sm text-secondary">Signing out…</p>
    </div>
  );
}
