#!/usr/bin/env bash
# 21 - 录制「一个完整回合」：ffmpeg 抓屏出 mp4 + 逐帧 CSV（角度可离线核算）
#
# 一个完整回合 = 从回合开始到环境自动重置为止。步数由 max_episode_seconds / ctrl_dt 决定：
#   cartpole 1000 步（10 s / 0.01 s）
#   pendulum  400 步（10 s / 0.025 s）
#   acrobot   500 步（10 s / 0.02 s）
# play.py 用 --num-envs 1 只跑一个环境，--seed 固定初始姿态（A/B 两组同 seed 起点相同）。
#
# 用法：
#   ENV=pendulum TAG=A SEED=0 bash scripts/21_record_episode.sh
#   ENV=pendulum TAG=B SEED=2 POLICY=runs/week4/pendulum_B/checkpoints/best_agent.pt bash scripts/21_record_episode.sh
#   ENV=acrobot TAG=demo SEED=0 STEPS=500 bash scripts/21_record_episode.sh
#
# 依赖：ffmpeg（sudo apt-get install -y ffmpeg）、KDE 桌面（DISPLAY 默认 :20）
#
# 产出：
#   evidence/week4/video/<env>_<tag>_seed<seed>.mp4     成片（一个完整回合）
#   evidence/week4/csv/<env>_<tag>_seed<seed>.csv       逐帧 obs/reward/done
#   evidence/week4/21_record_<env>_<tag>_seed<seed>.log

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ENV="${ENV:?用法：ENV=pendulum TAG=A SEED=0 bash scripts/21_record_episode.sh}"
TAG="${TAG:?需要 TAG，例如 A / B / demo}"
SEED="${SEED:-0}"

W4="$REPO_ROOT/evidence/week4"
VID="$W4/video"
CSV="$W4/csv"
mkdir -p "$VID" "$CSV"

case "$ENV" in
    cartpole) STEPS_DEFAULT=1000 ;;
    pendulum) STEPS_DEFAULT=400  ;;
    acrobot)  STEPS_DEFAULT=500  ;;
    *)        STEPS_DEFAULT=400  ;;
esac
STEPS="${STEPS:-$STEPS_DEFAULT}"

DISPLAY_ID="${DISPLAY_ID:-${DISPLAY:-:20}}"
RATE="${RATE:-30}"
WAIT_READY="${WAIT_READY:-60}"   # 等窗口出现的最长秒数

POLICY="${POLICY:-$ML_DIR/runs/week4/${ENV}_${TAG}/checkpoints/best_agent.pt}"
[[ -f "$POLICY" ]] || die "找不到模型：$POLICY（先跑 20_train_env.sh，或用 POLICY=... 指定）"
POLICY_REL="${POLICY#$ML_DIR/}"

OUT="$VID/${ENV}_${TAG}_seed${SEED}.mp4"
CSV_OUT="$CSV/${ENV}_${TAG}_seed${SEED}.csv"
LOG="$W4/21_record_${ENV}_${TAG}_seed${SEED}.log"
FFLOG="$W4/21_ffmpeg_${ENV}_${TAG}_seed${SEED}.log"

command -v ffmpeg >/dev/null 2>&1 || die "缺 ffmpeg：sudo apt-get install -y ffmpeg"
[[ -n "${DISPLAY_ID:-}" ]] || die "没有 DISPLAY，抓屏需要图形桌面（本机 KDE 一般是 :20）"

cd "$ML_DIR"

{
    echo "================================================================"
    echo "env       : $ENV"
    echo "tag       : $TAG"
    echo "seed      : $SEED"
    echo "steps     : $STEPS   （一个完整回合）"
    echo "policy    : $POLICY_REL"
    echo "display   : $DISPLAY_ID  @ ${RATE}fps"
    echo "date      : $(date -Is)"
    echo "command   : PLAY_MAX_STEPS=$STEPS PLAY_LOG_CSV=<csv> uv run scripts/play.py --env $ENV --policy $POLICY_REL --num-envs 1 --seed $SEED"
    echo "================================================================"
} | tee "$LOG"

