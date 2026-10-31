# 运行证据

两个目录，同一套指标，不同运行环境：

| 目录 | 运行环境 | 用途 |
| --- | --- | --- |
| `cloud/` | 巧工云 GPU 服务器（Ubuntu） | **主证据**，作业提交用 |
| `local-windows/` | 本地 Windows（i5-8300H / GTX 1050 Ti / CPU 版 PyTorch） | 对照与排错，证明流程可复现 |

`comparison.md` 是两边自动生成的对照表（`scripts/09_compare.sh`），云端未跑时该列为「待生成」。

## 判定对应

| # | 作业要求 | 云端 | 本地 |
| --- | --- | --- | --- |
| 1 | 输出目录截图 | `cloud/07_runs_tree.txt`、`cloud/02_train_console.log` | `local-windows/01_runs_directory.png`、`01b_explorer_view.png`、`01_runs_tree.txt` |
| 2 | TensorBoard reward/loss 曲线 + 结论 | `cloud/03_tensorboard_reward_loss.png`、`cloud/04_summary.md`、`cloud/04_scalars.csv` | `local-windows/05_tensorboard_reward_loss.png`、`04_tensorboard_scalars.png`、`scalars.csv` |
| 3 | `play.py` 加载 checkpoint | `cloud/05_play_headless.log`、`cloud/06_play_xvfb.png` | `local-windows/03_play_demo.png`、`03_play_demo.txt`、`05_play_headless.log` |

## 本地证据文件说明

| 文件 | 内容 |
| --- | --- |
| `00_env_report.json` | 本机硬件与软件版本（UTF-16 编码，`compare_runs.py` 能自动识别） |
| `01_runs_directory.png` / `01b_explorer_view.png` | `runs/cartpole/<时间戳>_PPO/` 目录截图 |
| `01_runs_tree.txt` | `tree /F runs\cartpole` 的文本输出 |
| `01_reward_curve.png` / `02_loss_curve.png` / `03_reward_and_loss.png` | 从 tfevents 导出的曲线 |
| `scalars.csv` | 全部 scalar 原始数据（13 个 tag） |
| `04_tensorboard_scalars.png` / `05_tensorboard_reward_loss.png` | TensorBoard SCALARS 页截图 |
| `03_play_demo.png` / `03_play_demo.txt` | 带渲染窗口的推理演示（180 步 / 180.00） |
| `05_play_headless.log` | headless 推理（1000 步 / 1000.00，与云端脚本口径一致） |
| `train_console_utf8.log` | 完整训练输出（5000/5000 timesteps，83 episodes） |
| `play_console_utf8.log` | 推理控制台原文 |

原始训练产物在 `motrixlab/runs/cartpole/<时间戳>_PPO/`（checkpoint + tfevents 都在仓库里，可直接 `tensorboard --logdir` 复现曲线）。
