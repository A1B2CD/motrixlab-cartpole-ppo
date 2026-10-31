#!/usr/bin/env bash
# 02 - 训练 CartPole PPO，产出 runs/cartpole/<时间戳>_PPO/
#
# 用法：
#   bash scripts/02_train.sh                 # 默认 64 并行环境（与本地跑通的一致）
#   NUM_ENVS=256 bash scripts/02_train.sh
#   EXACT=1 bash scripts/02_train.sh         # 严格只跑作业原命令：uv run scripts/train.py --env cartpole
#
# 产出：evidence/cloud/02_train_console.log

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NUM_ENVS="${NUM_ENVS:-64}"
LOG="$EVID/02_train_console.log"

cd "$ML_DIR"

if [[ "${EXACT:-0}" == "1" ]]; then
    CMD=(uv run scripts/train.py --env cartpole)
else
    CMD=(uv run scripts/train.py --env cartpole --num-envs "$NUM_ENVS")
fi

log "训练命令：${CMD[*]}"
{
    echo "================================================================"
    echo "host      : $(hostname)"
    echo "date      : $(date -Is)"
    echo "cwd       : $(pwd)"
    echo "command   : ${CMD[*]}"
    echo "torch     : $(uv run --no-sync python -c 'import torch;print(torch.__version__, "cuda=", torch.cuda.is_available())')"
    echo "================================================================"
    echo
} | tee "$LOG"

# 训练本身耗时较短（5000 timesteps），前台跑完即可
"${CMD[@]}" 2>&1 | tee -a "$LOG"

RUN="$(latest_run)"
log "训练完成，输出目录：$RUN"

{
    echo
    echo "================================================================"
    echo "RUN_DIR   : ${RUN#$REPO_ROOT/}"
    echo "checkpoints:"
    ls -lh "$RUN/checkpoints" | sed 's/^/  /'
    echo "tfevents  :"
    ls -lh "$RUN"/events.out.tfevents.* | sed 's/^/  /'
    echo "================================================================"
} | tee -a "$LOG"

log "下一步：bash scripts/03_tensorboard.sh"
