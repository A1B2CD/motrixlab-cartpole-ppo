#!/usr/bin/env bash
# 24 - 三个 Demo 的训练 + 回放（CartPole 沿用第二周结果，这里只跑 Pendulum / Acrobot）
#
# 用法：
#   bash scripts/24_demo_train_record.sh
#   NUM_ENVS=512 bash scripts/24_demo_train_record.sh      # 算力不够时减少并行环境
#   ENVS="pendulum" bash scripts/24_demo_train_record.sh   # 只跑一个
#
# 产出（每个任务 5 项证据）：
#   1. 训练/回放命令   → evidence/week4/20_train_<env>_demo.log 里的 command 行 + 21_record_*.log
#   2. 训练结束日志    → 20_train_<env>_demo.log 末尾
#   3. 模型路径        → motrixlab/runs/week4/<env>_demo/checkpoints/best_agent.pt
#   4. TensorBoard 曲线 → motrixlab/runs/week4/<env>_demo/ 下的 events.out.tfevents.*
#   5. 一个完整回合视频 → evidence/week4/video/<env>_demo_seed0.mp4

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ENVS="${ENVS:-pendulum acrobot}"
export NUM_ENVS="${NUM_ENVS:-}"

for env in $ENVS; do
    log "==== $env：训练 ===="
    ENV="$env" TAG=demo bash "$REPO_ROOT/scripts/20_train_env.sh"

    log "==== $env：回放一个完整回合 ===="
    ENV="$env" TAG=demo SEED=0 bash "$REPO_ROOT/scripts/21_record_episode.sh"
done

log "完成。TensorBoard 查看：uv run tensorboard --logdir runs/week4 --port 6006"
