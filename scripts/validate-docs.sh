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

echo "==> Validating Agent Skills"
python - <<'PY'
from pathlib import Path
import re
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required: python -m pip install pyyaml", file=sys.stderr)
    raise SystemExit(1)

skill_files = sorted(
    [*Path(".agents/skills").glob("*/SKILL.md"), *Path(".claude/skills").glob("*/SKILL.md")]
)
if not skill_files:
    print("No repository Agent Skills found", file=sys.stderr)
    raise SystemExit(1)

metadata = {}
for file in skill_files:
    text = file.read_text(encoding="utf-8")
    match = re.match(r"\A---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not match:
        print(f"Missing YAML frontmatter: {file}", file=sys.stderr)
        raise SystemExit(1)
    try:
        frontmatter = yaml.safe_load(match.group(1))
    except yaml.YAMLError as error:
        print(f"Invalid Skill frontmatter in {file}: {error}", file=sys.stderr)
        raise SystemExit(1)
    if not isinstance(frontmatter, dict):
        print(f"Skill frontmatter must be a mapping: {file}", file=sys.stderr)
        raise SystemExit(1)

    name = frontmatter.get("name")
    description = frontmatter.get("description")
    if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9-]{1,64}", name):
        print(f"Invalid Skill name in {file}: {name!r}", file=sys.stderr)
        raise SystemExit(1)
    if file.parent.name != name:
        print(f"Skill folder must match name: {file} -> {name}", file=sys.stderr)
        raise SystemExit(1)
    if not isinstance(description, str) or not description.strip() or len(description) > 1024:
        print(f"Invalid Skill description in {file}", file=sys.stderr)
        raise SystemExit(1)
    if re.search(r"\[TODO(?::|\])", text):
        print(f"Unfinished Skill scaffold: {file}", file=sys.stderr)
        raise SystemExit(1)
    metadata[str(file)] = frontmatter

canonical = Path(".agents/skills/netbird-network-operator/SKILL.md")
claude_entry = Path(".claude/skills/netbird-network-operator/SKILL.md")
if not canonical.exists() or not claude_entry.exists():
    print("Missing NetBird canonical Skill or Claude compatibility entry", file=sys.stderr)
    raise SystemExit(1)
if metadata[str(canonical)]["name"] != metadata[str(claude_entry)]["name"]:
    print("Canonical and Claude Skill names differ", file=sys.stderr)
    raise SystemExit(1)
if "../../../.agents/skills/netbird-network-operator/SKILL.md" not in claude_entry.read_text(encoding="utf-8"):
    print("Claude entry must load the canonical NetBird Skill", file=sys.stderr)
    raise SystemExit(1)

openai_file = canonical.parent / "agents/openai.yaml"
try:
    openai = yaml.safe_load(openai_file.read_text(encoding="utf-8"))
except (OSError, UnicodeError, yaml.YAMLError) as error:
    print(f"Invalid OpenAI Skill metadata: {error}", file=sys.stderr)
    raise SystemExit(1)
interface = openai.get("interface", {}) if isinstance(openai, dict) else {}
for key in ("display_name", "short_description", "default_prompt"):
    if not isinstance(interface.get(key), str) or not interface[key].strip():
        print(f"Missing interface.{key} in {openai_file}", file=sys.stderr)
        raise SystemExit(1)
if not 25 <= len(interface["short_description"]) <= 64:
    print("OpenAI short_description must be 25-64 characters", file=sys.stderr)
    raise SystemExit(1)
if "$netbird-network-operator" not in interface["default_prompt"]:
    print("OpenAI default_prompt must mention $netbird-network-operator", file=sys.stderr)
    raise SystemExit(1)

print(f"validated agent skills: {len(skill_files)}")
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

echo "==> Parsing Bash code blocks"
python - <<'PY'
from pathlib import Path
import re
import subprocess
import sys

count = 0
bad = []
pattern = re.compile(r"^```(?:bash|sh)\s*\n(.*?)^```\s*$", re.MULTILINE | re.DOTALL)

