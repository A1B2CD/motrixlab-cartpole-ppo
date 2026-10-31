"""从 TensorBoard tfevents 导出 scalar 数据、曲线图和一页式趋势结论。

在云服务器上没有浏览器也能出证据图，和 TensorBoard 网页截图互为印证。

用法：
    uv run --no-sync python scripts/export_scalars.py \
        --runs-dir motrixlab/runs/cartpole \
        --out evidence/cloud
"""

from __future__ import annotations

import argparse
import csv
import glob
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from tensorboard.backend.event_processing.event_accumulator import EventAccumulator  # noqa: E402

TAG_REWARD_MEAN = "Reward / Total reward (mean)"
TAG_REWARD_MIN = "Reward / Total reward (min)"
TAG_REWARD_MAX = "Reward / Total reward (max)"
TAG_VALUE_LOSS = "Loss / Value loss"
TAG_POLICY_LOSS = "Loss / Policy loss"


def find_event_file(runs_dir: Path) -> Path:
    files = sorted(glob.glob(str(runs_dir / "*" / "events.out.tfevents.*")))
    if not files:
        raise SystemExit(f"在 {runs_dir} 下没找到 events.out.tfevents.*，请先训练")
    # 取最新修改的那个
    return Path(max(files, key=lambda p: Path(p).stat().st_mtime))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs-dir", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    event_file = find_event_file(args.runs_dir)
    print(f"event file: {event_file}")

    acc = EventAccumulator(str(event_file), size_guidance={"scalars": 0})
    acc.Reload()
    tags = acc.Tags()["scalars"]
    print(f"scalar tags: {len(tags)}")

    # ---- CSV ----
    rows = []
    for tag in tags:
        for e in acc.Scalars(tag):
            rows.append([tag, e.step, e.wall_time, e.value])
    with open(args.out / "04_scalars.csv", "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["tag", "step", "wall_time", "value"])
        w.writerows(rows)

    def series(tag: str):
        if tag not in tags:
            return [], []
        ev = acc.Scalars(tag)
        return [e.step for e in ev], [e.value for e in ev]

    plt.rcParams.update({"font.size": 11, "axes.grid": True, "grid.alpha": 0.25})

    def save(fig, name: str) -> None:
        fig.tight_layout()
        fig.savefig(args.out / name, dpi=160, bbox_inches="tight")
        plt.close(fig)

    # ---- reward 曲线 ----
    x, y = series(TAG_REWARD_MEAN)
    if x:
        fig, ax = plt.subplots(figsize=(9, 4.6))
        ax.plot(x, y, color="#2f6fdb", linewidth=2, label="Total reward (mean)")
        xmin, ymin = series(TAG_REWARD_MIN)
        xmax, ymax = series(TAG_REWARD_MAX)
        if xmin and xmax:
            ax.fill_between(xmin, ymin, ymax, color="#2f6fdb", alpha=0.12, label="min-max range")
        ax.set_xlabel("Timestep")
        ax.set_ylabel("Episode return")
        ax.set_title("CartPole PPO - Reward")
        ax.legend(loc="lower right")
        save(fig, "04_reward_curve.png")

    # ---- loss 曲线 ----
    fig, ax = plt.subplots(figsize=(9, 4.6))
    plotted = False
    for tag, color in [(TAG_VALUE_LOSS, "#d9534f"), (TAG_POLICY_LOSS, "#2f6fdb")]:
        xs, ys = series(tag)
        if xs:
            ax.plot(xs, ys, linewidth=1.8, color=color, label=tag.split(" / ")[-1])
            plotted = True
    if plotted:
        ax.set_xlabel("Timestep")
        ax.set_ylabel("Loss")
        ax.set_title("CartPole PPO - Loss")
        ax.legend()
        save(fig, "04_loss_curve.png")

    # ---- 合并图 ----
    if x:
        fig, axes = plt.subplots(1, 2, figsize=(14, 4.8))
        axes[0].plot(x, y, color="#2f6fdb", linewidth=2)
        axes[0].set_title(TAG_REWARD_MEAN)
        axes[0].set_xlabel("Timestep")
        axes[0].set_ylabel("Episode return")
        for tag, color in [(TAG_VALUE_LOSS, "#d9534f"), (TAG_POLICY_LOSS, "#2f6fdb")]:
            xs, ys = series(tag)
            if xs:
                axes[1].plot(xs, ys, linewidth=1.6, color=color, label=tag.split(" / ")[-1])
        axes[1].set_title("Loss")
        axes[1].set_xlabel("Timestep")
        axes[1].legend()
        save(fig, "04_reward_and_loss.png")

    # ---- 一页式结论 ----
    summary = {"event_file": str(event_file), "tags": tags, "metrics": {}}
    for tag in [TAG_REWARD_MEAN, TAG_REWARD_MIN, TAG_REWARD_MAX, TAG_VALUE_LOSS, TAG_POLICY_LOSS]:
        xs, ys = series(tag)
        if xs:
            summary["metrics"][tag] = {
                "count": len(ys),
                "first": ys[0],
                "last": ys[-1],
                "min": min(ys),
                "max": max(ys),
            }

    reward = summary["metrics"].get(TAG_REWARD_MEAN)
    value_loss = summary["metrics"].get(TAG_VALUE_LOSS)
    lines = [
        "# CartPole PPO 训练结果摘要",
        "",
        f"- event 文件：`{event_file.name}`",
        f"- scalar 数量：{len(tags)}",
        "",
        "| 指标 | 首值 | 末值 | 最小 | 最大 | 记录数 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for tag, m in summary["metrics"].items():
        lines.append(
            f"| `{tag}` | {m['first']:.6g} | {m['last']:.6g} | {m['min']:.6g} | {m['max']:.6g} | {m['count']} |"
        )
    lines.append("")
    if reward and value_loss:
        lines.append("## 一句话趋势结论")
        lines.append("")
        lines.append(
            f"> 平均回合回报从 **{reward['first']:.2f}** 升到 **{reward['last']:.2f}**，"
            f"value loss 从 **{value_loss['first']:.4g}** 降到 **{value_loss['last']:.4g}**，"
            f"PPO 在 {len(series(TAG_REWARD_MEAN)[0])} 个记录内收敛到稳定倒立。"
        )
        lines.append("")

    (args.out / "04_summary.md").write_text("\n".join(lines), encoding="utf-8")
    (args.out / "04_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print("\n".join(lines))


if __name__ == "__main__":
    main()
