#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
installer="$project_root/install.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/code-health-install-test.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [[ -f $1 ]] || fail "expected file: $1"
}

assert_contains_line() {
  grep -Fqx -- "$2" "$1" || fail "expected '$2' in $1"
}

assert_marker_once() {
  local count
  count=$(grep -Fxc -- "$2" "$1" || true)
  [[ $count -eq 1 ]] || fail "expected one '$2' marker in $1, found $count"
}

assert_equals() {
  [[ $1 == "$2" ]] || fail "expected '$2', got '$1'"
}

permission_bits() {
  local mode

  if mode=$(stat -f '%Lp' "$1" 2>/dev/null); then
    printf '%s\n' "$mode"
  else
    stat -c '%a' "$1"
  fi
}

create_repository() {
  mkdir -p "$1"
  git init -q "$1"
}

copy_installer_release() {
  local destination=$1

  mkdir -p "$destination/plugins"
  cp "$project_root/README.md" "$destination/README.md"
  cp "$project_root/install.sh" "$destination/install.sh"
  cp -R "$project_root/plugins/code-health" \
    "$destination/plugins/code-health"
}

test_installs_without_overwriting_and_is_repeatable() {
  local target="$test_root/target repository"
  local agents_permissions
  local claude_permissions
  local gitignore_permissions
  create_repository "$target"
  target=$(cd "$target" && pwd -P)

  printf 'existing agent guidance\n' > "$target/AGENTS.md"
  printf 'existing Claude guidance\n' > "$target/CLAUDE.md"
  printf 'node_modules/\n.code-health/\n' > "$target/.gitignore"
  chmod 640 "$target/AGENTS.md"
  chmod 600 "$target/CLAUDE.md"
  chmod 644 "$target/.gitignore"
  agents_permissions=$(permission_bits "$target/AGENTS.md")
  claude_permissions=$(permission_bits "$target/CLAUDE.md")
  gitignore_permissions=$(permission_bits "$target/.gitignore")
  mkdir -p "$target/.claude/agents"
  printf 'custom agent\n' > "$target/.claude/agents/custom.md"

  "$installer" "$target"

  assert_file "$target/.code-health/framework/README.md"
  assert_file "$target/.code-health/framework/AGENTS.md"
  assert_file "$target/.code-health/framework/CLAUDE.md"
  assert_file "$target/.code-health/framework/LICENSE"
  assert_file "$target/.code-health/framework/docs/code-health/tooling.md"
  assert_file "$target/.code-health/framework/scripts/code-health/collect-baseline.sh"
  assert_file "$target/.code-health/framework/.claude/skills/code-health/SKILL.md"
  assert_file "$target/.claude/skills/code-health/SKILL.md"
  assert_file "$target/.claude/agents/security.md"
  assert_file "$target/.claude/agents/custom.md"
  assert_file "$target/.code-health/framework/.codex-plugin/plugin.json"
  cmp -s \
    "$project_root/plugins/code-health/skills/code-health/SKILL.md" \
    "$target/.claude/skills/code-health/SKILL.md" || \
    fail 'installer did not install the canonical plugin skill'
  cmp -s \
    "$project_root/plugins/code-health/agents/security.md" \
    "$target/.claude/agents/security.md" || \
    fail 'installer did not install the canonical plugin agent'
  [[ -x $target/.code-health/framework/scripts/code-health/collect-baseline.sh ]] || \
    fail 'installed baseline collector is not executable'

  assert_contains_line "$target/AGENTS.md" 'existing agent guidance'
  assert_contains_line "$target/CLAUDE.md" 'existing Claude guidance'
  assert_contains_line "$target/.gitignore" 'node_modules/'
  assert_contains_line "$target/.claude/agents/custom.md" 'custom agent'
  assert_marker_once "$target/AGENTS.md" '<!-- code-health:start -->'
  assert_marker_once "$target/CLAUDE.md" '<!-- code-health:start -->'
  assert_marker_once "$target/.gitignore" '# code-health:start'
  assert_equals "$(permission_bits "$target/AGENTS.md")" "$agents_permissions"
  assert_equals "$(permission_bits "$target/CLAUDE.md")" "$claude_permissions"
  assert_equals "$(permission_bits "$target/.gitignore")" "$gitignore_permissions"

  git -C "$target" check-ignore -q .code-health/runs/example || \
    fail '.code-health/runs is not ignored'
  if git -C "$target" check-ignore -q .code-health/framework/README.md; then
    fail '.code-health/framework is ignored'
  fi

  mkdir -p "$target/nested/path"
  (
    cd "$target/nested/path"
    ../../.code-health/framework/scripts/code-health/collect-baseline.sh \
      .code-health/runs/test-baseline
  )

  assert_file "$target/.code-health/runs/test-baseline/repository.txt"
  assert_contains_line \
    "$target/.code-health/runs/test-baseline/repository.txt" \
    "repository_root=$target"
  assert_contains_line \
    "$target/.code-health/runs/test-baseline/README.md" \
    "- Collector: \`.code-health/framework/scripts/code-health/collect-baseline.sh\`"

  "$installer" "$target"

  assert_file "$target/.code-health/runs/test-baseline/repository.txt"
  assert_marker_once "$target/AGENTS.md" '<!-- code-health:start -->'
  assert_marker_once "$target/CLAUDE.md" '<!-- code-health:start -->'
  assert_marker_once "$target/.gitignore" '# code-health:start'
}

