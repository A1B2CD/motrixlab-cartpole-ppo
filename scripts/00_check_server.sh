#!/usr/bin/env bash
# 00 - 记录服务器硬件与软件配置（对应教程第 7 节的"服务器硬件配置分析"）
#
# 产出：evidence/cloud/00_server_report.txt / 00_server_report.json
#
# 用法：bash scripts/00_check_server.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log "采集服务器硬件/软件信息"

{
    echo "===== 采集时间 ====="
    date -Is
    echo
    echo "===== 主机 ====="
    hostname
    uname -a
    echo
    echo "===== 发行版 ====="
    (cat /etc/os-release 2>/dev/null) || echo "n/a"
    echo
    echo "===== CPU ====="
    lscpu 2>/dev/null || echo "n/a"
    echo
    echo "===== 内存 ====="
    free -h 2>/dev/null || echo "n/a"
    echo
    echo "===== 磁盘 ====="
    df -h . 2>/dev/null || echo "n/a"
    echo
    echo "===== GPU ====="
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi || true
    else
        echo "nvidia-smi not found"
    fi
    echo
    echo "===== Vulkan（xvfb 软件渲染需要） ====="
    if command -v vulkaninfo >/dev/null 2>&1; then
        vulkaninfo --summary 2>&1 | head -n 40 || true
    else
        echo "vulkaninfo not installed"
    fi
    echo
    echo "===== 工具链 ====="
    python3 --version 2>&1 || true
    uv --version 2>&1 || true
    git --version 2>&1 || true
} | tee "$EVID/00_server_report.txt"

log "生成机器可读报告（需要先跑过 01_bootstrap.sh）"
if [[ -x "$ML_DIR/.venv/bin/python" ]]; then
    ( cd "$ML_DIR" && uv run --no-sync python tools/check_env.py ) \
        | tee "$EVID/00_server_report.json" \
        || warn "check_env.py 执行失败，纯文本报告仍然有效"
else
    warn "还没创建虚拟环境，跳过 00_server_report.json"
fi

log "完成：$EVID/00_server_report.txt"