for file in Path(".").rglob("*.md"):
    text = file.read_text(encoding="utf-8")
    for match in pattern.finditer(text):
        count += 1
        line = text.count("\n", 0, match.start()) + 1
        block = match.group(1)
        angle = re.search(r"<[^>\n]+>", block)
        if angle:
            block_line = line + block.count("\n", 0, angle.start()) + 1
            bad.append(
                f"{file}:{block_line}: Bash block uses an unsafe angle-bracket placeholder"
            )
            continue
        result = subprocess.run(
            ["bash", "-n"],
            input=block,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode:
            bad.append(f"{file}:{line}: {result.stderr.strip()}")

if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
print(f"parsed bash/sh blocks: {count}")
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
python - <<'PY'
from pathlib import Path
import re
import sys

stale = re.compile(
    r"v0\.71\.4|v0\.73\.2|v2\.90\.9|v0\.76\.3|v2\.90\.10|v0\.77\.0|"
    r"netbirdio/(?:netbird|netbird-server|management|signal|relay):0\.77\.0|"
    r"netbird_installer_0\.77\.0|2026-06-05|2026-07-01|512899d82|0358be2|"
    r"4e5b63249032|how-to/networks|how-to/resolve-overlapping-routes|"
    r"use-cases/setup-site-to-site-access|use-cases/cloud/routing-peers-and-kubernetes|"
    r"manage/integrations/kubernetes|manage/network-routes/use-cases/exit-nodes|"
    r"manage/networks/accessing-restricted-domain-resources|"
    r"manage/networks/use-cases/site-to-site|"
    r"manage/peers/access-infrastructure/setup-keys-add-servers-to-network|"
    r"selfhosted/configuration-files|selfhosted/reverse-proxy"
)
excluded = {
    Path("scripts/validate-docs.sh"),
    Path("CHANGELOG.md"),
    Path("docs/selfhosted/upstream-version-status.md"),
    Path("docs/operations/legacy-external-idp-upgrade.md"),
    Path("docs/decisions/ADR-001-documentation-operating-model.md"),
}
bad = []

for file in Path(".").rglob("*"):
    if not file.is_file() or ".git" in file.parts:
        continue
    relative = Path(*file.parts[1:]) if file.parts and file.parts[0] == "." else file
    if relative in excluded:
        continue
    try:
        lines = file.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        continue
    for number, line in enumerate(lines, 1):
        if stale.search(line):
            bad.append(f"{file}:{number}: stale version marker or official-doc path")

required_baselines = [
    Path("README.md"),
    Path("部署说明.md"),
    Path("docs/selfhosted/quickstart-modern.md"),
    Path("docs/selfhosted/upstream-version-status.md"),
    Path("docs/selfhosted/docker-compose-config-cheatsheet.md"),
]
for file in required_baselines:
    if not re.search(r"v?0\.77\.1", file.read_text(encoding="utf-8")):
        bad.append(f"{file}: current NetBird v0.77.1 baseline missing")

status_file = Path("docs/selfhosted/upstream-version-status.md")
status_text = status_file.read_text(encoding="utf-8")
required_status_lines = [
    "| NetBird Server / Client | `v0.77.1` | 2026-08-21 | GitHub `releases/latest`，`prerelease=false` |",
    "| NetBird Dashboard | `v2.91.1` | 2026-08-14 | Dashboard GitHub `releases/latest`，`prerelease=false` |",
    "NetBird `v0.77.1` peeled commit：`79a06720b684768b421f0a54f3bb14f22704994f`",
]
for expected in required_status_lines:
    if expected not in status_text:
        bad.append(f"{status_file}: current stable status evidence is missing: {expected}")

if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
PY

echo "==> Checking production image tags"
python - <<'PY'
from pathlib import Path
import re
import sys

generic_latest = re.compile(r"image:\s*[^#\s]+:latest(?:\s|$)", re.IGNORECASE)
inline_drift = re.compile(
    r"netbirdio/(?:dashboard|netbird-server|netbird|management|signal|relay|reverse-proxy):"
    r"(?:latest|main)\b|\$\{[^}]*:-(?:latest|main)\}",
    re.IGNORECASE,
)
bad = []

for file in [*Path(".").rglob("*.md"), *Path(".").rglob("*.yml"), *Path(".").rglob("*.yaml")]:
    if ".git" in file.parts:
        continue
    for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
        if generic_latest.search(line):
            bad.append(f"{file}:{number}: production image uses latest")

for root in [Path("README.md"), Path("部署说明.md"), Path("docs"), Path(".agents")]:
    files = [root] if root.is_file() else [path for path in root.rglob("*") if path.is_file()]
    for file in files:
        try:
            lines = file.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            continue
        for number, line in enumerate(lines, 1):
            if inline_drift.search(line):
                bad.append(f"{file}:{number}: drifting NetBird image reference")

if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
PY

python - <<'PY'
from pathlib import Path
import re
import sys

components = {
    "dashboard",
    "management",
    "netbird",
    "netbird-server",
    "relay",
    "reverse-proxy",
    "signal",
}
files = [*Path(".").rglob("*.md"), *Path(".").rglob("*.yml"), *Path(".").rglob("*.yaml")]
bad = []

def image_issue(value):
    basename = value.rsplit("/", 1)[-1]
    component = re.split(r"[:@]", basename, maxsplit=1)[0]
    if component not in components:
        return None
    if re.search(r"\$\{[^}]*:-(?:latest|main)\}", value, flags=re.IGNORECASE):
        return "defaults to a drifting tag"
    if re.search(r":(?:latest|main)$", basename, flags=re.IGNORECASE):
        return "uses a drifting tag"
    if ":" not in basename and "@sha256:" not in basename:
        return "omits a fixed tag or digest"
    return None

image_self_tests = {
    "netbirdio/netbird": "omits a fixed tag or digest",
    "registry.example.com/team/netbird-server": "omits a fixed tag or digest",
    "netbirdio/reverse-proxy:${NETBIRD_TAG:-latest}": "defaults to a drifting tag",
    "netbirdio/netbird:${NETBIRD_TAG:-main}": "defaults to a drifting tag",
    "netbirdio/netbird:main": "uses a drifting tag",
    "netbirdio/netbird:0.77.1": None,
    "netbirdio/netbird@sha256:" + "0" * 64: None,
}
for sample, expected in image_self_tests.items():
    actual = image_issue(sample)
    if actual != expected:
        raise SystemExit(
            f"internal image validation self-test failed for {sample}: {actual!r}"
        )

for file in files:
    if ".git" in file.parts:
        continue
    for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
        match = re.match(r"^\s*image:\s*(.+?)\s*$", line)
        if not match:
            continue
        value = match.group(1).split(" #", 1)[0].strip().strip("\"'")
        issue = image_issue(value)
        if issue:
            bad.append(f"{file}:{number}: NetBird image {issue}: {value}")

if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
PY

echo "==> Checking Setup Key placeholders"
python - <<'PY'
from pathlib import Path
import re
import sys

files = [*Path(".").rglob("*.md"), *Path(".").rglob("*.yml"), *Path(".").rglob("*.yaml")]
bad = []

quoted_or_token = r'''(?:"[^"]*"|'[^']*'|\{\{[^}]+\}\}|[^\s`\\]+)'''
context_patterns = [
    re.compile(rf"--setup-key(?!-file)(?:\s*=\s*|\s+)({quoted_or_token})", re.IGNORECASE),
    re.compile(
        rf"(?<!\^)\b[A-Z0-9_]*SETUP_KEY\s*(?::|=)\s*({quoted_or_token})",
        re.IGNORECASE,
    ),
    re.compile(rf"[\"']setup_key[\"']\s*:\s*({quoted_or_token})", re.IGNORECASE),
    re.compile(rf"^\s*(?:[-*]\s+)?Setup Key[：:]\s*({quoted_or_token})", re.IGNORECASE),
]

def allowed_context_value(raw):
    value = raw.strip().rstrip(",")
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1].strip()
    return (
        not value
        or value in {"...", "<key>", "YOUR_SETUP_KEY"}
        or "REPLACE-ME" in value
        or value.startswith(("$", "${", "{{", "<"))
        or value.startswith(("var.", "vault_", "lookup(", "!vault"))
        or "secretKeyRef" in value
        or "valueFrom" in value
    )

