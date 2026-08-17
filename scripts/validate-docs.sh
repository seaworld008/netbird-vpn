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
host_network_peers = []
targeted_default_routes = []
for file in Path(".").rglob("*.md"):
    text = file.read_text(encoding="utf-8")
    if file.name == "18-kubernetes-targeted-public-egress.md":
        for block in re.findall(r"^```[^\n]*\n(.*?)^```", text, re.MULTILINE | re.DOTALL):
            if "0.0.0.0/0" in block or "::/0" in block:
                targeted_default_routes.append(str(file))
    for block in re.findall(r"^```ya?ml\s*\n(.*?)^```", text, re.MULTILINE | re.DOTALL):
        count += 1
        try:
            documents = list(yaml.safe_load_all(block))
        except yaml.YAMLError as error:
            print(f"YAML error in {file}: {error}", file=sys.stderr)
            raise SystemExit(1)
        for document in documents:
            if not isinstance(document, dict):
                continue
            services = document.get("services", {})
            if isinstance(services, dict):
                for name, service in services.items():
                    if not isinstance(service, dict):
                        continue
                    image = str(service.get("image", "")).lower()
                    is_netbird_peer = (
                        "routing" in str(name).lower()
                        or image.startswith("netbirdio/netbird:")
                        or "/netbird:" in image
                    )
                    if is_netbird_peer and service.get("network_mode") == "host":
                        host_network_peers.append(f"{file}: service {name}")

            kind = str(document.get("kind", ""))
            spec = document.get("spec", {})
            if kind == "Pod":
                pod_spec = spec
            elif kind in {"Deployment", "DaemonSet", "StatefulSet", "Job"}:
                pod_spec = spec.get("template", {}).get("spec", {}) if isinstance(spec, dict) else {}
            elif kind == "CronJob":
                pod_spec = (
                    spec.get("jobTemplate", {}).get("spec", {}).get("template", {}).get("spec", {})
                    if isinstance(spec, dict)
                    else {}
                )
            else:
                pod_spec = {}

            if not isinstance(pod_spec, dict):
                continue
            containers = pod_spec.get("containers", [])
            is_netbird_peer = any(
                isinstance(container, dict)
                and (
                    str(container.get("image", "")).lower().startswith("netbirdio/netbird:")
                    or "/netbird:" in str(container.get("image", "")).lower()
                )
                for container in containers
            )
            if is_netbird_peer and pod_spec.get("hostNetwork") is True:
                name = document.get("metadata", {}).get("name", "unnamed")
                host_network_peers.append(f"{file}: {kind} {name}")
if host_network_peers:
    print("NetBird Routing Peer production examples must not use host networking:", file=sys.stderr)
    print("\n".join(host_network_peers), file=sys.stderr)
    raise SystemExit(1)
if targeted_default_routes:
    print("Targeted egress examples must not configure a default route in code blocks:", file=sys.stderr)
    print("\n".join(sorted(set(targeted_default_routes))), file=sys.stderr)
    raise SystemExit(1)
print(f"parsed yaml blocks: {count}")
PY

echo "==> Checking stale version markers"
if rg -n "v0\\.71\\.4|v0\\.73\\.2|v0\\.76\\.1|v2\\.90\\.9|v0\\.76\\.3|v2\\.90\\.10|2026-06-05|2026-07-01|512899d82|0358be2|how-to/networks|use-cases/setup-site-to-site-access|use-cases/cloud/routing-peers-and-kubernetes" . --glob '!scripts/validate-docs.sh' --glob '!CHANGELOG.md' --glob '!docs/selfhosted/upstream-version-status.md' --glob '!docs/decisions/ADR-001-documentation-operating-model.md'; then
  echo "Found stale version markers or old official-doc paths" >&2
  exit 1
fi

echo "==> Checking production image tags"
if rg -n "image:\\s*[^#[:space:]]+:latest([[:space:]]|$)" . --glob '*.yml' --glob '*.yaml' --glob '*.md'; then
  echo "Found a production image using the latest tag" >&2
  exit 1
fi

echo "==> Checking Setup Key placeholders"
python - <<'PY'
from pathlib import Path
import re
import sys

files = [*Path(".").rglob("*.md"), *Path(".").rglob("*.yml"), *Path(".").rglob("*.yaml")]
bad = []

for file in files:
    if ".git" in file.parts:
        continue
    text = file.read_text(encoding="utf-8")
    for number, line in enumerate(text.splitlines(), 1):
        for token in re.findall(r"NBSETUP-[A-Za-z0-9._-]+", line):
            if not token.endswith("REPLACE-ME"):
                bad.append(f"{file}:{number}: possible real Setup Key: {token[:16]}...")

        match = re.search(r"NB_SETUP_KEY\s*:\s*[\"']?([^\"'#\s]+)", line)
        if not match:
            continue
        value = match.group(1)
        allowed = (
            value.startswith("${")
            or value.endswith("REPLACE-ME")
            or value in {"<key>", "YOUR_SETUP_KEY"}
        )
        if not allowed:
            bad.append(f"{file}:{number}: NB_SETUP_KEY must use Secret reference or placeholder")

if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
PY

echo "==> Checking patch whitespace"
git diff --check
git diff --cached --check

echo "Documentation validation passed."
