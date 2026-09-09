#!/usr/bin/env pwsh
# Bootstrap a local development environment for the HR Automation Platform.
# Safe to re-run: every step is idempotent and non-destructive.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "== HR Automation Platform — local bootstrap =="

# --- 1. Environment file ---
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example — fill in local values before running services."
} else {
    Write-Host ".env already exists — leaving it untouched."
}

# --- 2. Toolchain checks (non-fatal warnings only) ---
function Test-Tool {
    param([string]$Name, [string]$Purpose)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "OK   $Name found at $($cmd.Source)"
    } else {
        Write-Host "WARN $Name not found on PATH — required for [$Purpose]"
    }
}

Test-Tool -Name "dotnet" -Purpose "backend build/test (see global.json for pinned SDK version)"
Test-Tool -Name "node" -Purpose "frontend build/test (src/frontend, once bootstrapped)"
Test-Tool -Name "python" -Purpose "agent service and config validation scripts"
Test-Tool -Name "docker" -Purpose "local dependencies via docker-compose.yml"

# --- 3. Restore backend dependencies if the solution exists ---
if (Test-Path "HrAutomation.slnx") {
    Write-Host "Restoring .NET solution..."
    dotnet restore HrAutomation.slnx
}

# --- 4. Start local dependencies ---
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "Starting local dependencies (Postgres, Redis, OTel collector)..."
    docker compose up -d
} else {
    Write-Host "WARN Docker not found — skipping local dependency startup. Run 'make up' once installed."
}

Write-Host ""
Write-Host "Bootstrap complete. Next steps:"
Write-Host "  1. Fill in .env with your local values (never commit it)."
Write-Host "  2. Review NEXT_STEPS.md for the current implementation phase."
Write-Host "  3. Run './scripts/validate-config.ps1' to check config/ against its schemas."
