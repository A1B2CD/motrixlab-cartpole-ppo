#!/usr/bin/env bash
# 28 - 八要素代码截图引导：Pendulum / Acrobot / CartPole 的观测·动作·奖励
#
# 用法：
#   bash scripts/28_code_screenshots.sh
#
# 每屏顶部标注「第几屏 / 要素 / 文件:行号」，下面是带行号的代码，
# 截完一屏按回车进入下一屏；输入 q 随时退出。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

B="$ML_DIR/motrix_envs/src/motrix_envs/basic"

show() {
    local title="$1" file="$2" range="$3" note="${4:-}"
    clear
    echo "================================================================"
    echo "  $title"
    echo "  文件：${file#"$REPO_ROOT"/}:$range"
    [[ -n "$note" ]] && echo "  要点：$note"
    echo "================================================================"
    echo
    nl -ba "$file" | sed -n "${range}p"
    echo
    printf '  \033[1;33m↳ 截完这一屏按回车继续（输入 q 退出）\033[0m '
    local ans=""
    read -r ans || true
    if [[ "$ans" == "q" ]]; then
        log "已退出截图引导"
        exit 0
    fi
}

# ---------------------------------------------------------------- Pendulum
show "A1/10  Pendulum 观测（3 维）" \
     "$B/pendulum/pendulum_np.py" "65,67" \
     "cosθ / sinθ / θ̇，用单位圆编码避免 ±π 跳变"

show "A2/10  Pendulum 动作（1 维）" \
     "$B/pendulum/pendulum_np.py" "54,58" \
     "先 clip(-1,1) 再线性映射到 ctrlrange"

show "A3/10  Pendulum 奖励（含 energy_reward）" \
     "$B/pendulum/pendulum_np.py" "71,90" \
     "3.0·upright + energy_reward − 0.2θ̇² − 0.001u² − 0.001Δu²"

show "A4/10  Pendulum 执行器（gear=5）" \
     "$B/pendulum/pendulum.xml" "31,33" \
     "唯一关节 hinge 由 torque 电机直接驱动（全驱动）"

# ---------------------------------------------------------------- Acrobot
show "B1/10  Acrobot 观测（6 维）" \
     "$B/acrobot/acrobot_np.py" "61,86" \
     "[cosθ₁, cos(θ₁+θ₂), sinθ₁, sin(θ₁+θ₂), θ̇₁, θ̇₂]"

show "B2/10  Acrobot 动作（1 维）" \
     "$B/acrobot/acrobot_np.py" "56,59" \
     "clip(-1,1) 后写入 actuator_ctrls，只有 1 个电机"

show "B3/10  Acrobot 奖励（4 项相加）" \
     "$B/acrobot/acrobot_np.py" "96,113" \
     "base_rwd + 0.1·in_target + 0.3·distance − 0.01·速度惩罚"

show "B4/10  Acrobot 执行器（只有 elbow）" \
     "$B/acrobot/acrobot.xml" "46,48" \
     "shoulder 没有 motor → 肩关节欠驱动"

# ---------------------------------------------------------------- CartPole
show "C1/10  CartPole 动作 + 观测 + 奖励" \
     "$B/cartpole/cartpole_np.py" "50,63" \
     "可直接引用第三周截图；如需重截用这一屏"

show "C2/10  CartPole 关节 + 执行器" \
     "$B/cartpole/cartpole.xml" "27,36" \
     "slider 有电机、hinge 没有（2 关节 1 电机）"

clear
log "截图引导结束。按下面的名字存档："
echo "  08_code_pendulum_obs.png     A1"
echo "  09_code_pendulum_action.png  A2 + A4"
echo "  10_code_pendulum_reward.png  A3"
echo "  11_code_acrobot_obs.png      B1"
echo "  12_code_acrobot_action.png   B2 + B4"
echo "  13_code_acrobot_reward.png   B3"
echo "  第三周截图                   C1 + C2（可直接引用）"
