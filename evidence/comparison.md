# 本地 Windows 与巧工云服务器：CartPole PPO 运行对比

- 生成时间：2026-10-31T19:57:10+08:00
- 本地证据目录：`evidence/local-windows`
- 云端证据目录：`evidence/cloud`
- 两边超参一致：`cartpole`、64 并行环境、5000 timesteps、`hiddens=[32,32]`

> 缺失项显示为「待生成」。云端跑完 `scripts/run_all.sh` 后重新执行
> `python scripts/compare_runs.py` 即可补齐。

## 1. 运行环境

| 项目 | 本地 Windows | 巧工云服务器 |
| --- | --- | --- |
| 主机名 | DESKTOP-KDF3DEV | 待生成 |
| 操作系统 | Windows 10 (AMD64) | 待生成 |
| Python | 3.10.11 | 待生成 |
| CPU | Intel(R) Core(TM) i5-8300H CPU @ 2.30GHz (4C/8T) | 待生成 |
| 内存 (GB) | 15.9 | 待生成 |
| GPU | NVIDIA GeForce GTX 1050 Ti 4096MB / 驱动 528.79 / CC 6.1 | 待生成 |
| PyTorch | 2.7.0+cpu | 待生成 |
| CUDA 可用 | 否 | 待生成 |
| CUDA 设备 | 待生成 | 待生成 |
| motrixsim | 0.7.0 | 待生成 |
| skrl | 1.4.3 | 待生成 |
| numpy | 2.2.6 | 待生成 |
| gymnasium | 1.1.1 | 待生成 |
| tensorboard | 2.20.0 | 待生成 |

## 2. 训练结果

| 指标 | 本地 Windows | 巧工云服务器 |
| --- | --- | --- |
| 训练目录 | 26-10-31_18-14-47-731131_PPO | 待生成 |
| checkpoint 数量 | 11 | 待生成 |
| 记录的 episode 数 | 83 | 待生成 |
| 平均回报 · 首次 | 32.49 | 待生成 |
| 平均回报 · 末次 | 1000.00 | 待生成 |
| 平均回报 · 最高 | 1000.00 | 待生成 |
| value loss · 首次 | 3.487 | 待生成 |
| value loss · 末次 | 2.016e-06 | 待生成 |
| 训练耗时 (秒) | 82.4 | 待生成 |

## 3. 推理演示（play.py）

| 指标 | 本地 Windows | 巧工云服务器 |
| --- | --- | --- |
| 加载的 checkpoint | runs/cartpole/26-10-31_18-14-47-731131_PPO/checkpoints/best_agent.pt | 待生成 |
| 运行步数 | 1000 | 待生成 |
| 平均回合回报 | 1000.00 | 待生成 |

## 4. 自动结论

- 云端训练数据尚未生成，无法对比收敛情况。
- 本地训练耗时 **82.4s**；云端数据待生成。
- 本地推理跑通 **1000** 步；云端待生成。
