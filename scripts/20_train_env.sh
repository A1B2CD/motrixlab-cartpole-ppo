#!/usr/bin/env bash
# 20 - 训练任意环境（pendulum / acrobot / cartpole ...），并把训练目录快照成带标签的副本
#
# 为什么需要快照：skrl 每次都写 runs/<env>/<时间戳>_PPO/，A 组和 B 组的目录名只差时间戳，
# 很容易搞混。这里训练完立刻复制一份到 runs/week4/<env>_<tag>/，模型路径就能写死。
#
# 用法：
#   ENV=pendulum TAG=A bash scripts/20_train_env.sh          # A 组：默认奖励、默认参数
#   ENV=pendulum TAG=B bash scripts/20_train_env.sh          # B 组：先改代码再跑（见 22_pendulum_ab.sh）
#   ENV=acrobot   TAG=demo NUM_ENVS=512 bash scripts/20_train_env.sh
#   ENV=pendulum  TAG=A SEED=42 bash scripts/20_train_env.sh
#
# 产出：
#   evidence/week4/20_train_<env>_<tag>.log
#   motrixlab/runs/week4/<env>_<tag>/   （完整训练目录：checkpoints/ + events.out.tfevents.*）

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ENV="${ENV:?用法：ENV=pendulum TAG=A bash scripts/20_train_env.sh}"
TAG="${TAG:-$(date +%H%M%S)}"
NUM_ENVS="${NUM_ENVS:-}"
TIMESTEPS="${TIMESTEPS:-}"
SEED="${SEED:-}"
EXTRA="${EXTRA:-}"

W4="$REPO_ROOT/evidence/week4"
LOG="$W4/20_train_${ENV}_${TAG}.log"
SNAP_ROOT="$ML_DIR/runs/week4"
SNAP="$SNAP_ROOT/${ENV}_${TAG}"
mkdir -p "$W4" "$SNAP_ROOT"

cd "$ML_DIR"

CMD=(uv run scripts/train.py --env "$ENV")
if [[ -n "$NUM_ENVS" ]]; then CMD+=(--num-envs "$NUM_ENVS"); fi
if [[ -n "$TIMESTEPS" ]]; then CMD+=(--timesteps "$TIMESTEPS"); fi
if [[ -n "$SEED" ]]; then CMD+=(--seed "$SEED"); fi
if [[ -n "$EXTRA" ]]; then
    # shellcheck disable=SC2206
    EXTRA_ARR=($EXTRA)
    CMD+=("${EXTRA_ARR[@]}")
fi

{
    echo "================================================================"
    echo "env       : $ENV"
    echo "tag       : $TAG"
    echo "host      : $(hostname)"
    echo "date      : $(date -Is)"
    echo "cwd       : $(pwd)"
    echo "git       : $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo n/a)"
    echo "command   : ${CMD[*]}"
    echo "torch     : $(uv run --no-sync python -c 'import torch;print(torch.__version__, "cuda=", torch.cuda.is_available())' 2>/dev/null || echo n/a)"
    echo "================================================================"
} | tee "$LOG"

T0=$(date +%s)
"${CMD[@]}" 2>&1 | tee -a "$LOG"
T1=$(date +%s)

RUN="$(find "runs/$ENV" -maxdepth 1 -mindepth 1 -type d -name '*_PPO' | sort | tail -n 1)"
[[ -n "$RUN" ]] || die "没找到 runs/$ENV/*_PPO，训练可能失败了"

rm -rf "$SNAP"
mkdir -p "$SNAP"
cp -a "$RUN"/. "$SNAP"/

{
    echo
    echo "================================================================"
    echo "耗时      : $((T1 - T0)) s"
    echo "RUN_DIR   : ${RUN#$REPO_ROOT/}"
    echo "SNAPSHOT  : ${SNAP#$REPO_ROOT/}"
    echo "BEST      : ${SNAP#$REPO_ROOT/}/checkpoints/best_agent.pt"
    echo "checkpoints:"
    ls -lh "$SNAP/checkpoints" 2>/dev/null | sed 's/^/  /'
    echo "tfevents  :"
    ls -lh "$SNAP"/events.out.tfevents.* 2>/dev/null | sed 's/^/  /'
    echo "================================================================"
} | tee -a "$LOG"

log "下一步：ENV=$ENV TAG=$TAG SEED=0 bash scripts/21_record_episode.sh"
