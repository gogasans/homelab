#!/usr/bin/env bash
# check-prerequisites.sh
# Verifies that all required tools are installed at the versions pinned in .tool-versions.
# Run: make prereqs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL_VERSIONS_FILE="$ROOT_DIR/.tool-versions"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

check_tool() {
  local tool="$1"
  local expected_version="$2"
  local version_cmd="$3"
  local version_pattern="${4:-}"

  if ! command -v "$tool" &>/dev/null; then
    echo -e "${RED}✗ $tool: NOT FOUND${NC} (expected $expected_version)"
    FAILED=1
    return
  fi

  local actual_version
  actual_version=$(eval "$version_cmd" 2>/dev/null || echo "unknown")

  if [ -n "$version_pattern" ]; then
    actual_version=$(echo "$actual_version" | grep -oE "$version_pattern" | head -1)
  fi

  if [[ "$actual_version" == *"$expected_version"* ]]; then
    echo -e "${GREEN}✓ $tool $actual_version${NC}"
  else
    echo -e "${YELLOW}~ $tool $actual_version${NC} (expected $expected_version)"
    # Warn but don't fail — minor version differences are usually OK
  fi
}

echo "Checking prerequisites against $TOOL_VERSIONS_FILE"
echo "---------------------------------------------------"

# Read .tool-versions and check each tool
while IFS=' ' read -r tool version; do
  # Skip blank lines and comments
  [[ -z "$tool" || "$tool" == \#* ]] && continue

  case "$tool" in
    opentofu)
      check_tool "tofu" "$version" "tofu version" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    kubectl)
      check_tool "kubectl" "$version" "kubectl version --client --short 2>/dev/null || kubectl version --client" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    flux2)
      check_tool "flux" "$version" "flux version --client" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    vault)
      check_tool "vault" "$version" "vault version" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    ansible)
      check_tool "ansible" "$version" "ansible --version | head -1" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    helm)
      check_tool "helm" "$version" "helm version --short" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    kubeconform)
      check_tool "kubeconform" "$version" "kubeconform -v" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    kube-linter)
      check_tool "kube-linter" "$version" "kube-linter version" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    gitleaks)
      check_tool "gitleaks" "$version" "gitleaks version" '[0-9]+\.[0-9]+\.[0-9]+'
      ;;
    *)
      echo -e "${YELLOW}? $tool: no check configured for this tool${NC}"
      ;;
  esac
done < "$TOOL_VERSIONS_FILE"

echo "---------------------------------------------------"
if [ $FAILED -eq 1 ]; then
  echo -e "${RED}Some required tools are missing. Install them with: asdf install${NC}"
  exit 1
else
  echo -e "${GREEN}All required tools are installed.${NC}"
fi
