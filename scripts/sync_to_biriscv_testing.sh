#!/usr/bin/env bash
################################################################################
# Sync Verilog files from biriscv repo to biriscv-testing-ready folder
# Usage: ./scripts/sync_to_biriscv_testing.sh [--push-to-remote]
#
# Description:
#   - Copies all src/ (core, dcache, icache, tcm, top) and tb/ folders
#   - Copies docs/, README.md, LICENSE
#   - Creates/updates ./biriscv-testing-ready folder
#   - Optionally pushes to cadence-bitirme/biriscv-testing remote
#
# Options:
#   --push-to-remote    After sync, commit and push to GitHub
#   --force             Force push (use with caution)
#
# Examples:
#   ./scripts/sync_to_biriscv_testing.sh                 # Just sync locally
#   ./scripts/sync_to_biriscv_testing.sh --push-to-remote  # Sync and push
################################################################################

set -euo pipefail

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READY_DIR="${REPO_ROOT}/biriscv-testing-ready"
REMOTE_URL="${REMOTE_URL:-git@github.com:cadence-bitirme/biriscv-testing.git}"
REMOTE_BRANCH="${REMOTE_BRANCH:-main}"
PUSH_TO_REMOTE=0
FORCE_PUSH=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --push-to-remote)
      PUSH_TO_REMOTE=1
      shift
      ;;
    --force)
      FORCE_PUSH=1
      shift
      ;;
    --remote)
      REMOTE_URL="$2"
      shift 2
      ;;
    --branch)
      REMOTE_BRANCH="$2"
      shift 2
      ;;
    -h|--help)
      head -n 20 "$0" | grep "^#"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Utility functions
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; exit 1; }

# Check git status
log_info "Checking git status in $REPO_ROOT..."
cd "$REPO_ROOT"
if [[ -n "$(git status --porcelain)" ]]; then
  log_warn "Working tree has uncommitted changes. Stash or commit them first."
  git status --short
  log_error "Aborting sync to avoid overwriting work."
fi

# Create target directory
log_info "Preparing $READY_DIR..."
mkdir -p "$READY_DIR"
cd "$READY_DIR"

# Initialize git if not already done
if [[ ! -d .git ]]; then
  log_info "Initializing git repo in $READY_DIR..."
  git init
  git config user.email "auto-sync@biriscv.local"
  git config user.name "biRISC-V Sync Bot"
fi

# Add remote if pushing
if [[ $PUSH_TO_REMOTE -eq 1 ]]; then
  log_info "Configuring remote: $REMOTE_URL"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$REMOTE_URL"
fi

# Sync source files (src/)
log_info "Syncing src/ (Verilog core files)..."
rsync -av --delete \
  "$REPO_ROOT/src/" \
  "$READY_DIR/src/" \
  || log_error "Failed to sync src/"

# Sync testbenches (tb/)
log_info "Syncing tb/ (testbenches)..."
rsync -av --delete \
  "$REPO_ROOT/tb/" \
  "$READY_DIR/tb/" \
  || log_error "Failed to sync tb/"

# Sync docs and config
log_info "Syncing docs/, README.md, LICENSE..."
rsync -av \
  "$REPO_ROOT/docs/" \
  "$READY_DIR/docs/" \
  2>/dev/null || true

cp "$REPO_ROOT/README.md" "$READY_DIR/README.md" 2>/dev/null || log_warn "README.md not found"
cp "$REPO_ROOT/LICENSE" "$READY_DIR/LICENSE" 2>/dev/null || log_warn "LICENSE not found"

# Create .gitignore for build artifacts
log_info "Creating .gitignore..."
cat > "$READY_DIR/.gitignore" << 'EOF'
# Build artifacts
*.o
*.elf
*.bin
*.vcd
*.out
*.vvp

# Simulation outputs
build/
output/
sim/
*.log

# IDEs
.vscode/
*.swp
*.swo
*~
.DS_Store

# Temporary files
/tmp/
*.tmp
EOF

# Stage and commit
cd "$READY_DIR"
log_info "Staging files..."
git add -A

# Check if there are changes to commit
if git diff --quiet --cached; then
  log_info "No changes to commit. Sync is up to date."
else
  COMMIT_MSG="Auto-sync: biriscv Verilog core and testbenches"
  log_info "Committing changes: '$COMMIT_MSG'"
  git commit -m "$COMMIT_MSG"
fi

# Push to remote if requested
if [[ $PUSH_TO_REMOTE -eq 1 ]]; then
  log_info "Pushing to $REMOTE_URL ($REMOTE_BRANCH)..."
  if [[ $FORCE_PUSH -eq 1 ]]; then
    git push --force origin HEAD:"$REMOTE_BRANCH"
    log_info "Force-pushed to remote (be careful!)"
  else
    git push origin HEAD:"$REMOTE_BRANCH"
  fi
  log_info "Push successful!"
fi

log_info "Sync complete. Ready folder: $READY_DIR"
log_info "Next steps:"
log_info "  - Review changes: cd $READY_DIR && git log --oneline -5"
log_info "  - To push manually: cd $READY_DIR && git push origin main"
log_info "  - Or use: ./scripts/sync_to_biriscv_testing.sh --push-to-remote"
