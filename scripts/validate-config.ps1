#!/usr/bin/env pwsh
# Validate config/ YAML files against their JSON Schemas in config/schemas/.
# Best-effort: environment/tenant files are partial overlays, so a schema
# mismatch there may reflect an incomplete override rather than a real error.
# Delegates to the same Python validation logic as validate-config.sh so the
# two never drift apart.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}

if (-not $python) {
    Write-Host "ERROR python not found — cannot run config validation. Install Python 3 and 'pip install pyyaml jsonschema'."
    exit 1
}

$bashScript = Join-Path $repoRoot "scripts/validate-config.sh"
if (Get-Command bash -ErrorAction SilentlyContinue) {
    bash $bashScript
    exit $LASTEXITCODE
} else {
    Write-Host "WARN bash not found — re-implement inline Python call here or run scripts/validate-config.sh under WSL/Git Bash."
    exit 1
}
