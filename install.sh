#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

usage() {
  printf 'Usage: %s <target-repository>\n' "${0##*/}"
  printf 'Installs the code-health framework without overwriting repository-owned files.\n'
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
plugin_root="$source_root/plugins/code-health"

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

[[ -d $1 ]] || die "target directory does not exist: $1"
target_root=$(cd "$1" && pwd -P)

if ! discovered_root=$(git -C "$target_root" rev-parse --show-toplevel 2>/dev/null); then
  die "target is not a Git repository: $target_root"
fi
discovered_root=$(cd "$discovered_root" && pwd -P)
[[ $discovered_root == "$target_root" ]] || \
  die "target must be the Git repository root: $discovered_root"

reject_target_symlinks() {
  local relative_path=$1
  local remaining=$relative_path
  local current_path=$target_root
  local component

  while [[ -n $remaining ]]; do
    component=${remaining%%/*}
    current_path="$current_path/$component"
    [[ ! -L $current_path ]] || \
      die "target integration path contains a symbolic link: $relative_path"
    if [[ $remaining == */* ]]; then
      remaining=${remaining#*/}
    else
      remaining=''
    fi
  done
}

reject_non_directory_ancestors() {
  local relative_path=$1
  local remaining=${relative_path%/*}
  local current_path=$target_root
  local component

  [[ $remaining != "$relative_path" ]] || return 0
  while [[ -n $remaining ]]; do
    component=${remaining%%/*}
    current_path="$current_path/$component"
    if [[ -e $current_path && ! -d $current_path ]]; then
      die "target integration path is not a directory: $current_path"
    fi
    if [[ $remaining == */* ]]; then
      remaining=${remaining#*/}
    else
      remaining=''
    fi
  done
}

reject_target_symlinks 'AGENTS.md'
reject_target_symlinks 'CLAUDE.md'
reject_target_symlinks '.gitignore'
reject_target_symlinks '.code-health/framework'
reject_target_symlinks '.claude'

required_paths=(
  README.md
  install.sh
  plugins/code-health/framework/AGENTS.md
  plugins/code-health/framework/CLAUDE.md
  plugins/code-health/LICENSE
  plugins/code-health/.claude-plugin/plugin.json
  plugins/code-health/.codex-plugin/plugin.json
  plugins/code-health/skills/code-health/SKILL.md
  plugins/code-health/agents
  plugins/code-health/docs/code-health
  plugins/code-health/scripts/code-health
)
for required_path in "${required_paths[@]}"; do
  [[ -e $source_root/$required_path ]] || \
    die "installer payload is missing: $required_path"
done

framework_parent="$target_root/.code-health"
framework_dir="$framework_parent/framework"
managed_marker='.code-health-managed'
managed_claude_manifest='.code-health-managed-claude-files'

if [[ -e $framework_dir && ! -f $framework_dir/$managed_marker ]]; then
  die "existing framework directory is not installer-managed: $framework_dir"
fi
if [[ -e $framework_dir/$managed_claude_manifest && \
  ( ! -f $framework_dir/$managed_claude_manifest || \
    -L $framework_dir/$managed_claude_manifest ) ]]; then
  die "invalid managed Claude file inventory: $framework_dir/$managed_claude_manifest"
fi

manifest_contains() {
  local manifest=$1
  local relative_path=$2

  [[ -f $manifest ]] && grep -Fqx -- "$relative_path" "$manifest"
}

validate_managed_block() {
  local file=$1
  local start_marker=$2
  local end_marker=$3

  [[ -e $file ]] || return 0
  [[ -f $file ]] || die "managed integration path is not a file: $file"

  if ! awk -v start_marker="$start_marker" -v end_marker="$end_marker" '
    $0 == start_marker {
      if (inside || saw_start) {
        invalid = 1
      }
      inside = 1
      saw_start = 1
      next
    }
    $0 == end_marker {
      if (!inside || saw_end) {
        invalid = 1
      }
      inside = 0
      saw_end = 1
      next
    }
    END {
      if (inside || saw_start != saw_end) {
        invalid = 1
      }
      exit invalid ? 1 : 0
    }
  ' "$file"; then
    die "malformed code-health managed block in $file"
  fi
}

validate_managed_block "$target_root/AGENTS.md" \
  '<!-- code-health:start -->' '<!-- code-health:end -->'
validate_managed_block "$target_root/CLAUDE.md" \
  '<!-- code-health:start -->' '<!-- code-health:end -->'
validate_managed_block "$target_root/.gitignore" \
  '# code-health:start' '# code-health:end'

preflight_claude_file() {
  local relative_path=$1
  local source_file="$plugin_root/$relative_path"
  local target_file="$target_root/.claude/$relative_path"
  local previous_file="$framework_dir/.claude/$relative_path"

  reject_target_symlinks ".claude/$relative_path"
  reject_non_directory_ancestors ".claude/$relative_path"
  [[ -e $target_file ]] || return 0
  [[ -f $target_file ]] || \
    die "Refusing to overwrite non-file Claude path: .claude/$relative_path"

  if cmp -s "$source_file" "$target_file"; then
    return 0
  fi
  if [[ -f $framework_dir/$managed_marker ]] && \
    manifest_contains \
      "$framework_dir/$managed_claude_manifest" "$relative_path" && \
    [[ -f $previous_file ]] && cmp -s "$previous_file" "$target_file"; then
    return 0
  fi

  die "Refusing to overwrite repository-owned Claude file: .claude/$relative_path"
}

while IFS= read -r claude_file; do
  preflight_claude_file "${claude_file#"$plugin_root/"}"
done < <(find "$plugin_root/skills" "$plugin_root/agents" -type f -print | sort)

if [[ -f $framework_dir/$managed_marker ]]; then
  while IFS= read -r previous_file; do
    relative_path=${previous_file#"$framework_dir/.claude/"}
    [[ ! -e $plugin_root/$relative_path ]] || continue
    manifest_contains \
      "$framework_dir/$managed_claude_manifest" "$relative_path" || continue
    target_file="$target_root/.claude/$relative_path"
    reject_target_symlinks ".claude/$relative_path"
    reject_non_directory_ancestors ".claude/$relative_path"
    [[ ! -e $target_file || -f $target_file ]] || \
      die "obsolete managed Claude path is not a file: .claude/$relative_path"
  done < <(find \
    "$framework_dir/.claude/skills" \
    "$framework_dir/.claude/agents" \
    -type f -print | sort)
fi

write_agents_block() {
  printf '%s\n' \
    '<!-- code-health:start -->' \
    '## Code-health framework' \
    '' \
    "For code-health audits and remediation, first read \`.code-health/framework/AGENTS.md\` and the documents it references. Treat the target repository instructions and business rules as higher priority when they conflict with generic framework guidance." \
    '<!-- code-health:end -->'
}

write_claude_block() {
  printf '%s\n' \
    '<!-- code-health:start -->' \
    '## Code-health framework' \
    '' \
    "Use \`/code-health\` for evidence-backed audits. Its project skill and specialist agents are installed under \`.claude/\`; the canonical framework guidance is under \`.code-health/framework/\`." \
    '<!-- code-health:end -->'
}

write_gitignore_block() {
  printf '%s\n' \
    '# code-health:start' \
    '!/.code-health/' \
    '/.code-health/*' \
    '!/.code-health/framework/' \
    '!/.code-health/framework/**' \
    '/.code-health/runs/' \
    '# code-health:end'
}

upsert_managed_block() {
  local file=$1
  local start_marker=$2
  local end_marker=$3
  local writer=$4
  local file_parent
  local block_file
  local output_file

  file_parent=$(dirname "$file")
  mkdir -p "$file_parent"
  block_file=$(mktemp "$file_parent/.code-health-block.XXXXXX")
  output_file=$(mktemp "$file_parent/.code-health-output.XXXXXX")
  "$writer" > "$block_file"

  if [[ -f $file ]]; then
    cp -p "$file" "$output_file"
    awk -v start_marker="$start_marker" \
      -v end_marker="$end_marker" \
      -v block_file="$block_file" '
      function emit_block(line) {
        while ((getline line < block_file) > 0) {
          print line
        }
        close(block_file)
      }
      $0 == start_marker {
        emit_block()
        replacing = 1
        replaced = 1
        next
      }
      replacing && $0 == end_marker {
        replacing = 0
        next
      }
      !replacing { print }
      END {
        if (!replaced) {
          if (NR > 0) {
            print ""
          }
          emit_block()
        }
      }
    ' "$file" > "$output_file"
  else
    cp "$block_file" "$output_file"
    chmod 644 "$output_file"
  fi

  mv "$output_file" "$file"
  rm -f "$block_file"
}

mkdir -p "$framework_parent"
staging_dir=$(mktemp -d "$framework_parent/.framework-stage.XXXXXX")
cleanup_staging() {
  if [[ -n ${staging_dir:-} && -d $staging_dir ]]; then
    rm -rf -- "$staging_dir"
  fi
}

cleanup_failed_install() {
  local relative_path
  local source_file
  local target_file

  [[ ${framework_swapped:-0} -eq 1 ]] || return 0
  [[ -f $framework_dir/$managed_marker ]] || {
    printf 'Error: cannot roll back unmarked framework: %s\n' \
      "$framework_dir" >&2
    return 0
  }

  if [[ -z ${backup_dir:-} ]]; then
    while IFS= read -r relative_path; do
      source_file="$plugin_root/$relative_path"
      target_file="$target_root/.claude/$relative_path"
      if [[ -f $source_file && -f $target_file ]] && \
        cmp -s "$source_file" "$target_file"; then
        rm -f -- "$target_file"
      fi
    done < "$framework_dir/$managed_claude_manifest"
  fi

  if ! rm -rf -- "$framework_dir"; then
    printf 'Error: could not remove failed framework payload: %s\n' \
      "$framework_dir" >&2
    return 0
  fi

  if [[ -n ${backup_dir:-} && -d $backup_dir ]]; then
    if ! mv "$backup_dir" "$framework_dir"; then
      printf 'Error: previous framework remains at %s\n' "$backup_dir" >&2
    fi
  fi
}

cleanup_install() {
  local exit_status=$?

  if [[ $exit_status -ne 0 ]]; then
    cleanup_failed_install
  fi
  cleanup_staging
}
trap cleanup_install EXIT

cp "$plugin_root/framework/AGENTS.md" "$staging_dir/AGENTS.md"
cp "$plugin_root/framework/CLAUDE.md" "$staging_dir/CLAUDE.md"
cp "$plugin_root/LICENSE" "$staging_dir/LICENSE"
cp "$source_root/README.md" "$staging_dir/README.md"
cp "$source_root/install.sh" "$staging_dir/install.sh"
cp -R "$plugin_root/.claude-plugin" "$staging_dir/.claude-plugin"
cp -R "$plugin_root/.codex-plugin" "$staging_dir/.codex-plugin"
cp -R "$plugin_root/agents" "$staging_dir/agents"
cp -R "$plugin_root/assets" "$staging_dir/assets"
cp -R "$plugin_root/docs" "$staging_dir/docs"
cp -R "$plugin_root/scripts" "$staging_dir/scripts"
cp -R "$plugin_root/skills" "$staging_dir/skills"
mkdir -p "$staging_dir/.claude"
cp -R "$plugin_root/agents" "$staging_dir/.claude/agents"
cp -R "$plugin_root/skills" "$staging_dir/.claude/skills"
printf 'managed-by=code-health-installer\n' > "$staging_dir/$managed_marker"
: > "$staging_dir/$managed_claude_manifest"
while IFS= read -r claude_file; do
  relative_path=${claude_file#"$plugin_root/"}
  target_file="$target_root/.claude/$relative_path"
  if manifest_contains \
    "$framework_dir/$managed_claude_manifest" "$relative_path" || \
    [[ ! -e $target_file ]]; then
    printf '%s\n' "$relative_path" >> \
      "$staging_dir/$managed_claude_manifest"
  fi
done < <(find "$plugin_root/skills" "$plugin_root/agents" -type f -print | sort)
chmod +x "$staging_dir/install.sh"
chmod +x "$staging_dir/scripts/code-health/collect-baseline.sh"

backup_dir=''
framework_swapped=0
if [[ -d $framework_dir ]]; then
  backup_dir=$(mktemp -d "$framework_parent/.framework-backup.XXXXXX")
  rmdir "$backup_dir"
  mv "$framework_dir" "$backup_dir"
fi

if ! mv "$staging_dir" "$framework_dir"; then
  if [[ -n $backup_dir && -d $backup_dir ]]; then
    mv "$backup_dir" "$framework_dir"
  fi
  die 'could not install the staged framework payload'
fi
staging_dir=''
framework_swapped=1

install_claude_file() {
  local source_file=$1
  local relative_path=${source_file#"$plugin_root/"}
  local target_file="$target_root/.claude/$relative_path"
  local target_parent
  local temporary_file

  manifest_contains \
    "$framework_dir/$managed_claude_manifest" "$relative_path" || return 0

  target_parent=$(dirname "$target_file")
  mkdir -p "$target_parent"
  temporary_file=$(mktemp "$target_parent/.code-health-copy.XXXXXX")
  if ! cp -p "$source_file" "$temporary_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi
  if ! mv "$temporary_file" "$target_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi
}

while IFS= read -r claude_file; do
  install_claude_file "$claude_file"
done < <(find "$plugin_root/skills" "$plugin_root/agents" -type f -print | sort)

if [[ -n $backup_dir && -d $backup_dir ]]; then
  while IFS= read -r previous_file; do
    relative_path=${previous_file#"$backup_dir/.claude/"}
    [[ ! -e $plugin_root/$relative_path ]] || continue
    manifest_contains \
      "$backup_dir/$managed_claude_manifest" "$relative_path" || continue
    target_file="$target_root/.claude/$relative_path"
    [[ -f $target_file ]] || continue
    if cmp -s "$previous_file" "$target_file"; then
      rm -f -- "$target_file"
    else
      printf 'Preserving modified obsolete Claude file: .claude/%s\n' \
        "$relative_path" >&2
    fi
  done < <(find \
    "$backup_dir/.claude/skills" \
    "$backup_dir/.claude/agents" \
    -type f -print | sort)
fi

upsert_managed_block "$target_root/AGENTS.md" \
  '<!-- code-health:start -->' '<!-- code-health:end -->' write_agents_block
upsert_managed_block "$target_root/CLAUDE.md" \
  '<!-- code-health:start -->' '<!-- code-health:end -->' write_claude_block
upsert_managed_block "$target_root/.gitignore" \
  '# code-health:start' '# code-health:end' write_gitignore_block

if [[ -n $backup_dir && -d $backup_dir ]]; then
  [[ -f $backup_dir/$managed_marker ]] || \
    die "refusing to remove unmarked framework backup: $backup_dir"
  rm -rf -- "$backup_dir"
fi
framework_swapped=0

printf 'Code-health framework installed in %s\n' "$framework_dir"
printf 'Baseline collector: %s\n' \
  "$framework_dir/scripts/code-health/collect-baseline.sh"
