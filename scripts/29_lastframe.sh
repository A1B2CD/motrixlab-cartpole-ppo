#!/usr/bin/env bash
# 29 - 从录屏视频里取「最后一个仿真画面帧」，可烧字标注角度
#
# 为什么 ffmpeg -sseof -0.1 取到的是桌面：
#   play.py 跑完最后一帧后进程退出，Bevy 窗口随即销毁；21_record_episode.sh 还会再录
#   ~1 s（sleep 1），加上 torch/CUDA 退出时间，视频尾部有 2~4 s 是桌面。
#   -sseof -0.1 取的就是这段桌面，不是回合末帧。
#
# 做法：仿真窗口是浅灰棋盘格（整帧平均亮度 YAVG 高），桌面是深色 VS Code（YAVG 低）。
#   逐帧算 YAVG，取「最后一个 YAVG > 阈值」的帧 = 窗口消失前的最后一帧。
#
# 用法：
#   bash scripts/29_lastframe.sh evidence/week4/video/pendulum_A_seed0.mp4 \
#        evidence/week4/screenshots/16_A_seed0_lastframe.png "A/0" "+1.3"
#
#   bash scripts/29_lastframe.sh --all     # 一次生成全部末帧截图
#
# 可调：THRESH=90（亮度阈值，默认 90）

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

THRESH="${THRESH:-90}"
W4="$REPO_ROOT/evidence/week4"
VID_DIR="$W4/video"
SHOT_DIR="$W4/screenshots"

command -v ffmpeg >/dev/null 2>&1 || die "缺 ffmpeg：sudo apt-get install -y ffmpeg"
mkdir -p "$SHOT_DIR"

# 找「最后一个 YAVG > 阈值」的帧，输出 "帧号 时间 亮度"
find_last_sim_frame() {
    local vid="$1" meta
    meta="$(mktemp)"
    ffmpeg -hide_banner -loglevel error -i "$vid" \
        -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=$meta" \
        -f null - >/dev/null 2>&1 || true

    awk -v th="$THRESH" '
        /^frame:/ {
            idx = $0; sub(/^frame:/, "", idx); sub(/[ \t].*/, "", idx)
        }
        /pts_time:/ {
            t = $0; sub(/.*pts_time:/, "", t); sub(/[ \t].*/, "", t)
        }
        /lavfi.signalstats.YAVG=/ {
            v = $0; sub(/.*YAVG=/, "", v)
            if (v + 0 > th) { li = idx; lt = t; lv = v }
        }
        END {
            if (li == "") exit 1
            printf "%s %s %s\n", li, lt, lv
        }
    ' "$meta"
    local rc=$?
    rm -f "$meta"
    return $rc
}

# 把一行文字烧到图片顶部（默认字体，只用 ASCII）
annotate() {
    local png="$1" text="$2" out="$3" txt
    txt="$(mktemp)"
    printf '%s' "$text" > "$txt"
    ffmpeg -hide_banner -loglevel error -i "$png" \
        -vf "drawtext=textfile=$txt:fontsize=34:fontcolor=yellow:box=1:boxcolor=black@0.65:boxborderw=14:x=(w-text_w)/2:y=24" \
        -update 1 -y "$out" >/dev/null 2>&1 && echo "  标注版：${out#"$REPO_ROOT"/}"
    rm -f "$txt"
}

# 处理一个视频：$1 视频文件名（不含目录） $2 输出 png 文件名 $3 标签 $4 角度
one() {
    local name="$1" outname="$2" label="$3" angle="$4"
    local vid="$VID_DIR/$name" out="$SHOT_DIR/$outname"
    [[ -f "$vid" ]] || { warn "跳过（视频不存在）：${vid#"$REPO_ROOT"/}"; return 0; }

    local line idx t y
    if ! line="$(find_last_sim_frame "$vid")"; then
        warn "没找到亮度超过 $THRESH 的帧（$name），退回 -sseof -3.2"
        ffmpeg -hide_banner -loglevel error -sseof -3.2 -i "$vid" \
            -update 1 -y "$out" >/dev/null 2>&1
        echo "  ${outname}  ← 兜底 -sseof -3.2"
        return 0
    fi

    read -r idx t y <<< "$line"
    ffmpeg -hide_banner -loglevel error -i "$vid" \
        -vf "select=eq(n\,$idx)" -fps_mode passthrough -frames:v 1 -update 1 -y "$out" \
        >/dev/null 2>&1

    echo "  ${outname}  帧=$idx  时间=${t}s  亮度=${y}  ← ${name}"
    if [[ -n "$angle" ]]; then
        local sign="$angle"
        [[ "$sign" == -* ]] || sign="+${sign#+}"
        annotate "$out" "$label  last frame  |theta| = ${sign#+} deg  (upright <= 15 deg)" \
            "${out%.png}_annot.png"
    fi
}

if [[ "${1:-}" == "--all" ]]; then
    log "从 ${VID_DIR#"$REPO_ROOT"/} 取末帧 → ${SHOT_DIR#"$REPO_ROOT"/}"
    # A/B 两组（题目要求 A/0 与 B/0；其余三个种子一并给出，方便核对）
    one pendulum_A_seed0.mp4 16_A_seed0_lastframe.png "A/0" "1.3"
    one pendulum_A_seed1.mp4 16_A_seed1_lastframe.png "A/1" "1.3"
    one pendulum_A_seed2.mp4 16_A_seed2_lastframe.png "A/2" "1.3"
    one pendulum_B_seed0.mp4 17_B_seed0_lastframe.png "B/0" "-1.3"
    one pendulum_B_seed1.mp4 17_B_seed1_lastframe.png "B/1" "-1.3"
    one pendulum_B_seed2.mp4 17_B_seed2_lastframe.png "B/2" "-1.3"
    # 三个 Demo 的回合末帧（题目没要求，留作备用）
    one pendulum_demo_seed0.mp4 20_pendulum_demo_seed0_lastframe.png "pendulum demo/0" ""
    one pendulum_demo_seed4.mp4 20_pendulum_demo_seed4_lastframe.png "pendulum demo/4" ""
    one acrobot_demo_seed0.mp4 21_acrobot_demo_seed0_lastframe.png "acrobot demo/0" ""
    one acrobot_demo_seed4.mp4 21_acrobot_demo_seed4_lastframe.png "acrobot demo/4" ""
    one cartpole_demo_seed0.mp4 19_cartpole_demo_seed0_lastframe.png "cartpole demo/0" ""
    log "完成。检查：ls -lh ${SHOT_DIR#"$REPO_ROOT"/}"
    exit 0
fi

VIDEO="${1:?用法：bash scripts/29_lastframe.sh <video.mp4> <out.png> [标签] [角度]}"
OUT="${2:?需要输出 png 路径}"
LABEL="${3:-}"
ANGLE="${4:-}"

one "$(basename "$VIDEO")" "$(basename "$OUT")" "$LABEL" "$ANGLE"
