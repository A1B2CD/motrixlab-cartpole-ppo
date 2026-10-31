#!/usr/bin/env bash
# 09 - 对比本地与云端两次运行，生成 evidence/comparison.md
#
# 用法：bash scripts/09_compare.sh
#
# 说明：只读证据文件，不需要 GPU，也不会改动任何证据。
#       run_all.sh 最后会自动调用本脚本。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$ML_DIR"
uv run --no-sync python "$REPO_ROOT/scripts/compare_runs.py" \
    --local "$REPO_ROOT/evidence/local-windows" \
    --cloud "$EVID" \
    --out "$REPO_ROOT/evidence"

log "完成：$REPO_ROOT/evidence/comparison.md"
