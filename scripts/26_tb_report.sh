#!/usr/bin/env bash
# 26 - 训练曲线的数值摘要 + PNG（TensorBoard 网页截图的数值备份 / 兜底图）
#
# 用途：训练刚跑完时先看数值判断"到底学没学会"，再决定要不要重训；
#       同时把 A/B 两组画在一张图上，做能量奖励对照的直观证据。
#
# 用法：
#   bash scripts/26_tb_report.sh                        # week4 下所有训练目录
#   bash scripts/26_tb_report.sh pendulum_A pendulum_B  # 只跑指定标签
#
# 产出：
#   evidence/week4/tb/26_summary.md
#   evidence/week4/tb/26_<tag>_reward.png
#   evidence/week4/tb/26_pendulum_AB_reward.png

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OUT="${OUT:-$REPO_ROOT/evidence/week4/tb}"
W4="$ML_DIR/runs/week4"

[[ -d "$W4" ]] || die "$W4 不存在，请先跑 bash scripts/25_train_all.sh"

DIRS=()
if [[ $# -gt 0 ]]; then
    for t in "$@"; do DIRS+=("$W4/$t"); done
else
    while IFS= read -r d; do DIRS+=("$d"); done < <(find "$W4" -maxdepth 1 -mindepth 1 -type d | sort)
fi

[[ ${#DIRS[@]} -gt 0 ]] || die "$W4 下没有训练目录，请先跑 bash scripts/25_train_all.sh"

cd "$ML_DIR"
uv run --no-sync python "$REPO_ROOT/scripts/26_tb_report.py" --out "$OUT" "${DIRS[@]}"

log "完成。图与摘要：${OUT#$REPO_ROOT/}"
log "用 cat 看摘要：cat ${OUT#$REPO_ROOT/}/26_summary.md"
