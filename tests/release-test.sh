#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
plugin_root="$project_root/plugins/code-health"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/code-health-release-test.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [[ -f $1 ]] || fail "expected file: $1"
}

required_files=(
  "$project_root/.claude-plugin/marketplace.json"
  "$project_root/.agents/plugins/marketplace.json"
  "$project_root/LICENSE"
  "$project_root/PRIVACY.md"
  "$project_root/SUPPORT.md"
  "$project_root/TERMS.md"
  "$plugin_root/.claude-plugin/plugin.json"
  "$plugin_root/.codex-plugin/plugin.json"
  "$plugin_root/LICENSE"
  "$plugin_root/framework/AGENTS.md"
  "$plugin_root/framework/CLAUDE.md"
  "$plugin_root/skills/code-health/SKILL.md"
  "$plugin_root/skills/code-health/references/operating-model.md"
  "$plugin_root/skills/code-health/references/scoring.md"
  "$plugin_root/skills/code-health/references/finding-format.md"
  "$plugin_root/skills/code-health/references/tooling.md"
  "$plugin_root/skills/code-health/scripts/collect-baseline.sh"
  "$plugin_root/assets/logo.png"
  "$plugin_root/submission/listing.md"
  "$plugin_root/submission/openai-test-cases.json"
  "$plugin_root/submission/release-notes.md"
)

for required_file in "${required_files[@]}"; do
  assert_file "$required_file"
done

python3 - "$project_root" <<'PY'
import json
import filecmp
import pathlib
import re
import struct
import sys

root = pathlib.Path(sys.argv[1])
plugin = root / "plugins" / "code-health"