rm -f "$OUT" "$CSV_OUT"

# 1) 先起仿真（窗口由 NpRenderer 创建）
PLAY_MAX_STEPS="$STEPS" PLAY_LOG_CSV="$CSV_OUT" \
    uv run scripts/play.py --env "$ENV" --policy "$POLICY_REL" --num-envs 1 --seed "$SEED" \
    > "$LOG.play" 2>&1 &
PLAY_PID=$!
trap 'kill "$PLAY_PID" 2>/dev/null || true' EXIT

# 2) 等 play.py 把环境建好（日志里出现 "[play] env="），窗口这时已经在屏幕上
READY=0
for _ in $(seq 1 "$((WAIT_READY * 5))"); do
    if grep -q "\[play\] env=" "$LOG.play" 2>/dev/null; then READY=1; break; fi
    if ! kill -0 "$PLAY_PID" 2>/dev/null; then break; fi
    sleep 0.2
done
if [[ "$READY" != "1" ]]; then
    cat "$LOG.play" | tee -a "$LOG"
    die "play.py 没进入回放循环（渲染失败？）。日志：$LOG.play"
fi
sleep 0.5

# 3) 开始抓屏；回合结束 play.py 自己退出，我们再收尾
# -t 只是兜底：正常情况下 play.py 退出后我们主动 kill。软件渲染时 400 步可能要跑 40 s+，
# 这里按最低 5 fps 估，避免把回合尾巴切掉。
DUR_MAX=$(( STEPS / 5 + 60 ))
ffmpeg -y -loglevel warning -f x11grab -framerate "$RATE" -i "$DISPLAY_ID" \
    -t "$DUR_MAX" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT" > "$FFLOG" 2>&1 &
FFPID=$!

# 4) 收尾：play.py 打印 "[play] finished" 时窗口还在；等到进程真正退出时 Bevy 窗口
#    已经销毁，再录就是桌面了（旧版这里还多 sleep 1，视频尾部 2~4 s 都是桌面）。
#    所以一看到 finished 就停录，让最后一帧就是回合最后一帧。
FINISHED=0
for _ in $(seq 1 1200); do
    if grep -q "\[play\] finished" "$LOG.play" 2>/dev/null; then FINISHED=1; break; fi
    if ! kill -0 "$PLAY_PID" 2>/dev/null; then break; fi
    sleep 0.05
done
[[ "$FINISHED" == "1" ]] || warn "没等到 [play] finished（可能提前退出），按进程退出收尾"

kill -INT "$FFPID" 2>/dev/null || true
wait "$FFPID" 2>/dev/null || true
wait "$PLAY_PID" || warn "play.py 返回非 0（多半是关窗时 Bevy 崩溃，不影响证据），检查 $LOG.play"

cat "$LOG.play" >> "$LOG"
trap - EXIT

[[ -s "$OUT" ]] || die "没生成视频，看 $FFLOG"
[[ -s "$CSV_OUT" ]] || die "没生成逐帧 CSV，看 $LOG.play"

DUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" 2>/dev/null || echo '?')"

{
    echo
    echo "================================================================"
    echo "视频     : ${OUT#$REPO_ROOT/}   ($(du -h "$OUT" | cut -f1), 时长 ${DUR}s)"
    echo "逐帧 CSV : ${CSV_OUT#$REPO_ROOT/}   ($(wc -l < "$CSV_OUT") 行)"
    echo "ffmpeg   : ${FFLOG#$REPO_ROOT/}"
    echo "================================================================"
} | tee -a "$LOG"

# 时长接近兜底值 = 视频被 -t 截断，回合尾巴没录到
if [[ "$DUR" != "?" ]] && awk "BEGIN{exit !($DUR >= $DUR_MAX - 2)}"; then
    warn "视频时长 ${DUR}s 已达到兜底上限 ${DUR_MAX}s，可能没录完整回合；用 STEPS 更大的值或提高 RATE 重录"
fi

log "角度核算：python3 scripts/23_analyze_episode.py --env $ENV --csv ${CSV_OUT#$REPO_ROOT/}"
