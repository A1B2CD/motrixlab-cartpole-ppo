#!/usr/bin/env bash
# 公共变量与函数，被 scripts/*.sh source。
# 用法：source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ML_DIR="$REPO_ROOT/motrixlab"
EVID="$REPO_ROOT/evidence/cloud"
RUNS_DIR="$ML_DIR/runs/cartpole"

export UV_LINK_MODE="${UV_LINK_MODE:-copy}"
export UV_HTTP_TIMEOUT="${UV_HTTP_TIMEOUT:-180}"
export PYTHONUNBUFFERED=1

mkdir -p "$EVID"

log()  { printf '\n\033[1;36m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

# 取最新的训练目录（按名字里的时间戳排序，时间戳格式 26-10-31_18-14-47-731131_PPO）
latest_run() {
    local d
    d="$(find "$RUNS_DIR" -maxdepth 1 -mindepth 1 -type d -name '*_PPO' 2>/dev/null | sort | tail -n 1)"
    [[ -n "$d" ]] || die "在 $RUNS_DIR 下没找到 *_PPO 训练目录，请先跑 02_train.sh"
    printf '%s\n' "$d"
}

# 取某个 run 下最好的 checkpoint
best_checkpoint() {
    local run="$1"
    if [[ -f "$run/checkpoints/best_agent.pt" ]]; then
        printf '%s\n' "$run/checkpoints/best_agent.pt"
    elif [[ -f "$run/checkpoints/best_agent.pickle" ]]; then
        printf '%s\n' "$run/checkpoints/best_agent.pickle"
    else
        local f
        f="$(find "$run/checkpoints" -name 'agent_*' 2>/dev/null | sort -V | tail -n 1)"
        [[ -n "$f" ]] || die "$run/checkpoints 下没有任何 checkpoint"
        printf '%s\n' "$f"
    fi
}
