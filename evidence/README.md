# 运行证据

两个目录，同一套指标，不同运行环境：

| 目录 | 运行环境 | 用途 |
| --- | --- | --- |
| `cloud/` | 巧工云 GPU 服务器（Ubuntu） | **主证据**，作业提交用 |
| `local-windows/` | 本地 Windows（i5-8300H / GTX 1050 Ti / CPU 版 PyTorch） | 对照与排错，证明流程可复现 |

## 判定对应

| # | 作业要求 | 云端 | 本地 |
| --- | --- | --- | --- |
| 1 | 输出目录截图 | `cloud/07_runs_tree.txt`、`cloud/02_train_console.log` | `local-windows/01_runs_directory.png`、`01b_explorer_view.png` |
| 2 | TensorBoard reward/loss 曲线 + 结论 | `cloud/03_tensorboard_reward_loss.png`、`cloud/04_summary.md`、`cloud/04_scalars.csv` | `local-windows/05_tensorboard_reward_loss.png`、`scalars.csv` |
| 3 | `play.py` 加载 checkpoint | `cloud/05_play_headless.log`、`cloud/06_play_xvfb.png` | `local-windows/03_play_demo.png`、`play_console_utf8.log` |

原始训练产物在 `motrixlab/runs/cartpole/<时间戳>_PPO/`（checkpoint + tfevents 都在仓库里，可直接 `tensorboard --logdir` 复现曲线）。
