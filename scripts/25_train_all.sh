#!/usr/bin/env bash
# 25 - 一次性跑完第 4 周所有训练（不录屏），跑完统一列出模型路径
#
# 用法：
#   bash scripts/25_train_all.sh
#   ACROBOT_ENVS=1024 bash scripts/25_train_all.sh     # Acrobot 用更多并行环境
#   SKIP_ACROBOT=1 bash scripts/25_train_all.sh        # 只跑 Pendulum A/B
#   SKIP_AB=1      bash scripts/25_train_all.sh        # 只跑 Acrobot
#   FORCE=1        bash scripts/25_train_all.sh        # 已存在也重训
#
# 说明：
#   * CartPole 沿用第二周结果，本脚本不重训
#   * Pendulum demo 已存在则跳过（FORCE=1 可重训）
#   * A 组用默认奖励、B 组把能量项系数改为 0，两组都从头训练
#
# 产出：
#   evidence/week4/20_train_*.log          每个任务的训练日志
#   evidence/week4/22_b_group_diff.patch   B 组那一行改动
#   evidence/week4/25_training_summary.md  全部模型路径汇总
#   motrixlab/runs/week4/<env>_<tag>/      训练目录（含 checkpoints 与 tfevents）

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACROBOT_ENVS="${ACROBOT_ENVS:-512}"
SKIP_AB="${SKIP_AB:-0}"
SKIP_ACROBOT="${SKIP_ACROBOT:-0}"
FORCE="${FORCE:-0}"

W4="$REPO_ROOT/evidence/week4"
mkdir -p "$W4"

have_model() {
    [[ -f "$ML_DIR/runs/week4/$1/checkpoints/best_agent.pt" ]]
}

# ---------------------------------------------------------------- 1. Acrobot
if [[ "$SKIP_ACROBOT" != "1" ]]; then
    if have_model acrobot_demo && [[ "$FORCE" != "1" ]]; then
        log "acrobot_demo 已存在，跳过（FORCE=1 可重训）"
    else
        log "==== Acrobot demo 训练（num_envs=$ACROBOT_ENVS）===="
        ENV=acrobot TAG=demo NUM_ENVS="$ACROBOT_ENVS" bash "$REPO_ROOT/scripts/20_train_env.sh"
    fi
fi

# ---------------------------------------------------------------- 2. Pendulum A/B
if [[ "$SKIP_AB" != "1" ]]; then
    if have_model pendulum_A && have_model pendulum_B && [[ "$FORCE" != "1" ]]; then
        log "pendulum_A / pendulum_B 都已存在，跳过（FORCE=1 可重训）"
    else
        log "==== Pendulum A/B 对照训练（默认参数，两组只差一行奖励）===="
        STAGES=train bash "$REPO_ROOT/scripts/22_pendulum_ab.sh"
    fi
fi

# ---------------------------------------------------------------- 3. 汇总
SUMMARY="$W4/25_training_summary.md"

{
    echo "# 第 4 周训练产物汇总"
    echo
    echo "- 生成时间：$(date -Is)"
    echo "- 主机：$(hostname)"
    echo "- 仓库提交：$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo n/a)"
    echo
    echo "| 标签 | 模型路径 | 大小 | TensorBoard 事件文件 |"
    echo "| --- | --- | --- | --- |"
    for d in "$ML_DIR"/runs/week4/*/; do
        [[ -d "$d" ]] || continue
        tag="$(basename "$d")"
        best="${d%/}/checkpoints/best_agent.pt"
        [[ -f "$best" ]] || continue
        ev="$(find "$d" -maxdepth 1 -name 'events.out.tfevents.*' -print -quit)"
        printf '| `%s` | `%s` | %s | `%s` |\n' \
            "$tag" "${best#$REPO_ROOT/}" "$(du -h "$best" | cut -f1)" "${ev#$REPO_ROOT/}"
    done
    echo
    echo "## 回放命令模板"
    echo
    echo '```bash'
    for d in "$ML_DIR"/runs/week4/*/; do
        [[ -d "$d" ]] || continue
        tag="$(basename "$d")"
        env="${tag%_*}"
        [[ -f "$d/checkpoints/best_agent.pt" ]] || continue
        echo "ENV=$env TAG=${tag#*_} SEED=0 bash scripts/21_record_episode.sh"
    done
    echo '```'
} > "$SUMMARY"

cat "$SUMMARY"

log "全部训练完成。下一步：bash scripts/22_pendulum_ab.sh（STAGES=record）录 A/B 回放，或按作业逐项截图"