test_upgrades_unmodified_installer_managed_files() {
  local target="$test_root/upgrade-repository"
  local release="$test_root/new-release"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)

  "$installer" "$target" >/dev/null
  assert_equals "$(permission_bits "$target/AGENTS.md")" '644'
  assert_equals "$(permission_bits "$target/CLAUDE.md")" '644'
  assert_equals "$(permission_bits "$target/.gitignore")" '644'

  copy_installer_release "$release"
  printf '\nUpgrade fixture.\n' >> \
    "$release/plugins/code-health/agents/security.md"

  "$release/install.sh" "$target" >/dev/null

  cmp -s \
    "$release/plugins/code-health/agents/security.md" \
    "$target/.claude/agents/security.md" || \
    fail 'installer did not upgrade an unmodified managed Claude file'
  cmp -s \
    "$release/plugins/code-health/agents/security.md" \
    "$target/.code-health/framework/.claude/agents/security.md" || \
    fail 'canonical framework did not receive the upgraded Claude file'
}

test_removes_obsolete_unmodified_installer_managed_files() {
  local target="$test_root/obsolete-managed-file-repository"
  local old_release="$test_root/old-release"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)

  copy_installer_release "$old_release"
  touch "$old_release/plugins/code-health/agents/obsolete.md"

  "$old_release/install.sh" "$target" >/dev/null
  assert_file "$target/.claude/agents/obsolete.md"

  "$installer" "$target" >/dev/null

  [[ ! -e $target/.claude/agents/obsolete.md ]] || \
    fail 'installer retained an obsolete unmodified managed Claude file'
}

test_preserves_modified_obsolete_installer_managed_files() {
  local target="$test_root/modified-obsolete-managed-file-repository"
  local old_release="$test_root/modified-old-release"
  local output="$test_root/modified-obsolete-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)

  copy_installer_release "$old_release"
  touch "$old_release/plugins/code-health/agents/obsolete.md"

  "$old_release/install.sh" "$target" >/dev/null
  printf 'repository-owned replacement\n' > \
    "$target/.claude/agents/obsolete.md"

  "$installer" "$target" > "$output" 2>&1

  assert_contains_line "$target/.claude/agents/obsolete.md" \
    'repository-owned replacement'
  grep -Fq 'Preserving modified obsolete Claude file' "$output" || \
    fail 'installer did not explain why it preserved a modified obsolete file'
}

test_preserves_identical_repository_owned_files_when_they_become_obsolete() {
  local target="$test_root/identical-repository-owned-file-repository"
  local old_release="$test_root/identical-repository-owned-old-release"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)
  mkdir -p "$target/.claude/agents"
  touch "$target/.claude/agents/obsolete.md"

  copy_installer_release "$old_release"
  touch "$old_release/plugins/code-health/agents/obsolete.md"

  "$old_release/install.sh" "$target" >/dev/null
  "$installer" "$target" >/dev/null

  assert_file "$target/.claude/agents/obsolete.md"
}

