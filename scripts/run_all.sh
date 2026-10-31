#!/usr/bin/env bash
# run_all - 在云服务器上一键跑完 00 → 07（TensorBoard 截图除外）
#
# 用法：
#   bash scripts/run_all.sh
#   SKIP_BOOTSTRAP=1 bash scripts/run_all.sh     # 依赖已装好，跳过 01
#   NUM_ENVS=64 bash scripts/run_all.sh
#
# 说明：
#   * 会在 03 启动 TensorBoard 并保持运行，方便你在本机用 SSH 隧道截图；
#     截图完成后脚本继续执行 04 → 07，最后自动停掉 TensorBoard。
#   * 如果你只想先看 TensorBoard，先单独跑 03，再跑本脚本并设 SKIP_TB=1。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STEP() { log "===== $* ====="; }

STEP "00 服务器信息"
bash "$REPO_ROOT/scripts/00_check_server.sh"

if [[ "${SKIP_BOOTSTRAP:-0}" != "1" ]]; then
    STEP "01 安装依赖"
    bash "$REPO_ROOT/scripts/01_bootstrap.sh"
else
    warn "SKIP_BOOTSTRAP=1，跳过 01"
fi

STEP "02 训练"
NUM_ENVS="${NUM_ENVS:-64}" bash "$REPO_ROOT/scripts/02_train.sh"

STEP "04 导出 scalar 与曲线（无浏览器也能出图）"
bash "$REPO_ROOT/scripts/04_export_scalars.sh"

if [[ "${SKIP_TB:-0}" != "1" ]]; then
    STEP "03 启动 TensorBoard"
    bash "$REPO_ROOT/scripts/03_tensorboard.sh"
fi

STEP "05 推理（headless）"
bash "$REPO_ROOT/scripts/05_play_headless.sh"

STEP "06 推理（xvfb 截图，失败不影响证据）"
bash "$REPO_ROOT/scripts/06_play_xvfb.sh" || warn "06 失败，忽略"

if [[ "${SKIP_TB:-0}" != "1" ]]; then
    log "TensorBoard 仍在运行，现在可以在本机建隧道截图："
    echo "    ssh -N -L 6006:127.0.0.1:6006 <user>@<ip> -p <port>"
    echo "    浏览器打开 http://127.0.0.1:6006 → SCALARS → 截图"
    echo "    存为 evidence/cloud/03_tensorboard_reward_loss.png"
    echo
    read -r -p "截图完成后按回车继续（脚本会停掉 TensorBoard）..." _ || true
    bash "$REPO_ROOT/scripts/03_tensorboard_stop.sh"
fi

STEP "07 汇总证据"
bash "$REPO_ROOT/scripts/07_collect_evidence.sh"

STEP "完成"
log "下一步：bash scripts/08_push_evidence.sh"
ls -lh "$EVID" | sed 's/^/  /'
