#!/usr/bin/env bash
# 01 - 在云服务器上安装依赖并同步 Python 环境
#
# 用法：
#   bash scripts/01_bootstrap.sh              # 自动判断 CPU / CUDA 版 PyTorch
#   TORCH_VARIANT=cpu   bash scripts/01_bootstrap.sh
#   TORCH_VARIANT=cu128 bash scripts/01_bootstrap.sh
#
# 说明：
#   * 本仓库 vendored 的 MotrixLab v0.3.0 默认锁的是 CPU 版 PyTorch（本地验证用）。
#   * 云 GPU 机器上会自动切到 cu128 轮子；只有驱动 >= 570（CUDA 12.8）时才切。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TORCH_VARIANT="${TORCH_VARIANT:-auto}"

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

# ---------------------------------------------------------------- 1. 系统依赖
log "安装系统依赖"
if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y --no-install-recommends \
        git curl ca-certificates build-essential \
        xvfb x11-utils imagemagick \
        mesa-vulkan-drivers libvulkan1 vulkan-tools
else
    warn "非 apt 系统，请自行确认 git / curl / xvfb / vulkan 已安装"
fi

# ---------------------------------------------------------------- 2. uv
log "检查 uv"
if ! command -v uv >/dev/null 2>&1; then
    if curl -LsSf --max-time 60 https://astral.sh/uv/install.sh -o /tmp/uv-install.sh 2>/dev/null; then
        sh /tmp/uv-install.sh
        export PATH="$HOME/.local/bin:$PATH"
    else
        warn "astral.sh 不可达，改用 pip 安装 uv"
        python3 -m pip install --user -U uv
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi
command -v uv >/dev/null 2>&1 || die "uv 安装失败"
uv --version

# ---------------------------------------------------------------- 3. Python 3.10
log "安装 Python 3.10（MotrixLab v0.3.0 要求 ==3.10.*）"
uv python install 3.10
uv python list 2>/dev/null | grep -E '3\.10' | head -n 3 || true

# ---------------------------------------------------------------- 4. 选择 PyTorch 轮子
detect_variant() {
    if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi >/dev/null 2>&1; then
        echo cpu; return
    fi
    local cuda
    cuda="$(nvidia-smi | sed -n 's/.*CUDA Version: *\([0-9]\+\)\.\([0-9]\+\).*/\1\2/p' | head -n 1)"
    if [[ -n "$cuda" ]] && (( cuda >= 128 )); then
        echo cu128
    else
        echo cpu
    fi
}

if [[ "$TORCH_VARIANT" == "auto" ]]; then
    TORCH_VARIANT="$(detect_variant)"
    log "自动检测到 PyTorch 轮子类型：$TORCH_VARIANT"
fi
[[ "$TORCH_VARIANT" == "cpu" || "$TORCH_VARIANT" == "cu128" ]] \
    || die "TORCH_VARIANT 只能是 cpu 或 cu128，当前为 $TORCH_VARIANT"

log "写入 PyTorch 轮子配置：$TORCH_VARIANT"
python3 - "$ML_DIR" "$TORCH_VARIANT" <<'PY'
import pathlib, re, sys

ml = pathlib.Path(sys.argv[1])
variant = sys.argv[2]

root = ml / "pyproject.toml"
text = root.read_text(encoding="utf-8")
text = re.sub(
    r'url = "https://download\.pytorch\.org/whl/[a-z0-9]+"',
    f'url = "https://download.pytorch.org/whl/{variant}"',
    text,
)
root.write_text(text, encoding="utf-8")

rl = ml / "motrix_rl" / "pyproject.toml"
text = rl.read_text(encoding="utf-8")
text = re.sub(
    r"(torch|torchvision|torchaudio)===([0-9][0-9.]*)\+[a-z0-9]+",
    r"\1===\2+" + variant,
    text,
)
rl.write_text(text, encoding="utf-8")

print(f"  pyproject.toml        -> {variant}")
print(f"  motrix_rl/pyproject.toml -> {variant}")
PY

# ---------------------------------------------------------------- 5. 同步环境
log "uv sync（首次约 2-5 分钟，取决于网络）"
cd "$ML_DIR"
rm -f uv.lock
uv sync --all-packages --extra skrl-torch --python 3.10

log "安装取证用的额外依赖（matplotlib 画曲线）"
uv pip install matplotlib

# ---------------------------------------------------------------- 6. 自检
log "自检"
uv run --no-sync python - <<'PY'
import torch, skrl, numpy, gymnasium
import motrix_rl, motrix_envs, motrixsim
print(f"torch      {torch.__version__}  cuda_available={torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"cuda device {torch.cuda.get_device_name(0)}")
print(f"skrl       {skrl.__version__}")
print(f"numpy      {numpy.__version__}")
print(f"gymnasium  {gymnasium.__version__}")
print(f"motrix_rl  {motrix_rl.__file__}")
print(f"motrix_envs {motrix_envs.__file__}")
PY

log "环境就绪。下一步：bash scripts/02_train.sh"
