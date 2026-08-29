#!/usr/bin/env bash

set -u
set -o pipefail
IFS=$'\n\t'
export LC_ALL=C

usage() {
  printf 'Usage: %s [output-directory]\n' "${0##*/}"
  printf 'Collects safe, read-only repository metadata and tool availability.\n'
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  printf 'Error: run this script inside a Git repository.\n' >&2
  exit 1
fi
repo_root=$(cd "$repo_root" && pwd -P)
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
script_path="$script_dir/${BASH_SOURCE[0]##*/}"
case $script_path in
  "$repo_root"/*) collector_path=${script_path#"$repo_root"/} ;;
  *) collector_path=$script_path ;;
esac

if [[ $# -eq 1 ]]; then
  if [[ $1 = /* ]]; then
    output_dir=$1
  else
    output_dir="$repo_root/$1"
  fi
else
  timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
  output_dir="$repo_root/.code-health/runs/baseline-$timestamp-$$"
fi

if [[ -e $output_dir ]]; then
  printf 'Error: output path already exists: %s\n' "$output_dir" >&2
  exit 2
fi

mkdir -p "$output_dir" || exit 1
cd "$repo_root" || exit 1

generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
if ! head_commit=$(git rev-parse --verify HEAD 2>/dev/null); then
  head_commit=unborn
fi

{
  printf '# Code-health baseline\n\n'
  printf -- '- Generated: `%s`\n' "$generated_at"
  printf -- '- Repository root: `%s`\n' "$repo_root"
  printf -- '- Collector: `%s`\n\n' "$collector_path"
  printf 'This inventory is read-only evidence. It does not by itself establish a finding.\n'
} > "$output_dir/README.md"

{
  printf 'generated_at=%s\n' "$generated_at"
  printf 'repository_root=%s\n' "$repo_root"
  printf 'branch=%s\n' "$(git branch --show-current 2>/dev/null || true)"
  printf 'head=%s\n' "$head_commit"
  printf 'operating_system=%s\n' "$(uname -s 2>/dev/null || true)"
  printf 'kernel_release=%s\n' "$(uname -r 2>/dev/null || true)"
  printf 'architecture=%s\n' "$(uname -m 2>/dev/null || true)"
} > "$output_dir/repository.txt"

git status --short > "$output_dir/git-status.txt" 2>&1
git log --oneline --decorate -20 > "$output_dir/recent-history.txt" 2>&1
git ls-files | sort > "$output_dir/tracked-files.txt"

: > "$output_dir/manifests.txt"
: > "$output_dir/ci-files.txt"
while IFS= read -r tracked_path; do
  case "/$tracked_path" in
    */package.json|*/package-lock.json|*/pnpm-lock.yaml|*/yarn.lock|*/bun.lock|*/bun.lockb|*/deno.json|*/deno.jsonc|*/pyproject.toml|*/requirements.txt|*/requirements-*.txt|*/Pipfile|*/Pipfile.lock|*/poetry.lock|*/uv.lock|*/go.mod|*/go.sum|*/Cargo.toml|*/Cargo.lock|*/pom.xml|*/build.gradle|*/build.gradle.kts|*/settings.gradle|*/settings.gradle.kts|*/Gemfile|*/Gemfile.lock|*/composer.json|*/composer.lock|*/Dockerfile|*/Dockerfile.*|*/docker-compose.yml|*/docker-compose.yaml|*/compose.yml|*/compose.yaml|*/Makefile|*/Taskfile.yml|*/Taskfile.yaml)
      printf '%s\n' "$tracked_path" >> "$output_dir/manifests.txt"
      ;;
  esac
  case "/$tracked_path" in
    */.github/workflows/*.yml|*/.github/workflows/*.yaml|*/.gitlab-ci.yml|*/Jenkinsfile|*/azure-pipelines.yml|*/bitbucket-pipelines.yml|*/.circleci/config.yml)
      printf '%s\n' "$tracked_path" >> "$output_dir/ci-files.txt"
      ;;
  esac
done < "$output_dir/tracked-files.txt"

record_version() {
  local tool=$1
  shift
  if command -v "$tool" >/dev/null 2>&1; then
    printf '\n[%s]\n' "$tool"
    "$@" 2>&1 | sed -n '1,4p'
    printf 'status=%s\n' "${PIPESTATUS[0]}"
  else
    printf '\n[%s]\nmissing\n' "$tool"
  fi
}

{
  record_version git git --version
  record_version node node --version
  record_version npm npm --version
  record_version pnpm pnpm --version
  record_version yarn yarn --version
  record_version bun bun --version
  record_version deno deno --version
  record_version python3 python3 --version
  record_version pytest pytest --version
  record_version ruff ruff --version
  record_version mypy mypy --version
  record_version go go version
  record_version rustc rustc --version
  record_version cargo cargo --version
  record_version java java -version
  record_version mvn mvn --version
  record_version gradle gradle --version
  record_version dotnet dotnet --version
  record_version ruby ruby --version
  record_version bundle bundle --version
  record_version php php --version
  record_version composer composer --version
  record_version docker docker --version
  record_version semgrep semgrep --version
  record_version trivy trivy --version
} > "$output_dir/tool-versions.txt"

{
  printf '# Suggested checks\n\n'
  printf 'Review repository scripts and configuration before running these commands.\n\n'

  if grep -Eq '(^|/)package.json$' "$output_dir/manifests.txt"; then
    printf -- '- JavaScript/TypeScript: use the lockfile-selected package manager to run configured test, lint, type-check, build, and audit scripts.\n'
  fi
  if grep -Eq '(^|/)(pyproject.toml|requirements[^/]*\\.txt|Pipfile)$' "$output_dir/manifests.txt"; then
    printf -- '- Python: run configured tests, lint, type checks, and dependency audit in the project environment.\n'
  fi
  if grep -Eq '(^|/)go\\.mod$' "$output_dir/manifests.txt"; then
    printf -- '- Go: `go test ./...` and `go vet ./...`.\n'
  fi
  if grep -Eq '(^|/)Cargo\\.toml$' "$output_dir/manifests.txt"; then
    printf -- '- Rust: `cargo test` and the repository-configured format and Clippy checks.\n'
  fi
  if grep -Eq '(^|/)(pom\\.xml|build\\.gradle|build\\.gradle\\.kts)$' "$output_dir/manifests.txt"; then
    printf -- '- JVM: use the checked-in Maven or Gradle wrapper and configured verification tasks.\n'
  fi
  if grep -Eq '(^|/)Gemfile$' "$output_dir/manifests.txt"; then
    printf -- '- Ruby: run the repository-configured Bundler test, lint, and audit commands.\n'
  fi
  if grep -Eq '(^|/)composer\\.json$' "$output_dir/manifests.txt"; then
    printf -- '- PHP: run the repository-configured Composer test, static-analysis, and audit commands.\n'
  fi
  if [[ ! -s $output_dir/manifests.txt ]]; then
    printf -- '- No recognized project manifest was found. Identify the repository-defined validation commands manually.\n'
  fi
} > "$output_dir/suggested-checks.md"

printf 'Baseline written to %s\n' "$output_dir"
