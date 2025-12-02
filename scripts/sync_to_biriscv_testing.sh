#!/usr/bin/env bash
################################################################################
# Sync Verilog files from biriscv repo to biriscv-testing-ready folder
# FLATTENS all .v files into a single verilog/ folder (no subfolders)
# Usage: ./scripts/sync_to_biriscv_testing.sh
################################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READY_DIR="${REPO_ROOT}/biriscv-testing-ready"
VERILOG_DIR="${READY_DIR}/verilog"

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; exit 1; }

# Check git status
log_info "Checking git status in $REPO_ROOT..."
cd "$REPO_ROOT"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "[WARN] Working tree has uncommitted changes."
  git status --short
  log_error "Aborting sync."
fi

# Create verilog directory
log_info "Preparing $VERILOG_DIR..."
rm -rf "$VERILOG_DIR"
mkdir -p "$VERILOG_DIR"

# Flatten and copy all .v files from src/
log_info "Copying all .v files from src/ (flattened)..."
find "$REPO_ROOT/src" -name "*.v" -type f | while read -r vfile; do
  filename=$(basename "$vfile")
  cp "$vfile" "$VERILOG_DIR/$filename"
done

FILE_COUNT=$(find "$VERILOG_DIR" -name "*.v" | wc -l)
log_info "Copied $FILE_COUNT .v files to $VERILOG_DIR"

# Initialize git if not already done
if [[ ! -d "$READY_DIR/.git" ]]; then
  log_info "Initializing git repo in $READY_DIR..."
  cd "$READY_DIR"
  git init
  git config user.email "auto-sync@biriscv.local"
  git config user.name "biRISC-V Sync Bot"
else
  cd "$READY_DIR"
fi

# Create .gitignore
cat > "$READY_DIR/.gitignore" << 'EOF'
*.o
*.elf
*.bin
*.vcd
*.out
*.vvp
build/
output/
sim/
*.log
.vscode/
*.swp
*~
.DS_Store
EOF

# Stage and commit
log_info "Staging files..."
git add -A

if git diff --quiet --cached; then
  log_info "No changes to commit. Sync is up to date."
else
  log_info "Committing changes..."
  git commit -m "Auto-sync: biriscv Verilog files (flattened)"
fi

log_info "Sync complete!"
log_info "Verilog files: $VERILOG_DIR ($FILE_COUNT files)"
log_info "List files: ls -la $VERILOG_DIR"
log_info "Push to remote: cd $READY_DIR && git push origin main"
