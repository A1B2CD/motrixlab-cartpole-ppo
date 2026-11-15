#!/usr/bin/env bash
# 22 - 单摆能量奖励 A/B 对照实验（一条命令跑完训练 → 回放 → 核算）
#
# 设计：
#   A 组 = 默认奖励（不改任何代码）
#   B 组 = 只把能量项对总奖励的贡献改成 0：pendulum_np.py 第 88 行
#           3.0 * upright + energy_reward - ...   →   3.0 * upright + 0.0 * energy_reward - ...
#   其余奖励项、环境设置、训练设置、随机种子、并行环境数、训练步数全部相同。
#
# 用法：
#   bash scripts/22_pendulum_ab.sh                 # 训练 + 回放 + 核算，全跑
#   STAGES=train bash scripts/22_pendulum_ab.sh    # 只训练
#   STAGES=record bash scripts/22_pendulum_ab.sh   # 只回放（训练已完成）
#   STAGES=analyze bash scripts/22_pendulum_ab.sh  # 只核算
#
# 前置：01_bootstrap.sh 已跑过；ffmpeg 已装（sudo apt-get install -y ffmpeg）；有图形桌面。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STAGES="${STAGES:-train,record,analyze}"
PEND_FILE="$ML_DIR/motrix_envs/src/motrix_envs/basic/pendulum/pendulum_np.py"
W4="$REPO_ROOT/evidence/week4"
SEEDS="${SEEDS:-0 1 2}"
mkdir -p "$W4"

PEND_REL="${PEND_FILE#$REPO_ROOT/}"

patch_energy() {
    local mode="$1"   # off = 改成 B 组；revert = 恢复 A 组
    python3 - "$PEND_FILE" "$mode" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
mode = sys.argv[2]

A = "3.0 * upright + energy_reward - vel_penalty"
B = "3.0 * upright + 0.0 * energy_reward - vel_penalty"

text = path.read_text(encoding="utf-8")

if mode == "off":
    if text.count(B) == 1:
        print("B 组代码已是目标状态，跳过")
    else:
        n = text.count(A)
        assert n == 1, f"期望找到 1 处默认奖励行，实际 {n} 处；请确认代码没被改过"
        path.write_text(text.replace(A, B), encoding="utf-8")
        print("B 组：能量项系数已改为 0.0")
elif mode == "revert":
    if text.count(A) == 1 and text.count(B) == 0:
        print("已是默认奖励（A 组状态），跳过")
    else:
        n = text.count(B)
        assert n == 1, f"期望找到 1 处 B 组奖励行，实际 {n} 处"
        path.write_text(text.replace(B, A), encoding="utf-8")
        print("A 组：已恢复默认奖励")
else:
    raise SystemExit(f"未知 mode: {mode}")
PY
}

show_line() {
    local no
    no="$(grep -n "3.0 \* upright" "$PEND_FILE" | cut -d: -f1)"
    echo "---- $PEND_REL 第 ${no} 行 ----"
    nl -ba "$PEND_FILE" | sed -n "$((no - 4)),$((no + 3))p"
    echo "-----------------------------"
}

run_train() {
    log "== A 组训练（默认奖励）=="
    patch_energy revert
    show_line | tee "$W4/22_A_reward_line.txt"
    ENV=pendulum TAG=A bash "$REPO_ROOT/scripts/20_train_env.sh"

    log "== 切换到 B 组代码（只改一行）=="
    patch_energy off
    show_line | tee "$W4/22_B_reward_line.txt"
    git -C "$REPO_ROOT" diff -- "$PEND_REL" > "$W4/22_b_group_diff.patch" || true
    cat "$W4/22_b_group_diff.patch"

    log "== B 组训练（能量项贡献 = 0）=="
    ENV=pendulum TAG=B bash "$REPO_ROOT/scripts/20_train_env.sh"

    log "== 恢复默认代码（A 组状态）=="
    patch_energy revert
    show_line | tee -a "$W4/22_A_reward_line.txt"
    if git -C "$REPO_ROOT" diff --quiet -- "$PEND_REL"; then
        log "已恢复：工作区与提交版本一致"
    else
        warn "代码还没恢复干净，请手动检查：git -C $REPO_ROOT diff -- $PEND_REL"
    fi
}

run_record() {
    log "== 回放：每组 3 个完整回合，seed 0/1/2，视角一致（--num-envs 1）=="
    local tag seed
    for tag in A B; do
        for seed in $SEEDS; do
            ENV=pendulum TAG="$tag" SEED="$seed" bash "$REPO_ROOT/scripts/21_record_episode.sh"
        done
    done
}

run_analyze() {
    log "== 核算角度并生成回放记录表 =="
    python3 "$REPO_ROOT/scripts/23_analyze_episode.py" \
        --env pendulum \
        --csv "$W4"/csv/pendulum_A_seed*.csv "$W4"/csv/pendulum_B_seed*.csv \
        --markdown | tee "$W4/23_ab_table.md"
    python3 "$REPO_ROOT/scripts/23_analyze_episode.py" \
        --env pendulum \
        --csv "$W4"/csv/pendulum_A_seed*.csv "$W4"/csv/pendulum_B_seed*.csv \
        | tee "$W4/23_ab_table.txt"
}

case ",$STAGES," in
    *,train,*)   run_train ;;
esac
case ",$STAGES," in
    *,record,*)  run_record ;;
esac
case ",$STAGES," in
    *,analyze,*) run_analyze ;;
esac

log "完成。产物在 evidence/week4/（表格、视频、CSV、日志、diff）"
