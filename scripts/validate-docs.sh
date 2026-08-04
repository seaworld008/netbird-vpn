#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Checking local Markdown links"
python - <<'PY'
from pathlib import Path
import re
import sys

for file in Path(".").rglob("*.md"):
    text = file.read_text(encoding="utf-8")
    for link in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        if re.match(r"^(https?:|mailto:|#)", link):
            continue
        path = link.split("#", 1)[0]
        if path and not (file.parent / path).resolve().exists():
            print(f"missing: {file} -> {link}", file=sys.stderr)
            raise SystemExit(1)
PY

echo "==> Checking Markdown code fences"
python - <<'PY'
from pathlib import Path
import re
import sys

bad = []
for file in Path(".").rglob("*.md"):
    stack = []
    for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
        match = re.match(r"^(`{3,}|~{3,})", line)
        if not match:
            continue
        mark = match.group(1)
        if not stack:
            stack.append((mark[0], len(mark), number))
        elif stack[-1][0] == mark[0] and len(mark) >= stack[-1][1]:
            stack.pop()
        else:
            stack.append((mark[0], len(mark), number))
    if stack:
        bad.append((file, stack))
if bad:
    for file, stack in bad:
        print(f"unclosed {file}: {stack}", file=sys.stderr)
    raise SystemExit(1)
PY

echo "==> Parsing YAML code blocks"
python - <<'PY'
from pathlib import Path
import re
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required: python -m pip install pyyaml", file=sys.stderr)
    raise SystemExit(1)

count = 0
for file in Path(".").rglob("*.md"):
    text = file.read_text(encoding="utf-8")
    for block in re.findall(r"^```ya?ml\s*\n(.*?)^```", text, re.MULTILINE | re.DOTALL):
        count += 1
        try:
            list(yaml.safe_load_all(block))
        except yaml.YAMLError as error:
            print(f"YAML error in {file}: {error}", file=sys.stderr)
            raise SystemExit(1)
print(f"parsed yaml blocks: {count}")
PY

echo "==> Checking stale version markers"
if rg -n "v0\\.71\\.4|v0\\.73\\.2|2026-06-05|2026-07-01|512899d82|0358be2|how-to/networks|use-cases/setup-site-to-site-access" . --glob '!scripts/validate-docs.sh' --glob '!docs/decisions/ADR-001-documentation-operating-model.md'; then
  echo "Found stale version markers or old official-doc paths" >&2
  exit 1
fi

echo "==> Checking production image tags"
if rg -n "image:\\s*[^#[:space:]]+:latest([[:space:]]|$)" . --glob '*.yml' --glob '*.yaml' --glob '*.md'; then
  echo "Found a production image using the latest tag" >&2
  exit 1
fi

echo "==> Checking patch whitespace"
git diff --check
git diff --cached --check

echo "Documentation validation passed."
