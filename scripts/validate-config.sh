#!/usr/bin/env bash
# Validate config/ YAML files against their JSON Schemas in config/schemas/.
# Best-effort: environment/tenant files are partial overlays, so a schema
# mismatch there may reflect an incomplete override rather than a real error —
# read the reported path before assuming a failure. Requires python3 with
# PyYAML and jsonschema installed; if unavailable, this script reports that
# clearly instead of silently skipping validation.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR python3 not found — cannot run config validation. Install Python 3 and 'pip install pyyaml jsonschema'."
  exit 1
fi

python3 - <<'PYEOF'
import sys, glob, os

try:
    import yaml
except ImportError:
    print("ERROR PyYAML not installed. Run: pip install pyyaml jsonschema")
    sys.exit(1)

try:
    import jsonschema
    HAVE_JSONSCHEMA = True
except ImportError:
    HAVE_JSONSCHEMA = False
    print("WARN jsonschema not installed - will only check YAML syntax, not schema conformance.")
    print("     Run: pip install jsonschema")

import json

# Best-effort filename -> schema mapping. Extend as new config files are added.
SCHEMA_MAP = {
    "config/defaults/platform.default.yaml": "config/schemas/platform-config.schema.json",
    "config/defaults/workflow.default.yaml": "config/schemas/workflow-config.schema.json",
    "config/defaults/rag.default.yaml": "config/schemas/rag-config.schema.json",
    "config/defaults/model-routing.default.yaml": "config/schemas/model-routing.schema.json",
    "config/tenants/sample-tenant.yaml": "config/schemas/tenant-config.schema.json",
}

exit_code = 0
all_yaml = sorted(glob.glob("config/**/*.yaml", recursive=True))

for path in all_yaml:
    posix_path = path.replace(os.sep, "/")
    try:
        with open(path, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh)
        print(f"OK   (syntax) {posix_path}")
    except Exception as e:
        print(f"FAIL (syntax) {posix_path}: {e}")
        exit_code = 1
        continue

    schema_path = SCHEMA_MAP.get(posix_path)
    if not schema_path:
        print(f"SKIP (no schema mapping - likely a partial environment/tenant overlay) {posix_path}")
        continue
    if not HAVE_JSONSCHEMA:
        print(f"SKIP (jsonschema not installed) {posix_path} -- would check against {schema_path}")
        continue

    with open(schema_path, encoding="utf-8") as fh:
        schema = json.load(fh)
    try:
        jsonschema.validate(instance=doc, schema=schema)
        print(f"OK   (schema) {posix_path} against {schema_path}")
    except jsonschema.ValidationError as e:
        print(f"FAIL (schema) {posix_path} against {schema_path}: {e.message}")
        exit_code = 1

sys.exit(exit_code)
PYEOF
