# 第 4 周证据索引

> 所有文件都在本仓库里，点链接即可查看/下载。mp4 在 GitHub 文件页可以直接播放，
> 右上角 `Download` 可保存原文件。

## 1. 三个 Demo 的回放视频

| 任务 | 视频 | 时长 | 内容 |
| --- | --- | --- | --- |
| CartPole | [cartpole_demo_seed0.mp4](video/cartpole_demo_seed0.mp4) | 19.0 s | 1000 步全程未倒，累计 1000.00 |
| Pendulum | [pendulum_demo_seed0.mp4](video/pendulum_demo_seed0.mp4) | 9.4 s | 初始 +17.6°，末帧 +1.3°，直立占比 99.0% |
| Pendulum（补充） | [pendulum_demo_seed4.mp4](video/pendulum_demo_seed4.mp4) | 10.6 s | 初始 +168.1°（近垂下），可见完整摆起过程 |
| Acrobot | [acrobot_demo_seed0.mp4](video/acrobot_demo_seed0.mp4) | 12.5 s | 初始 +17.6°，直立占比 55.8%，累计 327.45 |
| Acrobot（补充） | [acrobot_demo_seed4.mp4](video/acrobot_demo_seed4.mp4) | 11.0 s | 初始 +168.1°，末帧 −0.1°，可见摆起过程 |

## 2. 能量奖励 A/B 对照的回放视频（视角一致，`--num-envs 1`）

| 组 | seed 0 | seed 1 | seed 2 |
| --- | --- | --- | --- |
| A（能量项保留） | [A_seed0](video/pendulum_A_seed0.mp4) | [A_seed1](video/pendulum_A_seed1.mp4) | [A_seed2](video/pendulum_A_seed2.mp4) |
| B（能量项系数 0） | [B_seed0](video/pendulum_B_seed0.mp4) | [B_seed1](video/pendulum_B_seed1.mp4) | [B_seed2](video/pendulum_B_seed2.mp4) |

## 3. 逐帧数据与核算表

- 逐帧 CSV（obs / reward / done）：[`csv/`](csv/)
- A/B 回放记录表：[`23_ab_table.md`](23_ab_table.md) · [`23_ab_table.txt`](23_ab_table.txt)
- 曲线数值摘要 + A/B 同图对比：[`tb/26_summary.md`](tb/26_summary.md) · [`tb/26_pendulum_AB_reward.png`](tb/26_pendulum_AB_reward.png)

## 4. 训练日志

| 任务 | 日志 |
| --- | --- |
| Acrobot demo | [`20_train_acrobot_demo.log`](20_train_acrobot_demo.log) |
| Pendulum demo | [`20_train_pendulum_demo.log`](20_train_pendulum_demo.log) |
| Pendulum A 组 | [`20_train_pendulum_A.log`](20_train_pendulum_A.log) |
| Pendulum B 组 | [`20_train_pendulum_B.log`](20_train_pendulum_B.log) |
| 一次性训练总日志 | [`25_train_all.log`](25_train_all.log) |
| 全部模型路径汇总 | [`25_training_summary.md`](25_training_summary.md) |

## 5. 模型文件（`best_agent.pt`）

| 任务 | 路径 |
| --- | --- |
| Acrobot demo | [`acrobot_demo/checkpoints/best_agent.pt`](../../motrixlab/runs/week4/acrobot_demo/checkpoints/best_agent.pt) |
| Pendulum demo | [`pendulum_demo/checkpoints/best_agent.pt`](../../motrixlab/runs/week4/pendulum_demo/checkpoints/best_agent.pt) |
| Pendulum A | [`pendulum_A/checkpoints/best_agent.pt`](../../motrixlab/runs/week4/pendulum_A/checkpoints/best_agent.pt) |
| Pendulum B | [`pendulum_B/checkpoints/best_agent.pt`](../../motrixlab/runs/week4/pendulum_B/checkpoints/best_agent.pt) |

TensorBoard 事件文件与各 checkpoint 在同一目录下（`events.out.tfevents.*`）。

## 6. B 组改动

- [`22_b_group_diff.patch`](22_b_group_diff.patch) —— 只有一行：`energy_reward` → `0.0 * energy_reward`
- [`22_A_reward_line.txt`](22_A_reward_line.txt) · [`22_B_reward_line.txt`](22_B_reward_line.txt)

## 7. 复现

```bash
bash scripts/25_train_all.sh      # Acrobot demo + Pendulum A/B 训练
bash scripts/26_tb_report.sh      # 曲线数值摘要 + A/B 对比图
ENV=acrobot TAG=demo SEED=0 bash scripts/21_record_episode.sh
STAGES=record bash scripts/22_pendulum_ab.sh
STAGES=analyze bash scripts/22_pendulum_ab.sh
```

完整步骤见 [`../../docs/第4周作业操作手册.md`](../../docs/第4周作业操作手册.md)，
答题内容见 [`../../docs/第4周作业答案.md`](../../docs/第4周作业答案.md)。
