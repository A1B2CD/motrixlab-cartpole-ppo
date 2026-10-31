#!/usr/bin/env bash
# 06 - 推理演示（xvfb 虚拟显示 + 截图，能出仿真画面）
#
# 前提：01_bootstrap.sh 已装好 xvfb / mesa-vulkan-drivers / imagemagick。
# 说明：Bevy 走 Vulkan，云上通常由 mesa 的 lavapipe 软件渲染兜底，
#       速度慢但足够截几张图。渲染失败时脚本不会中断，headless 证据仍然有效。
#
# 用法：bash scripts/06_play_xvfb.sh
#
# 产出：
#   evidence/cloud/06_play_xvfb.log
#   evidence/cloud/06_play_xvfb.png      （成功时才有）

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DISPLAY_NUM="${DISPLAY_NUM:-99}"
PLAY_MAX_STEPS="${PLAY_MAX_STEPS:-600}"
SCREEN="${SCREEN:-1280x720x24}"
LOG="$EVID/06_play_xvfb.log"
SHOT="$EVID/06_play_xvfb.png"

if ! command -v Xvfb >/dev/null 2>&1; then
    warn "没装 Xvfb，跳过。先跑 bash scripts/01_bootstrap.sh"
    exit 0
fi

if [[ -z "${POLICY:-}" ]]; then
    RUN="$(latest_run)"
    POLICY="$(best_checkpoint "$RUN")"
    POLICY_REL="${POLICY#$ML_DIR/}"
else
    POLICY_REL="$POLICY"
fi

cd "$ML_DIR"

log "启动虚拟显示 :$DISPLAY_NUM ($SCREEN)"
Xvfb ":$DISPLAY_NUM" -screen 0 "$SCREEN" > "$EVID/06_xvfb.log" 2>&1 &
XVFB_PID=$!
trap 'kill "$XVFB_PID" 2>/dev/null || true' EXIT
sleep 2

export DISPLAY=":$DISPLAY_NUM"
export LIBGL_ALWAYS_SOFTWARE=1
export WGPU_BACKEND="${WGPU_BACKEND:-vulkan}"

{
    echo "================================================================"
    echo "host      : $(hostname)"
    echo "date      : $(date -Is)"
    echo "display   : $DISPLAY  ($SCREEN)"
    echo "command   : PLAY_MAX_STEPS=$PLAY_MAX_STEPS uv run scripts/play.py --env cartpole --policy $POLICY_REL"
    echo "policy    : $POLICY_REL"
    echo "================================================================"
    echo
} | tee "$LOG"

PLAY_MAX_STEPS="$PLAY_MAX_STEPS" uv run scripts/play.py \
    --env cartpole \
    --policy "$POLICY_REL" 2>&1 | tee -a "$LOG" &
PLAY_PID=$!

# 等窗口出来再截图
sleep 12
if kill -0 "$PLAY_PID" 2>/dev/null; then
    if command -v import >/dev/null 2>&1; then
        import -display ":$DISPLAY_NUM" -window root "$SHOT" 2>>"$LOG" \
            && log "已截图：$SHOT" \
            || warn "截图失败"
    else
        warn "没装 imagemagick，无法截图"
    fi
else
    warn "play.py 已经退出，可能渲染失败；详见 $LOG"
fi

wait "$PLAY_PID" || warn "play.py 返回非 0（软件渲染失败属正常，headless 证据仍然有效）"

log "完成"
