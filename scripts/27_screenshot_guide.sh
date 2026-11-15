#!/usr/bin/env bash
# 27 - 逐项截图引导：每按一次回车显示一段「带文件路径与行号」的终端输出，截完继续
#
# 用法：
#   bash scripts/27_screenshot_guide.sh
#
# 每屏顶部会写清「第几步 / 评分项」，截图自带上下文，不用再手写标题。
# 输入 q 可随时退出。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

B="$ML_DIR/motrix_envs/src/motrix_envs/basic"
W4="$REPO_ROOT/evidence/week4"

pause() {
    echo
    printf '  \033[1;33m↳ 截完这一屏按回车继续（输入 q 退出）\033[0m '
    local ans=""
    read -r ans || true
    if [[ "$ans" == "q" ]]; then
        log "已退出截图引导"
        exit 0
    fi
}

step() {
    clear
    echo "================================================================"
    echo "  $1"
    echo "  评分项：$2"
    echo "================================================================"
    echo
}

# ---------------------------------------------------------------- Demo 证据
step "1/14  CartPole 训练日志（第二周，含命令与结束信息）" "Demo 证据 ② 训练结束日志"
tail -n 25 "$REPO_ROOT/evidence/local-windows/train_console_utf8.log"
pause

step "2/14  Pendulum demo 训练日志尾部" "Demo 证据 ② 训练结束日志"
tail -n 22 "$W4/20_train_pendulum_demo.log"
pause

step "3/14  Acrobot demo 训练日志尾部（29000/29000 + 耗时 417s 那次是 512 envs；当前为 2048）" "Demo 证据 ② 训练结束日志"
tail -n 22 "$W4/20_train_acrobot_demo.log"
pause

step "4/14  四个模型文件（路径 + 大小）" "Demo 证据 ③ 模型文件路径"
ls -lh "$ML_DIR"/runs/week4/*/checkpoints/best_agent.pt
echo
echo "第二周 CartPole 模型："
ls -lh "$ML_DIR"/runs/cartpole/*_PPO/checkpoints/best_agent.pt
pause

step "5/14  三个 Demo 的逐帧统计（直立占比 / 累计奖励）" "Demo 证据 ⑤ 回放表现"
echo "---- CartPole ----"
python3 "$REPO_ROOT/scripts/23_analyze_episode.py" --env cartpole --csv "$W4/csv/cartpole_demo_seed0.csv"
echo
echo "---- Pendulum（seed 4，从垂下起摆）----"
python3 "$REPO_ROOT/scripts/23_analyze_episode.py" --env pendulum --csv "$W4/csv/pendulum_demo_seed4.csv"
echo
echo "---- Acrobot（seed 4，从垂下起摆）----"
python3 "$REPO_ROOT/scripts/23_analyze_episode.py" --env acrobot --csv "$W4/csv/acrobot_demo_seed4.csv"
pause

step "6/14  TensorBoard 四条曲线（网页截图，本屏只是命令）" "Demo 证据 ④ 训练曲线"
cat <<EOF
在另一个终端执行：

    cd ~/motrixlab-cartpole-ppo
    bash scripts/03_tensorboard_stop.sh
    LOGDIR=runs/week4 bash scripts/03_tensorboard.sh

浏览器打开 http://127.0.0.1:6006 ，勾选
    pendulum_demo / pendulum_A / pendulum_B / acrobot_demo
截 Reward / Total reward (mean) 曲线（任务名和曲线要在同一张图里）。

CartPole 用第二周已截好的：evidence/local-windows/05_tensorboard_reward_loss.png
EOF
pause

# ---------------------------------------------------------------- 八要素表
step "7/14  Pendulum 观测 + 动作 + 奖励（含能量项）" "八要素表 / 能量奖励 ①"
echo "================ $B/pendulum/pendulum_np.py 第 54-99 行 ================"
nl -ba "$B/pendulum/pendulum_np.py" | sed -n '54,99p'
pause

step "8/14  Pendulum 模型：摆杆几何（0 是竖直向上）+ motor gear=5" "八要素表"
echo "================ $B/pendulum/pendulum.xml 第 17-33 行 ================"
nl -ba "$B/pendulum/pendulum.xml" | sed -n '17,33p'
pause

step "9/14  Acrobot 观测（6 维）+ 动作 + 奖励 + 初始状态" "八要素表 / 欠驱动"
echo "================ $B/acrobot/acrobot_np.py 第 56-143 行 ================"
nl -ba "$B/acrobot/acrobot_np.py" | sed -n '56,143p'
pause

step "10/14  Acrobot 模型：2 关节、只有 elbow 有 motor（欠驱动）" "八要素表 / 欠驱动"
echo "================ $B/acrobot/acrobot.xml 第 28-48 行 ================"
nl -ba "$B/acrobot/acrobot.xml" | sed -n '28,48p'
pause

# ---------------------------------------------------------------- 能量奖励
step "11/14  B 组那一行改动（git diff）" "能量奖励 ② 对照改动"
cat "$W4/22_b_group_diff.patch"
echo
echo "改前 / 改后奖励行："
cat "$W4/22_A_reward_line.txt"
echo
cat "$W4/22_B_reward_line.txt"
pause

step "12/14  两组训练日志的关键行（步数 / it/s / 耗时）" "能量奖励 ③ 训练证据"
for t in A B; do
    echo "---- pendulum_$t ----"
    grep -E "command|it/s|耗时" "$W4/20_train_pendulum_$t.log" || true
    echo
done
pause

step "13/14  A/B 回放记录表 + 曲线数值摘要" "能量奖励 ④⑤ 回放记录与分析"
cat "$W4/23_ab_table.md"
echo
echo "================ tb/26_summary.md（Pendulum 部分）================"
sed -n '/## pendulum_A/,/## pendulum_demo/p' "$W4/tb/26_summary.md"
pause

# ---------------------------------------------------------------- dm-reacher
step "14/14  dm-reacher 关键代码（观测拼接 / 动作 / 奖励 / 目标采样）" "dm-reacher 25 分"
echo "================ $B/reacher/reacher_np.py 第 44-98 行 ================"
nl -ba "$B/reacher/reacher_np.py" | sed -n '44,98p'
echo
echo "================ $B/reacher/reacher.xml 第 28-53 行 ================"
nl -ba "$B/reacher/reacher.xml" | sed -n '28,53p'
echo
cat <<'EOF'

场景截图（另开终端，截完再回来）：
    cd ~/motrixlab-cartpole-ppo/motrixlab
    uv run scripts/view.py --env dm-reacher
    # 窗口出来后：spectacle -b -n -f -o ~/reacher.png
    # 标注：arm（第一段 0.12）/ hand（第二段 0.1）/ shoulder / wrist / target（红球 r=0.02）
EOF
pause

clear
log "截图引导结束。产物清单："
echo "  视频    : $(ls -1 "$W4"/video/*.mp4 2>/dev/null | wc -l) 个"
echo "  CSV     : $(ls -1 "$W4"/csv/*.csv 2>/dev/null | wc -l) 个"
echo "  日志    : $(ls -1 "$W4"/*.log 2>/dev/null | wc -l) 个"
echo "  曲线图  : $(ls -1 "$W4"/tb/*.png 2>/dev/null | wc -l) 张"