def rejected_contexts(line):
    return [
        match.group(1)
        for pattern in context_patterns
        for match in pattern.finditer(line)
        if not allowed_context_value(match.group(1))
    ]

blocked_self_tests = [
    "netbird up --setup-key 11111111-2222-4333-8444-555555555555",
    "NB_SETUP_KEY=11111111-2222-4333-8444-555555555555",
    'netbird_setup_key = "11111111-2222-4333-8444-555555555555"',
    'setup_key: "11111111-2222-4333-8444-555555555555"',
    '"setup_key": "11111111-2222-4333-8444-555555555555"',
    "Setup Key：11111111-2222-4333-8444-555555555555",
]
allowed_self_tests = [
    'netbird up --setup-key "$NETBIRD_SETUP_KEY"',
    "NB_SETUP_KEY=${NB_SETUP_KEY:-}",
    "netbird up --setup-key NBSETUP-EXAMPLE-REPLACE-ME",
    'netbird up --setup-key-file "$SETUP_KEY_FILE"',
]
if any(not rejected_contexts(sample) for sample in blocked_self_tests):
    raise SystemExit("internal Setup Key validation failed to reject a literal credential")
if any(rejected_contexts(sample) for sample in allowed_self_tests):
    raise SystemExit("internal Setup Key validation rejected an approved placeholder")

for file in files:
    if ".git" in file.parts:
        continue
    text = file.read_text(encoding="utf-8")
    for number, line in enumerate(text.splitlines(), 1):
        for token in re.findall(r"NBSETUP-[A-Za-z0-9._-]+", line):
            if not token.endswith("REPLACE-ME"):
                bad.append(f"{file}:{number}: possible real Setup Key: {token[:16]}...")

        if rejected_contexts(line):
            bad.append(
                f"{file}:{number}: Setup Key context must use a variable, "
                "Secret reference, or REPLACE-ME placeholder"
            )

if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
PY

echo "==> Checking patch whitespace"
git diff --check
git diff --cached --check

echo "Documentation validation passed."
