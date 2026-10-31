#!/usr/bin/env bash
# run_all - 在云服务器上一键跑完 00 → 07（TensorBoard 截图除外）
#
# 用法：
#   bash scripts/run_all.sh
#   SKIP_BOOTSTRAP=1 bash scripts/run_all.sh     # 依赖已装好，跳过 01
#   NUM_ENVS=64 bash scripts/run_all.sh
#
# 说明：
#   * 先装依赖（01）再采集服务器信息（00），这样 00 能顺带跑出 JSON 版硬件报告。
#   * 会在 03 启动 TensorBoard 并保持运行，方便你在本机用 SSH 隧道截图；
#     截图后按回车，脚本停掉 TensorBoard 并继续 05 → 07。
#   * 如果只想先看 TensorBoard，单独跑 03，再用 SKIP_TB=1 跑本脚本。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STEP() { log "===== $* ====="; }

if [[ "${SKIP_BOOTSTRAP:-0}" != "1" ]]; then
    STEP "01 安装依赖"
    bash "$REPO_ROOT/scripts/01_bootstrap.sh"
else
    warn "SKIP_BOOTSTRAP=1，跳过 01"
fi

STEP "00 服务器信息"
bash "$REPO_ROOT/scripts/00_check_server.sh"

STEP "02 训练"
NUM_ENVS="${NUM_ENVS:-64}" bash "$REPO_ROOT/scripts/02_train.sh"

STEP "04 导出 scalar 与曲线（无浏览器也能出图）"
bash "$REPO_ROOT/scripts/04_export_scalars.sh"

if [[ "${SKIP_TB:-0}" != "1" ]]; then
    STEP "03 启动 TensorBoard"
    bash "$REPO_ROOT/scripts/03_tensorboard.sh"

    cat <<EOF

----------------------------------------------------------------
现在去截图（TensorBoard 正在运行）：

  1) 在你自己的电脑上开一个新终端，建 SSH 隧道：
       ssh -N -L 6006:127.0.0.1:6006 <user>@<server-ip> -p <port>

  2) 本机浏览器打开 http://127.0.0.1:6006
     进 SCALARS → 展开 Reward 与 Loss → 截图

  3) 存成（放在本仓库里，之后一起提交）：
       evidence/cloud/03_tensorboard_reward_loss.png

  建不了隧道也没关系：evidence/cloud/04_reward_and_loss.png 已经由
  04_export_scalars.sh 生成，读的是同一份 tfevents，可直接当证据。
----------------------------------------------------------------

EOF
    read -r -p "截图完成后按回车继续（脚本会停掉 TensorBoard）..." _ || true
    bash "$REPO_ROOT/scripts/03_tensorboard_stop.sh"
fi

STEP "05 推理（headless）"
bash "$REPO_ROOT/scripts/05_play_headless.sh"

STEP "06 推理（xvfb 截图，失败不影响证据）"
bash "$REPO_ROOT/scripts/06_play_xvfb.sh" || warn "06 失败，忽略"

STEP "07 汇总证据"
bash "$REPO_ROOT/scripts/07_collect_evidence.sh"

STEP "对比本地与云端"
( cd "$ML_DIR" && uv run --no-sync python "$REPO_ROOT/scripts/compare_runs.py" \
    --local "$REPO_ROOT/evidence/local-windows" \
    --cloud "$EVID" \
    --out "$REPO_ROOT/evidence" ) || warn "对比脚本失败，不影响证据"

STEP "完成"
log "下一步：bash scripts/08_push_evidence.sh"
ls -lh "$EVID" | sed 's/^/  /'
