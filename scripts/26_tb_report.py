"""26 - 把 week4 各次训练的曲线导出成 PNG + 数值摘要。

用途：
  1. 训练刚跑完时先用数值确认"到底学没学会"，再决定要不要重训；
  2. TensorBoard 网页截图之外留一份数值备份（截图看不清时用它兜底）；
  3. Pendulum A/B 两组画在同一张图上，直接做对照。

用法（在仓库根目录）：
    uv run --no-sync --project motrixlab python scripts/26_tb_report.py \
        --out evidence/week4/tb \
        motrixlab/runs/week4/acrobot_demo \
        motrixlab/runs/week4/pendulum_A \
        motrixlab/runs/week4/pendulum_B

或直接用包装脚本：
    bash scripts/26_tb_report.sh
"""

from __future__ import annotations

import argparse
import glob
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from tensorboard.backend.event_processing.event_accumulator import EventAccumulator  # noqa: E402

TAG_MEAN = "Reward / Total reward (mean)"
TAG_MIN = "Reward / Total reward (min)"
TAG_MAX = "Reward / Total reward (max)"
TAG_VALUE_LOSS = "Loss / Value loss"
TAG_POLICY_LOSS = "Loss / Policy loss"

COLORS = ["#2f6fdb", "#d9534f", "#2ca02c", "#9467bd", "#ff7f0e"]


def find_events(run_dir: Path) -> Path:
    files = sorted(glob.glob(str(run_dir / "events.out.tfevents.*")))
    if not files:
        files = sorted(glob.glob(str(run_dir / "*" / "events.out.tfevents.*")))
    if not files:
        raise SystemExit(f"[FAIL] {run_dir} 下没有 events.out.tfevents.*，请先训练")
    return Path(files[0])


def load(run_dir: Path) -> tuple[Path, dict[str, list[tuple[int, float]]]]:
    events = find_events(run_dir)
    acc = EventAccumulator(str(events), size_guidance={"scalars": 0})
    acc.Reload()
    data: dict[str, list[tuple[int, float]]] = {}
    for tag in acc.Tags()["scalars"]:
        data[tag] = [(e.step, e.value) for e in acc.Scalars(tag)]
    return events, data


def tail_mean(values: list[float], frac: float = 0.1) -> float:
    """末段均值：取最后 10% 的点，避免被单个尖峰带偏。"""
    if not values:
        return float("nan")
    k = max(1, int(len(values) * frac))
    return sum(values[-k:]) / k


def stats(data: dict[str, list[tuple[int, float]]], tag: str) -> dict | None:
    if tag not in data or not data[tag]:
        return None
    values = [v for _, v in data[tag]]
    steps = [s for s, _ in data[tag]]
    return {
        "count": len(values),
        "first": values[0],
        "last": values[-1],
        "max": max(values),
        "min": min(values),
        "tail_mean": tail_mean(values),
        "last_step": steps[-1],
    }


def plot_run(name: str, data: dict, out: Path) -> Path | None:
    if TAG_MEAN not in data or not data[TAG_MEAN]:
        return None
    xs = [s for s, _ in data[TAG_MEAN]]
    ys = [v for _, v in data[TAG_MEAN]]

    fig, ax = plt.subplots(figsize=(9, 4.6))
    ax.plot(xs, ys, color=COLORS[0], linewidth=1.8, label="Total reward (mean)")
    if TAG_MIN in data and TAG_MAX in data:
        lo = [v for _, v in data[TAG_MIN]]
        hi = [v for _, v in data[TAG_MAX]]
        if len(lo) == len(xs) and len(hi) == len(xs):
            ax.fill_between(xs, lo, hi, color=COLORS[0], alpha=0.12, label="min-max range")
    ax.set_xlabel("Timestep")
    ax.set_ylabel("Episode return")
    ax.set_title(f"{name} - reward")
    ax.grid(alpha=0.25)
    ax.legend(loc="lower right")
    fig.tight_layout()
    path = out / f"26_{name}_reward.png"
    fig.savefig(path, dpi=160, bbox_inches="tight")
    plt.close(fig)
    return path


