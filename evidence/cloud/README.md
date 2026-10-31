# 云端证据（待服务器生成）

本目录由 `scripts/*.sh` 在巧工云服务器上自动写入。跑完 `bash scripts/07_collect_evidence.sh` 后会生成 `07_manifest.md` 汇总表。

| 文件 | 生成脚本 | 内容 |
| --- | --- | --- |
| `00_server_report.txt` / `.json` | `00_check_server.sh` | 服务器 CPU / 内存 / GPU / 驱动 / CUDA / 磁盘 / 工具链 |
| `02_train_console.log` | `02_train.sh` | 训练命令、torch 版本、完整训练输出、checkpoint 清单 |
| `03_tensorboard.log` / `.pid` | `03_tensorboard.sh` | TensorBoard 启动日志 |
| `03_tensorboard_reward_loss.png` | 人工截图 | TensorBoard SCALARS 页 Reward + Loss 曲线 |
| `04_scalars.csv` | `04_export_scalars.sh` | 全部 scalar 原始数据 |
| `04_reward_curve.png` / `04_loss_curve.png` / `04_reward_and_loss.png` | `04_export_scalars.sh` | 服务器端导出的高清曲线 |
| `04_summary.md` / `.json` | `04_export_scalars.sh` | 首末值、极值、一句话趋势结论 |
| `05_play_headless.log` | `05_play_headless.sh` | headless 推理：加载的 checkpoint、步数、平均回报 |
| `06_play_xvfb.log` / `06_play_xvfb.png` | `06_play_xvfb.sh` | xvfb 虚拟显示下的渲染日志与截图（可能失败，失败不影响证据 3） |
| `07_runs_tree.txt` | `07_collect_evidence.sh` | `runs/cartpole` 目录树（类型、大小、路径） |
| `07_checksums.txt` | `07_collect_evidence.sh` | 所有证据文件的 sha256 |
| `07_manifest.md` | `07_collect_evidence.sh` | 文件清单 |
