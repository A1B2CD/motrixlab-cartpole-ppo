#!/usr/bin/env bash
# 04 - 从 tfevents 导出 scalar 数据与曲线图（服务器上无浏览器也能出图）
#
# 用法：bash scripts/04_export_scalars.sh
#
# 产出：
#   evidence/cloud/04_scalars.csv
#   evidence/cloud/04_reward_curve.png
#   evidence/cloud/04_loss_curve.png
#   evidence/cloud/04_reward_and_loss.png

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$ML_DIR"
uv run --no-sync python "$REPO_ROOT/scripts/export_scalars.py" --runs-dir "$RUNS_DIR" --out "$EVID"

log "完成，文件在 $EVID"
