#!/usr/bin/env bash
################################################################################
# Copy biriscv-testing-ready to cadence-bitirme/Testcases/
# Usage: ./scripts/copy_to_cadence.sh
################################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/biriscv-testing-ready"
DEST_DIR="/home/ziyx/Masaüstü/Şükrü/cs401/riscv-extension/cadence-bitirme/Testcases/biriscv-testing-ready"

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; exit 1; }

# Check source exists
if [[ ! -d "$SOURCE_DIR" ]]; then
  log_error "Source directory not found: $SOURCE_DIR"
fi

log_info "Copying $SOURCE_DIR to $DEST_DIR..."

# Create destination parent if needed
mkdir -p "$(dirname "$DEST_DIR")"

# Copy with rsync (preserves structure, shows progress)
rsync -av --delete "$SOURCE_DIR/" "$DEST_DIR/" || log_error "Copy failed"

log_info "Copy complete!"
log_info "Destination: $DEST_DIR"
log_info "Files: $(find "$DEST_DIR/verilog" -name "*.v" | wc -l) .v files"
log_info "Verify: ls -la $DEST_DIR/"
