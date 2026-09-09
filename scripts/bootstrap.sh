#!/usr/bin/env bash
# Bootstrap a local development environment for the HR Automation Platform.
# Safe to re-run: every step is idempotent and non-destructive.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "== HR Automation Platform — local bootstrap =="

# --- 1. Environment file ---
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example — fill in local values before running services."
else
  echo ".env already exists — leaving it untouched."
fi

# --- 2. Toolchain checks (non-fatal warnings only) ---
check_tool() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    echo "OK   $name found: $("$name" --version 2>&1 | head -n1)"
  else
    echo "WARN $name not found on PATH — required for [$2]"
  fi
}

check_tool dotnet "backend build/test (see global.json for pinned SDK version)"
check_tool node "frontend build/test (src/frontend, once bootstrapped)"
check_tool python3 "agent service and config validation scripts"
check_tool docker "local dependencies via docker-compose.yml"

# --- 3. Restore backend dependencies if the solution exists ---
if [ -f HrAutomation.slnx ]; then
  echo "Restoring .NET solution..."
  dotnet restore HrAutomation.slnx
fi

# --- 4. Start local dependencies ---
if command -v docker >/dev/null 2>&1; then
  echo "Starting local dependencies (Postgres, Redis, OTel collector)..."
  docker compose up -d
else
  echo "WARN Docker not found — skipping local dependency startup. Run 'make up' once installed."
fi

echo ""
echo "Bootstrap complete. Next steps:"
echo "  1. Fill in .env with your local values (never commit it)."
echo "  2. Review NEXT_STEPS.md for the current implementation phase."
echo "  3. Run './scripts/validate-config.sh' to check config/ against its schemas."
