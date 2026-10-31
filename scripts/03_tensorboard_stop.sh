#!/usr/bin/env bash
# 03b - 停止 TensorBoard
#
# 用法：bash scripts/03_tensorboard_stop.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PIDFILE="$EVID/03_tensorboard.pid"

if [[ -f "$PIDFILE" ]]; then
    PID="$(cat "$PIDFILE")"
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" && log "已停止 TensorBoard（PID $PID）"
    else
        warn "PID $PID 已不存在"
    fi
    rm -f "$PIDFILE"
else
    # 兜底：按端口找
    if command -v lsof >/dev/null 2>&1; then
        lsof -ti:6006 | xargs -r kill && log "已按端口 6006 停止 TensorBoard"
    else
        warn "没有 pid 文件，也没有 lsof"
    fi
fi