test_preserves_identical_repository_owned_files_during_content_upgrades() {
  local target="$test_root/identical-repository-owned-upgrade-repository"
  local release="$test_root/identical-repository-owned-new-release"
  local expected="$test_root/identical-repository-owned-security.md"
  local output="$test_root/identical-repository-owned-upgrade-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)
  mkdir -p "$target/.claude/agents"
  cp "$project_root/plugins/code-health/agents/security.md" \
    "$target/.claude/agents/security.md"
  cp "$target/.claude/agents/security.md" "$expected"

  "$installer" "$target" >/dev/null
  if grep -Fqx 'agents/security.md' \
    "$target/.code-health/framework/.code-health-managed-claude-files"; then
    fail 'installer claimed ownership of an existing identical Claude file'
  fi

  copy_installer_release "$release"
  printf '\nChanged release fixture.\n' >> \
    "$release/plugins/code-health/agents/security.md"

  if "$release/install.sh" "$target" > "$output" 2>&1; then
    fail 'installer overwrote an identical repository-owned Claude file'
  fi

  cmp -s "$expected" "$target/.claude/agents/security.md" || \
    fail 'installer changed an identical repository-owned Claude file'
  grep -Fq 'Refusing to overwrite repository-owned Claude file' "$output" || \
    fail 'installer did not explain the repository-owned upgrade conflict'
}

test_preserves_ambiguous_obsolete_files_from_legacy_installations() {
  local target="$test_root/legacy-obsolete-file-repository"
  local old_release="$test_root/legacy-obsolete-old-release"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)

  copy_installer_release "$old_release"
  touch "$old_release/plugins/code-health/agents/obsolete.md"

  "$old_release/install.sh" "$target" >/dev/null
  rm -f -- \
    "$target/.code-health/framework/.code-health-managed-claude-files"
  "$installer" "$target" >/dev/null

  assert_file "$target/.claude/agents/obsolete.md"
}

