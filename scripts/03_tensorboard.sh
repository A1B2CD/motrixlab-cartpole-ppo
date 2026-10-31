#!/usr/bin/env bash
# 03 - 在服务器上启动 TensorBoard
#
# 用法：
#   bash scripts/03_tensorboard.sh              # 只监听 127.0.0.1，用 SSH 隧道访问（推荐）
#   HOST=0.0.0.0 bash scripts/03_tensorboard.sh # 监听所有网卡（需要平台开放端口）
#   PORT=6007 bash scripts/03_tensorboard.sh
#
# 产出：evidence/cloud/03_tensorboard.log、03_tensorboard.pid

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-6006}"
LOG="$EVID/03_tensorboard.log"
PIDFILE="$EVID/03_tensorboard.pid"

cd "$ML_DIR"

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    warn "TensorBoard 已在运行（PID $(cat "$PIDFILE")），先停止"
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    sleep 1
fi

log "启动：uv run tensorboard --logdir runs/cartpole --host $HOST --port $PORT"
{
    echo "================================================================"
    echo "host      : $(hostname)"
    echo "date      : $(date -Is)"
    echo "command   : uv run tensorboard --logdir runs/cartpole --host $HOST --port $PORT"
    echo "logdir    : $ML_DIR/runs/cartpole"
    echo "================================================================"
} > "$LOG"

nohup uv run tensorboard --logdir runs/cartpole --host "$HOST" --port "$PORT" >> "$LOG" 2>&1 &
echo $! > "$PIDFILE"

# 等待端口就绪
for _ in $(seq 1 30); do
    if grep -q "TensorBoard .* at http" "$LOG" 2>/dev/null; then break; fi
    sleep 1
done

if grep -q "TensorBoard .* at http" "$LOG" 2>/dev/null; then
    log "TensorBoard 已启动："
    grep "TensorBoard .* at http" "$LOG" | tail -n 1
else
    warn "30 秒内没看到启动完成日志，请检查 $LOG"
fi

cat <<EOF

----------------------------------------------------------------
本机浏览器访问方式（不要直接在服务器上开浏览器）：

  1) 在你自己的电脑上开一个终端，建立 SSH 隧道：
       ssh -N -L ${PORT}:127.0.0.1:${PORT} <user>@<server-ip> -p <port>

  2) 然后本机浏览器打开：
       http://127.0.0.1:${PORT}

  3) 截图 SCALARS 页签的 Reward / Loss 曲线，存成
       evidence/cloud/03_tensorboard_reward_loss.png

  停止 TensorBoard：
       bash scripts/03_tensorboard_stop.sh
----------------------------------------------------------------
EOF

log "日志：$LOG"
