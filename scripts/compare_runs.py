"""对比「本地 Windows」与「巧工云服务器」两次 CartPole PPO 运行。

两边用同一套脚本、同一套超参（64 并行环境 / 5000 timesteps），
所以可以直接把硬件、耗时、回报曲线放在一张表里看差异。

用法：
    uv run --no-sync python scripts/compare_runs.py \
        --local evidence/local-windows \
        --cloud evidence/cloud \
        --out   evidence

产出：
    evidence/comparison.md    人读的对比表
    evidence/comparison.json  机器可读的原始数值

任意一侧缺文件都不会报错，缺失项显示为「待生成」。
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from datetime import datetime
from pathlib import Path

NA = "待生成"

# 两边文件名不同：本地是手工整理的，云端是脚本生成的
ENV_FILES = ("00_server_report.json", "00_env_report.json")
SCALAR_FILES = ("04_scalars.csv", "scalars.csv")
PLAY_FILES = ("05_play_headless.log", "03_play_demo.txt", "play_console_utf8.log")
TREE_FILES = ("07_runs_tree.txt", "01_runs_tree.txt")

TAG_REWARD = "Reward / Total reward (mean)"
TAG_VALUE_LOSS = "Loss / Value loss"


# --------------------------------------------------------------------------- io
def read_text(path: Path) -> str:
    """按 BOM 判断编码。Windows 上 PowerShell 写出的日志可能是 UTF-16。"""
    data = path.read_bytes()
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return data.decode("utf-16")
    if data[:3] == b"\xef\xbb\xbf":
        return data.decode("utf-8-sig")
    for enc in ("utf-8", "gbk"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def find_first(base: Path, names: tuple[str, ...]) -> Path | None:
    for name in names:
        p = base / name
        if p.is_file():
            return p
    return None


# ------------------------------------------------------------------------ parse
def parse_env(base: Path) -> dict:
    path = find_first(base, ENV_FILES)
    if path is None:
        return {}
    try:
        raw = json.loads(read_text(path))
    except json.JSONDecodeError:
        return {}

    cpu = raw.get("cpu") or {}
    cores = cpu.get("physical_cores")
    threads = cpu.get("logical_cores")
    if cores and threads:
        cpu_txt = f"{cpu.get('model', '?')} ({cores}C/{threads}T)"
    elif threads:
        cpu_txt = f"{cpu.get('model', '?')} ({threads} 线程)"
    else:
        cpu_txt = cpu.get("model", "?")

    gpus = raw.get("gpu") or []
    if gpus:
        gpu_txt = "; ".join(
            f"{g.get('name', '?')} {g.get('memory_mb', '?')}MB / 驱动 {g.get('driver', '?')} / CC {g.get('compute_capability', '?')}"
            for g in gpus
        )
    else:
        gpu_txt = "无（或未检测到 nvidia-smi）"

    pkg = raw.get("packages") or {}
    return {
        "hostname": raw.get("hostname", "?"),
        "os": raw.get("os", "?"),
        "python": raw.get("python", "?"),
        "cpu": cpu_txt,
        "memory_gb": raw.get("memory_gb"),
        "gpu": gpu_txt,
        "torch": pkg.get("torch", "?"),
        "cuda_available": pkg.get("torch_cuda_available"),
        "cuda_device": pkg.get("torch_cuda_device"),
        "motrixsim": pkg.get("motrixsim", "?"),
        "skrl": pkg.get("skrl", "?"),
        "numpy": pkg.get("numpy", "?"),
        "gymnasium": pkg.get("gymnasium", "?"),
        "tensorboard": pkg.get("tensorboard", "?"),
        "source": path.name,
    }


def parse_scalars(base: Path) -> dict:
    path = find_first(base, SCALAR_FILES)
    if path is None:
        return {}

    text = read_text(path)
    rows = list(csv.DictReader(text.splitlines()))
    if not rows:
        return {}

    by_tag: dict[str, list[tuple[float, float]]] = {}
    wall_times: list[float] = []
    for row in rows:
        try:
            wall = float(row["wall_time"])
            value = float(row["value"])
        except (KeyError, ValueError):
            continue
        by_tag.setdefault(row["tag"], []).append((wall, value))
        wall_times.append(wall)

    reward = by_tag.get(TAG_REWARD, [])
    value_loss = by_tag.get(TAG_VALUE_LOSS, [])
    duration = (max(wall_times) - min(wall_times)) if wall_times else None

    return {
        "records": len(reward),
        "reward_first": reward[0][1] if reward else None,
        "reward_last": reward[-1][1] if reward else None,
        "reward_max": max(v for _, v in reward) if reward else None,
        "value_loss_first": value_loss[0][1] if value_loss else None,
        "value_loss_last": value_loss[-1][1] if value_loss else None,
        "duration_s": duration,
        "tags": len(by_tag),
        "source": path.name,
    }


def parse_play(base: Path) -> dict:
    path = find_first(base, PLAY_FILES)
    if path is None:
        return {}
    text = read_text(path)

    steps = re.search(r"finished\s+(\d+)\s+steps,\s*mean episode reward=([0-9.]+)", text)
    policy = re.search(r"Loaded policy:\s*(\S+)", text)
    return {
        "steps": int(steps.group(1)) if steps else None,
        "reward": float(steps.group(2)) if steps else None,
        "policy": policy.group(1) if policy else None,
        "source": path.name,
    }


def parse_tree(base: Path) -> dict:
    path = find_first(base, TREE_FILES)
    if path is None:
        return {}
    text = read_text(path)
    agents = re.findall(r"(?:best_agent|agent_\d+)\.(?:pt|pickle)", text)
    runs = re.findall(r"(\d{2}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}-\d+_PPO)", text)
    return {
        "checkpoints": len(set(agents)),
        "run_dir": runs[0] if runs else None,
        "source": path.name,
    }


# ----------------------------------------------------------------------- render
def cell(value, fmt: str = "{}") -> str:
    if value is None:
        return NA
    if value == "":
        return NA
    try:
        return fmt.format(value)
    except (ValueError, TypeError):
        return str(value)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--local", type=Path, default=Path("evidence/local-windows"))
    parser.add_argument("--cloud", type=Path, default=Path("evidence/cloud"))
    parser.add_argument("--out", type=Path, default=Path("evidence"))
    args = parser.parse_args()

    local = {
        "env": parse_env(args.local),
        "scalars": parse_scalars(args.local),
        "play": parse_play(args.local),
        "tree": parse_tree(args.local),
    }
    cloud = {
        "env": parse_env(args.cloud),
        "scalars": parse_scalars(args.cloud),
        "play": parse_play(args.cloud),
        "tree": parse_tree(args.cloud),
    }

    L, C = local, cloud
    lines: list[str] = []
    add = lines.append

    add("# 本地 Windows 与巧工云服务器：CartPole PPO 运行对比")
    add("")
    add(f"- 生成时间：{datetime.now().astimezone().isoformat(timespec='seconds')}")
    add(f"- 本地证据目录：`{args.local.as_posix()}`")
    add(f"- 云端证据目录：`{args.cloud.as_posix()}`")
    add("- 两边超参一致：`cartpole`、64 并行环境、5000 timesteps、`hiddens=[32,32]`")
    add("")
    add("> 缺失项显示为「待生成」。云端跑完 `scripts/run_all.sh` 后重新执行")
    add("> `python scripts/compare_runs.py` 即可补齐。")
    add("")

    # ---- 1. 环境 ----
    add("## 1. 运行环境")
    add("")
    add("| 项目 | 本地 Windows | 巧工云服务器 |")
    add("| --- | --- | --- |")
    rows = [
        ("主机名", "hostname", None),
        ("操作系统", "os", None),
        ("Python", "python", None),
        ("CPU", "cpu", None),
        ("内存 (GB)", "memory_gb", None),
        ("GPU", "gpu", None),
        ("PyTorch", "torch", None),
        ("CUDA 可用", "cuda_available", None),
        ("CUDA 设备", "cuda_device", None),
        ("motrixsim", "motrixsim", None),
        ("skrl", "skrl", None),
        ("numpy", "numpy", None),
        ("gymnasium", "gymnasium", None),
        ("tensorboard", "tensorboard", None),
    ]
    for label, key, fmt in rows:
        lv = L["env"].get(key)
        cv = C["env"].get(key)
        if key == "cuda_available":
            lv = "是" if lv is True else ("否" if lv is False else lv)
            cv = "是" if cv is True else ("否" if cv is False else cv)
        add(f"| {label} | {cell(lv)} | {cell(cv)} |")
    add("")

    # ---- 2. 训练 ----
    add("## 2. 训练结果")
    add("")
    add("| 指标 | 本地 Windows | 巧工云服务器 |")
    add("| --- | --- | --- |")
    tr_rows = [
        ("训练目录", L["tree"].get("run_dir"), C["tree"].get("run_dir"), None),
        ("checkpoint 数量", L["tree"].get("checkpoints"), C["tree"].get("checkpoints"), None),
        ("记录的 episode 数", L["scalars"].get("records"), C["scalars"].get("records"), None),
        ("平均回报 · 首次", L["scalars"].get("reward_first"), C["scalars"].get("reward_first"), "{:.2f}"),
        ("平均回报 · 末次", L["scalars"].get("reward_last"), C["scalars"].get("reward_last"), "{:.2f}"),
        ("平均回报 · 最高", L["scalars"].get("reward_max"), C["scalars"].get("reward_max"), "{:.2f}"),
        ("value loss · 首次", L["scalars"].get("value_loss_first"), C["scalars"].get("value_loss_first"), "{:.4g}"),
        ("value loss · 末次", L["scalars"].get("value_loss_last"), C["scalars"].get("value_loss_last"), "{:.4g}"),
        ("训练耗时 (秒)", L["scalars"].get("duration_s"), C["scalars"].get("duration_s"), "{:.1f}"),
    ]
    for label, lv, cv, fmt in tr_rows:
        add(f"| {label} | {cell(lv, fmt) if fmt else cell(lv)} | {cell(cv, fmt) if fmt else cell(cv)} |")
    add("")

    # ---- 3. 推理 ----
    add("## 3. 推理演示（play.py）")
    add("")
    add("| 指标 | 本地 Windows | 巧工云服务器 |")
    add("| --- | --- | --- |")
    for label, key, fmt in [
        ("加载的 checkpoint", "policy", None),
        ("运行步数", "steps", None),
        ("平均回合回报", "reward", "{:.2f}"),
    ]:
        lv = L["play"].get(key)
        cv = C["play"].get(key)
        add(f"| {label} | {cell(lv, fmt) if fmt else cell(lv)} | {cell(cv, fmt) if fmt else cell(cv)} |")
    add("")

    # ---- 4. 结论 ----
    add("## 4. 自动结论")
    add("")
    conclusions: list[str] = []

    lr, cr = L["scalars"].get("reward_last"), C["scalars"].get("reward_last")
    if lr is not None and cr is not None:
        if lr >= 990 and cr >= 990:
            conclusions.append(
                f"- 两侧都收敛：末次平均回报 **{lr:.2f}** vs **{cr:.2f}**，均达到 CartPole 上限 1000。"
            )
        else:
            conclusions.append(f"- 末次平均回报：本地 **{lr:.2f}**，云端 **{cr:.2f}**，存在差距，需要检查训练是否跑满。")
    else:
        conclusions.append("- 云端训练数据尚未生成，无法对比收敛情况。")

    ld, cd = L["scalars"].get("duration_s"), C["scalars"].get("duration_s")
    if ld and cd:
        ratio = ld / cd
        if abs(ratio - 1) < 0.02:
            conclusions.append(f"- 训练耗时：本地 **{ld:.1f}s**，云端 **{cd:.1f}s**，基本持平。")
        else:
            faster = "云端更快" if ratio > 1 else "本地更快"
            conclusions.append(
                f"- 训练耗时：本地 **{ld:.1f}s**，云端 **{cd:.1f}s**，{faster}（{abs(ratio - 1) * 100:.0f}% 差异）。"
            )
    elif ld:
        conclusions.append(f"- 本地训练耗时 **{ld:.1f}s**；云端数据待生成。")

    lp, cp = L["play"].get("steps"), C["play"].get("steps")
    if lp and cp:
        conclusions.append(f"- 推理：本地跑 **{lp}** 步、云端跑 **{cp}** 步，都能加载同一类 checkpoint。")
    elif lp:
        conclusions.append(f"- 本地推理跑通 **{lp}** 步；云端待生成。")

    lcuda = L["env"].get("cuda_available")
    ccuda = C["env"].get("cuda_available")
    if lcuda is False and ccuda is True:
        conclusions.append(
            "- 云端用上了 CUDA 版 PyTorch，但 CartPole 的瓶颈在 NumPy 物理步进与 Python 开销，"
            "**GPU 不会带来数量级加速**；耗时差异主要反映 CPU 单核性能。"
        )

    lines.extend(conclusions)
    add("")

    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "comparison.md").write_text("\n".join(lines), encoding="utf-8")
    (args.out / "comparison.json").write_text(
        json.dumps({"local": local, "cloud": cloud}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print("\n".join(lines))
    print(f"\n已写入 {args.out / 'comparison.md'}")
    print(f"已写入 {args.out / 'comparison.json'}")


if __name__ == "__main__":
    main()