test_restores_previous_framework_after_integration_failure() {
  local target="$test_root/retryable-upgrade-repository"
  local old_release="$test_root/retryable-old-release"
  local output="$test_root/retryable-upgrade-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)

  copy_installer_release "$old_release"
  printf '\nOld release fixture.\n' >> \
    "$old_release/plugins/code-health/agents/security.md"
  "$old_release/install.sh" "$target" >/dev/null

  if bash -c '
    cp() {
      local source=$1
      local destination=${!#}
      if [[ $source == */plugins/code-health/agents/reliability.md ]]; then
        printf 'partial copy\n' > "$destination"
        return 73
      fi
      command cp "$@"
    }

    source "$1" "$2"
  ' _ "$installer" "$target" > "$output" 2>&1; then
    fail 'installer ignored an injected integration-copy failure'
  fi

  cmp -s \
    "$old_release/plugins/code-health/agents/security.md" \
    "$target/.code-health/framework/.claude/agents/security.md" || \
    fail 'installer did not restore the previous framework after failure'
  if find "$target/.claude" -name '.code-health-copy.*' -print -quit | \
    grep -q .; then
    fail 'installer retained a temporary integration file after failure'
  fi

  "$installer" "$target" >/dev/null
  cmp -s \
    "$project_root/plugins/code-health/agents/security.md" \
    "$target/.claude/agents/security.md" || \
    fail 'installer upgrade was not retryable after integration failure'
}

test_rolls_back_new_framework_after_integration_failure() {
  local target="$test_root/rolled-back-new-install-repository"
  local output="$test_root/rolled-back-new-install-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)

  if bash -c '
    cp() {
      local source=$1
      local destination=${!#}
      if [[ $source == */plugins/code-health/agents/reliability.md ]]; then
        printf 'partial copy\n' > "$destination"
        return 73
      fi
      command cp "$@"
    }

    source "$1" "$2"
  ' _ "$installer" "$target" > "$output" 2>&1; then
    fail 'installer ignored an injected new-install copy failure'
  fi

  [[ ! -e $target/.code-health/framework ]] || \
    fail 'installer retained a new framework after integration failure'
  if find "$target/.claude" -type f -print -quit 2>/dev/null | grep -q .; then
    fail 'installer retained managed Claude files after new-install failure'
  fi
}

test_rejects_conflicting_claude_files_before_writing() {
  local target="$test_root/conflicting-repository"
  local output="$test_root/conflict-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)
  mkdir -p "$target/.claude/agents"
  printf 'repository-owned security agent\n' > "$target/.claude/agents/security.md"

  if "$installer" "$target" > "$output" 2>&1; then
    fail 'installer accepted a conflicting Claude agent file'
  fi

  assert_contains_line "$target/.claude/agents/security.md" \
    'repository-owned security agent'
  [[ ! -e $target/.code-health/framework ]] || \
    fail 'installer wrote framework files before reporting a conflict'
  [[ ! -e $target/AGENTS.md ]] || \
    fail 'installer wrote AGENTS.md before reporting a conflict'
  grep -Fq 'Refusing to overwrite' "$output" || \
    fail 'installer did not explain the Claude file conflict'
}

test_rejects_symlinked_integration_directories() {
  local target="$test_root/symlinked-repository"
  local external_agents="$test_root/external-agents"
  local output="$test_root/symlink-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)
  mkdir -p "$target/.claude" "$external_agents"
  ln -s "$external_agents" "$target/.claude/agents"

  if "$installer" "$target" > "$output" 2>&1; then
    fail 'installer accepted a symlinked Claude agents directory'
  fi

  [[ ! -e $external_agents/security.md ]] || \
    fail 'installer followed a Claude directory symlink outside the repository'
  [[ ! -e $target/.code-health/framework ]] || \
    fail 'installer wrote framework files before reporting a symlink'
  grep -Fq 'symbolic link' "$output" || \
    fail 'installer did not explain the unsafe symbolic link'
}

test_rejects_non_directory_claude_ancestors_before_writing() {
  local target="$test_root/non-directory-claude-repository"
  local output="$test_root/non-directory-claude-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)
  mkdir -p "$target/.claude"
  touch "$target/.claude/agents"

  if "$installer" "$target" > "$output" 2>&1; then
    fail 'installer accepted a non-directory Claude ancestor'
  fi

  [[ -f $target/.claude/agents ]] || \
    fail 'installer changed the repository-owned Claude ancestor'
  [[ ! -e $target/.code-health/framework ]] || \
    fail 'installer wrote framework files before rejecting a non-directory ancestor'
  grep -Fq 'not a directory' "$output" || \
    fail 'installer did not explain the non-directory Claude ancestor'
}

test_rejects_reversed_managed_markers_without_writing() {
  local target="$test_root/reversed-markers-repository"
  local expected="$test_root/reversed-markers-expected.txt"
  local output="$test_root/reversed-markers-output.txt"
  create_repository "$target"
  target=$(cd "$target" && pwd -P)
  printf '%s\n' \
    'before' \
    '<!-- code-health:end -->' \
    'repository-owned middle' \
    '<!-- code-health:start -->' \
    'repository-owned after' > "$target/AGENTS.md"
  cp "$target/AGENTS.md" "$expected"

  if "$installer" "$target" > "$output" 2>&1; then
    fail 'installer accepted reversed managed markers'
  fi

  cmp -s "$expected" "$target/AGENTS.md" || \
    fail 'installer changed AGENTS.md with malformed markers'
  [[ ! -e $target/.code-health/framework ]] || \
    fail 'installer wrote framework files before rejecting malformed markers'
  grep -Fq 'malformed code-health managed block' "$output" || \
    fail 'installer did not explain the malformed managed block'
}

test_rejects_non_repository_target() {
  local target="$test_root/not-a-repository"
  local output="$test_root/not-a-repository-output.txt"
  mkdir -p "$target"

  if "$installer" "$target" > "$output" 2>&1; then
    fail 'installer accepted a directory that is not a Git repository'
  fi

  grep -Fq 'not a Git repository' "$output" || \
    fail 'installer did not explain the invalid target'
  [[ ! -e $target/.code-health ]] || \
    fail 'installer modified a directory that is not a Git repository'
}

test_installs_without_overwriting_and_is_repeatable
test_upgrades_unmodified_installer_managed_files
test_removes_obsolete_unmodified_installer_managed_files
test_preserves_modified_obsolete_installer_managed_files
test_preserves_identical_repository_owned_files_when_they_become_obsolete
test_preserves_identical_repository_owned_files_during_content_upgrades
test_preserves_ambiguous_obsolete_files_from_legacy_installations
test_restores_previous_framework_after_integration_failure
test_rolls_back_new_framework_after_integration_failure
test_rejects_conflicting_claude_files_before_writing
test_rejects_symlinked_integration_directories
test_rejects_non_directory_claude_ancestors_before_writing
test_rejects_reversed_managed_markers_without_writing
test_rejects_non_repository_target

printf 'PASS: installer behavior\n'