def plot_ab(runs: dict[str, dict], out: Path) -> Path | None:
    if "pendulum_A" not in runs or "pendulum_B" not in runs:
        return None
    fig, ax = plt.subplots(figsize=(9.5, 4.8))
    for i, name in enumerate(["pendulum_A", "pendulum_B"]):
        data = runs[name]
        if TAG_MEAN not in data or not data[TAG_MEAN]:
            continue
        xs = [s for s, _ in data[TAG_MEAN]]
        ys = [v for _, v in data[TAG_MEAN]]
        ax.plot(xs, ys, color=COLORS[i], linewidth=1.8, label=f"{name} ({'energy on' if i == 0 else 'energy off'})")
    ax.set_xlabel("Timestep")
    ax.set_ylabel("Episode return")
    ax.set_title("Pendulum A/B - reward (same seed/params, only energy term differs)")
    ax.grid(alpha=0.25)
    ax.legend(loc="lower right")
    fig.tight_layout()
    path = out / "26_pendulum_AB_reward.png"
    fig.savefig(path, dpi=160, bbox_inches="tight")
    plt.close(fig)
    return path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dirs", nargs="+", type=Path, help="训练目录，如 motrixlab/runs/week4/pendulum_A")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    runs: dict[str, dict] = {}
    events: dict[str, str] = {}
    lines = ["# 第 4 周训练曲线数值摘要", ""]

    for run_dir in args.run_dirs:
        name = run_dir.name
        ev, data = load(run_dir)
        runs[name] = data
        events[name] = str(ev)
        plot_run(name, data, args.out)

        lines.append(f"## {name}")
        lines.append("")
        lines.append(f"- event 文件：`{ev}`")
        lines.append(f"- scalar 标签数：{len(data)}")
        lines.append("")
        lines.append("| 指标 | 首值 | 末值 | 末段均值(10%) | 最大 | 记录点数 |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for tag in [TAG_MEAN, TAG_MIN, TAG_MAX, TAG_VALUE_LOSS, TAG_POLICY_LOSS]:
            s = stats(data, tag)
            if s is None:
                continue
            lines.append(
                f"| `{tag}` | {s['first']:.6g} | {s['last']:.6g} | "
                f"{s['tail_mean']:.6g} | {s['max']:.6g} | {s['count']} |"
            )
        lines.append("")

    # ---- A/B 对照小结 ----
    a, b = stats(runs.get("pendulum_A", {}), TAG_MEAN), stats(runs.get("pendulum_B", {}), TAG_MEAN)
    if a and b:
        lines.append("## Pendulum A/B 对照（同一 seed=42、同一套超参，只差能量项）")
        lines.append("")
        lines.append("| 组 | 末段均值(10%) | 末值 | 最大 |")
        lines.append("| --- | --- | --- | --- |")
        lines.append(f"| A（能量项保留） | {a['tail_mean']:.4f} | {a['last']:.4f} | {a['max']:.4f} |")
        lines.append(f"| B（能量项系数 0） | {b['tail_mean']:.4f} | {b['last']:.4f} | {b['max']:.4f} |")
        lines.append(f"| 差值 A-B | {a['tail_mean'] - b['tail_mean']:+.4f} | {a['last'] - b['last']:+.4f} | |")
        lines.append("")
        lines.append("> 注：末段均值反映“收敛后能拿多少分”，首值反映“刚起步多难”。")
        lines.append("> 单摆理论上限为 3.10/步 × 400 步 = 1240。")
        lines.append("")

    ab = plot_ab(runs, args.out)
    if ab:
        lines.append(f"![A/B 对照]({ab.name})")
        lines.append("")

    summary = args.out / "26_summary.md"
    summary.write_text("\n".join(lines), encoding="utf-8")
    (args.out / "26_summary.json").write_text(
        json.dumps({"events": events, "runs": {k: sorted(v) for k, v in runs.items()}}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print("\n".join(lines))
    print(f"\n[OK] 图与摘要已写入 {args.out}")


if __name__ == "__main__":
    main()
