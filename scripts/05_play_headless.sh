#!/usr/bin/env bash
# 05 - 推理演示（headless，云服务器无显示器也能跑）
#
# 用法：
#   bash scripts/05_play_headless.sh
#   PLAY_MAX_STEPS=1000 bash scripts/05_play_headless.sh
#   POLICY=runs/cartpole/<时间戳>_PPO/checkpoints/agent_5000.pt bash scripts/05_play_headless.sh
#
# 产出：evidence/cloud/05_play_headless.log

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PLAY_MAX_STEPS="${PLAY_MAX_STEPS:-1000}"
LOG="$EVID/05_play_headless.log"

if [[ -z "${POLICY:-}" ]]; then
    RUN="$(latest_run)"
    POLICY="$(best_checkpoint "$RUN")"
    POLICY_REL="${POLICY#$ML_DIR/}"
else
    POLICY_REL="$POLICY"
fi

cd "$ML_DIR"

log "推理命令：uv run scripts/play.py --env cartpole --policy $POLICY_REL --headless"
{
    echo "================================================================"
    echo "host      : $(hostname)"
    echo "date      : $(date -Is)"
    echo "cwd       : $(pwd)"
    echo "command   : PLAY_MAX_STEPS=$PLAY_MAX_STEPS uv run scripts/play.py --env cartpole --policy $POLICY_REL --headless"
    echo "policy    : $POLICY_REL  ($(du -h "$POLICY" | cut -f1))"
    echo "================================================================"
    echo
} | tee "$LOG"

PLAY_MAX_STEPS="$PLAY_MAX_STEPS" uv run scripts/play.py \
    --env cartpole \
    --policy "$POLICY_REL" \
    --headless 2>&1 | tee -a "$LOG"

log "完成。一句话结果请取日志最后一行 [play] finished ..."
