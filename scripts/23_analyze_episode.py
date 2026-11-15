#!/usr/bin/env python3
"""23 - 从 play.py 的逐帧 CSV 里核算「摆杆角度」并给出 A/B 回放记录表的数值依据。

play.py 的 CSV 每行是：step, obs0..obsN, reward, done
  * pendulum : obs = [cos θ, sin θ, θ̇]              → θ = atan2(obs1, obs0)
  * acrobot  : obs = [cos θ1, cos(θ1+θ2), sin θ1, sin(θ1+θ2), θ̇1, θ̇2]
                                                    → θ1 = atan2(obs2, obs0)
  * cartpole : obs = [x, θ, ẋ, θ̇]                   → θ = obs1

「直立范围」判据：摆杆与竖直向上方向的夹角 ≤ 15°。
pendulum / cartpole 里 θ 本身就是「偏离竖直向上」的角度，所以判据是 |θ| ≤ 15°。

用法：
    python3 scripts/23_analyze_episode.py --env pendulum --csv evidence/week4/csv/pendulum_A_seed0.csv
    python3 scripts/23_analyze_episode.py --env pendulum --csv evidence/week4/csv/*.csv   # 批量
    python3 scripts/23_analyze_episode.py --env pendulum --csv a.csv b.csv --markdown

只用标准库，云上不需要额外装包。
"""

from __future__ import annotations

import argparse
import csv
import glob
import math
import os
import sys

UPRIGHT_DEG = 15.0


def wrap_pi(x: float) -> float:
    """把角度折到 (-pi, pi]。"""
    return (x + math.pi) % (2 * math.pi) - math.pi


def angles_from_row(env: str, row: dict[str, str]) -> float:
    """从一行观测里取出「摆杆偏离竖直向上」的角度（弧度）。"""
    o = [float(row[k]) for k in sorted(row, key=lambda k: (len(k), k)) if k.startswith("obs")]
    if env == "pendulum":
        return wrap_pi(math.atan2(o[1], o[0]))
    if env == "acrobot":
        # 第一根连杆相对竖直向上的角度
        return wrap_pi(math.atan2(o[2], o[0]))
    if env == "cartpole":
        return wrap_pi(o[1])
    raise SystemExit(f"未知 env：{env}")


def load(path: str, env: str):
    steps, angles, rewards, dones = [], [], [], []
    with open(path, newline="", encoding="utf-8") as fp:
        for row in csv.DictReader(fp):
            steps.append(int(row["step"]))
            angles.append(angles_from_row(env, row))
            rewards.append(float(row["reward"]))
            dones.append(int(row.get("done", 0)))
    return steps, angles, rewards, dones


def analyze(path: str, env: str) -> dict:
    steps, angles, rewards, dones = load(path, env)
    if not angles:
        raise SystemExit(f"{path} 是空文件")

    # 只统计第一个回合（到第一次 done 为止）
    end = len(angles)
    for i, d in enumerate(dones):
        if d:
            end = i + 1
            break

    a = angles[:end]
    deg = [math.degrees(x) for x in a]
    inside = [abs(d) <= UPRIGHT_DEG for d in deg]

    first_inside = next((steps[i] for i in range(end) if inside[i]), None)
    return {
        "file": os.path.basename(path),
        "steps": end,
        "initial_deg": deg[0],
        "final_deg": deg[-1],
        "ever_upright": first_inside is not None,
        "first_upright_step": first_inside,
        "final_upright": abs(deg[-1]) <= UPRIGHT_DEG,
        "inside_ratio": sum(inside) / len(inside),
        "min_abs_deg": min(abs(d) for d in deg),
        "mean_reward": sum(rewards[:end]) / end,
        "total_reward": sum(rewards[:end]),
    }


def fmt_verdict(flag: bool) -> str:
    return "是" if flag else "否"


CTRL_DT = {"pendulum": 0.025, "acrobot": 0.02, "cartpole": 0.01}


def print_table(rows: list[dict], markdown: bool, env: str) -> None:
    if markdown:
        print("| 组别 / 回合 | 初始姿态 | 是否曾到达直立范围 | 末帧是否在直立范围内 | 证据时间点 |")
        print("| --- | --- | --- | --- | --- |")
        for r in rows:
            ever = fmt_verdict(r["ever_upright"])
            if r["first_upright_step"] is not None:
                ever += f"（第 {r['first_upright_step']} 步首次进入）"
            tag = r["file"].replace(".csv", "")
            print(
                f"| {tag} | {r['initial_deg']:+.1f}° | {ever} | {fmt_verdict(r['final_upright'])}"
                f"（{r['final_deg']:+.1f}°） | 末帧 {r['steps']} 步 / {r['steps'] * CTRL_DT[env]:.2f} s |"
            )
        return

    head = f"{'file':34s} {'步数':>5s} {'初始°':>8s} {'末帧°':>8s} {'曾直立':>6s} {'末帧直立':>8s} {'直立占比':>8s} {'累计奖励':>9s}"
    print(head)
    print("-" * len(head))
    for r in rows:
        print(
            f"{r['file']:34s} {r['steps']:5d} {r['initial_deg']:+8.1f} {r['final_deg']:+8.1f} "
            f"{fmt_verdict(r['ever_upright']):>6s} {fmt_verdict(r['final_upright']):>8s} "
            f"{r['inside_ratio'] * 100:7.1f}% {r['total_reward']:9.2f}"
        )


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="核算回放 CSV 里的摆杆角度")
    ap.add_argument("--env", required=True, choices=["pendulum", "acrobot", "cartpole"])
    ap.add_argument("--csv", nargs="+", required=True, help="CSV 路径，支持通配符")
    ap.add_argument("--markdown", action="store_true", help="直接输出作业表格（Markdown）")
    args = ap.parse_args(argv)

    paths: list[str] = []
    for pattern in args.csv:
        matched = sorted(glob.glob(pattern))
        paths.extend(matched if matched else [pattern])
    missing = [p for p in paths if not os.path.isfile(p)]
    if missing:
        print("找不到这些文件：", missing, file=sys.stderr)
        return 2

    rows = [analyze(p, args.env) for p in paths]
    print_table(rows, args.markdown, args.env)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