def load_json(path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


claude_manifest = load_json(plugin / ".claude-plugin" / "plugin.json")
codex_manifest = load_json(plugin / ".codex-plugin" / "plugin.json")
claude_marketplace = load_json(root / ".claude-plugin" / "marketplace.json")
codex_marketplace = load_json(root / ".agents" / "plugins" / "marketplace.json")
test_cases = load_json(plugin / "submission" / "openai-test-cases.json")
release_notes = (plugin / "submission" / "release-notes.md").read_text(
    encoding="utf-8"
)

expected_version = codex_manifest["version"]
assert re.fullmatch(r"\d+\.\d+\.\d+", expected_version)
for manifest in (claude_manifest, codex_manifest):
    assert manifest["name"] == "code-health"
    assert manifest["version"] == expected_version
    assert manifest["description"].strip()
    assert manifest["author"]["name"] == "minhtuanchannhan"
    assert manifest["repository"] == "https://github.com/minhtuanchannhan/code-health"
    assert manifest["license"] == "MIT"

assert claude_manifest["displayName"] == "Code Health"
assert claude_manifest["skills"] == "./skills/"
assert filecmp.cmp(root / "LICENSE", plugin / "LICENSE", shallow=False)

interface = codex_manifest["interface"]
required_interface = {
    "displayName",
    "shortDescription",
    "longDescription",
    "developerName",
    "category",
    "capabilities",
    "websiteURL",
    "privacyPolicyURL",
    "termsOfServiceURL",
    "defaultPrompt",
    "brandColor",
    "composerIcon",
    "logo",
}
assert required_interface <= interface.keys()
assert interface["displayName"] == "Code Health"
assert interface["developerName"] == "minhtuanchannhan"
assert 1 <= len(interface["defaultPrompt"]) <= 3
assert all(len(prompt) <= 128 for prompt in interface["defaultPrompt"])

for key in ("websiteURL", "privacyPolicyURL", "termsOfServiceURL"):
    assert interface[key].startswith("https://")
expected_document_root = (
    "https://github.com/minhtuanchannhan/code-health/blob/master"
)
assert interface["privacyPolicyURL"] == f"{expected_document_root}/PRIVACY.md"
assert interface["termsOfServiceURL"] == f"{expected_document_root}/TERMS.md"
for key in ("composerIcon", "logo"):
    asset = plugin / interface[key].removeprefix("./")
    assert asset.is_file(), f"missing manifest asset: {asset}"

assert claude_marketplace["name"] == "code-health"
assert claude_marketplace["owner"]["name"] == "minhtuanchannhan"
assert len(claude_marketplace["plugins"]) == 1
claude_entry = claude_marketplace["plugins"][0]
assert claude_entry["name"] == "code-health"
assert claude_entry["source"] == "./plugins/code-health"
assert claude_entry["version"] == expected_version
release_version = re.search(r"^## (\d+\.\d+\.\d+)$", release_notes, re.MULTILINE)
assert release_version, "release notes must start with a semantic version heading"
assert release_version.group(1) == expected_version

assert codex_marketplace["name"] == "code-health"
assert codex_marketplace["interface"]["displayName"] == "Code Health"
assert len(codex_marketplace["plugins"]) == 1
codex_entry = codex_marketplace["plugins"][0]
assert codex_entry["name"] == "code-health"
assert codex_entry["source"] == {
    "source": "local",
    "path": "./plugins/code-health",
}
assert codex_entry["policy"] == {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL",
}
assert codex_entry["category"] == "Developer Tools"

assert len(test_cases["positive"]) >= 5
assert len(test_cases["negative"]) >= 3
for case_type in ("positive", "negative"):
    for case in test_cases[case_type]:
        assert case["prompt"].strip()
        assert case["expected_behavior"].strip()

logo = plugin / "assets" / "logo.png"
with logo.open("rb") as handle:
    assert handle.read(8) == b"\x89PNG\r\n\x1a\n"
    length = struct.unpack(">I", handle.read(4))[0]
    assert handle.read(4) == b"IHDR"
    ihdr = handle.read(length)
width, height, bit_depth, color_type = struct.unpack(">IIBB", ihdr[:10])
assert width >= 512 and height >= 512
assert bit_depth == 8
assert color_type in (4, 6), "logo must preserve transparency"

assert filecmp.cmp(
    root / ".claude" / "skills" / "code-health" / "SKILL.md",
    plugin / "skills" / "code-health" / "SKILL.md",
    shallow=False,
)
for agent in (root / ".claude" / "agents").glob("*.md"):
    assert filecmp.cmp(agent, plugin / "agents" / agent.name, shallow=False)

mirrored_contracts = {
    root / "AGENTS.md": [plugin / "framework" / "AGENTS.md"],
    root / "CLAUDE.md": [plugin / "framework" / "CLAUDE.md"],
    root / "docs" / "code-health" / "README.md": [
        plugin / "docs" / "code-health" / "README.md",
        plugin / "skills" / "code-health" / "references" / "operating-model.md",
        root / ".claude" / "skills" / "code-health" / "references" / "operating-model.md",
    ],
    root / "docs" / "code-health" / "scoring.md": [
        plugin / "docs" / "code-health" / "scoring.md",
        plugin / "skills" / "code-health" / "references" / "scoring.md",
        root / ".claude" / "skills" / "code-health" / "references" / "scoring.md",
    ],
    root / "docs" / "code-health" / "finding-format.md": [
        plugin / "docs" / "code-health" / "finding-format.md",
        plugin / "skills" / "code-health" / "references" / "finding-format.md",
        root / ".claude" / "skills" / "code-health" / "references" / "finding-format.md",
    ],
    root / "docs" / "code-health" / "tooling.md": [
        plugin / "docs" / "code-health" / "tooling.md",
        plugin / "skills" / "code-health" / "references" / "tooling.md",
        root / ".claude" / "skills" / "code-health" / "references" / "tooling.md",
    ],
    root / "scripts" / "code-health" / "collect-baseline.sh": [
        plugin / "scripts" / "code-health" / "collect-baseline.sh",
        plugin / "skills" / "code-health" / "scripts" / "collect-baseline.sh",
        root / ".claude" / "skills" / "code-health" / "scripts" / "collect-baseline.sh",
    ],
    root / ".claude" / "skills" / "code-health" / "agents" / "openai.yaml": [
        plugin / "skills" / "code-health" / "agents" / "openai.yaml",
    ],
}
for source, mirrors in mirrored_contracts.items():
    for mirror in mirrors:
        assert filecmp.cmp(source, mirror, shallow=False), f"stale mirror: {mirror}"

for path in root.rglob("*"):
    if not path.is_file() or ".git" in path.parts:
        continue
    if path.suffix.lower() not in {".md", ".json", ".sh", ".yml", ".yaml"}:
        continue
    text = path.read_text(encoding="utf-8")
    unfinished_marker = "[TO" + "DO:"
    assert unfinished_marker not in text, f"unfinished placeholder in {path}"
PY

isolated_plugin="$test_root/code-health"
cp -R "$plugin_root" "$isolated_plugin"
target="$test_root/target-repository"
mkdir -p "$target"
git init -q "$target"
(
  cd "$target"
  "$isolated_plugin/skills/code-health/scripts/collect-baseline.sh" \
    .code-health/runs/release-test >/dev/null
)
assert_file "$target/.code-health/runs/release-test/repository.txt"

if command -v claude >/dev/null 2>&1; then
  claude plugin validate "$project_root" --strict
  claude plugin validate "$plugin_root" --strict
fi

printf 'PASS: release package\n'
